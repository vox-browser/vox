module main

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import ggshape
import ggtext
import os

fn C.native_set_gg_glyph_run(run voidptr)
fn C.native_set_gg_shape_draw(draw voidptr)
fn C.native_set_gg_path_draw(draw voidptr)
fn C.native_set_gg_svg_image_draw(draw voidptr)

// install_gg_canvas_renderers lets gg.canvas draw the bridge's CPU glyph runs
// (VOX_GG_TEXT=1), its Graphite shape descriptors (VOX_GG_SHAPES=1) and its
// Graphite path and SVG image descriptors (VOX_GG_PATHS=1).
// Anything gg.canvas cannot reproduce exactly falls back to Skia.
fn install_gg_canvas_renderers() {
	if os.getenv('VOX_GG_TEXT') == '1' {
		C.native_set_gg_glyph_run(voidptr(ggtext.glyph_run))
	}
	if os.getenv('VOX_GG_SHAPES') == '1' {
		C.native_set_gg_shape_draw(voidptr(ggshape.draw))
	}
	if os.getenv('VOX_GG_PATHS') == '1' {
		C.native_set_gg_path_draw(voidptr(ggshape.draw_path))
		C.native_set_gg_svg_image_draw(voidptr(ggshape.draw_svg_image))
	}
	if os.getenv('VOX_GG_DIAGNOSTICS') == '1' {
		eprintln('VOX_GG enabled text=${os.getenv('VOX_GG_TEXT') == '1'} shapes=${os.getenv('VOX_GG_SHAPES') == '1'} paths=${os.getenv('VOX_GG_PATHS') == '1'}')
	}
}
