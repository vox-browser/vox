// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Geometry/DOMRectList.{h,cpp}.
module geometry

// DOMRectList is a legacy indexed platform object upstream. V exposes the same
// stable object references through item() and an iterator-friendly snapshot.
@[heap]
pub struct DOMRectList {
mut:
	rects_ []&DOMRect
}

pub fn DOMRectList.create(rects []&DOMRect) &DOMRectList {
	return &DOMRectList{
		rects_: rects.clone()
	}
}

pub fn (list &DOMRectList) length() u32 {
	return u32(list.rects_.len)
}

pub fn (list &DOMRectList) item(index u32) ?&DOMRect {
	if index >= u32(list.rects_.len) {
		return none
	}
	return list.rects_[index]
}

// Bindings::PlatformObject::item_value is a LibJS boundary. Returning the
// typed object is the equivalent operation for V callers.
pub fn (list &DOMRectList) item_value(index uint) ?&DOMRect {
	if index >= uint(list.rects_.len) {
		return none
	}
	return list.rects_[index]
}

pub fn (list &DOMRectList) values() []&DOMRect {
	return list.rects_.clone()
}
