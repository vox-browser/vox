module layout

import html

// Brave 156: GitHub's icon buttons are 28px grids with 8px inline padding and
// a 16px column, so their centered track overflows the 12px content box by 2px
// on each side. Positional content alignment is unsafe unless 'safe' is given.
fn test_chromium_grid_centers_tracks_that_overflow_the_content_box() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		.b{display:grid;place-content:center;grid-template-columns:16px;padding:0 8px;width:28px;height:28px;box-sizing:border-box;border:0}
		.s{display:block;width:16px;height:16px}</style>
		<div class="b"><span class="s" id="centered"></span></div>
		<div class="b" style="grid-template-columns:20px"><span class="s" id="wider"></span></div>
		<div class="b" style="justify-content:end"><span class="s" id="end"></span></div>
		<div class="b" style="justify-content:space-around"><span class="s" id="around"></span></div>
		<button class="b"><span class="s" id="button"></span></button>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 400, 400) or { panic('layout') }
	for id, x in {
		'centered': 6.0
		'wider':    4.0
		'end':      4.0
		'around':   8.0
		'button':   6.0
	} {
		element := document.get_element_by_id(id) or { panic(id) }
		assert element.get_bounding_client_rect().x == x, '${id}: ${element.get_bounding_client_rect().x}'
	}
}
