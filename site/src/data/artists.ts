/// The artists in the App Store screenshots' music library, in the order the app's grid shows them, with the number of favorited and 5-star songs each has.
export interface Artist {
	id: string
	name: string
	songs: number
}

export const ARTISTS: Artist[] = [
	{ id: 'album-leaf', name: 'The Album Leaf', songs: 20 },
	{ id: 'deafheaven', name: 'Deafheaven', songs: 21 },
	{ id: 'bon-iver', name: 'Bon Iver', songs: 25 },
	{ id: 'death-cab', name: 'Death Cab for Cutie', songs: 59 },
	{ id: 'belle-sebastian', name: 'Belle & Sebastian', songs: 51 },
	{ id: 'car-seat-headrest', name: 'Car Seat Headrest', songs: 18 },
	{ id: 'the-national', name: 'The National', songs: 61 },
	{ id: 'bob-marley', name: 'Bob Marley & The Wailers', songs: 33 },
	{ id: 'decemberists', name: 'The Decemberists', songs: 52 },
	{ id: 'postal-service', name: 'The Postal Service', songs: 19 },
	{ id: 'sigur-ros', name: 'Sigur Rós', songs: 30 },
	{ id: 'beach-house', name: 'Beach House', songs: 50 },
	{ id: 'polo-pan', name: 'Polo & Pan', songs: 16 },
	{ id: 'indigo-la-end', name: 'indigo la End', songs: 37 },
	{ id: 'chopin', name: 'Frédéric Chopin', songs: 22 },
	{ id: 'stromae', name: 'Stromae', songs: 15 },
	{ id: 'lost-frequencies', name: 'Lost Frequencies', songs: 23 },
	{ id: 'sufjan-stevens', name: 'Sufjan Stevens', songs: 16 },
	{ id: 'toe', name: 'Toe', songs: 34 },
	{ id: 'yelle', name: 'Yelle', songs: 26 },
]
