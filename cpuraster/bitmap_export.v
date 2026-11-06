module cpuraster

import math

// Gfx::export_bitmap_to_byte_buffer() (LibGfx/BitmapExport.cpp), reproducing
// LibWeb Skia's SkCanvas::drawImageRect() of the source into a zeroed surface
// of the export color type with nearest sampling and an optional vertical flip.
pub enum BitmapExportFormat {
	gray8
	alpha8
	rgb565
	rgba5551
	rgba4444
	rgb888
	rgba8888
}

pub struct BitmapSource {
pub:
	width  int
	height int
	pitch  int
	// V host layout: RGBA, BGRA, RGBx, BGRx.
	layout      int
	alpha_type  int = 1
	color_space int
	pixels      []u8
}

pub struct BitmapExport {
pub:
	width  int
	height int
	pixels []u8
}

pub fn export_bitmap_to_byte_buffer(bitmap BitmapSource, format BitmapExportFormat, flip_y bool, premultiply_alpha bool, target_width ?int, target_height ?int) !BitmapExport {
	mut width := target_width or { bitmap.width }
	mut height := target_height or { bitmap.height }
	// HostWebGLContext::convert_bitmap_for_upload returns these sizes to GL.
	if width < 0 || height < 0 {
		return BitmapExport{
			width:  width
			height: height
		}
	}
	if format == .rgb888 && (width != bitmap.width || height != bitmap.height) {
		width = bitmap.width
		height = bitmap.height
	}
	bytes_per_pixel := export_bytes_per_pixel(format)
	length := u64(width) * u64(height) * u64(bytes_per_pixel)
	if length > u64(max_int) {
		return error('Gfx::export_bitmap_to_byte_buffer size overflow')
	}
	mut output := []u8{len: int(length)}
	if length == 0 {
		return BitmapExport{
			width:  width
			height: height
			pixels: output
		}
	}
	pitch := if bitmap.pitch == 0 { bitmap.width * 4 } else { bitmap.pitch }
	if bitmap.width <= 0 || bitmap.height <= 0 || pitch < bitmap.width * 4
		|| u64(pitch) * u64(bitmap.height) > u64(bitmap.pixels.len) {
		return error('Invalid bitmap storage')
	}
	if !export_pixels(bitmap, pitch, format, premultiply_alpha, flip_y, width, height, mut
		output)
	{
		return error('Failed to export the bitmap')
	}
	return BitmapExport{
		width:  width
		height: height
		pixels: output
	}
}

fn export_bytes_per_pixel(format BitmapExportFormat) int {
	return match format {
		.gray8, .alpha8 { 1 }
		.rgb565, .rgba5551, .rgba4444 { 2 }
		.rgb888 { 3 }
		.rgba8888 { 4 }
	}
}

// Skia's draws tile devices wider or taller than this; each tile translates
// the device matrix by its origin (SkDrawTiler::kMaxDim).
const draw_tile_size = 8192 - 1

// One destination axis of the drawImageRect() matrix: the rect-to-rect scale,
// the optional vertical flip, and each draw tile's translation.
struct SampleAxis {
	identity bool
	// Highp fuses matrix_scale_translate's mad(); lowp does not.
	fused  bool
	scale  f32
	flip   bool
	extent f32
	limit  f32
}

// SkMatrix::invert() of this axis of the tile's device matrix, which is
// postTranslate(-origin) of the flip concatenated with the scale.
fn (axis SampleAxis) inverse(origin int) (f32, f32) {
	scale := if axis.flip { -axis.scale } else { axis.scale }
	translate := if axis.flip { axis.extent + f32(-origin) } else { f32(0) + f32(-origin) }
	inverse_scale := f32(1) / scale
	inverse_translate := -translate * inverse_scale
	return inverse_scale, inverse_translate
}

