import type { MatchPost } from '@/types/api'
import { areaLabel } from '@/utils/scene'
import {
  formatCostLabel,
  formatEventTime,
  isPostFull,
  memberLimit,
} from '@/utils/post'

export type ShareViewerState = {
  hasApplied?: boolean
  applicationStatus?: string
}

export const DEFAULT_SHARE_IMAGE = '/static/tab/home-active.png'

export function truncateText(text: string, max: number): string {
  const t = text.trim()
  if (t.length <= max) return t
  return `${t.slice(0, max)}…`
}

/** 分享标题/卡片上展示的组队状态（分享时拉取最新帖子数据） */
export function postShareStatusLine(
  post: MatchPost,
  viewer?: ShareViewerState,
): string {
  const limit = memberLimit(post)
  const cur = post.currentMembers
  if (isPostFull(post)) return `已满员 ${cur}/${limit}人`
  if (viewer?.applicationStatus === 'approved') {
    return `已通过 · ${cur}/${limit}人`
  }
  if (viewer?.applicationStatus === 'pending' || viewer?.hasApplied) {
    return `已申请 · ${cur}/${limit}人`
  }
  const need = Math.max(0, limit - cur)
  return `组队中 ${cur}/${limit}人 · 还差${need}人`
}

export function buildPostShareTitle(
  post: MatchPost,
  viewer?: ShareViewerState,
): string {
  const status = postShareStatusLine(post, viewer)
  const scene = areaLabel(post.area)
  const title = truncateText(post.title, 22)
  return `【${status}】${title}${scene ? ` · ${scene}` : ''}`
}

export function buildPostSharePath(postId: string): string {
  return `/pages/post/detail?id=${encodeURIComponent(postId)}`
}

export type PostShareConfig = {
  title: string
  path: string
  imageUrl: string
}

export function buildPostShareConfig(
  post: MatchPost,
  imageUrl?: string,
  viewer?: ShareViewerState,
): PostShareConfig {
  return {
    title: buildPostShareTitle(post, viewer),
    path: buildPostSharePath(post.id),
    imageUrl: imageUrl || DEFAULT_SHARE_IMAGE,
  }
}

/** 分享封面卡片副文案 */
export function postSharePosterSubline(post: MatchPost): string {
  const parts: string[] = []
  const scene = areaLabel(post.area)
  if (scene) parts.push(scene)
  const cost = formatCostLabel(post)
  if (cost) parts.push(cost)
  const time = formatEventTime(post.eventDateTime)
  if (time && time !== '时间待定') parts.push(time)
  return parts.slice(0, 2).join(' · ') || 'MATCHit 组局'
}
