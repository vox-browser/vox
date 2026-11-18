module ggshape

import gg.canvas

// SurfaceRegion is the rectangle of a raster surface that one document leaf
// can change. A leaf is drawn on a surface of its compositor tile's size so
// its samples match that tile, but only its own padded bounds hold ink.
pub struct SurfaceRegion {
pub:
	surface_width  int
	surface_height int
	x              int
	y              int
	width          int
	height         int
}

fn (region SurfaceRegion) holds(pixels &u8, pitch i32) bool {
	return pixels != unsafe { nil } && region.surface_width > 0 && region.surface_height > 0
		&& region.width > 0 && region.height > 0 && region.x >= 0 && region.y >= 0
		&& region.x <= region.surface_width - region.width
		&& region.y <= region.surface_height - region.height && pitch >= region.width * 4
}

// draw_path_region draws like draw_path() (or draw_multisampled_path()) on a
// surface of `region`'s surface size, but uploads the backdrop and reads the
// result back for the region only. `pixels` holds the region's rows, `pitch`
// bytes apart, in the surface's BGRA8 premultiplied format.
//
// Each destination pixel blends with its own backdrop pixel, so the region's
// result equals the same rectangle of a whole-surface draw. Returns 0 without
// touching the pixels when the descriptor or the backend is unsupported.
pub fn draw_path_region(pixels &u8, pitch i32, region SurfaceRegion, has_background i32, path &C.VoxGraphitePath, multisampled bool) i32 {
	if path == unsafe { nil } || !region.holds(pixels, pitch) || !path_supported(path)
		|| C.pthread_main_np() == 0 {
		return 0
	}
	mut ctx := context() or { return 0 }
	return draw_path_region_with_context(mut ctx, pixels, pitch, region, has_background, path, multisampled)
}

fn draw_path_region_with_context(mut ctx canvas.GpuContext, pixels &u8, pitch i32, region SurfaceRegion, has_background i32, path &C.VoxGraphitePath, multisampled bool) i32 {
	mut target := ctx.new_surface(width: region.surface_width, height: region.surface_height) or {
		return 0
	}
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
			return 0
		}
	} else {
		target.clear(canvas.Color4f{})
	}
	if multisampled { target.draw_msaa_trigger() }
	draw_descriptor(mut target, path, none, none) or { return 0 }
	target.read_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
		return 0
	}
	return 1
}

// draw_region is draw() restricted to one region of the shape's surface, like
// draw_path_region().
pub fn draw_region(pixels &u8, pitch i32, region SurfaceRegion, has_background i32, shape &C.VoxGraphiteShape) i32 {
	if shape == unsafe { nil } || !region.holds(pixels, pitch) || !supported(shape)
		|| C.pthread_main_np() == 0 {
		return 0
	}
	samples := if shape.force_msaa != 0 { 4 } else { 1 }
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(
		width:        region.surface_width
		height:       region.surface_height
		sample_count: samples
	) or { return 0 }
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
			return 0
		}
	} else {
		target.clear(canvas.Color4f{})
	}
	if samples == 4 {
		target.draw_msaa_trigger()
	}
	draw_shape_descriptor(mut target, shape, region.surface_width, region.surface_height) or {
		return 0
	}
	target.read_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
		return 0
	}
	return 1
}

// draw_svg_image_region is draw_svg_image() restricted to one region of the
// image's surface, like draw_path_region(). Dithered gradients keep the
// surface's device coordinates.
pub fn draw_svg_image_region(pixels &u8, pitch i32, region SurfaceRegion, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	if paths == unsafe { nil } || parent == unsafe { nil } || viewport == unsafe { nil }
		|| count <= 0 || count > 65536 || !region.holds(pixels, pitch) || C.pthread_main_np() == 0 {
		return 0
	}
	for index in 0 .. int(count) {
		if !path_supported(unsafe { &paths[index] }) {
			return 0
		}
	}
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(width: region.surface_width, height: region.surface_height) or {
		return 0
	}
	defer {
		target.free()
	}
	if flags & svg_backdrop != 0 {
		target.write_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
			return 0
		}
	} else {
		target.clear(canvas.Color4f{})
	}
	record_svg_image(mut target, flags, paths, count, parent, viewport, rounded_clip) or { return 0 }
	target.read_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
		return 0
	}
	return 1
}

// draw_shapes_region is draw_shapes() restricted to one region of the shapes'
// surface, like draw_region().
pub fn draw_shapes_region(pixels &u8, pitch i32, region SurfaceRegion, has_background i32, shapes &C.VoxGraphiteShape, count i32) i32 {
	if shapes == unsafe { nil } || count <= 0 || count > 32 || !region.holds(pixels, pitch)
		|| C.pthread_main_np() == 0 {
		return 0
	}
	mut samples := 1
	for i in 0 .. int(count) {
		shape := unsafe { &shapes[i] }
		if !supported(shape) { return 0 }
		if shape.force_msaa != 0 { samples = 4 }
	}
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(
		width:        region.surface_width
		height:       region.surface_height
		sample_count: samples
	) or { return 0 }
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
			return 0
		}
	} else {
		target.clear(canvas.Color4f{})
	}
	if samples == 4 {
		target.draw_msaa_trigger()
	}
	for i in 0 .. int(count) {
		target.save()
		draw_shape_descriptor(mut target, unsafe { &shapes[i] }, region.surface_width, region.surface_height) or {
			return 0
		}
		target.restore()
	}
	target.read_document_region(pixels, int(pitch), region.x, region.y, region.width, region.height) or {
		return 0
	}
	return 1
}
