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
    GameQuestion,
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
    language_code = serializers.CharField(source='language.code', read_only=True)
    rounds_answered = serializers.SerializerMethodField()

    class Meta:
        model = GameSession
        fields = [
            'id',
            'profile',
            'language',
            'language_code',
            'topic',
            'game_type',
            'question_count',
            'rounds_answered',
            'correct_count',
            'wrong_count',
            'xp_earned',
            'started_at',
            'finished_at',
        ]

        read_only_fields = [
            'profile',
            'language',
            'language_code',
            'topic',
            'game_type',
            'question_count',
            'rounds_answered',
            'correct_count',
            'wrong_count',
            'xp_earned',
            'started_at',
            'finished_at',
        ]

    def get_rounds_answered(self, obj):
        return obj.questions.filter(is_answered=True).count()


class GameSessionCreateSerializer(serializers.Serializer):
    language = serializers.SlugRelatedField(
        slug_field='code',
        queryset=Language.objects.all(),
    )
    topic = serializers.PrimaryKeyRelatedField(
        queryset=Topic.objects.filter(is_active=True),
    )
    game_type = serializers.ChoiceField(choices=GameSession.GAME_TYPES_CHOICES)
    question_count = serializers.IntegerField(min_value=1, max_value=20, default=10)

    def validate(self, attrs):
        from .game_services import validate_game_content

        validate_game_content(
            attrs['topic'],
            attrs['language'],
            attrs['game_type'],
        )
        return attrs

    def create(self, validated_data):
        request = self.context['request']
        from account.services import get_child_profile
        return GameSession.objects.create(
            profile=get_child_profile(request),
            **validated_data,
        )


class GameAnswerRequestSerializer(serializers.Serializer):
    question_id = serializers.IntegerField(min_value=1)
    answer_id = serializers.IntegerField(min_value=1, required=False)
    pairs = serializers.ListField(
        child=serializers.DictField(),
        required=False,
    )

    def validate(self, attrs):
        if 'answer_id' not in attrs and 'pairs' not in attrs:
            raise serializers.ValidationError(
                'Передайте answer_id либо pairs.'
            )
        return attrs


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
    # Счёт и XP вычисляются исключительно сервером.
    pass
