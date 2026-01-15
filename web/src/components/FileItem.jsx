import React, { useState } from 'react'
import { useTranslation } from '../context/I18nContext'
import api from '../utils/api'
import MediaPlayer from './MediaPlayer'
import DocumentViewer from './DocumentViewer'
import NodeInfoModal from './NodeInfoModal'
import './FileItem.css'

function FileItem({ node, isSelected, isSelectionMode, onClick, onDelete, onRename, onCopy, onCut, onRefresh }) {
  const { t } = useTranslation()
  const [showMenu, setShowMenu] = useState(false)
  const [showRenameModal, setShowRenameModal] = useState(false)
  const [newName, setNewName] = useState(node.name)
  const [showMediaPlayer, setShowMediaPlayer] = useState(false)
  const [showDocumentViewer, setShowDocumentViewer] = useState(false)
  const [showNodeInfo, setShowNodeInfo] = useState(false)
  const handleRename = () => {
    if (newName.trim() && newName !== node.name) {
      onRename(newName)
    }
    setShowRenameModal(false)
  }
  const handleCreateShare = async () => {
    try {
      const response = await api.createShareLink(node.id)
      const shareUrl = api.getShareUrl(response.token)
      let clipboardSuccess = false
      try {
        await navigator.clipboard.writeText(shareUrl)
        clipboardSuccess = true
      } catch (e) {
        window.prompt(t('share_link_copied'), shareUrl)
      }
      alert(t('share_link_copied'))
      if (onRefresh) onRefresh()
    } catch (err) {
      alert(t('share_link_failed'))
    }
    setShowMenu(false)
  }
  const handleCopyShareLink = async () => {
    if (!node.share_token) return
    const shareUrl = api.getShareUrl(node.share_token)
    await navigator.clipboard.writeText(shareUrl)
    alert(t('share_link_copied'))
    setShowMenu(false)
  }
  const handleDeleteShare = async () => {
    try {
      await api.deleteShare(node.id)
      alert(t('share_link_deleted'))
      if (onRefresh) onRefresh()
    } catch (err) {
      alert(t('share_delete_failed'))
    }
    setShowMenu(false)
  }
  const handleDownload = () => {
    window.open(api.getDownloadUrl(node.id), '_blank')
    setShowMenu(false)
  }
  const isMediaFile = () => {
    if (node.is_dir) return false
    const ext = node.name.split('.').pop()?.toLowerCase()
    const mediaExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', 'mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac']
    return mediaExts.includes(ext)
  }
  const isDocumentFile = () => {
    if (node.is_dir) return false
    const ext = node.name.split('.').pop()?.toLowerCase()
    const docExts = ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg']
    return docExts.includes(ext)
  }
  const handlePreview = () => {
    if (isMediaFile()) {
      setShowMediaPlayer(true)
    } else if (isDocumentFile()) {
      setShowDocumentViewer(true)
    } else {
      handleDownload()
    }
    setShowMenu(false)
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
    if (imageExts.includes(ext) || videoExts.includes(ext)) {
      const fallbackIcon = videoExts.includes(ext) ? (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z" />
        </svg>
      )
      return (
        <>
          <img 
            src={api.getThumbnailUrl(node.id)} 
            alt={node.name}
            className="file-thumbnail"
            onError={(e) => {
              e.target.style.display = 'none'
              const fallback = e.target.nextElementSibling
              if (fallback) fallback.style.display = 'block'
            }}
          />
          <div className="file-thumbnail-fallback" style={{ display: 'none' }}>
            {fallbackIcon}
          </div>
        </>
      )
    }
    if (audioExts.includes(ext)) {
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
  const formatFileSize = (bytes) => {
    if (!bytes) return ''
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB'
  }
  const handleClick = (e) => {
    if (e.target.closest('.file-menu-button')) {
      return
    }
    if (isSelectionMode) {
      if (onClick) {
        onClick(node)
      }
      return
    }
    if (!node.is_dir) {
      if (isMediaFile()) {
        setShowMediaPlayer(true)
        return
      } else if (isDocumentFile()) {
        setShowDocumentViewer(true)
        return
      } else {
        window.open(api.getDownloadUrl(node.id), '_blank')
        return
      }
    }
    if (onClick) {
      onClick(node)
    }
  }
  return (
    <>
      <div
        className={`file-item ${isSelected ? 'selected' : ''} ${node.is_dir ? 'folder' : 'file'}`}
        onClick={handleClick}
        onContextMenu={(e) => {
          e.preventDefault()
          setShowMenu(true)
        }}
      >
        {isSelected && (
          <div className="selection-indicator">
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
            </svg>
          </div>
        )}
        <div className="file-icon">{getFileIcon()}</div>
        <div className="file-name">{node.name}</div>
        <button
          className="file-menu-button"
          onClick={(e) => {
            e.stopPropagation()
            setShowMenu(true)
          }}
        >
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z" />
          </svg>
        </button>
      </div>
      {showMenu && (
        <div className="menu-overlay" onClick={() => setShowMenu(false)}>
          <div className="context-menu" onClick={(e) => e.stopPropagation()}>
            {!node.is_dir && (
              <>
                <button className="menu-item" onClick={handlePreview}>
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z" />
                  </svg>
                  {isMediaFile() ? t('play') : t('view')}
                </button>
                <button className="menu-item" onClick={handleDownload}>
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" />
                  </svg>
                  {t('download')}
                </button>
              </>
            )}
            <button
              className="menu-item"
              onClick={() => {
                setShowNodeInfo(true)
                setShowMenu(false)
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
              </svg>
              {t('info')}
            </button>
            <button
              className="menu-item"
              onClick={() => {
                onCopy()
                setShowMenu(false)
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z" />
              </svg>
              {t('copy')}
            </button>
            <button
              className="menu-item"
              onClick={() => {
                onCut()
                setShowMenu(false)
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M9.64 7.64c.23-.5.36-1.05.36-1.64 0-2.21-1.79-4-4-4S2 3.79 2 6s1.79 4 4 4c.59 0 1.14-.13 1.64-.36L10 12l-2.36 2.36C7.14 14.13 6.59 14 6 14c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4c0-.59-.13-1.14-.36-1.64L12 14l7 7h3v-1L9.64 7.64z" />
              </svg>
              {t('cut')}
            </button>
            <button
              className="menu-item"
              onClick={() => {
                setShowRenameModal(true)
                setShowMenu(false)
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z" />
              </svg>
              {t('rename')}
            </button>
            {!node.is_dir && (
              <>
                {node.share_token ? (
                  <>
                    <button className="menu-item" onClick={handleCopyShareLink}>
                      <svg viewBox="0 0 24 24" fill="currentColor">
                        <path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z" />
                      </svg>
                      {t('share_copy')}
                    </button>
                    <button className="menu-item" onClick={handleDeleteShare}>
                      <svg viewBox="0 0 24 24" fill="currentColor">
                        <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
                      </svg>
                      {t('share_remove')}
                    </button>
                  </>
                ) : (
                  <button className="menu-item" onClick={handleCreateShare}>
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92 1.61 0 2.92-1.31 2.92-2.92s-1.31-2.92-2.92-2.92z" />
                    </svg>
                    {t('share_create')}
                  </button>
                )}
              </>
            )}
            <button
              className="menu-item danger"
              onClick={() => {
                onDelete()
                setShowMenu(false)
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" />
              </svg>
              {t('delete')}
            </button>
          </div>
        </div>
      )}
      {showRenameModal && (
        <div className="menu-overlay" onClick={() => setShowRenameModal(false)}>
          <div className="rename-modal" onClick={(e) => e.stopPropagation()}>
            <h3>{t('rename')}</h3>
            <input
              type="text"
              className="rename-input"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleRename()}
              autoFocus
            />
            <div className="rename-actions">
              <button onClick={() => setShowRenameModal(false)}>{t('cancel')}</button>
              <button className="primary" onClick={handleRename}>
                {t('ok')}
              </button>
            </div>
          </div>
        </div>
      )}
      {showMediaPlayer && (
        <MediaPlayer node={node} onClose={() => setShowMediaPlayer(false)} />
      )}
      {showDocumentViewer && (
        <DocumentViewer node={node} onClose={() => setShowDocumentViewer(false)} />
      )}
      {showNodeInfo && (
        <NodeInfoModal node={node} onClose={() => setShowNodeInfo(false)} />
      )}
    </>
  )
}

export default FileItem
