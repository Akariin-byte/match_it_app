import { WS_BASE_URL } from '@/config'
import { getToken, request } from '@/utils/request'
import type { ApiList, ChatMessage, ConversationItem } from '@/types/api'

export async function listConversations(): Promise<ConversationItem[]> {
  const res = await request<ApiList<ConversationItem>>('/api/v1/conversations')
  return res.data || []
}

export async function listMessages(
  conversationId: string,
  beforeSeq = 0,
): Promise<ChatMessage[]> {
  const qs = beforeSeq > 0 ? `?before_seq=${beforeSeq}` : ''
  const res = await request<ApiList<ChatMessage>>(
    `/api/v1/conversations/${conversationId}/messages${qs}`,
  )
  return res.data || []
}

export function connectChatSocket(
  handlers: {
    onMessage: (msg: ChatMessage) => void
    onAck: (clientId: string, msg: ChatMessage) => void
    onError?: (err: string) => void
  },
): UniApp.SocketTask {
  const token = getToken()
  const task = uni.connectSocket({
    url: `${WS_BASE_URL}/api/v1/ws?token=${encodeURIComponent(token)}`,
  })

  task.onMessage((ev) => {
    try {
      const data = JSON.parse(ev.data as string) as Record<string, unknown>
      const type = data.type as string
      if (type === 'message' && data.message) {
        handlers.onMessage(data.message as ChatMessage)
      } else if (type === 'ack' && data.message) {
        handlers.onAck(data.clientId as string, data.message as ChatMessage)
      } else if (type === 'error') {
        handlers.onError?.((data.error as string) || 'send failed')
      }
    } catch {
      /* ignore */
    }
  })

  return task
}

export function sendChatMessage(
  task: UniApp.SocketTask,
  conversationId: string,
  body: string,
  clientId: string,
) {
  task.send({
    data: JSON.stringify({
      type: 'send',
      conversationId,
      clientId,
      body: body.trim(),
    }),
  })
}

export async function markRead(conversationId: string, seq: number) {
  await request(`/api/v1/conversations/${conversationId}/read`, {
    method: 'POST',
    data: { seq },
  })
}
