module ggshape

import gg.canvas
import imageraster
import math
import os
import yuv

pub fn draw_sampled_rgba(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, source_width int, source_height int, x f32, y f32,
	destination_width f32, destination_height f32, samples int, natural_width int, natural_height int) i32 {
	return draw_sampled_rgba_clipped(pixels, width, height, pitch, backdrop, source,
		source_width, source_height, x, y, destination_width, destination_height, samples,
		natural_width, natural_height, [12]f32{}, false)
}

pub fn draw_sampled_rgba_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, source_width int, source_height int, x f32, y f32,
	destination_width f32, destination_height f32, samples int, natural_width int, natural_height int,
	clip [12]f32, gpu_mips bool) i32 {
	return draw_sampled_rgba_with_shadow(pixels, width, height, pitch, backdrop, source, source_width, source_height, x, y, destination_width, destination_height, samples, natural_width, natural_height, clip, gpu_mips, unsafe { nil })
}

pub fn draw_sampled_rgba_with_shadow(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, source_width int, source_height int, x f32, y f32,
	destination_width f32, destination_height f32, samples int, natural_width int, natural_height int,
	clip [12]f32, gpu_mips bool, shadow &C.VoxGraphiteShape) i32 {
 return draw_sampled_image(pixels,width,height,pitch,backdrop,source,[],source_width,source_height,x,y,destination_width,destination_height,samples,natural_width,natural_height,clip,gpu_mips,shadow,0,false,[2]f32{},false)
}

pub fn draw_sampled_colors_clipped(pixels &u8,width i32,height i32,pitch i32,backdrop i32,colors []f32,sw int,sh int,x f32,y f32,dw f32,dh f32,samples int,nw int,nh int,clip [12]f32) i32 {
 if sw<=0 || sh<=0 || sw>4096 || sh>4096 || sw*sh>4*1024*1024 || colors.len!=sw*sh*4 {return 0}
 for i,v in colors {if !math.is_finite(v) || v<0 || v>1 || (i%4==3 && v!=1) {return 0}}
 return draw_sampled_image(pixels,width,height,pitch,backdrop,[],colors,sw,sh,x,y,dw,dh,samples,nw,nh,clip,false,unsafe{nil},0,false,[2]f32{},false)
}

// The caller supplies premultiplied rows; opaque rows also have straight RGB.
// Preserve image-quad coordinates through the analytic rounded clip renderer.
pub fn draw_sampled_image_quad_rgba(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, sw int, sh int, x f32, y f32, samples int, clip [12]f32) i32 {
	if sw <= 0 || sh != sw || sw > 128 || source.len != sw * sh * 4 { return 0 }
	for i := 3; i < source.len; i += 4 { if source[i] != 255 { return 0 } }
	if clip[0] != x || clip[1] != y || clip[2] != sw || clip[3] != sh
		|| clip[4..12].any(it != f32(sw) * .5) { return 0 }
	return draw_sampled_image(pixels,width,height,pitch,backdrop,source,[],sw,sh,x,y,f32(sw),f32(sh),samples,sw,sh,clip,false,unsafe{nil},0,false,[2]f32{},true)
}

