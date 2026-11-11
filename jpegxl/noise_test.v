module jpegxl

import encoding.hex
import math

fn test_noise_lut_headers_match_native_words_consumption_and_truncation() {
	mut count := 0
	mut accepted := 0
	mut covered := []bool{len: 1024}
	for line in $embed_file('testdata/noise-headers.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		mut reader := new_bit_reader(hex.decode(f[1])!)
		if noise := reader.read_noise() {
			assert f[2] != 'err'
			assert reader.position == f[2].u64()
			assert noise.lut[..].map(math.f32_bits(it)) == f[3].split(',').map(it.u32()), 'Noise header ${f[0]}'
			covered[int(noise.lut[0] * f32(1024))] = true
			accepted++
		} else { assert f[2] == 'err' }
		count++
	}
	assert count == 1034 && accepted == 1024 && covered.all(it)
}

fn test_noise_rng_constructors_and_successive_blocks_match_native_words() {
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/noise-rng.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		seeds := f[1].split(',').map(it.u64())
		mut rng := if f[0] == 'one' { new_noise_rng_single(seeds[0]) } else {
			new_noise_rng(u32(seeds[0]), u32(seeds[1]), u32(seeds[2]), u32(seeds[3]))
		}
		expected := f[2].split(',').map(it.u64())
		assert expected.len == 96
		mut actual := []u64{cap: expected.len}
		for _ in 0 .. 12 { actual << rng.next_block()[..] }
		assert actual == expected, 'Noise RNG ${count}, ${f[0]}'
		words += actual.len
		count++
	}
	assert count == 128 && words == 12288
}
