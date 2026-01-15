import axios from 'axios'

const BACKEND_URL = window.APP_CONFIG?.BACKEND_URL
const API_BASE_URL = import.meta.env.DEV ? '/api' : BACKEND_URL

class HaNasAPI {
  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
      withCredentials: true,
    })
  }

  async login(username, password) {
    const response = await this.client.post('/login', { username, password })
    return response.data
  }

  async register(username, password) {
    const response = await this.client.post('/register', { username, password })
    return response.data
  }

  async logout() {
    await this.client.post('/logout')
  }

  async me() {
    const response = await this.client.get('/me')
    return response.data
  }

  async deleteAccount(password) {
    const response = await this.client.post('/delete-account', { password })
    return response.data
  }

  async getNode(id = -1) {
    const response = await this.client.get(`/node/${id}`)
    return response.data
  }

  async createFolder(name, oyaId = null) {
    const response = await this.client.post('/upload', {
      filename: name,
      is_dir: true,
      oya_id: oyaId,
    })
    return { id: response.data.node_id, name: response.data.name }
  }

  async uploadFile(file, oyaId = null, onProgress = null) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('filename', file.name)
    if (oyaId !== null) {
      formData.append('oya_id', oyaId)
    }
    const response = await this.client.post('/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (onProgress && progressEvent.total) {
          const percentCompleted = Math.round(
            (progressEvent.loaded * 100) / progressEvent.total
          )
          onProgress(percentCompleted)
        }
      },
    })
    return response.data
  }

  async deleteNode(id) {
    const response = await this.client.post('/delete', { src_id: id })
    return response.data
  }

  async renameNode(id, newName) {
    const response = await this.client.post('/rename', {
      src_id: id,
      new_name: newName,
    })
    return response.data
  }

  async moveNode(id, targetOyaId) {
    const response = await this.client.post('/move', {
      src_id: id,
      dst_id: targetOyaId,
    })
    return response.data
  }

  async copyNode(id, targetOyaId) {
    const response = await this.client.post('/copy', {
      src_id: id,
      dst_id: targetOyaId,
    })
    return response.data
  }

  async createShareLink(nodeId) {
    const response = await this.client.post('/share/create', { node_id: nodeId })
    return response.data
  }

  async deleteShare(nodeId) {
    const response = await this.client.post('/share/delete', { node_id: nodeId })
    return response.data
  }

  getDownloadUrl(nodeId) {
    return `${API_BASE_URL}/file/${nodeId}`
  }

  getViewUrl(nodeId) {
    return `${API_BASE_URL}/file/${nodeId}?inline=1`
  }

  getThumbnailUrl(nodeId) {
    return `${API_BASE_URL}/thumbnail/${nodeId}`
  }

  getShareUrl(token) {
    return `${BACKEND_URL}/s/${token}`
  }
}

export default new HaNasAPI()
