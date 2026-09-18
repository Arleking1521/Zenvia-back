from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils import timezone
from .services import check_achievements
from .game_services import generate_question, serialize_question, submit_answer
from .xp_services import award_xp, get_daily_xp_status
from account.models import ChildProfile
from account.services import get_child_profile
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema
from rest_framework.mixins import (
    ListModelMixin,
    RetrieveModelMixin,
    CreateModelMixin,
)

from rest_framework.viewsets import (
    GenericViewSet,
    ReadOnlyModelViewSet,
)

from .models import (
    Language,
    Topic,
    Concept,
    Word,
    WordProgress,
    LiteraryContent,
    ProfileContentProgress,
    GameSession,
    GameQuestion,
    Achievement,
    ProfileAchievement,
    Level,
)

from .serializers import (
    LanguageSerializer,
    TopicSerializer,
    ConceptSerializer,
    ConceptDetailSerializer,

    WordAnswerRequestSerializer,
    ContentListenRequestSerializer,
    GameFinishRequestSerializer,
    GameSessionCreateSerializer,
    GameAnswerRequestSerializer,

    WordSerializer,
    WordProgressSerializer,
    LiteraryContentSerializer,
    ProfileContentProgressSerializer,
    GameSessionSerializer,
    AchievementSerializer,
    ProfileAchievementSerializer,
    LevelSerializer,
)

class LanguageViewSet(ReadOnlyModelViewSet):
    queryset = Language.objects.all().order_by('id')
    serializer_class = LanguageSerializer
    permission_classes = [AllowAny]

class TopicViewSet(ReadOnlyModelViewSet):
    serializer_class = TopicSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            Topic.objects
            .filter(is_active=True)
            .prefetch_related(
                'translations',
                'translations__language'
            )
        )

        difficulty = self.request.query_params.get('difficulty')

        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)

        return queryset

    @action(
        detail=False,
        methods=['get'],
        url_path='by-language'
    )
        
    def by_language(self, request):
        language_code = request.query_params.get('language')

        if not language_code:
            child = get_child_profile(request)
            if not child.base_language:
                return Response(
                    {'error': 'Базовый язык профиля ребёнка не выбран'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            language_code = child.base_language.code

        topics = (
            self.get_queryset()
            .filter(
                translations__language__code=language_code
            )
        )

        result = []

        for topic in topics:
            translation = topic.translations.filter(
                language__code=language_code
            ).first()

            result.append({
                'id': topic.id,
                'title': translation.title if translation else '',
                'difficulty': topic.difficulty,
                'icon': (
                    request.build_absolute_uri(topic.icon.url)
                    if topic.icon
                    else None
                )
            })

        return Response(result)

class ConceptViewSet(ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            Concept.objects
            .filter(is_active=True)
            .select_related('topic')
            .prefetch_related(
                'words',
                'words__language'
            )
        )

        topic_id = self.request.query_params.get('topic')
        difficulty = self.request.query_params.get('difficulty')

        if topic_id:
            queryset = queryset.filter(topic_id=topic_id)

        if difficulty:
            queryset = queryset.filter(
                difficulty=difficulty
            )

        return queryset

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ConceptDetailSerializer

        return ConceptSerializer

class WordViewSet(ReadOnlyModelViewSet):
    serializer_class = WordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            Word.objects
            .select_related(
                'language',
                'concept',
                'concept__topic'
            )
        )

        language = self.request.query_params.get('language')
        concept = self.request.query_params.get('concept')
        topic = self.request.query_params.get('topic')

        if language:
            queryset = queryset.filter(
                language__code=language
            )

        if concept:
            queryset = queryset.filter(
                concept_id=concept
            )

        if topic:
            queryset = queryset.filter(
                concept__topic_id=topic
            )

        return queryset

class WordProgressViewSet(ListModelMixin, RetrieveModelMixin, GenericViewSet):
    serializer_class = WordProgressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            WordProgress.objects
            .filter(profile=get_child_profile(self.request))
            .select_related(
                'concept',
                'language'
            )
        )

        language = self.request.query_params.get('language')
        topic = self.request.query_params.get('topic')

        if language:
            queryset = queryset.filter(
                language__code=language
            )

        if topic:
            queryset = queryset.filter(
                concept__topic_id=topic
            )

        return queryset

    @extend_schema(
        request=WordAnswerRequestSerializer,
        responses={410: dict},
        description=(
            'Устаревший endpoint. Клиент больше не передает is_correct. '
            'Используйте /api/game-sessions/{id}/answer/, где ответ проверяет сервер.'
        )
    )
    @action(
        detail=False,
        methods=['post'],
        url_path='answer'
    )
    def answer(self, request):
        return Response(
            {
                'detail': (
                    'Прямая отправка is_correct отключена. '
                    'Используйте серверно проверяемые игровые сессии.'
                )
            },
            status=status.HTTP_410_GONE
        )

