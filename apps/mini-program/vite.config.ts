import { defineConfig } from 'vite'
import uni from '@dcloudio/vite-plugin-uni'

export default defineConfig({
  plugins: [uni()],
  css: {
    preprocessorOptions: {
      scss: {
        // uni-app / Vite 仍走 Sass legacy JS API，静默弃用提示（不影响编译）
        silenceDeprecations: ['legacy-js-api'],
      },
    },
  },
})
