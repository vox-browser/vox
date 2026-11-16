module canvas

import sokol.gfx
import math

// Power transfer followed by a column-major linear-light gamut transform.
// Zero gamma retains the ordinary image shader.
pub struct DocumentImageColorTransform {
pub:
	yuv_rec601_limited bool
	yuv_jpeg_full bool
	yuv420_atlas bool
	// Strict source-subset bounds in luma coordinates. The YUV variant uses
	// the otherwise inactive gamut payload for these four values.
	yuv_chroma_bounds [4]f32
	gamma f32
	gamut [9]f32
}

struct DocumentImageSampler {
mut:
	sampler gfx.Sampler
}

const document_image_sampling = &DocumentImageSampler{}
const document_image_repeating = &DocumentImageSampler{}

fn document_image_repeat_sampler() gfx.Sampler {
	mut state := unsafe { document_image_repeating }
	if state.sampler.id == 0 {
		state.sampler = gfx.make_sampler(&gfx.SamplerDesc{
			min_filter:    .linear
			mag_filter:    .linear
			mipmap_filter: .linear
			wrap_u:        .repeat
			wrap_v:        .repeat
		})
	}
	return state.sampler
}

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

// Lazy embedded resources retain their byte cache. The owner calls this with
// its persistent arena active before any paint scope can load the shared file.
pub fn prepare_document_shader_resources() {
 _ = gradient_snippet_file.data()
}

// Pattern coordinates retain the natural image frame; the hardware sampler
// interpolates across repeated edges instead of clamping each materialized tile.
pub fn (mut s GpuSurface) draw_document_repeated_rgba(pixels []u8, width int, height int,
	x f32, y f32, bounds Rect) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || pixels.len != width * height * 4 {
		return error('gg.canvas: invalid repeated document image')
	}
	mut image := s.ctx.new_surface(width: width, height: height)!
	s.retired << image
	mut bgra := pixels.clone()
	for i in 0 .. width * height { bgra[i * 4], bgra[i * 4 + 2] = bgra[i * 4 + 2], bgra[i * 4] }
	image.write_pixels(bgra.data, width * 4)!
	saved := s.transform
	defer { s.transform = saved }
	s.transform = Transform.new(Matrix.identity())
	s.draw_shape(ShapeGeometry{
		kind: .rect
		rect: bounds
	}, Paint{
		anti_alias:  false
		layer_image: LayerImage{
			image:                  image.color
			texture_width:          width
			texture_height:         height
			document_linear_filter: true
			document_repeat_filter: true
			document_translation:   [-x, -y]!
		}
	})!
}

// Decoded document pixels are already premultiplied. The ordinary image
// shader performs the final bilinear sample and destination blend once.
pub fn (mut s GpuSurface) draw_document_scaled_rgba(levels [][]u8, width int, height int,
	natural_width int, natural_height int, x f32, y f32, destination_width f32, destination_height f32) ! {
	s.draw_document_color_rgba(levels, width, height, natural_width, natural_height,
		x, y, destination_width, destination_height, DocumentImageColorTransform{}, false)!
}

pub fn (mut s GpuSurface) draw_document_color_rgba(levels [][]u8, width int, height int,
	natural_width int, natural_height int, x f32, y f32, destination_width f32, destination_height f32,
	color_transform DocumentImageColorTransform, destination_frame bool) ! {
	s.draw_document_color_rgba_subset(levels, width, height, natural_width, natural_height,
		x, y, destination_width, destination_height, color_transform, destination_frame, [4]f32{}, [2]f32{})!
}

