from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from .models import Concept, DailyWordLesson, DailyWordLessonItem, Word
from .xp_services import get_xp_local_date


DAILY_WORDS_PER_LESSON = 5


def _eligible_new_concepts(profile, topic, language):
    introduced_ids = DailyWordLessonItem.objects.filter(
        lesson__profile=profile,
        lesson__topic=topic,
        lesson__language=language,
        lesson__completed_at__isnull=False,
    ).values_list('concept_id', flat=True)

    playable_concept_ids = (
        Word.objects
        .filter(
            concept__topic=topic,
            concept__is_active=True,
            language=language,
            audio__isnull=False,
        )
        .exclude(audio='')
        .values_list('concept_id', flat=True)
    )

    return (
        Concept.objects
        .filter(
            topic=topic,
            is_active=True,
            id__in=playable_concept_ids,
        )
        .exclude(id__in=introduced_ids)
        .order_by('position', 'id')
    )


@transaction.atomic
def get_or_create_daily_lesson(profile, topic, language):
    """Return today's stable server-side set of up to five new words."""
    local_date = get_xp_local_date()
    lesson, created = DailyWordLesson.objects.get_or_create(
        profile=profile,
        topic=topic,
        language=language,
        date=local_date,
        defaults={'required_count': 0},
    )
    lesson = DailyWordLesson.objects.select_for_update().get(pk=lesson.pk)

    if created:
        concepts = list(
            _eligible_new_concepts(profile, topic, language)[:DAILY_WORDS_PER_LESSON]
        )
        DailyWordLessonItem.objects.bulk_create([
            DailyWordLessonItem(
                lesson=lesson,
                concept=concept,
                position=index,
            )
            for index, concept in enumerate(concepts)
        ])
        lesson.required_count = len(concepts)
        if not concepts:
            lesson.completed_at = timezone.now()
        lesson.save(update_fields=['required_count', 'completed_at', 'updated_at'])

    return lesson


@transaction.atomic
def mark_daily_word_listened(profile, lesson, concept_id):
    local_date = get_xp_local_date()
    lesson = (
        DailyWordLesson.objects
        .select_for_update()
        .filter(pk=lesson.pk, profile=profile)
        .first()
    )
    if lesson is None:
        raise ValidationError({'detail': 'Ежедневный урок не найден.'})
    if lesson.date != local_date:
        raise ValidationError({'detail': 'Этот ежедневный урок уже устарел. Откройте тему заново.'})

    item = (
        DailyWordLessonItem.objects
        .select_for_update()
        .filter(lesson=lesson, concept_id=concept_id)
        .first()
    )
    if item is None:
        raise ValidationError({'concept': 'Это слово не входит в сегодняшний урок.'})

    if item.listened_at is None:
        item.listened_at = timezone.now()
        item.save(update_fields=['listened_at'])

    studied_count = lesson.items.filter(listened_at__isnull=False).count()
    if lesson.completed_at is None and studied_count >= lesson.required_count:
        lesson.completed_at = timezone.now()
        lesson.save(update_fields=['completed_at', 'updated_at'])

    return lesson


def ensure_daily_lesson_complete(profile, topic, language):
    lesson = get_or_create_daily_lesson(profile, topic, language)
    if not lesson.is_complete:
        raise ValidationError({
            'detail': (
                'Сначала изучите 5 новых слов сегодняшнего урока по этой теме. '
                f'Прогресс: {lesson.studied_count}/{lesson.required_count}.'
            ),
            'daily_lesson_required': True,
            'daily_lesson_id': lesson.id,
            'studied_count': lesson.studied_count,
            'required_count': lesson.required_count,
        })
    return lesson
