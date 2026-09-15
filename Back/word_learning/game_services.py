import random
from collections import Counter

from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from .models import Concept, GameQuestion, Word, WordProgress


_rng = random.SystemRandom()


def _absolute_url(request, field):
    if not field:
        return None
    try:
        url = field.url
    except (ValueError, AttributeError):
        return None
    return request.build_absolute_uri(url) if request else url


def _words_for_language(session):
    return (
        Word.objects
        .filter(
            concept__topic=session.topic,
            concept__is_active=True,
            language=session.language,
            concept__image__isnull=False,
        )
        .exclude(concept__image='')
        .select_related('concept', 'language')
    )


def _eligible_words(session, require_audio=False):
    queryset = _words_for_language(session)
    if require_audio:
        queryset = queryset.filter(audio__isnull=False).exclude(audio='')
    return list(queryset)


def validate_game_content(topic, language, game_type):
    words = list(
        Word.objects.filter(
            concept__topic=topic,
            concept__is_active=True,
            language=language,
            concept__image__isnull=False,
        ).exclude(concept__image='').select_related('concept')
    )

    concept_ids = {word.concept_id for word in words}
    if len(concept_ids) < 2:
        raise ValidationError(
            'Для игры в выбранной теме нужно минимум 2 активных слова с картинками на выбранном языке.'
        )

    if game_type == 'audio_choice':
        audio_concepts = {
            word.concept_id
            for word in words
            if word.audio and getattr(word.audio, 'name', '')
        }
        if len(audio_concepts) < 2:
            raise ValidationError(
                'Для аудио-игры нужно минимум 2 слова с аудиофайлами.'
            )


def _mastery_by_concept(session, concept_ids):
    rows = WordProgress.objects.filter(
        profile=session.profile,
        language=session.language,
        concept_id__in=concept_ids,
    ).values_list('concept_id', 'mastery')
    return {concept_id: mastery for concept_id, mastery in rows}


def _single_usage(session):
    return Counter(
        session.questions
        .exclude(concept_id__isnull=True)
        .values_list('concept_id', flat=True)
    )


def _matching_usage(session):
    usage = Counter()
    for payload in session.questions.values_list('payload', flat=True):
        if not isinstance(payload, dict):
            continue
        for concept_id in payload.get('concept_ids', []):
            try:
                usage[int(concept_id)] += 1
            except (TypeError, ValueError):
                pass
    return usage


def _pick_low_mastery_words(session, words, count, matching=False):
    unique = {}
    for word in words:
        unique[word.concept_id] = word
    candidates = list(unique.values())

    mastery = _mastery_by_concept(session, [w.concept_id for w in candidates])
    usage = _matching_usage(session) if matching else _single_usage(session)

    decorated = [
        (
            usage.get(word.concept_id, 0),
            mastery.get(word.concept_id, 0),
            _rng.random(),
            word,
        )
        for word in candidates
    ]
    decorated.sort(key=lambda item: (item[0], item[1], item[2]))
    return [item[3] for item in decorated[:count]]


def _option_words(session, target_word, all_words, size=4):
    unique = {word.concept_id: word for word in all_words}
    distractors = [
        word for concept_id, word in unique.items()
        if concept_id != target_word.concept_id
    ]
    _rng.shuffle(distractors)
    selected = [target_word] + distractors[:max(0, size - 1)]
    _rng.shuffle(selected)
    return selected


