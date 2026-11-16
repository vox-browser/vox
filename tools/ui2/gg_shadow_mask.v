module canvas

import sokol.gfx

// Analytic coverage remains floating-point until the paint and destination
// blend. Resolving it to A8 first would add a visible quantization step.
pub fn (mut s GpuSurface) draw_float_alpha_mask(mask []f32, width int, height int, paint Paint) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096 || width * height > 4 * 1024 * 1024 || mask.len != width * height {
		return error('gg.canvas: invalid floating alpha mask')
	}
	if s.layer != unsafe { nil } {
		mut top := s.layer
		top.draw_float_alpha_mask(mask, width, height, paint)!
		return
	}
	mut rgba := []f32{len: mask.len * 4}
	for i, a in mask {
		for c in 0 .. 4 { rgba[i * 4 + c] = a }
	}
	mut desc := gfx.ImageDesc{ width: width, height: height, pixel_format: .rgba32f }
	desc.data.subimage[0][0] = gfx.Range{ ptr: rgba.data, size: u32(rgba.len * int(sizeof(f32))) }
	image := gfx.make_image(&desc)
	if gfx.query_image_state(image) != .valid {
		gfx.destroy_image(image)
		return error('gg.canvas: float mask upload failed')
	}
	s.retired << &GpuSurface{ ctx: s.ctx, color: image }
	s.draw_shape(ShapeGeometry{ kind: .rect, rect: Rect.ltrb(0, 0, f32(width), f32(height)) }, Paint{
		anti_alias:  paint.anti_alias
		layer_image: LayerImage{ image: image, texture_width: width, texture_height: height, mask_color: paint.color.premul() }
	})!
}

// draw_alpha_mask shades an A8 coverage mask with the paint's floating-point
// color, then applies the surface clip. Keep color multiplication in the GPU
// draw: storing a low-opacity colored RGBA bitmap first loses coverage bits.
pub fn (mut s GpuSurface) draw_alpha_mask(mask []u8, width int, height int, paint Paint) ! {
	s.draw_alpha_mask_image(mask, width, height, paint, false)!
}

// A resolved filter layer retains its affine transform until this draw.
pub fn (mut s GpuSurface) draw_linear_alpha_mask(mask []u8, width int, height int, paint Paint) ! {
	s.draw_alpha_mask_image(mask, width, height, paint, true)!
}

// Keep a filter's RGBA resolve separate from its final affine sample.
pub fn (mut s GpuSurface) draw_linear_premultiplied_layer(bgra []u8, width int, height int, anti_alias bool) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || bgra.len != width * height * 4 {
		return error('gg.canvas: invalid premultiplied layer')
	}
	if s.layer != unsafe { nil } {
		mut top := s.layer
		top.draw_linear_premultiplied_layer(bgra, width, height, anti_alias)!
		return
	}
	mut image := s.ctx.new_surface(width: width, height: height)!
	s.retired << image
	image.write_pixels(bgra.data, width * 4)!
	s.draw_shape(ShapeGeometry{
		kind: .rect
		rect: Rect.ltrb(0, 0, f32(width), f32(height))
	}, Paint{
		anti_alias:  anti_alias
		layer_image: LayerImage{
			image:                  image.color
			texture_width:          width
			texture_height:         height
			document_linear_filter: true
		}
	})!
}

fn (mut s GpuSurface) draw_alpha_mask_image(mask []u8, width int, height int, paint Paint,
	linear bool) ! {
	if width <= 0 || height <= 0 || mask.len != width * height {
		return error('gg.canvas: invalid alpha mask')
	}
	if s.layer != unsafe { nil } {
		mut top := s.layer
		top.draw_alpha_mask_image(mask, width, height, paint, linear)!
		return
	}
	mut image := s.ctx.new_surface(width: width, height: height)!
	s.retired << image
	mut pixels := []u8{len: mask.len * 4}
	for i, a in mask {
		pixels[i * 4] = a
		pixels[i * 4 + 1] = a
		pixels[i * 4 + 2] = a
		pixels[i * 4 + 3] = a
	}
	image.write_pixels(pixels.data, width * 4)!
	s.draw_shape(ShapeGeometry{
		kind: .rect
		rect: Rect.ltrb(0, 0, f32(width), f32(height))
	}, Paint{
		anti_alias:  paint.anti_alias
		layer_image: LayerImage{
			image:                  image.color
			texture_width:          width
			texture_height:         height
			mask_color:             paint.color.premul()
			document_linear_filter: linear
		}
	})!
}

// Graphite image-filter devices use the same approximate backing allocation
// as save-layer devices. Its viewport still clips to the logical dimensions.
pub fn (mut ctx GpuContext) new_filter_surface(width int, height int) !&GpuSurface {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096 || width * height > 4 * 1024 * 1024 {
		return error('gg.canvas: invalid filter surface')
	}
	return ctx.new_layer_surface(width, height)!
}
