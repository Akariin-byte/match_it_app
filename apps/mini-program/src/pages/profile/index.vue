<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { listMyPosts } from '@/api/posts'
import { useUserStore } from '@/stores/user'
import { areaLabel, sceneEmoji } from '@/utils/scene'
import { formatEventTime, memberLimit } from '@/utils/post'
import type { MatchPost } from '@/types/api'

const user = useUserStore()
const publishedCount = ref(0)
const myPosts = ref<MatchPost[]>([])
const loggingOut = ref(false)

const sortedPosts = computed(() =>
  [...myPosts.value].sort((a, b) => {
    const ta = Date.parse(a.createdAt || '') || 0
    const tb = Date.parse(b.createdAt || '') || 0
    return tb - ta
  }),
)

async function loadPublished() {
  if (user.isGuest) {
    publishedCount.value = 0
    myPosts.value = []
    return
  }
  try {
    const posts = await listMyPosts()
    myPosts.value = posts
    publishedCount.value = posts.length
  } catch {
    publishedCount.value = 0
    myPosts.value = []
  }
}

onShow(loadPublished)

function goLogin() {
  uni.navigateTo({ url: '/pages/login/index' })
}

function goPublish() {
  if (!user.requireRegistered()) return
  uni.navigateTo({ url: '/pages/publish/index' })
}

function openPost(post: MatchPost) {
  uni.navigateTo({ url: `/pages/post/detail?id=${encodeURIComponent(post.id)}` })
}

function formatCreated(post: MatchPost) {
  if (post.createdAt) return formatEventTime(post.createdAt)
  if (post.lastActiveTime) return formatEventTime(post.lastActiveTime)
  return ''
}

function onLogout() {
  if (user.isGuest) return
  uni.showModal({
    title: '退出登录',
    content: '退出后将回到游客模式，可重新绑定手机号登录。',
    confirmColor: '#c62828',
    success(res) {
      if (!res.confirm) return
      loggingOut.value = true
      user.logout().finally(() => {
        loggingOut.value = false
        loadPublished()
      })
    },
  })
}
</script>

<template>
  <view class="page">
    <view class="profile">
      <view class="avatar">{{ user.displayName.slice(0, 1) }}</view>
      <view class="info">
        <text class="name">{{ user.displayName }}</text>
        <text v-if="user.isGuest" class="sub">登录后发布与申请组局</text>
        <text v-else class="sub">已发布 {{ publishedCount }} 条组局</text>
      </view>
    </view>

    <view class="actions">
      <button v-if="user.isGuest" class="btn primary" @tap="goLogin">
        登录 / 注册
      </button>
      <button v-else class="btn primary" @tap="goPublish">发布组局</button>
    </view>

    <view v-if="!user.isGuest" class="my-section">
      <text class="section-title">我组的局</text>
      <view v-if="sortedPosts.length === 0" class="empty">
        <text class="empty-text">还没有发布过组局</text>
      </view>
      <view
        v-for="post in sortedPosts"
        :key="post.id"
        class="post-row"
        @tap="openPost(post)"
      >
        <view class="post-cover">{{ sceneEmoji(post.area) }}</view>
        <view class="post-main">
          <text class="post-title">{{ post.title }}</text>
          <text class="post-meta">
            {{ areaLabel(post.area) }} · 👤 {{ post.currentMembers }}/{{ memberLimit(post) }}
          </text>
          <text v-if="formatCreated(post)" class="post-date">
            创建于 {{ formatCreated(post) }}
          </text>
        </view>
      </view>
    </view>

    <view class="menu">
      <view v-if="!user.isGuest" class="menu-item danger" @tap="onLogout">
        <text>{{ loggingOut ? '退出中…' : '退出登录' }}</text>
      </view>
      <view v-else class="menu-item" @tap="goLogin">
        <text>已有账号？去登录</text>
      </view>
    </view>
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  padding: 32rpx;
  padding-bottom: 48rpx;
  background: #f2f2f7;
  box-sizing: border-box;
}
.profile {
  display: flex;
  align-items: center;
  background: #fff;
  padding: 32rpx;
  border-radius: 24rpx;
}
.avatar {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: #e6f0ff;
  color: #002fa7;
  font-size: 48rpx;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.info {
  margin-left: 28rpx;
  min-width: 0;
}
.name {
  font-size: 36rpx;
  font-weight: 800;
  display: block;
}
.sub {
  font-size: 26rpx;
  color: #999;
  margin-top: 8rpx;
  display: block;
}
.actions {
  margin-top: 32rpx;
}
.btn {
  font-size: 30rpx;
}
.primary {
  background: #002fa7;
  color: #fff;
}
.my-section {
  margin-top: 32rpx;
  background: #fff;
  border-radius: 24rpx;
  padding: 24rpx;
}
.section-title {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #111;
  margin-bottom: 16rpx;
}
.empty {
  padding: 32rpx 0;
  text-align: center;
}
.empty-text {
  font-size: 26rpx;
  color: #999;
}
.post-row {
  display: flex;
  gap: 20rpx;
  padding: 20rpx 0;
  border-bottom: 1rpx solid #f0f0f0;
}
.post-row:last-child {
  border-bottom: none;
}
.post-cover {
  width: 88rpx;
  height: 88rpx;
  border-radius: 16rpx;
  background: #ececf7;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40rpx;
  flex-shrink: 0;
}
.post-main {
  flex: 1;
  min-width: 0;
}
.post-title {
  display: block;
  font-size: 28rpx;
  font-weight: 700;
  color: #111;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.post-meta {
  display: block;
  font-size: 24rpx;
  color: #666;
  margin-top: 8rpx;
}
.post-date {
  display: block;
  font-size: 22rpx;
  color: #aaa;
  margin-top: 6rpx;
}
.menu {
  margin-top: 24rpx;
  background: #fff;
  border-radius: 24rpx;
  overflow: hidden;
}
.menu-item {
  padding: 32rpx;
  text-align: center;
  font-size: 30rpx;
  color: #002fa7;
  border-top: 1rpx solid #f0f0f0;
}
.menu-item.danger {
  color: #c62828;
  font-weight: 600;
}
</style>
