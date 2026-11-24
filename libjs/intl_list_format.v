// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform
import vunicode

@[heap]
pub struct IntlListFormat {
	object &Object
	locale string
	type_ string
	style string
	templates map[string]string
}

struct IntlListPart { type_ string; value Utf16String }
struct IntlListEmission { prefix int; element int = -1; literal ?Utf16String }

fn intl_list_format_this(mut vm VM) !&IntlListFormat {
	value := vm.this_value()
	if value.is_object() { if formatter := value.as_object().slots.intl_list_format { return formatter } }
	return vm.throw_error(.type_error, 'Intl.ListFormat member called on incompatible receiver')
}

fn intl_list_format_construct(mut vm VM, new_target &Object) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_list_format_prototype or { panic('Missing Intl.ListFormat prototype') } })!
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	options_value := vm.argument(1)
	if !options_value.is_undefined() && !options_value.is_object() { return vm.throw_error(.type_error, 'Intl.ListFormat options must be an object') }
	options := intl_options_object(mut vm, options_value)!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	locale, _ := intl_resolve_locale(mut vm, requested)!
	type_value := intl_string_option(mut vm, options, 'type', ['conjunction', 'disjunction', 'unit'])!
	style_value := intl_string_option(mut vm, options, 'style', ['long', 'short', 'narrow'])!
	type_ := if type_value.is_undefined() { 'conjunction' } else { type_value.as_string().str() }
	style := if style_value.is_undefined() { 'long' } else { style_value.as_string().str() }
	key := 'listPattern-type-' + (if type_ == 'conjunction' { 'standard' } else if type_ == 'disjunction' { 'or' } else { 'unit' }) + (if style == 'long' { '' } else { '-' + style })
	data := intl_date_locale_data(mut vm, locale)!
	templates := (data.list_patterns[key] or { return vm.throw_error(.internal_error, 'Missing CLDR list patterns') }).clone()
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.ListFormat'
	object.mut_slots().intl_list_format = &IntlListFormat{object: object, locale: locale, type_: type_, style: style, templates: templates}
	return object
}

// StringListFromIterable closes only the type-error path. Abrupt next/value
// operations propagate directly, and elements are never coerced to strings.
fn intl_string_list_from_iterable(mut vm VM, value Value) ![]Utf16String {
	if value.is_undefined() { return []Utf16String{} }
	mut iterator := get_iterator_sync_value(mut vm, value)!
	mut list := []Utf16String{}
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done { return list }
		if !step.value.is_string() {
			failure := vm.throw_error(.type_error, 'Intl.ListFormat iterable elements must be strings')
			closed := iterator_close(mut vm, iterator, completion_from_error(failure))
			return closed.release_error()
		}
		list << step.value.as_string().utf16
	}
	return list
}

// UTS #35 list-pattern contextual alternations. Inspect only the prefix needed
// for the condition; author strings otherwise retain every UTF-16 code unit.
fn intl_contextual_list_template(formatter &IntlListFormat, pattern string, last Utf16String, position string) string {
	if position !in ['2', 'end'] || last.data.len == 0 { return pattern }
	language := formatter.locale.all_before('-')
	mut prefix := ''
	for unit in last.data[..if last.data.len < 32 { last.data.len } else { 32 }] {
		if unit > 0x7f { break }
		prefix += u8(unit).ascii_str().to_lower()
	}
	if language == 'es' {
		if formatter.type_ == 'conjunction' && (prefix.starts_with('i') || (prefix.starts_with('hi') && !prefix.starts_with('hia') && !prefix.starts_with('hie'))) { return pattern.replace(' y ', ' e ') }
		if formatter.type_ == 'disjunction' {
			mut eleven := prefix.starts_with('11') && (prefix.len == 2 || prefix[2] < `0` || prefix[2] > `9`)
			if prefix.starts_with('11') && prefix.len > 2 {
				mut end := 2
				for end < prefix.len && prefix[end] == `0` { end++ }
				if (end - 2) % 3 == 0 && end > 2 && (end == prefix.len || prefix[end] < `0` || prefix[end] > `9`) { eleven = true }
			}
			if prefix.starts_with('o') || prefix.starts_with('ho') || prefix.starts_with('8') || eleven { return pattern.replace(' o ', ' u ') }
		}
	} else if language == 'he' && formatter.type_ == 'conjunction' {
		point := u32(last.data[0])
		hebrew := vunicode.has_script(point, vunicode.script_id('Hebrew') or { return pattern }) && vunicode.has_property(point, vunicode.property_id('Alphabetic') or { return pattern })
		if !hebrew { return pattern.replace('ו{1}', 'ו-{1}') }
	}
	return pattern
}

