module main

import dom
import math

fn test_chromium_rounded_background_retains_hsl_channels_until_rasterization() {
	markup := '<!doctype html><base href="https://asgardpvp.com/"><div style="width:50px;height:24px;border-radius:30px;background:hsl(222,14%,7%)"></div>'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url:    'about:blank'
		markup: markup
	}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	mut app := BrowserApp{
		document: document
	}
	app.relayout(800, 680)
	commands := app.paint_commands.filter(it.kind == 'fill_rect' && it.radius > 0)
	assert commands.len == 1
	color := commands[0].srgb_color_data
	assert color != unsafe { nil }
	assert color.serialized == commands[0].color
	assert math.abs(color.components[0] - .0602) < 1e-8
	assert math.abs(color.components[1] - .06608) < 1e-8
	assert math.abs(color.components[2] - .0798) < 1e-8
	assert color.components[3] == 1
}

fn test_libweb_rounded_background_keeps_its_existing_byte_color() {
	markup := '<!doctype html><div style="width:50px;height:24px;border-radius:30px;background:hsl(222,14%,7%)"></div>'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url: 'about:blank', markup: markup},
		dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	mut app := BrowserApp{document: document}
	app.relayout(800, 680)
	commands := app.paint_commands.filter(it.kind == 'fill_rect' && it.radius > 0)
	assert commands.len == 1
	assert commands[0].srgb_color_data == unsafe { nil }
	assert commands[0].color == 'rgb(15 17 20)'
}
