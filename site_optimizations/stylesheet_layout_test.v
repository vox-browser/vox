module main

import css
import dom

fn github_stylesheet_layout_fixture() &BrowserApp {
	mut document := parse_browser_navigation_document('<!doctype html><style>html,body{margin:0}#target{width:30px;height:20px}#row{display:block}#row span{display:block;width:12px;height:8px}</style><div id="target"></div><div id="row"><span id="one">a</span><span id="two">b</span></div><div id="stable">unchanged</div>',
		dom.URL{ value: 'https://github.com/vlang/v' }, none)
	document.set_scripting_enabled_by_embedder(false)
	mut app := &BrowserApp{
		document:                    document
		viewport_width:              320
		viewport_height:             200
		background_resource_results: chan PreloadedResource{cap: 2}
	}
	app.relayout(320, 200 + app.chrome_height())
	return app
}

fn github_test_complete_stylesheet(mut app BrowserApp, name string, text string) {
	address := 'https://github.com/${name}.css'
	app.script_stylesheet_requests[address] = true
	mut link := app.document.create_element('link') or { panic(err) }
	link.set_attribute_value('rel', 'stylesheet')
	link.set_attribute_value('href', address)
	mut head := app.document.head() or { panic('missing head') }
	head.as_node().append_child(link.as_node()) or { panic(err) }
	app.background_resource_results <- PreloadedResource{
		url:          address
		body:         text
		source_url:   app.document.url.serialize()
		request_type: 'stylesheet'
	}
	app.poll_background_resources()
}

fn test_github_stylesheet_completion_preserves_tree_until_synchronous_query() {
	mut app := github_stylesheet_layout_fixture()
	defer { app.document.finalize() }
	old_root := voidptr(app.document.layout_root)
	app.frame_preparation_depth = 1
	github_test_complete_stylesheet(mut app, 'vox-test-site-sheet-query', '#target{width:80px}#row{display:flex}')
	if !disable_github_stylesheet_layout_reuse {
		assert voidptr(app.document.layout_root) == old_root
		assert app.document.needs_style_update_after_layout()
	}
	// Geometry queries still flush the new cascade and reconstruct changed boxes.
	app.document.update_layout(.debugging)
	app.adopt_current_document_geometry()
	target := app.document.get_element_by_id('target')?
	one := app.document.get_element_by_id('one')?
	two := app.document.get_element_by_id('two')?
	target_box := app.root_box.find_box(i64(target.as_node().unique_id()))?
	one_box := app.root_box.find_box(i64(one.as_node().unique_id()))?
	two_box := app.root_box.find_box(i64(two.as_node().unique_id()))?
	assert target_box.border_box().width == 80 * app.document.layout_coordinate_scale()
	assert two_box.border_box().y == one_box.border_box().y
	assert two_box.border_box().x > one_box.border_box().x
}

fn test_github_stylesheet_completion_applies_hidden_and_generated_content_at_frame_end() {
	mut app := github_stylesheet_layout_fixture()
	defer { app.document.finalize() }
	app.frame_preparation_depth = 1
	github_test_complete_stylesheet(mut app, 'vox-test-site-sheet-pseudo', '#target{display:none}#stable::before{content:"new";color:red}')
	app.finish_frame_preparation()
	target := app.document.get_element_by_id('target')?
	stable := app.document.get_element_by_id('stable')?
	assert css.up_to_date_computed_properties_for_element(target).display().is_none()
	assert app.root_box.find_box(i64(target.as_node().unique_id())) == none
	assert dom.AbstractElement.new(stable, .before).computed_properties() != none
	assert app.document.layout_is_up_to_date()
}

fn test_site_stylesheet_completion_keeps_non_github_and_initial_boundaries() {
	mut app := github_stylesheet_layout_fixture()
	defer { app.document.finalize() }
	app.initial_layout_pending = true
	assert !app.complete_site_stylesheet_update()
	app.initial_layout_pending = false
	app.document.url = dom.URL{ value: 'https://example.org/' }
	assert !app.complete_site_stylesheet_update()
}

fn test_github_stylesheet_completion_keeps_targeted_cssom_invalidation() {
	mut app := github_stylesheet_layout_fixture()
	defer { app.document.finalize() }
	stable := app.document.get_element_by_id('stable')?
	before := voidptr(css.computed_properties_for_element(stable)?)
	app.document.reset_style_invalidation_counters()
	app.frame_preparation_depth = 1
	github_test_complete_stylesheet(mut app, 'vox-test-site-sheet-targeted', '#target{width:80px}')
	if !disable_github_stylesheet_layout_reuse {
		assert !app.document.needs_full_style_update()
		assert app.document.style_invalidation_counters().full_style_invalidations == 0
	}
	app.finish_frame_preparation()
	target := app.document.get_element_by_id('target')?
	assert app.root_box.find_box(i64(target.as_node().unique_id()))?.border_box().width == 80 * app.document.layout_coordinate_scale()
	if !disable_github_stylesheet_layout_reuse {
		assert voidptr(css.computed_properties_for_element(stable)?) == before
	}
}

fn test_github_stylesheet_completion_preserves_broad_layer_invalidation() {
	mut app := github_stylesheet_layout_fixture()
	defer { app.document.finalize() }
	app.frame_preparation_depth = 1
	github_test_complete_stylesheet(mut app, 'vox-test-site-sheet-layer', '@layer new-layer;')
	if !disable_github_stylesheet_layout_reuse { assert app.document.needs_full_style_update() }
	app.finish_frame_preparation()
	assert app.document.layout_is_up_to_date()
}
