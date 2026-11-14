// UAX #14 Unicode 17 default line breaking with CSS CJK tailoring.
module vunicode

fn resolved_line_class(p u32, mode int) string {
	mut c := line_class(p)
	if c in ['AI', 'SG', 'XX'] { c = 'AL' }
	if c == 'SA' { c = if category(p) in [u32(6), 8] { 'CM' } else { 'AL' } }
	if c == 'CJ' { c = if mode == 0 { 'NS' } else { 'ID' } }
	if mode >= 2 && p in [u32(0x3005), 0x303b, 0x309d, 0x309e, 0x30fd, 0x30fe] { c = 'ID' }
	if mode >= 3 && p in [u32(0x30fb), 0xff1a, 0xff1b, 0xff65, 0x203c, 0x2047, 0x2048, 0x2049,
		0xff01, 0xff1f, 0x301c, 0x30a0, 0xb0, 0x2030, 0x2032, 0x2033, 0x2035, 0x2103, 0x2109, 0xfe6a,
		0xff05, 0xffe0] {
		c = 'ID'
	}
	return c
}

fn east_asian(p u32) bool { return east_asian_width(p) in ['F', 'W', 'H'] }

fn alphabetic_line(c string) bool { return c in ['AL', 'HL'] }

fn hangul_line(c string) bool { return c in ['JL', 'JV', 'JT', 'H2', 'H3'] }

fn line_allows(points []u32, classes []string, raw []string, i int) bool {
	a := classes[i - 1]
	b := classes[i]
	if a == 'CR' && b == 'LF' { return false } // LB5
	if a in ['BK', 'CR', 'LF', 'NL'] { return true }
	if b in ['BK', 'CR', 'LF', 'NL', 'SP', 'ZW'] { return false } // LB6–7
	mut j := i - 1
	for j > 0 && classes[j] == 'SP' { j-- }
	prev := classes[j]
	if prev == 'ZW' { return true } // LB8
	if raw[i] in ['CM', 'ZWJ'] && a !in ['BK', 'CR', 'LF', 'NL', 'SP', 'ZW'] { return false }
	if a == 'WJ' || b == 'WJ' || a == 'GL' { return false }
	if b == 'GL' && a !in ['SP', 'BA', 'HY', 'HH'] { return false }
	if b in ['CL', 'CP', 'EX', 'SY'] || prev == 'OP' { return false }
	if prev == 'QU' && category(points[j]) == 28 && (j == 0 || classes[j - 1] in ['BK', 'CR', 'LF',
		'NL', 'OP', 'QU', 'GL', 'SP', 'ZW']) {
		return false
	}
	if b == 'QU' && category(points[i]) == 29 && (i + 1 == points.len || classes[i + 1] in [
		'SP',
		'GL',
		'WJ',
		'CL',
		'QU',
		'CP',
		'EX',
		'IS',
		'SY',
		'BK',
		'CR',
		'LF',
		'NL',
		'ZW',
	]) {
		return false
	}
	if a == 'SP' && b == 'IS' && i + 1 < points.len && classes[i + 1] == 'NU' { return true }
	if b == 'IS' { return false }
	if prev in ['CL', 'CP'] && b == 'NS' { return false }
	if prev == 'B2' && b == 'B2' { return false }
	if a == 'SP' { return true }
	if (b == 'QU' && category(points[i]) != 28) || (a == 'QU' && category(points[i - 1]) != 29) {
		return false
	}
	if b == 'QU' && (!east_asian(points[i - 1]) || i + 1 == points.len || !east_asian(points[i + 1])) {
		return false
	}
	if a == 'QU' && (!east_asian(points[i]) || i == 1 || !east_asian(points[i - 2])) {
		return false
	}
	if a == 'CB' || b == 'CB' { return true }
	if a in ['HY', 'HH'] && alphabetic_line(b) && (i == 1 || classes[i - 2] in ['BK', 'CR', 'LF',
		'NL', 'SP', 'ZW', 'CB', 'GL']) {
		return false
	}
	if b in ['BA', 'HH', 'HY', 'NS'] || a == 'BB' { return false }
	if a in ['HY', 'HH'] && i > 1 && classes[i - 2] == 'HL' && b != 'HL' { return false }
	if a == 'SY' && b == 'HL' { return false }
	if b == 'IN' { return false }
	if (alphabetic_line(a) && b == 'NU') || (a == 'NU' && alphabetic_line(b)) { return false }
	if a == 'PR' && b in ['ID', 'EB', 'EM'] { return false }
	if a in ['ID', 'EB', 'EM'] && b == 'PO' { return false }
	if (a in ['PR', 'PO'] && alphabetic_line(b)) || (alphabetic_line(a) && b in ['PR', 'PO']) {
		return false
	}
	// LB25 numeric sequences.
	mut k := i - 1
	if classes[k] in ['CL', 'CP'] && k > 0 { k-- }
	for k > 0 && classes[k] in ['SY', 'IS'] { k-- }
	if classes[k] == 'NU' && b in ['PO', 'PR', 'NU'] { return false }
	if a in ['PO', 'PR'] && (b == 'NU' || (b == 'OP' && i + 1 < points.len && (classes[i + 1] == 'NU' || (classes[i + 1] == 'IS' && i + 2 < points.len && classes[i + 2] == 'NU')))) {
		return false
	}
	if a in ['HY', 'IS'] && b == 'NU' { return false }
	if a == 'JL' && b in ['JL', 'JV', 'H2', 'H3'] { return false }
	if a in ['JV', 'H2'] && b in ['JV', 'JT'] { return false }
	if a in ['JT', 'H3'] && b == 'JT' { return false }
	if (hangul_line(a) && b == 'PO') || (a == 'PR' && hangul_line(b)) { return false }
	if alphabetic_line(a) && alphabetic_line(b) { return false }
	ac := a in ['AK', 'AS'] || points[i - 1] == 0x25cc
	bc := b in ['AK', 'AS'] || points[i] == 0x25cc
	if a == 'AP' && bc { return false }
	if ac && b in ['VF', 'VI'] { return false }
	if a == 'VI' && i > 1 && (classes[i - 2] in ['AK', 'AS'] || points[i - 2] == 0x25cc) && (b == 'AK' || points[i] == 0x25cc) {
		return false
	}
	if ac && bc && i + 1 < points.len && classes[i + 1] == 'VF' { return false }
	if a == 'IS' && alphabetic_line(b) { return false }
	if (alphabetic_line(a) || a == 'NU') && b == 'OP' && !east_asian(points[i]) { return false }
	if a == 'CP' && !east_asian(points[i - 1]) && (alphabetic_line(b) || b == 'NU') { return false }
	if a == 'RI' && b == 'RI' {
		mut count := 0
		for t := i - 1; t >= 0 && classes[t] == 'RI'; t-- {
			if raw[t] !in ['CM', 'ZWJ'] { count++ }
		}
		if count % 2 == 1 { return false }
	}
	if (a == 'EB' || (category(points[i - 1]) == 0 && property_named(points[i - 1], 'Extended_Pictographic'))) && b == 'EM' {
		return false
	}
	return true
}

