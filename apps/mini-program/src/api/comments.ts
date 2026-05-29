import { request } from '@/utils/request'
import type { ApiList, CommentNotification, PostComment } from '@/types/api'

export async function listPostComments(postId: string): Promise<PostComment[]> {
  const res = await request<ApiList<PostComment>>(
    `/api/v1/posts/${postId}/comments`,
    { method: 'GET' },
  )
  return Array.isArray(res.data) ? res.data : []
}

export async function createPostComment(
  postId: string,
  body: string,
  parentId?: string,
): Promise<PostComment> {
  const res = await request<{ data: PostComment }>(
    `/api/v1/posts/${postId}/comments`,
    {
      method: 'POST',
      data: {
        body: body.trim(),
        ...(parentId ? { parentId } : {}),
      },
    },
  )
  return res.data
}

export async function listCommentNotifications(): Promise<{
  items: CommentNotification[]
  unreadCount: number
}> {
  const res = await request<{
    data?: CommentNotification[]
    unreadCount?: number
  }>('/api/v1/me/comment-notifications', { method: 'GET' })
  return {
    items: Array.isArray(res.data) ? res.data : [],
    unreadCount: Number(res.unreadCount) || 0,
  }
}

export async function markCommentNotificationRead(id: string): Promise<void> {
  await request(`/api/v1/comment-notifications/${id}/read`, { method: 'POST' })
}
