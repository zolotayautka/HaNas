import React from 'react'
import { useTranslation } from '../context/I18nContext'
import './NodeInfoModal.css'

function NodeInfoModal({ node, onClose }) {
  const { t } = useTranslation()
  const formatFileSize = (bytes) => {
    if (!bytes) return '0 B'
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB'
  }
  const formatDate = (dateString) => {
    const date = new Date(dateString)
    return date.toLocaleString()
  }
  const getFileIcon = () => {
    if (node.is_dir) {
      return (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z" />
        </svg>
      )
    }
    const ext = node.name.split('.').pop()?.toLowerCase()
    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v']
    const audioExts = ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac']
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'md']
    if (imageExts.includes(ext)) {
      return (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z" />
        </svg>
      )
    } else if (videoExts.includes(ext)) {
      return (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z" />
        </svg>
      )
    } else if (audioExts.includes(ext)) {
      return (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
        </svg>
      )
    } else if (docExts.includes(ext)) {
      return (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z" />
        </svg>
      )
    }
    return (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M6 2c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6H6zm7 7V3.5L18.5 9H13z" />
      </svg>
    )
  }
  return (
    <div className="node-info-overlay" onClick={onClose}>
      <div className="node-info-modal" onClick={(e) => e.stopPropagation()}>
        <div className="node-info-header">
          <h3>Info</h3>
          <button className="close-button" onClick={onClose}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
        </div>
        <div className="node-info-content">
          <div className="node-info-icon">
            {getFileIcon()}
          </div>
          <div className="node-info-details">
            <div className="info-row">
              <span className="info-label">Name</span>
              <span className="info-value">{node.name}</span>
            </div>
            <div className="info-row">
              <span className="info-label">Type</span>
              <span className="info-value">{node.is_dir ? 'Folder' : 'File'}</span>
            </div>
            {node.size !== undefined && (
              <div className="info-row">
                <span className="info-label">Size</span>
                <span className="info-value">{formatFileSize(node.size)}</span>
              </div>
            )}
            {node.updated_at && (
              <div className="info-row">
                <span className="info-label">Modified</span>
                <span className="info-value">{formatDate(node.updated_at)}</span>
              </div>
            )}
            {node.path && (
              <div className="info-row">
                <span className="info-label">Path</span>
                <span className="info-value">{node.path}</span>
              </div>
            )}
          </div>
        </div>
        <div className="node-info-actions">
          <button className="modal-button primary" onClick={onClose}>
            OK
          </button>
        </div>
      </div>
    </div>
  )
}

export default NodeInfoModal