class LiteraryContentViewSet(ReadOnlyModelViewSet):
    serializer_class = LiteraryContentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            LiteraryContent.objects
            .filter(is_active=True)
            .select_related('language')
            .order_by('position')
        )

        language = self.request.query_params.get('language')
        content_type = self.request.query_params.get(
            'content_type'
        )
        difficulty = self.request.query_params.get(
            'difficulty'
        )

        if language:
            queryset = queryset.filter(
                language__code=language
            )
        else:
            child = get_child_profile(self.request)
            if child.base_language:
                queryset = queryset.filter(language=child.base_language)

        if content_type:
            queryset = queryset.filter(
                content_type=content_type
            )

        if difficulty:
            queryset = queryset.filter(
                difficulty=difficulty
            )

        return queryset

class ProfileContentProgressViewSet(ListModelMixin, RetrieveModelMixin, GenericViewSet):
    serializer_class = ProfileContentProgressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            ProfileContentProgress.objects
            .filter(profile=get_child_profile(self.request))
            .select_related('content')
        )
    
    @extend_schema(
        request=ContentListenRequestSerializer,
        responses=ProfileContentProgressSerializer,
        description='Отметить прослушивание литературного контента'
    )
    @action(
        detail=False,
        methods=['post'],
        url_path='listen'
    )
    def listen(self, request):
        request_serializer = ContentListenRequestSerializer(
            data=request.data
        )

        request_serializer.is_valid(
            raise_exception=True
        )

        content_id = request_serializer.validated_data[
            'content'
        ]

        content = get_object_or_404(
            LiteraryContent,
            pk=content_id,
            is_active=True
        )

        progress, created = (
            ProfileContentProgress.objects
            .get_or_create(
                profile=get_child_profile(request),
                content=content,
            )
        )

        progress.listen_count += 1
        progress.last_opened_at = timezone.now()

        progress.save()

        new_achievements = check_achievements(progress.profile)

        serializer = self.get_serializer(progress)

        return Response({
            'progress': serializer.data,
            'new_achievements': AchievementSerializer(
                new_achievements,
                many=True,
                context={'request': request}
            ).data
        })

    @action(
        detail=True,
        methods=['post'],
        url_path='complete'
    )
    def complete(self, request, pk=None):
        progress = self.get_object()

        progress.is_completed = True
        progress.save(
            update_fields=['is_completed']
        )

        new_achievements = check_achievements(progress.profile)

        serializer = self.get_serializer(progress)

        return Response({
            'progress': serializer.data,
            'new_achievements': AchievementSerializer(
                new_achievements,
                many=True,
                context={'request': request}
            ).data
        })

