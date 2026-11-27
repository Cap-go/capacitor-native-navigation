/** Shared flag for example builds and `cap sync` (set `VITE_WEB_NATIVE_UI_ENGINE=true` for both). */
export const webNativeUIEngineFromEnv = () => process.env.VITE_WEB_NATIVE_UI_ENGINE === 'true';