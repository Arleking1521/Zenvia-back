from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    LanguageViewSet,
    TopicViewSet,
    ConceptViewSet,
    WordViewSet,
    WordProgressViewSet,
    LiteraryContentViewSet,
    ProfileContentProgressViewSet,
    GameSessionViewSet,
    AchievementViewSet,
    ProfileAchievementViewSet,
    LevelViewSet,
)


router = DefaultRouter()

router.register(
    'languages',
    LanguageViewSet,
    basename='languages'
)

router.register(
    'topics',
    TopicViewSet,
    basename='topics'
)

router.register(
    'concepts',
    ConceptViewSet,
    basename='concepts'
)

router.register(
    'words',
    WordViewSet,
    basename='words'
)

router.register(
    'progress',
    WordProgressViewSet,
    basename='progress'
)

router.register(
    'literary-content',
    LiteraryContentViewSet,
    basename='literary-content'
)

router.register(
    'content-progress',
    ProfileContentProgressViewSet,
    basename='content-progress'
)

router.register(
    'game-sessions',
    GameSessionViewSet,
    basename='game-sessions'
)

router.register(
    'achievements',
    AchievementViewSet,
    basename='achievements'
)

router.register(
    'my-achievements',
    ProfileAchievementViewSet,
    basename='my-achievements'
)

router.register(
    'levels',
    LevelViewSet,
    basename='levels'
)


urlpatterns = [
    path('', include(router.urls)),
]