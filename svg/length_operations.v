// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// SVGLength's scalar and reflected-attribute algorithms. The CSS parser owns
// non-scalar math evaluation; this module retains those values canonically and
// implements all scalar conversion paths locally to avoid a css <-> svg module
// dependency cycle.
module svg

import math
import strconv

const svg_lengthtype_unknown = u8(0)
const svg_lengthtype_number = u8(1)
const svg_lengthtype_percentage = u8(2)
const svg_lengthtype_ems = u8(3)
const svg_lengthtype_exs = u8(4)
const svg_lengthtype_px = u8(5)
const svg_lengthtype_cm = u8(6)
const svg_lengthtype_mm = u8(7)
const svg_lengthtype_in = u8(8)
const svg_lengthtype_pt = u8(9)
const svg_lengthtype_pc = u8(10)

pub fn SvgLength.create_detached(value SvgLengthValue, read_only bool) SvgLength {
	return SvgLength{
		value: value.value
		unit: svg_length_value_unit(value)
		read_only: read_only
		default_value: value
	}
}

pub fn SvgLength.create_reflected_attribute(element Element, name string, directionality SvgLengthDirectionality, default_value SvgLengthValue, read_only bool) SvgLength {
	return SvgLength{
		value: default_value.value
		unit: svg_length_value_unit(default_value)
		reflected_attributes: element.attributes
		resolution_context: svg_length_context_from_element(element)
		read_only: read_only
		source: .reflected_attribute
		reflected_name: name
		default_value: default_value
		directionality: directionality
	}
}

fn svg_length_context_from_element(element Element) SvgLengthResolutionContext {
	viewport_size := element.viewport_size_for_percentage_resolution()
	viewport_width := viewport_size.width
	viewport_height := viewport_size.height
	font_size := parse_length(element.attributes['font-size'] or { '' }) or { 16 }
	writing_mode := (element.attributes['writing-mode'] or { 'horizontal-tb' }).trim_space().to_lower()
	return SvgLengthResolutionContext{
		has_associated_element: true
		subject_inline_axis_is_horizontal: writing_mode !in ['vertical-rl', 'vertical-lr', 'sideways-rl', 'sideways-lr', 'tb', 'tb-rl']
		viewport_width: viewport_width
		viewport_height: viewport_height
		container_width: parse_length(element.attributes['_container_width'] or { '' }) or { viewport_width }
		container_height: parse_length(element.attributes['_container_height'] or { '' }) or { viewport_height }
		font_size: font_size
		root_font_size: parse_length(element.attributes['_root_font_size'] or { '' }) or { 16 }
		x_height: parse_length(element.attributes['_x_height'] or { '' }) or { font_size / 2 }
		zero_advance: parse_length(element.attributes['_zero_advance'] or { '' }) or { font_size / 2 }
		line_height: parse_length(element.attributes['_line_height'] or { '' }) or { font_size * 1.2 }
		root_x_height: parse_length(element.attributes['_root_x_height'] or { '' }) or { 8 }
		root_zero_advance: parse_length(element.attributes['_root_zero_advance'] or { '' }) or { 8 }
		root_line_height: parse_length(element.attributes['_root_line_height'] or { '' }) or { 19.2 }
	}
}

// The DOM/layout adapter annotates portable SVG element records with the
// viewport that owns their user coordinate system. Reflected SVGLength values
// and geometry APIs share this basis, including the normalized diagonal used
// by directionless percentages.
pub fn (element &Element) viewport_size_for_percentage_resolution() ViewportSize {
	return ViewportSize{
		width: parse_length(element.attributes['_viewport_width'] or { '' }) or { 100 }
		height: parse_length(element.attributes['_viewport_height'] or { '' }) or { 100 }
	}
}

fn svg_length_value_unit(value SvgLengthValue) LengthUnit {
	return match value.kind {
		.number { .number }
		.percentage { .percentage }
		.length { value.unit }
	}
}

fn svg_length_scalar(length &SvgLength) ?SvgLengthValue {
	if length.source == .reflected_attribute {
		attribute := length.reflected_attributes[length.reflected_name] or { return length.default_value }
		return parse_svg_length_scalar(attribute)
	}
	if length.non_scalar_value.len > 0 {
		return none
	}
	return svg_length_value_from_parts(length.value, length.unit)
}

