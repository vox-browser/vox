module main

import browsersettings
import layout
import os
import pageswitch

fn C.native_begin_page_switch_raster(u64, u64, u64, u64, f64, f64, f64, &f64, int) int

struct FastPageSwitch {
mut:
	to       string
	owner    u64
	revision u64
	tiles    layout.PageSwitchTiles
}

// Snapshot before retiring the old document's arena. The native cache checks
// its actual owner/revision as well, so an unpainted mutation cannot reuse it.
fn (mut app BrowserApp) prepare_fast_page_switch(to string) {
	app.fast_page_switch = FastPageSwitch{}
	if !browsersettings.current().experimental_fast_page_switch
		|| !pageswitch.supports(app.source_label, to) || !app.document_presented
		|| app.document == unsafe { nil } || app.page_zoom != 1 || app.scroll_y != 0 {
		return
	}
	app.fast_page_switch = FastPageSwitch{
		to:       to.clone()
		owner:    u64(app.document.unique_id().value())
		revision: app.document.paint_content_revision()
		tiles:    layout.page_switch_tiles(app.paint_commands, app.viewport_width, app.viewport_height)
	}
}

fn (mut app BrowserApp) begin_fast_page_switch(eligible bool) ?[]layout.LayoutRect {
	previous := app.fast_page_switch
	app.fast_page_switch = FastPageSwitch{}
	if !eligible || previous.to == '' || previous.to != app.source_label
		|| app.scroll_y != 0 || !browsersettings.current().experimental_fast_page_switch {
		if previous.to != '' && os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
			eprintln('VOX_PAGE_SWITCH reused=false eligible=${eligible} source_matches=${previous.to == app.source_label}')
		}
		return none
	}
	after := layout.page_switch_tiles(app.paint_commands, app.viewport_width, app.viewport_height)
	damage := previous.tiles.damage(after)
	mut area := f64(0)
	mut packed := []f64{cap: damage.len * 4}
	for rect in damage {
		area += rect.width * rect.height
		packed << [rect.x, rect.y, rect.width, rect.height]
	}
	if area >= f64(app.viewport_width * app.viewport_height) {
		if os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
			eprintln('VOX_PAGE_SWITCH reused=false reason=all-tiles-dirty')
		}
		return none
	}
	$if macos {
		if C.native_begin_page_switch_raster(previous.owner, previous.revision,
			u64(app.document.unique_id().value()), app.document.paint_content_revision(),
			app.page_top(), app.viewport_width, app.viewport_height, packed.data, damage.len) != 0 {
			if os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
				eprintln('VOX_PAGE_SWITCH reused=true dirty_rects=${damage.len} repainted_area=${area} viewport_area=${app.viewport_width * app.viewport_height}')
			}
			return damage
		}
	}
	if os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
		eprintln('VOX_PAGE_SWITCH reused=false reason=native-cache-miss')
	}
	return none
}
