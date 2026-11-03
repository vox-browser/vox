module main

import css
import dom
import html

fn initial_resource_viewport_fixture(width int, height int, zoom f64) &BrowserApp {
	mut document := html.parse_document('<!doctype html><style>#target{width:40px;height:10vh}@media(min-width:900px){#target{width:80px}}</style><svg></svg><div id="target"></div>')
	document.set_browsing_context(&dom.BrowsingContext{active_document_:document})
	document.set_navigable(&dom.Navigable{active_document_:document})
	return &BrowserApp{document:document,viewport_width:width,viewport_height:height,page_zoom:zoom}
}

fn initial_resource_viewport_target_style(document &dom.Document) &css.ComputedProperties {
	target := document.get_element_by_id('target') or { panic('target') }
	return css.computed_properties_for_element(target) or { panic('computed target') }
}

fn test_initial_resource_viewport_matches_media_queries_before_device_layout_style_reads() {
	mut app := initial_resource_viewport_fixture(1024,768,1)
	defer { app.document.finalize() }
	app.prepare_initial_resource_viewport()
	assert app.document.viewport_rect()==dom.Rect{0,0,1024,768}
	first := initial_resource_viewport_target_style(app.document)
	assert (first.property(.width,.no) or { panic('width') }).css_text==if retain_initial_resource_viewport_after_style { '40px' } else { '80px' }
	app.document.reset_style_invalidation_counters()
	app.document.evaluate_media_queries_and_report_changes()
	_ = css.up_to_date_computed_properties_for_element(app.document.get_element_by_id('target') or { panic('target') })
	current := initial_resource_viewport_target_style(app.document)
	assert (current.property(.width,.no) or { panic('width') }).css_text=='80px'
	if !retain_initial_resource_viewport_after_style {
		assert app.document.style_invalidation_counters().element_style_recomputations==0
		assert voidptr(first)==voidptr(current)
	}
}

fn test_initial_resource_viewport_preserves_zoom_and_height_units() {
	mut app := initial_resource_viewport_fixture(1024,768,2)
	defer { app.document.finalize() }
	app.prepare_initial_resource_viewport()
	app.document.evaluate_media_queries_and_report_changes()
	_ = css.up_to_date_computed_properties_for_element(app.document.get_element_by_id('target') or { panic('target') })
	assert app.document.viewport_rect()==dom.Rect{0,0,512,384}
	current := initial_resource_viewport_target_style(app.document)
	assert (current.property(.width,.no) or { panic('width') }).css_text=='40px'
	// Without a media-query match change the old ordering can retain the
	// default viewport in computed viewport-relative lengths until restyled.
	assert current.viewport_rect_.width_value()==if retain_initial_resource_viewport_after_style { f64(800) } else { f64(512) }
	assert current.viewport_rect_.height_value()==if retain_initial_resource_viewport_after_style { f64(600) } else { f64(384) }
	app.document.set_needs_full_style_update(true)
	app.document.update_style()
	oracle := initial_resource_viewport_target_style(app.document)
	assert oracle.viewport_rect_.width_value()==512
	assert oracle.viewport_rect_.height_value()==384
}

fn test_initial_resource_viewport_defaults_and_repeated_preparation_keep_clean_styles() {
	mut app := initial_resource_viewport_fixture(0,0,1)
	defer { app.document.finalize() }
	app.prepare_initial_resource_viewport()
	app.document.evaluate_media_queries_and_report_changes()
	_ = css.up_to_date_computed_properties_for_element(app.document.get_element_by_id('target') or { panic('target') })
	assert app.document.viewport_rect()==dom.Rect{0,0,1024,f64(initial_height-app.chrome_height())}
	before := initial_resource_viewport_target_style(app.document)
	app.document.reset_style_invalidation_counters()
	app.prepare_initial_resource_viewport()
	_ = css.up_to_date_computed_properties_for_element(app.document.get_element_by_id('target') or { panic('target') })
	assert app.document.style_invalidation_counters().element_style_recomputations==0
	assert voidptr(before)==voidptr(initial_resource_viewport_target_style(app.document))
}
