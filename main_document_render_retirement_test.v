module main

import css
import dom
import page

#include "css/computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	__global native_retired_renderer_app_ &BrowserApp
	__global native_retired_renderer_document_ &dom.Document

	fn prepare_retired_renderer_before_new_layout() {
		owner := page.Page.create(1) or { panic(err) }
		mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
		app.install_loaded_page(LoadedPage{url: 'https://retired-renderer.test/old', markup: '<!doctype html><p id="old" style="color:green">Old results</p><input placeholder="Search">'}, false)
		old := app.document
		element := old.get_element_by_id('old') or { panic('old element') }
		properties := element.el_computed_properties() or { panic('old properties') }
		C.vox_property_store_watch(0, app.root_box.layout_handle)
		C.vox_property_store_watch(1, properties.css_handle)
		app.document = parse_loaded_browser_navigation_document(LoadedPage{
			url: 'https://retired-renderer.test/new'
			markup: '<!doctype html><p>New results</p>'
		}, dom.URL{value: 'https://retired-renderer.test/new'}, none, old,
			unsafe { &dom.Page(owner) }, false)
		// Isolate the shell's references: the Document has already dropped its
		// backend and resolved styles, but the new page has not been laid out.
		css.discard_native_document_computed_styles(old)
		native_retired_renderer_app_ = app
		native_retired_renderer_document_ = old
	}

	fn release_retired_renderer_before_new_layout() {
		mut app := native_retired_renderer_app_
		assert app.retire_native_document_rendering(native_retired_renderer_document_)
	}
}

fn test_outgoing_render_tree_and_styles_are_collectible_before_replacement_layout() {
	$if gcboehm ? {
		C.vox_property_store_worker(prepare_retired_renderer_before_new_layout)
		C.vox_property_store_collect(8)
		assert (C.vox_property_store_alive() & 2) == 2
		C.vox_property_store_worker(release_retired_renderer_before_new_layout)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 0
		assert native_retired_renderer_app_.document.layout_engine_handle() == unsafe { nil }
	}
}

fn test_early_retirement_preserves_active_rendering_and_paint_revisions_advance() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://retired-renderer.test/active', markup: '<!doctype html><p id="live">Current results</p>'}, false)
	defer { app.document.finalize() }
	generation := app.paint_generation
	list := app.paint_display_list
	assert generation > 0
	assert !app.retire_native_document_rendering(app.document)
	assert app.paint_display_list == list
	assert app.paint_generation == generation
	assert app.root_box.layout_handle != unsafe { nil }
	assert app.paint_commands.any(it.text.contains('Current results'))
	mut target := app.document.get_element_by_id('live')?
	mut target_node := target.as_node()
	target_node.set_text_content('Updated results')!
	app.relayout(320, 200 + app.chrome_height())
	assert app.paint_generation > generation
	assert app.paint_commands.any(it.text.contains('Updated results'))
}
