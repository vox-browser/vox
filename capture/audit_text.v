module main

import platform

// Opt-in scalar diagnostics from the committed paint input. This does not
// re-enter style, layout or author JavaScript. Ordinary content audits skip it.
struct CaptureAuditTextGeometry {
	index           int
	text            string
	x               f64
	y               f64
	width           f64
	height          f64
	baseline_x      f64
	baseline_y      f64
	transform       [6]f64
	family          string
	postscript_name string
	font_size       f32
	weight          int
	raw_metrics     platform.FontPixelMetrics
	inline_metrics  platform.FontPixelMetrics
}

fn capture_text_geometry_excerpt(text string) string {
	if text.len <= 256 { return text }
	mut end := 256
	for end > 0 && text[end] & 0xc0 == 0x80 { end-- }
	return text[..end]
}

fn (app &BrowserApp) capture_audit_text_geometry() []CaptureAuditTextGeometry {
	mut records := []CaptureAuditTextGeometry{}
	scale := app.document.display_device_pixel_ratio() / app.document.layout_coordinate_scale()
	for index, command in app.paint_commands {
		if records.len >= 128 { break }
		if command.kind != 'draw_text' || command.y + command.height < 0 || command.y > app.viewport_height {
			continue
		}
		if run := command.glyph_run {
			font := run.font()
			face := font.system_face()
			records << CaptureAuditTextGeometry{
				index:           index
				text:            capture_text_geometry_excerpt(command.text)
				x:               command.x
				y:               command.y
				width:           command.width
				height:          command.height
				baseline_x:      command.glyph_translation_x
				baseline_y:      command.glyph_translation_y
				transform:       command.transform
				family:          font.family
				postscript_name: if found := face { found.postscript_name } else { '' }
				font_size:       font.point_size
				weight:          font.weight
				raw_metrics:     font.pixel_metrics()
				inline_metrics:  font.inline_metrics_at_scale(scale)
			}
		}
	}
	return records
}
