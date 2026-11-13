module vunicode

const normalize_decomp_data = $embed_file('data/decomp.bin').to_string()
const normalize_compat_data = $embed_file('data/compat.bin').to_string()
const normalize_decomp_pool_data = $embed_file('data/decomp_pool.bin').to_string()
const normalize_compose_data = $embed_file('data/compose.bin').to_string()

pub enum NormalizationForm {
	nfd
	nfc
	nfkd
	nfkc
}

fn decompose(point u32, compatibility bool, mut output []u32) {
	// UAX #15 section 3.12: algorithmic Hangul decomposition.
	if point >= 0xac00 && point < 0xd7a4 {
		s := point - 0xac00
		output << 0x1100 + s / 588
		output << 0x1161 + (s % 588) / 28
		if s % 28 != 0 { output << 0x11a7 + s % 28 }
		return
	}
	data := normalize_decomp_data
	if row(data, point, 16) < 0 || (!compatibility && value(normalize_compat_data, point, 0) != 0) {
		output << point
		return
	}
	for p in mapping(data, normalize_decomp_pool_data, point) {
		decompose(p, compatibility, mut output)
	}
}

fn compose(a u32, b u32) ?u32 {
	if a >= 0x1100 && a < 0x1113 && b >= 0x1161 && b < 0x1176 {
		return 0xac00 + ((a - 0x1100) * 21 + b - 0x1161) * 28
	}
	if a >= 0xac00 && a < 0xd7a4 && (a - 0xac00) % 28 == 0 && b > 0x11a7 && b < 0x11c3 {
		return a + b - 0x11a7
	}
	data := normalize_compose_data
	mut low := 0
	mut high := data.len / 12
	for low < high {
		mid := (low + high) / 2
		x := word(data, mid * 12)
		y := word(data, mid * 12 + 4)
		if a < x || (a == x && b < y) {
			high = mid
		} else if a > x || (a == x && b > y) {
			low = mid + 1
		} else {
			return word(data, mid * 12 + 8)
		}
	}
	return none
}

pub fn normalize(points []u32, form NormalizationForm) []u32 {
	mut decomposed := []u32{cap: points.len}
	for p in points { decompose(p, form in [.nfkd, .nfkc], mut decomposed) }
	// Stable canonical ordering, stopping at each starter.
	for i in 1 .. decomposed.len {
		c := combining_class(decomposed[i])
		if c == 0 { continue }
		mut j := i
		for j > 0 && combining_class(decomposed[j - 1]) > c {
			decomposed[j], decomposed[j - 1] = decomposed[j - 1], decomposed[j]
			j--
		}
	}
	if form in [.nfd, .nfkd] || decomposed.len == 0 { return decomposed }
	mut result := [decomposed[0]]
	mut starter := 0
	mut last_class := combining_class(decomposed[0])
	for p in decomposed[1..] {
		c := combining_class(p)
		if last_class == 0 || last_class < c {
			if composite := compose(result[starter], p) {
				result[starter] = composite
				continue
			}
		}
		if c == 0 { starter = result.len }
		result << p
		last_class = c
	}
	return result
}
