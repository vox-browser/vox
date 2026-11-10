module libjs

import math

// TypedArrayPrototype.cpp::includes: SameValueZero and Get include an index
// that became invalid during fromIndex conversion (its value is undefined).
pub fn typed_array_prototype_includes(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	search := vm.argument(0)
	from := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	if length == 0 { return Value.from_bool(false) }
	mut n := from.to_integer_or_infinity(mut vm)!
	if from.is_undefined() {
		assert n == 0
	}
	if math.is_inf(n, 1) { return Value.from_bool(false) }
	if math.is_inf(n, -1) { n = 0 }
	mut k := u32(0)
	if n >= 0 {
		if n >= f64(length) { return Value.from_bool(false) }
		k = u32(n)
	} else {
		k = u32(math.max(f64(length) + n, 0.0))
	}
	for k < length {
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		if same_value_zero(search, value) { return Value.from_bool(true) }
		k++
	}
	return Value.from_bool(false)
}

// TypedArrayPrototype.cpp::index_of: unlike includes, HasProperty omits
// indices that became invalid after the initial length witness.
pub fn typed_array_prototype_index_of(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	search := vm.argument(0)
	from := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	if length == 0 { return Value.from_i32(-1) }
	mut n := from.to_integer_or_infinity(mut vm)!
	if from.is_undefined() {
		assert n == 0
	}
	if math.is_inf(n, 1) { return Value.from_i32(-1) }
	if math.is_inf(n, -1) { n = 0 }
	mut k := u32(0)
	if n >= 0 {
		if n >= f64(length) { return Value.from_i32(-1) }
		k = u32(n)
	} else {
		k = u32(math.max(f64(length) + n, 0.0))
	}
	for k < length {
		key := PropertyName.from_number(k)
		if array.object.has_property(key) {
			value := array.object.get(mut vm, key)!
			if is_strictly_equal(search, value) { return Value.from_f64(f64(k)) }
		}
		k++
	}
	return Value.from_i32(-1)
}

// TypedArrayPrototype.cpp::last_index_of. Presence of fromIndex is observable:
// omitted starts at length-1; explicit undefined starts at zero.
pub fn typed_array_prototype_last_index_of(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	search := vm.argument(0)
	from := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	if length == 0 { return Value.from_i32(-1) }
	n := if vm.argument_count() > 1 {
		from.to_integer_or_infinity(mut vm)!
	} else {
		f64(length - 1)
	}
	if math.is_inf(n, -1) { return Value.from_i32(-1) }
	k := if n >= 0 {
		u32(math.min(n, f64(length - 1)))
	} else {
		relative := f64(length) + n
		if relative < 0 { return Value.from_i32(-1) }
		u32(relative)
	}
	mut end := k + 1
	for end > 0 {
		end--
		key := PropertyName.from_number(end)
		if array.object.has_property(key) {
			value := array.object.get(mut vm, key)!
			if is_strictly_equal(search, value) { return Value.from_f64(f64(end)) }
		}
	}
	return Value.from_i32(-1)
}
