// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XLink/AttributeNames.{h,cpp}.
module xlink

// attribute_names is kept in the exact macro-enumeration order used upstream.
pub const attribute_names = ['actuate', 'arcrole', 'from', 'href', 'label', 'role', 'show', 'title',
	'to', 'type']

pub fn is_xlink_attribute(name string) bool {
	return name in attribute_names
}
