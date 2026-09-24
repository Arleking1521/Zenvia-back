# Models из приложения word_learning
from django.db import models
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator
# Create your models here.

DIFFICULTY_CHOICES = (
    ('Easy', 'Легко'),
    ('Medium', 'Средне'),
    ('Hard', 'Сложно')
)

class Language(models.Model):
    title = models.CharField(max_length=128, verbose_name='Название')
    code = models.CharField(max_length=5, unique=True, verbose_name='Код')
    icon = models.FileField(upload_to='icons/archives/', verbose_name='Архив картинок для языка')

    class Meta:
        verbose_name = 'Язык'
        verbose_name_plural = 'Языки'

    def __str__(self):
        return f'{self.title} ({self.code})'

class Topic(models.Model):
    difficulty = models.CharField( choices=DIFFICULTY_CHOICES ,max_length=64, verbose_name='Сложность')
    is_active = models.BooleanField(default=True, verbose_name='Активность')
    icon = models.ImageField(upload_to='icons/topics/', verbose_name='Иконка')
    position = models.PositiveIntegerField(default=0, verbose_name='Порядок')

    class Meta:
        verbose_name = 'Тема'
        verbose_name_plural = 'Темы'
        ordering = ['position', 'id']

    def __str__(self):
        translation = self.translations.first()

        if translation:
            return translation.title

        return f'Тема №{self.pk}'

class TopicTranslate(models.Model):
    language = models.ForeignKey(Language, on_delete=models.CASCADE, verbose_name='Язык')
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE, related_name='translations', verbose_name='Тема')
    title = models.CharField(max_length=128, verbose_name='Название')

    class Meta:
        verbose_name = 'Перевод темы'
        verbose_name_plural = 'Переводы тем'
        constraints = [
            models.UniqueConstraint(
                fields=['topic', 'language'],
                name='unique_topic_language'
            )
        ]

    def __str__(self):
        return f'{self.title}'

class Concept(models.Model):
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE, related_name='concepts', verbose_name='Тема')
    image = models.ImageField(upload_to='words/images/', verbose_name='Картинка слова')
    difficulty = models.CharField(choices=DIFFICULTY_CHOICES ,max_length=64, verbose_name='Сложность')
    is_active = models.BooleanField(default=True, verbose_name='Активность')
    position = models.PositiveIntegerField(default=0,verbose_name='Порядок')

    class Meta:
        verbose_name = 'Концепт'
        verbose_name_plural = 'Концепты'
        ordering = ['position', 'id']

    def __str__(self):
        return f'Концепт №{self.pk}'

class Word(models.Model):
    text = models.CharField(max_length=255, verbose_name='Текст')
    audio = models.FileField(upload_to='words/audio/', blank=True, null=True, verbose_name='Аудио')
    language = models.ForeignKey(Language, on_delete=models.CASCADE, verbose_name='Язык')
    concept = models.ForeignKey(Concept, on_delete=models.CASCADE, related_name='words', verbose_name='Концепт')
    transcription = models.CharField(max_length=128, blank=True, null=True, verbose_name='Транскрипция')
    
    class Meta:
        verbose_name = 'Слово'
        verbose_name_plural = 'Слова'
        constraints = [
            models.UniqueConstraint(
                fields=['concept', 'language'],
                name='unique_concept_language'
            )
        ]

    def __str__(self):
        return self.text

class WordProgress(models.Model):
    profile = models.ForeignKey('account.ChildProfile', on_delete=models.CASCADE, verbose_name='Профиль ребёнка')
    concept = models.ForeignKey(Concept, on_delete=models.CASCADE, verbose_name='Концепт')
    language = models.ForeignKey(Language, on_delete=models.CASCADE, verbose_name='Язык')
    mastery = models.PositiveSmallIntegerField(default=0,validators=[MinValueValidator(0), MaxValueValidator(5)], verbose_name='Статус знания')
    correct_answers = models.PositiveIntegerField(default=0, verbose_name='Кол-во правильных ответов')
    wrong_answers = models.PositiveIntegerField(default=0, verbose_name='Кол-во неправильных ответов')
    attempts = models.PositiveIntegerField(default=0, verbose_name='Попытки')
    last_played_at = models.DateTimeField(default=timezone.now, verbose_name='Дата последней игры')

    class Meta:
        verbose_name = 'Изученное слово'
        verbose_name_plural = 'Изученные слова'
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'concept', 'language'],
                name='unique_user_concept_language_progress'
            ),
            models.CheckConstraint(
                condition=models.Q(
                    mastery__gte=0,
                    mastery__lte=5
                ),
                name='mastery_between_0_and_5'
            )

        ]

    def __str__(self):
        return f'{self.profile.name}: {self.concept} / {self.language.code}'


