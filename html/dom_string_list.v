// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/DOMStringList.cpp.
module html

pub struct DOMStringList {
	list []string
}

pub fn DOMStringList.create(list []string) DOMStringList {
	return DOMStringList{
		list: list
	}
}

pub fn (list &DOMStringList) length() u32 {
	return u32(list.list.len)
}

pub fn (list &DOMStringList) item(index u32) ?string {
	if index >= u32(list.list.len) {
		return none
	}
	return list.list[index]
}

pub fn (list &DOMStringList) item_value(index int) ?string {
	if index < 0 || index >= list.list.len {
		return none
	}
	return list.list[index]
}

pub fn (list &DOMStringList) contains(value string) bool {
	return value in list.list
}
