// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLOrSVGElement.{h,cpp}. The C++ template is represented by
// a mixin state object associated with any DOM Element.
module html

import dom

@[heap]
pub struct HTMLOrSVGElement {
pub:
	element &dom.Element
mut:
	dataset_             ?&DOMStringMap
	cryptographic_nonce_ string
}

pub fn HTMLOrSVGElement.create(element &dom.Element) &HTMLOrSVGElement {
	return &HTMLOrSVGElement{
		element: element
	}
}

pub fn (mut mixin HTMLOrSVGElement) dataset() &DOMStringMap {
	if dataset := mixin.dataset_ {
		return dataset
	}
	dataset := DOMStringMap.create(mixin.element)
	mixin.dataset_ = dataset
	return dataset
}

pub fn (mixin &HTMLOrSVGElement) nonce() string {
	return mixin.cryptographic_nonce_
}

pub fn (mut mixin HTMLOrSVGElement) set_nonce(nonce string) {
	mixin.cryptographic_nonce_ = nonce
}

pub fn (mixin &HTMLOrSVGElement) focus() {
	if !mixin.element.document().allow_focus() {
		return
	}
	mut document := unsafe { &dom.Document(mixin.element.document()) }
	document.set_focused_area(mixin.element.as_node())
}

pub fn (mixin &HTMLOrSVGElement) blur() {
	mut document := unsafe { &dom.Document(mixin.element.document()) }
	if focused := document.focused_area() {
		if voidptr(focused) == voidptr(mixin.element.as_node()) {
			document.set_focused_area(none)
		}
	}
}

pub fn (mut mixin HTMLOrSVGElement) attribute_changed(local_name string, value ?string, namespace_ ?string) {
	if local_name != 'nonce' || namespace_ != none {
		return
	}
	mixin.cryptographic_nonce_ = value or { '' }
}

pub fn (mixin &HTMLOrSVGElement) cloned(copy &dom.Element) &HTMLOrSVGElement {
	return &HTMLOrSVGElement{
		element:              copy
		cryptographic_nonce_: mixin.cryptographic_nonce_
	}
}

// The CSP list lives in html::PolicyContainer upstream but Document lives in
// dom in this port. Its already-computed header-policy predicate crosses that
// module boundary explicitly here.
pub fn (mut mixin HTMLOrSVGElement) inserted(csp_contains_header_delivered_policy bool) {
	if !mixin.element.as_node().is_browsing_context_connected() {
		return
	}
	if csp_contains_header_delivered_policy && mixin.element.has_attribute('nonce') {
		nonce := mixin.cryptographic_nonce_
		mut element := unsafe { &dom.Element(mixin.element) }
		element.set_attribute_value('nonce', '')
		mixin.cryptographic_nonce_ = nonce
	}
}
