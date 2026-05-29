export type SceneOption = { id: string; label: string }

export const PUBLISH_SCENES: SceneOption[] = [
  { id: 'AnimeCon', label: '漫展同行' },
  { id: 'Photo', label: '摄影约拍' },
  { id: 'BoardGames', label: '桌游剧本' },
  { id: 'Sport', label: '运动健身' },
  { id: 'Food', label: '美食探店' },
  { id: 'Travel', label: '旅行出行' },
  { id: 'Study', label: '学习自习' },
  { id: 'Game', label: '游戏开黑' },
  { id: 'Pet', label: '宠物社交' },
  { id: 'Music', label: '音乐 live' },
  { id: 'Outdoor', label: '户外露营' },
  { id: 'Drive', label: '自驾拼车' },
  { id: 'Other', label: '其他组局' },
]

const AREA_LABELS: Record<string, string> = Object.fromEntries(
  PUBLISH_SCENES.map((s) => [s.id, s.label]),
)

export function areaLabel(area?: string): string {
  if (!area) return ''
  return AREA_LABELS[area] || area
}

export const SCENE_EMOJI: Record<string, string> = {
  AnimeCon: '🎭',
  Photo: '📷',
  BoardGames: '🎲',
  Sport: '⚽',
  Food: '🍜',
  Travel: '✈️',
  Study: '📚',
  Game: '🎮',
  Pet: '🐾',
  Music: '🎵',
  Outdoor: '⛺',
  Drive: '🚗',
  Other: '✨',
}

export const SCENE_GRADIENT: Record<string, string> = {
  AnimeCon: 'linear-gradient(145deg, #f3e8ff, #ddd6fe)',
  Photo: 'linear-gradient(145deg, #e0f2fe, #bae6fd)',
  BoardGames: 'linear-gradient(145deg, #e8eeff, #c7d7fe)',
  Sport: 'linear-gradient(145deg, #dcfce7, #bbf7d0)',
  Food: 'linear-gradient(145deg, #ffedd5, #fed7aa)',
  Travel: 'linear-gradient(145deg, #cffafe, #a5f3fc)',
  Study: 'linear-gradient(145deg, #f1f5f9, #e2e8f0)',
  Game: 'linear-gradient(145deg, #ede9fe, #ddd6fe)',
  Pet: 'linear-gradient(145deg, #fce7f3, #fbcfe8)',
  Music: 'linear-gradient(145deg, #ffe4e6, #fecdd3)',
  Outdoor: 'linear-gradient(145deg, #d1fae5, #a7f3d0)',
  Drive: 'linear-gradient(145deg, #e0e7ff, #c7d2fe)',
  Other: 'linear-gradient(145deg, #e8eeff, #dce6ff)',
}

export function sceneEmoji(area?: string): string {
  return (area && SCENE_EMOJI[area]) || '✨'
}

export function sceneGradient(area?: string): string {
  return (area && SCENE_GRADIENT[area]) || SCENE_GRADIENT.Other
}
