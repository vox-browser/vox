// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Web-facing SVG value wrappers and list/animation slot entry points.
module svg

pub fn NumberPercentage.create_number(value f64) NumberPercentage {
	return number(value)
}

pub fn NumberPercentage.create_percentage(value f64) NumberPercentage {
	return percentage(value)
}

pub fn (value NumberPercentage) value() f64 {
	return value.value
}

pub fn SvgLength.create(value f64, unit LengthUnit, read_only bool) SvgLength {
	return SvgLength{
		value: value
		unit: unit
		read_only: read_only
	}
}

pub fn SvgLength.from_length_percentage(value NumberPercentage) SvgLength {
	return SvgLength{
		value: if value.is_percentage { value.value * 100 } else { value.value }
		unit: if value.is_percentage { .percentage } else { .number }
	}
}

pub fn (length &SvgLength) read_only() bool {
	return length.read_only
}

pub fn SvgNumber.create(value f64, read_only bool) SvgNumber {
	return SvgNumber{
		value: value
		read_only: read_only
	}
}

pub fn (value &SvgNumber) read_only() bool {
	return value.read_only
}

pub fn LengthList.create(read_only bool) LengthList {
	return LengthList{
		read_only: read_only
	}
}

pub fn NumberList.create(read_only bool) NumberList {
	return NumberList{
		read_only: read_only
	}
}

pub fn TransformList.create(read_only bool) TransformList {
	return TransformList{
		read_only: read_only
	}
}

pub fn (list &LengthList) items() []SvgLength {
	return list.items
}

pub fn (list &LengthList) read_only() bool {
	return list.read_only
}

pub fn (list &NumberList) items() []f64 {
	return list.items
}

pub fn (list &NumberList) read_only() bool {
	return list.read_only
}

pub fn (list &TransformList) items() []Transform {
	return list.items
}

pub fn (list &TransformList) read_only() bool {
	return list.read_only
}

pub fn Transform.create() Transform {
	return Transform{
		kind: .unknown
	}
}

pub fn (_ &Transform) type_() TransformKind {
	return .unknown
}

pub fn (_ &Transform) angle() f64 {
	return 0
}

pub fn (mut _ Transform) set_translate(_ f64, _ f64) {
}

pub fn (mut _ Transform) set_scale(_ f64, _ f64) {
}

pub fn (mut _ Transform) set_rotate(_ f64, _ f64, _ f64) {
}

pub fn (mut _ Transform) set_skew_x(_ f64) {
}

pub fn (mut _ Transform) set_skew_y(_ f64) {
}

pub fn AnimatedLength.create(value SvgLength) AnimatedLength {
	base_value := &SvgLength{
		value: value.value
		unit: value.unit
		non_scalar_value: value.non_scalar_value
		reflected_attributes: value.reflected_attributes
		resolution_context: value.resolution_context
		read_only: value.read_only
		source: value.source
		reflected_name: value.reflected_name
		default_value: value.default_value
		directionality: value.directionality
	}
	anim_value := &SvgLength{
		value: value.value
		unit: value.unit
		non_scalar_value: value.non_scalar_value
		reflected_attributes: value.reflected_attributes
		resolution_context: value.resolution_context
		read_only: true
		source: value.source
		reflected_name: value.reflected_name
		default_value: value.default_value
		directionality: value.directionality
	}
	return AnimatedLength{ base_value: base_value, anim_value: anim_value }
}

pub fn (animated &AnimatedLength) base_val() &SvgLength {
	return animated.base_value
}

pub fn (animated &AnimatedLength) anim_val() &SvgLength {
	return animated.anim_value
}

pub fn AnimatedLengthList.create(value LengthList) AnimatedLengthList {
	base_value := &LengthList{
		items: value.items
		read_only: value.read_only
	}
	return AnimatedLengthList{ base_value: base_value, anim_value: base_value }
}

pub fn (animated &AnimatedLengthList) base_val() &LengthList {
	return animated.base_value
}

pub fn (animated &AnimatedLengthList) anim_val() &LengthList {
	return animated.anim_value
}

pub fn AnimatedNumberList.create(value NumberList) AnimatedNumberList {
	base_value := &NumberList{
		items: value.items
		read_only: value.read_only
	}
	return AnimatedNumberList{ base_value: base_value, anim_value: base_value }
}

pub fn (animated &AnimatedNumberList) base_val() &NumberList {
	return animated.base_value
}

pub fn (animated &AnimatedNumberList) anim_val() &NumberList {
	return animated.anim_value
}

pub fn AnimatedTransformList.create(base TransformList, animated TransformList) AnimatedTransformList {
	return AnimatedTransformList{
		base_value: &TransformList{
			items: base.items
			read_only: base.read_only
		}
		anim_value: &TransformList{
			items: animated.items
			read_only: animated.read_only
		}
	}
}

pub fn (animated &AnimatedTransformList) base_val() &TransformList {
	return animated.base_value
}

