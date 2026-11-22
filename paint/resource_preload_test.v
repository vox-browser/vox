module main

import dom
import gg
import html
import layout

fn test_pending_background_requests_follow_root_paint_commands() {
	for address in ['http://paint-resources.test/arrow.svg', 'https://paint-resources.test/tile.png'] {
		command := layout.PaintCommand{
			kind: 'draw_background_image'
			width: 14
			height: 14
			image_data: &layout.PaintImageData{image_url: address}
		}
		assert pending_paint_background_url(&command)? == address
		for kind in ['draw_replaced_image', 'paint_nested_display_list', 'draw_canvas', 'fill_rect'] {
			other := layout.PaintCommand{...command, kind: kind}
			assert pending_paint_background_url(&other) == none
		}
		for local in ['file:///tmp/tile.png', 'data:image/png;base64,AA==', '/tmp/tile.png', ''] {
			other := layout.PaintCommand{...command, image_data: &layout.PaintImageData{image_url: local}}
			assert pending_paint_background_url(&other) == none
		}
		missing := layout.PaintCommand{...command, image_data: unsafe { nil }}
		assert pending_paint_background_url(&missing) == none
		for extent in [0.0, -1.0] {
			thin := layout.PaintCommand{...command, width: extent}
			short := layout.PaintCommand{...command, height: extent}
			assert pending_paint_background_url(&thin) == none
			assert pending_paint_background_url(&short) == none
		}
		mut svg := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg"></svg>')
		defer { svg.finalize() }
		resolved := layout.PaintCommand{...command, image_data: &layout.PaintImageData{
			image_url: address
			background_svg_document: svg
		}}
		assert pending_paint_background_url(&resolved) == none
	}
}

fn test_priming_keeps_cached_and_inflight_background_responses() {
	address := 'https://paint-resources.test/cached.svg'
	command := layout.PaintCommand{
		kind: 'draw_background_image'
		width: 10
		height: 10
		image_data: &layout.PaintImageData{image_url: address}
	}
	mut app := BrowserApp{
		ctx: &gg.Context{native_rendering: true}
		paint_commands: [command, command]
		resource_cache: {address: PreloadedResource{url: address, body: 'cached response'}}
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	app.prime_document_paint_resources()
	assert app.background_resource_pending.len == 0
	assert app.background_resource_results.len == 0
	assert app.resource_cache[address].body == 'cached response'
	app.resource_cache.clear()
	app.background_resource_pending[address] = true
	app.prime_document_paint_resources()
	assert app.background_resource_pending.len == 1
	assert app.background_resource_results.len == 0
	// A layout-only owner must not initiate renderer-specific network work.
	app.background_resource_pending.clear()
	app.ctx = unsafe { nil }
	app.prime_document_paint_resources()
	assert app.background_resource_pending.len == 0
}

fn test_first_page_of_a_windowed_launch_prefetches_before_the_native_context_exists() {
	mut app := BrowserApp{}
	assert !app.document_paints_natively()
	app.native_paint_expected = true
	assert app.document_paints_natively()
	// Once created, the context decides; headless/layout-only owners stay off.
	app.ctx = &gg.Context{native_rendering: false}
	assert !app.document_paints_natively()
	app.ctx = &gg.Context{native_rendering: true}
	app.native_paint_expected = false
	assert app.document_paints_natively()
}

fn test_initial_image_batch_shares_its_budget_between_favicon_and_unique_visible_backgrounds() {
	mut document := dom.Document.create(dom.URL{value: 'https://paint-resources.test/page'})
	defer { document.finalize() }
	mut markup := '<!doctype html><link rel="icon" href="/first.png"><link rel="icon" href="/tab.png">'
	markup += '<div style="display:none;background-image:url(/hidden.png)"></div>'
	for index in 0 .. initial_image_preload_limit {
		markup += '<div style="background-image:url(/bg-${index}.png)">Tile</div>'
		markup += '<div style="background-image:url(/bg-${index}.png)">Duplicate</div>'
	}
	html.parse_html_from_a_string(document, markup)
	mut app := BrowserApp{document: document}
	mut jobs := []ResourceFetchJob{}
	app.enqueue_initial_tab_favicon(mut jobs)
	app.enqueue_initial_tab_favicon(mut jobs)
	assert jobs.len == 1
	assert jobs[0].url == 'https://paint-resources.test/tab.png'
	layout.prepare_initial_resource_styles(document, 800, 600)
	mut found := InitialBackgroundPreloads{limit: initial_image_preload_limit - jobs.len}
	collect_initial_background_preloads(document.as_node(), mut found)
	for address in found.urls { app.enqueue_background_resource(address, mut jobs) }
	assert jobs.len == initial_image_preload_limit
	for index in 1 .. jobs.len {
		assert jobs[index].url == 'https://paint-resources.test/bg-${index - 1}.png'
	}
}
