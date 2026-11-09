module main

import html
import layout

fn test_stretch_keyword_fits_margin_boxes_independently_of_box_sizing() {
	for sizing in ['content-box', 'border-box'] {
		for tag in ['div', 'canvas', 'input', 'button'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}#parent{width:100px;height:80px}
				#target{box-sizing:${sizing};width:stretch;height:stretch;margin:3px 5px;border:2px solid;padding:4px}
				</style><div id="parent"><${tag} id="target"></${tag}></div>')
			defer { document.finalize() }
			_ = layout.layout_document_typed_in_viewport(document, 400, 300)
			r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
			assert r.width == 90 && r.height == 74, '${tag} ${sizing}: ${r.width}x${r.height}'
		}
	}
}

fn test_stretch_keyword_indefinite_height_behaves_as_auto_for_aspect_ratio() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{width:100px}#target{height:stretch;aspect-ratio:2}</style><div id="parent"><div id="target"></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.width == 100 && r.height == 50, '${r.width}x${r.height}'
}