pub fn (animated &AnimatedTransformList) anim_val() &TransformList {
	return animated.anim_value
}

pub fn AnimatedRect.create(value ?Rect) AnimatedRect {
	if rect := value {
		return AnimatedRect{ base_value: rect, anim_value: rect }
	}
	return AnimatedRect{ nulled: true }
}

pub fn (animated &AnimatedRect) base_val() ?Rect {
	return animated.base()
}

pub fn (animated &AnimatedRect) anim_val() ?Rect {
	return animated.animated()
}

pub fn (mut animated AnimatedRect) set_base_val(value Rect) {
	animated.base_value = value
	animated.nulled = false
}

pub fn (mut animated AnimatedRect) set_anim_val(value Rect) {
	animated.anim_value = value
	animated.nulled = false
}

pub fn (mut animated AnimatedRect) set_nulled(value bool) {
	animated.nulled = value
}

pub fn AnimatedEnumeration.create(value u16) AnimatedEnumeration {
	return AnimatedEnumeration{ value: value }
}

pub fn (animated &AnimatedEnumeration) base_val() u16 {
	return animated.value
}

pub fn (animated &AnimatedEnumeration) anim_val() u16 {
	return animated.value
}

pub fn (animated &AnimatedEnumeration) base_or_anim_value() u16 {
	return animated.value
}

pub fn (mut animated AnimatedEnumeration) set_base_val(value u16) ! {
	animated.set_base_value(value)!
}

pub fn AnimatedNumber.create(attribute string, initial f64, supports_second bool, represents_second bool) AnimatedNumber {
	return AnimatedNumber{
		attribute: attribute
		initial: initial
		supports_second: supports_second
		represents_second: represents_second
	}
}

pub fn (animated &AnimatedNumber) base_val() f64 {
	return animated.value()
}

pub fn (animated &AnimatedNumber) anim_val() f64 {
	return animated.value()
}

pub fn (animated &AnimatedNumber) get_base_or_anim_value() f64 {
	return animated.value()
}

pub fn (mut animated AnimatedNumber) set_base_val(value f64) {
	animated.set_base_value(value)
}

pub fn AnimatedInteger.create(attribute string, initial int, supports_second bool, represents_second bool) AnimatedInteger {
	return AnimatedInteger{
		attribute: attribute
		initial: initial
		supports_second: supports_second
		represents_second: represents_second
	}
}

pub fn (animated &AnimatedInteger) base_val() int {
	return animated.value()
}

pub fn (animated &AnimatedInteger) anim_val() int {
	return animated.value()
}

pub fn (animated &AnimatedInteger) get_base_or_anim_value() int {
	return animated.value()
}

pub fn (mut animated AnimatedInteger) set_base_val(value int) {
	animated.set_base_value(value)
}

pub fn AnimatedString.create(primary ?string, legacy ?string, initial ?string) AnimatedString {
	return AnimatedString{ primary: primary, legacy: legacy, initial: initial }
}

pub fn (animated &AnimatedString) base_val() string {
	return animated.value()
}

pub fn (mut animated AnimatedString) set_base_val(value string) {
	animated.set_base_value(value)
}

pub fn (path &Path) instructions() []PathInstruction {
	return path.instructions
}

pub fn (path &Path) to_gfx_path() Path {
	return *path
}

pub fn (instruction &PathInstruction) dump() string {
	return instruction.serialize()
}

pub fn (fit &FitToViewBox) view_box() ?ViewBox {
	return fit.viewbox
}

pub fn (fit &FitToViewBox) view_box_for_bindings() AnimatedRect {
	return fit.bindings_rect
}

pub fn (fit &FitToViewBox) preserve_aspect_ratio() PreserveAspectRatio {
	return fit.preserve_aspect_ratio
}

pub fn (mut fit FitToViewBox) attribute_changed(name string, value ?string) {
	fit.update_attribute(name, value)
}

pub fn (positioning &TextPositioning) apply_to_text_position(index int, current Point, viewport Point) Point {
	mut result := current
	if positioning.x.len > 0 {
		value := positioning.x[if index < positioning.x.len { index } else { positioning.x.len - 1 }]
		result = Point{
			x: value.resolve_relative_to(viewport.x)
			y: result.y
		}
	}
	if positioning.y.len > 0 {
		value := positioning.y[if index < positioning.y.len { index } else { positioning.y.len - 1 }]
		result = Point{
			x: result.x
			y: value.resolve_relative_to(viewport.y)
		}
	}
	if positioning.dx.len > 0 {
		value := positioning.dx[if index < positioning.dx.len {
			index
		} else {
			positioning.dx.len - 1
		}]
		result = Point{
			x: result.x + value.resolve_relative_to(viewport.x)
			y: result.y
		}
	}
	if positioning.dy.len > 0 {
		value := positioning.dy[if index < positioning.dy.len {
			index
		} else {
			positioning.dy.len - 1
		}]
		result = Point{
			x: result.x
			y: result.y + value.resolve_relative_to(viewport.y)
		}
	}
	return result
}
