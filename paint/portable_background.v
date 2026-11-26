module main

import painting

struct PortableBackgroundTextClip {
	bounds painting.IntRect
	pixels []u8
}

fn (clip &PortableBackgroundTextClip) alpha_at(x int, y int) u8 {
	if !clip.bounds.contains(painting.IntPoint{x, y}) {
		return 0
	}
	return clip.pixels[((y - clip.bounds.y) * clip.bounds.width + x - clip.bounds.x) * 4 + 3]
}
