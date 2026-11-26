// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct IntlDatePatternToken {
	literal string
	field u8
	count int
}

fn intl_parse_date_pattern(mut vm VM, text string) ![]IntlDatePatternToken {
	mut tokens := []IntlDatePatternToken{}
	mut literal := ''
	mut quoted := false
	mut index := 0
	for index < text.len {
		unit := text[index]
		if unit == `'` {
			if index + 1 < text.len && text[index + 1] == `'` { literal += "'"; index += 2; continue }
			quoted = !quoted; index++; continue
		}
		if !quoted && ((unit >= `a` && unit <= `z`) || (unit >= `A` && unit <= `Z`)) {
			if literal != '' { tokens << IntlDatePatternToken{literal: literal}; literal = '' }
			start := index
			for index < text.len && text[index] == unit { index++ }
			tokens << IntlDatePatternToken{field: unit, count: index - start}
		} else { literal += text[index..index + 1]; index++ }
	}
	if quoted { return vm.throw_error(.internal_error, 'Invalid quoted CLDR date pattern') }
	if literal != '' { tokens << IntlDatePatternToken{literal: literal} }
	return tokens
}

fn intl_date_token_name(token IntlDatePatternToken) string {
	return match token.field {
		`G` { 'era' } `y` { 'year' } `M`, `L` { 'month' } `d` { 'day' }
		`E`, `e`, `c` { 'weekday' } `a`, `b`, `B` { 'dayPeriod' }
		`h`, `H`, `K`, `k` { 'hour' } `m` { 'minute' } `s` { 'second' }
		`S` { 'fractionalSecondDigits' } `z`, `v`, `O`, `V`, `Z`, `X`, `x` { 'timeZoneName' }
		else { '' }
	}
}

fn intl_date_token_style(token IntlDatePatternToken) string {
	if token.field == `S` { return token.count.str() }
	if token.field in [`y`, `d`, `h`, `H`, `K`, `k`, `m`, `s`] { return if token.count == 2 { '2-digit' } else { 'numeric' } }
	if token.field in [`M`, `L`] && token.count <= 2 { return if token.count == 2 { '2-digit' } else { 'numeric' } }
	if token.field in [`z`, `v`, `O`, `V`, `Z`, `X`, `x`] {
		if token.field == `O` { return if token.count >= 4 { 'longOffset' } else { 'shortOffset' } }
		if token.field == `v` || token.field == `V` { return if token.count >= 4 { 'longGeneric' } else { 'shortGeneric' } }
		return if token.count >= 4 { 'long' } else { 'short' }
	}
	return if token.count >= 5 { 'narrow' } else if token.count == 4 { 'long' } else { 'short' }
}

fn intl_date_pattern_fields(tokens []IntlDatePatternToken) (map[string]string, bool) {
	mut fields := map[string]string{}
	for token in tokens {
		// AM/PM is inherent in 12-hour patterns; only flexible B is the
		// optional ECMA-402 dayPeriod field exposed by resolvedOptions.
		if token.field in [u8(0), `a`, `b`] { continue }
		name := intl_date_token_name(token)
		if name == '' { return fields, false }
		fields[name] = intl_date_token_style(token)
	}
	return fields, true
}

fn intl_date_field_width(style string) int {
	return match style { '2-digit' { 2 } 'short' { 3 } 'long' { 4 } 'narrow' { 5 } else { 1 } }
}

fn intl_hour_field(cycle string) u8 {
	return match cycle { 'h11' { `K` } 'h12' { `h` } 'h24' { `k` } else { `H` } }
}

