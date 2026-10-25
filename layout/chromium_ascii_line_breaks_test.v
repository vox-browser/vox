module layout

fn test_chromium_ascii_identifiers_and_punctuation_breaks() {
	for text, expected in {
		'r/experienceddevs':     []int{}
		'https://example.com/a': []int{}
		'open-source':           [5]
		'what?next':             [5]
		'item-2':                [5]
		'-2':                    []int{}
	} {
		units := utf16_code_units_for_line_box(text)
		mut boundaries := []bool{len: units.len + 1, init: true}
		apply_chromium_ascii_line_breaks(units, mut boundaries)
		mut actual := []int{}
		for i in 1 .. units.len {
			if boundaries[i] { actual << i }
		}
		assert actual == expected, '${text}: ${actual}'
	}
}
