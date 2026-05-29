<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useUserStore } from '@/stores/user'
import { ApiError, request } from '@/utils/request'
import { PUBLISH_SCENES, areaLabel } from '@/utils/scene'

const user = useUserStore()
const content = ref('')
const loading = ref(false)

const sceneId = ref('BoardGames')
const location = ref('')
const eventDate = ref('')
const eventTime = ref('')
const costType = ref<'free' | 'aa' | 'negotiate' | 'fixed'>('free')
const costAmount = ref('')
const maxPeople = ref(4)

const maxPeopleOptions = Array.from({ length: 19 }, (_, i) => i + 2)
const maxPeopleIndex = computed(() =>
  Math.max(0, maxPeopleOptions.indexOf(maxPeople.value)),
)

const locationPresets = [
  '线上',
  '上海市 · 待定',
  '北京市 · 待定',
  '广州市 · 待定',
  '深圳市 · 待定',
]

const costLabel = computed(() => {
  switch (costType.value) {
    case 'free':
      return '免费参与'
    case 'aa':
      return 'AA制'
    case 'negotiate':
      return '面议'
    case 'fixed': {
      const n = parseFloat(costAmount.value)
      return n > 0 ? `¥${n}/人` : '设定金额'
    }
    default:
      return ''
  }
})

const timeLabel = computed(() => {
  if (!eventDate.value) return ''
  return eventTime.value ? `${eventDate.value} ${eventTime.value}` : eventDate.value
})

onShow(() => {
  if (user.isGuest) {
    user.requireRegistered()
  }
})

function pickScene() {
  uni.showActionSheet({
    itemList: PUBLISH_SCENES.map((s) => s.label),
    success(res) {
      const s = PUBLISH_SCENES[res.tapIndex]
      if (s) sceneId.value = s.id
    },
  })
}

function pickLocation() {
  uni.showActionSheet({
    itemList: [...locationPresets, '自定义输入'],
    success(res) {
      if (res.tapIndex < locationPresets.length) {
        location.value = locationPresets[res.tapIndex]
        return
      }
      uni.showModal({
        title: '活动地点',
        editable: true,
        placeholderText: '输入地点',
        content: location.value,
        success(r) {
          if (r.confirm && r.content?.trim()) {
            location.value = r.content.trim()
          }
        },
      })
    },
  })
}

function onDateChange(e: { detail: { value: string } }) {
  eventDate.value = e.detail.value
}

function onTimeChange(e: { detail: { value: string } }) {
  eventTime.value = e.detail.value
}

function pickCost() {
  uni.showActionSheet({
    itemList: ['免费参与', 'AA制', '面议', '固定金额/人'],
    success(res) {
      const map: Array<'free' | 'aa' | 'negotiate' | 'fixed'> = [
        'free',
        'aa',
        'negotiate',
        'fixed',
      ]
      costType.value = map[res.tapIndex] ?? 'free'
      if (costType.value === 'fixed') {
        uni.showModal({
          title: '人均金额（元）',
          editable: true,
          placeholderText: '例如 50',
          success(r) {
            if (r.confirm) costAmount.value = r.content?.trim() || ''
          },
        })
      }
    },
  })
}

function onMaxPeopleChange(e: { detail: { value: number | string } }) {
  const i = Number(e.detail.value)
  maxPeople.value = maxPeopleOptions[i] ?? 4
}

/** 后端 Go 要求 RFC3339（须含时区），如 2026-05-28T12:00:00.000Z */
function buildEventDateTime(): string | undefined {
  if (!eventDate.value) return undefined
  const t = eventTime.value || '12:00'
  const d = new Date(`${eventDate.value}T${t}:00`)
  if (Number.isNaN(d.getTime())) return undefined
  return d.toISOString()
}

