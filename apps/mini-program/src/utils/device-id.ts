const STORAGE_KEY = 'matchit_device_id'

function randomId(): string {
  return 'mp_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10)
}

export function getDeviceId(): string {
  let id = uni.getStorageSync(STORAGE_KEY) as string
  if (!id) {
    id = randomId()
    uni.setStorageSync(STORAGE_KEY, id)
  }
  return id
}
