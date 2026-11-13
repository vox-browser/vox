// SPDX-License-Identifier: Unicode-3.0
// Greek tailoring follows ICU; see data/LICENSE for the Unicode license.
// Greek uppercase tailoring, including disjunctive eta and hiatus diaeresis.
// Unicode case data supplies letter forms; contextual rules follow the
// GreekUpper algorithm documented at icu.unicode.org/design/case/greek-upper.
module vunicode

fn greek_diacritic(p u32) bool {
	return p in [u32(0x300), 0x301, 0x302, 0x303, 0x304, 0x306, 0x308, 0x311, 0x313, 0x314, 0x342,
		0x343, 0x344, 0x345]
}

fn greek_accent(p u32) bool { return p in [u32(0x300), 0x301, 0x302, 0x303, 0x311, 0x342, 0x344] }

fn greek_letter(p u32) bool {
	return ((p >= 0x370 && p <= 0x3ff) || (p >= 0x1f00 && p <= 0x1fff) || p == 0x2126) && property_named(p, 'Cased')
}

fn greek_uppercase(points []u32) CaseMapping {
	mut output := []u16{}
	mut edits := []CaseEdit{}
	mut i := 0
	mut source := 0
	mut preceding_accent := 0
	for i < points.len {
		p := points[i]
		mut next := i + 1
		mut mapped := full_upper(p)
		mut next_accent := 0
		if greek_letter(p) {
			decomposed := normalize([p], .nfd)
			mut upper := full_upper(decomposed[0])[0]
			precomposed_accent := decomposed.any(greek_accent(it))
			mut accent := precomposed_accent
			mut precomposed_diaeresis := u32(0x308) in decomposed
			mut combining_diaeresis := false
			mut subscripts := decomposed.filter(it == 0x345).len
			for next < points.len && greek_diacritic(points[next]) {
				mark := points[next]
				if greek_accent(mark) { accent = true }
				if mark in [u32(0x308), 0x344] { combining_diaeresis = true }
				if mark == 0x345 { subscripts++ }
				next++
			}
			vowel := upper in [u32(0x391), 0x395, 0x397, 0x399, 0x39f, 0x3a5, 0x3a9]
			if vowel && preceding_accent != 0 && upper in [u32(0x399), 0x3a5] {
				if preceding_accent == 1 {
					precomposed_diaeresis = true
				} else {
					combining_diaeresis = true
				}
			}
			if vowel && accent && !precomposed_diaeresis && !combining_diaeresis {
				next_accent = if precomposed_accent { 1 } else { 2 }
			}
			mut tonos := false
			if upper == 0x397 && accent && subscripts == 0 && !cased_before(points, i) && !cased_after(points, next - 1) {
				if precomposed_accent { upper = 0x389 } else { tonos = true }
			} else if precomposed_diaeresis && upper in [u32(0x399), 0x3a5] {
				upper = if upper == 0x399 { u32(0x3aa) } else { u32(0x3ab) }
				precomposed_diaeresis = false
				combining_diaeresis = false
			}
			mapped = [upper]
			if precomposed_diaeresis || combining_diaeresis { mapped << u32(0x308) }
			if tonos { mapped << u32(0x301) }
			for _ in 0 .. subscripts { mapped << u32(0x399) }
		}
		original_length := encode_utf16(points[i..next]).len
		rendered := encode_utf16(mapped)
		if original_length != rendered.len {
			edits << CaseEdit{source, original_length, output.len, rendered.len}
		}
		output << rendered
		source += original_length
		preceding_accent = next_accent
		i = next
	}
	return CaseMapping{output, edits}
}
