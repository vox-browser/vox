// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Table.{h,cpp}.
module webassembly

import webidl

pub enum TableKind {
	externref
	anyfunc
}

pub fn table_kind_to_value_type(kind TableKind) ValueType {
	return match kind {
		.externref { .externref }
		.anyfunc { .anyfunc }
	}
}

pub struct TableDescriptor {
pub:
	element TableKind
	initial u32
	maximum ?u32
}

@[heap]
pub struct Table {
pub:
	element TableKind
	maximum ?u32
mut:
	elements []webidl.Value
}

pub fn Table.construct(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	if maximum := descriptor.maximum {
		if maximum < descriptor.initial {
			return error('RangeError: Maximum should not be less than initial in table type')
		}
	}
	default_value := if descriptor.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	value := validate_table_value(descriptor.element, initial or { default_value })!
	return &Table{
		element:  descriptor.element
		maximum:  descriptor.maximum
		elements: []webidl.Value{len: int(descriptor.initial), init: value}
	}
}

pub fn Table.construct_impl(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	return Table.construct(descriptor, initial)
}

pub fn (table &Table) address() u64 {
	return u64(voidptr(table))
}

fn validate_table_value(kind TableKind, value webidl.Value) !webidl.Value {
	if kind == .anyfunc && value.kind !in [.null_, .callback] {
		return error('TypeError: anyfunc table values must be null or exported functions')
	}
	return value
}

pub fn (mut table Table) grow(delta u32, initial ?webidl.Value) !u32 {
	previous := table.length()
	new_length := u64(previous) + u64(delta)
	if maximum := table.maximum {
		if new_length > maximum {
			return error('RangeError: Failed to grow table')
		}
	}
	default_value := if table.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	value := validate_table_value(table.element, initial or { default_value })!
	table.elements << []webidl.Value{len: int(delta), init: value}
	return previous
}

pub fn (table &Table) get(index u32) !webidl.Value {
	if index >= table.elements.len {
		return error('RangeError: Table element index out of range')
	}
	return table.elements[index]
}

pub fn (mut table Table) set(index u32, value ?webidl.Value) ! {
	if index >= table.elements.len {
		return error('RangeError: Table element index out of range')
	}
	default_value := if table.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	table.elements[index] = validate_table_value(table.element, value or { default_value })!
}

pub fn (table &Table) length() u32 {
	return u32(table.elements.len)
}
