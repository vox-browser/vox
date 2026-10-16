module platform

// The embedder can select Blink-compatible HTML font geometry while keeping
// translated LibWeb fixtures on their original metrics and shaping precision.
pub enum FontRenderingPolicy {
	libweb
	chromium
}

pub fn (font &Font) shaping_resolution() f32 {
	return if font.font_rendering_policy == .chromium { f32(65536) } else { f32(64) }
}
