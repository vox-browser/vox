module main

import layout
import css
import dom
import os

const disable_paint_resource_prefetch = os.getenv('VOX_DISABLE_PAINT_RESOURCE_PREFETCH') != ''
const paint_resource_prefetch_diagnostics = os.getenv('VOX_PAINT_RESOURCE_PREFETCH_DIAGNOSTICS') != ''

// The root display list has already selected its paintable backgrounds. Start
// unresolved network images during preparation, allowing completed responses to
// join the first paint instead of requesting them from inside native replay.
fn pending_paint_background_url(command &layout.PaintCommand) ?string {
	if command.kind != 'draw_background_image' || command.image_data == unsafe { nil }
		|| command.width <= 0 || command.height <= 0 {
		return none
	}
	image := command.image_data
	if image.background_svg_document != none || image.background_static_svg_resource != none {
		return none
	}
	address := image.image_url
	if !address.starts_with('http://') && !address.starts_with('https://') { return none }
	return address
}

fn (mut app BrowserApp) prime_document_paint_resources() {
	if disable_paint_resource_prefetch || app.ctx == unsafe { nil } || !app.ctx.native_rendering { return }
	before := app.background_resource_pending.len
	for index in 0 .. app.paint_commands.len {
		if address := pending_paint_background_url(&app.paint_commands[index]) {
			app.request_background_resource(address)
		}
	}
	if paint_resource_prefetch_diagnostics && app.background_resource_pending.len > before {
		eprintln('VOX_PAINT_RESOURCE_PREFETCH requests=${app.background_resource_pending.len - before}')
	}
}

const disable_initial_background_preload = os.getenv('VOX_DISABLE_INITIAL_BACKGROUND_PRELOAD') != ''
const initial_background_preload_diagnostics = os.getenv('VOX_INITIAL_BACKGROUND_PRELOAD_DIAGNOSTICS') != ''
const initial_background_preload_limit = 4

struct InitialBackgroundPreloads {
mut:
	urls []string
	seen map[string]bool
}

fn collect_initial_background_preloads(node &dom.Node, mut found InitialBackgroundPreloads) {
	if found.urls.len >= initial_background_preload_limit { return }
	if element := node.as_element() {
		style := css.computed_properties_for_element(element) or { return }
		if style.display().is_none() { return }
		if !style.display().is_contents() && style.visibility() == .visible {
			for address in style.background_resource_urls() {
				if address in found.seen { continue }
				found.seen[address] = true
				found.urls << address
				if found.urls.len == initial_background_preload_limit { return }
			}
		}
	}
	for child in node.children { collect_initial_background_preloads(child, mut found) }
}

fn (mut app BrowserApp) prime_initial_computed_background_resources(width f64, height f64) {
	if disable_initial_background_preload || app.ctx == unsafe { nil } || !app.ctx.native_rendering
		|| app.document == unsafe { nil } || app.document.layout_root != unsafe { nil } { return }
	layout.prepare_initial_resource_styles(app.document, width, height)
	mut found := InitialBackgroundPreloads{}
	collect_initial_background_preloads(app.document.as_node(), mut found)
	before := app.background_resource_pending.len
	for address in found.urls { app.request_background_resource(address) }
	if initial_background_preload_diagnostics {
		eprintln('VOX_INITIAL_BACKGROUND_PRELOAD requests=${app.background_resource_pending.len - before}')
	}
}
