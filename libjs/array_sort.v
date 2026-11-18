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
		vm.consume_execution_budget()!
		key := if index < 0xffffffff {
			PropertyName.from_number(u32(index))
		} else {
			PropertyName.from_str(index.str())
		}
		if holes == .skip_holes && !object.has_property_checked(mut vm, key)! { continue
		 }
		items << object.get(mut vm, key)!
	}
	array_merge_sort(mut vm, compare, mut items)!
	return items
}

// Runtime/ArrayPrototype.cpp::array_merge_sort. Left-before-right recursion
// and the <= comparison preserve the upstream stable order and abrupt exits.
pub fn array_merge_sort(mut vm VM, compare ArraySortCompare, mut items []Value) ! {
	length := items.len
	if length <= 1 { return }
	middle := length / 2
	// Keep the caller's array intact until both halves sort successfully.
	// Only the final merge writes back, in the same order as before.
	mut sorted := items.clone()
	mut merged := []Value{cap: length - middle}
	sort_array_range(mut vm, compare, mut sorted, mut merged, 0, middle)!
	sort_array_range(mut vm, compare, mut sorted, mut merged, middle, length)!
	items.clear()
	merge_array_runs(mut vm, compare, sorted[..middle], sorted[middle..], mut items)!
}

fn sort_array_range(mut vm VM, compare ArraySortCompare, mut items []Value, mut merged []Value,
	start int, end int) ! {
	if end - start <= 1 { return }
	middle := start + (end - start) / 2
	sort_array_range(mut vm, compare, mut items, mut merged, start, middle)!
	sort_array_range(mut vm, compare, mut items, mut merged, middle, end)!
	merged.clear()
	merge_array_runs(mut vm, compare, items[start..middle], items[middle..end], mut merged)!
	for index, item in merged {
		items[start + index] = item
	}
}

fn merge_array_runs(mut vm VM, compare ArraySortCompare, left []Value, right []Value,
	mut result []Value) ! {
	mut left_index := 0
	mut right_index := 0
	for left_index < left.len && right_index < right.len {
		x := left[left_index]
		y := right[right_index]
		if compare(mut vm, x, y)! <= 0 {
			result << x
			left_index++
		} else {
			result << y
			right_index++
		}
	}
	result << left[left_index..]
	result << right[right_index..]
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
