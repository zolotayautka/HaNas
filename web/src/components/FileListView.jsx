import React, { useState, useEffect, useRef } from 'react'
import { useAppContext } from '../context/AppContext'
import { useTranslation } from '../context/I18nContext'
import api from '../utils/api'
import FileItem from './FileItem'
import './FileListView.css'

function FileListView() {
  const { logout, username } = useAppContext()
  const { t } = useTranslation()
  const [currentFolder, setCurrentFolder] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)
  const [isSelectionMode, setIsSelectionMode] = useState(false)
  const [selectedNodes, setSelectedNodes] = useState(new Set())
  const [copiedNodes, setCopiedNodes] = useState([])
  const [cutNodes, setCutNodes] = useState([])
  const [showNewFolderModal, setShowNewFolderModal] = useState(false)
  const [newFolderName, setNewFolderName] = useState('')
  const [uploadProgress, setUploadProgress] = useState(null)
  const [showAccountModal, setShowAccountModal] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const fileInputRef = useRef(null)
  useEffect(() => {
    loadFolder(-1)
  }, [])
  const loadFolder = async (folderId) => {
    setIsLoading(true)
    setError(null)
    try {
      const data = await api.getNode(folderId)
      setCurrentFolder(data)
      setSelectedNodes(new Set())
      setIsSelectionMode(false)
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load folder')
    } finally {
      setIsLoading(false)
    }
  }
  const handleFileUpload = async (files) => {
    const filesArray = Array.from(files)
    const existingFiles = filesArray.filter(file => 
      currentFolder.ko?.some(node => !node.is_dir && node.name === file.name)
    )
    if (existingFiles.length > 0) {
      const fileNames = existingFiles.map(f => f.name).join(', ')
      if (!confirm(t('overwrite_confirm', { names: fileNames }))) {
        return
      }
    }
    const parentId = currentFolder.id === -1 ? null : currentFolder.id
    for (const file of filesArray) {
      try {
        setUploadProgress({ name: file.name, percent: 0 })
        await api.uploadFile(file, parentId, (percent) => {
          setUploadProgress({ name: file.name, percent })
        })
      } catch (err) {
        console.error('Upload failed:', err)
        alert(`Failed to upload ${file.name}: ${err.response?.data?.message || err.message}`)
      }
    }
    setUploadProgress(null)
    loadFolder(currentFolder.id)
  }
  const handleCreateFolder = async () => {
    if (!newFolderName.trim()) return
    
    if (currentFolder.ko?.some(node => node.is_dir && node.name === newFolderName)) {
      alert(t('folder_exists'))
      return
    }    
    try {
      await api.createFolder(
        newFolderName,
        currentFolder.id === -1 ? null : currentFolder.id
      )
      setShowNewFolderModal(false)
      setNewFolderName('')
      loadFolder(currentFolder.id)
    } catch (err) {
      console.error('Create folder failed:', err)
      console.error('Error response:', err.response?.data)
      if (err.response?.status === 409 || err.response?.data?.includes('folder_exists')) {
        alert(t('folder_exists'))
      } else {
        alert(err.response?.data?.message || t('folder_create_failed'))
      }
    }
  }
  const handleDelete = async (nodeId) => {
    if (!confirm(t('delete_confirm'))) return   
    try {
      await api.deleteNode(nodeId)
      loadFolder(currentFolder.id)
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to delete')
    }
  }
  const handleDeleteSelected = async () => {
    if (!confirm(t('delete_multiple_confirm', { count: selectedNodes.size }))) return
    try {
      for (const nodeId of selectedNodes) {
        await api.deleteNode(nodeId)
      }
      loadFolder(currentFolder.id)
    } catch (err) {
      alert('Failed to delete some items')
    }
  }
  const handleRename = async (nodeId, newName) => {
    try {
      await api.renameNode(nodeId, newName)
      loadFolder(currentFolder.id)
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to rename')
    }
  }
  const handleCopy = (node) => {
    setCopiedNodes([node])
    setCutNodes([])
  }
  const handleCut = (node) => {
    setCutNodes([node])
    setCopiedNodes([])
  }
  const handleCopySelected = () => {
    const nodes = currentFolder.ko.filter(node => selectedNodes.has(node.id))
    setCopiedNodes(nodes)
    setCutNodes([])
    setIsSelectionMode(false)
    setSelectedNodes(new Set())
  }
  const handleCutSelected = () => {
    const nodes = currentFolder.ko.filter(node => selectedNodes.has(node.id))
    setCutNodes(nodes)
    setCopiedNodes([])
    setIsSelectionMode(false)
    setSelectedNodes(new Set())
  }
  const handlePaste = async () => {
    const targetId = currentFolder.id === -1 ? null : currentFolder.id
    
    try {
      for (const node of copiedNodes) {
        await api.copyNode(node.id, targetId)
      }
      for (const node of cutNodes) {
        await api.moveNode(node.id, targetId)
      }
      setCopiedNodes([])
      setCutNodes([])
      loadFolder(currentFolder.id)
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to paste')
    }
  }
  const handleNodeClick = (node) => {
    if (isSelectionMode) {
      const newSelected = new Set(selectedNodes)
      if (newSelected.has(node.id)) {
        newSelected.delete(node.id)
      } else {
        newSelected.add(node.id)
      }
      setSelectedNodes(newSelected)
    } else if (node.is_dir) {
      loadFolder(node.id)
    }
  }
  const handleDragOver = (e) => {
    e.preventDefault()
    e.stopPropagation()
    e.dataTransfer.dropEffect = 'copy'
    setIsDragging(true)
  }
  const handleDragLeave = (e) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.target.className === 'file-list-container' || e.target.className.includes('file-list-container')) {
      setIsDragging(false)
    }
  }
  const handleDrop = async (e) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)
    const items = Array.from(e.dataTransfer.items)
    const entries = []
    for (const item of items) {
      if (item.kind === 'file') {
        const entry = item.webkitGetAsEntry()
        if (entry) {
          entries.push(entry)
        }
      }
    }
    const fileEntries = entries.filter(e => e.isFile)
    const existingFiles = fileEntries.filter(entry => 
      currentFolder.ko?.some(node => !node.is_dir && node.name === entry.name)
    )
    if (existingFiles.length > 0) {
      const fileNames = existingFiles.map(e => e.name).join(', ')
      if (!confirm(t('overwrite_confirm', { names: fileNames }))) {
        return
      }
    }
    const parentId = currentFolder.id === -1 ? null : currentFolder.id
    for (const entry of entries) {
      await processAndUploadEntry(entry, parentId)
    }
    setUploadProgress(null)
    loadFolder(currentFolder.id)
  }
  const processAndUploadEntry = async (entry, parentId) => {
    if (entry.isFile) {
      return new Promise((resolve) => {
        entry.file(async (file) => {
          try {
            setUploadProgress({ name: file.name, percent: 0 })
            await api.uploadFile(file, parentId, (percent) => {
              setUploadProgress({ name: file.name, percent })
            })
            resolve()
          } catch (err) {
            console.error('Upload failed:', err)
            alert(`Failed to upload ${file.name}: ${err.response?.data?.message || err.message}`)
            resolve()
          }
        })
      })
    } else if (entry.isDirectory) {
      try {
        const folderResponse = await api.createFolder(entry.name, parentId)
        const folderId = folderResponse.id
        const dirReader = entry.createReader()
        return new Promise((resolve) => {
          const readEntries = () => {
            dirReader.readEntries(async (entries) => {
              if (entries.length === 0) {
                resolve()
                return
              }
              for (const childEntry of entries) {
                await processAndUploadEntry(childEntry, folderId)
              }
              readEntries()
            })
          }
          readEntries()
        })
      } catch (err) {
        console.error('Create folder failed:', err)
        alert(`Failed to create folder ${entry.name}: ${err.response?.data?.message || err.message}`)
      }
    }
  }
  const toggleSelectionMode = () => {
    setIsSelectionMode(!isSelectionMode)
    if (isSelectionMode) {
      setSelectedNodes(new Set())
    }
  }
  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
        <p>{t('loading')}</p>
      </div>
    )
  }
  if (error) {
    return (
      <div className="error-container">
        <p>{error}</p>
        <button onClick={() => loadFolder(currentFolder?.id || -1)}>
          {t('retry')}
        </button>
      </div>
    )
  }
  return (
    <div 
      className={`file-list-container ${isDragging ? 'drag-over' : ''}`}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <div className="file-list-header">
        <div className="header-left">
          <h2 className="current-path">
            {currentFolder?.path || currentFolder?.name || 'Home'}
          </h2>
        </div>
        <div className="header-actions">
          <button
            className="icon-button"
            onClick={() => loadFolder(-1)}
            title="Home"
          >
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" />
            </svg>
          </button>
          {currentFolder?.oya_id && (
            <button
              className="icon-button"
              onClick={() => loadFolder(currentFolder.oya_id)}
              title="Up"
            >
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M7 14l5-5 5 5z" />
              </svg>
            </button>
          )}
          <button
            className={`icon-button ${isSelectionMode ? 'active' : ''}`}
            onClick={toggleSelectionMode}
            title="Select"
          >
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
            </svg>
          </button>
          <button
            className="icon-button"
            onClick={() => setShowAccountModal(true)}
            title="Account"
          >
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z" />
            </svg>
          </button>
        </div>
      </div>
      {isSelectionMode && selectedNodes.size > 0 && (
        <div className="selection-toolbar">
          <button className="toolbar-button" onClick={handleCopySelected}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z" />
            </svg>
            {t('copy')}
          </button>
          <button className="toolbar-button" onClick={handleCutSelected}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M9.64 7.64c.23-.5.36-1.05.36-1.64 0-2.21-1.79-4-4-4S2 3.79 2 6s1.79 4 4 4c.59 0 1.14-.13 1.64-.36L10 12l-2.36 2.36C7.14 14.13 6.59 14 6 14c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4c0-.59-.13-1.14-.36-1.64L12 14l7 7h3v-1L9.64 7.64zM6 8c-1.1 0-2-.89-2-2s.9-2 2-2 2 .89 2 2-.9 2-2 2zm0 12c-1.1 0-2-.89-2-2s.9-2 2-2 2 .89 2 2-.9 2-2 2zm6-7.5c-.28 0-.5-.22-.5-.5s.22-.5.5-.5.5.22.5.5-.22.5-.5.5zM19 3l-6 6 2 2 7-7V3z" />
            </svg>
            {t('cut')}
          </button>
          <button className="toolbar-button danger" onClick={handleDeleteSelected}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" />
            </svg>
            {t('delete')} ({selectedNodes.size})
          </button>
        </div>
      )}
      <div className="action-buttons">
        <button className="action-button primary" onClick={() => fileInputRef.current?.click()}>
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 16h6v-6h4l-7-7-7 7h4zm-4 2h14v2H5z" />
          </svg>
          {t('upload_file')}
        </button>
        <button className="action-button" onClick={() => setShowNewFolderModal(true)}>
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-1 8h-3v3h-2v-3h-3v-2h3V9h2v3h3v2z" />
          </svg>
          {t('new_folder')}
        </button>
        {(copiedNodes.length > 0 || cutNodes.length > 0) && (
          <button className="action-button" onClick={handlePaste}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 2h-4.18C14.4.84 13.3 0 12 0c-1.3 0-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm7 18H5V4h2v3h10V4h2v16z" />
            </svg>
            {t('paste')}
          </button>
        )}
        <button className="action-button" onClick={() => loadFolder(currentFolder.id)}>
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z" />
          </svg>
          {t('refresh')}
        </button>
      </div>
      <div className="file-grid">
        {currentFolder?.ko && currentFolder.ko.length > 0 ? (
          currentFolder.ko.map((node) => (
            <FileItem
              key={node.id}
              node={node}
              isSelected={selectedNodes.has(node.id)}
              isSelectionMode={isSelectionMode}
              onClick={() => handleNodeClick(node)}
              onDelete={() => handleDelete(node.id)}
              onRename={(newName) => handleRename(node.id, newName)}
              onCopy={() => handleCopy(node)}
              onCut={() => handleCut(node)}
              onRefresh={() => loadFolder(currentFolder.id)}
            />
          ))
        ) : (
          <div className="empty-folder">
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M20 6h-8l-2-2H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm0 12H4V8h16v10z" />
            </svg>
            <p>{t('empty_folder')}</p>
          </div>
        )}
      </div>
      <input
        ref={fileInputRef}
        type="file"
        multiple
        style={{ display: 'none' }}
        onChange={(e) => {
          if (e.target.files) {
            handleFileUpload(Array.from(e.target.files))
          }
        }}
      />
      {showNewFolderModal && (
        <div className="modal-overlay" onClick={() => setShowNewFolderModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>{t('new_folder')}</h3>
            <input
              type="text"
              className="form-input"
              placeholder={t('folder_name_placeholder')}
              value={newFolderName}
              onChange={(e) => setNewFolderName(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleCreateFolder()}
              autoFocus
            />
            <div className="modal-actions">
              <button className="modal-button" onClick={() => setShowNewFolderModal(false)}>
                {t('cancel')}
              </button>
              <button className="modal-button primary" onClick={handleCreateFolder}>
                {t('create')}
              </button>
            </div>
          </div>
        </div>
      )}
      {showAccountModal && (
        <div className="modal-overlay" onClick={() => setShowAccountModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div style={{ textAlign: 'center', marginBottom: '20px' }}>
              <div style={{ 
                width: '80px', 
                height: '80px', 
                borderRadius: '50%', 
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                margin: '0 auto 15px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'white'
              }}>
                <svg viewBox="0 0 24 24" fill="currentColor" style={{ width: '48px', height: '48px' }}>
                  <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                </svg>
              </div>
              <h3 style={{ margin: '0', fontSize: '20px' }}>{username || 'Unknown'}</h3>
            </div>
            <button 
              className="modal-button primary full-width" 
              onClick={async () => {
                if (confirm(t('logout_confirm'))) {
                  await logout()
                }
              }}
            >
              {t('logout')}
            </button>
            <button 
              className="modal-button danger full-width" 
              onClick={async () => {
                const password = prompt(t('delete_account_prompt'))
                if (password) {
                  try {
                    await api.deleteAccount(password)
                    await logout()
                  } catch (err) {
                    alert(err.response?.data?.message || t('delete_account_failed'))
                  }
                }
              }}
            >
              {t('delete_account')}
            </button>
            <button className="modal-button" onClick={() => setShowAccountModal(false)}>
              {t('close')}
            </button>
          </div>
        </div>
      )}
      {uploadProgress && (
        <div className="upload-toast">
          <p>{t('uploading', { name: uploadProgress.name })}</p>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${uploadProgress.percent}%` }}></div>
          </div>
          <p className="progress-text">{Math.round(uploadProgress.percent)}%</p>
        </div>
      )}
    </div>
  )
}

export default FileListView
