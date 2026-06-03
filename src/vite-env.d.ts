/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_AWS_KEY: string
  readonly VITE_AWS_SECRET: string
  readonly VITE_S3_BUCKET: string
  readonly VITE_APP_ENV: string
  readonly VITE_APP_VERSION: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
