module main

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import ggshape
import ggtext
import os
import renderbackend

fn C.native_set_gg_glyph_run(run voidptr)
fn C.native_set_gg_shape_draw(draw voidptr)
fn C.native_set_gg_path_draw(draw voidptr)
fn C.native_set_gg_svg_image_draw(draw voidptr)

// GG draws supported text, shapes and paths by default. VOX_USE_SKIA=1 selects
// the legacy renderer. Skia still prepares these descriptors and handles the
// unsupported and unmigrated draws; this is not a Skia-free renderer yet.
fn install_gg_canvas_renderers() {
	selected := renderbackend.from_environment()
	if selected.text {
		C.native_set_gg_glyph_run(voidptr(ggtext.glyph_run))
	}
	if selected.shapes {
		C.native_set_gg_shape_draw(voidptr(ggshape.draw))
	}
	if selected.paths {
		C.native_set_gg_path_draw(voidptr(ggshape.draw_path))
		C.native_set_gg_svg_image_draw(voidptr(ggshape.draw_svg_image))
	}
	if os.getenv('VOX_GG_DIAGNOSTICS') == '1' {
		eprintln('VOX_GG enabled text=${selected.text} shapes=${selected.shapes} paths=${selected.paths}')
	}
}
