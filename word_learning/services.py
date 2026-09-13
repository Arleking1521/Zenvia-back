from django.db.models import Sum

from .models import (
    Achievement,
    ProfileAchievement,
    WordProgress,
    GameSession,
    ProfileContentProgress,
    Topic,
)

def get_game_sessions(user, achievement):
    queryset = GameSession.objects.filter(
        profile=user,
        finished_at__isnull=False
    )

    if achievement.language:
        queryset = queryset.filter(
            language=achievement.language
        )

    if achievement.topic:
        queryset = queryset.filter(
            topic=achievement.topic
        )

    return queryset

def get_condition_value(user, achievement):

    condition = achievement.condition_type

    if condition == 'words_learned':

        queryset = WordProgress.objects.filter(profile=user, mastery=5)

        if achievement.language:
            queryset = queryset.filter(language=achievement.language)

        if achievement.topic:
            queryset = queryset.filter(concept__topic=achievement.topic)

        return queryset.count()

    elif condition == 'games_completed':

        return get_game_sessions(
            user,
            achievement
        ).count()

    elif condition == 'correct_answers':

        result = (get_game_sessions(user, achievement).aggregate(total=Sum('correct_count')))

        return result['total'] or 0

    elif condition == 'perfect_games':

        return get_game_sessions(
            user,
            achievement
        ).filter(
            wrong_count=0,
            correct_count__gt=0
        ).count()

    elif condition == 'poems_listened':

        queryset = ProfileContentProgress.objects.filter(
            profile=user,
            content__content_type='poem',
            listen_count__gt=0
        )

        if achievement.language:
            queryset = queryset.filter(
                content__language=achievement.language
            )

        return queryset.count()

    elif condition == 'proverbs_learned':

        queryset = ProfileContentProgress.objects.filter(
            profile=user,
            content__content_type='proverb',
            is_completed=True
        )

        if achievement.language:
            queryset = queryset.filter(
                content__language=achievement.language
            )

        return queryset.count()

    elif condition == 'topics_completed':

        if not achievement.language:
            return 0

        topics = Topic.objects.filter(
            is_active=True
        )

        if achievement.topic:
            topics = topics.filter(
                pk=achievement.topic_id
            )

        completed_topics = 0

        for topic in topics:

            concepts = topic.concepts.filter(
                is_active=True
            )

            total_concepts = concepts.count()

            if total_concepts == 0:
                continue

            learned_concepts = (
                WordProgress.objects
                .filter(
                    profile=user,
                    language=achievement.language,
                    concept__in=concepts,
                    mastery=5
                )
                .values('concept_id')
                .distinct()
                .count()
            )

            if learned_concepts == total_concepts:
                completed_topics += 1

        return completed_topics

    elif condition == 'xp_earned':

        return user.total_xp

    return 0

def check_achievements(user):

    achievements = Achievement.objects.all()

    earned_ids = set(
        ProfileAchievement.objects
        .filter(profile=user)
        .values_list(
            'achievement_id',
            flat=True
        )
    )

    new_achievements = []

    for achievement in achievements:

        if achievement.id in earned_ids:
            continue

        value = get_condition_value(
            user,
            achievement
        )

        if value >= achievement.condition_value:

            profile_achievement, created = (
                ProfileAchievement.objects.get_or_create(
                    profile=user,
                    achievement=achievement
                )
            )

            if not created:
                continue

            user.total_xp += achievement.xp_reward

            new_achievements.append(
                achievement
            )

    if new_achievements:
        user.save(
            update_fields=['total_xp']
        )

    return new_achievements