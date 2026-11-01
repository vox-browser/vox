module main

import css
import dom
import html
import layout

fn static_svg_background_test_command(commands []layout.PaintCommand) layout.PaintCommand {
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind == 'draw_background_image' && command.image_data != unsafe { nil }
			&& command.image_data.background_static_svg_resource != none {
			return *command
		}
	}
	panic('missing static SVG background command')
}

fn static_svg_background_test_fill(commands []layout.PaintCommand) css.Color {
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind == 'draw_svg_path' {
			if color := command.retained_svg_fill_color() { return color }
		}
	}
	panic('missing solid SVG path')
}

fn test_native_static_svg_background_refresh_preserves_owned_replay_and_msaa() {
	$if !prealloc {
		return
	}
	address := 'https://native-static-svg-cache.example.test/sprite.svg?version=1'
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:30px;height:20px;background:url("${address}") no-repeat}</style><div id="target"></div>')
	document.enable_native_storage()
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 1}
		background_resource_pending: {
			address: true
		}
	}
	defer {
		app.release_paint_commands()
		layout.release_paint_tree(app.paint_tree_storage)
		layout.retire_native_document_layout(document.layout_engine_handle())
		document.finalize()
		document.release_native_storage()
	}
	app.relayout(200, 232)
	before := layout.document_layout_result(document) or { panic('missing layout') }
	root := before.root
	state := before.state
	assert !app.paint_commands.any(it.image().background_static_svg_resource != none)
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="20"><path d="M0 0L30 0L15 20Z" fill="red"/></svg>'
	}
	app.poll_background_resources()
	assert address !in app.background_resource_pending
	assert !app.paint_commands.any(it.image().background_svg_document != none)
	first := static_svg_background_test_command(app.paint_commands)
	first_resource := first.image_data.background_static_svg_resource or { panic('missing first resource') }
	first_commands := svg_background_paint_commands(first.image_data, 30, 20) or { panic('missing first picture') }
	assert static_svg_background_test_fill(first_commands) == css.Color.rgb(255, 0, 0)
	repeated := svg_background_paint_commands(first.image_data, 30, 20) or { panic('missing cached picture') }
	assert voidptr(repeated.data) == voidptr(first_commands.data)
	// Distinct fractional viewports must not alias the same integer-size scene.
	fractional := svg_background_paint_commands_for_viewport(first.image_data,30.125,20.25) or { panic('fractional picture') }
	other := svg_background_paint_commands_for_viewport(first.image_data,30.25,20.25) or { panic('other fractional picture') }
	assert voidptr(fractional.data) != voidptr(other.data)
	cached_fractional := svg_background_paint_commands_for_viewport(first.image_data,30.125,20.25) or { panic('cached fractional picture') }
	assert voidptr(cached_fractional.data) == voidptr(fractional.data)
	assert static_svg_background_test_fill(fractional) == css.Color.rgb(255,0,0)
	first_ranges := chromium_svg_background_msaa_ranges(first)
	assert first_ranges.len == 1
	first_body := app.resource_cache[address].body
	// Native layout may use display pixels while SVG user space remains in
	// CSS pixels. Compare both storage paths under the same host transform.
	mut generic := dom.Document.create(dom.URL{value: address})
	generic.enable_native_storage()
	generic.set_content_type('image/svg+xml')
	generic.set_document_type(.xml)
	generic.set_is_svg_image_document(true)
	generic.set_font_rendering_policy(.chromium)
	defer {
		layout.retire_native_document_layout(generic.layout_engine_handle())
		generic.finalize()
		generic.release_native_storage()
	}
	html.parse_xml_document_source(generic, first_body) or { panic(err) }
	generic_command := layout.PaintCommand{
		...first
		image_data: &layout.PaintImageData{
			...first.image_data
			background_static_svg_resource: none
			background_svg_document: generic
		}
	}
	assert chromium_svg_background_msaa_ranges(generic_command) == first_ranges
	assert first_ranges[0] == [first.transform[5], 20 * first.transform[3] + first.transform[5]]
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: first_body.replace('red', 'tan')
	}
	app.poll_background_resources()
	assert app.resource_cache[address].body.len == first_body.len
	after := layout.document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(after.root) == voidptr(root)
	assert voidptr(after.state) == voidptr(state)
	assert !app.paint_commands.any(it.image().background_svg_document != none)
	second := static_svg_background_test_command(app.paint_commands)
	second_resource := second.image_data.background_static_svg_resource or { panic('missing replacement resource') }
	assert voidptr(second_resource) != voidptr(first_resource)
	second_commands := svg_background_paint_commands(second.image_data, 30, 20) or { panic('missing replacement picture') }
	assert static_svg_background_test_fill(second_commands) == css.Color.rgb(210, 180, 140)
	assert chromium_svg_background_msaa_ranges(second) == first_ranges
	assert static_svg_background_test_fill(first_commands) == css.Color.rgb(255, 0, 0)
	app.background_resource_results <- PreloadedResource{
		url:   address
		error: 'replacement failed'
	}
	app.poll_background_resources()
	assert !app.paint_commands.any(it.image().background_static_svg_resource != none)
	assert !app.paint_commands.any(it.image().background_svg_document != none)
	failed := layout.document_layout_result(document) or { panic('missing layout after failed replacement') }
	assert voidptr(failed.root) == voidptr(root)
	assert voidptr(failed.state) == voidptr(state)
	assert static_svg_background_test_fill(first_commands) == css.Color.rgb(255, 0, 0)
	assert static_svg_background_test_fill(second_commands) == css.Color.rgb(210, 180, 140)
}
