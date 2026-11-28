// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

// Runtime/Intl/AbstractOperations.cpp and Unicode locale identifiers. String
// options remain UTF-16 until ASCII grammar validation, including lone surrogates.
pub struct IntlLocaleIdentifier {
pub mut:
	language string
	script string
	region string
	variants []string
	attributes []string
	keywords map[string]string
	extensions map[string][]string
	private_use []string
}

fn intl_alpha(text string) bool { return text.len > 0 && text.bytes().all((it >= `a` && it <= `z`) || (it >= `A` && it <= `Z`)) }
fn intl_digits(text string) bool { return text.len > 0 && text.bytes().all(it >= `0` && it <= `9`) }
fn intl_alnum(text string) bool { return text.len > 0 && text.bytes().all((it >= `a` && it <= `z`) || (it >= `A` && it <= `Z`) || (it >= `0` && it <= `9`)) }
fn intl_language_subtag(text string) bool { return (text.len in [2, 3] || (text.len >= 5 && text.len <= 8)) && intl_alpha(text) }
fn intl_region_subtag(text string) bool { return (text.len == 2 && intl_alpha(text)) || (text.len == 3 && intl_digits(text)) }
fn intl_variant_subtag(text string) bool { return intl_alnum(text) && ((text.len >= 5 && text.len <= 8) || (text.len == 4 && text[0] >= `0` && text[0] <= `9`)) }
fn intl_type_identifier(text string) bool { return text.split('-').all(it.len >= 3 && it.len <= 8 && intl_alnum(it)) }

fn intl_ascii(mut vm VM, text Utf16String) !string {
	mut bytes := []u8{cap: text.data.len}
	for index, unit in text.data {
		if index % 64 == 0 { vm.consume_execution_budget()! }
		if unit > 0x7f { return vm.throw_error(.range_error, 'Invalid Unicode locale identifier or option') }
		bytes << u8(unit)
	}
	return bytes.bytestr()
}

fn intl_parse_base(mut vm VM, subtags []string) !(IntlLocaleIdentifier, int) {
	if subtags.len == 0 || !intl_language_subtag(subtags[0]) { return vm.throw_error(.range_error, 'Invalid Unicode language subtag') }
	mut result := IntlLocaleIdentifier{language: subtags[0].to_lower()}
	mut index := 1
	if index < subtags.len && subtags[index].len == 4 && intl_alpha(subtags[index]) {
		script := subtags[index].to_lower(); result.script = script[..1].to_upper() + script[1..]; index++
	}
	if index < subtags.len && intl_region_subtag(subtags[index]) { result.region = subtags[index].to_upper(); index++ }
	mut seen := map[string]bool{}
	for index < subtags.len && intl_variant_subtag(subtags[index]) {
		vm.consume_execution_budget()!
		variant := subtags[index].to_lower()
		if seen[variant] { return vm.throw_error(.range_error, 'Duplicate Unicode locale variant') }
		seen[variant] = true; result.variants << variant; index++
	}
	return result, index
}

fn intl_parse_language_tag(mut vm VM, text Utf16String) !IntlLocaleIdentifier {
	input := intl_ascii(mut vm, text)!.to_lower().split('-')
	mut result, mut index := intl_parse_base(mut vm, input)!
	mut seen := map[string]bool{}
	for index < input.len {
		vm.consume_execution_budget()!
		key := input[index]
		if key.len != 1 || !intl_alnum(key) || seen[key] { return vm.throw_error(.range_error, 'Invalid or duplicate Unicode locale extension') }
		seen[key] = true; index++
		start := index
		if key == 'x' {
			for index < input.len {
				if input[index].len < 1 || input[index].len > 8 || !intl_alnum(input[index]) { return vm.throw_error(.range_error, 'Invalid locale private use') }
				index++
			}
		} else {
			for index < input.len && input[index].len >= 2 && input[index].len <= 8 && intl_alnum(input[index]) { index++ }
		}
		if index == start { return vm.throw_error(.range_error, 'Empty Unicode locale extension') }
		values := input[start..index]
		if key == 'x' { result.private_use = values.clone(); break }
		if key == 'u' {
			mut at := 0
			for at < values.len && values[at].len >= 3 {
				if values[at] !in result.attributes { result.attributes << values[at] }; at++
			}
			for at < values.len {
				keyword := values[at]
				if keyword.len != 2 || !intl_alpha(keyword[1..]) { return vm.throw_error(.range_error, 'Invalid Unicode locale keyword') }
				at++; from := at
				for at < values.len && values[at].len >= 3 { at++ }
				if keyword !in result.keywords { result.keywords[keyword] = values[from..at].join('-') }
			}
		} else if key == 't' {
			mut at := 0
			mut transformed := []string{}
			if intl_language_subtag(values[0]) {
				language, used := intl_parse_base(mut vm, values)!
				canonical := intl_canonical_base(mut vm, language)!
				transformed << canonical.base_name().to_lower().split('-'); at = used
			}
			mut fields := map[string][]string{}
			for at < values.len {
				field := values[at]
				if field.len != 2 || !intl_alpha(field[..1]) || !intl_digits(field[1..]) { return vm.throw_error(.range_error, 'Invalid transformed locale field') }
				at++; from := at
				for at < values.len && values[at].len >= 3 { at++ }
				if from == at { return vm.throw_error(.range_error, 'Empty transformed locale field') }
				if field !in fields { fields[field] = values[from..at].clone() }
			}
			mut keys := fields.keys(); keys.sort()
			for field in keys { transformed << field; transformed << fields[field] }
			result.extensions[key] = transformed
		} else { result.extensions[key] = values.clone() }
	}
	return result
}