fn svg_length_non_scalar(length &SvgLength) string {
	if length.source == .reflected_attribute {
		attribute := length.reflected_attributes[length.reflected_name] or { return '' }
		if parse_svg_length_scalar(attribute) == none {
			return attribute.trim_space()
		}
		return ''
	}
	return length.non_scalar_value
}

fn svg_length_value_from_parts(value f64, unit LengthUnit) SvgLengthValue {
	return match unit {
		.number { SvgLengthValue.number(value) }
		.percentage { SvgLengthValue.percentage(value) }
		else { SvgLengthValue.length(value, unit) }
	}
}

pub fn parse_svg_length_scalar(input string) ?SvgLengthValue {
	text := input.trim_space()
	if text.len == 0 {
		return none
	}
	units := ['cqmax', 'cqmin', 'dvmax', 'dvmin', 'lvmax', 'lvmin', 'svmax', 'svmin', 'rcap', 'rch',
		'rem', 'rex', 'ric', 'rlh', 'cap', 'cqb', 'cqh', 'cqi', 'cqw', 'dvb', 'dvh', 'dvi', 'dvw',
		'lvb', 'lvh', 'lvi', 'lvw', 'svb', 'svh', 'svi', 'svw', 'vmax', 'vmin', 'ch', 'cm', 'em',
		'ex', 'ic', 'in', 'lh', 'mm', 'pc', 'pt', 'px', 'vb', 'vh', 'vi', 'vw', 'Q']
	if text.ends_with('%') {
		value := strconv.atof64(text[..text.len - 1]) or { return none }
		return SvgLengthValue.percentage(value)
	}
	for suffix in units {
		if text.ends_with(suffix) && text.len > suffix.len {
			value := strconv.atof64(text[..text.len - suffix.len]) or { return none }
			return SvgLengthValue.length(value, length_unit_from_name(suffix)?)
		}
	}
	return SvgLengthValue.number(strconv.atof64(text) or { return none })
}

fn length_unit_from_name(name string) ?LengthUnit {
	return match name {
		'em' { .ems }
		'ex' { .exs }
		'px' { .px }
		'cm' { .cm }
		'mm' { .mm }
		'in' { .inches }
		'pt' { .pt }
		'pc' { .pc }
		'Q' { .q }
		'cap' { .cap }
		'ch' { .ch }
		'cqb' { .cqb }
		'cqh' { .cqh }
		'cqi' { .cqi }
		'cqmax' { .cqmax }
		'cqmin' { .cqmin }
		'cqw' { .cqw }
		'dvb' { .dvb }
		'dvh' { .dvh }
		'dvi' { .dvi }
		'dvmax' { .dvmax }
		'dvmin' { .dvmin }
		'dvw' { .dvw }
		'ic' { .ic }
		'lh' { .lh }
		'lvb' { .lvb }
		'lvh' { .lvh }
		'lvi' { .lvi }
		'lvmax' { .lvmax }
		'lvmin' { .lvmin }
		'lvw' { .lvw }
		'rcap' { .rcap }
		'rch' { .rch }
		'rem' { .rem }
		'rex' { .rex }
		'ric' { .ric }
		'rlh' { .rlh }
		'svb' { .svb }
		'svh' { .svh }
		'svi' { .svi }
		'svmax' { .svmax }
		'svmin' { .svmin }
		'svw' { .svw }
		'vb' { .vb }
		'vh' { .vh }
		'vi' { .vi }
		'vmax' { .vmax }
		'vmin' { .vmin }
		'vw' { .vw }
		else { none }
	}
}

pub fn (length &SvgLength) unit_type() u8 {
	scalar := svg_length_scalar(length) or { return svg_lengthtype_unknown }
	return match scalar.kind {
		.number { svg_lengthtype_number }
		.percentage { svg_lengthtype_percentage }
		.length {
			match scalar.unit {
				.ems { svg_lengthtype_ems }
				.exs { svg_lengthtype_exs }
				.px { svg_lengthtype_px }
				.cm { svg_lengthtype_cm }
				.mm { svg_lengthtype_mm }
				.inches { svg_lengthtype_in }
				.pt { svg_lengthtype_pt }
				.pc { svg_lengthtype_pc }
				else { svg_lengthtype_unknown }
			}
		}
	}
}

