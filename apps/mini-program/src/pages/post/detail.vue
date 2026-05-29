<script setup lang="ts">
import { computed, getCurrentInstance, ref } from 'vue'
import {
  onLoad,
  onPullDownRefresh,
  onShareAppMessage,
  onShareTimeline,
  onShow,
} from '@dcloudio/uni-app'
import {
  applyToPost,
  approveApplication,
  getMyPostApplication,
  getPost,
  getPostMembers,
  cancelApplication,
  listPostReceivedApplications,
  rejectApplication,
} from '@/api/posts'
import { listPostComments } from '@/api/comments'
import { useUserStore } from '@/stores/user'
import { ApiError } from '@/utils/request'
import {
  formatCostLabel,
  formatEventTime,
  formatRelativeTime,
  isPostFull,
  memberLimit,
} from '@/utils/post'
import { areaLabel, sceneEmoji, sceneGradient } from '@/utils/scene'
import type { MatchPost, PostComment, PostMember, ReceivedApplicationItem } from '@/types/api'
import {
  buildPostShareConfig,
  DEFAULT_SHARE_IMAGE,
  type ShareViewerState,
} from '@/utils/post-share'
import { buildSharePosterOrDefault } from '@/utils/share-poster'

const pageProxy = getCurrentInstance()?.proxy ?? null

const user = useUserStore()
const postId = ref('')
const post = ref<MatchPost | null>(null)
const members = ref<PostMember[]>([])
const hasApplied = ref(false)
const applicationStatus = ref<string | undefined>()
const loading = ref(true)
const applying = ref(false)
const comments = ref<PostComment[]>([])
const hostApplications = ref<ReceivedApplicationItem[]>([])
const hostPendingCount = ref(0)
const actingAppId = ref('')
const sharePosterUrl = ref('')
const shareRefreshing = ref(false)

const DETAIL_SHARE_CANVAS = 'postShareCanvas'

const shareViewer = computed<ShareViewerState>(() => ({
  hasApplied: hasApplied.value,
  applicationStatus: applicationStatus.value,
}))

const limit = computed(() => (post.value ? memberLimit(post.value) : 0))
const full = computed(() => (post.value ? isPostFull(post.value) : false))
const isHost = computed(
  () =>
    !!post.value?.hostUserId &&
    !!user.session?.userId &&
    post.value.hostUserId === user.session.userId,
)

const statusLabel = computed(() => {
  if (full.value) return '已满员'
  if (applicationStatus.value === 'approved') return '已通过'
  if (hasApplied.value || applicationStatus.value === 'pending') return '已申请'
  return '组队中'
})

const canApply = computed(
  () =>
    !!post.value &&
    !full.value &&
    !hasApplied.value &&
    applicationStatus.value !== 'approved' &&
    !isHost.value &&
    !user.isGuest,
)

const progressPct = computed(() => {
  if (!post.value || limit.value <= 0) return 0
  return Math.min(100, Math.round((post.value.currentMembers / limit.value) * 100))
})

const sceneLabel = computed(() =>
  post.value ? areaLabel(post.value.area) : '',
)

const costText = computed(() =>
  post.value ? formatCostLabel(post.value) : '',
)

const applyBtnLabel = computed(() => {
  if (isHost.value) return '我发布的组局'
  if (user.isGuest) return '登录后申请'
  if (full.value) return '已满员'
  if (applicationStatus.value === 'approved') return '已通过'
  if (hasApplied.value) return '已申请'
  return '申请加入'
})

const tags = computed(() => post.value?.hostFaceTraits ?? [])

const showDescription = computed(() => {
  const p = post.value
  if (!p?.description?.trim()) return false
  const t = p.title.trim()
  const d = p.description.trim()
  return d !== t && !t.includes(d) && !d.includes(t)
})

const activeLabel = computed(() =>
  post.value ? formatRelativeTime(post.value.lastActiveTime) : '',
)

async function updateSharePoster() {
  if (!post.value) return
  sharePosterUrl.value = await buildSharePosterOrDefault(
    post.value,
    DETAIL_SHARE_CANVAS,
    shareViewer.value,
    pageProxy,
  )
}

