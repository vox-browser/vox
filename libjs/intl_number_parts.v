// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn intl_number_symbols(data &IntlDateLocaleData, system string) map[string]string {
	return (data.number_symbols[system] or { data.number_symbols['latn'] or { map[string]string{} } }).clone()
}

fn intl_number_pattern(data &IntlDateLocaleData, system string, style string, name string) string {
	return data.number_patterns[system + ':' + style + ':' + name] or { data.number_patterns['latn:' + style + ':' + name] or { '#,##0.###' } }
}

fn intl_number_literal_parts(text string, type_ string) []IntlNumberPart {
	if text == '' { return []IntlNumberPart{} }
	if type_ == 'literal' { return [IntlNumberPart{type_: type_, value: text}] }
	points := text.runes()
	mut start := 0; mut end := points.len
	for start < end && is_number_whitespace(u16(points[start])) { start++ }
	for end > start && is_number_whitespace(u16(points[end - 1])) { end-- }
	mut parts := []IntlNumberPart{}
	if start > 0 { parts << IntlNumberPart{type_: 'literal', value: points[..start].string()} }
	if start < end { parts << IntlNumberPart{type_: type_, value: points[start..end].string()} }
	if end < points.len { parts << IntlNumberPart{type_: 'literal', value: points[end..].string()} }
	return parts
}

// Parse CLDR quoting and the numeric skeleton, retaining bidi controls and
// quoted punctuation. Number skeleton widths are handled by the digit options.
fn intl_partition_number_pattern(pattern string, number []IntlNumberPart, symbols map[string]string, currency string, literal_type string) []IntlNumberPart {
	points := pattern.runes()
	mut output := []IntlNumberPart{}
	mut literal := ''
	mut quoted := false
	mut emitted := false
	mut cursor := 0
	for cursor < points.len {
		point := points[cursor]
		if point == `'` {
			if cursor + 1 < points.len && points[cursor + 1] == `'` { literal += "'"; cursor += 2; continue }
			quoted = !quoted; cursor++; continue
		}
		if !quoted && point in [`#`, `0`, `@`, `.`, `,`] {
			output << intl_number_literal_parts(literal, literal_type); literal = ''
			if !emitted { output << number; emitted = true }
			cursor++; continue
		}
		if !quoted && point in [rune(0xa4), `%`, `-`, `+`] {
			output << intl_number_literal_parts(literal, literal_type); literal = ''
			kind := match point { rune(0xa4) { 'currency' } `%` { 'percentSign' } `-` { 'minusSign' } else { 'plusSign' } }
			output << IntlNumberPart{type_: kind, value: if kind == 'currency' { currency } else { symbols[kind] or { point.str() } }}
			if point == rune(0xa4) { for cursor + 1 < points.len && points[cursor + 1] == point { cursor++ } }
		} else { literal += point.str() }
		cursor++
	}
	output << intl_number_literal_parts(literal, literal_type)
	return output
}

fn intl_number_group_sizes(pattern string) (int, int) {
	mut skeleton := ''
	mut quoted := false
	for point in pattern.runes() {
		if point == `'` { quoted = !quoted; continue }
		if quoted { continue }
		if point == `.` || point == `;` { break }
		if point in [`0`, `#`, `,`] { skeleton += point.str() }
	}
	groups := skeleton.split(',')
	if groups.len < 2 { return 0, 0 }
	primary := groups.last().len
	return primary, if groups.len >= 3 { groups[groups.len - 2].len } else { primary }
}

fn intl_number_numeric_parts(mut vm VM, data &IntlDateLocaleData, formatter &IntlNumberFormat, text string) ![]IntlNumberPart {
	core := intl_core_data(mut vm)!
	symbols := intl_number_symbols(data, formatter.numbering_system)
	fields := text.split('.')
	integer := fields[0]
	primary, secondary := intl_number_group_sizes(intl_number_pattern(data, formatter.numbering_system, 'decimal', 'standard'))
	minimum_grouping := if formatter.grouping == 'min2' { 2 } else if formatter.grouping == 'always' { 1 } else { data.minimum_grouping.int() }
	mut groups := []string{}
	if formatter.grouping != 'false' && primary > 0 && secondary > 0 && integer.len >= primary + minimum_grouping {
		mut end := integer.len
		mut width := primary
		for end > width { groups << integer[end - width..end]; end -= width; width = secondary; vm.consume_execution_budget()! }
		groups << integer[..end]; groups.reverse_in_place()
	} else { groups << integer }
	group := if formatter.style == 'currency' { symbols['currencyGroup'] or { symbols['group'] or { ',' } } } else { symbols['group'] or { ',' } }
	decimal := if formatter.style == 'currency' { symbols['currencyDecimal'] or { symbols['decimal'] or { '.' } } } else { symbols['decimal'] or { '.' } }
	mut output := []IntlNumberPart{}
	for index, digits in groups {
		if index != 0 { output << IntlNumberPart{type_: 'group', value: group} }
		output << IntlNumberPart{type_: 'integer', value: intl_localize_digits(core, formatter.numbering_system, digits)}
	}
	if fields.len > 1 {
		output << IntlNumberPart{type_: 'decimal', value: decimal}
		output << IntlNumberPart{type_: 'fraction', value: intl_localize_digits(core, formatter.numbering_system, fields[1])}
	}
	return output
}

