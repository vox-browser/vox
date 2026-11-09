// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

struct LfFrameReference {
	planes ?[3]FloatPlane
}

fn validate_lf_reference_frame(file FileHeader, frame FrameHeader) ! {
	validate_modular_group_geometry(frame)!
	if frame.frame_type != .lf || frame.lf_level < 1 || frame.lf_level > 4 || frame.is_last
		|| frame.have_crop || frame.x0 != 0 || frame.y0 != 0 || frame.width != file.size.width
		|| frame.height != file.size.height || !frame.is444() || frame.has_noise()
		|| file.metadata.extra_channels.len > 1 || frame.extra_upsampling.len != file.metadata.extra_channels.len {
		return error('Unsupported JPEG XL LF reference frame geometry')
	}
	for i, extra in file.metadata.extra_channels {
		if extra.kind != .alpha || extra.dimension_shift != 0 || extra.bit_depth.floating_point
			|| extra.bit_depth.bits_per_sample != 8 || frame.extra_upsampling[i] != 1 || frame.upsampling != 1 {
			return error('JPEG XL LF references require one unscaled 8-bit alpha channel')
		}
	}
	size := frame.size()
	if u64(size.width) * u64(size.height) > 67108864 / u64(3 + file.metadata.extra_channels.len) { return error('JPEG XL LF reference sample budget exceeded') }
	if frame.encoding == .modular && (!file.metadata.xyb_encoded || frame.has_lf_frame()) {
		return error('Unsupported JPEG XL modular LF reference color encoding')
	}
}

// Save source-space floats after restoration and before color conversion.
// LF level N supplies slot N-1; a VarDCT frame at level N reads slot N.
fn decode_lf_reference_frame(file FileHeader, frame FrameHeader, storage ModularStorage, reference ?[3]FloatPlane, mut sections []BitReader) ![3]FloatPlane {
	validate_lf_reference_frame(file, frame)!
	if frame.encoding == .modular {
		if reference != none { return error('Unexpected JPEG XL modular LF dependency') }
		raw := decode_modular_frame(file, frame, storage, mut sections)!
		// LF storage owns only the three source-color planes. Extra channels
		// are decoded and validated, but never premultiply the saved reference.
		return render_modular_xyb_frame_impl(raw, file, frame, storage, true)
	}
	raw := decode_vardct_frame_with_lf(file, frame, storage, reference, mut sections)!
	return render_vardct_frame(raw, frame, file.transform)
}
