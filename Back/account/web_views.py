from django.shortcuts import render
from django.views.decorators.clickjacking import xframe_options_deny
from django.views.decorators.cache import never_cache


@never_cache
@xframe_options_deny
def delete_account_page(request):
    """Public page for a parent to permanently delete their own account.

    The page does not accept a user id. JavaScript authenticates the parent
    through the existing JWT login endpoint and then calls the same
    delete-account API used by Flutter. The access token is kept only in page
    memory and is never written to localStorage/sessionStorage/cookies.
    """
    return render(request, 'account/delete_account.html')
