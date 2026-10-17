module layout

import css
import dom
import html

fn whitespace_font_fixture(contents string, declarations string) (&dom.Document, &css.FontFaceObject, &Node) {
	document := html.parse_document('<!doctype html><style>
		@font-face{font-family:WhitespaceFixture;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}
		body{margin:0}#target{font:16px/24px WhitespaceFixture,serif;${declarations}}
	</style><div id="target">${contents}</div>')
	result := run_document_layout(document, 300, 200) or { panic('layout failed') }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	assert faces.len == 1
	return document, faces[0], result.root
}

fn test_collapsed_block_indentation_does_not_load_its_unused_font() {
	$if !darwin { return }
	for declarations in ['', 'white-space:nowrap'] {
		mut document, face, _ := whitespace_font_fixture(' \n\t \r\n ', declarations)
		assert face.status() == .unloaded
		defer { document.finalize() }
		// The font remains unused after a readiness flush too.
		assert css.css_style_computer_for(document).font_face_set_.status() == .loaded
		assert face.status() == .unloaded
	}
}

fn test_preserved_whitespace_and_real_text_still_load_their_fonts() {
	$if !darwin { return }
	for fixture in [[' \n ', 'white-space:pre'], [' ', 'white-space:pre-wrap'],
		['A', ''], ['one <span> </span> two', '']] {
		mut document, face, _ := whitespace_font_fixture(fixture[0], fixture[1])
		assert face.status() == .loaded
		document.finalize()
	}
}

fn test_collapsible_empty_context_retains_inter_element_spaces() {
	$if !darwin { return }
	mut document, face, root := whitespace_font_fixture('one <span>two</span>', '')
	defer { document.finalize() }
	assert face.status() == .loaded
	// Dropping a whitespace-only block must not change an ordinary mixed run.
	assert whitespace_font_rendered_text(root) == 'one two'
}

fn whitespace_font_rendered_text(node &Node) string {
	if value := node.as_text_node() { return value.text_for_rendering() }
	mut text := ''
	for child in node.children() { text += whitespace_font_rendered_text(child) }
	return text
}
