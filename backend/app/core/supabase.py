from supabase import Client, create_client

from app.core.config import get_settings

settings = get_settings()


def get_public_supabase() -> Client:
    """
    Uses the publishable key.
    Public/RLS-protected operations use this client.
    """
    return create_client(
        settings.supabase_url,
        settings.supabase_publishable_key,
    )


def get_service_supabase() -> Client:
    """
    Uses the secret key.
    Trusted backend operations only.
    Never expose this client/key to the frontend.
    """
    return create_client(
        settings.supabase_url,
        settings.supabase_secret_key,
    )