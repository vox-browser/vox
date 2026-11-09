// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct FileHeader {
pub:
	size      Size
	metadata  ImageMetadata
	transform CustomTransformData
}

pub fn (mut reader BitReader) read_file_header() !FileHeader {
	first := reader.read(8)!
	second := reader.read(8)!
	if first != 0xff || second != 0x0a { return error('Invalid JPEG XL codestream signature') }
	size := reader.read_size(false)!
	metadata := reader.read_image_metadata()!
	transform := reader.read_transform_data(metadata.xyb_encoded)!
	return FileHeader{ size: size, metadata: metadata, transform: transform }
}

pub fn parse_file_header(input []u8) !FileHeader {
	codestream := extract_codestream(input)!
	mut reader := new_bit_reader(codestream)
	return reader.read_file_header()
}
