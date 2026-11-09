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
		|| frame.height != file.size.height || !frame.is444()
		|| file.metadata.extra_channels.len != 0 || frame.extra_upsampling.len != 0 {
		return error('Unsupported JPEG XL LF reference frame geometry')
	}
	size := frame.size()
	if u64(size.width) * u64(size.height) > 67108864 / 3 { return error('JPEG XL LF reference sample budget exceeded') }
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
		return render_modular_xyb_frame(raw, file, frame, storage)
	}
	raw := decode_vardct_frame_with_lf(file, frame, storage, reference, mut sections)!
	return render_vardct_frame(raw, frame, file.transform)
}
