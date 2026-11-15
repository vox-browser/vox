// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// Runtime/StringPrototype.cpp::{includes,starts_with,ends_with}. IsRegExp
// observes @@match before coercing the needle, including false overrides on
// actual RegExp records. Search positions and comparisons use UTF-16 units.
fn string_search_needle(mut vm VM, value Value) !Utf16String {
	if value.is_object() {
		object := value.as_object()
		matcher := object.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match()))!
		is_regex := if matcher.is_undefined() { object.regexp_object != none } else { matcher.to_boolean() }
		if is_regex { return vm.throw_error(.type_error, 'searchString must not be a regular expression') }
	}
	return value.to_primitive_string(mut vm)!.utf16
}

pub fn string_prototype_includes(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!.utf16
	search := string_search_needle(mut vm, vm.argument(0))!
	position := vm.argument(1).to_integer_or_infinity(mut vm)!
	start := uint(math.min(math.max(position, 0), f64(text.len())))
	return Value.from_bool(string_index_of(text, search, start) != none)
}

pub fn string_prototype_starts_with(mut vm VM) !Value {
	return string_boundary_search(mut vm, false)
}

pub fn string_prototype_ends_with(mut vm VM) !Value {
	return string_boundary_search(mut vm, true)
}

fn string_boundary_search(mut vm VM, ends bool) !Value {
	text := string_primitive_from(mut vm)!.utf16
	search := string_search_needle(mut vm, vm.argument(0))!
	position := if ends && vm.argument(1).is_undefined() { f64(text.len()) } else { vm.argument(1).to_integer_or_infinity(mut vm)! }
	boundary := int(math.min(math.max(position, 0), f64(text.len())))
	if search.len() == 0 { return Value.from_bool(true) }
	start := if ends { boundary - search.len() } else { boundary }
	if start < 0 || search.len() > text.len() - start { return Value.from_bool(false) }
	return Value.from_bool(utf16_equals(text.data[start..start + search.len()], search.data))
}
