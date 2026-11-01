import { createVaporApp } from 'vue'
import CoverWall from './components/CoverWall.vue'
import './styles/site.css'

// The covers drifting behind the top of the page and behind the closing call to download.
for (const mount of document.querySelectorAll<HTMLElement>('[data-wall]')) {
	createVaporApp(CoverWall, { rows: Number(mount.dataset.wall) || 3 }).mount(mount)
}

const motion = !matchMedia('(prefers-reduced-motion: reduce)').matches

// Runs `reveal` once, the first time `element` is mostly on screen
const onFirstView = (element: Element, reveal: () => void, threshold = 0.6) => {
	const observer = new IntersectionObserver(
		entries => {
			if (!entries.some(entry => entry.isIntersecting)) return
			observer.disconnect()
			reveal()
		},
		{ threshold },
	)
	observer.observe(element)
}
const ease = 'cubic-bezier(0.3, 0, 0.2, 1)'
// A small overshoot, like a widget settling onto the Home Screen
const spring = 'linear(0, 0.42 12%, 0.82 25%, 1.04 38%, 1.07 46%, 1.03 58%, 0.99 72%, 1)'

// Every section rises into place part by part the first time it's scrolled to. Until then the head's script keeps its parts hidden.
for (const section of document.querySelectorAll<HTMLElement>('main > section')) {
	const parts = [...section.querySelectorAll<HTMLElement>('[data-reveal]')]
	if (!parts.length) continue
	if (!motion) {
		for (const part of parts) part.dataset.reveal = 'shown'
		continue
	}
	onFirstView(
		section,
		() => {
			for (const [index, part] of parts.entries()) {
				part.dataset.reveal = 'shown'
				part.animate({ opacity: [0, 1], translate: ['0 28px', '0 0'] }, { duration: 700, delay: index * 120, easing: 'cubic-bezier(0.2, 0.7, 0.2, 1)', fill: 'backwards' })
			}
			section.dispatchEvent(new CustomEvent('revealed', { detail: parts.length * 120 }))
		},
		0.15,
	)
}

// Artists, genres, years: pointing at a tab (or tapping, or the arrow keys) shows its panel.
const views = document.querySelector<HTMLElement>('.views')
if (views) {
	const tabs = [...views.querySelectorAll<HTMLButtonElement>('[role="tab"]')]
	const show = (tab: HTMLButtonElement) => {
		views.dataset.view = tab.dataset.view
		for (const other of tabs) {
			other.setAttribute('aria-selected', String(other === tab))
			other.tabIndex = other === tab ? 0 : -1
		}
	}
	// With motion, nothing is selected until the section comes in, then the highlight slides onto Artists
	if (motion && tabs[0]) {
		delete views.dataset.view
		for (const tab of tabs) tab.setAttribute('aria-selected', 'false')
		views.addEventListener(
			'revealed',
			event => {
				setTimeout(() => {
					if (!views.dataset.view) show(tabs[0]!)
				}, (event as CustomEvent<number>).detail + 300)
			},
			{ once: true },
		)
	}
	for (const [index, tab] of tabs.entries()) {
		tab.addEventListener('pointerenter', event => {
			if (event.pointerType !== 'touch') show(tab)
		})
		tab.addEventListener('click', () => show(tab))
		tab.addEventListener('keydown', event => {
			const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
			const next = tabs[(index + step + tabs.length) % tabs.length]
			if (!step || !next) return
			event.preventDefault()
			show(next)
			next.focus()
		})
	}
}

// The minimum songs controls, like the app's: − and + (held, they keep going) hide the artists or genres with fewer songs than the number.

for (const minimum of document.querySelectorAll<HTMLElement>('.minimum')) {
	const list = minimum.closest('.list')!
	const grid = list.querySelector<HTMLElement>('.tiles')!
	const tiles = [...grid.querySelectorAll<HTMLElement>('[data-songs]')]
	const songs = (tile: HTMLElement) => Number(tile.dataset.songs)
	const output = minimum.querySelector('output')!
	const [fewer, more] = [...minimum.querySelectorAll<HTMLButtonElement>('[data-step]')]
	// Capped like the app's stepper, at 99 or the largest group
	const largest = Math.min(Number(minimum.dataset.cap) || 99, Math.max(...tiles.map(songs)))
	for (const [index, tile] of tiles.entries()) tile.style.viewTransitionName = `${list.parentElement!.id}-${index}`
	let value = Number(minimum.dataset.minimum)
	const apply = () => {
		output.value = String(value)
		fewer!.disabled = value <= 1
		more!.disabled = value >= largest
		for (const tile of tiles) tile.hidden = songs(tile) < value
	}
	const step = (by: number) => {
		const next = Math.min(largest, Math.max(1, value + by))
		if (next === value) return false
		value = next
		const changes = tiles.some(tile => tile.hidden !== songs(tile) < value)
		if (changes && motion && document.startViewTransition) document.startViewTransition(apply)
		else apply()
		return true
	}
	let timer: ReturnType<typeof setTimeout> | undefined
	const stop = () => clearTimeout(timer)
	for (const button of [fewer!, more!]) {
		const by = Number(button.dataset.step)
		button.addEventListener('pointerdown', event => {
			if (event.button !== 0) return
			event.preventDefault()
			// Keeps the press while the card grows or shrinks and the button moves out from under the pointer
			button.setPointerCapture(event.pointerId)
			stop()
			if (!step(by)) return
			const repeat = (delay: number) => {
				timer = setTimeout(() => {
					if (step(by)) repeat(Math.max(40, delay * 0.8))
				}, delay)
			}
			repeat(400)
		})
		for (const end of ['pointerup', 'pointercancel', 'lostpointercapture']) button.addEventListener(end, stop)
		// Keyboard and assistive tech press the button without a pointer
		button.addEventListener('click', event => {
			if (event.detail === 0) step(by)
		})
	}
	apply()
}

