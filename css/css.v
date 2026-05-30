// Stub module for CSS-related functions called by Document
module css

import math
import strings
import dom

// --- Style invalidation ---

pub enum StyleInvalidationReason {
	base_url_changed
	hover_changed
	style_sheet_changed
	dom_mutation
}

pub fn invalidate_style(doc &dom.Document, reason StyleInvalidationReason) {
	mapped_reason := match reason {
		.base_url_changed { dom.StyleInvalidationReason.base_url_changed }
		.hover_changed, .style_sheet_changed, .dom_mutation { dom.StyleInvalidationReason.style_change }
	}

	mut document_node := unsafe { &dom.Node(doc) }
	document_node.invalidate_style(mapped_reason)
}

// --- CSS Parsing stubs ---

pub struct ParsingParams {
pub:
	document            &dom.Document = unsafe { nil }
	rule_context        []RuleContext
	declared_namespaces map[string]bool
}

pub enum PropertyID {
	accent_color
	anchor_name
	anchor_scope
	animation_composition
	animation_delay
	animation_direction
	animation_duration
	animation_fill_mode
	animation_iteration_count
	animation_name
	animation_play_state
	animation_timeline
	animation_timing_function
	aspect_ratio
	background_color
	background_image
	border_bottom_color
	border_bottom_width
	border_left_color
	border_left_width
	border_right_color
	border_right_width
	border_top_color
	border_top_width
	border_image_source
	caret_color
	clear
	color
	color_scheme
	content_visibility
	corner_bottom_left_shape
	corner_bottom_right_shape
	corner_top_left_shape
	corner_top_right_shape
	fill_opacity
	flood_color
	flood_opacity
	float_
	font_feature_settings
	font_style
	font_variation_settings
	font_weight
	font_width
	letter_spacing
	line_height
	list_style_image
	mask_image
	math_depth
	math_style
	mix_blend_mode
	object_fit
	opacity
	order
	orphans
	outline_color
	outline_offset
	outline_style
	outline_width
	overflow_x
	overflow_y
	pointer_events
	position
	position_anchor
	shape_image_threshold
	stop_color
	stop_opacity
	stroke_opacity
	rotate
	scale
	scroll_timeline_name
	transform
	transition_behavior
	transition_delay
	transition_duration
	transition_property
	transition_timing_function
	translate
	view_timeline_inset
	view_timeline_name
	webkit_text_fill_color
	word_spacing
	caption_side
	direction
	empty_cells
	table_layout
	unicode_bidi
	visibility
	z_index
	clip_rule
	color_interpolation
	fill_rule
	mask_type
	shape_rendering
	stroke_linecap
	stroke_linejoin
	text_anchor
	border_bottom_style
	border_left_style
	border_right_style
	border_top_style
	isolation
	border_collapse
	user_select
	box_sizing
	list_style_position
	transform_style
	text_align
	text_justify
	text_overflow
	text_rendering
	text_transform
	text_wrap_mode
	text_wrap_style
	white_space_collapse
	white_space_trim
	word_break
	font_kerning
	font_language_override
	font_optical_sizing
	font_variant_caps
	font_variant_emoji
	font_variant_position
	flex_direction
	flex_wrap
	align_content
	align_items
	align_self
	justify_content
	justify_items
	justify_self
	appearance
	column_span
	image_rendering
	transform_box
	touch_action
	writing_mode
	view_transition_name
	scrollbar_width
	resize
}

pub fn parse_css_value(context ParsingParams, text string, property PropertyID) ?&dom.StyleValue {
	mut parser := Parser.with_context(context, text)
	value := parser.parse_css_value(property) or { return none }
	return dom_style_value_from_value_logic(value)
}

// --- Color resolution ---

pub struct ColorResolutionContext {
pub mut:
	color_scheme  ?PreferredColorScheme
	current_color ?Color
	accent_color  ?Color
}

pub fn color_resolution_context_for_layout_node(node &dom.LayoutNode) ColorResolutionContext {
	return ColorResolutionContext{}
}

// --- ContentVisibility ---

pub enum ContentVisibility {
	auto_
	visible
	hidden
}

// --- RequiredInvalidationAfterStyleChange ---

pub struct RequiredInvalidationAfterStyleChange {
pub mut:
	repaint                             bool
	rebuild_stacking_context_tree       bool
	relayout                            bool
	rebuild_layout_tree                 bool
	rebuild_accumulated_visual_contexts bool
}

pub fn (r RequiredInvalidationAfterStyleChange) is_none() bool {
	return !r.repaint && !r.rebuild_stacking_context_tree && !r.relayout && !r.rebuild_layout_tree
		&& !r.rebuild_accumulated_visual_contexts
}

// --- StyleComputer user agent source ---

pub fn user_agent_style_sheet_source(url string) ?string {
	return none
}

// --- Serialization ---

pub enum SerializationMode {
	normal
	resolved_value
}

// https://drafts.csswg.org/cssom/#serialize-a-css-value
pub fn serialize_a_number(value f64) string {
	// -> <number>
	// A base-ten number using digits 0-9 (U+0030 to U+0039) in the shortest form possible, using "." to separate
	// decimals (if any), rounding the value if necessary to not produce more than 6 decimals, preceded by "-"
	// (U+002D) if it is negative.
	// NOTE: scientific notation is not used.

	// AD-HOC: If the number is small enough that it would not print any digits when rounded, serialize it as 0.
	if math.abs(value) < 0.0000005 {
		return '0'
	}

	mut serialized := '${value:.6f}'
	for serialized.contains('.') && serialized.ends_with('0') {
		serialized = serialized[..serialized.len - 1]
	}
	if serialized.ends_with('.') {
		serialized = serialized[..serialized.len - 1]
	}
	if serialized == '-0' {
		return '0'
	}
	return serialized
}

pub fn serialize_an_identifier(ident string) string {
	mut builder := strings.new_builder(ident.len)
	runes := ident.runes()
	first_character := if runes.len == 0 { rune(0) } else { runes[0] }
	for index, character in runes {
		code_point := u32(character)
		if code_point == 0 {
			builder.write_rune(rune(0xfffd))
			continue
		}
		if (code_point >= 0x0001 && code_point <= 0x001f) || code_point == 0x007f {
			builder.write_string('\\${code_point:x} ')
			continue
		}
		if index == 0 && character >= `0` && character <= `9` {
			builder.write_string('\\${code_point:x} ')
			continue
		}
		if index == 1 && first_character == `-` && character >= `0` && character <= `9` {
			builder.write_string('\\${code_point:x} ')
			continue
		}
		if index == 0 && character == `-` && runes.len == 1 {
			builder.write_u8(`\\`)
			builder.write_rune(character)
			continue
		}
		if code_point >= 0x0080 || character == `-` || character == `_`
			|| (character >= `0` && character <= `9`)
			|| (character >= `A` && character <= `Z`)
			|| (character >= `a` && character <= `z`) {
			builder.write_rune(character)
			continue
		}
		builder.write_u8(`\\`)
		builder.write_rune(character)
	}
	return builder.str()
}

pub fn serialize_a_string(value string) string {
	mut builder := strings.new_builder(value.len + 2)
	builder.write_u8(`"`)
	for character in value.runes() {
		code_point := u32(character)
		if code_point == 0 {
			builder.write_rune(rune(0xfffd))
			continue
		}
		if (code_point >= 0x0001 && code_point <= 0x001f) || code_point == 0x007f {
			builder.write_string('\\${code_point:x} ')
			continue
		}
		if character == `"` || character == `\\` {
			builder.write_u8(`\\`)
			builder.write_rune(character)
			continue
		}
		builder.write_rune(character)
	}
	builder.write_u8(`"`)
	return builder.str()
}

pub fn serialize_a_url(url string) string {
	return 'url(${serialize_a_string(url)})'
}

// https://drafts.csswg.org/cssom/#serialize-a-css-declaration
pub fn serialize_a_css_declaration(property string, value string, important Important) string {
	// 1. Let s be the empty string.
	mut serialized := ''

	// 2. Append property to s.
	// AD-HOC: There's no place currently on the spec where the property name properly escaped,
	//         and this needs to be done when custom properties have special characters.
	//         Related spec issues:
	//          - https://github.com/w3c/csswg-drafts/issues/11729
	//          - https://github.com/w3c/csswg-drafts/issues/12258
	serialized += serialize_an_identifier(property)

	// 3. Append ": " (U+003A U+0020) to s.
	serialized += ': '

	// 4. If value contains any non-whitespace characters, append value to s.
	if value.trim_space().len != 0 {
		serialized += value
	}

	// 5. If the important flag is set, append " !important" (U+0020 U+0021 U+0069 U+006D U+0070 U+006F U+0072 U+0074
	//    U+0061 U+006E U+0074) to s.
	if important == .yes {
		serialized += ' !important'
	}

	// 6. Append ";" (U+003B) to s.
	serialized += ';'

	// 7. Return s.
	return serialized
}

// --- Units ---

pub enum AngleUnit {
	deg
	grad
	rad
	turn
}

pub enum FrequencyUnit {
	hz
	khz
}

pub enum FlexUnit {
	fr
}

pub enum ResolutionUnit {
	dpcm
	dpi
	dppx
	x
}

pub enum TimeUnit {
	ms
	s
}

