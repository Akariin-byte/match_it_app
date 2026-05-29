import { getDeviceId } from '@/utils/device-id'

import {

  ApiError,

  getToken,

  parseAuthResponse,

  request,

} from '@/utils/request'

import type { AuthSession } from '@/types/api'



export type PhoneStatus = {

  registered: boolean

  username?: string

}



/** 微信登录（M2：需后端 POST /auth/wechat-login） */

export async function wechatLogin(code: string): Promise<AuthSession> {

  const json = await request<Record<string, unknown>>('/api/v1/auth/wechat-login', {

    method: 'POST',

    data: { code },

  })

  return parseAuthResponse(json)

}



/** 游客登录（开发 / 未配置微信时兜底） */

export async function guestLogin(username?: string): Promise<AuthSession> {

  const data: Record<string, string> = { device_id: getDeviceId() }

  if (username?.trim()) data.username = username.trim()

  const json = await request<Record<string, unknown>>('/api/v1/auth/guest-login', {

    method: 'POST',

    data,

  })

  return parseAuthResponse(json)

}



const skipWechatLogin =

  import.meta.env.VITE_SKIP_WECHAT_LOGIN === 'true' ||

  import.meta.env.VITE_SKIP_WECHAT_LOGIN === true



export async function loginWithWechatOrGuest(): Promise<AuthSession> {

  if (!skipWechatLogin) {

    // #ifdef MP-WEIXIN

    try {

      const loginRes = await new Promise<UniApp.LoginRes>((resolve, reject) => {

        uni.login({ provider: 'weixin', success: resolve, fail: reject })

      })

      if (loginRes.code) {

        return await wechatLogin(loginRes.code)

      }

    } catch {

      // 游客模式 / 未配置 wechat-login / 网络失败时回落游客

    }

    // #endif

  }

  return guestLogin()

}



/** 查询手机号是否已注册 */

export async function phoneStatus(phone: string): Promise<PhoneStatus> {

  const json = await request<Record<string, unknown>>('/api/v1/auth/phone-status', {

    method: 'POST',

    data: { phone },

  })

  return {

    registered: Boolean(json.registered),

    username: json.username as string | undefined,

  }

}



/** 发送验证码（scene: bind | login，与 Flutter 一致） */

export async function sendSmsCode(

  phone: string,

  scene: 'bind' | 'login',

): Promise<void> {

  await request('/api/v1/auth/send-code', {

    method: 'POST',

    data: { phone, scene },

  })

}



/** 按手机号状态自动选择 bind / login 场景发码 */

export async function sendSmsCodeForPhone(phone: string): Promise<PhoneStatus> {

  const status = await phoneStatus(phone)

  await sendSmsCode(phone, status.registered ? 'login' : 'bind')

  return status

}



/** 已注册手机号登录 */

export async function loginWithPhone(

  phone: string,

  verificationCode: string,

): Promise<AuthSession> {

  const json = await request<Record<string, unknown>>('/api/v1/auth/login', {

    method: 'POST',

    data: {

      phone,

      verification_code: verificationCode,

      device_id: getDeviceId(),

    },

  })

  return parseAuthResponse(json)

}



/** 游客绑定手机号（需游客 Token） */

export async function bindPhone(

  phone: string,

  verificationCode: string,

  username?: string,

): Promise<AuthSession> {

  const data: Record<string, string> = {

    phone,

    verification_code: verificationCode,

  }

  if (username?.trim()) data.username = username.trim()

  const json = await request<Record<string, unknown>>('/api/v1/auth/bind-phone', {

    method: 'POST',

    data,

    header: { Authorization: `Bearer ${getToken()}` },

  })

  return parseAuthResponse(json)

}



/** 新手机号注册 */

export async function registerWithPhone(

  phone: string,

  verificationCode: string,

  username?: string,

): Promise<AuthSession> {

  const data: Record<string, string> = {

    phone,

    verification_code: verificationCode,

    device_id: getDeviceId(),

  }

  if (username?.trim()) data.username = username.trim()

  const json = await request<Record<string, unknown>>('/api/v1/auth/register', {

    method: 'POST',

    data,

  })

  return parseAuthResponse(json)

}



/** 游客升级 / 已注册号自动走 login（与 Flutter loginOrBindPhone 对齐） */

export async function loginOrBindPhone(

  phone: string,

  verificationCode: string,

  username?: string,

): Promise<AuthSession> {

  if (!getToken()) {

    await guestLogin()

  }

  try {

    return await bindPhone(phone, verificationCode, username)

  } catch (e) {

    if (

      e instanceof ApiError &&

      (e.action === 'login' ||

        e.message.includes('已注册') ||

        e.message.includes('registered'))

    ) {

      return loginWithPhone(phone, verificationCode)

    }

    throw e

  }

}

/** 退出登录（可选传 refresh_token 作废刷新令牌） */
export async function logout(refreshToken?: string): Promise<void> {
  const data: Record<string, string> = {}
  if (refreshToken?.trim()) data.refresh_token = refreshToken.trim()
  await request('/api/v1/auth/logout', { method: 'POST', data })
}

