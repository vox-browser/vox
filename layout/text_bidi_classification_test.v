module layout

import css
import dom
import html

fn bidi_cache_generated_text(document &dom.Document, source string) &TextNode {
	parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	text := TextNode.new_generated(document, source)
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn test_text_bidi_classification_keeps_ltr_unicode_and_all_directional_controls() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for source in ['', 'plain ASCII', 'café — “news”', '中文', 'á', '😀', 'ΑΒΓ'] {
		text := bidi_cache_generated_text(document, source)
		for _ in 0 .. 4 { assert !text_may_require_bidi_processing(text) }
		assert (text.cached_inline_bidi_processing_ != none) == !retain_text_bidi_scans
	}
	for source in ['א', 'ع', '\u200f', '\u202a', '\u202b', '\u202c', '\u202d',
		'\u202e', '\u2066', '\u2067', '\u2068', '\u2069'] {
		text := bidi_cache_generated_text(document, 'before ${source} after')
		for _ in 0 .. 4 { assert text_may_require_bidi_processing(text) }
	}
}

fn test_text_bidi_classification_refreshes_after_live_dom_changes_without_layout() {
	mut document := html.parse_document('<!doctype html><p id="target">café</p>')
	defer { document.finalize() }
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut source := target.first_child() or { panic('missing text') }.as_character_data() or { panic('not text') }
	bridge := source.layout_node() or { panic('missing layout bridge') }
	text := unsafe { &TextNode(bridge.layout_handle) }
	for value in ['אבג', 'ASCII', 'العربية', '', 'café 😀', '\u2066plain\u2069'] {
		_ = text_may_require_bidi_processing(text)
		source.set_data(value)
		assert text.cached_inline_bidi_processing_ == none
		for _ in 0 .. 3 {
			assert text_may_require_bidi_processing(text) == uncached_text_may_require_bidi_processing(value)
			assert text.text_for_rendering() == value
		}
	}
}

fn test_text_bidi_classification_uses_the_rendered_source_range_and_recomputation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut text := bidi_cache_generated_text(document, 'éא😀')
	assert text_may_require_bidi_processing(text)
	text.source_range_start_ = 0
	text.source_range_length_ = 1
	text.invalidate_text_for_rendering()
	assert text.cached_inline_bidi_processing_ == none
	assert !text_may_require_bidi_processing(text)
	assert text.text_for_rendering() == 'é'
	text.source_range_start_ = 1
	text.invalidate_text_for_rendering()
	assert text_may_require_bidi_processing(text)
	assert text.text_for_rendering() == 'א'
	// A direct lazy-rendering reset must also retire an old classification.
	text.source_range_start_ = 2
	text.source_range_length_ = 2
	text.text_for_rendering_valid_ = false
	assert !text_may_require_bidi_processing(text)
	assert text.text_for_rendering() == '😀'
}

fn test_text_bidi_classification_does_not_cache_paragraph_or_inline_direction() {
	mut document := html.parse_document('<!doctype html><div id="target" style="direction:ltr">café <span id="span">news</span></div>')
	defer { document.finalize() }
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut span := document.get_element_by_id('span') or { panic('missing span') }
	for index, declarations in ['direction:ltr', 'direction:rtl', 'direction:ltr', 'direction:ltr'] {
		target.set_attribute_value('style', declarations)
		span.set_attribute_value('style', if index == 3 { 'unicode-bidi:bidi-override' } else { '' })
		_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
		root := unsafe { &BlockContainer(target.as_node().unsafe_layout_node() or { panic('missing root') }.real_layout_handle()) }
		mut iterator := InlineLevelIterator{containing_block: root}
		for _ in 0 .. 3 {
			assert iterator.compute_is_unidirectional_left_to_right() == (index == 0 || index == 2)
		}
	}
}

fn test_text_bidi_classification_preserves_live_layout_against_a_fresh_tree() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}p{font:16px/20px SerenitySans;width:170px}</style><p id="target">café news from the world</p>')
	defer { document.finalize() }
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut source := target.first_child() or { panic('missing text') }.as_character_data() or { panic('not text') }
	for index, value in ['café news from the world', 'אבג mixed Latin words', 'عربي café 😀', 'plain again', 'a\u2067אבג\u2069 b'] {
		source.set_data(value)
		target.set_attribute_value('style', if index % 2 == 0 { 'direction:ltr;text-transform:uppercase' } else { 'direction:rtl' })
		document.update_layout(.debugging)
		current := (document.record_display_list() or { panic('missing current paint') }).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == current
	}
}
