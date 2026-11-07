module main

import css
import dom
import os
import platform

fn install_browser_document_font_policies(mut document dom.Document) {
	if os.getenv('LADYBIRD_LAYOUT_TEST_FONT') != '' {
		document.set_font_size_keyword_policy(.libweb)
		document.set_font_rendering_policy(.libweb)
	} else {
		document.set_font_size_keyword_policy(.chromium)
		document.set_font_rendering_policy(.chromium)
	}
}

fn native_retained_font_smoothing(smoothing css.FontSmoothing, font &platform.Font) int {
	// The low nibble carries CSS FontSmoothing. Bit 4 selects Chromium's
	// coverage rules; the native bridge can add bit 5 for an opaque backdrop.
	// Bit 6 permits synthetic slant; bit 7 prohibits synthetic weight.
	if font.font_rendering_policy == .chromium {
		return int(smoothing) | 16 |
			if font.italic && font.font_synthesis_disabled & platform.font_synthesis_style_disabled == 0 {
				64
			} else {
				0
			} |
			if font.font_synthesis_disabled & platform.font_synthesis_weight_disabled != 0 {
				128
			} else {
				0
			}
	}
	return int(smoothing)
}
