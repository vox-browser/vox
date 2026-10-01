module libjs

import math

pub enum ArrayHoles {
	skip_holes
	read_through_holes
}

pub type ArraySortCompare = fn (mut vm VM, x Value, y Value) !f64

// Runtime/Array.cpp::SortIndexedProperties. Gather indexed values before
// comparing any of them; inherited properties participate in skip-holes mode.
pub fn sort_indexed_properties(mut vm VM, object &Object, length u64, compare ArraySortCompare, holes ArrayHoles) ![]Value {
	mut items := []Value{}
	for index := u64(0); index < length; index++ {
		key := if index < 0xffffffff {
			PropertyName.from_number(u32(index))
		} else {
			PropertyName.from_str(index.str())
		}
		if holes == .skip_holes && !object.has_property(key) { continue
		 }
		items << object.get(mut vm, key)!
	}
	array_merge_sort(mut vm, compare, mut items)!
	return items
}

// Runtime/ArrayPrototype.cpp::array_merge_sort. Left-before-right recursion
// and the <= comparison preserve the upstream stable order and abrupt exits.
pub fn array_merge_sort(mut vm VM, compare ArraySortCompare, mut items []Value) ! {
	if items.len <= 1 { return }
	middle := items.len / 2
	mut left := items[..middle].clone()
	mut right := items[middle..].clone()
	array_merge_sort(mut vm, compare, mut left)!
	array_merge_sort(mut vm, compare, mut right)!
	items.clear()
	mut left_index := 0
	mut right_index := 0
	for left_index < left.len && right_index < right.len {
		x := left[left_index]
		y := right[right_index]
		result := compare(mut vm, x, y)!
		if result <= 0 {
			items << x
			left_index++
		} else {
			items << y
			right_index++
		}
	}
	for left_index < left.len {
		items << left[left_index]
		left_index++
	}
	for right_index < right.len {
		items << right[right_index]
		right_index++
	}
}

// Runtime/Array.cpp::CompareArrayElements. Undefined sorts after all other
// values without calling the comparator. Default ordering uses UTF-16 strings.
pub fn compare_array_elements(mut vm VM, x Value, y Value, compare_function ?&Object) !f64 {
	if x.is_undefined() && y.is_undefined() { return 0 }
	if x.is_undefined() { return 1 }
	if y.is_undefined() { return -1 }
	if function := compare_function {
		value := call(mut vm, Value.from_object(function), js_undefined(), [x, y])!
		number := value.to_number(mut vm)!
		return if math.is_nan(number.number) { 0 } else { number.number }
	}
	x_string := x.to_primitive_string(mut vm)!
	y_string := y.to_primitive_string(mut vm)!
	if x_string.utf16 < y_string.utf16 { return -1 }
	if y_string.utf16 < x_string.utf16 { return 1 }
	return 0
}
