from django.shortcuts import get_object_or_404
from django.utils import timezone
from .services import check_achievements
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
            if not request.user.base_language:
                return Response(
                    {
                        'error': 'Базовый язык пользователя не выбран'
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            language_code = request.user.base_language.code

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
            .filter(profile=self.request.user)
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
        responses=WordProgressSerializer,
        description='Сохранение ответа ребенка на задание'
    )
    @action(
        detail=False,
        methods=['post'],
        url_path='answer'
    )

    def answer(self, request):
        request_serializer = WordAnswerRequestSerializer(
            data=request.data
        )

        request_serializer.is_valid(
            raise_exception=True
        )

        concept_id = request_serializer.validated_data[
            'concept'
        ]

        language_id = request_serializer.validated_data[
            'language'
        ]

        is_correct = request_serializer.validated_data[
            'is_correct'
        ]

        concept = get_object_or_404(
            Concept,
            pk=concept_id,
            is_active=True
        )

        language = get_object_or_404(
            Language,
            pk=language_id
        )

        progress, created = WordProgress.objects.get_or_create(
            profile=request.user,
            concept=concept,
            language=language,
        )

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

        progress.save()

        new_achievements = check_achievements(
            request.user
        )

        serializer = self.get_serializer(progress)

        return Response({
            'progress': serializer.data,
            'new_achievements': AchievementSerializer(
                new_achievements,
                many=True,
                context={'request': request}
            ).data
        })

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
        elif self.request.user.base_language:
            queryset = queryset.filter(
                language=self.request.user.base_language
            )

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
            .filter(profile=self.request.user)
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
                profile=request.user,
                content=content,
            )
        )

        progress.listen_count += 1
        progress.last_opened_at = timezone.now()

        progress.save()

        new_achievements = check_achievements(
            request.user
        )

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

        new_achievements = check_achievements(
            request.user
        )

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
    serializer_class = GameSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            GameSession.objects
            .filter(profile=self.request.user)
            .select_related(
                'language',
                'topic'
            )
            .order_by('-started_at')
        )

    def perform_create(self, serializer):
        serializer.save(
            profile=self.request.user
        )

    @extend_schema(
        request=GameFinishRequestSerializer,
        responses=GameSessionSerializer,
        description='Завершение игровой сессии'
    )
    @action(
        detail=True,
        methods=['post'],
        url_path='finish'
    )
    

    def finish(self, request, pk=None):
        game = self.get_object()

        if game.finished_at:
            return Response(
                {
                    'error':
                    'Игровая сессия уже завершена'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        request_serializer = GameFinishRequestSerializer(
            data=request.data
        )

        request_serializer.is_valid(
            raise_exception=True
        )

        correct = request_serializer.validated_data[
            'correct_count'
        ]

        wrong = request_serializer.validated_data[
            'wrong_count'
        ]

        if correct < 0 or wrong < 0:
            return Response(
                {
                    'error':
                    'Количество ответов не может быть отрицательным'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        #
        # XP считаем только на сервере
        #
        xp = correct * 10

        if wrong == 0 and correct > 0:
            xp += 30

        game.correct_count = correct
        game.wrong_count = wrong
        game.xp_earned = xp
        game.finished_at = timezone.now()

        game.save()

        #
        # Начисляем XP пользователю
        #
        request.user.total_xp += xp
        request.user.save(
            update_fields=['total_xp']
        )
        new_achievements = check_achievements(request.user)

        serializer = self.get_serializer(game)

        return Response({
            'game': serializer.data,

            'total_xp': request.user.total_xp,

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
        xp = request.user.total_xp

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
            .filter(profile=self.request.user)
            .select_related('achievement')
            .order_by('-earned_at')
        )

