module layout

import css
import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn shared_font_test_text_node() &TextNode {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font-family:SerenitySans;font-size:16.5px')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	parent := BlockContainer.new(document, none, style)
	text := TextNode.new(document, document.create_text_node('Hello').as_node(), 'Hello')
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn test_text_iterators_reuse_the_retained_cascade_native_handles() {
	text := shared_font_test_text_node()
	first := TextNodeChunkIterator.new(text, true, false)
	second := TextNodeChunkIterator.new(text, false, false)
	assert first.font_cascade_fonts.len > 0
	assert first.font_cascade_fonts.len == second.font_cascade_fonts.len
	for index in 0 .. first.font_cascade_fonts.len {
		assert voidptr(first.font_cascade_fonts[index]) == voidptr(second.font_cascade_fonts[index])
	}
	$if gcboehm ? { C.GC_gcollect() }
	assert first.font_cascade_fonts[0].pixel_metrics().size == 16.5
	assert voidptr(text.first_available_font()) == voidptr(first.font_cascade_fonts[0])
}

fn test_text_svg_and_ellipsis_conversions_reuse_the_same_visible_font() {
	text := shared_font_test_text_node()
	cascade := text.font_list()
	first := text_node_chunk_platform_font(&cascade.fonts[0].font)
	svg := svg_cascade_platform_fonts(cascade)
	assert voidptr(svg.fonts[0]) == voidptr(first)
	ellipsis := block_ellipsis_font_for_code_point(cascade, u32(`A`))
	assert voidptr(ellipsis) == voidptr(first)
	$if gcboehm ? { C.GC_gcollect() }
	assert first.contains_glyph(u32(`A`))
	assert !first.is_invisible
}
