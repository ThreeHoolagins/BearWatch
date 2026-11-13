// Thin fetch wrapper for the Rails API. Same origin, so the session cookie
// rides along; writes carry the CSRF token from GET /api/session.

let csrfToken = ''

export function setCsrfToken(token: string) {
  csrfToken = token
}

export function getCsrfToken() {
  return csrfToken
}

export class ApiError extends Error {
  status: number
  body: unknown

  constructor(status: number, body: unknown) {
    super(`Request failed with status ${status}`)
    this.status = status
    this.body = body
  }
}

export async function api<T>(path: string, options: { method?: string; body?: unknown } = {}): Promise<T> {
  const method = options.method ?? 'GET'
  const isForm = options.body instanceof FormData
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (method !== 'GET') headers['X-CSRF-Token'] = csrfToken
  // FormData (file uploads) sets its own multipart Content-Type.
  if (options.body !== undefined && !isForm) headers['Content-Type'] = 'application/json'

  const response = await fetch(path, {
    method,
    headers,
    credentials: 'same-origin',
    body: options.body === undefined ? undefined : isForm ? (options.body as FormData) : JSON.stringify(options.body),
  })
  const text = await response.text()
  let data: unknown = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = null // e.g. a proxy's HTML "request too large" page
  }
  if (!response.ok) throw new ApiError(response.status, data)
  return data as T
}

// The server's human-readable message, if it sent one.
export function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof ApiError) {
    const message = (error.body as { message?: unknown } | null)?.message
    if (typeof message === 'string' && message) return message
  }
  return fallback
}
