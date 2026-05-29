<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { listConversations } from '@/api/chat'
import { useUserStore } from '@/stores/user'
import type { ConversationItem } from '@/types/api'

const user = useUserStore()
const items = ref<ConversationItem[]>([])
const loading = ref(false)

async function load() {
  if (user.isGuest) return
  loading.value = true
  try {
    items.value = await listConversations()
  } catch {
    uni.showToast({ title: '加载失败', icon: 'none' })
  } finally {
    loading.value = false
  }
}

onShow(load)

function goLogin() {
  uni.navigateTo({ url: '/pages/login/index' })
}

function openRoom(item: ConversationItem) {
  uni.navigateTo({
    url: `/pages/chat/room?id=${item.id}&name=${encodeURIComponent(item.otherUser.username)}`,
  })
}
</script>

<template>
  <view class="page">
    <view v-if="user.isGuest" class="guest">
      <text>登录后使用私信</text>
      <button class="btn" @tap="goLogin">去登录</button>
    </view>
    <view v-else-if="loading" class="center"><text>加载中…</text></view>
    <view v-else-if="items.length === 0" class="center">
      <text class="muted">暂无私信\n申请通过后会自动创建会话</text>
    </view>
    <view v-else class="list">
      <view
        v-for="item in items"
        :key="item.id"
        class="row"
        @tap="openRoom(item)"
      >
        <view class="avatar">{{ item.otherUser.username.slice(0, 1) }}</view>
        <view class="content">
          <text class="name">{{ item.otherUser.username }}</text>
          <text class="preview">{{ item.lastMessage?.body || '开始聊天吧' }}</text>
        </view>
        <view v-if="item.unreadCount > 0" class="badge">{{ item.unreadCount }}</view>
      </view>
    </view>
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
}
.guest,
.center {
  padding: 120rpx 40rpx;
  text-align: center;
  color: #666;
}
.btn {
  margin-top: 24rpx;
  background: #002fa7;
  color: #fff;
}
.muted {
  color: #999;
  white-space: pre-line;
}
.row {
  display: flex;
  align-items: center;
  padding: 28rpx 32rpx;
  background: #fff;
  border-bottom: 1rpx solid #f0f0f0;
}
.avatar {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  background: #e6f0ff;
  color: #002fa7;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 32rpx;
}
.content {
  flex: 1;
  margin-left: 24rpx;
  overflow: hidden;
}
.name {
  font-size: 30rpx;
  font-weight: 700;
  display: block;
}
.preview {
  font-size: 26rpx;
  color: #999;
  margin-top: 8rpx;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.badge {
  background: #ff3b30;
  color: #fff;
  font-size: 22rpx;
  min-width: 36rpx;
  height: 36rpx;
  line-height: 36rpx;
  text-align: center;
  border-radius: 18rpx;
  padding: 0 10rpx;
}
</style>
