import React, { createContext, useContext, useState } from 'react'
import api from '../utils/api'

const AppContext = createContext()

export const useAppContext = () => {
  const context = useContext(AppContext)
  if (!context) {
    throw new Error('useAppContext must be used within AppProvider')
  }
  return context
}

export const AppProvider = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [username, setUsername] = useState(() => {
    return localStorage.getItem('username') || null
  })
  const checkAuthentication = async () => {
    try {
      const userInfo = await api.me()
      setIsAuthenticated(true)
      if (userInfo.username) {
        setUsername(userInfo.username)
        localStorage.setItem('username', userInfo.username)
      }
    } catch (error) {
      setIsAuthenticated(false)
      setUsername(null)
      localStorage.removeItem('username')
    }
  }
  const login = async (username, password) => {
    const response = await api.login(username, password)
    if (response.success) {
      setIsAuthenticated(true)
      const serverUsername = response.username || username
      setUsername(serverUsername)
      localStorage.setItem('username', serverUsername)
      return true
    }
    return false
  }
  const register = async (username, password) => {
    const response = await api.register(username, password)
    if (response.success) {
      setIsAuthenticated(true)
      const serverUsername = response.username || username
      setUsername(serverUsername)
      localStorage.setItem('username', serverUsername)
      return true
    }
    return false
  }
  const logout = async () => {
    await api.logout()
    setIsAuthenticated(false)
    setUsername(null)
    localStorage.removeItem('username')
  }
  return (
    <AppContext.Provider
      value={{
        isAuthenticated,
        username,
        checkAuthentication,
        login,
        register,
        logout,
      }}
    >
      {children}
    </AppContext.Provider>
  )
}
