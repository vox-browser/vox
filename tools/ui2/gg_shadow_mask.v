module canvas

// draw_alpha_mask shades an A8 coverage mask with the paint's floating-point
// color, then applies the surface clip. Keep color multiplication in the GPU
// draw: storing a low-opacity colored RGBA bitmap first loses coverage bits.
pub fn (mut s GpuSurface) draw_alpha_mask(mask []u8, width int, height int, paint Paint) ! {
	if width <= 0 || height <= 0 || mask.len != width * height {
		return error('gg.canvas: invalid alpha mask')
	}
	if s.layer != unsafe { nil } {
		mut top := s.layer
		top.draw_alpha_mask(mask, width, height, paint)!
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
			image:          image.color
			texture_width:  width
			texture_height: height
			mask_color:     paint.color.premul()
		}
	})!
}
