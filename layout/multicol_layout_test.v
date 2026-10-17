module layout

import css
import dom
import html

fn multicol_element_rect(document &dom.Document, id string) dom.Rect {
	element := css.query_selector(document.as_node(), '#${id}') or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

// Seven one-line items in three 80px-wide columns balance to three lines per
// column, then move a line back so the last column keeps two (widows: 2).
fn test_multicol_inline_content_balances_lines_into_columns() {
	mut items := ''
	for index in 0 .. 7 {
		items += '<li id="i${index}">x</li> '
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:14px/20px Helvetica}ul{margin:0;padding:0;width:300px;column-width:80px;column-gap:10px;list-style:none}li{display:inline-block;width:80px}</style><ul id="list">${items}</ul>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	pitch := (300.0 - 20.0) / 3.0 + 10.0
	expected := [[0.0, 0.0], [0.0, 20.0], [0.0, 40.0], [1.0, 0.0], [1.0, 20.0], [2.0, 0.0], [2.0, 20.0]]
	for index, position in expected {
		rect := multicol_element_rect(document, 'i${index}')
		assert math_abs(rect.x - position[0] * pitch) < 0.02
		assert rect.y == position[1]
	}
	assert multicol_element_rect(document, 'list').height == 60
}

// LibWeb's policy keeps a multi-column container's lines in one column.
fn test_libweb_policy_keeps_multicol_lines_in_one_column() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:14px/20px Helvetica}ul{margin:0;padding:0;width:300px;column-width:80px;list-style:none}li{display:inline-block;width:80px}</style><ul id="list"><li id="a">x</li> <li id="b">x</li> <li id="c">x</li> <li id="d">x</li></ul>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert multicol_element_rect(document, 'd').y == 20
	assert multicol_element_rect(document, 'list').height == 40
}

fn math_abs(value f64) f64 {
	return if value < 0 { -value } else { value }
}
