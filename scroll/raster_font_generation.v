module main

import css
import os

// Same-binary control: reuse retained pixels across font environment changes.
const retain_font_blind_raster_reuse = os.getenv('VOX_RETAIN_FONT_BLIND_RASTER_REUSE') != ''

// The document's font environment generation, which advances when a face
// loads or fails. Text commands whose glyph runs stay the same can still
// rasterize differently afterwards.
fn (app &BrowserApp) scroll_raster_font_generation() u64 {
	if app.document == unsafe { nil } { return 0 }
	return css.css_style_computer_for(app.document).font_computer().environment_generation()
}
