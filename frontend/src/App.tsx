import { useCallback, useEffect, useState } from 'react'

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL ?? 'http://localhost:3000'

// P0 frontend session persistence (REQ-GUEST-004) — separate storage keys per
// api-spec.md's own "guest/staff authentication kept structurally separate"
// principle (Phase 5B.7), so neither token can ever be read/sent as the
// other's by accident. `staff_session_email` is a display-only convenience
// (not a credential) so "Logged in as <email>" survives a refresh without a
// whoami endpoint, which this task's own scope forbids adding.
const GUEST_TOKEN_STORAGE_KEY = 'guest_active_visit_token'
const STAFF_TOKEN_STORAGE_KEY = 'staff_session_token'
const STAFF_EMAIL_STORAGE_KEY = 'staff_session_email'

function readStoredGuestToken(): string | null {
  return localStorage.getItem(GUEST_TOKEN_STORAGE_KEY)
}

function readStoredStaffSession(): { token: string; email: string } | null {
  const token = localStorage.getItem(STAFF_TOKEN_STORAGE_KEY)
  if (!token) return null
  return { token, email: localStorage.getItem(STAFF_EMAIL_STORAGE_KEY) ?? '' }
}

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

interface StaffQueueWaitingEntry {
  entry_id: number
  group_size: number
  joined_at: string
  position: number
  is_starvation_protected: boolean
}

interface StaffQueueReadyEntry {
  entry_id: number
  group_size: number
  ready_at: string
  seating_code: string
}

interface StaffQueueResponse {
  waiting: StaffQueueWaitingEntry[]
  ready: StaffQueueReadyEntry[]
}

interface StaffTableEntry {
  table_id: number
  capacity: number
  status: 'free' | 'held' | 'occupied'
  current_queue_entry_id?: number
  seating_assignment_id?: number
}

interface StaffTablesResponse {
  tables: StaffTableEntry[]
}

interface ApiErrorBody {
  error?: { type: string; message: string }
}

type GuestScreen =
  | { phase: 'recovering' }
  | { phase: 'form' }
  | { phase: 'loading' }
  | { phase: 'result'; status: CurrentStatusResponse }
  | { phase: 'error'; message: string }
  | { phase: 'recovery-error'; message: string }

async function parseJson(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    return null
  }
}

interface SeatResponse {
  entry_id: number
  status: 'seated'
  table_ids: number[]
}

