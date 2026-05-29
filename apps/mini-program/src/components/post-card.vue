<script setup lang="ts">
import { computed } from 'vue'
import type { MatchPost } from '@/types/api'
import { areaLabel, sceneEmoji } from '@/utils/scene'
import { isPostFull, memberLimit } from '@/utils/post'

const props = defineProps<{ post: MatchPost }>()

const limit = computed(() => memberLimit(props.post))
const isFull = computed(() => isPostFull(props.post))

const statusText = computed(() => {
  if (isFull.value) return '已满员'
  if (props.post.applicationStatus === 'approved') return '已通过'
  if (props.post.hasApplied) return '已申请'
  return '组队中'
})

const coverEmoji = computed(() => sceneEmoji(props.post.area))
const sceneName = computed(() => areaLabel(props.post.area))

const coverClass = computed(() => {
  const area = props.post.area || 'Other'
  const known = [
    'AnimeCon',
    'Photo',
    'BoardGames',
    'Sport',
    'Food',
    'Travel',
    'Study',
    'Game',
    'Pet',
    'Music',
    'Outdoor',
    'Drive',
    'Other',
  ]
  return known.includes(area) ? `cover-${area}` : 'cover-Other'
})

const countLabel = computed(() => {
  const n = `${props.post.currentMembers}/${limit.value}`
  return isFull.value ? `👤 ${n} 满` : `👤 ${n}`
})

const hostInitial = computed(() => {
  const name = (props.post.hostNickname || '用户').trim()
  return name ? name.slice(0, 1) : 'U'
})
</script>

<template>
  <view class="card" :class="{ dimmed: isFull }">
    <view class="cover" :class="coverClass">
      <view v-if="sceneName" class="scene-pill">
        <text class="scene-pill-text">{{ coverEmoji }} {{ sceneName }}</text>
      </view>
      <text class="cover-emoji">{{ coverEmoji }}</text>
      <view class="count-badge">
        <text>{{ countLabel }}</text>
      </view>
      <view v-if="isFull" class="full-mask">
        <text class="full-label">已满员</text>
      </view>
    </view>
    <view class="body">
      <text class="title">{{ post.title }}</text>
      <view class="tags">
        <text class="tag" :class="{ full: isFull }">
          {{ statusText }}
        </text>
      </view>
      <view class="author">
        <view class="author-avatar">
          <text class="author-initial">{{ hostInitial }}</text>
        </view>
        <text class="author-name">{{ post.hostNickname }}</text>
      </view>
    </view>
  </view>
</template>

<style scoped lang="scss">
.card {
  background: #fff;
  border-radius: 24rpx;
  overflow: hidden;
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.04);
}
.card.dimmed {
  opacity: 0.88;
}
.cover {
  height: 200rpx;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #ececf7;
}
.cover-AnimeCon {
  background-image: linear-gradient(145deg, #f3e8ff, #ddd6fe);
}
.cover-Photo {
  background-image: linear-gradient(145deg, #e0f2fe, #bae6fd);
}
.cover-BoardGames {
  background-image: linear-gradient(145deg, #e8eeff, #c7d7fe);
}
.cover-Sport {
  background-image: linear-gradient(145deg, #dcfce7, #bbf7d0);
}
.cover-Food {
  background-image: linear-gradient(145deg, #ffedd5, #fed7aa);
}
.cover-Travel {
  background-image: linear-gradient(145deg, #cffafe, #a5f3fc);
}
.cover-Study {
  background-image: linear-gradient(145deg, #f1f5f9, #e2e8f0);
}
.cover-Game {
  background-image: linear-gradient(145deg, #ede9fe, #ddd6fe);
}
.cover-Pet {
  background-image: linear-gradient(145deg, #fce7f3, #fbcfe8);
}
.cover-Music {
  background-image: linear-gradient(145deg, #ffe4e6, #fecdd3);
}
.cover-Outdoor {
  background-image: linear-gradient(145deg, #d1fae5, #a7f3d0);
}
.cover-Drive {
  background-image: linear-gradient(145deg, #e0e7ff, #c7d2fe);
}
.cover-Other {
  background-image: linear-gradient(145deg, #e8eeff, #dce6ff);
}
.scene-pill {
  position: absolute;
  top: 12rpx;
  left: 12rpx;
  max-width: calc(100% - 120rpx);
  padding: 6rpx 14rpx;
  border-radius: 20rpx;
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 2rpx 8rpx rgba(0, 0, 0, 0.06);
}
.scene-pill-text {
  font-size: 20rpx;
  font-weight: 600;
  color: #002fa7;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cover-emoji {
  font-size: 64rpx;
  line-height: 1;
}
.count-badge {
  position: absolute;
  top: 12rpx;
  right: 12rpx;
  background: rgba(0, 0, 0, 0.5);
  color: #fff;
  font-size: 20rpx;
  font-weight: 700;
  padding: 6rpx 14rpx;
  border-radius: 16rpx;
}
.full-mask {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.28);
  display: flex;
  align-items: center;
  justify-content: center;
}
.full-label {
  padding: 8rpx 24rpx;
  border-radius: 24rpx;
  background: rgba(255, 255, 255, 0.92);
  color: #616161;
  font-size: 24rpx;
  font-weight: 800;
}
.body {
  padding: 20rpx;
}
.title {
  font-size: 28rpx;
  font-weight: 700;
  color: #111;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.tags {
  margin-top: 12rpx;
}
.tag {
  font-size: 20rpx;
  color: #002fa7;
  background: #e6f0ff;
  padding: 4rpx 12rpx;
  border-radius: 12rpx;
}
.tag.full {
  color: #424242;
  background: #eee;
}
.author {
  margin-top: 16rpx;
  display: flex;
  align-items: center;
  gap: 10rpx;
}
.author-avatar {
  width: 36rpx;
  height: 36rpx;
  border-radius: 50%;
  background: #e6f0ff;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.author-initial {
  font-size: 20rpx;
  font-weight: 700;
  color: #002fa7;
}
.author-name {
  font-size: 22rpx;
  color: rgba(0, 0, 0, 0.45);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
