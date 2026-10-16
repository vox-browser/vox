module skia

$if linux {
	#flag @DIR/../Build/linux/native/skia.a
} $else {
	#flag @DIR/shadow_raster.o
}
#include "shadow_raster.h"

pub struct ShadowRect {
pub:
	rect [4]f32
	radii [8]f32
}

pub struct ShadowClip {
pub:
	shape ShadowRect
	transform [6]f32
	path Path
	is_path bool
}

pub struct ShadowCommand {
pub:
	kind int
	color u32
	blur f32
	transform [6]f32
	content ShadowRect
	outer ShadowRect
	inner ShadowRect
	clips []ShadowClip
	font_path string
	face_index int
	font_size f32
	glyphs []u16
	positions []f32
	translation [2]f32
	font_smoothing int
}

struct C.VoxShadowRect {
	rect [4]f32
	radii [8]f32
}
struct C.VoxShadowClip {
	shape C.VoxShadowRect
	transform [6]f32
	path C.VoxCanvasPath
	is_path int
}
struct C.VoxShadowCommand {
	kind int
	color u32
	blur f32
	transform [6]f32
	content C.VoxShadowRect
	outer C.VoxShadowRect
	inner C.VoxShadowRect
	clips &C.VoxShadowClip
	clip_count int
	font_path &char
	face_index int
	glyph_count int
	font_smoothing int
	font_size f32
	translation [2]f32
	glyphs &u16
	positions &f32
}

fn C.vox_skia_shadow(&u8, int, int, int, &C.VoxShadowCommand) bool

fn shadow_native_rect(shape ShadowRect) C.VoxShadowRect {
	return C.VoxShadowRect{ shape.rect, shape.radii }
}

pub fn rasterize_shadow(width int, height int, command ShadowCommand) ![]u8 {
	if width <= 0 || height <= 0 {
		return error('Invalid shadow surface dimensions')
	}
	mut pixels := []u8{len: width * height * 4}
	clips := command.clips.map(C.VoxShadowClip{ shape: shadow_native_rect(it.shape), transform: it.transform, path: native_path(it.path), is_path: int(it.is_path) })
	native := C.VoxShadowCommand{
		kind: command.kind
		color: command.color
		blur: command.blur
		transform: command.transform
		content: shadow_native_rect(command.content)
		outer: shadow_native_rect(command.outer)
		inner: shadow_native_rect(command.inner)
		clips: clips.data
		clip_count: clips.len
		font_path: command.font_path.str
		face_index: command.face_index
		glyph_count: command.glyphs.len
		font_smoothing: command.font_smoothing
		font_size: command.font_size
		translation: command.translation
		glyphs: command.glyphs.data
		positions: command.positions.data
	}
	if !C.vox_skia_shadow(pixels.data, width, height, width * 4, &native) {
		return error('Skia shadow command failed')
	}
	return pixels
}
