module css

import math
import dom

// Translated scaffolding from:
// - LibWeb/CSS/ComputedProperties.h/cpp
// - LibWeb/CSS/Interpolation.h/cpp
// - LibWeb/CSS/StyleComputer.h/cpp
// - LibWeb/CSS/StyleInvalidation.h/cpp
// - LibWeb/CSS/StyleInvalidationData.h/cpp
// - LibWeb/CSS/InvalidationSet.h/cpp
//
// The surrounding V port does not yet expose the full generated CSS property
// table, selector AST, parser, layout tree, rendering tree, style value
// subclasses, font APIs, or animation APIs. This file keeps the C++ structure
// and directly translatable algorithms where possible, and marks those missing
// integration points as explicit stubs.

pub const computed_properties_normal_line_height_scale = 1.15

// --- Small support stubs for untranslated layout/rendering/font/style-value APIs ---

pub struct ComputedColor {
pub mut:
	red_   u8
	green_ u8
	blue_  u8
	alpha_ u8 = 255
}

pub fn ComputedColor.rgb(red u8, green u8, blue u8) ComputedColor {
	return ComputedColor{
		red_:   red
		green_: green
		blue_:  blue
		alpha_: 255
	}
}

pub fn ComputedColor.rgba(red u8, green u8, blue u8, alpha u8) ComputedColor {
	return ComputedColor{
		red_:   red
		green_: green
		blue_:  blue
		alpha_: alpha
	}
}

pub fn ComputedColor.black() ComputedColor {
	return ComputedColor.rgb(0, 0, 0)
}

pub fn ComputedColor.transparent() ComputedColor {
	return ComputedColor.rgba(0, 0, 0, 0)
}

pub fn (c ComputedColor) red() u8 {
	return c.red_
}

pub fn (c ComputedColor) green() u8 {
	return c.green_
}

pub fn (c ComputedColor) blue() u8 {
	return c.blue_
}

pub fn (c ComputedColor) alpha() u8 {
	return c.alpha_
}

pub enum ColorSyntax {
	legacy
	modern
}

pub struct NormalGap {}

pub struct GapValue {
pub mut:
	is_normal         bool             = true
	length_percentage LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
}

pub fn GapValue.normal() GapValue {
	return GapValue{}
}

pub fn GapValue.from_length_percentage(length_percentage LengthPercentage) GapValue {
	return GapValue{
		is_normal:         false
		length_percentage: length_percentage
	}
}

pub enum ColorInterpolation {
	auto_
	srgb
	srgb_linear
	oklab
}

pub enum TextAnchor {
	start
	middle
	end_
}

pub struct BaselineMetric {
pub mut:
	value f64
}

pub enum TextAlign {
	start
	end_
	left
	right
	center
	justify
}

pub enum TextJustify {
	auto_
	none_
	inter_word
}

pub enum TextOverflow {
	clip
	ellipsis
}

pub struct BackgroundLayerData {
pub mut:
	color      ComputedColor
	position_x LengthPercentage       = LengthPercentage.from_percentage(Percentage.new(0))
	position_y LengthPercentage       = LengthPercentage.from_percentage(Percentage.new(0))
	size_x     LengthPercentageOrAuto = LengthPercentageOrAuto.make_auto()
	size_y     LengthPercentageOrAuto = LengthPercentageOrAuto.make_auto()
}

pub enum BackgroundBox {
	border_box
	padding_box
	content_box
	text
}

pub enum CaptionSide {
	top
	bottom
}

pub enum Float {
	none_
	left
	right
}

pub enum Clear {
	none_
	left
	right
	both
}

pub enum ColumnSpan {
	none_
	all
}

pub struct ContentData {
pub mut:
	text string
}

pub struct ContentDataAndQuoteNestingLevel {
pub mut:
	content_data              ContentData
	final_quote_nesting_level u32
}

pub struct CursorData {
pub mut:
	keyword string
}

pub struct TabSize {
pub mut:
	is_length bool
	length    Length
	number    f64
}

pub fn TabSize.number(value f64) TabSize {
	return TabSize{
		number: value
	}
}

pub fn TabSize.length(value Length) TabSize {
	return TabSize{
		is_length: true
		length:    value
	}
}

pub enum WhiteSpaceCollapse {
	collapse
	preserve
	preserve_breaks
	break_spaces
}

pub struct WhiteSpaceTrimData {
pub mut:
	discard_before bool
	discard_after  bool
	discard_inner  bool
}

pub enum WordBreak {
	normal
	break_all
	keep_all
	break_word
}

pub enum LineStyle {
	none_
	hidden
	dotted
	dashed
	solid
	double_
	groove
	ridge
	inset
	outset
}

pub enum OutlineStyle {
	auto_
	none_
	dotted
	dashed
	solid
	double_
	groove
	ridge
	inset
	outset
}

pub enum TextDecorationLine {
	underline
	overline
	line_through
	blink
}

pub enum TextDecorationStyle {
	solid
	double_
	dotted
	dashed
	wavy
}

pub struct TextDecorationThickness {
pub mut:
	is_auto           bool = true
	from_font         bool
	length_percentage LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
}

pub enum TextTransform {
	none_
	capitalize
	uppercase
	lowercase
	full_width
	full_size_kana
}

pub struct TextIndentData {
pub mut:
	length_percentage LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
	each_line         bool
	hanging           bool
}

pub enum TextWrapMode {
	wrap
	nowrap
}

pub struct ListStyleType {
pub mut:
	name string
}

pub enum ListStylePosition {
	outside
	inside
}

pub enum FlexDirection {
	row
	row_reverse
	column
	column_reverse
}

pub enum FlexWrap {
	nowrap
	wrap
	wrap_reverse
}

pub struct FlexBasis {
pub mut:
	size Size = Size.make_auto()
}

pub enum AlignContent {
	normal
	start
	end_
	center
	stretch
	space_between
	space_around
	space_evenly
}

pub enum AlignItems {
	normal
	start
	end_
	center
	stretch
	baseline
}

pub enum AlignSelf {
	auto_
	normal
	start
	end_
	center
	stretch
	baseline
}

pub enum Appearance {
	none_
	auto_
}

pub enum Visibility {
	visible
	hidden
	collapse
}

pub enum ImageRendering {
	auto_
	crisp_edges
	pixelated
}

pub enum JustifyContent {
	normal
	start
	end_
	center
	stretch
	space_between
	space_around
	space_evenly
}

pub enum JustifyItems {
	normal
	start
	end_
	center
	stretch
}

pub enum JustifySelf {
	auto_
	normal
	start
	end_
	center
	stretch
}

pub enum Overflow {
	visible
	hidden
	clip
	scroll
	auto_
}

pub struct ShadowData {
pub mut:
	offset_x        Length
	offset_y        Length
	blur_radius     Length
	spread_distance Length
	color           ComputedColor
	inset           bool
}

pub enum BoxSizing {
	content_box
	border_box
}

pub enum PointerEvents {
	auto_
	none_
}

pub enum VerticalAlign {
	baseline
	sub
	super_
	text_top
	text_bottom
	middle
	top
	bottom
}

pub enum GridAutoFlow {
	row
	column
}

pub enum BorderCollapse {
	separate
	collapse
}

pub enum EmptyCells {
	show
	hide
}

pub enum ObjectFit {
	fill
	contain
	cover
	none_
	scale_down
}

pub struct Position {
pub mut:
	offset_x LengthPercentage = LengthPercentage.from_percentage(Percentage.new(50))
	offset_y LengthPercentage = LengthPercentage.from_percentage(Percentage.new(50))
}

pub enum TableLayout {
	auto_
	fixed
}

pub enum Direction {
	ltr
	rtl
}

pub enum UnicodeBidi {
	normal
	embed
	isolate
	bidi_override
	isolate_override
	plaintext
}

pub enum WritingMode {
	horizontal_tb
	vertical_rl
	vertical_lr
}

pub enum UserSelect {
	auto_
	text
	none_
	all
}

pub enum Isolation {
	auto_
	isolate
}

pub struct TouchActionData {
pub mut:
	pan_x      bool
	pan_y      bool
	pinch_zoom bool
	double_tap bool
	manipulate bool
}

pub fn TouchActionData.auto_() TouchActionData {
	return TouchActionData{
		pan_x:      true
		pan_y:      true
		pinch_zoom: true
		double_tap: true
		manipulate: true
	}
}

pub fn TouchActionData.none() TouchActionData {
	return TouchActionData{}
}

pub struct Containment {
pub mut:
	size    bool
	layout  bool
	style   bool
	paint   bool
	inline_ bool
}

pub enum ContainerType {
	normal
	size
	inline_size
}

pub enum MixBlendMode {
	normal
	multiply
	screen
	overlay
	darken
	lighten
}

pub enum TransformBox {
	view_box
	border_box
	fill_box
	stroke_box
	content_box
}

pub struct TransformOrigin {
pub mut:
	x LengthPercentage = LengthPercentage.from_percentage(Percentage.new(50))
	y LengthPercentage = LengthPercentage.from_percentage(Percentage.new(50))
	z Length           = Length.make_px(0)
}

pub enum TransformStyle {
	flat
	preserve_3d
}

pub struct TransformationData {
pub mut:
	property_id PropertyID
	values      []&dom.StyleValue
}

pub enum MaskType {
	luminance
	alpha
}

pub struct StrokeDasharrayItem {
pub mut:
	is_length_percentage bool
	length_percentage    LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
	number               f64
}

pub enum StrokeLinecap {
	butt
	round
	square
}

pub enum StrokeLinejoin {
	miter
	round
	bevel
}

pub enum FillRule {
	nonzero
	evenodd
}

pub enum ClipRule {
	nonzero
	evenodd
}

pub enum ShapeRendering {
	auto_
	optimize_speed
	crisp_edges
	geometric_precision
}

pub struct PaintOrderList {
pub mut:
	order []string
}

pub struct WillChange {
pub mut:
	is_auto bool = true
	names   []string
}

pub fn WillChange.make_auto() WillChange {
	return WillChange{}
}

pub struct FontData {
pub mut:
	monospace  bool
	bold       bool
	point_size f64
}

pub enum MathStyle {
	normal
	compact
}

pub enum Positioning {
	static_
	relative
	absolute
	sticky
	fixed
}

pub struct QuotesData {
pub mut:
	pairs []string
}

pub struct CounterData {
pub mut:
	name  string
	value int
}

pub struct ScrollbarColorData {
pub mut:
	auto_ bool = true
	thumb ComputedColor
	track ComputedColor
}

pub enum ScrollbarWidth {
	auto_
	thin
	none_
}

pub enum Resize {
	none_
	both
	horizontal
	vertical
	block
	inline_
}

pub enum AnimationDirection {
	normal
	reverse
	alternate
	alternate_reverse
}

pub enum AnimationPlayState {
	running
	paused
}

pub enum AnimationFillMode {
	none_
	forwards
	backwards
	both
}

pub enum AnimationComposition {
	replace
	add
	accumulate
}

pub enum AnimationTimelineKind {
	generic
	scroll
}

@[heap]
pub struct AnimationTimeline {
pub mut:
	kind             AnimationTimelineKind
	anonymous_source ?string
}

pub enum TransitionBehavior {
	normal
	allow_discrete
}

pub struct TransitionProperties {
pub mut:
	properties          []PropertyID
	duration            f64
	timing_function     EasingFunction = EasingFunction.linear()
	delay               f64
	transition_behavior TransitionBehavior
}

pub struct ComputedAnimationProperties {
pub mut:
	duration        f64
	duration_string string
	timing_function EasingFunction = EasingFunction.linear()
	iteration_count f64            = 1
	direction       AnimationDirection
	play_state      AnimationPlayState
	delay           f64
	fill_mode       AnimationFillMode
	composition     AnimationComposition
	name            string
	timeline        ?&AnimationTimeline
}

fn computed_interpolation_empty_style_value() &dom.StyleValue {
	return &dom.StyleValue{}
}

fn style_value_option_changed(old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) bool {
	if old := old_value {
		if new := new_value {
			return old.css_text != new.css_text
		}
		return true
	}
	return new_value != none
}

type ComputedInterpolationPropertyIDs = []PropertyID

type ComputedInterpolationInvalidationProperties = []InvalidationProperty

fn computed_interpolation_longhand_property_ids() ComputedInterpolationPropertyIDs {
	mut ids := []PropertyID{cap: number_of_longhand_properties}
	for index in 0 .. number_of_longhand_properties {
		if property_id := property_id_from_longhand_index(index) {
			ids << property_id
		}
	}
	return ids
}

fn computed_interpolation_is_longhand_property(property_id PropertyID) bool {
	for longhand_id in computed_interpolation_longhand_property_ids() {
		if longhand_id == property_id {
			return true
		}
	}
	return false
}

fn computed_interpolation_verify_longhand_property(property_id PropertyID) {
	if !computed_interpolation_is_longhand_property(property_id) {
		panic('PropertyID ${property_id} is not a translated longhand property')
	}
}

fn computed_interpolation_property_computation_order() ComputedInterpolationPropertyIDs {
	// C++ uses the generated `property_computation_order()` table. The V port
	// currently exposes only the translated longhand range, so canonical enum order
	// is the available computation order.
	return computed_interpolation_longhand_property_ids()
}

fn computed_interpolation_property_initial_value(property_id PropertyID) &dom.StyleValue {
	computed_interpolation_verify_longhand_property(property_id)
	initial_text := match property_id {
		.animation_timeline { 'auto' }
		.color { 'canvastext' }
		.color_scheme { 'normal' }
		.content_visibility { 'visible' }
	}

	return parse_css_value(ParsingParams{}, initial_text, property_id) or {
		return computed_interpolation_empty_style_value()
	}
}

fn computed_interpolation_is_inherited_property(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.color, .color_scheme { true }
		else { false }
	}
}

fn computed_interpolation_property_requires_computation_with_cascaded_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.animation_timeline, .color { true }
		.color_scheme, .content_visibility { false }
	}
}

fn computed_interpolation_property_requires_computation_with_inherited_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return false
}

fn computed_interpolation_property_requires_computation_with_initial_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.color { true }
		.animation_timeline, .color_scheme, .content_visibility { false }
	}
}

fn computed_interpolation_style_value_keyword(value &dom.StyleValue) ?Keyword {
	serialized := value.css_text.trim_space()
	if serialized.len == 0 {
		return none
	}
	return keyword_from_string(to_ascii_lowercase(serialized))
}

fn computed_interpolation_style_value_is_inherit(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .inherit
}

fn computed_interpolation_style_value_is_initial(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .initial
}

fn computed_interpolation_style_value_is_unset(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .unset
}

fn computed_interpolation_style_value_is_revert(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .revert
}

fn computed_interpolation_style_value_is_revert_layer(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .revert_layer
}

fn keyword_to_content_visibility_for_computed_interpolation(keyword Keyword) ?ContentVisibility {
	return match keyword {
		.visible { ContentVisibility.visible }
		.auto { ContentVisibility.auto_ }
		.hidden { ContentVisibility.hidden }
		else { none }
	}
}

fn content_visibility_from_style_value(value &dom.StyleValue) ?ContentVisibility {
	keyword := computed_interpolation_style_value_keyword(value) or { return none }
	return keyword_to_content_visibility_for_computed_interpolation(keyword)
}

fn computed_interpolation_style_value_is_currentcolor(value &dom.StyleValue) bool {
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .currentcolor
}

fn property_affects_computed_font_list(id PropertyID) bool {
	computed_interpolation_verify_longhand_property(id)
	// The translated PropertyID enum does not yet include FontFamily, FontSize,
	// FontStyle, FontWeight, FontWidth, or FontVariationSettings.
	return false
}

// --- ComputedProperties ---

pub enum ComputedPropertyInheritance {
	no
	yes
}

