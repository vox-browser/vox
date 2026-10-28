module layout

import css
import platform

// The empty-pending path needs no document and must still honor cascade ranges.
fn test_chunk_font_without_pending_faces_selects_ranges_without_document_access() {
	mut cascade := css.FontCascadeList.create()
	first := &platform.Font{family: 'SerenitySans', point_size: 16}
	second := &platform.Font{family: 'SerenityMono', point_size: 18}
	mut iterator := TextNodeChunkIterator{
		font: first
		font_cascade_list: cascade
		font_cascade_fonts: [first, second]
		font_cascade_ranges: [[css.UnicodeRange{start: u32(`A`), end: u32(`A`)}], []css.UnicodeRange{}]
	}
	assert first.contains_glyph(u32(`A`))
	assert second.contains_glyph(u32(`B`))
	assert voidptr(iterator.font_for_code_point(u32(`A`))) == voidptr(first)
	assert voidptr(iterator.font_for_code_point(u32(`B`))) == voidptr(second)
	assert iterator.selected_font_storage_ == unsafe { nil }
}

fn test_chunk_font_without_pending_faces_retains_synthetic_caps_selection() {
	font := &platform.Font{family: 'SerenitySans', point_size: 20, font_rendering_policy: .chromium}
	mut iterator := TextNodeChunkIterator{
		font: font
		font_cascade_list: css.FontCascadeList.create()
		font_cascade_fonts: [font]
		font_cascade_ranges: [[]css.UnicodeRange{}]
		font_variant_caps: .small_caps
	}
	selected := iterator.font_for_code_point(u32(`a`))
	assert !selected.is_invisible
	if !font.has_gsub_feature('smcp') && font.contains_glyph(u32(`A`)) {
		assert selected.synthesize_ascii_caps
		assert selected.point_size == 14
		assert voidptr(iterator.font_for_code_point(u32(`b`))) == voidptr(selected)
	}
	assert voidptr(iterator.font_for_code_point(u32(`A`))) == voidptr(font)
}
