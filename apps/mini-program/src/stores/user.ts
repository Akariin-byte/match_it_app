import { defineStore } from 'pinia'
import { loginWithWechatOrGuest, logout as apiLogout } from '@/api/auth'
import { API_BASE_URL } from '@/config'
import {
  clearSession,
  loadSession,
  saveSession,
} from '@/utils/request'
import type { AuthSession } from '@/types/api'

export const useUserStore = defineStore('user', {
  state: () => ({
    session: null as AuthSession | null,
    bootstrapping: false,
    ready: false,
    bootstrapError: null as string | null,
  }),

  getters: {
    isLoggedIn: (s) => !!s.session,
    isGuest: (s) => !s.session || s.session.isGuest,
    displayName: (s) => {
      if (!s.session) return '游客'
      const name = s.session.username?.trim()
      if (name && name !== '游客') return name
      return s.session.isGuest ? '游客' : '用户'
    },
    token: (s) => s.session?.token || '',
  },

  actions: {
    async bootstrap() {
      if (this.bootstrapping) return
      this.bootstrapping = true
      this.bootstrapError = null
      try {
        const cached = loadSession()
        if (cached?.token) {
          this.session = cached
          return
        }
        const session = await loginWithWechatOrGuest()
        this.setSession(session)
      } catch (e) {
        console.error('bootstrap failed', e)
        this.bootstrapError =
          '无法连接后端，请先在本机启动 API（默认 ' + API_BASE_URL + '）'
        uni.showToast({
          title: '请先启动后端服务',
          icon: 'none',
          duration: 3000,
        })
      } finally {
        this.bootstrapping = false
        this.ready = true
      }
    },

    setSession(session: AuthSession) {
      this.session = session
      saveSession(session)
    },

    async logout() {
      const refresh = this.session?.refreshToken
      try {
        if (this.session?.token) {
          await apiLogout(refresh)
        }
      } catch (e) {
        console.warn('logout api failed', e)
      }
      this.session = null
      clearSession()
      try {
        const session = await loginWithWechatOrGuest()
        this.setSession(session)
      } catch {
        /* 游客登录失败时保持未登录 */
      }
      uni.showToast({ title: '已退出登录', icon: 'none' })
      uni.switchTab({ url: '/pages/feed/index' })
    },

    requireRegistered(): boolean {
      if (!this.session?.isGuest) return true
      uni.navigateTo({ url: '/pages/login/index' })
      return false
    },
  },
})