async function loadDetail() {
  if (!postId.value) return
  loading.value = true
  try {
    const p = await getPost(postId.value)
    if (!p) {
      uni.showToast({ title: '帖子不存在', icon: 'none' })
      setTimeout(() => uni.navigateBack(), 800)
      return
    }
    post.value = p
    hasApplied.value = Boolean(p.hasApplied)
    applicationStatus.value = p.applicationStatus

    const memberList = await getPostMembers(postId.value)
    members.value = memberList

    if (!user.isGuest && user.token) {
      const app = await getMyPostApplication(postId.value)
      hasApplied.value = app.hasApplied || hasApplied.value
      applicationStatus.value = app.status || applicationStatus.value
    }

    if (isHost.value && user.token) {
      const received = await listPostReceivedApplications(postId.value)
      hostApplications.value = received.items
      hostPendingCount.value = received.pendingCount
    } else {
      hostApplications.value = []
      hostPendingCount.value = 0
    }

    comments.value = await listPostComments(postId.value)
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '加载失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    loading.value = false
    uni.stopPullDownRefresh()
  }
}

async function onShareTap() {
  if (!postId.value || shareRefreshing.value) return
  shareRefreshing.value = true
  try {
    const p = await getPost(postId.value)
    if (p) {
      post.value = p
      if (!user.isGuest && user.token) {
        const app = await getMyPostApplication(postId.value)
        hasApplied.value = app.hasApplied || hasApplied.value
        applicationStatus.value = app.status || applicationStatus.value
      }
      await updateSharePoster()
    }
  } catch {
    uni.showToast({ title: '刷新分享信息失败', icon: 'none' })
  } finally {
    shareRefreshing.value = false
  }
}

function shareMessage() {
  const p = post.value
  if (!p) {
    return {
      title: 'MATCHit · 发现组局搭子',
      path: '/pages/feed/index',
      imageUrl: sharePosterUrl.value,
    }
  }
  return buildPostShareConfig(
    p,
    sharePosterUrl.value || DEFAULT_SHARE_IMAGE,
    shareViewer.value,
  )
}

onShareAppMessage(() => shareMessage())
onShareTimeline(() => shareMessage())

onLoad((query) => {
  postId.value = (query?.id as string) || ''
  // #ifdef MP-WEIXIN
  uni.showShareMenu({
    withShareTicket: true,
    menus: ['shareAppMessage', 'shareTimeline'],
  })
  // #endif
  loadDetail()
})

onShow(() => {
  if (postId.value && post.value && !loading.value) {
    if (!user.isGuest && user.token) {
      getMyPostApplication(postId.value).then((app) => {
        hasApplied.value = app.hasApplied || hasApplied.value
        applicationStatus.value = app.status || applicationStatus.value
      })
    }
  }
})

onPullDownRefresh(loadDetail)

function onApplyTap() {
  if (user.isGuest) {
    uni.showModal({
      title: '需要登录',
      content: '申请组局须先绑定手机号登录，游客无法提交申请。',
      confirmText: '去登录',
      success: (res) => {
        if (res.confirm) user.requireRegistered()
      },
    })
    return
  }
  if (!canApply.value || !post.value) return
  uni.showModal({
    title: '微信昵称或微信号',
    editable: true,
    placeholderText: '必填，主理人对账用',
    content: '',
    success: (res) => {
      if (!res.confirm) return
      const wechat = res.content?.trim()
      if (!wechat) {
        uni.showToast({ title: '请填写微信信息', icon: 'none' })
        return
      }
      submitApply(wechat)
    },
  })
}

async function submitApply(wechatContact: string) {
  if (!post.value) return
  applying.value = true
  try {
    await applyToPost(post.value.id, wechatContact)
    hasApplied.value = true
    applicationStatus.value = 'pending'
    uni.showModal({
      title: '申请已发送',
      content: '等待主理人确认，可在「消息」查看进度。',
      showCancel: false,
    })
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '申请失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    applying.value = false
  }
}

function applicantName(item: ReceivedApplicationItem): string {
  return item.applicantUsername?.trim() || '用户'
}

async function onHostApprove(item: ReceivedApplicationItem) {
  if (item.status !== 'pending' || actingAppId.value) return
  actingAppId.value = item.id
  try {
    await approveApplication(item.id)
    uni.showToast({ title: `已通过 ${applicantName(item)}`, icon: 'none' })
    await loadDetail()
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '操作失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    actingAppId.value = ''
  }
}