// ECMA-402 BasicFormatMatcher penalties. Best-fit currently uses this same
// deterministic matching policy over pinned CLDR patterns, without host calls.
fn intl_date_match_score(wanted map[string]string, actual map[string]string) int {
	mut score := 0
	for name, desired in wanted {
		candidate := actual[name] or { score += 120; continue }
		if candidate == desired { continue }
		if name == 'timeZoneName' {
			if desired.starts_with('short') && candidate.starts_with('long') { score += 3 }
			else if desired.starts_with('long') && candidate.starts_with('short') { score += 8 }
			if desired.contains('Offset') != candidate.contains('Offset') { score += 1 }
			continue
		}
		widths := ['2-digit', 'numeric', 'narrow', 'short', 'long']
		wanted_at := widths.index(desired); actual_at := widths.index(candidate)
		if wanted_at < 0 || actual_at < 0 { score += 20; continue }
		delta := actual_at - wanted_at
		score += if delta <= -2 { 8 } else if delta == -1 { 6 } else if delta == 1 { 3 } else { 6 }
	}
	for name in actual.keys() {
		if name !in wanted && !(name == 'dayPeriod' && 'hour' in wanted) { score += 20 }
	}
	return score
}

fn intl_best_date_pattern(mut vm VM, data &IntlDateLocaleData, wanted map[string]string, hour_cycle string) ![]IntlDatePatternToken {
	if wanted.len == 0 { return []IntlDatePatternToken{} }
	if wanted.len == 1 && 'dayPeriod' in wanted { return [IntlDatePatternToken{field: `B`, count: intl_date_field_width(wanted['dayPeriod'])}] }
	if wanted.len == 1 && 'fractionalSecondDigits' in wanted { return [IntlDatePatternToken{field: `S`, count: wanted['fractionalSecondDigits'].int()}] }
	mut candidates := data.available.clone()
	for name, pattern in data.date_formats { candidates['date:' + name] = pattern }
	for name, pattern in data.time_formats { candidates['time:' + name] = pattern }
	mut names := candidates.keys(); names.sort()
	mut best := []IntlDatePatternToken{}
	mut best_score := int(1_000_000)
	for name in names {
		vm.consume_execution_budget()!
		if name.contains('-alt-') { continue }
		tokens := intl_parse_date_pattern(mut vm, candidates[name])!
		actual, valid := intl_date_pattern_fields(tokens)
		if !valid { continue }
		mut score := intl_date_match_score(wanted, actual)
		for token in tokens {
			if token.field in [`b`, `B`] && 'dayPeriod' !in wanted { score += 20 }
			if intl_date_token_name(token) == 'hour' && 'hour' in wanted {
				if (token.field in [`h`, `K`]) != (hour_cycle in ['h11', 'h12']) { score += 1000 }
			}
		}
		if score < best_score { best = tokens.clone(); best_score = score }
	}
	if best.len == 0 { return vm.throw_error(.internal_error, 'No supported CLDR date pattern') }
	mut adjusted := []IntlDatePatternToken{}
	for token in best {
		name := intl_date_token_name(token)
		mut field := token.field
		mut count := token.count
		if requested := wanted[name] {
			if name == 'hour' {
				field = intl_hour_field(hour_cycle)
				if requested == '2-digit' { count = 2 }
			} else if name in ['minute', 'second'] {
				if requested == '2-digit' { count = 2 }
			} else if name in ['day', 'month'] && requested == 'numeric' && token.count <= 2 {
				// Numeric requests retain locale-mandated leading zeroes.
				count = token.count
			} else if name == 'timeZoneName' {
				field = if requested.ends_with('Offset') { `O` } else if requested.ends_with('Generic') { `v` } else { `z` }
				count = if requested.starts_with('long') { 4 } else { 1 }
			} else { count = intl_date_field_width(requested) }
		}
		adjusted << IntlDatePatternToken{field: field, count: count, literal: token.literal}
	}
	return adjusted
}

fn intl_combine_date_patterns(mut vm VM, date []IntlDatePatternToken, clock []IntlDatePatternToken, combination string) ![]IntlDatePatternToken {
	if date.len == 0 { return clock }
	if clock.len == 0 { return date }
	// Parse the surrounding literals too: CLDR combinations may quote words.
	mut result := []IntlDatePatternToken{}
	mut index := 0
	mut start := 0
	for index + 2 < combination.len {
		if combination[index..index + 3] in ['{0}', '{1}'] {
			result << intl_parse_date_pattern(mut vm, combination[start..index])!
			if combination[index + 1] == `0` { result << clock } else { result << date }
			index += 3; start = index
		} else { index++ }
	}
	result << intl_parse_date_pattern(mut vm, combination[start..])!
	return result
}
