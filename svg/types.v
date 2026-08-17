module svg

import math

pub enum Units {
	object_bounding_box
	user_space_on_use
}

pub enum SpreadMethod {
	pad
	repeat
	reflect
}

pub enum FillRule {
	nonzero
	evenodd
}

pub enum TextAnchor {
	start
	middle
	end
}

pub enum Align {
	none_
	x_min_y_min
	x_mid_y_min
	x_max_y_min
	x_min_y_mid
	x_mid_y_mid
	x_max_y_mid
	x_min_y_max
	x_mid_y_max
	x_max_y_max
}

pub enum MeetOrSlice {
	meet
	slice
}

pub struct PreserveAspectRatio {
pub:
	align         Align       = .x_mid_y_mid
	meet_or_slice MeetOrSlice = .meet
}

pub struct ViewBox {
pub:
	min_x  f64
	min_y  f64
	width  f64
	height f64
}

pub struct Point {
pub:
	x f64
	y f64
}

pub struct Rect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct NumberPercentage {
pub:
	value         f64
	is_percentage bool
}

pub fn number(value f64) NumberPercentage {
	return NumberPercentage{
		value: value
	}
}

pub fn percentage(value f64) NumberPercentage {
	return NumberPercentage{
		value:         value / 100.0
		is_percentage: true
	}
}

pub fn (n NumberPercentage) resolve_relative_to(length f64) f64 {
	if n.is_percentage {
		return n.value * length
	}
	return n.value
}

pub enum TransformKind {
	translate
	scale
	rotate
	skew_x
	skew_y
	matrix
}

pub struct Transform {
pub:
	kind TransformKind
	// translate/scale use [0..1], rotate [angle,cx,cy], skew [angle], matrix all six.
	values [6]f64
}

pub struct AffineTransform {
pub:
	a f64 = 1
	b f64
	c f64
	d f64 = 1
	e f64
	f f64
}

pub fn (left AffineTransform) multiply(right AffineTransform) AffineTransform {
	return AffineTransform{
		a: left.a * right.a + left.c * right.b
		b: left.b * right.a + left.d * right.b
		c: left.a * right.c + left.c * right.d
		d: left.b * right.c + left.d * right.d
		e: left.a * right.e + left.c * right.f + left.e
		f: left.b * right.e + left.d * right.f + left.f
	}
}

pub fn (transform Transform) matrix() AffineTransform {
	match transform.kind {
		.translate {
			return AffineTransform{
				e: transform.values[0]
				f: transform.values[1]
			}
		}
		.scale {
			return AffineTransform{
				a: transform.values[0]
				d: transform.values[1]
			}
		}
		.rotate {
			angle := transform.values[0] * math.pi / 180.0
			cosine := math.cos(angle)
			sine := math.sin(angle)
			rotation := AffineTransform{
				a: cosine
				b: sine
				c: -sine
				d: cosine
			}
			cx := transform.values[1]
			cy := transform.values[2]
			return AffineTransform{
				e: cx
				f: cy
			}.multiply(rotation).multiply(AffineTransform{
				e: -cx
				f: -cy
			})
		}
		.skew_x {
			return AffineTransform{
				c: math.tan(transform.values[0] * math.pi / 180.0)
			}
		}
		.skew_y {
			return AffineTransform{
				b: math.tan(transform.values[0] * math.pi / 180.0)
			}
		}
		.matrix {
			return AffineTransform{
				a: transform.values[0]
				b: transform.values[1]
				c: transform.values[2]
				d: transform.values[3]
				e: transform.values[4]
				f: transform.values[5]
			}
		}
	}
}

pub fn compose_transforms(transforms []Transform) AffineTransform {
	mut result := AffineTransform{}
	for transform in transforms {
		result = result.multiply(transform.matrix())
	}
	return result
}

pub enum LengthUnit {
	unknown
	number
	percentage
	ems
	exs
	px
	cm
	mm
	inches
	pt
	pc
}

pub struct SvgLength {
pub mut:
	value f64
	unit  LengthUnit
pub:
	read_only bool
}

pub fn (mut length SvgLength) set_value(value f64) ! {
	if length.read_only {
		return error('Cannot modify value of read-only SVGLength')
	}
	length.value = value
	length.unit = .number
}

pub struct SvgNumber {
pub mut:
	value f64
pub:
	read_only bool
}