async function onHostCancel(item: ReceivedApplicationItem) {
  if (item.status !== 'approved' || actingAppId.value) return
  uni.showModal({
    title: '取消资格',
    content: `确认取消 ${applicantName(item)} 的加入资格？（如未收到转账）`,
    success: async (res) => {
      if (!res.confirm) return
      actingAppId.value = item.id
      try {
        await cancelApplication(item.id)
        uni.showToast({ title: '已取消该申请', icon: 'none' })
        await loadDetail()
      } catch (e) {
        const msg = e instanceof ApiError ? e.message : '操作失败'
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        actingAppId.value = ''
      }
    },
  })
}

async function onHostReject(item: ReceivedApplicationItem) {
  if (item.status !== 'pending' || actingAppId.value) return
  uni.showModal({
    title: '拒绝申请',
    content: `确定拒绝 ${applicantName(item)} 的加入申请？`,
    success: async (res) => {
      if (!res.confirm) return
      actingAppId.value = item.id
      try {
        await rejectApplication(item.id)
        uni.showToast({ title: `已拒绝 ${applicantName(item)}`, icon: 'none' })
        await loadDetail()
      } catch (e) {
        const msg = e instanceof ApiError ? e.message : '操作失败'
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        actingAppId.value = ''
      }
    },
  })
}
</script>