pub enum AnimatedPropertyResultOfTransition {
	no
	yes
}

pub enum WithAnimationsApplied {
	no
	yes
}

@[heap]
pub struct ComputedProperties {
pub mut:
	property_values_                        map[PropertyID]&dom.StyleValue
	property_important_                     map[PropertyID]bool
	property_inherited_                     map[PropertyID]bool
	animated_property_inherited_            map[PropertyID]bool
	animated_property_result_of_transition_ map[PropertyID]bool
	animated_property_values_               map[PropertyID]&dom.StyleValue
	display_before_box_type_transformation_ Display = Display.new()
	cached_computed_font_list_              ?&FontCascadeList
	cached_first_available_computed_font_   ?&FontData
	line_height_                            ?CSSPixels
	attempted_pseudo_class_matches_         map[string]bool
}

pub fn ComputedProperties.new() &ComputedProperties {
	return &ComputedProperties{}
}

pub fn (c &ComputedProperties) for_each_property(callback fn (PropertyID, &dom.StyleValue)) {
	for property_id, value in c.property_values_ {
		callback(property_id, value)
	}
}

pub fn (c &ComputedProperties) animated_property_values() map[PropertyID]&dom.StyleValue {
	return c.animated_property_values_.clone()
}

pub fn (mut c ComputedProperties) reset_non_inherited_animated_properties() {
	mut to_remove := []PropertyID{}
	for property_id, _ in c.animated_property_values_ {
		if !c.is_animated_property_inherited(property_id) {
			to_remove << property_id
		}
	}
	for property_id in to_remove {
		c.animated_property_values_.delete(property_id)
	}
}

pub fn (c &ComputedProperties) is_property_important(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return c.property_important_[property_id] or { false }
}

pub fn (c &ComputedProperties) is_property_inherited(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return c.property_inherited_[property_id] or { false }
}

pub fn (c &ComputedProperties) is_animated_property_inherited(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return c.animated_property_inherited_[property_id] or { false }
}

pub fn (c &ComputedProperties) is_animated_property_result_of_transition(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return c.animated_property_result_of_transition_[property_id] or { false }
}

pub fn (mut c ComputedProperties) set_property_important(property_id PropertyID, important Important) {
	computed_interpolation_verify_longhand_property(property_id)
	if important == .yes {
		c.property_important_[property_id] = true
	} else {
		c.property_important_.delete(property_id)
	}
}

pub fn (mut c ComputedProperties) set_property_inherited(property_id PropertyID, inherited ComputedPropertyInheritance) {
	computed_interpolation_verify_longhand_property(property_id)
	if inherited == .yes {
		c.property_inherited_[property_id] = true
	} else {
		c.property_inherited_.delete(property_id)
	}
}

pub fn (mut c ComputedProperties) set_animated_property_inherited(property_id PropertyID, inherited ComputedPropertyInheritance) {
	computed_interpolation_verify_longhand_property(property_id)
	if inherited == .yes {
		c.animated_property_inherited_[property_id] = true
	} else {
		c.animated_property_inherited_.delete(property_id)
	}
}

pub fn (mut c ComputedProperties) set_animated_property_result_of_transition(property_id PropertyID, result AnimatedPropertyResultOfTransition) {
	computed_interpolation_verify_longhand_property(property_id)
	if result == .yes {
		c.animated_property_result_of_transition_[property_id] = true
	} else {
		c.animated_property_result_of_transition_.delete(property_id)
	}
}

pub fn (mut c ComputedProperties) set_property(property_id PropertyID, value &dom.StyleValue, inherited ComputedPropertyInheritance, important Important) {
	c.set_property_without_modifying_flags(property_id, value)
	c.set_property_important(property_id, important)
	c.set_property_inherited(property_id, inherited)
}

pub fn (mut c ComputedProperties) set_property_without_modifying_flags(property_id PropertyID, value &dom.StyleValue) {
	computed_interpolation_verify_longhand_property(property_id)
	c.property_values_[property_id] = unsafe { value }
	if property_affects_computed_font_list(property_id) {
		c.clear_computed_font_list_cache()
	}
}

pub fn (mut c ComputedProperties) set_animated_property(property_id PropertyID, value &dom.StyleValue, result AnimatedPropertyResultOfTransition, inherited ComputedPropertyInheritance) {
	computed_interpolation_verify_longhand_property(property_id)
	c.animated_property_values_[property_id] = unsafe { value }
	c.set_animated_property_inherited(property_id, inherited)
	c.set_animated_property_result_of_transition(property_id, result)
	if property_affects_computed_font_list(property_id) {
		c.clear_computed_font_list_cache()
	}
}

pub fn (mut c ComputedProperties) remove_animated_property(property_id PropertyID) {
	computed_interpolation_verify_longhand_property(property_id)
	c.animated_property_values_.delete(property_id)
}

pub fn (c &ComputedProperties) property(property_id PropertyID, return_animated_value WithAnimationsApplied) ?&dom.StyleValue {
	computed_interpolation_verify_longhand_property(property_id)
	// Important properties override animated but not transitioned properties.
	if (!c.is_property_important(property_id)
		|| c.is_animated_property_result_of_transition(property_id))
		&& return_animated_value == .yes {
		if animated_value := c.animated_property_values_[property_id] {
			return animated_value
		}
	}

	// By the time C++ calls this method, the property should have been assigned.
	return c.property_values_[property_id] or { return none }
}

pub fn (mut c ComputedProperties) revert_property(property_id PropertyID, style_for_revert &ComputedProperties) {
	computed_interpolation_verify_longhand_property(property_id)
	if value := style_for_revert.property_values_[property_id] {
		c.property_values_[property_id] = unsafe { value }
	} else {
		c.property_values_.delete(property_id)
	}
	c.set_property_important(property_id, if style_for_revert.is_property_important(property_id) {
		Important.yes
	} else {
		Important.no
	})
	c.set_property_inherited(property_id, if style_for_revert.is_property_inherited(property_id) {
		ComputedPropertyInheritance.yes
	} else {
		ComputedPropertyInheritance.no
	})
}

pub fn (c &ComputedProperties) gap_value(property_id PropertyID) GapValue {
	_ = property_id
	// Boundary: StyleValue keyword and LengthPercentage extraction are not wired to dom.StyleValue yet.
	return GapValue.normal()
}

pub fn (c &ComputedProperties) size_value(property_id PropertyID) Size {
	_ = property_id
	// Boundary: requires KeywordStyleValue/FitContentStyleValue/LengthStyleValue plumbing.
	return Size.make_auto()
}

pub fn (c &ComputedProperties) length(property_id PropertyID) Length {
	value := c.property(property_id, .yes) or { return Length.make_px(0) }
	return Length.from_style_value(value, none)
}

pub fn (c &ComputedProperties) length_box(left_id PropertyID, top_id PropertyID, right_id PropertyID, bottom_id PropertyID, default_value LengthPercentageOrAuto) LengthBox {
	_ = left_id
	_ = top_id
	_ = right_id
	_ = bottom_id
	// Boundary: individual side StyleValue conversion is not available yet.
	return LengthBox.with_values(default_value, default_value, default_value, default_value)
}

pub fn (c &ComputedProperties) color_or_fallback(property_id PropertyID, color_resolution_context ColorResolutionContext, fallback ComputedColor) ComputedColor {
	value := c.property(property_id, .yes) or { return fallback }
	parsed_value := parse_css_value_logic(property_id, value.css_text) or { return fallback }
	if !parsed_value.has_color() {
		return fallback
	}
	color := parsed_value.to_color(color_resolution_context) or { return fallback }
	return ComputedColor.rgba(color.red(), color.green(), color.blue(), color.alpha())
}

fn color_scheme_style_value_from_dom_style_value(value &dom.StyleValue) ?ColorSchemeStyleValue {
	parsed_value := parse_css_value_logic(.color_scheme, value.css_text) or { return none }
	if parsed_value is ColorSchemeStyleValue {
		color_scheme := parsed_value
		return color_scheme
	}
	return none
}

fn first_supported_color_scheme(schemes []string) ?PreferredColorScheme {
	for scheme in schemes {
		supported_scheme := preferred_color_scheme_from_string(scheme)
		if supported_scheme != .auto_ {
			return supported_scheme
		}
	}
	return none
}

fn used_color_scheme_from_scheme_list(schemes []string, preferred_scheme PreferredColorScheme) ?PreferredColorScheme {
	if preferred_scheme != .auto_ && preferred_color_scheme_to_string(preferred_scheme) in schemes {
		return preferred_scheme
	}
	return first_supported_color_scheme(schemes)
}

fn used_document_color_scheme(document_supported_schemes ?[]string, preferred_scheme PreferredColorScheme) ?PreferredColorScheme {
	if supported_schemes := document_supported_schemes {
		return used_color_scheme_from_scheme_list(supported_schemes, preferred_scheme)
	}
	return none
}

fn computed_interpolation_default_color_scheme(preferred_scheme PreferredColorScheme, document_supported_schemes ?[]string) PreferredColorScheme {
	if document_scheme := used_document_color_scheme(document_supported_schemes, preferred_scheme) {
		return document_scheme
	}
	return .light
}

pub fn (c &ComputedProperties) color_scheme(preferred_scheme PreferredColorScheme, document_supported_schemes ?[]string) PreferredColorScheme {
	scheme_property := c.property(.color_scheme, .yes) or {
		return computed_interpolation_default_color_scheme(preferred_scheme,
			document_supported_schemes)
	}
	scheme_value := color_scheme_style_value_from_dom_style_value(scheme_property) or {
		return computed_interpolation_default_color_scheme(preferred_scheme,
			document_supported_schemes)
	}

	if element_scheme := used_color_scheme_from_scheme_list(scheme_value.schemes(),
		preferred_scheme)
	{
		return element_scheme
	}

	// FIXME: We don't currently support setting an "overriding preference" for color schemes.
	// `normal` indicates that the element supports the page's supported color schemes, if they are set.
	return computed_interpolation_default_color_scheme(preferred_scheme, document_supported_schemes)
}

pub fn (c &ComputedProperties) assemble_coordinated_value_list(base_property_id PropertyID, property_ids ComputedInterpolationPropertyIDs) map[PropertyID][]&dom.StyleValue {
	_ = base_property_id
	mut result := map[PropertyID][]&dom.StyleValue{}
	for property_id in property_ids {
		if value := c.property(property_id, .yes) {
			result[property_id] = [value]
		}
	}
	return result
}

pub fn (c &ComputedProperties) color_interpolation() ColorInterpolation {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) text_anchor() TextAnchor {
	_ = c
	return .start
}

pub fn (c &ComputedProperties) dominant_baseline() ?BaselineMetric {
	_ = c
	return none
}

pub fn (c &ComputedProperties) text_align() TextAlign {
	_ = c
	return .start
}

pub fn (c &ComputedProperties) text_justify() TextJustify {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) text_overflow() TextOverflow {
	_ = c
	return .clip
}

pub fn (c &ComputedProperties) text_rendering() TextRendering {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) text_underline_offset() CSSPixels {
	_ = c
	return CSSPixels{}
}

pub fn (c &ComputedProperties) text_underline_position() TextUnderlinePosition {
	_ = c
	return TextUnderlinePosition{}
}

pub struct TextUnderlinePosition {}

pub fn (c &ComputedProperties) background_layers() []BackgroundLayerData {
	_ = c
	return []BackgroundLayerData{}
}

pub fn (c &ComputedProperties) background_color_clip() BackgroundBox {
	_ = c
	return .border_box
}

pub fn (c &ComputedProperties) border_spacing_horizontal() Length {
	_ = c
	return Length.make_px(0)
}

pub fn (c &ComputedProperties) border_spacing_vertical() Length {
	_ = c
	return Length.make_px(0)
}

pub fn (c &ComputedProperties) caption_side() CaptionSide {
	_ = c
	return .top
}

pub fn (c &ComputedProperties) clip() Clip {
	_ = c
	return Clip.make_auto()
}

pub fn (c &ComputedProperties) display() Display {
	return c.display_before_box_type_transformation_
}

pub fn (c &ComputedProperties) float_() Float {
	_ = c
	return .none_
}

pub fn (c &ComputedProperties) caret_color(layout_node &dom.LayoutNode) ComputedColor {
	_ = c
	_ = layout_node
	return ComputedColor.black()
}

pub fn (c &ComputedProperties) clear() Clear {
	_ = c
	return .none_
}

pub fn (c &ComputedProperties) column_span() ColumnSpan {
	_ = c
	return .none_
}

pub fn (c &ComputedProperties) content(abstract_element &dom.AbstractElement, initial_quote_nesting_level u32) ContentDataAndQuoteNestingLevel {
	_ = c
	_ = abstract_element
	return ContentDataAndQuoteNestingLevel{
		final_quote_nesting_level: initial_quote_nesting_level
	}
}

pub fn (c &ComputedProperties) content_visibility() ContentVisibility {
	if value := c.property(.content_visibility, .yes) {
		return content_visibility_from_style_value(value) or { ContentVisibility.visible }
	}
	return .visible
}

pub fn (c &ComputedProperties) cursor() []CursorData {
	_ = c
	return []CursorData{}
}

pub fn (c &ComputedProperties) tab_size() TabSize {
	_ = c
	return TabSize.number(8)
}

pub fn (c &ComputedProperties) white_space_collapse() WhiteSpaceCollapse {
	_ = c
	return .collapse
}

pub fn (c &ComputedProperties) white_space_trim() WhiteSpaceTrimData {
	_ = c
	return WhiteSpaceTrimData{}
}

pub fn (c &ComputedProperties) word_break() WordBreak {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) word_spacing() CSSPixels {
	_ = c
	return CSSPixels{}
}

pub fn (c &ComputedProperties) letter_spacing() CSSPixels {
	_ = c
	return CSSPixels{}
}

pub fn (c &ComputedProperties) line_style(property_id PropertyID) LineStyle {
	_ = c
	_ = property_id
	return .none_
}

pub fn (c &ComputedProperties) outline_style() OutlineStyle {
	_ = c
	return .none_
}

pub fn (c &ComputedProperties) text_decoration_line() []TextDecorationLine {
	_ = c
	return []TextDecorationLine{}
}

pub fn (c &ComputedProperties) text_decoration_style() TextDecorationStyle {
	_ = c
	return .solid
}

pub fn (c &ComputedProperties) text_decoration_thickness() TextDecorationThickness {
	_ = c
	return TextDecorationThickness{}
}

pub fn (c &ComputedProperties) text_transform() TextTransform {
	_ = c
	return .none_
}

pub fn (c &ComputedProperties) text_shadow(layout_node &dom.LayoutNode) []ShadowData {
	_ = c
	_ = layout_node
	return []ShadowData{}
}

pub fn (c &ComputedProperties) text_indent() TextIndentData {
	_ = c
	return TextIndentData{}
}

pub fn (c &ComputedProperties) text_wrap_mode() TextWrapMode {
	_ = c
	return .wrap
}

pub fn (c &ComputedProperties) list_style_type(registered_counter_styles map[string]string) ListStyleType {
	_ = c
	_ = registered_counter_styles
	return ListStyleType{
		name: 'disc'
	}
}

pub fn (c &ComputedProperties) list_style_position() ListStylePosition {
	_ = c
	return .outside
}

pub fn (c &ComputedProperties) flex_direction() FlexDirection {
	_ = c
	return .row
}

pub fn (c &ComputedProperties) flex_wrap() FlexWrap {
	_ = c
	return .nowrap
}

pub fn (c &ComputedProperties) flex_basis() FlexBasis {
	_ = c
	return FlexBasis{}
}

pub fn (c &ComputedProperties) flex_grow() f32 {
	_ = c
	return 0
}

pub fn (c &ComputedProperties) flex_shrink() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) order() int {
	_ = c
	return 0
}

