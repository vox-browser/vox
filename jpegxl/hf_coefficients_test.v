module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex

fn hf_channel_fixture_status(params HfChannelParameters, permutation Permutation, contexts int, mut input BitReader, mut coefficients []i32) string {
	mut histograms := input.read_histograms(contexts, true) or { return 'parse' }
	histograms.resize(params.histogram_offset + 474) or { return 'parse' }
	mut symbols := SymbolReader.new(histograms, mut input, none) or { return 'parse' }
	decode_hf_channel(params, permutation, histograms, mut input, mut symbols, mut coefficients) or {
		assert err.msg() == 'Residual JPEG XL HF nonzeros', err.msg()
		return 'residual'
	}
	symbols.check_final_state(histograms, input) or { return 'entropy' }
	return 'ok'
}

fn test_hf_channels_match_original_entropy_decode_and_progressive_accumulation() {
	mut count := 0
	mut words := 0
	mut successes := 0
	for line in $embed_file('testdata/hf-channels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 12
		params := HfChannelParameters{
			storage: if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			transform: hf_transform_from_id(f[1].int())!
			shift: f[2].u32()
			nonzeros: f[3].u32()
			histogram_offset: f[4].int()
		}
		permutation := Permutation{ values: f[6].split(',').map(it.u32()) }
		mut coefficients := f[7].split(',').map(i32(it.i64()))
		bytes := hex.decode(f[8])!
		mut input := new_bit_reader(bytes)
		actual := hf_channel_fixture_status(params, permutation, f[5].int(), mut input, mut coefficients)
		assert actual == f[10], 'HF channel ${count}: ${actual}, expected ${f[10]}'
		if f[9].int() <= bytes.len * 8 {
			assert input.position == f[9].int(), 'HF channel cursor ${count}'
		} else {
			assert actual != 'ok'
		}
		mut output := []u8{len: coefficients.len * 4}
		for k, value in coefficients { binary.little_endian_put_u32_at(mut output, u32(value), k * 4) }
		assert sha256.sum(output).hex() == f[11], 'HF channel coefficient buffer ${count}'
		if actual == 'ok' { successes++ }
		words += coefficients.len
		count++
	}
	assert count == 1152
	assert successes > 800
	assert words > 776448
}

fn test_hf_channels_validate_parameters_before_consuming_or_modifying() {
	mut input := new_bit_reader([u8(0xf2), 1])
	histograms := input.read_histograms(474, true)!
	mut symbols := SymbolReader.new(histograms, mut input, none)!
	mut values := []u32{len: 64}
	for i in 0 .. 64 { values[i] = u32(i) }
	permutation := Permutation{ values: values }
	mut coefficients := []i32{len: 64, init: 1}
	before := coefficients.clone()
	position := input.position
	for invalid in [HfChannelParameters{ shift: 32 },
		HfChannelParameters{ nonzeros: 64 }, HfChannelParameters{ histogram_offset: -1 },
		HfChannelParameters{ histogram_offset: 1 }, HfChannelParameters{ transform: .dct16x16 }] {
		if _ := decode_hf_channel(invalid, permutation, histograms, mut input, mut symbols, mut coefficients) { assert false }
		assert input.position == position && coefficients == before
	}
	for bad_index in [u32(0), 64] {
		mut bad := values.clone()
		bad[1] = bad_index
		if _ := decode_hf_channel(HfChannelParameters{}, Permutation{ values: bad }, histograms, mut input, mut symbols, mut coefficients) { assert false }
		assert input.position == position && coefficients == before
	}
	coefficients[63] = 32768
	if _ := decode_hf_channel(HfChannelParameters{ storage: .signed16 }, permutation, histograms, mut input, mut symbols, mut coefficients) { assert false }
	assert input.position == position && coefficients[63] == 32768
}
