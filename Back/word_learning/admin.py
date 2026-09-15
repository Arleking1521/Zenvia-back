from django.contrib import admin
from django.db.models import Count
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from urllib.parse import urlencode

from .models import *


# ---------------------------------------------------------
# Общий внешний вид Django Admin
# ---------------------------------------------------------

admin.site.site_header = "Zenvia — администрирование"
admin.site.site_title = "Zenvia Admin"
admin.site.index_title = "Управление учебным контентом и прогрессом"


def image_preview(image_field, width=70, height=70):
    """Безопасный предпросмотр ImageField в Django Admin."""
    if not image_field:
        return "—"

    try:
        return format_html(
            '<a href="{}" target="_blank">'
            '<img src="{}" style="width:{}px;height:{}px;'
            'object-fit:cover;border-radius:8px;border:1px solid #ddd;" />'
            "</a>",
            image_field.url,
            image_field.url,
            width,
            height,
        )
    except (ValueError, AttributeError):
        return "—"


@admin.action(description="Активировать выбранные записи")
def make_active(modeladmin, request, queryset):
    queryset.update(is_active=True)


@admin.action(description="Деактивировать выбранные записи")
def make_inactive(modeladmin, request, queryset):
    queryset.update(is_active=False)


# ---------------------------------------------------------
# Language
# ---------------------------------------------------------

@admin.register(Language)
class LanguageAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "code",
        "archive_link",
    )
    search_fields = (
        "title",
        "code",
    )
    ordering = ("id",)
    list_per_page = 50

    fieldsets = (
        (
            "Основная информация",
            {
                "fields": (
                    "title",
                    "code",
                    "icon",
                )
            },
        ),
    )

    @admin.display(description="Файл / архив")
    def archive_link(self, obj):
        if not obj.icon:
            return "—"

        try:
            return format_html(
                '<a href="{}" target="_blank">Открыть файл</a>',
                obj.icon.url,
            )
        except (ValueError, AttributeError):
            return "—"


# ---------------------------------------------------------
# Topic + переводы темы
# ---------------------------------------------------------

class TopicTranslateInline(admin.TabularInline):
    model = TopicTranslate
    extra = 0
    min_num = 0
    show_change_link = True
    autocomplete_fields = ("language",)
    fields = (
        "language",
        "title",
    )


@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "display_title",
        "difficulty",
        "position",
        "is_active",
        "translations_count",
        "concepts_count",
        "icon_preview",
    )
    list_display_links = (
        "id",
        "display_title",
    )
    list_editable = (
        "position",
        "is_active",
    )
    list_filter = (
        "difficulty",
        "is_active",
    )
    search_fields = (
        "translations__title",
        "translations__language__title",
        "translations__language__code",
    )
    ordering = (
        "position",
        "id",
    )
    actions = (
        make_active,
        make_inactive,
    )
    inlines = (
        TopicTranslateInline,
    )
    readonly_fields = (
        "icon_preview_large",
    )
    save_on_top = True
    list_per_page = 50

    fieldsets = (
        (
            "Настройки темы",
            {
                "fields": (
                    "difficulty",
                    "position",
                    "is_active",
                )
            },
        ),
        (
            "Оформление",
            {
                "fields": (
                    "icon",
                    "icon_preview_large",
                )
            },
        ),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .prefetch_related(
                "translations__language",
            )
            .annotate(
                _translations_count=Count(
                    "translations",
                    distinct=True,
                ),
                _concepts_count=Count(
                    "concepts",
                    distinct=True,
                ),
            )
        )

    @admin.display(description="Название темы")
    def display_title(self, obj):
        translations = list(obj.translations.all())

        if not translations:
            return f"Тема #{obj.pk}"

        # Для админки сначала показываем русское название, если оно есть.
        for translation in translations:
            if translation.language.code == "ru":
                return translation.title

        return translations[0].title

    @admin.display(
        description="Переводов",
        ordering="_translations_count",
    )
    def translations_count(self, obj):
        return obj._translations_count

    @admin.display(
        description="Концептов",
        ordering="_concepts_count",
    )
    def concepts_count(self, obj):
        return obj._concepts_count

    @admin.display(description="Иконка")
    def icon_preview(self, obj):
        return image_preview(obj.icon, 45, 45)

    @admin.display(description="Предпросмотр")
    def icon_preview_large(self, obj):
        return image_preview(obj.icon, 140, 140)


