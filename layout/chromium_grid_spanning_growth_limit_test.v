module layout

import html

fn grid_spanning_item_rect(document_markup string, id string) []f64 {
	mut document := html.parse_document(document_markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = run_document_layout(document, 1024, 768) or { panic('missing layout') }
	element := document.get_element_by_id(id) or { panic(id) }
	rect := element.get_bounding_client_rect()
	return [rect.x, rect.y, rect.width, rect.height]
}

fn test_spanning_items_grow_only_the_auto_row_without_a_finite_growth_limit() {
	// Discord's footer: span-1 items fix the first two auto rows; a taller
	// item spanning all three rows grows only the empty third row, whose
	// growth limit is still infinite, so the second-row item stays at 156+48.
	markup := '<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; grid-template-columns:repeat(12,1fr); row-gap:48px; column-gap:20px;
			align-items:start; width:944px }
		.a { grid-area:span 1/span 4/span 1/span 4; height:156px }
		.s { grid-area:span 3/span 2/span 3/span 2 }
		#f { grid-area:span 1/span 4/span 1/span 4; height:60px }
	</style><div id="grid"><div class="a"></div><div class="s" style="height:200px"></div>
		<div class="s" style="height:164px"></div><div class="s" style="height:368px"></div>
		<div class="s" style="height:296px"></div><div id="f"></div></div>'
	assert grid_spanning_item_rect(markup, 'f') == [0.0, 204, 301.328125, 60]
	assert grid_spanning_item_rect(markup, 'grid')[3] == 368
}
