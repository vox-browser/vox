module main

import css
import dom
import html
import layout

fn test_embedded_display_probe_during_preload_uses_the_final_viewport_for_its_first_style() {
	mut document := parse_browser_navigation_document('<!doctype html><style>@media(min-width:900px){svg{display:none}}</style><svg id="embedded"></svg>',
		dom.URL{ value: 'https://viewport-style.test/' }, none)
	defer { document.finalize() }
	mut app := BrowserApp{ document: document, viewport_width: 1024, viewport_height: 656 }
	_ = app.preload_initial_document_resources('about:blank')
	element := document.get_element_by_id('embedded')?
	computed := css.computed_properties_for_element(element)?
	assert computed.display().is_none() == !retain_late_viewport_setup
	assert document.viewport_rect().width == 1024
	assert document.viewport_rect().height == 656
	_ = layout.run_document_layout(document, 1024, 656)?
	assert css.computed_properties_for_element(element)?.display().is_none()
}

fn test_early_viewport_resize_preserves_viewport_units_media_queries_and_scroll_origin() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#item{width:50vw;height:25vh}@media(max-width:500px){#item{height:50vh}}</style><div id="item"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document, layout_tree_only: true }
	app.relayout(1000, 600 + app.chrome_height())
	element := document.get_element_by_id('item')?
	assert element.get_bounding_client_rect().width == 500
	assert element.get_bounding_client_rect().height == 150
	document.set_viewport_rect(dom.Rect{7, 13, 1000, 600})
	app.install_viewport_before_style_query(400, 200)
	assert document.viewport_rect().x == 7
	assert document.viewport_rect().y == 13
	app.relayout(400, 200 + app.chrome_height())
	assert element.get_bounding_client_rect().width == 200
	assert element.get_bounding_client_rect().height == 100
	before := element.get_bounding_client_rect()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert element.get_bounding_client_rect() == before
}

fn test_unchanged_early_viewport_keeps_a_completed_layout_and_uses_css_zoom_units() {
	mut document := html.parse_document('<!doctype html><div style="width:50vw;height:30px">stable</div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document, layout_tree_only: true, page_zoom: 2 }
	app.relayout(1000, 600 + app.chrome_height())
	assert document.viewport_rect().width == 500
	assert document.viewport_rect().height == 300
	root := layout.document_layout_result(document)?.root
	style_count := document.style_invalidation_counters().element_style_recomputations
	app.install_viewport_before_style_query(1000, 600)
	document.update_layout(.debugging)
	assert voidptr(layout.document_layout_result(document)?.root) == voidptr(root)
	assert document.style_invalidation_counters().element_style_recomputations == style_count
}
