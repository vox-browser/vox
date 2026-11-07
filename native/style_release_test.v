module main

import css
import dom
import page

#include "@VMODROOT/css/computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
}

fn test_native_style_release_preserves_active_pages_and_clears_closed_shadow_pseudos() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://native-style.test/old', markup: '<!doctype html><div id="host"></div>'}, false)
	mut host := app.document.get_element_by_id('host')?
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .closed})!
	span := app.document.create_element('span')!
	mut root := unsafe { &dom.Node(shadow) }
	root.append_child(span.as_node())!
	css.add_shadow_root_author_style_sheet(shadow, 'span{color:green}span::before{content:"Shadow"}')
	app.relayout(320, 200)
	assert span.el_computed_properties() != none
	assert span.computed_properties_for_pseudo(int(dom.PseudoElement.before)) != none
	assert !css.discard_native_document_computed_styles(app.document)
	assert span.el_computed_properties() != none
	mut old := app.document
	app.install_loaded_page(LoadedPage{url: 'https://native-style.test/new', markup: '<!doctype html><p>Replacement</p>'}, false)
	defer { old.finalize(); app.document.finalize() }
	assert span.el_computed_properties() == none
	assert span.computed_properties_for_pseudo(int(dom.PseudoElement.before)) == none
	assert span.as_node().unsafe_layout_node() == none
	assert app.document.body()?.el_computed_properties() != none
	assert app.paint_commands.any(it.text.contains('Replacement'))
}

@[noinline]
fn create_native_retired_style_for_collection() {
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://native-style-gc.test/old', markup: '<!doctype html><p id="old" style="color:green">Old</p><input placeholder="query" value="old">'}, false)
	element := app.document.get_element_by_id('old') or { panic('old element') }
	properties := element.el_computed_properties() or { panic('old style') }
	$if gcboehm ? { C.vox_property_store_watch(0, voidptr(properties)); C.vox_property_store_watch(1, properties.css_handle) }
	app.install_loaded_page(LoadedPage{url: 'https://native-style-gc.test/new', markup: '<!doctype html><p>New</p>'}, false)
	app.document.finalize()
}

fn test_replaced_native_computed_style_becomes_collectible() {
	$if gcboehm ? {
		C.vox_property_store_worker(create_native_retired_style_for_collection)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 0
	} $else {
		create_native_retired_style_for_collection()
	}
}
