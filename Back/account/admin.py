from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import (
    User,
    Avatar,
    ChildProfile,
    ChildLearningLanguage,
    TariffPlan,
    Subscription,
    Kindergarten,
    PromoCode,
    PromoCodeUsage,
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
    list_display = (
        'id',
        'title',
        'price',
        'currency',
        'duration_days',
        'max_children',
        'is_public',
        'is_active',
    )
    list_filter = ('is_public', 'is_active', 'currency')
    search_fields = ('title', 'code')
    ordering = ('position', 'id')


@admin.register(Kindergarten)
class KindergartenAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name',)
    readonly_fields = ('created_at',)


@admin.register(PromoCode)
class PromoCodeAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'code',
        'kindergarten',
        'tariff',
        'is_active',
        'valid_from',
        'valid_until',
        'max_uses',
        'usage_count',
    )
    list_filter = ('is_active', 'one_use_per_parent', 'kindergarten')
    search_fields = ('code', 'kindergarten__name', 'tariff__title')
    autocomplete_fields = ('kindergarten', 'tariff')
    readonly_fields = ('created_at', 'updated_at', 'usage_count')

    @admin.display(description='Использований')
    def usage_count(self, obj):
        if obj is None or not obj.pk:
            return 0
        return obj.usages.count()

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == 'tariff':
            kwargs['queryset'] = TariffPlan.objects.filter(
                is_active=True,
                is_public=False,
            )
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


@admin.register(PromoCodeUsage)
class PromoCodeUsageAdmin(admin.ModelAdmin):
    list_display = ('id', 'promo_code', 'parent', 'subscription', 'used_at')
    list_filter = ('promo_code__kindergarten', 'promo_code')
    search_fields = (
        'promo_code__code',
        'promo_code__kindergarten__name',
        'parent__email',
    )
    autocomplete_fields = ('promo_code', 'parent', 'subscription')
    readonly_fields = ('used_at',)


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('id', 'parent', 'tariff', 'status', 'starts_at', 'ends_at', 'created_at')
    list_filter = ('status', 'tariff')
    search_fields = ('parent__email', 'parent__first_name', 'external_payment_id')
    readonly_fields = ('created_at', 'updated_at')
