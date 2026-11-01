/// <reference types="vite-plus/client" />

// For the linter's type checker, which doesn't read .vue files; vue-tsc uses the real component types.
declare module '*.vue' {
	import type { VaporComponent } from 'vue'
	const component: VaporComponent
	export default component
}
