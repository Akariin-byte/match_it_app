<script setup lang="ts">

import { ref } from 'vue'

import { API_BASE_URL } from '@/config'

import {

  loginOrBindPhone,

  registerWithPhone,

  sendSmsCodeForPhone,

  phoneStatus,

} from '@/api/auth'

import { useUserStore } from '@/stores/user'

import { ApiError } from '@/utils/request'



const user = useUserStore()

const phone = ref('')

const code = ref('')

const username = ref('')

const sending = ref(false)

const loading = ref(false)

const registered = ref<boolean | null>(null)

const welcomeName = ref('')



async function onSendCode() {

  if (!/^1[3-9]\d{9}$/.test(phone.value)) {

    uni.showToast({ title: '请输入正确手机号', icon: 'none' })

    return

  }

  sending.value = true

  try {

    const status = await sendSmsCodeForPhone(phone.value)

    registered.value = status.registered

    welcomeName.value = status.username?.trim() || ''

    uni.showToast({

      title: status.registered ? '验证码已发送（登录）' : '验证码已发送（绑定）',

      icon: 'none',

    })

  } catch (e: unknown) {

    const msg = e instanceof ApiError ? e.message : '发送失败'

    uni.showToast({ title: msg, icon: 'none' })

  } finally {

    sending.value = false

  }

}



async function onLogin() {

  if (!/^1[3-9]\d{9}$/.test(phone.value)) {

    uni.showToast({ title: '请输入正确手机号', icon: 'none' })

    return

  }

  if (!/^\d{4,8}$/.test(code.value)) {

    uni.showToast({ title: '请输入验证码', icon: 'none' })

    return

  }

  loading.value = true

  try {

    let session

    if (registered.value === false) {

      try {

        session = await registerWithPhone(

          phone.value,

          code.value,

          username.value || undefined,

        )

      } catch (e) {

        if (

          e instanceof ApiError &&

          (e.action === 'login' || e.message.includes('已注册'))

        ) {

          session = await loginOrBindPhone(

            phone.value,

            code.value,

            username.value || undefined,

          )

        } else {

          throw e

        }

      }

    } else {

      session = await loginOrBindPhone(

        phone.value,

        code.value,

        username.value || undefined,

      )

    }

    user.setSession(session)

    uni.showToast({ title: '登录成功', icon: 'success' })

    setTimeout(() => uni.navigateBack(), 500)

  } catch (e: unknown) {

    const msg = e instanceof ApiError ? e.message : '登录失败'

    uni.showToast({ title: msg, icon: 'none' })

  } finally {

    loading.value = false

  }

}



async function onPhoneBlur() {

  if (!/^1[3-9]\d{9}$/.test(phone.value)) return

  try {

    const status = await phoneStatus(phone.value)

    registered.value = status.registered

    welcomeName.value = status.username?.trim() || ''

  } catch {

    /* ignore */

  }

}

</script>



<template>

  <view class="page">

    <text class="hint">绑定手机号后可发布、申请组局与私信</text>

    <text v-if="registered && welcomeName" class="welcome">

      欢迎回来，{{ welcomeName }}

    </text>

    <input

      v-model="phone"

      class="input"

      type="number"

      maxlength="11"

      placeholder="手机号"

      @blur="onPhoneBlur"

    />

    <view class="row">

      <input

        v-model="code"

        class="input flex"

        type="number"

        maxlength="6"

        placeholder="验证码"

      />

      <button class="code-btn" :disabled="sending" @tap="onSendCode">

        获取验证码

      </button>

    </view>

    <input

      v-if="registered !== true"

      v-model="username"

      class="input"

      placeholder="昵称（可选）"

    />

    <button class="submit" :loading="loading" @tap="onLogin">登录</button>

    <text class="mock-tip">

      开发环境验证码填 000000（SMS_MOCK=true 时见后端日志）

    </text>

    <text class="mock-tip api-tip">API: {{ API_BASE_URL }}</text>

  </view>

</template>



<style scoped lang="scss">

.page {

  padding: 40rpx 32rpx;

}

.hint {

  display: block;

  color: #666;

  font-size: 28rpx;

  margin-bottom: 16rpx;

}

.welcome {

  display: block;

  color: #002fa7;

  font-size: 28rpx;

  margin-bottom: 24rpx;

}

.input {

  background: #fff;

  border-radius: 16rpx;

  padding: 24rpx;

  margin-bottom: 24rpx;

  font-size: 30rpx;

}

.row {

  display: flex;

  gap: 16rpx;

  margin-bottom: 24rpx;

}

.flex {

  flex: 1;

  margin-bottom: 0;

}

.code-btn {

  font-size: 26rpx;

  white-space: nowrap;

}

.submit {

  background: #002fa7;

  color: #fff;

  margin-top: 16rpx;

}

.mock-tip {

  display: block;

  margin-top: 32rpx;

  font-size: 24rpx;

  color: #999;

}

.api-tip {

  margin-top: 12rpx;

  word-break: break-all;

}

</style>

