import type { MatchPost } from '@/types/api'
import {
  DEFAULT_SHARE_IMAGE,
  postSharePosterSubline,
  postShareStatusLine,
  truncateText,
  type ShareViewerState,
} from '@/utils/post-share'
import { isPostFull, memberLimit } from '@/utils/post'

const W = 500
const H = 400
const CANVAS_TIMEOUT_MS = 2500

function drawRoundRect(
  ctx: UniApp.CanvasContext,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const rr = Math.min(r, w / 2, h / 2)
  ctx.beginPath()
  ctx.moveTo(x + rr, y)
  ctx.lineTo(x + w - rr, y)
  ctx.arc(x + w - rr, y + rr, rr, -Math.PI / 2, 0)
  ctx.lineTo(x + w, y + h - rr)
  ctx.arc(x + w - rr, y + h - rr, rr, 0, Math.PI / 2)
  ctx.lineTo(x + rr, y + h)
  ctx.arc(x + rr, y + h - rr, rr, Math.PI / 2, Math.PI)
  ctx.lineTo(x, y + rr)
  ctx.arc(x + rr, y + rr, rr, Math.PI, -Math.PI / 2)
  ctx.closePath()
}

export function generatePostSharePoster(
  post: MatchPost,
  canvasId: string,
  viewer?: ShareViewerState,
  componentInstance?: unknown,
): Promise<string> {
  return new Promise((resolve, reject) => {
    let settled = false
    const finish = (fn: () => void) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      fn()
    }

    const timer = setTimeout(() => {
      finish(() => reject(new Error('canvas timeout')))
    }, CANVAS_TIMEOUT_MS)

    const ctx = uni.createCanvasContext(canvasId, componentInstance as unknown as undefined)
    const limit = memberLimit(post)
    const pct =
      limit > 0
        ? Math.min(100, Math.round((post.currentMembers / limit) * 100))
        : 0
    const status = postShareStatusLine(post, viewer)
    const title = truncateText(post.title, 16)
    const sub = truncateText(postSharePosterSubline(post), 24)
    const host = truncateText(post.hostNickname || '主理人', 12)

    ctx.setFillStyle('#002FA7')
    ctx.fillRect(0, 0, W, H)

    ctx.setFillStyle('#ffffff')
    drawRoundRect(ctx, 28, 56, W - 56, H - 88, 20)
    ctx.fill()

    ctx.setFillStyle('#002FA7')
    ctx.setFontSize(13)
    ctx.fillText('MATCHit', 48, 88)

    ctx.setFillStyle(isPostFull(post) ? '#757575' : '#002FA7')
    ctx.setFontSize(22)
    ctx.fillText(status, 48, 128)

    ctx.setFillStyle('#111111')
    ctx.setFontSize(20)
    ctx.fillText(title, 48, 168)

    ctx.setFillStyle('#666666')
    ctx.setFontSize(14)
    ctx.fillText(sub, 48, 198)

    ctx.setFillStyle('#eeeeee')
    drawRoundRect(ctx, 48, 228, W - 96, 14, 7)
    ctx.fill()

    if (pct > 0) {
      ctx.setFillStyle('#002FA7')
      drawRoundRect(ctx, 48, 228, ((W - 96) * pct) / 100, 14, 7)
      ctx.fill()
    }

    ctx.setFillStyle('#999999')
    ctx.setFontSize(13)
    ctx.fillText(`主理人 ${host}`, 48, 268)
    ctx.fillText(`${post.currentMembers}/${limit} 人`, 48, 294)

    ctx.draw(false, () => {
      setTimeout(() => {
        const opts: UniApp.CanvasToTempFilePathOptions = {
          canvasId,
          width: W,
          height: H,
          destWidth: W,
          destHeight: H,
          fileType: 'png',
          success: (res) => finish(() => resolve(res.tempFilePath)),
          fail: (err) => finish(() => reject(err)),
        }
        if (componentInstance) {
          uni.canvasToTempFilePath(opts, componentInstance as unknown as undefined)
        } else {
          uni.canvasToTempFilePath(opts)
        }
      }, 200)
    })
  })
}

export async function buildSharePosterOrDefault(
  post: MatchPost,
  canvasId: string,
  viewer?: ShareViewerState,
  componentInstance?: unknown,
): Promise<string> {
  try {
    return await generatePostSharePoster(
      post,
      canvasId,
      viewer,
      componentInstance,
    )
  } catch (e) {
    console.warn('generatePostSharePoster failed', e)
    return DEFAULT_SHARE_IMAGE
  }
}
