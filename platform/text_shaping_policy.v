module platform

// LibWeb shapes in 26.6 fixed point. Blink uses 16.16, retaining fractional
// advances before accumulating a run. Keep the translated default explicit.
pub enum TextShapingPolicy {
	libweb
	chromium
}

pub fn (font &Font) shaping_resolution() f32 {
	return if font.text_shaping_policy == .chromium { f32(65536) } else { f32(64) }
}