class GameSessionViewSet(CreateModelMixin, ListModelMixin, RetrieveModelMixin, GenericViewSet):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'create':
            return GameSessionCreateSerializer
        return GameSessionSerializer

    def get_queryset(self):
        return (
            GameSession.objects
            .filter(profile=get_child_profile(self.request))
            .select_related(
                'language',
                'topic'
            )
            .prefetch_related('questions')
            .order_by('-started_at')
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        game = serializer.save()
        return Response(
            GameSessionSerializer(
                game,
                context={'request': request}
            ).data,
            status=status.HTTP_201_CREATED
        )

    @action(
        detail=True,
        methods=['get'],
        url_path='next'
    )
    def next_question(self, request, pk=None):
        with transaction.atomic():
            game = (
                GameSession.objects
                .select_for_update()
                .select_related('language', 'topic', 'profile')
                .get(pk=self.get_object().pk)
            )

            if game.finished_at:
                return Response(
                    {'detail': 'Игровая сессия уже завершена.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            unanswered = game.questions.filter(
                is_answered=False
            ).order_by('sequence').first()

            if unanswered:
                return Response({
                    'complete': False,
                    'question': serialize_question(unanswered, request),
                })

            answered_rounds = game.questions.filter(
                is_answered=True
            ).count()

            if answered_rounds >= game.question_count:
                return Response({
                    'complete': True,
                    'question': None,
                    'rounds_answered': answered_rounds,
                    'question_count': game.question_count,
                })

            question = generate_question(game)
            return Response({
                'complete': False,
                'question': serialize_question(question, request),
            })

    @extend_schema(
        request=GameAnswerRequestSerializer,
        responses=dict,
        description='Проверка ответа выполняется только сервером.'
    )
    @action(
        detail=True,
        methods=['post'],
        url_path='answer'
    )
    def answer(self, request, pk=None):
        request_serializer = GameAnswerRequestSerializer(data=request.data)
        request_serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            owned_game = self.get_object()
            # Lock only the GameSession row itself.
            # Do not combine select_for_update() with select_related() here:
            # topic and other related objects may be nullable, which makes
            # PostgreSQL reject FOR UPDATE on the nullable side of an outer join.
            game = (
                GameSession.objects
                .select_for_update()
                .get(pk=owned_game.pk)
            )

            if game.finished_at:
                return Response(
                    {'detail': 'Игровая сессия уже завершена.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Lock only the GameQuestion row.
            # select_related('concept') can create a LEFT OUTER JOIN because
            # concept is nullable for some game modes. PostgreSQL does not allow
            # FOR UPDATE on the nullable side of that join.
            question = get_object_or_404(
                GameQuestion.objects.select_for_update(),
                pk=request_serializer.validated_data['question_id'],
                session=game,
            )

            result = submit_answer(
                question,
                answer_id=request_serializer.validated_data.get('answer_id'),
                pairs=request_serializer.validated_data.get('pairs'),
            )
            result.pop('progresses', None)

            game.refresh_from_db(fields=[
                'correct_count',
                'wrong_count',
                'xp_earned',
                'finished_at',
            ])
            rounds_answered = GameQuestion.objects.filter(
                session=game,
                is_answered=True,
            ).count()

            response_data = {
                **result,
                'session': {
                    'id': game.id,
                    'profile': game.profile_id,
                    'language': game.language_id,
                    'language_code': game.language.code,
                    'topic': game.topic_id,
                    'game_type': game.game_type,
                    'question_count': game.question_count,
                    'rounds_answered': rounds_answered,
                    'correct_count': game.correct_count,
                    'wrong_count': game.wrong_count,
                    'xp_earned': game.xp_earned,
                    'started_at': game.started_at,
                    'finished_at': game.finished_at,
                },
            }

        return Response(response_data, status=status.HTTP_200_OK)

    @extend_schema(
        request=GameFinishRequestSerializer,
        responses=GameSessionSerializer,
        description=(
            'Завершение игровой сессии. correct_count, wrong_count и XP '
            'вычисляются сервером и не принимаются от клиента.'
        )
    )
    @action(
        detail=True,
        methods=['post'],
        url_path='finish'
    )
    def finish(self, request, pk=None):
        with transaction.atomic():
            game = (
                GameSession.objects
                .select_for_update()
                .select_related('profile', 'language', 'topic')
                .get(pk=self.get_object().pk)
            )

            if game.finished_at:
                return Response(
                    {'detail': 'Игровая сессия уже завершена.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            answered_rounds = game.questions.filter(
                is_answered=True
            ).count()

            if answered_rounds < game.question_count:
                return Response(
                    {
                        'detail': 'Сначала ответьте на все раунды.',
                        'rounds_answered': answered_rounds,
                        'question_count': game.question_count,
                        'remaining': game.question_count - answered_rounds,
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            requested_xp = game.correct_count * 10
            if game.wrong_count == 0 and game.correct_count > 0:
                requested_xp += 30

            child = ChildProfile.objects.select_for_update().get(pk=game.profile_id)
            xp_award = award_xp(child, requested_xp)

            # В GameSession сохраняем именно фактически начисленный XP,
            # а не теоретическую награду до применения дневного лимита.
            game.xp_earned = xp_award.granted_xp
            game.finished_at = timezone.now()
            game.save(update_fields=['xp_earned', 'finished_at'])

            child.refresh_from_db(fields=['total_xp'])
            new_achievements = check_achievements(child)
            child.refresh_from_db(fields=['total_xp'])
            daily_status = get_daily_xp_status(child)

            return Response({
                'game': GameSessionSerializer(
                    game,
                    context={'request': request}
                ).data,
                'total_xp': child.total_xp,
                'xp_requested': requested_xp,
                'xp_granted': game.xp_earned,
                **daily_status,
                'new_achievements': AchievementSerializer(
                    new_achievements,
                    many=True,
                    context={'request': request}
                ).data
            })

class LevelViewSet(ReadOnlyModelViewSet):
    queryset = Level.objects.all().order_by('number')
    serializer_class = LevelSerializer
    permission_classes = [IsAuthenticated]

    @action(
        detail=False,
        methods=['get'],
        url_path='current'
    )
    def current(self, request):
        xp = get_child_profile(request).total_xp

        current_level = (
            Level.objects
            .filter(xp_required__lte=xp)
            .order_by('-xp_required')
            .first()
        )

        next_level = (
            Level.objects
            .filter(xp_required__gt=xp)
            .order_by('xp_required')
            .first()
        )

        return Response({
            'total_xp': xp,

            'current_level': (
                LevelSerializer(
                    current_level,
                    context={
                        'request': request
                    }
                ).data
                if current_level
                else None
            ),

            'next_level': (
                LevelSerializer(
                    next_level,
                    context={
                        'request': request
                    }
                ).data
                if next_level
                else None
            ),

            'xp_to_next_level': (
                next_level.xp_required - xp
                if next_level
                else 0
            )
        })

    @action(
        detail=False,
        methods=['get'],
        url_path='daily-xp'
    )
    def daily_xp(self, request):
        child = get_child_profile(request)
        return Response({
            'total_xp': child.total_xp,
            **get_daily_xp_status(child),
        })


class AchievementViewSet(ReadOnlyModelViewSet):
    serializer_class = AchievementSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Achievement.objects.all()

class ProfileAchievementViewSet(ReadOnlyModelViewSet):
    serializer_class = ProfileAchievementSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            ProfileAchievement.objects
            .filter(profile=get_child_profile(self.request))
            .select_related('achievement')
            .order_by('-earned_at')
        )