// The Siri request cycles through the top artists: each name slides up and out as the next comes in.
const asked = document.querySelector<HTMLElement>('.bubble [data-names]')
const cycleArtists = () => {
	if (!asked) return
	const names = asked.dataset.names!.split(', ')
	let index = 0
	setInterval(async () => {
		if (document.hidden) return
		index = (index + 1) % names.length
		const timing = { duration: 260, easing: ease, fill: 'forwards' } as const
		await asked.animate({ opacity: [1, 0], translate: ['0 0', '0 -0.5em'], filter: ['blur(0)', 'blur(3px)'] }, timing).finished
		asked.textContent = names[index]!
		asked.animate({ opacity: [0, 1], translate: ['0 0.5em', '0 0'], filter: ['blur(3px)', 'blur(0)'] }, timing)
	}, 2600)
}

// The Siri requests pop in one after the other and fill in word by word, as if spoken, the first time they're scrolled to.
const bubbles = [...document.querySelectorAll<HTMLElement>('.bubble')]
if (bubbles.length && motion) {
	const words = bubbles.map(bubble => {
		const parts: HTMLElement[] = []
		// A copy, since the text nodes are replaced along the way
		for (const node of Array.from(bubble.childNodes)) {
			if (node instanceof HTMLElement) {
				// The artist's name comes in whole
				parts.push(node)
				continue
			}
			const pieces = (node.textContent ?? '').split(/(\s+)/)
			node.replaceWith(
				...pieces.map(piece => {
					if (!piece || /^\s+$/.test(piece)) return piece
					const word = document.createElement('span')
					word.className = 'word'
					word.textContent = piece
					parts.push(word)
					return word
				}),
			)
		}
		return parts
	})
	for (const element of [...bubbles, ...words.flat()]) element.style.opacity = '0'
	onFirstView(bubbles[0]!.parentElement!, () => {
		let delay = 0
		for (const [index, bubble] of bubbles.entries()) {
			bubble.style.opacity = ''
			bubble.animate({ opacity: [0, 1], scale: [0.85, 1] }, { duration: 420, delay, easing: spring, fill: 'backwards' })
			delay += 200
			for (const word of words[index]!) {
				word.style.opacity = ''
				word.animate({ opacity: [0, 1], translate: ['0 0.3em', '0 0'], filter: ['blur(4px)', 'blur(0)'] }, { duration: 300, delay, easing: ease, fill: 'backwards' })
				delay += 110
			}
			delay += 250
		}
		setTimeout(cycleArtists, delay + 1400)
	})
} else if (motion) cycleArtists()

// The widget tilts a few degrees toward the pointer and catches the light where it is.
const widget = document.querySelector<HTMLElement>('.widget')
if (widget && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
	const tilt = 5
	widget.addEventListener('pointermove', event => {
		if (event.pointerType === 'touch') return
		const box = widget.getBoundingClientRect()
		const x = (event.clientX - box.left) / box.width
		const y = (event.clientY - box.top) / box.height
		widget.style.setProperty('--mx', `${x * 100}%`)
		widget.style.setProperty('--rx', String((x - 0.5) * 2 * tilt))
		widget.style.setProperty('--ry', String((0.5 - y) * 2 * tilt))
	})
	widget.addEventListener('pointerleave', () => {
		for (const name of ['--mx', '--rx', '--ry']) widget.style.removeProperty(name)
	})
}


// The widget drops onto the page like one added to the Home Screen, then its covers fill in, the first time it's scrolled to.
const addedWidget = document.querySelector<HTMLElement>('.widget')
if (addedWidget && motion) {
	const covers = [...addedWidget.querySelectorAll<HTMLElement>('.w-row > span')]
	for (const element of [addedWidget, ...covers]) element.style.opacity = '0'
	onFirstView(addedWidget, () => {
		for (const element of [addedWidget, ...covers]) element.style.opacity = ''
		addedWidget.animate({ opacity: [0, 1, 1], scale: [0.55, 1], translate: ['0 -18px', '0 0'] }, { duration: 700, easing: spring, fill: 'backwards' })
		for (const [index, cover] of covers.entries()) {
			cover.animate({ opacity: [0, 1], scale: [0.7, 1] }, { duration: 420, delay: 380 + index * 90, easing: spring, fill: 'backwards' })
		}
	})
}
