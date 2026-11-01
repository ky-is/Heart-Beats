// Draws the 1200x630 link preview (public/og.png): the app icon and name over a tilted wall of album covers.
// Needs ImageMagick and uses the SF Rounded font that ships with macOS. Run again if the covers or the name change: pnpm run og
import { execFileSync } from 'node:child_process'
import { resolve } from 'node:path'
import { ARTISTS } from '../src/data/artists.ts'

const site = resolve(import.meta.dirname, '..')
const covers = (offset: number) => Array.from({ length: 7 }, (_, index) => resolve(site, `public/covers/${ARTISTS[(offset + index * 3) % ARTISTS.length]!.id}.webp`))
const magick = (...args: string[]) => execFileSync('magick', args)

// Three rows of covers, each shifted so the rows don't line up, then tilted.
const rows = [0, 1, 2].map((offset, row) => {
	const file = resolve(site, `node_modules/.og-row-${row}.png`)
	magick(...covers(offset).flatMap(cover => ['(', cover, '-resize', '190x190', ')']), '-background', 'none', '-splice', '0x0', '+smush', '14', file)
	return file
})
const wall = resolve(site, 'node_modules/.og-wall.png')
magick(...rows, '-background', 'none', '-smush', '14', '-background', 'none', '-rotate', '-8', wall)

const font = '/System/Library/Fonts/SFNSRounded.ttf'
magick(
	'-size', '1200x630', 'gradient:#fff4f2-#f6dde0',
	wall, '-gravity', 'east', '-geometry', '+0+0', '-composite',
	// A fade from the page color on the left, so the text stays readable over the covers.
	'(', '-size', '1200x630', 'xc:#fff4f2', '(', '-size', '630x1200', 'gradient:white-black', '-level', '30%,52%', '-rotate', '-90', ')', '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', ')', '-compose', 'over', '-composite',
	'(', resolve(site, 'public/icon.png'), '-resize', '150x150', ')', '-gravity', 'northwest', '-geometry', '+84+96', '-composite',
	'-font', font, '-fill', '#1d1416', '-stroke', '#1d1416', '-strokewidth', '3', '-pointsize', '104', '-gravity', 'northwest', '-annotate', '+84+280', 'Heart Beats',
	'-stroke', 'none', '-strokewidth', '0', '-fill', '#6c5a5e', '-pointsize', '40', '-annotate', '+88+410', 'Playlists from the songs\nyou already love.',
	'-depth', '8', '-strip', '-define', 'png:compression-level=9',
	resolve(site, 'public/og.png'),
)
// Palette-quantized and recompressed: about a quarter of the size, with no visible banding.
const og = resolve(site, 'public/og.png')
execFileSync('pngquant', ['--quality=85-98', '--speed', '1', '--strip', '--force', '--output', og, og])
execFileSync('oxipng', ['-o', 'max', '--strip', 'all', '-q', og])
console.log('og.png')