class LiteraryContent(models.Model):
    CONTENT_TYPES_CHOICES = (
        ('poem', 'Стихотворение'),
        ('proverb', 'Пословица'),
        ('riddle', 'Загадка'),
        ('tongue_twister', 'Скороговорка')
    )

    title = models.CharField(max_length=128, blank=True, null=True, verbose_name='Название')
    text = models.TextField(verbose_name='Пословица/стих')
    audio = models.FileField(upload_to='content/audios/', blank=True, null=True, verbose_name='Аудио')
    content_type =  models.CharField(max_length=32, choices=CONTENT_TYPES_CHOICES, verbose_name='Тип контента')
    language = models.ForeignKey(Language, on_delete=models.CASCADE, verbose_name='Язык')
    image = models.ImageField(upload_to='content/images/', blank=True, null=True, verbose_name='Картинка')
    author = models.CharField(max_length=128, blank=True, null=True, verbose_name='Автор')
    difficulty = models.CharField(choices=DIFFICULTY_CHOICES, max_length=16, verbose_name='Сложность')
    position = models.PositiveIntegerField(default=0, verbose_name='Порядковый номер')
    is_active = models.BooleanField(default=True, verbose_name='Активность')

    class Meta:
        verbose_name = 'Пословица или стих'
        verbose_name_plural = 'Пословицы или стихи'

    def __str__(self):
        return f'{self.title}: {self.author}'

class ProfileContentProgress(models.Model):
    profile = models.ForeignKey('account.ChildProfile', on_delete=models.CASCADE, verbose_name='Профиль ребёнка')
    content = models.ForeignKey(LiteraryContent, on_delete=models.CASCADE, verbose_name='Пословица/стих')
    is_completed = models.BooleanField(default=False, verbose_name='Изучен ли?')
    listen_count = models.PositiveIntegerField(default=0, verbose_name='Кол-во прослушиваний')
    last_opened_at = models.DateTimeField(default=timezone.now, verbose_name='Дата последнего открытия')

    class Meta:
        verbose_name = 'Прогресс по пословице или стиху'
        verbose_name_plural = 'Прогресс по пословицам и стихам'
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'content'],
                name='unique_profile_content_progress'
            )
        ]

    def __str__(self):
        return f'{self.profile.name}: {self.listen_count}'

class GameSession(models.Model):
    GAME_TYPES_CHOICES = (
        ('image_choice', 'Выбери картинку'),
        ('word_choice', 'Выбери слово'),
        ('audio_choice', 'Прослушай и выбери'),
        ('matching', 'Найди пару')
    )
    profile = models.ForeignKey('account.ChildProfile', on_delete=models.CASCADE, verbose_name='Профиль ребёнка')
    language = models.ForeignKey(Language, on_delete=models.CASCADE, verbose_name='Язык')
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE, verbose_name='Тема')
    game_type = models.CharField( choices=GAME_TYPES_CHOICES ,max_length=128, verbose_name='Тип игры')
    correct_count = models.PositiveIntegerField(default=0, verbose_name='Кол-во правильных')
    wrong_count = models.PositiveIntegerField(default=0, verbose_name='Кол-во неправильных')
    xp_earned = models.PositiveIntegerField(default=0, verbose_name='Получаемый опыт')
    question_count = models.PositiveSmallIntegerField(default=10, validators=[MinValueValidator(1), MaxValueValidator(20)], verbose_name='Количество раундов')
    started_at = models.DateTimeField(default=timezone.now, verbose_name='Начало игры')
    finished_at = models.DateTimeField(null=True, blank=True, verbose_name='Окончание игры')

    class Meta:
        verbose_name = 'Игровая сессия'
        verbose_name_plural = 'Игровые сессии'

    def __str__(self):
        return f'{self.profile.name} : {self.game_type}'


