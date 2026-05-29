<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow, onPullDownRefresh } from '@dcloudio/uni-app'
import {
  approveApplication,
  cancelApplication,
  listReceivedApplications,
  rejectApplication,
} from '@/api/posts'
import {
  listCommentNotifications,
  markCommentNotificationRead,
} from '@/api/comments'
import { useUserStore } from '@/stores/user'
import { ApiError } from '@/utils/request'
import { areaLabel } from '@/utils/scene'
import { formatRelativeTime } from '@/utils/post'
import type { CommentNotification, ReceivedApplicationItem } from '@/types/api'

const user = useUserStore()
const pageTab = ref<'applications' | 'comments'>('applications')
const pendingCount = ref(0)
const items = ref<ReceivedApplicationItem[]>([])
const commentItems = ref<CommentNotification[]>([])
const commentUnread = ref(0)
const loading = ref(false)
const loadError = ref('')
const actingId = ref('')
const listFilter = ref<'pending' | 'all'>('pending')

const displayedItems = computed(() => {
  if (listFilter.value === 'all') return items.value
  return items.value.filter((i) => i.status === 'pending')
})

function statusLabel(status: string): string {
  switch (status) {
    case 'approved':
      return '已通过'
    case 'rejected':
      return '已拒绝'
    case 'cancelled':
      return '已取消'
    default:
      return '待确认'
  }
}

function displayName(item: ReceivedApplicationItem): string {
  const n = item.applicantUsername?.trim()
  return n || '用户'
}

async function loadApplications() {
  const res = await listReceivedApplications()
  items.value = res.items
  pendingCount.value = res.pendingCount
}

async function loadComments() {
  const res = await listCommentNotifications()
  commentItems.value = res.items
  commentUnread.value = res.unreadCount
}

async function load() {
  if (!user.token) return
  loading.value = true
  loadError.value = ''
  try {
    await Promise.all([loadApplications(), loadComments()])
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '加载失败'
    loadError.value = msg
    uni.showToast({ title: msg.slice(0, 36), icon: 'none' })
  } finally {
    loading.value = false
    uni.stopPullDownRefresh()
  }
}

onShow(load)
onPullDownRefresh(load)

function goLogin() {
  uni.navigateTo({ url: '/pages/login/index' })
}

function openPost(item: ReceivedApplicationItem) {
  uni.navigateTo({
    url: `/pages/post/detail?id=${encodeURIComponent(item.postId)}`,
  })
}

async function openCommentNotice(item: CommentNotification) {
  if (!item.isRead) {
    try {
      await markCommentNotificationRead(item.id)
      item.isRead = true
      commentUnread.value = Math.max(0, commentUnread.value - 1)
    } catch {
      /* ignore */
    }
  }
  uni.navigateTo({
    url: `/pages/post/detail?id=${encodeURIComponent(item.postId)}`,
  })
}

function commentTitle(item: CommentNotification): string {
  if (item.kind === 'comment_reply') {
    return `${item.actorUsername} 回复了你的评论`
  }
  return `${item.actorUsername} 评论了你的组局`
}

async function onApprove(item: ReceivedApplicationItem) {
  if (item.status !== 'pending' || actingId.value) return
  actingId.value = item.id
  try {
    await approveApplication(item.id)
    uni.showToast({
      title: `已通过 ${displayName(item)}`,
      icon: 'none',
    })
    await load()
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '操作失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    actingId.value = ''
  }
}

async function onCancel(item: ReceivedApplicationItem) {
  if (item.status !== 'approved' || actingId.value) return
  uni.showModal({
    title: '取消资格',
    content: `确认取消 ${displayName(item)} 的加入资格？（如未收到转账）`,
    success: async (res) => {
      if (!res.confirm) return
      actingId.value = item.id
      try {
        await cancelApplication(item.id)
        uni.showToast({ title: '已取消', icon: 'none' })
        await load()
      } catch (e) {
        const msg = e instanceof ApiError ? e.message : '操作失败'
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        actingId.value = ''
      }
    },
  })
}

async function onReject(item: ReceivedApplicationItem) {
  if (item.status !== 'pending' || actingId.value) return
  uni.showModal({
    title: '拒绝申请',
    content: `确定拒绝 ${displayName(item)} 的加入申请？`,
    success: async (res) => {
      if (!res.confirm) return
      actingId.value = item.id
      try {
        await rejectApplication(item.id)
        uni.showToast({
          title: `已拒绝 ${displayName(item)}`,
          icon: 'none',
        })
        await load()
      } catch (e) {
        const msg = e instanceof ApiError ? e.message : '操作失败'
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        actingId.value = ''
      }
    },
  })
}
</script>

