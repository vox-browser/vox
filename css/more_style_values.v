// Translated from the remaining non-image/non-transform LibWeb/CSS StyleValue subclasses.
module css

import dom
import math
import strings

// CursorStyleValue retains the parsed AbstractImageStyleValue, just as the C++
// implementation does. Keeping the typed value is important here: serializing
// and reparsing loses resource/style-sheet ownership and delays image loading.
pub struct CursorImageValue {
pub mut:
	value CSSImageSourceStyleValue
}

pub fn CursorImageValue.create(value CSSImageSourceStyleValue) CursorImageValue {
	return CursorImageValue{
		value: value
	}
}

pub fn (image CursorImageValue) serialize(mode SerializationMode) string {
	return image.value.serialize(mode)
}

pub fn (image CursorImageValue) absolutized(context ComputationContext) CursorImageValue {
	return CursorImageValue.create(image.value.absolutized(context))
}

fn serialize_style_value_sequence(values []StyleValue, separator string, mode SerializationMode) string {
	mut builder := strings.new_builder(values.len * 8)
	for index, value in values {
		if index > 0 {
			builder.write_string(separator)
		}
		builder.write_string(value.serialize(mode))
	}
	return builder.str()
}

fn serialize_style_value_options(values []?StyleValue, separator string, mode SerializationMode) string {
	mut builder := strings.new_builder(values.len * 8)
	mut first := true
	for maybe_value in values {
		value := maybe_value or { continue }
		if !first {
			builder.write_string(separator)
		}
		builder.write_string(value.serialize(mode))
		first = false
	}
	return builder.str()
}

// The shorthands marked `positional-value-list-shorthand` in Properties.json, whose values
// collapse `{1,4}`/`{1,2}` -> shortest form (upstream serialize_a_positional_value_list).
fn serialize_a_positional_value_list(values []StyleValue, mode SerializationMode) string {
	if values.len == 2 {
		first := values[0].serialize(mode)
		second := values[1].serialize(mode)
		return if first == second { first } else { '${first} ${second}' }
	}

	if values.len != 4 {
		return serialize_style_value_sequence(values, ' ', mode)
	}

	top := values[0].serialize(mode)
	right := values[1].serialize(mode)
	bottom := values[2].serialize(mode)
	left := values[3].serialize(mode)

	if top == right && top == bottom && top == left {
		return top
	}
	if top == bottom && right == left {
		return '${top} ${right}'
	}
	if right == left {
		return '${top} ${right} ${bottom}'
	}
	return '${top} ${right} ${bottom} ${left}'
}

fn absolutized_style_value_option(value ?StyleValue, context ComputationContext) ?StyleValue {
	if actual := value {
		return actual.absolutized(context)
	}
	return none
}

fn zero_length_style_value() StyleValue {
	return StyleValue(LengthStyleValue.create(Length.make_px(0)))
}

fn currentcolor_style_value() StyleValue {
	return StyleValue(KeywordStyleValue.create(.currentcolor))
}

fn percentage_style_value(value f64) StyleValue {
	return StyleValue(PercentageStyleValue.create(Percentage.new(value)))
}

// --- Generated enum subset ---
pub enum AnchorSize {
	block
	height
	inline_
	self_block
	self_inline
	width
}

pub fn anchor_size_to_string(value AnchorSize) string {
	return match value {
		.block { 'block' }
		.height { 'height' }
		.inline_ { 'inline' }
		.self_block { 'self-block' }
		.self_inline { 'self-inline' }
		.width { 'width' }
	}
}

pub enum Axis {
	block
	inline_
	x
	y
}

pub fn axis_to_string(value Axis) string {
	return match value {
		.block { 'block' }
		.inline_ { 'inline' }
		.x { 'x' }
		.y { 'y' }
	}
}

pub fn fill_rule_to_string(value FillRule) string {
	return match value {
		.nonzero { 'nonzero' }
		.evenodd { 'evenodd' }
	}
}

pub enum FontStyleKeyword {
	normal
	italic
	left
	right
	oblique
}

pub fn font_style_keyword_to_string(value FontStyleKeyword) string {
	return match value {
		.normal { 'normal' }
		.italic { 'italic' }
		.left { 'left' }
		.right { 'right' }
		.oblique { 'oblique' }
	}
}

pub enum PositionEdge {
	center
	left
	right
	top
	bottom
}

pub fn position_edge_to_string(value PositionEdge) string {
	return match value {
		.center { 'center' }
		.left { 'left' }
		.right { 'right' }
		.top { 'top' }
		.bottom { 'bottom' }
	}
}

pub enum RadialExtent {
	closest_corner
	closest_side
	farthest_corner
	farthest_side
}

pub fn radial_extent_to_string(value RadialExtent) string {
	return match value {
		.closest_corner { 'closest-corner' }
		.closest_side { 'closest-side' }
		.farthest_corner { 'farthest-corner' }
		.farthest_side { 'farthest-side' }
	}
}

pub enum Repetition {
	no_repeat
	repeat
	round
	space
}

pub fn repetition_to_string(value Repetition) string {
	return match value {
		.no_repeat { 'no-repeat' }
		.repeat { 'repeat' }
		.round { 'round' }
		.space { 'space' }
	}
}

pub enum Scroller {
	root
	nearest
	self_
}

pub fn scroller_to_string(value Scroller) string {
	return match value {
		.root { 'root' }
		.nearest { 'nearest' }
		.self_ { 'self' }
	}
}

pub enum ScrollbarGutter {
	auto_
	stable
	both_edges
}

pub enum TextUnderlinePositionHorizontal {
	auto_
	from_font
	under
}

pub fn text_underline_position_horizontal_to_string(value TextUnderlinePositionHorizontal) string {
	return match value {
		.auto_ { 'auto' }
		.from_font { 'from-font' }
		.under { 'under' }
	}
}

pub enum TextUnderlinePositionVertical {
	auto_
	left
	right
}

pub fn text_underline_position_vertical_to_string(value TextUnderlinePositionVertical) string {
	return match value {
		.auto_ { 'auto' }
		.left { 'left' }
		.right { 'right' }
	}
}

pub fn font_tech_to_string(value FontTech) string {
	return match value {
		.features_opentype { 'features-opentype' }
		.features_aat { 'features-aat' }
		.features_graphite { 'features-graphite' }
		.variations { 'variations' }
		.color_colrv0 { 'color-colrv0' }
		.color_colrv1 { 'color-colrv1' }
		.color_svg { 'color-svg' }
		.color_sbix { 'color-sbix' }
		.color_cbdt { 'color-cbdt' }
		.palettes { 'palettes' }
		.incremental { 'incremental' }
		.avar2 { 'avar2' }
	}
}

// --- AnchorStyleValue ---
pub struct AnchorStyleValue {
pub mut:
	anchor_name_    ?string
	anchor_side_    []StyleValue = [StyleValue(KeywordStyleValue{})]
	fallback_value_ &StyleValueSlot = unsafe { nil }
}

pub fn AnchorStyleValue.create(anchor_name ?string, anchor_side StyleValue, fallback_value ?StyleValue) AnchorStyleValue {
	return AnchorStyleValue{
		anchor_name_: anchor_name
		anchor_side_: [anchor_side]
		fallback_value_: optional_style_value_storage(fallback_value)
	}
}

pub fn (style_value AnchorStyleValue) anchor_name() ?string {
	return style_value.anchor_name_
}

pub fn (style_value AnchorStyleValue) anchor_side() StyleValue {
	return style_value.anchor_side_[0]
}

pub fn (style_value AnchorStyleValue) fallback_value() ?StyleValue {
	return style_value_from_optional_storage(style_value.fallback_value_)
}

pub fn (style_value AnchorStyleValue) serialize(mode SerializationMode) string {
	mut serialized := 'anchor('

	if anchor_name := style_value.anchor_name_ {
		serialized += anchor_name
	}

	if style_value.anchor_name_ != none {
		serialized += ' '
	}
	serialized += style_value.anchor_side_[0].serialize(mode)

	if fallback_value := style_value_from_optional_storage(style_value.fallback_value_) {
		serialized += ', ${fallback_value.serialize(mode)}'
	}

	serialized += ')'
	return serialized
}

pub fn (style_value AnchorStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value AnchorStyleValue) properties_equal(other AnchorStyleValue) bool {
	return style_value == other
}

// --- AnchorSizeStyleValue ---
pub struct AnchorSizeStyleValue {
pub mut:
	anchor_name_ ?string
	anchor_size_ ?AnchorSize
	// StyleValue includes AnchorSizeStyleValue, so the optional child must be boxed.
	fallback_value_ &StyleValueSlot = unsafe { nil }
}

pub fn AnchorSizeStyleValue.create(anchor_name ?string, anchor_size ?AnchorSize, fallback_value ?StyleValue) AnchorSizeStyleValue {
	return AnchorSizeStyleValue{
		anchor_name_:    anchor_name
		anchor_size_:    anchor_size
		fallback_value_: optional_style_value_storage(fallback_value)
	}
}

pub fn (style_value AnchorSizeStyleValue) anchor_name() ?string {
	return style_value.anchor_name_
}

pub fn (style_value AnchorSizeStyleValue) anchor_size() ?AnchorSize {
	return style_value.anchor_size_
}

pub fn (style_value AnchorSizeStyleValue) fallback_value() ?StyleValue {
	return style_value_from_optional_storage(style_value.fallback_value_)
}

pub fn (style_value AnchorSizeStyleValue) serialize(mode SerializationMode) string {
	// FIXME: Handle SerializationMode.
	mut serialized := 'anchor-size('

	if anchor_name := style_value.anchor_name_ {
		serialized += anchor_name
	}

	if anchor_size := style_value.anchor_size_ {
		if style_value.anchor_name_ != none {
			serialized += ' '
		}
		serialized += anchor_size_to_string(anchor_size)
	}

	if fallback_value := style_value_from_optional_storage(style_value.fallback_value_) {
		if style_value.anchor_name_ != none || style_value.anchor_size_ != none {
			serialized += ', '
		}
		serialized += fallback_value.serialize(mode)
	}

	serialized += ')'
	return serialized
}

pub fn (style_value AnchorSizeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value AnchorSizeStyleValue) properties_equal(other AnchorSizeStyleValue) bool {
	return style_value == other
}