class GameQuestion(models.Model):
    session = models.ForeignKey(
        GameSession,
        on_delete=models.CASCADE,
        related_name='questions',
        verbose_name='Игровая сессия'
    )
    sequence = models.PositiveSmallIntegerField(verbose_name='Номер раунда')
    concept = models.ForeignKey(
        Concept,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='+',
        verbose_name='Основной концепт'
    )
    payload = models.JSONField(default=dict, blank=True, verbose_name='Данные задания')
    correct_answer = models.JSONField(default=dict, blank=True, verbose_name='Правильный ответ')
    submitted_answer = models.JSONField(default=dict, blank=True, verbose_name='Ответ пользователя')
    is_answered = models.BooleanField(default=False, verbose_name='Есть ответ')
    is_correct = models.BooleanField(null=True, blank=True, verbose_name='Ответ полностью верный')
    correct_items = models.PositiveSmallIntegerField(default=0, verbose_name='Правильных элементов')
    wrong_items = models.PositiveSmallIntegerField(default=0, verbose_name='Ошибочных элементов')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создано')
    answered_at = models.DateTimeField(null=True, blank=True, verbose_name='Отвечено')

    class Meta:
        verbose_name = 'Игровой вопрос'
        verbose_name_plural = 'Игровые вопросы'
        ordering = ['session_id', 'sequence']
        constraints = [
            models.UniqueConstraint(
                fields=['session', 'sequence'],
                name='unique_game_session_question_sequence'
            )
        ]

    def __str__(self):
        return f'Сессия #{self.session_id}, раунд {self.sequence}'


class DailyWordLesson(models.Model):
    """Server-owned daily set of new words for one child/topic/language."""

    profile = models.ForeignKey(
        'account.ChildProfile',
        on_delete=models.CASCADE,
        related_name='daily_word_lessons',
        verbose_name='Профиль ребёнка',
    )
    topic = models.ForeignKey(
        Topic,
        on_delete=models.CASCADE,
        related_name='daily_word_lessons',
        verbose_name='Тема',
    )
    language = models.ForeignKey(
        Language,
        on_delete=models.CASCADE,
        related_name='daily_word_lessons',
        verbose_name='Язык',
    )
    date = models.DateField(verbose_name='Дата')
    required_count = models.PositiveSmallIntegerField(
        default=0,
        validators=[MaxValueValidator(5)],
        verbose_name='Слов для изучения',
    )
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Завершён',
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создан')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Обновлён')

    class Meta:
        verbose_name = 'Ежедневный урок слов'
        verbose_name_plural = 'Ежедневные уроки слов'
        ordering = ['-date', '-id']
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'topic', 'language', 'date'],
                name='unique_daily_word_lesson',
            )
        ]
        indexes = [
            models.Index(
                fields=['profile', 'topic', 'language', 'date'],
                name='daily_word_lesson_lookup_idx',
            )
        ]

    @property
    def studied_count(self):
        return self.items.filter(listened_at__isnull=False).count()

    @property
    def is_complete(self):
        return self.completed_at is not None or self.required_count == 0

    def __str__(self):
        return f'{self.profile}: {self.topic} / {self.language.code} / {self.date}'


class DailyWordLessonItem(models.Model):
    lesson = models.ForeignKey(
        DailyWordLesson,
        on_delete=models.CASCADE,
        related_name='items',
        verbose_name='Ежедневный урок',
    )
    concept = models.ForeignKey(
        Concept,
        on_delete=models.CASCADE,
        related_name='daily_lesson_items',
        verbose_name='Концепт',
    )
    position = models.PositiveSmallIntegerField(default=0, verbose_name='Порядок')
    listened_at = models.DateTimeField(null=True, blank=True, verbose_name='Прослушано')

    class Meta:
        verbose_name = 'Слово ежедневного урока'
        verbose_name_plural = 'Слова ежедневного урока'
        ordering = ['position', 'id']
        constraints = [
            models.UniqueConstraint(
                fields=['lesson', 'concept'],
                name='unique_daily_lesson_concept',
            )
        ]

    @property
    def listened(self):
        return self.listened_at is not None

    def __str__(self):
        return f'{self.lesson_id}: {self.concept_id}'


