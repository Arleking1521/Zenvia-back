import os


def fake_payments_enabled_for(user):
    """Return True only for explicitly whitelisted development accounts.

    Required environment variables:
      ALLOW_FAKE_PAYMENTS=True
      FAKE_PAYMENT_ALLOWED_EMAILS=test@example.com[,second@example.com]

    The whitelist is mandatory on purpose so a public development server cannot
    accidentally grant free subscriptions to every authenticated parent.
    """

    enabled = os.getenv('ALLOW_FAKE_PAYMENTS', 'False').strip().lower()
    if enabled not in {'1', 'true', 'yes', 'on'}:
        return False

    allowed = {
        value.strip().lower()
        for value in os.getenv('FAKE_PAYMENT_ALLOWED_EMAILS', '').split(',')
        if value.strip()
    }
    if not allowed:
        return False

    email = (getattr(user, 'email', '') or '').strip().lower()
    return email in allowed