// Shared by StaffSeatPanel's manual-entry form and StaffQueue's per-row
// "Seat" button — a single real POST /staff/seat implementation reused by
// both call sites (api-spec.md, already implemented/authenticated on the
// backend; this task only adds the missing frontend UI for it). Never
// fabricates success — the caller only shows "seated" after this returns ok.
async function seatByCode(token: string, seatingCode: string): Promise<{ status: number; body: unknown }> {
  const response = await fetch(`${BACKEND_URL}/staff/seat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ seating_code: seatingCode }),
  })
  return { status: response.status, body: await parseJson(response) }
}

function GuestJoin() {
  const [groupSize, setGroupSize] = useState(2)
  const [phoneNumber, setPhoneNumber] = useState('')
  const [activeVisitToken, setActiveVisitToken] = useState<string | null>(() => readStoredGuestToken())
  const [screen, setScreen] = useState<GuestScreen>(() =>
    readStoredGuestToken() ? { phase: 'recovering' } : { phase: 'form' }
  )
  const [isLeaving, setIsLeaving] = useState(false)
  const [leaveError, setLeaveError] = useState<string | null>(null)

  const isLoading = screen.phase === 'loading'

  // REQ-GUEST-004 — recover a stored active visit from the real backend, not
  // fabricated locally. A 404 (token unknown/expired) clears the stored
  // token and falls back to the Join screen; any other failure (network,
  // 5xx) keeps the token and offers a retry — a temporary outage is not
  // proof the visit is gone.
  const recoverVisit = useCallback(async (token: string) => {
    setScreen({ phase: 'recovering' })
    try {
      const response = await fetch(`${BACKEND_URL}/guest/queue-entries/current`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      const body = await parseJson(response)

      if (response.status === 404) {
        localStorage.removeItem(GUEST_TOKEN_STORAGE_KEY)
        setActiveVisitToken(null)
        setScreen({ phase: 'form' })
        return
      }

      if (!response.ok) {
        const message = (body as ApiErrorBody | null)?.error?.message
        setScreen({
          phase: 'recovery-error',
          message: message ?? `Could not recover your visit (HTTP ${response.status}).`,
        })
        return
      }

      setScreen({ phase: 'result', status: body as CurrentStatusResponse })
    } catch {
      setScreen({
        phase: 'recovery-error',
        message: 'Could not reach the server. Check your connection and try again.',
      })
    }
  }, [])

  useEffect(() => {
    const stored = readStoredGuestToken()
    if (stored) {
      recoverVisit(stored)
    }
  }, [recoverVisit])

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
      localStorage.setItem(GUEST_TOKEN_STORAGE_KEY, active_visit_token)

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

  // Deliberately does NOT clear the stored token — this button never calls
  // the real Leave API, so a still-active (waiting/ready) backend visit is
  // untouched; clearing storage here would silently orphan it on the next
  // refresh. Storage is only ever cleared by an actual Leave (below) or a
  // confirmed-invalid (404) token during recovery (functional-spec.md §3/§5
  // — "follow existing product behavior... do not invent a new guest-session
  // lifecycle").
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

      localStorage.removeItem(GUEST_TOKEN_STORAGE_KEY)
      setScreen({ phase: 'result', status: body as CurrentStatusResponse })
    } catch {
      setLeaveError('Could not reach the server. Check your connection and try again.')
    } finally {
      setIsLeaving(false)
    }
  }

  return (
    <>
      {screen.phase === 'recovering' && <p>Loading your visit…</p>}

      {screen.phase === 'recovery-error' && (
        <>
          <p role="alert" style={{ color: '#b00020' }}>
            {screen.message}
          </p>
          <button type="button" onClick={() => activeVisitToken && recoverVisit(activeVisitToken)}>
            Retry
          </button>
        </>
      )}

      {(screen.phase === 'form' || screen.phase === 'loading' || screen.phase === 'error') && (
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
  | { phase: 'authenticated'; email: string; token: string }
  | { phase: 'error'; message: string }

// P0 — completes the existing POST /staff/seat capability with the missing
// Staff UI (the backend/auth/service logic already existed and is
// unmodified by this task). A standalone manual seating_code entry — staff
// key in whatever code a guest presents, independent of whether that guest
// happens to be visible in the current Queue list. Never runs allocation:
// this only confirms an already-made reservation (functional-spec.md §6a).
function StaffSeatPanel({
  token,
  onUnauthorized,
  onSeated,
}: {
  token: string
  onUnauthorized: () => void
  onSeated: () => void
}) {
  const [code, setCode] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault()
    setIsSubmitting(true)
    setError(null)
    setMessage(null)

    try {
      const { status, body } = await seatByCode(token, code)

      if (status === 401) {
        onUnauthorized()
        return
      }

      if (status !== 200) {
        const apiMessage = (body as ApiErrorBody | null)?.error?.message
        setError(apiMessage ?? `Could not seat guest (HTTP ${status}).`)
        return
      }

      const seated = body as SeatResponse
      setMessage(`Seated entry #${seated.entry_id}.`)
      setCode('')
      onSeated()
    } catch {
      setError('Could not reach the server. Check your connection and try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div style={{ marginBottom: '1.5rem', paddingBottom: '1rem', borderBottom: '1px solid #ccc' }}>
      <h2>Seat Guest</h2>
      <form onSubmit={handleSubmit}>
        <label htmlFor="seating-code">Seating Code</label>
        <br />
        <input
          id="seating-code"
          type="text"
          required
          value={code}
          disabled={isSubmitting}
          onChange={(event) => setCode(event.target.value)}
        />{' '}
        <button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Seating…' : 'Seat'}
        </button>
      </form>
      {message && <p>{message}</p>}
      {error && (
        <p role="alert" style={{ color: '#b00020' }}>
          {error}
        </p>
      )}
    </div>
  )
}

type QueueScreen =
  | { phase: 'loading' }
  | { phase: 'loaded'; data: StaffQueueResponse }
  | { phase: 'error'; message: string }

interface NoShowResponse {
  entry_id: number
  status: 'no_show'
}

async function markNoShow(token: string, entryId: number): Promise<{ status: number; body: unknown }> {
  const response = await fetch(`${BACKEND_URL}/staff/queue/no-show`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ entry_id: entryId }),
  })
  return { status: response.status, body: await parseJson(response) }
}

