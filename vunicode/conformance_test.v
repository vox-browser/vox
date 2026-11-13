module vunicode

fn conformance_points(field string) []u32 {
	return field.fields().map(u32(it.parse_uint(16, 32) or { panic(err) }))
}

fn test_unicode17_normalization_conformance() {
	for line in $embed_file('testdata/NormalizationTest.txt').to_string().split_into_lines() {
		body := line.all_before('#').trim_space()
		if body == '' || body.starts_with('@') { continue }
		fields := body.split(';')
		a := conformance_points(fields[0])
		b := conformance_points(fields[1])
		c := conformance_points(fields[2])
		d := conformance_points(fields[3])
		e := conformance_points(fields[4])
		for input in [a, b, c] {
			assert normalize(input, .nfc) == b, body
			assert normalize(input, .nfd) == c, body
		}
		for input in [a, b, c, d, e] {
			assert normalize(input, .nfkc) == d, body
			assert normalize(input, .nfkd) == e, body
		}
		for input in [d, e] {
			assert normalize(input, .nfc) == d, body
			assert normalize(input, .nfd) == e, body
		}
	}
}

fn test_unicode17_default_line_break_conformance() {
	mut failures := 0
	for line in $embed_file('testdata/LineBreakTest.txt').to_string().split_into_lines() {
		body := line.all_before('#').trim_space()
		if body == '' { continue }
		mut points := []u32{}
		mut expected := [0]
		mut offset := 0
		for token in body.fields() {
			if token == '×' { continue }
			if token == '÷' {
				if offset > 0 { expected << offset }
				continue
			}
			p := u32(token.parse_uint(16, 32) or { panic(err) })
			points << p
			offset += if p > 0xffff { 2 } else { 1 }
		}
		if line_boundaries(points, 0) != expected {
			if failures < 20 { eprintln(line) }
			failures++
		}
	}
	assert failures == 0
}

fn test_unicode17_bidi_character_conformance() {
	for line in $embed_file('testdata/BidiCharacterTest.txt').to_string().split_into_lines() {
		body := line.all_before('#').trim_space()
		if body == '' { continue }
		fields := body.split(';')
		points := conformance_points(fields[0])
		if fields[1] == '2' { continue } // Caller supplies an explicit paragraph direction.
		actual := bidi_levels(points, fields[1] == '1')
		expected := fields[3].fields()
		mut offset := 0
		mut point_levels := []u8{}
		for i, p in points {
			point_levels << actual[offset]
			if expected[i] != 'x' {
				assert actual[offset] == u8(expected[i].int()), line
			}
			offset += if p > 0xffff { 2 } else { 1 }
		}
		reordered := visual_order(point_levels).filter(expected[it] != 'x')
		assert reordered == fields[4].fields().map(it.int()), line
	}
}

fn test_unicode17_word_break_conformance() {
	for line in $embed_file('testdata/WordBreakTest.txt').to_string().split_into_lines() {
		body := line.all_before('#').trim_space()
		if body == '' { continue }
		mut points := []u32{}
		mut expected := []int{}
		for token in body.fields() {
			if token == '×' { continue }
			if token == '÷' {
				expected << points.len
				continue
			}
			points << u32(token.parse_uint(16, 32) or { panic(err) })
		}
		assert word_boundaries(points) == expected, line
	}
}
