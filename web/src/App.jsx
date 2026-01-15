import React, { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import LoginView from './components/LoginView'
import FileListView from './components/FileListView'
import { AppProvider, useAppContext } from './context/AppContext'
import { I18nProvider } from './context/I18nContext'
import './App.css'

function AppContent() {
  const { isAuthenticated, checkAuthentication } = useAppContext()
  const [isLoading, setIsLoading] = useState(true)
  useEffect(() => {
    checkAuthentication().finally(() => setIsLoading(false))
  }, [])
  if (isLoading) {
    return (
      <div className="loading-screen">
        <div className="spinner"></div>
        <p>Loading...</p>
      </div>
    )
  }
  return (
    <Routes>
      <Route
        path="/login"
        element={!isAuthenticated ? <LoginView /> : <Navigate to="/" />}
      />
      <Route
        path="/"
        element={isAuthenticated ? <FileListView /> : <Navigate to="/login" />}
      />
    </Routes>
  )
}

function App() {
  return (
    <BrowserRouter>
      <I18nProvider>
        <AppProvider>
          <AppContent />
        </AppProvider>
      </I18nProvider>
    </BrowserRouter>
  )
}

export default App
