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
	align         Align = .x_mid_y_mid
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

pub struct ViewportSize {
pub:
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
		value: value / 100.0
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
	unknown
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
	// Gfx::AffineTransform stores and operates on floats. Keep the public V
	// representation as f64 for the rest of the translated SVG code, but round
	// every matrix operation exactly where the upstream implementation does.
	left_a := f32(left.a)
	left_b := f32(left.b)
	left_c := f32(left.c)
	left_d := f32(left.d)
	left_e := f32(left.e)
	left_f := f32(left.f)
	right_a := f32(right.a)
	right_b := f32(right.b)
	right_c := f32(right.c)
	right_d := f32(right.d)
	right_e := f32(right.e)
	right_f := f32(right.f)
	return AffineTransform{
		a: f64(right_a * left_a + right_b * left_c)
		b: f64(right_a * left_b + right_b * left_d)
		c: f64(right_c * left_a + right_d * left_c)
		d: f64(right_c * left_b + right_d * left_d)
		e: f64(right_e * left_a + right_f * left_c + left_e)
		f: f64(right_e * left_b + right_f * left_d + left_f)
	}
}

// Gfx::AffineTransform::map(). SVG layout composes transforms in document
// order, then maps geometry into CSS-pixel space through these helpers.
pub fn (transform AffineTransform) map_point(point Point) Point {
	x := f32(point.x)
	y := f32(point.y)
	return Point{
		x: f64(f32(transform.a) * x + f32(transform.c) * y + f32(transform.e))
		y: f64(f32(transform.b) * x + f32(transform.d) * y + f32(transform.f))
	}
}

// Map all four corners and return the axis-aligned bounds. Mapping only the
// top-left and bottom-right is incorrect for rotations and negative scales.
pub fn (transform AffineTransform) map_rect(rect Rect) Rect {
	x := f32(rect.x)
	y := f32(rect.y)
	right := x + f32(rect.width)
	bottom := y + f32(rect.height)
	points := [
		transform.map_point(Point{ x: f64(x), y: f64(y) }),
		transform.map_point(Point{ x: f64(right), y: f64(y) }),
		transform.map_point(Point{ x: f64(x), y: f64(bottom) }),
		transform.map_point(Point{ x: f64(right), y: f64(bottom) }),
	]
	mut min_x := points[0].x
	mut max_x := points[0].x
	mut min_y := points[0].y
	mut max_y := points[0].y
	for point in points[1..] {
		min_x = math.min(min_x, point.x)
		max_x = math.max(max_x, point.x)
		min_y = math.min(min_y, point.y)
		max_y = math.max(max_y, point.y)
	}
	return Rect{
		x: min_x
		y: min_y
		width: max_x - min_x
		height: max_y - min_y
	}
}

pub fn (transform AffineTransform) translated(x f64, y f64) AffineTransform {
	return transform.multiply(AffineTransform{
		e: x
		f: y
	})
}

pub fn (transform AffineTransform) scaled(x f64, y f64) AffineTransform {
	return transform.multiply(AffineTransform{
		a: x
		d: y
	})
}

pub fn (transform AffineTransform) x_scale() f64 {
	a := f32(transform.a)
	b := f32(transform.b)
	return f64(math.sqrtf(a * a + b * b))
}

pub fn (transform Transform) matrix() AffineTransform {
	match transform.kind {
		.unknown {
			return AffineTransform{}
		}
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
			angle := f32(transform.values[0]) * f32(math.pi) / f32(180.0)
			cosine := math.cosf(angle)
			sine := math.sinf(angle)
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
				c: f64(math.tanf(f32(transform.values[0]) * f32(math.pi) / f32(180.0)))
			}
		}
		.skew_y {
			return AffineTransform{
				b: f64(math.tanf(f32(transform.values[0]) * f32(math.pi) / f32(180.0)))
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
	// CSS length units which do not have dedicated SVGLength unitType values.
	// They are retained so valueAsString and value conversion can still follow
	// the current upstream SVGLength implementation.
	q
	cap
	ch
	cqb
	cqh
	cqi
	cqmax
	cqmin
	cqw
	dvb
	dvh
	dvi
	dvmax
	dvmin
	dvw
	ic
	lh
	lvb
	lvh
	lvi
	lvmax
	lvmin
	lvw
	rcap
	rch
	rem
	rex
	ric
	rlh
	svb
	svh
	svi
	svmax
	svmin
	svw
	vb
	vh
	vi
	vmax
	vmin
	vw
}

pub enum SvgLengthDirectionality {
	horizontal
	vertical
	unspecified
}

pub enum SvgLengthSource {
	detached
	reflected_attribute
}

pub struct SvgLengthResolutionContext {
pub:
	has_associated_element bool
	subject_inline_axis_is_horizontal bool = true
	viewport_width         f64 = 100
	viewport_height        f64 = 100
	container_width        f64
	container_height       f64
	font_size              f64 = 16
	root_font_size         f64 = 16
	x_height               f64 = 8
	zero_advance           f64 = 8
	line_height            f64 = 19.2
	root_x_height          f64 = 8
	root_zero_advance      f64 = 8
	root_line_height       f64 = 19.2
}

pub struct SvgLength {
pub mut:
	value                f64
	unit                 LengthUnit
	non_scalar_value     string
	reflected_attributes map[string]string
	resolution_context   SvgLengthResolutionContext
pub:
	read_only      bool
	source         SvgLengthSource
	reflected_name string
	default_value  SvgLengthValue = SvgLengthValue.number(0)
	directionality SvgLengthDirectionality
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
pub:
	base_value &SvgLength = unsafe { nil }
	anim_value &SvgLength = unsafe { nil }
}

pub struct AnimatedLengthList {
pub:
	base_value &LengthList = unsafe { nil }
	anim_value &LengthList = unsafe { nil }
}

pub struct AnimatedNumberList {
pub:
	base_value &NumberList = unsafe { nil }
	anim_value &NumberList = unsafe { nil }
}

pub struct AnimatedTransformList {
pub:
	base_value &TransformList = unsafe { nil }
	anim_value &TransformList = unsafe { nil }
}

pub struct AnimatedRect {
pub mut:
	base_value Rect
	anim_value Rect
	nulled     bool = true
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
	if parts.len == 0 {
		return animated.initial
	}
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
	if parts.len == 0 {
		return animated.initial
	}
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
