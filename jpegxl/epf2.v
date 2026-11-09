// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub fn epf2_planes(input []FloatPlane, parameters EpfParameters, sigma EpfSigma, origin_x u32, origin_y u32) ![]FloatPlane {
	return epf_planes(input, parameters, sigma, origin_x, origin_y, 2)
}
