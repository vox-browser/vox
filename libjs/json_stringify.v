// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// Runtime/JSONObject.cpp::stringify_impl and SerializeJSONProperty. A local
// UTF-16 builder preserves lone surrogates and checks every output growth.
struct JSONStringifyState {
mut:
	replacer Value = js_undefined()
	has_property_list bool
	property_list []PropertyName
	gap []u16
	output []u16
	ancestors []&Object
	ancestor_ids map[voidptr]bool
}

fn json_stringify(mut vm VM) !Value {
	mut state := JSONStringifyState{}
	replacer := vm.argument(1)
	if replacer.is_function() {
		state.replacer = replacer
	} else if replacer.is_array(mut vm)! {
		state.has_property_list = true
		object := replacer.as_object()
		length := length_of_array_like(mut vm, object)!
		mut seen := map[string]bool{}
		for index := u64(0); index < length; index++ {
			vm.consume_execution_budget()!
			value := object.get(mut vm, array_index_key(index))!
			if !value.is_string() && !value.is_number() {
				if !value.is_object() { continue }
				boxed := value.as_object()
				if boxed.slots.number_object == none && boxed.string_object == none { continue }
			}
			key := PropertyName.from_utf16(value.to_primitive_string(mut vm)!.utf16)
			identity := property_name_identity(key)
			if seen[identity] { continue }
			seen[identity] = true
			state.property_list << key
		}
	}
	mut space := vm.argument(2)
	if space.is_object() {
		boxed := space.as_object()
		if boxed.slots.number_object != none { space = space.to_number(mut vm)! }
		else if boxed.string_object != none { space = Value.from_string(space.to_primitive_string(mut vm)!) }
	}
	if space.is_number() {
		count := space.to_integer_or_infinity(mut vm)!
		if count > 0 { state.gap = []u16{len: int(math.min(10, count)), init: u16(` `)} }
	} else if space.is_string() {
		units := space.as_string().utf16.data
		state.gap = units[..int(math.min(10, units.len))].clone()
	}
	mut wrapper := Object.create(vm.realm(), vm.realm().object_prototype)
	key := PropertyName.from_str('')
	wrapper.create_data_property_or_throw(mut vm, key, vm.argument(0))!
	value := state.prepare_property(mut vm, wrapper, key)!
	if !state.serialize_value(mut vm, value)! { return js_undefined() }
	return Value.from_string(vm.create_string(Utf16String.from_slice(state.output)))
}

fn (mut state JSONStringifyState) prepare_property(mut vm VM, holder &Object, key PropertyName) !Value {
	vm.consume_execution_budget()!
	mut value := holder.get(mut vm, key)!
	if value.is_object() || value.is_bigint() {
		to_json := value.get_with_prototypes(mut vm, PropertyName.from_str('toJSON'), realm_primitive_prototypes())!
		if to_json.is_function() { value = call(mut vm, to_json, value, [key.to_value(mut vm)])! }
	}
	if !state.replacer.is_undefined() {
		value = call(mut vm, state.replacer, Value.from_object(holder), [key.to_value(mut vm), value])!
	}
	if value.is_object() {
		object := value.as_object()
		if object.slots.number_object != none { value = value.to_number(mut vm)! }
		else if object.string_object != none { value = Value.from_string(value.to_primitive_string(mut vm)!) }
		else if boolean := object.slots.boolean_object { value = Value.from_bool(boolean.value) }
		else if bigint := object.slots.bigint_object { value = Value.from_bigint(bigint.bigint) }
	}
	if value.is_bigint() { return vm.throw_error_type(.type_error, .json_big_int) }
	return value
}

fn (mut state JSONStringifyState) append(mut vm VM, units []u16) ! {
	checked_js_string_length_sum(mut vm, uint(state.output.len), uint(units.len), .string_size_must_not_overflow)!
	state.output << units
}

fn (mut state JSONStringifyState) ascii(mut vm VM, text string) ! {
	state.append(mut vm, utf16_string(text).data)!
}

fn (mut state JSONStringifyState) indent(mut vm VM, depth int) ! {
	if state.gap.len == 0 { return }
	state.ascii(mut vm, '\n')!
	for _ in 0 .. depth { state.append(mut vm, state.gap)! }
}