pub fn (c &ComputedProperties) accent_color(layout_node &dom.LayoutNode) ?ComputedColor {
	_ = c
	_ = layout_node
	return none
}

pub fn (c &ComputedProperties) align_content() AlignContent {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) align_items() AlignItems {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) align_self() AlignSelf {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) appearance() Appearance {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) backdrop_filter() Filter {
	_ = c
	return Filter.make_none()
}

pub fn (c &ComputedProperties) filter() Filter {
	_ = c
	return Filter.make_none()
}

pub fn (c &ComputedProperties) opacity() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) visibility() Visibility {
	_ = c
	return .visible
}

pub fn (c &ComputedProperties) image_rendering() ImageRendering {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) justify_content() JustifyContent {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) justify_items() JustifyItems {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) justify_self() JustifySelf {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) overflow_x() Overflow {
	_ = c
	return .visible
}

pub fn (c &ComputedProperties) overflow_y() Overflow {
	_ = c
	return .visible
}

pub fn (c &ComputedProperties) box_shadow(layout_node &dom.LayoutNode) []ShadowData {
	_ = c
	_ = layout_node
	return []ShadowData{}
}

pub fn (c &ComputedProperties) box_sizing() BoxSizing {
	_ = c
	return .content_box
}

pub fn (c &ComputedProperties) pointer_events() PointerEvents {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) vertical_align() VerticalAlign {
	_ = c
	return .baseline
}

pub fn (c &ComputedProperties) font_feature_data() FontFeatureData {
	_ = c
	return FontFeatureData{}
}

pub fn (c &ComputedProperties) font_variant_alternates() ?FontVariantAlternates {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_variant_caps() FontVariantCaps {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) font_variant_east_asian() ?FontVariantEastAsian {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_variant_emoji() FontVariantEmoji {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) font_variant_ligatures() ?FontVariantLigatures {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_variant_numeric() ?FontVariantNumeric {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_variant_position() FontVariantPosition {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) font_kerning() FontKerning {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) font_language_override() ?string {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_feature_settings() map[string]u8 {
	_ = c
	return map[string]u8{}
}

pub fn (c &ComputedProperties) font_variation_settings() map[string]f64 {
	_ = c
	return map[string]f64{}
}

pub fn (c &ComputedProperties) grid_auto_columns() GridTrackSizeList {
	_ = c
	return GridTrackSizeList{}
}

pub fn (c &ComputedProperties) grid_auto_rows() GridTrackSizeList {
	_ = c
	return GridTrackSizeList{}
}

pub fn (c &ComputedProperties) grid_template_columns() GridTrackSizeList {
	_ = c
	return GridTrackSizeList{}
}

pub fn (c &ComputedProperties) grid_template_rows() GridTrackSizeList {
	_ = c
	return GridTrackSizeList{}
}

pub fn (c &ComputedProperties) grid_auto_flow() GridAutoFlow {
	_ = c
	return .row
}

pub fn (c &ComputedProperties) grid_column_end() GridTrackPlacement {
	_ = c
	return GridTrackPlacement.make_auto()
}

pub fn (c &ComputedProperties) grid_column_start() GridTrackPlacement {
	_ = c
	return GridTrackPlacement.make_auto()
}

pub fn (c &ComputedProperties) grid_row_end() GridTrackPlacement {
	_ = c
	return GridTrackPlacement.make_auto()
}

pub fn (c &ComputedProperties) grid_row_start() GridTrackPlacement {
	_ = c
	return GridTrackPlacement.make_auto()
}

pub fn (c &ComputedProperties) border_collapse() BorderCollapse {
	_ = c
	return .separate
}

pub fn (c &ComputedProperties) empty_cells() EmptyCells {
	_ = c
	return .show
}

pub fn (c &ComputedProperties) grid_template_areas() GridTemplateAreas {
	_ = c
	return GridTemplateAreas{}
}

pub fn (c &ComputedProperties) object_fit() ObjectFit {
	_ = c
	return .fill
}

pub fn (c &ComputedProperties) object_position() Position {
	_ = c
	return Position{}
}

pub fn (c &ComputedProperties) table_layout() TableLayout {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) direction() Direction {
	_ = c
	return .ltr
}

pub fn (c &ComputedProperties) unicode_bidi() UnicodeBidi {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) writing_mode() WritingMode {
	_ = c
	return .horizontal_tb
}

pub fn (c &ComputedProperties) user_select() UserSelect {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) isolation() Isolation {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) touch_action() TouchActionData {
	_ = c
	return TouchActionData.auto_()
}

pub fn (c &ComputedProperties) contain() Containment {
	_ = c
	return Containment{}
}

pub fn (c &ComputedProperties) container_type() ContainerType {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) mix_blend_mode() MixBlendMode {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) view_transition_name() ?string {
	_ = c
	return none
}

pub fn (c &ComputedProperties) animations(abstract_element &dom.AbstractElement) []ComputedAnimationProperties {
	_ = c
	_ = abstract_element
	// Boundary: requires CSS animation longhands and AnimationTimeline subclasses.
	return []ComputedAnimationProperties{}
}

pub fn (c &ComputedProperties) transitions() []TransitionProperties {
	_ = c
	// Boundary: requires transition-* longhands and property name parsing.
	return []TransitionProperties{}
}

pub fn (c &ComputedProperties) display_before_box_type_transformation() Display {
	return c.display_before_box_type_transformation_
}

pub fn (mut c ComputedProperties) set_display_before_box_type_transformation(value Display) {
	c.display_before_box_type_transformation_ = value
}

pub fn ComputedProperties.transformations_for_style_value(value &dom.StyleValue) []TransformationData {
	_ = value
	// Boundary: TransformationStyleValue/StyleValueList are not translated to dom.StyleValue yet.
	return []TransformationData{}
}

pub fn (c &ComputedProperties) transformations() []TransformationData {
	_ = c
	return []TransformationData{}
}

pub fn (c &ComputedProperties) transform_box() TransformBox {
	_ = c
	return .view_box
}

pub fn (c &ComputedProperties) transform_origin() TransformOrigin {
	_ = c
	return TransformOrigin{}
}

pub fn (c &ComputedProperties) transform_style() TransformStyle {
	_ = c
	return .flat
}

pub fn (c &ComputedProperties) rotate() ?TransformationData {
	_ = c
	return none
}

pub fn (c &ComputedProperties) translate() ?TransformationData {
	_ = c
	return none
}

pub fn (c &ComputedProperties) scale() ?TransformationData {
	_ = c
	return none
}

pub fn (c &ComputedProperties) perspective() ?CSSPixels {
	_ = c
	return none
}

pub fn (c &ComputedProperties) perspective_origin() Position {
	_ = c
	return Position{}
}

pub fn (c &ComputedProperties) mask_type() MaskType {
	_ = c
	return .luminance
}

pub fn (c &ComputedProperties) stop_opacity() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) fill_opacity() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) stroke_dasharray() []StrokeDasharrayItem {
	_ = c
	return []StrokeDasharrayItem{}
}

pub fn (c &ComputedProperties) stroke_linecap() StrokeLinecap {
	_ = c
	return .butt
}

pub fn (c &ComputedProperties) stroke_linejoin() StrokeLinejoin {
	_ = c
	return .miter
}

pub fn (c &ComputedProperties) stroke_miterlimit() f64 {
	_ = c
	return 4
}

pub fn (c &ComputedProperties) stroke_opacity() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) fill_rule() FillRule {
	_ = c
	return .nonzero
}

pub fn (c &ComputedProperties) clip_rule() ClipRule {
	_ = c
	return .nonzero
}

pub fn (c &ComputedProperties) flood_opacity() f32 {
	_ = c
	return 1
}

pub fn (c &ComputedProperties) shape_rendering() ShapeRendering {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) paint_order() PaintOrderList {
	_ = c
	return PaintOrderList{}
}

pub fn (c &ComputedProperties) will_change() WillChange {
	_ = c
	return WillChange.make_auto()
}

pub fn (c &ComputedProperties) cached_computed_font_list() ?&FontCascadeList {
	return c.cached_computed_font_list_
}

pub fn (mut c ComputedProperties) clear_computed_font_list_cache() {
	c.cached_computed_font_list_ = none
	c.cached_first_available_computed_font_ = none
}

pub fn (mut c ComputedProperties) computed_font_list(font_computer &FontComputer) &FontCascadeList {
	_ = font_computer
	if font_list := c.cached_computed_font_list_ {
		return font_list
	}
	font_list := &FontCascadeList{}
	c.cached_computed_font_list_ = font_list
	return font_list
}

pub fn (mut c ComputedProperties) first_available_computed_font(font_computer &FontComputer) &FontData {
	_ = font_computer
	if font := c.cached_first_available_computed_font_ {
		return font
	}
	font := ComputedProperties.font_fallback(false, false, f32(c.font_size().to_double()))
	c.cached_first_available_computed_font_ = font
	return font
}

pub fn (c &ComputedProperties) math_style() MathStyle {
	_ = c
	return .normal
}

pub fn (c &ComputedProperties) math_depth() int {
	_ = c
	return 0
}

pub fn (c &ComputedProperties) line_height() CSSPixels {
	if line_height := c.line_height_ {
		return line_height
	}
	return c.font_size().times_float(computed_properties_normal_line_height_scale)
}

pub fn (c &ComputedProperties) font_size() CSSPixels {
	_ = c
	return CSSPixels.nearest_value_for(16)
}

pub fn (c &ComputedProperties) font_weight() f64 {
	_ = c
	return 400
}

pub fn (c &ComputedProperties) font_width() Percentage {
	_ = c
	return Percentage.new(100)
}

pub fn (c &ComputedProperties) font_slope() int {
	_ = c
	return 0
}

pub fn (c &ComputedProperties) font_optical_sizing() bool {
	_ = c
	return true
}

pub fn (c &ComputedProperties) equals(other &ComputedProperties) bool {
	if c.property_values_.len != other.property_values_.len {
		return false
	}
	for property_id, value in c.property_values_ {
		other_value := other.property_values_[property_id] or { return false }
		if value != other_value {
			return false
		}
	}
	return true
}

pub fn (c &ComputedProperties) position() Positioning {
	_ = c
	return .static_
}

pub fn (c &ComputedProperties) z_index() ?int {
	_ = c
	return none
}

pub fn (c &ComputedProperties) quotes() QuotesData {
	_ = c
	return QuotesData{}
}

pub fn (c &ComputedProperties) counter_data(property_id PropertyID) []CounterData {
	_ = c
	_ = property_id
	return []CounterData{}
}

pub fn (c &ComputedProperties) scrollbar_color(layout_node &dom.LayoutNode) ScrollbarColorData {
	_ = c
	_ = layout_node
	return ScrollbarColorData{}
}

pub fn (c &ComputedProperties) scrollbar_width() ScrollbarWidth {
	_ = c
	return .auto_
}

pub fn (c &ComputedProperties) resize() Resize {
	_ = c
	return .none_
}

pub fn ComputedProperties.font_fallback(monospace bool, bold bool, point_size f32) &FontData {
	return &FontData{
		monospace:  monospace
		bold:       bold
		point_size: f64(point_size)
	}
}

pub fn (c &ComputedProperties) has_attempted_match_against_pseudo_class(pseudo_class CSSPseudoClass) bool {
	return c.attempted_pseudo_class_matches_[pseudo_class_name(pseudo_class)] or { false }
}

pub fn (mut c ComputedProperties) set_attempted_pseudo_class_matches(results map[string]bool) {
	c.attempted_pseudo_class_matches_ = results.clone()
}

// --- Interpolation ---

pub enum AllowDiscrete {
	yes
	no
}

pub enum AnimationType {
	by_computed_value
	none_
	repeatable_list
	custom
	discrete
}

pub enum CompositeOperation {
	replace
	add
	accumulate
}

pub enum InterpolableValueType {
	angle
	length
	percentage
	number
	integer
}

pub struct AcceptedTypeRange {
pub mut:
	min f64
	max f64
}

pub struct InterpolationCalculationContext {
pub mut:
	property             PropertyID
	accepted_type_ranges map[InterpolableValueType]AcceptedTypeRange
}

pub fn InterpolationCalculationContext.for_property(property PropertyID) InterpolationCalculationContext {
	return InterpolationCalculationContext{
		property: property
	}
}

fn interpolation_accepted_type_range(calculation_context InterpolationCalculationContext, value_type InterpolableValueType) ?AcceptedTypeRange {
	if range := calculation_context.accepted_type_ranges[value_type] {
		return range
	}
	return none
}

fn clamp_f64(value f64, min f64, max f64) f64 {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return unsafe { value }
}

pub fn interpolate_raw(from f64, to f64, delta f64, accepted_type_range ?AcceptedTypeRange) f64 {
	result := from + (to - from) * delta
	if range := accepted_type_range {
		return clamp_f64(result, range.min, range.max)
	}
	return result
}

pub fn interpolate_raw_int(from int, to int, delta f64, accepted_type_range ?AcceptedTypeRange) int {
	min := if range := accepted_type_range { range.min } else { f64(-2147483648) }
	max := if range := accepted_type_range { range.max } else { f64(2147483647) }
	result := math.round(f64(from) + (f64(to) - f64(from)) * delta)
	return int(clamp_f64(result, min, max))
}

fn with_keyword_values_resolved_boundary(element &dom.Element, property_id PropertyID, value &dom.StyleValue) &dom.StyleValue {
	_ = element
	if computed_interpolation_style_value_is_initial(value)
		|| computed_interpolation_style_value_is_revert(value)
		|| computed_interpolation_style_value_is_revert_layer(value)
		|| (computed_interpolation_style_value_is_unset(value)
		&& !computed_interpolation_is_inherited_property(property_id)) {
		return computed_interpolation_property_initial_value(property_id)
	}
	// Boundary: inherited keyword resolution requires parent computed style access
	// from DOM::Element, which is not exposed in this V port yet.
	return unsafe { value }
}

pub fn interpolate_discrete(from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	if from == to {
		return unsafe { from }
	}
	if allow_discrete == .no {
		return none
	}
	if delta >= 0.5 {
		return unsafe { to }
	}
	return unsafe { from }
}

fn animation_type_from_longhand_property(property_id PropertyID) AnimationType {
	return match property_id {
		.animation_timeline { .none_ }
		.color { .by_computed_value }
		.content_visibility { .custom }
		.color_scheme { .discrete }
	}
}

pub fn interpolate_property(element &dom.Element, property_id PropertyID, a_from &dom.StyleValue, a_to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	from := with_keyword_values_resolved_boundary(element, property_id, a_from)
	to := with_keyword_values_resolved_boundary(element, property_id, a_to)
	calculation_context := InterpolationCalculationContext.for_property(property_id)

	match animation_type_from_longhand_property(property_id) {
		.by_computed_value {
			return interpolate_value(element, calculation_context, from, to, delta, allow_discrete)
		}
		.none_ {
			return unsafe { to }
		}
		.repeatable_list {
			return interpolate_repeatable_list(element, calculation_context, from, to, delta,
				allow_discrete)
		}
		.custom {
			if property_id == .content_visibility {
				// https://drafts.csswg.org/css-contain/#content-visibility-animation
				// In general, the content-visibility property’s animation type is discrete.
				// However, similar to interpolation of visibility, during interpolation between hidden and any other content-visibility value,
				// p values between 0 and 1 map to the non-hidden value.
				from_content_visibility := content_visibility_from_style_value(from) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				to_content_visibility := content_visibility_from_style_value(to) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				if from_content_visibility == to_content_visibility {
					return unsafe { from }
				}
				from_is_hidden := from_content_visibility == .hidden
				to_is_hidden := to_content_visibility == .hidden
				if from_is_hidden || to_is_hidden {
					non_hidden_value := if from_is_hidden { to } else { from }
					if delta <= 0 {
						return unsafe { from }
					}
					if delta >= 1 {
						return unsafe { to }
					}
					return unsafe { non_hidden_value }
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			return interpolate_discrete(from, to, delta, allow_discrete)
		}
		.discrete {
			return interpolate_discrete(from, to, delta, allow_discrete)
		}
	}
}

// https://drafts.csswg.org/css-transitions/#transitionable
pub fn property_values_are_transitionable(property_id PropertyID, old_value &dom.StyleValue, new_value &dom.StyleValue, element &dom.Element, transition_behavior TransitionBehavior) bool {
	// When comparing the before-change style and after-change style for a given property,
	// the property values are transitionable if they have an animation type that is neither not animatable nor discrete.
	animation_type := animation_type_from_longhand_property(property_id)
	if animation_type == .none_
		|| (transition_behavior != .allow_discrete && animation_type == .discrete) {
		return false
	}

	// Even when a property is transitionable, the two values may not be. The spec uses the example of inset/non-inset shadows.
	if transition_behavior != .allow_discrete
		&& interpolate_property(element, property_id, old_value, new_value, 0.5, .no) == none {
		return false
	}
	return true
}

pub fn interpolate_length_percentage(calculation_context InterpolationCalculationContext, from LengthPercentage, to LengthPercentage, delta f64) ?LengthPercentage {
	if from.is_length() && to.is_length() {
		range := interpolation_accepted_type_range(calculation_context, .length)
		return LengthPercentage.from_length(Length.make_px(interpolate_raw(from.length().raw_value(),
			to.length().raw_value(), delta, range)))
	}
	if from.is_percentage() && to.is_percentage() {
		range := interpolation_accepted_type_range(calculation_context, .percentage)
		return LengthPercentage.from_percentage(Percentage.new(interpolate_raw(from.percentage().value(),
			to.percentage().value(), delta, range)))
	}

	// Boundary: mixed percentages/dimensions require CalculatedStyleValue math-sum creation.
	return none
}

pub fn interpolate_length_percentage_or_auto(calculation_context InterpolationCalculationContext, from LengthPercentageOrAuto, to LengthPercentageOrAuto, delta f64) ?LengthPercentageOrAuto {
	if from.is_auto() && to.is_auto() {
		return LengthPercentageOrAuto.make_auto()
	}
	if from.is_length() && to.is_length() {
		range := interpolation_accepted_type_range(calculation_context, .length)
		return LengthPercentageOrAuto.from_length(Length.make_px(interpolate_raw(from.length().raw_value(),
			to.length().raw_value(), delta, range)))
	}
	if from.is_percentage() && to.is_percentage() {
		range := interpolation_accepted_type_range(calculation_context, .percentage)
		return LengthPercentageOrAuto.from_percentage(Percentage.new(interpolate_raw(from.percentage().value(),
			to.percentage().value(), delta, range)))
	}

	// Boundary: auto/non-auto and mixed calc interpolation need StyleValue conversion.
	return none
}

pub fn interpolate_discrete_style_value(from StyleValue, to StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	if from.equals(to) {
		return from
	}
	if allow_discrete == .no {
		return none
	}
	if delta >= 0.5 {
		return to
	}
	return from
}

pub fn interpolate_css_color(from Color, to Color, delta f64, syntax ColorSyntax) Color {
	// https://drafts.csswg.org/css-color/#interpolation
	// FIXME: Handle all interpolation methods.
	// FIXME: Handle "analogous", "missing", and "powerless" components, somehow.
	// FIXME: Remove duplicated code with Color::mixed_with(Color other, float weight)

	from_alpha := f64(from.alpha()) / 255.0
	to_alpha := f64(to.alpha()) / 255.0
	interpolated_alpha := interpolate_raw(from_alpha, to_alpha, delta, none)
	clamped_alpha := clamp_f64(interpolated_alpha, 0.0, 1.0)
	if clamped_alpha == 0 {
		return Color.rgba(0, 0, 0, 0)
	}

	if syntax == .modern {
		from_oklab := from.to_premultiplied_oklab()
		to_oklab := to.to_premultiplied_oklab()
		return Color.from_oklab(interpolate_raw(from_oklab.l, to_oklab.l, delta, none) / clamped_alpha, interpolate_raw(from_oklab.a,
			to_oklab.a, delta, none) / clamped_alpha, interpolate_raw(from_oklab.b, to_oklab.b,
			delta, none) / clamped_alpha, clamped_alpha)
	}

	premultiply_interpolate_unpremultiply := fn [delta, clamped_alpha, from_alpha, to_alpha] (from_channel u8, to_channel u8) u8 {
		pre_from := f64(from_channel) * from_alpha
		pre_to := f64(to_channel) * to_alpha
		interpolated := interpolate_raw(pre_from, pre_to, delta, none)
		return u8(clamp_f64(math.round(interpolated / clamped_alpha), 0, 255))
	}

	return Color.rgba(premultiply_interpolate_unpremultiply(from.red(), to.red()), premultiply_interpolate_unpremultiply(from.green(),
		to.green()), premultiply_interpolate_unpremultiply(from.blue(), to.blue()),
		u8(math.round(clamped_alpha * 255.0)))
}

fn interpolate_raw_i64(from i64, to i64, delta f64, accepted_type_range ?AcceptedTypeRange) i64 {
	min := if range := accepted_type_range { range.min } else { f64(-9223372036854775808) }
	max := if range := accepted_type_range { range.max } else { f64(9223372036854775807) }
	result := math.round(f64(from) + (f64(to) - f64(from)) * delta)
	return i64(clamp_f64(result, min, max))
}

fn interpolate_style_value_impl(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	if from.type_() != to.type_() || from.is_calculated() || to.is_calculated() {
		// Boundary: mixed percentages/dimensions and CalculatedStyleValue interpolation require CalculationNode math-sum creation.
		return none
	}

	if from.type_() == .color {
		// Boundary: DOM/layout color resolution context is unavailable to this CSS-side helper, so unresolved colors use the default context.
		color_resolution_context := ColorResolutionContext{}
		from_color := from.to_color(color_resolution_context)
		to_color := to.to_color(color_resolution_context)
		mut interpolated_color := Color.black()
		if resolved_from_color := from_color {
			if resolved_to_color := to_color {
				interpolated_color = interpolate_css_color(resolved_from_color, resolved_to_color,
					delta, .modern)
			}
		}
		return StyleValue(ColorStyleValue.create(interpolated_color))
	}

	return match from {
		AngleStyleValue {
			if to is AngleStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .angle)
				interpolated_value := interpolate_raw(from.angle().to_degrees(),
					to.angle().to_degrees(), delta, range)
				StyleValue(AngleStyleValue.create(Angle.make_degrees(interpolated_value)))
			} else {
				none
			}
		}
		BorderRadiusStyleValue {
			if to is BorderRadiusStyleValue {
				interpolated_horizontal_radius := interpolate_style_value_impl(calculation_context,
					from.horizontal_radius_(), to.horizontal_radius_(), delta, allow_discrete) or {
					return none
				}
				interpolated_vertical_radius := interpolate_style_value_impl(calculation_context,
					from.vertical_radius_(), to.vertical_radius_(), delta, allow_discrete) or {
					return none
				}
				StyleValue(BorderRadiusStyleValue.create(interpolated_horizontal_radius,
					interpolated_vertical_radius))
			} else {
				none
			}
		}
		BorderRadiusRectStyleValue {
			if to is BorderRadiusRectStyleValue {
				mut border_radius_rect_context := calculation_context
				border_radius_rect_context.accepted_type_ranges[.length] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				border_radius_rect_context.accepted_type_ranges[.percentage] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				interpolated_top_left := interpolate_style_value_impl(border_radius_rect_context,
					from.top_left(), to.top_left(), delta, allow_discrete) or { return none }
				interpolated_top_right := interpolate_style_value_impl(border_radius_rect_context,
					from.top_right(), to.top_right(), delta, allow_discrete) or { return none }
				interpolated_bottom_right := interpolate_style_value_impl(border_radius_rect_context,
					from.bottom_right(), to.bottom_right(), delta, allow_discrete) or {
					return none
				}
				interpolated_bottom_left := interpolate_style_value_impl(border_radius_rect_context,
					from.bottom_left(), to.bottom_left(), delta, allow_discrete) or { return none }
				StyleValue(BorderRadiusRectStyleValue.create(interpolated_top_left,
					interpolated_top_right, interpolated_bottom_right, interpolated_bottom_left))
			} else {
				none
			}
		}
		IntegerStyleValue {
			if to is IntegerStyleValue {
				// https://drafts.csswg.org/css-values/#combine-integers
				// Interpolation of <integer> is defined as Vresult = round((1 - p) x VA + p x VB);
				// that is, interpolation happens in the real number space as for <number>s, and the result is converted to an <integer> by rounding to the nearest integer.
				range := interpolation_accepted_type_range(calculation_context, .integer)
				StyleValue(IntegerStyleValue.create(interpolate_raw_i64(from.integer(),
					to.integer(), delta, range)))
			} else {
				none
			}
		}
		LengthStyleValue {
			if to is LengthStyleValue {
				from_length := from.length()
				to_length := to.length()
				range := interpolation_accepted_type_range(calculation_context, .length)
				interpolated_value := interpolate_raw(from_length.raw_value(),
					to_length.raw_value(), delta, range)
				StyleValue(LengthStyleValue.create(Length.new(interpolated_value,
					from_length.unit())))
			} else {
				none
			}
		}
		NumberStyleValue {
			if to is NumberStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .number)
				StyleValue(NumberStyleValue.create(interpolate_raw(from.number(), to.number(),
					delta, range)))
			} else {
				none
			}
		}
		PercentageStyleValue {
			if to is PercentageStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .percentage)
				StyleValue(PercentageStyleValue.create(Percentage.new(interpolate_raw(from.percentage().value(),
					to.percentage().value(), delta, range))))
			} else {
				none
			}
		}
		StyleValueList {
			if to is StyleValueList {
				if from.size() != to.size() {
					return none
				}
				mut interpolated_values := []StyleValue{cap: from.size()}
				for i in 0 .. from.size() {
					interpolated := interpolate_style_value(calculation_context, from.values()[i],
						to.values()[i], delta, .no) or { return none }
					interpolated_values << interpolated
				}
				StyleValue(StyleValueList.create(interpolated_values, from.separator(), .yes))
			} else {
				none
			}
		}
		TextIndentStyleValue {
			if to is TextIndentStyleValue {
				if from.each_line() != to.each_line() || from.hanging() != to.hanging() {
					return none
				}
				interpolated_length_percentage := interpolate_style_value(calculation_context,
					from.length_percentage(), to.length_percentage(), delta, allow_discrete) or {
					return none
				}
				StyleValue(TextIndentStyleValue.create(interpolated_length_percentage, if from.hanging() {
					TextIndentHanging.yes
				} else {
					TextIndentHanging.no
				}, if from.each_line() { TextIndentEachLine.yes } else { TextIndentEachLine.no }))
			} else {
				none
			}
		}
		else {
			none
		}
	}
}

