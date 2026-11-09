module jpegxl

import encoding.hex
import math

fn test_lf_quant_factors_match_pinned_source_float_words_and_positions() {
	mut count := 0
	for line in $embed_file('testdata/lf-quant.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		mut reader := new_bit_reader(hex.decode(f[0])!)
		result := if q := reader.read_lf_quant_factors() {
			'${q.quant_factors[..].map(math.f32_bits(it).str()).join(',')}|${q.inverse_factors[..].map(math.f32_bits(it).str()).join(',')}'
		} else {
			'err'
		}
		assert result == f[2], 'LF quantization ${count}'
		assert reader.position == f[1].int()
		count++
	}
	assert count == 4096
}
