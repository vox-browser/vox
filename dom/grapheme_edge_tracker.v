module dom

fn segmenter_grapheme_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	for grapheme in text.graphemes() {
		code_units += utf16_code_unit_length(grapheme)
		boundaries << code_units
	}
	return boundaries
}

fn segmenter_word_class(grapheme string) int {
	if grapheme.len == 0 {
		return 0
	}
	if grapheme.len > 1 || grapheme[0] >= 0x80 {
		return 1
	}
	byte := grapheme[0]
	if (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
		|| (byte >= `0` && byte <= `9`) || byte == `_` {
		return 1
	}
	if byte == ` ` || byte == `\t` || byte == `\n` || byte == `\r` || byte == `\f` {
		return 2
	}
	return 3
}

fn segmenter_word_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	mut previous_class := -1
	for grapheme in text.graphemes() {
		class := segmenter_word_class(grapheme)
		if previous_class >= 0 && class != previous_class {
			boundaries << code_units
		}
		code_units += utf16_code_unit_length(grapheme)
		previous_class = class
	}
	if boundaries.len == 0 || boundaries.last() != code_units {
		boundaries << code_units
	}
	return boundaries
}

enum ASCIILineBreakClass {
	al
	ba
	bk
	cl
	cp
	cr
	ex
	hy
	is_
	lf
	nu
	op
	po
	pr
	qu
	sp
	sy
}

fn segmenter_can_use_ascii_line_fast_path(text string) bool {
	for byte in text.bytes() {
		if !(byte >= 0x20 && byte <= 0x7e) && byte !in [u8(`\t`), `\n`, `\v`, `\f`, `\r`] {
			return false
		}
	}
	return true
}

fn classify_ascii_line_byte(byte u8) ASCIILineBreakClass {
	return match byte {
		`\t`, `|` { .ba }
		`\n` { .lf }
		`\v`, `\f` { .bk }
		`\r` { .cr }
		` ` { .sp }
		`!`, `?` { .ex }
		`"`, `'` { .qu }
		`$`, `+`, `\\` { .pr }
		`%` { .po }
		`(`, `[`, `{` { .op }
		`)`, `]` { .cp }
		`,`, `.`, `:`, `;` { .is_ }
		`-` { .hy }
		`/` { .sy }
		`}` { .cl }
		else {
			if byte >= `0` && byte <= `9` {
				ASCIILineBreakClass.nu
			} else {
				ASCIILineBreakClass.al
			}
		}
	}
}

fn mark_ascii_numeric_expression_interiors(text []u8) []bool {
	mut interiors := []bool{len: text.len + 1}
	mut i := 0
	for i < text.len {
		if classify_ascii_line_byte(text[i]) != .nu {
			i++
			continue
		}
		mut start := i
		if start > 0 && classify_ascii_line_byte(text[start - 1]) == .is_ {
			start--
		}
		if start > 0 && classify_ascii_line_byte(text[start - 1]) in [.op, .hy] {
			start--
		}
		if start > 0 && classify_ascii_line_byte(text[start - 1]) in [.pr, .po] {
			start--
		}

		mut end := i + 1
		for end < text.len && classify_ascii_line_byte(text[end]) in [.nu, .sy, .is_] {
			end++
		}
		if end < text.len && classify_ascii_line_byte(text[end]) in [.cl, .cp] {
			end++
		}
		if end < text.len && classify_ascii_line_byte(text[end]) in [.pr, .po] {
			end++
		}
		for position := start + 1; position < end; position++ {
			interiors[position] = true
		}
		i = end
	}
	return interiors
}