<template>
  <view class="page">
    <view class="main-tabs">
      <text
        class="main-tab"
        :class="{ active: pageTab === 'applications' }"
        @tap="pageTab = 'applications'"
      >
        申请{{ pendingCount > 0 ? ` (${pendingCount})` : '' }}
      </text>
      <text
        class="main-tab"
        :class="{ active: pageTab === 'comments' }"
        @tap="pageTab = 'comments'"
      >
        评论{{ commentUnread > 0 ? ` (${commentUnread})` : '' }}
      </text>
    </view>

    <view v-if="loading && items.length === 0 && commentItems.length === 0" class="center">
      <text class="muted">加载中…</text>
    </view>

    <view v-else-if="loadError && items.length === 0 && commentItems.length === 0" class="center">
      <text class="muted">{{ loadError }}</text>
      <button class="btn outline" size="mini" @tap="load">重试</button>
    </view>

    <view v-else-if="pageTab === 'comments'" class="list">
      <view v-if="commentItems.length === 0" class="center inner">
        <text class="muted">暂无评论通知</text>
        <text class="hint">有人评论或回复你的组局时会显示在这里</text>
      </view>
      <view
        v-for="item in commentItems"
        :key="item.id"
        class="card comment-card"
        :class="{ unread: !item.isRead }"
        @tap="openCommentNotice(item)"
      >
        <view class="card-main full">
          <text class="name">{{ commentTitle(item) }}</text>
          <text class="post-line">{{ item.postTitle }}</text>
          <text class="msg">「{{ item.commentBody }}」</text>
          <text class="area">{{ formatRelativeTime(item.createdAt) }}</text>
        </view>
        <view v-if="!item.isRead" class="dot" />
      </view>
    </view>

    <view v-else-if="items.length === 0" class="center">
      <text class="muted">暂无收到的申请</text>
      <text class="hint">发布组局后，申请者须登录并填写微信昵称/号，申请会显示在这里</text>
      <text class="hint warn">
        请用发布组局的同一账号查看；换设备或退出后请用手机号重新登录
      </text>
    </view>

    <view v-else class="list">
      <view class="tabs">
        <text
          class="tab"
          :class="{ active: listFilter === 'pending' }"
          @tap="listFilter = 'pending'"
        >
          待处理{{ pendingCount > 0 ? ` (${pendingCount})` : '' }}
        </text>
        <text
          class="tab"
          :class="{ active: listFilter === 'all' }"
          @tap="listFilter = 'all'"
        >
          全部
        </text>
      </view>

      <view v-if="pendingCount > 0 && listFilter === 'pending'" class="banner">
        待处理 {{ pendingCount }} 条
      </view>

      <view v-if="displayedItems.length === 0" class="center inner">
        <text class="muted">暂无待处理申请</text>
        <text class="hint">切换到「全部」可查看已通过/已拒绝记录</text>
      </view>

      <view
        v-for="item in displayedItems"
        :key="item.id"
        class="card"
        @tap="openPost(item)"
      >
        <view class="card-head">
          <view class="avatar">{{ displayName(item).slice(0, 1) }}</view>
          <view class="card-main">
            <text class="name">{{ displayName(item) }}</text>
            <text v-if="item.wechatContact" class="wechat">
              微信：{{ item.wechatContact }}
            </text>
            <text v-if="item.applicantPhoneMasked" class="phone">
              {{ item.applicantPhoneMasked }}
            </text>
            <text class="post-line">申请加入 · {{ item.postTitle }}</text>
            <text class="area">{{ areaLabel(item.postArea) }}</text>
            <text v-if="item.message" class="msg">「{{ item.message }}」</text>
          </view>
          <view
            v-if="item.status !== 'pending'"
            class="status-badge"
            :class="item.status"
          >
            {{ statusLabel(item.status) }}
          </view>
        </view>

        <view v-if="item.status === 'pending'" class="actions" @tap.stop>
          <button
            class="btn-reject"
            size="mini"
            :disabled="!!actingId"
            @tap="onReject(item)"
          >
            拒绝
          </button>
          <button
            class="btn-approve"
            size="mini"
            :loading="actingId === item.id"
            :disabled="!!actingId && actingId !== item.id"
            @tap="onApprove(item)"
          >
            同意
          </button>
        </view>
        <view v-else-if="item.status === 'approved'" class="actions" @tap.stop>
          <button
            class="btn-cancel"
            size="mini"
            :disabled="!!actingId"
            @tap="onCancel(item)"
          >
            取消资格（未付款）
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  padding: 24rpx;
  padding-bottom: 48rpx;
  box-sizing: border-box;
  background: #f2f2f7;
}
.guest,
.center {
  padding: 120rpx 32rpx;
  text-align: center;
}
.center.inner {
  padding: 48rpx 16rpx;
}
.guest-title {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #333;
  margin-bottom: 12rpx;
}
.guest-sub,
.hint {
  display: block;
  font-size: 26rpx;
  color: #999;
  margin-top: 12rpx;
}
.hint.warn {
  color: #c76a00;
  margin-top: 20rpx;
  line-height: 1.5;
}
.btn {
  margin-top: 32rpx;
  background: #002fa7;
  color: #fff;
  font-size: 28rpx;
}
.btn.outline {
  background: #fff;
  color: #002fa7;
  border: 1rpx solid #002fa7;
}
.muted {
  color: #999;
  font-size: 28rpx;
}
.main-tabs {
  display: flex;
  gap: 16rpx;
  margin-bottom: 24rpx;
}
.main-tab {
  flex: 1;
  text-align: center;
  padding: 18rpx;
  border-radius: 16rpx;
  font-size: 28rpx;
  color: #666;
  background: #fff;
  font-weight: 600;
}
.main-tab.active {
  background: #002fa7;
  color: #fff;
}
.card.unread {
  border-left: 6rpx solid #002fa7;
}
.comment-card {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}
.card-main.full {
  flex: 1;
  margin-left: 0;
}
.dot {
  width: 16rpx;
  height: 16rpx;
  border-radius: 50%;
  background: #ff3b30;
  flex-shrink: 0;
  margin-left: 12rpx;
  margin-top: 8rpx;
}
.tabs {
  display: flex;
  gap: 16rpx;
  margin-bottom: 24rpx;
}
.tab {
  flex: 1;
  text-align: center;
  padding: 16rpx;
  border-radius: 16rpx;
  font-size: 28rpx;
  color: #666;
  background: #fff;
}
.tab.active {
  background: #002fa7;
  color: #fff;
  font-weight: 700;
}
.wechat {
  display: block;
  font-size: 26rpx;
  color: #002fa7;
  font-weight: 600;
  margin-top: 6rpx;
}
.btn-cancel {
  width: 100%;
  background: #fff;
  color: #c62828;
  border: 1rpx solid #e57373;
  border-radius: 40rpx;
}
.banner {
  background: #e6f0ff;
  color: #002fa7;
  padding: 16rpx 24rpx;
  border-radius: 16rpx;
  margin-bottom: 24rpx;
  font-size: 26rpx;
  font-weight: 600;
}
.card {
  background: #fff;
  padding: 28rpx;
  border-radius: 24rpx;
  margin-bottom: 20rpx;
}
.card-head {
  display: flex;
  align-items: flex-start;
}
.avatar {
  width: 80rpx;
  height: 80rpx;
  border-radius: 50%;
  background: #e6f0ff;
  color: #002fa7;
  font-size: 36rpx;
  font-weight: 800;
  text-align: center;
  line-height: 80rpx;
  flex-shrink: 0;
}
.card-main {
  flex: 1;
  margin-left: 20rpx;
  min-width: 0;
}
.name {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #111;
}
.phone {
  display: block;
  font-size: 24rpx;
  color: #999;
  margin-top: 4rpx;
}
.post-line {
  display: block;
  font-size: 26rpx;
  color: #555;
  margin-top: 8rpx;
  line-height: 1.4;
}
.area {
  display: block;
  font-size: 22rpx;
  color: #aaa;
  margin-top: 4rpx;
}
.msg {
  display: block;
  font-size: 24rpx;
  color: #666;
  margin-top: 8rpx;
  font-style: italic;
}
.status-badge {
  font-size: 22rpx;
  font-weight: 600;
  padding: 6rpx 16rpx;
  border-radius: 12rpx;
  flex-shrink: 0;
}
.status-badge.approved {
  background: #e8f5e9;
  color: #2e7d32;
}
.status-badge.rejected {
  background: #ffebee;
  color: #c62828;
}
.actions {
  display: flex;
  gap: 20rpx;
  margin-top: 24rpx;
}
.btn-reject {
  flex: 1;
  background: #fff;
  color: #666;
  border: 1rpx solid #ddd;
  border-radius: 40rpx;
}
.btn-approve {
  flex: 2;
  background: #002fa7;
  color: #fff;
  border-radius: 40rpx;
}
</style>
