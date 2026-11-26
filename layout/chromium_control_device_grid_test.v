module layout

import html

// Brave's windowed 2x font strike makes this default 20-column system-font
// field 156 CSS pixels wide. Rounding its projected average in CSS pixels
// instead made it 153 pixels wide, shifting GitHub's Go to file wrapper.
fn test_system_text_field_compatibility_rounding_uses_the_device_font_strike() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}input{display:block;font:14px/20px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:1px 0;border:0;appearance:none}</style><input id="field">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0, 1.0] {
		document.set_layout_coordinate_scale(scale)
		run_document_layout(document, 1024, 768) or { panic('Missing layout') }
		field := document.get_element_by_id('field') or { panic('Missing field') }
		assert field.get_bounding_client_rect().width == if scale == 2 { 156.0 } else { 154.0 }
	}
}
