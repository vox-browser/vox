module platform

import vunicode

pub enum TextCaseTransform {
	uppercase
	lowercase
	titlecase
}

pub fn transform_text_case(text string, locale string, transform TextCaseTransform) string {
	points := text.runes().map(u32(it))
	mapped := transform_text_case_with_edits(vunicode.encode_utf16(points), locale, transform)
	return vunicode.decode_utf16(mapped.units).map(rune(it)).string()
}