// SkImageShader's nearest sampling in the raster pipeline: seed_shader,
// matrix_scale_translate, and gather_8888's clamp_ex and roundDownAtInteger.
fn (axis SampleAxis) source(position int) int {
	if axis.identity {
		// SkTreatAsSprite(): an unscaled, unflipped draw copies pixels in place.
		return position
	}
	origin := (position / draw_tile_size) * draw_tile_size
	inverse_scale, inverse_translate := axis.inverse(origin)
	center := f32(position - origin) + f32(0.5)
	mut coordinate := f32(0)
	if axis.fused {
		coordinate = mad(center, inverse_scale, inverse_translate)
	} else {
		product := center * inverse_scale
		coordinate = product + inverse_translate
	}
	upper := math.f32_from_bits(math.f32_bits(axis.limit) - 1)
	clamped := fmin(fmax(f32_min_normal, coordinate), upper)
	rounded_down := math.f32_from_bits(math.f32_bits(clamped) - 1)
	return int(rounded_down)
}

// SkFloatToFixed3232(): saturating truncation of value * 2^32.
fn fixed3232(value f32) i64 {
	scaled := value * f32(4294967296.0)
	if scaled >= f32(9.223372e18) {
		return max_i64
	}
	if scaled <= f32(-9.223372e18) {
		return min_i64
	}
	return i64(scaled)
}

@[inline]
fn pin(value i64, maximum int) int {
	return if value < 0 {
		0
	} else if value > maximum {
		maximum
	} else {
		int(value)
	}
}

// The legacy N32 shader blitter's nearest sampling (SkBitmapProcState with
// Clamp_S32_opaque_D32_nofilter_DX_shaderproc): the pixel center mapped in
// floats, biased down by one 16.16 unit in 32.32 fixed point, then stepped
// across each tile row by the inverse x scale.
struct LegacySampling {
	horizontal     SampleAxis
	vertical       SampleAxis
	translate_only bool
}

fn new_legacy_sampling(horizontal SampleAxis, vertical SampleAxis) LegacySampling {
	// SkBitmapProcState::init() treats a matrix whose forward scales are within
	// 1/32768 of one as a pure translation (just_trans_general()).
	inverse_x, _ := horizontal.inverse(0)
	inverse_y, _ := vertical.inverse(0)
	tolerance := f32(1) / f32(32768)
	forward_x := f32(1) / inverse_x - f32(1)
	forward_y := f32(1) / inverse_y - f32(1)
	return LegacySampling{
		horizontal:     horizontal
		vertical:       vertical
		translate_only: math.abs(forward_x) <= tolerance && math.abs(forward_y) <= tolerance
	}
}

fn (sampling LegacySampling) axis_matrix(axis SampleAxis, origin int) (f32, f32) {
	inverse_scale, inverse_translate := axis.inverse(origin)
	if !sampling.translate_only {
		return inverse_scale, inverse_translate
	}
	forward_scale := f32(1) / inverse_scale
	forward_translate := -inverse_translate * forward_scale
	return f32(1), -forward_translate
}

// SkBitmapProcStateAutoMapper: mapPoint(position + 0.5) less the 16.16 bias.
fn (sampling LegacySampling) mapped(axis SampleAxis, origin int, position int) i64 {
	inverse_scale, inverse_translate := sampling.axis_matrix(axis, origin)
	center := f32(position - origin) + f32(0.5)
	product := center * inverse_scale
	point := product + inverse_translate
	return fixed3232(point) - (i64(1) << 16)
}

fn (sampling LegacySampling) columns(width int) []int {
	mut columns := []int{len: width}
	maximum := int(sampling.horizontal.limit) - 1
	for origin := 0; origin < width; origin += draw_tile_size {
		inverse_scale, _ := sampling.axis_matrix(sampling.horizontal, origin)
		step := fixed3232(inverse_scale)
		mut x := sampling.mapped(sampling.horizontal, origin, origin)
		end := math.min(width, origin + draw_tile_size)
		for column in origin .. end {
			columns[column] = pin(x >> 32, maximum)
			x += step
		}
	}
	return columns
}

