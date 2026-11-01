// Cuts each artist's album art out of the Mac App Store screenshot (the artists grid) as a rounded WebP with a transparent corner, in public/covers.
// Also fetches the album art for a few genres' covers that no artist in the screenshots has (EXTRA, by Apple Music album id).
// Needs ImageMagick. Run again if the screenshot changes: pnpm run covers
import { execFileSync } from 'node:child_process'
import { mkdirSync } from 'node:fs'
import { resolve } from 'node:path'
import { ARTISTS } from '../src/data/artists.ts'

const source = resolve(import.meta.dirname, '../../fastlane/screenshots/en-US/Mac-1-artists.jpg')
const output = resolve(import.meta.dirname, '../public/covers')
mkdirSync(output, { recursive: true })

// The grid is nine tiles wide; each tile is 288 pixels across, 320 apart horizontally and 358.6 vertically, starting at 16, 205.
// Cutting 8 pixels in from every edge, with a corner a little rounder than the app's own, keeps the screenshot's own corner and shadow out of the result.
const columns = 9
const size = 272
const radius = 30
const final = 278
for (const [index, artist] of ARTISTS.entries()) {
	const x = Math.round(16 + 8 + (index % columns) * 319.7)
	const y = Math.round(205 + 8 + Math.floor(index / columns) * 358.6)
	execFileSync('magick', [source, '-crop', `${size}x${size}+${x}+${y}`, '+repage', '(', '-size', `${size}x${size}`, 'xc:black', '-fill', 'white', '-draw', `roundrectangle 0,0 ${size - 1},${size - 1} ${radius},${radius}`, ')', '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', '-resize', `${final}x${final}`, '-quality', '75', '-define', 'webp:method=6', '-define', 'webp:alpha-quality=80', resolve(output, `${artist.id}.webp`)])
}

// Album art from the iTunes lookup API, masked like the cut-out covers.
const EXTRA = [
	{ id: 'satie', album: 694083664 },
	{ id: 'gould', album: 594521223 },
	{ id: 'vivaldi', album: 693711974 },
]
for (const { id, album } of EXTRA) {
	const lookup = await (await fetch(`https://itunes.apple.com/lookup?id=${album}&entity=album`)).json()
	const art = await (await fetch(lookup.results[0].artworkUrl100.replace('100x100bb', '600x600bb'))).arrayBuffer()
	const file = resolve(output, `${id}.webp`)
	execFileSync('magick', ['-', '-resize', `${size}x${size}!`, '(', '-size', `${size}x${size}`, 'xc:black', '-fill', 'white', '-draw', `roundrectangle 0,0 ${size - 1},${size - 1} ${radius},${radius}`, ')', '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', '-resize', `${final}x${final}`, '-quality', '75', '-define', 'webp:method=6', '-define', 'webp:alpha-quality=80', file], { input: Buffer.from(art) })
}
console.log(`${ARTISTS.length + EXTRA.length} covers`)
