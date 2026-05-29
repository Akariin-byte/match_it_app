<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad, onUnload } from '@dcloudio/uni-app'
import {
  connectChatSocket,
  listMessages,
  markRead,
  sendChatMessage,
} from '@/api/chat'
import { useUserStore } from '@/stores/user'
import type { ChatMessage } from '@/types/api'

const user = useUserStore()
const conversationId = ref('')
const peerName = ref('')
const messages = ref<ChatMessage[]>([])
const input = ref('')
const loading = ref(true)
let socket: UniApp.SocketTask | null = null

onLoad((query) => {
  conversationId.value = (query?.id as string) || ''
  peerName.value = decodeURIComponent((query?.name as string) || '聊天')
  uni.setNavigationBarTitle({ title: peerName.value })
  init()
})

onUnload(() => {
  socket?.close({})
  socket = null
})

async function init() {
  if (!conversationId.value || !user.token) return
  try {
    messages.value = await listMessages(conversationId.value)
    if (messages.value.length > 0) {
      const last = messages.value[messages.value.length - 1]
      markRead(conversationId.value, last.seq)
    }
  } finally {
    loading.value = false
  }

  socket = connectChatSocket({
    onMessage(msg) {
      if (msg.conversationId !== conversationId.value) return
      if (!messages.value.some((m) => m.clientId === msg.clientId)) {
        messages.value.push(msg)
        markRead(conversationId.value, msg.seq)
      }
    },
    onAck(clientId, msg) {
      const i = messages.value.findIndex((m) => m.clientId === clientId)
      if (i >= 0) messages.value[i] = msg
    },
  })
}

function genClientId() {
  return `c_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`
}

function send() {
  const text = input.value.trim()
  if (!text || !socket) return
  const clientId = genClientId()
  const optimistic: ChatMessage = {
    id: '',
    conversationId: conversationId.value,
    senderId: user.session!.userId,
    clientId,
    seq: 0,
    body: text,
    createdAt: new Date().toISOString(),
  }
  messages.value.push(optimistic)
  input.value = ''
  sendChatMessage(socket, conversationId.value, text, clientId)
}

const sortedMessages = computed(() => messages.value)
</script>

<template>
  <view class="page">
    <scroll-view scroll-y class="list" :scroll-into-view="'msg-' + (sortedMessages.length - 1)">
      <view v-if="loading" class="center"><text>加载中…</text></view>
      <view
        v-for="(msg, idx) in sortedMessages"
        :id="'msg-' + idx"
        :key="msg.clientId"
        class="bubble-row"
        :class="{ mine: msg.senderId === user.session?.userId }"
      >
        <view class="bubble">{{ msg.body }}</view>
      </view>
    </scroll-view>
    <view class="composer">
      <input v-model="input" class="input" confirm-type="send" @confirm="send" />
      <button class="send" @tap="send">发送</button>
    </view>
  </view>
</template>

<style scoped lang="scss">
.page {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: #f2f2f7;
}
.list {
  flex: 1;
  padding: 24rpx;
  box-sizing: border-box;
}
.center {
  text-align: center;
  padding: 40rpx;
  color: #999;
}
.bubble-row {
  display: flex;
  margin-bottom: 16rpx;
}
.bubble-row.mine {
  justify-content: flex-end;
}
.bubble {
  max-width: 70%;
  padding: 20rpx 28rpx;
  border-radius: 24rpx;
  background: #fff;
  font-size: 30rpx;
  line-height: 1.45;
}
.mine .bubble {
  background: #002fa7;
  color: #fff;
}
.composer {
  display: flex;
  padding: 16rpx 24rpx;
  padding-bottom: calc(16rpx + env(safe-area-inset-bottom));
  background: #fff;
  gap: 16rpx;
}
.input {
  flex: 1;
  background: #f2f2f7;
  border-radius: 40rpx;
  padding: 16rpx 28rpx;
  font-size: 28rpx;
}
.send {
  background: #002fa7;
  color: #fff;
  font-size: 28rpx;
  line-height: 2;
  padding: 0 28rpx;
  margin: 0;
}
</style>