// Returned offsets include both endpoints, in UTF-16 units.
pub fn line_boundaries(points []u32, mode int) []int {
	mut result := [0]
	if points.len == 0 { return result }
	mut raw := []string{cap: points.len}
	mut classes := []string{cap: points.len}
	for p in points {
		c := resolved_line_class(p, mode)
		raw << c
		classes << if c in ['CM', 'ZWJ'] {
			if classes.len > 0 && classes.last() !in ['BK', 'CR', 'LF', 'NL', 'SP', 'ZW'] {
				classes.last()
			} else {
				'AL'
			}
		} else {
			c
		}
	}
	mut effective_points := []u32{}
	mut effective_classes := []string{}
	mut effective_raw := []string{}
	mut offsets := []int{}
	mut preceding_zwj := []bool{}
	mut offset := 0
	for i, p in points {
		inherited := raw[i] in ['CM', 'ZWJ'] && i > 0 && classes[i - 1] !in ['BK', 'CR', 'LF',
			'NL', 'SP', 'ZW']
		if !inherited {
			effective_points << p
			effective_classes << classes[i]
			effective_raw << raw[i]
			offsets << offset
			preceding_zwj << (i > 0 && raw[i - 1] == 'ZWJ')
		}
		offset += if p > 0xffff { 2 } else { 1 }
	}
	for i in 1 .. effective_points.len {
		if !preceding_zwj[i] && line_allows(effective_points, effective_classes, effective_raw, i) {
			result << offsets[i]
		}
	}
	result << offset
	return result
}