fn draw_sampled_image(pixels &u8,width i32,height i32,pitch i32,backdrop i32,source []u8,colors []f32,source_width int,source_height int,x f32,y f32,destination_width f32,destination_height f32,samples int,natural_width int,natural_height int,clip [12]f32,gpu_mips bool,shadow &C.VoxGraphiteShape,yuv_mode int,yuv_atlas bool,origin [2]f32, image_quad bool) i32 {
	if shadow != unsafe { nil } && (shadow.fill != 9 || shadow.thickness != 0 || !supported(shadow)) {
		return 0
	}
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| int(width) * int(height) > 4 * 1024 * 1024 || pitch < width * 4 || samples !in [
		1,
		4,
	]
		|| C.pthread_main_np() == 0 {
		return 0
	}
	if natural_width <= 0 || natural_height <= 0 || natural_width > 4096 || natural_height > 4096
		|| destination_width <= 0 || destination_height <= 0
		|| math.is_nan(x) || math.is_nan(y) || math.is_nan(destination_width) || math.is_nan(destination_height)
		|| math.is_inf(x, 0) || math.is_inf(y, 0) || math.is_inf(destination_width, 0) || math.is_inf(destination_height, 0) {
		return 0
	}
	extent_x := f32(natural_width) * (f32(source_width) / f32(natural_width))
	extent_y := f32(natural_height) * (f32(source_height) / f32(natural_height))
	byte_source := if colors.len>0 {colors.map(u8(math.floor(it*255+.5)))} else {source}
	mut levels := [byte_source]
	if (yuv_mode != 1 || gpu_mips || yuv_atlas) && destination_width < source_width && destination_height < source_height
		&& extent_x >= source_width && extent_y >= source_height {
		image := imageraster.Image{ width: source_width, height: source_height, pixels: byte_source }
		chain := if gpu_mips {
			gpu_image_mip_chain(image) or { return 0 }
		} else {
			imageraster.mip_chain(image) or { return 0 }
		}
		levels = chain.map(it.pixels)
        if yuv_atlas && destination_width*2<source_width && destination_height*2<source_height {
            // Only chroma levels 0 and 1 are selected in this aligned domain.
            // Extend the generated level's own edge before trilinear sampling.
            levels[1]=yuv.webp_atlas_extend_mip_chroma(levels[1],source_width/2,source_height/2,
                source_width/4,source_height/4) or {return 0}
        }
	}
	mut ctx := context() or { return 0 }
	mut surface := ctx.new_surface(width: width, height: height, sample_count: samples) or { return 0 }
	defer { surface.free() }
	if backdrop != 0 {
		surface.write_pixels(pixels, pitch) or { return 0 }
	} else {
		surface.clear(canvas.Color4f{})
	}
	if shadow != unsafe { nil } {
		if samples == 4 { surface.draw_msaa_trigger() }
		surface.save()
		draw_shape_descriptor(mut surface, shadow, int(width), int(height)) or { return 0 }
		surface.restore()
	}
	for value in clip { if !math.is_finite(value) { return 0 } }
	if clip[4..12].any(it < 0) { return 0 }
	// Keep a rectangular source-subset clip in destination coordinates. An
	// inverse image-scale round trip otherwise moves its sampling grid.
	partial_atlas_clip := yuv_atlas && destination_width * 2 > source_width
		&& destination_height * 2 > source_height
		&& clip[2] > 0 && clip[3] > 0 && clip[0..4].all(it == math.floor(it))
		&& clip[0] >= x && clip[1] >= y
		&& clip[0] + clip[2] <= x + destination_width
		&& clip[1] + clip[3] <= y + destination_height
		&& (clip[0] != x || clip[1] != y || clip[2] != destination_width || clip[3] != destination_height)
		&& clip[4..12].all(it == 0)

	if clip[2] > 0 && clip[3] > 0 {
		if samples == 4 { surface.draw_msaa_trigger() }
		// Full-plane atlases already draw this exact full-image rectangle.
		// Intersecting it again in image coordinates perturbs the sampler's
		// float32 inverse transform. Retain the shared MSAA trigger above.
		full_atlas := yuv_atlas
			&& (source_width % 2 != 0 || source_height % 2 != 0
				|| (destination_width * 2 > source_width && destination_height * 2 > source_height
					&& clip[0..4].all(it == math.floor(it))))
			&& clip[0] == x && clip[1] == y && clip[2] == destination_width
			&& clip[3] == destination_height && clip[4..12].all(it == 0)
		if !full_atlas && !partial_atlas_clip {
			rect := canvas.Rect.xywh(clip[0], clip[1], clip[2], clip[3])
			surface.clip_rrect(canvas.RRect.rect_radii(rect, [
				canvas.Point{clip[4], clip[5]},
				canvas.Point{clip[6], clip[7]},
				canvas.Point{clip[8], clip[9]},
				canvas.Point{clip[10], clip[11]},
			]!), .intersect, true) or { return 0 }
		}
	}
 if colors.len>0 {
  mut floats:=[colors]
  for level in levels[1..] {floats << level.map(f32(it)/255)}
  surface.draw_document_scaled_float_rgba(floats,source_width,source_height,natural_width,natural_height,x,y,destination_width,destination_height) or {return 0}
 } else {
	mut chroma_bounds := [4]f32{}
	if partial_atlas_clip {
		source_clip := [(clip[0] - x) * f32(source_width) / destination_width,
			(clip[1] - y) * f32(source_height) / destination_height,
			(clip[0] + clip[2] - x) * f32(source_width) / destination_width,
			(clip[1] + clip[3] - y) * f32(source_height) / destination_height]!
		// Chromium intersects UV texel-center bounds with the luma subset,
		// then applies the larger inset symmetrically on each axis.
		for axis in 0 .. 2 {
			lo, hi := source_clip[axis], source_clip[axis + 2]
			inset_lo := math.max(lo + .5, (f32(math.floor(lo * .5)) + .5) * 2)
			inset_hi := math.min(hi - .5, (f32(math.ceil(hi * .5)) - .5) * 2)
			inset := math.max(inset_lo - lo, hi - inset_hi)
			chroma_bounds[axis], chroma_bounds[axis + 2] = lo + inset, hi - inset
		}
	}
	destination_subset := if partial_atlas_clip { [clip[0], clip[1], clip[2], clip[3]]! } else { [4]f32{} }
	surface.draw_document_color_rgba_subset(levels, source_width, source_height, natural_width, natural_height, x, y,
		destination_width, destination_height, canvas.DocumentImageColorTransform{ image_quad_coords: image_quad && samples == 4, yuv_rec601_limited: yuv_mode == 1, yuv_jpeg_full: yuv_mode == 2, yuv420_atlas: yuv_atlas, yuv_chroma_bounds: chroma_bounds },
		partial_atlas_clip || (samples == 1 && clip[0] == x && clip[1] == y && clip[2] == destination_width
			&& clip[3] == destination_height
			&& (clip[4] != clip[5] || clip[6] != clip[7] || clip[8] != clip[9] || clip[10] != clip[11])),
		destination_subset, origin) or { if os.getenv('VOX_GG_DIAGNOSTICS') != '' { eprintln('VOX_YUV_IMAGE ${err}') }; return 0 }
 }
	surface.read_pixels(pixels, pitch) or { return 0 }
	return 1
}

