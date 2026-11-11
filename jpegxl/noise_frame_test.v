module jpegxl

import crypto.sha256
import math
import os

fn test_complete_noisy_vardct_images_match_native_pixels_and_lut_words() {
	mut count := 0
	mut total := 0
	mut zero := 0
	mut permuted := 0
	mut multiple_lf := 0
	mut factors := []bool{len: 4}
	for line in $embed_file('testdata/noise-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/noise', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Noisy VarDCT ${f[0]}, paint=${paint}'
			mut alpha := []u8{len: image.width * image.height}
			for i in 0 .. alpha.len { alpha[i] = image.pixels[i * 4 + 3] }
			assert sha256.sum(alpha).hex() == f[6]
			total += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert frame.has_noise() && frame.upsampling == f[8].u32()
		assert frame.num_groups() == f[9].u64() && frame.num_lf_groups() == f[10].u64()
		toc := reader.read_toc(int(frame.num_toc_entries()))!
		mut sections := reader.read_sections(toc)!
		state := sections[0].read_lf_global(file, frame)!
		noise := state.noise or { panic('Missing noise LUT') }
		assert noise.lut[..].map(math.f32_bits(it)) == f[7].split(',').map(it.u32())
		if noise.lut == [8]f32{} { zero++ }
		if toc.permuted { permuted++ }
		if frame.num_lf_groups() > 1 { multiple_lf++ }
		factors[ceil_log2(int(frame.upsampling))] = true
		count++
	}
	assert count == 28 && total == 2477600 && zero == 7 && permuted > 0 && multiple_lf == 4 && factors.all(it)
}

fn test_noise_fields_bound_allocations_and_preserve_partial_rows() {
	for dims in [[0, 1], [1, 0], [65536, 65536]] {
		if _ := generate_noise_fields(dims[0], dims[1], 1, 0) { assert false }
	}
	fields := generate_noise_fields(1, 1, 1, 0)!
	for plane in fields {
		assert plane.width == 1 && plane.height == 1 && plane.samples.len == 1
		assert plane.samples[0] >= 0 && plane.samples[0] <= 65535
		assert convolve_noise_plane(plane)!.samples.all(math.is_finite(it))
	}
}

fn test_noisy_output_rejects_truncated_and_trailing_frame_payloads() {
	data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/noise/noise-3-3.jxl'))!
	for end in [0, 1, 2, 5, 10, data.len / 2, data.len - 1] {
		if _ := decode_rgba(data[..end], false) { assert false }
	}
	mut trailing := data.clone()
	trailing << u8(0)
	if _ := decode_rgba(trailing, true) { assert false }
}
