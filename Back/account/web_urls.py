from django.urls import path

from .web_views import delete_account_page

app_name = 'account_web'

urlpatterns = [
    path(
        'delete-account/',
        delete_account_page,
        name='delete_account',
    ),
]