pub enum LengthUnit {
	cap
	ch
	cm
	dvb
	dvh
	dvi
	dvmax
	dvmin
	dvw
	em
	ex
	ic
	in_
	lh
	lvb
	lvh
	lvi
	lvmax
	lvmin
	lvw
	mm
	pc
	pt
	px
	q
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

pub fn angle_unit_name(unit AngleUnit) string {
	return match unit {
		.deg { 'deg' }
		.grad { 'grad' }
		.rad { 'rad' }
		.turn { 'turn' }
	}
}

pub fn frequency_unit_name(unit FrequencyUnit) string {
	return match unit {
		.hz { 'Hz' }
		.khz { 'kHz' }
	}
}

pub fn flex_unit_name(unit FlexUnit) string {
	return match unit {
		.fr { 'fr' }
	}
}

pub fn resolution_unit_name(unit ResolutionUnit) string {
	return match unit {
		.dpcm { 'dpcm' }
		.dpi { 'dpi' }
		.dppx { 'dppx' }
		.x { 'x' }
	}
}

pub fn time_unit_name(unit TimeUnit) string {
	return match unit {
		.ms { 'ms' }
		.s { 's' }
	}
}

pub fn length_unit_name(unit LengthUnit) string {
	return match unit {
		.cap { 'cap' }
		.ch { 'ch' }
		.cm { 'cm' }
		.dvb { 'dvb' }
		.dvh { 'dvh' }
		.dvi { 'dvi' }
		.dvmax { 'dvmax' }
		.dvmin { 'dvmin' }
		.dvw { 'dvw' }
		.em { 'em' }
		.ex { 'ex' }
		.ic { 'ic' }
		.in_ { 'in' }
		.lh { 'lh' }
		.lvb { 'lvb' }
		.lvh { 'lvh' }
		.lvi { 'lvi' }
		.lvmax { 'lvmax' }
		.lvmin { 'lvmin' }
		.lvw { 'lvw' }
		.mm { 'mm' }
		.pc { 'pc' }
		.pt { 'pt' }
		.px { 'px' }
		.q { 'Q' }
		.rcap { 'rcap' }
		.rch { 'rch' }
		.rem { 'rem' }
		.rex { 'rex' }
		.ric { 'ric' }
		.rlh { 'rlh' }
		.svb { 'svb' }
		.svh { 'svh' }
		.svi { 'svi' }
		.svmax { 'svmax' }
		.svmin { 'svmin' }
		.svw { 'svw' }
		.vb { 'vb' }
		.vh { 'vh' }
		.vi { 'vi' }
		.vmax { 'vmax' }
		.vmin { 'vmin' }
		.vw { 'vw' }
	}
}

fn angle_units_per_canonical_unit(unit AngleUnit) f64 {
	return match unit {
		.deg { 1.0 }
		.grad { 0.9 }
		.rad { 57.29577951308232 }
		.turn { 360.0 }
	}
}

fn frequency_units_per_canonical_unit(unit FrequencyUnit) f64 {
	return match unit {
		.hz { 1.0 }
		.khz { 1000.0 }
	}
}

fn flex_units_per_canonical_unit(unit FlexUnit) f64 {
	return match unit {
		.fr { 1.0 }
	}
}

fn resolution_units_per_canonical_unit(unit ResolutionUnit) f64 {
	return match unit {
		.dpcm { 0.026458333333333334 }
		.dpi { 0.010416666666666666 }
		.dppx { 1.0 }
		.x { 1.0 }
	}
}

fn time_units_per_canonical_unit(unit TimeUnit) f64 {
	return match unit {
		.ms { 0.001 }
		.s { 1.0 }
	}
}

fn length_units_per_canonical_unit(unit LengthUnit) f64 {
	return match unit {
		.cm { 37.79527559055118 }
		.in_ { 96.0 }
		.mm { 3.779527559055118 }
		.pc { 16.0 }
		.pt { 1.3333333333333333 }
		.px { 1.0 }
		.q { 0.9448818897637795 }
		else { 1.0 }
	}
}

pub fn is_absolute_length_unit(unit LengthUnit) bool {
	return unit in [.cm, .in_, .mm, .pc, .pt, .px, .q]
}

pub fn is_font_relative_length_unit(unit LengthUnit) bool {
	return unit in [.cap, .ch, .em, .ex, .ic, .lh, .rcap, .rch, .rem, .rex, .ric, .rlh]
}

pub fn is_viewport_relative_length_unit(unit LengthUnit) bool {
	return unit in [
		.dvb,
		.dvh,
		.dvi,
		.dvmax,
		.dvmin,
		.dvw,
		.lvb,
		.lvh,
		.lvi,
		.lvmax,
		.lvmin,
		.lvw,
		.svb,
		.svh,
		.svi,
		.svmax,
		.svmin,
		.svw,
		.vb,
		.vh,
		.vi,
		.vmax,
		.vmin,
		.vw,
	]
}

pub fn is_relative_length_unit(unit LengthUnit) bool {
	return is_font_relative_length_unit(unit) || is_viewport_relative_length_unit(unit)
}

pub fn angle_units_are_compatible(a AngleUnit, b AngleUnit) bool {
	_ = a
	_ = b
	return true
}

pub fn frequency_units_are_compatible(a FrequencyUnit, b FrequencyUnit) bool {
	_ = a
	_ = b
	return true
}

pub fn flex_units_are_compatible(a FlexUnit, b FlexUnit) bool {
	_ = a
	_ = b
	return true
}

pub fn resolution_units_are_compatible(a ResolutionUnit, b ResolutionUnit) bool {
	_ = a
	_ = b
	return true
}

pub fn time_units_are_compatible(a TimeUnit, b TimeUnit) bool {
	_ = a
	_ = b
	return true
}

pub fn length_units_are_compatible(a LengthUnit, b LengthUnit) bool {
	// https://drafts.csswg.org/css-values-4/#compatible-units
	// NB: The spec describes two ways units can be compatible. Absolute ones always are, but it also lists em/px
	//     as compatible at computed value time. We should already have absolutized the units by then, but perhaps
	//     there is some case where we need to handle that here instead.
	return is_absolute_length_unit(a) && is_absolute_length_unit(b)
}

pub fn ratio_between_angle_units(from AngleUnit, to AngleUnit) f64 {
	return angle_units_per_canonical_unit(from) / angle_units_per_canonical_unit(to)
}

pub fn ratio_between_frequency_units(from FrequencyUnit, to FrequencyUnit) f64 {
	return frequency_units_per_canonical_unit(from) / frequency_units_per_canonical_unit(to)
}

pub fn ratio_between_flex_units(from FlexUnit, to FlexUnit) f64 {
	return flex_units_per_canonical_unit(from) / flex_units_per_canonical_unit(to)
}

pub fn ratio_between_resolution_units(from ResolutionUnit, to ResolutionUnit) f64 {
	return resolution_units_per_canonical_unit(from) / resolution_units_per_canonical_unit(to)
}

pub fn ratio_between_time_units(from TimeUnit, to TimeUnit) f64 {
	return time_units_per_canonical_unit(from) / time_units_per_canonical_unit(to)
}

pub fn ratio_between_length_units(from LengthUnit, to LengthUnit) f64 {
	return length_units_per_canonical_unit(from) / length_units_per_canonical_unit(to)
}

// --- Percentage ---

pub struct Percentage {
pub mut:
	value_ f64
}

pub fn Percentage.new(value f64) Percentage {
	return Percentage{
		value_: value
	}
}

pub fn (p Percentage) value() f64 {
	return p.value_
}

pub fn (p Percentage) as_fraction() f64 {
	return p.value_ * 0.01
}

pub fn (p Percentage) serialize(mode SerializationMode) string {
	_ = mode
	return '${serialize_a_number(p.value_)}%'
}

pub fn (p Percentage) to_string() string {
	return p.serialize(.normal)
}

pub fn (p Percentage) compare(other Percentage) int {
	if p.value_ < other.value_ {
		return -1
	}
	if p.value_ > other.value_ {
		return 1
	}
	return 0
}

// --- Angle ---

pub struct Angle {
pub mut:
	value_ f64
	unit_  AngleUnit
}

pub fn Angle.new(value f64, unit AngleUnit) Angle {
	return Angle{
		value_: value
		unit_:  unit
	}
}

pub fn Angle.make_degrees(value f64) Angle {
	return Angle.new(value, .deg)
}

pub fn (a Angle) percentage_of(percentage Percentage) Angle {
	return Angle.new(percentage.as_fraction() * a.value_, a.unit_)
}

pub fn (a Angle) serialize(mode SerializationMode) string {
	if mode == .resolved_value {
		return '${serialize_a_number(a.to_degrees())}deg'
	}
	return '${serialize_a_number(a.raw_value())}${a.unit_name()}'
}

pub fn (a Angle) to_string() string {
	return a.serialize(.normal)
}

pub fn (a Angle) to_string_with_mode(mode SerializationMode) string {
	return a.serialize(mode)
}

pub fn (a Angle) to_degrees() f64 {
	return ratio_between_angle_units(a.unit_, .deg) * a.value_
}

pub fn (a Angle) to_radians() f64 {
	return ratio_between_angle_units(a.unit_, .rad) * a.value_
}

pub fn (a Angle) raw_value() f64 {
	return a.value_
}

pub fn (a Angle) unit() AngleUnit {
	return a.unit_
}

pub fn (a Angle) unit_name() string {
	return angle_unit_name(a.unit_)
}

pub fn (a Angle) compare(other Angle) int {
	this_degrees := a.to_degrees()
	other_degrees := other.to_degrees()
	if this_degrees < other_degrees {
		return -1
	}
	if this_degrees > other_degrees {
		return 1
	}
	return 0
}

// --- Frequency ---

pub struct Frequency {
pub mut:
	value_ f64
	unit_  FrequencyUnit
}

pub fn Frequency.new(value f64, unit FrequencyUnit) Frequency {
	return Frequency{
		value_: value
		unit_:  unit
	}
}

pub fn Frequency.make_hertz(value f64) Frequency {
	return Frequency.new(value, .hz)
}

pub fn (f Frequency) percentage_of(percentage Percentage) Frequency {
	return Frequency.new(percentage.as_fraction() * f.value_, f.unit_)
}

pub fn (f Frequency) serialize(mode SerializationMode) string {
	if mode == .resolved_value {
		return '${serialize_a_number(f.to_hertz())}hz'
	}
	return '${serialize_a_number(f.raw_value())}${f.unit_name()}'
}

pub fn (f Frequency) to_string() string {
	return f.serialize(.normal)
}

pub fn (f Frequency) to_string_with_mode(mode SerializationMode) string {
	return f.serialize(mode)
}

pub fn (f Frequency) to_hertz() f64 {
	return ratio_between_frequency_units(f.unit_, .hz) * f.value_
}

pub fn (f Frequency) raw_value() f64 {
	return f.value_
}

pub fn (f Frequency) unit() FrequencyUnit {
	return f.unit_
}

pub fn (f Frequency) unit_name() string {
	return frequency_unit_name(f.unit_)
}

pub fn (f Frequency) compare(other Frequency) int {
	this_hertz := f.to_hertz()
	other_hertz := other.to_hertz()
	if this_hertz < other_hertz {
		return -1
	}
	if this_hertz > other_hertz {
		return 1
	}
	return 0
}

// --- Flex ---

// https://drafts.csswg.org/css-grid-2/#typedef-flex
pub struct Flex {
pub mut:
	value_ f64
	unit_  FlexUnit
}

pub fn Flex.new(value f64, unit FlexUnit) Flex {
	return Flex{
		value_: value
		unit_:  unit
	}
}

pub fn Flex.make_fr(value f64) Flex {
	return Flex.new(value, .fr)
}

pub fn (f Flex) percentage_of(percentage Percentage) Flex {
	return Flex.new(percentage.as_fraction() * f.value_, f.unit_)
}

pub fn (f Flex) serialize(mode SerializationMode) string {
	// https://drafts.csswg.org/cssom/#serialize-a-css-value
	// AD-HOC: No spec definition, so copy the other <dimension> definitions.
	if mode == .resolved_value {
		return '${serialize_a_number(f.to_fr())}fr'
	}
	return '${serialize_a_number(f.raw_value())}${f.unit_name()}'
}

pub fn (f Flex) to_string() string {
	return f.serialize(.normal)
}

pub fn (f Flex) to_string_with_mode(mode SerializationMode) string {
	return f.serialize(mode)
}

pub fn (f Flex) to_fr() f64 {
	return ratio_between_flex_units(f.unit_, .fr) * f.value_
}

pub fn (f Flex) raw_value() f64 {
	return f.value_
}

pub fn (f Flex) unit() FlexUnit {
	return f.unit_
}

pub fn (f Flex) unit_name() string {
	return flex_unit_name(f.unit_)
}

pub fn (f Flex) compare(other Flex) int {
	this_fr := f.to_fr()
	other_fr := other.to_fr()
	if this_fr < other_fr {
		return -1
	}
	if this_fr > other_fr {
		return 1
	}
	return 0
}

// --- Number ---

pub enum NumberType {
	number
	integer_with_explicit_sign
	integer
}

pub struct Number {
pub mut:
	value_ f64
	type_  NumberType = .number
}

pub fn Number.new() Number {
	return Number{}
}

pub fn Number.with_type(type_ NumberType, value f64) Number {
	return Number{
		value_: value
		type_:  type_
	}
}

pub fn (n Number) type_() NumberType {
	return n.type_
}

pub fn (n Number) value() f64 {
	return n.value_
}

pub fn (n Number) integer_value() i64 {
	// https://www.w3.org/TR/css-values-4/#numeric-types
	// When a value cannot be explicitly supported due to range/precision limitations, it must be converted
	// to the closest value supported by the implementation, but how the implementation defines "closest"
	// is explicitly undefined as well.
	return i64(math.round(n.value_))
}

pub fn (n Number) is_integer() bool {
	return n.type_ == .integer || n.type_ == .integer_with_explicit_sign
}

pub fn (n Number) is_integer_with_explicit_sign() bool {
	return n.type_ == .integer_with_explicit_sign
}

pub fn (n Number) plus(other Number) Number {
	if n.is_integer() && other.is_integer() {
		return Number.with_type(.integer, n.value_ + other.value_)
	}
	return Number.with_type(.number, n.value_ + other.value_)
}

pub fn (n Number) minus(other Number) Number {
	if n.is_integer() && other.is_integer() {
		return Number.with_type(.integer, n.value_ - other.value_)
	}
	return Number.with_type(.number, n.value_ - other.value_)
}

pub fn (n Number) times(other Number) Number {
	if n.is_integer() && other.is_integer() {
		return Number.with_type(.integer, n.value_ * other.value_)
	}
	return Number.with_type(.number, n.value_ * other.value_)
}

pub fn (n Number) divided_by(other Number) Number {
	return Number.with_type(.number, n.value_ / other.value_)
}

pub fn (n Number) percentage_of(percentage Percentage) Number {
	return Number.with_type(.number, percentage.as_fraction() * n.value_)
}

pub fn (n Number) serialize(mode SerializationMode) string {
	_ = mode
	if n.type_ == .integer_with_explicit_sign {
		if n.value_ >= 0 {
			return '+${serialize_a_number(n.value_)}'
		}
		return serialize_a_number(n.value_)
	}
	if math.is_inf(n.value_, 1) {
		return 'infinity'
	}
	if math.is_inf(n.value_, -1) {
		return '-infinity'
	}
	if math.is_nan(n.value_) {
		return 'NaN'
	}
	return serialize_a_number(n.value_)
}

pub fn (n Number) to_string() string {
	return n.serialize(.normal)
}

pub fn (n Number) to_string_with_mode(mode SerializationMode) string {
	return n.serialize(mode)
}

pub fn (n Number) compare(other Number) int {
	if n.value_ < other.value_ {
		return -1
	}
	if n.value_ > other.value_ {
		return 1
	}
	return 0
}

// --- Ratio ---

pub struct Ratio {
pub mut:
	first_value_  f64
	second_value_ f64 = 1.0
}

pub fn Ratio.new(first f64, second f64) Ratio {
	return Ratio{
		first_value_:  first
		second_value_: second
	}
}

pub fn Ratio.new_single(first f64) Ratio {
	return Ratio.new(first, 1.0)
}

pub fn (r Ratio) numerator() f64 {
	return r.first_value_
}

pub fn (r Ratio) denominator() f64 {
	return r.second_value_
}

pub fn (r Ratio) value() f64 {
	return r.first_value_ / r.second_value_
}

// https://www.w3.org/TR/css-values-4/#degenerate-ratio
pub fn (r Ratio) is_degenerate() bool {
	return math.is_inf(r.first_value_, 0) || math.is_nan(r.first_value_) || r.first_value_ == 0
		|| math.is_inf(r.second_value_, 0) || math.is_nan(r.second_value_) || r.second_value_ == 0
}

pub fn (r Ratio) to_string() string {
	// https://drafts.csswg.org/cssom/#serialize-a-css-value
	// -> <ratio>
	// The numerator serialized as per <number> followed by the literal string " / ", followed by the denominator
	// serialized as per <number>.
	return '${serialize_a_number(r.first_value_)} / ${serialize_a_number(r.second_value_)}'
}

pub fn (r Ratio) compare(other Ratio) int {
	this_value := r.value()
	other_value := other.value()
	if this_value < other_value {
		return -1
	}
	if this_value > other_value {
		return 1
	}
	return 0
}

// --- Resolution ---

pub struct Resolution {
pub mut:
	value_ f64
	unit_  ResolutionUnit
}

pub fn Resolution.new(value f64, unit ResolutionUnit) Resolution {
	return Resolution{
		value_: value
		unit_:  unit
	}
}

pub fn Resolution.make_dots_per_pixel(value f64) Resolution {
	return Resolution.new(value, .dppx)
}

pub fn (r Resolution) serialize(mode SerializationMode) string {
	// https://drafts.csswg.org/cssom/#serialize-a-css-value
	// -> <resolution>
	// The resolution in dots per CSS pixel serialized as per <number> followed by the literal string "dppx".
	// AD-HOC: WPT expects us to serialize using the actual unit, like for other dimensions.
	//         https://github.com/w3c/csswg-drafts/issues/12616
	if mode == .resolved_value {
		return '${serialize_a_number(r.to_dots_per_pixel())}dppx'
	}
	return '${serialize_a_number(r.raw_value())}${r.unit_name()}'
}

pub fn (r Resolution) to_string() string {
	return r.serialize(.normal)
}

pub fn (r Resolution) to_string_with_mode(mode SerializationMode) string {
	return r.serialize(mode)
}

pub fn (r Resolution) to_dots_per_pixel() f64 {
	return ratio_between_resolution_units(r.unit_, .dppx) * r.value_
}

pub fn (r Resolution) raw_value() f64 {
	return r.value_
}

pub fn (r Resolution) unit() ResolutionUnit {
	return r.unit_
}

pub fn (r Resolution) unit_name() string {
	return resolution_unit_name(r.unit_)
}

pub fn (r Resolution) compare(other Resolution) int {
	this_dots_per_pixel := r.to_dots_per_pixel()
	other_dots_per_pixel := other.to_dots_per_pixel()
	if this_dots_per_pixel < other_dots_per_pixel {
		return -1
	}
	if this_dots_per_pixel > other_dots_per_pixel {
		return 1
	}
	return 0
}

// --- Time ---

pub struct Time {
pub mut:
	value_ f64
	unit_  TimeUnit
}

pub fn Time.new(value f64, unit TimeUnit) Time {
	return Time{
		value_: value
		unit_:  unit
	}
}

pub fn Time.make_seconds(value f64) Time {
	return Time.new(value, .s)
}

pub fn (t Time) percentage_of(percentage Percentage) Time {
	return Time.new(percentage.as_fraction() * t.value_, t.unit_)
}

pub fn (t Time) serialize(mode SerializationMode) string {
	// https://drafts.csswg.org/cssom/#serialize-a-css-value
	// -> <time>
	// The time in seconds serialized as per <number> followed by the literal string "s".
	// AD-HOC: WPT expects us to serialize using the actual unit, like for other dimensions.
	//         https://github.com/w3c/csswg-drafts/issues/12616
	if mode == .resolved_value {
		return '${serialize_a_number(t.to_seconds())}s'
	}
	return '${serialize_a_number(t.raw_value())}${t.unit_name()}'
}

pub fn (t Time) to_string() string {
	return t.serialize(.normal)
}

pub fn (t Time) to_string_with_mode(mode SerializationMode) string {
	return t.serialize(mode)
}

pub fn (t Time) to_seconds() f64 {
	return ratio_between_time_units(t.unit_, .s) * t.value_
}

pub fn (t Time) to_milliseconds() f64 {
	return ratio_between_time_units(t.unit_, .ms) * t.value_
}

pub fn (t Time) raw_value() f64 {
	return t.value_
}

pub fn (t Time) unit() TimeUnit {
	return t.unit_
}

pub fn (t Time) unit_name() string {
	return time_unit_name(t.unit_)
}

pub fn (t Time) compare(other Time) int {
	this_seconds := t.to_seconds()
	other_seconds := other.to_seconds()
	if this_seconds < other_seconds {
		return -1
	}
	if this_seconds > other_seconds {
		return 1
	}
	return 0
}

// --- CSS pixel units ---

pub struct CSSPixels {
pub mut:
	raw_value_ int
}

pub fn CSSPixels.new(value int) CSSPixels {
	return CSSPixels.from_raw(value * css_pixels_fixed_point_denominator)
}

pub fn CSSPixels.from_raw(value int) CSSPixels {
	return CSSPixels{
		raw_value_: value
	}
}

pub fn CSSPixels.nearest_value_for(value f64) CSSPixels {
	mut raw_value := 0
	if !math.is_nan(value) {
		raw_value = int(math.round(value * f64(css_pixels_fixed_point_denominator)))
	}
	return CSSPixels.from_raw(raw_value)
}

pub fn (p CSSPixels) to_double() f64 {
	return f64(p.raw_value_) / f64(css_pixels_fixed_point_denominator)
}

pub fn (p CSSPixels) raw_value() int {
	return p.raw_value_
}

pub fn (p CSSPixels) plus(other CSSPixels) CSSPixels {
	return CSSPixels.from_raw(p.raw_value_ + other.raw_value_)
}

pub fn (p CSSPixels) minus(other CSSPixels) CSSPixels {
	return CSSPixels.from_raw(p.raw_value_ - other.raw_value_)
}

pub fn (p CSSPixels) times_float(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(p.to_double() * value)
}

pub fn (p CSSPixels) divided_by_float(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(p.to_double() / value)
}

pub fn (p CSSPixels) might_be_saturated() bool {
	return false
}

const css_pixels_fractional_bits = 6
const css_pixels_fixed_point_denominator = 1 << css_pixels_fractional_bits

pub struct CSSPixelRect {
pub mut:
	x      CSSPixels
	y      CSSPixels
	width  CSSPixels
	height CSSPixels
}

pub fn CSSPixelRect.new(x f64, y f64, width f64, height f64) CSSPixelRect {
	return CSSPixelRect{
		x:      CSSPixels.nearest_value_for(x)
		y:      CSSPixels.nearest_value_for(y)
		width:  CSSPixels.nearest_value_for(width)
		height: CSSPixels.nearest_value_for(height)
	}
}

pub fn (r CSSPixelRect) width_value() f64 {
	return r.width.to_double()
}

pub fn (r CSSPixelRect) height_value() f64 {
	return r.height.to_double()
}

pub fn (r CSSPixelRect) left_value() f64 {
	return r.x.to_double()
}

pub fn (r CSSPixelRect) top_value() f64 {
	return r.y.to_double()
}

pub struct CSSPixelSize {
pub mut:
	width_  CSSPixels
	height_ CSSPixels
}

pub fn CSSPixelSize.new(width CSSPixels, height CSSPixels) CSSPixelSize {
	return CSSPixelSize{
		width_:  width
		height_: height
	}
}

pub fn CSSPixelSize.from_values(width f64, height f64) CSSPixelSize {
	return CSSPixelSize.new(CSSPixels.nearest_value_for(width), CSSPixels.nearest_value_for(height))
}

pub fn (s CSSPixelSize) width() CSSPixels {
	return s.width_
}

pub fn (s CSSPixelSize) height() CSSPixels {
	return s.height_
}

pub fn (s CSSPixelSize) is_empty() bool {
	return s.width_.raw_value() <= 0 || s.height_.raw_value() <= 0
}

pub struct CSSPixelFraction {
pub mut:
	value_ f64
}

pub fn CSSPixelFraction.new(numerator CSSPixels, denominator CSSPixels) CSSPixelFraction {
	if denominator.raw_value() == 0 {
		return CSSPixelFraction{
			value_: math.inf(1)
		}
	}
	return CSSPixelFraction{
		value_: numerator.to_double() / denominator.to_double()
	}
}

pub fn CSSPixelFraction.from_double(value f64) CSSPixelFraction {
	return CSSPixelFraction{
		value_: value
	}
}

pub fn (f CSSPixelFraction) to_double() f64 {
	return f.value_
}

pub fn (f CSSPixelFraction) might_be_saturated() bool {
	return math.is_inf(f.value_, 0) || math.is_nan(f.value_) || f.value_ == 0
}

// --- Length ---

pub struct LengthFontMetrics {
pub mut:
	font_size    CSSPixels
	x_height     CSSPixels
	cap_height   CSSPixels
	zero_advance CSSPixels
	line_height  CSSPixels
}

pub fn LengthFontMetrics.new(font_size CSSPixels, x_height CSSPixels, cap_height CSSPixels, zero_advance CSSPixels, line_height CSSPixels) LengthFontMetrics {
	return LengthFontMetrics{
		font_size:    font_size
		x_height:     x_height
		cap_height:   cap_height
		zero_advance: zero_advance
		line_height:  line_height
	}
}

pub fn LengthFontMetrics.default() LengthFontMetrics {
	font_size := CSSPixels.nearest_value_for(16.0)
	return LengthFontMetrics{
		font_size:    font_size
		x_height:     CSSPixels.nearest_value_for(8.0)
		cap_height:   CSSPixels.nearest_value_for(12.0)
		zero_advance: CSSPixels.nearest_value_for(8.0)
		line_height:  CSSPixels.nearest_value_for(19.2)
	}
}

pub struct LengthResolutionContext {
pub mut:
	viewport_rect     CSSPixelRect
	font_metrics      LengthFontMetrics
	root_font_metrics LengthFontMetrics
}

pub fn LengthResolutionContext.default() LengthResolutionContext {
	font_metrics := LengthFontMetrics.default()
	return LengthResolutionContext{
		viewport_rect:     CSSPixelRect.new(0, 0, 0, 0)
		font_metrics:      font_metrics
		root_font_metrics: font_metrics
	}
}

pub fn LengthResolutionContext.for_document(document &dom.Document) LengthResolutionContext {
	_ = document
	return LengthResolutionContext.default()
}

pub fn LengthResolutionContext.for_layout_node(node &dom.LayoutNode) LengthResolutionContext {
	_ = node
	return LengthResolutionContext.default()
}

pub struct Length {
pub mut:
	value_ f64
	unit_  LengthUnit
}

pub fn Length.new(value f64, unit LengthUnit) Length {
	return Length{
		value_: value
		unit_:  unit
	}
}

pub fn Length.make_px(value f64) Length {
	return Length.new(value, .px)
}

pub fn Length.make_css_px(value CSSPixels) Length {
	return Length.make_px(value.to_double())
}

pub fn (l Length) percentage_of(percentage Percentage) Length {
	return Length.new(percentage.as_fraction() * l.raw_value(), l.unit_)
}

pub fn (l Length) is_px() bool {
	return l.unit_ == .px
}

pub fn (l Length) is_absolute() bool {
	return is_absolute_length_unit(l.unit_)
}

pub fn (l Length) is_font_relative() bool {
	return is_font_relative_length_unit(l.unit_)
}

pub fn (l Length) is_viewport_relative() bool {
	return is_viewport_relative_length_unit(l.unit_)
}

pub fn (l Length) is_relative() bool {
	return is_relative_length_unit(l.unit_)
}

pub fn (l Length) raw_value() f64 {
	return l.value_
}

pub fn (l Length) unit() LengthUnit {
	return l.unit_
}

pub fn (l Length) unit_name() string {
	return length_unit_name(l.unit_)
}

pub fn (l Length) to_px(context LengthResolutionContext) CSSPixels {
	return l.to_px_with_values(context.viewport_rect, context.font_metrics,
		context.root_font_metrics)
}

pub fn (l Length) to_px_without_rounding(context LengthResolutionContext) f64 {
	if l.is_absolute() {
		return l.absolute_length_to_px_without_rounding()
	}
	if l.is_font_relative() {
		return l.font_relative_length_to_px_without_rounding(context.font_metrics,
			context.root_font_metrics)
	}
	if l.is_viewport_relative() {
		return l.viewport_relative_length_to_px_without_rounding(context.viewport_rect)
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (l Length) to_px_with_values(viewport_rect CSSPixelRect, font_metrics LengthFontMetrics, root_font_metrics LengthFontMetrics) CSSPixels {
	if l.is_absolute() {
		return l.absolute_length_to_px()
	}
	if l.is_font_relative() {
		return l.font_relative_length_to_px(font_metrics, root_font_metrics)
	}
	if l.is_viewport_relative() {
		return l.viewport_relative_length_to_px(viewport_rect)
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (l Length) absolute_length_to_px() CSSPixels {
	return CSSPixels.nearest_value_for(l.absolute_length_to_px_without_rounding())
}

pub fn (l Length) absolute_length_to_px_without_rounding() f64 {
	return ratio_between_length_units(l.unit_, .px) * l.value_
}

pub fn (l Length) font_relative_length_to_px(font_metrics LengthFontMetrics, root_font_metrics LengthFontMetrics) CSSPixels {
	return CSSPixels.nearest_value_for(l.font_relative_length_to_px_without_rounding(font_metrics,
		root_font_metrics))
}

pub fn (l Length) font_relative_length_to_px_without_rounding(font_metrics LengthFontMetrics, root_font_metrics LengthFontMetrics) f64 {
	return match l.unit_ {
		.em {
			l.value_ * font_metrics.font_size.to_double()
		}
		.rem {
			l.value_ * root_font_metrics.font_size.to_double()
		}
		.ex {
			l.value_ * font_metrics.x_height.to_double()
		}
		.rex {
			l.value_ * root_font_metrics.x_height.to_double()
		}
		.cap {
			l.value_ * font_metrics.cap_height.to_double()
		}
		.rcap {
			l.value_ * root_font_metrics.cap_height.to_double()
		}
		.ch {
			l.value_ * font_metrics.zero_advance.to_double()
		}
		.rch {
			l.value_ * root_font_metrics.zero_advance.to_double()
		}
		.ic {
			// FIXME: Use the advance measure of the CJK water ideograph, U+6C34.
			l.value_ * font_metrics.font_size.to_double()
		}
		.ric {
			// FIXME: Use the advance measure of the CJK water ideograph, U+6C34.
			l.value_ * root_font_metrics.font_size.to_double()
		}
		.lh {
			l.value_ * font_metrics.line_height.to_double()
		}
		.rlh {
			l.value_ * root_font_metrics.line_height.to_double()
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub fn (l Length) viewport_relative_length_to_px(viewport_rect CSSPixelRect) CSSPixels {
	return CSSPixels.nearest_value_for(l.viewport_relative_length_to_px_without_rounding(viewport_rect))
}

pub fn (l Length) viewport_relative_length_to_px_without_rounding(viewport_rect CSSPixelRect) f64 {
	width := viewport_rect.width_value()
	height := viewport_rect.height_value()
	return match l.unit_ {
		.vw, .svw, .lvw, .dvw {
			width * l.value_ / 100.0
		}
		.vh, .svh, .lvh, .dvh {
			height * l.value_ / 100.0
		}
		.vi, .svi, .lvi, .dvi {
			// FIXME: Select the width or height based on which is the inline axis.
			width * l.value_ / 100.0
		}
		.vb, .svb, .lvb, .dvb {
			// FIXME: Select the width or height based on which is the block axis.
			height * l.value_ / 100.0
		}
		.vmin, .svmin, .lvmin, .dvmin {
			math.min(width, height) * l.value_ / 100.0
		}
		.vmax, .svmax, .lvmax, .dvmax {
			math.max(width, height) * l.value_ / 100.0
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub fn (l Length) serialize(mode SerializationMode) string {
	// https://drafts.csswg.org/cssom/#serialize-a-css-value
	// -> <length>
	// The <number> component serialized as per <number> followed by the unit in its canonical form as defined in its
	// respective specification.

	// FIXME: Manually skip this for px so we avoid rounding errors in absolute_length_to_px.
	//        Maybe provide alternative functions that don't produce CSSPixels?
	if mode == .resolved_value && l.is_absolute() && l.unit_ != .px {
		return '${serialize_a_number(l.absolute_length_to_px().to_double())}px'
	}
	return '${serialize_a_number(l.value_)}${l.unit_name()}'
}

pub fn (l Length) to_string() string {
	return l.serialize(.normal)
}

pub fn (l Length) to_string_with_mode(mode SerializationMode) string {
	return l.serialize(mode)
}

pub fn (l Length) absolutize(context LengthResolutionContext) ?Length {
	if l.is_px() {
		return none
	}
	return Length.make_px(l.to_px_without_rounding(context))
}

pub struct LengthOrAuto {
pub mut:
	length_ ?Length
}

pub fn LengthOrAuto.new(length Length) LengthOrAuto {
	return LengthOrAuto{
		length_: length
	}
}

pub fn LengthOrAuto.make_auto() LengthOrAuto {
	return LengthOrAuto{}
}

pub fn (loa LengthOrAuto) is_length() bool {
	return loa.length_ != none
}

pub fn (loa LengthOrAuto) is_auto() bool {
	return loa.length_ == none
}

pub fn (loa LengthOrAuto) length() ?Length {
	return loa.length_
}

pub fn (loa LengthOrAuto) serialize(mode SerializationMode) string {
	if length := loa.length_ {
		return length.serialize(mode)
	}
	return 'auto'
}

pub fn (loa LengthOrAuto) to_string() string {
	return loa.serialize(.normal)
}

pub fn (loa LengthOrAuto) to_string_with_mode(mode SerializationMode) string {
	return loa.serialize(mode)
}

pub fn (loa LengthOrAuto) to_px_or_zero(context LengthResolutionContext) CSSPixels {
	if length := loa.length_ {
		return length.to_px(context)
	}
	return CSSPixels{}
}

// --- Calculated style value stubs ---

pub type CalculationPercentageBasis = Angle | Frequency | Length | Number | Time

pub struct CalculationResolutionContext {
pub mut:
	percentage_basis          ?CalculationPercentageBasis
	length_resolution_context LengthResolutionContext
}

pub fn (context CalculationResolutionContext) percentage_basis_angle() ?Angle {
	basis := context.percentage_basis or { return none }
	if basis is Angle {
		if basis.unit() == .deg {
			return basis
		}
		return Angle.make_degrees(basis.to_degrees())
	}
	return none
}

pub fn (context CalculationResolutionContext) percentage_basis_frequency() ?Frequency {
	basis := context.percentage_basis or { return none }
	if basis is Frequency {
		if basis.unit() == .hz {
			return basis
		}
		return Frequency.make_hertz(basis.to_hertz())
	}
	return none
}

pub fn (context CalculationResolutionContext) percentage_basis_length() ?Length {
	basis := context.percentage_basis or { return none }
	if basis is Length {
		if basis.is_px() {
			return basis
		}
		if basis.is_absolute() {
			return Length.make_px(basis.absolute_length_to_px_without_rounding())
		}
		return Length.make_px(basis.to_px_without_rounding(context.length_resolution_context))
	}
	return none
}

pub fn (context CalculationResolutionContext) percentage_basis_number() ?Number {
	basis := context.percentage_basis or { return none }
	if basis is Number {
		return basis
	}
	return none
}

pub fn (context CalculationResolutionContext) percentage_basis_time() ?Time {
	basis := context.percentage_basis or { return none }
	if basis is Time {
		if basis.unit() == .s {
			return basis
		}
		return Time.make_seconds(basis.to_seconds())
	}
	return none
}

pub fn CalculationResolutionContext.from_computation_context(computation_context ComputationContext, percentage_basis ?CalculationPercentageBasis) CalculationResolutionContext {
	return CalculationResolutionContext{
		percentage_basis:          percentage_basis
		length_resolution_context: computation_context.length_resolution_context
	}
}

pub struct CalculatedStyleValue {
pub mut:
	serialization string = 'calc(0px)'
	numeric_type_ ?NumericType
}

pub fn CalculatedStyleValue.create(node CalculationNode, numeric_type NumericType, context CalculationContext) CalculatedStyleValue {
	_ = context
	return CalculatedStyleValue{
		serialization: if node.serialization.len == 0 { 'calc(0px)' } else { node.serialization }
		numeric_type_: numeric_type
	}
}

pub fn (c CalculatedStyleValue) numeric_type() ?NumericType {
	return c.numeric_type_
}

pub fn (c CalculatedStyleValue) contains_percentage() bool {
	if numeric_type := c.numeric_type_ {
		if exponent := numeric_type.exponent(.percent) {
			return exponent != 0
		}
	}
	return c.serialization.contains('%')
}

pub fn (c CalculatedStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if c.serialization.len == 0 {
		return 'calc(0px)'
	}
	return c.serialization
}

pub fn (c CalculatedStyleValue) absolutized(computation_context ComputationContext) StyleValue {
	_ = computation_context
	// C++ simplifies the calculation tree with computed-value-time information here.
	// This port stores only serialized calculation text, so the full tree simplification is a boundary until
	// CalculationNode carries translated children. Keep the calculated value intact instead of inventing a simplified
	// value.
	return StyleValue(c)
}

fn (c CalculatedStyleValue) inner_calculation_text() string {
	trimmed := c.serialization.trim_space()
	if trimmed.starts_with('calc(') && trimmed.ends_with(')') {
		return trimmed[5..trimmed.len - 1].trim_space()
	}
	return trimmed
}

fn calculated_parse_number(text string) ?Number {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_number(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn calculated_parse_percentage(text string) ?Percentage {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_percentage(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn calculated_parse_length(text string) ?Length {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_length(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn calculated_parse_angle(text string) ?Angle {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_angle(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn calculated_parse_frequency(text string) ?Frequency {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	style_value := parser.parse_frequency_value(mut tokens) or { return none }
	if tokens.has_more_tokens() || style_value !is FrequencyStyleValue {
		return none
	}
	return (style_value as FrequencyStyleValue).frequency()
}

fn calculated_parse_resolution(text string) ?Resolution {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	style_value := parser.parse_resolution_value(mut tokens) or { return none }
	if tokens.has_more_tokens() || style_value !is ResolutionStyleValue {
		return none
	}
	return (style_value as ResolutionStyleValue).resolution()
}

fn calculated_parse_time(text string) ?Time {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	style_value := parser.parse_time_value(mut tokens) or { return none }
	if tokens.has_more_tokens() || style_value !is TimeStyleValue {
		return none
	}
	return (style_value as TimeStyleValue).time()
}

pub struct CalculatedResolvedValue {
pub mut:
	value f64
	type_ ?NumericType
}

// https://drafts.csswg.org/css-values-4/#calc-computed-value
pub fn (c CalculatedStyleValue) resolve_value(resolution_context CalculationResolutionContext) ?CalculatedResolvedValue {
	_ = resolution_context
	// The calculation tree is again simplified at used value time; with used value time information.
	// Boundary: the full CalculationNode tree is not translated yet, so reify the currently supported serialized
	// numeric/math functions through Typed OM and require a single sum item.
	numeric_value := CSSNumericValue.parse(c.serialize(.normal)) or { return none }
	sum := numeric_value.create_a_sum_value() or { return none }
	if sum.len != 1 {
		return none
	}

	unit_value := CSSUnitValue.create_from_sum_value_item(sum[0]) or { return none }
	mut raw_value := unit_value.value()

	// https://drafts.csswg.org/css-values/#calc-ieee
	// NaN does not escape a top-level calculation; it’s censored into a zero value.
	if math.is_nan(raw_value) {
		raw_value = 0
	}

	// https://drafts.csswg.org/css-values/#calc-range
	// the value resulting from a top-level calculation must be clamped to the range allowed in the target context.
	// Boundary: accepted type ranges are not translated into CalculationContext yet.
	resolved_type := NumericType.create_from_unit(unit_value.unit()) or { return none }
	return CalculatedResolvedValue{
		value: raw_value
		type_: resolved_type
	}
}

pub fn (c CalculatedStyleValue) resolve_length(context CalculationResolutionContext) ?Length {
	result := c.resolve_value(context) or { return none }
	resolved_type := result.type_ or { return none }
	if resolved_type.matches_length(none) {
		return Length.make_px(result.value)
	}
	if resolved_type.matches_percentage() {
		if percentage_basis := context.percentage_basis_length() {
			return percentage_basis.percentage_of(Percentage.new(result.value))
		}
	}
	return none
}

fn parsed_length_percentage_style_value_from_dom_style_value(style_value &dom.StyleValue) ?StyleValue {
	if style_value.css_text.len == 0 {
		return none
	}
	mut parser := Parser.from_css_text(style_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_length_percentage_value(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

pub fn Length.from_style_value(style_value &dom.StyleValue, percentage_basis ?Length) Length {
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return Length.from_style_value_logic(parsed_value, percentage_basis)
	}
	if basis := percentage_basis {
		return basis
	}
	return Length.make_px(0)
}

pub fn Length.resolve_calculated(calculated CalculatedStyleValue, context LengthResolutionContext, reference_value Length) Length {
	resolution_context := CalculationResolutionContext{
		percentage_basis:          reference_value
		length_resolution_context: context
	}
	return calculated.resolve_length(resolution_context) or { Length.make_px(0) }
}

pub fn Length.resolve_calculated_with_px(calculated CalculatedStyleValue, context LengthResolutionContext, reference_value CSSPixels) Length {
	return Length.resolve_calculated(calculated, context, Length.make_css_px(reference_value))
}

// --- PercentageOr ---

pub type AnglePercentageValue = Angle | CalculatedStyleValue | Percentage

pub struct AnglePercentage {
pub mut:
	value_ AnglePercentageValue
}

pub fn AnglePercentage.from_angle(angle Angle) AnglePercentage {
	return AnglePercentage{
		value_: angle
	}
}

pub fn AnglePercentage.from_percentage(percentage Percentage) AnglePercentage {
	return AnglePercentage{
		value_: percentage
	}
}

pub fn AnglePercentage.from_calculated(calculated CalculatedStyleValue) AnglePercentage {
	return AnglePercentage{
		value_: calculated
	}
}

pub fn (ap AnglePercentage) is_angle() bool {
	return ap.value_ is Angle
}

pub fn (ap AnglePercentage) is_percentage() bool {
	return ap.value_ is Percentage
}

pub fn (ap AnglePercentage) is_calculated() bool {
	return ap.value_ is CalculatedStyleValue
}

pub fn (ap AnglePercentage) contains_percentage() bool {
	value := ap.value_
	return match value {
		Angle { false }
		Percentage { true }
		CalculatedStyleValue { value.contains_percentage() }
	}
}

pub fn (ap AnglePercentage) angle() Angle {
	value := ap.value_
	if value is Angle {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (ap AnglePercentage) percentage() Percentage {
	value := ap.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (ap AnglePercentage) calculated() CalculatedStyleValue {
	value := ap.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (ap AnglePercentage) resolved(reference_value Angle) Angle {
	value := ap.value_
	return match value {
		Angle {
			value
		}
		Percentage {
			reference_value.percentage_of(value)
		}
		CalculatedStyleValue {
			value.resolve_angle(CalculationResolutionContext{
				percentage_basis: reference_value
			}) or { reference_value }
		}
	}
}

pub fn (ap AnglePercentage) serialize(mode SerializationMode) string {
	value := ap.value_
	return match value {
		Angle { value.serialize(mode) }
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (ap AnglePercentage) to_string() string {
	return ap.serialize(.normal)
}

pub fn (ap AnglePercentage) to_string_with_mode(mode SerializationMode) string {
	return ap.serialize(mode)
}

pub type FrequencyPercentageValue = CalculatedStyleValue | Frequency | Percentage

pub struct FrequencyPercentage {
pub mut:
	value_ FrequencyPercentageValue
}

pub fn FrequencyPercentage.from_frequency(frequency Frequency) FrequencyPercentage {
	return FrequencyPercentage{
		value_: frequency
	}
}

pub fn FrequencyPercentage.from_percentage(percentage Percentage) FrequencyPercentage {
	return FrequencyPercentage{
		value_: percentage
	}
}

pub fn FrequencyPercentage.from_calculated(calculated CalculatedStyleValue) FrequencyPercentage {
	return FrequencyPercentage{
		value_: calculated
	}
}

pub fn (fp FrequencyPercentage) is_frequency() bool {
	return fp.value_ is Frequency
}

pub fn (fp FrequencyPercentage) is_percentage() bool {
	return fp.value_ is Percentage
}

pub fn (fp FrequencyPercentage) is_calculated() bool {
	return fp.value_ is CalculatedStyleValue
}

pub fn (fp FrequencyPercentage) contains_percentage() bool {
	value := fp.value_
	return match value {
		Frequency { false }
		Percentage { true }
		CalculatedStyleValue { value.contains_percentage() }
	}
}

pub fn (fp FrequencyPercentage) frequency() Frequency {
	value := fp.value_
	if value is Frequency {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (fp FrequencyPercentage) percentage() Percentage {
	value := fp.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (fp FrequencyPercentage) calculated() CalculatedStyleValue {
	value := fp.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (fp FrequencyPercentage) resolved(reference_value Frequency) Frequency {
	value := fp.value_
	return match value {
		Frequency {
			value
		}
		Percentage {
			reference_value.percentage_of(value)
		}
		CalculatedStyleValue {
			value.resolve_frequency(CalculationResolutionContext{
				percentage_basis: reference_value
			}) or { reference_value }
		}
	}
}

pub fn (fp FrequencyPercentage) serialize(mode SerializationMode) string {
	value := fp.value_
	return match value {
		Frequency { value.serialize(mode) }
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (fp FrequencyPercentage) to_string() string {
	return fp.serialize(.normal)
}

pub fn (fp FrequencyPercentage) to_string_with_mode(mode SerializationMode) string {
	return fp.serialize(mode)
}

pub type LengthPercentageValue = CalculatedStyleValue | Length | Percentage

pub struct LengthPercentage {
pub mut:
	value_ LengthPercentageValue
}

pub fn LengthPercentage.from_length(length Length) LengthPercentage {
	return LengthPercentage{
		value_: length
	}
}

pub fn LengthPercentage.from_percentage(percentage Percentage) LengthPercentage {
	return LengthPercentage{
		value_: percentage
	}
}

pub fn LengthPercentage.from_calculated(calculated CalculatedStyleValue) LengthPercentage {
	return LengthPercentage{
		value_: calculated
	}
}

pub fn LengthPercentage.from_style_value(style_value &dom.StyleValue) LengthPercentage {
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return LengthPercentage.from_style_value_logic(parsed_value)
	}
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn (lp LengthPercentage) is_length() bool {
	return lp.value_ is Length
}

pub fn (lp LengthPercentage) is_percentage() bool {
	return lp.value_ is Percentage
}

pub fn (lp LengthPercentage) is_calculated() bool {
	return lp.value_ is CalculatedStyleValue
}

pub fn (lp LengthPercentage) contains_percentage() bool {
	value := lp.value_
	return match value {
		Length { false }
		Percentage { true }
		CalculatedStyleValue { value.contains_percentage() }
	}
}

pub fn (lp LengthPercentage) length() Length {
	value := lp.value_
	if value is Length {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (lp LengthPercentage) percentage() Percentage {
	value := lp.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (lp LengthPercentage) calculated() CalculatedStyleValue {
	value := lp.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (lp LengthPercentage) to_px(context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	value := lp.value_
	if value is Length {
		if value.is_absolute() {
			return value.absolute_length_to_px()
		}
	}
	return lp.resolved(context, reference_value).to_px(context)
}

pub fn (lp LengthPercentage) resolved(context LengthResolutionContext, reference_value CSSPixels) Length {
	value := lp.value_
	return match value {
		Length {
			value
		}
		Percentage {
			Length.make_css_px(CSSPixels.nearest_value_for(value.value() * reference_value.to_double() / 100.0))
		}
		CalculatedStyleValue {
			Length.resolve_calculated_with_px(value, context, reference_value)
		}
	}
}

pub fn (lp LengthPercentage) serialize(mode SerializationMode) string {
	value := lp.value_
	return match value {
		Length { value.serialize(mode) }
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (lp LengthPercentage) to_string() string {
	return lp.serialize(.normal)
}

pub fn (lp LengthPercentage) to_string_with_mode(mode SerializationMode) string {
	return lp.serialize(mode)
}

pub struct LengthPercentageOrAuto {
pub mut:
	length_percentage_ ?LengthPercentage
}

pub fn LengthPercentageOrAuto.from_length_percentage(length_percentage LengthPercentage) LengthPercentageOrAuto {
	return LengthPercentageOrAuto{
		length_percentage_: length_percentage
	}
}

pub fn LengthPercentageOrAuto.from_length(length Length) LengthPercentageOrAuto {
	return LengthPercentageOrAuto.from_length_percentage(LengthPercentage.from_length(length))
}

pub fn LengthPercentageOrAuto.from_percentage(percentage Percentage) LengthPercentageOrAuto {
	return LengthPercentageOrAuto.from_length_percentage(LengthPercentage.from_percentage(percentage))
}

pub fn LengthPercentageOrAuto.make_auto() LengthPercentageOrAuto {
	return LengthPercentageOrAuto{}
}

pub fn LengthPercentageOrAuto.from_style_value(style_value &dom.StyleValue) LengthPercentageOrAuto {
	if keyword := computed_interpolation_style_value_keyword(style_value) {
		if keyword == .auto {
			return LengthPercentageOrAuto.make_auto()
		}
	}
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return LengthPercentageOrAuto.from_style_value_logic(parsed_value)
	}
	return LengthPercentageOrAuto.make_auto()
}

pub fn (lpoa LengthPercentageOrAuto) is_auto() bool {
	return lpoa.length_percentage_ == none
}

pub fn (lpoa LengthPercentageOrAuto) is_length() bool {
	if length_percentage := lpoa.length_percentage_ {
		return length_percentage.is_length()
	}
	return false
}

pub fn (lpoa LengthPercentageOrAuto) is_percentage() bool {
	if length_percentage := lpoa.length_percentage_ {
		return length_percentage.is_percentage()
	}
	return false
}

pub fn (lpoa LengthPercentageOrAuto) is_calculated() bool {
	if length_percentage := lpoa.length_percentage_ {
		return length_percentage.is_calculated()
	}
	return false
}

pub fn (lpoa LengthPercentageOrAuto) contains_percentage() bool {
	if length_percentage := lpoa.length_percentage_ {
		return length_percentage.contains_percentage()
	}
	return false
}

pub fn (lpoa LengthPercentageOrAuto) length_percentage() LengthPercentage {
	if length_percentage := lpoa.length_percentage_ {
		return length_percentage
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (lpoa LengthPercentageOrAuto) length() Length {
	return lpoa.length_percentage().length()
}

pub fn (lpoa LengthPercentageOrAuto) percentage() Percentage {
	return lpoa.length_percentage().percentage()
}

pub fn (lpoa LengthPercentageOrAuto) calculated() CalculatedStyleValue {
	return lpoa.length_percentage().calculated()
}

pub fn (lpoa LengthPercentageOrAuto) resolved_or_auto(context LengthResolutionContext, reference_value CSSPixels) LengthOrAuto {
	if lpoa.is_auto() {
		return LengthOrAuto.make_auto()
	}
	return LengthOrAuto.new(lpoa.length_percentage().resolved(context, reference_value))
}

pub fn (lpoa LengthPercentageOrAuto) to_px_or_zero(context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	if lpoa.is_auto() {
		return CSSPixels{}
	}
	return lpoa.length_percentage().to_px(context, reference_value)
}

pub fn (lpoa LengthPercentageOrAuto) serialize(mode SerializationMode) string {
	if lpoa.is_auto() {
		return 'auto'
	}
	return lpoa.length_percentage().serialize(mode)
}

pub fn (lpoa LengthPercentageOrAuto) to_string() string {
	return lpoa.serialize(.normal)
}

pub fn (lpoa LengthPercentageOrAuto) to_string_with_mode(mode SerializationMode) string {
	return lpoa.serialize(mode)
}

pub type TimePercentageValue = CalculatedStyleValue | Percentage | Time

pub struct TimePercentage {
pub mut:
	value_ TimePercentageValue
}

pub fn TimePercentage.from_time(time Time) TimePercentage {
	return TimePercentage{
		value_: time
	}
}

pub fn TimePercentage.from_percentage(percentage Percentage) TimePercentage {
	return TimePercentage{
		value_: percentage
	}
}

pub fn TimePercentage.from_calculated(calculated CalculatedStyleValue) TimePercentage {
	return TimePercentage{
		value_: calculated
	}
}

pub fn (tp TimePercentage) is_time() bool {
	return tp.value_ is Time
}

pub fn (tp TimePercentage) is_percentage() bool {
	return tp.value_ is Percentage
}

pub fn (tp TimePercentage) is_calculated() bool {
	return tp.value_ is CalculatedStyleValue
}

pub fn (tp TimePercentage) contains_percentage() bool {
	value := tp.value_
	return match value {
		Time { false }
		Percentage { true }
		CalculatedStyleValue { value.contains_percentage() }
	}
}

pub fn (tp TimePercentage) time() Time {
	value := tp.value_
	if value is Time {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (tp TimePercentage) percentage() Percentage {
	value := tp.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (tp TimePercentage) calculated() CalculatedStyleValue {
	value := tp.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (tp TimePercentage) resolved(reference_value Time) Time {
	value := tp.value_
	return match value {
		Time {
			value
		}
		Percentage {
			reference_value.percentage_of(value)
		}
		CalculatedStyleValue {
			value.resolve_time(CalculationResolutionContext{
				percentage_basis: reference_value
			}) or { reference_value }
		}
	}
}

pub fn (tp TimePercentage) serialize(mode SerializationMode) string {
	value := tp.value_
	return match value {
		Time { value.serialize(mode) }
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (tp TimePercentage) to_string() string {
	return tp.serialize(.normal)
}

pub fn (tp TimePercentage) to_string_with_mode(mode SerializationMode) string {
	return tp.serialize(mode)
}

pub type NumberPercentageValue = CalculatedStyleValue | Number | Percentage

pub struct NumberPercentage {
pub mut:
	value_ NumberPercentageValue
}

pub fn NumberPercentage.from_number(number Number) NumberPercentage {
	return NumberPercentage{
		value_: number
	}
}

pub fn NumberPercentage.from_percentage(percentage Percentage) NumberPercentage {
	return NumberPercentage{
		value_: percentage
	}
}

pub fn NumberPercentage.from_calculated(calculated CalculatedStyleValue) NumberPercentage {
	return NumberPercentage{
		value_: calculated
	}
}

pub fn (np NumberPercentage) is_number() bool {
	return np.value_ is Number
}

pub fn (np NumberPercentage) is_percentage() bool {
	return np.value_ is Percentage
}

pub fn (np NumberPercentage) is_calculated() bool {
	return np.value_ is CalculatedStyleValue
}

pub fn (np NumberPercentage) contains_percentage() bool {
	value := np.value_
	return match value {
		Number { false }
		Percentage { true }
		CalculatedStyleValue { value.contains_percentage() }
	}
}

pub fn (np NumberPercentage) number() Number {
	value := np.value_
	if value is Number {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (np NumberPercentage) percentage() Percentage {
	value := np.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (np NumberPercentage) calculated() CalculatedStyleValue {
	value := np.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (np NumberPercentage) resolved(reference_value Number) Number {
	value := np.value_
	return match value {
		Number {
			value
		}
		Percentage {
			reference_value.percentage_of(value)
		}
		CalculatedStyleValue {
			resolved := value.resolve_number(CalculationResolutionContext{
				percentage_basis: reference_value
			}) or { return reference_value }
			Number.with_type(.number, resolved)
		}
	}
}

pub fn (np NumberPercentage) serialize(mode SerializationMode) string {
	value := np.value_
	return match value {
		Number { value.serialize(mode) }
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (np NumberPercentage) to_string() string {
	return np.serialize(.normal)
}

pub fn (np NumberPercentage) to_string_with_mode(mode SerializationMode) string {
	return np.serialize(mode)
}

// --- LengthBox ---

pub struct LengthBox {
pub mut:
	top_    LengthPercentageOrAuto
	right_  LengthPercentageOrAuto
	bottom_ LengthPercentageOrAuto
	left_   LengthPercentageOrAuto
}

pub fn LengthBox.new() LengthBox {
	return LengthBox{
		top_:    LengthPercentageOrAuto.make_auto()
		right_:  LengthPercentageOrAuto.make_auto()
		bottom_: LengthPercentageOrAuto.make_auto()
		left_:   LengthPercentageOrAuto.make_auto()
	}
}

pub fn LengthBox.with_values(top LengthPercentageOrAuto, right LengthPercentageOrAuto, bottom LengthPercentageOrAuto, left LengthPercentageOrAuto) LengthBox {
	return LengthBox{
		top_:    top
		right_:  right
		bottom_: bottom
		left_:   left
	}
}

pub fn (b LengthBox) top() LengthPercentageOrAuto {
	return b.top_
}

pub fn (b LengthBox) right() LengthPercentageOrAuto {
	return b.right_
}

pub fn (b LengthBox) bottom() LengthPercentageOrAuto {
	return b.bottom_
}

pub fn (b LengthBox) left() LengthPercentageOrAuto {
	return b.left_
}

// --- EdgeRect ---

pub struct EdgeRect {
pub mut:
	top_edge    LengthOrAuto
	right_edge  LengthOrAuto
	bottom_edge LengthOrAuto
	left_edge   LengthOrAuto
}

// https://www.w3.org/TR/CSS2/visufx.html#value-def-shape
pub fn (e EdgeRect) resolved(context LengthResolutionContext, border_box CSSPixelRect) CSSPixelRect {
	// In CSS 2.1, the only valid <shape> value is: rect(<top>, <right>, <bottom>, <left>) where
	// <top> and <bottom> specify offsets from the top border edge of the box, and <right>, and
	// <left> specify offsets from the left border edge of the box.

	// The value 'auto' means that a given edge of the clipping region will be the same as the edge
	// of the element's generated border box (i.e., 'auto' means the same as '0' for <top> and
	// <left>, the same as the used value of the height plus the sum of vertical padding and border
	// widths for <bottom>, and the same as the used value of the width plus the sum of the
	// horizontal padding and border widths for <right>, such that four 'auto' values result in the
	// clipping region being the same as the element's border box).
	left_offset := if length := e.left_edge.length() {
		length.to_px(context).to_double()
	} else {
		0.0
	}
	top_offset := if length := e.top_edge.length() {
		length.to_px(context).to_double()
	} else {
		0.0
	}
	right_offset := if length := e.right_edge.length() {
		length.to_px(context).to_double()
	} else {
		border_box.width_value()
	}
	bottom_offset := if length := e.bottom_edge.length() {
		length.to_px(context).to_double()
	} else {
		border_box.height_value()
	}
	left := border_box.left_value() + left_offset
	top := border_box.top_value() + top_offset
	right := border_box.left_value() + right_offset
	bottom := border_box.top_value() + bottom_offset
	return CSSPixelRect.new(left, top, right - left, bottom - top)
}

// --- Size ---

pub enum SizeType {
	auto_
	calculated
	length
	percentage
	min_content
	max_content
	fit_content
	none_
}

pub struct Size {
pub mut:
	type_              SizeType
	length_percentage_ ?LengthPercentage
}

pub fn Size.new(type_ SizeType, length_percentage ?LengthPercentage) Size {
	return Size{
		type_:              type_
		length_percentage_: length_percentage
	}
}

pub fn Size.make_auto() Size {
	return Size.new(.auto_, none)
}

pub fn Size.make_px(px CSSPixels) Size {
	return Size.make_length(Length.make_css_px(px))
}

pub fn Size.make_length(length Length) Size {
	return Size.new(.length, LengthPercentage.from_length(length))
}

pub fn Size.make_percentage(percentage Percentage) Size {
	return Size.new(.percentage, LengthPercentage.from_percentage(percentage))
}

pub fn Size.make_calculated(calculated CalculatedStyleValue) Size {
	return Size.new(.calculated, LengthPercentage.from_calculated(calculated))
}

pub fn Size.make_length_percentage(length_percentage LengthPercentage) Size {
	if length_percentage.is_length() {
		return Size.make_length(length_percentage.length())
	}
	if length_percentage.is_percentage() {
		return Size.make_percentage(length_percentage.percentage())
	}
	return Size.make_calculated(length_percentage.calculated())
}

pub fn Size.make_min_content() Size {
	return Size.new(.min_content, none)
}

pub fn Size.make_max_content() Size {
	return Size.new(.max_content, none)
}

pub fn Size.make_fit_content(available_space LengthPercentage) Size {
	return Size.new(.fit_content, available_space)
}

pub fn Size.make_fit_content_without_available_space() Size {
	return Size.new(.fit_content, none)
}

pub fn Size.make_none() Size {
	return Size.new(.none_, none)
}

pub fn (s Size) is_auto() bool {
	return s.type_ == .auto_
}

pub fn (s Size) is_calculated() bool {
	return s.type_ == .calculated
}

pub fn (s Size) is_length() bool {
	return s.type_ == .length
}

pub fn (s Size) is_percentage() bool {
	return s.type_ == .percentage
}

pub fn (s Size) is_min_content() bool {
	return s.type_ == .min_content
}

pub fn (s Size) is_max_content() bool {
	return s.type_ == .max_content
}

pub fn (s Size) is_fit_content() bool {
	return s.type_ == .fit_content
}

pub fn (s Size) is_none() bool {
	return s.type_ == .none_
}

pub fn (s Size) type_() SizeType {
	return s.type_
}

pub fn (s Size) is_intrinsic_sizing_constraint() bool {
	return s.is_min_content() || s.is_max_content() || s.is_fit_content()
}

pub fn (s Size) is_length_percentage() bool {
	return s.is_length() || s.is_percentage() || s.is_calculated()
}

pub fn (s Size) to_px(context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	if length_percentage := s.length_percentage_ {
		return length_percentage.resolved(context, reference_value).to_px(context)
	}
	return CSSPixels{}
}

pub fn (s Size) contains_percentage() bool {
	match s.type_ {
		.auto_, .min_content, .max_content, .none_ {
			return false
		}
		.fit_content {
			if length_percentage := s.length_percentage_ {
				return length_percentage.contains_percentage()
			}
			return false
		}
		else {
			if length_percentage := s.length_percentage_ {
				return length_percentage.contains_percentage()
			}
			return false
		}
	}
}

pub fn (s Size) calculated() CalculatedStyleValue {
	return s.length_percentage().calculated()
}

pub fn (s Size) length() Length {
	return s.length_percentage().length()
}

pub fn (s Size) percentage() Percentage {
	return s.length_percentage().percentage()
}

pub fn (s Size) length_percentage() LengthPercentage {
	if length_percentage := s.length_percentage_ {
		return length_percentage
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (s Size) fit_content_available_space() ?LengthPercentage {
	if !s.is_fit_content() {
		panic('VERIFY_NOT_REACHED')
	}
	return s.length_percentage_
}

pub fn (s Size) serialize(mode SerializationMode) string {
	return match s.type_ {
		.auto_ {
			'auto'
		}
		.calculated, .length, .percentage {
			s.length_percentage().serialize(mode)
		}
		.min_content {
			'min-content'
		}
		.max_content {
			'max-content'
		}
		.fit_content {
			if length_percentage := s.length_percentage_ {
				'fit-content(${length_percentage.serialize(mode)})'
			} else {
				'fit-content'
			}
		}
		.none_ {
			'none'
		}
	}
}

pub fn (s Size) to_string() string {
	return s.serialize(.normal)
}

pub fn (s Size) to_string_with_mode(mode SerializationMode) string {
	return s.serialize(mode)
}

// --- Sizing ---

pub struct SizeWithAspectRatio {
pub mut:
	width        ?CSSPixels
	height       ?CSSPixels
	aspect_ratio ?CSSPixelFraction
}

pub fn (s SizeWithAspectRatio) has_width() bool {
	return s.width != none
}

pub fn (s SizeWithAspectRatio) has_height() bool {
	return s.height != none
}

pub fn (s SizeWithAspectRatio) has_aspect_ratio() bool {
	return s.aspect_ratio != none
}

// https://drafts.csswg.org/css-images/#default-sizing
pub fn run_default_sizing_algorithm(specified_width ?CSSPixels, specified_height ?CSSPixels, natural SizeWithAspectRatio, default_size CSSPixelSize) CSSPixelSize {
	// If the specified size is a definite width and height, the concrete object size is given that width and height.
	if width := specified_width {
		if height := specified_height {
			return CSSPixelSize.new(width, height)
		}
	}
	// If the specified size is only a width or height (but not both) then the concrete object size is given that specified width or height.
	// The other dimension is calculated as follows:
	if specified_width != none || specified_height != none {
		// 1. If the object has a natural aspect ratio,
		// the missing dimension of the concrete object size is calculated using that aspect ratio and the present dimension.
		if aspect_ratio := natural.aspect_ratio {
			if !aspect_ratio.might_be_saturated() {
				if width := specified_width {
					return CSSPixelSize.new(width,
						CSSPixels.nearest_value_for(width.to_double() / aspect_ratio.to_double()))
				}
				if height := specified_height {
					return CSSPixelSize.new(CSSPixels.nearest_value_for(height.to_double() * aspect_ratio.to_double()),
						height)
				}
			}
		}
		// 2. Otherwise, if the missing dimension is present in the object's natural dimensions,
		// the missing dimension is taken from the object's natural dimensions.
		if height := specified_height {
			if width := natural.width {
				return CSSPixelSize.new(width, height)
			}
		}
		if width := specified_width {
			if height := natural.height {
				return CSSPixelSize.new(width, height)
			}
		}
		// 3. Otherwise, the missing dimension of the concrete object size is taken from the default object size.
		if height := specified_height {
			return CSSPixelSize.new(default_size.width(), height)
		}
		if width := specified_width {
			return CSSPixelSize.new(width, default_size.height())
		}
		panic('VERIFY_NOT_REACHED')
	}
	// If the specified size has no constraints:
	// 1. If the object has a natural height or width, its size is resolved as if its natural dimensions were given as the specified size.
	if natural.width != none || natural.height != none {
		return run_default_sizing_algorithm(natural.width, natural.height, natural, default_size)
	}

	// 2. Otherwise, its size is resolved as a contain constraint against the default object size.
	if aspect_ratio := natural.aspect_ratio {
		if !aspect_ratio.might_be_saturated() {
			if default_size.is_empty() {
				return default_size
			}
			default_width := default_size.width().to_double()
			default_height := default_size.height().to_double()
			if aspect_ratio.to_double() >= default_width / default_height {
				return CSSPixelSize.new(default_size.width(),
					CSSPixels.nearest_value_for(default_width / aspect_ratio.to_double()))
			}
			return CSSPixelSize.new(CSSPixels.nearest_value_for(default_height * aspect_ratio.to_double()),
				default_size.height())
		}
	}
	return default_size
}