fn (length &SvgLength) percentage_resolution_basis() f64 {
	context := length.resolution_context
	if !context.has_associated_element {
		return 100
	}
	return match length.directionality {
		.horizontal { context.viewport_width }
		.vertical { context.viewport_height }
		.unspecified {
			math.sqrt((context.viewport_width * context.viewport_width + context.viewport_height * context.viewport_height) / 2.0)
		}
	}
}

pub fn (length &SvgLength) resolved_value() !f64 {
	scalar := svg_length_scalar(length) or {
		return error('NotSupportedError: non-scalar SVGLength requires CSS calculation context')
	}
	return match scalar.kind {
		.number { scalar.value }
		.percentage { scalar.value * length.percentage_resolution_basis() / 100.0 }
		.length { length.resolve_length_unit(scalar.value, scalar.unit)! }
	}
}

fn (length &SvgLength) resolve_length_unit(value f64, unit LengthUnit) !f64 {
	if is_absolute_svg_length_unit(unit) {
		return value * absolute_svg_length_unit_scale(unit)
	}
	context := length.resolution_context
	if !context.has_associated_element {
		return error('NotSupportedError: Cannot resolve relative length without an associated element')
	}
	return value * match unit {
		.ems { context.font_size }
		.exs { context.x_height }
		.cap { context.font_size * 0.7 }
		.ch { context.zero_advance }
		.ic { context.font_size }
		.lh { context.line_height }
		.rcap { context.root_font_size * 0.7 }
		.rch { context.root_zero_advance }
		.rem { context.root_font_size }
		.rex { context.root_x_height }
		.ric { context.root_font_size }
		.rlh { context.root_line_height }
		.cqw { context.container_width / 100.0 }
		.cqh { context.container_height / 100.0 }
		.cqi { context.container_width / 100.0 }
		.cqb { context.container_height / 100.0 }
		.cqmin { math.min(context.container_width, context.container_height) / 100.0 }
		.cqmax { math.max(context.container_width, context.container_height) / 100.0 }
		.vw, .svw, .lvw, .dvw { context.viewport_width / 100.0 }
		.vh, .svh, .lvh, .dvh { context.viewport_height / 100.0 }
		.vi, .svi, .lvi, .dvi {
			if context.subject_inline_axis_is_horizontal { context.viewport_width / 100.0 } else { context.viewport_height / 100.0 }
		}
		.vb, .svb, .lvb, .dvb {
			if context.subject_inline_axis_is_horizontal { context.viewport_height / 100.0 } else { context.viewport_width / 100.0 }
		}
		.vmin, .svmin, .lvmin, .dvmin {
			math.min(context.viewport_width, context.viewport_height) / 100.0
		}
		.vmax, .svmax, .lvmax, .dvmax {
			math.max(context.viewport_width, context.viewport_height) / 100.0
		}
		else {
			return error('NotSupportedError: Unsupported SVG length unit')
		}
	}
}

fn is_absolute_svg_length_unit(unit LengthUnit) bool {
	return unit in [.px, .cm, .mm, .inches, .pt, .pc, .q]
}

fn absolute_svg_length_unit_scale(unit LengthUnit) f64 {
	return match unit {
		.px { 1.0 }
		.cm { 96.0 / 2.54 }
		.mm { 96.0 / 25.4 }
		.inches { 96.0 }
		.pt { 96.0 / 72.0 }
		.pc { 16.0 }
		.q { 96.0 / 101.6 }
		else { 1 }
	}
}

fn (length &SvgLength) px_to_unit(value f64, unit LengthUnit) !f64 {
	if unit == .number {
		return value
	}
	if unit == .percentage {
		basis := length.percentage_resolution_basis()
		return if basis == 0 { 0 } else { value / basis * 100.0 }
	}
	if is_absolute_svg_length_unit(unit) {
		return value / absolute_svg_length_unit_scale(unit)
	}
	// Resolve one unit in the same context, then divide by that ratio.
	ratio := length.resolve_length_unit(1, unit)!
	return if !math.is_finite(ratio) || ratio == 0 { 0 } else { value / ratio }
}

