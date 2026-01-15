import React, { createContext, useContext, useState, useEffect } from 'react'
import en from '../locales/en.json'
import ko from '../locales/ko.json'
import ja from '../locales/ja.json'

const translations = { en, ko, ja }

const I18nContext = createContext()

export const useTranslation = () => {
  const context = useContext(I18nContext)
  if (!context) {
    throw new Error('useTranslation must be used within I18nProvider')
  }
  return context
}

export const I18nProvider = ({ children }) => {
  const [language, setLanguage] = useState(() => {
    const saved = localStorage.getItem('language')
    if (saved && translations[saved]) {
      return saved
    }
    const browserLang = navigator.language.toLowerCase()
    if (browserLang.startsWith('ko')) return 'ko'
    if (browserLang.startsWith('ja')) return 'ja'
    return 'en'
  })
  useEffect(() => {
    localStorage.setItem('language', language)
    document.documentElement.lang = language
  }, [language])
  const t = (key, params = {}) => {
    let text = translations[language][key] || translations['en'][key] || key
    Object.keys(params).forEach(param => {
      text = text.replace(`{${param}}`, params[param])
    })
    return text
  }
  return (
    <I18nContext.Provider value={{ t, language, setLanguage }}>
      {children}
    </I18nContext.Provider>
  )
}
