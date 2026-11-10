module layout

import dom
import html
import page

fn inline_word_fixture(source string) &dom.Document {
	document := html.parse_document('<!doctype html>${source}')
	_ = run_document_layout(document, 800, 300) or { panic('missing layout') }
	return document
}

fn inline_word_text(document &dom.Document, id string) &dom.Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return element.as_node().first_child() or { panic('missing text') }
}

fn test_inline_word_query_crosses_nested_inline_elements_and_keeps_single_node_fallback() {
	mut document := inline_word_fixture('<p id="p">super<span id="hit"><em>cali</em>fragilistic</span>expialidocious</p><p>one <span id="single">word</span> two</p>')
	defer { document.finalize() }
	hit := inline_word_text(document, 'hit').first_child()?
	mut range := hit.layout_node()?.inline_word_range(2)?
	defer { range.finalize() }
	assert range.to_string() == 'supercalifragilisticexpialidocious'
	assert range.start_container() == inline_word_text(document, 'p')
	assert range.start_offset() == 0
	assert range.end_offset() == 14
	live_before_fallback := dom.Range.live_ranges().len
	assert inline_word_text(document, 'single').layout_node()?.inline_word_range(2) == none
	assert dom.Range.live_ranges().len == live_before_fallback
}

fn test_inline_word_query_stops_at_boxes_line_breaks_and_generated_content() {
	for boundary in ['<br>', '<i style="display:inline-block">other</i>', '<i class="generated"></i>'] {
		mut document := inline_word_fixture('<style>.generated::before{content:"other"}</style><p>before${boundary}<span id="hit">bar</span>baz</p>')
		hit := inline_word_text(document, 'hit')
		mut range := hit.layout_node()?.inline_word_range(1)?
		assert range.to_string() == 'barbaz'
		assert range.start_container() == hit
		assert range.start_offset() == 0
		assert range.end_offset() == 3
		range.finalize()
		document.finalize()
	}
}

fn test_inline_word_query_maps_first_letter_transforms_and_utf16_source_offsets() {
	mut document := inline_word_fixture('<style>#p{text-transform:uppercase}#p::first-letter{font-size:30px}</style><p id="p">ß<span id="hit">bc</span>𐐀</p>')
	defer { document.finalize() }
	first := inline_word_text(document, 'p')
	for hit in [first, inline_word_text(document, 'hit')] {
		mut range := hit.layout_node()?.inline_word_range(0)?
		assert range.to_string() == 'ßbc𐐀'
		assert range.start_container() == first
		assert range.start_offset() == 0
		assert range.end_offset() == 2
		range.finalize()
	}
	mut password := unsafe { &dom.Text(inline_word_text(document, 'hit')) }
	password.set_is_password_input(true)
	assert password.as_node().layout_node()?.inline_word_range(0) == none
}

fn inline_word_single_node_fallback(text string, offset int) page.SelectionRange {
	boundaries := (dom.Segmenter{segmented_text: text, granularity: .word}).boundaries()
	for i in 1 .. boundaries.len {
		if boundaries[i] > offset {
			return page.SelectionRange{start: boundaries[i - 1], end: boundaries[i]}
		}
	}
	return page.SelectionRange{}
}

fn test_double_click_selects_the_complete_word_across_inline_elements() {
	mut owner := page.Page.create(1)!
	mut document := html.parse_document_with_url('<!doctype html><p>super<span id="hit">cali</span>fragilistic</p>', dom.URL{value: 'https://selection.example/'})
	defer { document.finalize() }
	document.set_page(unsafe { &dom.Page(owner) })
	window := html.WindowModel.create_top_level(document, none, 'selection')!
	owner.set_local_root_navigable(window.navigable_model().host_navigable())!
	_ = run_document_layout(document, 800, 300)?
	box := document.get_element_by_id('hit')?.get_bounding_client_rect()
	mut handler := page.EventHandler{}
	live_before_click := dom.Range.live_ranges().len
	handler.select_mouse_text(document, page.PixelPoint{x: box.x + box.width / 2,
		y: box.y + box.height / 2}, 2, inline_word_single_node_fallback)
	selection := document.get_selection()?
	assert selection.to_string() == 'supercalifragilistic'
	assert dom.Range.live_ranges().len == live_before_click + 1
	mut selected_range := selection.get_range_at(0)!
	selected_range.finalize()
}