def generate_question(session):
    if session.finished_at:
        raise ValidationError('Игровая сессия уже завершена.')

    sequence = session.questions.count() + 1
    if sequence > session.question_count:
        return None

    if session.game_type == 'matching':
        words = _eligible_words(session)
        board_size = min(4, len({word.concept_id for word in words}))
        targets = _pick_low_mastery_words(
            session,
            words,
            board_size,
            matching=True,
        )
        if len(targets) < 2:
            raise ValidationError('Недостаточно слов для игры на соответствие.')

        right_words = list(targets)
        _rng.shuffle(right_words)

        payload = {
            'concept_ids': [word.concept_id for word in targets],
            'word_ids': [word.id for word in right_words],
        }
        correct = {
            'pairs': {
                str(word.concept_id): word.id
                for word in targets
            }
        }

        return GameQuestion.objects.create(
            session=session,
            sequence=sequence,
            payload=payload,
            correct_answer=correct,
        )

    require_audio = session.game_type == 'audio_choice'
    target_candidates = _eligible_words(session, require_audio=require_audio)
    if not target_candidates:
        raise ValidationError('Нет подходящих слов для генерации задания.')

    picked = _pick_low_mastery_words(
        session,
        target_candidates,
        1,
    )
    if not picked:
        raise ValidationError('Не удалось выбрать слово для задания.')
    target_word = picked[0]

    all_words = _eligible_words(session)
    if len({word.concept_id for word in all_words}) < 2:
        raise ValidationError('Недостаточно слов с картинками для вариантов ответа.')
    options = _option_words(session, target_word, all_words, size=4)

    if session.game_type == 'word_choice':
        payload = {'option_word_ids': [word.id for word in options]}
        answer_id = target_word.id
    elif session.game_type in ('image_choice', 'audio_choice'):
        payload = {'option_concept_ids': [word.concept_id for word in options]}
        answer_id = target_word.concept_id
    else:
        raise ValidationError('Неизвестный тип игры.')

    return GameQuestion.objects.create(
        session=session,
        sequence=sequence,
        concept=target_word.concept,
        payload=payload,
        correct_answer={'answer_id': answer_id},
    )


def serialize_question(question, request=None, reveal_answer=False):
    session = question.session
    data = {
        'id': question.id,
        'sequence': question.sequence,
        'total': session.question_count,
        'game_type': session.game_type,
        'answered': question.is_answered,
    }

    if session.game_type == 'matching':
        concept_ids = question.payload.get('concept_ids', [])
        word_ids = question.payload.get('word_ids', [])
        concepts = {
            concept.id: concept
            for concept in Concept.objects.filter(id__in=concept_ids)
        }
        words = {
            word.id: word
            for word in Word.objects.filter(id__in=word_ids)
        }
        data['left'] = [
            {
                'id': concept_id,
                'image': _absolute_url(request, concepts[concept_id].image)
                if concept_id in concepts else None,
            }
            for concept_id in concept_ids
        ]
        data['right'] = [
            {
                'id': word_id,
                'text': words[word_id].text,
                'transcription': words[word_id].transcription,
            }
            for word_id in word_ids
            if word_id in words
        ]
        if reveal_answer:
            pairs = question.correct_answer.get('pairs', {})
            data['correct_pairs'] = [
                {'concept_id': int(concept_id), 'word_id': int(word_id)}
                for concept_id, word_id in pairs.items()
            ]
        return data

    target_word = Word.objects.filter(
        concept=question.concept,
        language=session.language,
    ).select_related('concept').first()
    if not target_word:
        raise ValidationError('Слово для вопроса больше не найдено.')

    if session.game_type == 'word_choice':
        option_ids = question.payload.get('option_word_ids', [])
        option_map = {
            word.id: word
            for word in Word.objects.filter(id__in=option_ids)
        }
        data['prompt'] = {
            'kind': 'image',
            'image': _absolute_url(request, target_word.concept.image),
        }
        data['options'] = [
            {
                'id': word_id,
                'text': option_map[word_id].text,
                'transcription': option_map[word_id].transcription,
            }
            for word_id in option_ids
            if word_id in option_map
        ]
    elif session.game_type == 'image_choice':
        option_ids = question.payload.get('option_concept_ids', [])
        concept_map = {
            concept.id: concept
            for concept in Concept.objects.filter(id__in=option_ids)
        }
        data['prompt'] = {
            'kind': 'word',
            'text': target_word.text,
            'transcription': target_word.transcription,
        }
        data['options'] = [
            {
                'id': concept_id,
                'image': _absolute_url(request, concept_map[concept_id].image),
            }
            for concept_id in option_ids
            if concept_id in concept_map
        ]
    elif session.game_type == 'audio_choice':
        option_ids = question.payload.get('option_concept_ids', [])
        concept_map = {
            concept.id: concept
            for concept in Concept.objects.filter(id__in=option_ids)
        }
        data['prompt'] = {
            'kind': 'audio',
            'audio': _absolute_url(request, target_word.audio),
        }
        data['options'] = [
            {
                'id': concept_id,
                'image': _absolute_url(request, concept_map[concept_id].image),
            }
            for concept_id in option_ids
            if concept_id in concept_map
        ]

    if reveal_answer:
        data['correct_answer_id'] = question.correct_answer.get('answer_id')
    return data


