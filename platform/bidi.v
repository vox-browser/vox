module platform

import vunicode

pub fn bidi_paragraph_levels(text []u16, rtl bool) []u8 {
	return vunicode.bidi_levels(vunicode.decode_utf16(text), rtl)
}

pub fn bidi_visual_order(levels []u8) []int { return vunicode.visual_order(levels) }
