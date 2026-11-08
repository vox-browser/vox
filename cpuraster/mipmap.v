module cpuraster

fn C.log2f(x f32) f32

// Raster mipmaps halve each dimension, using a box for even dimensions and
// the overlapping [1,2,1] triangle for odd ones. Components stay in their
// stored color space and alpha representation.
pub fn build_image_mipmap(bitmap CanvasBitmap, level int) ?CanvasBitmap {
	if !bitmap.installs() || level < 0 { return none }
	mut count := 0
	for n := math_max_int(bitmap.width, bitmap.height); n > 1; n >>= 1 { count++ }
	if level > count { return none }
	mut image := bitmap
	for _ in 0 .. level {
		w, h := math_max_int(1, image.width/2), math_max_int(1, image.height/2)
		x_taps := if image.width == 1 { 1 } else if image.width & 1 != 0 { 3 } else { 2 }
		y_taps := if image.height == 1 { 1 } else if image.height & 1 != 0 { 3 } else { 2 }
		shift := x_taps-1 + y_taps-1
		mut pixels := []u8{len: w*h*4}
		for y in 0 .. h { for x in 0 .. w { for c in 0 .. 4 {
			mut sum := 0
			for j in 0 .. y_taps { for i in 0 .. x_taps {
				wx := if x_taps == 3 && i == 1 { 2 } else { 1 }
				wy := if y_taps == 3 && j == 1 { 2 } else { 1 }
				sum += int(image.pixels[(y*2+j)*image.pitch+(x*2+i)*4+c])*wx*wy
			} }
			pixels[(y*w+x)*4+c] = u8(sum >> shift)
		} } }
		image = CanvasBitmap{...bitmap, pixels: pixels, width: w, height: h, pitch: w*4}
	}
	return image
}

fn new_mipmap_image_shader(bitmap CanvasBitmap, tile_x TileMode, tile_y TileMode, linear bool, total SkAffine) CanvasShader {
	inverse := affine_invert(total) or { return CanvasShader{kind: .empty} }
	xx, xy := inverse.sx*inverse.sx, inverse.ky*inverse.ky
	yx, yy := inverse.kx*inverse.kx, inverse.sy*inverse.sy
	sx, sy := C.sqrtf(xx+xy), C.sqrtf(yx+yy)
	mut level := 0
	if is_finite_f32(sx) && is_finite_f32(sy) && math_abs32(sx) > f32(1)/4096 && math_abs32(sy) > f32(1)/4096 {
		scale := fmin_std(f32(1)/sx, f32(1)/sy)
		if scale > 0 && scale < 1 {
			l := fmax_std(-C.log2f(scale)-f32(0.5), 0)
			if is_finite_f32(l) { level = float_saturate2int(floor_f32(l+f32(0.5))) }
		}
	}
	if level == 0 { return image_shader_with_inverse(bitmap, tile_x, tile_y, linear, inverse) }
	image := build_image_mipmap(bitmap, level) or { return image_shader_with_inverse(bitmap, tile_x, tile_y, linear, inverse) }
	mapped := post_scale(inverse, f32(image.width)/f32(bitmap.width), f32(image.height)/f32(bitmap.height))
	return image_shader_with_inverse(image, tile_x, tile_y, linear, mapped)
}
