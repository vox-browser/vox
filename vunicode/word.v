// Unicode 17 UAX #29 default word boundaries (code-point indices).
module vunicode

fn word_ignored(c string) bool { return c in ['Extend', 'Format', 'ZWJ'] }

fn word_letter(c string) bool { return c in ['ALetter', 'Hebrew_Letter'] }

fn word_midletter(c string) bool { return c in ['MidLetter', 'MidNumLet', 'Single_Quote'] }

fn word_midnumber(c string) bool { return c in ['MidNum', 'MidNumLet', 'Single_Quote'] }

fn word_boundary_at(points []u32, classes []string, i int) bool {
	a0 := classes[i - 1]
	b := classes[i]
	if a0 == 'CR' && b == 'LF' { return false }
	if a0 in ['CR', 'LF', 'Newline'] || b in ['CR', 'LF', 'Newline'] { return true }
	if a0 == 'ZWJ' && property_named(points[i], 'Extended_Pictographic') { return false }
	if a0 == 'WSegSpace' && b == 'WSegSpace' { return false }
	if word_ignored(b) { return false }
	mut left := i - 1
	for left >= 0 && word_ignored(classes[left]) { left-- }
	if left < 0 { return true }
	a := classes[left]
	mut before := left - 1
	for before >= 0 && word_ignored(classes[before]) { before-- }
	mut after := i + 1
	for after < classes.len && word_ignored(classes[after]) { after++ }
	prev := if before >= 0 { classes[before] } else { '' }
	next := if after < classes.len { classes[after] } else { '' }
	if word_letter(a) && word_letter(b) { return false }
	if word_letter(a) && word_midletter(b) && word_letter(next) { return false }
	if word_letter(prev) && word_midletter(a) && word_letter(b) { return false }
	if a == 'Hebrew_Letter' && b == 'Single_Quote' { return false }
	if a == 'Hebrew_Letter' && b == 'Double_Quote' && next == 'Hebrew_Letter' { return false }
	if prev == 'Hebrew_Letter' && a == 'Double_Quote' && b == 'Hebrew_Letter' { return false }
	if a == 'Numeric' && b == 'Numeric' { return false }
	if (word_letter(a) && b == 'Numeric') || (a == 'Numeric' && word_letter(b)) { return false }
	if prev == 'Numeric' && word_midnumber(a) && b == 'Numeric' { return false }
	if a == 'Numeric' && word_midnumber(b) && next == 'Numeric' { return false }
	if a == 'Katakana' && b == 'Katakana' { return false }
	if a in ['ALetter', 'Hebrew_Letter', 'Numeric', 'Katakana', 'ExtendNumLet'] && b == 'ExtendNumLet' {
		return false
	}
	if a == 'ExtendNumLet' && b in ['ALetter', 'Hebrew_Letter', 'Numeric', 'Katakana'] {
		return false
	}
	if a == 'Regional_Indicator' && b == 'Regional_Indicator' {
		mut count := 0
		for j := left; j >= 0; j-- {
			if word_ignored(classes[j]) { continue }
			if classes[j] != 'Regional_Indicator' { break }
			count++
		}
		if count % 2 == 1 { return false }
	}
	return true
}

pub fn word_boundaries(points []u32) []int {
	mut result := [0]
	if points.len == 0 { return result }
	classes := points.map(word_class(it))
	for i in 1 .. points.len { if word_boundary_at(points, classes, i) { result << i } }
	result << points.len
	return result
}
