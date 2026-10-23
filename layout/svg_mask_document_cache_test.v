module layout

import dom
import html
import http
import loader
import painting

const mask_cache_svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10"><style>@media(prefers-color-scheme:dark){#shape{fill:blue}}</style><defs><linearGradient id="gradient"><stop offset="0" stop-color="lime"/></linearGradient></defs><path id="shape" d="M0 0H20V10H0Z" fill="url(#gradient)"/></svg>'

fn register_mask_cache_source(address string, source string) {
	mut resources := if loader.is_initialized() {
		loader.ResourceLoader.the()
	} else {
		loader.initialize()
	}
	resources.register_network_response(address, loader.NetworkResponse{
		data:    source.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
}

fn mask_cache_collect(root &Node, address string, width f64, height f64, dark bool) SVGMaskPaintCollection {
	mut collection := SVGMaskPaintCollection{}
	assert collect_svg_vector_image_paint_operations(root, address, painting.Rect{3, 5, width, height}, if dark {
		.dark
	} else {
		.light
	}, mut collection)
	assert collection.operations.len == 1
	return collection
}

fn mask_cache_gradient_color(collection SVGMaskPaintCollection) painting.Color {
	gradient := collection.operations[0].fill_linear_gradient or { panic('missing gradient') }
	return gradient.gradient.color_stops[0].color
}

fn test_svg_masks_share_background_documents_and_preserve_retained_operations() {
	address := 'https://svg-mask-cache.test/shared.svg'
	register_mask_cache_source(address, mask_cache_svg)
	mut document :=
		html.parse_document('<!doctype html><style>div{width:20px;height:10px;color-scheme:light;background:url("${address}");mask-image:url("${address}")}</style><div id="one"></div><div id="two"></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 100, 80)
	result := document_layout_result(document) or { panic('missing layout') }
	viewport := result.root.as_viewport() or { panic('missing viewport') }
	assert viewport.svg_image_documents_.len == 1
	one := document.get_element_by_id('one')?
	box := root.find_box(i64(one.as_node().unique_id()))?
	mut isolated := box.decorations().background_images[0].svg_document?
	first := mask_cache_collect(result.root, address, 20, 10, false)
	first_handle := isolated.layout_engine_handle()
	repeated := mask_cache_collect(result.root, address, 20, 10, false)
	assert isolated.layout_engine_handle() == first_handle
	assert first.operations == repeated.operations
	assert mask_cache_gradient_color(first) == painting.Color{0, 255, 0, 255}
	_ = mask_cache_collect(result.root, address, 40, 20, false)
	assert isolated.viewport_rect().width == 40
	assert isolated.layout_engine_handle() != first_handle
	assert first.operations == repeated.operations
	assert mask_cache_gradient_color(first) == painting.Color{0, 255, 0, 255}
	dark := mask_cache_collect(result.root, address, 20, 10, true)
	assert dark.operations[0].fill_color == painting.Color{0, 0, 255, 255}
	assert viewport.svg_image_documents_.len == 2
	assert isolated.svg_image_color_scheme()? == 'light'
	assert mask_cache_gradient_color(first) == painting.Color{0, 255, 0, 255}
	_ = run_document_layout(isolated, 20, 10)?
	isolated_list := isolated.record_display_list()?
	commands := display_list_commands(isolated_list)
	assert commands.filter(it.kind == 'draw_svg_path').len == 1
	assert mask_cache_collect(result.root, address, 20, 10, false).operations == first.operations
}

fn test_svg_mask_cache_rechecks_exact_response_bytes_and_failures() {
	address := 'https://svg-mask-cache.test/replaced.svg'
	register_mask_cache_source(address, mask_cache_svg)
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 100, 80)?
	first := mask_cache_collect(result.root, address, 20, 10, false)
	before := svg_image_document_for_source_in_viewport(result.root, address, .light)?
	changed := mask_cache_svg.replace('lime', 'blue')
	assert changed.len == mask_cache_svg.len
	register_mask_cache_source(address, changed)
	second := mask_cache_collect(result.root, address, 20, 10, false)
	after := svg_image_document_for_source_in_viewport(result.root, address, .light)?
	assert voidptr(before) != voidptr(after)
	assert mask_cache_gradient_color(first) == painting.Color{0, 255, 0, 255}
	assert mask_cache_gradient_color(second) == painting.Color{0, 0, 255, 255}
	mut resources := loader.ResourceLoader.the()
	resources.register_network_response(address, loader.NetworkResponse{ status_code: 404 })
	mut failed := SVGMaskPaintCollection{}
	assert !collect_svg_vector_image_paint_operations(result.root, address, painting.Rect{0, 0, 20, 10},
		.light, mut failed)
	assert failed.operations.len == 0
	assert mask_cache_gradient_color(second) == painting.Color{0, 0, 255, 255}
}

fn test_svg_mask_cache_is_owned_by_each_embedding_layout_tree() {
	address := 'https://svg-mask-cache.test/ownership.svg'
	register_mask_cache_source(address, mask_cache_svg)
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	first := run_document_layout(document, 100, 80)?
	_ = mask_cache_collect(first.root, address, 20, 10, false)
	before := svg_image_document_for_source_in_viewport(first.root, address, .light)?
	document.set_needs_full_layout_tree_update(true)
	second := run_document_layout(document, 100, 80)?
	_ = mask_cache_collect(second.root, address, 20, 10, false)
	after := svg_image_document_for_source_in_viewport(second.root, address, .light)?
	assert voidptr(first.root) != voidptr(second.root)
	assert voidptr(before) != voidptr(after)
	assert before.get_element_by_id('shape') != none
	assert after.get_element_by_id('shape') != none
}
