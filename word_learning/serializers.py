from rest_framework import serializers

from .models import (
    Language,
    Topic,
    TopicTranslate,
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


class LanguageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Language
        fields = [
            'id',
            'title',
            'code',
            'icon',
        ]


class TopicTranslateSerializer(serializers.ModelSerializer):
    language_code = serializers.CharField(
        source='language.code',
        read_only=True
    )

    class Meta:
        model = TopicTranslate
        fields = [
            'id',
            'language',
            'language_code',
            'title',
        ]


class TopicSerializer(serializers.ModelSerializer):
    translations = TopicTranslateSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Topic
        fields = [
            'id',
            'difficulty',
            'is_active',
            'icon',
            'position',
            'translations',
        ]


class ConceptSerializer(serializers.ModelSerializer):
    class Meta:
        model = Concept
        fields = [
            'id',
            'topic',
            'image',
            'difficulty',
            'is_active',
            'position',
        ]


class WordSerializer(serializers.ModelSerializer):
    language_code = serializers.CharField(
        source='language.code',
        read_only=True
    )

    class Meta:
        model = Word
        fields = [
            'id',
            'text',
            'audio',
            'language',
            'language_code',
            'concept',
            'transcription',
        ]


class ConceptDetailSerializer(serializers.ModelSerializer):
    words = WordSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Concept
        fields = [
            'id',
            'topic',
            'image',
            'difficulty',
            'is_active',
            'position',
            'words',
        ]


class WordProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = WordProgress
        fields = [
            'id',
            'profile',
            'concept',
            'language',
            'mastery',
            'correct_answers',
            'wrong_answers',
            'attempts',
            'last_played_at',
        ]

        read_only_fields = [
            'profile',
            'mastery',
            'correct_answers',
            'wrong_answers',
            'attempts',
            'last_played_at',
        ]


class LiteraryContentSerializer(serializers.ModelSerializer):
    language_code = serializers.CharField(
        source='language.code',
        read_only=True
    )

    class Meta:
        model = LiteraryContent
        fields = [
            'id',
            'title',
            'text',
            'audio',
            'content_type',
            'language',
            'language_code',
            'image',
            'author',
            'difficulty',
            'position',
        ]


class ProfileContentProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProfileContentProgress
        fields = [
            'id',
            'profile',
            'content',
            'is_completed',
            'listen_count',
            'last_opened_at',
        ]

        read_only_fields = [
            'profile',
            'is_completed',
            'listen_count',
            'last_opened_at',
        ]


class GameSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = GameSession
        fields = [
            'id',
            'profile',
            'language',
            'topic',
            'game_type',
            'correct_count',
            'wrong_count',
            'xp_earned',
            'started_at',
            'finished_at',
        ]

        read_only_fields = [
            'profile',
            'correct_count',
            'wrong_count',
            'xp_earned',
            'started_at',
            'finished_at',
        ]


class AchievementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Achievement
        fields = '__all__'


class ProfileAchievementSerializer(serializers.ModelSerializer):
    achievement = AchievementSerializer(read_only=True)

    class Meta:
        model = ProfileAchievement
        fields = [
            'id',
            'achievement',
            'earned_at',
        ]


class LevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Level
        fields = [
            'id',
            'number',
            'title',
            'xp_required',
            'icon',
        ]

class WordAnswerRequestSerializer(serializers.Serializer):
    concept = serializers.IntegerField(min_value=1)
    language = serializers.IntegerField(min_value=1)
    is_correct = serializers.BooleanField()


class ContentListenRequestSerializer(serializers.Serializer):
    content = serializers.IntegerField(min_value=1)


class GameFinishRequestSerializer(serializers.Serializer):
    correct_count = serializers.IntegerField(min_value=0)
    wrong_count = serializers.IntegerField(min_value=0)