pub fn (id IntlLocaleIdentifier) base_name() string {
	mut parts := [id.language]
	if id.script != '' { parts << id.script }
	if id.region != '' { parts << id.region }
	parts << id.variants
	return parts.join('-')
}

pub fn (id IntlLocaleIdentifier) tag() string {
	mut output := [id.base_name()]
	mut extensions := id.extensions.clone()
	mut unicode := id.attributes.clone(); unicode.sort()
	mut keys := id.keywords.keys(); keys.sort()
	for key in keys {
		unicode << key
		if id.keywords[key] != '' && id.keywords[key] != 'true' { unicode << id.keywords[key].split('-') }
	}
	if unicode.len > 0 { extensions['u'] = unicode }
	mut singleton_keys := extensions.keys(); singleton_keys.sort()
	for key in singleton_keys { output << key; output << extensions[key] }
	if id.private_use.len > 0 { output << 'x'; output << id.private_use }
	return output.join('-')
}

fn intl_canonical_base(mut vm VM, original IntlLocaleIdentifier) !IntlLocaleIdentifier {
	core := intl_core_data(mut vm)!
	mut id := original
	for rule in core.language_rules {
		vm.consume_execution_budget()!
		if rule.language != 'und' && rule.language != id.language { continue }
		if rule.script != '' && rule.script != id.script { continue }
		if rule.region != '' && rule.region != id.region { continue }
		if !rule.variants.all(it in id.variants) { continue }
		base, _ := intl_parse_base(mut vm, rule.replacement.split('-'))!
		if base.language != 'und' { id.language = base.language }
		if id.script == '' || rule.script != '' { id.script = base.script }
		if id.region == '' || rule.region != '' { id.region = base.region }
		id.variants = id.variants.filter(it !in rule.variants)
		for variant in base.variants { if variant !in id.variants { id.variants << variant } }
	}
	if replacement := core.language_alias[id.language] {
		base, _ := intl_parse_base(mut vm, replacement.split('-'))!
		id.language = base.language
		if id.script == '' { id.script = base.script }
		if id.region == '' { id.region = base.region }
	}
	if alias := core.script_alias[id.script.to_lower()] { id.script = alias }
	if aliases := core.region_alias[id.region] {
		if aliases.len > 0 {
			mut chosen := aliases[0]
			for key in [id.language + '-' + id.script, id.language] {
				if likely := core.likely_subtags[key] { region := likely.split('-').last(); if region in aliases { chosen = region; break } }
			}
			id.region = chosen
		}
	}
	mut variants := []string{}
	for variant in id.variants {
		value := core.variant_alias[variant] or { variant }
		for part in value.to_lower().split('-') { if part !in variants { variants << part } }
	}
	variants.sort(); id.variants = variants
	return id
}

fn intl_canonicalize_language_tag(mut vm VM, text Utf16String) !IntlLocaleIdentifier {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut id := intl_canonical_base(mut vm, intl_parse_language_tag(mut vm, text)!)!
	core := intl_core_data(mut vm)!
	mut keywords := id.keywords.clone()
	for key, value in keywords { keywords[key] = core.type_alias[key + ':' + value] or { value } }
	id.keywords = keywords
	return id
}
