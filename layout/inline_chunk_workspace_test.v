module layout

import css
import dom
import platform
import html

fn chunk_workspace_text(document &dom.Document, source string, declarations string) &TextNode {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font-family:SerenitySans;font-size:18px;' + declarations)
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	parent := BlockContainer.new(document, none, style)
	text := TextNode.new(document, document.create_text_node(source).as_node(), source)
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn assert_chunk_workspace_output(actual []TextNodeChunk, expected []TextNodeChunk) {
	assert actual.len == expected.len
	for index, chunk in actual {
		reference := expected[index]
		assert chunk.view == reference.view
		assert chunk.start == reference.start && chunk.length == reference.length
		assert chunk.has_breaking_newline == reference.has_breaking_newline
		assert chunk.has_breaking_tab == reference.has_breaking_tab
		assert chunk.is_all_whitespace == reference.is_all_whitespace
		assert chunk.can_break_after == reference.can_break_after
		assert chunk.text_type == reference.text_type
		assert chunk.font.has_same_identity(reference.font)
		assert chunk.font.synthesize_ascii_caps == reference.font.synthesize_ascii_caps
	}
}

fn test_retired_chunk_workspace_preserves_unicode_breaks_and_font_selection() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	for source in ['Latin words and spaces', 'café 文 😀 e\u0301', 'one\ttwo\nthree', ''] {
		for declarations in ['white-space:normal', 'white-space:pre-wrap',
			'font-variant-caps:small-caps;white-space:pre-wrap'] {
			text := chunk_workspace_text(document, source, declarations)
			for direction in [TextDirectionMode.per_code_point, .unidirectional_left_to_right] {
				reference := collect_text_node_chunks(text, true, true, direction, false)
				actual := retained_text_node_chunks(text, true, true, direction)
				assert_chunk_workspace_output(actual, reference)
			}
		}
	}
}

fn test_chunk_workspace_keeps_published_fonts_in_the_document_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	text := chunk_workspace_text(document, 'abc', '')
	selected := text.font_for_rendering()
	mut scratch := platform.begin_thread_scratch('test chunk font publication')
	mut iterator := TextNodeChunkIterator{ text_node: text, font_variant_caps: .small_caps, retain_selected_fonts_: true }
	invisible := iterator.invisible_font_for(selected)
	caps := iterator.synthetic_caps_font_for(selected, u32(`a`))
	scratch.finish()
	assert invisible.is_invisible
	assert invisible.family == selected.family
	assert caps.family == selected.family
	assert !selected.is_invisible
	if !selected.has_gsub_feature('smcp') && selected.contains_glyph(u32(`A`)) {
		assert caps.synthesize_ascii_caps
		$if prealloc {
			assert document.native_storage().arena.contains(voidptr(caps))
		}
	}
	$if prealloc {
		assert document.native_storage().arena.contains(voidptr(invisible))
	}
}

fn test_chunk_construction_retires_iterator_and_growing_output_storage() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	text := chunk_workspace_text(document, 'word and spaces '.repeat(512), '')
	// Prime the node's retained UTF-16, segmenter, cascade and grapheme caches.
	_ = collect_text_node_chunks(text, true, false, .per_code_point, false)
	before_reference := document.native_storage().arena.usage().used
	reference := collect_text_node_chunks(text, true, false, .per_code_point, false)
	reference_bytes := document.native_storage().arena.usage().used - before_reference
	before_owned := document.native_storage().arena.usage().used
	actual := retained_text_node_chunks(text, true, false, .per_code_point)
	owned_bytes := document.native_storage().arena.usage().used - before_owned
	assert_chunk_workspace_output(actual, reference)
	assert owned_bytes < reference_bytes * 8 / 10, 'owned=${owned_bytes} reference=${reference_bytes}'
}

fn test_chunk_font_publication_does_not_borrow_an_unrelated_document_arena() {
	$if !prealloc {
		return
	}
	mut outer := dom.Document.create(dom.url_about_blank())
	outer.enable_native_storage()
	mut entered := outer.enter_native_storage()
	persistent := platform.enter_persistent()
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	text := chunk_workspace_text(document, 'nested text', '')
	selected := text.font_for_rendering()
	platform.leave_persistent(persistent)
	mut scratch := platform.begin_thread_scratch('unrelated font owner')
	mut iterator := TextNodeChunkIterator{ text_node: text, retain_selected_fonts_: true }
	invisible := iterator.invisible_font_for(selected)
	scratch.finish()
	assert !outer.native_storage().arena.contains(voidptr(invisible))
	entered.finish()
	outer.finalize()
	outer.release_native_storage()
	assert invisible.is_invisible
	assert invisible.family == selected.family
	document.finalize()
}

fn test_native_chunk_workspace_survives_live_font_change_and_layout_rebuild() {
	mut document := html.parse_document('<!doctype html><div id="owner" style="width:300px;font:16px SerenitySans"><p>A paragraph with <strong>nested bold text</strong> and trailing content.</p></div>')
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut owner := document.get_element_by_id('owner')?
	for style in ['width:300px;font:20px SerenityMono', 'width:120px;font:12px SerenitySans'] {
		owner.set_attribute_value('style', style)
		document.update_layout(.debugging)
		current := document.record_display_list()?.dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert document.record_display_list()?.dump() == current
	}
}
