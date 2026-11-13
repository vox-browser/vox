module vunicode

const idna_idna_data = $embed_file('data/idna.bin').to_string()
const idna_idna_pool_data = $embed_file('data/idna_pool.bin').to_string()

pub fn idna_map(points []u32, strict bool) ?[]u32 {
	data := idna_idna_data
	pool := idna_idna_pool_data
	mut result := []u32{cap: points.len}
	for p in points {
		i := row(data, p, 20)
		if i < 0 { return none }
		status := word(data, i + 8)
		if status == 4 || (strict && status in [u32(5), 6]) { return none }
		if status == 1 { continue }
		if status in [u32(2), 6] {
			start := int(word(data, i + 12)) * 4
			for j in 0 .. int(word(data, i + 16)) { result << word(pool, start + j * 4) }
		} else {
			result << p
		}
	}
	return normalize(result, .nfc)
}

// UTS #46 validity with nontransitional processing and ContextJ. Bidi is
// checked for every label when the domain contains an RTL character.
pub fn idna_valid_label(points []u32, strict bool, bidi_domain bool) bool {
	if points.len == 0 { return !strict }
	if !strict && points.len >= 4 && points[..4] == [u32(0x78), 0x6e, 0x2d, 0x2d] { return false }
	if strict && (points[0] == 45 || points.last() == 45 || (points.len >= 4 && points[2] == 45 && points[3] == 45)) {
		return false
	}
	if category(points[0]) in [u32(6), 7, 8] { return false }
	if normalize(points, .nfc) != points { return false }
	data := idna_idna_data
	for i, p in points {
		if strict && p < 128 && !((p >= 0x61 && p <= 0x7a) || (p >= 0x30 && p <= 0x39) || p == 45) {
			return false
		}
		j := row(data, p, 20)
		if j < 0 { return false }
		status := word(data, j + 8)
		if status !in [u32(0), 3] && !(status == 5 && !strict) { return false }
		if p == 0x2e { return false }
		if p in [u32(0x200c), 0x200d] {
			if i > 0 && combining_class(points[i - 1]) == 9 { continue }
			if p == 0x200d { return false }
			mut left := i - 1
			for left >= 0 && joining_type(points[left]) == 'T' { left-- }
			mut right := i + 1
			for right < points.len && joining_type(points[right]) == 'T' { right++ }
			if left < 0 || right == points.len || joining_type(points[left]) !in ['L', 'D'] || joining_type(points[right]) !in [
				'R',
				'D',
			] {
				return false
			}
		}
	}
	if !bidi_domain { return true }
	first := bidi_class(points[0])
	rtl := first in [u32(1), 13]
	if !rtl && first != 0 { return false }
	mut last := first
	mut en := false
	mut an := false
	for p in points {
		c := bidi_class(p)
		if rtl {
			if c !in [u32(1), 13, 5, 2, 3, 6, 4, 10, 18, 17] { return false }
		} else if c !in [u32(0), 2, 3, 6, 4, 10, 18, 17] {
			return false
		}
		if c == 2 { en = true }
		if c == 5 { an = true }
		if c != 17 { last = c }
	}
	if rtl { return last in [u32(1), 13, 2, 5] && !(en && an) }
	return last in [u32(0), 2]
}
