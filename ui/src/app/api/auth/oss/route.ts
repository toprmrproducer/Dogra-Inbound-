/*
  Provides authentication token to LocalProviderWrapper once loaded
  in the browser.
  Returns 401 if no token cookie exists (user needs to log in).
*/
import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

import { getAuthProvider } from '@/lib/auth/config';

const OSS_TOKEN_COOKIE = 'dograh_auth_token';
const OSS_USER_COOKIE = 'dograh_auth_user';

async function clearSessionCookies() {
  const cookieStore = await cookies();
  const cookieOptions = {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax' as const,
    maxAge: 0,
    path: '/',
  };

  cookieStore.set(OSS_TOKEN_COOKIE, '', cookieOptions);
  cookieStore.set(OSS_USER_COOKIE, '', cookieOptions);
}

export async function GET() {
  const authProvider = await getAuthProvider();

  // Only handle OSS mode
  if (authProvider !== 'local') {
    return NextResponse.json({ error: 'Not in OSS mode' }, { status: 400 });
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(OSS_TOKEN_COOKIE)?.value;
  const user = cookieStore.get(OSS_USER_COOKIE)?.value;

  // If no token exists, return 401 (user needs to sign up or log in)
  if (!token) {
    return NextResponse.json({ error: 'Not authenticated' }, { status: 401 });
  }

  const backendUrl = process.env.BACKEND_URL || 'http://api:8000';
  try {
    const validationResponse = await fetch(`${backendUrl}/api/v1/auth/me`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });

    if (!validationResponse.ok) {
      await clearSessionCookies();
      return NextResponse.json(
        { error: 'Session expired. Please sign in again.' },
        { status: 401 },
      );
    }
  } catch {
    return NextResponse.json(
      { error: 'Unable to validate authentication session' },
      { status: 503 },
    );
  }

  // Return the auth info as JSON
  return NextResponse.json({
    token,
    user: user ? JSON.parse(user) : { id: token, name: 'Local User', provider: 'local' },
  });
}
