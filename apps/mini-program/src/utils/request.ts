import { API_BASE_URL } from '@/config'
import type { AuthSession } from '@/types/api'

const TOKEN_KEY = 'matchit_token'
const SESSION_KEY = 'matchit_session'

export class ApiError extends Error {
  status: number
  action?: string

  constructor(message: string, status: number, action?: string) {
    super(message)
    this.status = status
    this.action = action
  }
}

export function getToken(): string {
  return (uni.getStorageSync(TOKEN_KEY) as string) || ''
}

export function saveSession(session: AuthSession) {
  uni.setStorageSync(TOKEN_KEY, session.token)
  uni.setStorageSync(SESSION_KEY, session)
}

export function loadSession(): AuthSession | null {
  return (uni.getStorageSync(SESSION_KEY) as AuthSession) || null
}

export function clearSession() {
  uni.removeStorageSync(TOKEN_KEY)
  uni.removeStorageSync(SESSION_KEY)
}

export async function request<T>(
  path: string,
  options: UniApp.RequestOptions = {},
): Promise<T> {
  const token = getToken()
  const url = path.startsWith('http') ? path : `${API_BASE_URL}${path}`

  return new Promise((resolve, reject) => {
    uni.request({
      url,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...((options.header as Record<string, string>) || {}),
      },
      success(res) {
        const status = res.statusCode || 0
        const body = res.data as Record<string, unknown>
        if (status >= 200 && status < 300) {
          resolve(body as T)
          return
        }
        const message =
          (body?.message as string) ||
          (body?.error as string) ||
          `HTTP ${status}`
        reject(
          new ApiError(message, status, body?.action as string | undefined),
        )
      },
      fail(err) {
        reject(new ApiError(err.errMsg || 'network error', 0))
      },
    })
  })
}

export function parseAuthResponse(json: Record<string, unknown>): AuthSession {
  const user = json.user as Record<string, unknown>
  return {
    token: json.token as string,
    refreshToken: json.refreshToken as string | undefined,
    userId: String(user.id),
    openid: (user.openid as string) || '',
    isGuest: (user.isGuest as boolean) ?? true,
    username: (user.username as string) || '游客',
    phone: user.phone as string | undefined,
  }
}