@admin.register(TopicTranslate)
class TopicTranslateAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "topic",
        "language",
    )
    list_filter = (
        "language",
    )
    search_fields = (
        "title",
        "topic__translations__title",
        "language__title",
        "language__code",
    )
    autocomplete_fields = (
        "topic",
        "language",
    )
    list_select_related = (
        "topic",
        "language",
    )
    list_per_page = 50


# ---------------------------------------------------------
# Concept + слова на 4 языках
# ---------------------------------------------------------

class WordInline(admin.TabularInline):
    model = Word
    extra = 0
    min_num = 0
    show_change_link = True
    autocomplete_fields = ("language",)
    fields = (
        "language",
        "text",
        "transcription",
        "audio",
    )
    ordering = (
        "language",
    )


@admin.register(Concept)
class ConceptAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "topic_name",
        "position",
        "difficulty",
        "is_active",
        "words_count",
        "image_preview_small",
    )
    list_display_links = (
        "id",
        "topic_name",
    )
    list_editable = (
        "position",
        "is_active",
    )
    list_filter = (
        "topic",
        "difficulty",
        "is_active",
    )
    search_fields = (
        "words__text",
        "words__transcription",
        "topic__translations__title",
    )
    autocomplete_fields = (
        "topic",
    )
    ordering = (
        "topic",
        "position",
        "id",
    )
    actions = (
        make_active,
        make_inactive,
    )
    inlines = (
        WordInline,
    )
    readonly_fields = (
        "image_preview_large",
        "words_manage_link",
    )
    save_on_top = True
    list_per_page = 50

    fieldsets = (
        (
            "Расположение",
            {
                "fields": (
                    "topic",
                    "position",
                    "difficulty",
                    "is_active",
                )
            },
        ),
        (
            "Изображение понятия",
            {
                "fields": (
                    "image",
                    "image_preview_large",
                )
            },
        ),
        (
            "Дополнительно",
            {
                "fields": (
                    "words_manage_link",
                )
            },
        ),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related("topic")
            .prefetch_related(
                "topic__translations__language",
                "words__language",
            )
            .annotate(
                _words_count=Count(
                    "words",
                    distinct=True,
                )
            )
        )

    @admin.display(description="Тема")
    def topic_name(self, obj):
        return str(obj.topic)

    @admin.display(
        description="Слов",
        ordering="_words_count",
    )
    def words_count(self, obj):
        return obj._words_count

    @admin.display(description="Картинка")
    def image_preview_small(self, obj):
        return image_preview(obj.image, 55, 55)

    @admin.display(description="Предпросмотр")
    def image_preview_large(self, obj):
        return image_preview(obj.image, 180, 180)

    @admin.display(description="Слова концепта")
    def words_manage_link(self, obj):
        if not obj.pk:
            return "Сначала сохраните концепт"

        url = reverse(
            f"admin:{obj._meta.app_label}_word_changelist"
        )
        query = urlencode(
            {
                "concept__id__exact": obj.pk,
            }
        )

        return format_html(
            '<a class="button" href="{}?{}">Открыть список слов</a>',
            url,
            query,
        )


@admin.register(Word)
class WordAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "text",
        "language",
        "concept",
        "topic_name",
        "transcription",
        "has_audio",
    )
    list_filter = (
        "language",
        "concept__topic",
    )
    search_fields = (
        "text",
        "transcription",
        "language__title",
        "language__code",
        "concept__topic__translations__title",
    )
    autocomplete_fields = (
        "language",
        "concept",
    )
    list_select_related = (
        "language",
        "concept",
        "concept__topic",
    )
    save_on_top = True
    list_per_page = 100

    fieldsets = (
        (
            "Слово",
            {
                "fields": (
                    "concept",
                    "language",
                    "text",
                    "transcription",
                )
            },
        ),
        (
            "Озвучка",
            {
                "fields": (
                    "audio",
                )
            },
        ),
    )

    @admin.display(description="Тема")
    def topic_name(self, obj):
        return str(obj.concept.topic)

    @admin.display(
        description="Аудио",
        boolean=True,
    )
    def has_audio(self, obj):
        return bool(obj.audio)


