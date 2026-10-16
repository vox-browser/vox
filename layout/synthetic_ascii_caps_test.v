module layout

import css
import dom
import html

fn caps_test_text(chromium bool) &TextNode {
	mut document := dom.Document.create(dom.url_about_blank())
	if chromium { document.set_font_rendering_policy(.chromium) }
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font:20px SerenitySans;font-variant-caps:small-caps')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut parent := BlockContainer.new(document, none, style)
	text := TextNode.new(document, document.create_text_node('Abc Def').as_node(), 'Abc Def')
	parent.append_child(unsafe { &Node(text) })
	return text
}

fn test_mixed_synthetic_caps_keep_retained_fonts_in_native_paint_commands() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:20px SerenitySans;font-variant-caps:small-caps}</style><body>Abc Def</body>')
	document.set_font_rendering_policy(.chromium)
	mut root := layout_document_typed_in_viewport(document, 300, 100)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	mut text := ''
	mut sizes := []f32{}
	for command in commands {
		text += command.text
		run := command.glyph_run or { panic('retained font lost during paint grouping') }
		sizes << run.font().point_size
		if run.font().synthesize_ascii_caps { assert run.font().point_size == 14 }
	}
	assert text == 'Abc Def'
	assert f32(14) in sizes
	assert f32(20) in sizes
}

fn test_synthetic_small_caps_keep_capitals_spaces_and_dom_text_at_the_original_size() {
	text := caps_test_text(true)
	mut iterator := TextNodeChunkIterator.new(text, true, false)
	mut chunks := []TextNodeChunk{}
	for { chunks << iterator.next() or { break } }
	assert chunks.map(it.view) == ['A', 'bc', ' ', 'D', 'ef']
	assert chunks.map(it.font.point_size) == [f32(20), 14, 20, 20, 14]
	assert chunks.map(it.font.synthesize_ascii_caps) == [false, true, false, false, true]
	assert chunks[1].font == chunks[4].font
	assert chunks.map(it.length) == [1, 2, 1, 1, 2]
	assert text.text_for_rendering() == 'Abc Def'
	assert text.font_for_rendering().point_size == 20
	mut translated := TextNodeChunkIterator.new(caps_test_text(false), true, false)
	for {
		chunk := translated.next() or { break }
		assert !chunk.font.synthesize_ascii_caps
		assert chunk.font.point_size == 20
	}
}
