module url

import vunicode
import encoding.punycode
import encoding.utf8

// https://url.spec.whatwg.org/#concept-domain-to-ascii
pub fn domain_to_ascii(domain string, be_strict bool) ?string {
	// Preserve LibURL's ASCII fast path. xn-- labels still take the Unicode path
	// so invalid Punycode is rejected.
	if !be_strict && domain.is_ascii() {
		if domain == '' {
			return none
		}
		mut needs_idna := false
		for index in 0 .. domain.len {
			if index != 0 && domain[index - 1] != `.` {
				continue
			}
			if domain.len - index >= 4 && (domain[index] == `x` || domain[index] == `X`)
				&& (domain[index + 1] == `n` || domain[index + 1] == `N`)
				&& domain[index + 2] == `-` && domain[index + 3] == `-` {
				needs_idna = true
				break
			}
		}
		if !needs_idna {
			return domain.to_lower()
		}
	}
	return idna_to_ascii(domain, be_strict)
}

fn idna_to_ascii(domain string, strict bool) ?string {
	if !utf8.validate_str(domain) { return none }
	mapped := vunicode.idna_map(domain.runes().map(u32(it)), strict)?
	text := mapped.map(rune(it)).string()
	labels := text.split('.')
	mut decoded := [][]u32{cap: labels.len}
	mut bidi := false
	for label in labels {
		mut points := label.runes().map(u32(it))
		if label.starts_with('xn--') {
			unicode_label := punycode.decode(label[4..]) or { return none }
			points = unicode_label.runes().map(u32(it))
			if points.len == 0 || points.all(it < 128) { return none }
			encoded := punycode.encode(unicode_label) or { return none }
			if encoded != label[4..] { return none }
		}
		if points.any(vunicode.bidi_class(it) in [u32(1), 13, 5]) { bidi = true }
		decoded << points
	}
	mut result := []string{cap: labels.len}
	for i, points in decoded {
		// An optional root dot is excluded from label length validation.
		if !strict && i == labels.len - 1 && points.len == 0 && i > 0 {
			result << ''
			continue
		}
		if !vunicode.idna_valid_label(points, strict, bidi) { return none }
		label := points.map(rune(it)).string()
		ascii_label := if points.all(it < 128) {
			label
		} else {
			encoded := punycode.encode(label) or { return none }
			'xn--' + encoded
		}
		if strict && (ascii_label.len == 0 || ascii_label.len > 63) { return none }
		result << ascii_label
	}
	ascii_domain := result.join('.')
	if ascii_domain == '' { return none }
	length := ascii_domain.len - if ascii_domain.ends_with('.') { 1 } else { 0 }
	if strict && length > 253 { return none }
	return ascii_domain
}
