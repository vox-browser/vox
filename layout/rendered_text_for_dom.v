// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import encoding.utf8

fn collect_dom_rendered_text_with_chunks(text_node &TextNode) string {
	mut iterator := TextNodeChunkIterator.new(text_node, false, false)
	mut chunks := []string{}
	for {
		chunk := iterator.next() or { break }
		chunks << chunk.view
	}
	return chunks.join('')
}

fn removed_dom_space_has_grapheme_extension(text string, index int) bool {
	if text[index] != ` ` || index + 1 >= text.len || text[index + 1] < 0x80 {
		return false
	}
	// Probe only the removed space and the next validated code point. Using
	// the same segmenter as ChunkIterator keeps its Unicode version and GB9/
	// GB9a rules, without initializing font or UTF-16 data for ordinary text.
	first := text[index + 1]
	length := if first < 0xe0 { 2 } else if first < 0xf0 { 3 } else { 4 }
	return text[index..index + 1 + length].graphemes().len == 1
}

// HTML's rendered-text collection concatenates the text of every no-wrap,
// non-line-preserving chunk. Font and bidi boundaries do not affect that string.
// Collect it directly, retaining text-transform and source-fragment boundaries
// from text_for_rendering() without rebuilding a font cascade or segmenters.
fn collect_dom_rendered_text(text_node &TextNode) string {
	text := text_node.text_for_rendering()
	if !utf8.validate_str(text) {
		// Keep the existing decoder's replacement behavior for malformed input,
		// including WTF-8 surrogate bytes. This uncommon path still uses the
		// original iterator rather than copying invalid byte sequences directly.
		return collect_dom_rendered_text_with_chunks(text_node)
	}
	if text_node.Node.computed_values().white_space_collapse() !in [.collapse, .preserve_breaks] {
		return text
	}

	mut previous_is_space := false
	mut first_removed := -1
	mut index := 0
	for index < text.len {
		is_space := is_ascii_space_code_point(u32(text[index]))
		if is_space && previous_is_space {
			if removed_dom_space_has_grapheme_extension(text, index) {
				// The iterator discards the entire redundant-space grapheme,
				// including any attached marks. Preserve that uncommon behavior.
				return collect_dom_rendered_text_with_chunks(text_node)
			}
			first_removed = index
			break
		}
		previous_is_space = is_space
		// The existing no-wrap ChunkIterator advances by extended graphemes.
		// A retained CRLF is one cluster (UAX #29 GB3), so preserve both units.
		index += if text[index] == `\r` && index + 1 < text.len && text[index + 1] == `\n` {
			2
		} else {
			1
		}
	}
	if first_removed < 0 {
		return text
	}

	// Allocate only after finding a redundant space; unchanged text shares the
	// already retained rendering string. UTF-8 continuation bytes cannot be an
	// ASCII space, so copying validated bytes preserves Unicode exactly.
	mut bytes := []u8{cap: text.len}
	for byte in text[..first_removed] { bytes << byte }
	index = first_removed
	for index < text.len {
		is_space := is_ascii_space_code_point(u32(text[index]))
		cluster_length := if text[index] == `\r` && index + 1 < text.len && text[index + 1] == `\n` {
			2
		} else {
			1
		}
		if !is_space || !previous_is_space {
			for byte in text[index..index + cluster_length] { bytes << byte }
		} else if removed_dom_space_has_grapheme_extension(text, index) {
			return collect_dom_rendered_text_with_chunks(text_node)
		}
		previous_is_space = is_space
		index += cluster_length
	}
	return bytes.bytestr()
}