// --- FunctionStyleValue ---
pub struct FunctionStyleValue {
pub mut:
	name_  string
	value_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn FunctionStyleValue.create(name string, value StyleValue) FunctionStyleValue {
	return FunctionStyleValue{
		name_: name
		value_: [value]
	}
}

pub fn (style_value FunctionStyleValue) name() string {
	return style_value.name_
}

pub fn (style_value FunctionStyleValue) value() StyleValue {
	return style_value.value_[0]
}

pub fn (style_value FunctionStyleValue) absolutized(context ComputationContext) StyleValue {
	computed_value := style_value.value_[0].absolutized(context)
	absolutized_value := if style_value.name_ == '-webkit-cross-fade' { compute_webkit_cross_fade(computed_value,context) } else { computed_value }
	if absolutized_value.equals(style_value.value_[0]) {
		return StyleValue(style_value)
	}
	return StyleValue(FunctionStyleValue.create(style_value.name_, absolutized_value))
}

pub fn (style_value FunctionStyleValue) serialize(mode SerializationMode) string {
	if style_value.name_ == calc_size_function_name {
		return serialize_calc_size_function(style_value, mode)
	}
	return '${style_value.name_}(${style_value.value_[0].serialize(mode)})'
}

pub fn (style_value FunctionStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value FunctionStyleValue) properties_equal(other FunctionStyleValue) bool {
	return style_value.name_ == other.name_ && style_value.value_[0].equals(other.value_[0])
}

// --- BackgroundSizeStyleValue ---
pub struct BackgroundSizeStyleValue {
pub mut:
	size_x_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	size_y_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn BackgroundSizeStyleValue.create(size_x StyleValue, size_y StyleValue) BackgroundSizeStyleValue {
	return BackgroundSizeStyleValue{
		size_x_: [size_x]
		size_y_: [size_y]
	}
}

pub fn (style_value BackgroundSizeStyleValue) size_x() StyleValue {
	return style_value.size_x_[0]
}

pub fn (style_value BackgroundSizeStyleValue) size_y() StyleValue {
	return style_value.size_y_[0]
}

pub fn (style_value BackgroundSizeStyleValue) serialize(mode SerializationMode) string {
	if style_value.size_x_[0].has_auto() && style_value.size_y_[0].has_auto() {
		return 'auto'
	}
	return '${style_value.size_x_[0].serialize(mode)} ${style_value.size_y_[0].serialize(mode)}'
}

pub fn (style_value BackgroundSizeStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_size_x := style_value.size_x_[0].absolutized(context)
	absolutized_size_y := style_value.size_y_[0].absolutized(context)
	if absolutized_size_x == style_value.size_x_[0] && absolutized_size_y == style_value.size_y_[0] {
		return StyleValue(style_value)
	}
	return StyleValue(BackgroundSizeStyleValue.create(absolutized_size_x, absolutized_size_y))
}

pub fn (style_value BackgroundSizeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value BackgroundSizeStyleValue) properties_equal(other BackgroundSizeStyleValue) bool {
	return style_value == other
}

// --- BorderImageSliceStyleValue ---
pub struct BorderImageSliceStyleValue {
pub mut:
	top_    []StyleValue = [StyleValue(KeywordStyleValue{})]
	right_  []StyleValue = [StyleValue(KeywordStyleValue{})]
	bottom_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	left_   []StyleValue = [StyleValue(KeywordStyleValue{})]
	fill_   bool
}

pub fn BorderImageSliceStyleValue.create(top StyleValue, right StyleValue, bottom StyleValue, left StyleValue, fill bool) BorderImageSliceStyleValue {
	return BorderImageSliceStyleValue{
		top_: [top]
		right_: [right]
		bottom_: [bottom]
		left_: [left]
		fill_: fill
	}
}

pub fn (style_value BorderImageSliceStyleValue) top() StyleValue {
	return style_value.top_[0]
}

pub fn (style_value BorderImageSliceStyleValue) right() StyleValue {
	return style_value.right_[0]
}

pub fn (style_value BorderImageSliceStyleValue) bottom() StyleValue {
	return style_value.bottom_[0]
}

pub fn (style_value BorderImageSliceStyleValue) left() StyleValue {
	return style_value.left_[0]
}

pub fn (style_value BorderImageSliceStyleValue) fill() bool {
	return style_value.fill_
}

pub fn (style_value BorderImageSliceStyleValue) serialize(mode SerializationMode) string {
	mut serialized := style_value.top_[0].serialize(mode)
	if !(style_value.top_[0] == style_value.right_[0] && style_value.top_[0] == style_value.bottom_[0] && style_value.top_[0] == style_value.left_[0]) {
		serialized += ' ${style_value.right_[0].serialize(mode)}'
		if style_value.top_[0] != style_value.bottom_[0] || style_value.right_[0] != style_value.left_[0] {
			serialized += ' ${style_value.bottom_[0].serialize(mode)}'
			if style_value.left_[0] != style_value.right_[0] {
				serialized += ' ${style_value.left_[0].serialize(mode)}'
			}
		}
	}

	if style_value.fill_ {
		serialized += ' fill'
	}
	return serialized
}

fn computed_border_slice_component(value StyleValue, context ComputationContext) StyleValue {
 absolute := value.absolutized(context)
 if absolute is CalculatedStyleValue {
  resolution := CalculationResolutionContext{length_resolution_context:context.length_resolution_context}
  if absolute.resolves_to_number() {
   if number := absolute.resolve_number(resolution) { return StyleValue(NumberStyleValue.create(if number < 0 { 0.0 } else { number })) }
  } else if absolute.resolves_to_percentage() {
   if percentage := absolute.resolve_percentage(resolution) { return StyleValue(PercentageStyleValue.create(Percentage.new(if percentage.value() < 0 { 0.0 } else { percentage.value() }))) }
  }
 }
 return absolute
}

pub fn (style_value BorderImageSliceStyleValue) absolutized(context ComputationContext) StyleValue {
 top := computed_border_slice_component(style_value.top(),context)
 right := computed_border_slice_component(style_value.right(),context)
 bottom := computed_border_slice_component(style_value.bottom(),context)
 left := computed_border_slice_component(style_value.left(),context)
 if top == style_value.top() && right == style_value.right()
  && bottom == style_value.bottom() && left == style_value.left() { return StyleValue(style_value) }
 return StyleValue(BorderImageSliceStyleValue.create(top,right,bottom,left,style_value.fill()))
}

pub fn (style_value BorderImageSliceStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value BorderImageSliceStyleValue) properties_equal(other BorderImageSliceStyleValue) bool {
	return style_value == other
}

// --- BorderRadiusStyleValue ---
pub struct BorderRadiusStyleValue {
pub mut:
	is_elliptical_    bool
	horizontal_radius []StyleValue = [StyleValue(KeywordStyleValue{})]
	vertical_radius   []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn BorderRadiusStyleValue.create_zero() BorderRadiusStyleValue {
	return BorderRadiusStyleValue.create(zero_length_style_value(), zero_length_style_value())
}

pub fn BorderRadiusStyleValue.create(horizontal_radius StyleValue, vertical_radius StyleValue) BorderRadiusStyleValue {
	return BorderRadiusStyleValue{
		is_elliptical_: horizontal_radius != vertical_radius
		horizontal_radius: [horizontal_radius]
		vertical_radius: [vertical_radius]
	}
}

pub fn (style_value BorderRadiusStyleValue) horizontal_radius_() StyleValue {
	return style_value.horizontal_radius[0]
}

pub fn (style_value BorderRadiusStyleValue) vertical_radius_() StyleValue {
	return style_value.vertical_radius[0]
}

pub fn (style_value BorderRadiusStyleValue) is_elliptical() bool {
	return style_value.is_elliptical_
}

pub fn (style_value BorderRadiusStyleValue) serialize(mode SerializationMode) string {
	if style_value.horizontal_radius[0] == style_value.vertical_radius[0] {
		return style_value.horizontal_radius[0].serialize(mode)
	}
	return '${style_value.horizontal_radius[0].serialize(mode)} ${style_value.vertical_radius[0].serialize(mode)}'
}

pub fn (style_value BorderRadiusStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_horizontal_radius := style_value.horizontal_radius[0].absolutized(context)
	absolutized_vertical_radius := style_value.vertical_radius[0].absolutized(context)

	if absolutized_vertical_radius == style_value.vertical_radius[0] && absolutized_horizontal_radius == style_value.horizontal_radius[0] {
		return StyleValue(style_value)
	}

	return StyleValue(BorderRadiusStyleValue.create(absolutized_horizontal_radius, absolutized_vertical_radius))
}

pub fn (style_value BorderRadiusStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value BorderRadiusStyleValue) properties_equal(other BorderRadiusStyleValue) bool {
	return style_value == other
}

// --- BorderRadiusRectStyleValue ---
pub struct BorderRadiusRectStyleValue {
pub mut:
	top_left_     []StyleValue = [StyleValue(KeywordStyleValue{})]
	top_right_    []StyleValue = [StyleValue(KeywordStyleValue{})]
	bottom_right_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	bottom_left_  []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn BorderRadiusRectStyleValue.create_zero() BorderRadiusRectStyleValue {
	return BorderRadiusRectStyleValue.create(StyleValue(BorderRadiusStyleValue.create_zero()), StyleValue(BorderRadiusStyleValue.create_zero()), StyleValue(BorderRadiusStyleValue.create_zero()), StyleValue(BorderRadiusStyleValue.create_zero()))
}

pub fn BorderRadiusRectStyleValue.create(top_left StyleValue, top_right StyleValue, bottom_right StyleValue, bottom_left StyleValue) BorderRadiusRectStyleValue {
	return BorderRadiusRectStyleValue{
		top_left_: [top_left]
		top_right_: [top_right]
		bottom_right_: [bottom_right]
		bottom_left_: [bottom_left]
	}
}

pub fn (style_value BorderRadiusRectStyleValue) top_left() StyleValue {
	return style_value.top_left_[0]
}

pub fn (style_value BorderRadiusRectStyleValue) top_right() StyleValue {
	return style_value.top_right_[0]
}

pub fn (style_value BorderRadiusRectStyleValue) bottom_right() StyleValue {
	return style_value.bottom_right_[0]
}

pub fn (style_value BorderRadiusRectStyleValue) bottom_left() StyleValue {
	return style_value.bottom_left_[0]
}

fn border_radius_from_style_value(value StyleValue) BorderRadiusStyleValue {
	if actual := value.as_border_radius() {
		return actual
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value BorderRadiusRectStyleValue) serialize(mode SerializationMode) string {
	top_left := border_radius_from_style_value(style_value.top_left_[0])
	top_right := border_radius_from_style_value(style_value.top_right_[0])
	bottom_right := border_radius_from_style_value(style_value.bottom_right_[0])
	bottom_left := border_radius_from_style_value(style_value.bottom_left_[0])

	horizontal_radii_serialized := serialize_a_positional_value_list([
		top_left.horizontal_radius[0],
		top_right.horizontal_radius[0],
		bottom_right.horizontal_radius[0],
		bottom_left.horizontal_radius[0],
	], mode)

	vertical_radii_serialized := serialize_a_positional_value_list([
		top_left.vertical_radius[0],
		top_right.vertical_radius[0],
		bottom_right.vertical_radius[0],
		bottom_left.vertical_radius[0],
	], mode)

	if horizontal_radii_serialized == vertical_radii_serialized {
		return horizontal_radii_serialized
	}

	return '${horizontal_radii_serialized} / ${vertical_radii_serialized}'
}

pub fn (style_value BorderRadiusRectStyleValue) absolutized(context ComputationContext) StyleValue {
	return StyleValue(BorderRadiusRectStyleValue.create(style_value.top_left_[0].absolutized(context), style_value.top_right_[0].absolutized(context), style_value.bottom_right_[0].absolutized(context), style_value.bottom_left_[0].absolutized(context)))
}

pub fn (style_value BorderRadiusRectStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value BorderRadiusRectStyleValue) properties_equal(other BorderRadiusRectStyleValue) bool {
	return style_value == other
}

// --- BasicShapeStyleValue ---
pub struct BasicShapeInset {
pub mut:
	top           StyleValue
	right         StyleValue
	bottom        StyleValue
	left          StyleValue
	border_radius StyleValue
}

pub struct BasicShapeXywh {
pub mut:
	x             StyleValue
	y             StyleValue
	width         StyleValue
	height        StyleValue
	border_radius StyleValue
}

pub struct BasicShapeRect {
pub mut:
	top           StyleValue
	right         StyleValue
	bottom        StyleValue
	left          StyleValue
	border_radius StyleValue
}

pub struct BasicShapeCircle {
pub mut:
	radius   StyleValue
	position ?StyleValue
}

pub struct BasicShapeEllipse {
pub mut:
	radius   StyleValue
	position ?StyleValue
}

pub struct BasicShapePolygonPoint {
pub mut:
	x StyleValue
	y StyleValue
}

pub struct BasicShapePolygon {
pub mut:
	fill_rule FillRule
	round_radius StyleValue = StyleValue(LengthStyleValue.create(Length.make_px(0)))
	points    []BasicShapePolygonPoint
}

pub struct BasicShapePath {
pub mut:
	fill_rule         FillRule
	path_instructions string
}

pub type BasicShape = BasicShapeCircle
	| BasicShapeEllipse
	| BasicShapeCommands
	| BasicShapeInset
	| BasicShapePath
	| BasicShapePolygon
	| BasicShapeRect
	| BasicShapeXywh

pub struct BasicShapeStyleValue {
pub mut:
	basic_shape_ []BasicShape = [BasicShape(BasicShapeCircle{})]
}

pub fn BasicShapeStyleValue.create(basic_shape BasicShape) BasicShapeStyleValue {
	return BasicShapeStyleValue{
		basic_shape_: [basic_shape]
	}
}

pub fn (style_value BasicShapeStyleValue) basic_shape() BasicShape {
	return style_value.basic_shape_[0]
}

pub fn (shape BasicShapeInset) serialize(mode SerializationMode) string {
	mut serialized := 'inset('
	serialized += serialize_a_positional_value_list([shape.top, shape.right, shape.bottom,
		shape.left], mode)

	serialized_border_radius := shape.border_radius.serialize(mode)
	if serialized_border_radius != '0px' {
		serialized += ' round ${serialized_border_radius}'
	}

	serialized += ')'
	return serialized
}

pub fn (shape BasicShapeXywh) serialize(mode SerializationMode) string {
	mut serialized := 'xywh('
	serialized += '${shape.x.serialize(mode)} ${shape.y.serialize(mode)} ${shape.width.serialize(mode)} ${shape.height.serialize(mode)}'

	serialized_border_radius := shape.border_radius.serialize(mode)
	if serialized_border_radius != '0px' {
		serialized += ' round ${serialized_border_radius}'
	}

	serialized += ')'
	return serialized
}

pub fn (shape BasicShapeRect) serialize(mode SerializationMode) string {
	mut serialized := 'rect('
	serialized += '${shape.top.serialize(mode)} ${shape.right.serialize(mode)} ${shape.bottom.serialize(mode)} ${shape.left.serialize(mode)}'

	serialized_border_radius := shape.border_radius.serialize(mode)
	if serialized_border_radius != '0px' {
		serialized += ' round ${serialized_border_radius}'
	}

	serialized += ')'
	return serialized
}

pub fn (shape BasicShapeCircle) serialize(mode SerializationMode) string {
	mut serialized := 'circle('
	serialized_radius := shape.radius.serialize(mode)

	has_radius := serialized_radius != 'closest-side'
	if has_radius {
		serialized += serialized_radius
	}

	if position := shape.position {
		if has_radius {
			serialized += ' '
		}
		serialized += 'at ${position.serialize(mode)}'
	}

	serialized += ')'
	return serialized
}

pub fn (shape BasicShapeEllipse) serialize(mode SerializationMode) string {
	mut serialized := 'ellipse('
	serialized_radius := shape.radius.serialize(mode)

	has_radius := serialized_radius != 'closest-side closest-side'
	if has_radius {
		serialized += serialized_radius
	}

	if position := shape.position {
		if has_radius {
			serialized += ' '
		}
		serialized += 'at ${position.serialize(mode)}'
	}

	serialized += ')'
	return serialized
}

pub fn (shape BasicShapePolygon) serialize(mode SerializationMode) string {
	mut serialized := 'polygon('
	mut first := true
	match shape.fill_rule {
		.nonzero {}
		.evenodd {
			first = false
			serialized += 'evenodd'
		}
	}

	if shape.round_radius.serialize(mode) != '0px' {
		if !first { serialized += ' ' }
		serialized += 'round '+shape.round_radius.serialize(mode)
		first = false
	}
	for point in shape.points {
		if !first {
			serialized += ', '
		}
		first = false
		serialized += '${point.x.serialize(mode)} ${point.y.serialize(mode)}'
	}
	serialized += ')'
	return serialized
}

pub fn (shape BasicShapePath) serialize(mode SerializationMode) string {
	mut serialized := 'path('

	if shape.fill_rule == .evenodd { serialized += 'evenodd, ' }

	serialized += serialize_a_string(shape.path_instructions)
	serialized += ')'
	return serialized
}

pub fn (style_value BasicShapeStyleValue) serialize(mode SerializationMode) string {
	shape := style_value.basic_shape_[0]
	return match shape {
		BasicShapeCommands { shape.serialize(mode) }
		BasicShapeInset { shape.serialize(mode) }
		BasicShapeXywh { shape.serialize(mode) }
		BasicShapeRect { shape.serialize(mode) }
		BasicShapeCircle { shape.serialize(mode) }
		BasicShapeEllipse { shape.serialize(mode) }
		BasicShapePolygon { shape.serialize(mode) }
		BasicShapePath { shape.serialize(mode) }
	}
}

fn basic_shape_percentage_value(style_value StyleValue) ?f64 {
	return match style_value {
		PercentageStyleValue { style_value.percentage().value() }
		else { none }
	}
}

fn basic_shape_one_hundred_percent_minus(values []StyleValue, context ComputationContext) StyleValue {
	if values.len == 0 {
		return percentage_style_value(100)
	}

	mut absolutized_values := []StyleValue{cap: values.len}
	mut percentage_total := 0.0
	mut all_values_are_percentages := true
	for value in values {
		absolutized_value := value.absolutized(context)
		absolutized_values << absolutized_value
		if percentage_value := basic_shape_percentage_value(absolutized_value) {
			percentage_total += percentage_value
		} else {
			all_values_are_percentages = false
		}
	}

	if all_values_are_percentages {
		return percentage_style_value(100.0 - percentage_total)
	}

	// Construct the same calc(100% - ...) tree as the C++ implementation. The helper parses the
	// synthesized expression into a typed CalcNode rather than retaining serialized text.
	mut serialized := 'calc(100%'
	for value in absolutized_values {
		serialized += ' - ${value.serialize(.normal)}'
	}
	serialized += ')'
	return calculated_style_value_from_text(serialized)
}

fn basic_shape_rect_resolve_auto(style_value StyleValue, value_of_auto f64) StyleValue {
	if style_value.is_keyword() {
		if style_value.to_keyword() != .auto {
			panic('VERIFY_NOT_REACHED')
		}
		return percentage_style_value(value_of_auto)
	}

	return style_value
}

pub fn (style_value BasicShapeStyleValue) absolutized(context ComputationContext) StyleValue {
	// The values in a <basic-shape> function are computed as specified, with these exceptions:
	// - Omitted values are included and compute to their defaults.
	// FIXME: A <position> value in circle() or ellipse() is computed as a pair of offsets (horizontal then vertical)
	//        from the top left origin, each given as a <length-percentage>.
	// FIXME: A <'border-radius'> value in a <basic-shape-rect> function is computed as an expanded list of all eight
	//        <length-percentage> values.
	// - All <basic-shape-rect> functions compute to the equivalent inset() function.
	shape := style_value.basic_shape_[0]
	absolutized_shape := match shape {
		BasicShapeCommands { BasicShape(shape.absolutized(context)) }
		BasicShapeInset {
			BasicShape(BasicShapeInset{
				top: shape.top.absolutized(context)
				right: shape.right.absolutized(context)
				bottom: shape.bottom.absolutized(context)
				left: shape.left.absolutized(context)
				border_radius: shape.border_radius.absolutized(context)
			})
		}
		BasicShapeXywh {
			// Note: Given xywh(x y w h), the equivalent function is inset(y calc(100% - x - w)
			// calc(100% - y - h) x).
			BasicShape(BasicShapeInset{
				top: shape.y.absolutized(context)
				right: basic_shape_one_hundred_percent_minus([shape.x, shape.width], context)
				bottom: basic_shape_one_hundred_percent_minus([shape.y, shape.height], context)
				left: shape.x.absolutized(context)
				border_radius: shape.border_radius.absolutized(context)
			})
		}
		BasicShapeRect {
			// Note: Given rect(t r b l), the equivalent function is inset(t calc(100% - r) calc(100% - b) l).
			BasicShape(BasicShapeInset{
				top: basic_shape_rect_resolve_auto(shape.top, 0).absolutized(context)
				right: basic_shape_one_hundred_percent_minus([
					basic_shape_rect_resolve_auto(shape.right, 100),
				], context)
				bottom: basic_shape_one_hundred_percent_minus([
					basic_shape_rect_resolve_auto(shape.bottom, 100),
				], context)
				left: basic_shape_rect_resolve_auto(shape.left, 0).absolutized(context)
				border_radius: shape.border_radius.absolutized(context)
			})
		}
		BasicShapeCircle {
			BasicShape(BasicShapeCircle{
				radius: shape.radius.absolutized(context)
				position: absolutized_style_value_option(shape.position, context)
			})
		}
		BasicShapeEllipse {
			BasicShape(BasicShapeEllipse{
				radius: shape.radius.absolutized(context)
				position: absolutized_style_value_option(shape.position, context)
			})
		}
		BasicShapePolygon {
			mut points := []BasicShapePolygonPoint{cap: shape.points.len}
			for point in shape.points {
				points << BasicShapePolygonPoint{
					x: point.x.absolutized(context)
					y: point.y.absolutized(context)
				}
			}
			BasicShape(BasicShapePolygon{
				fill_rule: shape.fill_rule
				round_radius:shape.round_radius.absolutized(context)
				points: points
			})
		}
		BasicShapePath {
			BasicShape(shape)
		}
	}

	if absolutized_shape == style_value.basic_shape_[0] {
		return StyleValue(style_value)
	}
	return StyleValue(BasicShapeStyleValue.create(absolutized_shape))
}

pub fn (style_value BasicShapeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value BasicShapeStyleValue) properties_equal(other BasicShapeStyleValue) bool {
	return style_value.basic_shape_[0] == other.basic_shape_[0]
}

// --- ContentStyleValue ---
pub struct ContentStyleValue {
pub mut:
	content_  StyleValueList
	alt_text_ ?StyleValueList
}

pub fn ContentStyleValue.create(content StyleValueList, alt_text ?StyleValueList) ContentStyleValue {
	return ContentStyleValue{
		content_: content
		alt_text_: alt_text
	}
}

pub fn (style_value ContentStyleValue) content() StyleValueList {
	return style_value.content_
}

pub fn (style_value ContentStyleValue) alt_text() ?StyleValueList {
	return style_value.alt_text_
}

pub fn (mut style_value ContentStyleValue) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	style_value.content_.set_style_sheet(style_sheet)
	if alt_text := style_value.alt_text_ {
		mut mutable_alt_text := alt_text
		mutable_alt_text.set_style_sheet(style_sheet)
		style_value.alt_text_ = mutable_alt_text
	}
}

pub fn (style_value ContentStyleValue) absolutized(context ComputationContext) StyleValue {
	content := style_value.content_.absolutized(context)
	alt_text := if value := style_value.alt_text_ { ?StyleValueList(value.absolutized(context) as StyleValueList) } else { none }
	return StyleValue(ContentStyleValue.create(content as StyleValueList,alt_text))
}

pub fn (style_value ContentStyleValue) serialize(mode SerializationMode) string {
	mut serialized := style_value.content_.serialize(mode)
	if alt_text := style_value.alt_text_ {
		serialized += ' / ${alt_text.serialize(mode)}'
	}
	return serialized
}

pub fn (style_value ContentStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value ContentStyleValue) properties_equal(other ContentStyleValue) bool {
	return style_value == other
}

// --- CursorStyleValue ---
pub struct CursorStyleValue {
pub mut:
	image_ []CursorImageValue = [CursorImageValue{}]
	x_     &StyleValueSlot = unsafe { nil }
	y_     &StyleValueSlot = unsafe { nil }
}

pub fn CursorStyleValue.create(image CursorImageValue, x ?StyleValue, y ?StyleValue) CursorStyleValue {
	// We require either both or neither the X and Y parameters.
	if !((x == none && y == none) || (x != none && y != none)) {
		panic('VERIFY_NOT_REACHED')
	}
	return CursorStyleValue{
		image_: [image]
		x_: optional_style_value_storage(x)
		y_: optional_style_value_storage(y)
	}
}

pub fn (style_value CursorStyleValue) serialize(mode SerializationMode) string {
	mut serialized := style_value.image_[0].serialize(mode)
	if x := style_value_from_optional_storage(style_value.x_) {
		y := style_value_from_optional_storage(style_value.y_) or { panic('VERIFY_NOT_REACHED') }
		serialized += ' ${x.serialize(mode)} ${y.serialize(mode)}'
	}
	return serialized
}

pub fn (style_value CursorStyleValue) absolutized(context ComputationContext) StyleValue {
	return StyleValue(CursorStyleValue.create(style_value.image_[0].absolutized(context), absolutized_style_value_option(style_value_from_optional_storage(style_value.x_), context), absolutized_style_value_option(style_value_from_optional_storage(style_value.y_), context)))
}

pub fn (style_value CursorStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value CursorStyleValue) properties_equal(other CursorStyleValue) bool {
	return style_value == other
}

// --- DisplayStyleValue ---
pub struct DisplayStyleValue {
pub mut:
	display_ Display
}

pub fn DisplayStyleValue.create(display Display) DisplayStyleValue {
	return DisplayStyleValue{
		display_: display
	}
}

pub fn (style_value DisplayStyleValue) display() Display {
	return style_value.display_
}

pub fn (style_value DisplayStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.display_.to_string()
}

pub fn (style_value DisplayStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value DisplayStyleValue) properties_equal(other DisplayStyleValue) bool {
	return style_value.display_ == other.display_
}

pub fn (style_value DisplayStyleValue) reify(associated_property string) CSSStyleValue {
	if keyword := style_value.display_.to_keyword() {
		return CSSStyleValue.from_keyword(CSSKeywordValue.create(string_from_keyword(keyword)))
	}
	return CSSStyleValue.create(associated_property, StyleValue(style_value))
}

// --- EasingStyleValue ---
pub struct EasingLinearStop {
pub mut:
	output StyleValue
	input  ?StyleValue
}

pub struct EasingLinear {
pub mut:
	stops []EasingLinearStop
}

pub struct EasingCubicBezier {
pub mut:
	x1 StyleValue
	y1 StyleValue
	x2 StyleValue
	y2 StyleValue
}

pub struct EasingSteps {
pub mut:
	number_of_intervals StyleValue
	position            StepPosition
}

pub type EasingStyleValueFunction = EasingCubicBezier | EasingLinear | EasingSteps

pub struct EasingStyleValue {
pub mut:
	function_ []EasingStyleValueFunction = [EasingStyleValueFunction(EasingCubicBezier{})]
}

pub fn EasingStyleValue.create(function EasingStyleValueFunction) EasingStyleValue {
	return EasingStyleValue{
		function_: [function]
	}
}

pub fn (style_value EasingStyleValue) function() EasingStyleValueFunction {
	return style_value.function_[0]
}

pub fn (linear EasingLinear) serialize(mode SerializationMode) string {
	// To serialize a linear() function:
	// 1. Let s be the string "linear(".
	mut serialized := 'linear('

	// 2. Serialize each control point of the function, concatenate the results using the separator ", ", and append
	//    the result to s.
	for index, stop in linear.stops {
		if index > 0 {
			serialized += ', '
		}

		// To serialize a linear() control point:
		// 1. Let s be the serialization, as a <number>, of the control point's output progress value.
		serialized += stop.output.serialize(mode)

		// 2. If the control point originally lacked an input progress value, return s.
		// 3. Otherwise, append " " (U+0020 SPACE) to s, then serialize the control point's input progress value as a
		//    <percentage> and append it to s.
		if input := stop.input {
			serialized += ' ${input.serialize(mode)}'
		}

		// 4. Return s.
	}

	// 4. Append ")" to s, and return it.
	serialized += ')'
	return serialized
}

pub fn (cubic_bezier EasingCubicBezier) serialize(mode SerializationMode) string {
	return 'cubic-bezier(${cubic_bezier.x1.serialize(mode)}, ${cubic_bezier.y1.serialize(mode)}, ${cubic_bezier.x2.serialize(mode)}, ${cubic_bezier.y2.serialize(mode)})'
}

pub fn step_position_to_css_string(position StepPosition) string {
	return match position {
		.jump_start { 'jump-start' }
		.jump_end { 'jump-end' }
		.jump_none { 'jump-none' }
		.jump_both { 'jump-both' }
		.start { 'start' }
		.end { 'end' }
	}
}

pub fn (steps EasingSteps) serialize(mode SerializationMode) string {
	position := if steps.position == .jump_end || steps.position == .end {
		''
	} else {
		step_position_to_css_string(steps.position)
	}

	mut serialized := 'steps(${steps.number_of_intervals.serialize(mode)}'
	if position != '' {
		serialized += ', ${position}'
	}
	serialized += ')'
	return serialized
}

pub fn (function EasingStyleValueFunction) serialize(mode SerializationMode) string {
	return match function {
		EasingLinear { function.serialize(mode) }
		EasingCubicBezier { function.serialize(mode) }
		EasingSteps { function.serialize(mode) }
	}
}

pub fn (style_value EasingStyleValue) serialize(mode SerializationMode) string {
	return style_value.function_[0].serialize(mode)
}

pub fn (style_value EasingStyleValue) absolutized(context ComputationContext) StyleValue {
	function := style_value.function_[0]
	absolutized_function := match function {
		EasingLinear {
			mut absolutized_stops := []EasingLinearStop{cap: function.stops.len}
			for stop in function.stops {
				absolutized_stops << EasingLinearStop{
					output: stop.output.absolutized(context)
					input: absolutized_style_value_option(stop.input, context)
				}
			}
			EasingStyleValueFunction(EasingLinear{
				stops: absolutized_stops
			})
		}
		EasingCubicBezier {
			EasingStyleValueFunction(EasingCubicBezier{
				x1: function.x1.absolutized(context)
				y1: function.y1.absolutized(context)
				x2: function.x2.absolutized(context)
				y2: function.y2.absolutized(context)
			})
		}
		EasingSteps {
			EasingStyleValueFunction(EasingSteps{
				number_of_intervals: function.number_of_intervals.absolutized(context)
				position: function.position
			})
		}
	}

	return StyleValue(EasingStyleValue.create(absolutized_function))
}

pub fn (style_value EasingStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value EasingStyleValue) properties_equal(other EasingStyleValue) bool {
	return style_value.function_[0] == other.function_[0]
}

// --- EdgeStyleValue ---
pub struct EdgeStyleValue {
pub mut:
	edge_   ?PositionEdge
	offset_ &StyleValueSlot = unsafe { nil }
}

pub fn EdgeStyleValue.create(edge ?PositionEdge, offset ?StyleValue) EdgeStyleValue {
	return EdgeStyleValue{
		edge_: edge
		offset_: optional_style_value_storage(offset)
	}
}

pub fn (style_value EdgeStyleValue) edge() ?PositionEdge {
	return style_value.edge_
}

pub fn (style_value EdgeStyleValue) offset() StyleValue {
	return style_value_from_optional_storage(style_value.offset_) or { panic('VERIFY_NOT_REACHED') }
}

pub fn (style_value EdgeStyleValue) is_center(mode SerializationMode) bool {
	if edge := style_value.edge_ {
		if edge == .center {
			return true
		}
	}

	if offset := style_value_from_optional_storage(style_value.offset_) {
		if offset.serialize(mode) == '50%' {
			return true
		}
	}

	return false
}

pub fn (style_value EdgeStyleValue) serialize(mode SerializationMode) string {
	mut serialized := ''
	if edge := style_value.edge_ {
		serialized += position_edge_to_string(edge)
	}

	if style_value.edge_ != none && style_value_from_optional_storage(style_value.offset_) != none {
		serialized += ' '
	}

	if offset := style_value_from_optional_storage(style_value.offset_) {
		serialized += offset.serialize(mode)
	}
	return serialized
}

pub fn (style_value EdgeStyleValue) with_resolved_keywords() EdgeStyleValue {
	if edge := style_value.edge_ {
		if edge == .center {
			return EdgeStyleValue.create(none, StyleValue(PercentageStyleValue.create(Percentage.new(50))))
		}
	}

	if edge := style_value.edge_ {
		if edge == .right || edge == .bottom {
			if offset := style_value_from_optional_storage(style_value.offset_) {
				return EdgeStyleValue.create(none, calculated_style_value_from_text('calc(100% - ${offset.serialize(.normal)})'))
			}
			return EdgeStyleValue.create(none, StyleValue(PercentageStyleValue.create(Percentage.new(100))))
		}
	}

	if offset := style_value_from_optional_storage(style_value.offset_) {
		return EdgeStyleValue.create(none, offset)
	}
	return EdgeStyleValue.create(none, StyleValue(PercentageStyleValue.create(Percentage.new(0))))
}

pub fn (style_value EdgeStyleValue) absolutized(context ComputationContext) StyleValue {
	resolved := style_value.with_resolved_keywords()
	absolutized_offset := resolved.offset().absolutized(context)
	if style_value.edge_ == none {
		if offset := style_value_from_optional_storage(style_value.offset_) {
			if offset == absolutized_offset {
				return StyleValue(style_value)
			}
		}
	}
	return StyleValue(EdgeStyleValue.create(none, absolutized_offset))
}

pub fn (style_value EdgeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value EdgeStyleValue) properties_equal(other EdgeStyleValue) bool {
	return style_value == other
}

// --- FilterValueListStyleValue ---
pub enum ColorFilterType {
	brightness
	contrast
	grayscale
	invert
	opacity
	saturate
	sepia
}

pub fn color_filter_type_to_string(value ColorFilterType) string {
	return match value {
		.brightness { 'brightness' }
		.contrast { 'contrast' }
		.grayscale { 'grayscale' }
		.invert { 'invert' }
		.opacity { 'opacity' }
		.saturate { 'saturate' }
		.sepia { 'sepia' }
	}
}

pub struct FilterOperationBlur {
pub mut:
	radius StyleValue
}

pub struct FilterOperationDropShadow {
pub mut:
	offset_x StyleValue
	offset_y StyleValue
	radius   ?StyleValue
	color    ?StyleValue
}

pub struct FilterOperationHueRotate {
pub mut:
	angle StyleValue
}

pub struct FilterOperationColor {
pub mut:
	operation ColorFilterType
	amount    StyleValue
}

pub type FilterStyleValue = FilterOperationBlur
	| FilterOperationColor
	| FilterOperationDropShadow
	| FilterOperationHueRotate
	| URL

pub struct FilterValueListStyleValue {
pub mut:
	filter_value_list_ []FilterStyleValue
}

pub fn FilterValueListStyleValue.create(filter_value_list []FilterStyleValue) FilterValueListStyleValue {
	if filter_value_list.len < 1 {
		panic('VERIFY_NOT_REACHED')
	}
	return FilterValueListStyleValue{
		filter_value_list_: filter_value_list
	}
}

pub fn (style_value FilterValueListStyleValue) filter_value_list() []FilterStyleValue {
	return style_value.filter_value_list_
}

pub fn (style_value FilterValueListStyleValue) size() int {
	return style_value.filter_value_list_.len
}

pub fn (style_value FilterValueListStyleValue) contains_url() bool {
	for filter_value in style_value.filter_value_list_ {
		if filter_value is URL {
			return true
		}
	}
	return false
}

pub fn (filter_value FilterStyleValue) serialize(mode SerializationMode) string {
	return match filter_value {
		FilterOperationBlur {
			'blur(${filter_value.radius.serialize(mode)})'
		}
		FilterOperationDropShadow {
			mut serialized := 'drop-shadow('
			if color := filter_value.color {
				serialized += '${color.serialize(mode)} '
			}
			serialized += '${filter_value.offset_x.serialize(mode)} ${filter_value.offset_y.serialize(mode)}'
			if radius := filter_value.radius {
				serialized += ' ${radius.serialize(mode)}'
			}
			serialized += ')'
			serialized
		}
		FilterOperationHueRotate {
			'hue-rotate(${filter_value.angle.serialize(mode)})'
		}
		FilterOperationColor {
			'${color_filter_type_to_string(filter_value.operation)}(${filter_value.amount.serialize(mode)})'
		}
		URL {
			filter_value.to_string()
		}
	}
}

pub fn (style_value FilterValueListStyleValue) serialize(mode SerializationMode) string {
	mut parts := []string{cap: style_value.filter_value_list_.len}
	for filter_value in style_value.filter_value_list_ {
		parts << filter_value.serialize(mode)
	}
	return parts.join(' ')
}

pub fn (style_value FilterValueListStyleValue) absolutized(context ComputationContext) StyleValue {
	mut absolutized_filter_values := []FilterStyleValue{cap: style_value.filter_value_list_.len}
	for filter_value in style_value.filter_value_list_ {
		absolutized_filter_values << match filter_value {
			FilterOperationBlur {
				FilterStyleValue(FilterOperationBlur{
					radius: filter_value.radius.absolutized(context)
				})
			}
			FilterOperationDropShadow {
				FilterStyleValue(FilterOperationDropShadow{
					offset_x: filter_value.offset_x.absolutized(context)
					offset_y: filter_value.offset_y.absolutized(context)
					radius: absolutized_style_value_option(filter_value.radius, context)
					color: absolutized_style_value_option(filter_value.color, context)
				})
			}
			FilterOperationHueRotate {
				FilterStyleValue(FilterOperationHueRotate{
					angle: filter_value.angle.absolutized(context)
				})
			}
			FilterOperationColor {
				FilterStyleValue(FilterOperationColor{
					operation: filter_value.operation
					amount: StyleValue(NumberStyleValue.create(number_from_style_value(filter_value.amount.absolutized(context), 1.0)))
				})
			}
			URL {
				FilterStyleValue(filter_value)
			}
		}
	}
	return StyleValue(FilterValueListStyleValue.create(absolutized_filter_values))
}

pub fn (style_value FilterValueListStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value FilterValueListStyleValue) properties_equal(other FilterValueListStyleValue) bool {
	return style_value.filter_value_list_ == other.filter_value_list_
}

// --- FontSourceStyleValue ---
pub struct FontSourceLocal {
pub mut:
	name StyleValue
}

pub type FontSourceStyleValueSource = FontSourceLocal | URL

pub struct FontSourceStyleValue {
pub mut:
	source_ []FontSourceStyleValueSource = [FontSourceStyleValueSource(FontSourceLocal{})]
	format_ ?string
	tech_   []FontTech
}

pub fn FontSourceStyleValue.create(source FontSourceStyleValueSource, format ?string, tech []FontTech) FontSourceStyleValue {
	return FontSourceStyleValue{
		source_: [source]
		format_: format
		tech_: tech
	}
}

pub fn (style_value FontSourceStyleValue) source() FontSourceStyleValueSource {
	return style_value.source_[0]
}

pub fn (style_value FontSourceStyleValue) format() ?string {
	return style_value.format_
}

pub fn (style_value FontSourceStyleValue) tech() []FontTech {
	return style_value.tech_
}

pub fn (style_value FontSourceStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	source := style_value.source_[0]
	return match source {
		FontSourceLocal {
			// https://www.w3.org/TR/cssom-1/#serialize-a-local
			// To serialize a LOCAL means to create a string represented by "local(", followed by the serialization of
			// the LOCAL as a string, followed by ")".
			'local(${source.name.serialize(.normal)})'
		}
		URL {
			mut serialized := source.to_string()
			if format := style_value.format_ {
				serialized += ' format(${serialize_an_identifier(format)})'
			}
			if style_value.tech_.len > 0 {
				mut tech_parts := []string{cap: style_value.tech_.len}
				for tech in style_value.tech_ {
					tech_parts << font_tech_to_string(tech)
				}
				serialized += ' tech(${tech_parts.join(', ')})'
			}
			serialized
		}
	}
}

pub fn (style_value FontSourceStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value FontSourceStyleValue) properties_equal(other FontSourceStyleValue) bool {
	// Faithful to upstream: tech is intentionally not part of equality there.
	return style_value.source_[0] == other.source_[0] && style_value.format_ == other.format_
}

// --- FontStyleStyleValue ---
pub struct FontStyleStyleValue {
pub mut:
	font_style_  FontStyleKeyword
	angle_value_ &StyleValueSlot = unsafe { nil }
}

pub fn FontStyleStyleValue.create(font_style FontStyleKeyword, angle_value ?StyleValue) FontStyleStyleValue {
	return FontStyleStyleValue{
		font_style_: font_style
		angle_value_: optional_style_value_storage(angle_value)
	}
}

pub fn (style_value FontStyleStyleValue) font_style() FontStyleKeyword {
	return style_value.font_style_
}

pub fn (style_value FontStyleStyleValue) angle() ?StyleValue {
	return style_value_from_optional_storage(style_value.angle_value_)
}

pub fn (style_value FontStyleStyleValue) to_font_slope() int {
	// FIXME: Implement `left`, `right`, and `oblique <angle>`
	return match style_value.font_style_ {
		.italic { 1 }
		.oblique { 2 }
		else { 0 }
	}
}

pub fn (style_value FontStyleStyleValue) serialize(mode SerializationMode) string {
	mut angle_string := ?string(none)
	if angle_value := style_value_from_optional_storage(style_value.angle_value_) {
		serialized_angle := angle_value.serialize(mode)
		angle_string = serialized_angle
		if style_value.font_style_ == .oblique && serialized_angle == '0deg' {
			return 'normal'
		}
	}
	mut serialized := font_style_keyword_to_string(style_value.font_style_)
	// https://drafts.csswg.org/css-fonts/#valdef-font-style-oblique-angle--90deg-90deg
	// The lack of an <angle> represents 14deg. (Note that a font might internally provide its own mapping for
	// "oblique", but the mapping within the font is disregarded.)
	if actual_angle := angle_string {
		if actual_angle != '14deg' {
			serialized += ' ${actual_angle}'
		}
	}
	return serialized
}

pub fn (style_value FontStyleStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_angle := absolutized_style_value_option(style_value_from_optional_storage(style_value.angle_value_), context)
	if absolutized_angle == style_value_from_optional_storage(style_value.angle_value_) {
		return StyleValue(style_value)
	}
	return StyleValue(FontStyleStyleValue.create(style_value.font_style_, absolutized_angle))
}

pub fn (style_value FontStyleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value FontStyleStyleValue) properties_equal(other FontStyleStyleValue) bool {
	return style_value == other
}

// --- OpenTypeTaggedStyleValue ---
pub enum OpenTypeTaggedStyleValueMode {
	font_feature_settings
	font_variation_settings
}

pub struct OpenTypeTaggedStyleValue {
pub mut:
	mode_  OpenTypeTaggedStyleValueMode
	tag_   string
	value_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn OpenTypeTaggedStyleValue.create(mode OpenTypeTaggedStyleValueMode, tag string, value StyleValue) OpenTypeTaggedStyleValue {
	return OpenTypeTaggedStyleValue{
		mode_: mode
		tag_: tag
		value_: [value]
	}
}

pub fn (style_value OpenTypeTaggedStyleValue) tag() string {
	return style_value.tag_
}

pub fn (style_value OpenTypeTaggedStyleValue) value() StyleValue {
	return style_value.value_[0]
}

pub fn (style_value OpenTypeTaggedStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_value := style_value.value_[0].absolutized(context)
	if absolutized_value == style_value.value_[0] {
		return StyleValue(style_value)
	}
	return StyleValue(OpenTypeTaggedStyleValue.create(style_value.mode_, style_value.tag_, absolutized_value))
}

pub fn (style_value OpenTypeTaggedStyleValue) serialize(mode SerializationMode) string {
	mut serialized := serialize_a_string(style_value.tag_)
	match style_value.mode_ {
		.font_feature_settings {
			// For font-feature-settings, a 1 value is implicit, so we shouldn't output it.
			value_string := style_value.value_[0].serialize(mode)
			if value_string != '1' {
				serialized += ' ${value_string}'
			}
		}
		.font_variation_settings {
			serialized += ' ${style_value.value_[0].serialize(mode)}'
		}
	}

	return serialized
}

pub fn (style_value OpenTypeTaggedStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value OpenTypeTaggedStyleValue) properties_equal(other OpenTypeTaggedStyleValue) bool {
	// Faithful to upstream: mode is not part of properties_equal().
	return other.tag() == style_value.tag() && other.value() == style_value.value()
}

// --- PositionStyleValue ---
pub struct PositionStyleValue {
pub mut:
	edge_x_ EdgeStyleValue
	edge_y_ EdgeStyleValue
}

pub fn PositionStyleValue.create(edge_x EdgeStyleValue, edge_y EdgeStyleValue) PositionStyleValue {
	return PositionStyleValue{
		edge_x_: edge_x
		edge_y_: edge_y
	}
}

pub fn PositionStyleValue.create_center() PositionStyleValue {
	return PositionStyleValue.create(EdgeStyleValue.create(PositionEdge.center, none), EdgeStyleValue.create(PositionEdge.center, none))
}

pub fn PositionStyleValue.create_computed_center() PositionStyleValue {
	center := StyleValue(PercentageStyleValue.create(Percentage.new(50)))
	return PositionStyleValue.create(EdgeStyleValue.create(none, center), EdgeStyleValue.create(none, center))
}

pub fn (style_value PositionStyleValue) edge_x() EdgeStyleValue {
	return style_value.edge_x_
}

pub fn (style_value PositionStyleValue) edge_y() EdgeStyleValue {
	return style_value.edge_y_
}

pub fn (style_value PositionStyleValue) is_center(mode SerializationMode) bool {
	return style_value.edge_x_.is_center(mode) && style_value.edge_y_.is_center(mode)
}

pub fn (style_value PositionStyleValue) with_resolved_keywords() PositionStyleValue {
	return PositionStyleValue.create(style_value.edge_x_.with_resolved_keywords(), style_value.edge_y_.with_resolved_keywords())
}

pub fn (style_value PositionStyleValue) absolutized(context ComputationContext) StyleValue {
	edge_x := style_value.edge_x_.absolutized(context)
	edge_y := style_value.edge_y_.absolutized(context)
	return StyleValue(PositionStyleValue.create(edge_x.as_edge(), edge_y.as_edge()))
}

pub fn (style_value PositionStyleValue) serialize(mode SerializationMode) string {
	return '${style_value.edge_x_.serialize(mode)} ${style_value.edge_y_.serialize(mode)}'
}

pub fn (style_value PositionStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value PositionStyleValue) properties_equal(other PositionStyleValue) bool {
	return style_value == other
}

// --- RadialSizeStyleValue ---
pub struct RadialExtentComponent {
pub mut:
	extent RadialExtent
}

pub type RadialSizeStyleValueComponent = RadialExtentComponent | StyleValue

pub struct RadialSizeStyleValue {
pub mut:
	components_ []RadialSizeStyleValueComponent
}

pub fn RadialSizeStyleValue.create(components []RadialSizeStyleValueComponent) RadialSizeStyleValue {
	if components.len != 1 && components.len != 2 {
		panic('VERIFY_NOT_REACHED')
	}
	return RadialSizeStyleValue{
		components_: components
	}
}

pub fn (style_value RadialSizeStyleValue) components() []RadialSizeStyleValueComponent {
	return style_value.components_
}

pub fn (style_value RadialSizeStyleValue) absolutized(context ComputationContext) StyleValue {
	mut any_component_required_absolutization := false
	mut absolutized_components := []RadialSizeStyleValueComponent{cap: style_value.components_.len}

	for component in style_value.components_ {
		match component {
			RadialExtentComponent {
				absolutized_components << component
			}
			StyleValue {
				absolutized_length_percentage := component.absolutized(context)
				if absolutized_length_percentage != component {
					any_component_required_absolutization = true
				}
				absolutized_components << RadialSizeStyleValueComponent(absolutized_length_percentage)
			}
		}
	}

	if !any_component_required_absolutization {
		return StyleValue(style_value)
	}

	return StyleValue(RadialSizeStyleValue.create(absolutized_components))
}

pub fn (style_value RadialSizeStyleValue) serialize(mode SerializationMode) string {
	mut parts := []string{cap: style_value.components_.len}
	for component in style_value.components_ {
		parts << match component {
			RadialExtentComponent { radial_extent_to_string(component.extent) }
			StyleValue { component.serialize(mode) }
		}
	}
	return parts.join(' ')
}

pub fn (style_value RadialSizeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value RadialSizeStyleValue) properties_equal(other RadialSizeStyleValue) bool {
	return style_value.components_ == other.components_
}

// --- RandomValueSharingStyleValue ---
pub struct RandomCachingKey {
pub mut:
	name       string
	element_id ?i64
}

pub fn (key RandomCachingKey) cache_key_string() string {
	if element_id := key.element_id {
		return '${key.name.len}:${key.name}:${element_id}'
	}
	return '${key.name.len}:${key.name}:element-shared'
}

pub struct RandomValueSharingStyleValue {
pub mut:
	fixed_value_    &StyleValueSlot = unsafe { nil }
	is_auto_        bool
	name_           ?string
	element_shared_ bool
}

pub fn RandomValueSharingStyleValue.create_fixed(fixed_value StyleValue) RandomValueSharingStyleValue {
	return RandomValueSharingStyleValue{
		fixed_value_: optional_style_value_storage(fixed_value)
	}
}

pub fn RandomValueSharingStyleValue.create_auto(name string, element_shared bool) RandomValueSharingStyleValue {
	return RandomValueSharingStyleValue{
		is_auto_: true
		name_: name
		element_shared_: element_shared
	}
}

pub fn RandomValueSharingStyleValue.create_dashed_ident(name string, element_shared bool) RandomValueSharingStyleValue {
	return RandomValueSharingStyleValue{
		is_auto_: false
		name_: name
		element_shared_: element_shared
	}
}

pub fn (style_value RandomValueSharingStyleValue) absolutized(context ComputationContext) StyleValue {
	// https://drafts.csswg.org/css-values-5/#random-caching
	// Each instance of a random function in styles has an associated random base value.
	// If the random function's <random-value-sharing> is fixed <number>, the random base value is that number.
	if fixed_value := style_value_from_optional_storage(style_value.fixed_value_) {
		absolutized_fixed_value := fixed_value.absolutized(context)
		if fixed_value == absolutized_fixed_value {
			return StyleValue(style_value)
		}
		return StyleValue(RandomValueSharingStyleValue.create_fixed(absolutized_fixed_value))
	}

	// Otherwise, the random base value is a pseudo-random real number in the range `[0, 1)` (greater than or equal to 0
	// and less than 1), generated from a uniform distribution, and influenced by the function's random caching key.
	abstract_element := context.abstract_element or {
		panic('RandomValueSharingStyleValue::absolutized requires ComputationContext.abstract_element')
	}

	// A random caching key is a tuple of:
	element_id := if style_value.element_shared_ {
		none
	} else {
		// FIXME: Use the pseudo element's unique_id() when that's accessible
		abstract_element.element().as_node().unique_id().value()
	}
	random_caching_key := style_value.random_caching_key(element_id) or {
		panic('RandomValueSharingStyleValue::absolutized requires a random caching key name')
	}
	cache_key := random_caching_key.cache_key_string()

	// 1. A string name: the value of the <dashed-ident>, if specified in <random-value-sharing>; or else a string
	//    of the form "PROPERTY N", where PROPERTY is the name of the property the random function is used in
	//    (before shorthand expansion, if relevant), and N is the index of the random function among other random
	//    functions in the same property value.
	// 2. An element ID identifying the element the style is being applied to, or null if element-shared is
	//    specified in <random-value-sharing>.
	// 3. A document ID identifying the Document the styles are from.
	// NB: This is implicit since the cache is stored on the document or the element (which is a child of the document).
	random_base_value := if style_value.element_shared_ {
		mut document := unsafe { &dom.Document(abstract_element.document()) }
		document.ensure_element_shared_css_random_base_value(cache_key)
	} else {
		mut element := unsafe { &dom.Element(abstract_element.element()) }
		element.ensure_css_random_base_value(cache_key)
	}

	return StyleValue(RandomValueSharingStyleValue.create_fixed(StyleValue(NumberStyleValue.create(random_base_value))))
}

pub fn (style_value RandomValueSharingStyleValue) random_base_value() f64 {
	fixed_value := style_value_from_optional_storage(style_value.fixed_value_) or { return 0.0 }
	return number_from_style_value(fixed_value, none)
}

pub fn (style_value RandomValueSharingStyleValue) serialize(mode SerializationMode) string {
	if fixed_value := style_value_from_optional_storage(style_value.fixed_value_) {
		return 'fixed ${fixed_value.serialize(mode)}'
	}

	mut serialized := ''
	mut first := true
	if !style_value.is_auto_ {
		if name := style_value.name_ {
			serialized += name
		}
		first = false
	}

	if style_value.element_shared_ {
		if !first {
			serialized += ' '
		}
		serialized += 'element-shared'
	}
	return serialized
}

pub fn (style_value RandomValueSharingStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value RandomValueSharingStyleValue) properties_equal(other RandomValueSharingStyleValue) bool {
	return style_value == other
}

// --- RectStyleValue ---
pub struct RectStyleValue {
pub mut:
	top_    []StyleValue = [StyleValue(KeywordStyleValue{})]
	right_  []StyleValue = [StyleValue(KeywordStyleValue{})]
	bottom_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	left_   []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn RectStyleValue.create(top StyleValue, right StyleValue, bottom StyleValue, left StyleValue) RectStyleValue {
	return RectStyleValue{
		top_: [top]
		right_: [right]
		bottom_: [bottom]
		left_: [left]
	}
}

pub fn (style_value RectStyleValue) top() StyleValue {
	return style_value.top_[0]
}

pub fn (style_value RectStyleValue) right() StyleValue {
	return style_value.right_[0]
}

pub fn (style_value RectStyleValue) bottom() StyleValue {
	return style_value.bottom_[0]
}

pub fn (style_value RectStyleValue) left() StyleValue {
	return style_value.left_[0]
}

pub fn (style_value RectStyleValue) rect() EdgeRect {
	return EdgeRect{
		top_edge: LengthOrAuto.from_style_value_logic(style_value.top_[0], none)
		right_edge: LengthOrAuto.from_style_value_logic(style_value.right_[0], none)
		bottom_edge: LengthOrAuto.from_style_value_logic(style_value.bottom_[0], none)
		left_edge: LengthOrAuto.from_style_value_logic(style_value.left_[0], none)
	}
}

pub fn (style_value RectStyleValue) serialize(mode SerializationMode) string {
	return 'rect(${style_value.top_[0].serialize(mode)}, ${style_value.right_[0].serialize(mode)}, ${style_value.bottom_[0].serialize(mode)}, ${style_value.left_[0].serialize(mode)})'
}

pub fn (style_value RectStyleValue) absolutized(context ComputationContext) StyleValue {
	return StyleValue(RectStyleValue.create(style_value.top_[0].absolutized(context), style_value.right_[0].absolutized(context), style_value.bottom_[0].absolutized(context), style_value.left_[0].absolutized(context)))
}

pub fn (style_value RectStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value RectStyleValue) properties_equal(other RectStyleValue) bool {
	return style_value.top_[0] == other.top_[0] && style_value.right_[0] == other.right_[0]
		&& style_value.bottom_[0] == other.bottom_[0] && style_value.left_[0] == other.left_[0]
}

// --- RepeatStyleStyleValue ---
pub struct RepeatStyleStyleValue {
pub mut:
	repeat_x_ Repetition
	repeat_y_ Repetition
}

pub fn RepeatStyleStyleValue.create(repeat_x Repetition, repeat_y Repetition) RepeatStyleStyleValue {
	return RepeatStyleStyleValue{
		repeat_x_: repeat_x
		repeat_y_: repeat_y
	}
}

pub fn (style_value RepeatStyleStyleValue) repeat_x() Repetition {
	return style_value.repeat_x_
}

pub fn (style_value RepeatStyleStyleValue) repeat_y() Repetition {
	return style_value.repeat_y_
}

pub fn (style_value RepeatStyleStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if style_value.repeat_x_ == style_value.repeat_y_ {
		return repetition_to_string(style_value.repeat_x_)
	}

	if style_value.repeat_x_ == .repeat && style_value.repeat_y_ == .no_repeat {
		return 'repeat-x'
	}
	if style_value.repeat_x_ == .no_repeat && style_value.repeat_y_ == .repeat {
		return 'repeat-y'
	}

	return '${repetition_to_string(style_value.repeat_x_)} ${repetition_to_string(style_value.repeat_y_)}'
}

pub fn (style_value RepeatStyleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value RepeatStyleStyleValue) properties_equal(other RepeatStyleStyleValue) bool {
	return style_value == other
}

// --- ScrollbarColorStyleValue ---
pub struct ScrollbarColorStyleValue {
pub mut:
	thumb_color_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	track_color_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn ScrollbarColorStyleValue.create(thumb_color StyleValue, track_color StyleValue) ScrollbarColorStyleValue {
	return ScrollbarColorStyleValue{
		thumb_color_: [thumb_color]
		track_color_: [track_color]
	}
}

pub fn (style_value ScrollbarColorStyleValue) thumb_color() StyleValue {
	return style_value.thumb_color_[0]
}

pub fn (style_value ScrollbarColorStyleValue) track_color() StyleValue {
	return style_value.track_color_[0]
}

pub fn (style_value ScrollbarColorStyleValue) absolutized(context ComputationContext) StyleValue {
	return StyleValue(ScrollbarColorStyleValue.create(style_value.thumb_color_[0].absolutized(context), style_value.track_color_[0].absolutized(context)))
}

pub fn (style_value ScrollbarColorStyleValue) serialize(mode SerializationMode) string {
	return '${style_value.thumb_color_[0].serialize(mode)} ${style_value.track_color_[0].serialize(mode)}'
}

pub fn (style_value ScrollbarColorStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value ScrollbarColorStyleValue) properties_equal(other ScrollbarColorStyleValue) bool {
	return style_value == other
}

// --- ScrollbarGutterStyleValue ---
pub struct ScrollbarGutterStyleValue {
pub mut:
	value_ ScrollbarGutter
}

pub fn ScrollbarGutterStyleValue.create(value ScrollbarGutter) ScrollbarGutterStyleValue {
	return ScrollbarGutterStyleValue{
		value_: value
	}
}

pub fn (style_value ScrollbarGutterStyleValue) value() ScrollbarGutter {
	return style_value.value_
}

pub fn (style_value ScrollbarGutterStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return match style_value.value_ {
		.auto_ { 'auto' }
		.stable { 'stable' }
		.both_edges { 'stable both-edges' }
	}
}

pub fn (style_value ScrollbarGutterStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value ScrollbarGutterStyleValue) properties_equal(other ScrollbarGutterStyleValue) bool {
	return style_value.value_ == other.value_
}

// --- ShadowStyleValue ---
pub enum ShadowPlacement {
	outer
	inner
}

pub enum ShadowType {
	normal
	text
}

pub struct ShadowStyleValue {
pub mut:
	shadow_type_     ShadowType
	color_           &StyleValueSlot = unsafe { nil }
	offset_x_        []StyleValue = [StyleValue(KeywordStyleValue{})]
	offset_y_        []StyleValue = [StyleValue(KeywordStyleValue{})]
	blur_radius_     &StyleValueSlot = unsafe { nil }
	spread_distance_ &StyleValueSlot = unsafe { nil }
	placement_       ShadowPlacement
}

pub fn ShadowStyleValue.create(shadow_type ShadowType, color ?StyleValue, offset_x StyleValue, offset_y StyleValue, blur_radius ?StyleValue, spread_distance ?StyleValue, placement ShadowPlacement) ShadowStyleValue {
	return ShadowStyleValue{
		shadow_type_: shadow_type
		color_: optional_style_value_storage(color)
		offset_x_: [offset_x]
		offset_y_: [offset_y]
		blur_radius_: optional_style_value_storage(blur_radius)
		spread_distance_: optional_style_value_storage(spread_distance)
		placement_: placement
	}
}

pub fn (style_value ShadowStyleValue) shadow_type() ShadowType {
	return style_value.shadow_type_
}

pub fn (style_value ShadowStyleValue) color() StyleValue {
	return style_value_from_optional_storage(style_value.color_) or { currentcolor_style_value() }
}

pub fn (style_value ShadowStyleValue) offset_x() StyleValue {
	return style_value.offset_x_[0]
}

pub fn (style_value ShadowStyleValue) offset_y() StyleValue {
	return style_value.offset_y_[0]
}

pub fn (style_value ShadowStyleValue) blur_radius() StyleValue {
	return style_value_from_optional_storage(style_value.blur_radius_) or { zero_length_style_value() }
}

pub fn (style_value ShadowStyleValue) spread_distance() StyleValue {
	return style_value_from_optional_storage(style_value.spread_distance_) or { zero_length_style_value() }
}

pub fn (style_value ShadowStyleValue) placement() ShadowPlacement {
	return style_value.placement_
}

pub fn (style_value ShadowStyleValue) serialize(mode SerializationMode) string {
	mut serialized := ''
	if color := style_value_from_optional_storage(style_value.color_) {
		serialized += '${color.serialize(mode)} '
	}

	serialized += '${style_value.offset_x_[0].serialize(mode)} ${style_value.offset_y_[0].serialize(mode)}'

	if blur_radius := style_value_from_optional_storage(style_value.blur_radius_) {
		serialized += ' ${blur_radius.serialize(mode)}'
	}

	if spread_distance := style_value_from_optional_storage(style_value.spread_distance_) {
		if style_value.shadow_type_ == .normal {
			serialized += ' ${spread_distance.serialize(mode)}'
		}
	}

	if style_value.placement_ == .inner {
		serialized += ' inset'
	}
	return serialized
}

pub fn (style_value ShadowStyleValue) absolutized(context ComputationContext) StyleValue {
	return StyleValue(ShadowStyleValue.create(style_value.shadow_type_, style_value.color().absolutized(context), style_value.offset_x_[0].absolutized(context), style_value.offset_y_[0].absolutized(context), style_value.blur_radius().absolutized(context), style_value.spread_distance().absolutized(context), style_value.placement_))
}

pub fn (style_value ShadowStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value ShadowStyleValue) properties_equal(other ShadowStyleValue) bool {
	return style_value == other
}

// --- ShorthandStyleValue ---
pub struct ShorthandStyleValue {
pub mut:
	system_font_    string
	shorthand_      PropertyID
	sub_properties_ []PropertyID
	values_         []StyleValue
}

pub fn ShorthandStyleValue.create(shorthand PropertyID, sub_properties []PropertyID, values []StyleValue) ShorthandStyleValue {
	return ShorthandStyleValue{
		shorthand_: shorthand
		sub_properties_: sub_properties
		values_: values
	}
}

pub fn (style_value ShorthandStyleValue) shorthand() PropertyID {
	return style_value.shorthand_
}

pub fn (style_value ShorthandStyleValue) sub_properties() []PropertyID {
	return style_value.sub_properties_
}

pub fn (style_value ShorthandStyleValue) values() []StyleValue {
	return style_value.values_
}

// Configuration for the coordinating-list shorthands (transition/animation/scroll-timeline/
// view-timeline), whose longhands are parallel comma-separated lists that must be zipped by
// index when serializing.
struct CoordinatingListConfig {
	entry_when_all_initial string
	required_longhands     []PropertyID
	reset_only_longhands   []PropertyID
}

fn coordinating_list_config(shorthand PropertyID) ?CoordinatingListConfig {
	return match shorthand {
		.animation {
			CoordinatingListConfig{
				entry_when_all_initial: 'none'
				reset_only_longhands: [PropertyID.animation_timeline, .animation_range_start, .animation_range_end]
			}
		}
		.transition {
			CoordinatingListConfig{
				entry_when_all_initial: 'all'
			}
		}
		.scroll_timeline {
			CoordinatingListConfig{
				required_longhands: [PropertyID.scroll_timeline_name]
			}
		}
		.view_timeline {
			CoordinatingListConfig{
				required_longhands: [PropertyID.view_timeline_name]
			}
		}
		else {
			none
		}
	}
}

// Serialize a coordinating-list shorthand by zipping its parallel longhand lists per entry,
// mirroring the upstream `coordinating_value_list_shorthand_serialize`. A recognized
// shorthand with incompatible lists or non-initial reset-only values serializes empty.
fn (style_value ShorthandStyleValue) serialize_coordinating_list(mode SerializationMode) ?string {
	config := coordinating_list_config(style_value.shorthand_) or { return none }

	// Reset-only longhands must all hold their initial value (the port stores them as a
	// per-entry list, so every entry must be initial).
	for reset_only in config.reset_only_longhands {
		index := style_value.coordinating_longhand_index(reset_only) or { return '' }
		initial_css := computed_interpolation_property_initial_value(reset_only).css_text
		value := style_value.values_[index]
		if value is StyleValueList {
			for item in value.values() {
				if item.serialize(mode) != initial_css {
					return ''
				}
			}
		} else if value.serialize(mode) != initial_css {
			return ''
		}
	}

	// Every non-reset-only longhand must be a value list with the same entry count.
	mut entry_count := -1
	for index, sub_property in style_value.sub_properties_ {
		if sub_property in config.reset_only_longhands {
			continue
		}
		value := style_value.values_[index]
		if value !is StyleValueList {
			return ''
		}
		count := (value as StyleValueList).values().len
		if entry_count == -1 {
			entry_count = count
		} else if count != entry_count {
			return ''
		}
	}
	if entry_count <= 0 {
		return ''
	}

	mut entries := []string{}
	for entry_index := 0; entry_index < entry_count; entry_index++ {
		mut parts := []string{}
		for longhand_index, _ in style_value.sub_properties_ {
			if !style_value.should_serialize_coordinating_longhand(entry_index, longhand_index, config, mode) {
				continue
			}
			list := style_value.values_[longhand_index] as StyleValueList
			parts << list.values()[entry_index].serialize(mode)
		}
		if parts.len == 0 {
			entries << config.entry_when_all_initial
		} else {
			entries << parts.join(' ')
		}
	}
	return entries.join(', ')
}

fn (style_value ShorthandStyleValue) coordinating_longhand_value(property_id PropertyID) ?StyleValue {
	index := style_value.coordinating_longhand_index(property_id) or { return none }
	return style_value.values_[index]
}

// The number of layers a longhand value carries (a comma list's length, or 1).
fn shorthand_layer_count_of(value StyleValue) int {
	if value is StyleValueList {
		return value.values().len
	}
	return 1
}

// The StyleValue for one layer of a longhand (looping short lists, as upstream does).
fn shorthand_layer_value(value StyleValue, index int) StyleValue {
	if value is StyleValueList {
		return value.value_at(index, true)
	}
	return value
}

fn shorthand_append_if_not_initial(mut parts []string, value StyleValue, property_id PropertyID, mode SerializationMode) {
	serialized := value.serialize(mode)
	if serialized != computed_interpolation_property_initial_value(property_id).css_text {
		parts << serialized
	}
}

// background: zip the per-layer longhands (color only on the last layer), mirroring the
// upstream Background serialize_layer. AD-HOC (as upstream): no `/` is emitted before the
// background-size, so a layer with a non-initial size does not round-trip.
fn (style_value ShorthandStyleValue) serialize_background(mode SerializationMode) ?string {
	if style_value.shorthand_ != .background {
		return none
	}
	color := style_value.coordinating_longhand_value(.background_color) or { return none }
	image := style_value.coordinating_longhand_value(.background_image) or { return none }
	position_x := style_value.coordinating_longhand_value(.background_position_x) or {
		position := style_value.coordinating_longhand_value(.background_position) or { return none }
		if position is ShorthandStyleValue {
			position.longhand(.background_position_x) or { return none }
		} else {
			return none
		}
	}
	position_y := style_value.coordinating_longhand_value(.background_position_y) or {
		position := style_value.coordinating_longhand_value(.background_position) or { return none }
		if position is ShorthandStyleValue {
			position.longhand(.background_position_y) or { return none }
		} else {
			return none
		}
	}
	size := style_value.coordinating_longhand_value(.background_size) or { return none }
	repeat := style_value.coordinating_longhand_value(.background_repeat) or { return none }
	attachment := style_value.coordinating_longhand_value(.background_attachment) or { return none }
	origin := style_value.coordinating_longhand_value(.background_origin) or { return none }
	clip := style_value.coordinating_longhand_value(.background_clip) or { return none }

	mut layer_count := shorthand_layer_count_of(image)
	for value in [position_x, position_y, size, repeat, attachment, origin, clip] {
		count := shorthand_layer_count_of(value)
		if count > layer_count {
			layer_count = count
		}
	}

	mut layers := []string{}
	for index := 0; index < layer_count; index++ {
		mut parts := []string{}
		// The background-color belongs to the final layer only.
		if index == layer_count - 1 {
			shorthand_append_if_not_initial(mut parts, color, .background_color, mode)
		}
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(image, index), .background_image, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(position_x, index), .background_position_x, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(position_y, index), .background_position_y, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(size, index), .background_size, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(repeat, index), .background_repeat, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(attachment, index), .background_attachment, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(origin, index), .background_origin, mode)
		shorthand_append_if_not_initial(mut parts, shorthand_layer_value(clip, index), .background_clip, mode)
		layers << if parts.len == 0 { 'none' } else { parts.join(' ') }
	}
	return layers.join(', ')
}

fn mask_longhand_initial(property_id PropertyID) string {
	return computed_interpolation_property_initial_value(property_id).css_text
}

// mask: zip the per-layer longhands, mirroring the upstream Mask serialize_layer. Unlike
// background, mask emits `position / size` (with the slash) and special-cases origin/clip.
fn (style_value ShorthandStyleValue) serialize_mask(mode SerializationMode) ?string {
	if style_value.shorthand_ != .mask {
		return none
	}
	image := style_value.coordinating_longhand_value(.mask_image) or { return none }
	position := style_value.coordinating_longhand_value(.mask_position) or { return none }
	size := style_value.coordinating_longhand_value(.mask_size) or { return none }
	repeat := style_value.coordinating_longhand_value(.mask_repeat) or { return none }
	origin := style_value.coordinating_longhand_value(.mask_origin) or { return none }
	clip := style_value.coordinating_longhand_value(.mask_clip) or { return none }
	composite := style_value.coordinating_longhand_value(.mask_composite) or { return none }
	mask_mode := style_value.coordinating_longhand_value(.mask_mode) or { return none }

	mut layer_count := shorthand_layer_count_of(image)
	for value in [position, size, repeat, origin, clip, composite, mask_mode] {
		count := shorthand_layer_count_of(value)
		if count > layer_count {
			layer_count = count
		}
	}

	mut layers := []string{}
	for index := 0; index < layer_count; index++ {
		layers << serialize_mask_layer(mode, shorthand_layer_value(image, index), shorthand_layer_value(position, index), shorthand_layer_value(size, index), shorthand_layer_value(repeat, index), shorthand_layer_value(origin, index), shorthand_layer_value(clip, index), shorthand_layer_value(composite, index), shorthand_layer_value(mask_mode, index))
	}
	return layers.join(', ')
}

fn serialize_mask_layer(mode SerializationMode, image StyleValue, position StyleValue, size StyleValue, repeat StyleValue, origin StyleValue, clip StyleValue, composite StyleValue, mask_mode StyleValue) string {
	image_serialized := image.serialize(mode)
	position_serialized := position.serialize(mode)
	size_serialized := size.serialize(mode)
	repeat_serialized := repeat.serialize(mode)
	origin_serialized := origin.serialize(mode)
	clip_serialized := clip.serialize(mode)
	composite_serialized := composite.serialize(mode)
	mode_serialized := mask_mode.serialize(mode)

	size_is_initial := size_serialized == mask_longhand_initial(.mask_size)
	clip_is_initial := clip_serialized == mask_longhand_initial(.mask_clip)

	mut parts := []string{}
	if image_serialized != mask_longhand_initial(.mask_image) {
		parts << image_serialized
	}
	// mask-position is kept when it (or the size) is non-initial; a non-initial size is
	// appended after a `/`.
	if !(position_serialized == mask_longhand_initial(.mask_position) && size_is_initial) {
		if size_is_initial {
			parts << position_serialized
		} else {
			parts << '${position_serialized} / ${size_serialized}'
		}
	}
	if repeat_serialized != mask_longhand_initial(.mask_repeat) {
		parts << repeat_serialized
	}
	// mask-origin can be omitted when initial and the clip is initial or `no-clip`.
	origin_can_skip := clip_is_initial || clip_serialized == 'no-clip'
	if !(origin_serialized == mask_longhand_initial(.mask_origin) && origin_can_skip) {
		parts << origin_serialized
	}
	// mask-clip is omitted when initial or identical to mask-origin.
	if !(clip_is_initial || clip_serialized == origin_serialized) {
		parts << clip_serialized
	}
	if composite_serialized != mask_longhand_initial(.mask_composite) {
		parts << composite_serialized
	}
	if mode_serialized != mask_longhand_initial(.mask_mode) {
		parts << mode_serialized
	}

	return if parts.len == 0 { 'none' } else { parts.join(' ') }
}

// background-position: zip background-position-x/-y per layer as `<x> <y>`.
fn (style_value ShorthandStyleValue) serialize_background_position(mode SerializationMode) ?string {
	if style_value.shorthand_ != .background_position {
		return none
	}
	position_x := style_value.coordinating_longhand_value(.background_position_x) or { return none }
	position_y := style_value.coordinating_longhand_value(.background_position_y) or { return none }
	x_count := shorthand_layer_count_of(position_x)
	y_count := shorthand_layer_count_of(position_y)
	layer_count := if x_count > y_count { x_count } else { y_count }
	mut layers := []string{}
	for index := 0; index < layer_count; index++ {
		layers << '${shorthand_layer_value(position_x, index).serialize(mode)} ${shorthand_layer_value(position_y, index).serialize(mode)}'
	}
	return layers.join(', ')
}

fn (style_value ShorthandStyleValue) coordinating_longhand_index(property_id PropertyID) ?int {
	for index, sub_property in style_value.sub_properties_ {
		if sub_property == property_id {
			return index
		}
	}
	return none
}

fn (style_value ShorthandStyleValue) should_serialize_coordinating_longhand(entry_index int, longhand_index int, config CoordinatingListConfig, mode SerializationMode) bool {
	longhand_id := style_value.sub_properties_[longhand_index]
	if longhand_id in config.reset_only_longhands {
		return false
	}
	if longhand_id in config.required_longhands {
		return true
	}

	entry_value := (style_value.values_[longhand_index] as StyleValueList).values()[entry_index]
	if entry_value.serialize(mode) != computed_interpolation_property_initial_value(longhand_id).css_text {
		return true
	}

	// Disambiguation: serialize this (initial) longhand if a later, non-initial longhand's
	// value could be mis-parsed as this longhand once the earlier ones are omitted.
	for other_index := longhand_index + 1; other_index < style_value.sub_properties_.len; other_index++ {
		other_id := style_value.sub_properties_[other_index]
		if other_id in config.reset_only_longhands {
			continue
		}
		other_value := (style_value.values_[other_index] as StyleValueList).values()[entry_index]
		other_serialized := other_value.serialize(mode)
		if other_serialized == computed_interpolation_property_initial_value(other_id).css_text {
			continue
		}
		if _ := parse_css_value_logic(longhand_id, other_serialized) {
			return true
		}
	}
	return false
}

// Whether a border-family sub-value is at its property's initial value. Translated longhands
// compare against their initial serialization; a nested shorthand (border-image) is initial
// only when every one of its own longhands is.
fn border_family_longhand_is_initial(id PropertyID, value StyleValue, mode SerializationMode) bool {
	if computed_interpolation_is_longhand_property(id) {
		return value.serialize(mode) == computed_interpolation_property_initial_value(id).css_text
	}
	if value is ShorthandStyleValue {
		for i, sub_value in value.values_ {
			if !border_family_longhand_is_initial(value.sub_properties_[i], sub_value, mode) {
				return false
			}
		}
		return true
	}
	return false
}

// The border-family shorthands (border, border-<edge>, border-block/inline[-start/end]) have a
// uniform structure: the width/style/color longhands lay out as M widths, then M styles, then M
// colors (M edges). When every edge in each group is equal, they serialize to the short
// `<width> <style> <color>` form (omitting initials) which re-parses; the default longhand join
// does not. The full `border` shorthand additionally carries a trailing `border-image` longhand
// (a nested shorthand); upstream only lets `border` serialize when that longhand is at its
// initial value, in which case it is omitted. Returns none when the positional collapse doesn't
// apply, and '' when a non-collapsible longhand (border-image) is non-initial — matching
// upstream's empty serialization for that case.
// Whether every longhand of a nested shorthand carries the same value, i.e.
// ShorthandStyleValue::serialize()'s `all_longhands_same_value`.
fn border_family_nested_shorthand_is_uniform(value StyleValue, mode SerializationMode) bool {
	if value !is ShorthandStyleValue {
		return true
	}
	nested := value as ShorthandStyleValue
	if nested.values_.len < 2 {
		return true
	}
	first := nested.values_[0].serialize(mode)
	for longhand in nested.values_[1..] {
		if longhand.serialize(mode) != first {
			return false
		}
	}
	return true
}

fn (style_value ShorthandStyleValue) serialize_border_family(mode SerializationMode) ?string {
	if style_value.shorthand_ !in [PropertyID.border, .border_top, .border_right, .border_bottom,
		.border_left, .border_block, .border_inline, .border_block_start, .border_block_end,
		.border_inline_start, .border_inline_end] {
		return none
	}
	sub := style_value.sub_properties_
	// `border`, `border-block`, and `border-inline` retain the same nested
	// width/style/color shorthands as Ladybird. Their remaining nested child
	// (`border-image` for `border`) is reset-only and must be initial.
	if style_value.shorthand_ in [PropertyID.border, .border_block, .border_inline]
		&& sub.len >= 3 && property_is_shorthand(sub[0]) {
		// "`border` only has a reasonable value if all four sides are the same."
		// A non-uniform width, style or colour serializes as the empty string, so
		// the declaration block falls back to the nested shorthands.
		for i in 0 .. 3 {
			if !border_family_nested_shorthand_is_uniform(style_value.values_[i], mode) {
				return ''
			}
		}
		mut parts := []string{}
		for i in 0 .. 3 {
			if !border_family_longhand_is_initial(sub[i], style_value.values_[i], mode) {
				parts << style_value.values_[i].serialize(mode)
			}
		}
		for i in 3 .. sub.len {
			if !border_family_longhand_is_initial(sub[i], style_value.values_[i], mode) {
				return ''
			}
		}
		if parts.len == 0 {
			parts << style_value.values_[0].serialize(mode)
		}
		return parts.join(' ')
	}
	// Split the width/style/color longhands (which collapse positionally) from any nested
	// shorthand longhand (border-image on the `border` shorthand), which must be initial.
	mut ser := []string{}
	mut core_sub := []PropertyID{}
	for i, value in style_value.values_ {
		if computed_interpolation_is_longhand_property(sub[i]) {
			ser << value.serialize(mode)
			core_sub << sub[i]
		} else if !border_family_longhand_is_initial(sub[i], value, mode) {
			return ''
		}
	}
	if ser.len == 0 || ser.len % 3 != 0 {
		return none
	}
	m := ser.len / 3
	// Every edge within each of the 3 groups (width/style/color) must be identical.
	for group in 0 .. 3 {
		for edge in 1 .. m {
			if ser[group * m + edge] != ser[group * m] {
				return none
			}
		}
	}
	mut parts := []string{}
	if ser[0] != computed_interpolation_property_initial_value(core_sub[0]).css_text {
		parts << ser[0]
	}
	if ser[m] != computed_interpolation_property_initial_value(core_sub[m]).css_text {
		parts << ser[m]
	}
	if ser[2 * m] != computed_interpolation_property_initial_value(core_sub[2 * m]).css_text {
		parts << ser[2 * m]
	}
	if parts.len == 0 {
		parts << ser[0]
	}
	return parts.join(' ')
}

pub fn (style_value ShorthandStyleValue) serialize(mode SerializationMode) string {
	if style_value.shorthand_ == .font && style_value.system_font_ != '' { return style_value.system_font_ }
	if style_value.shorthand_ == .position_try {
		order := style_value.values_[0].serialize(mode)
		fallbacks := style_value.values_[1].serialize(mode)
		return if order == 'normal' { fallbacks } else { order+' '+fallbacks }
	}
	if range := style_value.serialize_animation_range(mode) { return range }
	if synthesis := style_value.serialize_font_synthesis(mode) { return synthesis }
	if s := style_value.serialize_page_break_legacy_shorthand(mode) {
		return s
	}
	if s := style_value.serialize_line_clamp(mode) {
		return s
	}
	if s := style_value.serialize_container(mode) {
		return s
	}
	if border_serialization := style_value.serialize_border_family(mode) {
		return border_serialization
	}
	if s := style_value.serialize_grid_line(mode) {
		return s
	}
	if s := style_value.serialize_grid_area(mode) {
		return s
	}
	if s := style_value.serialize_border_image(mode) {
		return s
	}
	// The box `{1,4}`/`{1,2}` shorthands (margin/padding/inset/border-color/style/width/
	// corner-*-shape/gap/overflow and their logical variants) collapse via the positional
	// value list serializer rather than default_serialize.
	if property_is_positional_value_list_shorthand(style_value.shorthand_) || style_value.shorthand_ in [
		PropertyID.place_content,
		.place_items,
		.place_self,
	] {
		return serialize_a_positional_value_list(style_value.values_, mode)
	}
	if s := style_value.serialize_grid_template(mode) {
		return s
	}
	if s := style_value.serialize_grid(mode) {
		return s
	}
	if s := style_value.serialize_flex(mode) {
		return s
	}
	if s := style_value.serialize_border_radius(mode) {
		return s
	}
	if s := style_value.serialize_font(mode) {
		return s
	}
	// Longhand values the font shorthand cannot express serialize as the
	// empty string rather than as a list of the longhands.
	if style_value.shorthand_ == .font && style_value.values_.len == 12 {
		return ''
	}
	if s := style_value.serialize_coordinating_list(mode) {
		return s
	}
	if s := style_value.serialize_background(mode) {
		return s
	}
	if s := style_value.serialize_background_position(mode) {
		return s
	}
	if s := style_value.serialize_mask(mode) {
		return s
	}
	if s := style_value.serialize_white_space(mode) {
		return s
	}
	if s := style_value.serialize_text_decoration(mode) {
		return s
	}
	// Mirrors the upstream `default_serialize`: the remaining property-specific cases
	// (font, background, grid, …) are not ported, so they use this default.
	values := style_value.values_
	if values.len == 0 {
		return ''
	}
	mut serialized := []string{cap: values.len}
	for value in values {
		serialized << value.serialize(mode)
	}
	// If every longhand has the same value, serialize it once (e.g. `margin: 5px`).
	mut all_same := true
	for i := 1; i < serialized.len; i++ {
		if serialized[i] != serialized[0] {
			all_same = false
			break
		}
	}
	if all_same {
		return serialized[0]
	}
	// Otherwise serialize each value, omitting any longhand equal to its initial value.
	sub_props := style_value.sub_properties_
	mut builder := strings.new_builder(64)
	mut first := true
	for i, s in serialized {
		if i < sub_props.len && computed_interpolation_is_longhand_property(sub_props[i]) {
			if s == computed_interpolation_property_initial_value(sub_props[i]).css_text {
				continue
			}
		}
		if !first {
			builder.write_string(' ')
		}
		first = false
		builder.write_string(s)
	}
	// When every longhand was omitted (all equal their initial), serialize the first.
	if builder.len == 0 {
		return serialized[0]
	}
	return builder.str()
}

fn (style_value ShorthandStyleValue) serialize_page_break_legacy_shorthand(mode SerializationMode) ?string {
	if !property_is_legacy_shorthand(style_value.shorthand_) || style_value.values_.len != 1 {
		return none
	}
	serialized := style_value.values_[0].serialize(mode)
	if serialized in ['auto', 'avoid', 'left', 'right'] {
		return serialized
	}
	if serialized == 'page' {
		return 'always'
	}
	if style_value.shorthand_ == .page_break_inside && serialized == 'avoid-page' {
		return 'avoid'
	}
	return ''
}

fn (style_value ShorthandStyleValue) serialize_line_clamp(mode SerializationMode) ?string {
	if style_value.shorthand_ !in [.line_clamp, .webkit_line_clamp] {
		return none
	}
	max_lines := style_value.longhand(.max_lines) or { return '' }
	block_ellipsis := style_value.longhand(.block_ellipsis) or { return '' }
	continue_value := style_value.longhand(.continue_) or { return '' }
	max_lines_text := max_lines.serialize(mode)
	block_ellipsis_text := block_ellipsis.serialize(mode)
	continue_text := continue_value.serialize(mode)
	max_lines_is_none := max_lines_text == 'none'
	block_ellipsis_is_auto := block_ellipsis_text == 'auto'

	if style_value.shorthand_ == .webkit_line_clamp {
		if max_lines_is_none && block_ellipsis_text == 'no-ellipsis' && continue_text == 'auto' {
			return 'none'
		}
		if !max_lines_is_none && block_ellipsis_is_auto && continue_text == '-webkit-legacy' {
			return max_lines_text
		}
		return ''
	}

	if max_lines_is_none && block_ellipsis_text == 'no-ellipsis' && continue_text == 'auto' {
		return 'none'
	}
	if continue_text !in ['collapse', '-webkit-legacy'] {
		return ''
	}
	mut parts := []string{}
	if !max_lines_is_none {
		parts << max_lines_text
	}
	if !block_ellipsis_is_auto || max_lines_is_none {
		parts << block_ellipsis_text
	}
	if continue_text == '-webkit-legacy' {
		parts << continue_text
	}
	return parts.join(' ')
}

fn (style_value ShorthandStyleValue) serialize_container(mode SerializationMode) ?string {
	if style_value.shorthand_ != .container {
		return none
	}
	name := style_value.longhand(.container_name) or { return none }
	type_ := style_value.longhand(.container_type) or { return none }
	mut serialized := name.serialize(mode)
	if type_.serialize(mode) != computed_interpolation_property_initial_value(.container_type).css_text {
		serialized += ' / ${type_.serialize(mode)}'
	}
	return serialized
}

// The rule here seems to be, only print what's different from the default value,
// but if they're all default, print the line. The order is fixed - line,
// thickness, style, colour - and is not the order the longhands are listed in.
fn (style_value ShorthandStyleValue) serialize_text_decoration(mode SerializationMode) ?string {
	if style_value.shorthand_ != .text_decoration {
		return none
	}
	line := style_value.coordinating_longhand_value(.text_decoration_line) or { return none }
	mut parts := []string{}
	for property_id in [PropertyID.text_decoration_line, .text_decoration_thickness,
		.text_decoration_style, .text_decoration_color] {
		value := style_value.coordinating_longhand_value(property_id) or { return none }
		serialized := value.serialize(mode)
		if serialized != computed_interpolation_property_initial_value(property_id).css_text {
			parts << serialized
		}
	}
	if parts.len == 0 {
		return line.serialize(mode)
	}
	return parts.join(' ')
}

// `white-space` collapses back to its single-keyword form when `white-space-trim`
// is `none` and the collapse/wrap pair matches one of the four legacy keywords.
// Anything else falls through to the default longhand serialization.
fn (style_value ShorthandStyleValue) serialize_white_space(mode SerializationMode) ?string {
	if style_value.shorthand_ != .white_space {
		return none
	}
	white_space_collapse := style_value.coordinating_longhand_value(.white_space_collapse) or {
		return none
	}
	text_wrap_mode := style_value.coordinating_longhand_value(.text_wrap_mode) or { return none }
	white_space_trim := style_value.coordinating_longhand_value(.white_space_trim) or { return none }
	if white_space_trim.serialize(mode) != 'none' {
		return none
	}
	collapse := white_space_collapse.serialize(mode)
	wrap := text_wrap_mode.serialize(mode)
	if collapse == 'collapse' && wrap == 'wrap' {
		return 'normal'
	}
	if collapse == 'preserve' && wrap == 'nowrap' {
		return 'pre'
	}
	if collapse == 'preserve' && wrap == 'wrap' {
		return 'pre-wrap'
	}
	if collapse == 'preserve-breaks' && wrap == 'wrap' {
		return 'pre-line'
	}
	return none
}

// grid-row / grid-column serialize as `<start> [/ <end>]`, dropping the end when it
// is `auto` or equal to the start.
fn (style_value ShorthandStyleValue) serialize_grid_line(mode SerializationMode) ?string {
	if style_value.shorthand_ !in [PropertyID.grid_row, .grid_column] {
		return none
	}
	if style_value.values_.len != 2 {
		return none
	}
	// ShorthandStyleValue::serialize() reaches each longhand by property id, not
	// by position: Properties.json lists a shorthand's longhands alphabetically
	// (`grid-row` is `[grid-row-end, grid-row-start]`), which is not the order
	// they serialize in.
	start_id := if style_value.shorthand_ == .grid_row {
		PropertyID.grid_row_start
	} else {
		PropertyID.grid_column_start
	}
	end_id := if style_value.shorthand_ == .grid_row {
		PropertyID.grid_row_end
	} else {
		PropertyID.grid_column_end
	}
	start := (style_value.coordinating_longhand_value(start_id) or { return none }).serialize(mode)
	end := (style_value.coordinating_longhand_value(end_id) or { return none }).serialize(mode)
	if end == 'auto' || start == end {
		return start
	}
	return '${start} / ${end}'
}

// grid-template: `none`, the `<'grid-template-rows'> / <'grid-template-columns'>` form, and
// the named `[<line-names>? <string> <track-size>?]+ [/ <explicit-track-list>]?` form (which
// interleaves the area-row strings with the row tracks).
fn (style_value ShorthandStyleValue) serialize_grid_template(mode SerializationMode) ?string {
	if style_value.shorthand_ != .grid_template {
		return none
	}
	areas := style_value.coordinating_longhand_value(.grid_template_areas) or { return none }
	rows := style_value.coordinating_longhand_value(.grid_template_rows) or { return none }
	columns := style_value.coordinating_longhand_value(.grid_template_columns) or { return none }
	return serialize_grid_template_values(mode, areas, rows, columns)
}

fn serialize_grid_template_values(mode SerializationMode, areas StyleValue, rows StyleValue, columns StyleValue) ?string {
	if areas !is GridTemplateAreaStyleValue || rows !is GridTrackSizeListStyleValue || columns !is GridTrackSizeListStyleValue {
		return none
	}
	areas_value := areas as GridTemplateAreaStyleValue
	rows_value := rows as GridTrackSizeListStyleValue
	columns_value := columns as GridTrackSizeListStyleValue

	if areas_value.row_count() == 0 && rows_value.grid_track_size_list().is_empty() && columns_value.grid_track_size_list().is_empty() {
		return 'none'
	}

	// Without named areas, the simple `<rows> / <columns>` form.
	if areas_value.row_count() == 0 {
		return '${rows_value.serialize(mode)} / ${columns_value.serialize(mode)}'
	}

	// Named-areas form: interleave each area-row string with the row track sizes (omitting
	// `auto` track sizes), keeping any line-names.
	mut parts := []string{}
	mut area_index := 0
	for item in rows_value.grid_track_size_list().list() {
		if item is GridLineNames {
			parts << item.serialize()
		} else if item is ExplicitGridTrack {
			if area_index < int(areas_value.row_count()) {
				mut cells := []string{}
				for column in 0 .. int(areas_value.column_count()) {
					cells << areas_value.cell_name_at(uint(area_index), uint(column))
				}
				parts << serialize_a_string(cells.join(' '))
			}
			track_serialization := item.serialize(mode)
			if track_serialization != 'auto' {
				parts << track_serialization
			}
			area_index++
		}
	}
	if parts.len == 0 {
		return none
	}
	rows_serialization := parts.join(' ')
	if columns_value.grid_track_size_list().is_empty() {
		return rows_serialization
	}
	return '${rows_serialization} / ${columns_value.serialize(mode)}'
}

// grid = <'grid-template'> | <'grid-template-rows'> / [ auto-flow && dense? ] <'grid-auto-columns'>?
//      | [ auto-flow && dense? ] <'grid-auto-rows'>? / <'grid-template-columns'>
fn (style_value ShorthandStyleValue) serialize_grid(mode SerializationMode) ?string {
	if style_value.shorthand_ != .grid {
		return none
	}
	auto_flow := style_value.coordinating_longhand_value(.grid_auto_flow) or { return none }
	auto_rows := style_value.coordinating_longhand_value(.grid_auto_rows) or { return none }
	auto_columns := style_value.coordinating_longhand_value(.grid_auto_columns) or { return none }
	areas := style_value.coordinating_longhand_value(.grid_template_areas) or { return none }
	rows := style_value.coordinating_longhand_value(.grid_template_rows) or { return none }
	columns := style_value.coordinating_longhand_value(.grid_template_columns) or { return none }

	auto_flow_is_initial := auto_flow.serialize(mode) == computed_interpolation_property_initial_value(.grid_auto_flow).css_text
	auto_rows_is_initial := auto_rows.serialize(mode) == computed_interpolation_property_initial_value(.grid_auto_rows).css_text
	auto_columns_is_initial := auto_columns.serialize(mode) == computed_interpolation_property_initial_value(.grid_auto_columns).css_text

	// With no grid-auto-* set, `grid` is just a `<'grid-template'>`.
	if auto_flow_is_initial && auto_rows_is_initial && auto_columns_is_initial {
		return serialize_grid_template_values(mode, areas, rows, columns)
	}

	if auto_flow !is GridAutoFlowStyleValue {
		return none
	}
	flow := auto_flow as GridAutoFlowStyleValue
	areas_is_initial := areas.serialize(mode) == computed_interpolation_property_initial_value(.grid_template_areas).css_text
	rows_is_initial := rows.serialize(mode) == computed_interpolation_property_initial_value(.grid_template_rows).css_text
	columns_is_initial := columns.serialize(mode) == computed_interpolation_property_initial_value(.grid_template_columns).css_text

	// [ auto-flow && dense? ] <'grid-auto-rows'>? / <'grid-template-columns'>
	if flow.is_row() && auto_columns_is_initial && areas_is_initial && rows_is_initial {
		mut serialized := 'auto-flow'
		if flow.is_dense() {
			serialized += ' dense'
		}
		if !auto_rows_is_initial {
			serialized += ' ${auto_rows.serialize(mode)}'
		}
		serialized += ' / ${columns.serialize(mode)}'
		return serialized
	}

	// <'grid-template-rows'> / [ auto-flow && dense? ] <'grid-auto-columns'>?
	if flow.is_column() && auto_rows_is_initial && areas_is_initial && columns_is_initial {
		mut serialized := '${rows.serialize(mode)} / auto-flow'
		if flow.is_dense() {
			serialized += ' dense'
		}
		if !auto_columns_is_initial {
			serialized += ' ${auto_columns.serialize(mode)}'
		}
		return serialized
	}

	return none
}

fn grid_placement_is_auto(value StyleValue) bool {
	if value is GridTrackPlacementStyleValue {
		return value.grid_track_placement().is_auto()
	}
	return false
}

fn grid_placement_is_custom_ident(value StyleValue) bool {
	if value is GridTrackPlacementStyleValue {
		return value.grid_track_placement().is_custom_ident()
	}
	return false
}

// border-image always serializes the full `<source> <slice> / <width> / <outset> <repeat>`
// form (upstream does not omit initial longhands here).
fn (style_value ShorthandStyleValue) serialize_border_image(mode SerializationMode) ?string {
	if style_value.shorthand_ != .border_image {
		return none
	}
	source := style_value.coordinating_longhand_value(.border_image_source) or { return none }
	slice := style_value.coordinating_longhand_value(.border_image_slice) or { return none }
	width := style_value.coordinating_longhand_value(.border_image_width) or { return none }
	outset := style_value.coordinating_longhand_value(.border_image_outset) or { return none }
	repeat := style_value.coordinating_longhand_value(.border_image_repeat) or { return none }
	return '${source.serialize(mode)} ${slice.serialize(mode)} / ${width.serialize(mode)} / ${outset.serialize(mode)} ${repeat.serialize(mode)}'
}

// grid-area = <grid-line> [ / <grid-line> ]{0,3} — serialize row-start/column-start/
// row-end/column-end joined by ` / `, applying the same custom-ident propagation and
// collapse rules as upstream so the shortest equivalent form is produced.
fn (style_value ShorthandStyleValue) serialize_grid_area(mode SerializationMode) ?string {
	if style_value.shorthand_ != .grid_area || style_value.values_.len != 4 {
		return none
	}
	mut row_start := style_value.coordinating_longhand_value(.grid_row_start) or { return none }
	mut column_start := style_value.coordinating_longhand_value(.grid_column_start) or {
		return none
	}
	mut row_end := style_value.coordinating_longhand_value(.grid_row_end) or { return none }
	mut column_end := style_value.coordinating_longhand_value(.grid_column_end) or { return none }

	// With four explicit (non-auto) lines, serialize as-is (after collapse).
	if !grid_placement_is_auto(row_start) && !grid_placement_is_auto(column_start) && !grid_placement_is_auto(row_end) && !grid_placement_is_auto(column_end) {
		return serialize_grid_area_lines(mode, row_start, column_start, row_end, column_end)
	}

	// Reconstruct omitted lines from a <custom-ident> start (reverse of the shorthand's rules).
	if grid_placement_is_auto(column_end) && grid_placement_is_custom_ident(column_start) {
		column_end = column_start
	}
	if grid_placement_is_auto(column_start) && grid_placement_is_custom_ident(row_start) {
		column_start = row_start
		row_end = row_start
		column_end = row_start
	}
	if grid_placement_is_auto(row_end) && grid_placement_is_custom_ident(row_start) {
		row_end = row_start
	}
	return serialize_grid_area_lines(mode, row_start, column_start, row_end, column_end)
}

fn serialize_grid_area_lines(mode SerializationMode, row_start StyleValue, column_start StyleValue, row_end StyleValue, column_end StyleValue) string {
	row_start_s := row_start.serialize(mode)
	column_start_s := column_start.serialize(mode)
	row_end_s := row_end.serialize(mode)
	column_end_s := column_end.serialize(mode)

	if row_start_s == column_start_s && row_start_s == row_end_s && row_start_s == column_end_s {
		return row_start_s
	}
	if row_start_s == row_end_s && column_start_s == column_end_s {
		return '${row_start_s} / ${column_start_s}'
	}
	if column_start_s == column_end_s {
		if grid_placement_is_auto(row_end) {
			if grid_placement_is_auto(column_start) {
				return row_start_s
			}
			return '${row_start_s} / ${column_start_s}'
		}
		return '${row_start_s} / ${column_start_s} / ${row_end_s}'
	}
	return '${row_start_s} / ${column_start_s} / ${row_end_s} / ${column_end_s}'
}

// flex serializes its three longhands (grow, shrink, basis), space-separated.
fn (style_value ShorthandStyleValue) serialize_flex(mode SerializationMode) ?string {
	if style_value.shorthand_ != .flex || style_value.values_.len != 3 {
		return none
	}
	return '${style_value.values_[0].serialize(mode)} ${style_value.values_[1].serialize(mode)} ${style_value.values_[2].serialize(mode)}'
}

// Collapse four corner strings the way border-radius does (all-equal -> 1, opposite
// corners equal -> 2, etc.).
fn serialize_border_radius_corners(top_left string, top_right string, bottom_right string, bottom_left string) string {
	if top_left == top_right && top_left == bottom_right && top_left == bottom_left {
		return top_left
	}
	if top_left == bottom_right && top_right == bottom_left {
		return '${top_left} ${top_right}'
	}
	if top_right == bottom_left {
		return '${top_left} ${top_right} ${bottom_right}'
	}
	return '${top_left} ${top_right} ${bottom_right} ${bottom_left}'
}

// font serializes as `[<style> || <variant-css2> || <weight> || <width>]? <size>
// [/ <line-height>]? <family>` (matching the upstream Font case). Returns none when
// the value can't be represented as a `font` shorthand.
fn (style_value ShorthandStyleValue) serialize_font(mode SerializationMode) ?string {
	// Index layout must match `font_shorthand_longhands`:
	// 0 family, 1 size, 2 width, 3 style, 4 nested font-variant,
	// 5 weight, 6 line-height, 7.. reset-only longhands.
	if style_value.shorthand_ != .font { return none }
	if style_value.values_.len != font_shorthand_longhands.len { return '' }
	mut ser := []string{cap: 12}
	for value in style_value.values_ {
		ser << value.serialize(mode)
	}
	// The reset-only sub-properties must all be at their initial value.
	for i in 7 .. ser.len {
		if ser[i] != computed_interpolation_property_initial_value(style_value.sub_properties_[i]).css_text {
			return ''
		}
	}

	variant_value := style_value.values_[4]
	if variant_value !is ShorthandStyleValue {
		return ''
	}
	variant_shorthand := variant_value as ShorthandStyleValue
	if variant_shorthand.shorthand_ != .font_variant {
		return ''
	}
	// <font-variant-css2> = normal | small-caps: only font-variant-caps may differ.
	mut variant := 'normal'
	for id in [PropertyID.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
		.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position] {
		value := variant_shorthand.longhand(id) or { return '' }
		serialized := value.serialize(mode)
		initial := computed_interpolation_property_initial_value(id).css_text
		if id == .font_variant_caps {
			if serialized == 'small-caps' {
				variant = 'small-caps'
			} else if serialized != initial {
				return ''
			}
		} else if serialized != initial {
			return ''
		}
	}
	// <font-width-css3> is a keyword. A computed width is a percentage, which
	// the shorthand can express only when it is one of the keyword widths.
	ser[2] = match ser[2] {
		'50%' { 'ultra-condensed' }
		'62.5%' { 'extra-condensed' }
		'75%' { 'condensed' }
		'87.5%' { 'semi-condensed' }
		'100%' { 'normal' }
		'112.5%' { 'semi-expanded' }
		'125%' { 'expanded' }
		'150%' { 'extra-expanded' }
		'200%' { 'ultra-expanded' }
		else { ser[2] }
	}
	if ser[2] !in ['normal', 'ultra-condensed', 'extra-condensed', 'condensed', 'semi-condensed',
		'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded'] {
		return ''
	}
	mut parts := []string{}
	if ser[3] != 'normal' {
		parts << ser[3]
	}
	if variant != 'normal' {
		parts << variant
	}
	if ser[5] != 'normal' && ser[5] != '400' {
		parts << ser[5]
	}
	if ser[2] != 'normal' {
		parts << ser[2]
	}
	parts << ser[1]
	if ser[6] != 'normal' {
		parts << '/ ${ser[6]}'
	}
	parts << ser[0]
	return parts.join(' ')
}

// border-radius serializes as `<horizontal radii> [/ <vertical radii>]`.
fn (style_value ShorthandStyleValue) serialize_border_radius(mode SerializationMode) ?string {
	if style_value.shorthand_ != .border_radius || style_value.values_.len != 4 {
		return none
	}
	mut h := []string{cap: 4}
	mut v := []string{cap: 4}
	for value in style_value.values_ {
		if value is BorderRadiusStyleValue {
			h << value.horizontal_radius_().serialize(mode)
			v << value.vertical_radius_().serialize(mode)
		} else {
			s := value.serialize(mode)
			h << s
			v << s
		}
	}
	horizontal := serialize_border_radius_corners(h[0], h[1], h[2], h[3])
	vertical := serialize_border_radius_corners(v[0], v[1], v[2], v[3])
	if horizontal == vertical {
		return horizontal
	}
	return '${horizontal} / ${vertical}'
}

pub fn (style_value ShorthandStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value ShorthandStyleValue) properties_equal(other ShorthandStyleValue) bool {
	return style_value == other
}

// --- StyleValueList ---
pub enum StyleValueListSeparator {
	space
	comma
}

pub enum StyleValueListCollapsible {
	yes
	no
}

pub struct StyleValueList {
pub mut:
	separator_   StyleValueListSeparator
	collapsible_ StyleValueListCollapsible = .yes
	values_      []StyleValue
}

pub fn StyleValueList.create(values []StyleValue, separator StyleValueListSeparator, collapsible StyleValueListCollapsible) StyleValueList {
	return StyleValueList{
		separator_: separator
		collapsible_: collapsible
		values_: values
	}
}

pub fn StyleValueList.create_collapsible(values []StyleValue, separator StyleValueListSeparator) StyleValueList {
	return StyleValueList.create(values, separator, .yes)
}

pub fn (style_value StyleValueList) size() int {
	return style_value.values_.len
}

pub fn (style_value StyleValueList) values() []StyleValue {
	return style_value.values_
}

pub fn (style_value StyleValueList) value_at(i int, allow_loop bool) StyleValue {
	if allow_loop {
		return style_value.values_[i % style_value.size()]
	}
	return style_value.values_[i]
}

pub fn (style_value StyleValueList) separator() StyleValueListSeparator {
	return style_value.separator_
}

pub fn (style_value StyleValueList) serialize(mode SerializationMode) string {
	if style_value.values_.len == 0 {
		return ''
	}

	separator := match style_value.separator_ {
		.space { ' ' }
		.comma { ', ' }
	}

	first_value := style_value.values_[0]
	if style_value.separator_ != .comma && style_value.collapsible_ == .yes {
		mut all_equal := true
		for index in 1 .. style_value.values_.len {
			if !style_value.values_[index].equals(first_value) {
				all_equal = false
				break
			}
		}
		if all_equal {
			return first_value.serialize(mode)
		}
	}

	return serialize_style_value_sequence(style_value.values_, separator, mode)
}

pub fn (style_value StyleValueList) absolutized(context ComputationContext) StyleValue {
	for i, value in style_value.values_ {
		absolutized_value := value.absolutized(context)
		if absolutized_value != value {
			mut result := []StyleValue{cap: style_value.values_.len}
			for j := 0; j < i; j++ {
				result << style_value.values_[j]
			}
			result << absolutized_value
			for j := i + 1; j < style_value.values_.len; j++ {
				result << style_value.values_[j].absolutized(context)
			}
			return StyleValue(StyleValueList.create(result, style_value.separator_, style_value.collapsible_))
		}
	}
	return StyleValue(style_value)
}

pub fn (style_value StyleValueList) tokenize() []ComponentValue {
	mut component_values := []ComponentValue{}
	mut first := true
	for value in style_value.values_ {
		if first {
			first = false
		} else {
			if style_value.separator_ == .comma {
				component_values << ComponentValue.from_token(Token.create(.comma, ','))
			}
			component_values << ComponentValue.from_token(Token.create_whitespace(' '))
		}
		component_values << value.tokenize()
	}
	return component_values
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-transform-list
fn reify_a_transform_list(values []StyleValue) !CSSTransformValue {
	mut transform_components := []CSSTransformComponent{cap: values.len}
	for transform in values {
		if transform !is TransformationStyleValue {
			return error('Not a transform list')
		}
		transformation := transform as TransformationStyleValue
		// NB: Not all transform functions are reifiable, in which case we give up
		// reifying as a transform list.
		transform_components << transformation.reify_a_transform_function()!
	}
	return CSSTransformValue.create(transform_components)
}

pub fn (style_value StyleValueList) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	// NB: <transform-list> is a StyleValueList that contains TransformStyleValues. If that is what we are, follow the
	//     steps for reifying that.
	mut all_transformations := style_value.values_.len != 0
	for value in style_value.values_ {
		if value !is TransformationStyleValue {
			all_transformations = false
			break
		}
	}
	if all_transformations {
		if transform_list := reify_a_transform_list(style_value.values_) {
			return CSSStyleValue.from_transform(transform_list)
		}
	}

	// NB: Otherwise, there is not an equivalent CSSStyleValue for StyleValueList, so just use the default.
	return CSSStyleValue.create(associated_property, StyleValue(style_value))
}

pub fn (style_value StyleValueList) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value StyleValueList) properties_equal(other StyleValueList) bool {
	if style_value.separator_ != other.separator_ || style_value.values_.len != other.values_.len {
		return false
	}
	for index, value in style_value.values_ {
		if !value.equals(other.values_[index]) {
			return false
		}
	}
	return true
}

// --- SuperellipseStyleValue ---
pub struct SuperellipseStyleValue {
pub mut:
	parameter_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn SuperellipseStyleValue.create(parameter StyleValue) SuperellipseStyleValue {
	return SuperellipseStyleValue{
		parameter_: [parameter]
	}
}

pub fn (style_value SuperellipseStyleValue) parameter() f64 {
	return number_from_style_value(style_value.parameter_[0], none)
}

pub fn (style_value SuperellipseStyleValue) serialize(mode SerializationMode) string {

	mut serialized := 'superellipse('
	if !style_value.parameter_[0].is_number() {
		serialized += style_value.parameter_[0].serialize(mode)
	} else {
		number := style_value.parameter_[0].as_number().number()
		if math.is_inf(number, 1) {
			serialized += 'infinity'
		} else if math.is_inf(number, -1) {
			serialized += '-infinity'
		} else {
			serialized += style_value.parameter_[0].serialize(mode)
		}
	}
	serialized += ')'
	return serialized
}

pub fn (style_value SuperellipseStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_parameter := style_value.parameter_[0].absolutized(context)
	if absolutized_parameter == style_value.parameter_[0] {
		return StyleValue(style_value)
	}
	return StyleValue(SuperellipseStyleValue.create(absolutized_parameter))
}

pub fn (style_value SuperellipseStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value SuperellipseStyleValue) properties_equal(other SuperellipseStyleValue) bool {
	return style_value.parameter_[0] == other.parameter_[0]
}

// --- TextIndentStyleValue ---
pub enum TextIndentHanging {
	no
	yes
}

pub enum TextIndentEachLine {
	no
	yes
}

pub struct TextIndentStyleValue {
pub mut:
	length_percentage_ []StyleValue = [StyleValue(KeywordStyleValue{})]
	hanging_           bool
	each_line_         bool
}

pub fn TextIndentStyleValue.create(length_percentage StyleValue, hanging TextIndentHanging, each_line TextIndentEachLine) TextIndentStyleValue {
	return TextIndentStyleValue{
		length_percentage_: [length_percentage]
		hanging_: hanging == .yes
		each_line_: each_line == .yes
	}
}

pub fn (style_value TextIndentStyleValue) length_percentage() StyleValue {
	return style_value.length_percentage_[0]
}

pub fn (style_value TextIndentStyleValue) hanging() bool {
	return style_value.hanging_
}

pub fn (style_value TextIndentStyleValue) each_line() bool {
	return style_value.each_line_
}

pub fn (style_value TextIndentStyleValue) serialize(mode SerializationMode) string {
	mut serialized := style_value.length_percentage_[0].serialize(mode)
	if style_value.each_line_ {
		serialized += ' each-line'
	}
	if style_value.hanging_ {
		serialized += ' hanging'
	}
	return serialized
}

pub fn (style_value TextIndentStyleValue) absolutized(context ComputationContext) StyleValue {
	new_length_percentage := style_value.length_percentage_[0].absolutized(context)
	if new_length_percentage == style_value.length_percentage_[0] {
		return StyleValue(style_value)
	}
	return StyleValue(TextIndentStyleValue.create(new_length_percentage, if style_value.hanging_ {
		TextIndentHanging.yes
	} else {
		TextIndentHanging.no
	}, if style_value.each_line_ { TextIndentEachLine.yes } else { TextIndentEachLine.no }))
}

pub fn (style_value TextIndentStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value TextIndentStyleValue) properties_equal(other TextIndentStyleValue) bool {
	return style_value == other
}

// --- TextUnderlinePositionStyleValue ---
pub struct TextUnderlinePositionStyleValue {
pub mut:
	horizontal_ TextUnderlinePositionHorizontal
	vertical_   TextUnderlinePositionVertical
}

pub fn TextUnderlinePositionStyleValue.create(horizontal TextUnderlinePositionHorizontal, vertical TextUnderlinePositionVertical) TextUnderlinePositionStyleValue {
	return TextUnderlinePositionStyleValue{
		horizontal_: horizontal
		vertical_: vertical
	}
}

pub fn (style_value TextUnderlinePositionStyleValue) horizontal() TextUnderlinePositionHorizontal {
	return style_value.horizontal_
}

pub fn (style_value TextUnderlinePositionStyleValue) vertical() TextUnderlinePositionVertical {
	return style_value.vertical_
}

pub fn (style_value TextUnderlinePositionStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if style_value.horizontal_ == .auto_ && style_value.vertical_ == .auto_ {
		return 'auto'
	}

	if style_value.vertical_ == .auto_ {
		return text_underline_position_horizontal_to_string(style_value.horizontal_)
	}

	if style_value.horizontal_ == .auto_ {
		return text_underline_position_vertical_to_string(style_value.vertical_)
	}

	return '${text_underline_position_horizontal_to_string(style_value.horizontal_)} ${text_underline_position_vertical_to_string(style_value.vertical_)}'
}

pub fn (style_value TextUnderlinePositionStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value TextUnderlinePositionStyleValue) properties_equal(other TextUnderlinePositionStyleValue) bool {
	return style_value == other
}

// --- TreeCountingFunctionStyleValue ---
pub enum TreeCountingFunction {
	sibling_count
	sibling_index
}

pub enum TreeCountingComputedType {
	number
	integer
}

pub struct TreeCountingFunctionStyleValue {
pub mut:
	function_      TreeCountingFunction
	computed_type_ TreeCountingComputedType
}

pub fn TreeCountingFunctionStyleValue.create(function TreeCountingFunction, computed_type TreeCountingComputedType) TreeCountingFunctionStyleValue {
	return TreeCountingFunctionStyleValue{
		function_: function
		computed_type_: computed_type
	}
}

pub fn (style_value TreeCountingFunctionStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return match style_value.function_ {
		.sibling_count { 'sibling-count()' }
		.sibling_index { 'sibling-index()' }
	}
}

fn (style_value TreeCountingFunctionStyleValue) resolve_for_dom_context(context dom.TreeCountingFunctionResolutionContext) int {
	return match style_value.function_ {
		.sibling_count { context.sibling_count }
		.sibling_index { context.sibling_index }
	}
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve_for_dom_abstract_element(abstract_element &dom.AbstractElement) int {
	mut element := unsafe { &dom.Element(abstract_element.element()) }
	element.set_style_uses_tree_counting_function()
	tree_counting_function_resolution_context := abstract_element.tree_counting_function_resolution_context()
	return style_value.resolve_for_dom_context(tree_counting_function_resolution_context)
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve_to_calculation_node(calculation_context CalculationContext, calculation_resolution_context CalculationResolutionContext) ?CalculationNode {
	_ = calculation_context
	abstract_element := calculation_resolution_context.abstract_element or { return none }
	value := style_value.resolve_for_dom_abstract_element(&abstract_element)
	return calculation_node_from_calc(calc_canonical_leaf(.number, f64(value)))
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve() int {
	// DOM context integration: C++ resolves this through ComputationContext::abstract_element. Callers with a DOM
	// element should use resolve_for_dom_abstract_element().
	panic('TreeCountingFunctionStyleValue::resolve requires a DOM AbstractElement')
}

fn tree_counting_computed_style_value(value int, computed_type TreeCountingComputedType) StyleValue {
	return match computed_type {
		.integer { StyleValue(IntegerStyleValue.create(i64(value))) }
		.number { StyleValue(NumberStyleValue.create(f64(value))) }
	}
}

pub fn (style_value TreeCountingFunctionStyleValue) absolutized(context ComputationContext) StyleValue {
	// FIXME: We should clamp this value in case it falls outside the valid range for the context it is in.
	abstract_element := context.abstract_element or {
		panic('TreeCountingFunctionStyleValue::absolutized requires ComputationContext.abstract_element')
	}

	value := style_value.resolve_for_dom_abstract_element(abstract_element)
	return tree_counting_computed_style_value(value, style_value.computed_type_)
}

pub fn (style_value TreeCountingFunctionStyleValue) absolutized_for_dom_abstract_element(context ComputationContext, abstract_element &dom.AbstractElement) StyleValue {
	_ = context
	// FIXME: We should clamp this value in case it falls outside the valid range for the context it is in.
	value := style_value.resolve_for_dom_abstract_element(abstract_element)
	return tree_counting_computed_style_value(value, style_value.computed_type_)
}

pub fn (style_value TreeCountingFunctionStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value TreeCountingFunctionStyleValue) properties_equal(other TreeCountingFunctionStyleValue) bool {
	return style_value == other
}

// --- TupleStyleValue ---
const tuple_scroll_function_scroller_index = 0
const tuple_scroll_function_axis_index = 1
const tuple_view_function_axis_index = 0
const tuple_view_function_inset_index = 1

pub struct TupleStyleValue {
pub mut:
	tuple_ []?StyleValue
}

pub fn TupleStyleValue.create(values []?StyleValue) TupleStyleValue {
	return TupleStyleValue{
		tuple_: values
	}
}

pub fn (style_value TupleStyleValue) tuple() []?StyleValue {
	return style_value.tuple_
}

pub fn (style_value TupleStyleValue) serialize(mode SerializationMode) string {
	return serialize_style_value_options(style_value.tuple_, ' ', mode)
}

pub fn (style_value TupleStyleValue) absolutized(context ComputationContext) StyleValue {
	mut absolutized_tuple := []?StyleValue{cap: style_value.tuple_.len}
	mut any_value_changed := false

	for maybe_value in style_value.tuple_ {
		if value := maybe_value {
			absolutized_value := value.absolutized(context)
			if absolutized_value != value {
				any_value_changed = true
			}
			absolutized_tuple << absolutized_value
		} else {
			absolutized_tuple << none
		}
	}

	if !any_value_changed {
		return StyleValue(style_value)
	}

	return StyleValue(TupleStyleValue.create(absolutized_tuple))
}

pub fn (style_value TupleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value TupleStyleValue) properties_equal(other TupleStyleValue) bool {
	return style_value.tuple_ == other.tuple_
}

// --- UnicodeRangeStyleValue ---
pub struct UnicodeRangeStyleValue {
pub mut:
	unicode_range_ UnicodeRange
}

pub fn UnicodeRangeStyleValue.create(unicode_range UnicodeRange) UnicodeRangeStyleValue {
	return UnicodeRangeStyleValue{
		unicode_range_: unicode_range
	}
}

pub fn (style_value UnicodeRangeStyleValue) unicode_range() UnicodeRange {
	return style_value.unicode_range_
}

pub fn (range UnicodeRange) to_css_string() string {
	if range.start == range.end {
		return 'U+${range.start:X}'
	}
	return 'U+${range.start:X}-${range.end:X}'
}

pub fn serialize_unicode_ranges(ranges []UnicodeRange) string {
	mut serialized_ranges := []string{cap: ranges.len}
	for range_ in ranges {
		serialized_ranges << range_.to_css_string()
	}
	return serialized_ranges.join(', ')
}

pub fn (style_value UnicodeRangeStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.unicode_range_.to_css_string()
}

pub fn (style_value UnicodeRangeStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value UnicodeRangeStyleValue) properties_equal(other UnicodeRangeStyleValue) bool {
	return style_value.unicode_range_ == other.unicode_range_
}

// --- StyleValue downcasts for translated subclasses ---
pub fn (style_value StyleValue) as_border_radius() ?BorderRadiusStyleValue {
	value := style_value
	if value is BorderRadiusStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_shadow() ?ShadowStyleValue {
	value := style_value
	if value is ShadowStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_value_list() ?StyleValueList {
	value := style_value
	if value is StyleValueList {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_image() ?ImageStyleValue {
	value := style_value
	if value is ImageStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_url() ?URLStyleValue {
	value := style_value
	if value is URLStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_font_style() ?FontStyleStyleValue {
	value := style_value
	if value is FontStyleStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_linear_gradient() ?LinearGradientStyleValue {
	value := style_value
	if value is LinearGradientStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_radial_gradient() ?RadialGradientStyleValue {
	value := style_value
	if value is RadialGradientStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_conic_gradient() ?ConicGradientStyleValue {
	value := style_value
	if value is ConicGradientStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_radial_size() ?RadialSizeStyleValue {
	value := style_value
	if value is RadialSizeStyleValue {
		return value
	}
	return none
}

pub fn (style_value StyleValue) as_edge() EdgeStyleValue {
	value := style_value
	if value is EdgeStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_position() PositionStyleValue {
	value := style_value
	if value is PositionStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}
