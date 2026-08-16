import { useEffect, useState } from 'react'

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL ?? 'http://localhost:3000'

type BackendStatus = 'checking' | 'connected' | 'unreachable'

function App() {
  const [backendStatus, setBackendStatus] = useState<BackendStatus>('checking')

  useEffect(() => {
    let cancelled = false

    fetch(`${BACKEND_URL}/health`)
      .then((response) => {
        if (!response.ok) throw new Error(`Backend responded with ${response.status}`)
        return response.json()
      })
      .then((data) => {
        if (!cancelled) {
          setBackendStatus(data?.status === 'ok' ? 'connected' : 'unreachable')
        }
      })
      .catch(() => {
        if (!cancelled) setBackendStatus('unreachable')
      })

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: '2rem' }}>
      <h1>Restaurant Waitlist</h1>
      <p>Frontend: running</p>
      <p>
        Backend:{' '}
        {backendStatus === 'checking' && 'checking…'}
        {backendStatus === 'connected' && 'connected'}
        {backendStatus === 'unreachable' && 'unreachable'}
      </p>
    </main>
  )
}

export default App
