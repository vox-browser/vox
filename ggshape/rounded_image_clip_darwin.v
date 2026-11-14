module ggshape

import gg.canvas
import math
import platform

struct RoundedImageClipEntry {
	width  int
	height int
	radius f32
	mask   []u8
}

struct RoundedImageClipCache {
mut:
	entries []RoundedImageClipEntry
}

const rounded_image_clip_cache = &RoundedImageClipCache{}

// Produce top-down alpha coverage for a rounded image clip. Image sampling
// remains with the platform painter; the clip uses the document rasterizer.
pub fn rounded_image_clip_mask(width int, height int, radius f32) ?[]u8 {
	if width <= 0 || height <= 0 || width > 1024 || height > 1024 || !(radius > 0)
		|| math.is_inf(f64(radius), 0) || C.pthread_main_np() == 0 {
		return none
	}
	mut ctx := context() or { return none }
	mut target := ctx.new_surface(width: width, height: height) or { return none }
	defer { target.free() }
	target.clear(canvas.Color4f{})
	rect := canvas.Rect.xywh(0, 0, f32(width), f32(height))
	target.clip_rrect(canvas.RRect.rect_radii(rect, [canvas.Point{radius, radius},
		canvas.Point{radius, radius}, canvas.Point{radius, radius}, canvas.Point{radius, radius}]!), .intersect, true) or { return none }
	target.draw_rect(rect, canvas.Paint{ color: canvas.Color4f{1, 1, 1, 1}, anti_alias: false }) or { return none }
	mut rgba := []u8{len: width * height * 4}
	target.read_pixels(rgba.data, width * 4) or { return none }
	mut mask := []u8{len: width * height}
	for i in 0 .. mask.len { mask[i] = rgba[i * 4 + 3] }
	return mask
}

@[export: 'vox_document_rounded_image_clip_mask']
fn document_rounded_image_clip_mask(pixels &u8, width i32, height i32, radius f32) i32 {
	if pixels == unsafe { nil } { return 0 }
	if C.pthread_main_np() == 0 { return 0 }
	mut cache := unsafe { rounded_image_clip_cache }
	for entry in cache.entries {
		if entry.width == width && entry.height == height && entry.radius == radius {
			unsafe { vmemcpy(pixels, entry.mask.data, entry.mask.len) }
			return 1
		}
	}
	mask := rounded_image_clip_mask(int(width), int(height), radius) or { return 0 }
	unsafe { vmemcpy(pixels, mask.data, mask.len) }
	// Repeated small avatars share coverage without repeated GPU readbacks.
	// At most sixteen 4 KiB masks live outside the frame allocation scope.
	if mask.len <= 4096 && cache.entries.len < 16 {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		if cache.entries.cap == 0 { cache.entries = []RoundedImageClipEntry{cap: 16} }
		cache.entries << RoundedImageClipEntry{int(width), int(height), radius, mask.clone()}
	}
	return 1
}