pub fn interpolate_style_value(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	if result := interpolate_style_value_impl(calculation_context, from, to, delta, allow_discrete) {
		return result
	}
	return interpolate_discrete_style_value(from, to, delta, allow_discrete)
}

fn interpolation_gcd(a int, b int) int {
	mut x := if a < 0 { -a } else { a }
	mut y := if b < 0 { -b } else { b }
	for y != 0 {
		remainder := x % y
		x = y
		y = remainder
	}
	return x
}

fn interpolation_lcm(a int, b int) int {
	if a == 0 || b == 0 {
		return 0
	}
	return (a / interpolation_gcd(a, b)) * b
}

fn interpolation_make_single_value_list(value StyleValue, size int, separator StyleValueListSeparator) StyleValueList {
	mut values := []StyleValue{cap: size}
	for _ in 0 .. size {
		values << value
	}
	return StyleValueList.create(values, separator, .yes)
}

fn interpolate_repeatable_style_value_lists(calculation_context InterpolationCalculationContext, from_list StyleValueList, to_list StyleValueList, from_original StyleValue, to_original StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	repeated_size := interpolation_lcm(from_list.size(), to_list.size())
	if repeated_size == 0 {
		return none
	}
	mut interpolated_values := []StyleValue{cap: repeated_size}
	for i in 0 .. repeated_size {
		value := interpolate_style_value(calculation_context, from_list.value_at(i, true),
			to_list.value_at(i, true), delta, .no) or {
			return interpolate_discrete_style_value(from_original, to_original, delta,
				allow_discrete)
		}
		interpolated_values << value
	}
	return StyleValue(StyleValueList.create(interpolated_values, from_list.separator(), .yes))
}

pub fn interpolate_repeatable_style_value_list(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	// https://www.w3.org/TR/web-animations/#repeatable-list
	// Same as by computed value except that if the two lists have differing numbers of items, they are first repeated to the least common multiple number of items.
	if from is StyleValueList {
		if to is StyleValueList {
			return interpolate_repeatable_style_value_lists(calculation_context, from, to, from,
				to, delta, allow_discrete)
		}
		to_list := interpolation_make_single_value_list(to, from.size(), from.separator())
		return interpolate_repeatable_style_value_lists(calculation_context, from, to_list, from,
			to, delta, allow_discrete)
	}
	if to is StyleValueList {
		from_list := interpolation_make_single_value_list(from, to.size(), to.separator())
		return interpolate_repeatable_style_value_lists(calculation_context, from_list, to, from,
			to, delta, allow_discrete)
	}
	return interpolate_style_value(calculation_context, from, to, delta, allow_discrete)
}

pub fn interpolate_value(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	_ = element
	from_value := parse_css_value_logic(calculation_context.property, from.css_text) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := parse_css_value_logic(calculation_context.property, to.css_text) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	interpolated := interpolate_style_value(calculation_context, from_value, to_value, delta,
		allow_discrete) or { return none }
	return dom_style_value_from_value_logic(interpolated)
}

pub fn interpolate_repeatable_list(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	_ = element
	from_value := parse_css_value_logic(calculation_context.property, from.css_text) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := parse_css_value_logic(calculation_context.property, to.css_text) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	interpolated := interpolate_repeatable_style_value_list(calculation_context, from_value,
		to_value, delta, allow_discrete) or { return none }
	return dom_style_value_from_value_logic(interpolated)
}

pub fn interpolate_box_shadow(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	_ = element
	_ = calculation_context
	// Boundary: requires ShadowStyleValue, StyleValueList, and color resolution.
	return interpolate_discrete(from, to, delta, allow_discrete)
}

pub fn interpolate_transform(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	_ = element
	_ = calculation_context
	// Boundary: requires TransformationStyleValue, matrix decomposition, and paintable-box APIs.
	return interpolate_discrete(from, to, delta, allow_discrete)
}

