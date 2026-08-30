module main

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
