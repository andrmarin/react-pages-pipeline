import './index.css'

function show(value: string | undefined): string {
  return value && value.length > 0 ? value : '(not set)'
}

export default function App() {
  const env = import.meta.env

  return (
    <main className="card">
      <h1>Demo App</h1>
      <p>Hello from the demo app 👋</p>
      <p className="feature">Feature A</p>

      <dl>
        <dt>Version</dt>
        <dd>{show(env.VITE_APP_VERSION)}</dd>

        <dt>Environment</dt>
        <dd>{show(env.VITE_APP_ENV)}</dd>

        <dt>AWS_KEY</dt>
        <dd>{show(env.VITE_AWS_KEY)}</dd>

        <dt>AWS_SECRET</dt>
        <dd>{show(env.VITE_AWS_SECRET)}</dd>

        <dt>S3_BUCKET</dt>
        <dd>{show(env.VITE_S3_BUCKET)}</dd>
      </dl>

      {/*
        SECURITY NOTE: every VITE_* value above is embedded into the static
        JavaScript bundle at build time and is therefore PUBLICLY VISIBLE in
        the browser to anyone who opens the page. The values here are
        placeholder demo data only. A real secret must NEVER be exposed this
        way — AWS_SECRET is wired through a GitHub Actions *secret* purely to
        demonstrate the secrets plumbing, not to keep it hidden on the client.
      */}
    </main>
  )
}
