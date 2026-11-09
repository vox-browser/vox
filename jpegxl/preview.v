// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Match the production API's default skip_preview option. A visible final
// preview has its header/TOC validated and bounded sections skipped, without
// entropy decoding or contributing pixels/references to the main image.
fn (mut reader BitReader) skip_preview(file FileHeader) ! {
	if file.metadata.preview == none { return }
	context := file.preview_frame_header_context() or { return error('Missing JPEG XL preview context') }
	mut frame := reader.read_frame_header(context)!
	frame.postprocess(context)!
	if !frame.is_last || !frame.is_visible() {
		return error('JPEG XL preview requires unsupported non-visible frame processing')
	}
	size := frame.size_upsampled()
	channels := u64(3 + file.metadata.extra_channels.len)
	if size.width == 0 || size.height == 0 || channels > 259
		|| u64(size.width)*u64(size.height) > 67108864 / channels
		|| frame.num_toc_entries() > u64(max_permutation_entries) {
		return error('JPEG XL preview exceeds frame sample limits')
	}
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	reader.read_sections(toc)!
}
