module main

import dom
import encoding.base64
import os
import x.json2

// Set VOX_SVG_RECORDING_INPUT to export one SVG through the native paint path.
fn test_export_svg_native_recording_diagnostic() {
	input := os.getenv('VOX_SVG_RECORDING_INPUT')
	if input == '' { return }
	output := os.getenv_opt('VOX_SVG_RECORDING_OUTPUT') or { os.join_path(os.dir(@FILE), 'Build', 'svg-recording.json') }
	width := (os.getenv_opt('VOX_SVG_RECORDING_WIDTH') or { '80' }).int()
	assert width > 0
	source := os.read_bytes(input)!
	encoded_source := base64.encode(source)
	markup := '<!doctype html><base href="https://asgardpvp.com/"><style>body{margin:0}img{position:absolute;left:0;top:0;display:block;height:auto;width:${width}px}</style><img src="data:image/svg+xml;base64,' + encoded_source + '">'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{ url: 'about:blank', markup: markup }, dom.url_about_blank(), none, none, none, false)
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	mut app := BrowserApp{ document: document }
	app.relayout(1280, 880)
	image := app.paint_commands.filter(it.kind == 'paint_nested_display_list')[0]
	mut records := []string{}
	for path in image.nested_viewport_commands {
		svg := path.svg()
		order := if svg.stroke_first { [1, 0] } else { [0, 1] }
		for part in order {
			if part == 0 && path.color == '' { continue }
			if part == 1 && (path.stroke_color == '' || path.stroke_width <= 0) { continue }
			color := if part == 0 {
				app.paint_colors.color_with_retained(path.color, 1, path.retained_svg_fill_color())
			} else {
				app.paint_colors.color_with_retained(path.stroke_color, 1, path.retained_svg_stroke_color())
			}
			alpha := f64(color.a) / 255 * if part == 0 {
				svg.fill_opacity
			} else {
				svg.stroke_opacity
			}
			records << '{"outer":${normalized_paint_transform(path.transform).str()},"inner":${normalized_paint_transform(svg.path_transform).str()},"source":${json2.encode(json2.Any(svg.path))},"data":${svg.path_data.str()},"rgba":[${color.r},${color.g},${color.b},${color.a}],"opacity":${alpha},"stroke":${part},"width":${path.stroke_width},"cap":${svg.stroke_linecap},"join":${svg.stroke_linejoin},"miter":${svg.stroke_miterlimit},"nss":${int(svg.non_scaling_stroke)},"even":${int(svg.fill_even_odd)}}'
		}
	}
	os.mkdir_all(os.dir(output))!
	os.write_file(output, '{"width":${image.width},"height":${image.height},"paths":[' + records.join(',') + ']}')!
	document.finalize()
}