fn intl_list_template_emissions(mut vm VM, text string, prefix int, element int) ![]IntlListEmission {
	units := utf16_string(text).data
	mut result := []IntlListEmission{}
	mut start := 0
	mut index := 0
	mut zeroes := 0
	mut ones := 0
	for index + 2 < units.len {
		if units[index] == u16(`{`) && units[index + 2] == u16(`}`) && units[index + 1] in [u16(`0`), u16(`1`)] {
			if index > start { result << IntlListEmission{literal: Utf16String.from_slice(units[start..index])} }
			if units[index + 1] == u16(`0`) { zeroes++; result << IntlListEmission{prefix: prefix} }
			else { ones++; result << IntlListEmission{element: element} }
			index += 3; start = index
		} else { index++ }
	}
	if start < units.len { result << IntlListEmission{literal: Utf16String.from_slice(units[start..])} }
	if zeroes != 1 || ones != 1 { return vm.throw_error(.internal_error, 'Invalid CLDR list template') }
	return result
}

fn intl_partition_list(mut vm VM, formatter &IntlListFormat, values []Utf16String) ![]IntlListPart {
	if values.len == 0 { return []IntlListPart{} }
	mut stack := [IntlListEmission{prefix: values.len}]
	mut result := []IntlListPart{}
	mut literal := []u16{}
	for stack.len > 0 {
		vm.consume_execution_budget()!
		emission := stack.pop()
		if text := emission.literal {
			checked_js_string_length_sum(mut vm, uint(literal.len), uint(text.len()), .string_size_must_not_overflow)!
			literal << text.data
			continue
		}
		if emission.element >= 0 || emission.prefix == 1 {
			if literal.len > 0 { result << IntlListPart{type_: 'literal', value: Utf16String.from_slice(literal)}; literal = []u16{} }
			result << IntlListPart{type_: 'element', value: values[if emission.element >= 0 { emission.element } else { 0 }]}
			continue
		}
		count := emission.prefix
		key := if values.len == 2 { '2' } else if count == values.len { 'end' } else if count == 2 { 'start' } else { 'middle' }
		pattern := intl_contextual_list_template(formatter, formatter.templates[key], values[count - 1], key)
		pieces := intl_list_template_emissions(mut vm, pattern, count - 1, count - 1)!
		for index := pieces.len - 1; index >= 0; index-- { stack << pieces[index] }
	}
	if literal.len > 0 { result << IntlListPart{type_: 'literal', value: Utf16String.from_slice(literal)} }
	return result
}

fn intl_list_format(mut vm VM) !Value {
	formatter := intl_list_format_this(mut vm)!
	values := intl_string_list_from_iterable(mut vm, vm.argument(0))!
	parts := intl_partition_list(mut vm, formatter, values)!
	mut output := []u16{}
	for part in parts {
		checked_js_string_length_sum(mut vm, uint(output.len), uint(part.value.len()), .string_size_must_not_overflow)!
		output << part.value.data
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(output)))
}

fn intl_list_format_to_parts(mut vm VM) !Value {
	formatter := intl_list_format_this(mut vm)!
	values := intl_string_list_from_iterable(mut vm, vm.argument(0))!
	parts := intl_partition_list(mut vm, formatter, values)!
	mut output := []Value{cap: parts.len}
	for part in parts {
		mut object := Object.create(vm.realm(), vm.realm().object_prototype)
		object.create_data_property_or_throw(mut vm, PropertyName.from_str('type'), Value.from_string(vm.create_string_from_str(part.type_)))!
		object.create_data_property_or_throw(mut vm, PropertyName.from_str('value'), Value.from_string(vm.create_string(part.value)))!
		output << Value.from_object(object)
	}
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), output, vm.realm().array_prototype_record())!.object)
}

fn initialize_intl_list_format(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_list_format_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Intl.ListFormat constructor requires new') }, intl_list_format_construct, 0, PropertyName.from_str('ListFormat')).object
	realm.intl_list_format_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.ListFormat')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'supportedLocalesOf', 1, fn (mut vm VM) !Value { return intl_supported_locales(mut vm, vm.argument(0), vm.argument(1)) })
	install_intrinsic_method(mut vm, realm, mut prototype, 'format', 1, intl_list_format)
	install_intrinsic_method(mut vm, realm, mut prototype, 'formatToParts', 1, intl_list_format_to_parts)
	install_intrinsic_method(mut vm, realm, mut prototype, 'resolvedOptions', 0, fn (mut vm VM) !Value {
		formatter := intl_list_format_this(mut vm)!
		mut object := Object.create(vm.realm(), vm.realm().object_prototype)
		for name, value in {'locale': formatter.locale, 'type': formatter.type_, 'style': formatter.style} { object.create_data_property_or_throw(mut vm, PropertyName.from_str(name), Value.from_string(vm.create_string_from_str(value)))! }
		return Value.from_object(object)
	})
	mut namespace := realm.intl_object or { panic('Missing Intl namespace') }
	namespace.define_direct_property(PropertyName.from_str('ListFormat'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}
