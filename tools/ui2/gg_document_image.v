module canvas

import sokol.gfx
import math

struct DocumentImageSampler {
mut:
	sampler gfx.Sampler
}

const document_image_sampling = &DocumentImageSampler{}

fn document_image_sampler() gfx.Sampler {
	mut state := unsafe { document_image_sampling }
	if state.sampler.id == 0 {
		state.sampler = gfx.make_sampler(&gfx.SamplerDesc{
			min_filter:    .linear
			mag_filter:    .linear
			mipmap_filter: .linear
			wrap_u:        .clamp_to_edge
			wrap_v:        .clamp_to_edge
		})
	}
	return state.sampler
}

// Decoded document pixels are already premultiplied. The ordinary image
// shader performs the final bilinear sample and destination blend once.
pub fn (mut s GpuSurface) draw_document_scaled_rgba(levels [][]u8, width int, height int,
	natural_width int, natural_height int, x f32, y f32, destination_width f32, destination_height f32) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || levels.len == 0 || levels.len > 13
		|| natural_width <= 0 || natural_height <= 0 || destination_width <= 0 || destination_height <= 0 {
		return error('gg.canvas: invalid document image')
	}
	mut desc := gfx.ImageDesc{ width: width, height: height, pixel_format: .rgba8, num_mipmaps: levels.len }
	for index, level in levels {
		if level.len != math.max(1, width >> index) * math.max(1, height >> index) * 4 {
			return error('gg.canvas: invalid image mip')
		}
		desc.data.subimage[0][index] = gfx.Range{ ptr: level.data, size: u32(level.len) }
	}
	image := gfx.make_image(&desc)
	if gfx.query_image_state(image) != .valid {
		gfx.destroy_image(image)
		return error('gg.canvas: image upload failed')
	}
	s.retired << &GpuSurface{ ctx: s.ctx, color: image }
	extent_x := f32(natural_width) * (f32(width) / f32(natural_width))
	extent_y := f32(natural_height) * (f32(height) / f32(natural_height))
	mut draw_width, mut draw_height := f32(natural_width), f32(natural_height)
	mut sx, mut sy := destination_width / f32(natural_width), destination_height / f32(natural_height)
	mut sample_x, mut sample_y := extent_x / f32(natural_width), extent_y / f32(natural_height)
	if levels.len > 1 {
		sx *= f32(natural_width) / extent_x
		sy *= f32(natural_height) / extent_y
		draw_width, draw_height = f32(width), f32(height)
		sample_x, sample_y = 1, 1
	}
	saved := s.transform
	defer { s.transform = saved }
	s.transform = Transform.new(Matrix.values([sx, f32(0), x, 0, sy, y, 0, 0, 1]!))
	s.draw_shape(ShapeGeometry{ kind: .rect, rect: Rect.ltrb(0, 0, draw_width, draw_height) }, Paint{
		anti_alias:  true
		layer_image: LayerImage{
			image:                  image
			texture_width:          width
			texture_height:         height
			document_scale:         [sample_x, sample_y]!
			document_linear_filter: true
		}
	})!
}

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
