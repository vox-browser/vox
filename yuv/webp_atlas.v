module yuv

// Keep full-size luma and half-size chroma in different channels of one
// texture. Chroma occupies its top-left quarter, with edge extension over
// the remaining texels. Sampling at half the luma coordinates gives chroma
// its own derivatives and filtering without first reconstructing RGB.
pub fn webp_420_atlas_upload(planes []u8, width int, height int) ?[]u8 {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || width % 2 != 0 || height % 2 != 0 {
		return none
	}
	ys := width * height
	cw, ch := width / 2, height / 2
	cs := cw * ch
	if planes.len != ys + 2 * cs { return none }
	mut packed := []u8{len: ys * 4}
	for y in 0 .. height {
		cy := if y < ch { y } else { ch - 1 }
		for x in 0 .. width {
			cx := if x < cw { x } else { cw - 1 }
			i := y * width + x
			packed[i * 4] = planes[i]
			packed[i * 4 + 1] = planes[ys + cy * cw + cx]
			packed[i * 4 + 2] = planes[ys + cs + cy * cw + cx]
			packed[i * 4 + 3] = 255
		}
	}
	return packed
}
