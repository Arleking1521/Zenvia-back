from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import (
    User,
    Avatar,
    ChildProfile,
    ChildLearningLanguage,
    TariffPlan,
    Subscription,
)


@admin.register(User)
class ParentAdmin(UserAdmin):
    list_display = ('id', 'email', 'first_name', 'is_active', 'is_staff')
    search_fields = ('email', 'first_name')
    ordering = ('id',)
    fieldsets = UserAdmin.fieldsets
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Родитель', {'fields': ('email', 'first_name')}),
    )


@admin.register(Avatar)
class AvatarAdmin(admin.ModelAdmin):
    list_display = ('id', 'title')
    search_fields = ('title',)


@admin.register(ChildProfile)
class ChildProfileAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'parent', 'base_language', 'total_xp', 'is_active')
    list_filter = ('is_active', 'base_language')
    search_fields = ('name', 'parent__email', 'parent__first_name')
    autocomplete_fields = ('parent', 'base_language', 'icon')


@admin.register(ChildLearningLanguage)
class ChildLearningLanguageAdmin(admin.ModelAdmin):
    list_display = ('id', 'profile', 'language', 'is_active')
    list_filter = ('is_active', 'language')
    search_fields = ('profile__name', 'profile__parent__email')


@admin.register(TariffPlan)
class TariffPlanAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'price', 'currency', 'duration_days', 'max_children', 'is_active')
    list_filter = ('is_active', 'currency')
    search_fields = ('title', 'code')
    ordering = ('position', 'id')


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('id', 'parent', 'tariff', 'status', 'starts_at', 'ends_at', 'created_at')
    list_filter = ('status', 'tariff')
    search_fields = ('parent__email', 'parent__first_name', 'external_payment_id')
    readonly_fields = ('created_at', 'updated_at')
