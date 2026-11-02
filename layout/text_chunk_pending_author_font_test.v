module layout

import css
import dom
import html
import os

fn generated_icon_text(node &Node) ?&TextNode {
	if text := node.as_text_node() {
		if node.is_generated_for_pseudo_element() && text.text_for_rendering().len > 0 {
			return text
		}
	}
	for child in node.children() {
		if text := generated_icon_text(child) { return text }
	}
	return none
}

fn test_generated_private_use_glyph_starts_and_selects_its_pending_author_font() {
	$if !darwin { return }
	font_path := os.real_path(os.join_path(os.dir(@FILE), '..', 'Tests', 'Browser', 'Brave', 'resources', 'sdicon.woff'))
	assert os.is_file(font_path)
	mut document := html.parse_document('<!doctype html><style>
		@font-face{font-family:GeneratedIcons;src:url(file://${font_path}) format("woff")}
		body{margin:0}.icon::before{content:"\\e800";font:20px GeneratedIcons,Arial}
	</style><span class="icon"></span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('missing layout') }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	assert faces.len == 1
	assert faces[0].status() == .loaded
	assert faces[0].parsed_font != unsafe { nil }
	text := generated_icon_text(result.root) or { panic('missing generated glyph') }
	mut iterator := TextNodeChunkIterator.new(text, false, false)
	selected := iterator.font_for_code_point(0xe800)
	assert selected.source_path.len > 0
	assert selected.contains_glyph(0xe800)
}

fn pending_glyph_iterator() (&dom.Document, &TextNodeChunkIterator) {
	mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial">A</p>')
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 300, 100)
	element := document.get_element_by_id('text') or { panic('missing target') }
	node := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	text := node.first_child() or { panic('missing child') }.as_text_node() or { panic('missing text') }
	return document, TextNodeChunkIterator.new(text, false, false)
}

fn test_pending_author_font_display_controls_system_fallback_ink_for_missing_glyphs() {
	$if !darwin { return }
	for sample in [['block', '0'], ['block', '3000'], ['swap', '0']] {
		mut document, mut iterator := pending_glyph_iterator()
		defer { document.finalize() }
		mut face := css.FontFaceObject.construct_impl('PendingGlyph', css.FontFaceSource.from_string('url(pending.woff)'),
			css.FontFaceDescriptors{display: sample[0], unicode_range: 'U+E800'})
		face.status_ = .loading
		face.set_font_display_time_for_testing(sample[1].u32())
		mut cascade := css.FontCascadeList.create()
		cascade.add_pending_face(face)
		cascade.add(iterator.font_cascade_list.fonts[0].font, [])
		iterator.install_font_cascade(cascade)
		assert !iterator.font_cascade_fonts[0].contains_glyph(0xe800)
		assert iterator.system_fallback_font(0xe800) != none
		selected := iterator.font_for_code_point(0xe800)
		assert selected.is_invisible == (sample[0] == 'block' && sample[1] == '0')
	}
}

fn test_system_fallback_does_not_start_an_author_face_outside_its_unicode_range() {
	$if !darwin { return }
	mut document, mut iterator := pending_glyph_iterator()
	defer { document.finalize() }
	face := css.FontFaceObject.construct_impl('UnusedGlyph', css.FontFaceSource.from_string('url(unused.woff)'),
		css.FontFaceDescriptors{display: 'block', unicode_range: 'U+0041'})
	mut cascade := css.FontCascadeList.create()
	cascade.add_pending_face(face)
	cascade.add(iterator.font_cascade_list.fonts[0].font, [])
	iterator.install_font_cascade(cascade)
	assert !iterator.font_for_code_point(0xe800).is_invisible
	assert face.status() == .unloaded
	assert face.font_download_timer_start_ns_ == none
}