// QuoteJSONString: valid pairs remain UTF-16, lone surrogates become \uXXXX.
fn (mut state JSONStringifyState) quote(mut vm VM, text Utf16String) ! {
	state.ascii(mut vm, '"')!
	units := text.data
	mut index := 0
	mut start := 0
	mut next_budget_check := 0
	for index < units.len {
		if index >= next_budget_check {
			vm.consume_execution_budget()!
			next_budget_check = index + 64
		}
		unit := units[index]
		escaped := match unit {
			u16(`"`) { '\\"' }
			u16(`\\`) { '\\\\' }
			u16(8) { '\\b' }
			u16(9) { '\\t' }
			u16(10) { '\\n' }
			u16(12) { '\\f' }
			u16(13) { '\\r' }
			else { '' }
		}
		paired := unit >= 0xd800 && unit <= 0xdbff && index + 1 < units.len && units[index + 1] >= 0xdc00 && units[index + 1] <= 0xdfff
		if paired { index += 2; continue }
		if escaped.len == 0 && unit >= 0x20 && !(unit >= 0xd800 && unit <= 0xdfff) { index++; continue }
		state.append(mut vm, units[start..index])!
		if escaped.len > 0 {
			state.ascii(mut vm, escaped)!
		} else {
			hex := '0123456789abcdef'
			state.append(mut vm, [u16(`\\`), u16(`u`), u16(hex[(unit >> 12) & 15]), u16(hex[(unit >> 8) & 15]), u16(hex[(unit >> 4) & 15]), u16(hex[unit & 15])])!
		}
		index++
		start = index
	}
	state.append(mut vm, units[start..])!
	state.ascii(mut vm, '"')!
}

fn (mut state JSONStringifyState) serialize_value(mut vm VM, value Value) !bool {
	vm.consume_execution_budget()!
	if value.is_null() { state.ascii(mut vm, 'null')!; return true }
	if value.is_boolean() { state.ascii(mut vm, if value.as_bool() { 'true' } else { 'false' })!; return true }
	if value.is_string() { state.quote(mut vm, value.as_string().utf16)!; return true }
	if value.is_number() {
		state.ascii(mut vm, if math.is_nan(value.number) || math.is_inf(value.number, 0) { 'null' } else { format_f64_value(value.number) })!
		return true
	}
	if !value.is_object() || value.is_function() { return false }
	object := value.as_object()
	is_array := value.is_array(mut vm)!
	if state.ancestor_ids[voidptr(object)] { return vm.throw_error_type(.type_error, .json_circular) }
	if state.ancestors.len >= 128 || vm.did_reach_stack_space_limit() { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
	state.ancestor_ids[voidptr(object)] = true
	state.ancestors << object
	defer { state.ancestors.pop(); state.ancestor_ids.delete(voidptr(object)) }
	if is_array { state.serialize_array(mut vm, object)! }
	else { state.serialize_object(mut vm, object)! }
	return true
}

fn (mut state JSONStringifyState) serialize_array(mut vm VM, object &Object) ! {
	length := length_of_array_like(mut vm, object)!
	state.ascii(mut vm, '[')!
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		if index > 0 { state.ascii(mut vm, ',')! }
		state.indent(mut vm, state.ancestors.len)!
		value := state.prepare_property(mut vm, object, array_index_key(index))!
		if !state.serialize_value(mut vm, value)! { state.ascii(mut vm, 'null')! }
	}
	if length > 0 { state.indent(mut vm, state.ancestors.len - 1)! }
	state.ascii(mut vm, ']')!
}

fn (mut state JSONStringifyState) serialize_object(mut vm VM, object &Object) ! {
	mut keys := state.property_list.clone()
	if !state.has_property_list {
		keys = []PropertyName{}
		for key in object.own_property_keys_checked(mut vm)! {
			vm.consume_execution_budget()!
			if key.is_symbol() { continue }
			if descriptor := object.get_own_property_checked(mut vm, key)!.descriptor {
				if descriptor.enumerable or { false } { keys << key }
			}
		}
	}
	state.ascii(mut vm, '{')!
	mut first := true
	for key in keys {
		value := state.prepare_property(mut vm, object, key)!
		if value.is_undefined() || value.is_symbol() || value.is_function() { continue }
		if !first { state.ascii(mut vm, ',')! }
		state.indent(mut vm, state.ancestors.len)!
		name := key.to_value(mut vm).as_string().utf16
		state.quote(mut vm, name)!
		state.ascii(mut vm, if state.gap.len > 0 { ': ' } else { ':' })!
		state.serialize_value(mut vm, value)!
		first = false
	}
	if !first { state.indent(mut vm, state.ancestors.len - 1)! }
	state.ascii(mut vm, '}')!
}