pub fn draw_sampled_yuv_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32) i32 {
 return draw_sampled_yuv_with_mips_clipped(pixels,width,height,pitch,backdrop,source,sw,sh,x,y,dw,dh,samples,nw,nh,clip,false)
}

pub fn draw_sampled_yuv_with_mips_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32, gpu_mips bool) i32 {
 if sw <= 0 || sh <= 0 || sw > 4096 || sh > 4096 || sw * sh > 4 * 1024 * 1024 || source.len != sw * sh * 4 { return 0 }
 for i := 3; i < source.len; i += 4 { if source[i] != 255 { return 0 } }
 return draw_sampled_image(pixels,width,height,pitch,backdrop,source,[],sw,sh,x,y,dw,dh,samples,nw,nh,clip,gpu_mips,unsafe{nil},1,false,[2]f32{},false)
}

// Chroma is sampled from the top-left quarter at its own resolution. The
// full-upload bounds preserve alignment of the selected chroma and luma mips.
pub fn draw_sampled_yuv_atlas_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32) i32 {
 return draw_sampled_yuv_atlas_with_mips_clipped(pixels,width,height,pitch,backdrop,source,sw,sh,x,y,dw,dh,samples,nw,nh,clip,true)
}

// New pixmap uploads can carry CPU byte mips; retained textures use GPU mips.
pub fn draw_sampled_yuv_atlas_with_mips_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32, gpu_mips bool) i32 {
 return draw_sampled_yuv_atlas_at_origin(pixels,width,height,pitch,backdrop,source,sw,sh,x,y,dw,dh,samples,nw,nh,clip,gpu_mips,[2]f32{})
}

pub fn draw_sampled_yuv_atlas_at_origin(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32, gpu_mips bool, origin [2]f32) i32 {
 if origin.any(!math.is_finite(it)) { return 0 }
 if !yuv.webp_atlas_sampling_supported(sw,sh,f64(dw),f64(dh)) || source.len!=sw*sh*4 {return 0}
 for i:=3;i<source.len;i+=4 {if source[i]!=255 {return 0}}
 return draw_sampled_image(pixels,width,height,pitch,backdrop,source,[],sw,sh,x,y,dw,dh,samples,nw,nh,clip,gpu_mips,unsafe{nil},1,true,origin,false)
}

// JPEG uploads have full-range 4:4:4 planes and retain CPU byte mips.
pub fn draw_sampled_jpeg_clipped(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
 source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32, samples int, nw int, nh int, clip [12]f32) i32 {
 if sw <= 0 || sh <= 0 || sw > 4096 || sh > 4096 || sw * sh > 4 * 1024 * 1024 || source.len != sw * sh * 4 { return 0 }
 for i := 3; i < source.len; i += 4 { if source[i] != 255 { return 0 } }
 return draw_sampled_image(pixels,width,height,pitch,backdrop,source,[],sw,sh,x,y,dw,dh,samples,nw,nh,clip,false,unsafe{nil},2,false,[2]f32{},false)
}
