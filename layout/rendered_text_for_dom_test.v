module layout

import css
import dom
import html

fn dom_text_collection_test_node(document &dom.Document, source string, white_space string) &TextNode {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'white-space-collapse:${white_space}; font-size:16px')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	parent := BlockContainer.new(document, none, style)
	text := TextNode.new(document, document.create_text_node(source).as_node(), source)
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn test_dom_text_collection_preserves_no_wrap_iterator_output_for_whitespace_and_unicode() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	inputs := [
		'',
		'plain text',
		'  a   b  ',
		' \t\n\r\x0b\x0c ',
		'A\r\nB',
		'A \r\nB',
		'A\r\n \nB',
		'\r\n\r\n',
		'A\t\tB\n\nC',
		'Á  é',
		' \u0301  A',
		'  \u0301A',
		'  \u200dA',
		'  \ufe0fA',
		'  \u0903A',
		'  \u0301\u200d\ufe0fA',
		'  \u200d\u0301\u0903A',
		'\r\n\r\n\u0301A',
		' \t\u0301A',
		'A  B  \u0301C',
		'\u0600  B',
		'中文  日本語',
		'אבג  العربية',
		'🇦🇺  👩‍👩‍👧‍👦',
		'A\u00a0\u00a0B\u202f C\u2003D',
		'A\u2028\u2029B',
		'a\u00adb  c',
		[u8(0xff), 0x20, 0x20, 0x41].bytestr(),
		[u8(0xed), 0xa0, 0x80, 0x20, 0x20, 0x42].bytestr(),
		[u8(0xf0), 0x9f, 0x20, 0x20, 0x43].bytestr(),
	]
	for white_space in ['collapse', 'preserve-breaks', 'preserve', 'preserve-spaces', 'break-spaces'] {
		for source in inputs {
			text := dom_text_collection_test_node(document, source, white_space)
			actual := collect_dom_rendered_text(text)
			mut iterator := TextNodeChunkIterator.new(text, false, false)
			mut chunks := []string{}
			for {
				chunk := iterator.next() or { break }
				chunks << chunk.view
			}
			assert actual == chunks.join(''), '${white_space}: ${source.bytes()} -> ${actual.bytes()}'
		}
	}
}

fn test_dom_text_collection_leaves_font_utf16_and_segmenters_lazy_and_reuses_unchanged_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for white_space in ['collapse', 'preserve-breaks', 'preserve', 'break-spaces'] {
		text := dom_text_collection_test_node(document, 'Á 👩‍👩‍👧‍👦 中文 אבג', white_space)
		rendered := text.text_for_rendering()
		actual := collect_dom_rendered_text(text)
		assert actual == rendered
		assert actual.str == rendered.str
		assert text.font_for_rendering_ == none
		assert text.cached_utf16_code_units_ == none
		assert text.cached_inline_chunks_ == none
		assert text.line_segmenter_ == unsafe { nil }
	}
	collapsed := dom_text_collection_test_node(document, '  Á   👩‍👩‍👧‍👦  ', 'collapse')
	assert collect_dom_rendered_text(collapsed) == ' Á 👩‍👩‍👧‍👦 '
	assert collapsed.font_for_rendering_ == none
	assert collapsed.cached_utf16_code_units_ == none
	assert collapsed.line_segmenter_ == unsafe { nil }
}

fn test_dom_text_collection_keeps_first_letter_transforms_live_text_and_source_geometry() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{font:16px/20px SerenityMono;text-transform:uppercase}p::first-letter{font-size:24px}</style><p id="host" contenteditable>ßabc  é</p>')
	defer { document.finalize() }
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	mut text := host.as_node().first_child() or { panic('missing text') }
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'SSABC É'
	committed := text.layout_node() or { panic('missing committed text') }
	assert committed.rendered_text_chunks_.join('') == 'SSABC É'
	range := dom.Range.create_from_boundary_points(text, 0, text, 1)
	assert range.get_client_rects().length() > 0
	mut caret_offsets := []int{}
	for line in committed.visual_lines() {
		for stop in line.caret_stops { caret_offsets << stop.offset }
	}
	assert 0 in caret_offsets
	assert 1 in caret_offsets
	assert 5 in caret_offsets
	text.set_text_content('z  👩‍👩‍👧‍👦') or { panic(err) }
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'Z 👩‍👩‍👧‍👦'
	assert document.find_matching_text('Z 👩‍👩‍👧‍👦', .case_sensitive).len == 1
	host.set_attribute_value('style', 'white-space:pre')
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'Z  👩‍👩‍👧‍👦'
	updated := text.layout_node() or { panic('missing updated text') }
	assert updated.visual_lines().len > 0
}