async function submit() {
  const text = content.value.trim()
  if (!text) {
    uni.showToast({ title: '请输入组局内容', icon: 'none' })
    return
  }
  if (!sceneId.value) {
    uni.showToast({ title: '请选择场景', icon: 'none' })
    return
  }
  if (costType.value === 'fixed') {
    const n = parseFloat(costAmount.value)
    if (!n || n <= 0) {
      uni.showToast({ title: '请填写人均金额', icon: 'none' })
      return
    }
  }

  loading.value = true
  try {
    const payload: Record<string, unknown> = {
      content: text,
      area: sceneId.value,
      maxPeople: maxPeople.value,
      tags: [areaLabel(sceneId.value)],
      tab: '推荐',
    }
    const loc = location.value.trim()
    if (loc) payload.eventLocation = loc
    const dt = buildEventDateTime()
    if (dt) payload.eventDateTime = dt
    if (costType.value) payload.costType = costType.value
    if (costType.value === 'fixed') {
      payload.amount = parseFloat(costAmount.value)
    }

    await request('/api/v1/posts', { method: 'POST', data: payload })
    uni.showToast({ title: '发布成功', icon: 'success' })
    setTimeout(() => uni.switchTab({ url: '/pages/feed/index' }), 600)
  } catch (e) {
    const msg = e instanceof ApiError ? e.message : '发布失败'
    uni.showToast({ title: msg, icon: 'none' })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <view class="page">
    <textarea
      v-model="content"
      class="textarea"
      placeholder="描述你的组局：时间、地点、人数、玩法…"
      maxlength="500"
    />
    <text class="char-count">{{ content.length }}/500</text>

    <view class="toolbar">
      <view class="tool-item" @tap="pickScene">
        <text class="tool-emoji">🏷</text>
        <text class="tool-text">{{ areaLabel(sceneId) || '场景' }}</text>
      </view>
      <view class="tool-item" @tap="pickLocation">
        <text class="tool-emoji">📍</text>
        <text class="tool-text">{{ location || '地点' }}</text>
      </view>
      <picker mode="date" :value="eventDate" @change="onDateChange">
        <view class="tool-item">
          <text class="tool-emoji">🕐</text>
          <text class="tool-text">{{ eventDate || '日期' }}</text>
        </view>
      </picker>
      <picker mode="time" :value="eventTime" @change="onTimeChange">
        <view class="tool-item">
          <text class="tool-emoji">⏰</text>
          <text class="tool-text">{{ eventTime || '时刻' }}</text>
        </view>
      </picker>
      <view class="tool-item" @tap="pickCost">
        <text class="tool-emoji">💰</text>
        <text class="tool-text">{{ costLabel || '费用' }}</text>
      </view>
      <picker
        mode="selector"
        :range="maxPeopleOptions"
        :value="maxPeopleIndex"
        @change="onMaxPeopleChange"
      >
        <view class="tool-item">
          <text class="tool-emoji">👥</text>
          <text class="tool-text">{{ maxPeople }}人</text>
        </view>
      </picker>
    </view>

    <view v-if="location || timeLabel || costLabel" class="summary">
      <text v-if="location" class="summary-line">📍 {{ location }}</text>
      <text v-if="timeLabel" class="summary-line">🕐 {{ timeLabel }}</text>
      <text class="summary-line">💰 {{ costLabel }} · 👥 {{ maxPeople }}人</text>
    </view>

    <button class="submit" :loading="loading" @tap="submit">发布</button>
  </view>
</template>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  padding: 24rpx 32rpx 48rpx;
  background: #f2f2f7;
  box-sizing: border-box;
}
.textarea {
  width: 100%;
  min-height: 280rpx;
  background: #fff;
  border-radius: 20rpx;
  padding: 24rpx;
  box-sizing: border-box;
  font-size: 30rpx;
}
.char-count {
  display: block;
  text-align: right;
  font-size: 24rpx;
  color: #999;
  margin: 8rpx 8rpx 20rpx;
}
.toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
  margin-bottom: 24rpx;
}
.tool-item {
  display: flex;
  align-items: center;
  background: #fff;
  border-radius: 999rpx;
  padding: 14rpx 24rpx;
  max-width: 100%;
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.04);
}
.tool-emoji {
  font-size: 28rpx;
  margin-right: 8rpx;
}
.tool-text {
  font-size: 26rpx;
  color: #1d9bf0;
  max-width: 200rpx;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.summary {
  background: #fff;
  border-radius: 16rpx;
  padding: 20rpx 24rpx;
  margin-bottom: 24rpx;
}
.summary-line {
  display: block;
  font-size: 26rpx;
  color: #555;
  line-height: 1.6;
}
.submit {
  background: #002fa7;
  color: #fff;
  border-radius: 48rpx;
  font-size: 32rpx;
  font-weight: 700;
}
</style>
