module jpegxl

import crypto.sha256
import encoding.binary
import math

fn hf_render_fixture_floats(text string) []f32 {
	return text.split(',').map(math.f32_from_bits(it.u32()))
}

fn hf_render_fixture_matrices(seed int) !DequantMatrices {
	mut tables := []DequantMatrix{cap: 17}
	for t in 0 .. 17 {
		blocks := quant_table_blocks(t)!
		num := blocks[0] * blocks[1] * 64
		mut samples := []f32{len: 3 * num}
		for c in 0 .. 3 {
			for k in 0 .. num { samples[c * num + k] = f32(8 + ((seed * 7 + t * 11 + c * 3 + k) % 29)) / f32(4096) }
		}
		tables << DequantMatrix{ rows: blocks[0] * 8, columns: blocks[1] * 8, samples: samples }
	}
	return DequantMatrices{ tables: tables }
}

fn hf_render_fixture_digest(planes [3]FloatPlane) string {
	mut words := 6
	for plane in planes { words += plane.samples.len }
	mut bytes := []u8{len: words * 4}
	mut offset := 0
	for plane in planes {
		for value in [u32(plane.width), u32(plane.height)] {
			binary.little_endian_put_u32_at(mut bytes, value, offset)
			offset += 4
		}
		for value in plane.samples {
			binary.little_endian_put_u32_at(mut bytes, math.f32_bits(value), offset)
			offset += 4
		}
	}
	assert offset == bytes.len
	return sha256.sum(bytes).hex()
}

fn test_hf_group_rendering_matches_complete_source_planes_and_subsampled_placement() {
	context := BlockContextMap{ context_map: []u8{len: 39}, num_lf_contexts: 1, num_contexts: 1 }
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/hf-render.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 19
		maps := HfGroupMaps{ width: f[0].int(), height: f[1].int(),
			transform_ids: f[11].split(',').map(u8(it.u32())), raw_quant: f[12].split(',').map(i32(it.i64())),
			lf_contexts: []u8{len: f[0].int() * f[1].int()} }
		sampling := f[2].split(';')
		h := sampling[0].split(',').map(it.u32())
		v := sampling[1].split(',').map(it.u32())
		params := HfGroupParameters{ horizontal_shift: [h[0], h[1], h[2]]!, vertical_shift: [v[0], v[1], v[2]]! }
		biases := hf_render_fixture_floats(f[10])
		rendering := HfGroupRendering{
			storage: if f[3] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			quantizer: QuantizerParams{ global_scale: f[4].u32() }
			x_qm_scale: f[5].u32()
			b_qm_scale: f[6].u32()
			color_correlation: ColorCorrelationParams{ color_factor: f[7].u32(),
				base_correlation_x: math.f32_from_bits(f[8].u32()), base_correlation_b: math.f32_from_bits(f[9].u32()) }
			biases: [biases[0], biases[1], biases[2], biases[3]]!
		}
		low := f[15].split(';')
		quantized := f[16].split(';')
		mut lf := [3]FloatPlane{}
		mut coefficients := [3][]i32{}
		for c in 0 .. 3 {
			lf[c] = FloatPlane{ width: maps.width >> h[c], height: maps.height >> v[c], samples: hf_render_fixture_floats(low[c]) }
			coefficients[c] = quantized[c].split(',').map(i32(it.i64()))
		}
		before := coefficients[0].clone()
		output := render_hf_group(maps, params, context, HfGroupColorMap{
			y_to_x: f[13].split(',').map(i32(it.i64())), y_to_b: f[14].split(',').map(i32(it.i64())) },
			lf, coefficients, hf_render_fixture_matrices(f[17].int())!, rendering)!
		assert coefficients[0] == before
		assert hf_render_fixture_digest(output) == f[18], 'HF rendered group ${count}'
		for c in 0 .. 3 {
			assert output[c].width == lf[c].width * 8 && output[c].height == lf[c].height * 8
			words += output[c].samples.len
		}
		count++
	}
	assert count == 64
	assert words > 1000000
}

fn test_hf_render_constant_lf_reconstructs_every_sample_and_checks_geometry() {
	maps := HfGroupMaps{ width: 2, height: 2, raw_quant: []i32{len: 4, init: 1},
		transform_ids: []u8{len: 4, init: 128}, lf_contexts: []u8{len: 4} }
	context := BlockContextMap{ context_map: []u8{len: 39}, num_lf_contexts: 1, num_contexts: 1 }
	colors := HfGroupColorMap{ y_to_x: [i32(0)], y_to_b: [i32(0)] }
	coefficients := [ []i32{len: 256}, []i32{len: 256}, []i32{len: 256} ]!
	rendering := HfGroupRendering{ quantizer: QuantizerParams{ global_scale: 65536 }, x_qm_scale: 2, b_qm_scale: 2 }
	matrices := hf_render_fixture_matrices(0)!
	for mode in 0 .. 4 {
		h := if mode == 1 || mode == 2 { u32(1) } else { u32(0) }
		v := if mode == 1 || mode == 3 { u32(1) } else { u32(0) }
		params := HfGroupParameters{ horizontal_shift: [h, 0, h]!, vertical_shift: [v, 0, v]! }
		mut lf := [3]FloatPlane{}
		for c in 0 .. 3 {
			w := 2 >> params.horizontal_shift[c]
			height := 2 >> params.vertical_shift[c]
			lf[c] = FloatPlane{ width: w, height: height, samples: []f32{len: w * height, init: f32(c + 1)} }
		}
		output := render_hf_group(maps, params, context, colors, lf, coefficients, matrices, rendering)!
		for c in 0 .. 3 { assert output[c].samples.all(it == f32(c + 1)) }
		if _ := render_hf_group(maps, params, context, HfGroupColorMap{}, lf, coefficients, matrices, rendering) { assert false }
		if _ := render_hf_group(maps, params, context, HfGroupColorMap{ y_to_x: [i32(128)], y_to_b: [i32(0)] }, lf, coefficients, matrices, rendering) { assert false }
		lf[0] = FloatPlane{}
		if _ := render_hf_group(maps, params, context, colors, lf, coefficients, matrices, rendering) { assert false }
	}
}
