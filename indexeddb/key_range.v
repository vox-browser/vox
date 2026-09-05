// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IndexedDB/IDBKeyRange.{h,cpp,idl}.
module indexeddb

pub struct IDBKeyRange {
pub:
	lower      ?Key
	upper      ?Key
	lower_open bool
	upper_open bool
}

pub fn IDBKeyRange.only(value Key) !IDBKeyRange {
	ensure_valid_key(value)!
	return IDBKeyRange{
		lower: value.clone()
		upper: value.clone()
	}
}

pub fn IDBKeyRange.lower_bound(lower Key, open bool) !IDBKeyRange {
	ensure_valid_key(lower)!
	return IDBKeyRange{
		lower: lower.clone()
		lower_open: open
		upper_open: true
	}
}

pub fn IDBKeyRange.upper_bound(upper Key, open bool) !IDBKeyRange {
	ensure_valid_key(upper)!
	return IDBKeyRange{
		upper: upper.clone()
		lower_open: true
		upper_open: open
	}
}

pub fn IDBKeyRange.bound(lower Key, upper Key, lower_open bool, upper_open bool) !IDBKeyRange {
	ensure_valid_key(lower)!
	ensure_valid_key(upper)!
	comparison := compare_two_keys(lower, upper)!
	if comparison > 0 {
		return error('DataError: lower key is greater than upper key')
	}
	return IDBKeyRange{
		lower: lower.clone()
		upper: upper.clone()
		lower_open: lower_open
		upper_open: upper_open
	}
}

pub fn IDBKeyRange.unbounded() IDBKeyRange {
	return IDBKeyRange{
		lower_open: true
		upper_open: true
	}
}

fn ensure_valid_key(key Key) ! {
	if !key.is_valid() {
		return error('DataError: invalid IndexedDB key')
	}
}

// https://w3c.github.io/IndexedDB/#in
pub fn (range IDBKeyRange) includes(key Key) !bool {
	ensure_valid_key(key)!
	if lower := range.lower {
		comparison := compare_two_keys(key, lower)!
		if comparison < 0 || (comparison == 0 && range.lower_open) {
			return false
		}
	}
	if upper := range.upper {
		comparison := compare_two_keys(key, upper)!
		if comparison > 0 || (comparison == 0 && range.upper_open) {
			return false
		}
	}
	return true
}

pub fn key_or_range(key ?Key, range ?IDBKeyRange) !IDBKeyRange {
	if actual := range {
		return actual
	}
	if actual := key {
		return IDBKeyRange.only(actual)
	}
	return IDBKeyRange.unbounded()
}
