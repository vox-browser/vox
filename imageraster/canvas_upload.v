module imageraster

// GG's portable image pipeline expects straight RGBA. Canvas surfaces retain
// premultiplied channels; convert a copy so script-visible pixels stay intact.
pub fn unpremultiply_canvas_rgba(pixels []u8) []u8 {
	if pixels.len % 4 != 0 { return []u8{} }
	mut result := pixels.clone()
	for offset := 0; offset < result.len; offset += 4 {
		alpha := int(result[offset + 3])
		if alpha == 255 { continue }
		for channel in 0 .. 3 {
			value := if alpha == 0 { 0 } else { (int(result[offset + channel]) * 255 + alpha / 2) / alpha }
			result[offset + channel] = u8(if value > 255 { 255 } else { value })
		}
	}
	return result
}
