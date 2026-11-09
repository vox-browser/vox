module jpegxl

fn rct_test_text(values [3]i32) string { return '${values[0]},${values[1]},${values[2]}' }

fn rct_test_text16(values [3]i16) string { return '${values[0]},${values[1]},${values[2]}' }

fn test_reversible_color_matches_source_for_all_types_and_storage_widths() {
	mut count := 0
	for line in $embed_file('testdata/reversible-color.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		input := f[0].split(',').map(it.i32())
		wide := f[1].split(';')
		narrow := f[2].split(';')
		assert input.len == 3 && wide.len == 42 && narrow.len == 42
		for kind in 0 .. 42 {
			assert rct_test_text(inverse_rct_sample(u32(kind), input[0], input[1], input[2])!) == wide[kind], 'RCT i32 input ${count}, type ${kind}'
			assert rct_test_text16(inverse_rct_sample16(u32(kind), i16(input[0]), i16(input[1]), i16(input[2]))!) == narrow[kind], 'RCT i16 input ${count}, type ${kind}'
			if count < 64 {
				mut first := [input[0], input[0], input[0]]
				mut second := [input[1], input[1], input[1]]
				mut third := [input[2], input[2], input[2]]
				inverse_rct_rows(mut first, mut second, mut third, u32(kind))!
				mut first16 := [i16(input[0]), i16(input[0]), i16(input[0])]
				mut second16 := [i16(input[1]), i16(input[1]), i16(input[1])]
				mut third16 := [i16(input[2]), i16(input[2]), i16(input[2])]
				inverse_rct_rows16(mut first16, mut second16, mut third16, u32(kind))!
				for x in 0 .. 3 {
					assert '${first[x]},${second[x]},${third[x]}' == wide[kind]
					assert '${first16[x]},${second16[x]},${third16[x]}' == narrow[kind]
				}
			}
		}
		count++
	}
	assert count == 2048
}

fn test_reversible_color_wraps_before_averaging_and_validates_before_writing() {
	assert inverse_rct_sample(7, 1, 2, 3)! == [i32(3), 1, 2]!
	assert inverse_rct_sample(14, 1, 2, 3)! == [i32(2), 3, 1]!
	assert inverse_rct_sample(4, 2147483647, 0, 2147483647)![1] == -1
	assert inverse_rct_sample16(4, 32767, 0, 32767)![1] == 32767
	for kind in [u32(42), ~u32(0)] {
		if _ := inverse_rct_sample(kind, 0, 0, 0) {
			assert false
		}
		if _ := inverse_rct_sample16(kind, 0, 0, 0) {
			assert false
		}
	}
	mut first := [i32(1)]
	mut second := [i32(2)]
	mut third := []i32{}
	mut rejected := false
	inverse_rct_rows(mut first, mut second, mut third, 6) or { rejected = true }
	assert rejected && first == [i32(1)] && second == [i32(2)] && third.len == 0
	third << 3
	rejected = false
	inverse_rct_rows(mut first, mut second, mut third, 42) or { rejected = true }
	assert rejected && first == [i32(1)] && second == [i32(2)] && third == [i32(3)]
	mut first16 := [i16(1)]
	mut second16 := [i16(2)]
	mut third16 := []i16{}
	rejected = false
	inverse_rct_rows16(mut first16, mut second16, mut third16, 6) or { rejected = true }
	assert rejected && first16 == [i16(1)] && second16 == [i16(2)] && third16.len == 0
}