fn intl_number_compact_pattern(data &IntlDateLocaleData, formatter &IntlNumberFormat, magnitude int, plural string) (int, string) {
	kind := if formatter.style == 'currency' && formatter.currency_display != 'name' { 'currency' } else { 'decimal' }
	width := if kind == 'currency' { 'short' } else { formatter.compact_display }
	patterns := (data.number_compact[formatter.numbering_system + ':' + kind + ':' + width] or { data.number_compact['latn:' + kind + ':' + width] or { map[string]string{} } }).clone()
	mut selected := -1
	for key in patterns.keys() {
		power := key.all_before('-count-').len - 1
		if power <= magnitude && power > selected { selected = power }
	}
	if selected < 0 { return 0, '0' }
	key := '1' + '0'.repeat(selected) + '-count-'
	pattern := patterns[key + plural] or { patterns[key + 'other'] or { '0' } }
	if pattern == '0' { return 0, pattern }
	mut zeroes := 0
	mut quoted := false
	for point in pattern.runes() { if point == `'` { quoted = !quoted } else if !quoted && point == `0` { zeroes++ } }
	return selected - zeroes + 1, pattern
}

fn intl_number_currency_name(data &IntlDateLocaleData, formatter &IntlNumberFormat, plural string) string {
	info := (data.number_currencies[formatter.currency] or { map[string]string{} }).clone()
	return match formatter.currency_display {
		'code' { formatter.currency }
		'name' { info['displayName-count-' + plural] or { info['displayName'] or { formatter.currency } } }
		'narrowSymbol' { info['symbol-alt-narrow'] or { info['symbol'] or { formatter.currency } } }
		else { info['symbol'] or { formatter.currency } }
	}
}

// A {0} placeholder inserts already partitioned numeric text. Outer text is
// split into literal spacing and a semantic unit/currency part.
fn intl_number_unit_pattern(pattern string, number []IntlNumberPart, name string, type_ string) []IntlNumberPart {
	mut output := []IntlNumberPart{}
	mut cursor := 0
	mut literal := ''
	for cursor < pattern.len {
		if pattern[cursor..].starts_with('{0}') {
			output << intl_number_literal_parts(literal, type_); literal = ''; output << number; cursor += 3
		} else if pattern[cursor..].starts_with('{1}') {
			output << intl_number_literal_parts(literal, type_); literal = ''; output << IntlNumberPart{type_: type_, value: name}; cursor += 3
		} else { literal += pattern[cursor..cursor + 1]; cursor++ }
	}
	output << intl_number_literal_parts(literal, type_)
	return output
}

fn intl_number_unit_parts(data &IntlDateLocaleData, formatter &IntlNumberFormat, plural string, number []IntlNumberPart) []IntlNumberPart {
	pieces := formatter.unit.split('-per-')
	info := (data.number_units[formatter.unit_display + ':' + pieces[0]] or { map[string]string{} }).clone()
	pattern := info['unitPattern-count-' + plural] or { info['unitPattern-count-other'] or { '{0} ' + pieces[0] } }
	mut output := intl_number_unit_pattern(pattern, number, '', 'unit')
	if pieces.len == 2 {
		denominator := (data.number_units[formatter.unit_display + ':' + pieces[1]] or { map[string]string{} }).clone()
		if per := denominator['perUnitPattern'] { return intl_number_unit_pattern(per, output, '', 'unit') }
		name := (denominator['unitPattern-count-one'] or { denominator['unitPattern-count-other'] or { pieces[1] } }).replace('{0}', '').trim_space()
		output = intl_number_unit_pattern(data.number_per[formatter.unit_display] or { '{0}/{1}' }, output, name, 'unit')
	}
	return output
}