<template>
  <view class="page">
    <view v-if="loading" class="center">
      <text class="muted">加载中…</text>
    </view>

    <view v-else-if="post" class="content">
      <view class="cover" :style="{ background: sceneGradient(post.area) }">
        <text class="cover-hero-emoji">{{ sceneEmoji(post.area) }}</text>
        <view class="cover-badges">
          <text v-if="post.isPinned" class="cover-label pin">置顶</text>
          <text v-if="sceneLabel" class="cover-label">{{ sceneLabel }}</text>
          <text v-if="post.tab" class="cover-label tab">{{ post.tab }}</text>
        </view>
      </view>

      <text class="title">{{ post.title }}</text>
      <text v-if="showDescription" class="desc">{{ post.description }}</text>

      <view v-if="tags.length" class="tag-row">
        <text v-for="(tag, i) in tags" :key="i" class="tag-chip">{{ tag }}</text>
      </view>

      <view class="info-card">
        <view v-if="costText" class="meta-row">
          <text class="meta-label">费用</text>
          <text class="meta-value highlight">{{ costText }}</text>
        </view>
        <view v-if="sceneLabel" class="meta-row">
          <text class="meta-label">场景</text>
          <text class="meta-value">{{ sceneLabel }}</text>
        </view>
        <view class="meta-row">
          <text class="meta-label">人数</text>
          <text class="meta-value">最多 {{ limit }} 人 · 已 {{ post.currentMembers }} 人</text>
        </view>
        <view v-if="post.eventLocation" class="meta-row">
          <text class="meta-label">地点</text>
          <text class="meta-value">{{ post.eventLocation }}</text>
        </view>
        <view class="meta-row">
          <text class="meta-label">时间</text>
          <text class="meta-value">{{ formatEventTime(post.eventDateTime) }}</text>
        </view>
        <view class="meta-row">
          <text class="meta-label">主理人</text>
          <text class="meta-value">
            {{ post.hostNickname }}
            <text v-if="post.hostCreditScore" class="credit">
              · 信用 {{ post.hostCreditScore }}
            </text>
          </text>
        </view>
        <view v-if="activeLabel || post.interactionCount" class="meta-row meta-sub">
          <text v-if="activeLabel" class="sub-item">{{ activeLabel }}</text>
          <text v-if="post.interactionCount" class="sub-item">
            {{ post.interactionCount }} 次互动
          </text>
        </view>
      </view>

      <view class="section">
        <view class="section-head">
          <text class="section-title">组队进度</text>
          <text class="section-sub">{{ post.currentMembers }}/{{ limit }} 人</text>
        </view>
        <view class="progress-track">
          <view class="progress-fill" :style="{ width: progressPct + '%' }" />
        </view>
        <view class="status-pill">
          <view class="status-dot" :class="{ full, applied: hasApplied }" />
          <text class="status-text">{{ statusLabel }}</text>
        </view>
      </view>

      <post-host-apps
        v-if="isHost"
        :applications="hostApplications"
        :pending-count="hostPendingCount"
        :acting-app-id="actingAppId"
        @approve="onHostApprove"
        @reject="onHostReject"
        @cancel="onHostCancel"
      />

      <view v-if="members.length > 0" class="section">
        <text class="section-title">已加入</text>
        <view class="member-row">
          <view v-for="(m, i) in members" :key="m.userId || i" class="member-chip">
            <text class="member-avatar">{{ (m.username || '用').slice(0, 1) }}</text>
            <text class="member-name">{{ m.username }}</text>
            <text v-if="m.role === 'host'" class="member-tag">主理</text>
          </view>
        </view>
      </view>

      <post-comments
        :post-id="postId"
        :comments="comments"
        @refresh="loadDetail"
      />

      <view class="footer">
        <button
          class="share-btn"
          open-type="share"
          :loading="shareRefreshing"
          :disabled="shareRefreshing"
          @tap="onShareTap"
        >
          <view class="share-icon" />
          <text class="share-label">分享</text>
        </button>
        <button
          class="apply-btn"
          :class="{ disabled: !canApply && !user.isGuest }"
          :loading="applying"
          :disabled="applying || (!canApply && !user.isGuest && !isHost)"
          @tap="onApplyTap"
        >
          {{ applyBtnLabel }}
        </button>
      </view>
    </view>

    <canvas
      canvas-id="postShareCanvas"
      class="share-canvas"
      :style="{ width: '500px', height: '400px' }"
    />
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  background: #f2f2f7;
  padding-bottom: 220rpx;
  box-sizing: border-box;
}
.center {
  padding: 200rpx 0;
  text-align: center;
}
.muted {
  color: #999;
  font-size: 28rpx;
}
.content {
  padding: 24rpx 32rpx;
}
.cover {
  height: 320rpx;
  border-radius: 24rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  padding: 24rpx;
  margin-bottom: 28rpx;
  position: relative;
}
.cover-hero-emoji {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -58%);
  font-size: 96rpx;
  line-height: 1;
  opacity: 0.92;
}
.cover-badges {
  position: relative;
  z-index: 1;
  width: 100%;
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}
.cover-label {
  background: rgba(0, 47, 167, 0.12);
  color: #002fa7;
  font-size: 24rpx;
  padding: 8rpx 20rpx;
  border-radius: 999rpx;
}
.cover-label.pin {
  background: rgba(230, 126, 0, 0.15);
  color: #c76a00;
}
.cover-label.tab {
  background: rgba(255, 255, 255, 0.85);
}
.tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-bottom: 24rpx;
}
.tag-chip {
  font-size: 24rpx;
  color: #555;
  background: #fff;
  border: 1rpx solid #e8e8e8;
  padding: 8rpx 20rpx;
  border-radius: 999rpx;
}
.info-card {
  background: #fff;
  border-radius: 20rpx;
  padding: 24rpx;
  margin-bottom: 8rpx;
}
.meta-value.highlight {
  color: #002fa7;
  font-weight: 700;
}
.credit {
  color: #666;
  font-weight: 400;
}
.meta-sub {
  margin-top: 8rpx;
  margin-bottom: 0;
  gap: 20rpx;
}
.sub-item {
  font-size: 24rpx;
  color: #999;
  margin-right: 20rpx;
}
.title {
  display: block;
  font-size: 40rpx;
  font-weight: 800;
  color: #111;
  line-height: 1.35;
  margin-bottom: 20rpx;
}
.desc {
  display: block;
  font-size: 30rpx;
  color: #333;
  line-height: 1.65;
  margin-bottom: 28rpx;
}
.meta-row {
  display: flex;
  margin-bottom: 16rpx;
  font-size: 28rpx;
}
.meta-label {
  width: 100rpx;
  color: #999;
  flex-shrink: 0;
}
.meta-value {
  flex: 1;
  color: #333;
}
.section {
  background: #fff;
  border-radius: 20rpx;
  padding: 24rpx;
  margin-top: 24rpx;
}
.section-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16rpx;
}
.section-title {
  font-size: 30rpx;
  font-weight: 700;
  color: #111;
}
.section-sub {
  font-size: 26rpx;
  color: #666;
}
.progress-track {
  height: 16rpx;
  background: #eee;
  border-radius: 8rpx;
  overflow: hidden;
}
.progress-fill {
  height: 100%;
  background: #002fa7;
  border-radius: 8rpx;
}
.status-pill {
  display: flex;
  align-items: center;
  margin-top: 20rpx;
}
.status-dot {
  width: 16rpx;
  height: 16rpx;
  border-radius: 50%;
  background: #002fa7;
  margin-right: 12rpx;
}
.status-dot.full {
  background: #999;
}
.status-dot.applied {
  background: #e67e00;
}
.status-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #333;
}
.member-row {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
  margin-top: 16rpx;
}
.member-chip {
  display: flex;
  align-items: center;
  background: #f5f5f5;
  border-radius: 999rpx;
  padding: 8rpx 20rpx 8rpx 8rpx;
}
.member-avatar {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background: #e6f0ff;
  color: #002fa7;
  font-size: 24rpx;
  font-weight: 700;
  text-align: center;
  line-height: 48rpx;
  margin-right: 10rpx;
}
.member-name {
  font-size: 26rpx;
  color: #333;
}
.member-tag {
  margin-left: 8rpx;
  font-size: 22rpx;
  color: #002fa7;
}
.footer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 20rpx 32rpx calc(20rpx + env(safe-area-inset-bottom));
  background: #fff;
  box-shadow: 0 -4rpx 24rpx rgba(0, 0, 0, 0.06);
  display: flex;
  gap: 20rpx;
  align-items: center;
}
.share-btn {
  flex: 0 0 200rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  background: #fff;
  color: #002fa7;
  border: 2rpx solid #002fa7;
  border-radius: 48rpx;
  font-size: 28rpx;
  font-weight: 600;
  margin: 0;
  padding: 0 20rpx;
}
.share-btn::after {
  border: none;
}
.share-icon {
  width: 32rpx;
  height: 32rpx;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23002FA7' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8'/%3E%3Cpolyline points='16 6 12 2 8 6'/%3E%3Cline x1='12' y1='2' x2='12' y2='15'/%3E%3C/svg%3E");
  background-size: contain;
  background-repeat: no-repeat;
}
.share-label {
  color: #002fa7;
}
.apply-btn {
  flex: 1;
  background: #002fa7;
  color: #fff;
  border-radius: 48rpx;
  font-size: 32rpx;
  font-weight: 700;
  margin: 0;
}
.share-canvas {
  position: fixed;
  left: -9999px;
  top: 0;
  pointer-events: none;
}
.apply-btn.disabled {
  background: #c8c8c8;
  color: #fff;
}
.app-card {
  padding: 20rpx 0;
  border-bottom: 1rpx solid #f0f0f0;
}
.app-card:last-child {
  border-bottom: none;
}
.app-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.app-name {
  font-size: 30rpx;
  font-weight: 700;
  color: #111;
}
.app-status {
  font-size: 22rpx;
  font-weight: 600;
  color: #666;
}
.app-status.approved {
  color: #2e7d32;
}
.app-status.rejected {
  color: #c62828;
}
.app-wechat {
  display: block;
  font-size: 26rpx;
  color: #002fa7;
  font-weight: 600;
  margin-top: 8rpx;
}
.app-phone {
  display: block;
  font-size: 24rpx;
  color: #999;
  margin-top: 6rpx;
}
.empty-hint {
  display: block;
  font-size: 26rpx;
  color: #888;
  line-height: 1.55;
  margin-top: 12rpx;
}
.btn-cancel {
  width: 100%;
  background: #fff;
  color: #c62828;
  border: 1rpx solid #e57373;
  border-radius: 40rpx;
}
.app-msg {
  display: block;
  font-size: 26rpx;
  color: #555;
  margin-top: 8rpx;
}
.app-actions {
  display: flex;
  gap: 16rpx;
  margin-top: 16rpx;
}
.app-actions .btn-reject {
  flex: 1;
  background: #fff;
  color: #666;
  border: 1rpx solid #ddd;
  border-radius: 40rpx;
}
.app-actions .btn-approve {
  flex: 2;
  background: #002fa7;
  color: #fff;
  border-radius: 40rpx;
}
</style>
