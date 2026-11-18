module imageraster

import cpuraster

// GG's portable image pipeline expects straight RGBA. Canvas surfaces retain
// premultiplied channels; convert a copy so script-visible pixels stay intact.
pub fn unpremultiply_canvas_rgba(pixels []u8) []u8 {
	return cpuraster.unpremultiply_canvas_rgba(pixels)
}