pub fn (mut number SvgNumber) set_value(value f64) ! {
	if number.read_only {
		return error('Cannot modify value of read-only SVGNumber')
	}
	number.value = value
}

pub struct NumberList {
pub mut:
	items []f64
pub:
	read_only bool
}

pub struct LengthList {
pub mut:
	items []SvgLength
pub:
	read_only bool
}

pub fn (list LengthList) length() u32 {
	return u32(list.items.len)
}

pub fn (list LengthList) number_of_items() u32 {
	return list.length()
}

pub fn (mut list LengthList) clear() ! {
	list.ensure_mutable()!
	list.items.clear()
}

pub fn (mut list LengthList) initialize(value SvgLength) !SvgLength {
	list.ensure_mutable()!
	list.items = [value]
	return value
}

pub fn (list LengthList) get_item(index u32) !SvgLength {
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	return list.items[index]
}

pub fn (mut list LengthList) insert_item_before(value SvgLength, index u32) !SvgLength {
	list.ensure_mutable()!
	position := if index > list.items.len { list.items.len } else { int(index) }
	list.items.insert(position, value)
	return value
}

pub fn (mut list LengthList) replace_item(value SvgLength, index u32) !SvgLength {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	list.items[index] = value
	return value
}

pub fn (mut list LengthList) remove_item(index u32) !SvgLength {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	item := list.items[index]
	list.items.delete(int(index))
	return item
}

pub fn (mut list LengthList) append_item(value SvgLength) !SvgLength {
	list.ensure_mutable()!
	list.items << value
	return value
}

fn (list LengthList) ensure_mutable() ! {
	if list.read_only {
		return error('Cannot modify a read-only list')
	}
}

pub struct TransformList {
pub mut:
	items []Transform
pub:
	read_only bool
}

pub fn (list TransformList) length() u32 {
	return u32(list.items.len)
}

pub fn (list TransformList) number_of_items() u32 {
	return list.length()
}

pub fn (mut list TransformList) clear() ! {
	list.ensure_mutable()!
	list.items.clear()
}

pub fn (mut list TransformList) initialize(value Transform) !Transform {
	list.ensure_mutable()!
	list.items = [value]
	return value
}

pub fn (list TransformList) get_item(index u32) !Transform {
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	return list.items[index]
}

pub fn (mut list TransformList) insert_item_before(value Transform, index u32) !Transform {
	list.ensure_mutable()!
	position := if index > list.items.len { list.items.len } else { int(index) }
	list.items.insert(position, value)
	return value
}

pub fn (mut list TransformList) replace_item(value Transform, index u32) !Transform {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	list.items[index] = value
	return value
}

pub fn (mut list TransformList) remove_item(index u32) !Transform {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	item := list.items[index]
	list.items.delete(int(index))
	return item
}

pub fn (mut list TransformList) append_item(value Transform) !Transform {
	list.ensure_mutable()!
	list.items << value
	return value
}

fn (list TransformList) ensure_mutable() ! {
	if list.read_only {
		return error('Cannot modify a read-only list')
	}
}

pub struct AnimatedLength {
pub mut:
	base_value SvgLength
	anim_value SvgLength
}

pub struct AnimatedLengthList {
pub mut:
	base_value LengthList
	anim_value LengthList
}

pub struct AnimatedNumberList {
pub mut:
	base_value NumberList
	anim_value NumberList
}

pub struct AnimatedTransformList {
pub mut:
	base_value TransformList
	anim_value TransformList
}

pub struct AnimatedRect {
pub mut:
	base_value Rect
	anim_value Rect
	nulled     bool
}

pub fn (rect AnimatedRect) base() ?Rect {
	return if rect.nulled { none } else { rect.base_value }
}

pub fn (rect AnimatedRect) animated() ?Rect {
	return if rect.nulled { none } else { rect.anim_value }
}

pub struct AnimatedEnumeration {
pub mut:
	value u16
}

pub fn (list NumberList) length() u32 {
	return u32(list.items.len)
}

pub fn (list NumberList) number_of_items() u32 {
	return list.length()
}

pub fn (mut enumeration AnimatedEnumeration) set_base_value(value u16) ! {
	if value == 0 {
		return error('invalid value for baseVal')
	}
	enumeration.value = value
}

pub fn (mut list NumberList) clear() ! {
	list.ensure_mutable()!
	list.items.clear()
}

