import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync } from 'node:fs'

// version.txt is the single source of truth for the app version. It is read at
// build time (both locally and in CI) and injected into the client bundle.
const version = readFileSync('./version.txt', 'utf-8').trim()

// BASE_PATH is provided by the CI workflow so assets resolve under the
// per-environment subfolder of the GitHub Pages site (e.g. /repo/staging/).
// Locally it defaults to '/'.
export default defineConfig({
  plugins: [react()],
  base: process.env.BASE_PATH || '/',
  define: {
    'import.meta.env.VITE_APP_VERSION': JSON.stringify(version),
  },
})
