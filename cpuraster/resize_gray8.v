module cpuraster

// Gray8 stores the interpolated RGB gray through the raster pipeline's BT.709
// luma stage. Its separate products/additions can round differently from R8,
// even when all three interpolated channels have the same value.
pub fn resize_gray8(pixels []u8, source_width int, source_height int, width int, height int) ?[]u8 {
	return resize_image_pixels(pixels, source_width, source_height, width, height, .gray8)
}
