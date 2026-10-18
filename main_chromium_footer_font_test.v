module main

import dom
import math

fn test_chromium_small_monospace_lines_keep_blink_line_height_precision() {
	markup := '<!doctype html><base href="https://asgardpvp.com/"><style>body{margin:0;font:9px/1.3 monospace}</style>First line<br>Second line<br>Third line'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url:    'about:blank'
		markup: markup
	}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	mut app := BrowserApp{
		document: document
	}
	app.relayout(800, 680)
	text := app.paint_commands.filter(it.kind == 'draw_text')
	assert text.len == 3
	assert math.abs(text[1].y - text[0].y - 11.6875) < 1e-9
	assert math.abs(text[2].y - text[1].y - 11.6875) < 1e-9
}
