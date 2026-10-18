module layout

import dom
import html
import http
import loader
import os
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

const cached_svg_image_source = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10" viewBox="0 0 20 10"><defs><linearGradient id="gradient"><stop offset="0" stop-color="lime"/></linearGradient></defs><path id="shape" d="M0 0H20V10H0Z" fill="url(#gradient)"/></svg>'

fn svg_document_cache_test_loader() &loader.ResourceLoader {
	return if loader.is_initialized() { loader.ResourceLoader.the() } else { loader.initialize() }
}

fn register_svg_document_cache_test_source(address string, source string) {
	mut resource_loader := svg_document_cache_test_loader()
	resource_loader.register_network_response(address, loader.NetworkResponse{
		data:    source.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
}

fn svg_document_cache_test_background(root &BlockBox, document &dom.Document, id string) &dom.Document {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing ${id} box') }
	return box.background_images[0].svg_document or { panic('missing ${id} SVG document') }
}

fn test_svg_background_documents_share_the_current_viewport_and_color_environment() {
	address := 'https://svg-cache.test/shared.svg'
	register_svg_document_cache_test_source(address, cached_svg_image_source)
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}.sample{width:20px;height:10px;background:url("${address}") no-repeat;color-scheme:light}.dark{color-scheme:dark}</style><div id="one" class="sample"></div><div id="two" class="sample"></div><div id="dark" class="sample dark"></div>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	one := svg_document_cache_test_background(&root, document, 'one')
	two := svg_document_cache_test_background(&root, document, 'two')
	dark := svg_document_cache_test_background(&root, document, 'dark')
	assert voidptr(one) == voidptr(two)
	assert voidptr(one) != voidptr(dark)
	assert one.svg_image_color_scheme()? == 'light'
	assert dark.svg_image_color_scheme()? == 'dark'
	result := document_layout_result(document) or { panic('missing layout') }
	viewport := result.root.as_viewport() or { panic('missing viewport') }
	assert viewport.svg_image_documents_.len == 2
	$if gcboehm ? { C.GC_gcollect() }
	assert one.get_element_by_id('shape') != none
	assert two.get_element_by_id('gradient') != none
}

fn test_svg_background_sharing_preserves_layout_sizes_clean_display_lists_and_resource_mutations() {
	address := 'https://svg-cache.test/layout.svg'
	register_svg_document_cache_test_source(address, cached_svg_image_source)
	document :=
		html.parse_document('<!doctype html><style>div{width:20px;height:10px;background:url("${address}");color-scheme:light}</style><div id="one"></div><div id="two"></div>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	mut isolated := svg_document_cache_test_background(&root, document, 'one')
	assert voidptr(isolated) == voidptr(svg_document_cache_test_background(&root, document, 'two'))
	_ = run_document_layout(isolated, 20, 10) or { panic('missing first SVG layout') }
	first_handle := isolated.layout_engine_handle()
	// Retained so its storage is not reused by the later recordings compared below.
	first_list := record_retained_display_list(mut isolated) or { panic('missing first SVG list') }
	_ = run_document_layout(isolated, 20, 10) or { panic('missing repeated SVG layout') }
	assert isolated.layout_engine_handle() == first_handle
	assert voidptr(isolated.record_display_list()?) == voidptr(first_list)
	_ = run_document_layout(isolated, 40, 30) or { panic('missing resized SVG layout') }
	assert isolated.viewport_rect().width == 40
	assert isolated.viewport_rect().height == 30
	assert isolated.layout_engine_handle() != first_handle
	assert voidptr(isolated.record_display_list()?) != voidptr(first_list)
	_ = run_document_layout(isolated, 20, 10) or { panic('missing restored SVG layout') }
	assert isolated.viewport_rect().width == 20
	assert isolated.viewport_rect().height == 10
	mut gradient := isolated.get_element_by_id('gradient') or { panic('missing gradient') }
	stop := gradient.as_node().first_child()?.as_element()?
	mut mutable_stop := unsafe { &dom.Element(stop) }
	mutable_stop.set_attribute_value('stop-color', 'blue')
	_ = run_document_layout(isolated, 20, 10) or { panic('missing mutated SVG layout') }
	mutated_commands := display_list_commands(isolated.record_display_list()?)
	paths := mutated_commands.filter(it.kind == 'draw_svg_path')
	gradient_paint := paths[0].fill_linear_gradient() or { panic('missing mutated gradient') }
	assert gradient_paint.gradient.color_stops[0].color == painting.Color{0, 0, 255, 255}
}

fn test_svg_background_cache_checks_exact_response_bytes_and_preserves_earlier_documents() {
	address := 'https://svg-cache.test/replaced.svg'
	register_svg_document_cache_test_source(address, cached_svg_image_source)
	document :=
		html.parse_document('<!doctype html><div id="one" style="width:20px;height:10px;background:url(${address})"></div>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	before := svg_document_cache_test_background(&root, document, 'one')
	result := document_layout_result(document) or { panic('missing layout') }
	changed := cached_svg_image_source.replace('lime', 'blue')
	assert changed.len == cached_svg_image_source.len
	register_svg_document_cache_test_source(address, changed)
	after := svg_image_document_for_source_in_viewport(result.root, address, image_color_scheme(document,
		result.root.computed_values())) or { panic('missing replacement') }
	assert voidptr(before) != voidptr(after)
	assert before.get_element_by_id('gradient')?.as_node().first_child()?.as_element()?.get_attribute_value('stop-color') == 'lime'
	assert after.get_element_by_id('gradient')?.as_node().first_child()?.as_element()?.get_attribute_value('stop-color') == 'blue'
	assert voidptr(svg_image_document_for_source_in_viewport(result.root, address, image_color_scheme(document,
		result.root.computed_values()))?) == voidptr(after)
	mut resource_loader := svg_document_cache_test_loader()
	resource_loader.register_network_response(address, loader.NetworkResponse{ status_code: 404 })
	assert svg_image_document_for_source_in_viewport(result.root, address, image_color_scheme(document,
		result.root.computed_values())) == none
}

fn test_svg_background_cache_keeps_fragment_and_viewport_ownership_distinct() {
	address := 'https://svg-cache.test/fragments.svg'
	register_svg_document_cache_test_source(address, cached_svg_image_source)
	mut document :=
		html.parse_document('<!doctype html><style>div{width:20px;height:10px;color-scheme:light}</style><div id="one" style="background:url(${address}#one)"></div><div id="two" style="background:url(${address}#two)"></div>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	one := svg_document_cache_test_background(&root, document, 'one')
	two := svg_document_cache_test_background(&root, document, 'two')
	assert voidptr(one) != voidptr(two)
	assert one.url.serialize() == address + '#one'
	assert two.url.serialize() == address + '#two'
	old_result := document_layout_result(document) or { panic('missing old layout') }
	document.set_needs_full_layout_tree_update(true)
	rebuilt := layout_document_typed_in_viewport(document, 100, 100)
	new_one := svg_document_cache_test_background(&rebuilt, document, 'one')
	new_result := document_layout_result(document) or { panic('missing rebuilt layout') }
	assert voidptr(old_result.root) != voidptr(new_result.root)
	assert voidptr(one) != voidptr(new_one)
	assert old_result.root.as_viewport()?.svg_image_documents_.len == 2
	assert new_result.root.as_viewport()?.svg_image_documents_.len == 2
	assert one.get_element_by_id('shape') != none
}

fn test_svg_background_cache_rechecks_local_files_and_covers_body_and_inline_layers() {
	file_path := os.join_path(os.temp_dir(), 'vox-svg-image-cache-${os.getpid()}.svg')
	os.write_file(file_path, cached_svg_image_source)!
	defer { os.rm(file_path) or {} }
	address := 'file://' + file_path
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0;color-scheme:light}body,div,span{background-image:url("${address}");background-repeat:no-repeat}div{width:20px;height:10px}</style><body><div></div><span>inline</span></body>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	layers := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert layers.len >= 3
	before := layers[0].image().background_svg_document or { panic('missing first background') }
	for layer in layers {
		assert voidptr(layer.image().background_svg_document?) == voidptr(before)
	}
	os.write_file(file_path, cached_svg_image_source.replace('lime', 'blue'))!
	result := document_layout_result(document) or { panic('missing layout') }
	after := svg_image_document_for_source_in_viewport(result.root, address, .light) or {
		panic('missing changed local image')
	}
	assert voidptr(after) != voidptr(before)
	assert before.get_element_by_id('gradient')?.as_node().first_child()?.as_element()?.get_attribute_value('stop-color') == 'lime'
	assert after.get_element_by_id('gradient')?.as_node().first_child()?.as_element()?.get_attribute_value('stop-color') == 'blue'
}