pub fn interpolate_color(from ComputedColor, to ComputedColor, delta f64, syntax ColorSyntax) ComputedColor {
	// https://drafts.csswg.org/css-color/#interpolation
	// FIXME: Handle all interpolation methods.
	// FIXME: Handle "analogous", "missing", and "powerless" components, somehow.
	// FIXME: Remove duplicated code with Color::mixed_with(Color other, float weight)

	from_alpha := f64(from.alpha()) / 255.0
	to_alpha := f64(to.alpha()) / 255.0
	interpolated_alpha := interpolate_raw(from_alpha, to_alpha, delta, none)
	clamped_alpha := clamp_f64(interpolated_alpha, 0.0, 1.0)
	if clamped_alpha == 0 {
		return ComputedColor.transparent()
	}

	if syntax == .modern {
		from_oklab :=
			Color.rgba(from.red(), from.green(), from.blue(), from.alpha()).to_premultiplied_oklab()
		to_oklab := Color.rgba(to.red(), to.green(), to.blue(), to.alpha()).to_premultiplied_oklab()
		interpolated := Color.from_oklab(interpolate_raw(from_oklab.l, to_oklab.l, delta, none) / clamped_alpha, interpolate_raw(from_oklab.a,
			to_oklab.a, delta, none) / clamped_alpha, interpolate_raw(from_oklab.b, to_oklab.b,
			delta, none) / clamped_alpha, clamped_alpha)
		return ComputedColor.rgba(interpolated.red(), interpolated.green(), interpolated.blue(),
			interpolated.alpha())
	}

	premultiply_interpolate_unpremultiply := fn [delta, clamped_alpha, from_alpha, to_alpha] (from_channel u8, to_channel u8) u8 {
		pre_from := f64(from_channel) * from_alpha
		pre_to := f64(to_channel) * to_alpha
		interpolated := interpolate_raw(pre_from, pre_to, delta, none)
		return u8(clamp_f64(math.round(interpolated / clamped_alpha), 0, 255))
	}

	return ComputedColor.rgba(premultiply_interpolate_unpremultiply(from.red(), to.red()), premultiply_interpolate_unpremultiply(from.green(),
		to.green()), premultiply_interpolate_unpremultiply(from.blue(), to.blue()),
		u8(math.round(clamped_alpha * 255.0)))
}

fn filter_style_value_zero_length() StyleValue {
	return StyleValue(LengthStyleValue.create(Length.make_px(0)))
}

fn filter_style_value_zero_angle() StyleValue {
	return StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
}

fn filter_style_value_number(value f64) StyleValue {
	return StyleValue(NumberStyleValue.create(value))
}

fn filter_style_value_initial_value_for_accumulation(value FilterStyleValue) ?FilterStyleValue {
	return match value {
		FilterOperationBlur {
			FilterStyleValue(FilterOperationBlur{
				radius: filter_style_value_zero_length()
			})
		}
		FilterOperationDropShadow {
			FilterStyleValue(FilterOperationDropShadow{
				offset_x: filter_style_value_zero_length()
				offset_y: filter_style_value_zero_length()
				radius:   filter_style_value_zero_length()
			})
		}
		FilterOperationHueRotate {
			FilterStyleValue(FilterOperationHueRotate{
				angle: filter_style_value_zero_angle()
			})
		}
		FilterOperationColor {
			default_amount := match value.operation {
				.grayscale, .invert, .sepia { 0.0 }
				.brightness, .contrast, .opacity, .saturate { 1.0 }
			}

			FilterStyleValue(FilterOperationColor{
				operation: value.operation
				amount:    filter_style_value_number(default_amount)
			})
		}
		URL {
			none
		}
	}
}

fn filter_style_value_add_lengths(a StyleValue, b StyleValue) StyleValue {
	a_value :=
		style_values_extra_length_from_style_value(a).absolute_length_to_px_without_rounding()
	b_value :=
		style_values_extra_length_from_style_value(b).absolute_length_to_px_without_rounding()
	return StyleValue(LengthStyleValue.create(Length.make_px(a_value + b_value)))
}

fn filter_style_value_add_optional_lengths(a ?StyleValue, b ?StyleValue) ?StyleValue {
	if a == none && b == none {
		return none
	}
	a_value := if value := a {
		style_values_extra_length_from_style_value(value).absolute_length_to_px_without_rounding()
	} else {
		0.0
	}
	b_value := if value := b {
		style_values_extra_length_from_style_value(value).absolute_length_to_px_without_rounding()
	} else {
		0.0
	}
	return StyleValue(LengthStyleValue.create(Length.make_px(a_value + b_value)))
}

fn filter_style_value_saturating_channel_add(a u8, b u8) u8 {
	sum := int(a) + int(b)
	if sum > 255 {
		return 255
	}
	return u8(sum)
}

fn filter_style_value_accumulate_filter(underlying FilterStyleValue, animated FilterStyleValue) ?FilterStyleValue {
	return match underlying {
		FilterOperationBlur {
			if animated is FilterOperationBlur {
				FilterStyleValue(FilterOperationBlur{
					radius: StyleValue(LengthStyleValue.create(Length.make_px(
						underlying.resolved_radius() + animated.resolved_radius())))
				})
			} else {
				none
			}
		}
		FilterOperationHueRotate {
			if animated is FilterOperationHueRotate {
				FilterStyleValue(FilterOperationHueRotate{
					angle: StyleValue(AngleStyleValue.create(Angle.make_degrees(
						underlying.angle_degrees() + animated.angle_degrees())))
				})
			} else {
				none
			}
		}
		FilterOperationColor {
			if animated is FilterOperationColor {
				if underlying.operation != animated.operation {
					return none
				}
				underlying_amount := underlying.resolved_amount()
				animated_amount := animated.resolved_amount()
				accumulated := match underlying.operation {
					.brightness, .contrast, .opacity, .saturate {
						underlying_amount + animated_amount - 1.0
					}
					.grayscale, .invert, .sepia {
						underlying_amount + animated_amount
					}
				}

				FilterStyleValue(FilterOperationColor{
					operation: underlying.operation
					amount:    filter_style_value_number(accumulated)
				})
			} else {
				none
			}
		}
		FilterOperationDropShadow {
			if animated is FilterOperationDropShadow {
				mut accumulated_color := animated.color
				if underlying_color_value := underlying.color {
					if animated_color_value := animated.color {
						if underlying_color := underlying_color_value.to_color(ColorResolutionContext{}) {
							if animated_color := animated_color_value.to_color(ColorResolutionContext{}) {
								accumulated_color = StyleValue(ColorStyleValue.create(Color.rgba(filter_style_value_saturating_channel_add(underlying_color.red(),
									animated_color.red()), filter_style_value_saturating_channel_add(underlying_color.green(),
									animated_color.green()), filter_style_value_saturating_channel_add(underlying_color.blue(),
									animated_color.blue()), filter_style_value_saturating_channel_add(underlying_color.alpha(),
									animated_color.alpha()))))
							}
						}
					}
				}
				FilterStyleValue(FilterOperationDropShadow{
					offset_x: filter_style_value_add_lengths(underlying.offset_x, animated.offset_x)
					offset_y: filter_style_value_add_lengths(underlying.offset_y, animated.offset_y)
					radius:   filter_style_value_add_optional_lengths(underlying.radius,
						animated.radius)
					color:    accumulated_color
				})
			} else {
				none
			}
		}
		URL {
			none
		}
	}
}

pub fn accumulate_filter_function(underlying_list []FilterStyleValue, animated_list []FilterStyleValue) []FilterStyleValue {
	// https://drafts.csswg.org/filter-effects/#accumulation
	// Accumulation of <filter-value-list>s follows the same matching and extending rules as interpolation, falling
	// back to replace behavior if the lists do not match. Instead of interpolating matching <filter-function> pairs,
	// their arguments are arithmetically added together, except functions whose initial value is 1 use one-based addition.
	max_size := if underlying_list.len > animated_list.len {
		underlying_list.len
	} else {
		animated_list.len
	}
	mut extended_underlying := []FilterStyleValue{cap: max_size}
	mut extended_animated := []FilterStyleValue{cap: max_size}
	for i in 0 .. max_size {
		if i < underlying_list.len {
			extended_underlying << underlying_list[i]
		} else {
			extended_underlying << (filter_style_value_initial_value_for_accumulation(animated_list[i]) or {
				return []FilterStyleValue{}
			})
		}

		if i < animated_list.len {
			extended_animated << animated_list[i]
		} else {
			extended_animated << (filter_style_value_initial_value_for_accumulation(underlying_list[i]) or {
				return []FilterStyleValue{}
			})
		}
	}

	mut result := []FilterStyleValue{cap: max_size}
	for i in 0 .. max_size {
		accumulated := filter_style_value_accumulate_filter(extended_underlying[i],
			extended_animated[i]) or { return []FilterStyleValue{} }
		result << accumulated
	}
	return result
}

pub fn composite_value(property_id PropertyID, underlying_value &dom.StyleValue, animated_value &dom.StyleValue, composite_operation CompositeOperation) ?&dom.StyleValue {
	_ = property_id
	_ = underlying_value
	_ = animated_value
	match composite_operation {
		.replace {
			return none
		}
		.add, .accumulate {
			// Boundary: additive composition requires typed StyleValue subclasses.
			return none
		}
	}
}

// --- Style invalidation after style changes ---

fn property_affects_layout_generated_metadata_boundary(property_id PropertyID) bool {
	return match property_id {
		// C++ handles ContentVisibility as a full layout-tree rebuild before the
		// generated property metadata check. For the currently translated
		// PropertyID set, the missing generated metadata has no remaining
		// layout-affecting properties.
		.animation_timeline, .color, .color_scheme, .content_visibility { false }
	}
}

fn property_affects_stacking_context_generated_metadata_boundary(property_id PropertyID) bool {
	return match property_id {
		// None of the currently translated longhands maps to the C++ generated
		// affects-stacking-context metadata. ContentVisibility is handled by the
		// full-invalidation branch above.
		.animation_timeline, .color, .color_scheme, .content_visibility { false }
	}
}

fn is_stacking_context_creating_value_boundary(property_id PropertyID, value ?&dom.StyleValue) bool {
	_ = property_id
	if value == none {
		return false
	}
	// Boundary: the C++ implementation checks typed DOM StyleValue subclasses
	// (opacity numbers, keywords, lists, transforms, filters). The V DOM
	// StyleValue representation does not expose those queries yet.
	return true
}

fn property_rebuilds_accumulated_visual_contexts(property_id PropertyID) bool {
	return match property_id {
		// The translated PropertyID enum does not yet include transform,
		// perspective, clip, opacity, mix-blend-mode, or filter.
		.animation_timeline, .color, .color_scheme, .content_visibility { false }
	}
}

fn property_requires_full_invalidation(property_id PropertyID) bool {
	return match property_id {
		// C++: Display, Position, Content, ContentVisibility.
		// Only ContentVisibility is currently represented in the V PropertyID enum.
		.content_visibility { true }
		else { false }
	}
}

pub fn compute_property_invalidation(property_id PropertyID, old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}

	property_value_changed := style_value_option_changed(old_value, new_value)
	if !property_value_changed {
		return invalidation
	}

	// NOTE: If the computed CSS display, position, content, or content-visibility property changes, we have to rebuild the entire layout tree.
	//       In the future, we should figure out ways to rebuild a smaller part of the tree.
	if property_requires_full_invalidation(property_id) {
		return required_invalidation_after_style_change_full()
	}

	if property_affects_layout_generated_metadata_boundary(property_id) {
		invalidation.relayout = true
	}

	if property_affects_stacking_context_generated_metadata_boundary(property_id) {
		// OPTIMIZATION: Only rebuild stacking context tree when property crosses from a neutral value
		// (doesn't create stacking context) to a creating value or vice versa.
		old_creates := is_stacking_context_creating_value_boundary(property_id, old_value)
		new_creates := is_stacking_context_creating_value_boundary(property_id, new_value)
		if old_creates != new_creates {
			invalidation.rebuild_stacking_context_tree = true
		}
	}

	if property_rebuilds_accumulated_visual_contexts(property_id) {
		invalidation.rebuild_accumulated_visual_contexts = true
	}

	invalidation.repaint = true
	return invalidation
}

pub fn required_invalidation_after_style_change_full() RequiredInvalidationAfterStyleChange {
	return RequiredInvalidationAfterStyleChange{
		repaint:                       true
		relayout:                      true
		rebuild_layout_tree:           true
		rebuild_stacking_context_tree: true
	}
}

pub fn required_invalidation_after_style_change_is_full(invalidation RequiredInvalidationAfterStyleChange) bool {
	return invalidation.repaint && invalidation.rebuild_stacking_context_tree
		&& invalidation.relayout && invalidation.rebuild_layout_tree
}

pub fn required_invalidation_after_style_change_or(left RequiredInvalidationAfterStyleChange, right RequiredInvalidationAfterStyleChange) RequiredInvalidationAfterStyleChange {
	return RequiredInvalidationAfterStyleChange{
		repaint:                             left.repaint || right.repaint
		relayout:                            left.relayout || right.relayout
		rebuild_layout_tree:                 left.rebuild_layout_tree || right.rebuild_layout_tree
		rebuild_stacking_context_tree:       left.rebuild_stacking_context_tree
			|| right.rebuild_stacking_context_tree
		rebuild_accumulated_visual_contexts: left.rebuild_accumulated_visual_contexts
			|| right.rebuild_accumulated_visual_contexts
	}
}

// --- InvalidationSet ---

pub enum CSSPseudoClass {
	enabled
	disabled
	defined
	placeholder_shown
	checked
	required
	optional
	link
	any_link
	local_link
	default_
	has
	not
	is_
	where
	nth_child
	nth_last_child
	nth_of_type
	nth_last_of_type
	other
}

pub fn pseudo_class_name(pseudo_class CSSPseudoClass) string {
	return match pseudo_class {
		.enabled { 'enabled' }
		.disabled { 'disabled' }
		.defined { 'defined' }
		.placeholder_shown { 'placeholder-shown' }
		.checked { 'checked' }
		.required { 'required' }
		.optional { 'optional' }
		.link { 'link' }
		.any_link { 'any-link' }
		.local_link { 'local-link' }
		.default_ { 'default' }
		.has { 'has' }
		.not { 'not' }
		.is_ { 'is' }
		.where { 'where' }
		.nth_child { 'nth-child' }
		.nth_last_child { 'nth-last-child' }
		.nth_of_type { 'nth-of-type' }
		.nth_last_of_type { 'nth-last-of-type' }
		.other { 'other' }
	}
}

fn pseudo_class_from_name(name string) CSSPseudoClass {
	return match name.to_lower() {
		'enabled' { .enabled }
		'disabled' { .disabled }
		'defined' { .defined }
		'placeholder-shown' { .placeholder_shown }
		'checked' { .checked }
		'required' { .required }
		'optional' { .optional }
		'link' { .link }
		'any-link' { .any_link }
		'local-link' { .local_link }
		'default' { .default_ }
		'has' { .has }
		'not' { .not }
		'is' { .is_ }
		'where' { .where }
		'nth-child' { .nth_child }
		'nth-last-child' { .nth_last_child }
		'nth-of-type' { .nth_of_type }
		'nth-last-of-type' { .nth_last_of_type }
		else { .other }
	}
}

pub enum InvalidationPropertyType {
	invalidate_self
	invalidate_whole_subtree
	class
	id
	tag_name
	attribute
	pseudo_class
}

pub struct InvalidationProperty {
pub mut:
	type_        InvalidationPropertyType
	value        string
	pseudo_class CSSPseudoClass
}

pub fn InvalidationProperty.invalidate_self() InvalidationProperty {
	return InvalidationProperty{
		type_: .invalidate_self
	}
}

pub fn InvalidationProperty.invalidate_whole_subtree() InvalidationProperty {
	return InvalidationProperty{
		type_: .invalidate_whole_subtree
	}
}

pub fn InvalidationProperty.class(name string) InvalidationProperty {
	return InvalidationProperty{
		type_: .class
		value: name
	}
}

pub fn InvalidationProperty.id(name string) InvalidationProperty {
	return InvalidationProperty{
		type_: .id
		value: name
	}
}

pub fn InvalidationProperty.tag_name(name string) InvalidationProperty {
	return InvalidationProperty{
		type_: .tag_name
		value: name
	}
}

pub fn InvalidationProperty.attribute(name string) InvalidationProperty {
	return InvalidationProperty{
		type_: .attribute
		value: name
	}
}

pub fn InvalidationProperty.pseudo_class(pseudo_class CSSPseudoClass) InvalidationProperty {
	return InvalidationProperty{
		type_:        .pseudo_class
		pseudo_class: pseudo_class
	}
}

pub fn (p InvalidationProperty) name() string {
	return p.value
}

