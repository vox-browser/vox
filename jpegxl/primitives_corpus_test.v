module jpegxl

import encoding.hex
import math

fn primitive_result(operation string, mut reader BitReader) !string {
	match operation {
		'f16' { return math.f32_bits(reader.read_f16()!).str() }
		'u64' { return reader.read_u64()!.str() }
		'size', 'preview' {
			size := reader.read_size(operation == 'preview')!
			return '${size.width},${size.height}'
		}
		'depth' {
			depth := reader.read_bit_depth()!
			return '${if depth.floating_point { 1 } else { 0 }},${depth.bits_per_sample},${depth.exponent_bits}'
		}
		'hybrid' {
			config := reader.read_hybrid_uint(15)!
			return 'HybridUint { split_token: ${u32(1) << config.split_exponent}, split_exponent: ${config.split_exponent}, msb_in_token: ${config.msb_in_token}, lsb_in_token: ${config.lsb_in_token} }'
		}
		else { return error('Unknown fixture operation') }
	}
}

fn test_jpegxl_primitives_match_frozen_jxl_0_7_results() {
	mut count := 0
	for line in $embed_file('testdata/primitives.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4, line
		data := hex.decode(fields[1])!
		mut reader := new_bit_reader(data)
		result := primitive_result(fields[0], mut reader) or { 'err' }
		assert result == fields[3], line
		assert reader.position == fields[2].int(), line
		count++
	}
	assert count == 75776
}
