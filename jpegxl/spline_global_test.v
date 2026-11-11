module jpegxl

import crypto.sha256
import math
import os

fn test_spline_lf_global_preserves_native_cache_and_unchanged_coded_planes() {
	mut count := 0
	mut caches := 0
	mut permuted := 0
	mut grouped := 0
	for line in $embed_file('testdata/spline-global-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/spline-frames', f[0]))!
		assert sha256.sum(data).hex() == f[15]
		mut input := new_bit_reader(extract_codestream(data)!)
		file := input.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := input.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert frame.has_splines() && frame.has_noise()
		assert frame.size().width == f[4].u32() && frame.size().height == f[5].u32() && frame.upsampling == f[6].u32()
		assert frame.num_groups() == f[7].u64() && frame.num_lf_groups() == f[8].u64()
		toc := input.read_toc(int(frame.num_toc_entries()))!
		mut sections := input.read_sections(toc)!
		mut full_sections := sections.clone()
		mut primitive := sections[0]
		curves := primitive.read_splines(frame.width * frame.height)!
		assert primitive.position == f[2].int() && curves.splines.len == 1
		_ := primitive.read_noise()!
		lf_quant := primitive.read_lf_quant_factors()!
		quantizer := primitive.read_quantizer_params()!
		_ := primitive.read_block_context_map()!
		_ := primitive.read_color_correlation_params()!
		assert primitive.position == f[3].int()
		assert '${quantizer.global_scale},${quantizer.quant_lf}' == f[9]
		assert lf_quant.quant_factors[..].map(math.f32_bits(it).str()).join(',') == f[10]
		assert lf_quant.inverse_factors[..].map(math.f32_bits(it).str()).join(',') == f[11]
		state := sections[0].read_lf_global(file, frame)!
		cache := state.spline_cache or { panic('Lost spline global state') }
		assert_spline_global_cache(cache, f)
		storage := if file.metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
		raw := decode_vardct_frame_with_lf(file, frame, storage, none, mut full_sections)!
		assert_spline_global_cache(raw.spline_cache or { panic('Lost spline frame state') }, f)
		control := os.read_bytes(os.join_path(@VMODROOT, f[16]))!
		assert sha256.sum(control).hex() == f[17]
		old := read_spline_global_control(control)!
		assert old.spline_cache == none
		for c in 0 .. 3 {
			assert raw.planes[c].width == old.planes[c].width && raw.planes[c].height == old.planes[c].height
			assert spline_global_plane_hash(raw.planes[c]) == spline_global_plane_hash(old.planes[c]), 'Changed coded color samples ${f[0]}/${c}'
		}
		assert raw.extra_channels == old.extra_channels
		if cache.segments.len > 0 { caches++ }
		if toc.permuted { permuted++ }
		if frame.num_lf_groups() > 1 { grouped++ }
		count++
	}
	assert count == 42 && caches == 28 && permuted > 0 && grouped == 6
}

fn assert_spline_global_cache(cache SplineDrawCache, f []string) {
	assert cache.is_initialized() && cache.width == f[4].int() && cache.height == f[5].int()
	mut words := []u32{}
	for segment in cache.segments {
		for value in [segment.center_x, segment.center_y, segment.maximum_distance, segment.inv_sigma,
			segment.sigma_over_4_times_intensity, segment.color[0], segment.color[1], segment.color[2]] {
			words << if math.is_nan(value) { u32(0x7fc00000) } else { math.f32_bits(value) }
		}
	}
	expected := if f[12] == '' { []u32{} } else { f[12].split(',').map(it.u32()) }
	assert words.len == expected.len
	for i, word in words { assert word == expected[i], 'Spline global ${f[0]}, segment field ${i}' }
	assert cache.row_starts == f[13].split(',').map(it.int())
	assert cache.row_indices == if f[14] == '' { []int{} } else { f[14].split(',').map(it.int()) }
}

fn read_spline_global_control(data []u8) !VarDctFramePlanes {
	mut input := new_bit_reader(extract_codestream(data)!)
	file := input.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := input.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	toc := input.read_toc(int(frame.num_toc_entries()))!
	mut sections := input.read_sections(toc)!
	storage := if file.metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
	return decode_vardct_frame_with_lf(file, frame, storage, none, mut sections)
}

fn spline_global_plane_hash(plane FloatPlane) string {
	mut bytes := []u8{len: plane.samples.len * 4}
	for i, value in plane.samples {
		word := math.f32_bits(value)
		for shift in 0 .. 4 { bytes[i * 4 + shift] = u8(word >> (shift * 8)) }
	}
	return sha256.sum(bytes).hex()
}
