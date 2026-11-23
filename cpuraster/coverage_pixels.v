module cpuraster

import math

// covers_surface reports whether the clip leaves every pixel untouched.
pub fn (clip &RasterClip) covers_surface(width int, height int) bool {
	return clip.is_bw && clip.rect == IRect{0, 0, width, height}
}

pub struct ClipCoverageRect {
pub:
	rect  IRect
	alpha u8
}

// Visit the clip's nonzero runs as disjoint constant-coverage rectangles.
// Combining neighboring runs of the same alpha keeps long opaque rows compact.
pub fn (clip &RasterClip) coverage_rects(limit int) ?[]ClipCoverageRect {
	if clip.is_empty { return []ClipCoverageRect{} }
	if limit < 1 { return none }
	if clip.is_bw { return [ClipCoverageRect{clip.rect, 255}] }
	mut rects := []ClipCoverageRect{cap: math.min(limit, 32)}
	mut bands := new_aaclip_iter(&clip.aa)
	for !bands.done {
		mut runs := new_aaclip_row_iter(clip.aa.rows[bands.index].data, true, clip.aa.bounds)
		for !runs.done {
			left, alpha := runs.left, runs.alpha
			mut right := runs.right
			runs.next()
			for !runs.done && runs.alpha == alpha {
				right = runs.right
				runs.next()
			}
			if alpha == 0 { continue }
			if rects.len == limit { return none }
			rects << ClipCoverageRect{IRect{left, bands.top, right, bands.bottom}, alpha}
		}
		bands.next()
	}
	return rects
}

// apply_to_straight_rgba clips a packed straight-alpha texture. Opaque runs
// leave the source untouched, including the interior of a rounded rectangle.
pub fn (clip &RasterClip) apply_to_straight_rgba(mut pixels []u8, width int, height int) bool {
	if !untiled_device(pixels, width, height, width * 4) { return false }
	if clip.covers_surface(width, height) { return true }
	stride := width * 4
	bounds := clip.bounds().intersect(IRect{0, 0, width, height}) or {
		unsafe { vmemset(pixels.data, 0, stride * height) }
		return true
	}
	data := &u8(pixels.data)
	unsafe {
		vmemset(data, 0, bounds.top * stride)
		vmemset(data + bounds.bottom * stride, 0, (height - bounds.bottom) * stride)
	}
	if bounds.left != 0 || bounds.right != width {
		for y in bounds.top .. bounds.bottom {
			unsafe {
				row := data + y * stride
				vmemset(row, 0, bounds.left * 4)
				vmemset(row + bounds.right * 4, 0, (width - bounds.right) * 4)
			}
		}
	}
	if clip.is_bw { return true }
	mut bands := new_aaclip_iter(&clip.aa)
	for !bands.done && bands.top < bounds.bottom {
		if bands.bottom > bounds.top {
			top := math.max(bands.top, bounds.top)
			bottom := math.min(bands.bottom, bounds.bottom)
			mut runs := new_aaclip_row_iter(clip.aa.rows[bands.index].data, true, clip.aa.bounds)
			for !runs.done && runs.left < bounds.right {
				if runs.alpha != 255 {
					left := math.max(runs.left, bounds.left)
					right := math.min(runs.right, bounds.right)
					for y in top .. bottom {
						apply_straight_rgba_coverage(unsafe { data + y * stride }, left,
							right, runs.alpha)
					}
				}
				runs.next()
			}
		}
		bands.next()
	}
	return true
}

fn apply_straight_rgba_coverage(row &u8, left int, right int, coverage u8) {
	if right <= left { return }
	unsafe {
		if coverage == 0 {
			vmemset(row + left * 4, 0, (right - left) * 4)
			return
		}
		for x in left .. right {
			offset := x * 4 + 3
			row[offset] = u8((int(row[offset]) * int(coverage) + 127) / 255)
		}
	}
}
