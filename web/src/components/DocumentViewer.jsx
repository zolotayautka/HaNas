import React from 'react'
import { useTranslation } from '../context/I18nContext'
import api from '../utils/api'
import './DocumentViewer.css'

function DocumentViewer({ node, onClose }) {
  const { t } = useTranslation()
  const isPDF = () => {
    const ext = node.name.split('.').pop()?.toLowerCase()
    return ext === 'pdf'
  }
  const isImage = () => {
    const ext = node.name.split('.').pop()?.toLowerCase()
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)
  }
  const viewUrl = api.getViewUrl(node.id)
  const downloadUrl = api.getDownloadUrl(node.id)
  return (
    <div className="document-viewer-overlay" onClick={onClose}>
      <div className="document-viewer-container" onClick={(e) => e.stopPropagation()}>
        <div className="document-viewer-header">
          <h3>{node.name}</h3>
          <button className="close-button" onClick={onClose}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
        </div>
        <div className="document-viewer-content">
          {isPDF() && (
            <iframe
              src={viewUrl}
              className="document-iframe"
              title={node.name}
              type="application/pdf"
            />
          )}
          {isImage() && (
            <img
              src={viewUrl}
              alt={node.name}
              className="document-image"
            />
          )}
        </div>
        <div className="document-viewer-actions">
          <button className="close-button-secondary" onClick={onClose}>
            {t('close')}
          </button>
          <a
            href={downloadUrl}
            download={node.name}
            className="download-button"
          >
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" />
            </svg>
            {t('download')}
          </a>
        </div>
      </div>
    </div>
  )
}

export default DocumentViewer
