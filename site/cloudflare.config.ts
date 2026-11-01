// Serves the built site (dist) on heartbeats.ky.is as Workers static assets.
// Deploy with: pnpm run deploy
import { bindings, defineConfig } from 'cf/config'

export default defineConfig({
	worker: {
		name: 'heart-beats',
		compatibilityDate: '2026-10-23',
		domains: ['heartbeats.ky.is'],
		env: { ASSETS: bindings.assets() },
	},
})
