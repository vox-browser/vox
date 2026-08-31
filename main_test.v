module main

import html
import os

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

fn test_document_preload_resources_are_resolved_deduplicated_and_ordered() {
	document := html.parse_document('<html><head>
		<link rel="stylesheet" href="/news.css">
		<link rel="stylesheet" href="/news.css">
		<script src="hn.js"></script>
		<script type="application/json" src="ignored.json"></script>
		</head><body>
		<img src="/y18.svg"><img src="data:image/gif;base64,AA==">
		</body></html>')
	urls := document_preload_resource_urls(document, 'https://news.ycombinator.com/news')
	assert urls == [
		'https://news.ycombinator.com/news.css',
		'https://news.ycombinator.com/hn.js',
		'https://news.ycombinator.com/y18.svg',
	]
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
