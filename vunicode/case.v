module vunicode

const case_upper_data = $embed_file('data/upper.bin').to_string()
const case_upper_pool_data = $embed_file('data/upper_pool.bin').to_string()
const case_lower_data = $embed_file('data/lower.bin').to_string()
const case_lower_pool_data = $embed_file('data/lower_pool.bin').to_string()
const case_title_data = $embed_file('data/title.bin').to_string()
const case_title_pool_data = $embed_file('data/title_pool.bin').to_string()

pub enum CaseTransform {
	uppercase
	lowercase
	titlecase
}

pub struct CaseEdit {
pub:
	source_start    int
	source_length   int
	rendered_start  int
	rendered_length int
}

pub struct CaseMapping {
pub:
	units []u16
	edits []CaseEdit
}

pub fn full_upper(point u32) []u32 {
	return mapping(case_upper_data, case_upper_pool_data, point)
}

fn full_lower(point u32) []u32 {
	return mapping(case_lower_data, case_lower_pool_data, point)
}

fn full_title(point u32) []u32 {
	return mapping(case_title_data, case_title_pool_data, point)
}

fn cased_before(points []u32, index int) bool {
	for i := index - 1; i >= 0; i-- {
		if property_named(points[i], 'Case_Ignorable') { continue }
		return property_named(points[i], 'Cased')
	}
	return false
}

fn cased_after(points []u32, index int) bool {
	for p in points[index + 1..] {
		if property_named(p, 'Case_Ignorable') { continue }
		return property_named(p, 'Cased')
	}
	return false
}

fn more_above(points []u32, index int) bool {
	for p in points[index + 1..] {
		c := combining_class(p)
		if c == 230 { return true }
		if c == 0 { break }
	}
	return false
}

fn before_dot(points []u32, index int) bool {
	for p in points[index + 1..] {
		if p == 0x307 { return true }
		if combining_class(p) in [u32(0), 230] { break }
	}
	return false
}

fn after_base(points []u32, index int, soft bool) bool {
	for i := index - 1; i >= 0; i-- {
		p := points[i]
		if (soft && property_named(p, 'Soft_Dotted')) || (!soft && p == 0x49) { return true }
		if combining_class(p) in [u32(0), 230] { break }
	}
	return false
}

fn contextual_case(points []u32, i int, lang string, transform CaseTransform) []u32 {
	p := points[i]
	if transform == .lowercase {
		if p == 0x3a3 && cased_before(points, i) && !cased_after(points, i) { return [u32(0x3c2)] }
		if lang in ['tr', 'az'] {
			if p == 0x130 { return [u32(0x69)] }
			if p == 0x49 && !before_dot(points, i) { return [u32(0x131)] }
			if p == 0x307 && after_base(points, i, false) { return []u32{} }
		}
		if lang == 'lt' {
			if p in [u32(0x49), 0x4a, 0x12e] && more_above(points, i) {
				return [full_lower(p)[0], u32(0x307)]
			}
			if p == 0xcc { return [u32(0x69), 0x307, 0x300] }
			if p == 0xcd { return [u32(0x69), 0x307, 0x301] }
			if p == 0x128 { return [u32(0x69), 0x307, 0x303] }
		}
		return full_lower(p)
	}
	if lang in ['tr', 'az'] && p == 0x69 { return [u32(0x130)] }
	if lang == 'lt' && p == 0x307 && after_base(points, i, true) { return []u32{} }
	if transform == .titlecase { return full_title(p) }
	return full_upper(p)
}

pub fn map_case(units []u16, locale string, transform CaseTransform) CaseMapping {
	points := decode_utf16(units)
	lang := locale.replace('_', '-').split('-')[0].to_lower()
	if lang == 'el' && transform == .uppercase { return greek_uppercase(points) }
	boundaries := if transform == .titlecase { word_boundaries(points) } else { []int{} }
	mut title_initials := []bool{len: points.len}
	if transform == .titlecase {
		for word in 0 .. boundaries.len - 1 {
			for index in boundaries[word] .. boundaries[word + 1] {
				if property_named(points[index], 'Cased') {
					title_initials[index] = true
					break
				}
			}
		}
	}
	mut output := []u16{cap: units.len}
	mut edits := []CaseEdit{}
	mut source := 0
	for i, p in points {
		length := if p > 0xffff { 2 } else { 1 }
		mut mapped := [p]
		if transform != .titlecase || title_initials[i] {
			mapped = contextual_case(points, i, lang, transform)
			// Dutch titlecase treats IJ as a single initial letter.
			if transform == .titlecase && lang == 'nl' && p in [u32(0x69), 0x49] && i + 1 < points.len && points[i + 1] in [
				u32(0x6a),
				0x4a,
			] {
				mapped = [u32(0x49)]
			}
		} else if transform == .titlecase && lang == 'nl' && i > 0 && p in [u32(0x6a), 0x4a] && points[i - 1] in [
			u32(0x69),
			0x49,
		] && title_initials[i - 1] {
			mapped = [u32(0x4a)]
		}
		rendered := encode_utf16(mapped)
		if rendered.len != length { edits << CaseEdit{source, length, output.len, rendered.len} }
		output << rendered
		source += length
	}
	return CaseMapping{output, edits}
}
