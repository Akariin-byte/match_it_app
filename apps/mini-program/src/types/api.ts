export interface AuthUser {
  id: string
  isGuest: boolean
  username: string
  phone?: string
  openid?: string
}

export interface AuthSession {
  token: string
  refreshToken?: string
  userId: string
  openid: string
  isGuest: boolean
  username: string
  phone?: string
}

export interface MatchPost {
  id: string
  title: string
  description: string
  currentMembers: number
  maxMembers: number
  maxPeople?: number
  area: string
  tab: string
  hostNickname: string
  hostUserId?: string
  eventLocation?: string
  eventDateTime?: string
  costType?: string
  amount?: number
  hardcoreScore?: number
  hostFaceTraits?: string[]
  hostCreditScore?: number
  interactionCount?: number
  lastActiveTime?: string
  matchScore?: number
  hasApplied?: boolean
  applicationStatus?: string
  isPinned?: boolean
  pinPriority?: number
  createdAt?: string
}

export interface PostComment {
  id: string
  postId: string
  parentId?: string
  body: string
  authorUserId: string
  authorUsername: string
  roleBadge?: string
  replyToUsername?: string
  createdAt: string
}

export interface CommentNotification {
  id: string
  kind: 'post_comment' | 'comment_reply'
  postId: string
  postTitle: string
  commentId: string
  commentBody: string
  actorUsername: string
  isRead: boolean
  createdAt: string
}

export interface PostMember {
  userId?: string
  username: string
  role?: string
  joinedAt?: string
}

export interface ReceivedApplicationItem {
  id: string
  postId: string
  applicantUserId: string
  status: string
  postTitle: string
  postArea: string
  applicantUsername: string
  applicantPhoneMasked?: string
  wechatContact?: string
  message?: string
  createdAt?: string
}

export interface ReceivedApplicationsResult {
  items: ReceivedApplicationItem[]
  pendingCount: number
}

export interface ConversationItem {
  id: string
  type: string
  postId?: string
  otherUser: { userId: string; username: string }
  lastMessage?: {
    body: string
    seq: number
    createdAt: string
  }
  unreadCount: number
  updatedAt: string
}

export interface ChatMessage {
  id: string
  conversationId: string
  senderId: string
  clientId: string
  seq: number
  body: string
  createdAt: string
}

export interface ApiList<T> {
  data: T[]
  total: number
}
