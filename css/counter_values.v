module css

import dom

// Translated from:
// - Libraries/LibWeb/CSS/CounterStyle.cpp
// - Libraries/LibWeb/CSS/CounterStyle.h
// - Libraries/LibWeb/CSS/CounterStyleDefinition.cpp
// - Libraries/LibWeb/CSS/CounterStyleDefinition.h
// - Libraries/LibWeb/CSS/CountersSet.cpp
// - Libraries/LibWeb/CSS/CountersSet.h
// - Libraries/LibWeb/CSS/StyleValues/CounterDefinitionsStyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/CounterStyleStyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/CounterStyleSystemStyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/CounterStyleValue.cpp/.h

const counter_i64_min = i64(-9223372036854775807 - 1)
const counter_i64_max = i64(9223372036854775807)
const counter_i32_min = i32(-2147483647 - 1)
const counter_i32_max = i32(2147483647)

// --- CounterStyleDefinition ---

pub struct CounterStyleRangeEntry {
pub mut:
	start i64
	end   i64
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-symbols
// <symbol> = <string> | <image> | <custom-ident>
// Note: The <image> syntax in <symbol> is currently at-risk. No implementations have plans to implement it currently,
//       and it complicates some usages of counter() in ways that haven’t been fully handled.
// FIXME: Given the above note we don't currently support <image> here - we may need to revisit this if other browsers
//        implement it.

pub struct CounterStyleNegativeSign {
pub mut:
	prefix string
	suffix string
}

pub struct CounterStylePad {
pub mut:
	minimum_length i32
	symbol         string
}

pub struct AdditiveCounterStyleTuple {
pub mut:
	weight i32
	symbol string
}

pub struct AdditiveCounterStyleAlgorithm {
pub mut:
	symbol_list []AdditiveCounterStyleTuple
}

pub struct FixedCounterStyleAlgorithm {
pub mut:
	first_symbol i64
	symbol_list  []string
}

pub enum CounterStyleSystem {
	cyclic
	numeric
	alphabetic
	symbolic
	additive
}

pub fn counter_style_system_to_string(system CounterStyleSystem) string {
	return match system {
		.cyclic { 'cyclic' }
		.numeric { 'numeric' }
		.alphabetic { 'alphabetic' }
		.symbolic { 'symbolic' }
		.additive { 'additive' }
	}
}

pub struct GenericCounterStyleAlgorithm {
pub mut:
	type_       CounterStyleSystem
	symbol_list []string
}

pub struct EthiopicNumericCounterStyleAlgorithm {}

pub enum ExtendedCJKCounterStyleAlgorithmType {
	simp_chinese_informal
	simp_chinese_formal
	trad_chinese_informal
	trad_chinese_formal
	japanese_informal
	japanese_formal
	korean_hangul_formal
	korean_hanja_informal
	korean_hanja_formal
}

pub struct ExtendedCJKCounterStyleAlgorithm {
pub mut:
	type_ ExtendedCJKCounterStyleAlgorithmType
}

pub type CounterStyleAlgorithm = AdditiveCounterStyleAlgorithm
	| EthiopicNumericCounterStyleAlgorithm
	| ExtendedCJKCounterStyleAlgorithm
	| FixedCounterStyleAlgorithm
	| GenericCounterStyleAlgorithm

pub struct CounterStyleSystemExtends {
pub mut:
	name string
}

pub type CounterStyleAlgorithmOrExtends = CounterStyleAlgorithm | CounterStyleSystemExtends

pub struct AutoRange {}

pub struct CounterStyleRangeOmitted {}

pub struct CounterStyleRangeEntries {
pub mut:
	entries []CounterStyleRangeEntry
}

pub type CounterStyleDefinitionRange = AutoRange
	| CounterStyleRangeEntries
	| CounterStyleRangeOmitted

// https://drafts.csswg.org/css-counter-styles-3/#valdef-counter-style-range-auto
pub fn AutoRange.resolve(algorithm CounterStyleAlgorithm) []CounterStyleRangeEntry {
	// The range depends on the counter system:
	return match algorithm {
		AdditiveCounterStyleAlgorithm {
			// For additive systems, the range is 0 to positive infinity.
			[CounterStyleRangeEntry{0, counter_i64_max}]
		}
		FixedCounterStyleAlgorithm {
			// For cyclic, numeric, and fixed systems, the range is negative infinity to positive infinity.
			// NB: cyclic and numeric are handled below.
			[CounterStyleRangeEntry{counter_i64_min, counter_i64_max}]
		}
		GenericCounterStyleAlgorithm {
			match algorithm.type_ {
				.cyclic, .numeric {
					// For cyclic, numeric, and fixed systems, the range is negative infinity to positive infinity.
					// NB: Fixed is handled above.
					[CounterStyleRangeEntry{counter_i64_min, counter_i64_max}]
				}
				.alphabetic, .symbolic {
					// For alphabetic and symbolic systems, the range is 1 to positive infinity.
					[CounterStyleRangeEntry{1, counter_i64_max}]
				}
				.additive {
					// NB: Additive is handled above.
					panic('VERIFY_NOT_REACHED')
				}
			}
		}
		EthiopicNumericCounterStyleAlgorithm {
			// NB: All complex predefined counter styles define their range explicitly (i.e. not via auto)
			panic('VERIFY_NOT_REACHED')
		}
		ExtendedCJKCounterStyleAlgorithm {
			// NB: All complex predefined counter styles define their range explicitly (i.e. not via auto)
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub struct CounterStyleDefinition {
pub mut:
	name_          string
	algorithm_     CounterStyleAlgorithmOrExtends
	negative_sign_ ?CounterStyleNegativeSign
	prefix_        ?string
	suffix_        ?string
	range_         CounterStyleDefinitionRange = CounterStyleRangeOmitted{}
	fallback_      ?string
	pad_           ?CounterStylePad
}

pub fn CounterStyleDefinition.create(name string, algorithm CounterStyleAlgorithmOrExtends, negative_sign ?CounterStyleNegativeSign, prefix ?string, suffix ?string, range CounterStyleDefinitionRange, fallback ?string, pad ?CounterStylePad) CounterStyleDefinition {
	return CounterStyleDefinition{
		name_: name
		algorithm_: algorithm
		negative_sign_: negative_sign
		prefix_: prefix
		suffix_: suffix
		range_: range
		fallback_: fallback
		pad_: pad
	}
}

pub fn (definition CounterStyleDefinition) name() string {
	return definition.name_
}

pub fn (definition CounterStyleDefinition) algorithm() CounterStyleAlgorithmOrExtends {
	return definition.algorithm_
}

pub fn (mut definition CounterStyleDefinition) set_algorithm(algorithm CounterStyleAlgorithmOrExtends) {
	definition.algorithm_ = algorithm
}

pub fn (definition CounterStyleDefinition) negative_sign() ?CounterStyleNegativeSign {
	return definition.negative_sign_
}

pub fn (definition CounterStyleDefinition) prefix() ?string {
	return definition.prefix_
}

pub fn (definition CounterStyleDefinition) suffix() ?string {
	return definition.suffix_
}

pub fn (definition CounterStyleDefinition) range() CounterStyleDefinitionRange {
	return definition.range_
}

pub fn (definition CounterStyleDefinition) fallback() ?string {
	return definition.fallback_
}

pub fn (definition CounterStyleDefinition) pad() ?CounterStylePad {
	return definition.pad_
}

pub fn CounterStyleDefinition.from_counter_style_rule(rule &CSSCounterStyleRule, computation_context ComputationContext) ?CounterStyleDefinition {
	system_style_value := rule.system_style_value() or {
		CounterStyleSystemStyleValue.create(.symbolic)
	}

	maybe_algorithm := CounterStyleDefinition.resolve_algorithm(system_style_value, rule.symbols_style_value(), rule.additive_symbols_style_value(), computation_context) or {
		return none
	}

	negative_sign := if value := rule.negative_style_value() {
		?CounterStyleNegativeSign(CounterStyleDefinition.resolve_negative_sign(value))
	} else {
		?CounterStyleNegativeSign(none)
	}
	prefix := if value := rule.prefix_style_value() {
		?string(string_from_style_value(value))
	} else {
		?string(none)
	}
	suffix := if value := rule.suffix_style_value() {
		?string(string_from_style_value(value))
	} else {
		?string(none)
	}
	range := if value := rule.range_style_value() {
		CounterStyleDefinitionRange(CounterStyleDefinition.resolve_range(value, computation_context))
	} else {
		CounterStyleDefinitionRange(CounterStyleRangeOmitted{})
	}
	fallback := if value := rule.fallback_style_value() {
		?string(string_from_style_value(value))
	} else {
		?string(none)
	}
	pad := if value := rule.pad_style_value() {
		?CounterStylePad(CounterStyleDefinition.resolve_pad(value, computation_context))
	} else {
		?CounterStylePad(none)
	}

	return CounterStyleDefinition.create(rule.name(), maybe_algorithm, negative_sign, prefix, suffix, range, fallback, pad)
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-system
pub fn CounterStyleDefinition.resolve_algorithm(system_style_value CounterStyleSystemStyleValue, symbols_style_value ?CounterStyleSymbolListStyleValue, additive_symbols_style_value ?CounterStyleAdditiveSymbolsStyleValue, computation_context ComputationContext) ?CounterStyleAlgorithmOrExtends {
	// https://drafts.csswg.org/css-counter-styles-3/#counter-style-symbols
	// The @counter-style rule must have a valid symbols descriptor if the counter system is cyclic,
	// numeric, alphabetic, symbolic, or fixed, or a valid additive-symbols descriptor if the counter system
	// is additive; otherwise, the @counter-style does not define a counter style (but is still a valid
	// at-rule).
	value := system_style_value.value()
	return match value {
		CounterStyleSystem {
			match value {
				.cyclic, .alphabetic, .symbolic, .numeric {
					symbols := symbols_style_value or { return none }
					parsed_symbols := CounterStyleDefinition.resolve_symbols(symbols)
					if !system_style_value.is_valid_symbol_count(parsed_symbols.len) {
						return none
					}
					CounterStyleAlgorithmOrExtends(CounterStyleAlgorithm(GenericCounterStyleAlgorithm{
						type_: value
						symbol_list: parsed_symbols
					}))
				}
				.additive {
					additive_symbols := additive_symbols_style_value or { return none }
					additive_tuples := CounterStyleDefinition.resolve_additive_symbols(additive_symbols, computation_context)
					if !system_style_value.is_valid_additive_symbol_count(additive_tuples.len) {
						return none
					}
					CounterStyleAlgorithmOrExtends(CounterStyleAlgorithm(AdditiveCounterStyleAlgorithm{
						symbol_list: additive_tuples
					}))
				}
			}
		}
		CounterStyleSystemFixed {
			symbols := symbols_style_value or { return none }
			parsed_symbols := CounterStyleDefinition.resolve_symbols(symbols)
			if !system_style_value.is_valid_symbol_count(parsed_symbols.len) {
				return none
			}

			// https://drafts.csswg.org/css-counter-styles-3/#fixed-system
			// If it is omitted, the first symbol value is 1.
			mut first_symbol := i64(1)
			if first := value.first_symbol {
				first_symbol = int_from_style_value(first.absolutized(computation_context))
			}

			CounterStyleAlgorithmOrExtends(CounterStyleAlgorithm(FixedCounterStyleAlgorithm{
				first_symbol: first_symbol
				symbol_list: parsed_symbols
			}))
		}
		CounterStyleSystemExtends {
			CounterStyleAlgorithmOrExtends(value)
		}
	}
}

// https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-symbols
pub fn CounterStyleDefinition.resolve_symbols(symbols_style_value CounterStyleSymbolListStyleValue) []string {
	mut symbols := []string{cap: symbols_style_value.values.len}
	for entry in symbols_style_value.values {
		symbols << string_from_style_value(entry)
	}
	return symbols
}

// https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-additive-symbols
pub fn CounterStyleDefinition.resolve_additive_symbols(additive_symbols_style_value CounterStyleAdditiveSymbolsStyleValue, computation_context ComputationContext) []AdditiveCounterStyleTuple {
	mut additive_tuples := []AdditiveCounterStyleTuple{cap: additive_symbols_style_value.tuples.len}
	for entry in additive_symbols_style_value.tuples {
		weight :=
			clamp_i64_to_i32(int_from_style_value(entry.weight.absolutized(computation_context)))
		symbol := string_from_style_value(entry.symbol)
		additive_tuples << AdditiveCounterStyleTuple{
			weight: weight
			symbol: symbol
		}
	}
	return additive_tuples
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-negative
pub fn CounterStyleDefinition.resolve_negative_sign(style_value CounterStyleSymbolListStyleValue) CounterStyleNegativeSign {
	negative_entries := style_value.values
	return CounterStyleNegativeSign{
		prefix: string_from_style_value(negative_entries[0])
		suffix: if negative_entries.len > 1 {
			string_from_style_value(negative_entries[1])
		} else {
			''
		}
	}
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-range
pub fn CounterStyleDefinition.resolve_range(style_value CounterStyleRangeStyleValue, computation_context ComputationContext) CounterStyleDefinitionRange {
	// auto
	// NB: Resolving auto depends on the algorithm, which we may not know at parse time i.e. if the system is 'extends'
	//     To handle this we return an intermediate value which we resolve when creating the CounterStyle.
	if style_value.auto_ {
		return CounterStyleDefinitionRange(AutoRange{})
	}

	// [ [ <integer> | infinite ]{2} ]#
	// This defines a comma-separated list of ranges. For each individual range, the first value is the lower bound and
	// the second value is the upper bound. This range is inclusive - it contains both the lower and upper bound
	// numbers. If infinite is used as the first value in a range, it represents negative infinity; if used as the
	// second value, it represents positive infinity. The range of the counter style is the union of all the ranges
	// defined in the list.
	mut ranges := []CounterStyleRangeEntry{cap: style_value.entries.len}
	for entry in style_value.entries {
		ranges << CounterStyleRangeEntry{
			start: resolve_counter_style_range_bound(entry.start, counter_i64_min, computation_context)
			end: resolve_counter_style_range_bound(entry.end, counter_i64_max, computation_context)
		}
	}
	return CounterStyleDefinitionRange(CounterStyleRangeEntries{
		entries: ranges
	})
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-pad
pub fn CounterStyleDefinition.resolve_pad(style_value CounterStylePadStyleValue, computation_context ComputationContext) CounterStylePad {
	return CounterStylePad{
		minimum_length: clamp_i64_to_i32(int_from_style_value(style_value.minimum_length.absolutized(computation_context)))
		symbol: string_from_style_value(style_value.symbol)
	}
}

// --- CounterStyle ---

// https://drafts.csswg.org/css-counter-styles-3/#counter-styles
pub struct CounterStyle {
pub mut:
	// Counter styles are composed of:
	// a name, to identify the style
	name_ string

	// an algorithm, which transforms integer counter values into a basic string representation
	algorithm_ CounterStyleAlgorithm

	// a negative sign, which is prepended or appended to the representation of a negative counter value.
	negative_sign_ CounterStyleNegativeSign

	// a prefix, to prepend to the representation
	prefix_ string

	// a suffix to append to the representation
	suffix_ string

	// a range, which limits the values that a counter style handles
	range_ []CounterStyleRangeEntry

	// FIXME: a spoken form, which describes how to read out the counter style in a speech synthesizer
	// and a fallback style, to render the representation with when the counter value is outside the counter style’s
	// range or the counter style otherwise can’t render the counter value
	fallback_ ?string

	// AD-HOC: We store the `pad` descriptor here as well to have everything in one place
	pad_ CounterStylePad
}

// https://drafts.csswg.org/css-counter-styles-3/#decimal
pub fn CounterStyle.decimal() CounterStyle {
	return CounterStyle.create('decimal', CounterStyleAlgorithm(GenericCounterStyleAlgorithm{
		type_: .numeric
		symbol_list: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
	}), CounterStyleNegativeSign{
		prefix: '-'
		suffix: ''
	}, '', '. ', [CounterStyleRangeEntry{counter_i64_min, counter_i64_max}], none, CounterStylePad{
		minimum_length: 0
		symbol: ''
	})
}

// https://drafts.csswg.org/css-counter-styles-3/#disc
pub fn CounterStyle.disc() CounterStyle {
	return CounterStyle.create('disc', CounterStyleAlgorithm(GenericCounterStyleAlgorithm{
		type_: .cyclic
		symbol_list: [counter_symbol_from_code_point(0x2022)]
	}), CounterStyleNegativeSign{
		prefix: ''
		suffix: ' '
	}, '', ' ', [CounterStyleRangeEntry{counter_i64_min, counter_i64_max}], 'decimal', CounterStylePad{
		minimum_length: 0
		symbol: ''
	})
}

pub fn CounterStyle.from_counter_style_definition(definition CounterStyleDefinition, registered_counter_styles map[string]CounterStyle) CounterStyle {
	algorithm_or_extends := definition.algorithm()
	return match algorithm_or_extends {
		CounterStyleSystemExtends {
			// NB: The caller should ensure that this is always set (i.e. by ensuring the relevant rule is registered
			//     before this one, and replacing the extended counter style with "decimal" if it is not defined).
			extended_counter_style := registered_counter_styles[algorithm_or_extends.name] or {
				CounterStyle.decimal()
			}
			CounterStyle.create(definition.name(), extended_counter_style.algorithm(), definition.negative_sign() or {
				extended_counter_style.negative_sign()
			}, definition.prefix() or { extended_counter_style.prefix() }, definition.suffix() or {
				extended_counter_style.suffix()
			}, match definition.range() {
				CounterStyleRangeOmitted { extended_counter_style.range() }
				CounterStyleRangeEntries { definition.range().entries }
				AutoRange { AutoRange.resolve(extended_counter_style.algorithm()) }
			}, definition.fallback() or { extended_counter_style.fallback() or { 'decimal' } }, definition.pad() or {
				extended_counter_style.pad()
			})
		}
		CounterStyleAlgorithm {
			CounterStyle.create(definition.name(), algorithm_or_extends, definition.negative_sign() or {
				CounterStyleNegativeSign{
					prefix: '-'
					suffix: ''
				}
			}, definition.prefix() or { '' }, definition.suffix() or { '. ' }, match definition.range() {
				CounterStyleRangeEntries { definition.range().entries }
				else { AutoRange.resolve(algorithm_or_extends) }
			}, definition.fallback() or { 'decimal' }, definition.pad() or {
				CounterStylePad{
					minimum_length: 0
					symbol: ''
				}
			})
		}
	}
}

pub fn CounterStyle.create(name string, algorithm CounterStyleAlgorithm, negative_sign CounterStyleNegativeSign, prefix string, suffix string, range []CounterStyleRangeEntry, fallback ?string, pad CounterStylePad) CounterStyle {
	// NB: All counter styles apart from 'decimal' must have a fallback.
	assert fallback != none || name == 'decimal'

	return CounterStyle{
		name_: name
		algorithm_: algorithm
		negative_sign_: negative_sign
		prefix_: prefix
		suffix_: suffix
		range_: range
		fallback_: fallback
		pad_: pad
	}
}

pub fn (counter_style CounterStyle) name() string {
	return counter_style.name_
}

pub fn (counter_style CounterStyle) algorithm() CounterStyleAlgorithm {
	return counter_style.algorithm_
}

pub fn (counter_style CounterStyle) negative_sign() CounterStyleNegativeSign {
	return counter_style.negative_sign_
}

pub fn (counter_style CounterStyle) prefix() string {
	return counter_style.prefix_
}

pub fn (counter_style CounterStyle) suffix() string {
	return counter_style.suffix_
}

pub fn (counter_style CounterStyle) range() []CounterStyleRangeEntry {
	return counter_style.range_
}

pub fn (counter_style CounterStyle) fallback() ?string {
	return counter_style.fallback_
}

pub fn (counter_style CounterStyle) pad() CounterStylePad {
	return counter_style.pad_
}

pub fn (counter_style CounterStyle) equals(other CounterStyle) bool {
	mut fallbacks_equal := counter_style.fallback_ == none && other.fallback_ == none
	if fallback := counter_style.fallback_ {
		if other_fallback := other.fallback_ {
			fallbacks_equal = fallback == other_fallback
		}
	}
	return counter_style.name_ == other.name_ && counter_style.algorithm_ == other.algorithm_
		&& counter_style.negative_sign_ == other.negative_sign_
		&& counter_style.prefix_ == other.prefix_ && counter_style.suffix_ == other.suffix_
		&& counter_style.range_ == other.range_ && counter_style.pad_ == other.pad_
		&& fallbacks_equal
}

// https://drafts.csswg.org/css-counter-styles-3/#extended-range-optional
fn generate_an_initial_representation_for_extended_cjk_system(input_value i64, type_ ExtendedCJKCounterStyleAlgorithmType, digit_strings []string, digit_marker_strings []string, group_marker_strings []string) string {
	mut value := input_value

	// 1. If the counter value is 0, the representation is the character for 0 specified for the given counter style.
	//    Skip the rest of this algorithm.
	if value == 0 {
		return digit_strings[0]
	}

	// 2. If the counter value is negative, instead use the absolute value of the counter value for the remaining steps
	//    of this algorithm.
	// NB: This is handled within `generate_a_counter_representation_impl`

	// 3. Initially represent the counter value as a decimal number. Starting from the right (ones place), split the
	//    decimal number into groups of four digits.
	mut groups := []u16{}
	for value > 0 {
		groups << u16(value % 10000)
		value /= 10000
	}

	mut builder := ''

	for group_index := groups.len - 1; group_index >= 0; group_index-- {
		group_value := groups[group_index]

		mut digits := []u8{}

		mut temp_group_value := group_value
		for temp_group_value > 0 {
			digits << u8(temp_group_value % 10)
			temp_group_value /= 10
		}

		// NB: Pad the group with zeroes up to four digits, unless this is the most significant group.
		if group_index != groups.len - 1 {
			for digits.len < 4 {
				digits << 0
			}
		}

		// NB: We move around the order of spec steps to work with a string builder rather than replacing characters in
		//     a string.
		for digit_index := digits.len - 1; digit_index >= 0; digit_index-- {
			digit_value := digits[digit_index]

			mut should_drop_digit := false
			// 6. Drop ones:
			//  - For the Chinese informal styles, for any group with a value between ten and nineteen, remove the tens
			//    digit (leave the digit marker).
			if extended_cjk_type_is_one_of(type_, [.simp_chinese_informal, .trad_chinese_informal]) {
				should_drop_digit = should_drop_digit
					|| (group_value >= 10 && group_value < 20 && digit_index == 1)
			}

			//  - For the Japanese informal and Korean informal styles, if any of the digit markers are preceded
			//   by the digit 1, and that digit is not the first digit of the group, remove the digit (leave the
			//    digit marker).
			if extended_cjk_type_is_one_of(type_, [.japanese_informal, .korean_hanja_informal]) {
				should_drop_digit = should_drop_digit || (digit_value == 1 && digit_index != 0)
			}

			//  - For Korean informal styles, if the value of the ten-thousands group is 1, drop the digit (leave the
			//    digit marker).
			if type_ == .korean_hanja_informal {
				should_drop_digit = should_drop_digit
					|| (group_index == 1 && group_value == 1 && digit_index == 0)
			}

			// 7. Drop zeros:
			//  - For the Japanese and Korean styles, drop all zero digits.
			if extended_cjk_type_is_one_of(type_, [
				.japanese_informal,
				.japanese_formal,
				.korean_hangul_formal,
				.korean_hanja_informal,
				.korean_hanja_formal,
			]) {
				should_drop_digit = should_drop_digit || digit_value == 0
			}

			//  - For the Chinese styles, drop any trailing zeros for all non-zero groups and collapse (across groups)
			//    each remaining consecutive group of zeros into a single zero digit.
			if extended_cjk_type_is_one_of(type_, [
				.simp_chinese_informal,
				.simp_chinese_formal,
				.trad_chinese_informal,
				.trad_chinese_formal,
			]) {
				mut is_trailing_zero := true
				for trailing_zero_index := digit_index; trailing_zero_index >= 0; trailing_zero_index-- {
					if digits[trailing_zero_index] != 0 {
						is_trailing_zero = false
						break
					}
				}

				should_drop_digit = should_drop_digit || is_trailing_zero

				// NB: We don't need to worry about collapsing across groups since dropping trailing zeroes above means
				//     that a run of zeroes can't occur at the end of a group.
				should_drop_digit = should_drop_digit
					|| (digit_value == 0 && digit_index != 3 && digits[digit_index + 1] == 0)
			}

			// 9. Replace the digits 0-9 with the appropriate character for the given counter style.
			if !should_drop_digit {
				builder += digit_strings[digit_value]
			}

			// 5. Within each group, for each digit that is not 0, append the appropriate digit marker to the digit.
			//    The ones digit of each group has no marker.
			if digit_value != 0 && digit_index != 0 {
				builder += digit_marker_strings[digit_index - 1]
			}
		}

		// 4. For each group with a non-zero value, append the appropriate group marker to the group. The ones group has no marker.
		if groups[group_index] != 0 && group_index != 0 {
			builder += group_marker_strings[group_index - 1]
		}

		// 8. For the Korean styles, insert a space (" " U+0020) between each group.
		if extended_cjk_type_is_one_of(type_, [.korean_hangul_formal, .korean_hanja_informal,
			.korean_hanja_formal])
			&& group_index != 0 {
			builder += ' '
		}
	}

	// 10. If the counter value was negative, prepend the appropriate negative sign character for the given counter
	//     style as specified in the table of characters for each style.
	// NB: This is handled within `generate_a_counter_representation_impl`

	// 11. Return the resultant string as the representation of the counter value.
	return builder
}

pub fn (counter_style CounterStyle) generate_an_initial_representation_for_the_counter_value(input_value i64) ?string {
	algorithm := counter_style.algorithm_
	return match algorithm {
		AdditiveCounterStyleAlgorithm {
			// https://drafts.csswg.org/css-counter-styles-3/#additive-system
			// To construct the representation:
			mut value := input_value

			// 1. Let value initially be the counter value, S initially be the empty string, and symbol list initially
			//    be the list of additive tuples.

			// 2. If value is zero:
			if value == 0 {
				// 1. If symbol list contains a tuple with a weight of zero, append that tuple’s counter symbol to S and
				//    return S.
				for tuple in algorithm.symbol_list {
					if tuple.weight == 0 {
						return tuple.symbol
					}
				}

				// 2. Otherwise, the given counter value cannot be represented by this counter style, and must instead
				//    be represented by the fallback counter style.
				return none
			}

			mut builder := ''

			// 3. For each tuple in symbol list:
			for tuple in algorithm.symbol_list {
				// 1. Let symbol and weight be tuple’s counter symbol and weight, respectively.

				// 2. If weight is zero, or weight is greater than value, continue.
				if tuple.weight == 0 || i64(tuple.weight) > value {
					continue
				}

				// 3. Let reps be floor( value / weight ).
				reps := value / i64(tuple.weight)

				// 4. Append symbol to S reps times.
				builder += tuple.symbol.repeat(int(reps))

				// 5. Decrement value by weight * reps.
				value -= i64(tuple.weight) * reps

				// 6. If value is zero, return S.
				if value == 0 {
					return builder
				}
			}

			// Assertion: value is still non-zero.
			assert value != 0

			// The given counter value cannot be represented by this counter style, and must instead be represented by
			// the fallback counter style.
			none
		}
		FixedCounterStyleAlgorithm {
			// https://drafts.csswg.org/css-counter-styles-3/#fixed-system
			// The first counter symbol is the representation for the first symbol value, and subsequent counter values
			// are represented by subsequent counter symbols. Once the list of counter symbols is exhausted, further
			// values cannot be represented by this counter style, and must instead be represented by the fallback
			// counter style.
			index := input_value - algorithm.first_symbol
			if index < 0 || index >= i64(algorithm.symbol_list.len) {
				return none
			}
			algorithm.symbol_list[int(index)]
		}
		GenericCounterStyleAlgorithm {
			mut value := input_value
			match algorithm.type_ {
				.cyclic {
					// https://drafts.csswg.org/css-counter-styles-3/#cyclic-system
					// If there are N counter symbols and a representation is being constructed for the integer value, the
					// representation is the counter symbol at index ( (value-1) mod N) of the list of counter symbols
					// (0-indexed).
					algorithm.symbol_list[positive_mod_i64(value - 1, algorithm.symbol_list.len)]
				}
				.numeric {
					// https://drafts.csswg.org/css-counter-styles-3/#numeric-system
					// If there are N counter symbols, the representation is a base N number using the counter symbols as
					// digits. To construct the representation, run the following algorithm:

					// Let N be the length of the list of counter symbols, value initially be the counter value, S
					// initially be the empty string, and symbol(n) be the nth counter symbol in the list of counter
					// symbols (0-indexed).

					// 1. If value is 0, append symbol(0) to S and return S.
					if value == 0 {
						return algorithm.symbol_list[0]
					}

					// NB: Our string builder doesn't support prepending, so we use a vector and convert that to a string at
					//     the end.
					mut symbols := []string{}
					n := i64(algorithm.symbol_list.len)

					// 2. While value is not equal to 0:
					for value != 0 {
						// 1. Prepend symbol( value mod N ) to S.
						symbols.prepend(algorithm.symbol_list[int(value % n)])

						// 2. Set value to floor( value / N ).
						value /= n
					}

					// 3. Return S.
					symbols.join('')
				}
				.alphabetic {
					// https://drafts.csswg.org/css-counter-styles-3/#alphabetic-system
					// If there are N counter symbols, the representation is a base N alphabetic number using the counter
					// symbols as digits. To construct the representation, run the following algorithm:

					// Let N be the length of the list of counter symbols, value initially be the counter value, S initially
					// be the empty string, and symbol(n) be the nth counter symbol in the list of counter symbols
					// (0-indexed).

					// NB: Our string builder doesn't support prepending, so we use a vector and convert that to a string at
					//     the end.
					mut symbols := []string{}
					n := i64(algorithm.symbol_list.len)

					// While value is not equal to 0:
					for value != 0 {
						// 1. Set value to value - 1.
						value -= 1

						// 2. Prepend symbol( value mod N ) to S.
						symbols.prepend(algorithm.symbol_list[int(value % n)])

						// 3. Set value to floor( value / N ).
						value /= n
					}

					// Finally, return S.
					symbols.join('')
				}
				.symbolic {
					// https://drafts.csswg.org/css-counter-styles-3/#symbolic-system
					// To construct the representation, run the following algorithm:

					// Let N be the length of the list of counter symbols, value initially be the counter value, S initially
					// be the empty string, and symbol(n) be the nth counter symbol in the list of counter symbols
					// (0-indexed).

					// 1. Let the chosen symbol be symbol( (value - 1) mod N).
					symbol := algorithm.symbol_list[positive_mod_i64(value - 1, algorithm.symbol_list.len)]

					// 2. Let the representation length be ceil( value / N ).
					representation_length := (value + i64(algorithm.symbol_list.len) - 1) / i64(algorithm.symbol_list.len)

					// 3. Append the chosen symbol to S a number of times equal to the representation length.
					// Finally, return S.
					symbol.repeat(int(representation_length))
				}
				.additive {
					// NB: This is handled by AdditiveCounterStyleAlgorithm.
					panic('VERIFY_NOT_REACHED')
				}
			}
		}
		EthiopicNumericCounterStyleAlgorithm {
			mut value := input_value

			// https://drafts.csswg.org/css-counter-styles-3/#ethiopic-numeric-counter-style
			// The following algorithm converts decimal digits to ethiopic numbers:

			// 1. If the number is 1, return "፩" (U+1369).
			if value == 1 {
				return counter_symbol_from_code_point(0x1369)
			}

			// 2. Split the number into groups of two digits, starting with the least significant decimal digit.
			mut groups := []u8{}
			for value != 0 {
				groups << u8(value % 100)
				value /= 100
			}

			mut builder := ''

			// 3. Index each group sequentially, starting from the least significant as group number zero.

			// NB: We iterate in descending order of significance, so we can append to the string builder in order
			for i := groups.len - 1; i >= 0; i-- {
				group_value := groups[i]

				// 4. If the group has the value zero, or if the group is the most significant one and has the value
				//    1, or if the group has an odd index (as given in the previous step) and has the value 1, then
				//    remove the digits (but leave the group, so it still has a separator appended below).
				if group_value != 0 && !(i == groups.len - 1 && group_value == 1) && !(i % 2 == 1
					&& group_value == 1) {
					// 5. For each remaining digit, substitute the relevant ethiopic character from the list below.
					//      Tens
					// Values Codepoints
					// 10     ፲ U+1372
					// 20     ፳ U+1373
					// 30     ፴ U+1374
					// 40     ፵ U+1375
					// 50     ፶ U+1376
					// 60     ፷ U+1377
					// 70     ፸ U+1378
					// 80     ፹ U+1379
					// 90     ፺ U+137A
					tens := group_value / 10
					if tens != 0 {
						builder += counter_symbol_from_code_point(u32(0x1372 + tens - 1))
					}

					//     Units
					// Values Codepoints
					// 1      ፩ U+1369
					// 2      ፪ U+136A
					// 3      ፫ U+136B
					// 4      ፬ U+136C
					// 5      ፭ U+136D
					// 6      ፮ U+136E
					// 7      ፯ U+136F
					// 8      ፰ U+1370
					// 9      ፱ U+1371
					units := group_value % 10
					if units != 0 {
						builder += counter_symbol_from_code_point(u32(0x1369 + units - 1))
					}
				}

				// 6. For each group with an odd index (as given in the second step), except groups which originally
				//    had a value of zero, append ፻ U+137B.
				if i % 2 == 1 && group_value != 0 {
					builder += counter_symbol_from_code_point(0x137b)
				// 7. For each group with an even index (as given in the second step), except the group with index
				//    0, append ፼ U+137C.
				} else if i % 2 == 0 && i != 0 {
					builder += counter_symbol_from_code_point(0x137c)
				}
			}

			// 8. Concatenate the groups into one string, and return it.
			builder
		}
		ExtendedCJKCounterStyleAlgorithm {
			// https://drafts.csswg.org/css-counter-styles-3/#extended-range-optional
			// All of the styles are defined by almost identical algorithms (specified as a single algorithm here, with
			// the differences called out when relevant), but use different sets of characters.
			// The following tables define the characters used in these styles:
			generate_extended_cjk_counter_style(input_value, algorithm.type_)
		}
	}
}

// https://drafts.csswg.org/css-counter-styles-3/#counter-style-negative
pub fn (counter_style CounterStyle) uses_a_negative_sign() bool {
	// Not all system values use a negative sign. In particular, a counter style uses a negative sign if its system
	// value is symbolic, alphabetic, numeric, additive, or extends if the extended counter style itself uses a negative
	// sign.
	// NB: We have resolved extends to the underlying algorithm before calling this
	algorithm := counter_style.algorithm_
	return match algorithm {
		AdditiveCounterStyleAlgorithm {
			true
		}
		FixedCounterStyleAlgorithm {
			false
		}
		GenericCounterStyleAlgorithm {
			match algorithm.type_ {
				.cyclic {
					false
				}
				.symbolic, .alphabetic, .numeric {
					true
				}
				.additive {
					// NB: This is handled by AdditiveCounterStyleAlgorithm.
					panic('VERIFY_NOT_REACHED')
				}
			}
		}
		EthiopicNumericCounterStyleAlgorithm {
			// https://drafts.csswg.org/css-counter-styles-3/#complex-predefined-counters
			// All of the counter styles defined in this section have a spoken form of numbers, and use a negative sign.
			true
		}
		ExtendedCJKCounterStyleAlgorithm {
			// https://drafts.csswg.org/css-counter-styles-3/#complex-predefined-counters
			// All of the counter styles defined in this section have a spoken form of numbers, and use a negative sign.
			true
		}
	}
}

// https://drafts.csswg.org/css-counter-styles-3/#generate-a-counter
fn generate_a_counter_representation_impl(counter_style ?CounterStyle, registered_counter_styles map[string]CounterStyle, value i32, mut fallback_history map[string]bool) string {
	// When asked to generate a counter representation using a particular counter style for a particular
	// counter value, follow these steps:

	// 1. If the counter style is unknown, exit this algorithm and instead generate a counter representation using the
	//    decimal style and the same counter value.
	style := counter_style or {
		return generate_a_counter_representation_impl(CounterStyle.decimal(), registered_counter_styles, value, mut fallback_history)
	}

	// 2. If the counter value is outside the range of the counter style, exit this algorithm and instead generate a
	//    counter representation using the counter style’s fallback style and the same counter value.
	mut in_range := false
	for entry in style.range() {
		if i64(value) >= entry.start && i64(value) <= entry.end {
			in_range = true
			break
		}
	}
	if !in_range {
		return generate_a_counter_representation_using_fallback(style, registered_counter_styles, value, mut fallback_history)
	}

	value_is_negative_and_uses_negative_sign := value < 0 && style.uses_a_negative_sign()

	// 3. Using the counter value and the counter algorithm for the counter style, generate an initial representation
	//    for the counter value. If the counter value is negative and the counter style uses a negative sign, instead
	//    generate an initial representation using the absolute value of the counter value.
	representation_value := if value_is_negative_and_uses_negative_sign {
		-i64(value)
	} else {
		i64(value)
	}
	maybe_representation :=
		style.generate_an_initial_representation_for_the_counter_value(representation_value)

	// AD-HOC: Algorithms are sometimes unable to produce a representation and require us to use the fallback - we
	//         represent this by returning an empty Optional.
	mut representation := maybe_representation or {
		return generate_a_counter_representation_using_fallback(style, registered_counter_styles, value, mut fallback_history)
	}

	// 4. Prepend symbols to the representation as specified in the pad descriptor.
	{
		// https://drafts.csswg.org/css-counter-styles-3/#counter-style-pad
		// Let difference be the provided <integer> minus the number of grapheme clusters in the initial representation
		// for the counter value.
		// FIXME: We should be counting grapheme clusters here.
		mut difference := style.pad().minimum_length - i32(representation.len)

		// If the counter value is negative and the counter style uses a negative sign, further reduce difference by
		// the number of grapheme clusters in the counter style’s negative descriptor’s <symbol>(s).
		// FIXME: We should be counting grapheme clusters here.
		if value_is_negative_and_uses_negative_sign {
			difference -= i32(style.negative_sign().prefix.len + style.negative_sign().suffix.len)
		}

		// If difference is greater than zero, prepend difference copies of the specified <symbol> to the representation.
		if difference > 0 {
			representation = style.pad().symbol.repeat(int(difference)) + representation
		}
	}

	// 5. If the counter value is negative and the counter style uses a negative sign, wrap the representation in the
	//    counter style’s negative sign as specified in the negative descriptor.
	if value_is_negative_and_uses_negative_sign {
		representation = style.negative_sign().prefix + representation + style.negative_sign().suffix
	}

	// 6. Return the representation.
	return representation
}

fn generate_a_counter_representation_using_fallback(counter_style CounterStyle, registered_counter_styles map[string]CounterStyle, value i32, mut fallback_history map[string]bool) string {
	assert counter_style.name() != 'decimal'

	fallback_name := counter_style.fallback() or { 'decimal' }

	// https://drafts.csswg.org/css-counter-styles-3/#counter-style-fallback
	// If the value of the fallback descriptor isn’t the name of any defined counter style, the used value of the
	// fallback descriptor is decimal instead. Similarly, while following fallbacks to find a counter style that
	// can render the given counter value, if a loop in the specified fallbacks is detected, the decimal style must
	// be used instead.
	if fallback_name in fallback_history {
		return generate_a_counter_representation_impl(CounterStyle.decimal(), registered_counter_styles, value, mut fallback_history)
	}
	fallback := registered_counter_styles[fallback_name] or {
		return generate_a_counter_representation_impl(CounterStyle.decimal(), registered_counter_styles, value, mut fallback_history)
	}

	fallback_history[counter_style.name()] = true
	return generate_a_counter_representation_impl(fallback, registered_counter_styles, value, mut fallback_history)
}

pub fn generate_a_counter_representation(counter_style ?CounterStyle, registered_counter_styles map[string]CounterStyle, value i32) string {
	mut fallback_history := map[string]bool{}
	return generate_a_counter_representation_impl(counter_style, registered_counter_styles, value, mut fallback_history)
}

fn collect_counter_style_definitions_from_sheet(sheet &CSSStyleSheet, context ComputationContext, definitions_ptr &map[string]CounterStyleDefinition) {
	sheet.for_each_effective_counter_style_at_rule(fn [context, definitions_ptr] (rule &CSSRule) {
		counter_style_rule := rule.counter_style_rule_value() or { return }
		definition := CounterStyleDefinition.from_counter_style_rule(counter_style_rule, context) or {
			return
		}
		unsafe {
			mut definitions := *definitions_ptr
			definitions[definition.name()] = definition
			*definitions_ptr = definitions
		}
	})
}

struct ComplexPredefinedCounterStyle {
	name     string
	type_    ExtendedCJKCounterStyleAlgorithmType
	negative string
	suffix   string
}

fn define_complex_predefined_counter_styles(mut definitions map[string]CounterStyleDefinition) {
	extended_range := CounterStyleDefinitionRange(CounterStyleRangeEntries{
		entries: [CounterStyleRangeEntry{-9999999999999999, 9999999999999999}]
	})
	definitions['ethiopic-numeric'] = CounterStyleDefinition.create('ethiopic-numeric', CounterStyleAlgorithmOrExtends(CounterStyleAlgorithm(EthiopicNumericCounterStyleAlgorithm{})), none, none, '/ ', CounterStyleDefinitionRange(CounterStyleRangeEntries{
		entries: [CounterStyleRangeEntry{1, counter_i64_max}]
	}), none, none)
	for entry in [
		ComplexPredefinedCounterStyle{'simp-chinese-informal', .simp_chinese_informal, '负', '、'},
		ComplexPredefinedCounterStyle{'simp-chinese-formal', .simp_chinese_formal, '负', '、'},
		ComplexPredefinedCounterStyle{'trad-chinese-informal', .trad_chinese_informal, '負', '、'},
		ComplexPredefinedCounterStyle{'trad-chinese-formal', .trad_chinese_formal, '負', '、'},
		ComplexPredefinedCounterStyle{'cjk-ideographic', .trad_chinese_informal, '負', '、'},
		ComplexPredefinedCounterStyle{'japanese-informal', .japanese_informal, 'マイナス', '、'},
		ComplexPredefinedCounterStyle{'japanese-formal', .japanese_formal, 'マイナス', '、'},
		ComplexPredefinedCounterStyle{'korean-hangul-formal', .korean_hangul_formal, '마이너스 ', ', '},
		ComplexPredefinedCounterStyle{'korean-hanja-informal', .korean_hanja_informal, '마이너스 ', ', '},
		ComplexPredefinedCounterStyle{'korean-hanja-formal', .korean_hanja_formal, '마이너스 ', ', '},
	] {
		definitions[entry.name] = CounterStyleDefinition.create(entry.name, CounterStyleAlgorithmOrExtends(CounterStyleAlgorithm(ExtendedCJKCounterStyleAlgorithm{
			type_: entry.type_
		})), CounterStyleNegativeSign{
			prefix: entry.negative
			suffix: ''
		}, none, entry.suffix, extended_range, 'cjk-decimal', none)
	}
}

fn parent_style_scope_for_global_tree_scoped_reference(scope &StyleScope) ?&StyleScope {
	node := scope.node_ref() or { return none }
	shadow_root := node.as_shadow_root() or { return none }
	host := shadow_root.host() or { return none }
	root := host.as_node().root()
	if outer_shadow_root := root.as_shadow_root() {
		return css_style_scope_for_shadow_root(outer_shadow_root)
	}
	return css_style_scope_for_document(root.document())
}

fn counter_style_definition_is_part_of_extends_cycle(name string, definitions map[string]CounterStyleDefinition) bool {
	mut visited := map[string]bool{}
	mut current_name := name
	for {
		if visited[current_name] {
			return true
		}
		visited[current_name] = true
		definition := definitions[current_name] or { return false }
		algorithm := definition.algorithm()
		if algorithm is CounterStyleAlgorithm {
			return false
		}
		current_name = (algorithm as CounterStyleSystemExtends).name
	}
	return false
}

fn build_registered_counter_styles_for_scope(scope &StyleScope) map[string]CounterStyle {
	document := scope.document() or { return map[string]CounterStyle{} }
	mut definitions := map[string]CounterStyleDefinition{}
	definitions_ptr := &definitions
	context := ComputationContext{
		length_resolution_context: LengthResolutionContext.for_document(document)
	}
	mut registered := map[string]CounterStyle{}
	if parent_scope := parent_style_scope_for_global_tree_scoped_reference(scope) {
		registered = registered_counter_styles_for_scope(parent_scope).clone()
	} else {
		collect_counter_style_definitions_from_sheet(user_agent_counter_style_sheet(), context, definitions_ptr)
		for sheet in scope.stylesheets_for_cascade_origin(.user_agent) {
			collect_counter_style_definitions_from_sheet(sheet, context, definitions_ptr)
		}
		define_complex_predefined_counter_styles(mut definitions)
		for sheet in scope.stylesheets_for_cascade_origin(.user) {
			collect_counter_style_definitions_from_sheet(sheet, context, definitions_ptr)
		}
	}
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		collect_counter_style_definitions_from_sheet(sheet, context, definitions_ptr)
	}

	// Default.css defines these in the document scope. Retain the spec fallback
	// when a reduced embedding omits that stylesheet; descendant scopes inherit
	// the resulting definitions through the global tree-scoped-name chain.
	if parent_style_scope_for_global_tree_scoped_reference(scope) == none {
		if 'decimal' !in definitions {
			registered['decimal'] = CounterStyle.decimal()
		}
		if 'disc' !in definitions {
			registered['disc'] = CounterStyle.disc()
		}
	}
	mut extending := []CounterStyleDefinition{}
	mut resolved_in_this_scope := map[string]bool{}
	for _, definition in definitions {
		algorithm := definition.algorithm()
		if algorithm is CounterStyleAlgorithm {
			registered[definition.name()] = CounterStyle.from_counter_style_definition(definition, registered)
			resolved_in_this_scope[definition.name()] = true
		} else {
			if counter_style_definition_is_part_of_extends_cycle(definition.name(), definitions) {
				mut copied := definition
				copied.set_algorithm(CounterStyleAlgorithmOrExtends(CounterStyleSystemExtends{
					name: 'decimal'
				}))
				extending << copied
			} else {
				extending << definition
			}
		}
	}
	for extending.len > 0 {
		mut remaining := []CounterStyleDefinition{}
		for definition in extending {
			algorithm := definition.algorithm()
			extends := if algorithm is CounterStyleSystemExtends {
				algorithm.name
			} else {
				'decimal'
			}
			if extends in definitions && !resolved_in_this_scope[extends] {
				remaining << definition
				continue
			}
			registered[definition.name()] = CounterStyle.from_counter_style_definition(definition, registered)
			resolved_in_this_scope[definition.name()] = true
		}
		extending = remaining.clone()
	}
	return registered
}

fn mark_counter_style_scope_cache_dirty(scope &StyleScope) {
	mut mutable_scope := unsafe { &StyleScope(scope) }
	mutable_scope.needs_counter_style_cache_update = true
}

pub fn (mut scope StyleScope) invalidate_counter_style_cache() {
	document := scope.document() or { return }
	mark_counter_style_scope_cache_dirty(css_style_scope_for_document(document))
	document.for_each_shadow_root(fn (shadow_root &dom.ShadowRoot) {
		mark_counter_style_scope_cache_dirty(css_style_scope_for_shadow_root(shadow_root))
	})
}

pub fn registered_counter_styles_for_scope(scope &StyleScope) map[string]CounterStyle {
	if scope.needs_counter_style_cache_update && !scope.is_doing_counter_style_cache_update {
		mut mutable_scope := unsafe { &StyleScope(scope) }
		mutable_scope.is_doing_counter_style_cache_update = true
		mutable_scope.registered_counter_styles = build_registered_counter_styles_for_scope(scope)
		mutable_scope.is_doing_counter_style_cache_update = false
		mutable_scope.needs_counter_style_cache_update = false
	}
	return scope.registered_counter_styles
}

pub fn registered_counter_styles_for_abstract_element(abstract_element dom.AbstractElement) map[string]CounterStyle {
	return registered_counter_styles_for_scope(css_style_scope_for(abstract_element))
}

pub fn registered_counter_styles_for_document(document &dom.Document) map[string]CounterStyle {
	return registered_counter_styles_for_scope(css_style_scope_for_document(document))
}

fn rebuild_registered_counter_styles_for_document(document &dom.Document) {
	mut scope := css_style_scope_for_document(document)
	scope.needs_counter_style_cache_update = true
	_ = registered_counter_styles_for_scope(scope)
}

pub fn invalidate_registered_counter_styles_for_document(document &dom.Document) {
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_counter_style_cache()
}

// --- CountersSet ---

// "UAs may have implementation-specific limits on the maximum or minimum value of a counter.
// If a counter reset, set, or increment would push the value outside of that range, the value
// must be clamped to that range." - https://drafts.csswg.org/css-lists-3/#auto-numbering
pub type CounterValue = i32

// Narrow stand-in for DOM::AbstractElement identity and tree ordering hooks used by CountersSet.
pub struct CounterOriginatingElement {
pub mut:
	id                i64
	parent_id         ?i64
	tree_order_index  i64
	debug_description string
}

pub fn (element CounterOriginatingElement) is_before(other CounterOriginatingElement) bool {
	return element.tree_order_index < other.tree_order_index
}

pub fn (element CounterOriginatingElement) same_parent_as(other CounterOriginatingElement) bool {
	return element.parent_id == other.parent_id
}

// https://drafts.csswg.org/css-lists-3/#counter
pub struct Counter {
pub mut:
	name                string
	originating_element CounterOriginatingElement // "creator"
	reversed            bool
	value               ?CounterValue
}

pub struct CountersSet {
pub mut:
	counters_ []Counter
}

// https://drafts.csswg.org/css-lists-3/#instantiate-counter
pub fn (mut counters_set CountersSet) instantiate_a_counter(name string, element CounterOriginatingElement, reversed bool, value ?CounterValue) Counter {
	// 1. Let counters be element’s CSS counters set.

	// 2. Let innermost counter be the last counter in counters with the name name.
	//    If innermost counter’s originating element is element or a previous sibling of element,
	//    remove innermost counter from counters.
	if innermost_index := counters_set.last_counter_with_name_index(name) {
		innermost_counter := counters_set.counters_[innermost_index]
		innermost_element := innermost_counter.originating_element
		if innermost_element == element
			|| (innermost_element.same_parent_as(element) && innermost_element.is_before(element)) {
			counters_set.counters_.delete(innermost_index)
		}
	}

	// 3. Append a new counter to counters with name name, originating element element,
	//    reversed being reversed, and initial value value (if given)
	counter := Counter{
		name: name
		originating_element: element
		reversed: reversed
		value: value
	}
	counters_set.counters_ << counter
	return counter
}

// https://drafts.csswg.org/css-lists-3/#propdef-counter-set
pub fn (mut counters_set CountersSet) set_a_counter(name string, element CounterOriginatingElement, value CounterValue) {
	if existing_index := counters_set.last_counter_with_name_index(name) {
		counters_set.counters_[existing_index].value = value
		return
	}

	// If there is not currently a counter of the given name on the element, the element instantiates
	// a new counter of the given name with a starting value of 0 before setting or incrementing its value.
	// https://drafts.csswg.org/css-lists-3/#valdef-counter-set-counter-name-integer
	counters_set.instantiate_a_counter(name, element, false, 0)
	counters_set.counters_[counters_set.counters_.len - 1].value = value
}

// https://drafts.csswg.org/css-lists-3/#propdef-counter-increment
pub fn (mut counters_set CountersSet) increment_a_counter(name string, element CounterOriginatingElement, amount CounterValue) {
	if existing_index := counters_set.last_counter_with_name_index(name) {
		// FIXME: How should we handle existing counters with no value? Can that happen?
		existing_value := counters_set.counters_[existing_index].value or {
			panic('VERIFY_NOT_REACHED')
		}

		counters_set.counters_[existing_index].value = saturating_add_counter_value(existing_value, amount)
		return
	}

	// If there is not currently a counter of the given name on the element, the element instantiates
	// a new counter of the given name with a starting value of 0 before setting or incrementing its value.
	// https://drafts.csswg.org/css-lists-3/#valdef-counter-set-counter-name-integer
	counters_set.instantiate_a_counter(name, element, false, 0)
	current_value := counters_set.counters_[counters_set.counters_.len - 1].value or {
		CounterValue(0)
	}

	counters_set.counters_[counters_set.counters_.len - 1].value = saturating_add_counter_value(current_value, amount)
}

pub fn (mut counters_set CountersSet) counter_value_for_use(name string, element CounterOriginatingElement) CounterValue {
	if existing_index := counters_set.last_counter_with_name_index(name) {
		return counters_set.counters_[existing_index].value or { CounterValue(0) }
	}
	counters_set.instantiate_a_counter(name, element, false, 0)
	return CounterValue(0)
}

pub fn (counters_set CountersSet) last_counter_with_name_index(name string) ?int {
	for i := counters_set.counters_.len - 1; i >= 0; i-- {
		if counters_set.counters_[i].name == name {
			return i
		}
	}
	return none
}

pub fn (counters_set CountersSet) last_counter_with_name(name string) ?Counter {
	index := counters_set.last_counter_with_name_index(name) or { return none }
	return counters_set.counters_[index]
}

pub fn (counters_set CountersSet) counter_with_same_name_and_creator_index(name string, element CounterOriginatingElement) ?int {
	for i, counter in counters_set.counters_ {
		if counter.name == name && counter.originating_element == element {
			return i
		}
	}
	return none
}

pub fn (counters_set CountersSet) counter_with_same_name_and_creator(name string, element CounterOriginatingElement) ?Counter {
	index := counters_set.counter_with_same_name_and_creator_index(name, element) or { return none }
	return counters_set.counters_[index]
}

pub fn (mut counters_set CountersSet) append_copy(counter Counter) {
	counters_set.counters_ << counter
}

pub fn (counters_set CountersSet) counters() []Counter {
	return counters_set.counters_
}

pub fn (counters_set CountersSet) is_empty() bool {
	return counters_set.counters_.len == 0
}

pub fn list_item_counter_name() string {
	return 'list-item'
}

fn style_has_implicit_list_item_increment(style &ComputedProperties) bool {
	if !style.display().is_list_item() {
		return false
	}
	for counter in unsafe { &ComputedValues(style) }.counter_increment() {
		if counter.name == list_item_counter_name() {
			return false
		}
	}
	return true
}

enum ReversedScopeWalkDecision {
	@continue
	stop
}

struct ReversedScopeWalkState {
mut:
	name                           string
	name_is_list_item              bool
	num                            i64
	last_nonzero_increment_negated i64
}

fn apply_reversed_counter_contribution(mut state ReversedScopeWalkState, style &ComputedProperties) ReversedScopeWalkDecision {
	computed_values := unsafe { &ComputedValues(style) }
	mut increment := i64(0)
	for counter in computed_values.counter_increment() {
		if counter.name == state.name {
			increment += i64(counter.value or { 0 })
		}
	}
	if state.name_is_list_item && style_has_implicit_list_item_increment(style) {
		increment = -1
	}

	increment_negated := -increment
	if increment_negated != 0 {
		state.last_nonzero_increment_negated = increment_negated
	}
	for counter in computed_values.counter_set() {
		if counter.name == state.name {
			state.num += i64(counter.value or { 0 })
			return .stop
		}
	}
	state.num += increment_negated
	return .@continue
}

fn first_element_child(element &dom.Element) ?&dom.Element {
	for child in element.as_node().children_as_vector() {
		if child_element := child.as_element() {
			return child_element
		}
	}
	return none
}

fn walk_reversed_counter_sibling_run(mut state ReversedScopeWalkState, first ?&dom.Element) ReversedScopeWalkDecision {
	mut current := first
	for current != none {
		element := current or { break }
		current = element.as_node().next_element_sibling()
		style := computed_properties_for_element(element) or { continue }
		if style.display().is_none() {
			continue
		}
		mut resets_name := false
		for counter in unsafe { &ComputedValues(style) }.counter_reset() {
			if counter.name == state.name {
				resets_name = true
				break
			}
		}
		if resets_name {
			break
		}
		if apply_reversed_counter_contribution(mut state, style) == .stop {
			return .stop
		}
		if walk_reversed_counter_sibling_run(mut state, first_element_child(element)) == .stop {
			return .stop
		}
	}
	return .@continue
}

fn clamp_reversed_counter_value(value i64) CounterValue {
	if value > 2147483647 {
		return CounterValue(2147483647)
	}
	if value < -2147483648 {
		return CounterValue(-2147483648)
	}
	return CounterValue(value)
}

fn reversed_counter_start_value(name string, originating_element &dom.AbstractElement, originating_style &ComputedProperties) CounterValue {
	mut state := ReversedScopeWalkState{
		name: name
		name_is_list_item: name == list_item_counter_name()
	}
	mut decision := apply_reversed_counter_contribution(mut state, originating_style)
	if decision == .@continue && originating_element.pseudo_element() == none {
		element := originating_element.element()
		decision = walk_reversed_counter_sibling_run(mut state, first_element_child(element))
		if decision == .@continue {
			walk_reversed_counter_sibling_run(mut state, element.as_node().next_element_sibling())
		}
	}
	return clamp_reversed_counter_value(state.num + state.last_nonzero_increment_negated)
}

fn counters_set_from_dom(wrapper &dom.CSSCountersSet_) ?&CountersSet {
	if wrapper.css_handle == unsafe { nil } {
		return none
	}
	return unsafe { &CountersSet(wrapper.css_handle) }
}

// CSS owns the concrete CountersSet while DOM stores an opaque holder to avoid
// the dom -> css import cycle, just like the ComputedProperties bridge.
pub fn counters_set_for_abstract_element(abstract_element &dom.AbstractElement) ?CountersSet {
	wrapper := abstract_element.counters_set() or { return none }
	set := counters_set_from_dom(wrapper) or { return none }
	return *set
}

pub fn set_counters_set_for_abstract_element(mut abstract_element dom.AbstractElement, counters_set ?CountersSet) {
	if set := counters_set {
		if set.is_empty() {
			abstract_element.set_counters_set(none)
			return
		}
		stored := &CountersSet{
			counters_: set.counters_.clone()
		}
		abstract_element.set_counters_set(dom.CSSCountersSet_.with_css_handle(voidptr(stored)))
		return
	}
	abstract_element.set_counters_set(none)
}

fn ensure_counters_set_for_abstract_element(abstract_element &dom.AbstractElement) &CountersSet {
	if wrapper := abstract_element.counters_set() {
		if set := counters_set_from_dom(wrapper) {
			return set
		}
	}
	stored := &CountersSet{}
	mut mutable_abstract_element := unsafe { &dom.AbstractElement(abstract_element) }
	mutable_abstract_element.set_counters_set(dom.CSSCountersSet_.with_css_handle(voidptr(stored)))
	return stored
}

pub struct CounterOperation {
pub mut:
	name        string
	is_reversed bool
	value       ?CounterValue
}

fn optional_counter_operation_value(value ?i32) ?CounterValue {
	resolved := value or { return none }
	return CounterValue(resolved)
}

// TreeBuilder supplies the layout-tree neighbors because counter inheritance
// is defined over the layout tree, not the DOM tree. This invokes the literal
// translated resolve_counters()/inherit_counters() algorithms above and then
// publishes their result through DOM::AbstractElement.
pub fn resolve_counters_for_layout(mut abstract_element dom.AbstractElement, computed &ComputedProperties, origin CounterOriginatingElement, has_parent_element bool, parent_counters ?CountersSet, previous_sibling_counters ?CountersSet, previous_element_counters ?CountersSet) ?CountersSet {
	computed_values := unsafe { &ComputedValues(computed) }
	// A previous element only supplies values for counters already inherited
	// from the parent or preceding sibling. With neither source nor an operation,
	// resolution can only clear the DOM snapshot; no CounterElement is needed.
	if !computed.display().is_list_item() && computed_values.counter_reset().len == 0
		&& computed_values.counter_increment().len == 0 && computed_values.counter_set().len == 0 {
		parent_nonempty := if counters := parent_counters { !counters.is_empty() } else { false }
		sibling_nonempty := if counters := previous_sibling_counters { !counters.is_empty() } else { false }
		if !has_parent_element || (!parent_nonempty && !sibling_nonempty) {
			set_counters_set_for_abstract_element(mut abstract_element, none)
			return none
		}
	}
	mut reset := []CounterOperation{}
	for counter in computed_values.counter_reset() {
		mut value := optional_counter_operation_value(counter.value)
		if counter.is_reversed && value == none {
			value = reversed_counter_start_value(counter.name, &abstract_element, computed)
		}
		reset << CounterOperation{
			name: counter.name
			is_reversed: counter.is_reversed
			value: value
		}
	}
	mut increment := []CounterOperation{}
	for counter in computed_values.counter_increment() {
		increment << CounterOperation{
			name: counter.name
			value: optional_counter_operation_value(counter.value)
		}
	}
	mut set := []CounterOperation{}
	for counter in computed_values.counter_set() {
		set << CounterOperation{
			name: counter.name
			value: optional_counter_operation_value(counter.value)
		}
	}
	resolved := resolve_retained_counter_state(CounterElement{
		origin: origin
		generates_box: !computed.display().is_none()
		parent_counters: parent_counters
		previous_sibling_in_tree_order: previous_sibling_counters
		previous_element_in_tree_order: previous_element_counters
		counter_reset: reset
		counter_increment: increment
		counter_set: set
		is_list_item: computed.display().is_list_item()
		has_parent_element: has_parent_element
	})
	set_counters_set_for_abstract_element(mut abstract_element, resolved)
	return resolved
}

// Narrow stand-in for the DOM/Layout/style hooks used by resolve_counters()/inherit_counters().
pub struct CounterElement {
pub mut:
	origin                         CounterOriginatingElement
	generates_box                  bool = true
	parent_counters                ?CountersSet
	previous_sibling_in_tree_order ?CountersSet
	previous_element_in_tree_order ?CountersSet
	counters_set                   ?CountersSet
	counter_reset                  []CounterOperation
	counter_increment              []CounterOperation
	counter_set                    []CounterOperation
	is_list_item                   bool
	has_parent_element             bool
}

// https://drafts.csswg.org/css-lists-3/#auto-numbering
pub fn resolve_counters(element CounterElement) CounterElement {
	mut element_reference := element

	// Resolving counter values on a given element is a multi-step process:

	// 1. Existing counters are inherited from previous elements.
	element_reference = inherit_counters(element_reference)

	// https://drafts.csswg.org/css-lists-3/#counters-without-boxes
	// An element that does not generate a box (for example, an element with display set to none,
	// or a pseudo-element with content set to none) cannot set, reset, or increment a counter.
	// The counter properties are still valid on such an element, but they must have no effect.
	if !element_reference.generates_box {
		return element_reference
	}

	// 2. New counters are instantiated (counter-reset).
	for counter in element_reference.counter_reset {
		mut counters := element_reference.ensure_counters_set()
		counters.instantiate_a_counter(counter.name, element_reference.origin, counter.is_reversed, counter.value)
		element_reference.counters_set = counters
	}

	// FIXME: Take style containment into account
	// https://drafts.csswg.org/css-contain-2/#containment-style
	// Giving an element style containment has the following effects:
	// 1. The 'counter-increment' and 'counter-set' properties must be scoped to the element’s sub-tree and create a
	//    new counter.

	// 3. Counter values are incremented (counter-increment).
	for counter in element_reference.counter_increment {
		mut counters := element_reference.ensure_counters_set()
		counters.increment_a_counter(counter.name, element_reference.origin, counter.value or {
			CounterValue(0)
		})
		element_reference.counters_set = counters
	}

	mut has_implicit_list_item_increment := element_reference.is_list_item
	for counter in element_reference.counter_increment {
		if counter.name == list_item_counter_name() {
			has_implicit_list_item_increment = false
			break
		}
	}
	if has_implicit_list_item_increment {
		mut counters := element_reference.ensure_counters_set()
		innermost := counters.last_counter_with_name(list_item_counter_name())
		reversed := if counter := innermost { counter.reversed } else { false }
		counters.increment_a_counter(list_item_counter_name(), element_reference.origin, if reversed {
			CounterValue(-1)
		} else {
			CounterValue(1)
		})
		element_reference.counters_set = counters
	}

	// 4. Counter values are explicitly set (counter-set).
	for counter in element_reference.counter_set {
		mut counters := element_reference.ensure_counters_set()
		counters.set_a_counter(counter.name, element_reference.origin, counter.value or {
			CounterValue(0)
		})
		element_reference.counters_set = counters
	}

	// 5. Counter values are used (counter()/counters()).
	// NOTE: This happens when we process the `content` property.
	return element_reference
}

// https://drafts.csswg.org/css-lists-3/#inherit-counters
pub fn inherit_counters(element CounterElement) CounterElement {
	mut element_reference := element
	// 1. If element is the root of its document tree, the element has an initially-empty CSS counters set.
	//    Return.
	if !element_reference.has_parent_element {
		// NOTE: We represent an empty counters set with `m_counters_set = nullptr`.
		element_reference.counters_set = none
		return element_reference
	}

	// 2. Let element counters, representing element’s own CSS counters set, be a copy of the CSS counters
	//    set of element’s parent element.
	mut element_counters := ?CountersSet(none)
	if parent_counters := element_reference.parent_counters {
		if !parent_counters.is_empty() {
			element_counters = parent_counters
		}
	}

	// 3. Let sibling counters be the CSS counters set of element’s preceding sibling (if it has one),
	//    or an empty CSS counters set otherwise.
	//    For each counter of sibling counters, if element counters does not already contain a counter with
	//    the same name, append a copy of counter to element counters.
	if sibling_counters := element_reference.previous_sibling_in_tree_order {
		if !sibling_counters.is_empty() {
			mut counters := element_counters or { CountersSet{} }
			for counter in sibling_counters.counters() {
				if counters.last_counter_with_name(counter.name) == none {
					counters.append_copy(counter)
				}
			}
			element_counters = counters
		}
	}

	// 4. Let value source be the CSS counters set of the element immediately preceding element in tree order.
	//    For each source counter of value source, if element counters contains a counter with the same name
	//    and creator, then set the value of that counter to source counter’s value.
	if previous_counters := element_reference.previous_element_in_tree_order {
		if mut counters := element_counters {
			for source_counter in previous_counters.counters() {
				if existing_index := counters.counter_with_same_name_and_creator_index(source_counter.name, source_counter.originating_element) {
					counters.counters_[existing_index].value = source_counter.value
				}
			}
			element_counters = counters
		}
	}

	if counters := element_counters {
		assert !counters.is_empty()
		element_reference.counters_set = counters
	} else {
		element_reference.counters_set = none
	}
	return element_reference
}

pub fn (mut element_reference CounterElement) ensure_counters_set() CountersSet {
	if counters := element_reference.counters_set {
		return counters
	}
	return CountersSet{}
}

pub fn (counters_set CountersSet) dump() string {
	mut builder := '{\n'
	for counter in counters_set.counters_ {
		value := if counter_value := counter.value { '${counter_value}' } else { 'none' }
		builder += '    ${counter.name} (${counter.originating_element.debug_description}) = ${value}\n'
	}
	builder += '}'
	return builder
}

// --- CounterStyleSystemStyleValue ---

pub struct CounterStyleSystemFixed {
pub mut:
	first_symbol ?StyleValue
}

pub type CounterStyleSystemStyleValueValue = CounterStyleSystem
	| CounterStyleSystemExtends
	| CounterStyleSystemFixed

pub struct CounterStyleSystemStyleValue {
pub mut:
	value_ CounterStyleSystemStyleValueValue
}

pub fn CounterStyleSystemStyleValue.create(system CounterStyleSystem) CounterStyleSystemStyleValue {
	return CounterStyleSystemStyleValue{
		value_: CounterStyleSystemStyleValueValue(system)
	}
}

pub fn CounterStyleSystemStyleValue.create_fixed(first_symbol ?StyleValue) CounterStyleSystemStyleValue {
	return CounterStyleSystemStyleValue{
		value_: CounterStyleSystemStyleValueValue(CounterStyleSystemFixed{
			first_symbol: first_symbol
		})
	}
}

pub fn CounterStyleSystemStyleValue.create_extends(name string) CounterStyleSystemStyleValue {
	return CounterStyleSystemStyleValue{
		value_: CounterStyleSystemStyleValueValue(CounterStyleSystemExtends{
			name: name
		})
	}
}

pub fn (style_value CounterStyleSystemStyleValue) value() CounterStyleSystemStyleValueValue {
	return style_value.value_
}

pub fn (style_value CounterStyleSystemStyleValue) serialize(mode SerializationMode) string {
	value := style_value.value_
	return match value {
		CounterStyleSystem {
			counter_style_system_to_string(value)
		}
		CounterStyleSystemFixed {
			mut serialized := 'fixed'
			if first_symbol := value.first_symbol {
				serialized += ' '
				serialized += first_symbol.serialize(mode)
			}
			serialized
		}
		CounterStyleSystemExtends {
			'extends ${serialize_an_identifier(value.name)}'
		}
	}
}

pub fn (style_value CounterStyleSystemStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value CounterStyleSystemStyleValue) absolutized(context ComputationContext) CounterStyleSystemStyleValue {
	value := style_value.value_
	return match value {
		CounterStyleSystem {
			style_value
		}
		CounterStyleSystemFixed {
			first_symbol := value.first_symbol or { return style_value }
			absolutized_value := first_symbol.absolutized(context)
			if absolutized_value == first_symbol {
				return style_value
			}
			CounterStyleSystemStyleValue.create_fixed(absolutized_value)
		}
		CounterStyleSystemExtends {
			style_value
		}
	}
}

pub fn (style_value CounterStyleSystemStyleValue) algorithm_differs_from(other CounterStyleSystemStyleValue) bool {
	if typeof(style_value.value_).name != typeof(other.value_).name {
		return true
	}

	value := style_value.value_
	return match value {
		CounterStyleSystem {
			other_value := other.value_
			if other_value is CounterStyleSystem {
				value != other_value
			} else {
				true
			}
		}
		CounterStyleSystemFixed {
			false
		}
		CounterStyleSystemExtends {
			// FIXME: We don't know which counter style the 'extends' refers to here, so we have to assume it might
			//        differ if the names differ. Is this correct?
			other_value := other.value_
			if other_value is CounterStyleSystemExtends {
				value.name != other_value.name
			} else {
				true
			}
		}
	}
}

pub fn (style_value CounterStyleSystemStyleValue) is_valid_symbol_count(count int) bool {
	value := style_value.value_
	return match value {
		CounterStyleSystem {
			match value {
				// https://drafts.csswg.org/css-counter-styles-3/#cyclic-system
				// If the system is cyclic, the symbols descriptor must contain at least one counter symbol, otherwise the
				// rule does not define a counter style (but is still a valid rule)
				.cyclic, // https://drafts.csswg.org/css-counter-styles-3/#symbolic-system
				// If the system is symbolic, the symbols descriptor must contain at least one counter symbol, otherwise the
				// rule does not define a counter style (but is still a valid rule).
				.symbolic {
					count >= 1
				}

				// https://drafts.csswg.org/css-counter-styles-3/#alphabetic-system
				// If the system is alphabetic, the symbols descriptor must contain at least two counter symbols, otherwise
				// the rule does not define a counter style (but is still a valid rule).
				.alphabetic, // https://drafts.csswg.org/css-counter-styles-3/#numeric-system
				// If the system is numeric, the symbols descriptor must contain at least two counter symbols, otherwise the
				// rule does not define a counter style (but is still a valid rule).
				.numeric {
					count >= 2
				}
				.additive {
					// NB: Additive relies on the `additive-symbols` descriptor instead and `symbols` is ignored.
					true
				}
			}
		}
		CounterStyleSystemFixed {
			// https://drafts.csswg.org/css-counter-styles-3/#fixed-system
			// If the system is fixed, the symbols descriptor must contain at least one counter symbol, otherwise the
			// rule does not define a counter style (but is still a valid rule).
			count >= 1
		}
		CounterStyleSystemExtends {
			// https://drafts.csswg.org/css-counter-styles-3/#extends-system
			// If a @counter-style uses the extends system, it must not contain a symbols or additive-symbols
			// descriptor, otherwise the rule does not define a counter style (but is still a valid rule).
			false
		}
	}
}

pub fn (style_value CounterStyleSystemStyleValue) is_valid_additive_symbol_count(count int) bool {
	value := style_value.value_
	return match value {
		CounterStyleSystem {
			// https://drafts.csswg.org/css-counter-styles-3/#additive-system
			// If the system is additive, the additive-symbols descriptor must contain at least one additive tuple,
			// otherwise the rule does not define a counter style (but is still a valid rule).
			if value == .additive {
				count >= 1
			} else {
				// NB: Other systems ignore rely on the `symbols` descriptor instead and `additive-symbols` is ignored.
				true
			}
		}
		CounterStyleSystemFixed {
			// NB: Fixed relies on the `symbols` descriptor instead and `additive-symbols` is ignored.
			true
		}
		CounterStyleSystemExtends {
			// https://drafts.csswg.org/css-counter-styles-3/#extends-system
			// If a @counter-style uses the extends system, it must not contain a symbols or additive-symbols
			// descriptor, otherwise the rule does not define a counter style (but is still a valid rule).
			false
		}
	}
}

pub fn (style_value CounterStyleSystemStyleValue) properties_equal(other CounterStyleSystemStyleValue) bool {
	return style_value.value_ == other.value_
}

// --- CounterStyleStyleValue ---

pub enum SymbolsType {
	cyclic
	numeric
	alphabetic
	symbolic
	fixed
}

pub fn symbols_type_to_string(type_ SymbolsType) string {
	return match type_ {
		.cyclic { 'cyclic' }
		.numeric { 'numeric' }
		.alphabetic { 'alphabetic' }
		.symbolic { 'symbolic' }
		.fixed { 'fixed' }
	}
}

pub fn symbols_type_from_string(name string) ?SymbolsType {
	return match to_ascii_lowercase(name) {
		'cyclic' { SymbolsType.cyclic }
		'numeric' { SymbolsType.numeric }
		'alphabetic' { SymbolsType.alphabetic }
		'symbolic' { SymbolsType.symbolic }
		'fixed' { SymbolsType.fixed }
		else { none }
	}
}

pub struct CounterStyleSymbolsFunction {
pub mut:
	type_   SymbolsType
	symbols []string
}

pub type CounterStyleStyleValueValue = CounterStyleSymbolsFunction | string

pub struct CounterStyleStyleValue {
pub mut:
	value_ CounterStyleStyleValueValue
}

pub fn CounterStyleStyleValue.create(value CounterStyleStyleValueValue) CounterStyleStyleValue {
	return CounterStyleStyleValue{
		value_: value
	}
}

pub fn CounterStyleStyleValue.create_named(name string) CounterStyleStyleValue {
	return CounterStyleStyleValue.create(CounterStyleStyleValueValue(name))
}

pub fn CounterStyleStyleValue.create_symbols(type_ SymbolsType, symbols []string) CounterStyleStyleValue {
	return CounterStyleStyleValue.create(CounterStyleStyleValueValue(CounterStyleSymbolsFunction{
		type_: type_
		symbols: symbols
	}))
}

pub fn (style_value CounterStyleStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	value := style_value.value_
	return match value {
		string {
			value
		}
		CounterStyleSymbolsFunction {
			mut serialized := 'symbols('
			if value.type_ != .symbolic {
				serialized += '${symbols_type_to_string(value.type_)} '
			}
			mut parts := []string{}
			for symbol in value.symbols {
				parts << serialize_a_string(symbol)
			}
			serialized += parts.join(' ')
			serialized += ')'
			serialized
		}
	}
}

pub fn (style_value CounterStyleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value CounterStyleStyleValue) resolve_counter_style(registered_counter_styles map[string]CounterStyle) ?CounterStyle {
	value := style_value.value_
	return match value {
		string {
			registered_counter_styles[value] or { none }
		}
		CounterStyleSymbolsFunction {
			// https://drafts.csswg.org/css-counter-styles-3/#symbols-function

			algorithm := match value.type_ {
				// The counter style’s algorithm is constructed by consulting the previous chapter using the provided
				// system — or symbolic if the system was omitted — and the provided <string>s and <image>s as the value
				// of the symbols property. If the system is fixed, the first symbol value is 1.
				.cyclic {
					CounterStyleAlgorithm(GenericCounterStyleAlgorithm{CounterStyleSystem.cyclic, value.symbols})
				}
				.numeric {
					CounterStyleAlgorithm(GenericCounterStyleAlgorithm{CounterStyleSystem.numeric, value.symbols})
				}
				.alphabetic {
					CounterStyleAlgorithm(GenericCounterStyleAlgorithm{CounterStyleSystem.alphabetic, value.symbols})
				}
				.symbolic {
					CounterStyleAlgorithm(GenericCounterStyleAlgorithm{CounterStyleSystem.symbolic, value.symbols})
				}
				.fixed {
					CounterStyleAlgorithm(FixedCounterStyleAlgorithm{
						first_symbol: 1
						symbol_list: value.symbols
					})
				}
			}

			// The symbols() function defines an anonymous counter style with no name, a prefix of "" (empty string) and
			// suffix of " " (U+0020 SPACE), a range of auto, a fallback of decimal, a negative of "\2D" ("-"
			// hyphen-minus), a pad of 0 "", and a speak-as of auto.
			// FIXME: Pass the correct speak-as value once we support that.

			definition := CounterStyleDefinition.create( // NB: We use empty string instead of no name for simplicity - this doesn't clash with
			//     <counter-style-name> since that is a <custom-ident> which can't be an empty string.
			'', CounterStyleAlgorithmOrExtends(algorithm), CounterStyleNegativeSign{
				prefix: '-'
				suffix: ''
			}, '', ' ', CounterStyleDefinitionRange(AutoRange{}), 'decimal', CounterStylePad{
				minimum_length: 0
				symbol: ''
			})

			// NB: We don't need to pass registered counter styles here since we don't rely on extension.
			CounterStyle.from_counter_style_definition(definition, map[string]CounterStyle{})
		}
	}
}

pub fn (style_value CounterStyleStyleValue) properties_equal(other CounterStyleStyleValue) bool {
	return style_value.value_ == other.value_
}

// --- CounterStyleValue ---

// https://drafts.csswg.org/css-lists-3/#counter-functions
pub enum CounterFunction {
	counter
	counters
}

pub struct CounterStyleValue {
pub mut:
	function_      CounterFunction
	counter_name_  string
	counter_style_ CounterStyleStyleValue
	join_string_   string
}

pub fn CounterStyleValue.create_counter(counter_name string, counter_style CounterStyleStyleValue) CounterStyleValue {
	return CounterStyleValue{
		function_: .counter
		counter_name_: counter_name
		counter_style_: counter_style
	}
}

pub fn CounterStyleValue.create_counters(counter_name string, join_string string, counter_style CounterStyleStyleValue) CounterStyleValue {
	return CounterStyleValue{
		function_: .counters
		counter_name_: counter_name
		counter_style_: counter_style
		join_string_: join_string
	}
}

pub fn (style_value CounterStyleValue) function_type() CounterFunction {
	return style_value.function_
}

pub fn (style_value CounterStyleValue) counter_name() string {
	return style_value.counter_name_
}

pub fn (style_value CounterStyleValue) counter_style() CounterStyleStyleValue {
	return style_value.counter_style_
}

pub fn (style_value CounterStyleValue) join_string() string {
	return style_value.join_string_
}

pub struct CounterStyleResolutionContext {
pub mut:
	counters_set              CountersSet
	registered_counter_styles map[string]CounterStyle
	originating_element       CounterOriginatingElement
}

pub fn (style_value CounterStyleValue) resolve(mut context CounterStyleResolutionContext) string {
	// "If no counter named <counter-name> exists on an element where counter() or counters() is used,
	// one is first instantiated with a starting value of 0."
	_ = context.counters_set.counter_value_for_use(style_value.counter_name_, context.originating_element)

	// counter( <counter-name>, <counter-style>? )
	// "Represents the value of the innermost counter in the element’s CSS counters set named <counter-name>
	// using the counter style named <counter-style>."
	if style_value.function_ == .counter {
		// NOTE: This should always be present because of the handling of a missing counter above.
		counter := context.counters_set.last_counter_with_name(style_value.counter_name_) or {
			return ''
		}
		return generate_a_counter_representation(style_value.counter_style_.resolve_counter_style(context.registered_counter_styles), context.registered_counter_styles, counter.value or { 0 })
	}

	// counters( <counter-name>, <string>, <counter-style>? )
	// "Represents the values of all the counters in the element’s CSS counters set named <counter-name>
	// using the counter style named <counter-style>, sorted in outermost-first to innermost-last order
	// and joined by the specified <string>."
	// NOTE: The way counters sets are inherited, this should be the order they appear in the counters set.
	mut parts := []string{}
	for counter in context.counters_set.counters() {
		if counter.name != style_value.counter_name_ {
			continue
		}

		counter_string := generate_a_counter_representation(style_value.counter_style_.resolve_counter_style(context.registered_counter_styles), context.registered_counter_styles, counter.value or { 0 })
		parts << counter_string
	}
	return parts.join(style_value.join_string_)
}

pub fn (style_value CounterStyleValue) resolve_for_abstract_element(abstract_element &dom.AbstractElement, registered_counter_styles map[string]CounterStyle) string {
	mut counters_set := ensure_counters_set_for_abstract_element(abstract_element)
	parent := abstract_element.parent_element()
	origin := CounterOriginatingElement{
		id: abstract_element.element().as_node().unique_id().value() * 16 + if pseudo := abstract_element.pseudo_element() {
			i64(int(pseudo) + 1)
		} else {
			0
		}
		parent_id: if parent_element := parent {
			parent_element.as_node().unique_id().value() * 16
		} else {
			none
		}
		debug_description: abstract_element.debug_description()
	}
	mut context := CounterStyleResolutionContext{
		counters_set: *counters_set
		registered_counter_styles: registered_counter_styles
		originating_element: origin
	}
	result := style_value.resolve(mut context)
	unsafe {
		*counters_set = context.counters_set
	}
	return result
}

// https://drafts.csswg.org/cssom-1/#ref-for-typedef-counter
pub fn (style_value CounterStyleValue) serialize(mode SerializationMode) string {
	// The return value of the following algorithm:
	// 1. Let s be the empty string.
	// (We use builder instead)

	mut serialized := ''

	// 2. If <counter> has three CSS component values append the string "counters(" to s.
	if style_value.function_ == .counters {
		serialized += 'counters('
	// 3. If <counter> has two CSS component values append the string "counter(" to s.
	} else if style_value.function_ == .counter {
		serialized += 'counter('
	}

	// 4. Let list be a list of CSS component values belonging to <counter>,
	//    omitting the last CSS component value if it is "decimal".
	mut list := []string{}
	list << serialize_an_identifier(style_value.counter_name_)
	if style_value.function_ == .counters {
		list << serialize_a_string(style_value.join_string_)
	}
	if style_value.counter_style_.serialize(mode) != 'decimal' {
		list << style_value.counter_style_.serialize(mode)
	}

	// 5. Let each item in list be the result of invoking serialize a CSS component value on that item.
	// 6. Append the result of invoking serialize a comma-separated list on list to s.
	serialized += list.join(', ')

	// 7. Append ")" (U+0029) to s.
	serialized += ')'
	return serialized
}

pub fn (style_value CounterStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value CounterStyleValue) properties_equal(other CounterStyleValue) bool {
	return style_value == other
}

// --- CounterDefinitionsStyleValue ---

pub struct CounterDefinition {
pub mut:
	name        string
	is_reversed bool
	value       ?StyleValue
}

/**
 * Holds a list of CounterDefinitions.
 * Shared between counter-increment, counter-reset, and counter-set properties that have (almost) identical grammar.
 */
pub struct CounterDefinitionsStyleValue {
pub mut:
	counter_definitions_ []CounterDefinition
}

pub fn CounterDefinitionsStyleValue.create(counter_definitions []CounterDefinition) CounterDefinitionsStyleValue {
	return CounterDefinitionsStyleValue{
		counter_definitions_: counter_definitions
	}
}

pub fn (style_value CounterDefinitionsStyleValue) counter_definitions() []CounterDefinition {
	return style_value.counter_definitions_
}

pub fn (style_value CounterDefinitionsStyleValue) serialize(mode SerializationMode) string {
	mut parts := []string{}
	for counter_definition in style_value.counter_definitions_ {
		mut part := ''
		if counter_definition.is_reversed {
			part += 'reversed(${counter_definition.name})'
		} else {
			part += counter_definition.name
		}

		if value := counter_definition.value {
			part += ' '
			part += value.serialize(mode)
		}
		parts << part
	}
	return parts.join(' ')
}

pub fn (style_value CounterDefinitionsStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value CounterDefinitionsStyleValue) absolutized(computation_context ComputationContext) CounterDefinitionsStyleValue {
	mut computed_definitions := []CounterDefinition{}

	for specified_definition in style_value.counter_definitions_ {
		mut computed_definition := CounterDefinition{
			name: specified_definition.name
			is_reversed: specified_definition.is_reversed
			value: none
		}

		if value := specified_definition.value {
			computed_definition.value = value.absolutized(computation_context)
		}

		computed_definitions << computed_definition
	}

	return CounterDefinitionsStyleValue.create(computed_definitions)
}

pub fn (style_value CounterDefinitionsStyleValue) properties_equal(other CounterDefinitionsStyleValue) bool {
	if style_value.counter_definitions_.len != other.counter_definitions().len {
		return false
	}

	for i := 0; i < style_value.counter_definitions_.len; i++ {
		ours := style_value.counter_definitions_[i]
		theirs := other.counter_definitions()[i]
		if ours.name != theirs.name || ours.is_reversed != theirs.is_reversed
			|| ours.value != theirs.value {
			return false
		}
	}
	return true
}

// --- Counter descriptor style-value stubs used by CounterStyleDefinition ---

pub struct CounterStyleSymbolListStyleValue {
pub mut:
	values []StyleValue
}

pub fn CounterStyleSymbolListStyleValue.create(values []StyleValue) CounterStyleSymbolListStyleValue {
	return CounterStyleSymbolListStyleValue{
		values: values
	}
}

pub fn (style_value CounterStyleSymbolListStyleValue) serialize(mode SerializationMode) string {
	mut parts := []string{}
	for value in style_value.values {
		parts << value.serialize(mode)
	}
	return parts.join(' ')
}

pub struct CounterStyleAdditiveSymbolTupleStyleValue {
pub mut:
	weight StyleValue
	symbol StyleValue
}

pub struct CounterStyleAdditiveSymbolsStyleValue {
pub mut:
	tuples []CounterStyleAdditiveSymbolTupleStyleValue
}

pub fn CounterStyleAdditiveSymbolsStyleValue.create(tuples []CounterStyleAdditiveSymbolTupleStyleValue) CounterStyleAdditiveSymbolsStyleValue {
	return CounterStyleAdditiveSymbolsStyleValue{
		tuples: tuples
	}
}

pub fn (style_value CounterStyleAdditiveSymbolsStyleValue) serialize(mode SerializationMode) string {
	mut parts := []string{}
	for tuple in style_value.tuples {
		parts << '${tuple.weight.serialize(mode)} ${tuple.symbol.serialize(mode)}'
	}
	return parts.join(', ')
}

pub struct CounterStyleInfinite {}

pub type CounterStyleRangeBound = CounterStyleInfinite | StyleValue

pub struct CounterStyleRangeStyleValueEntry {
pub mut:
	start CounterStyleRangeBound
	end   CounterStyleRangeBound
}

pub struct CounterStyleRangeStyleValue {
pub mut:
	auto_   bool
	entries []CounterStyleRangeStyleValueEntry
}

pub fn CounterStyleRangeStyleValue.create_auto() CounterStyleRangeStyleValue {
	return CounterStyleRangeStyleValue{
		auto_: true
	}
}

pub fn CounterStyleRangeStyleValue.create(entries []CounterStyleRangeStyleValueEntry) CounterStyleRangeStyleValue {
	return CounterStyleRangeStyleValue{
		entries: entries
	}
}

pub fn (style_value CounterStyleRangeStyleValue) serialize(mode SerializationMode) string {
	if style_value.auto_ {
		return 'auto'
	}
	mut parts := []string{}
	for entry in style_value.entries {
		parts << '${serialize_counter_style_range_bound(entry.start, mode)} ${serialize_counter_style_range_bound(entry.end, mode)}'
	}
	return parts.join(', ')
}

pub struct CounterStylePadStyleValue {
pub mut:
	minimum_length StyleValue
	symbol         StyleValue
}

pub fn CounterStylePadStyleValue.create(minimum_length StyleValue, symbol StyleValue) CounterStylePadStyleValue {
	return CounterStylePadStyleValue{
		minimum_length: minimum_length
		symbol: symbol
	}
}

pub fn (style_value CounterStylePadStyleValue) serialize(mode SerializationMode) string {
	return '${style_value.minimum_length.serialize(mode)} ${style_value.symbol.serialize(mode)}'
}

// CSSCounterStyleRule translation so CounterStyleDefinition::from_counter_style_rule can keep its logic.
@[heap]
pub struct CSSCounterStyleRule {
pub mut:
	name_                         string
	system_style_value_           ?CounterStyleSystemStyleValue
	negative_style_value_         ?CounterStyleSymbolListStyleValue
	prefix_style_value_           ?StyleValue
	suffix_style_value_           ?StyleValue
	range_style_value_            ?CounterStyleRangeStyleValue
	pad_style_value_              ?CounterStylePadStyleValue
	fallback_style_value_         ?StyleValue
	symbols_style_value_          ?CounterStyleSymbolListStyleValue
	additive_symbols_style_value_ ?CounterStyleAdditiveSymbolsStyleValue
	speak_as_style_value_         ?StyleValue
	parent_style_sheet_           ?&CSSStyleSheet
}

pub fn CSSCounterStyleRule.create(name string, system ?CounterStyleSystemStyleValue, negative ?CounterStyleSymbolListStyleValue, prefix ?StyleValue, suffix ?StyleValue, range ?CounterStyleRangeStyleValue, pad ?CounterStylePadStyleValue, fallback ?StyleValue, symbols ?CounterStyleSymbolListStyleValue, additive_symbols ?CounterStyleAdditiveSymbolsStyleValue, speak_as ?StyleValue) &CSSCounterStyleRule {
	return &CSSCounterStyleRule{
		name_: name
		system_style_value_: system
		negative_style_value_: negative
		prefix_style_value_: prefix
		suffix_style_value_: suffix
		range_style_value_: range
		pad_style_value_: pad
		fallback_style_value_: fallback
		symbols_style_value_: symbols
		additive_symbols_style_value_: additive_symbols
		speak_as_style_value_: speak_as
	}
}

pub fn (rule &CSSCounterStyleRule) name() string {
	return rule.name_
}

// https://drafts.csswg.org/css-counter-styles-3/#dom-csscounterstylerule-name
pub fn (mut rule CSSCounterStyleRule) set_name(name string) {
	// On setting the name attribute, run the following steps:

	// 1. If the value is an ASCII case-insensitive match for "none" or one of the non-overridable counter-style names, do nothing and return.
	if equals_ignoring_ascii_case(name, 'none')
		|| css_counter_style_rule_matches_non_overridable_counter_style_name(name) {
		return
	}

	// 2. If the value is an ASCII case-insensitive match for any of the predefined counter styles, lowercase it.
	// 3. Replace the associated rule's name with an identifier equal to the value.
	rule.name_ = if is_predefined_counter_style_name(name) { name.to_lower() } else { name }
	rule.clear_caches()
}

pub fn (rule &CSSCounterStyleRule) system() string {
	system := rule.system_style_value_ or { return '' }
	return system.serialize(.normal)
}

// https://drafts.csswg.org/css-counter-styles-3/#dom-csscounterstylerule-system
pub fn (mut rule CSSCounterStyleRule) set_system(system string) {
	// 1. parse the given value as the descriptor associated with the attribute.
	value := parse_counter_style_system_descriptor_value(system) or { return }

	// 2. If the result is invalid according to the given descriptor's grammar, or would cause the @counter-style rule
	//    to not define a counter style, do nothing and abort these steps. (For example, some systems require the
	//    symbols descriptor to contain two values.)
	// NB: Since we only allow changing parameters of the system, not the algorithm itself (see below), we know this
	//     change can't cause the @counter-style to not define a counter style.

	// 3. If the attribute being set is system, and the new value would change the algorithm used, do nothing and abort
	//    these steps.
	// Note: It's okay to change an aspect of the algorithm, like the first symbol value of a fixed system.
	current_system := rule.system_style_value_ or { return }
	if current_system.algorithm_differs_from(value) {
		return
	}

	// 4. Set the descriptor to the value.
	rule.system_style_value_ = value
	rule.clear_caches()
}

pub fn (rule &CSSCounterStyleRule) system_style_value() ?CounterStyleSystemStyleValue {
	return rule.system_style_value_
}

pub fn (rule &CSSCounterStyleRule) negative() string {
	negative := rule.negative_style_value_ or { return '' }
	return negative.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_negative(negative string) {
	if value := parse_counter_style_symbol_list_descriptor_value(negative) {
		rule.negative_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) negative_style_value() ?CounterStyleSymbolListStyleValue {
	return rule.negative_style_value_
}

pub fn (rule &CSSCounterStyleRule) prefix() string {
	prefix := rule.prefix_style_value_ or { return '' }
	return prefix.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_prefix(prefix string) {
	if value := parse_counter_style_symbol_descriptor_value(prefix) {
		rule.prefix_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) prefix_style_value() ?StyleValue {
	return rule.prefix_style_value_
}

pub fn (rule &CSSCounterStyleRule) suffix() string {
	suffix := rule.suffix_style_value_ or { return '' }
	return suffix.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_suffix(suffix string) {
	if value := parse_counter_style_symbol_descriptor_value(suffix) {
		rule.suffix_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) suffix_style_value() ?StyleValue {
	return rule.suffix_style_value_
}

pub fn (rule &CSSCounterStyleRule) range() string {
	range := rule.range_style_value_ or { return '' }
	return range.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_range(range string) {
	if value := parse_counter_style_range_descriptor_value(range) {
		rule.range_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) range_style_value() ?CounterStyleRangeStyleValue {
	return rule.range_style_value_
}

pub fn (rule &CSSCounterStyleRule) pad() string {
	pad := rule.pad_style_value_ or { return '' }
	return pad.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_pad(pad string) {
	if value := parse_counter_style_pad_descriptor_value(pad) {
		rule.pad_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) pad_style_value() ?CounterStylePadStyleValue {
	return rule.pad_style_value_
}

pub fn (rule &CSSCounterStyleRule) fallback() string {
	fallback := rule.fallback_style_value_ or { return '' }
	return fallback.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_fallback(fallback string) {
	if value := parse_counter_style_name_descriptor_value(fallback) {
		rule.fallback_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (rule &CSSCounterStyleRule) fallback_style_value() ?StyleValue {
	return rule.fallback_style_value_
}

pub fn (rule &CSSCounterStyleRule) symbols() string {
	symbols := rule.symbols_style_value_ or { return '' }
	return symbols.serialize(.normal)
}

// https://drafts.csswg.org/css-counter-styles-3/#dom-csscounterstylerule-symbols
pub fn (mut rule CSSCounterStyleRule) set_symbols(symbols string) {
	// On setting, run the following steps:

	// 1. parse the given value as the descriptor associated with the attribute.
	value := parse_counter_style_symbol_list_descriptor_value(symbols) or { return }

	// 2. If the result is invalid according to the given descriptor's grammar, or would cause the @counter-style rule
	//    to not define a counter style, do nothing and abort these steps. (For example, some systems require the
	//    symbols descriptor to contain two values.)
	if system := rule.system_style_value_ {
		if !system.is_valid_symbol_count(value.values.len) {
			return
		}
	}

	// 3. If the attribute being set is system, and the new value would change the algorithm used, do nothing and abort
	//    these steps. It's okay to change an aspect of the algorithm, like the first symbol value of a fixed system.

	// 4. Set the descriptor to the value.
	rule.symbols_style_value_ = value
	rule.clear_caches()
}

pub fn (rule &CSSCounterStyleRule) symbols_style_value() ?CounterStyleSymbolListStyleValue {
	return rule.symbols_style_value_
}

pub fn (rule &CSSCounterStyleRule) additive_symbols() string {
	additive_symbols := rule.additive_symbols_style_value_ or { return '' }
	return additive_symbols.serialize(.normal)
}

// https://drafts.csswg.org/css-counter-styles-3/#dom-csscounterstylerule-additivesymbols
pub fn (mut rule CSSCounterStyleRule) set_additive_symbols(additive_symbols string) {
	// On setting, run the following steps:

	// 1. parse the given value as the descriptor associated with the attribute.
	value := parse_counter_style_additive_symbols_descriptor_value(additive_symbols) or { return }

	// 2. If the result is invalid according to the given descriptor's grammar, or would cause the @counter-style rule
	//    to not define a counter style, do nothing and abort these steps. (For example, some systems require the
	//    symbols descriptor to contain two values.)
	if system := rule.system_style_value_ {
		if !system.is_valid_additive_symbol_count(value.tuples.len) {
			return
		}
	}

	// 3. If the attribute being set is system, and the new value would change the algorithm used, do nothing and abort
	//    these steps. It's okay to change an aspect of the algorithm, like the first symbol value of a fixed system.

	// 4. Set the descriptor to the value.
	rule.additive_symbols_style_value_ = value
	rule.clear_caches()
}

pub fn (rule &CSSCounterStyleRule) additive_symbols_style_value() ?CounterStyleAdditiveSymbolsStyleValue {
	return rule.additive_symbols_style_value_
}

pub fn (rule &CSSCounterStyleRule) speak_as() string {
	speak_as := rule.speak_as_style_value_ or { return '' }
	return speak_as.serialize(.normal)
}

pub fn (mut rule CSSCounterStyleRule) set_speak_as(speak_as string) {
	if value := parse_counter_style_speak_as_descriptor_value(speak_as) {
		rule.speak_as_style_value_ = value
		rule.clear_caches()
	}
}

pub fn (mut rule CSSCounterStyleRule) set_parent_style_sheet(parent_style_sheet ?&CSSStyleSheet) {
	rule.clear_caches()
	rule.parent_style_sheet_ = parent_style_sheet
	rule.clear_caches()
}

pub fn (mut rule CSSCounterStyleRule) clear_caches() {
	sheet := rule.parent_style_sheet_ or { return }
	sheet.for_each_owning_style_scope(fn (scope &StyleScope) {
		mut mutable_scope := unsafe { &StyleScope(scope) }
		mutable_scope.invalidate_counter_style_cache()
		owner := scope.node_ref() or { return }
		mut mutable_owner := unsafe { &dom.Node(owner) }
		mutable_owner.invalidate_style(.counter_style_cache_invalidated)
	})
}

pub fn (rule &CSSCounterStyleRule) speak_as_style_value() ?StyleValue {
	return rule.speak_as_style_value_
}

pub fn (rule &CSSCounterStyleRule) serialized() string {
	mut parts := []string{}
	if value := rule.system_style_value_ {
		parts << 'system: ${value.serialize(.normal)};'
	}
	if value := rule.negative_style_value_ {
		parts << 'negative: ${value.serialize(.normal)};'
	}
	if value := rule.prefix_style_value_ {
		parts << 'prefix: ${value.to_string()};'
	}
	if value := rule.suffix_style_value_ {
		parts << 'suffix: ${value.to_string()};'
	}
	if value := rule.range_style_value_ {
		parts << 'range: ${value.serialize(.normal)};'
	}
	if value := rule.pad_style_value_ {
		parts << 'pad: ${value.serialize(.normal)};'
	}
	if value := rule.fallback_style_value_ {
		parts << 'fallback: ${value.to_string()};'
	}
	if value := rule.symbols_style_value_ {
		parts << 'symbols: ${value.serialize(.normal)};'
	}
	if value := rule.additive_symbols_style_value_ {
		parts << 'additive-symbols: ${value.serialize(.normal)};'
	}
	if value := rule.speak_as_style_value_ {
		parts << 'speak-as: ${value.to_string()};'
	}
	if parts.len == 0 {
		return '@counter-style ${serialize_an_identifier(rule.name_)} { }'
	}
	return '@counter-style ${serialize_an_identifier(rule.name_)} { ${parts.join(' ')} }'
}

fn serialize_counter_style_range_bound(bound CounterStyleRangeBound, mode SerializationMode) string {
	return match bound {
		CounterStyleInfinite { 'infinite' }
		StyleValue { bound.serialize(mode) }
	}
}

fn resolve_counter_style_range_bound(bound CounterStyleRangeBound, infinite_value i64, computation_context ComputationContext) i64 {
	return match bound {
		CounterStyleInfinite { infinite_value }
		StyleValue { int_from_style_value(bound.absolutized(computation_context)) }
	}
}

fn counter_symbol_from_code_point(code_point u32) string {
	return string_from_code_point(code_point)
}

fn counter_symbol_from_code_points(code_points []u32) string {
	mut result := ''
	for code_point in code_points {
		result += counter_symbol_from_code_point(code_point)
	}
	return result
}

fn extended_cjk_type_is_one_of(type_ ExtendedCJKCounterStyleAlgorithmType, types []ExtendedCJKCounterStyleAlgorithmType) bool {
	for item in types {
		if type_ == item {
			return true
		}
	}
	return false
}

fn positive_mod_i64(value i64, modulus int) int {
	m := i64(modulus)
	mut result := value % m
	if result < 0 {
		result += m
	}
	return int(result)
}

fn clamp_i64_to_i32(value i64) i32 {
	if value < counter_i32_min {
		return counter_i32_min
	}
	if value > counter_i32_max {
		return counter_i32_max
	}
	return i32(value)
}

fn saturating_add_counter_value(left CounterValue, right CounterValue) CounterValue {
	return CounterValue(clamp_i64_to_i32(i64(left) + i64(right)))
}

fn generate_extended_cjk_counter_style(value i64, type_ ExtendedCJKCounterStyleAlgorithmType) string {
	return match type_ {
		// | Values                | Codepoints
		// |                       | simp-chinese-informal |  simp-chinese-formal |  trad-chinese-informal | trad-chinese-formal
		// | Digit 0               | 零 U+96F6             | 零 U+96F6            | 零 U+96F6              | 零 U+96F6
		// | Digit 1               | 一 U+4E00             | 壹 U+58F9            | 一 U+4E00              | 壹 U+58F9
		// | Digit 2               | 二 U+4E8C             | 贰 U+8D30            | 二 U+4E8C              | 貳 U+8CB3
		// | Digit 3               | 三 U+4E09             | 叁 U+53C1            | 三 U+4E09              | 參 U+53C3
		// | Digit 4               | 四 U+56DB             | 肆 U+8086            | 四 U+56DB              | 肆 U+8086
		// | Digit 5               | 五 U+4E94             | 伍 U+4F0D            | 五 U+4E94              | 伍 U+4F0D
		// | Digit 6               | 六 U+516D             | 陆 U+9646            | 六 U+516D              | 陸 U+9678
		// | Digit 7               | 七 U+4E03             | 柒 U+67D2            | 七 U+4E03              | 柒 U+67D2
		// | Digit 8               | 八 U+516B             | 捌 U+634C            | 八 U+516B              | 捌 U+634C
		// | Digit 9               | 九 U+4E5D             | 玖 U+7396            | 九 U+4E5D              | 玖 U+7396
		// | Second Digit Marker   | 十 U+5341             | 拾 U+62FE            | 十 U+5341              | 拾 U+62FE
		// | Third Digit Marker    | 百 U+767E             | 佰 U+4F70            | 百 U+767E              | 佰 U+4F70
		// | Fourth Digit Marker   | 千 U+5343             | 仟 U+4EDF            | 千 U+5343              | 仟 U+4EDF
		// | Second Group Marker   | 万 U+4E07             | 万 U+4E07            | 萬 U+842C              | 萬 U+842C
		// | Third Group Marker    | 亿 U+4EBF             | 亿 U+4EBF            | 億 U+5104              | 億 U+5104
		// | Fourth Group Marker   | 万亿 U+4E07 U+4EBF    | 万亿 U+4E07 U+4EBF    | 兆 U+5146             | 兆 U+5146
		.simp_chinese_informal {
			generate_an_initial_representation_for_extended_cjk_system(value, .simp_chinese_informal, code_point_symbols([
				u32(0x96f6),
				0x4e00,
				0x4e8c,
				0x4e09,
				0x56db,
				0x4e94,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), code_point_symbols([
				u32(0x5341),
				0x767e,
				0x5343,
			]), [
				counter_symbol_from_code_point(0x4e07),
				counter_symbol_from_code_point(0x4ebf),
				counter_symbol_from_code_points([u32(0x4e07), 0x4ebf]),
			])
		}
		.simp_chinese_formal {
			generate_an_initial_representation_for_extended_cjk_system(value, .simp_chinese_formal, code_point_symbols([
				u32(0x96f6),
				0x58f9,
				0x8d30,
				0x53c1,
				0x8086,
				0x4f0d,
				0x9646,
				0x67d2,
				0x634c,
				0x7396,
			]), code_point_symbols([u32(0x62fe), 0x4f70, 0x4edf]), [
				counter_symbol_from_code_point(0x4e07),
				counter_symbol_from_code_point(0x4ebf),
				counter_symbol_from_code_points([u32(0x4e07), 0x4ebf]),
			])
		}
		.trad_chinese_informal {
			generate_an_initial_representation_for_extended_cjk_system(value, .trad_chinese_informal, code_point_symbols([
				u32(0x96f6),
				0x4e00,
				0x4e8c,
				0x4e09,
				0x56db,
				0x4e94,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), code_point_symbols([
				u32(0x5341),
				0x767e,
				0x5343,
			]), code_point_symbols([u32(0x842c), 0x5104, 0x5146]))
		}
		.trad_chinese_formal {
			generate_an_initial_representation_for_extended_cjk_system(value, .trad_chinese_formal, code_point_symbols([
				u32(0x96f6),
				0x58f9,
				0x8cb3,
				0x53c3,
				0x8086,
				0x4f0d,
				0x9678,
				0x67d2,
				0x634c,
				0x7396,
			]), code_point_symbols([u32(0x62fe), 0x4f70, 0x4edf]), code_point_symbols([
				u32(0x842c),
				0x5104,
				0x5146,
			]))
		}

		// Values              | Codepoints
		//                     | japanese-informal | japanese-formal
		// Digit 0             | 〇 U+3007         | 零 U+96F6
		// Digit 1             | 一 U+4E00         | 壱 U+58F1
		// Digit 2             | 二 U+4E8C         | 弐 U+5F10
		// Digit 3             | 三 U+4E09         | 参 U+53C2
		// Digit 4             | 四 U+56DB         | 四 U+56DB
		// Digit 5             | 五 U+4E94         | 伍 U+4f0D
		// Digit 6             | 六 U+516D         | 六 U+516D
		// Digit 7             | 七 U+4E03         | 七 U+4E03
		// Digit 8             | 八 U+516B         | 八 U+516B
		// Digit 9             | 九 U+4E5D         | 九 U+4E5D
		// Second Digit Marker | 十 U+5341         | 拾 U+62FE
		// Third Digit Marker  | 百 U+767E         | 百 U+767E
		// Fourth Digit Marker | 千 U+5343         | 阡 U+9621
		// Second Group Marker | 万 U+4E07         | 萬 U+842C
		// Third Group Marker  | 億 U+5104         | 億 U+5104
		// Fourth Group Marker | 兆 U+5146         | 兆 U+5146
		.japanese_informal {
			generate_an_initial_representation_for_extended_cjk_system(value, .japanese_informal, code_point_symbols([
				u32(0x3007),
				0x4e00,
				0x4e8c,
				0x4e09,
				0x56db,
				0x4e94,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), code_point_symbols([u32(0x5341), 0x767e, 0x5343]), code_point_symbols([
				u32(0x4e07),
				0x5104,
				0x5146,
			]))
		}
		.japanese_formal {
			generate_an_initial_representation_for_extended_cjk_system(value, .japanese_formal, code_point_symbols([
				u32(0x96f6),
				0x58f1,
				0x5f10,
				0x53c2,
				0x56db,
				0x4f0d,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), [
				counter_symbol_from_code_point(0x62fe),
				counter_symbol_from_code_point(0x767e),
				counter_symbol_from_code_point(0x9621),
			], code_point_symbols([u32(0x842c), 0x5104, 0x5146]))
		}

		// Values              | Codepoints
		//                     | korean-hangul-formal | korean-hanja-informal | korean-hanja-formal
		// Digit 0             | 영 U+C601            |  零 U+96F6            | 零 U+96F6
		// Digit 1             | 일 U+C77C            |  一 U+4E00            | 壹 U+58F9
		// Digit 2             | 이 U+C774            |  二 U+4E8C            | 貳 U+8CB3
		// Digit 3             | 삼 U+C0BC            |  三 U+4E09            | 參 U+53C3
		// Digit 4             | 사 U+C0AC            |  四 U+56DB            | 四 U+56DB
		// Digit 5             | 오 U+C624            |  五 U+4E94            | 五 U+4E94
		// Digit 6             | 육 U+C721            |  六 U+516D            | 六 U+516D
		// Digit 7             | 칠 U+CE60            |  七 U+4E03            | 七 U+4E03
		// Digit 8             | 팔 U+D314            |  八 U+516B            | 八 U+516B
		// Digit 9             | 구 U+AD6C            |  九 U+4E5D            | 九 U+4E5D
		// Second Digit Marker | 십 U+C2ED            |  十 U+5341            | 拾 U+62FE
		// Third Digit Marker  | 백 U+BC31            |  百 U+767E            | 百 U+767E
		// Fourth Digit Marker | 천 U+CC9C            |  千 U+5343            | 仟 U+4EDF
		// Second Group Marker | 만 U+B9CC            |  萬 U+842C            | 萬 U+842C
		// Third Group Marker  | 억 U+C5B5            |  億 U+5104            | 億 U+5104
		// Fourth Group Marker | 조 U+C870            |  兆 U+5146            | 兆 U+5146
		.korean_hangul_formal {
			generate_an_initial_representation_for_extended_cjk_system(value, .korean_hangul_formal, code_point_symbols([
				u32(0xc601),
				0xc77c,
				0xc774,
				0xc0bc,
				0xc0ac,
				0xc624,
				0xc721,
				0xce60,
				0xd314,
				0xad6c,
			]), code_point_symbols([
				u32(0xc2ed),
				0xbc31,
				0xcc9c,
			]), code_point_symbols([u32(0xb9cc), 0xc5b5, 0xc870]))
		}
		.korean_hanja_informal {
			generate_an_initial_representation_for_extended_cjk_system(value, .korean_hanja_informal, code_point_symbols([
				u32(0x96f6),
				0x4e00,
				0x4e8c,
				0x4e09,
				0x56db,
				0x4e94,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), code_point_symbols([
				u32(0x5341),
				0x767e,
				0x5343,
			]), code_point_symbols([u32(0x842c), 0x5104, 0x5146]))
		}
		.korean_hanja_formal {
			generate_an_initial_representation_for_extended_cjk_system(value, .korean_hanja_formal, code_point_symbols([
				u32(0x96f6),
				0x58f9,
				0x8cb3,
				0x53c3,
				0x56db,
				0x4e94,
				0x516d,
				0x4e03,
				0x516b,
				0x4e5d,
			]), [
				counter_symbol_from_code_point(0x62fe),
				counter_symbol_from_code_point(0x767e),
				counter_symbol_from_code_point(0x4edf),
			], code_point_symbols([u32(0x842c), 0x5104, 0x5146]))
		}
	}
}

fn code_point_symbols(code_points []u32) []string {
	mut symbols := []string{cap: code_points.len}
	for code_point in code_points {
		symbols << counter_symbol_from_code_point(code_point)
	}
	return symbols
}
