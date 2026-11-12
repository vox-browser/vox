module canvas

import sokol.gfx

// Draw a small document image through the texture shader. Source texels are
// straight RGBA8; the sampled texture owns their premultiplied BGRA8 form.
pub fn (mut s GpuSurface) draw_document_rgba(pixels []u8, width int, height int, x f32, y f32) ! {
	if width <= 0 || height <= 0 || width > 32 || height > 32 || width * height > 256 || pixels.len != width * height * 4 {
		return error('gg.canvas: invalid small document image')
	}
	mut image := s.ctx.new_surface(width: width, height: height)!
	s.retired << image
	mut data := []u8{len: pixels.len}
	for i in 0 .. width * height {
		a := u32(pixels[i * 4 + 3])
		data[i * 4] = u8((u32(pixels[i * 4 + 2]) * a + 127) / 255)
		data[i * 4 + 1] = u8((u32(pixels[i * 4 + 1]) * a + 127) / 255)
		data[i * 4 + 2] = u8((u32(pixels[i * 4]) * a + 127) / 255)
		data[i * 4 + 3] = u8(a)
	}
	image.write_pixels(data.data, width * 4)!
	saved := s.transform
	defer { s.transform = saved }
	s.transform = Transform.new(Matrix.translate(x, y))
	s.draw_shape(ShapeGeometry{ kind: .rect, rect: Rect.ltrb(0, 0, f32(width), f32(height)) }, Paint{
		anti_alias:  false
		layer_image: LayerImage{ image: image.color, texture_width: width, texture_height: height }
	})!
}

// Fractional JPEG RGB must reach the image shader without an RGBA8 store.
pub fn (mut s GpuSurface) draw_document_float_rgba(pixels []f32, width int, height int, x f32, y f32) ! {
	if width <= 0 || height <= 0 || width > 32 || height > 32 || width * height > 256 || pixels.len != width * height * 4 {
		return error('gg.canvas: invalid small floating document image')
	}
	mut data := []f32{len: pixels.len}
	for i in 0 .. width * height {
		a := pixels[i * 4 + 3]
		data[i * 4] = pixels[i * 4] * a
		data[i * 4 + 1] = pixels[i * 4 + 1] * a
		data[i * 4 + 2] = pixels[i * 4 + 2] * a
		data[i * 4 + 3] = a
	}
	mut desc := gfx.ImageDesc{ width: width, height: height, pixel_format: .rgba32f }
	desc.data.subimage[0][0] = gfx.Range{ ptr: data.data, size: u32(data.len * int(sizeof(f32))) }
	image := gfx.make_image(&desc)
	if gfx.query_image_state(image) != .valid {
		gfx.destroy_image(image)
		return error('gg.canvas: floating image upload failed')
	}
	// A sampled-only surface owns this image until the destination flushes.
	s.retired << &GpuSurface{ ctx: s.ctx, color: image }
	saved := s.transform
	defer { s.transform = saved }
	s.transform = Transform.new(Matrix.translate(x, y))
	s.draw_shape(ShapeGeometry{ kind: .rect, rect: Rect.ltrb(0, 0, f32(width), f32(height)) }, Paint{
		anti_alias:  false
		layer_image: LayerImage{ image: image, texture_width: width, texture_height: height }
	})!
}
