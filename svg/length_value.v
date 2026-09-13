// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module svg

// SvgLengthValue is the plain scalar backing value used by SVGLength. As in
// upstream, values which contain CSS math or tree-counting functions are not
// represented by this type; SVGLength retains their serialization instead.
pub enum SvgLengthValueKind {
	number
	length
	percentage
}

pub struct SvgLengthValue {
pub:
	kind  SvgLengthValueKind
	unit  LengthUnit
	value f64
}

pub fn SvgLengthValue.number(value f64) SvgLengthValue {
	return SvgLengthValue{
		kind: .number
		unit: .px
		value: value
	}
}

pub fn SvgLengthValue.length(value f64, unit LengthUnit) SvgLengthValue {
	return SvgLengthValue{
		kind: .length
		unit: unit
		value: value
	}
}

pub fn SvgLengthValue.percentage(value f64) SvgLengthValue {
	return SvgLengthValue{
		kind: .percentage
		unit: .px
		value: value
	}
}

pub fn (value SvgLengthValue) to_string() string {
	serialized_number := format_number(value.value)
	return match value.kind {
		.number { serialized_number }
		.percentage { '${serialized_number}%' }
		.length { '${serialized_number}${length_unit_name(value.unit)}' }
	}
}

fn length_unit_name(unit LengthUnit) string {
	return match unit {
		.unknown { '' }
		.number { '' }
		.percentage { '%' }
		.ems { 'em' }
		.exs { 'ex' }
		.px { 'px' }
		.cm { 'cm' }
		.mm { 'mm' }
		.inches { 'in' }
		.pt { 'pt' }
		.pc { 'pc' }
	}
}
