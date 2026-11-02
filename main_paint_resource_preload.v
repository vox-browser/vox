module main

import layout
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
