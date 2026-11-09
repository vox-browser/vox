// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn patch_clamp(value f32, clamp bool) f32 {
	if !clamp { return value }
	if value < 0 { return 0 }
	if value > 1 { return 1 }
	return value
}

fn patch_alpha(bg f32, fg f32, above bool, clamp bool) f32 {
	top := patch_clamp(if above { fg } else { bg }, clamp)
	bottom := if above { bg } else { fg }
	remaining := (f32(1) - top) * (f32(1) - bottom)
	return f32(1) - remaining
}

// Each arithmetic step is kept separate: the source uses unfused SIMD
// operators here, including the two products in unassociated alpha blending.
fn patch_blend_sample(bg f32, fg f32, bg_alpha f32, fg_alpha f32, blending PatchBlending, associated bool) f32 {
	match blending.mode {
		.none { return bg }
		.replace { return fg }
		.add { return bg + fg }
		.multiply { return bg * patch_clamp(fg, blending.clamp) }
		.alpha_weighted_add_above {
			weighted := fg * patch_clamp(fg_alpha, blending.clamp)
			return bg + weighted
		}
		.alpha_weighted_add_below {
			weighted := bg * patch_clamp(bg_alpha, blending.clamp)
			return fg + weighted
		}
		.blend_above, .blend_below {
			above := blending.mode == .blend_above
			top_alpha := patch_clamp(if above { fg_alpha } else { bg_alpha }, blending.clamp)
			bottom_alpha := if above { bg_alpha } else { fg_alpha }
			top := if above { fg } else { bg }
			bottom := if above { bg } else { fg }
			complement := f32(1) - top_alpha
			if associated {
				weighted := bottom * complement
				return top + weighted
			}
			remaining := complement * (f32(1) - bottom_alpha)
			alpha := f32(1) - remaining
			reciprocal := if alpha > 0 { f32(1) / alpha } else { f32(0) }
			top_weighted := top * top_alpha
			bottom_weighted := bottom * bottom_alpha
			bottom_remaining := bottom_weighted * complement
			numerator := top_weighted + bottom_remaining
			return numerator * reciprocal
		}
	}
}

// Blend matching finite sample rows in place. Foreground storage and the
// background channels must be disjoint, as in the source's borrowed row API.
pub fn blend_patch_rows(mut background [][]f32, foreground [][]f32, color PatchBlending, extra []PatchBlending, info []ExtraChannelInfo) ! {
	if info.len > 256 || extra.len != info.len || background.len != 3 + info.len || foreground.len != background.len {
		return error('Invalid JPEG XL patch channel count')
	}
	width := background[0].len
	if width > 1048576 || u64(width) * u64(background.len) > 67108864 {
		return error('JPEG XL patch rows exceed the sample budget')
	}
	for c in 0 .. background.len {
		if background[c].len != width || foreground[c].len != width {
			return error('Invalid JPEG XL patch row shape')
		}
		for x in 0 .. width {
			if !math.is_finite(background[c][x]) || !math.is_finite(foreground[c][x]) {
				return error('JPEG XL patch inputs must be finite')
			}
		}
	}
	has_alpha := info.any(it.kind == .alpha)
	if int(color.mode) < 0 || int(color.mode) > 7
		|| (has_alpha && color.mode.uses_alpha() && (color.alpha_channel < 0 || color.alpha_channel >= info.len)) {
		return error('Invalid JPEG XL patch color blending')
	}
	for blending in extra {
		if int(blending.mode) < 0 || int(blending.mode) > 7 || blending.alpha_channel < 0 || blending.alpha_channel >= info.len {
			return error('Invalid JPEG XL patch extra blending')
		}
	}
	mut old_extra := []f32{len: info.len}
	for x in 0 .. width {
		for i in 0 .. info.len { old_extra[i] = background[3 + i][x] }
		for i, blending in extra {
			a := blending.alpha_channel
			if i == a && blending.mode.uses_alpha() {
				background[3 + i][x] = match blending.mode {
					.blend_above {
						patch_alpha(old_extra[i], foreground[3 + i][x], true, blending.clamp)
					}
					.blend_below {
						patch_alpha(old_extra[i], foreground[3 + i][x], false, blending.clamp)
					}
					.alpha_weighted_add_above { old_extra[i] }
					else { foreground[3 + i][x] }
				}
			} else {
				background[3 + i][x] = patch_blend_sample(old_extra[i], foreground[3 + i][x],
					old_extra[a], foreground[3 + a][x], blending, info[a].alpha_associated)
			}
		}
		for c in 0 .. 3 {
			if !has_alpha && color.mode.uses_alpha() {
				background[c][x] = match color.mode {
					.blend_above { foreground[c][x] }
					.blend_below { background[c][x] }
					else { background[c][x] + foreground[c][x] }
				}
			} else if color.mode.uses_alpha() {
				a := color.alpha_channel
				background[c][x] = patch_blend_sample(background[c][x], foreground[c][x],
					old_extra[a], foreground[3 + a][x], color, info[a].alpha_associated)
			} else {
				background[c][x] = patch_blend_sample(background[c][x], foreground[c][x], 0, 0, color, false)
			}
		}
		if has_alpha && color.mode in [.blend_above, .blend_below] {
			a := color.alpha_channel
			background[3 + a][x] = patch_alpha(old_extra[a], foreground[3 + a][x], color.mode == .blend_above, color.clamp)
		}
	}
}
