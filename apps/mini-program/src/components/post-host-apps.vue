<script setup lang="ts">
import type { ReceivedApplicationItem } from '@/types/api'

defineProps<{
  applications: ReceivedApplicationItem[]
  pendingCount: number
  actingAppId: string
}>()

const emit = defineEmits<{
  approve: [item: ReceivedApplicationItem]
  reject: [item: ReceivedApplicationItem]
  cancel: [item: ReceivedApplicationItem]
}>()

function displayName(item: ReceivedApplicationItem): string {
  return item.applicantUsername?.trim() || '用户'
}

function statusText(status: string): string {
  if (status === 'approved') return '已通过'
  if (status === 'rejected') return '已拒绝'
  return status
}
</script>

<template>
  <view v-if="applications.length === 0" class="section">
    <text class="section-title">加入申请</text>
    <text class="empty-hint">
      暂无申请。申请人须先登录并绑定手机号；报名时会填写微信昵称/号便于你对账。
    </text>
  </view>

  <view v-else class="section">
    <view class="section-head">
      <text class="section-title">加入申请</text>
      <text v-if="pendingCount > 0" class="section-sub">待处理 {{ pendingCount }}</text>
    </view>
    <view v-for="app in applications" :key="app.id" class="app-card">
      <view class="app-head">
        <text class="app-name">{{ displayName(app) }}</text>
        <text
          v-if="app.status !== 'pending'"
          class="app-status"
          :class="app.status"
        >
          {{ statusText(app.status) }}
        </text>
      </view>
      <text v-if="app.wechatContact" class="app-wechat">微信：{{ app.wechatContact }}</text>
      <text v-if="app.applicantPhoneMasked" class="app-phone">
        {{ app.applicantPhoneMasked }}
      </text>
      <text v-if="app.message" class="app-msg">「{{ app.message }}」</text>
      <view v-if="app.status === 'approved'" class="app-actions">
        <button
          class="btn-cancel"
          size="mini"
          :disabled="!!actingAppId"
          @tap="emit('cancel', app)"
        >
          取消资格（未付款）
        </button>
      </view>
      <view v-if="app.status === 'pending'" class="app-actions">
        <button
          class="btn-reject"
          size="mini"
          :disabled="!!actingAppId"
          @tap="emit('reject', app)"
        >
          拒绝
        </button>
        <button
          class="btn-approve"
          size="mini"
          :loading="actingAppId === app.id"
          :disabled="!!actingAppId && actingAppId !== app.id"
          @tap="emit('approve', app)"
        >
          同意
        </button>
      </view>
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
  font-size: 26rpx;
  color: #666;
}
.empty-hint {
  display: block;
  font-size: 26rpx;
  color: #888;
  line-height: 1.55;
  margin-top: 12rpx;
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
.btn-cancel {
  width: 100%;
  background: #fff;
  color: #c62828;
  border: 1rpx solid #e57373;
  border-radius: 40rpx;
}
</style>
