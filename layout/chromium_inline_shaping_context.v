module layout

import platform

// Inline element boundaries do not end a shaping run when the font and
// spacing remain the same. Keep DOM offsets/fragments separate while shaping
// a bounded ASCII context across them. A boundary inside a ligature, bidi,
// preserved whitespace, a font change or an inline edge keeps the old path.
fn (mut iterator InlineLevelIterator) shape_across_compatible_inline_nodes() {
	if !iterator.is_unidirectional_left_to_right
		|| iterator.containing_block.computed_values().writing_mode() != .horizontal_tb {
		return
	}
	mut first := 0
	for first < iterator.items.len {
		if !cross_node_shaping_item(iterator.items[first]) {
			first++
			continue
		}
		font := (iterator.items[first].glyph_run or {
			first++
			continue
		}).font()
		node := iterator.items[first].node or {
			first++
			continue
		}
		letter := resolved_text_spacing_for_shaping(node, .letter_spacing)
		word := resolved_text_spacing_for_shaping(node, .word_spacing)
		mut end := first + 1
		for end < iterator.items.len && end - first < 128 {
			item := iterator.items[end]
			if !cross_node_shaping_item(item) { break }
			next := item.node or { break }
			run := item.glyph_run or { break }
			if !font.has_same_identity(run.font()) || font.variations() != run.font().variations()
				|| resolved_text_spacing_for_shaping(next, .letter_spacing) != letter
				|| resolved_text_spacing_for_shaping(next, .word_spacing) != word {
				break
			}
			end++
		}
		iterator.reshape_inline_node_group(first, end, f32(letter), f32(word))
		first = end
	}
}

fn cross_node_shaping_item(item InlineLevelItem) bool {
	if item.type_ != .text || item.margin_start.raw_value() != 0 || item.margin_end.raw_value() != 0
		|| item.border_start.raw_value() != 0 || item.border_end.raw_value() != 0
		|| item.padding_start.raw_value() != 0 || item.padding_end.raw_value() != 0 {
		return false
	}
	node := item.node or { return false }
	if node.as_text_node() == none || node.computed_values().white_space_collapse() != .collapse {
		return false
	}
	run := item.glyph_run or { return false }
	return run.font().font_rendering_policy == .chromium && run.text_type() != .rtl
}

fn (mut iterator InlineLevelIterator) reshape_inline_node_group(first int, end int, letter f32, word f32) {
	if end - first < 2 { return }
	first_node := iterator.items[first].node or { return }
	mut different_nodes := false
	for item in iterator.items[first + 1..end] {
		if node := item.node {
			different_nodes = different_nodes || !layout_nodes_same(first_node, node)
		}
	}
	if !different_nodes { return }
	scratch := platform.begin_thread_scratch('inline shaping context')
	defer { scratch.finish() }
	mut parts := []string{cap: end - first}
	mut length := 0
	for item in iterator.items[first..end] {
		node := item.node or { return }
		text_node := node.as_text_node() or { return }
		text := text_node.rendered_substring_for_line_box(item.offset_in_node, item.length_in_node)
		if !text.is_ascii() || text.contains_any('\t\n\r\x0c') || text.contains('  ') { return }
		length += text.len
		if length > 4096 { return }
		parts << text
	}
	text := parts.join('')
	if text.contains('  ') { return }
	// The context string is temporary; shaping caches clone their keys and
	// glyph storage must belong to the caller's layout owner.
	scratch.leave()
	font := (iterator.items[first].glyph_run or { return }).font()
	run := platform.shape_text_with_spacing(0, letter, word, text, font, .ltr).glyph_run
	mut shaped := []platform.ShapedText{cap: end - first}
	mut cursor := ChromiumContextSliceCursor{}
	mut offset := 0
	for item in iterator.items[first..end] {
		slice := chromium_context_slice_with_cursor(run, TextNodeChunk{ start: offset, length: item.length_in_node }, mut cursor) or { return }
		shaped << slice
		offset += item.length_in_node
	}
	for index in first .. end {
		old := iterator.items[index]
		slice := shaped[index - first]
		iterator.items[index] = InlineLevelItem{
			...old
			glyph_run:           slice.glyph_run
			width:               shaped_inline_width(slice.glyph_run, 0)
			trailing_whitespace: trailing_whitespace_from_shaped_text(slice)
		}
	}
}
