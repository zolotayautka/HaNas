import React, { useState } from 'react'
import { useAppContext } from '../context/AppContext'
import { useTranslation } from '../context/I18nContext'
import './LoginView.css'

function LoginView() {
  const { login, register } = useAppContext()
  const { t } = useTranslation()
  const [isRegisterMode, setIsRegisterMode] = useState(false)
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const handleSubmit = async (e) => {
    e.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    try {
      const success = isRegisterMode
        ? await register(username, password)
        : await login(username, password)
      if (!success) {
        setErrorMessage(
          isRegisterMode ? t('register_failed') : t('login_failed')
        )
      }
    } catch (error) {
      if (error.response?.status === 401) {
        setErrorMessage(t('login_invalid_credentials'))
      } else if (error.response?.status === 409) {
        setErrorMessage(t('register_duplicate_id'))
      } else {
        setErrorMessage(
          error.response?.data?.message || t('connection_error')
        )
      }
    } finally {
      setIsLoading(false)
    }
  }
  const toggleMode = () => {
    setIsRegisterMode(!isRegisterMode)
    setErrorMessage('')
  }
  return (
    <div className="login-container">
      <div className="login-content">
        <div className="login-header">
          <div className="app-icon">
            <img src="/apple-touch-icon.png" alt="HaNas" />
          </div>
          <h1 className="app-name">{t('app_name')}</h1>
          <p className="app-subtitle">
            {isRegisterMode ? t('register_title') : t('login_title')}
          </p>
        </div>
        <form className="login-form" onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">{t('username')}</label>
            <input
              type="text"
              className="form-input"
              placeholder={t('username_placeholder')}
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              required
            />
          </div>
          <div className="form-group">
            <label className="form-label">{t('password')}</label>
            <input
              type="password"
              className="form-input"
              placeholder={t('password_placeholder')}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={isRegisterMode ? 'new-password' : 'current-password'}
              required
            />
          </div>
          {errorMessage && (
            <div className="error-message">{errorMessage}</div>
          )}
          <button
            type="submit"
            className="submit-button"
            disabled={isLoading || !username || !password}
          >
            {isLoading ? (
              <div className="button-spinner"></div>
            ) : (
              isRegisterMode ? t('register_button') : t('login_button')
            )}
          </button>
          <button
            type="button"
            className="toggle-mode-button"
            onClick={toggleMode}
          >
            {isRegisterMode
              ? t('switch_to_login')
              : t('switch_to_register')}
          </button>
        </form>
      </div>
    </div>
  )
}

export default LoginView