pub fn (p InvalidationProperty) key() string {
	return match p.type_ {
		.invalidate_self { '$' }
		.invalidate_whole_subtree { '*' }
		.class { '.${p.value}' }
		.id { '#${p.value}' }
		.tag_name { 'tag:${p.value}' }
		.attribute { '[${p.value}]' }
		.pseudo_class { ':${pseudo_class_name(p.pseudo_class)}' }
	}
}

pub fn (p InvalidationProperty) to_string() string {
	return match p.type_ {
		.invalidate_self { '$' }
		.invalidate_whole_subtree { '*' }
		.class { '.${p.value}' }
		.id { '#${p.value}' }
		.tag_name { p.value }
		.attribute { '[${p.value}]' }
		.pseudo_class { ':${pseudo_class_name(p.pseudo_class)}' }
	}
}

pub struct InvalidationSet {
mut:
	needs_invalidate_self_          bool
	needs_invalidate_whole_subtree_ bool
	properties_                     []InvalidationProperty
}

pub fn (mut s InvalidationSet) include_all_from(other InvalidationSet) {
	s.needs_invalidate_self_ = s.needs_invalidate_self_ || other.needs_invalidate_self_
	s.needs_invalidate_whole_subtree_ = s.needs_invalidate_whole_subtree_
		|| other.needs_invalidate_whole_subtree_
	for property in other.properties_ {
		s.add_property(property)
	}
}

pub fn (s &InvalidationSet) needs_invalidate_self() bool {
	return s.needs_invalidate_self_
}

pub fn (mut s InvalidationSet) set_needs_invalidate_self() {
	s.needs_invalidate_self_ = true
}

pub fn (s &InvalidationSet) needs_invalidate_whole_subtree() bool {
	return s.needs_invalidate_whole_subtree_
}

pub fn (mut s InvalidationSet) set_needs_invalidate_whole_subtree() {
	s.needs_invalidate_whole_subtree_ = true
}

fn (mut s InvalidationSet) add_property(property InvalidationProperty) {
	key := property.key()
	for existing in s.properties_ {
		if existing.key() == key {
			return
		}
	}
	s.properties_ << property
}

pub fn (mut s InvalidationSet) set_needs_invalidate_class(name string) {
	s.add_property(InvalidationProperty.class(name))
}

pub fn (mut s InvalidationSet) set_needs_invalidate_id(name string) {
	s.add_property(InvalidationProperty.id(name))
}

pub fn (mut s InvalidationSet) set_needs_invalidate_tag_name(name string) {
	s.add_property(InvalidationProperty.tag_name(name))
}

pub fn (mut s InvalidationSet) set_needs_invalidate_attribute(name string) {
	s.add_property(InvalidationProperty.attribute(name))
}

pub fn (mut s InvalidationSet) set_needs_invalidate_pseudo_class(pseudo_class CSSPseudoClass) {
	s.add_property(InvalidationProperty.pseudo_class(pseudo_class))
}

pub fn (s &InvalidationSet) is_empty() bool {
	return !s.needs_invalidate_self_ && !s.needs_invalidate_whole_subtree_ && s.properties_.len == 0
}

pub fn (s &InvalidationSet) has_properties() bool {
	return s.properties_.len != 0
}

pub fn (s &InvalidationSet) properties() ComputedInterpolationInvalidationProperties {
	return s.properties_.clone()
}

pub fn (s &InvalidationSet) for_each_property(callback fn (InvalidationProperty) bool) {
	if s.needs_invalidate_self_ {
		if !callback(InvalidationProperty.invalidate_self()) {
			return
		}
	}
	if s.needs_invalidate_whole_subtree_ {
		if !callback(InvalidationProperty.invalidate_whole_subtree()) {
			return
		}
	}
	for property in s.properties_ {
		if !callback(property) {
			return
		}
	}
}

pub fn (s &InvalidationSet) to_string() string {
	mut parts := []string{}
	s.for_each_property(fn [mut parts] (property InvalidationProperty) bool {
		parts << property.to_string()
		return true
	})
	return parts.join(', ')
}

// --- StyleInvalidationData ---

pub enum ExcludePropertiesNestedInNotPseudoClass {
	no
	yes
}

pub enum InsideNthChildPseudoClass {
	no
	yes
}

pub enum SiblingInvalidationReach {
	adjacent
	subsequent
}

pub struct DescendantInvalidationRule {
pub mut:
	match_set InvalidationSet
	match_any bool
	payload   &InvalidationPlan = unsafe { nil }
}

pub struct SiblingInvalidationRule {
pub mut:
	reach     SiblingInvalidationReach
	match_set InvalidationSet
	match_any bool
	payload   &InvalidationPlan = unsafe { nil }
}

@[heap]
pub struct InvalidationPlan {
pub mut:
	invalidate_self          bool
	invalidate_whole_subtree bool
	descendant_rules         []DescendantInvalidationRule
	sibling_rules            []SiblingInvalidationRule
}

pub fn InvalidationPlan.create() &InvalidationPlan {
	return &InvalidationPlan{}
}

pub fn (p &InvalidationPlan) is_empty() bool {
	return !p.invalidate_self && !p.invalidate_whole_subtree && p.descendant_rules.len == 0
		&& p.sibling_rules.len == 0
}

pub fn (mut p InvalidationPlan) include_all_from(other &InvalidationPlan) {
	p.invalidate_self = p.invalidate_self || other.invalidate_self

	if p.invalidate_whole_subtree {
		return
	}

	if other.invalidate_whole_subtree {
		p.invalidate_whole_subtree = true
		p.descendant_rules.clear()
		p.sibling_rules.clear()
		return
	}

	p.descendant_rules << other.descendant_rules
	p.sibling_rules << other.sibling_rules
}

pub struct StyleInvalidationData {
pub mut:
	invalidation_plans                    map[string]&InvalidationPlan
	invalidation_plan_properties          map[string]InvalidationProperty
	ids_used_in_has_selectors             map[string]bool
	class_names_used_in_has_selectors     map[string]bool
	attribute_names_used_in_has_selectors map[string]bool
	tag_names_used_in_has_selectors       map[string]bool
	pseudo_classes_used_in_has_selectors  map[CSSPseudoClass]bool
}

pub fn (s &StyleInvalidationData) plan_for_property(property InvalidationProperty) ?&InvalidationPlan {
	return s.invalidation_plans[property.key()] or { return none }
}

pub fn (mut s StyleInvalidationData) build_invalidation_sets_for_selector(selector Selector) {
	_ = build_invalidation_sets_for_selector_impl(mut s, selector, .no)
}

fn should_register_invalidation_property(property InvalidationProperty) bool {
	return property.type_ != .invalidate_self && property.type_ != .invalidate_whole_subtree
}

fn make_invalidate_self_invalidation() &InvalidationPlan {
	mut invalidation := InvalidationPlan.create()
	invalidation.invalidate_self = true
	return invalidation
}

fn make_invalidate_whole_subtree_invalidation() &InvalidationPlan {
	mut invalidation := InvalidationPlan.create()
	invalidation.invalidate_whole_subtree = true
	return invalidation
}

fn add_invalidation_plan_for_properties(mut style_invalidation_data StyleInvalidationData, invalidation_properties InvalidationSet, plan &InvalidationPlan) {
	invalidation_properties.for_each_property(fn [mut style_invalidation_data, plan] (invalidation_property InvalidationProperty) bool {
		if !should_register_invalidation_property(invalidation_property) {
			return true
		}

		key := invalidation_property.key()
		if key !in style_invalidation_data.invalidation_plans {
			style_invalidation_data.invalidation_plans[key] = InvalidationPlan.create()
			style_invalidation_data.invalidation_plan_properties[key] = invalidation_property
		}
		mut stored_invalidation := style_invalidation_data.invalidation_plans[key] or {
			return true
		}
		stored_invalidation.include_all_from(plan)
		return true
	})
}

pub enum SelectorCombinator {
	none_
	immediate_child
	descendant
	next_sibling
	subsequent_sibling
	column
}

pub enum InvalidationSimpleSelectorType {
	universal
	class
	id
	tag_name
	attribute
	pseudo_class
	other
}

pub struct InvalidationSimpleSelector {
pub mut:
	type_            InvalidationSimpleSelectorType
	name             string
	pseudo_class     CSSPseudoClass
	nested_selectors []Selector
}

pub struct InvalidationSimpleSelectorGroup {
pub mut:
	simple_selectors []InvalidationSimpleSelector
	combinator       SelectorCombinator
}

struct SelectorRighthand {
mut:
	subject_match_set   InvalidationSet
	subject_matches_any bool
	payload             &InvalidationPlan = unsafe { nil }
}

fn css_pseudo_class_from_selector_pseudo_class(pseudo_class PseudoClass) CSSPseudoClass {
	return match pseudo_class {
		.enabled { .enabled }
		.disabled { .disabled }
		.defined { .defined }
		.placeholder_shown { .placeholder_shown }
		.checked { .checked }
		.required { .required }
		.optional { .optional }
		.link { .link }
		.any_link { .any_link }
		.local_link { .local_link }
		.default_ { .default_ }
		.has { .has }
		.not_ { .not }
		.is_ { .is_ }
		.where { .where }
		.nth_child { .nth_child }
		.nth_last_child { .nth_last_child }
		.nth_of_type { .nth_of_type }
		.nth_last_of_type { .nth_last_of_type }
		// Boundary: the local invalidation property enum only contains pseudo
		// classes that StyleInvalidationData.cpp uses for invalidation tracking.
		else { .other }
	}
}

fn selector_combinator_for_invalidation(combinator Combinator) SelectorCombinator {
	return match combinator {
		.no_combinator { .none_ }
		.immediate_child { .immediate_child }
		.descendant { .descendant }
		.next_sibling { .next_sibling }
		.subsequent_sibling { .subsequent_sibling }
		.column { .column }
	}
}

fn simple_selector_for_invalidation(simple_selector SimpleSelector) InvalidationSimpleSelector {
	match simple_selector.type_ {
		.universal {
			return InvalidationSimpleSelector{
				type_: .universal
			}
		}
		.class {
			return InvalidationSimpleSelector{
				type_: .class
				name:  simple_selector.name.name
			}
		}
		.id {
			return InvalidationSimpleSelector{
				type_: .id
				name:  simple_selector.name.name
			}
		}
		.tag_name {
			return InvalidationSimpleSelector{
				type_: .tag_name
				name:  simple_selector.qualified_name.name.lowercase_name
			}
		}
		.attribute {
			return InvalidationSimpleSelector{
				type_: .attribute
				name:  simple_selector.attribute.qualified_name.name.lowercase_name
			}
		}
		.pseudo_class {
			return InvalidationSimpleSelector{
				type_:            .pseudo_class
				name:             selector_pseudo_class_name(simple_selector.pseudo_class.type_)
				pseudo_class:     css_pseudo_class_from_selector_pseudo_class(simple_selector.pseudo_class.type_)
				nested_selectors: simple_selector.pseudo_class.argument_selector_list.selectors.clone()
			}
		}
		// Boundary: pseudo-elements, nesting selectors, and parser-invalid pieces
		// are represented in selectors.v, but this translated invalidation subset
		// has no property kind for them. Match the C++ default branch by ignoring
		// them for property collection while keeping the compound non-empty.
		else {
			return InvalidationSimpleSelector{
				type_: .other
			}
		}
	}
}

fn selector_groups_for_invalidation(selector Selector) []InvalidationSimpleSelectorGroup {
	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return []InvalidationSimpleSelectorGroup{}
	}

	mut groups := []InvalidationSimpleSelectorGroup{}
	for compound_index := compound_selectors.len - 1; compound_index >= 0; compound_index-- {
		compound_selector := compound_selectors[compound_index]
		mut simple_selectors := []InvalidationSimpleSelector{cap: compound_selector.simple_selectors.len}
		for simple_selector in compound_selector.simple_selectors {
			simple_selectors << simple_selector_for_invalidation(simple_selector)
		}
		if simple_selectors.len == 0 {
			continue
		}
		groups << InvalidationSimpleSelectorGroup{
			simple_selectors: simple_selectors
			combinator:       selector_combinator_for_invalidation(compound_selector.combinator)
		}
	}
	return groups
}

fn collect_properties_used_in_has(selector InvalidationSimpleSelector, mut style_invalidation_data StyleInvalidationData, in_has bool) {
	match selector.type_ {
		.id {
			if in_has {
				style_invalidation_data.ids_used_in_has_selectors[selector.name] = true
			}
		}
		.class {
			if in_has {
				style_invalidation_data.class_names_used_in_has_selectors[selector.name] = true
			}
		}
		.attribute {
			if in_has {
				style_invalidation_data.attribute_names_used_in_has_selectors[selector.name] = true
			}
		}
		.tag_name {
			if in_has {
				style_invalidation_data.tag_names_used_in_has_selectors[selector.name] = true
			}
		}
		.pseudo_class {
			if in_has
				&& selector.pseudo_class in [.enabled, .disabled, .defined, .placeholder_shown, .checked, .required, .optional, .link, .any_link, .local_link, .default_] {
				style_invalidation_data.pseudo_classes_used_in_has_selectors[selector.pseudo_class] = true
			}
			for child_selector in selector.nested_selectors {
				for group in selector_groups_for_invalidation(child_selector) {
					for simple_selector in group.simple_selectors {
						collect_properties_used_in_has(simple_selector, mut
							style_invalidation_data, in_has || selector.pseudo_class == .has)
					}
				}
			}
		}
		else {}
	}
}

fn build_invalidation_set_for_simple_selectors(simple_selectors []InvalidationSimpleSelector, exclude_properties_nested_in_not_pseudo_class ExcludePropertiesNestedInNotPseudoClass, mut style_invalidation_data StyleInvalidationData, inside_nth_child_pseudo_class InsideNthChildPseudoClass) InvalidationSet {
	mut invalidation_set := InvalidationSet{}
	for simple_selector in simple_selectors {
		build_invalidation_sets_for_simple_selector(simple_selector, mut invalidation_set,
			exclude_properties_nested_in_not_pseudo_class, mut style_invalidation_data,
			inside_nth_child_pseudo_class)
	}
	return invalidation_set
}

fn simple_selector_group_matches_any(simple_selectors []InvalidationSimpleSelector) bool {
	return simple_selectors.len == 1 && simple_selectors[0].type_ == .universal
}

fn build_invalidation_for_combinator(combinator SelectorCombinator, righthand SelectorRighthand) &InvalidationPlan {
	if righthand.payload.invalidate_whole_subtree
		|| (!righthand.subject_matches_any && righthand.subject_match_set.is_empty()) {
		return make_invalidate_whole_subtree_invalidation()
	}

	mut invalidation := InvalidationPlan.create()
	match combinator {
		.immediate_child, .descendant {
			invalidation.descendant_rules << DescendantInvalidationRule{
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload:   righthand.payload
			}
		}
		.next_sibling {
			invalidation.sibling_rules << SiblingInvalidationRule{
				reach:     .adjacent
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload:   righthand.payload
			}
		}
		.subsequent_sibling {
			invalidation.sibling_rules << SiblingInvalidationRule{
				reach:     .subsequent
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload:   righthand.payload
			}
		}
		else {
			invalidation.invalidate_whole_subtree = true
		}
	}

	return invalidation
}

