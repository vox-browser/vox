module main

import css
import platform

fn native_retained_font_smoothing(smoothing css.FontSmoothing, font &platform.Font) int {
	// The low nibble carries CSS FontSmoothing. Bit 4 selects Chromium's
	// coverage rules; the native bridge can add bit 5 for an opaque backdrop.
	if font.font_rendering_policy == .chromium {
		return int(smoothing) | 16 | if font.italic { 64 } else { 0 }
	}
	return int(smoothing)
}