fn ascii_line_boundaries(text string) []int {
	bytes := text.bytes()
	mut is_boundary := []bool{len: bytes.len + 1}
	is_boundary[0] = true
	if bytes.len == 0 {
		return [0]
	}
	is_boundary[bytes.len] = true
	interior_of_numeric_expression := mark_ascii_numeric_expression_interiors(bytes)
	mut in_op_space_run := false
	for i := 1; i < bytes.len; i++ {
		previous_class := classify_ascii_line_byte(bytes[i - 1])
		current_class := classify_ascii_line_byte(bytes[i])

		if previous_class == .cr && current_class == .lf {
			continue
		}
		if previous_class in [.bk, .cr, .lf] {
			is_boundary[i] = true
			in_op_space_run = false
			continue
		}
		if current_class in [.bk, .cr, .lf] {
			continue
		}
		if previous_class == .op {
			in_op_space_run = true
		}
		if current_class == .sp {
			continue
		}
		if in_op_space_run {
			in_op_space_run = false
			continue
		}
		if current_class in [.cl, .cp, .ex, .sy] {
			continue
		}
		if current_class == .is_ {
			if previous_class != .sp {
				continue
			}
			next_forces_break := i + 1 < bytes.len
				&& classify_ascii_line_byte(bytes[i + 1]) == .nu
			if !next_forces_break {
				continue
			}
			is_boundary[i] = true
			continue
		}
		if previous_class == .sp {
			is_boundary[i] = true
			continue
		}
		if current_class == .qu || previous_class == .qu {
			continue
		}
		if previous_class == .hy && current_class == .al {
			mut hyphen_starts_line := i == 1
			if !hyphen_starts_line && i >= 2 {
				hyphen_starts_line = classify_ascii_line_byte(bytes[i - 2]) in [.sp, .bk, .cr, .lf]
			}
			if hyphen_starts_line {
				continue
			}
		}
		if current_class in [.ba, .hy] {
			continue
		}
		if (previous_class == .al && current_class == .nu)
			|| (previous_class == .nu && current_class == .al) {
			continue
		}
		if (previous_class in [.pr, .po] && current_class == .al)
			|| (previous_class == .al && current_class in [.pr, .po]) {
			continue
		}
		if interior_of_numeric_expression[i] {
			continue
		}
		if previous_class == .al && current_class == .al {
			continue
		}
		if previous_class == .is_ && current_class == .al {
			continue
		}
		if current_class == .op && previous_class in [.al, .nu] {
			continue
		}
		if previous_class == .cp && current_class in [.al, .nu] {
			continue
		}
		is_boundary[i] = true
	}

	mut boundaries := []int{cap: bytes.len + 1}
	for index, boundary in is_boundary {
		if boundary {
			boundaries << index
		}
	}
	return boundaries
}

pub fn (segmenter &Segmenter) boundaries() []int {
	return match segmenter.granularity {
		.grapheme { segmenter_grapheme_boundaries(segmenter.segmented_text) }
		.word { segmenter_word_boundaries(segmenter.segmented_text) }
		.line {
			if segmenter.ascii_line_fast_path {
				ascii_line_boundaries(segmenter.segmented_text)
			} else {
				segmenter_line_boundaries(segmenter.segmented_text, segmenter.line_break_mode)
			}
		}
	}
}

pub fn (segmenter &Segmenter) next_boundary(offset int) ?int {
	for boundary in segmenter.boundaries() {
		if boundary > offset {
			return boundary
		}
	}
	return none
}

pub fn (segmenter &Segmenter) previous_boundary(offset int) ?int {
	boundaries := segmenter.boundaries()
	for index := boundaries.len - 1; index >= 0; index-- {
		if boundaries[index] < offset {
			return boundaries[index]
		}
	}
	return none
}

pub fn segmenter_should_continue_beyond_word(text string) bool {
	for grapheme in text.graphemes() {
		if segmenter_word_class(grapheme) == 1 {
			return false
		}
	}
	return true
}

pub fn find_line_start(text string, offset int) int {
	units := utf16_code_units_from_string(text)
	mut result := if offset < units.len { offset } else { units.len }
	for result > 0 && units[result - 1] != u16(`\n`) {
		result--
	}
	return result
}

pub fn find_line_end(text string, offset int) int {
	units := utf16_code_units_from_string(text)
	mut result := if offset < 0 {
		0
	} else if offset < units.len {
		offset
	} else {
		units.len
	}
	for result < units.len && units[result] != u16(`\n`) {
		result++
	}
	return result
}