fn intl_format_number_parts(mut vm VM, formatter &IntlNumberFormat, value IntlDecimal) ![]IntlNumberPart {
	data := intl_date_locale_data(mut vm, formatter.data_locale)!
	core := intl_core_data(mut vm)!
	symbols := intl_number_symbols(data, formatter.numbering_system)
	mut scaled := IntlDecimal{...value, exponent: value.exponent + if formatter.style == 'percent' { 2 } else { 0 }}
	mut exponent := 0
	mut compact_pattern := '0'
	mut numeric := []IntlNumberPart{}
	mut plural := 'other'
	mut zero := false
	if value.special != '' {
		kind := if value.special == 'nan' { 'nan' } else { 'infinity' }
		numeric << IntlNumberPart{type_: kind, value: symbols[kind] or { if kind == 'nan' { 'NaN' } else { '∞' } }}
	} else {
		if formatter.notation in ['scientific', 'engineering'] {
			magnitude := scaled.magnitude()
			exponent = if formatter.notation == 'scientific' { magnitude } else { magnitude - (magnitude % 3 + 3) % 3 }
		} else if formatter.notation == 'compact' { exponent, compact_pattern = intl_number_compact_pattern(data, formatter, scaled.magnitude(), 'other') }
		mut rounded := intl_round_number(mut vm, IntlDecimal{...scaled, exponent: scaled.exponent - exponent}, formatter.digits)!
		if formatter.notation != 'standard' && rounded.decimal.digits.trim('0') != '' {
			new_magnitude := rounded.decimal.magnitude() + exponent
			if formatter.notation == 'compact' {
				new_exponent, new_pattern := intl_number_compact_pattern(data, formatter, new_magnitude, 'other')
				if new_exponent != exponent { exponent = new_exponent; compact_pattern = new_pattern; rounded = intl_round_number(mut vm, IntlDecimal{...scaled, exponent: scaled.exponent - exponent}, formatter.digits)! }
			} else {
				new_exponent := if formatter.notation == 'scientific' { new_magnitude } else { new_magnitude - (new_magnitude % 3 + 3) % 3 }
				if new_exponent != exponent { exponent = new_exponent; rounded = intl_round_number(mut vm, IntlDecimal{...scaled, exponent: scaled.exponent - exponent}, formatter.digits)! }
			}
		}
		zero = rounded.decimal.digits.trim('0') == ''
		plural = intl_plural_category(mut vm, formatter.data_locale, rounded.text, if formatter.notation == 'compact' { exponent } else { 0 }, false)!
		numeric = intl_number_numeric_parts(mut vm, data, formatter, rounded.text)!
		if formatter.notation == 'compact' {
			_, compact_pattern = intl_number_compact_pattern(data, formatter, rounded.decimal.magnitude() + exponent, plural)
			// For currency compact notation the CLDR pattern supplies ¤ itself.
			numeric = intl_partition_number_pattern(compact_pattern, numeric, symbols, intl_number_currency_name(data, formatter, plural), 'compact')
		} else if formatter.notation in ['scientific', 'engineering'] {
			numeric << IntlNumberPart{type_: 'exponentSeparator', value: symbols['exponential'] or { 'E' }}
			if exponent < 0 { numeric << IntlNumberPart{type_: 'exponentMinusSign', value: symbols['minusSign'] or { '-' }} }
			numeric << IntlNumberPart{type_: 'exponentInteger', value: intl_localize_digits(core, formatter.numbering_system, (if exponent < 0 { -exponent } else { exponent }).str())}
		}
	}
	show_minus := value.negative && formatter.sign_display != 'never' && (!(formatter.sign_display in ['negative', 'exceptZero']) || !zero)
	show_plus := !show_minus && (formatter.sign_display == 'always' || (formatter.sign_display == 'exceptZero' && !zero))
	mut kind := if formatter.style in ['currency', 'percent'] { formatter.style } else { 'decimal' }
	mut pattern := intl_number_pattern(data, formatter.numbering_system, kind, if formatter.style == 'currency' { formatter.currency_sign } else { 'standard' })
	currency := intl_number_currency_name(data, formatter, plural)
	if formatter.style == 'currency' && formatter.currency_display == 'name' {
		kind = 'decimal'; pattern = intl_number_pattern(data, formatter.numbering_system, 'decimal', 'standard')
	} else if formatter.style == 'currency' && currency.bytes().any((it >= `A` && it <= `Z`) || (it >= `a` && it <= `z`)) {
		// CLDR's alphaNextToNumber variant provides the required currency
		// boundary spacing for codes/letter symbols adjacent to a number.
		key := formatter.numbering_system + ':currency:' + formatter.currency_sign + '-alphaNextToNumber'
		if variant := data.number_patterns[key] { pattern = variant }
	}
	if formatter.notation == 'compact' && compact_pattern.contains('¤') && value.special == '' { pattern = '0' }
	// Select explicit negative accounting patterns only when a minus sign is
	// displayed. Otherwise use the positive pattern, including for -0.
	patterns := pattern.split(';')
	pattern = patterns[0]
	if show_minus {
		pattern = if patterns.len > 1 { patterns[1] } else { '-' + pattern }
	} else if show_plus { pattern = '+' + pattern }
	mut output := intl_partition_number_pattern(pattern, numeric, symbols, currency, 'literal')
	if formatter.style == 'unit' { output = intl_number_unit_parts(data, formatter, plural, output) }
	if formatter.style == 'currency' && formatter.currency_display == 'name' {
		unit_pattern := data.number_patterns[formatter.numbering_system + ':currency:unitPattern-count-' + plural] or { data.number_patterns[formatter.numbering_system + ':currency:unitPattern-count-other'] or { data.number_patterns['latn:currency:unitPattern-count-other'] or { '{0} {1}' } } }
		output = intl_number_unit_pattern(unit_pattern, output, currency, 'currency')
	}
	return output
}