fn (mut length SvgLength) store_scalar(value SvgLengthValue) {
	length.value = value.value
	length.unit = svg_length_value_unit(value)
	length.non_scalar_value = ''
	if length.source == .reflected_attribute {
		length.reflected_attributes[length.reflected_name] = value.to_string()
	}
}

pub fn (mut length SvgLength) set_value(value f64) ! {
	if length.read_only {
		return error('NoModificationAllowedError: Cannot modify value of read-only SVGLength')
	}
	existing := svg_length_scalar(&length)
	target_unit := if scalar := existing {
		if scalar.kind == .length && is_container_relative_svg_length_unit(scalar.unit) {
			LengthUnit.number
		} else {
			svg_length_value_unit(scalar)
		}
	} else {
		LengthUnit.number
	}
	converted := length.px_to_unit(value, target_unit)!
	length.store_scalar(svg_length_value_from_parts(converted, target_unit))
}

fn is_container_relative_svg_length_unit(unit LengthUnit) bool {
	return unit in [.cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw]
}

pub fn (length &SvgLength) value_in_specified_units() f64 {
	scalar := svg_length_scalar(length) or { return 0 }
	return scalar.value
}

pub fn (mut length SvgLength) set_value_in_specified_units(value f64) ! {
	if length.read_only {
		return error('NoModificationAllowedError: Cannot modify value of read-only SVGLength')
	}
	existing := svg_length_scalar(&length)
	unit := if scalar := existing { svg_length_value_unit(scalar) } else { LengthUnit.number }
	length.store_scalar(svg_length_value_from_parts(value, unit))
}

pub fn (length &SvgLength) value_as_string() string {
	if scalar := svg_length_scalar(length) {
		return scalar.to_string()
	}
	return svg_length_non_scalar(length)
}

pub fn (mut length SvgLength) set_value_as_string(input string) ! {
	if length.read_only {
		return error('NoModificationAllowedError: Cannot modify value of read-only SVGLength')
	}
	text := input.trim_space()
	if scalar := parse_svg_length_scalar(text) {
		length.store_scalar(scalar)
		return
	}
	if !is_supported_non_scalar_svg_length(text) {
		return error('SyntaxError: Failed to parse value as a <number>, <length> or <percentage>')
	}
	length.non_scalar_value = text
	length.unit = .unknown
	length.value = 0
	if length.source == .reflected_attribute {
		length.reflected_attributes[length.reflected_name] = text
	}
}

fn is_supported_non_scalar_svg_length(value string) bool {
	for function_name in ['calc', 'min', 'max', 'clamp', 'round', 'mod', 'rem', 'abs', 'sign'] {
		if value.starts_with('${function_name}(') && value.ends_with(')') {
			return true
		}
	}
	return false
}

pub fn (mut length SvgLength) new_value_specified_units(unit_type u16, value f64) ! {
	if length.read_only {
		return error('NoModificationAllowedError: Cannot modify value of read-only SVGLength')
	}
	unit := length_unit_from_type(unit_type)!
	length.store_scalar(svg_length_value_from_parts(value, unit))
}

pub fn (mut length SvgLength) convert_to_specified_units(unit_type u16) ! {
	if length.read_only {
		return error('NoModificationAllowedError: Cannot modify value of read-only SVGLength')
	}
	unit := length_unit_from_type(unit_type)!
	absolute := length.resolved_value()!
	converted := length.px_to_unit(absolute, unit)!
	length.store_scalar(svg_length_value_from_parts(converted, unit))
}

fn length_unit_from_type(unit_type u16) !LengthUnit {
	return match unit_type {
		1 { .number }
		2 { .percentage }
		3 { .ems }
		4 { .exs }
		5 { .px }
		6 { .cm }
		7 { .mm }
		8 { .inches }
		9 { .pt }
		10 { .pc }
		else { error('NotSupportedError: Unsupported SVGLength unit type') }
	}
}
