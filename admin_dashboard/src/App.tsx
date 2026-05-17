import './App.css'
import { useEffect, useState, type FormEvent } from 'react'
import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL ?? ''
const key = import.meta.env.VITE_SUPABASE_ANON_KEY ?? ''
const client = url && key ? createClient(url, key) : null

type Row = Record<string, unknown>

function App() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [sessionEmail, setSessionEmail] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [properties, setProperties] = useState<Row[]>([])
  const [users, setUsers] = useState<Row[]>([])

  useEffect(() => {
    if (!client) return
    void client.auth.getSession().then(({ data }) => {
      const u = data.session?.user?.email
      setSessionEmail(u ?? null)
    })
    const { data } = client.auth.onAuthStateChange((_event, sess) => {
      setSessionEmail(sess?.user.email ?? null)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  async function refreshData() {
    if (!client) return
    setBusy(true)
    setError(null)
    try {
      const { data: p, error: e1 } = await client.from('properties').select('*').order('name').limit(200)
      const { data: u, error: e2 } = await client
        .from('users')
        .select('id, email, role, first_name, last_name, created_at')
        .order('created_at', { ascending: false })
        .limit(200)
      if (e1) throw e1
      if (e2) throw e2
      setProperties(p ?? [])
      setUsers(u ?? [])
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  useEffect(() => {
    if (sessionEmail && client) void refreshData()
    else {
      setProperties([])
      setUsers([])
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- refresh once per session toggle
  }, [sessionEmail])

  async function onSignIn(e: FormEvent) {
    e.preventDefault()
    if (!client) {
      setError('Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY.')
      return
    }
    setBusy(true)
    setError(null)
    const { error: signErr } = await client.auth.signInWithPassword({ email, password })
    if (signErr) setError(signErr.message)
    setBusy(false)
  }

  async function signOut() {
    if (!client) return
    await client.auth.signOut()
  }

  if (!client) {
    return (
      <div className="wrap">
        <h1>Valet Admin</h1>
        <p className="err">
          Configure <code>.env</code> with Vite variables (copy from <code>.env.example</code>).
        </p>
      </div>
    )
  }

  return (
    <div className="wrap">
      <header>
        <div>
          <h1>Valet Admin</h1>
          <p className="sub">
            Operational snapshot from Supabase — visibility follows Row Level Security (use{' '}
            <code>super_admin</code> or <code>property_manager</code> where policies allow).
          </p>
        </div>
        {sessionEmail ? (
          <div className="auth">
            <span>{sessionEmail}</span>
            <button type="button" onClick={() => void signOut()} disabled={busy}>
              Sign out
            </button>
          </div>
        ) : null}
      </header>

      {!sessionEmail ? (
        <form className="card" onSubmit={onSignIn}>
          <h2>Sign in</h2>
          <label>
            Email
            <input
              value={email}
              onChange={(evt) => setEmail(evt.target.value)}
              type="email"
              required
              autoComplete="username"
            />
          </label>
          <label>
            Password
            <input
              value={password}
              onChange={(evt) => setPassword(evt.target.value)}
              type="password"
              required
              autoComplete="current-password"
            />
          </label>
          {error ? <p className="err">{error}</p> : null}
          <button type="submit" disabled={busy}>
            {busy ? '…' : 'Sign in'}
          </button>
        </form>
      ) : (
        <>
          <div className="toolbar">
            <button type="button" onClick={() => void refreshData()} disabled={busy}>
              Refresh
            </button>
          </div>
          {error ? <p className="err">{error}</p> : null}

          <section className="grid">
            <div className="card">
              <h2>Properties ({properties.length})</h2>
              <div className="table">
                {properties.map((prop) => (
                  <div key={String(prop.id)} className="row">
                    <strong>{String(prop.name ?? '')}</strong>
                    <span className="mono">{String(prop.id ?? '').slice(0, 8)}…</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="card">
              <h2>Users ({users.length})</h2>
              <div className="table">
                {users.map((u) => (
                  <div key={String(u.id)} className="row">
                    <span>{String(u.email ?? '')}</span>
                    <span className="pill">{String(u.role ?? '')}</span>
                  </div>
                ))}
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  )
}

export default App
