module main

import cpuraster
import layout
import os
import painting

const portable_background_clip_reuse = os.getenv('VOX_PORTABLE_BACKGROUND_CLIP_REUSE') == '1'
const portable_background_clip_diagnostics = os.getenv('VOX_PORTABLE_BACKGROUND_CLIP_DIAGNOSTICS') == '1'

struct PortableBackgroundClipShapes {
mut:
	first ?cpuraster.RoundedClipGeometry
	paths []cpuraster.Path
}

fn (mut shapes PortableBackgroundClipShapes) add(shape cpuraster.RoundedClipGeometry) {
	if first := shapes.first {
		if shapes.paths.len == 0 {
			shapes.paths << first.path()
		}
		shapes.paths << shape.path()
	} else {
		shapes.first = shape
	}
}

struct PortableBackgroundClipReplay {
mut:
	active bool
	cache  &cpuraster.RoundedClipCache = unsafe { nil }
}

// The portable scissor handles rectangular bounds. Resolve rounded corners in
// the gradient texture's device space, where the shared rasterizer can retain
// runs of fully covered pixels without allocating a second texture-sized mask.
fn (mut replay PortableBackgroundClipReplay) raster_clip(command &layout.PaintCommand, bounds painting.IntRect,
	page_x f32, page_y f32, scale f64) ?cpuraster.RasterClip {
	mut shapes := PortableBackgroundClipShapes{}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.corner_radii == layout.BoxRadii{} || clip.is_path || clip.is_svg_mask
				|| clip.is_svg_content_mask {
				continue
			}
			transform := portable_device_transform(clip.transform, page_x, page_y, scale)
			shapes.add(portable_background_clip_shape(clip.rect, clip.corner_radii, transform, bounds))
		}
	}
	if command.gradient_background_layer {
		image := command.image()
		if image.image_clip_radii != layout.BoxRadii{} {
			rect := layout.LayoutRect{image.image_clip_x, image.image_clip_y,
				image.image_clip_width, image.image_clip_height}
			transform := portable_device_transform(command.transform, page_x, page_y, scale)
			shapes.add(portable_background_clip_shape(rect, image.image_clip_radii, transform, bounds))
		}
	}
	if shapes.paths.len != 0 {
		return portable_background_raster_clip(bounds, shapes.paths)
	}
	first := shapes.first or { return none }
	if !replay.active {
		return portable_background_raster_clip(bounds, [first.path()])
	}
	if replay.cache == unsafe { nil } {
		replay.cache = &cpuraster.RoundedClipCache{}
	}
	result := replay.cache.raster_clip(first, bounds.width, bounds.height)
	if portable_background_clip_diagnostics {
		status := if result.reused { 'hit' } else { 'miss' }
		eprintln('VOX_BACKGROUND_CLIP ${status} texture=${bounds.width}x${bounds.height}')
	}
	return result.clip
}

fn portable_background_raster_clip(bounds painting.IntRect, paths []cpuraster.Path) ?cpuraster.RasterClip {
	clip := cpuraster.canvas_raster_clip(bounds.width, bounds.height, paths)
	if clip.covers_surface(bounds.width, bounds.height) { return none }
	return clip
}

fn portable_background_clip_shape(rect layout.LayoutRect, radii layout.BoxRadii,
	transform painting.Affine, bounds painting.IntRect) cpuraster.RoundedClipGeometry {
	edges := cpuraster.Rect{f32(rect.x), f32(rect.y), f32(rect.x + rect.width), f32(rect.y + rect.height)}
	corners := [f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y),
		f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y)]!
	matrix := cpuraster.Matrix{f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
		f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))}
	return cpuraster.RoundedClipGeometry{edges, corners, matrix}
}
