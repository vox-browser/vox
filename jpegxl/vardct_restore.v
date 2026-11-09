// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Restore the actual frame extent; padded transform samples must not become
// filter neighbors beyond the source renderer's document boundary.
pub fn restore_vardct_frame(raw VarDctFramePlanes, frame FrameHeader) ![3]FloatPlane {
	if frame.upsampling != 1 || !frame.is444() || frame.restoration.epf_iterations > 3 {
		return error('Unsupported JPEG XL VarDCT restoration geometry')
	}
	size := frame.size()
	if size.width == 0 || size.height == 0 { return error('Empty JPEG XL restoration frame') }
	mut planes := []FloatPlane{cap: 3}
	for c in 0 .. 3 { planes << crop_float_plane(raw.planes[c], 0, 0, int(size.width), int(size.height))! }
	filter := frame.restoration
	if filter.gab {
		for c in 0 .. 3 { planes[c] = gaborish_plane(planes[c], filter.gab_weights[c * 2], filter.gab_weights[c * 2 + 1])! }
	}
	if filter.epf_iterations > 0 {
		blocks := frame.size_blocks()
		if raw.epf_maps.width != int(blocks.width) || raw.epf_maps.height != int(blocks.height) {
			return error('Incorrect JPEG XL restoration sigma geometry')
		}
		sigma := EpfSigma.vardct(raw.epf_maps, raw.quantizer, filter)!
		common := EpfParameters{ border_sad_multiplier: filter.epf_border_sad_multiplier, channel_scale: filter.epf_channel_scale }
		if filter.epf_iterations >= 3 {
			planes = epf0_planes(planes, EpfParameters{ ...common, sigma_scale: filter.epf_pass0_sigma_scale }, sigma, 0, 0)!
		}
		planes = epf1_planes(planes, EpfParameters{ ...common, sigma_scale: 1 }, sigma, 0, 0)!
		if filter.epf_iterations >= 2 {
			planes = epf2_planes(planes, EpfParameters{ ...common, sigma_scale: filter.epf_pass2_sigma_scale }, sigma, 0, 0)!
		}
	}
	return [planes[0], planes[1], planes[2]]!
}
