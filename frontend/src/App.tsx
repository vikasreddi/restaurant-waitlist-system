import { useState } from 'react'

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL ?? 'http://localhost:3000'

// Matches documents/05-specifications/api-spec.md exactly. Neither `position`
// nor `seating_code` is ever returned by the join response itself (DEC-005 /
// Phase 5B.3) — they only exist on GET /guest/queue-entries/current, so a
// truthful UI has to make that second call rather than inventing the value.
interface JoinResponse {
  entry_id: number
  active_visit_token: string
  status: 'waiting' | 'ready'
}

interface CurrentStatusResponse {
  entry_id?: number
  status: 'waiting' | 'ready' | 'seated' | 'left' | 'no_show'
  position?: number
  seating_code?: string
}

interface StaffLoginResponse {
  token: string
}

interface ApiErrorBody {
  error?: { type: string; message: string }
}

type GuestScreen =
  | { phase: 'form' }
  | { phase: 'loading' }
  | { phase: 'result'; status: CurrentStatusResponse }
  | { phase: 'error'; message: string }

async function parseJson(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    return null
  }
}

function GuestJoin() {
  const [groupSize, setGroupSize] = useState(2)
  const [phoneNumber, setPhoneNumber] = useState('')
  const [screen, setScreen] = useState<GuestScreen>({ phase: 'form' })
  const [activeVisitToken, setActiveVisitToken] = useState<string | null>(null)
  const [isLeaving, setIsLeaving] = useState(false)
  const [leaveError, setLeaveError] = useState<string | null>(null)

  const isLoading = screen.phase === 'loading'

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault()
    setScreen({ phase: 'loading' })

    try {
      const joinResponse = await fetch(`${BACKEND_URL}/guest/queue-entries`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          group_size: groupSize,
          phone_number: phoneNumber,
          idempotency_key: crypto.randomUUID(),
        }),
      })
      const joinBody = await parseJson(joinResponse)

      if (!joinResponse.ok) {
        const message = (joinBody as ApiErrorBody | null)?.error?.message
        setScreen({ phase: 'error', message: message ?? `Join failed (HTTP ${joinResponse.status}).` })
        return
      }

      const { active_visit_token } = joinBody as JoinResponse
      setActiveVisitToken(active_visit_token)

      // The join response only ever says "waiting" or "ready" — the actual
      // position/seating_code live on the current-status endpoint, so we
      // fetch it to show the guest their real state, not a guessed one.
      const currentResponse = await fetch(`${BACKEND_URL}/guest/queue-entries/current`, {
        headers: { Authorization: `Bearer ${active_visit_token}` },
      })
      const currentBody = await parseJson(currentResponse)

      if (!currentResponse.ok) {
        const message = (currentBody as ApiErrorBody | null)?.error?.message
        setScreen({ phase: 'error', message: message ?? `Could not load status (HTTP ${currentResponse.status}).` })
        return
      }

      setScreen({ phase: 'result', status: currentBody as CurrentStatusResponse })
    } catch {
      setScreen({ phase: 'error', message: 'Could not reach the server. Check your connection and try again.' })
    }
  }

  function reset() {
    setScreen({ phase: 'form' })
    setActiveVisitToken(null)
    setLeaveError(null)
  }

  // Uses the real leave endpoint (functional-spec.md §3, api-spec.md) —
  // never fabricates the resulting status. The response's own `status` is
  // rendered as-is, so an already-terminal-for-another-reason visit (e.g.
  // seated) shows its real state rather than being forced to "left".
  async function handleLeave() {
    if (!activeVisitToken) return
    setIsLeaving(true)
    setLeaveError(null)

    try {
      const response = await fetch(`${BACKEND_URL}/guest/queue-entries/current/leave`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${activeVisitToken}` },
      })
      const body = await parseJson(response)

      if (!response.ok) {
        const message = (body as ApiErrorBody | null)?.error?.message
        setLeaveError(message ?? `Could not leave (HTTP ${response.status}).`)
        return
      }

      setScreen({ phase: 'result', status: body as CurrentStatusResponse })
    } catch {
      setLeaveError('Could not reach the server. Check your connection and try again.')
    } finally {
      setIsLeaving(false)
    }
  }

  return (
    <>
      {screen.phase !== 'result' && (
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '1rem' }}>
            <label htmlFor="group-size">Group Size</label>
            <br />
            <input
              id="group-size"
              type="number"
              min={1}
              required
              value={groupSize}
              disabled={isLoading}
              onChange={(event) => setGroupSize(Number(event.target.value))}
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label htmlFor="phone-number">Phone Number</label>
            <br />
            <input
              id="phone-number"
              type="tel"
              required
              value={phoneNumber}
              disabled={isLoading}
              onChange={(event) => setPhoneNumber(event.target.value)}
            />
          </div>

          <button type="submit" disabled={isLoading}>
            {isLoading ? 'Joining…' : 'Join Queue'}
          </button>
        </form>
      )}

      {screen.phase === 'error' && (
        <p role="alert" style={{ color: '#b00020' }}>
          {screen.message}
        </p>
      )}

      {screen.phase === 'result' && (
        <div>
          {screen.status.status === 'waiting' && (
            <>
              <p>Status: WAITING</p>
              <p>Position: {screen.status.position}</p>
            </>
          )}
          {screen.status.status === 'ready' && (
            <>
              <p>Status: READY</p>
              <p>Seating code: {screen.status.seating_code}</p>
            </>
          )}
          {(screen.status.status === 'seated' ||
            screen.status.status === 'left' ||
            screen.status.status === 'no_show') && <p>Status: {screen.status.status.toUpperCase()}</p>}

          {(screen.status.status === 'waiting' || screen.status.status === 'ready') && (
            <button type="button" onClick={handleLeave} disabled={isLeaving}>
              {isLeaving ? 'Leaving…' : 'Leave Queue'}
            </button>
          )}

          {leaveError && (
            <p role="alert" style={{ color: '#b00020' }}>
              {leaveError}
            </p>
          )}

          <div style={{ marginTop: '0.5rem' }}>
            <button type="button" onClick={reset}>
              Start Over
            </button>
          </div>
        </div>
      )}
    </>
  )
}

type StaffScreen =
  | { phase: 'form' }
  | { phase: 'loading' }
  | { phase: 'authenticated'; email: string }
  | { phase: 'error'; message: string }

// P0 login stub only (REQ-STAFF-001) — no staff dashboard exists to unlock,
// so "authenticated" just confirms the real token was actually issued by the
// real backend. Never fakes a successful login client-side.
function StaffLogin() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [screen, setScreen] = useState<StaffScreen>({ phase: 'form' })

  const isLoading = screen.phase === 'loading'

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault()
    setScreen({ phase: 'loading' })

    try {
      const response = await fetch(`${BACKEND_URL}/staff/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })
      const body = await parseJson(response)

      if (!response.ok) {
        const message = (body as ApiErrorBody | null)?.error?.message
        setScreen({ phase: 'error', message: message ?? `Login failed (HTTP ${response.status}).` })
        return
      }

      const { token } = body as StaffLoginResponse
      if (!token) {
        setScreen({ phase: 'error', message: 'Login succeeded but no session token was returned.' })
        return
      }

      setScreen({ phase: 'authenticated', email })
    } catch {
      setScreen({ phase: 'error', message: 'Could not reach the server. Check your connection and try again.' })
    }
  }

  if (screen.phase === 'authenticated') {
    return (
      <div>
        <p>Logged in as {screen.email}.</p>
        <button type="button" onClick={() => setScreen({ phase: 'form' })}>
          Log Out
        </button>
      </div>
    )
  }

  return (
    <>
      <form onSubmit={handleSubmit}>
        <div style={{ marginBottom: '1rem' }}>
          <label htmlFor="staff-email">Email</label>
          <br />
          <input
            id="staff-email"
            type="email"
            required
            value={email}
            disabled={isLoading}
            onChange={(event) => setEmail(event.target.value)}
          />
        </div>

        <div style={{ marginBottom: '1rem' }}>
          <label htmlFor="staff-password">Password</label>
          <br />
          <input
            id="staff-password"
            type="password"
            required
            value={password}
            disabled={isLoading}
            onChange={(event) => setPassword(event.target.value)}
          />
        </div>

        <button type="submit" disabled={isLoading}>
          {isLoading ? 'Logging in…' : 'Login'}
        </button>
      </form>

      {screen.phase === 'error' && (
        <p role="alert" style={{ color: '#b00020' }}>
          {screen.message}
        </p>
      )}
    </>
  )
}

function App() {
  const [view, setView] = useState<'guest' | 'staff'>('guest')

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: '2rem' }}>
      <h1>Restaurant Waitlist</h1>

      <nav style={{ marginBottom: '1.5rem' }}>
        <button type="button" onClick={() => setView('guest')} disabled={view === 'guest'}>
          Guest
        </button>{' '}
        <button type="button" onClick={() => setView('staff')} disabled={view === 'staff'}>
          Staff Login
        </button>
      </nav>

      {view === 'guest' ? <GuestJoin /> : <StaffLogin />}
    </main>
  )
}

export default App