class DailyXP(models.Model):
    """Сколько XP ребёнок фактически получил за конкретный календарный день."""
    profile = models.ForeignKey(
        'account.ChildProfile',
        on_delete=models.CASCADE,
        related_name='daily_xp_records',
        verbose_name='Профиль ребёнка',
    )
    date = models.DateField(verbose_name='Дата')
    earned_xp = models.PositiveIntegerField(default=0, verbose_name='XP за день')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создано')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Обновлено')

    class Meta:
        verbose_name = 'Дневной XP'
        verbose_name_plural = 'Дневной XP'
        ordering = ['-date', '-id']
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'date'],
                name='unique_profile_daily_xp',
            )
        ]
        indexes = [
            models.Index(fields=['profile', 'date'], name='daily_xp_profile_date_idx'),
        ]

    def __str__(self):
        return f'{self.profile}: {self.date} — {self.earned_xp} XP'


class Achievement(models.Model):
    CONDITION_TYPES_CHOICES = (
        ('words_learned', 'Выучено слов'),
        ('games_completed', 'Пройдено игр'),
        ('correct_answers', 'Правильных ответов'),
        ('perfect_games', 'Игр без ошибок'),
        ('poems_listened', 'Прослушано стихотворений'),
        ('proverbs_learned', 'Изучено пословиц'),
        ('topics_completed', 'Завершено тем'),
        ('xp_earned', 'Получено XP')
    )
    title = models.CharField(max_length=128, verbose_name='Название')
    description = models.TextField(verbose_name='Описание')
    icon = models.ImageField(upload_to='achievements/icons/', verbose_name='Иконка')
    condition_type = models.CharField(max_length=128, choices=CONDITION_TYPES_CHOICES, verbose_name='Условие получения')
    condition_value = models.PositiveIntegerField(validators=[MinValueValidator(1)], verbose_name='Значение условия получения')
    xp_reward = models.PositiveIntegerField(default=0, verbose_name='Получаемый опыт')
    language = models.ForeignKey(Language, null=True, blank=True, on_delete=models.SET_NULL, verbose_name='Язык')
    topic = models.ForeignKey(Topic, null=True, blank=True, on_delete=models.SET_NULL, verbose_name='Тема')
    class Meta:
        verbose_name = 'Достижение'
        verbose_name_plural = 'Достижения'

    def __str__(self):
        return self.title

class ProfileAchievement(models.Model):
    profile = models.ForeignKey('account.ChildProfile', on_delete=models.CASCADE, verbose_name='Профиль ребёнка')
    achievement = models.ForeignKey(Achievement, on_delete=models.CASCADE, verbose_name='Достижение')
    earned_at = models.DateTimeField(auto_now_add=True, verbose_name='Получено')

    class Meta:
        verbose_name = 'Полученное достижение'
        verbose_name_plural = 'Полученные достижения'
        constraints = [
            models.UniqueConstraint(
                fields=[
                    'profile',
                    'achievement'
                ],
                name='unique_profile_achievement'
            )
        ]   

    def __str__(self):
        return f'{self.profile}: {self.achievement}'

class Level(models.Model):
    number = models.PositiveSmallIntegerField(unique=True, verbose_name='Номер')
    title = models.CharField(max_length=128, verbose_name='Название')
    xp_required = models.PositiveIntegerField(unique=True, verbose_name='Необходимый опыт')
    # Временный fallback для старых данных. Основные изображения эволюции
    # хранятся в DragonLevelImage и выбираются по аватарке ребёнка.
    icon = models.ImageField(
        upload_to='levels/icons/',
        blank=True,
        null=True,
        verbose_name='Иконка по умолчанию (fallback)',
    )

    class Meta:
        verbose_name = 'Уровень'
        verbose_name_plural = 'Уровни'

    def __str__(self):
        return self.title


class DragonLevelImage(models.Model):
    """Изображение стадии эволюции для конкретной аватарки и уровня."""

    level = models.ForeignKey(
        Level,
        on_delete=models.CASCADE,
        related_name='dragon_images',
        verbose_name='Уровень',
    )
    avatar = models.ForeignKey(
        'account.Avatar',
        on_delete=models.CASCADE,
        related_name='level_dragon_images',
        verbose_name='Аватар',
    )
    image = models.ImageField(
        upload_to='levels/dragons/',
        verbose_name='Изображение дракончика',
    )

    class Meta:
        verbose_name = 'Изображение дракончика уровня'
        verbose_name_plural = 'Изображения дракончиков уровней'
        ordering = ['level_id', 'avatar_id']
        constraints = [
            models.UniqueConstraint(
                fields=['level', 'avatar'],
                name='unique_level_avatar_dragon',
            )
        ]

    def __str__(self):
        return f'{self.avatar} — уровень {self.level.number}'