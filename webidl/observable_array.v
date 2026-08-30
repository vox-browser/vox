// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/ObservableArray.{h,cpp}.
module webidl

pub type SetIndexedValueCallback = fn (Value) !

pub type DeleteIndexedValueCallback = fn (Value) !

pub struct ObservableArray {
pub mut:
	values []Value
mut:
	on_set    ?SetIndexedValueCallback
	on_delete ?DeleteIndexedValueCallback
}

pub fn ObservableArray.create() ObservableArray {
	return ObservableArray{}
}

pub fn (mut array ObservableArray) set_on_set_an_indexed_value_callback(callback SetIndexedValueCallback) {
	array.on_set = callback
}

pub fn (mut array ObservableArray) set_on_delete_an_indexed_value_callback(callback DeleteIndexedValueCallback) {
	array.on_delete = callback
}

pub fn (mut array ObservableArray) set(index int, value Value) ! {
	if index < 0 {
		return error('RangeError: index cannot be negative')
	}
	if callback := array.on_set {
		callback(value)!
	}
	for array.values.len <= index {
		array.values << undefined_value()
	}
	array.values[index] = value
}

pub fn (mut array ObservableArray) internal_set(index int, value Value) !bool {
	array.set(index, value)!
	return true
}

pub fn (mut array ObservableArray) delete(index int) !bool {
	if index < 0 {
		return true
	}
	value := if index < array.values.len { array.values[index] } else { undefined_value() }
	if callback := array.on_delete {
		callback(value)!
	}
	if index >= array.values.len {
		return true
	}
	array.values.delete(index)
	return true
}

pub fn (mut array ObservableArray) internal_delete(index int) !bool {
	return array.delete(index)
}

pub fn (mut array ObservableArray) append(value Value) ! {
	array.set(array.values.len, value)!
}

// Upstream clear removes the first indexed value repeatedly and invokes the
// deletion callback for every present value.
pub fn (mut array ObservableArray) clear() ! {
	for array.values.len > 0 {
		value := array.values[0]
		if callback := array.on_delete {
			callback(value)!
		}
		array.values.delete(0)
	}
}

pub fn (array &ObservableArray) for_each(callback fn (Value)) {
	for value in array.values {
		callback(value)
	}
}
