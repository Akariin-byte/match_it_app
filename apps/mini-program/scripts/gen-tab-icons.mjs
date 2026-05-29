/**
 * 生成微信小程序 tabBar 图标（81×81，透明底 + 线型图标）
 * 运行: node scripts/gen-tab-icons.mjs
 */
import fs from 'fs'
import path from 'path'
import zlib from 'zlib'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const outDir = path.join(__dirname, '../src/static/tab')
const SIZE = 81

const GRAY = [140, 140, 148, 255]
const BRAND = [0, 47, 167, 255]

function crc32(buf) {
  let c = ~0
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i]
    for (let k = 0; k < 8; k++) c = c & 1 ? (0xedb88320 ^ (c >>> 1)) : c >>> 1
  }
  return ~c >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const typeBuf = Buffer.from(type)
  const body = Buffer.concat([typeBuf, data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([len, body, crc])
}

function encodePng(pixels) {
  const row = (y) => {
    const rowBuf = Buffer.alloc(1 + SIZE * 4)
    for (let x = 0; x < SIZE; x++) {
      const p = pixels[y * SIZE + x]
      const o = 1 + x * 4
      rowBuf[o] = p[0]
      rowBuf[o + 1] = p[1]
      rowBuf[o + 2] = p[2]
      rowBuf[o + 3] = p[3]
    }
    return rowBuf
  }
  const raw = Buffer.concat(Array.from({ length: SIZE }, (_, y) => row(y)))
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(SIZE, 0)
  ihdr.writeUInt32BE(SIZE, 4)
  ihdr[8] = 8
  ihdr[9] = 6
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

function blank() {
  return Array.from({ length: SIZE * SIZE }, () => [0, 0, 0, 0])
}

function blend(a, b) {
  const t = b[3] / 255
  return [
    Math.round(a[0] * (1 - t) + b[0] * t),
    Math.round(a[1] * (1 - t) + b[1] * t),
    Math.round(a[2] * (1 - t) + b[2] * t),
    Math.min(255, a[3] + b[3]),
  ]
}

function plot(pixels, x, y, color) {
  const ix = Math.round(x)
  const iy = Math.round(y)
  if (ix < 0 || ix >= SIZE || iy < 0 || iy >= SIZE) return
  const i = iy * SIZE + ix
  pixels[i] = blend(pixels[i], color)
}

function strokeDisc(pixels, x, y, r, color) {
  const r2 = r * r
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      if (dx * dx + dy * dy <= r2) plot(pixels, x + dx, y + dy, color)
    }
  }
}

function strokeLine(pixels, x0, y0, x1, y1, color, w = 2.8) {
  const dist = Math.hypot(x1 - x0, y1 - y0)
  const steps = Math.max(1, Math.ceil(dist * 2))
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const x = x0 + (x1 - x0) * t
    const y = y0 + (y1 - y0) * t
    strokeDisc(pixels, x, y, w / 2, color)
  }
}

function strokeRect(pixels, x, y, w, h, color, radius = 0, lineW = 2.6) {
  if (radius <= 0) {
    for (let t = 0; t <= 1; t += 0.02) {
      strokeLine(pixels, x, y + t * h, x + w, y + t * h, color, lineW)
      strokeLine(pixels, x, y + t * h, x + w, y + t * h, color, lineW)
    }
    strokeLine(pixels, x, y, x, y + h, color, lineW)
    strokeLine(pixels, x + w, y, x + w, y + h, color, lineW)
    return
  }
  const r = Math.min(radius, w / 2, h / 2)
  strokeLine(pixels, x + r, y, x + w - r, y, color, lineW)
  strokeLine(pixels, x + r, y + h, x + w - r, y + h, color, lineW)
  strokeLine(pixels, x, y + r, x, y + h - r, color, lineW)
  strokeLine(pixels, x + w, y + r, x + w, y + h - r, color, lineW)
  // corners as small arcs via dots
  for (let a = 0; a <= 90; a += 8) {
    const rad = (a * Math.PI) / 180
    const cx = [x + r, x + w - r, x + w - r, x + r]
    const cy = [y + r, y + r, y + h - r, y + h - r]
    const sx = [-1, 1, 1, -1]
    const sy = [-1, -1, 1, 1]
    for (let q = 0; q < 4; q++) {
      plot(
        pixels,
        cx[q] + sx[q] * r * Math.cos(rad),
        cy[q] + sy[q] * r * Math.sin(rad),
        color,
      )
    }
  }
}

function fillRect(pixels, x, y, w, h, color) {
  for (let py = y; py < y + h; py++) {
    for (let px = x; px < x + w; px++) {
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          plot(pixels, px + dx, py + dy, color)
        }
      }
    }
  }
}

function drawHome(pixels, color) {
  const c = 40
  strokeLine(pixels, c, 52, 40.5, 30, color, 3)
  strokeLine(pixels, 40.5, 30, 61, 52, color, 3)
  strokeLine(pixels, 28, 52, 53, 52, color, 3)
  strokeRect(pixels, 33, 44, 15, 14, color, 2, 2.4)
}

function drawMsg(pixels, color) {
  strokeRect(pixels, 26, 28, 29, 34, color, 6, 2.6)
  strokeLine(pixels, 33, 28, 40.5, 22, color, 2.6)
  strokeLine(pixels, 40.5, 22, 48, 28, color, 2.6)
  strokeDisc(pixels, 35, 42, 2.2, color)
  strokeDisc(pixels, 40.5, 42, 2.2, color)
  strokeDisc(pixels, 46, 42, 2.2, color)
}

function drawChat(pixels, color) {
  for (let r = 11; r <= 13; r += 0.4) {
    for (let a = 0; a < 360; a += 10) {
      const rad = (a * Math.PI) / 180
      plot(pixels, 34 + r * Math.cos(rad), 36 + r * Math.sin(rad), color)
    }
  }
  for (let r = 8.5; r <= 10.5; r += 0.4) {
    for (let a = 0; a < 360; a += 12) {
      const rad = (a * Math.PI) / 180
      plot(pixels, 50 + r * Math.cos(rad), 42 + r * Math.sin(rad), color)
    }
  }
  strokeDisc(pixels, 30, 36, 1.6, color)
  strokeDisc(pixels, 35, 36, 1.6, color)
  strokeDisc(pixels, 40, 36, 1.6, color)
  strokeDisc(pixels, 47, 42, 1.4, color)
  strokeDisc(pixels, 51, 42, 1.4, color)
}

function drawMe(pixels, color) {
  strokeDisc(pixels, 40.5, 30, 7.5, color)
  strokeLine(pixels, 27, 56, 40.5, 45, color, 3)
  strokeLine(pixels, 40.5, 45, 54, 56, color, 3)
}

const icons = {
  home: drawHome,
  msg: drawMsg,
  chat: drawChat,
  me: drawMe,
}

function renderIcon(drawFn, color) {
  const pixels = blank()
  drawFn(pixels, color)
  return encodePng(pixels)
}

fs.mkdirSync(outDir, { recursive: true })
for (const name of Object.keys(icons)) {
  fs.writeFileSync(path.join(outDir, `${name}.png`), renderIcon(icons[name], GRAY))
  fs.writeFileSync(
    path.join(outDir, `${name}-active.png`),
    renderIcon(icons[name], BRAND),
  )
}
console.log('Wrote tab icons to', outDir)