pub fn (mut list NumberList) initialize(value f64) !f64 {
	list.ensure_mutable()!
	list.items = [value]
	return value
}

pub fn (list NumberList) get_item(index u32) !f64 {
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	return list.items[index]
}

pub fn (mut list NumberList) insert_item_before(value f64, index u32) !f64 {
	list.ensure_mutable()!
	position := if index > list.items.len { list.items.len } else { int(index) }
	list.items.insert(position, value)
	return value
}

pub fn (mut list NumberList) replace_item(value f64, index u32) !f64 {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	list.items[index] = value
	return value
}

pub fn (mut list NumberList) remove_item(index u32) !f64 {
	list.ensure_mutable()!
	if index >= list.items.len {
		return error('List index out of bounds')
	}
	item := list.items[index]
	list.items.delete(int(index))
	return item
}

pub fn (mut list NumberList) append_item(value f64) !f64 {
	list.ensure_mutable()!
	list.items << value
	return value
}

fn (list NumberList) ensure_mutable() ! {
	if list.read_only {
		return error('Cannot modify a read-only list')
	}
}

pub struct AnimatedNumber {
pub mut:
	attribute string
pub:
	initial           f64
	supports_second   bool
	represents_second bool
}

pub fn (animated AnimatedNumber) value() f64 {
	if !animated.supports_second {
		return animated.parse_value_or_initial(animated.attribute)
	}
	parts := animated.attribute.split(' ')
	if parts.len == 0 { return animated.initial }
	first := animated.parse_value_or_initial(parts[0])
	if animated.represents_second && parts.len > 1 && parts[1].len > 0 {
		return animated.parse_value_or_initial(parts[1])
	}
	return first
}

pub fn (mut animated AnimatedNumber) set_base_value(value f64) {
	if !animated.supports_second {
		animated.attribute = format_number(value)
		return
	}
	parts := animated.attribute.split(' ')
	mut first := if parts.len > 0 {
		animated.parse_value_or_initial(parts[0])
	} else {
		animated.initial
	}
	mut second := if parts.len > 1 && parts[1].len > 0 {
		animated.parse_value_or_initial(parts[1])
	} else {
		first
	}
	if animated.represents_second {
		second = value
	} else {
		first = value
	}
	animated.attribute = '${format_number(first)} ${format_number(second)}'
}

fn (animated AnimatedNumber) parse_value_or_initial(value string) f64 {
	parsed := parse_number_percentage(value) or { return animated.initial }
	return parsed.value
}

pub struct AnimatedInteger {
pub mut:
	attribute string
pub:
	initial           int
	supports_second   bool
	represents_second bool
}

pub fn (animated AnimatedInteger) value() int {
	if !animated.supports_second {
		return animated.parse_value_or_initial(animated.attribute)
	}
	parts := animated.attribute.split(' ')
	if parts.len == 0 { return animated.initial }
	first := animated.parse_value_or_initial(parts[0])
	if animated.represents_second && parts.len > 1 && parts[1].len > 0 {
		return animated.parse_value_or_initial(parts[1])
	}
	return first
}

pub fn (mut animated AnimatedInteger) set_base_value(value int) {
	if !animated.supports_second {
		animated.attribute = value.str()
		return
	}
	parts := animated.attribute.split(' ')
	mut first := if parts.len > 0 {
		animated.parse_value_or_initial(parts[0])
	} else {
		animated.initial
	}
	mut second := if parts.len > 1 && parts[1].len > 0 {
		animated.parse_value_or_initial(parts[1])
	} else {
		first
	}
	if animated.represents_second {
		second = value
	} else {
		first = value
	}
	animated.attribute = '${first} ${second}'
}

fn (animated AnimatedInteger) parse_value_or_initial(value string) int {
	return parse_integer(value) or { animated.initial }
}

pub struct AnimatedString {
pub mut:
	primary ?string
	legacy  ?string
pub:
	initial ?string
}

pub fn (animated AnimatedString) value() string {
	return animated.primary or { animated.legacy or { animated.initial or { '' } } }
}

pub fn (mut animated AnimatedString) set_base_value(value string) {
	if animated.primary == none && animated.legacy != none {
		animated.legacy = value
	} else {
		animated.primary = value
	}
}

fn format_number(value f64) string {
	if value == f64(i64(value)) {
		return i64(value).str()
	}
	return value.str()
}
