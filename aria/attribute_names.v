// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/AttributeNames.{h,cpp}.
module aria

pub const aria_attribute_names = [
	'role',
	'aria-activedescendant',
	'aria-atomic',
	'aria-autocomplete',
	'aria-braillelabel',
	'aria-brailleroledescription',
	'aria-busy',
	'aria-checked',
	'aria-colcount',
	'aria-colindex',
	'aria-colindextext',
	'aria-colspan',
	'aria-controls',
	'aria-current',
	'aria-describedby',
	'aria-description',
	'aria-details',
	'aria-dropeffect',
	'aria-errormessage',
	'aria-disabled',
	'aria-expanded',
	'aria-flowto',
	'aria-grabbed',
	'aria-haspopup',
	'aria-hidden',
	'aria-invalid',
	'aria-keyshortcuts',
	'aria-label',
	'aria-labelledby',
	'aria-level',
	'aria-live',
	'aria-modal',
	'aria-multiline',
	'aria-multiselectable',
	'aria-orientation',
	'aria-owns',
	'aria-placeholder',
	'aria-posinset',
	'aria-pressed',
	'aria-readonly',
	'aria-relevant',
	'aria-required',
	'aria-roledescription',
	'aria-rowcount',
	'aria-rowindex',
	'aria-rowindextext',
	'aria-rowspan',
	'aria-selected',
	'aria-setsize',
	'aria-sort',
	'aria-valuemax',
	'aria-valuemin',
	'aria-valuenow',
	'aria-valuetext',
]

pub fn is_aria_attribute_name(name string) bool {
	return name in aria_attribute_names
}