pub fn build_invalidation_sets_for_simple_selector(selector InvalidationSimpleSelector, mut invalidation_set InvalidationSet, exclude_properties_nested_in_not_pseudo_class ExcludePropertiesNestedInNotPseudoClass, mut style_invalidation_data StyleInvalidationData, inside_nth_child_selector InsideNthChildPseudoClass) {
	match selector.type_ {
		.class {
			invalidation_set.set_needs_invalidate_class(selector.name)
		}
		.id {
			invalidation_set.set_needs_invalidate_id(selector.name)
		}
		.tag_name {
			invalidation_set.set_needs_invalidate_tag_name(selector.name)
		}
		.attribute {
			invalidation_set.set_needs_invalidate_attribute(selector.name)
		}
		.pseudo_class {
			pseudo_class := selector.pseudo_class
			match pseudo_class {
				.enabled, .defined, .disabled, .placeholder_shown, .checked, .has {
					if pseudo_class == .has {
						for nested_selector in selector.nested_selectors {
							add_invalidation_sets_to_cover_scope_leakage_of_relative_selector_in_has_pseudo_class(nested_selector, mut
								style_invalidation_data)
						}
					}
					invalidation_set.set_needs_invalidate_pseudo_class(pseudo_class)
				}
				.link, .any_link, .local_link, .required, .optional {
					invalidation_set.set_needs_invalidate_pseudo_class(pseudo_class)
				}
				else {}
			}

			if pseudo_class == .has {
				return
			}
			if exclude_properties_nested_in_not_pseudo_class == .yes && pseudo_class == .not {
				return
			}
			mut inside_nested := inside_nth_child_selector
			if pseudo_class in [.nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type] {
				inside_nested = .yes
			}
			for nested_selector in selector.nested_selectors {
				rightmost_set := build_invalidation_sets_for_selector_impl(mut style_invalidation_data,
					nested_selector, inside_nested)
				invalidation_set.include_all_from(rightmost_set)

				if selector_contains_pseudo_class(nested_selector, .has) {
					invalidation_set.set_needs_invalidate_pseudo_class(.has)
					if selector_groups_for_invalidation(nested_selector).len > 1 {
						mut has_only := InvalidationSet{}
						has_only.set_needs_invalidate_pseudo_class(.has)
						add_invalidation_plan_for_properties(mut style_invalidation_data, has_only,
							make_invalidate_whole_subtree_invalidation())
					}
				}
			}
		}
		else {}
	}
}

fn selector_contains_pseudo_class(selector Selector, pseudo_class CSSPseudoClass) bool {
	for group in selector_groups_for_invalidation(selector) {
		for simple_selector in group.simple_selectors {
			if simple_selector.type_ == .pseudo_class
				&& simple_selector.pseudo_class == pseudo_class {
				return true
			}
			for nested_selector in simple_selector.nested_selectors {
				if selector_contains_pseudo_class(nested_selector, pseudo_class) {
					return true
				}
			}
		}
	}
	return false
}

fn add_whole_subtree_invalidation_for_non_subject_complex_selector_properties(selector Selector, mut style_invalidation_data StyleInvalidationData) {
	groups := selector_groups_for_invalidation(selector)
	for index, group in groups {
		rightmost := index == 0
		if rightmost {
			continue
		}

		invalidation_set := build_invalidation_set_for_simple_selectors(group.simple_selectors,
			.no, mut style_invalidation_data, .no)
		add_invalidation_plan_for_properties(mut style_invalidation_data, invalidation_set,
			make_invalidate_whole_subtree_invalidation())
	}
}

fn add_invalidation_sets_to_cover_scope_leakage_of_relative_selector_in_has_pseudo_class(selector Selector, mut style_invalidation_data StyleInvalidationData) {
	// Normally, :has() invalidation scope is limited to ancestors and ancestor siblings, however it could require
	// descendants invalidation when :is() with complex selector is used inside :has() relative selector.
	// For example ".a:has(:is(.b .c))" requires invalidation whenever "b" class is added or removed.
	// To cover this case, we add descendant invalidation set that requires whole subtree invalidation for each
	// property used in non-subject part of complex selector.

	groups := selector_groups_for_invalidation(selector)
	for group in groups {
		for simple_selector in group.simple_selectors {
			if simple_selector.type_ != .pseudo_class {
				continue
			}
			if simple_selector.pseudo_class in [.is_, .where, .not] {
				for nested_selector in simple_selector.nested_selectors {
					add_whole_subtree_invalidation_for_non_subject_complex_selector_properties(nested_selector, mut
						style_invalidation_data)
				}
			}
		}
	}
}

fn build_invalidation_sets_for_selector_impl(mut style_invalidation_data StyleInvalidationData, selector Selector, inside_nth_child_pseudo_class InsideNthChildPseudoClass) InvalidationSet {
	groups := selector_groups_for_invalidation(selector)
	if groups.len == 0 {
		return InvalidationSet{}
	}

	mut invalidation_set_for_rightmost_selector := InvalidationSet{}
	mut previous_compound_combinator := SelectorCombinator.none_
	mut selector_righthand := ?SelectorRighthand(none)

	for index, group in groups {
		is_rightmost := index == 0
		for simple_selector in group.simple_selectors {
			in_has := simple_selector.type_ == .pseudo_class && simple_selector.pseudo_class == .has
			collect_properties_used_in_has(simple_selector, mut style_invalidation_data, in_has)
		}

		invalidation_properties := build_invalidation_set_for_simple_selectors(group.simple_selectors,
			.no, mut style_invalidation_data, inside_nth_child_pseudo_class)
		mut subject_match_set := build_invalidation_set_for_simple_selectors(group.simple_selectors,
			.yes, mut style_invalidation_data, inside_nth_child_pseudo_class)
		subject_matches_any := subject_match_set.is_empty()
			&& simple_selector_group_matches_any(group.simple_selectors)

		if is_rightmost {
			mut root_plan := make_invalidate_self_invalidation()
			if inside_nth_child_pseudo_class == .yes {
				// When invalidation property is nested in nth-child selector like
				// p:nth-child(even of #t1, #t2, #t3), we need to make sure all affected siblings are invalidated.
				root_plan.invalidate_whole_subtree = true
			}
			add_invalidation_plan_for_properties(mut style_invalidation_data,
				invalidation_properties, root_plan)
			invalidation_set_for_rightmost_selector = subject_match_set
			selector_righthand = SelectorRighthand{
				subject_match_set:   subject_match_set
				subject_matches_any: subject_matches_any
				payload:             root_plan
			}
		} else {
			righthand := selector_righthand or { break }
			mut plan := build_invalidation_for_combinator(previous_compound_combinator, righthand)
			add_invalidation_plan_for_properties(mut style_invalidation_data,
				invalidation_properties, plan)
			selector_righthand = SelectorRighthand{
				subject_match_set:   subject_match_set
				subject_matches_any: subject_matches_any
				payload:             plan
			}
		}

		previous_compound_combinator = group.combinator
	}

	return invalidation_set_for_rightmost_selector
}

// --- StyleComputer ---

const counting_bloom_filter_key_bits = 14
const counting_bloom_filter_bucket_count = 1 << counting_bloom_filter_key_bits
const counting_bloom_filter_key_mask = counting_bloom_filter_bucket_count - 1

pub struct CountingBloomFilter {
mut:
	buckets []u8
}

pub fn CountingBloomFilter.new() CountingBloomFilter {
	return CountingBloomFilter{
		buckets: []u8{len: counting_bloom_filter_bucket_count}
	}
}

pub fn (mut f CountingBloomFilter) clear() {
	for i in 0 .. f.buckets.len {
		f.buckets[i] = 0
	}
}

fn (f &CountingBloomFilter) hash1(key u32) int {
	return int(key & counting_bloom_filter_key_mask)
}

fn (f &CountingBloomFilter) hash2(key u32) int {
	return int((key >> 16) & counting_bloom_filter_key_mask)
}

pub fn (mut f CountingBloomFilter) increment(key u32) {
	first := f.hash1(key)
	if f.buckets[first] < 255 {
		f.buckets[first]++
	}
	second := f.hash2(key)
	if f.buckets[second] < 255 {
		f.buckets[second]++
	}
}

pub fn (mut f CountingBloomFilter) decrement(key u32) {
	first := f.hash1(key)
	// NOTE: C++ skips decrementing maxed-out overflow counters until the whole filter is cleared.
	if f.buckets[first] < 255 && f.buckets[first] > 0 {
		f.buckets[first]--
	}
	second := f.hash2(key)
	if f.buckets[second] < 255 && f.buckets[second] > 0 {
		f.buckets[second]--
	}
}

pub fn (f &CountingBloomFilter) may_contain(hash u32) bool {
	return f.buckets[f.hash1(hash)] != 0 && f.buckets[f.hash2(hash)] != 0
}

pub struct MatchingRule {
pub mut:
	shadow_root                  ?&dom.ShadowRoot
	rule                         ?&CSSRule
	sheet                        ?&CSSStyleSheet
	default_namespace            ?string
	selector                     Selector
	style_sheet_index            usize
	rule_index                   usize
	specificity                  u32
	cascade_origin               CascadeOrigin
	contains_pseudo_element      bool
	slotted                      bool
	contains_part_pseudo_element bool
}

pub struct LayerMatchingRules {
pub mut:
	qualified_layer_name string
	rules                []MatchingRule
}

pub struct MatchingRuleSet {
pub mut:
	user_agent_rules []MatchingRule
	user_rules       []MatchingRule
	author_rules     []LayerMatchingRules
}

pub enum ComputeStyleMode {
	normal
	create_pseudo_element_style_if_needed
}

pub struct StyleScope {
pub mut:
	qualified_layer_names_in_order                              []string
	selector_insights                                           ?&SelectorInsights
	pseudo_class_rule_cache                                     map[PseudoClass]&RuleCache
	style_invalidation_data                                     ?&StyleInvalidationData
	author_rule_cache                                           ?&RuleCaches
	user_rule_cache                                             ?&RuleCaches
	user_agent_rule_cache                                       ?&RuleCaches
	user_style_sheet                                            ?&CSSStyleSheet
	pending_nodes_for_style_invalidation_due_to_presence_of_has []&dom.Node
	node                                                        ?&dom.Node
}

pub struct LogicalAliasMappingContext {
pub mut:
	writing_mode WritingMode = .horizontal_tb
	direction    Direction   = .ltr
}

pub struct RuleCache {
pub mut:
	rules_by_id                  map[string][]MatchingRule
	rules_by_class               map[string][]MatchingRule
	rules_by_tag_name            map[string][]MatchingRule
	rules_by_attribute_name      map[string][]MatchingRule
	rules_by_pseudo_element      map[PseudoElement][]MatchingRule
	root_rules                   []MatchingRule
	slotted_rules                []MatchingRule
	part_rules                   []MatchingRule
	other_rules                  []MatchingRule
	rules_by_animation_keyframes map[string]bool
}

pub struct StyleComputationContextStub {
pub mut:
	property_id               PropertyID
	length_resolution_context LengthResolutionContext = LengthResolutionContext.default()
	color_scheme              ?PreferredColorScheme
	abstract_element          ?dom.AbstractElement
}

@[heap]
pub struct StyleComputer {
pub mut:
	document_                              &dom.Document     = unsafe { nil }
	default_font_metrics                   LengthFontMetrics = LengthFontMetrics.default()
	root_element_font_metrics              LengthFontMetrics = LengthFontMetrics.default()
	cached_font_computation_context        ?StyleComputationContextStub
	cached_line_height_computation_context ?StyleComputationContextStub
	cached_generic_computation_context     ?StyleComputationContextStub
	viewport_rect_                         CSSPixelRect
	ancestor_filter_                       CountingBloomFilter = CountingBloomFilter.new()
	has_result_cache_                      map[string]bool
}

pub fn StyleComputer.new(document &dom.Document) &StyleComputer {
	return &StyleComputer{
		document_:      unsafe { document }
		viewport_rect_: css_pixel_rect_from_dom_rect(document.viewport_rect())
	}
}

pub fn StyleComputer.for_each_property_expanding_shorthands(property_id PropertyID, value &dom.StyleValue, set_longhand_property fn (PropertyID, &dom.StyleValue)) {
	// Boundary: shorthand expansion requires the generated property metadata table and typed dom.StyleValue.
	set_longhand_property(property_id, value)
}

pub fn StyleComputer.get_non_animated_inherit_value(property_id PropertyID, abstract_element dom.AbstractElement) &dom.StyleValue {
	_ = property_id
	_ = abstract_element
	// Boundary: needs parent ComputedProperties and CSS inheritance metadata.
	return computed_interpolation_empty_style_value()
}

pub struct AnimatedInheritValue {
pub mut:
	value                   &dom.StyleValue = unsafe { nil }
	is_result_of_transition AnimatedPropertyResultOfTransition
}

pub fn StyleComputer.get_animated_inherit_value(property_id PropertyID, abstract_element dom.AbstractElement) ?AnimatedInheritValue {
	_ = property_id
	_ = abstract_element
	// Boundary: needs inherited animated property lookup from parent style.
	return none
}

pub fn StyleComputer.user_agent_style_sheet_source(name string) ?string {
	return user_agent_style_sheet_source(name)
}

pub fn (s &StyleComputer) document() &dom.Document {
	return s.document_
}

pub fn (mut s StyleComputer) reset_ancestor_filter() {
	s.ancestor_filter_.clear()
}

pub fn (mut s StyleComputer) reset_has_result_cache() {
	s.has_result_cache_.clear()
}

fn style_computer_element_hashes(element &dom.Element) []u32 {
	mut hashes := []u32{}
	hashes << selector_string_hash(to_ascii_lowercase(element.local_name()))
	if id := element.id() {
		hashes << selector_string_hash(id)
	}
	if class_attribute := element.get_attribute('class') {
		for class_name in class_attribute.fields() {
			hashes << selector_string_hash(class_name)
		}
	}
	for attribute_name in element.get_attribute_names() {
		hashes << selector_string_hash(to_ascii_lowercase(attribute_name))
	}
	return hashes
}

pub fn (mut s StyleComputer) push_ancestor(element &dom.Element) {
	for hash in style_computer_element_hashes(element) {
		s.ancestor_filter_.increment(hash)
	}
}

pub fn (mut s StyleComputer) pop_ancestor(element &dom.Element) {
	for hash in style_computer_element_hashes(element) {
		s.ancestor_filter_.decrement(hash)
	}
}

pub fn (s &StyleComputer) create_document_style() &ComputedProperties {
	_ = s
	return ComputedProperties.new()
}

pub fn (s &StyleComputer) compute_style(abstract_element dom.AbstractElement) &ComputedProperties {
	_ = s
	_ = abstract_element
	return ComputedProperties.new()
}

pub fn (mut s StyleComputer) compute_style_with_seeded_ancestors(abstract_element dom.AbstractElement) &ComputedProperties {
	mut ancestors := []&dom.Element{}
	mut parent := abstract_element.parent_element()
	for {
		ancestor := parent or { break }
		ancestors << ancestor
		s.push_ancestor(ancestor)
		parent = ancestor.as_node().parent_element()
	}

	computed_properties := s.compute_style(abstract_element)

	for ancestor in ancestors {
		s.pop_ancestor(ancestor)
	}

	return computed_properties
}

pub fn (s &StyleComputer) compute_pseudo_element_style_if_needed(abstract_element dom.AbstractElement) ?&ComputedProperties {
	_ = s
	_ = abstract_element
	return none
}

pub fn (s &StyleComputer) collect_matching_rules(abstract_element dom.AbstractElement, origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string) []MatchingRule {
	return style_computer_collect_matching_rules_without_scope_boundary(s, abstract_element,
		origin, mut attempted_pseudo_class_matches, qualified_layer_name)
}

pub fn (s &StyleComputer) invalidation_plan_for_properties(properties ComputedInterpolationInvalidationProperties, scope &StyleScope) &InvalidationPlan {
	_ = s
	return style_computer_invalidation_plan_for_properties_impl(properties, scope)
}

pub fn (s &StyleComputer) invalidation_property_used_in_has_selector(property InvalidationProperty, scope &StyleScope) bool {
	_ = s
	return style_computer_invalidation_property_used_in_has_selector_impl(property, scope)
}

