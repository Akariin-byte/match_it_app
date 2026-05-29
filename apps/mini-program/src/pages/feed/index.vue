<script setup lang="ts">
import { ref } from 'vue'
import {
  onPullDownRefresh,
  onShareAppMessage,
  onShareTimeline,
  onShow,
} from '@dcloudio/uni-app'
import { listPosts } from '@/api/posts'
import { useUserStore } from '@/stores/user'
import { ApiError } from '@/utils/request'
import type { MatchPost } from '@/types/api'

const user = useUserStore()
const posts = ref<MatchPost[]>([])
const loading = ref(false)

async function loadFeed() {
  if (!user.token) return
  loading.value = true
  try {
    posts.value = await listPosts()
  } catch (e) {
    const msg =
      e instanceof ApiError ? e.message : e instanceof Error ? e.message : '加载失败'
    console.error('loadFeed failed', e)
    uni.showToast({ title: msg.slice(0, 40) || '加载失败', icon: 'none' })
  } finally {
    loading.value = false
    uni.stopPullDownRefresh()
  }
}

onShow(() => {
  // #ifdef MP-WEIXIN
  uni.showShareMenu({
    withShareTicket: true,
    menus: ['shareAppMessage', 'shareTimeline'],
  })
  // #endif
  if (user.ready && user.token) loadFeed()
})

async function retryLogin() {
  await user.bootstrap()
  if (user.token) loadFeed()
}

onPullDownRefresh(loadFeed)

function goPublish() {
  if (!user.requireRegistered()) return
  uni.navigateTo({ url: '/pages/publish/index' })
}

function openPost(post: MatchPost) {
  uni.navigateTo({ url: `/pages/post/detail?id=${encodeURIComponent(post.id)}` })
}

function feedShareMessage() {
  return {
    title: 'MATCHit · 发现附近的组局搭子',
    path: '/pages/feed/index',
  }
}

onShareAppMessage(() => feedShareMessage())
onShareTimeline(() => feedShareMessage())
</script>

<template>
  <view class="page">
    <view class="header">
      <text class="greeting">嘿，{{ user.displayName }}，发现附近的组局搭子</text>
      <text v-if="posts.length > 0" class="feed-count">共 {{ posts.length }} 条组局 · 下拉刷新</text>
    </view>

    <view v-if="user.bootstrapError" class="center error-box">
      <text class="muted">{{ user.bootstrapError }}</text>
      <button class="retry-btn" size="mini" @tap="retryLogin">重试连接</button>
    </view>

    <view v-else-if="loading && posts.length === 0" class="center">
      <text class="muted">加载中…</text>
    </view>

    <view v-else-if="posts.length === 0" class="center">
      <text class="muted">暂无组局，先来发布一条吧</text>
    </view>

    <view v-else class="grid">
      <view
        v-for="item in posts"
        :key="item.id"
        class="grid-item"
        @tap="openPost(item)"
      >
        <post-card :post="item" />
      </view>
    </view>

    <view class="fab" @tap="goPublish">
      <view class="fab-plus" />
    </view>
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  padding: 24rpx 24rpx 160rpx;
  box-sizing: border-box;
  background: #f2f2f7;
}
.header {
  margin-bottom: 24rpx;
}
.greeting {
  font-size: 36rpx;
  font-weight: 700;
  color: #111;
  line-height: 1.4;
}
.feed-count {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #999;
}
.grid {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
}
.grid-item {
  width: 48%;
  margin-bottom: 20rpx;
}
.center {
  padding: 120rpx 0;
  text-align: center;
}
.error-box {
  padding: 80rpx 32rpx;
}
.error-box .muted {
  display: block;
  margin-bottom: 32rpx;
  line-height: 1.5;
}
.retry-btn {
  margin-top: 16rpx;
}
.muted {
  color: #999;
  font-size: 28rpx;
}
.fab {
  position: fixed;
  right: 40rpx;
  bottom: 120rpx;
  width: 104rpx;
  height: 104rpx;
  border-radius: 28rpx;
  background: linear-gradient(135deg, #0038c7, #002fa7);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(0, 47, 167, 0.35);
  z-index: 10;
}
.fab-plus {
  width: 40rpx;
  height: 40rpx;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2.5' stroke-linecap='round'%3E%3Cline x1='12' y1='5' x2='12' y2='19'/%3E%3Cline x1='5' y1='12' x2='19' y2='12'/%3E%3C/svg%3E");
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
}
</style>
