import { ref } from 'vue'
import type { MatchPost } from '@/types/api'
import {
  buildPostShareConfig,
  DEFAULT_SHARE_IMAGE,
  type ShareViewerState,
} from '@/utils/post-share'

/** 首页卡片分享时暂存，供 onShareAppMessage 读取 */
export const pendingSharePost = ref<MatchPost | null>(null)
export const pendingShareImage = ref('')

export function setPendingFeedShare(post: MatchPost | null, imageUrl = '') {
  pendingSharePost.value = post
  pendingShareImage.value = imageUrl
}

export function buildFeedShareMessage(viewer?: ShareViewerState) {
  const post = pendingSharePost.value
  if (!post) return null
  return buildPostShareConfig(
    post,
    pendingShareImage.value || DEFAULT_SHARE_IMAGE,
    viewer,
  )
}
