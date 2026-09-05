module main

import css
import html
import layout
import os
import painting

fn test_parse_launch_options_keeps_interactive_defaults() {
	options := parse_launch_options(['https://example.com']) or { panic(err) }
	assert options.source == 'https://example.com'
	assert options.width == initial_width
	assert options.height == initial_height
}

fn test_parse_launch_options_accepts_explicit_window_dimensions() {
	options := parse_launch_options([
		'--window-width=640',
		'--window-height',
		'480',
		'<p>Hello</p>',
	]) or { panic(err) }
	assert options.source == '<p>Hello</p>'
	assert options.width == 640
	assert options.height == 480
}

fn test_parse_launch_options_accepts_screenshot_output() {
	options := parse_launch_options([
		'--screenshot',
		'/tmp/example.png',
		'https://example.com',
	]) or { panic(err) }
	assert options.screenshot == '/tmp/example.png'
	assert options.source == 'https://example.com'
}

fn test_parse_launch_options_rejects_empty_screenshot_output() {
	parse_launch_options(['--screenshot=']) or {
		assert err.msg().contains('PNG output path')
		return
	}
	assert false, 'an empty screenshot output path must be rejected'
}

fn test_parse_launch_options_rejects_invalid_dimensions() {
	parse_launch_options(['--window-height', '0']) or {
		assert err.msg().contains('positive integer')
		return
	}
	assert false, 'a non-positive window dimension must be rejected'
}

fn test_native_text_draw_y_converts_layout_line_box_to_cocoa_position() {
	assert native_text_draw_y(90, 28) == 104
	assert native_text_draw_y(134, 18) == 138
	assert native_text_draw_y(10, 10) == 10
}

fn test_native_gradient_clip_path_is_one_closed_tile_path() {
	path := native_gradient_clip_path(layout.PaintCommand{
		gradient_background_layer: true
	}, painting.Rect{10, 20, 30, 40})
	stride := layout.compatibility_clip_path_segment_stride
	assert path.len == 5 * stride
	assert path[0] == 0
	assert path[stride] == 1
	assert path[2 * stride] == 1
	assert path[3 * stride] == 1
	assert path[4 * stride] == 5
	assert path[1] == 10 && path[2] == 20
	assert path[2 * stride + 1] == 40 && path[2 * stride + 2] == 60
}

fn test_native_gradient_stop_data_preserves_hard_stops_and_applies_opacity() {
	gradient := layout.LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 128}]
		stops: [
			layout.GradientStop{css.Color{255, 0, 0, 255}, 0.0},
			layout.GradientStop{css.Color{255, 0, 0, 255}, 0.5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, 0.5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, 1.0},
		]
	}
	data := native_gradient_stop_data(gradient, 0.5)
	mut half_offsets := 0
	for index := 0; index < data.len; index += 5 {
		if data[index + 4] == 0.5 {
			half_offsets++
		}
		assert data[index + 3] <= 0.5
	}
	assert half_offsets == 2
	assert data[3] == 0.5
	assert data[data.len - 2] > 0.25 && data[data.len - 2] < 0.252
}

fn test_backdrop_filter_canvas_detection_descends_into_nested_viewports() {
	assert !paint_commands_contain_backdrop_filter([
		layout.PaintCommand{ kind: 'fill_rect' },
	])
	assert paint_commands_contain_backdrop_filter([
		layout.PaintCommand{
			kind: 'paint_nested_display_list'
			nested_viewport_commands: [
				layout.PaintCommand{ kind: 'apply_backdrop_filter' },
			]
		},
	])
}

fn test_document_preload_resources_are_resolved_deduplicated_and_ordered() {
	document := html.parse_document('<html><head>
		<link rel="stylesheet" href="/news.css">
		<link rel="stylesheet" href="/news.css">
		<script src="hn.js"></script>
		<script type="application/json" src="ignored.json"></script>
		</head><body>
		<img src="/y18.svg"><img src="data:image/gif;base64,AA==">
		<svg><image href="/mask.png"/><image xlink:href="legacy.png"/>
		<image href="/y18.svg"/><image href="" xlink:href="ignored.png"/></svg>
		</body></html>')
	urls := document_preload_resource_urls(document, 'https://news.ycombinator.com/news')
	assert urls == [
		'https://news.ycombinator.com/news.css',
		'https://news.ycombinator.com/hn.js',
		'https://news.ycombinator.com/y18.svg',
		'https://news.ycombinator.com/mask.png',
		'https://news.ycombinator.com/legacy.png',
	]
}

fn test_svg_image_contain_destination_preserves_ratio_and_object_position() {
	x, y, width, height := contained_image_destination(10, 20, 100, 100, 200, 100, '25%', '75%')
	assert x == 10
	assert y == 57.5
	assert width == 100
	assert height == 50
}

fn test_svg_image_contain_destination_resolves_computed_edge_offsets() {
	x, y, width, height := contained_image_destination(10, 20, 100, 100, 50, 100, 'calc(100% - 10px)', 'calc(100% - 20px)')
	assert x == 50
	assert y == 0
	assert width == 50
	assert height == 100
}

fn test_document_preload_resources_are_bounded() {
	mut markup := '<html><head>'
	for index in 0 .. max_preloaded_resources + 5 {
		markup += '<link rel="stylesheet" href="/${index}.css">'
	}
	markup += '</head></html>'
	document := html.parse_document(markup)
	urls := document_preload_resource_urls(document, 'https://example.com/')
	assert urls.len == max_preloaded_resources
	assert urls[0] == 'https://example.com/0.css'
	assert urls[urls.len - 1] == 'https://example.com/${max_preloaded_resources - 1}.css'
}

fn test_successful_page_cache_round_trip() {
	cache_directory := os.join_path(os.temp_dir(), 'ladybird-v-cache-test-${os.getpid()}')
	os.rmdir_all(cache_directory) or {}
	previous_cache_directory := os.getenv_opt('LADYBIRD_CACHE_DIR')
	os.setenv('LADYBIRD_CACHE_DIR', cache_directory, true)
	defer {
		if previous := previous_cache_directory {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache_directory) or {}
	}

	cache_loaded_page(LoadedPage{
		url: 'https://news.ycombinator.com'
		markup: '<html><title>Cached HN</title></html>'
		status: 'HTTP 200'
		content_type: 'text/html; charset=utf-8'
	})
	cached := read_cached_page('https://news.ycombinator.com') or {
		panic('cached page was not restored')
	}
	assert cached.markup == '<html><title>Cached HN</title></html>'
	assert cached.status == 'Cached · refreshing'
	assert cached.content_type == 'text/html'
}

fn test_cached_status_is_replaced_without_relayout() {
	mut app := BrowserApp{
		load_status: 'Cached · refreshing'
		status: 'Cached · refreshing · 525 paints · 1200×1219 CSS px'
	}
	app.replace_load_status('HTTP 200 · 35000 bytes')
	assert app.load_status == 'HTTP 200 · 35000 bytes'
	assert app.status == 'HTTP 200 · 35000 bytes · 525 paints · 1200×1219 CSS px'
}

fn test_address_for_display_handles_a_narrow_toolbar() {
	assert address_for_display('file:///tmp/example.html', 0, false, 0) == ''
	assert address_for_display('file:///tmp/example.html', 0, true, -4) == ''
}
