module layout

import css
import dom
import platform

fn stable_marker_text_fixture(document &dom.Document, transform string) &TextNode {
	mut element := document.create_element('span') or { panic(err) }
	element.set_attribute_value('style', 'display:inline;font:16px/20px SerenitySans;text-transform:${transform}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut parent := BlockContainer.new(document, none, style)
	text := TextNode.new_generated(document, '')
	parent.append_child(unsafe { &Node(text) })
	return text
}

fn test_fixed_symbol_marker_text_outlives_producer_scratch_and_keeps_segmentation() {
	if disable_stable_symbol_marker_text_reuse { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut text := stable_marker_text_fixture(document, 'none')
	work := platform.begin_thread_scratch('resolved marker text producer')
	resolved := '• '.clone()
	set_resolved_marker_text_for_layout(mut text, resolved, true)
	assert text.text_for_rendering() == '• '
	segmenter := text.line_segmenter()
	work.finish()
	churn := platform.begin_thread_scratch('resolved marker text overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	gc_collect()
	// Both source and rendered data must remain valid after the producer dies.
	set_resolved_marker_text_for_layout(mut text, '• ', true)
	assert text.source_text_ == '• '
	assert text.text_for_rendering() == '• '
	assert voidptr(text.line_segmenter_) == voidptr(segmenter)
	// A different resolved symbol invalidates text and segmentation as usual.
	set_resolved_marker_text_for_layout(mut text, '◦ ', true)
	assert text.line_segmenter_ == unsafe { nil }
	assert text.text_for_rendering() == '◦ '
	owner.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_transformed_and_custom_marker_text_keep_ordinary_refresh() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut transformed := stable_marker_text_fixture(document, 'uppercase')
	set_resolved_marker_text_for_layout(mut transformed, 'a.', true)
	assert transformed.text_for_rendering() == 'A.'
	_ = transformed.line_segmenter()
	set_resolved_marker_text_for_layout(mut transformed, 'a.', true)
	assert transformed.line_segmenter_ == unsafe { nil }
	assert transformed.text_for_rendering() == 'A.'
	mut ordinary := stable_marker_text_fixture(document, 'none')
	set_resolved_marker_text_for_layout(mut ordinary, '• ', false)
	assert ordinary.text_for_rendering() == '• '
	_ = ordinary.line_segmenter()
	set_resolved_marker_text_for_layout(mut ordinary, '• ', false)
	assert ordinary.line_segmenter_ == unsafe { nil }
	owner.finish()
	document.finalize()
	document.release_native_storage()
}
