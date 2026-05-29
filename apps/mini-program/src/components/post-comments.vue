<script setup lang="ts">
import { computed, ref } from 'vue'
import { createPostComment } from '@/api/comments'
import { useUserStore } from '@/stores/user'
import { ApiError } from '@/utils/request'
import { formatRelativeTime } from '@/utils/post'
import type { PostComment } from '@/types/api'

const props = defineProps<{
  postId: string
  comments: PostComment[]
}>()

const emit = defineEmits<{
  refresh: []
}>()

const user = useUserStore()
const input = ref('')
const submitting = ref(false)
const replyingTo = ref<PostComment | null>(null)

const topLevel = computed(() =>
  props.comments.filter((c) => !c.parentId),
)

function repliesOf(parentId: string) {
  return props.comments.filter((c) => c.parentId === parentId)
}

function authorInitial(name: string) {
  const n = (name || '用户').trim()
  return n ? n.slice(0, 1) : 'U'
}

function startReply(comment: PostComment) {
  if (user.isGuest) {
    uni.showModal({
      title: '需要登录',
      content: '登录后才能评论与回复',
      confirmText: '去登录',
      success: (res) => {
        if (res.confirm) user.requireRegistered()
      },
    })
    return
  }
  replyingTo.value = comment
}

function cancelReply() {
  replyingTo.value = null
}

async function submitComment() {
  const text = input.value.trim()
  if (!text) return
  if (user.isGuest) {
    uni.showModal({
      title: '需要登录',
      content: '登录后才能评论与回复',
      confirmText: '去登录',
      success: (res) => {
        if (res.confirm) user.requireRegistered()
      },
    })
    return
  }
  submitting.value = true
  try {
    await createPostComment(
      props.postId,
      text,
      replyingTo.value?.id,
    )
    input.value = ''
    replyingTo.value = null
    emit('refresh')
    uni.showToast({ title: '已发送', icon: 'success' })
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '发送失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <view class="section">
    <view class="section-head">
      <text class="section-title">评论</text>
      <text class="section-sub">{{ comments.length }} 条</text>
    </view>

    <view v-if="comments.length === 0" class="empty">
      <text class="empty-text">还没有评论，来抢沙发吧</text>
    </view>

    <view v-for="item in topLevel" :key="item.id" class="comment-block">
      <view class="comment-row">
        <view class="avatar">{{ authorInitial(item.authorUsername) }}</view>
        <view class="comment-body">
          <view class="comment-meta">
            <text class="name">{{ item.authorUsername }}</text>
            <text v-if="item.roleBadge" class="badge">{{ item.roleBadge }}</text>
            <text class="time">{{ formatRelativeTime(item.createdAt) }}</text>
          </view>
          <text class="text">{{ item.body }}</text>
          <text class="reply-link" @tap="startReply(item)">回复</text>
        </view>
      </view>

      <view
        v-for="reply in repliesOf(item.id)"
        :key="reply.id"
        class="comment-row reply"
      >
        <view class="avatar small">{{ authorInitial(reply.authorUsername) }}</view>
        <view class="comment-body">
          <view class="comment-meta">
            <text class="name">{{ reply.authorUsername }}</text>
            <text v-if="reply.roleBadge" class="badge">{{ reply.roleBadge }}</text>
            <text class="time">{{ formatRelativeTime(reply.createdAt) }}</text>
          </view>
          <text v-if="reply.replyToUsername" class="reply-to">
            回复 {{ reply.replyToUsername }}
          </text>
          <text class="text">{{ reply.body }}</text>
          <text class="reply-link" @tap="startReply(reply)">回复</text>
        </view>
      </view>
    </view>

    <view v-if="replyingTo" class="reply-hint">
      <text>回复 {{ replyingTo.authorUsername }}</text>
      <text class="cancel" @tap="cancelReply">取消</text>
    </view>

    <view class="composer">
      <input
        v-model="input"
        class="input"
        :placeholder="replyingTo ? '写下回复…' : '说点什么…'"
        confirm-type="send"
        @confirm="submitComment"
      />
      <button
        class="send"
        size="mini"
        :loading="submitting"
        :disabled="submitting || !input.trim()"
        @tap="submitComment"
      >
        发送
      </button>
    </view>
  </view>
</template>

<style scoped lang="scss">
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
  font-size: 24rpx;
  color: #999;
}
.empty {
  padding: 24rpx 0 8rpx;
}
.empty-text {
  font-size: 26rpx;
  color: #999;
}
.comment-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid #f0f0f0;
}
.comment-block:last-child {
  border-bottom: none;
}
.comment-row {
  display: flex;
  align-items: flex-start;
  gap: 16rpx;
}
.comment-row.reply {
  margin-top: 16rpx;
  margin-left: 56rpx;
  padding-left: 16rpx;
  border-left: 4rpx solid #e6f0ff;
}
.avatar {
  width: 56rpx;
  height: 56rpx;
  border-radius: 50%;
  background: #e6f0ff;
  color: #002fa7;
  font-size: 24rpx;
  font-weight: 700;
  text-align: center;
  line-height: 56rpx;
  flex-shrink: 0;
}
.avatar.small {
  width: 44rpx;
  height: 44rpx;
  line-height: 44rpx;
  font-size: 20rpx;
}
.comment-body {
  flex: 1;
  min-width: 0;
}
.comment-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10rpx;
  margin-bottom: 8rpx;
}
.name {
  font-size: 26rpx;
  font-weight: 700;
  color: #111;
}
.badge {
  font-size: 20rpx;
  color: #002fa7;
  background: #e6f0ff;
  padding: 2rpx 10rpx;
  border-radius: 8rpx;
}
.time {
  font-size: 22rpx;
  color: #bbb;
}
.reply-to {
  display: block;
  font-size: 22rpx;
  color: #888;
  margin-bottom: 4rpx;
}
.text {
  display: block;
  font-size: 28rpx;
  color: #333;
  line-height: 1.55;
  word-break: break-word;
}
.reply-link {
  display: inline-block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #002fa7;
}
.reply-hint {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 16rpx;
  padding: 12rpx 16rpx;
  background: #f5f8ff;
  border-radius: 12rpx;
  font-size: 24rpx;
  color: #555;
}
.cancel {
  color: #002fa7;
}
.composer {
  display: flex;
  gap: 16rpx;
  align-items: center;
  margin-top: 20rpx;
  padding-top: 20rpx;
  border-top: 1rpx solid #f0f0f0;
}
.input {
  flex: 1;
  background: #f2f2f7;
  border-radius: 40rpx;
  padding: 16rpx 24rpx;
  font-size: 28rpx;
}
.send {
  background: #002fa7;
  color: #fff;
  border-radius: 40rpx;
  margin: 0;
  padding: 0 24rpx;
}
</style>