# ---------------------------------------------------------
# Прогресс изучения слов
# ---------------------------------------------------------

@admin.register(WordProgress)
class WordProgressAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "profile",
        "concept",
        "language",
        "mastery_visual",
        "correct_answers",
        "wrong_answers",
        "attempts",
        "accuracy",
        "last_played_at",
    )
    list_filter = (
        "language",
        "mastery",
        "concept__topic",
        "last_played_at",
    )
    search_fields = (
        "profile__parent__email",
        "profile__name",
        "concept__words__text",
        "language__title",
        "language__code",
    )
    raw_id_fields = (
        "profile",
    )
    autocomplete_fields = (
        "concept",
        "language",
    )
    readonly_fields = (
        "profile",
        "concept",
        "language",
        "mastery",
        "correct_answers",
        "wrong_answers",
        "attempts",
        "last_played_at",
        "accuracy",
    )
    actions = (
        "reset_progress",
    )
    date_hierarchy = "last_played_at"
    list_per_page = 100

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related(
                "profile",
                "concept",
                "language",
                "concept__topic",
            )
        )

    def has_add_permission(self, request):
        # Прогресс создается приложением/API.
        return False

    @admin.display(description="Уровень знания")
    def mastery_visual(self, obj):
        filled = "★" * obj.mastery
        empty = "☆" * (5 - obj.mastery)
        return f"{filled}{empty} ({obj.mastery}/5)"

    @admin.display(description="Точность")
    def accuracy(self, obj):
        total = obj.correct_answers + obj.wrong_answers

        if total == 0:
            return "—"

        value = round(
            (obj.correct_answers / total) * 100,
            1,
        )
        return f"{value}%"

    @admin.action(description="Сбросить прогресс выбранных пользователей")
    def reset_progress(self, request, queryset):
        updated = queryset.update(
            mastery=0,
            correct_answers=0,
            wrong_answers=0,
            attempts=0,
            last_played_at=timezone.now(),
        )

        self.message_user(
            request,
            f"Сброшено записей прогресса: {updated}",
        )


# ---------------------------------------------------------
# Литературный контент
# ---------------------------------------------------------

@admin.register(LiteraryContent)
class LiteraryContentAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "display_title",
        "content_type_label",
        "language",
        "difficulty",
        "position",
        "is_active",
        "has_audio",
        "image_preview_small",
    )
    list_display_links = (
        "id",
        "display_title",
    )
    list_editable = (
        "position",
        "is_active",
    )
    list_filter = (
        "content_type",
        "language",
        "difficulty",
        "is_active",
    )
    search_fields = (
        "title",
        "text",
        "author",
        "language__title",
        "language__code",
    )
    autocomplete_fields = (
        "language",
    )
    ordering = (
        "language",
        "content_type",
        "position",
        "id",
    )
    actions = (
        make_active,
        make_inactive,
    )
    readonly_fields = (
        "image_preview_large",
    )
    save_on_top = True
    list_per_page = 50

    fieldsets = (
        (
            "Основная информация",
            {
                "fields": (
                    "content_type",
                    "language",
                    "title",
                    "author",
                    "difficulty",
                    "position",
                    "is_active",
                )
            },
        ),
        (
            "Содержание",
            {
                "fields": (
                    "text",
                )
            },
        ),
        (
            "Медиа",
            {
                "fields": (
                    "audio",
                    "image",
                    "image_preview_large",
                )
            },
        ),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related("language")
        )

    @admin.display(description="Название")
    def display_title(self, obj):
        if obj.title:
            return obj.title

        text = (obj.text or "").strip()

        if len(text) > 55:
            return f"{text[:55]}…"

        return text or f"Контент #{obj.pk}"

    @admin.display(description="Тип")
    def content_type_label(self, obj):
        return obj.get_content_type_display()

    @admin.display(
        description="Аудио",
        boolean=True,
    )
    def has_audio(self, obj):
        return bool(obj.audio)

    @admin.display(description="Картинка")
    def image_preview_small(self, obj):
        return image_preview(obj.image, 50, 50)

    @admin.display(description="Предпросмотр")
    def image_preview_large(self, obj):
        return image_preview(obj.image, 180, 180)


