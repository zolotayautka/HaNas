import React, { useEffect, useRef } from 'react'
import { useTranslation } from '../context/I18nContext'
import api from '../utils/api'
import './MediaPlayer.css'

function MediaPlayer({ node, onClose }) {
  const { t } = useTranslation()
  const videoRef = useRef(null)
  const audioRef = useRef(null)
  useEffect(() => {
    if (videoRef.current) {
      videoRef.current.play().catch(() => {})
    }
    if (audioRef.current) {
      audioRef.current.play().catch(() => {})
    }
  }, [])
  const isVideo = () => {
    const ext = node.name.split('.').pop()?.toLowerCase()
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].includes(ext)
  }
  const isAudio = () => {
    const ext = node.name.split('.').pop()?.toLowerCase()
    return ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'].includes(ext)
  }
  const downloadUrl = api.getDownloadUrl(node.id)
  return (
    <div className="media-player-overlay" onClick={onClose}>
      <div className="media-player-container" onClick={(e) => e.stopPropagation()}>
        <div className="media-player-header">
          <h3>{node.name}</h3>
          <button className="close-button" onClick={onClose}>
            <svg viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
        </div>
        <div className="media-player-content">
          {isVideo() && (
            <video
              ref={videoRef}
              controls
              controlsList="nodownload"
              className="media-video"
            >
              <source src={downloadUrl} />
              Your browser does not support the video tag.
            </video>
          )}
          {isAudio() && (
            <div className="audio-player-wrapper">
              <div className="audio-icon">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                </svg>
              </div>
              <audio
                ref={audioRef}
                controls
                controlsList="nodownload"
                className="media-audio"
              >
                <source src={downloadUrl} />
                Your browser does not support the audio tag.
              </audio>
            </div>
          )}
        </div>
        <div className="media-player-actions">
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

export default MediaPlayer
