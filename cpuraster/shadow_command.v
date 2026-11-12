module cpuraster

// Retained box and text shadow commands for the portable (Sokol/Linux)
// presentation, rasterized into a straight-alpha RGBA surface. The exact
// ports in box_shadow.v, inner_shadow.v and text_shadow.v take every
// command they cover; the rest use the device-space shadow fallback.

pub struct ShadowRect {
pub:
	rect  [4]f32
	radii [8]f32
}

pub struct ShadowClip {
pub:
	shape     ShadowRect
	transform [6]f32
	path      PackedPath
	is_path   bool
}

// kind 0 is an outer box shadow, 1 an inner box shadow, 2 a text shadow.
pub struct ShadowCommand {
pub:
	kind           int
	color          u32
	blur           f32
	transform      [6]f32
	content        ShadowRect
	outer          ShadowRect
	inner          ShadowRect
	clips          []ShadowClip
	font_path      string
	face_index     int
	font_size      f32
	glyphs         []u16
	positions      []f32
	translation    [2]f32
	font_smoothing int
	coverage_alpha f32 = -1
}

// Surfaces past the untiled limit are drawn tile by tile, each through a
// translated transform, as Skia's raster device tiles large draws.
const shadow_tile_size = 4096

pub fn rasterize_shadow(width int, height int, command ShadowCommand) ![]u8 {
	if width <= 0 || height <= 0 {
		return error('Invalid shadow surface dimensions')
	}
	if command.kind !in [0, 1, 2] {
		return error('Unsupported shadow command')
	}
	if width <= max_untiled_dimension && height <= max_untiled_dimension {
		return rasterize_shadow_untiled(width, height, command)
	}
	mut pixels := []u8{len: width * height * 4}
	for top := 0; top < height; top += shadow_tile_size {
		for left := 0; left < width; left += shadow_tile_size {
			tw := if left + shadow_tile_size < width { shadow_tile_size } else { width - left }
			th := if top + shadow_tile_size < height { shadow_tile_size } else { height - top }
			tile := rasterize_shadow_untiled(tw, th, command.translated(-f32(left), -f32(top)))!
			for row in 0 .. th {
				copy(mut pixels[((top + row) * width + left) * 4..((top + row) * width + left + tw) * 4],
					tile[row * tw * 4..(row + 1) * tw * 4])
			}
		}
	}
	return pixels
}

fn (command ShadowCommand) translated(dx f32, dy f32) ShadowCommand {
	return ShadowCommand{
		...command
		transform: shadow_translate(command.transform, dx, dy)
		clips:     command.clips.map(ShadowClip{
			...it
			transform: shadow_translate(it.transform, dx, dy)
		})
	}
}

fn shadow_translate(m [6]f32, dx f32, dy f32) [6]f32 {
	return [m[0], m[1], m[2], m[3], m[4] + dx, m[5] + dy]!
}

fn rasterize_shadow_untiled(width int, height int, command ShadowCommand) ![]u8 {
	mut cpu_clips := []Path{}
	for clip in command.clips {
		m := clip.transform
		matrix := Matrix{m[0], m[1], m[2], m[3], m[4], m[5]}
		cpu_clips << if clip.is_path {
			canvas_path(clip.path.segments, clip.path.even_odd).transform(matrix)
		} else {
			shadow_rounded_rect(clip.shape).clip_path(matrix)
		}
	}
	if command.kind == 0 {
		if result := rasterize_outer_shadow_with_coverage(width, height, shadow_rounded_rect(command.outer),
			shadow_rounded_rect(command.content), command.transform, command.color, command.blur, cpu_clips, command.coverage_alpha) {
			return result
		}
	} else if command.kind == 1 {
		if result := rasterize_inner_shadow(width, height, shadow_rounded_rect(command.outer),
			shadow_rounded_rect(command.inner), shadow_rounded_rect(command.content), command.transform,
			command.color, command.blur, cpu_clips) {
			return result
		}
	} else {
		if result := rasterize_text_shadow(width, height, command.glyph_run(), command.transform,
			command.color, command.blur, cpu_clips) {
			return result
		}
	}
	return rasterize_general_shadow(width, height, command, cpu_clips) or {
		return error('Shadow command could not be rasterized')
	}
}

fn (command ShadowCommand) glyph_run() CanvasGlyphRun {
	return CanvasGlyphRun{
		font_path:   command.font_path
		face_index:  command.face_index
		font_size:   command.font_size
		glyphs:      command.glyphs
		positions:   command.positions
		translation: command.translation
		smoothing:   $if linux { 0 } $else { command.font_smoothing }
	}
}

fn shadow_rounded_rect(shape ShadowRect) RoundedRect {
	r := shape.rect
	return rounded_rect(Rect{r[0], r[1], r[0] + r[2], r[1] + r[3]}, shape.radii)
}

// The device-space fallback for shadows the exact ports decline: inner
// holes that intersect their outer shape, transforms the filter layers do
// not reproduce and very large blurs. It keeps DisplayListPlayerSkia's
// structure: opaque source geometry, a Gaussian blur of sigma blur / 2
// mapped through the transform, the shadow color as SrcIn, and the content
// clip (excluded for outer shadows, intersected for inner ones).
fn rasterize_general_shadow(width int, height int, command ShadowCommand, clips []Path) ?[]u8 {
	mut pixels := []u8{len: width * height * 4}
	t := command.transform
	matrix := Matrix{t[0], t[1], t[2], t[3], t[4], t[5]}
	mut all_clips := clips.clone()
	content := shadow_rounded_rect(command.content)
	if command.kind == 0 {
		excluded := content.clip_path(matrix)
		all_clips << Path{
			...excluded
			fill_type: if excluded.is_even_odd() { PathFillType.inverse_even_odd } else { .inverse_winding }
		}
	} else if command.kind == 1 {
		all_clips << content.clip_path(matrix)
	}
	sigma := canvas_shadow_sigma(command.blur) or { f32(0) }
	specs := if sigma > 0 { [CanvasFilterSpec{
		kind:   0
		radius: sigma
	}] } else { []CanvasFilterSpec{} }
	space := GeneralFilterSpace{
		map_params: true
		m:          canvas_affine(t)
		width:      width
		height:     height
	}
	outer := shadow_rounded_rect(command.outer)
	inner := shadow_rounded_rect(command.inner)
	run := command.glyph_run()
	kind := command.kind
	if !draw_general_filter_layer(mut pixels, width, height, width * 4, 2, t, all_clips, specs,
		space, command.color, .src_over, fn [kind, outer, inner, run] (mut layer []u8, w int, h int, lt [6]f32, layer_clips []Path) bool {
		if kind == 2 {
			fill_canvas_glyphs_surface(mut layer, w, h, w * 4, 2, CanvasGlyphRun{
				...run
				baseline_snap: true
			}, lt, 0xff000000, none, 1, .src_over, layer_clips, none, true, unsafe { nil })
			return true
		}
		if !fill_canvas_path(mut layer, w, h, w * 4, 2, outer.path(), lt, 0xff000000, none,
			1, .src_over, 0, layer_clips, none) {
			return false
		}
		if kind == 1 {
			// The difference of the two rounded rectangles: DstOut removes
			// the inner shape's coverage from the outer one.
			return fill_canvas_path(mut layer, w, h, w * 4, 2, inner.path(), lt, 0xff000000,
				none, 1, .dst_out, 0, layer_clips, none)
		}
		return true
	}) {
		return none
	}
	mut straight := []u8{len: pixels.len}
	if !read_pixels(pixels, width, height, width * 4, 2, mut straight, width, height, width * 4, 0,
		0) {
		return none
	}
	return straight
}
