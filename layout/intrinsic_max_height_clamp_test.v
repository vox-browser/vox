module layout

import css
import dom
import html

fn intrinsic_max_height_heights(markup string) []f64 {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:14px/20px Helvetica}div{width:300px}</style>${markup}')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 600)
	mut heights := []f64{}
	for index in 0 .. 32 {
		element := css.query_selector(document.as_node(), '#b${index}') or { break }
		heights << element.get_bounding_client_rect().height
	}
	return heights
}

// CSS 2 §10.7 applies max-height before min-height, so a larger minimum wins.
// cybersport.ru's ranking rows (`display:grid; min-height:44px;
// max-height:fit-content`) were 20px tall because intrinsic maxima were
// applied after the minimum.
fn test_min_height_wins_over_a_smaller_intrinsic_max_height() {
	mut markup := ''
	mut index := 0
	for display in ['block', 'grid', 'flex'] {
		for maximum in ['fit-content', 'min-content', 'max-content', '10px'] {
			markup += '<div id="b${index}" style="display:${display};min-height:44px;max-height:${maximum}">row</div>'
			index++
		}
	}
	heights := intrinsic_max_height_heights(markup)
	assert heights.len == 12
	for height in heights {
		assert height == 44
	}
}

fn test_intrinsic_max_height_still_caps_a_taller_specified_height() {
	heights := intrinsic_max_height_heights('<div id="b0" style="height:100px;max-height:fit-content">row</div>' +
		'<div id="b1" style="display:grid;height:100px;max-height:min-content;min-height:30px">row</div>' +
		'<div id="b2" style="height:100px;max-height:max-content;min-height:10px">row</div>')
	assert heights == [20.0, 30, 20]
}