def _update_progress(profile, concept, language, is_correct):
    # Для новой строки блокировать еще нечего. Сначала гарантированно
    # создаем/получаем прогресс, затем блокируем именно существующую строку.
    progress, _ = WordProgress.objects.get_or_create(
        profile=profile,
        concept=concept,
        language=language,
    )
    progress = WordProgress.objects.select_for_update().get(pk=progress.pk)

    progress.attempts += 1
    if is_correct:
        progress.correct_answers += 1
        if progress.mastery < 5:
            progress.mastery += 1
    else:
        progress.wrong_answers += 1
        if progress.mastery > 0:
            progress.mastery -= 1

    progress.last_played_at = timezone.now()
    progress.save(update_fields=[
        'attempts',
        'correct_answers',
        'wrong_answers',
        'mastery',
        'last_played_at',
    ])
    return progress


def submit_answer(question, *, answer_id=None, pairs=None):
    if question.is_answered:
        raise ValidationError('На этот вопрос уже был дан ответ.')

    session = question.session
    if session.finished_at:
        raise ValidationError('Игровая сессия уже завершена.')

    progresses = []

    if session.game_type == 'matching':
        if not isinstance(pairs, list):
            raise ValidationError({'pairs': 'Передайте список пар concept_id/word_id.'})

        correct_pairs = {
            int(concept_id): int(word_id)
            for concept_id, word_id in question.correct_answer.get('pairs', {}).items()
        }
        submitted = {}
        for item in pairs:
            if not isinstance(item, dict):
                continue
            try:
                concept_id = int(item['concept_id'])
                word_id = int(item['word_id'])
            except (KeyError, TypeError, ValueError):
                continue
            if concept_id in submitted:
                raise ValidationError({'pairs': 'Каждый concept_id можно отправить только один раз.'})
            submitted[concept_id] = word_id

        if set(submitted.keys()) != set(correct_pairs.keys()):
            raise ValidationError({'pairs': 'Нужно сопоставить все карточки раунда.'})

        correct_items = 0
        results = []
        for concept_id, correct_word_id in correct_pairs.items():
            chosen_word_id = submitted.get(concept_id)
            is_correct = chosen_word_id == correct_word_id
            correct_items += int(is_correct)
            concept = Concept.objects.get(pk=concept_id)
            progresses.append(
                _update_progress(session.profile, concept, session.language, is_correct)
            )
            results.append({
                'concept_id': concept_id,
                'word_id': chosen_word_id,
                'correct_word_id': correct_word_id,
                'correct': is_correct,
            })

        wrong_items = len(correct_pairs) - correct_items
        question.submitted_answer = {
            'pairs': {str(k): v for k, v in submitted.items()}
        }
        question.is_correct = wrong_items == 0
        question.correct_items = correct_items
        question.wrong_items = wrong_items
        result_payload = {'pair_results': results}
    else:
        if answer_id is None:
            raise ValidationError({'answer_id': 'Это поле обязательно.'})
        try:
            answer_id = int(answer_id)
        except (TypeError, ValueError):
            raise ValidationError({'answer_id': 'Некорректный идентификатор ответа.'})

        raw_correct_answer_id = question.correct_answer.get('answer_id')
        if raw_correct_answer_id is None:
            raise ValidationError(
                {'detail': 'У игрового вопроса отсутствует правильный ответ. Создайте новую игровую сессию.'}
            )
        try:
            correct_answer_id = int(raw_correct_answer_id)
        except (TypeError, ValueError):
            raise ValidationError(
                {'detail': 'Некорректные данные правильного ответа. Создайте новую игровую сессию.'}
            )
        is_correct = answer_id == correct_answer_id
        progresses.append(
            _update_progress(
                session.profile,
                question.concept,
                session.language,
                is_correct,
            )
        )
        question.submitted_answer = {'answer_id': answer_id}
        question.is_correct = is_correct
        question.correct_items = 1 if is_correct else 0
        question.wrong_items = 0 if is_correct else 1
        result_payload = {
            'correct_answer_id': correct_answer_id,
        }

    question.is_answered = True
    question.answered_at = timezone.now()
    question.save(update_fields=[
        'submitted_answer',
        'is_correct',
        'correct_items',
        'wrong_items',
        'is_answered',
        'answered_at',
    ])

    session.correct_count += question.correct_items
    session.wrong_count += question.wrong_items
    session.save(update_fields=['correct_count', 'wrong_count'])

    return {
        'correct': question.is_correct,
        'correct_items': question.correct_items,
        'wrong_items': question.wrong_items,
        'progresses': progresses,
        **result_payload,
    }