fn (sampling LegacySampling) row(y int) int {
	origin := (y / draw_tile_size) * draw_tile_size
	return pin(sampling.mapped(sampling.vertical, origin, y) >> 32, int(sampling.vertical.limit) - 1)
}

// The stages LibWeb Skia's raster pipeline runs for this source and export
// color type. Blending into the zeroed destination leaves src-over a no-op.
struct ExportPipeline {
	swap_rb      bool
	force_opaque bool
	// kOpaque_SkAlphaType: BGRx keeps its fourth byte as alpha.
	opaque        bool
	premultiplied bool
	display_p3    bool
	unpremultiply bool
	luminance     bool
	format        BitmapExportFormat
	highp         bool
}

fn export_pixels(bitmap BitmapSource, pitch int, format BitmapExportFormat, premultiply bool, flip bool, width int, height int, mut output []u8) bool {
	bytes_per_pixel := export_bytes_per_pixel(format)
	row_bytes := width * bytes_per_pixel
	if format == .rgb888 {
		// Source RGB888 export uses raw Bitmap::get_pixel and does not scale.
		swapped := bitmap.layout == 1 || bitmap.layout == 3
		for y in 0 .. height {
			target_y := if flip { height - y - 1 } else { y }
			for x in 0 .. width {
				source := y * pitch + x * 4
				destination := target_y * row_bytes + x * 3
				output[destination] = bitmap.pixels[source + if swapped { 2 } else { 0 }]
				output[destination + 1] = bitmap.pixels[source + 1]
				output[destination + 2] = bitmap.pixels[source + if swapped { 0 } else { 2 }]
			}
		}
		return true
	}
	// SkBitmap::installPixels() and SkSurfaces::WrapPixels() validation; the
	// current upstream export does not support RGBA5551.
	if format == .rgba5551 || pitch % 4 != 0 || pitch > max_i32 || bitmap.width > max_i32 / 4 {
		return false
	}
	if width > max_dimension || height > max_dimension || u64(height) * u64(row_bytes) > u64(max_i32) {
		return false
	}
	opaque := bitmap.layout == 2 || bitmap.layout == 3
	has_alpha := format == .rgba4444 || format == .rgba8888
	pipeline := ExportPipeline{
		swap_rb:       bitmap.layout == 1 || bitmap.layout == 3
		force_opaque:  bitmap.layout == 2
		opaque:        opaque
		premultiplied: !opaque && bitmap.alpha_type == 2
		display_p3:    bitmap.color_space == 1
		unpremultiply: has_alpha && !premultiply
		luminance:     format == .gray8
		format:        format
		highp:         bitmap.color_space == 1 || (has_alpha && !premultiply)
	}
	identity := width == bitmap.width && height == bitmap.height && !flip
	horizontal := SampleAxis{
		identity: identity
		fused:    pipeline.highp
		scale:    f32(width) / f32(bitmap.width)
		extent:   f32(width)
		limit:    f32(bitmap.width)
	}
	vertical := SampleAxis{
		identity: identity
		fused:    pipeline.highp
		scale:    f32(height) / f32(bitmap.height)
		flip:     flip
		extent:   f32(height)
		limit:    f32(bitmap.height)
	}
	// The legacy N32 shader blitter draws premultiplied sRGB RGBA into
	// premultiplied RGBA_8888 without a raster pipeline.
	legacy := !identity && bitmap.layout == 0 && pipeline.premultiplied && !pipeline.display_p3
		&& format == .rgba8888 && premultiply
	legacy_sampling := new_legacy_sampling(horizontal, vertical)
	columns := if legacy {
		legacy_sampling.columns(width)
	} else {
		[]int{len: width, init: horizontal.source(index)}
	}
	for y in 0 .. height {
		source_row := if legacy { legacy_sampling.row(y) } else { vertical.source(y) } * pitch
		destination_row := y * row_bytes
		for x in 0 .. width {
			source := source_row + columns[x] * 4
			pipeline.store(bitmap.pixels[source], bitmap.pixels[source + 1], bitmap.pixels[source +
				2], bitmap.pixels[source + 3], mut output, destination_row + x * bytes_per_pixel)
		}
	}
	return true
}

