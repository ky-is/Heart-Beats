import { cloudflare } from '@cloudflare/vite-plugin'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'node:path'
import { defineConfig } from 'vite-plus'
import { playwright } from 'vite-plus/test/browser-playwright'

export default defineConfig({
	// The Cloudflare plugin writes the output that `cf deploy` uploads; tests run without it.
	plugins: [vue(), ...(process.env.VITEST ? [] : [cloudflare()])],
	environments: {
		client: {
			build: {
				rolldownOptions: {
					input: {
						main: resolve(import.meta.dirname, 'index.html'),
						privacy: resolve(import.meta.dirname, 'privacy/index.html'),
					},
				},
			},
		},
	},
	fmt: {
		arrowParens: 'avoid',
		printWidth: 0,
		semi: false,
		singleQuote: true,
		useTabs: true,
	},
	lint: {
		jsPlugins: [{ name: 'vite-plus', specifier: 'vite-plus/oxlint-plugin' }],
		options: {
			typeAware: true,
			typeCheck: true,
		},
		rules: {
			'vite-plus/prefer-vite-plus-imports': 'error',
		},
		ignorePatterns: ['dist/**'],
	},
	test: {
		projects: [
			{
				test: {
					name: 'unit',
					include: ['test/*.test.ts'],
				},
			},
			{
				test: {
					name: 'browser',
					include: ['test/browser/*.browser.test.ts'],
					browser: {
						enabled: true,
						headless: true,
						provider: playwright(),
						instances: [{ browser: 'chromium' }],
						viewport: { width: 1000, height: 900 },
					},
				},
			},
		],
	},
})
