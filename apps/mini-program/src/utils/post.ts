import { areaLabel } from '@/utils/scene'
import type { MatchPost } from '@/types/api'

export function parseMatchPost(json: Record<string, unknown>): MatchPost {
  const maxMembers = Number(json.maxMembers) || 4
  const traits = json.hostFaceTraits
  const hostFaceTraits = Array.isArray(traits)
    ? traits.map((t) => String(t)).filter(Boolean)
    : []
  const amountRaw = json.amount
  return {
    id: String(json.id),
    title: (json.title as string) || '',
    description: (json.description as string) || '',
    currentMembers: Number(json.currentMembers) || 1,
    maxMembers,
    maxPeople: Number(json.maxPeople) || maxMembers,
    area: (json.area as string) || '',
    tab: (json.tab as string) || '推荐',
    hostNickname: (json.hostNickname as string) || '用户',
    hostUserId: json.hostUserId as string | undefined,
    eventLocation: (json.eventLocation as string) || '',
    eventDateTime: (json.eventDateTime as string) || '',
    costType: (json.costType as string) || '',
    amount:
      amountRaw === null || amountRaw === undefined
        ? undefined
        : Number(amountRaw),
    hardcoreScore: Number(json.hardcoreScore) || 0,
    hostFaceTraits,
    hostCreditScore: Number(json.hostCreditScore) || 0,
    interactionCount: Number(json.interactionCount) || 0,
    lastActiveTime: (json.lastActiveTime as string) || '',
    matchScore: Number(json.matchScore) || 0,
    hasApplied: Boolean(json.hasApplied),
    applicationStatus: json.applicationStatus as string | undefined,
    isPinned: Boolean(json.isPinned),
    pinPriority: Number(json.pinPriority) || 0,
    createdAt: (json.createdAt as string) || '',
  }
}

export function formatCostLabel(post: MatchPost): string {
  const t = (post.costType || '').toLowerCase()
  switch (t) {
    case 'free':
      return '免费参与'
    case 'aa':
      return 'AA 制 · 费用平摊'
    case 'negotiate':
      return '费用面议'
    case 'fixed': {
      const n = post.amount
      if (n && n > 0) {
        const text = n === Math.floor(n) ? String(n) : n.toFixed(2)
        return `¥${text}/人`
      }
      return '固定费用'
    }
    default:
      return ''
  }
}

export function formatRelativeTime(iso?: string): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const diff = Date.now() - d.getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return '刚刚活跃'
  if (min < 60) return `${min} 分钟前活跃`
  const h = Math.floor(min / 60)
  if (h < 24) return `${h} 小时前活跃`
  const day = Math.floor(h / 24)
  return `${day} 天前活跃`
}

export { areaLabel }

export function memberLimit(post: MatchPost): number {
  return post.maxPeople || post.maxMembers
}

export function isPostFull(post: MatchPost): boolean {
  return post.currentMembers >= memberLimit(post)
}

export function formatEventTime(iso?: string): string {
  if (!iso) return '时间待定'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getMonth() + 1}月${d.getDate()}日 ${pad(d.getHours())}:${pad(d.getMinutes())}`
}
