// SPDX-License-Identifier: BSD-2-Clause
module libjs

// CLDR plural operands use the rounded decimal including its visible trailing
// zeroes. Integer relation/modulo operations never narrow large values to f64.
fn intl_plural_operand(number string, operand string, exponent int) (string, bool) {
	pieces := number.split('.')
	integer := pieces[0]
	fraction := if pieces.len > 1 { pieces[1] } else { '' }
	trimmed := fraction.trim_right('0')
	match operand {
		'n' { return integer, fraction.trim('0') == '' }
		'i' { return integer, true }
		'v' { return fraction.len.str(), true }
		'w' { return trimmed.len.str(), true }
		'f' { return (if fraction == '' { '0' } else { fraction }), true }
		't' { return (if trimmed == '' { '0' } else { trimmed }), true }
		'c', 'e' { return exponent.str(), true }
		else { return '0', true }
	}
}

fn intl_plural_integer_compare(left string, right string) int {
	mut a := left.trim_left('0'); if a == '' { a = '0' }
	mut b := right.trim_left('0'); if b == '' { b = '0' }
	if a.len != b.len { return if a.len < b.len { -1 } else { 1 } }
	return if a == b { 0 } else if a < b { -1 } else { 1 }
}

fn intl_plural_relation(number string, relation string, exponent int) bool {
	words := relation.split(' ').filter(it != '')
	if words.len < 3 { return false }
	mut cursor := 1
	mut integer, integral := intl_plural_operand(number, words[0], exponent)
	if words[cursor] == '%' {
		if words.len < 5 { return false }
		_, remainder := intl_decimal_divide(integer, words[cursor + 1].int())
		integer = remainder.str(); cursor += 2
	}
	negate := words[cursor] == '!='
	cursor++
	mut matches := false
	if integral {
		for range_ in words[cursor..].join('').split(',') {
			ends := range_.split('..')
			if ends.len == 1 { matches = matches || intl_plural_integer_compare(integer, ends[0]) == 0 }
			else { matches = matches || (intl_plural_integer_compare(integer, ends[0]) >= 0 && intl_plural_integer_compare(integer, ends[1]) <= 0) }
		}
	}
	return if negate { !matches } else { matches }
}

fn intl_plural_category(mut vm VM, locale string, number string, exponent int, ordinal bool) !string {
	core := intl_core_data(mut vm)!
	mut candidate := locale
	for {
		rules := if ordinal { core.ordinal_rules[candidate] or { map[string]string{} } } else { core.cardinal_rules[candidate] or { map[string]string{} } }
		if rules.len > 0 {
			for category in ['zero', 'one', 'two', 'few', 'many'] {
				if rule := rules[category] {
					for alternative in rule.split(' or ') {
						mut matches := true
						for relation in alternative.split(' and ') { matches = matches && intl_plural_relation(number, relation, exponent) }
						if matches { return category }
					}
				}
			}
			return 'other'
		}
		if dash := candidate.last_index('-') { candidate = candidate[..dash] } else { return 'other' }
	}
}