# ---------------------------------------------------------
# Прогресс литературного контента
# ---------------------------------------------------------

@admin.register(ProfileContentProgress)
class ProfileContentProgressAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "profile",
        "content",
        "content_type",
        "is_completed",
        "listen_count",
        "last_opened_at",
    )
    list_filter = (
        "is_completed",
        "content__content_type",
        "content__language",
        "last_opened_at",
    )
    search_fields = (
        "profile__parent__email",
        "profile__name",
        "content__title",
        "content__text",
    )
    raw_id_fields = (
        "profile",
    )
    autocomplete_fields = (
        "content",
    )
    readonly_fields = (
        "profile",
        "content",
        "is_completed",
        "listen_count",
        "last_opened_at",
    )
    actions = (
        "reset_content_progress",
    )
    date_hierarchy = "last_opened_at"
    list_per_page = 100

    def has_add_permission(self, request):
        return False

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related(
                "profile",
                "content",
                "content__language",
            )
        )

    @admin.display(description="Тип")
    def content_type(self, obj):
        return obj.content.get_content_type_display()

    @admin.action(description="Сбросить прогресс выбранного контента")
    def reset_content_progress(self, request, queryset):
        updated = queryset.update(
            is_completed=False,
            listen_count=0,
            last_opened_at=timezone.now(),
        )

        self.message_user(
            request,
            f"Сброшено записей: {updated}",
        )


# ---------------------------------------------------------
# Игровые сессии
# ---------------------------------------------------------

@admin.register(GameSession)
class GameSessionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "profile",
        "game_type_label",
        "language",
        "topic",
        "correct_count",
        "wrong_count",
        "accuracy",
        "xp_earned",
        "question_count",
        "started_at",
        "finished_at",
        "duration",
    )
    list_filter = (
        "game_type",
        "language",
        "topic",
        "started_at",
        "finished_at",
    )
    search_fields = (
        "profile__parent__email",
        "profile__name",
        "topic__translations__title",
        "language__title",
        "language__code",
    )
    readonly_fields = (
        "profile",
        "language",
        "topic",
        "game_type",
        "correct_count",
        "wrong_count",
        "xp_earned",
        "question_count",
        "started_at",
        "finished_at",
        "accuracy",
        "duration",
    )
    date_hierarchy = "started_at"
    ordering = (
        "-started_at",
    )
    list_per_page = 100

    def has_add_permission(self, request):
        # Игровые сессии создаются через API.
        return False

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related(
                "profile",
                "language",
                "topic",
            )
            .prefetch_related(
                "topic__translations",
            )
        )

    @admin.display(description="Тип игры")
    def game_type_label(self, obj):
        return obj.get_game_type_display()

    @admin.display(description="Точность")
    def accuracy(self, obj):
        total = obj.correct_count + obj.wrong_count

        if total == 0:
            return "—"

        value = round(
            (obj.correct_count / total) * 100,
            1,
        )
        return f"{value}%"

    @admin.display(description="Длительность")
    def duration(self, obj):
        if not obj.finished_at or not obj.started_at:
            return "Не завершена"

        seconds = int(
            (
                obj.finished_at - obj.started_at
            ).total_seconds()
        )

        if seconds < 60:
            return f"{seconds} сек."

        minutes, seconds = divmod(seconds, 60)

        if minutes < 60:
            return f"{minutes} мин. {seconds} сек."

        hours, minutes = divmod(minutes, 60)
        return f"{hours} ч. {minutes} мин."


