module main

import color
import css
import dom
import domurl
import encoding
import fetch
import fileapi
import geolocation
import geometry
import gg
import highresolutiontime
import html
import http
import infra
import layout
import mimesniff
import namespace_
import os
import referrerpolicy
import selection
import sri
import storageapi
import url
import webvtt

const initial_width = 1024
const initial_height = 768
const toolbar_height = 62.0
const page_margin = 28.0

const demo_markup = '<!doctype html>
<html>
<head>
  <title>Ladybird V</title>
  <style>
    html { background: #e8edf3; color: #172033; font-size: 16px; }
    body { width: 760px; margin: 28px auto; padding: 36px; background: white;
           border: 1px solid #cbd5e1; border-radius: 14px; }
    h1 { color: #5b21b6; font-size: 34px; margin: 0 0 12px; }
    h2 { color: #334155; margin-top: 28px; }
    p { line-height: 1.55; margin: 10px 0; }
    .badge { display: block; width: 280px; padding: 10px 14px; margin: 20px 0;
             color: white; background: #6d28d9; border-radius: 8px; }
    code { color: #9f1239; background: #fff1f2; padding: 2px 5px; }
  </style>
</head>
<body>
  <h1>Ladybird, rendered by V</h1>
  <p>This native window was compiled from the translated LibWeb V modules.</p>
  <div class="badge">HTML → DOM → CSS → Layout → Paint</div>
  <h2>A working vertical slice</h2>
  <p>The document was parsed by <code>html.parse_document</code>, styled by the translated CSS
     engine, laid out by <code>layout.layout_document</code>, and painted into this window.</p>
  <p>Open a local HTML file by passing its path to the executable. Scroll with the mouse wheel,
     arrow keys, or Page Up/Page Down.</p>
</body>
</html>'

struct BrowserApp {
mut:
	ctx            &gg.Context = unsafe { nil }
	markup         string
	source_label   string
	viewport_width int
	scroll_y       f64
	content_height f64
	paint_commands []layout.PaintCommand
	status         string
}

// Keep the root executable linked against the translated support modules too. The visible page
// pipeline below directly exercises HTML, DOM, CSS, and Layout; these references make accidental
// breakage at the other translated root boundaries a build-time failure.
fn link_translated_modules() {
	_ = color.from_named_css_color_string
	_ = css.StyleInvalidationReason.dom_mutation
	_ = dom.NodeType.invalid
	_ = domurl.url_encode
	_ = encoding.TextEncoder.create
	_ = fetch.is_ok_status
	_ = fileapi.Blob.create
	_ = fileapi.File.construct
	_ = fileapi.FileList.create
	_ = geolocation.GeolocationCoordinates.create
	_ = geometry.DOMPoint.construct
	_ = highresolutiontime.coarsen_time
	_ = html.event_load
	_ = http.HeaderList.create
	_ = referrerpolicy.from_string
	_ = infra.ascii_whitespace
	_ = layout.translated_layout_function_count
	_ = layout.AvailableSize.make_indefinite()
	_ = mimesniff.javascript_mime_type_essence_strings
	_ = namespace_.html
	_ = selection.selection_create
	_ = sri.do_bytes_match_metadata_list
	_ = storageapi.registered_endpoints
	_ = url.percent_encode
	_ = webvtt.ScrollSetting.empty
}

fn html_escape(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn input_document() (string, string) {
	for argument in os.args[1..] {
		if argument == '--headless-smoke' || argument.starts_with('-psn_') {
			continue
		}
		if argument.trim_space().starts_with('<') {
			return argument, 'command-line HTML'
		}
		mut file_name := argument
		if file_name.starts_with('file://') {
			file_name = file_name['file://'.len..]
		}
		if os.is_file(file_name) {
			markup := os.read_file(file_name) or {
				return '<h1>Could not read file</h1><p>${html_escape(err.msg())}</p>', file_name
			}
			return markup, os.real_path(file_name)
		}
		return '<h1>Unsupported input</h1><p>The V-native viewer currently accepts a local HTML file or raw HTML, not a network URL.</p><p>${html_escape(argument)}</p>', argument
	}
	return demo_markup, 'built-in translated-engine demo'
}

fn clamp(value f64, low f64, high f64) f64 {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}

fn (mut app BrowserApp) relayout(window_width int) {
	available_width := if window_width > 360 { window_width - int(page_margin * 2.0) } else { 320 }
	document := html.parse_document(app.markup)
	root_box := layout.layout_document(document, f64(available_width))
	app.paint_commands = root_box.paint_commands()
	root_rect := root_box.border_box()
	app.content_height = root_rect.y + root_rect.height + page_margin * 2.0
	app.viewport_width = window_width
	app.status = '${app.paint_commands.len} paint commands · ${int(root_rect.width)}×${int(root_rect.height)} CSS px'
}

fn (app &BrowserApp) maximum_scroll(window_height int) f64 {
	return if app.content_height + toolbar_height > f64(window_height) {
		app.content_height + toolbar_height - f64(window_height)
	} else {
		0.0
	}
}

fn (mut app BrowserApp) scroll_by(delta f64, window_height int) {
	app.scroll_y = clamp(app.scroll_y + delta, 0.0, app.maximum_scroll(window_height))
}

fn paint_color(serialized string, opacity f64) gg.Color {
	parsed := css.parse_color_string(serialized) or { return gg.rgba(15, 23, 42, 255) }
	alpha := clamp(f64(parsed.a) * opacity, 0.0, 255.0)
	return gg.rgba(parsed.r, parsed.g, parsed.b, u8(int(alpha + 0.5)))
}

fn (mut app BrowserApp) draw_command(command layout.PaintCommand, page_x f32, page_y f32, window_height int) {
	x := page_x + f32(command.x)
	y := page_y + f32(command.y - app.scroll_y)
	w := f32(command.width)
	h := f32(command.height)
	if y + h < f32(toolbar_height) || y > f32(window_height) {
		return
	}
	match command.kind {
		'fill_rect' {
			fill := paint_color(command.color, command.opacity)
			if command.radius > 0.0 {
				app.ctx.draw_rounded_rect_filled(x, y, w, h, f32(command.radius), fill)
			} else {
				app.ctx.draw_rect_filled(x, y, w, h, fill)
			}
		}
		'fill_gradient' {
			if gradient := command.gradient {
				if gradient.colors.len > 0 {
					first := gradient.colors[0]
					app.ctx.draw_rect_filled(x, y, w, h, gg.rgba(first.r, first.g, first.b, u8(int(clamp(f64(first.a) * command.opacity,
						0.0, 255.0)))))
				}
			}
		}
		'draw_text' {
			font_size := int(clamp(command.height * 0.78, 10.0, 42.0))
			app.ctx.draw_text(int(x), int(y), command.text,
				color: paint_color(command.color, command.opacity)
				size:  font_size
			)
		}
		else {}
	}
}

fn (mut app BrowserApp) draw() {
	window := gg.window_size()
	if window.width > 0 && window.width != app.viewport_width {
		app.relayout(window.width)
		app.scroll_y = clamp(app.scroll_y, 0.0, app.maximum_scroll(window.height))
	}
	app.ctx.begin()
	app.ctx.draw_rect_filled(0, 0, f32(window.width), f32(window.height), gg.rgb(232, 237, 243))
	page_y := f32(toolbar_height + page_margin)
	for command in app.paint_commands {
		app.draw_command(command, f32(page_margin), page_y, window.height)
	}

	// Draw chrome last so scrolled page content cannot paint over it.
	app.ctx.draw_rect_filled(0, 0, f32(window.width), f32(toolbar_height), gg.rgb(23, 32, 51))
	app.ctx.draw_text(20, 10, 'Ladybird V', color: gg.rgb(255, 255, 255), size: 20)
	app.ctx.draw_text(20, 35, 'V engine · HTML → DOM → CSS → Layout',
		color: gg.rgb(196, 181, 253)
		size:  13
	)
	app.ctx.draw_text(320, 35, app.source_label, color: gg.rgb(203, 213, 225), size: 13)
	app.ctx.draw_text(window.width - 350, 10, app.status,
		color: gg.rgb(148, 163, 184)
		size:  12
	)
	app.ctx.end()
}

fn (mut app BrowserApp) handle_event(event &gg.Event) {
	match event.typ {
		.mouse_scroll {
			app.scroll_by(-f64(event.scroll_y) * 42.0, event.window_height)
		}
		.resized {
			app.relayout(event.window_width)
			app.scroll_y = clamp(app.scroll_y, 0.0, app.maximum_scroll(event.window_height))
		}
		else {}
	}
}

fn (mut app BrowserApp) handle_key(key gg.KeyCode) {
	height := gg.window_size().height
	match key {
		.up { app.scroll_by(-42.0, height) }
		.down { app.scroll_by(42.0, height) }
		.page_up { app.scroll_by(-f64(height) * 0.8, height) }
		.page_down { app.scroll_by(f64(height) * 0.8, height) }
		.home { app.scroll_y = 0.0 }
		.end { app.scroll_y = app.maximum_scroll(height) }
		.escape { app.ctx.quit() }
		else {}
	}
}

fn main() {
	link_translated_modules()
	markup, source_label := input_document()
	mut app := &BrowserApp{
		markup:       markup
		source_label: source_label
	}
	app.relayout(initial_width)

	if '--headless-smoke' in os.args {
		println('Ladybird V smoke check passed')
		println('source: ${app.source_label}')
		println(app.status)
		return
	}

	app.ctx = gg.new_context(
		width:            initial_width
		height:           initial_height
		min_width:        640
		min_height:       480
		window_title:     'Ladybird V'
		bg_color:         gg.rgb(232, 237, 243)
		native_rendering: true
		frame_fn:         fn (mut app BrowserApp) {
			app.draw()
		}
		event_fn:         fn (event &gg.Event, mut app BrowserApp) {
			app.handle_event(event)
		}
		keydown_fn:       fn (key gg.KeyCode, _ gg.Modifier, mut app BrowserApp) {
			app.handle_key(key)
		}
		user_data:        app
	)
	app.ctx.run()
}
