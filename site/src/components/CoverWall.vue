<script setup vapor lang="ts">
import { ARTISTS } from '../data/artists.ts'

const props = defineProps<{ rows: number }>()

/// Each row slides sideways, in alternating directions, and shows the covers twice so it can loop without a jump.
const perRow = Math.ceil(ARTISTS.length / 2)
const strips = Array.from({ length: props.rows }, (_, row) => {
	const start = (row * 7) % ARTISTS.length
	const covers = Array.from({ length: perRow }, (_, index) => ARTISTS[(start + index) % ARTISTS.length]!)
	return { covers: [...covers, ...covers], reverse: row % 2 === 1, seconds: 70 + row * 14 }
})
</script>

<template>
	<div class="wall" aria-hidden="true">
		<div v-for="(strip, row) in strips" :key="row" class="strip" :class="{ reverse: strip.reverse }" :style="{ '--seconds': `${strip.seconds}s` }">
			<img v-for="(cover, index) in strip.covers" :key="index" :src="`/covers/${cover.id}.webp`" alt="" width="278" height="278" decoding="async" />
		</div>
	</div>
</template>