// P0 REQ-STAFF-002 — a read-only-plus-actions view of GET /staff/queue,
// shown after Staff Login. Fetches on mount and whenever `refreshSignal`
// changes (bumped by the parent after any Seat/Release/No-show action
// completes anywhere in the Staff UI, including from outside this
// component) using the real session token — never a mocked response. No
// Staff Table/Release UI here (Release lives on the Tables view, next to
// the OCCUPIED rows it applies to), no live updates (P1) — a manual
// "Refresh" re-fetch is also still available.
function StaffQueue({
  token,
  onUnauthorized,
  refreshSignal,
  onActionComplete,
}: {
  token: string
  onUnauthorized: () => void
  refreshSignal: number
  onActionComplete: () => void
}) {
  const [screen, setScreen] = useState<QueueScreen>({ phase: 'loading' })
  const [actionEntryId, setActionEntryId] = useState<number | null>(null)
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  // This fetch doubles as the real backend validation of a restored Staff
  // session (no whoami endpoint exists, and this task's own scope forbids
  // adding one) — a 401 here means the token is genuinely invalid, not a
  // temporary hiccup, so it's the one status that triggers onUnauthorized
  // (clearing the stored session) rather than the generic error/retry state.
  const load = useCallback(async () => {
    setScreen({ phase: 'loading' })
    try {
      const response = await fetch(`${BACKEND_URL}/staff/queue`, {
        headers: { Authorization: `Bearer ${token}` },
      })

      if (response.status === 401) {
        onUnauthorized()
        return
      }

      const body = await parseJson(response)

      if (!response.ok) {
        const message = (body as ApiErrorBody | null)?.error?.message
        setScreen({ phase: 'error', message: message ?? `Could not load queue (HTTP ${response.status}).` })
        return
      }

      setScreen({ phase: 'loaded', data: body as StaffQueueResponse })
    } catch {
      setScreen({ phase: 'error', message: 'Could not reach the server. Check your connection and try again.' })
    }
  }, [token, onUnauthorized])

  useEffect(() => {
    load()
  }, [load, refreshSignal])

  async function handleSeat(entryId: number, seatingCode: string) {
    setActionEntryId(entryId)
    setActionMessage(null)
    setActionError(null)
    try {
      const { status, body } = await seatByCode(token, seatingCode)

      if (status === 401) {
        onUnauthorized()
        return
      }

      if (status !== 200) {
        const apiMessage = (body as ApiErrorBody | null)?.error?.message
        setActionError(apiMessage ?? `Could not seat guest (HTTP ${status}).`)
        return
      }

      setActionMessage(`Seated entry #${entryId}.`)
      onActionComplete()
      load()
    } catch {
      setActionError('Could not reach the server. Check your connection and try again.')
    } finally {
      setActionEntryId(null)
    }
  }

  async function handleNoShow(entryId: number) {
    setActionEntryId(entryId)
    setActionMessage(null)
    setActionError(null)
    try {
      const { status, body } = await markNoShow(token, entryId)

      if (status === 401) {
        onUnauthorized()
        return
      }

      if (status !== 200) {
        const apiMessage = (body as ApiErrorBody | null)?.error?.message
        setActionError(apiMessage ?? `Could not mark no-show (HTTP ${status}).`)
        return
      }

      const result = body as NoShowResponse
      setActionMessage(`Entry #${result.entry_id} marked no-show.`)
      onActionComplete()
      load()
    } catch {
      setActionError('Could not reach the server. Check your connection and try again.')
    } finally {
      setActionEntryId(null)
    }
  }

  if (screen.phase === 'loading') {
    return <p>Loading queue…</p>
  }

  if (screen.phase === 'error') {
    return (
      <>
        <p role="alert" style={{ color: '#b00020' }}>
          {screen.message}
        </p>
        <button type="button" onClick={load}>
          Retry
        </button>
      </>
    )
  }

  const { waiting, ready } = screen.data
  const isEmpty = waiting.length === 0 && ready.length === 0

  return (
    <div>
      <button type="button" onClick={load} style={{ marginBottom: '1rem' }}>
        Refresh
      </button>

      {actionMessage && <p>{actionMessage}</p>}
      {actionError && (
        <p role="alert" style={{ color: '#b00020' }}>
          {actionError}
        </p>
      )}

      {isEmpty && <p>The queue is empty.</p>}

      {!isEmpty && (
        <>
          <h2>Waiting</h2>
          {waiting.length === 0 ? (
            <p>No groups waiting.</p>
          ) : (
            <ul>
              {waiting.map((entry) => (
                <li key={entry.entry_id}>
                  #{entry.position} — Group of {entry.group_size}
                  {entry.is_starvation_protected ? ' (priority)' : ''}{' '}
                  <button
                    type="button"
                    onClick={() => handleNoShow(entry.entry_id)}
                    disabled={actionEntryId === entry.entry_id}
                  >
                    No-show
                  </button>
                </li>
              ))}
            </ul>
          )}

          <h2>Ready</h2>
          {ready.length === 0 ? (
            <p>No groups ready.</p>
          ) : (
            <ul>
              {ready.map((entry) => (
                <li key={entry.entry_id}>
                  Group of {entry.group_size} — code {entry.seating_code}{' '}
                  <button
                    type="button"
                    onClick={() => handleSeat(entry.entry_id, entry.seating_code)}
                    disabled={actionEntryId === entry.entry_id}
                  >
                    Seat
                  </button>{' '}
                  <button
                    type="button"
                    onClick={() => handleNoShow(entry.entry_id)}
                    disabled={actionEntryId === entry.entry_id}
                  >
                    No-show
                  </button>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </div>
  )
}

type TableScreen =
  | { phase: 'loading' }
  | { phase: 'loaded'; data: StaffTablesResponse }
  | { phase: 'error'; message: string }

interface ReleaseResponse {
  entry_id: number
  table_ids_released: number[]
}

async function releaseSeating(token: string, entryId: number): Promise<{ status: number; body: unknown }> {
  const response = await fetch(`${BACKEND_URL}/staff/seating-assignments/release`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ entry_id: entryId }),
  })
  return { status: response.status, body: await parseJson(response) }
}

// P0 REQ-STAFF-003 — a view of GET /staff/tables, shown after Staff Login
// alongside Staff Queue. Fetches on mount and whenever `refreshSignal`
// changes (bumped after any Seat/Release/No-show action anywhere in the
// Staff UI); a 401 here is the real backend validation of a restored Staff
// session, same as StaffQueue's own. An OCCUPIED table already carries its
// own `current_queue_entry_id` (api-spec.md), which is exactly what
// POST /staff/seating-assignments/release needs — DEC-014/INV-015 mean
// release is always by entry, never by table_id, so this button never sends
// a raw table_id anywhere. Occupancy itself is never represented from local
// state — every row always reflects the last real fetch.
function StaffTables({
  token,
  onUnauthorized,
  refreshSignal,
  onActionComplete,
}: {
  token: string
  onUnauthorized: () => void
  refreshSignal: number
  onActionComplete: () => void
}) {
  const [screen, setScreen] = useState<TableScreen>({ phase: 'loading' })
  const [actionEntryId, setActionEntryId] = useState<number | null>(null)
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setScreen({ phase: 'loading' })
    try {
      const response = await fetch(`${BACKEND_URL}/staff/tables`, {
        headers: { Authorization: `Bearer ${token}` },
      })

      if (response.status === 401) {
        onUnauthorized()
        return
      }

      const body = await parseJson(response)

      if (!response.ok) {
        const message = (body as ApiErrorBody | null)?.error?.message
        setScreen({ phase: 'error', message: message ?? `Could not load tables (HTTP ${response.status}).` })
        return
      }

      setScreen({ phase: 'loaded', data: body as StaffTablesResponse })
    } catch {
      setScreen({ phase: 'error', message: 'Could not reach the server. Check your connection and try again.' })
    }
  }, [token, onUnauthorized])

  useEffect(() => {
    load()
  }, [load, refreshSignal])

  async function handleRelease(entryId: number) {
    setActionEntryId(entryId)
    setActionMessage(null)
    setActionError(null)
    try {
      const { status, body } = await releaseSeating(token, entryId)

      if (status === 401) {
        onUnauthorized()
        return
      }

      if (status !== 200) {
        const apiMessage = (body as ApiErrorBody | null)?.error?.message
        setActionError(apiMessage ?? `Could not release table (HTTP ${status}).`)
        return
      }

      const result = body as ReleaseResponse
      setActionMessage(`Released table(s) ${result.table_ids_released.join(', ')}.`)
      onActionComplete()
      load()
    } catch {
      setActionError('Could not reach the server. Check your connection and try again.')
    } finally {
      setActionEntryId(null)
    }
  }

  if (screen.phase === 'loading') {
    return <p>Loading tables…</p>
  }

  if (screen.phase === 'error') {
    return (
      <>
        <p role="alert" style={{ color: '#b00020' }}>
          {screen.message}
        </p>
        <button type="button" onClick={load}>
          Retry
        </button>
      </>
    )
  }

  const { tables } = screen.data

  return (
    <div>
      <button type="button" onClick={load} style={{ marginBottom: '1rem' }}>
        Refresh
      </button>

      {actionMessage && <p>{actionMessage}</p>}
      {actionError && (
        <p role="alert" style={{ color: '#b00020' }}>
          {actionError}
        </p>
      )}

      {tables.length === 0 ? (
        <p>No tables found.</p>
      ) : (
        <ul>
          {tables.map((table) => (
            <li key={table.table_id}>
              Table {table.table_id} — {table.capacity} seats — {table.status.toUpperCase()}
              {table.status === 'occupied' && table.current_queue_entry_id !== undefined && (
                <>
                  {' '}
                  <button
                    type="button"
                    onClick={() => handleRelease(table.current_queue_entry_id as number)}
                    disabled={actionEntryId === table.current_queue_entry_id}
                  >
                    Release
                  </button>
                </>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

// P0 login stub only (REQ-STAFF-001) — no staff dashboard exists to unlock,
// so "authenticated" just confirms the real token was actually issued by the
// real backend. Never fakes a successful login client-side.
function StaffLogin() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  // Optimistically restored from storage as "authenticated" — StaffQueue's
  // own real GET /staff/queue fetch is what actually validates the token
  // against the backend (see its own comment); this is what avoids a
  // Login-screen flash on refresh (no whoami round trip needed first).
  const [screen, setScreen] = useState<StaffScreen>(() => {
    const stored = readStoredStaffSession()
    return stored ? { phase: 'authenticated', email: stored.email, token: stored.token } : { phase: 'form' }
  })
  const [staffView, setStaffView] = useState<'queue' | 'tables'>('queue')
  // Bumped after any Seat/Release/No-show action completes anywhere in the
  // Staff UI (StaffSeatPanel, or a row action inside StaffQueue/StaffTables)
  // so that whichever of Queue/Tables is currently visible re-fetches real
  // data — "refresh Queue/Tables from the real backend" without a state-
  // management library or lifting the queue/table data itself up here.
  const [refreshSignal, setRefreshSignal] = useState(0)
  const bumpRefresh = () => setRefreshSignal((n) => n + 1)

  const isLoading = screen.phase === 'loading'

  function clearStoredSession() {
    localStorage.removeItem(STAFF_TOKEN_STORAGE_KEY)
    localStorage.removeItem(STAFF_EMAIL_STORAGE_KEY)
  }

  function logOut() {
    clearStoredSession()
    setScreen({ phase: 'form' })
  }

  // Called by StaffQueue/StaffTables when the backend actually rejects the
  // restored token (401) — distinct from logOut only in who initiated it,
  // but kept as its own function so the call sites stay self-documenting.
  function handleUnauthorized() {
    clearStoredSession()
    setScreen({ phase: 'form' })
  }

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

      localStorage.setItem(STAFF_TOKEN_STORAGE_KEY, token)
      localStorage.setItem(STAFF_EMAIL_STORAGE_KEY, email)
      setScreen({ phase: 'authenticated', email, token })
    } catch {
      setScreen({ phase: 'error', message: 'Could not reach the server. Check your connection and try again.' })
    }
  }

  if (screen.phase === 'authenticated') {
    return (
      <div>
        <p>Logged in{screen.email ? ` as ${screen.email}` : ''}.</p>
        <button type="button" onClick={logOut}>
          Log Out
        </button>

        <StaffSeatPanel token={screen.token} onUnauthorized={handleUnauthorized} onSeated={bumpRefresh} />

        <nav style={{ marginBottom: '1rem' }}>
          <button type="button" onClick={() => setStaffView('queue')} disabled={staffView === 'queue'}>
            Queue
          </button>{' '}
          <button type="button" onClick={() => setStaffView('tables')} disabled={staffView === 'tables'}>
            Tables
          </button>
        </nav>

        <h2>{staffView === 'queue' ? 'Staff Queue' : 'Staff Tables'}</h2>
        {staffView === 'queue' ? (
          <StaffQueue
            token={screen.token}
            onUnauthorized={handleUnauthorized}
            refreshSignal={refreshSignal}
            onActionComplete={bumpRefresh}
          />
        ) : (
          <StaffTables
            token={screen.token}
            onUnauthorized={handleUnauthorized}
            refreshSignal={refreshSignal}
            onActionComplete={bumpRefresh}
          />
        )}
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