@admin.register(GameQuestion)
class GameQuestionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "session",
        "sequence",
        "is_answered",
        "is_correct",
        "correct_items",
        "wrong_items",
        "created_at",
        "answered_at",
    )
    list_filter = (
        "is_answered",
        "is_correct",
        "session__game_type",
    )
    search_fields = (
        "session__profile__parent__email",
    )
    readonly_fields = (
        "session",
        "sequence",
        "concept",
        "payload",
        "correct_answer",
        "submitted_answer",
        "is_answered",
        "is_correct",
        "correct_items",
        "wrong_items",
        "created_at",
        "answered_at",
    )
    ordering = ("-created_at",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


# ---------------------------------------------------------
# Достижения
# ---------------------------------------------------------

@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "condition_type_label",
        "condition_value",
        "xp_reward",
        "language",
        "topic",
        "icon_preview_small",
    )
    list_filter = (
        "condition_type",
        "language",
        "topic",
    )
    search_fields = (
        "title",
        "description",
        "topic__translations__title",
        "language__title",
        "language__code",
    )
    autocomplete_fields = (
        "language",
        "topic",
    )
    readonly_fields = (
        "icon_preview_large",
    )
    save_on_top = True
    list_per_page = 50

    fieldsets = (
        (
            "Достижение",
            {
                "fields": (
                    "title",
                    "description",
                    "icon",
                    "icon_preview_large",
                )
            },
        ),
        (
            "Условие получения",
            {
                "fields": (
                    "condition_type",
                    "condition_value",
                    "language",
                    "topic",
                ),
                "description": (
                    "Язык и тема необязательны. "
                    "Если они указаны, достижение будет считаться "
                    "только в рамках выбранного языка/темы."
                ),
            },
        ),
        (
            "Награда",
            {
                "fields": (
                    "xp_reward",
                )
            },
        ),
    )

    @admin.display(description="Условие")
    def condition_type_label(self, obj):
        return obj.get_condition_type_display()

    @admin.display(description="Иконка")
    def icon_preview_small(self, obj):
        return image_preview(obj.icon, 45, 45)

    @admin.display(description="Предпросмотр")
    def icon_preview_large(self, obj):
        return image_preview(obj.icon, 140, 140)


# ---------------------------------------------------------
# Полученные достижения
# ---------------------------------------------------------

@admin.register(ProfileAchievement)
class ProfileAchievementAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "profile",
        "achievement",
        "achievement_reward",
        "earned_at",
    )
    list_filter = (
        "achievement",
        "earned_at",
    )
    search_fields = (
        "profile__parent__email",
        "profile__name",
        "achievement__title",
    )
    raw_id_fields = (
        "profile",
    )
    autocomplete_fields = (
        "achievement",
    )
    readonly_fields = (
        "profile",
        "achievement",
        "earned_at",
        "achievement_reward",
    )
    date_hierarchy = "earned_at"
    ordering = (
        "-earned_at",
    )
    list_per_page = 100

    def has_add_permission(self, request):
        # Достижения выдаются сервисом check_achievements().
        return False

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related(
                "profile",
                "achievement",
            )
        )

    @admin.display(description="Награда XP")
    def achievement_reward(self, obj):
        return obj.achievement.xp_reward


# ---------------------------------------------------------
# Уровни
# ---------------------------------------------------------

@admin.register(Level)
class LevelAdmin(admin.ModelAdmin):
    list_display = (
        "number",
        "title",
        "xp_required",
        "icon_preview_small",
    )
    list_display_links = (
        "number",
    )
    list_editable = (
        "title",
        "xp_required",
    )
    search_fields = (
        "title",
    )
    ordering = (
        "number",
    )
    readonly_fields = (
        "icon_preview_large",
    )
    save_on_top = True
    list_per_page = 50

    fieldsets = (
        (
            "Уровень",
            {
                "fields": (
                    "number",
                    "title",
                    "xp_required",
                )
            },
        ),
        (
            "Оформление",
            {
                "fields": (
                    "icon",
                    "icon_preview_large",
                )
            },
        ),
    )

    @admin.display(description="Иконка")
    def icon_preview_small(self, obj):
        return image_preview(obj.icon, 45, 45)

    @admin.display(description="Предпросмотр")
    def icon_preview_large(self, obj):
        return image_preview(obj.icon, 140, 140)