fn (pipeline ExportPipeline) store(byte0 u8, byte1 u8, byte2 u8, byte3 u8, mut output []u8, offset int) {
	mut r := byte0
	mut b := byte2
	if pipeline.swap_rb {
		r, b = b, r
	}
	a := if pipeline.force_opaque { u8(255) } else { byte3 }
	if pipeline.highp {
		pipeline.store_highp(r, byte1, b, a, mut output, offset)
	} else {
		pipeline.store_lowp(r, byte1, b, a, mut output, offset)
	}
}

fn (pipeline ExportPipeline) store_lowp(red u8, green u8, blue u8, alpha u8, mut output []u8, offset int) {
	mut r := u32(red)
	mut g := u32(green)
	mut b := u32(blue)
	a := u32(alpha)
	if !pipeline.opaque && !pipeline.premultiplied {
		r = div255_accurate(r * a)
		g = div255_accurate(g * a)
		b = div255_accurate(b * a)
	}
	match pipeline.format {
		.gray8 {
			output[offset] = u8((r * 54 + g * 183 + b * 19) / 256)
		}
		.alpha8 {
			output[offset] = u8(a)
		}
		.rgb565 {
			packed := ((r * 9 + 36) / 74) << 11 | ((g * 21 + 42) / 85) << 5 | (b * 9 + 36) / 74
			output[offset] = u8(packed)
			output[offset + 1] = u8(packed >> 8)
		}
		.rgba4444 {
			packed := ((r + 8) / 17) << 12 | ((g + 8) / 17) << 8 | ((b + 8) / 17) << 4 | (a + 8) / 17
			output[offset] = u8(packed)
			output[offset + 1] = u8(packed >> 8)
		}
		else {
			output[offset] = u8(r)
			output[offset + 1] = u8(g)
			output[offset + 2] = u8(b)
			output[offset + 3] = u8(a)
		}
	}
}

fn (pipeline ExportPipeline) store_highp(red u8, green u8, blue u8, alpha u8, mut output []u8, offset int) {
	mut pixel := FloatPixel{
		r: f32(red) * inv_255
		g: f32(green) * inv_255
		b: f32(blue) * inv_255
		a: f32(alpha) * inv_255
	}
	if pipeline.display_p3 {
		if pipeline.premultiplied {
			pixel.unpremul()
		}
		pixel.transfer(srgb_to_linear)
		pixel.matrix_3x3(display_p3_to_srgb)
		pixel.transfer(linear_to_srgb)
		if !pipeline.opaque {
			pixel.premul()
		}
	} else if !pipeline.opaque && !pipeline.premultiplied {
		pixel.premul()
	}
	pixel.clamp_01()
	if pipeline.unpremultiply {
		pixel.unpremul()
	}
	if pipeline.luminance {
		pixel.a = pixel.luminance()
	}
	match pipeline.format {
		.gray8, .alpha8 {
			output[offset] = u8(to_unorm(pixel.a, 255))
		}
		.rgb565 {
			packed := to_unorm(pixel.r, 31) << 11 | to_unorm(pixel.g, 63) << 5 | to_unorm(pixel.b, 31)
			output[offset] = u8(packed)
			output[offset + 1] = u8(packed >> 8)
		}
		.rgba4444 {
			packed := to_unorm(pixel.r, 15) << 12 | to_unorm(pixel.g, 15) << 8 | to_unorm(pixel.b,
				15) << 4 | to_unorm(pixel.a, 15)
			output[offset] = u8(packed)
			output[offset + 1] = u8(packed >> 8)
		}
		else {
			output[offset] = u8(to_unorm(pixel.r, 255))
			output[offset + 1] = u8(to_unorm(pixel.g, 255))
			output[offset + 2] = u8(to_unorm(pixel.b, 255))
			output[offset + 3] = u8(to_unorm(pixel.a, 255))
		}
	}
}