pub fn (mut s GpuSurface) draw_document_color_rgba_subset(levels [][]u8, width int, height int,
	natural_width int, natural_height int, x f32, y f32, destination_width f32, destination_height f32,
	color_transform DocumentImageColorTransform, destination_frame bool, subset [4]f32, origin [2]f32) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || levels.len == 0 || levels.len > 13
		|| natural_width <= 0 || natural_height <= 0 || destination_width <= 0 || destination_height <= 0 {
		return error('gg.canvas: invalid document image')
	}
	if subset.any(!math.is_finite(it)) || origin.any(!math.is_finite(it)) {
		return error('gg.canvas: invalid document subset frame')
	}
	if subset != [4]f32{} && (subset[2] <= 0 || subset[3] <= 0
		|| subset[0] < x || subset[1] < y
		|| subset[0] + subset[2] > x + destination_width
		|| subset[1] + subset[3] > y + destination_height) {
		return error('gg.canvas: document subset exceeds image')
	}
	bounds := color_transform.yuv_chroma_bounds
	if bounds != [4]f32{} && (!color_transform.yuv420_atlas || color_transform.gamma != 0
		|| bounds.any(!math.is_finite(it)) || bounds[0] < 0 || bounds[1] < 0
		|| bounds[2] <= bounds[0] || bounds[3] <= bounds[1]
		|| bounds[2] > width || bounds[3] > height) {
		return error('gg.canvas: invalid document chroma subset')
	}
	if color_transform.yuv_jpeg_full && (color_transform.yuv_rec601_limited || color_transform.yuv420_atlas
        || !document_image_jpeg_upload_supported()) {
        return error('gg.canvas: invalid or unavailable full-range YUV shader')
    }
	if color_transform.yuv_rec601_limited && !document_image_yuv_upload_supported() {
		return error('gg.canvas: YUV shader is unavailable')
	}
	if color_transform.yuv420_atlas && (!color_transform.yuv_rec601_limited || !document_image_yuv_atlas_upload_supported()) {
		return error('gg.canvas: YUV atlas shader is unavailable')
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
	mut sample_translation := [2]f32{}
	mut geometry_x, mut geometry_y := f32(0), f32(0)
	if levels.len > 1 {
		sx *= f32(natural_width) / extent_x
		sy *= f32(natural_height) / extent_y
		draw_width, draw_height = f32(width), f32(height)
		sample_x, sample_y = 1, 1
	}
	saved := s.transform
	defer { s.transform = saved }
	if destination_frame {
		// Image draws use their destination rectangle as geometry. Keeping an
		// ellipse in that frame avoids warping texture coordinates when the
		// analytic rrect renderer expands its antialiasing vertices.
		s.transform = Transform.new(Matrix.translate(x, y))
		sample_x, sample_y = extent_x / destination_width, extent_y / destination_height
		draw_width, draw_height = destination_width, destination_height
	} else {
		s.transform = Transform.new(Matrix.values([sx, f32(0), x, 0, sy, y, 0, 0, 1]!))
	}
	if subset[2] > 0 && subset[3] > 0 {
		s.transform = Transform.new(Matrix.translate(-origin[0], -origin[1]))
		geometry_x, geometry_y = subset[0] + origin[0], subset[1] + origin[1]
		sample_x, sample_y = extent_x / destination_width, extent_y / destination_height
		sample_translation = [-(x + origin[0]) * sample_x, -(y + origin[1]) * sample_y]!
		draw_width, draw_height = subset[2], subset[3]
	}
	s.draw_shape(ShapeGeometry{ kind: .rect, rect: Rect.xywh(geometry_x, geometry_y, draw_width, draw_height) }, Paint{
		anti_alias:  true
		layer_image: LayerImage{
			image:                  image
			texture_width:          width
			texture_height:         height
			document_scale:         [sample_x, sample_y]!
			document_translation:   sample_translation
			document_linear_filter: true
			document_opaque:        color_transform.yuv_rec601_limited || color_transform.yuv_jpeg_full
			color_transform:        color_transform
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

pub fn (mut s GpuSurface) draw_document_scaled_float_rgba(levels [][]f32, width int, height int,
	natural_width int, natural_height int, x f32, y f32, destination_width f32, destination_height f32) ! {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width*height > 4*1024*1024 || levels.len == 0 || levels.len > 13
		|| natural_width <= 0 || natural_height <= 0 || destination_width <= 0 || destination_height <= 0 {
		return error('gg.canvas: invalid floating document image')
	}
	mut desc := gfx.ImageDesc{width:width,height:height,pixel_format:.rgba32f,num_mipmaps:levels.len}
	for index,level in levels {
		if level.len != math.max(1,width>>index)*math.max(1,height>>index)*4 {
			return error('gg.canvas: invalid floating image mip')
		}
		desc.data.subimage[0][index]=gfx.Range{ptr:level.data,size:u32(level.len*int(sizeof(f32)))}
	}
	image:=gfx.make_image(&desc)
	if gfx.query_image_state(image)!=.valid {gfx.destroy_image(image);return error('gg.canvas: float upload failed')}
	s.retired << &GpuSurface{ctx:s.ctx,color:image}
	extent_x,extent_y:=f32(natural_width)*(f32(width)/natural_width),f32(natural_height)*(f32(height)/natural_height)
	mut draw_width,mut draw_height:=f32(natural_width),f32(natural_height)
	mut sx,mut sy:=destination_width/natural_width,destination_height/natural_height
	mut sample_x,mut sample_y:=extent_x/natural_width,extent_y/natural_height
	if levels.len>1 {
		sx*=f32(natural_width)/extent_x;sy*=f32(natural_height)/extent_y
		draw_width,draw_height=f32(width),f32(height)
		sample_x,sample_y=1,1
	}
	saved:=s.transform
	defer {s.transform=saved}
	s.transform=Transform.new(Matrix.values([sx,f32(0),x,0,sy,y,0,0,1]!))
	s.draw_shape(ShapeGeometry{kind:.rect,rect:Rect.ltrb(0,0,draw_width,draw_height)},Paint{
		anti_alias:true
		layer_image:LayerImage{image:image,texture_width:width,texture_height:height,document_scale:[sample_x,sample_y]!,document_linear_filter:true}
	})!
}