pub fn StyleComputer.default_user_font_size() CSSPixels {
	return CSSPixels.nearest_value_for(16)
}

pub enum AbsoluteSize {
	xx_small
	x_small
	small
	medium
	large
	x_large
	xx_large
	xxx_large
}

pub enum RelativeSize {
	smaller
	larger
}

pub fn StyleComputer.absolute_size_mapping(size AbsoluteSize, default_font_size CSSPixels) CSSPixels {
	// CSS Fonts maps medium to the user's preferred font size; adjacent keywords scale around it.
	scale := match size {
		.xx_small { 3.0 / 5.0 }
		.x_small { 3.0 / 4.0 }
		.small { 8.0 / 9.0 }
		.medium { 1.0 }
		.large { 6.0 / 5.0 }
		.x_large { 3.0 / 2.0 }
		.xx_large { 2.0 }
		.xxx_large { 3.0 }
	}

	return default_font_size.times_float(scale)
}

pub fn StyleComputer.relative_size_mapping(size RelativeSize, inherited_font_size CSSPixels) CSSPixels {
	return match size {
		.smaller { inherited_font_size.times_float(1.0 / 1.2) }
		.larger { inherited_font_size.times_float(1.2) }
	}
}

pub fn (s &StyleComputer) recascade_font_size_if_needed(abstract_element dom.AbstractElement, mut cascaded_properties CascadedProperties) ?&dom.StyleValue {
	_ = s
	_ = abstract_element
	_ = cascaded_properties
	// Boundary: requires font-size dependency analysis and parser style values.
	return none
}

pub fn (mut s StyleComputer) set_viewport_rect(viewport_rect CSSPixelRect) {
	s.viewport_rect_ = viewport_rect
}

pub fn (s &StyleComputer) collect_animation_into(abstract_element dom.AbstractElement, animation voidptr, mut computed_properties ComputedProperties) {
	_ = s
	_ = abstract_element
	_ = animation
	_ = computed_properties
	// Boundary: requires Animations::KeyframeEffect.
}

pub fn (s &StyleComputer) compute_properties(abstract_element dom.AbstractElement, mut cascaded_properties CascadedProperties) &ComputedProperties {
	mut properties := ComputedProperties.new()
	// Boundary: DOM::AbstractElement exposes only the DOM-side computed style
	// placeholder here, not this port's ComputedProperties map.
	inherited_source_available := false

	for property_id in computed_interpolation_property_computation_order() {
		mut value := ?&dom.StyleValue(none)
		mut requires_computation := false

		if cascaded_style_property := cascaded_properties.style_property(property_id) {
			if cascaded_style_property.important == .yes {
				properties.set_property_important(property_id, .yes)
			}
			value = cascaded_style_property.value
			requires_computation =
				computed_interpolation_property_requires_computation_with_cascaded_value(property_id)
		}

		mut should_inherit := value == none
			&& computed_interpolation_is_inherited_property(property_id)

		// https://www.w3.org/TR/css-cascade-4/#inherit
		// If the cascaded value of a property is the inherit keyword, the property’s specified and computed values are the inherited value.
		if style_value := value {
			should_inherit = should_inherit
				|| computed_interpolation_style_value_is_inherit(style_value)
		}

		// https://www.w3.org/TR/css-cascade-4/#inherit-initial
		// If the cascaded value of a property is the unset keyword, then if it is an inherited property, this is treated as inherit, and if it is not, this is treated as initial.
		if style_value := value {
			should_inherit = should_inherit
				|| (computed_interpolation_style_value_is_unset(style_value)
				&& computed_interpolation_is_inherited_property(property_id))
		}

		// https://www.w3.org/TR/css-color-4/#resolving-other-colors
		// In the color property, the used value of currentcolor is the resolved inherited value.
		if style_value := value {
			should_inherit = should_inherit || (property_id == .color
				&& computed_interpolation_style_value_is_currentcolor(style_value))
		}

		if should_inherit && inherited_source_available {
			// Boundary: DOM::AbstractElement exposes only the DOM-side computed style
			// placeholder here, not this port's ComputedProperties map.
			properties.set_property_inherited(property_id, .yes)
			value = computed_interpolation_property_initial_value(property_id)
			requires_computation =
				computed_interpolation_property_requires_computation_with_inherited_value(property_id)
		}

		if style_value := value {
			if computed_interpolation_style_value_is_initial(style_value)
				|| computed_interpolation_style_value_is_unset(style_value)
				|| (should_inherit && !inherited_source_available) {
				value = computed_interpolation_property_initial_value(property_id)
				requires_computation =
					computed_interpolation_property_requires_computation_with_initial_value(property_id)
			}
		} else {
			value = computed_interpolation_property_initial_value(property_id)
			requires_computation =
				computed_interpolation_property_requires_computation_with_initial_value(property_id)
		}

		style_value := value or { continue }
		computed_value := if requires_computation {
			StyleComputer.compute_value_of_property(property_id, style_value, fn [properties] (id PropertyID) &dom.StyleValue {
				return properties.property(id, .no) or {
					computed_interpolation_property_initial_value(id)
				}
			}, s.get_computation_context_for_property(property_id, properties, abstract_element), 1.0)
		} else {
			style_value
		}
		properties.set_property_without_modifying_flags(property_id, computed_value)
	}

	return properties
}

pub fn (s &StyleComputer) compute_property_values(mut computed_properties ComputedProperties, abstract_element ?dom.AbstractElement) {
	for property_id in computed_interpolation_property_computation_order() {
		specified_value := computed_properties.property(property_id, .no) or {
			computed_interpolation_property_initial_value(property_id)
		}
		computation_context := s.get_computation_context_for_property(property_id,
			computed_properties, abstract_element)
		computed_value := StyleComputer.compute_value_of_property(property_id, specified_value, fn [computed_properties] (id PropertyID) &dom.StyleValue {
			return computed_properties.property(id, .no) or {
				computed_interpolation_property_initial_value(id)
			}
		}, computation_context, 1.0)
		computed_properties.set_property_without_modifying_flags(property_id, computed_value)
	}
}

pub fn (s &StyleComputer) process_animation_definitions(computed_properties &ComputedProperties, mut abstract_element dom.AbstractElement) {
	_ = s
	_ = computed_properties
	_ = abstract_element
	// Boundary: CSSAnimation and Keyframes rule processing is not translated yet.
}

pub fn (s &StyleComputer) should_reject_with_ancestor_filter(selector Selector) bool {
	for hash in selector.ancestor_hashes() {
		if hash == 0 {
			break
		}
		if !s.ancestor_filter_.may_contain(hash) {
			return true
		}
	}
	return false
}

pub fn StyleComputer.compute_value_of_custom_property(abstract_element dom.AbstractElement, custom_property string) &dom.StyleValue {
	_ = abstract_element
	_ = custom_property
	// Boundary: Parser::resolve_unresolved_style_value and custom-property substitution contexts are absent.
	return computed_interpolation_empty_style_value()
}

pub fn StyleComputer.compute_value_of_property(property_id PropertyID, specified_value &dom.StyleValue, get_property_specified_value fn (PropertyID) &dom.StyleValue, computation_context StyleComputationContextStub, device_pixels_per_css_pixel f64) &dom.StyleValue {
	_ = property_id
	_ = get_property_specified_value
	_ = computation_context
	_ = device_pixels_per_css_pixel
	// Boundary: property-specific computed-value conversions live in StyleComputer.cpp and depend on typed StyleValue APIs.
	return unsafe { specified_value }
}

pub fn StyleComputer.compute_animation_name(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_border_or_outline_width(absolutized_value &dom.StyleValue, device_pixels_per_css_pixel f64) &dom.StyleValue {
	_ = device_pixels_per_css_pixel
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_corner_shape(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_feature_tag_value_list(absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	_ = computation_context
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_math_depth(absolutized_value &dom.StyleValue, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	_ = inheritance_parent
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_size(absolutized_value &dom.StyleValue, computed_math_depth int, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	_ = computed_math_depth
	_ = inheritance_parent
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_style(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_weight(absolutized_value &dom.StyleValue, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	_ = inheritance_parent
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_width(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_variation_settings(absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	_ = computation_context
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_line_height(absolutized_value &dom.StyleValue, computed_font_size CSSPixels) &dom.StyleValue {
	_ = computed_font_size
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_opacity(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_position_area(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn (s &StyleComputer) build_matching_rule_set(abstract_element dom.AbstractElement, mut attempted_pseudo_class_matches PseudoClassBitmap, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, scope &StyleScope) MatchingRuleSet {
	return style_computer_build_matching_rule_set_impl(s, abstract_element, mut
		attempted_pseudo_class_matches, did_match_any_pseudo_element_rules, mode, scope)
}

pub fn (s &StyleComputer) compute_logical_alias_mapping_context(abstract_element dom.AbstractElement, mode ComputeStyleMode, matching_rule_set MatchingRuleSet) LogicalAliasMappingContext {
	_ = s
	_ = abstract_element
	_ = mode
	_ = matching_rule_set
	return LogicalAliasMappingContext{}
}

pub fn (s &StyleComputer) compute_style_impl(abstract_element dom.AbstractElement, mode ComputeStyleMode, did_change_custom_properties ?bool, scope &StyleScope) ?&ComputedProperties {
	_ = mode
	_ = did_change_custom_properties
	_ = scope
	return s.compute_style(abstract_element)
}

pub fn (s &StyleComputer) compute_cascaded_values(abstract_element dom.AbstractElement, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, matching_rule_set MatchingRuleSet, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade ComputedInterpolationPropertyIDs) &CascadedProperties {
	mut cascaded_properties := CascadedProperties.new()
	if mode == .create_pseudo_element_style_if_needed {
		if !did_match_any_pseudo_element_rules {
			return cascaded_properties
		}
	}

	// Normal user agent declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element,
		matching_rule_set.user_agent_rules, .user_agent, .no, none, logical_alias_mapping_context,
		properties_to_cascade)

	// Normal user declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_rules,
		.user, .no, none, logical_alias_mapping_context, properties_to_cascade)

	// Author presentational hints are not exposed by the current V DOM surface. SVG
	// presentation attributes are represented as cascaded properties elsewhere, so
	// keep the unresolved-property hook in the same cascade position.
	if abstract_element.pseudo_element() == none {
		if abstract_element.element().is_svg_element() {
			cascaded_properties.resolve_unresolved_properties(&abstract_element)
		}
	}

	// Normal author declarations, ordered by @layer, with un-@layer-ed rules last.
	for layer in matching_rule_set.author_rules {
		s.cascade_declarations(mut cascaded_properties, abstract_element, layer.rules, .author,
			.no, layer.qualified_layer_name, logical_alias_mapping_context, properties_to_cascade)
	}

	// Important author declarations, with un-@layer-ed rules first, followed by each @layer in reverse order.
	for i := matching_rule_set.author_rules.len - 1; i >= 0; i-- {
		layer := matching_rule_set.author_rules[i]
		s.cascade_declarations(mut cascaded_properties, abstract_element, layer.rules, .author,
			.yes, none, logical_alias_mapping_context, properties_to_cascade)
	}

	// Important user declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_rules,
		.user, .yes, none, logical_alias_mapping_context, properties_to_cascade)

	// Important user agent declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element,
		matching_rule_set.user_agent_rules, .user_agent, .yes, none, logical_alias_mapping_context,
		properties_to_cascade)

	return cascaded_properties
}

pub fn (s &StyleComputer) compute_custom_properties(mut computed_properties ComputedProperties, abstract_element dom.AbstractElement) {
	_ = s
	_ = computed_properties
	_ = abstract_element
	// Boundary: custom property substitution and inheritance are partially in properties_data.v only.
}

pub fn (s &StyleComputer) start_needed_transitions(old_style &ComputedProperties, mut new_style ComputedProperties, abstract_element dom.AbstractElement) {
	_ = s
	_ = old_style
	_ = new_style
	_ = abstract_element
	// Boundary: requires Animation timelines, transition generation, and effect stacks.
}

pub fn (s &StyleComputer) resolve_effective_overflow_values(mut computed_properties ComputedProperties) {
	_ = s
	_ = computed_properties
	// Boundary: requires overflow-x/overflow-y longhands.
}

pub fn (s &StyleComputer) transform_box_type_if_needed(mut computed_properties ComputedProperties, abstract_element dom.AbstractElement) {
	_ = s
	_ = computed_properties
	_ = abstract_element
	// Boundary: requires DOM/layout display transformations.
}

pub fn (s &StyleComputer) viewport_rect() CSSPixelRect {
	return s.viewport_rect_
}

pub fn (s &StyleComputer) calculate_root_element_font_metrics(computed_properties &ComputedProperties) LengthFontMetrics {
	_ = s
	_ = computed_properties
	return LengthFontMetrics.default()
}

fn style_computer_css_wide_keyword_from_declaration_text(value string) ?Keyword {
	return keyword_from_string(value.trim_space()) or { none }
}

pub fn (s &StyleComputer) cascade_declarations(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, rules []MatchingRule, origin CascadeOrigin, important Important, layer_name ?string, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade ComputedInterpolationPropertyIDs) {
	_ = s
	_ = logical_alias_mapping_context
	for match_rule in rules {
		rule := match_rule.rule or { continue }
		declaration := rule.style() or { continue }

		mut seen_properties := map[PropertyID]bool{}
		for property in declaration.properties {
			property_id := property_id_from_string(property.name) or { continue }
			if properties_to_cascade.len != 0 && property_id !in properties_to_cascade {
				continue
			}
			property_importance := if property.important { Important.yes } else { Important.no }
			if important != property_importance {
				continue
			}

			mut property_value := property.style_value or {
				parse_css_value(ParsingParams{
					document: abstract_element.document()
				}, property.value, property_id) or { continue }
			}

			if keyword := style_computer_css_wide_keyword_from_declaration_text(property.value) {
				if keyword == .revert {
					cascaded_properties.revert_property(property_id, important, origin)
					continue
				}
				if keyword == .revert_layer {
					cascaded_properties.revert_layer_property(property_id, important, layer_name)
					continue
				}
			}

			StyleComputer.for_each_property_expanding_shorthands(property_id, property_value, fn [mut cascaded_properties, mut seen_properties, important, origin, layer_name, declaration] (longhand_id PropertyID, longhand_value &dom.StyleValue) {
				if seen_properties[longhand_id] {
					return
				}
				seen_properties[longhand_id] = true
				cascaded_properties.set_property(longhand_id, longhand_value, important, origin,
					layer_name, voidptr(declaration))
			})
		}
	}

	if origin == .author && abstract_element.pseudo_element() == none {
		// The DOM-side inline style object is still an opaque CSSStyleProperties_
		// placeholder in this port, so inline declarations cannot be read here yet.
	}
}

pub fn (s &StyleComputer) rule_cache_for_cascade_origin(origin CascadeOrigin, qualified_layer_name ?string, shadow_root ?&dom.ShadowRoot) ?&RuleCache {
	return style_computer_rule_cache_for_cascade_origin_without_scope_boundary(s, origin,
		qualified_layer_name, shadow_root)
}

pub fn (mut s StyleComputer) clear_computation_context_caches() {
	s.cached_font_computation_context = none
	s.cached_line_height_computation_context = none
	s.cached_generic_computation_context = none
}

pub fn (s &StyleComputer) computation_context_cache_is_empty() bool {
	return s.cached_font_computation_context == none
		&& s.cached_line_height_computation_context == none
		&& s.cached_generic_computation_context == none
}

pub fn (s &StyleComputer) get_computation_context_for_property(property_id PropertyID, computed_properties &ComputedProperties, abstract_element ?dom.AbstractElement) StyleComputationContextStub {
	_ = s
	_ = computed_properties
	_ = abstract_element
	return StyleComputationContextStub{
		property_id: property_id
	}
}
