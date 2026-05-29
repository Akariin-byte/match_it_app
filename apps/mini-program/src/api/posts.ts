import { request } from '@/utils/request'
import { parseMatchPost } from '@/utils/post'
import type {
  ApiList,
  MatchPost,
  PostMember,
  ReceivedApplicationItem,
  ReceivedApplicationsResult,
} from '@/types/api'

function buildQuery(params?: { area?: string; tab?: string }): string {
  const parts: string[] = []
  if (params?.area) parts.push(`area=${encodeURIComponent(params.area)}`)
  if (params?.tab) parts.push(`tab=${encodeURIComponent(params.tab)}`)
  return parts.length ? `?${parts.join('&')}` : ''
}

export function parseReceivedApplication(
  json: Record<string, unknown>,
): ReceivedApplicationItem {
  return {
    id: String(json.id ?? ''),
    postId: String(json.postId ?? ''),
    applicantUserId: String(json.userId ?? json.applicantUserId ?? ''),
    status: (json.status as string) || 'pending',
    postTitle: (json.postTitle as string) || '',
    postArea: (json.postArea as string) || '',
    applicantUsername: (json.applicantUsername as string) || '用户',
    applicantPhoneMasked: json.applicantPhoneMasked as string | undefined,
    wechatContact: (json.wechatContact as string) || '',
    message: json.message as string | undefined,
    createdAt: json.createdAt as string | undefined,
  }
}

export async function listMyPosts(): Promise<MatchPost[]> {
  const res = await request<ApiList<Record<string, unknown>>>(
    '/api/v1/me/posts',
    { method: 'GET' },
  )
  const list = res.data
  if (!Array.isArray(list)) return []
  return list.map((row) => parseMatchPost(row))
}

export async function listPosts(params?: {
  area?: string
  tab?: string
}): Promise<MatchPost[]> {
  const path = `/api/v1/posts${buildQuery(params)}`
  const res = await request<ApiList<Record<string, unknown>>>(path, { method: 'GET' })
  const list = res.data
  if (!Array.isArray(list)) return []
  return list.map((row) => parseMatchPost(row))
}

export async function getPost(id: string): Promise<MatchPost | null> {
  try {
    const res = await request<Record<string, unknown>>(`/api/v1/posts/${id}`, {
      method: 'GET',
    })
    if (res.data && typeof res.data === 'object') {
      return parseMatchPost(res.data as Record<string, unknown>)
    }
    if (res.id) return parseMatchPost(res)
    return null
  } catch {
    return null
  }
}

export async function getPostMembers(postId: string): Promise<PostMember[]> {
  const res = await request<ApiList<PostMember>>(`/api/v1/posts/${postId}/members`, {
    method: 'GET',
  })
  return Array.isArray(res.data) ? res.data : []
}

export type PostApplicationState = {
  hasApplied: boolean
  status?: string
}

export async function getMyPostApplication(
  postId: string,
): Promise<PostApplicationState> {
  try {
    const res = await request<{
      hasApplied?: boolean
      status?: string
      data?: { hasApplied?: boolean; status?: string }
    }>(`/api/v1/posts/${postId}/application`, { method: 'GET' })
    if (res.data) {
      return {
        hasApplied: Boolean(res.data.hasApplied),
        status: res.data.status,
      }
    }
    return {
      hasApplied: Boolean(res.hasApplied),
      status: res.status,
    }
  } catch {
    return { hasApplied: false }
  }
}

export async function applyToPost(
  postId: string,
  wechatContact: string,
  message?: string,
): Promise<{ hasApplied: boolean }> {
  const data: Record<string, string> = {
    wechatContact: wechatContact.trim(),
  }
  const msg = message?.trim()
  if (msg) data.message = msg
  const res = await request<{ hasApplied?: boolean }>(`/api/v1/posts/${postId}/apply`, {
    method: 'POST',
    data,
  })
  return { hasApplied: res.hasApplied ?? true }
}

export async function listPostReceivedApplications(
  postId: string,
): Promise<ReceivedApplicationsResult> {
  const res = await request<{
    data?: Record<string, unknown>[]
    pendingCount?: number
  }>(`/api/v1/posts/${postId}/received-applications`, { method: 'GET' })
  const raw = res.data
  const items = Array.isArray(raw)
    ? raw.map((row) => parseReceivedApplication(row))
    : []
  return {
    items,
    pendingCount: Number(res.pendingCount) || 0,
  }
}

export async function listReceivedApplications(): Promise<ReceivedApplicationsResult> {
  const res = await request<{
    data?: Record<string, unknown>[]
    pendingCount?: number
  }>('/api/v1/me/received-applications', { method: 'GET' })
  const raw = res.data
  const items = Array.isArray(raw)
    ? raw.map((row) => parseReceivedApplication(row))
    : []
  return {
    items,
    pendingCount: Number(res.pendingCount) || 0,
  }
}

export async function approveApplication(applicationId: string): Promise<void> {
  await request(`/api/v1/applications/${applicationId}/approve`, {
    method: 'POST',
  })
}

export async function rejectApplication(applicationId: string): Promise<void> {
  await request(`/api/v1/applications/${applicationId}/reject`, {
    method: 'POST',
  })
}

export async function cancelApplication(applicationId: string): Promise<void> {
  await request(`/api/v1/applications/${applicationId}/cancel`, {
    method: 'POST',
  })
}
