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
	match_parent
	libweb_center
	libweb_inherit_or_center
	libweb_left
	libweb_right
}

pub enum TextJustify {
	auto_
	none_
	inter_word
	inter_character
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

pub enum BackgroundAttachment {
	scroll
	fixed
	local
}

pub enum CaptionSide {
	top
	bottom
}

pub enum Float {
	none_
	left
	right
	inline_start
	inline_end
}

pub enum Clear {
	none_
	left
	right
	both
	inline_start
	inline_end
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
	discard
	preserve
	preserve_breaks
	preserve_spaces
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

pub enum OverflowWrap {
	normal
	anywhere
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
	none_
	underline
	overline
	line_through
	blink
	spelling_error
	grammar_error
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
	math_auto
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

pub enum TextWrapStyle {
	auto_
	balance
	stable
	pretty
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
	flex_start
	end_
	flex_end
	center
	stretch
	space_between
	space_around
	space_evenly
}

pub enum AlignItems {
	normal
	start
	flex_start
	self_start
	end_
	flex_end
	self_end
	center
	stretch
	baseline
	safe
	unsafe_
}

pub enum AlignSelf {
	auto_
	normal
	start
	flex_start
	self_start
	end_
	flex_end
	self_end
	center
	stretch
	baseline
	safe
	unsafe_
}

pub enum Appearance {
	none_
	auto_
	textfield
	menulist_button
}

pub enum Visibility {
	visible
	hidden
	collapse
}

pub enum ImageRendering {
	auto_
	crisp_edges
	high_quality
	pixelated
	smooth
}

pub enum JustifyContent {
	normal
	start
	flex_start
	end_
	flex_end
	center
	stretch
	space_between
	space_around
	space_evenly
	left
	right
}

pub enum JustifyItems {
	normal
	start
	flex_start
	self_start
	end_
	flex_end
	self_end
	center
	stretch
	baseline
	safe
	unsafe_
	legacy
	left
	right
}

pub enum JustifySelf {
	auto_
	normal
	start
	flex_start
	self_start
	end_
	flex_end
	self_end
	center
	stretch
	baseline
	safe
	unsafe_
	left
	right
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
	all
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
	sideways_rl
	sideways_lr
}

pub enum UserSelect {
	auto_
	text
	none_
	all
	contain
}

pub enum Isolation {
	auto_
	isolate
}

pub struct TouchActionData {
pub mut:
	allow_left       bool = true
	allow_right      bool = true
	allow_up         bool = true
	allow_down       bool = true
	allow_pinch_zoom bool = true
	// Other touch interactions which aren't pan or pinch to zoom. E.g.: Double tap to zoom.
	allow_other bool = true
}

pub fn TouchActionData.auto_() TouchActionData {
	return TouchActionData{}
}

pub fn TouchActionData.none_() TouchActionData {
	return TouchActionData{
		allow_left:       false
		allow_right:      false
		allow_up:         false
		allow_down:       false
		allow_pinch_zoom: false
		allow_other:      false
	}
}

pub struct Containment {
pub mut:
	size_containment        bool
	inline_size_containment bool
	layout_containment      bool
	style_containment       bool
	paint_containment       bool
}

pub struct ContainerType {
pub mut:
	is_size_container         bool
	is_inline_size_container  bool
	is_scroll_state_container bool
}

pub enum MixBlendMode {
	normal
	multiply
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	hue
	saturation
	color
	luminosity
	plus_darker
	plus_lighter
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

pub enum MaskComposite {
	add
	subtract
	intersect
	exclude
}

pub enum MaskMode {
	alpha
	luminance
	match_source
}

pub enum MaskOrigin {
	content_box
	padding_box
	border_box
	fill_box
	stroke_box
	view_box
}

pub enum MaskClip {
	content_box
	padding_box
	border_box
	fill_box
	stroke_box
	view_box
	no_clip
}

pub enum BorderImageRepeat {
	stretch
	repeat
	round
	space
}

pub enum TimelineAxis {
	block
	inline_
	x
	y
}

pub enum PositionVisibility {
	always
	anchors_valid
	anchors_visible
	no_overflow
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

pub enum PaintOrder {
	fill
	stroke
	markers
}

pub struct PaintOrderList {
pub mut:
	order []PaintOrder
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

pub enum MathShift {
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

pub enum ScrollBehavior {
	auto_
	smooth
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
		.accent_color {
			'auto'
		}
		.anchor_name, .anchor_scope {
			'none'
		}
		.animation_composition {
			'replace'
		}
		.animation_delay {
			'0s'
		}
		.animation_direction {
			'normal'
		}
		.animation_duration {
			'0s'
		}
		.animation_fill_mode {
			'none'
		}
		.animation_iteration_count {
			'1'
		}
		.animation_name {
			'none'
		}
		.animation_play_state {
			'running'
		}
		.animation_timeline {
			'auto'
		}
		.animation_timing_function {
			'ease'
		}
		.aspect_ratio {
			'auto'
		}
		.background_color {
			'transparent'
		}
		.background_attachment {
			'scroll'
		}
		.background_blend_mode {
			'normal'
		}
		.background_clip {
			'border-box'
		}
		.background_image {
			'none'
		}
		.background_origin {
			'padding-box'
		}
		.background_position_x, .background_position_y {
			'0%'
		}
		.background_repeat {
			'repeat'
		}
		.background_size {
			'auto'
		}
		.block_size, .height, .inline_size, .min_height, .min_width, .width {
			'auto'
		}
		.max_block_size, .max_height, .max_inline_size, .max_width {
			'none'
		}
		.min_block_size, .min_inline_size {
			'0'
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
		.left, .right, .top {
			'auto'
		}
		.border_block_end_color, .border_block_start_color, .border_bottom_color,
		.border_inline_end_color, .border_inline_start_color, .border_left_color,
		.border_right_color, .border_top_color {
			'currentcolor'
		}
		.border_block_end_style, .border_block_start_style, .border_bottom_style,
		.border_inline_end_style, .border_inline_start_style, .border_left_style,
		.border_right_style, .border_top_style {
			'none'
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width {
			'medium'
		}
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius,
		.border_end_start_radius, .border_start_end_radius, .border_start_start_radius,
		.border_top_left_radius, .border_top_right_radius {
			'0'
		}
		.border_collapse {
			'separate'
		}
		.border_image_outset {
			'0'
		}
		.border_image_repeat {
			'stretch'
		}
		.border_image_slice {
			'100%'
		}
		.border_image_source {
			'none'
		}
		.border_image_width {
			'1'
		}
		.border_spacing {
			'0'
		}
		.box_sizing {
			'content-box'
		}
		.caption_side {
			'top'
		}
		.caret_color {
			'auto'
		}
		.clip_rule {
			'nonzero'
		}
		.color_interpolation {
			'srgb'
		}
		.clear {
			'none'
		}
		.color {
			'canvastext'
		}
		.color_scheme {
			'normal'
		}
		.content_visibility {
			'visible'
		}
		.contain {
			'none'
		}
		.container_type {
			'normal'
		}
		.direction {
			'ltr'
		}
		.empty_cells {
			'show'
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			'round'
		}
		.fill_opacity, .flood_opacity {
			'1'
		}
		.fill_rule {
			'nonzero'
		}
		.flood_color {
			'black'
		}
		.float_ {
			'none'
		}
		.font_feature_settings {
			'normal'
		}
		.font_style {
			'normal'
		}
		.font_variation_settings {
			'normal'
		}
		.font_weight {
			'normal'
		}
		.font_width {
			'normal'
		}
		.font_kerning {
			'auto'
		}
		.font_language_override {
			'normal'
		}
		.font_optical_sizing {
			'auto'
		}
		.font_variant_caps, .font_variant_emoji, .font_variant_position {
			'normal'
		}
		.flex_grow {
			'0'
		}
		.flex_shrink {
			'1'
		}
		.flex_direction {
			'row'
		}
		.flex_wrap {
			'nowrap'
		}
		.align_content, .align_items, .justify_content {
			'normal'
		}
		.align_self, .justify_self {
			'auto'
		}
		.justify_items {
			'legacy'
		}
		.appearance, .column_span {
			'none'
		}
		.column_count, .column_width, .column_height {
			'auto'
		}
		.column_gap, .row_gap {
			'normal'
		}
		.image_rendering {
			'auto'
		}
		.isolation {
			'auto'
		}
		.letter_spacing {
			'normal'
		}
		.line_height {
			'normal'
		}
		.list_style_image, .mask_image {
			'none'
		}
		.list_style_position {
			'outside'
		}
		.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end,
		.margin_inline_start, .margin_left, .margin_right, .margin_top, .padding_block_end,
		.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
		.padding_left, .padding_right, .padding_top {
			'0'
		}
		.mask_clip {
			'border-box'
		}
		.mask_type {
			'luminance'
		}
		.mask_composite {
			'add'
		}
		.mask_mode {
			'match-source'
		}
		.mask_origin {
			'border-box'
		}
		.mask_position {
			'0% 0%'
		}
		.mask_repeat {
			'repeat'
		}
		.mask_size {
			'auto'
		}
		.math_depth {
			'0'
		}
		.math_shift {
			'normal'
		}
		.math_style {
			'normal'
		}
		.mix_blend_mode {
			'normal'
		}
		.object_fit {
			'fill'
		}
		.object_position {
			'50% 50%'
		}
		.opacity {
			'1'
		}
		.order {
			'0'
		}
		.orphans {
			'2'
		}
		.widows {
			'2'
		}
		.outline_color {
			'currentcolor'
		}
		.outline_offset {
			'0'
		}
		.outline_style {
			'none'
		}
		.outline_width {
			'medium'
		}
		.overflow_block, .overflow_inline, .overflow_x, .overflow_y {
			'visible'
		}
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top {
			'0px'
		}
		.overflow_wrap {
			'normal'
		}
		.perspective {
			'none'
		}
		.perspective_origin {
			'50% 50%'
		}
		.pointer_events {
			'auto'
		}
		.paint_order {
			'normal'
		}
		.position {
			'static'
		}
		.position_anchor {
			'auto'
		}
		.position_area, .position_try_fallbacks {
			'none'
		}
		.position_try_order {
			'normal'
		}
		.position_visibility {
			'anchors-visible'
		}
		.shape_margin {
			'0'
		}
		.shape_image_threshold {
			'0'
		}
		.shape_rendering {
			'auto'
		}
		.stop_color {
			'black'
		}
		.stop_opacity, .stroke_opacity {
			'1'
		}
		.stroke_linecap {
			'butt'
		}
		.stroke_linejoin {
			'miter'
		}
		.stroke_miterlimit {
			'4'
		}
		.stroke_width {
			'1px'
		}
		.stroke_dashoffset {
			'0px'
		}
		.rotate, .scale, .transform, .translate {
			'none'
		}
		.scroll_timeline_name {
			'none'
		}
		.scroll_timeline_axis {
			'block'
		}
		.scrollbar_color, .scrollbar_gutter {
			'auto'
		}
		.tab_size {
			'8'
		}
		.table_layout {
			'auto'
		}
		.text_align {
			'start'
		}
		.text_anchor {
			'start'
		}
		.text_decoration_color {
			'currentcolor'
		}
		.text_decoration_line {
			'none'
		}
		.text_decoration_style {
			'solid'
		}
		.text_decoration_thickness, .text_underline_offset {
			'auto'
		}
		.text_underline_position {
			'auto'
		}
		.text_indent {
			'0'
		}
		.text_justify {
			'auto'
		}
		.text_overflow {
			'clip'
		}
		.text_rendering {
			'auto'
		}
		.text_transform {
			'none'
		}
		.text_wrap_mode {
			'wrap'
		}
		.text_wrap_style {
			'auto'
		}
		.timeline_scope {
			'none'
		}
		.transform_style {
			'flat'
		}
		.transform_box {
			'view-box'
		}
		.transform_origin {
			'50% 50%'
		}
		.transition_behavior {
			'normal'
		}
		.transition_delay, .transition_duration {
			'0s'
		}
		.transition_property {
			'all'
		}
		.transition_timing_function {
			'ease'
		}
		.unicode_bidi {
			'normal'
		}
		.vertical_align {
			'baseline'
		}
		.user_select {
			'auto'
		}
		.touch_action {
			'auto'
		}
		.writing_mode {
			'horizontal-tb'
		}
		.view_transition_name {
			'none'
		}
		.scrollbar_width {
			'auto'
		}
		.resize {
			'none'
		}
		.scroll_behavior {
			'auto'
		}
		.webkit_text_fill_color {
			'currentcolor'
		}
		.view_timeline_inset {
			'auto'
		}
		.view_timeline_axis {
			'block'
		}
		.view_timeline_name {
			'none'
		}
		.visibility {
			'visible'
		}
		.will_change {
			'auto'
		}
		.white_space_collapse {
			'collapse'
		}
		.white_space_trim {
			'none'
		}
		.word_break {
			'normal'
		}
		.word_spacing {
			'normal'
		}
		.z_index {
			'auto'
		}
		.cx, .cy, .x, .y, .r {
			'0'
		}
		.rx, .ry {
			'auto'
		}
		.dominant_baseline {
			'auto'
		}
		.display {
			'inline'
		}
		.flex_basis {
			'auto'
		}
		.quotes {
			'auto'
		}
		.box_shadow, .text_shadow {
			'none'
		}
		.list_style_type {
			'disc'
		}
		.clip {
			'auto'
		}
		.stroke_dasharray {
			'none'
		}
		.font_family {
			'serif'
		}
		.grid_column_start, .grid_column_end, .grid_row_start, .grid_row_end {
			'auto'
		}
		.grid_auto_flow {
			'row'
		}
		.grid_auto_columns, .grid_auto_rows {
			'auto'
		}
		.grid_template_columns, .grid_template_rows {
			'none'
		}
		.grid_template_areas {
			'none'
		}
		.filter, .backdrop_filter {
			'none'
		}
		.counter_increment, .counter_reset, .counter_set {
			'none'
		}
		.cursor {
			'auto'
		}
		.font_size {
			'medium'
		}
		.fill {
			'black'
		}
		.stroke {
			'none'
		}
		.font_variant_ligatures, .font_variant_numeric, .font_variant_east_asian,
		.font_variant_alternates {
			'normal'
		}
		.clip_path, .shape_outside {
			'none'
		}
		.content {
			'normal'
		}
		else {
			// Shorthands have no initial value of their own; their longhands do.
			''
		}
	}

	return parse_css_value(ParsingParams{}, initial_text, property_id) or {
		return computed_interpolation_empty_style_value()
	}
}

fn computed_interpolation_is_inherited_property(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.accent_color, .caption_side, .caret_color, .clip_rule, .color, .color_interpolation,
		.color_scheme, .direction, .empty_cells, .fill_opacity, .fill_rule, .font_kerning,
		.font_language_override, .font_optical_sizing, .font_style, .font_variant_caps,
		.font_variant_emoji, .font_variant_position, .font_weight, .letter_spacing,
		.image_rendering, .list_style_image, .list_style_position, .math_depth, .math_style,
		.math_shift, .orphans, .widows, .overflow_wrap, .pointer_events, .shape_rendering,
		.scrollbar_color, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity,
		.stroke_width, .stroke_dashoffset, .tab_size, .text_align, .text_anchor,
		.text_decoration_line, .paint_order, .text_justify, .text_rendering, .text_transform,
		.text_underline_offset, .text_underline_position, .text_indent, .text_wrap_mode,
		.text_wrap_style, .visibility, .webkit_text_fill_color, .white_space_collapse, .word_break,
		.word_spacing, .writing_mode, .border_collapse, .border_spacing, .dominant_baseline,
		.quotes, .text_shadow, .list_style_type, .stroke_dasharray, .font_family, .cursor,
		.font_size, .fill, .stroke, .font_variant_ligatures, .font_variant_numeric,
		.font_variant_east_asian, .font_variant_alternates {
			true
		}
		else {
			false
		}
	}
}

fn computed_interpolation_property_requires_computation_with_cascaded_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.accent_color, .animation_delay, .animation_duration, .animation_iteration_count,
		.animation_name, .animation_timeline, .animation_timing_function, .aspect_ratio,
		.background_color, .background_image, .background_attachment, .background_blend_mode,
		.background_clip, .background_origin, .background_position_x, .background_position_y,
		.background_repeat, .background_size, .border_block_end_color, .border_block_end_width,
		.border_block_start_color, .border_block_start_width, .border_bottom_color,
		.border_bottom_width, .border_bottom_left_radius, .border_bottom_right_radius,
		.border_end_end_radius, .border_end_start_radius, .border_image_outset,
		.border_image_slice, .border_image_source, .border_image_width, .border_inline_end_color,
		.border_inline_end_width, .border_inline_start_color, .border_inline_start_width,
		.border_left_color, .border_left_width, .border_right_color, .border_right_width,
		.border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_color,
		.border_top_width, .border_top_left_radius, .border_top_right_radius, .block_size, .bottom,
		.caret_color, .color, .corner_bottom_left_shape, .corner_bottom_right_shape,
		.corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape,
		.corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .fill_opacity,
		.flood_color, .flood_opacity, .font_feature_settings, .font_style,
		.font_variation_settings, .font_weight, .font_width, .flex_grow, .flex_shrink,
		.column_count, .column_width, .column_height, .column_gap, .row_gap, .height, .inline_size,
		.inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left,
		.letter_spacing, .line_height, .list_style_image, .margin_block_end, .margin_block_start,
		.margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right,
		.margin_top, .mask_image, .mask_position, .mask_size, .math_depth, .max_block_size,
		.max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size,
		.min_width, .object_position, .opacity, .order, .orphans, .widows, .outline_color,
		.outline_offset, .outline_width, .overflow_clip_margin_block_end,
		.overflow_clip_margin_block_start, .overflow_clip_margin_bottom,
		.overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start,
		.overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top,
		.padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end,
		.padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective,
		.perspective_origin, .position_area, .right, .scrollbar_color, .shape_margin,
		.shape_image_threshold, .stop_color, .stop_opacity, .stroke_miterlimit, .stroke_opacity,
		.stroke_width, .stroke_dashoffset, .tab_size, .text_decoration_color,
		.text_decoration_thickness, .text_underline_offset, .text_indent, .top, .transform_origin,
		.vertical_align, .width, .cx, .cy, .x, .y, .r, .rx, .ry, .rotate, .scale, .transform,
		.transition_delay, .transition_duration, .transition_timing_function, .translate,
		.view_timeline_inset, .webkit_text_fill_color, .word_spacing, .z_index, .flex_basis,
		.box_shadow, .text_shadow, .clip, .stroke_dasharray, .grid_auto_columns, .grid_auto_rows,
		.grid_template_columns, .grid_template_rows, .filter, .backdrop_filter, .counter_increment,
		.counter_reset, .counter_set, .cursor, .font_size, .fill, .stroke, .clip_path,
		.shape_outside, .content {
			true
		}
		else {
			false
		}
	}
}

fn computed_interpolation_property_requires_computation_with_inherited_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_origin,
		.background_position_x, .background_position_y, .background_repeat, .background_size {
			true
		}
		else {
			false
		}
	}
}

fn computed_interpolation_property_requires_computation_with_initial_value(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_color,
		.background_origin, .background_position_x, .background_position_y, .background_repeat,
		.background_size, .border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .color, .corner_bottom_left_shape,
		.corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape,
		.corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape,
		.corner_top_right_shape, .flood_color, .font_style, .font_weight, .font_width,
		.letter_spacing, .math_depth, .outline_width, .stop_color, .text_decoration_color,
		.word_spacing, .font_size, .fill {
			true
		}
		else {
			false
		}
	}
}

fn computed_interpolation_style_value_keyword(value &dom.StyleValue) ?Keyword {
	serialized := value.css_text.trim_space()
	if serialized.len == 0 {
		return none
	}
	return keyword_from_string(to_ascii_lowercase(serialized))
}

fn computed_interpolation_math_style_from_dom_style_value(value &dom.StyleValue) ?MathStyle {
	return match computed_interpolation_style_value_keyword(value) {
		.normal { MathStyle.normal }
		.compact { MathStyle.compact }
		else { none }
	} or { return none }
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
	// The translated PropertyID enum does not yet include FontFamily or FontSize.
	return id in [.font_style, .font_weight, .font_width, .font_variation_settings]
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
	value := c.property(property_id, .yes) or { return GapValue.normal() }
	if computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .normal {
		return GapValue.normal()
	}
	parsed_value := parse_css_value_logic(property_id, value.css_text) or {
		return GapValue.normal()
	}
	match parsed_value {
		LengthStyleValue, PercentageStyleValue, CalculatedStyleValue {
			return GapValue.from_length_percentage(LengthPercentage.from_style_value_logic(parsed_value))
		}
		else {}
	}

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

fn computed_interpolation_split_coordinating_list_value(value &dom.StyleValue) []&dom.StyleValue {
	// Boundary: DOM::StyleValue is currently an opaque DOM-side placeholder in this V port, so we subdivide the
	// serialized value list here. Coordinating list properties are comma-separated, and commas inside nested CSS
	// functions or strings are part of the item.
	text := value.css_text
	mut values := []&dom.StyleValue{}
	mut start := 0
	mut nesting := 0
	mut quote := u8(0)
	mut escaped := false

	for i, ch in text.bytes() {
		if escaped {
			escaped = false
			continue
		}
		if quote != 0 {
			if ch == `\\` {
				escaped = true
			} else if ch == quote {
				quote = 0
			}
			continue
		}
		match ch {
			`'`, `"` {
				quote = ch
			}
			`(`, `[`, `{` {
				nesting++
			}
			`)`, `]`, `}` {
				if nesting > 0 {
					nesting--
				}
			}
			`,` {
				if nesting == 0 {
					values << &dom.StyleValue{
						css_text: text[start..i].trim_space()
					}
					start = i + 1
				}
			}
			else {}
		}
	}

	if values.len == 0 {
		return [value]
	}

	values << &dom.StyleValue{
		css_text: text[start..].trim_space()
	}
	return values
}

pub fn (c &ComputedProperties) assemble_coordinated_value_list(base_property_id PropertyID, property_ids ComputedInterpolationPropertyIDs) map[PropertyID][]&dom.StyleValue {
	// A coordinating list property group creates a coordinated value list, which has, for each entry, a value from each
	// property in the group; these are used together to define a single effect, such as a background image layer or an
	// animation. The coordinated value list is assembled as follows:
	// - The length of the coordinated value list is determined by the number of items specified in one particular
	//   coordinating list property, the coordinating list base property. (In the case of backgrounds, this is the
	//   background-image property.)
	// - The Nth value of the coordinated value list is constructed by collecting the Nth use value of each coordinating
	//   list property
	// - If a coordinating list property has too many values specified, excess values at the end of its list are not
	//   used.
	// - If a coordinating list property has too few values specified, its value list is repeated to add more used
	//   values.
	// - The computed values of the coordinating list properties are not affected by such truncation or repetition.
	mut result := map[PropertyID][]&dom.StyleValue{}

	base_property := c.property(base_property_id, .yes) or { return result }
	base_list := computed_interpolation_split_coordinating_list_value(base_property)

	for i := 0; i < base_list.len; i++ {
		for property_id in property_ids {
			value := c.property(property_id, .yes) or { continue }
			list := computed_interpolation_split_coordinating_list_value(value)
			if list.len == 0 {
				continue
			}

			mut property_values := result[property_id] or { []&dom.StyleValue{} }
			property_values << list[i % list.len]
			result[property_id] = property_values
		}
	}

	return result
}

pub fn (c &ComputedProperties) color_interpolation() ColorInterpolation {
	value := c.property(.color_interpolation, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { ColorInterpolation.auto_ }
		.srgb { ColorInterpolation.srgb }
		.linearrgb { ColorInterpolation.srgb_linear }
		else { ColorInterpolation.auto_ }
	}
}

pub fn (c &ComputedProperties) text_anchor() TextAnchor {
	value := c.property(.text_anchor, .yes) or { return .start }
	keyword := computed_interpolation_style_value_keyword(value) or { return .start }
	return match keyword {
		.start { TextAnchor.start }
		.middle { TextAnchor.middle }
		.end_ { TextAnchor.end_ }
		else { TextAnchor.start }
	}
}

pub fn (c &ComputedProperties) dominant_baseline() ?BaselineMetric {
	_ = c
	return none
}

pub fn (c &ComputedProperties) text_align() TextAlign {
	value := c.property(.text_align, .yes) or { return .start }
	keyword := computed_interpolation_style_value_keyword(value) or { return .start }
	return match keyword {
		.start { TextAlign.start }
		.end_ { TextAlign.end_ }
		.left { TextAlign.left }
		.right { TextAlign.right }
		.center { TextAlign.center }
		.justify { TextAlign.justify }
		.match_parent { TextAlign.match_parent }
		.libweb_center { TextAlign.libweb_center }
		.libweb_inherit_or_center { TextAlign.libweb_inherit_or_center }
		.libweb_left { TextAlign.libweb_left }
		.libweb_right { TextAlign.libweb_right }
		else { TextAlign.start }
	}
}

pub fn (c &ComputedProperties) text_justify() TextJustify {
	value := c.property(.text_justify, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { TextJustify.auto_ }
		.none_ { TextJustify.none_ }
		.inter_word { TextJustify.inter_word }
		.inter_character { TextJustify.inter_character }
		else { TextJustify.auto_ }
	}
}

pub fn (c &ComputedProperties) text_overflow() TextOverflow {
	value := c.property(.text_overflow, .yes) or { return .clip }
	keyword := computed_interpolation_style_value_keyword(value) or { return .clip }
	return match keyword {
		.clip { TextOverflow.clip }
		.ellipsis { TextOverflow.ellipsis }
		else { TextOverflow.clip }
	}
}

pub fn (c &ComputedProperties) text_rendering() TextRendering {
	value := c.property(.text_rendering, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { TextRendering.auto_ }
		.optimizespeed { TextRendering.optimizespeed }
		.optimizelegibility { TextRendering.optimizelegibility }
		.geometricprecision { TextRendering.geometricprecision }
		else { TextRendering.auto_ }
	}
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

fn keyword_to_background_attachment_for_computed_properties(keyword Keyword) ?BackgroundAttachment {
	return match keyword {
		.scroll { BackgroundAttachment.scroll }
		.fixed { BackgroundAttachment.fixed }
		.local { BackgroundAttachment.local }
		else { none }
	}
}

pub fn (c &ComputedProperties) background_attachment() []BackgroundAttachment {
	keywords := computed_interpolation_keyword_list_property(c, .background_attachment, [
		Keyword.scroll,
	])
	mut values := []BackgroundAttachment{}
	for keyword in keywords {
		values << (keyword_to_background_attachment_for_computed_properties(keyword) or {
			return [BackgroundAttachment.scroll]
		})
	}
	return values
}

fn keyword_to_background_box_for_computed_properties(keyword Keyword, default_value BackgroundBox) BackgroundBox {
	return match keyword {
		.border_box { BackgroundBox.border_box }
		.padding_box { BackgroundBox.padding_box }
		.content_box { BackgroundBox.content_box }
		.text { BackgroundBox.text }
		else { default_value }
	}
}

pub fn (c &ComputedProperties) background_clip() []BackgroundBox {
	keywords := computed_interpolation_keyword_list_property(c, .background_clip, [
		Keyword.border_box,
	])
	mut values := []BackgroundBox{}
	for keyword in keywords {
		values << keyword_to_background_box_for_computed_properties(keyword, .border_box)
	}
	return values
}

pub fn (c &ComputedProperties) background_origin() []BackgroundBox {
	keywords := computed_interpolation_keyword_list_property(c, .background_origin, [
		Keyword.padding_box,
	])
	mut values := []BackgroundBox{}
	for keyword in keywords {
		values << keyword_to_background_box_for_computed_properties(keyword, .padding_box)
	}
	return values
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
	value := c.property(.caption_side, .yes) or { return .top }
	keyword := computed_interpolation_style_value_keyword(value) or { return .top }
	return match keyword {
		.top { CaptionSide.top }
		.bottom { CaptionSide.bottom }
		else { CaptionSide.top }
	}
}

pub fn (c &ComputedProperties) clip() Clip {
	_ = c
	return Clip.make_auto()
}

pub fn (c &ComputedProperties) display() Display {
	return c.display_before_box_type_transformation_
}

pub fn (c &ComputedProperties) float_() Float {
	value := c.property(.float_, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.none_ { Float.none_ }
		.left { Float.left }
		.right { Float.right }
		.inline_start { Float.inline_start }
		.inline_end { Float.inline_end }
		else { Float.none_ }
	}
}

pub fn (c &ComputedProperties) caret_color(layout_node &dom.LayoutNode) ComputedColor {
	color_resolution_context := color_resolution_context_for_layout_node(layout_node)
	value := c.property(.caret_color, .yes) or { return ComputedColor.black() }
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }
	if keyword == .auto {
		return c.color_or_fallback(.color, color_resolution_context, ComputedColor.black())
	}

	return c.color_or_fallback(.caret_color, color_resolution_context, ComputedColor.black())
}

pub fn (c &ComputedProperties) clear() Clear {
	value := c.property(.clear, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.none_ { Clear.none_ }
		.left { Clear.left }
		.right { Clear.right }
		.both { Clear.both }
		.inline_start { Clear.inline_start }
		.inline_end { Clear.inline_end }
		else { Clear.none_ }
	}
}

pub fn (c &ComputedProperties) column_span() ColumnSpan {
	value := c.property(.column_span, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.none_ { ColumnSpan.none_ }
		.all { ColumnSpan.all }
		else { ColumnSpan.none_ }
	}
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
	value := c.property(.white_space_collapse, .yes) or { return .collapse }
	keyword := computed_interpolation_style_value_keyword(value) or { return .collapse }
	return match keyword {
		.collapse { WhiteSpaceCollapse.collapse }
		.discard { WhiteSpaceCollapse.discard }
		.preserve { WhiteSpaceCollapse.preserve }
		.preserve_breaks { WhiteSpaceCollapse.preserve_breaks }
		.preserve_spaces { WhiteSpaceCollapse.preserve_spaces }
		.break_spaces { WhiteSpaceCollapse.break_spaces }
		else { WhiteSpaceCollapse.collapse }
	}
}

pub fn (c &ComputedProperties) white_space_trim() WhiteSpaceTrimData {
	value := c.property(.white_space_trim, .yes) or { return WhiteSpaceTrimData{} }
	parsed_value := parse_css_value_logic(.white_space_trim, value.css_text) or {
		return WhiteSpaceTrimData{}
	}
	if parsed_value is KeywordStyleValue {
		if parsed_value.keyword() == .none_ {
			return WhiteSpaceTrimData{}
		}
	}
	if parsed_value is StyleValueList {
		mut trim_data := WhiteSpaceTrimData{}
		for entry in parsed_value.values() {
			if entry is KeywordStyleValue {
				match entry.keyword() {
					.discard_before { trim_data.discard_before = true }
					.discard_after { trim_data.discard_after = true }
					.discard_inner { trim_data.discard_inner = true }
					else {}
				}
			}
		}
		return trim_data
	}
	return WhiteSpaceTrimData{}
}

pub fn (c &ComputedProperties) word_break() WordBreak {
	value := c.property(.word_break, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { WordBreak.normal }
		.keep_all { WordBreak.keep_all }
		.break_all { WordBreak.break_all }
		.break_word { WordBreak.break_word }
		else { WordBreak.normal }
	}
}

pub fn (c &ComputedProperties) overflow_wrap() OverflowWrap {
	value := c.property(.overflow_wrap, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { OverflowWrap.normal }
		.anywhere { OverflowWrap.anywhere }
		.break_word { OverflowWrap.break_word }
		else { OverflowWrap.normal }
	}
}

pub fn (c &ComputedProperties) word_spacing() CSSPixels {
	if value := c.property(.word_spacing, .yes) {
		if length := computed_interpolation_length_from_dom_style_value(value) {
			return length.absolute_length_to_px()
		}
	}
	return CSSPixels{}
}

pub fn (c &ComputedProperties) letter_spacing() CSSPixels {
	if value := c.property(.letter_spacing, .yes) {
		if length := computed_interpolation_length_from_dom_style_value(value) {
			return length.absolute_length_to_px()
		}
	}
	return CSSPixels{}
}

fn keyword_to_line_style_for_computed_properties(keyword Keyword) ?LineStyle {
	return match keyword {
		.none_ { LineStyle.none_ }
		.hidden { LineStyle.hidden }
		.dotted { LineStyle.dotted }
		.dashed { LineStyle.dashed }
		.solid { LineStyle.solid }
		.double_ { LineStyle.double_ }
		.groove { LineStyle.groove }
		.ridge { LineStyle.ridge }
		.inset { LineStyle.inset }
		.outset { LineStyle.outset }
		else { none }
	}
}

pub fn (c &ComputedProperties) line_style(property_id PropertyID) LineStyle {
	value := c.property(property_id, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return keyword_to_line_style_for_computed_properties(keyword) or { LineStyle.none_ }
}

pub fn (c &ComputedProperties) outline_offset() Length {
	return c.length(.outline_offset)
}

fn keyword_to_outline_style_for_computed_properties(keyword Keyword) ?OutlineStyle {
	return match keyword {
		.auto { OutlineStyle.auto_ }
		.none_ { OutlineStyle.none_ }
		.dotted { OutlineStyle.dotted }
		.dashed { OutlineStyle.dashed }
		.solid { OutlineStyle.solid }
		.double_ { OutlineStyle.double_ }
		.groove { OutlineStyle.groove }
		.ridge { OutlineStyle.ridge }
		.inset { OutlineStyle.inset }
		.outset { OutlineStyle.outset }
		else { none }
	}
}

pub fn (c &ComputedProperties) outline_style() OutlineStyle {
	value := c.property(.outline_style, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return keyword_to_outline_style_for_computed_properties(keyword) or { OutlineStyle.none_ }
}

fn keyword_to_text_decoration_line_for_computed_properties(keyword Keyword) ?TextDecorationLine {
	return match keyword {
		.none_ { TextDecorationLine.none_ }
		.underline { TextDecorationLine.underline }
		.overline { TextDecorationLine.overline }
		.line_through { TextDecorationLine.line_through }
		.blink { TextDecorationLine.blink }
		.spelling_error { TextDecorationLine.spelling_error }
		.grammar_error { TextDecorationLine.grammar_error }
		else { none }
	}
}

pub fn (c &ComputedProperties) text_decoration_line() []TextDecorationLine {
	value := c.property(.text_decoration_line, .yes) or { return []TextDecorationLine{} }
	parsed_value := parse_css_value_logic(.text_decoration_line, value.css_text) or {
		return []TextDecorationLine{}
	}

	if parsed_value is KeywordStyleValue {
		if parsed_value.keyword() == .none_ {
			return []TextDecorationLine{}
		}
		if line := keyword_to_text_decoration_line_for_computed_properties(parsed_value.keyword()) {
			return [line]
		}
		return []TextDecorationLine{}
	}

	if parsed_value is StyleValueList {
		mut lines := []TextDecorationLine{}
		for item in parsed_value.values() {
			if item is KeywordStyleValue {
				if line := keyword_to_text_decoration_line_for_computed_properties(item.keyword()) {
					if line != .none_ {
						lines << line
					}
				}
			}
		}
		return lines
	}

	return []TextDecorationLine{}
}

fn keyword_to_text_decoration_style_for_computed_properties(keyword Keyword) ?TextDecorationStyle {
	return match keyword {
		.solid { TextDecorationStyle.solid }
		.double_ { TextDecorationStyle.double_ }
		.dotted { TextDecorationStyle.dotted }
		.dashed { TextDecorationStyle.dashed }
		.wavy { TextDecorationStyle.wavy }
		else { none }
	}
}

pub fn (c &ComputedProperties) text_decoration_style() TextDecorationStyle {
	value := c.property(.text_decoration_style, .yes) or { return .solid }
	keyword := computed_interpolation_style_value_keyword(value) or { return .solid }
	return keyword_to_text_decoration_style_for_computed_properties(keyword) or {
		TextDecorationStyle.solid
	}
}

pub fn (c &ComputedProperties) text_decoration_thickness() TextDecorationThickness {
	value := c.property(.text_decoration_thickness, .yes) or { return TextDecorationThickness{} }
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }
	if keyword == .auto {
		return TextDecorationThickness{}
	}
	if keyword == .from_font {
		return TextDecorationThickness{
			is_auto:   false
			from_font: true
		}
	}
	parsed_value := parse_css_value_logic(.text_decoration_thickness, value.css_text) or {
		return TextDecorationThickness{}
	}
	match parsed_value {
		LengthStyleValue, PercentageStyleValue, CalculatedStyleValue {
			return TextDecorationThickness{
				is_auto:           false
				length_percentage: LengthPercentage.from_style_value_logic(parsed_value)
			}
		}
		else {}
	}

	return TextDecorationThickness{}
}

pub fn (c &ComputedProperties) text_transform() TextTransform {
	value := c.property(.text_transform, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.none_ { TextTransform.none_ }
		.capitalize { TextTransform.capitalize }
		.uppercase { TextTransform.uppercase }
		.lowercase { TextTransform.lowercase }
		.full_width { TextTransform.full_width }
		.full_size_kana { TextTransform.full_size_kana }
		.math_auto { TextTransform.math_auto }
		else { TextTransform.none_ }
	}
}

pub fn (c &ComputedProperties) text_shadow(layout_node &dom.LayoutNode) []ShadowData {
	_ = c
	_ = layout_node
	return []ShadowData{}
}

pub fn (c &ComputedProperties) text_indent() TextIndentData {
	value := c.property(.text_indent, .yes) or { return TextIndentData{} }
	parsed_value := parse_css_value_logic(.text_indent, value.css_text) or {
		return TextIndentData{}
	}
	if parsed_value is TextIndentStyleValue {
		return TextIndentData{
			length_percentage: LengthPercentage.from_style_value_logic(parsed_value.length_percentage())
			each_line:         parsed_value.each_line()
			hanging:           parsed_value.hanging()
		}
	}
	return TextIndentData{}
}

pub fn (c &ComputedProperties) text_wrap_mode() TextWrapMode {
	value := c.property(.text_wrap_mode, .yes) or { return .wrap }
	keyword := computed_interpolation_style_value_keyword(value) or { return .wrap }
	return match keyword {
		.wrap { TextWrapMode.wrap }
		.nowrap { TextWrapMode.nowrap }
		else { TextWrapMode.wrap }
	}
}

pub fn (c &ComputedProperties) text_wrap_style() TextWrapStyle {
	value := c.property(.text_wrap_style, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { TextWrapStyle.auto_ }
		.balance { TextWrapStyle.balance }
		.stable { TextWrapStyle.stable }
		.pretty { TextWrapStyle.pretty }
		else { TextWrapStyle.auto_ }
	}
}

pub fn (c &ComputedProperties) list_style_type(registered_counter_styles map[string]string) ListStyleType {
	_ = c
	_ = registered_counter_styles
	return ListStyleType{
		name: 'disc'
	}
}

pub fn (c &ComputedProperties) list_style_position() ListStylePosition {
	value := c.property(.list_style_position, .yes) or { return .outside }
	keyword := computed_interpolation_style_value_keyword(value) or { return .outside }
	return match keyword {
		.outside { ListStylePosition.outside }
		.inside { ListStylePosition.inside }
		else { ListStylePosition.outside }
	}
}

pub fn (c &ComputedProperties) flex_direction() FlexDirection {
	value := c.property(.flex_direction, .yes) or { return .row }
	keyword := computed_interpolation_style_value_keyword(value) or { return .row }
	return match keyword {
		.row { FlexDirection.row }
		.row_reverse { FlexDirection.row_reverse }
		.column { FlexDirection.column }
		.column_reverse { FlexDirection.column_reverse }
		else { FlexDirection.row }
	}
}

pub fn (c &ComputedProperties) flex_wrap() FlexWrap {
	value := c.property(.flex_wrap, .yes) or { return .nowrap }
	keyword := computed_interpolation_style_value_keyword(value) or { return .nowrap }
	return match keyword {
		.nowrap { FlexWrap.nowrap }
		.wrap { FlexWrap.wrap }
		.wrap_reverse { FlexWrap.wrap_reverse }
		else { FlexWrap.nowrap }
	}
}

pub fn (c &ComputedProperties) flex_basis() FlexBasis {
	_ = c
	return FlexBasis{}
}

pub fn (c &ComputedProperties) flex_grow() f32 {
	if value := c.property(.flex_grow, .yes) {
		if number := computed_interpolation_number_from_dom_style_value(value) {
			return f32(number)
		}
	}
	return 0
}

pub fn (c &ComputedProperties) flex_shrink() f32 {
	if value := c.property(.flex_shrink, .yes) {
		if number := computed_interpolation_number_from_dom_style_value(value) {
			return f32(number)
		}
	}
	return 1
}

pub fn (c &ComputedProperties) order() int {
	if value := c.property(.order, .yes) {
		if integer := computed_interpolation_integer_from_dom_style_value(value) {
			return int(integer)
		}
	}
	return 0
}

pub fn (c &ComputedProperties) orphans() int {
	if value := c.property(.orphans, .yes) {
		if integer := computed_interpolation_integer_from_dom_style_value(value) {
			return int(integer)
		}
	}
	return 2
}

pub fn (c &ComputedProperties) widows() int {
	if value := c.property(.widows, .yes) {
		if integer := computed_interpolation_integer_from_dom_style_value(value) {
			return int(integer)
		}
	}
	return 2
}

pub fn (c &ComputedProperties) accent_color(layout_node &dom.LayoutNode) ?ComputedColor {
	color_resolution_context := color_resolution_context_for_layout_node(layout_node)
	value := c.property(.accent_color, .yes) or { return none }
	parsed_value := parse_css_value_logic(.accent_color, value.css_text) or { return none }
	if !parsed_value.has_color() {
		return none
	}
	color := parsed_value.to_color(color_resolution_context) or { return none }
	return ComputedColor.rgba(color.red(), color.green(), color.blue(), color.alpha())
}

pub fn (c &ComputedProperties) align_content() AlignContent {
	value := c.property(.align_content, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { AlignContent.normal }
		.start { AlignContent.start }
		.flex_start { AlignContent.flex_start }
		.end_ { AlignContent.end_ }
		.flex_end { AlignContent.flex_end }
		.center { AlignContent.center }
		.stretch { AlignContent.stretch }
		.space_between { AlignContent.space_between }
		.space_around { AlignContent.space_around }
		.space_evenly { AlignContent.space_evenly }
		else { AlignContent.normal }
	}
}

pub fn (c &ComputedProperties) align_items() AlignItems {
	value := c.property(.align_items, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { AlignItems.normal }
		.start { AlignItems.start }
		.flex_start { AlignItems.flex_start }
		.self_start { AlignItems.self_start }
		.end_ { AlignItems.end_ }
		.flex_end { AlignItems.flex_end }
		.self_end { AlignItems.self_end }
		.center { AlignItems.center }
		.stretch { AlignItems.stretch }
		.baseline { AlignItems.baseline }
		.safe { AlignItems.safe }
		.unsafe_ { AlignItems.unsafe_ }
		else { AlignItems.normal }
	}
}

pub fn (c &ComputedProperties) align_self() AlignSelf {
	value := c.property(.align_self, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { AlignSelf.auto_ }
		.normal { AlignSelf.normal }
		.start { AlignSelf.start }
		.flex_start { AlignSelf.flex_start }
		.self_start { AlignSelf.self_start }
		.end_ { AlignSelf.end_ }
		.flex_end { AlignSelf.flex_end }
		.self_end { AlignSelf.self_end }
		.center { AlignSelf.center }
		.stretch { AlignSelf.stretch }
		.baseline { AlignSelf.baseline }
		.safe { AlignSelf.safe }
		.unsafe_ { AlignSelf.unsafe_ }
		else { AlignSelf.auto_ }
	}
}

pub fn (c &ComputedProperties) appearance() Appearance {
	value := c.property(.appearance, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	appearance := match keyword {
		.none_ { Appearance.none_ }
		.textfield { Appearance.textfield }
		.menulist_button { Appearance.menulist_button }
		else { Appearance.auto_ }
	}

	return appearance
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
	value := c.property(.visibility, .yes) or { return .visible }
	keyword := computed_interpolation_style_value_keyword(value) or { return .visible }
	return match keyword {
		.visible { Visibility.visible }
		.hidden { Visibility.hidden }
		.collapse { Visibility.collapse }
		else { Visibility.visible }
	}
}

pub fn (c &ComputedProperties) image_rendering() ImageRendering {
	value := c.property(.image_rendering, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { ImageRendering.auto_ }
		.crisp_edges { ImageRendering.crisp_edges }
		.high_quality { ImageRendering.high_quality }
		.pixelated, .optimizespeed { ImageRendering.pixelated }
		.smooth, .optimizequality { ImageRendering.smooth }
		else { ImageRendering.auto_ }
	}
}

pub fn (c &ComputedProperties) justify_content() JustifyContent {
	value := c.property(.justify_content, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { JustifyContent.normal }
		.start { JustifyContent.start }
		.flex_start { JustifyContent.flex_start }
		.end_ { JustifyContent.end_ }
		.flex_end { JustifyContent.flex_end }
		.center { JustifyContent.center }
		.stretch { JustifyContent.stretch }
		.space_between { JustifyContent.space_between }
		.space_around { JustifyContent.space_around }
		.space_evenly { JustifyContent.space_evenly }
		.left { JustifyContent.left }
		.right { JustifyContent.right }
		else { JustifyContent.normal }
	}
}

pub fn (c &ComputedProperties) justify_items() JustifyItems {
	value := c.property(.justify_items, .yes) or { return .legacy }
	keyword := computed_interpolation_style_value_keyword(value) or { return .legacy }
	return match keyword {
		.normal { JustifyItems.normal }
		.start { JustifyItems.start }
		.flex_start { JustifyItems.flex_start }
		.self_start { JustifyItems.self_start }
		.end_ { JustifyItems.end_ }
		.flex_end { JustifyItems.flex_end }
		.self_end { JustifyItems.self_end }
		.center { JustifyItems.center }
		.stretch { JustifyItems.stretch }
		.baseline { JustifyItems.baseline }
		.safe { JustifyItems.safe }
		.unsafe_ { JustifyItems.unsafe_ }
		.legacy { JustifyItems.legacy }
		.left { JustifyItems.left }
		.right { JustifyItems.right }
		else { JustifyItems.legacy }
	}
}

pub fn (c &ComputedProperties) justify_self() JustifySelf {
	value := c.property(.justify_self, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { JustifySelf.auto_ }
		.normal { JustifySelf.normal }
		.start { JustifySelf.start }
		.flex_start { JustifySelf.flex_start }
		.self_start { JustifySelf.self_start }
		.end_ { JustifySelf.end_ }
		.flex_end { JustifySelf.flex_end }
		.self_end { JustifySelf.self_end }
		.center { JustifySelf.center }
		.stretch { JustifySelf.stretch }
		.baseline { JustifySelf.baseline }
		.safe { JustifySelf.safe }
		.unsafe_ { JustifySelf.unsafe_ }
		.left { JustifySelf.left }
		.right { JustifySelf.right }
		else { JustifySelf.auto_ }
	}
}

fn keyword_to_overflow_for_computed_properties(keyword Keyword) ?Overflow {
	return match keyword {
		.visible { Overflow.visible }
		.hidden { Overflow.hidden }
		.clip { Overflow.clip }
		.scroll { Overflow.scroll }
		.auto { Overflow.auto_ }
		else { none }
	}
}

pub fn (c &ComputedProperties) overflow(property_id PropertyID) Overflow {
	value := c.property(property_id, .yes) or { return .visible }
	keyword := computed_interpolation_style_value_keyword(value) or { return .visible }
	return keyword_to_overflow_for_computed_properties(keyword) or { Overflow.visible }
}

pub fn (c &ComputedProperties) overflow_x() Overflow {
	return c.overflow(.overflow_x)
}

pub fn (c &ComputedProperties) overflow_y() Overflow {
	return c.overflow(.overflow_y)
}

pub fn (c &ComputedProperties) box_shadow(layout_node &dom.LayoutNode) []ShadowData {
	_ = c
	_ = layout_node
	return []ShadowData{}
}

pub fn (c &ComputedProperties) box_sizing() BoxSizing {
	value := c.property(.box_sizing, .yes) or { return .content_box }
	keyword := computed_interpolation_style_value_keyword(value) or { return .content_box }
	return match keyword {
		.content_box { BoxSizing.content_box }
		.border_box { BoxSizing.border_box }
		else { BoxSizing.content_box }
	}
}

fn keyword_to_pointer_events_for_computed_properties(keyword Keyword) ?PointerEvents {
	return match keyword {
		.auto { PointerEvents.auto_ }
		.all { PointerEvents.all }
		.none_ { PointerEvents.none_ }
		else { none }
	}
}

pub fn (c &ComputedProperties) pointer_events() PointerEvents {
	value := c.property(.pointer_events, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return keyword_to_pointer_events_for_computed_properties(keyword) or { PointerEvents.auto_ }
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
	value := c.property(.font_variant_caps, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { FontVariantCaps.normal }
		.small_caps { FontVariantCaps.small_caps }
		.all_small_caps { FontVariantCaps.all_small_caps }
		.petite_caps { FontVariantCaps.petite_caps }
		.all_petite_caps { FontVariantCaps.all_petite_caps }
		.unicase { FontVariantCaps.unicase }
		.titling_caps { FontVariantCaps.titling_caps }
		else { FontVariantCaps.normal }
	}
}

pub fn (c &ComputedProperties) font_variant_east_asian() ?FontVariantEastAsian {
	_ = c
	return none
}

pub fn (c &ComputedProperties) font_variant_emoji() FontVariantEmoji {
	value := c.property(.font_variant_emoji, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { FontVariantEmoji.normal }
		.text { FontVariantEmoji.text }
		.emoji { FontVariantEmoji.emoji }
		.unicode { FontVariantEmoji.unicode }
		else { FontVariantEmoji.normal }
	}
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
	value := c.property(.font_variant_position, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { FontVariantPosition.normal }
		.sub { FontVariantPosition.sub }
		.super { FontVariantPosition.super }
		else { FontVariantPosition.normal }
	}
}

pub fn (c &ComputedProperties) font_kerning() FontKerning {
	value := c.property(.font_kerning, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { FontKerning.auto_ }
		.normal { FontKerning.normal }
		.none_ { FontKerning.none_ }
		else { FontKerning.auto_ }
	}
}

pub fn (c &ComputedProperties) font_language_override() ?string {
	value := c.property(.font_language_override, .yes) or { return none }
	parsed_value := parse_css_value_logic(.font_language_override, value.css_text) or {
		return none
	}
	if parsed_value is StringStyleValue {
		return parsed_value.string_value()
	}
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
	value := c.property(.border_collapse, .yes) or { return .separate }
	keyword := computed_interpolation_style_value_keyword(value) or { return .separate }
	return match keyword {
		.separate { BorderCollapse.separate }
		.collapse { BorderCollapse.collapse }
		else { BorderCollapse.separate }
	}
}

pub fn (c &ComputedProperties) empty_cells() EmptyCells {
	value := c.property(.empty_cells, .yes) or { return .show }
	keyword := computed_interpolation_style_value_keyword(value) or { return .show }
	return match keyword {
		.show { EmptyCells.show }
		.hide { EmptyCells.hide }
		else { EmptyCells.show }
	}
}

pub fn (c &ComputedProperties) grid_template_areas() GridTemplateAreas {
	_ = c
	return GridTemplateAreas{}
}

pub fn (c &ComputedProperties) object_fit() ObjectFit {
	value := c.property(.object_fit, .yes) or { return .fill }
	keyword := computed_interpolation_style_value_keyword(value) or { return .fill }
	return match keyword {
		.fill { ObjectFit.fill }
		.contain { ObjectFit.contain }
		.cover { ObjectFit.cover }
		.none_ { ObjectFit.none_ }
		.scale_down { ObjectFit.scale_down }
		else { ObjectFit.fill }
	}
}

pub fn (c &ComputedProperties) object_position() Position {
	_ = c
	return Position{}
}

pub fn (c &ComputedProperties) table_layout() TableLayout {
	value := c.property(.table_layout, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { TableLayout.auto_ }
		.fixed { TableLayout.fixed }
		else { TableLayout.auto_ }
	}
}

pub fn (c &ComputedProperties) direction() Direction {
	value := c.property(.direction, .yes) or { return .ltr }
	keyword := computed_interpolation_style_value_keyword(value) or { return .ltr }
	return match keyword {
		.ltr { Direction.ltr }
		.rtl { Direction.rtl }
		else { Direction.ltr }
	}
}

pub fn (c &ComputedProperties) unicode_bidi() UnicodeBidi {
	value := c.property(.unicode_bidi, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { UnicodeBidi.normal }
		.embed { UnicodeBidi.embed }
		.isolate { UnicodeBidi.isolate }
		.bidi_override { UnicodeBidi.bidi_override }
		.isolate_override { UnicodeBidi.isolate_override }
		.plaintext { UnicodeBidi.plaintext }
		else { UnicodeBidi.normal }
	}
}

pub fn (c &ComputedProperties) writing_mode() WritingMode {
	value := c.property(.writing_mode, .yes) or { return .horizontal_tb }
	keyword := computed_interpolation_style_value_keyword(value) or { return .horizontal_tb }
	return match keyword {
		.horizontal_tb { WritingMode.horizontal_tb }
		.vertical_rl { WritingMode.vertical_rl }
		.vertical_lr { WritingMode.vertical_lr }
		.sideways_rl { WritingMode.sideways_rl }
		.sideways_lr { WritingMode.sideways_lr }
		else { WritingMode.horizontal_tb }
	}
}

pub fn (c &ComputedProperties) user_select() UserSelect {
	value := c.property(.user_select, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { UserSelect.auto_ }
		.text { UserSelect.text }
		.none_ { UserSelect.none_ }
		.all { UserSelect.all }
		.contain { UserSelect.contain }
		else { UserSelect.auto_ }
	}
}

pub fn (c &ComputedProperties) isolation() Isolation {
	value := c.property(.isolation, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { Isolation.auto_ }
		.isolate { Isolation.isolate }
		else { Isolation.auto_ }
	}
}

pub fn (c &ComputedProperties) touch_action() TouchActionData {
	value := c.property(.touch_action, .yes) or { return TouchActionData.auto_() }
	parsed_value := parse_css_value_logic(.touch_action, value.css_text) or {
		return TouchActionData.auto_()
	}
	if parsed_value is KeywordStyleValue {
		match parsed_value.keyword() {
			.auto {
				return TouchActionData.auto_()
			}
			.none_ {
				return TouchActionData.none_()
			}
			.manipulation {
				return TouchActionData{
					allow_other: false
				}
			}
			else {}
		}
	}
	if parsed_value is StyleValueList {
		mut touch_action_data := TouchActionData.none_()
		for item in parsed_value.values() {
			if item is KeywordStyleValue {
				match item.keyword() {
					.pan_x {
						touch_action_data.allow_right = true
						touch_action_data.allow_left = true
					}
					.pan_left {
						touch_action_data.allow_left = true
					}
					.pan_right {
						touch_action_data.allow_right = true
					}
					.pan_y {
						touch_action_data.allow_up = true
						touch_action_data.allow_down = true
					}
					.pan_up {
						touch_action_data.allow_up = true
					}
					.pan_down {
						touch_action_data.allow_down = true
					}
					else {}
				}
			}
		}
		return touch_action_data
	}
	return TouchActionData.auto_()
}

pub fn (c &ComputedProperties) contain() Containment {
	value := c.property(.contain, .yes) or { return Containment{} }
	parsed_value := parse_css_value_logic(.contain, value.css_text) or { return Containment{} }
	mut containment := Containment{}

	if parsed_value is KeywordStyleValue {
		match parsed_value.keyword() {
			.none_ {
				// This value indicates that the property has no effect. The element renders as normal, with no containment effects applied.
				return Containment{}
			}
			.strict {
				// This value computes to 'size layout paint style', and thus turns on all forms of containment for the element.
				containment.size_containment = true
				containment.layout_containment = true
				containment.paint_containment = true
				containment.style_containment = true
			}
			.content {
				// This value computes to 'layout paint style', and thus turns on all forms of containment except size containment for the element.
				containment.layout_containment = true
				containment.paint_containment = true
				containment.style_containment = true
			}
			.size {
				containment.size_containment = true
			}
			.inline_size {
				containment.inline_size_containment = true
			}
			.layout {
				containment.layout_containment = true
			}
			.style {
				containment.style_containment = true
			}
			.paint {
				containment.paint_containment = true
			}
			else {}
		}

		return containment
	}

	if parsed_value is StyleValueList {
		for item in parsed_value.values() {
			if item is KeywordStyleValue {
				match item.keyword() {
					.size {
						containment.size_containment = true
					}
					.inline_size {
						containment.inline_size_containment = true
					}
					.layout {
						containment.layout_containment = true
					}
					.style {
						containment.style_containment = true
					}
					.paint {
						containment.paint_containment = true
					}
					else {}
				}
			}
		}
	}

	return containment
}

pub fn (c &ComputedProperties) container_type() ContainerType {
	value := c.property(.container_type, .yes) or { return ContainerType{} }
	parsed_value := parse_css_value_logic(.container_type, value.css_text) or {
		return ContainerType{}
	}
	mut container_type := ContainerType{}

	if parsed_value is KeywordStyleValue {
		if parsed_value.keyword() == .normal {
			return container_type
		}
	}
	if parsed_value is StyleValueList {
		for item in parsed_value.values() {
			if item is KeywordStyleValue {
				match item.keyword() {
					.size {
						container_type.is_size_container = true
					}
					.inline_size {
						container_type.is_inline_size_container = true
					}
					.scroll_state {
						container_type.is_scroll_state_container = true
					}
					else {}
				}
			}
		}
	}

	return container_type
}

fn keyword_to_mix_blend_mode_for_computed_properties(keyword Keyword) ?MixBlendMode {
	return match keyword {
		.normal { MixBlendMode.normal }
		.multiply { MixBlendMode.multiply }
		.screen { MixBlendMode.screen }
		.overlay { MixBlendMode.overlay }
		.darken { MixBlendMode.darken }
		.lighten { MixBlendMode.lighten }
		.color_dodge { MixBlendMode.color_dodge }
		.color_burn { MixBlendMode.color_burn }
		.hard_light { MixBlendMode.hard_light }
		.soft_light { MixBlendMode.soft_light }
		.difference { MixBlendMode.difference }
		.exclusion { MixBlendMode.exclusion }
		.hue { MixBlendMode.hue }
		.saturation { MixBlendMode.saturation }
		.color { MixBlendMode.color }
		.luminosity { MixBlendMode.luminosity }
		.plus_darker { MixBlendMode.plus_darker }
		.plus_lighter { MixBlendMode.plus_lighter }
		else { none }
	}
}

pub fn (c &ComputedProperties) mix_blend_mode() MixBlendMode {
	value := c.property(.mix_blend_mode, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return keyword_to_mix_blend_mode_for_computed_properties(keyword) or { return .normal }
}

pub fn (c &ComputedProperties) background_blend_mode() []MixBlendMode {
	keywords := computed_interpolation_keyword_list_property(c, .background_blend_mode, [
		Keyword.normal,
	])
	mut values := []MixBlendMode{}
	for keyword in keywords {
		values << (keyword_to_mix_blend_mode_for_computed_properties(keyword) or {
			return [MixBlendMode.normal]
		})
	}
	return values
}

pub fn (c &ComputedProperties) view_transition_name() ?string {
	value := c.property(.view_transition_name, .yes) or { return none }
	parsed_value := parse_css_value_logic(.view_transition_name, value.css_text) or { return none }
	if parsed_value is CustomIdentStyleValue {
		return parsed_value.custom_ident()
	}
	return none
}

pub fn (c &ComputedProperties) animations(abstract_element &dom.AbstractElement) []ComputedAnimationProperties {
	animation_name_property := c.property(.animation_name, .yes) or {
		return []ComputedAnimationProperties{}
	}
	animation_name_values :=
		computed_interpolation_split_coordinating_list_value(animation_name_property)

	// OPTIMIZATION: If all animation names are 'none', there are no animations to process
	mut all_animation_names_are_none := true
	for value in animation_name_values {
		keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }
		if keyword != .none_ {
			all_animation_names_are_none = false
			break
		}
	}
	if all_animation_names_are_none {
		return []ComputedAnimationProperties{}
	}

	// CSS Animations are defined by binding keyframes to an element using the animation-* properties. These list-valued
	// properties, which are all longhands of the animation shorthand, form a coordinating list property group with
	// animation-name as the coordinating list base property and each item in the coordinated value list defining the
	// properties of a single animation effect.
	coordinated_properties := c.assemble_coordinated_value_list(.animation_name, [
		PropertyID.animation_duration,
		.animation_timing_function,
		.animation_iteration_count,
		.animation_direction,
		.animation_play_state,
		.animation_delay,
		.animation_fill_mode,
		.animation_composition,
		.animation_name,
		.animation_timeline,
	])

	duration_values := coordinated_properties[.animation_duration] or {
		return []ComputedAnimationProperties{}
	}
	timing_function_values := coordinated_properties[.animation_timing_function] or {
		return []ComputedAnimationProperties{}
	}
	iteration_count_values := coordinated_properties[.animation_iteration_count] or {
		return []ComputedAnimationProperties{}
	}
	direction_values := coordinated_properties[.animation_direction] or {
		return []ComputedAnimationProperties{}
	}
	play_state_values := coordinated_properties[.animation_play_state] or {
		return []ComputedAnimationProperties{}
	}
	delay_values := coordinated_properties[.animation_delay] or {
		return []ComputedAnimationProperties{}
	}
	fill_mode_values := coordinated_properties[.animation_fill_mode] or {
		return []ComputedAnimationProperties{}
	}
	composition_values := coordinated_properties[.animation_composition] or {
		return []ComputedAnimationProperties{}
	}
	name_values := coordinated_properties[.animation_name] or {
		return []ComputedAnimationProperties{}
	}
	timeline_values := coordinated_properties[.animation_timeline] or {
		return []ComputedAnimationProperties{}
	}

	mut animations := []ComputedAnimationProperties{}
	for i := 0; i < name_values.len; i++ {
		// https://drafts.csswg.org/css-animations-1/#propdef-animation-name
		// none: No keyframes are specified at all, so there will be no animation. Any other animations properties
		//       specified for this animation have no effect.
		name_keyword := computed_interpolation_style_value_keyword(name_values[i]) or {
			Keyword.invalid
		}
		if name_keyword == .none_ {
			continue
		}

		animation_duration_style_value := duration_values[i]
		duration :=
			computed_interpolation_animation_duration_to_milliseconds(animation_duration_style_value)
		duration_keyword := computed_interpolation_style_value_keyword(animation_duration_style_value) or {
			Keyword.invalid
		}

		animations << ComputedAnimationProperties{
			duration:        duration
			duration_string: if duration_keyword == .auto {
				'auto'
			} else {
				''
			}
			timing_function: EasingFunction.from_style_value(timing_function_values[i])
			iteration_count: computed_interpolation_animation_iteration_count_from_style_value(iteration_count_values[i])
			direction:       computed_interpolation_animation_direction_from_style_value(direction_values[i])
			play_state:      computed_interpolation_animation_play_state_from_style_value(play_state_values[i])
			delay:           computed_interpolation_time_value_to_milliseconds(delay_values[i])
			fill_mode:       computed_interpolation_animation_fill_mode_from_style_value(fill_mode_values[i])
			composition:     computed_interpolation_animation_composition_from_style_value(composition_values[i])
			name:            computed_interpolation_animation_name_from_style_value(name_values[i])
			timeline:        computed_interpolation_animation_timeline_from_style_value(timeline_values[i],
				abstract_element)
		}
	}

	return animations
}

fn computed_interpolation_animation_duration_to_milliseconds(value &dom.StyleValue) f64 {
	// https://drafts.csswg.org/css-animations-2/#animation-duration
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }
	if keyword == .auto {
		// For time-driven animations, equivalent to 0s.
		//
		// FIXME: For scroll-driven animations, equivalent to the duration necessary to fill the timeline in
		//        consideration of animation-range, animation-delay, and animation-iteration-count. See
		//        Scroll-driven Animations § 4.1 Finite Timeline Calculations.
		return 0
	}

	// <time [0s,∞]>
	//
	// FIXME: For scroll-driven animations, treated as auto.
	//
	// For time-driven animations, specifies the length of time that an animation takes to complete one cycle.
	// A negative <time> is invalid.
	return computed_interpolation_time_value_to_milliseconds(value)
}

fn computed_interpolation_animation_iteration_count_from_style_value(value &dom.StyleValue) f64 {
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }
	if keyword == .infinite {
		return math.inf(1)
	}

	return computed_interpolation_number_from_dom_style_value(value) or { 1.0 }
}

fn computed_interpolation_animation_direction_from_style_value(value &dom.StyleValue) AnimationDirection {
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.reverse { AnimationDirection.reverse }
		.alternate { AnimationDirection.alternate }
		.alternate_reverse { AnimationDirection.alternate_reverse }
		else { AnimationDirection.normal }
	}
}

fn computed_interpolation_animation_play_state_from_style_value(value &dom.StyleValue) AnimationPlayState {
	keyword := computed_interpolation_style_value_keyword(value) or { return .running }
	return match keyword {
		.paused { AnimationPlayState.paused }
		else { AnimationPlayState.running }
	}
}

fn computed_interpolation_animation_fill_mode_from_style_value(value &dom.StyleValue) AnimationFillMode {
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.forwards { AnimationFillMode.forwards }
		.backwards { AnimationFillMode.backwards }
		.both { AnimationFillMode.both }
		else { AnimationFillMode.none_ }
	}
}

fn computed_interpolation_animation_composition_from_style_value(value &dom.StyleValue) AnimationComposition {
	keyword := computed_interpolation_style_value_keyword(value) or { return .replace }
	return match keyword {
		.add { AnimationComposition.add }
		.accumulate { AnimationComposition.accumulate }
		else { AnimationComposition.replace }
	}
}

fn computed_interpolation_animation_name_from_style_value(value &dom.StyleValue) string {
	mut tokens := ComponentValueStream.new(parse_component_values_for_value_logic(value.css_text))
	entry := computed_interpolation_animation_name_entry_from_tokens(mut tokens) or {
		return value.css_text.trim_space()
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return value.css_text.trim_space()
	}
	computed_entry := computed_interpolation_compute_animation_name_entry(entry) or { entry }
	if computed_entry.is_custom_ident() {
		return computed_entry.as_custom_ident().custom_ident()
	}
	if computed_entry.is_string() {
		return computed_entry.as_string().string_value()
	}
	return value.css_text.trim_space()
}

fn computed_interpolation_animation_timeline_from_style_value(value &dom.StyleValue, abstract_element &dom.AbstractElement) ?&AnimationTimeline {
	_ = abstract_element
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }

	// https://drafts.csswg.org/css-animations-2/#animation-timeline
	if keyword == .auto {
		// auto
		// The animation's timeline is a DocumentTimeline, more specifically the default document timeline.
		return &AnimationTimeline{}
	}

	if keyword == .none_ {
		// none
		// The animation is not associated with a timeline.
		return none
	}

	serialized := value.css_text.trim_space()
	if serialized.starts_with('--') {
		// <dashed-ident>
		// FIXME: If a named scroll progress timeline or view progress timeline is in scope on this element, use the
		//        referenced timeline as defined in Scroll-driven Animations § Declaring a Named Timeline's Scope:
		//        the timeline-scope property. Otherwise the animation is not associated with a timeline.
	}

	if serialized.starts_with('scroll(') {
		// <scroll()>
		// Use the scroll progress timeline indicated by the given scroll() function. See Scroll-driven Animations
		// § 2.2.1 The scroll() notation.
		return &AnimationTimeline{
			kind: .scroll
		}
	}

	// <view()>
	// FIXME: Use the view progress timeline indicated by the given view() function. See Scroll-driven Animations § 3.3.1
	//        The view() notation.
	//
	// FIXME: We fall back to document timeline for now as though we don't support the `animation-timeline` property at
	//        all
	return &AnimationTimeline{}
}

pub fn (c &ComputedProperties) transitions() []TransitionProperties {
	coordinated_properties := c.assemble_coordinated_value_list(.transition_property, [
		PropertyID.transition_property,
		.transition_duration,
		.transition_timing_function,
		.transition_delay,
		.transition_behavior,
	])

	property_values := coordinated_properties[.transition_property] or {
		return []TransitionProperties{}
	}
	duration_values := coordinated_properties[.transition_duration] or {
		return []TransitionProperties{}
	}
	timing_function_values := coordinated_properties[.transition_timing_function] or {
		return []TransitionProperties{}
	}
	delay_values := coordinated_properties[.transition_delay] or { return []TransitionProperties{} }
	behavior_values := coordinated_properties[.transition_behavior] or {
		return []TransitionProperties{}
	}

	mut transitions := []TransitionProperties{cap: property_values.len}
	for i := 0; i < property_values.len; i++ {
		mut properties := []PropertyID{}
		property_name := property_values[i].css_text.trim_space()
		if !equals_ignoring_ascii_case(property_name, 'none') {
			if transition_property := property_id_from_string(property_name) {
				if !property_is_shorthand(transition_property) {
					properties << transition_property
				}
				// Boundary: shorthand expansion and logical alias mapping need the generated property tables.
			}
		}

		transitions << TransitionProperties{
			properties:          properties
			duration:            computed_interpolation_time_value_to_milliseconds(duration_values[i])
			timing_function:     EasingFunction.from_style_value(timing_function_values[i])
			delay:               computed_interpolation_time_value_to_milliseconds(delay_values[i])
			transition_behavior: computed_interpolation_transition_behavior_from_style_value(behavior_values[i])
		}
	}

	return transitions
}

fn computed_interpolation_time_value_to_milliseconds(value &dom.StyleValue) f64 {
	mut parser := Parser.from_css_text(value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	style_value := parser.parse_time_value(mut tokens) or { return 0.0 }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return 0.0
	}
	return match style_value {
		TimeStyleValue { style_value.time().to_milliseconds() }
		else { 0.0 }
	}
}

fn computed_interpolation_transition_behavior_from_style_value(value &dom.StyleValue) TransitionBehavior {
	if equals_ignoring_ascii_case(value.css_text.trim_space(), 'allow-discrete') {
		return .allow_discrete
	}
	return .normal
}

pub fn (c &ComputedProperties) display_before_box_type_transformation() Display {
	return c.display_before_box_type_transformation_
}

pub fn (mut c ComputedProperties) set_display_before_box_type_transformation(value Display) {
	c.display_before_box_type_transformation_ = value
}

fn property_id_from_transform_property(property TransformProperty) PropertyID {
	return match property {
		.transform { PropertyID.transform }
		.rotate { PropertyID.rotate }
		.scale { PropertyID.scale }
		.translate { PropertyID.translate }
	}
}

fn transformation_data_from_transformation_style_value(value TransformationStyleValue) TransformationData {
	mut values := []&dom.StyleValue{}
	for item in value.values() {
		values << dom_style_value_from_value_logic(item)
	}
	return TransformationData{
		property_id: property_id_from_transform_property(value.property_)
		values:      values
	}
}

pub fn ComputedProperties.transformations_for_style_value(value &dom.StyleValue) []TransformationData {
	parsed_value := parse_css_value_logic(.transform, value.css_text) or {
		return []TransformationData{}
	}
	if parsed_value.is_keyword() && parsed_value.to_keyword() == .none_ {
		return []TransformationData{}
	}
	if parsed_value is StyleValueList {
		mut transformations := []TransformationData{}
		for transform_value in parsed_value.values() {
			if transform_value is TransformationStyleValue {
				transformations << transformation_data_from_transformation_style_value(transform_value)
			}
		}
		return transformations
	}
	return []TransformationData{}
}

pub fn (c &ComputedProperties) transformations() []TransformationData {
	value := c.property(.transform, .yes) or { return []TransformationData{} }
	return ComputedProperties.transformations_for_style_value(value)
}

pub fn (c &ComputedProperties) transform_box() TransformBox {
	value := c.property(.transform_box, .yes) or { return .view_box }
	keyword := computed_interpolation_style_value_keyword(value) or { return .view_box }
	return match keyword {
		.content_box { TransformBox.content_box }
		.border_box { TransformBox.border_box }
		.fill_box { TransformBox.fill_box }
		.stroke_box { TransformBox.stroke_box }
		.view_box { TransformBox.view_box }
		else { TransformBox.view_box }
	}
}

pub fn (c &ComputedProperties) transform_origin() TransformOrigin {
	_ = c
	return TransformOrigin{}
}

pub fn (c &ComputedProperties) transform_style() TransformStyle {
	value := c.property(.transform_style, .yes) or { return .flat }
	keyword := computed_interpolation_style_value_keyword(value) or { return .flat }
	return match keyword {
		.flat { TransformStyle.flat }
		.preserve_3d { TransformStyle.preserve_3d }
		else { TransformStyle.flat }
	}
}

pub fn (c &ComputedProperties) rotate() ?TransformationData {
	value := c.property(.rotate, .yes) or { return none }
	parsed_value := parse_css_value_logic(.rotate, value.css_text) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
	return none
}

pub fn (c &ComputedProperties) translate() ?TransformationData {
	value := c.property(.translate, .yes) or { return none }
	parsed_value := parse_css_value_logic(.translate, value.css_text) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
	return none
}

pub fn (c &ComputedProperties) scale() ?TransformationData {
	value := c.property(.scale, .yes) or { return none }
	parsed_value := parse_css_value_logic(.scale, value.css_text) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
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
	value := c.property(.mask_type, .yes) or { return .luminance }
	keyword := computed_interpolation_style_value_keyword(value) or { return .luminance }
	return match keyword {
		.luminance { MaskType.luminance }
		.alpha { MaskType.alpha }
		else { MaskType.luminance }
	}
}

fn computed_interpolation_keyword_list_property(c &ComputedProperties, property_id PropertyID, default_keywords []Keyword) []Keyword {
	value := c.property(property_id, .yes) or { return default_keywords.clone() }
	parsed_value := parse_css_value_logic(property_id, value.css_text) or {
		return default_keywords.clone()
	}

	if parsed_value is KeywordStyleValue {
		return [parsed_value.keyword()]
	}
	if parsed_value is StyleValueList {
		mut keywords := []Keyword{}
		for item in parsed_value.values() {
			if item is KeywordStyleValue {
				keywords << item.keyword()
			} else {
				return default_keywords.clone()
			}
		}
		if keywords.len > 0 {
			return keywords
		}
	}
	return default_keywords.clone()
}

fn keyword_to_mask_composite_for_computed_properties(keyword Keyword) ?MaskComposite {
	return match keyword {
		.add { MaskComposite.add }
		.subtract { MaskComposite.subtract }
		.intersect { MaskComposite.intersect }
		.exclude { MaskComposite.exclude }
		else { none }
	}
}

pub fn (c &ComputedProperties) mask_composite() []MaskComposite {
	keywords := computed_interpolation_keyword_list_property(c, .mask_composite, [
		Keyword.add,
	])
	mut values := []MaskComposite{}
	for keyword in keywords {
		values << (keyword_to_mask_composite_for_computed_properties(keyword) or {
			return [MaskComposite.add]
		})
	}
	return values
}

fn keyword_to_mask_mode_for_computed_properties(keyword Keyword) ?MaskMode {
	return match keyword {
		.alpha { MaskMode.alpha }
		.luminance { MaskMode.luminance }
		.match_source { MaskMode.match_source }
		else { none }
	}
}

pub fn (c &ComputedProperties) mask_mode() []MaskMode {
	keywords := computed_interpolation_keyword_list_property(c, .mask_mode, [
		Keyword.match_source,
	])
	mut values := []MaskMode{}
	for keyword in keywords {
		values << (keyword_to_mask_mode_for_computed_properties(keyword) or {
			return [MaskMode.match_source]
		})
	}
	return values
}

fn keyword_to_mask_origin_for_computed_properties(keyword Keyword) ?MaskOrigin {
	return match keyword {
		.content_box { MaskOrigin.content_box }
		.padding_box { MaskOrigin.padding_box }
		.border_box { MaskOrigin.border_box }
		.fill_box { MaskOrigin.fill_box }
		.stroke_box { MaskOrigin.stroke_box }
		.view_box { MaskOrigin.view_box }
		else { none }
	}
}

pub fn (c &ComputedProperties) mask_origin() []MaskOrigin {
	keywords := computed_interpolation_keyword_list_property(c, .mask_origin, [
		Keyword.border_box,
	])
	mut values := []MaskOrigin{}
	for keyword in keywords {
		values << (keyword_to_mask_origin_for_computed_properties(keyword) or {
			return [MaskOrigin.border_box]
		})
	}
	return values
}

fn keyword_to_mask_clip_for_computed_properties(keyword Keyword) ?MaskClip {
	return match keyword {
		.content_box { MaskClip.content_box }
		.padding_box { MaskClip.padding_box }
		.border_box { MaskClip.border_box }
		.fill_box { MaskClip.fill_box }
		.stroke_box { MaskClip.stroke_box }
		.view_box { MaskClip.view_box }
		.no_clip { MaskClip.no_clip }
		else { none }
	}
}

pub fn (c &ComputedProperties) mask_clip() []MaskClip {
	keywords := computed_interpolation_keyword_list_property(c, .mask_clip, [
		Keyword.border_box,
	])
	mut values := []MaskClip{}
	for keyword in keywords {
		values << (keyword_to_mask_clip_for_computed_properties(keyword) or {
			return [MaskClip.border_box]
		})
	}
	return values
}

fn keyword_to_border_image_repeat_for_computed_properties(keyword Keyword) ?BorderImageRepeat {
	return match keyword {
		.stretch { BorderImageRepeat.stretch }
		.repeat { BorderImageRepeat.repeat }
		.round { BorderImageRepeat.round }
		.space { BorderImageRepeat.space }
		else { none }
	}
}

pub fn (c &ComputedProperties) border_image_repeat() []BorderImageRepeat {
	keywords := computed_interpolation_keyword_list_property(c, .border_image_repeat, [
		Keyword.stretch,
	])
	mut values := []BorderImageRepeat{}
	for keyword in keywords {
		values << (keyword_to_border_image_repeat_for_computed_properties(keyword) or {
			return [BorderImageRepeat.stretch]
		})
	}
	return values
}

fn computed_interpolation_repeat_style_list_property(c &ComputedProperties, property_id PropertyID) []RepeatStyleStyleValue {
	default_repeat := RepeatStyleStyleValue.create(.repeat, .repeat)
	value := c.property(property_id, .yes) or { return [default_repeat] }
	parsed_value := parse_css_value_logic(property_id, value.css_text) or {
		return [default_repeat]
	}

	if parsed_value is RepeatStyleStyleValue {
		return [parsed_value]
	}
	if parsed_value is StyleValueList {
		mut repeat_styles := []RepeatStyleStyleValue{}
		for item in parsed_value.values() {
			if item is RepeatStyleStyleValue {
				repeat_styles << item
			} else {
				return [default_repeat]
			}
		}
		if repeat_styles.len > 0 {
			return repeat_styles
		}
	}
	return [default_repeat]
}

pub fn (c &ComputedProperties) background_repeat() []RepeatStyleStyleValue {
	return computed_interpolation_repeat_style_list_property(c, .background_repeat)
}

pub fn (c &ComputedProperties) mask_repeat() []RepeatStyleStyleValue {
	return computed_interpolation_repeat_style_list_property(c, .mask_repeat)
}

fn keyword_to_timeline_axis_for_computed_properties(keyword Keyword) ?TimelineAxis {
	return match keyword {
		.block { TimelineAxis.block }
		.inline_ { TimelineAxis.inline_ }
		.x { TimelineAxis.x }
		.y { TimelineAxis.y }
		else { none }
	}
}

fn computed_interpolation_timeline_axis_property(c &ComputedProperties, property_id PropertyID) []TimelineAxis {
	keywords := computed_interpolation_keyword_list_property(c, property_id, [
		Keyword.block,
	])
	mut values := []TimelineAxis{}
	for keyword in keywords {
		values << (keyword_to_timeline_axis_for_computed_properties(keyword) or {
			return [TimelineAxis.block]
		})
	}
	return values
}

pub fn (c &ComputedProperties) scroll_timeline_axis() []TimelineAxis {
	return computed_interpolation_timeline_axis_property(c, .scroll_timeline_axis)
}

pub fn (c &ComputedProperties) view_timeline_axis() []TimelineAxis {
	return computed_interpolation_timeline_axis_property(c, .view_timeline_axis)
}

fn keyword_to_position_visibility_for_computed_properties(keyword Keyword) ?PositionVisibility {
	return match keyword {
		.always { PositionVisibility.always }
		.anchors_valid { PositionVisibility.anchors_valid }
		.anchors_visible { PositionVisibility.anchors_visible }
		.no_overflow { PositionVisibility.no_overflow }
		else { none }
	}
}

pub fn (c &ComputedProperties) position_visibility() []PositionVisibility {
	keywords := computed_interpolation_keyword_list_property(c, .position_visibility, [
		Keyword.anchors_visible,
	])
	mut values := []PositionVisibility{}
	for keyword in keywords {
		values << (keyword_to_position_visibility_for_computed_properties(keyword) or {
			return [PositionVisibility.anchors_visible]
		})
	}
	return values
}

fn (c &ComputedProperties) opacity_property(property_id PropertyID, default_value f32) f32 {
	if value := c.property(property_id, .yes) {
		if number := computed_interpolation_number_from_dom_style_value(value) {
			return f32(number)
		}
	}
	return default_value
}

pub fn (c &ComputedProperties) stop_opacity() f32 {
	return c.opacity_property(.stop_opacity, 1)
}

pub fn (c &ComputedProperties) fill_opacity() f32 {
	return c.opacity_property(.fill_opacity, 1)
}

pub fn (c &ComputedProperties) stroke_dasharray() []StrokeDasharrayItem {
	_ = c
	return []StrokeDasharrayItem{}
}

pub fn (c &ComputedProperties) stroke_linecap() StrokeLinecap {
	value := c.property(.stroke_linecap, .yes) or { return .butt }
	keyword := computed_interpolation_style_value_keyword(value) or { return .butt }
	return match keyword {
		.butt { StrokeLinecap.butt }
		.round { StrokeLinecap.round }
		.square { StrokeLinecap.square }
		else { StrokeLinecap.butt }
	}
}

pub fn (c &ComputedProperties) stroke_linejoin() StrokeLinejoin {
	value := c.property(.stroke_linejoin, .yes) or { return .miter }
	keyword := computed_interpolation_style_value_keyword(value) or { return .miter }
	return match keyword {
		.miter { StrokeLinejoin.miter }
		.round { StrokeLinejoin.round }
		.bevel { StrokeLinejoin.bevel }
		else { StrokeLinejoin.miter }
	}
}

pub fn (c &ComputedProperties) stroke_miterlimit() f64 {
	if value := c.property(.stroke_miterlimit, .yes) {
		if number := computed_interpolation_number_from_dom_style_value(value) {
			return number
		}
	}
	return 4
}

pub fn (c &ComputedProperties) stroke_opacity() f32 {
	return c.opacity_property(.stroke_opacity, 1)
}

pub fn (c &ComputedProperties) fill_rule() FillRule {
	value := c.property(.fill_rule, .yes) or { return .nonzero }
	keyword := computed_interpolation_style_value_keyword(value) or { return .nonzero }
	return match keyword {
		.nonzero { FillRule.nonzero }
		.evenodd { FillRule.evenodd }
		else { FillRule.nonzero }
	}
}

pub fn (c &ComputedProperties) clip_rule() ClipRule {
	value := c.property(.clip_rule, .yes) or { return .nonzero }
	keyword := computed_interpolation_style_value_keyword(value) or { return .nonzero }
	return match keyword {
		.nonzero { ClipRule.nonzero }
		.evenodd { ClipRule.evenodd }
		else { ClipRule.nonzero }
	}
}

pub fn (c &ComputedProperties) flood_opacity() f32 {
	return c.opacity_property(.flood_opacity, 1)
}

pub fn (c &ComputedProperties) shape_rendering() ShapeRendering {
	value := c.property(.shape_rendering, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { ShapeRendering.auto_ }
		.optimizespeed { ShapeRendering.optimize_speed }
		.crispedges { ShapeRendering.crisp_edges }
		.geometricprecision { ShapeRendering.geometric_precision }
		else { ShapeRendering.auto_ }
	}
}

fn initial_paint_order_for_computed_properties() PaintOrderList {
	return PaintOrderList{
		order: [PaintOrder.fill, .stroke, .markers]
	}
}

fn keyword_to_paint_order_for_computed_properties(keyword Keyword) ?PaintOrder {
	return match keyword {
		.fill { PaintOrder.fill }
		.stroke { PaintOrder.stroke }
		.markers { PaintOrder.markers }
		else { none }
	}
}

fn paint_order_from_sum_for_computed_properties(value int) PaintOrder {
	return match value {
		0 { PaintOrder.fill }
		1 { PaintOrder.stroke }
		else { PaintOrder.markers }
	}
}

pub fn (c &ComputedProperties) paint_order() PaintOrderList {
	value := c.property(.paint_order, .yes) or {
		return initial_paint_order_for_computed_properties()
	}
	parsed_value := parse_css_value_logic(.paint_order, value.css_text) or {
		return initial_paint_order_for_computed_properties()
	}

	if parsed_value is KeywordStyleValue {
		keyword := parsed_value.keyword()
		if keyword == .normal {
			return initial_paint_order_for_computed_properties()
		}
		paint_order_keyword := keyword_to_paint_order_for_computed_properties(keyword) or {
			return initial_paint_order_for_computed_properties()
		}
		match paint_order_keyword {
			.fill {
				return initial_paint_order_for_computed_properties()
			}
			.stroke {
				return PaintOrderList{
					order: [PaintOrder.stroke, .fill, .markers]
				}
			}
			.markers {
				return PaintOrderList{
					order: [PaintOrder.markers, .fill, .stroke]
				}
			}
		}
	}

	if parsed_value is StyleValueList {
		values := parsed_value.values()
		if values.len != 2 {
			return initial_paint_order_for_computed_properties()
		}

		mut paint_order_list := PaintOrderList{
			order: []PaintOrder{len: 3}
		}

		// We use the sum of the keyword values to infer what the missing keyword is. Since each keyword can only appear in
		// the list once, the sum of their values will always be 3.
		mut sum := 0
		for i in 0 .. 2 {
			item := values[i]
			if item is KeywordStyleValue {
				paint_order_keyword := keyword_to_paint_order_for_computed_properties(item.keyword()) or {
					return initial_paint_order_for_computed_properties()
				}
				sum += int(paint_order_keyword)
				paint_order_list.order[i] = paint_order_keyword
			} else {
				return initial_paint_order_for_computed_properties()
			}
		}
		if sum > 3 {
			return initial_paint_order_for_computed_properties()
		}
		paint_order_list.order[2] = paint_order_from_sum_for_computed_properties(3 - sum)
		return paint_order_list
	}

	return initial_paint_order_for_computed_properties()
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
	if value := c.property(.math_style, .yes) {
		if math_style := computed_interpolation_math_style_from_dom_style_value(value) {
			return math_style
		}
	}
	return .normal
}

pub fn (c &ComputedProperties) math_shift() MathShift {
	value := c.property(.math_shift, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.normal { MathShift.normal }
		.compact { MathShift.compact }
		else { MathShift.normal }
	}
}

pub fn (c &ComputedProperties) math_depth() int {
	if value := c.property(.math_depth, .yes) {
		if integer := computed_interpolation_integer_from_dom_style_value(value) {
			return int(integer)
		}
	}
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
	if value := c.property(.font_weight, .yes) {
		if number := computed_interpolation_number_from_dom_style_value(value) {
			return number
		}
	}
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

pub fn (c &ComputedProperties) font_optical_sizing() FontOpticalSizing {
	value := c.property(.font_optical_sizing, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { FontOpticalSizing.auto_ }
		.none_ { FontOpticalSizing.none_ }
		else { FontOpticalSizing.auto_ }
	}
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
	value := c.property(.position, .yes) or { return .static_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .static_ }
	return match keyword {
		.static_ { Positioning.static_ }
		.relative { Positioning.relative }
		.absolute { Positioning.absolute }
		.sticky { Positioning.sticky }
		.fixed { Positioning.fixed }
		else { Positioning.static_ }
	}
}

pub fn (c &ComputedProperties) z_index() ?int {
	value := c.property(.z_index, .yes) or { return none }
	if computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .auto {
		return none
	}

	parsed_value := parse_css_value_logic(.z_index, value.css_text) or { return none }
	if parsed_value.is_integer() || parsed_value.is_calculated() {
		// Clamp z-index to the range of a signed 32-bit integer for consistency with other engines.
		number := int_from_style_value(parsed_value)
		if number >= i64(2147483647) {
			return 2147483647
		}
		if number <= i64(-2147483647 - 1) {
			return -2147483647 - 1
		}
		return int(number)
	}

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
	value := c.property(.scrollbar_width, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { ScrollbarWidth.auto_ }
		.thin { ScrollbarWidth.thin }
		.none_ { ScrollbarWidth.none_ }
		else { ScrollbarWidth.auto_ }
	}
}

pub fn (c &ComputedProperties) scroll_behavior() ScrollBehavior {
	value := c.property(.scroll_behavior, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { ScrollBehavior.auto_ }
		.smooth { ScrollBehavior.smooth }
		else { ScrollBehavior.auto_ }
	}
}

pub fn (c &ComputedProperties) resize() Resize {
	value := c.property(.resize, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.none_ { Resize.none_ }
		.both { Resize.both }
		.horizontal { Resize.horizontal }
		.vertical { Resize.vertical }
		.block { Resize.block }
		.inline_ { Resize.inline_ }
		else { Resize.none_ }
	}
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
		.animation_composition, .animation_delay, .animation_direction, .animation_duration,
		.animation_fill_mode, .animation_iteration_count, .animation_name, .animation_play_state,
		.animation_timeline, .animation_timing_function, .direction, .font_feature_settings,
		.font_variation_settings, .math_depth, .math_style, .contain, .container_type, .math_shift,
		.scroll_behavior, .scroll_timeline_axis, .scroll_timeline_name, .timeline_scope,
		.transition_behavior, .transition_delay, .transition_duration, .transition_property,
		.transition_timing_function, .unicode_bidi, .view_timeline_axis, .view_timeline_inset,
		.view_timeline_name, .will_change, .writing_mode, .resize {
			.none_
		}
		.accent_color, .aspect_ratio, .background_color, .border_block_end_color,
		.border_block_end_width, .border_block_start_color, .border_block_start_width,
		.border_bottom_color, .border_bottom_width, .border_bottom_left_radius,
		.border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius,
		.border_image_outset, .border_image_slice, .border_image_width, .border_inline_end_color,
		.border_inline_end_width, .border_inline_start_color, .border_inline_start_width,
		.border_left_color, .border_left_width, .border_right_color, .border_right_width,
		.border_start_end_radius, .border_start_start_radius, .border_top_color, .border_top_width,
		.border_top_left_radius, .border_top_right_radius, .border_spacing, .block_size, .bottom,
		.caret_color, .color, .corner_bottom_left_shape, .corner_bottom_right_shape,
		.corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape,
		.corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .fill_opacity,
		.flood_color, .flood_opacity, .font_style, .font_weight, .font_width, .flex_grow,
		.flex_shrink, .column_count, .column_width, .column_height, .column_gap, .row_gap, .height,
		.inline_size, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
		.left, .letter_spacing, .line_height, .margin_block_end, .margin_block_start,
		.margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right,
		.margin_top, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size,
		.min_height, .min_inline_size, .min_width, .opacity, .order, .orphans, .widows,
		.outline_color, .outline_offset, .outline_style, .outline_width,
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end,
		.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
		.padding_left, .padding_right, .padding_top, .perspective, .perspective_origin, .right,
		.scrollbar_color, .shape_margin, .shape_image_threshold, .stop_color, .stop_opacity,
		.stroke_miterlimit, .stroke_opacity, .stroke_width, .stroke_dashoffset, .tab_size,
		.text_decoration_color, .text_decoration_thickness, .text_underline_offset, .text_indent,
		.top, .transform_origin, .vertical_align, .width, .cx, .cy, .x, .y, .r, .rx, .ry, .rotate,
		.scale, .transform, .translate, .webkit_text_fill_color, .word_spacing, .scrollbar_width,
		.z_index, .flex_basis, .clip, .grid_auto_columns, .grid_auto_rows, .counter_increment,
		.counter_reset, .counter_set, .font_size, .fill, .stroke, .clip_path, .shape_outside {
			.by_computed_value
		}
		.content_visibility, .visibility, .display, .box_shadow, .text_shadow, .stroke_dasharray,
		.grid_template_columns, .grid_template_rows, .filter, .backdrop_filter {
			.custom
		}
		.background_clip, .background_origin, .background_position_x, .background_position_y,
		.background_size, .mask_position, .mask_size {
			.repeatable_list
		}
		.object_position {
			.repeatable_list
		}
		.anchor_name, .anchor_scope, .background_attachment, .background_blend_mode,
		.background_image, .background_repeat, .border_block_end_style, .border_block_start_style,
		.border_bottom_style, .border_collapse, .border_image_repeat, .border_image_source,
		.border_inline_end_style, .border_inline_start_style, .border_left_style,
		.border_right_style, .border_top_style, .box_sizing, .caption_side, .clear, .clip_rule,
		.color_interpolation, .color_scheme, .empty_cells, .fill_rule, .float_, .font_kerning,
		.font_language_override, .font_optical_sizing, .font_variant_caps, .font_variant_emoji,
		.font_variant_position, .flex_direction, .flex_wrap, .align_content, .align_items,
		.align_self, .justify_content, .justify_items, .justify_self, .appearance, .column_span,
		.image_rendering, .isolation, .list_style_image, .list_style_position, .mask_clip,
		.mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_repeat, .mask_type,
		.mix_blend_mode, .object_fit, .overflow_block, .overflow_inline, .overflow_x, .overflow_y,
		.overflow_wrap, .pointer_events, .position, .position_anchor, .position_area,
		.position_try_fallbacks, .position_try_order, .position_visibility, .paint_order,
		.scrollbar_gutter, .shape_rendering, .stroke_linecap, .stroke_linejoin, .table_layout,
		.text_align, .text_anchor, .text_decoration_line, .text_decoration_style, .text_justify,
		.text_overflow, .text_rendering, .text_transform, .text_underline_position,
		.text_wrap_mode, .text_wrap_style, .transform_box, .transform_style, .touch_action,
		.user_select, .view_transition_name, .white_space_collapse, .white_space_trim, .word_break,
		.dominant_baseline, .quotes, .list_style_type, .font_family, .grid_column_start,
		.grid_column_end, .grid_row_start, .grid_row_end, .grid_auto_flow, .grid_template_areas,
		.cursor, .font_variant_ligatures, .font_variant_numeric, .font_variant_east_asian, .content,
		.font_variant_alternates {
			.discrete
		}
		else {
			// Shorthands are expanded before reaching this longhand-only classifier.
			.none_
		}
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
			if property_id == .visibility {
				// https://drafts.csswg.org/web-animations-1/#animating-visibility
				// For the visibility property, visible is interpolated as a discrete step where values of p between 0 and 1 map to visible and other values of p map to the closer endpoint.
				// If neither value is visible, then discrete animation is used.
				if from.css_text == to.css_text {
					return unsafe { from }
				}

				from_is_visible := computed_interpolation_style_value_keyword(from) or {
					Keyword.invalid
				} == .visible
				to_is_visible := computed_interpolation_style_value_keyword(to) or {
					Keyword.invalid
				} == .visible
				if from_is_visible || to_is_visible {
					if delta <= 0 {
						return unsafe { from }
					}
					if delta >= 1 {
						return unsafe { to }
					}
					visible_value := if from_is_visible { from } else { to }
					return unsafe { visible_value }
				}

				return interpolate_discrete(from, to, delta, allow_discrete)
			}
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
		.accent_color, .anchor_scope, .animation_composition, .animation_delay,
		.animation_direction, .animation_duration, .animation_fill_mode,
		.animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline,
		.animation_timing_function, .background_attachment, .background_blend_mode,
		.background_clip, .background_color, .background_image, .background_origin,
		.background_position_x, .background_position_y, .background_repeat, .background_size,
		.border_block_end_color, .border_block_start_color, .border_bottom_color,
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius,
		.border_end_start_radius, .border_image_outset, .border_image_repeat, .border_image_slice,
		.border_image_source, .border_image_width, .border_inline_end_color,
		.border_inline_start_color, .border_left_color, .border_right_color,
		.border_start_end_radius, .border_start_start_radius, .border_top_color,
		.border_top_left_radius, .border_top_right_radius, .caret_color, .clip_rule, .color,
		.color_interpolation, .color_scheme, .content_visibility, .corner_bottom_left_shape,
		.corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape,
		.corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape,
		.corner_top_right_shape, .fill_opacity, .fill_rule, .flood_color, .flood_opacity,
		.font_feature_settings, .font_variation_settings, .font_weight, .font_width,
		.image_rendering, .line_height, .mask_clip, .mask_composite, .mask_image, .mask_mode,
		.mask_origin, .mask_position, .mask_repeat, .mask_size, .mask_type, .math_depth,
		.math_style, .mix_blend_mode, .object_fit, .object_position, .opacity, .outline_color,
		.outline_offset, .outline_style, .outline_width, .perspective_origin, .pointer_events,
		.scrollbar_color, .scrollbar_gutter, .shape_image_threshold, .stop_color, .stop_opacity,
		.stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity, .stroke_width,
		.stroke_dashoffset, .rotate, .scale, .scroll_timeline_axis, .scroll_timeline_name,
		.timeline_scope, .transform, .transform_box, .transform_origin, .transition_behavior,
		.transition_delay, .transition_duration, .transition_property, .transition_timing_function,
		.translate, .touch_action, .user_select, .view_timeline_axis, .view_timeline_inset,
		.view_timeline_name, .view_transition_name, .will_change, .scrollbar_width,
		.scroll_behavior, .resize, .text_decoration_color, .text_decoration_line,
		.text_decoration_style, .text_decoration_thickness, .text_overflow, .text_rendering,
		.webkit_text_fill_color, .z_index, .box_shadow, .text_shadow, .clip, .stroke_dasharray,
		.filter, .backdrop_filter, .cursor, .fill, .stroke, .clip_path {
			false
		}
		.anchor_name, .aspect_ratio, .block_size, .bottom, .border_block_end_style,
		.border_block_end_width, .border_block_start_style, .border_block_start_width,
		.border_bottom_style, .border_bottom_width, .border_collapse, .border_inline_end_style,
		.border_inline_end_width, .border_inline_start_style, .border_inline_start_width,
		.border_left_style, .border_left_width, .border_right_style, .border_right_width,
		.border_spacing, .border_top_style, .border_top_width, .box_sizing, .caption_side, .clear,
		.direction, .empty_cells, .float_, .font_kerning, .font_language_override,
		.font_optical_sizing, .font_style, .font_variant_caps, .font_variant_emoji,
		.font_variant_position, .flex_grow, .flex_shrink, .flex_direction, .flex_wrap,
		.align_content, .align_items, .align_self, .justify_content, .justify_items, .justify_self,
		.appearance, .column_span, .column_count, .column_width, .column_height, .column_gap,
		.row_gap, .contain, .container_type, .height, .inline_size, .inset_block_end,
		.inset_block_start, .inset_inline_end, .inset_inline_start, .isolation, .left,
		.letter_spacing, .list_style_image, .list_style_position, .margin_block_end,
		.margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start,
		.margin_left, .margin_right, .margin_top, .math_shift, .max_block_size, .max_height,
		.max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width,
		.order, .orphans, .widows, .overflow_block, .overflow_clip_margin_block_end,
		.overflow_clip_margin_block_start, .overflow_clip_margin_bottom,
		.overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start,
		.overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top,
		.overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding_block_end,
		.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
		.padding_left, .padding_right, .padding_top, .paint_order, .perspective, .position,
		.position_anchor, .position_area, .position_try_fallbacks, .position_try_order,
		.position_visibility, .right, .shape_margin, .shape_rendering, .tab_size, .table_layout,
		.text_align, .text_anchor, .text_justify, .text_underline_offset, .text_underline_position,
		.text_indent, .text_transform, .text_wrap_mode, .text_wrap_style, .top, .transform_style,
		.unicode_bidi, .vertical_align, .visibility, .white_space_collapse, .white_space_trim,
		.width, .word_break, .word_spacing, .writing_mode, .cx, .cy, .x, .y, .r, .rx, .ry,
		.dominant_baseline, .display, .flex_basis, .quotes, .list_style_type, .font_family,
		.grid_column_start, .grid_column_end, .grid_row_start, .grid_row_end, .grid_auto_flow,
		.grid_auto_columns, .grid_auto_rows, .grid_template_columns, .grid_template_rows,
		.grid_template_areas, .counter_increment, .counter_reset, .counter_set, .font_size,
		.font_variant_ligatures, .font_variant_numeric, .font_variant_east_asian, .shape_outside,
		.content, .font_variant_alternates {
			true
		}
		else {
			// Shorthands are expanded before reaching this longhand-only classifier.
			false
		}
	}
}

fn property_affects_stacking_context_generated_metadata_boundary(property_id PropertyID) bool {
	return match property_id {
		// None of the currently translated longhands maps to the C++ generated
		// affects-stacking-context metadata. ContentVisibility is handled by the
		// full-invalidation branch above.
		.contain, .container_type, .mask_image, .mix_blend_mode, .opacity, .perspective, .rotate,
		.scale, .transform, .translate, .view_transition_name, .will_change, .z_index {
			true
		}
		.accent_color, .anchor_name, .anchor_scope, .animation_composition, .animation_delay,
		.animation_direction, .animation_duration, .animation_fill_mode,
		.animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline,
		.animation_timing_function, .aspect_ratio, .background_attachment, .background_blend_mode,
		.background_clip, .background_color, .background_image, .background_origin,
		.background_position_x, .background_position_y, .background_repeat, .background_size,
		.border_bottom_color, .border_bottom_style, .border_bottom_width,
		.border_bottom_left_radius, .border_bottom_right_radius, .border_collapse,
		.border_image_outset, .border_image_repeat, .border_image_slice, .border_image_source,
		.border_image_width, .border_left_color, .border_left_style, .border_left_width,
		.border_right_color, .border_right_style, .border_right_width, .border_top_color,
		.border_top_style, .border_top_width, .border_top_left_radius, .border_top_right_radius,
		.box_sizing, .caption_side, .caret_color, .clear, .clip_rule, .color, .color_interpolation,
		.color_scheme, .content_visibility, .corner_bottom_left_shape, .corner_bottom_right_shape,
		.corner_top_left_shape, .corner_top_right_shape, .fill_opacity, .fill_rule, .flood_color,
		.flood_opacity, .float_, .direction, .empty_cells, .font_feature_settings, .font_kerning,
		.font_language_override, .font_optical_sizing, .font_style, .font_variant_caps,
		.font_variant_emoji, .font_variant_position, .font_variation_settings, .font_weight,
		.font_width, .flex_grow, .flex_shrink, .flex_direction, .flex_wrap, .align_content,
		.align_items, .align_self, .justify_content, .justify_items, .justify_self, .appearance,
		.column_span, .column_count, .column_width, .column_height, .column_gap, .row_gap,
		.image_rendering, .isolation, .letter_spacing, .line_height, .list_style_image,
		.list_style_position, .mask_clip, .mask_composite, .mask_mode, .mask_origin,
		.mask_position, .mask_repeat, .mask_size, .mask_type, .math_depth, .math_shift,
		.math_style, .object_fit, .object_position, .order, .orphans, .widows, .outline_color,
		.outline_offset, .outline_style, .outline_width, .overflow_block,
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap,
		.overflow_x, .overflow_y, .perspective_origin, .pointer_events, .position_area,
		.position_try_fallbacks, .position_try_order, .paint_order, .scroll_behavior,
		.scroll_timeline_axis, .scrollbar_color, .scrollbar_gutter, .shape_margin,
		.shape_rendering, .position, .position_anchor, .position_visibility, .scroll_timeline_name,
		.shape_image_threshold, .stop_color, .stop_opacity, .stroke_linecap, .stroke_linejoin,
		.stroke_miterlimit, .stroke_opacity, .stroke_width, .stroke_dashoffset, .tab_size,
		.table_layout, .text_align, .text_anchor, .text_decoration_color, .text_decoration_line,
		.text_decoration_style, .text_decoration_thickness, .text_underline_offset,
		.text_underline_position, .text_indent, .text_justify, .text_overflow, .text_rendering,
		.text_transform, .text_wrap_mode, .text_wrap_style, .timeline_scope, .transform_box,
		.transform_origin, .transform_style, .touch_action, .transition_behavior,
		.transition_delay, .transition_duration, .transition_property, .transition_timing_function,
		.unicode_bidi, .user_select, .vertical_align, .view_timeline_axis, .view_timeline_inset,
		.view_timeline_name, .writing_mode, .scrollbar_width, .resize, .visibility,
		.webkit_text_fill_color, .white_space_collapse, .white_space_trim, .word_break,
		.word_spacing, .cx, .cy, .x, .y, .r, .rx, .ry {
			false
		}
		else {
			false
		}
	}
}

fn is_stacking_context_creating_value_boundary(property_id PropertyID, value ?&dom.StyleValue) bool {
	if value == none {
		return false
	}
	if property_id == .mix_blend_mode {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } != .normal
	}
	if property_id == .perspective {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } != .none_
	}
	if property_id == .z_index {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } != .auto
	}
	// Boundary: the C++ implementation checks typed DOM StyleValue subclasses
	// (opacity numbers, keywords, lists, transforms, filters). The V DOM
	// StyleValue representation does not expose those queries yet.
	return true
}

fn property_rebuilds_accumulated_visual_contexts(property_id PropertyID) bool {
	return match property_id {
		// The translated PropertyID enum does not yet include clip or filter.
		.mask_image, .mix_blend_mode, .opacity, .perspective, .perspective_origin, .rotate, .scale,
		.transform, .transform_origin, .translate {
			true
		}
		.accent_color, .anchor_name, .anchor_scope, .animation_composition, .animation_delay,
		.animation_direction, .animation_duration, .animation_fill_mode,
		.animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline,
		.animation_timing_function, .aspect_ratio, .background_attachment, .background_blend_mode,
		.background_clip, .background_color, .background_image, .background_origin,
		.background_position_x, .background_position_y, .background_repeat, .background_size,
		.border_bottom_color, .border_bottom_style, .border_bottom_width,
		.border_bottom_left_radius, .border_bottom_right_radius, .border_collapse,
		.border_image_outset, .border_image_repeat, .border_image_slice, .border_image_source,
		.border_image_width, .border_left_color, .border_left_style, .border_left_width,
		.border_right_color, .border_right_style, .border_right_width, .border_top_color,
		.border_top_style, .border_top_width, .border_top_left_radius, .border_top_right_radius,
		.box_sizing, .caption_side, .caret_color, .clear, .clip_rule, .color, .color_interpolation,
		.color_scheme, .content_visibility, .corner_bottom_left_shape, .corner_bottom_right_shape,
		.corner_top_left_shape, .corner_top_right_shape, .fill_opacity, .fill_rule, .flood_color,
		.flood_opacity, .float_, .direction, .empty_cells, .font_feature_settings, .font_kerning,
		.font_language_override, .font_optical_sizing, .font_style, .font_variant_caps,
		.font_variant_emoji, .font_variant_position, .font_variation_settings, .font_weight,
		.font_width, .flex_grow, .flex_shrink, .flex_direction, .flex_wrap, .align_content,
		.align_items, .align_self, .justify_content, .justify_items, .justify_self, .appearance,
		.column_span, .column_count, .column_width, .column_height, .column_gap, .row_gap,
		.contain, .container_type, .image_rendering, .isolation, .letter_spacing, .line_height,
		.list_style_image, .list_style_position, .mask_clip, .mask_composite, .mask_mode,
		.mask_origin, .mask_position, .mask_repeat, .mask_size, .mask_type, .math_depth,
		.math_shift, .math_style, .object_fit, .object_position, .order, .orphans, .widows,
		.outline_color, .outline_offset, .outline_style, .outline_width, .overflow_block,
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap,
		.overflow_x, .overflow_y, .pointer_events, .position_area, .position_try_fallbacks,
		.position_try_order, .scroll_behavior, .scroll_timeline_axis, .scrollbar_color,
		.scrollbar_gutter, .shape_margin, .shape_rendering, .position, .position_anchor,
		.position_visibility, .scroll_timeline_name, .shape_image_threshold, .stop_color,
		.stop_opacity, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity,
		.stroke_width, .stroke_dashoffset, .tab_size, .table_layout, .text_align, .text_anchor,
		.text_justify, .text_overflow, .text_decoration_color, .text_decoration_line,
		.text_decoration_style, .text_decoration_thickness, .text_underline_offset,
		.text_underline_position, .text_indent, .paint_order, .text_rendering, .text_transform,
		.text_wrap_mode, .text_wrap_style, .timeline_scope, .transform_box, .transform_style,
		.touch_action, .transition_behavior, .transition_delay, .transition_duration,
		.transition_property, .transition_timing_function, .unicode_bidi, .user_select,
		.vertical_align, .view_timeline_axis, .view_timeline_inset, .view_timeline_name,
		.view_transition_name, .will_change, .writing_mode, .scrollbar_width, .resize, .visibility,
		.webkit_text_fill_color, .white_space_collapse, .white_space_trim, .word_break,
		.word_spacing, .z_index, .cx, .cy, .x, .y, .r, .rx, .ry {
			false
		}
		else {
			false
		}
	}
}

fn property_requires_full_invalidation(property_id PropertyID) bool {
	return match property_id {
		// C++: Display, Position, Content, ContentVisibility, OverflowX, OverflowY.
		// Only these represented properties are currently present in the V PropertyID enum.
		.content_visibility, .overflow_block, .overflow_inline, .overflow_x, .overflow_y,
		.position {
			true
		}
		else {
			false
		}
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

	// NOTE: If the text-transform property changes, it may affect layout. Furthermore, since the
	//       Layout::TextNode caches the post-transform text, we have to update the layout tree.
	if property_id == .text_transform {
		invalidation.rebuild_layout_tree = true
		invalidation.relayout = true
		invalidation.repaint = true
		return invalidation
	}

	// OPTIMIZATION: Special handling for CSS `visibility`:
	if property_id == .visibility {
		// We don't need to relayout if the visibility changes from visible to hidden or vice versa. Only collapse requires relayout.
		old_is_collapse := if old := old_value {
			computed_interpolation_style_value_keyword(old) or { Keyword.invalid } == .collapse
		} else {
			false
		}
		new_is_collapse := if new := new_value {
			computed_interpolation_style_value_keyword(new) or { Keyword.invalid } == .collapse
		} else {
			false
		}
		if old_is_collapse != new_is_collapse {
			invalidation.relayout = true
		}
		// Of course, we still have to repaint on any visibility change.
		invalidation.repaint = true
	} else if property_affects_layout_generated_metadata_boundary(property_id) {
		invalidation.relayout = true
	}

	if property_affects_stacking_context_generated_metadata_boundary(property_id) {
		// z-index changes always require rebuilding the stacking context tree because
		// the value determines painting order within the tree, not just whether a
		// stacking context is created. During tree construction, elements with
		// z-index 0/auto are placed in m_positioned_descendants_and_stacking_contexts_
		// with_stack_level_0, while elements with non-zero z-index are painted from
		// m_children (negative z-index at step 3, positive at step 9 of CSS 2.1
		// Appendix E). If z-index changes between non-auto values (e.g. 0 -> 10),
		// both old and new values create stacking contexts, so the generic optimization
		// below would skip the rebuild. But the element remains in the wrong list,
		// causing it to be painted from both step 8 (m_positioned_descendants) and
		// step 9 (m_children with z >= 1), resulting in double painting.
		if property_id == .z_index {
			invalidation.rebuild_stacking_context_tree = true
		} else {
			// OPTIMIZATION: Only rebuild stacking context tree when property crosses from a neutral value
			// (doesn't create stacking context) to a creating value or vice versa.
			old_creates := is_stacking_context_creating_value_boundary(property_id, old_value)
			new_creates := is_stacking_context_creating_value_boundary(property_id, new_value)
			if old_creates != new_creates {
				invalidation.rebuild_stacking_context_tree = true
			}
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
	has_result_cache_                      map[string]HasMatchResult
}

pub fn StyleComputer.new(document &dom.Document) &StyleComputer {
	return &StyleComputer{
		document_:      unsafe { document }
		viewport_rect_: css_pixel_rect_from_dom_rect(document.viewport_rect())
	}
}

pub fn StyleComputer.for_each_property_expanding_shorthands(property_id PropertyID, value &dom.StyleValue, set_longhand_property fn (PropertyID, &dom.StyleValue)) {
	// Cascaded properties store opaque dom.StyleValues that only carry the serialized text. To expand a shorthand we
	// re-parse that text into a typed ShorthandStyleValue and run the typed expansion, bridging each longhand back to
	// a dom.StyleValue.
	if property_is_shorthand(property_id) {
		if typed_value := parse_css_value_logic(property_id, value.css_text) {
			for_each_typed_property_expanding_shorthands(property_id, typed_value, fn [set_longhand_property] (longhand_id PropertyID, longhand_value StyleValue) {
				set_longhand_property(longhand_id, dom_style_value_from_value_logic(longhand_value))
			})
			return
		}
	}
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
	_ = get_property_specified_value
	absolutized_value := unsafe { specified_value }

	return match property_id {
		.animation_name {
			StyleComputer.compute_animation_name(absolutized_value)
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .outline_width {
			StyleComputer.compute_border_or_outline_width(absolutized_value,
				device_pixels_per_css_pixel)
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			StyleComputer.compute_corner_shape(absolutized_value)
		}
		.font_feature_settings {
			StyleComputer.compute_font_feature_tag_value_list(absolutized_value,
				computation_context)
		}
		.font_style {
			StyleComputer.compute_font_style(absolutized_value)
		}
		.font_variation_settings {
			StyleComputer.compute_font_variation_settings(absolutized_value, computation_context)
		}
		.font_weight {
			inheritance_parent := style_computation_inheritance_parent(computation_context)
			StyleComputer.compute_font_weight(absolutized_value, inheritance_parent)
		}
		.font_width {
			StyleComputer.compute_font_width(absolutized_value)
		}
		.letter_spacing, .word_spacing {
			StyleComputer.compute_letter_or_word_spacing(absolutized_value)
		}
		.line_height {
			StyleComputer.compute_line_height(absolutized_value,
				computation_context.length_resolution_context.font_metrics.font_size)
		}
		.object_position, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .perspective, .perspective_origin {
			StyleComputer.compute_absolutized_value(property_id, absolutized_value,
				computation_context)
		}
		.outline_offset {
			StyleComputer.compute_length(absolutized_value, computation_context)
		}
		.math_depth {
			inheritance_parent := style_computation_inheritance_parent(computation_context)
			StyleComputer.compute_math_depth(absolutized_value, inheritance_parent)
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity,
		.stroke_opacity {
			StyleComputer.compute_opacity(absolutized_value)
		}
		.position_area {
			StyleComputer.compute_position_area(absolutized_value)
		}
		.scrollbar_color, .tab_size, .transform_origin, .vertical_align {
			StyleComputer.compute_absolutized_value(property_id, absolutized_value,
				computation_context)
		}
		else {
			unsafe { specified_value }
		}
	}
}

fn style_computation_inheritance_parent(computation_context StyleComputationContextStub) ?dom.AbstractElement {
	if abstract_element := computation_context.abstract_element {
		return abstract_element.element_to_inherit_style_from()
	}
	return none
}

fn computed_interpolation_compute_style_value_list(style_value &dom.StyleValue, compute_entry fn (StyleValue) ?StyleValue) ?&dom.StyleValue {
	mut computed_entries := []StyleValue{}
	for entry_component_values in parse_a_comma_separated_list_of_component_values_for_value_logic(parse_component_values_for_value_logic(style_value.css_text)) {
		mut entry_tokens := ComponentValueStream.new(entry_component_values)
		entry := computed_interpolation_animation_name_entry_from_tokens(mut entry_tokens) or {
			return none
		}
		entry_tokens.consume_whitespace()
		if entry_tokens.has_more_tokens() {
			return none
		}
		computed_entries << (compute_entry(entry) or { return none })
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(computed_entries,
		.comma, .yes)))
}

fn computed_interpolation_animation_name_entry_from_tokens(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if equals_ignoring_ascii_case(ident, 'none') {
			return StyleValue(KeywordStyleValue.create(.none_))
		}
		return StyleValue(CustomIdentStyleValue.create(ident))
	}
	if component_value.is(.string) {
		return StyleValue(StringStyleValue.create(component_value.token().string_value()))
	}
	return none
}

fn computed_interpolation_compute_animation_name_entry(entry StyleValue) ?StyleValue {
	// none | <custom-ident>
	if entry.to_keyword() == .none_ || entry.is_custom_ident() {
		return entry
	}

	// <string>
	if entry.is_string() {
		string_value := entry.as_string().string_value()

		// AD-HOC: We shouldn't convert strings that aren't valid <custom-ident>s
		if is_css_wide_keyword_string(string_value)
			|| to_ascii_lowercase(string_value) in ['default', 'none'] {
			return entry
		}

		return StyleValue(CustomIdentStyleValue.create(string_value))
	}

	return none
}

pub fn StyleComputer.compute_animation_name(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-animations-1/#animation-name
	// list, each item either a case-sensitive css identifier or the keyword none
	return computed_interpolation_compute_style_value_list(absolutized_value,
		computed_interpolation_compute_animation_name_entry) or { unsafe { absolutized_value } }
}

fn computed_interpolation_line_width_keyword_to_css_pixels(value string) ?CSSPixels {
	// https://drafts.csswg.org/css-backgrounds/#typedef-line-width
	// The thin, medium, and thick keywords are equivalent to 1px, 3px, and 5px, respectively.
	return match to_ascii_lowercase(value.trim_space()) {
		'thin' { CSSPixels.new(1) }
		'medium' { CSSPixels.new(3) }
		'thick' { CSSPixels.new(5) }
		else { none }
	}
}

// https://www.w3.org/TR/css-values-4/#snap-a-length-as-a-border-width
fn computed_interpolation_snap_a_length_as_a_border_width(device_pixels_per_css_pixel f64, length CSSPixels) CSSPixels {
	// 1. Assert: len is non-negative.
	if length.raw_value() < 0 {
		panic('VERIFY(length >= 0)')
	}

	// 2. If len is an integer number of device pixels, do nothing.
	device_pixels := length.to_double() * device_pixels_per_css_pixel
	if device_pixels == math.trunc(device_pixels) {
		return length
	}

	// 3. If len is greater than zero, but less than 1 device pixel, round len up to 1 device pixel.
	if device_pixels > 0 && device_pixels < 1 {
		return CSSPixels.nearest_value_for(1 / device_pixels_per_css_pixel)
	}

	// 4. If len is greater than 1 device pixel, round it down to the nearest integer number of device pixels.
	if device_pixels > 1 {
		return CSSPixels.nearest_value_for(math.floor(device_pixels) / device_pixels_per_css_pixel)
	}

	return length
}

fn computed_interpolation_length_from_dom_style_value(style_value &dom.StyleValue) ?Length {
	mut parser := Parser.from_css_text(style_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed_value := parser.parse_length_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	if parsed_value is LengthStyleValue {
		return parsed_value.length()
	}
	return none
}

pub fn StyleComputer.compute_border_or_outline_width(absolutized_value &dom.StyleValue, device_pixels_per_css_pixel f64) &dom.StyleValue {
	// https://drafts.csswg.org/css-backgrounds/#border-width
	// absolute length, snapped as a border width
	absolute_length := computed_interpolation_line_width_keyword_to_css_pixels(absolutized_value.css_text) or {
		length := computed_interpolation_length_from_dom_style_value(absolutized_value) or {
			return unsafe { absolutized_value }
		}
		length.absolute_length_to_px()
	}
	snapped_length := computed_interpolation_snap_a_length_as_a_border_width(device_pixels_per_css_pixel,
		absolute_length)
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(snapped_length))))
}

pub fn StyleComputer.compute_length(absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	length := computed_interpolation_length_from_dom_style_value(absolutized_value) or {
		return unsafe { absolutized_value }
	}
	computed_length := LengthStyleValue.create(length).absolutized(ComputationContext{
		length_resolution_context: computation_context.length_resolution_context
	})
	return dom_style_value_from_value_logic(StyleValue(computed_length))
}

pub fn StyleComputer.compute_absolutized_value(property_id PropertyID, absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	parsed_value := parse_css_value_logic(property_id, absolutized_value.css_text) or {
		return unsafe { absolutized_value }
	}
	computed_value := parsed_value.absolutized(ComputationContext{
		length_resolution_context: computation_context.length_resolution_context
	})
	return dom_style_value_from_value_logic(computed_value)
}

pub fn StyleComputer.compute_corner_shape(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-borders-4/#propdef-corner-top-left-shape
	// the corresponding superellipse() value
	mut parser := Parser.from_css_text(absolutized_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed_value := parser.parse_corner_shape_value(mut tokens) or {
		return unsafe { absolutized_value }
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return unsafe { absolutized_value }
	}

	if parsed_value is SuperellipseStyleValue {
		return dom_style_value_from_value_logic(parsed_value)
	}

	keyword := parsed_value.to_keyword()
	parameter := match keyword {
		.round {
			// The corner shape is a quarter of a convex ellipse. Equivalent to superellipse(1).
			1.0
		}
		.squircle {
			// The corner shape is a quarter of a "squircle", a convex curve between round and square. Equivalent to superellipse(2).
			2.0
		}
		.square {
			// The corner shape is a convex 90deg angle. Equivalent to superellipse(infinity).
			math.inf(1)
		}
		.bevel {
			// The corner shape is a straight diagonal line, neither convex nor concave. Equivalent to superellipse(0).
			0.0
		}
		.scoop {
			// The corner shape is a concave quarter-ellipse. Equivalent to superellipse(-1).
			-1.0
		}
		.notch {
			// The corner shape is a concave 90deg angle. Equivalent to superellipse(-infinity).
			math.inf(-1)
		}
		else {
			return unsafe { absolutized_value }
		}
	}

	return dom_style_value_from_value_logic(StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(parameter)))))
}

pub fn StyleComputer.compute_letter_or_word_spacing(absolutized_value &dom.StyleValue) &dom.StyleValue {
	if computed_interpolation_style_value_keyword(absolutized_value) or { Keyword.invalid } == .normal {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(0))))
	}
	return unsafe { absolutized_value }
}

fn computed_interpolation_parse_opentype_tag_value(mut tokens ComponentValueStream) ?StringStyleValue {
	// https://drafts.csswg.org/css-fonts/#typedef-opentype-tag
	// <opentype-tag> = <string>
	// The <opentype-tag> is a case-sensitive OpenType feature tag.
	// As specified in the OpenType specification [OPENTYPE], feature tags contain four ASCII characters.
	// Tag strings longer or shorter than four characters, or containing characters outside the U+20-7E codepoint range are invalid.
	mut parser := Parser{}
	string_value := parser.parse_string_value(mut tokens) or { return none }
	tag := string_value.string_value()
	if tag.len != 4 {
		return none
	}
	for character in tag {
		if character < 0x20 || character > 0x7e {
			return none
		}
	}
	return string_value
}

fn computed_interpolation_parse_font_feature_settings_entry(values []ComponentValue) ?OpenTypeTaggedStyleValue {
	// <feature-tag-value> = <opentype-tag> [ <integer [0,∞]> | on | off ]?
	mut parser := Parser{}
	mut tag_tokens := ComponentValueStream.new(values)
	tag_tokens.consume_whitespace()
	opentype_tag := computed_interpolation_parse_opentype_tag_value(mut tag_tokens) or {
		return none
	}
	tag_tokens.consume_whitespace()
	value := if tag_tokens.has_more_tokens() {
		if integer_value := parser.parse_integer_value(mut tag_tokens) {
			if integer_value is IntegerStyleValue {
				if integer_value.integer() < 0 {
					return none
				}
			}
			integer_value
		} else {
			component_value := tag_tokens.consume() or { return none }
			if !component_value.is(.ident) {
				return none
			}
			match to_ascii_lowercase(component_value.token().ident()) {
				'on' { StyleValue(IntegerStyleValue.create(1)) }
				'off' { StyleValue(IntegerStyleValue.create(0)) }
				else { return none }
			}
		}
	} else {
		// "If the value is omitted, a value of 1 is assumed."
		StyleValue(IntegerStyleValue.create(1))
	}
	tag_tokens.consume_whitespace()
	if tag_tokens.has_more_tokens() {
		return none
	}
	return OpenTypeTaggedStyleValue.create(.font_feature_settings, opentype_tag.string_value(),
		value)
}

fn computed_interpolation_parse_font_variation_settings_entry(values []ComponentValue) ?OpenTypeTaggedStyleValue {
	mut parser := Parser{}
	mut tag_tokens := ComponentValueStream.new(values)
	tag_tokens.consume_whitespace()
	opentype_tag := computed_interpolation_parse_opentype_tag_value(mut tag_tokens) or {
		return none
	}
	tag_tokens.consume_whitespace()
	number := parser.parse_number_value(mut tag_tokens) or { return none }
	tag_tokens.consume_whitespace()

	if tag_tokens.has_more_tokens() {
		return none
	}

	return OpenTypeTaggedStyleValue.create(.font_variation_settings, opentype_tag.string_value(),
		number)
}

fn computed_interpolation_compute_font_feature_tag_value_list(absolutized_value &dom.StyleValue, mode OpenTypeTaggedStyleValueMode) ?&dom.StyleValue {
	if equals_ignoring_ascii_case(absolutized_value.css_text.trim_space(), 'normal') {
		return unsafe { absolutized_value }
	}

	mut axis_tags_map := map[string]OpenTypeTaggedStyleValue{}
	for values in parse_a_comma_separated_list_of_component_values_for_value_logic(parse_component_values_for_value_logic(absolutized_value.css_text)) {
		axis_tag := match mode {
			.font_feature_settings {
				computed_interpolation_parse_font_feature_settings_entry(values) or { return none }
			}
			.font_variation_settings {
				computed_interpolation_parse_font_variation_settings_entry(values) or {
					return none
				}
			}
		}

		axis_tags_map[axis_tag.tag()] = axis_tag
	}

	mut tags := []string{}
	for tag, _ in axis_tags_map {
		tags << tag
	}
	tags.sort()

	mut axis_tags := []StyleValue{}
	for tag in tags {
		axis_tags << StyleValue(axis_tags_map[tag] or { return none })
	}

	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(axis_tags, .comma,
		.yes)))
}

pub fn StyleComputer.compute_font_feature_tag_value_list(absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	_ = computation_context
	// https://drafts.csswg.org/css-fonts-4/#font-variation-settings-def
	// https://drafts.csswg.org/css-fonts/#font-feature-settings-prop
	// NB: The computation logic is the same for both font-feature-settings and font-variation-settings, first we
	//     deduplicate feature tags (with latter taking precedence), then we sort them in ascending order by code unit
	return computed_interpolation_compute_font_feature_tag_value_list(absolutized_value,
		.font_feature_settings) or { unsafe { absolutized_value } }
}

pub fn StyleComputer.compute_math_depth(absolutized_value &dom.StyleValue, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	// https://w3c.github.io/mathml-core/#propdef-math-depth
	mut inherited_math_depth := 0
	mut inherited_math_style := MathStyle.normal
	if parent := inheritance_parent {
		if computed_properties := parent.computed_properties() {
			inherited_math_depth = computed_properties.math_depth()
			if computed_properties.math_style() == dom.CSSMathStyle_.compact {
				inherited_math_style = .compact
			}
		}
	}

	parsed_value := parse_css_value_logic(.math_depth, absolutized_value.css_text) or {
		return unsafe { absolutized_value }
	}

	// The computed value of the math-depth value is determined as follows:
	// - If the specified value of math-depth is auto-add and the inherited value of math-style is compact
	//   then the computed value of math-depth of the element is its inherited value plus one.
	if parsed_value.to_keyword() == .auto_add && inherited_math_style == .compact {
		return dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(i64(
			inherited_math_depth + 1))))
	}

	// - If the specified value of math-depth is of the form add(<integer>) then the computed value of
	//   math-depth of the element is its inherited value plus the specified integer.
	if parsed_value is AddFunctionStyleValue {
		depth := inherited_math_depth + int(int_from_style_value(parsed_value.value()))
		return dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(i64(depth))))
	}

	// - If the specified value of math-depth is of the form <integer> then the computed value of math-depth
	//   of the element is the specified integer.
	if parsed_value.is_integer() || parsed_value.is_calculated() {
		return dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(int_from_style_value(parsed_value))))
	}

	// - Otherwise, the computed value of math-depth of the element is the inherited one.
	return dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(i64(inherited_math_depth))))
}

pub fn StyleComputer.compute_font_size(absolutized_value &dom.StyleValue, computed_math_depth int, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	_ = computed_math_depth
	_ = inheritance_parent
	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_style(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-fonts-4/#font-style-prop
	// the keyword specified, plus angle in degrees if specified

	// NB: We always parse as a FontStyleStyleValue, but StylePropertyMap is able to set a KeywordStyleValue directly.
	mut parser := Parser.from_css_text(absolutized_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed_value := parser.parse_font_style_value(mut tokens) or {
		return unsafe { absolutized_value }
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() || parsed_value !is FontStyleStyleValue {
		return unsafe { absolutized_value }
	}
	return dom_style_value_from_value_logic(parsed_value)
}

pub fn StyleComputer.compute_font_weight(absolutized_value &dom.StyleValue, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	// https://drafts.csswg.org/css-fonts-4/#font-weight-prop
	// a number, see below
	inherited_font_weight := if parent := inheritance_parent {
		if computed_properties := parent.computed_properties() {
			computed_properties.font_weight()
		} else {
			400.0
		}
	} else {
		400.0
	}

	// <number [1,1000]>
	if number := computed_interpolation_number_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(number)))
	}

	// AD-HOC: Anywhere we support a numbers we should also support calcs
	if calculated_number := computed_interpolation_calculated_number_from_dom_style_value(absolutized_value,
		CSSPixels.nearest_value_for(0))
	{
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(calculated_number)))
	}

	keyword := computed_interpolation_style_value_keyword(absolutized_value) or {
		return unsafe { absolutized_value }
	}

	// normal
	// Same as 400.
	if keyword == .normal {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(400)))
	}

	// bold
	// Same as 700.
	if keyword == .bold {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(700)))
	}

	// Specified values of bolder and lighter indicate weights relative to the weight of the parent element. The
	// computed weight is calculated based on the inherited font-weight value using the chart below.
	//
	// Inherited value (w)  bolder     lighter
	// w < 100              400        No change
	// 100 <= w < 350       400        100
	// 350 <= w < 550       700        100
	// 550 <= w < 750       900        400
	// 750 <= w < 900       900        700
	// 900 <= w             No change  700

	// bolder
	// Specifies a bolder weight than the inherited value. See Section 2.2.1 Relative Weights.
	if keyword == .bolder {
		if inherited_font_weight < 350 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(400)))
		}
		if inherited_font_weight < 550 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(700)))
		}
		if inherited_font_weight < 900 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(900)))
		}
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(inherited_font_weight)))
	}

	// lighter
	// Specifies a lighter weight than the inherited value. See Section 2.2.1 Relative Weights.
	if keyword == .lighter {
		if inherited_font_weight < 100 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(inherited_font_weight)))
		}
		if inherited_font_weight < 550 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(100)))
		}
		if inherited_font_weight < 750 {
			return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(400)))
		}
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(700)))
	}

	return unsafe { absolutized_value }
}

fn computed_interpolation_style_value_from_numeric_primitive(value NumericPrimitiveValue) ?StyleValue {
	return match value {
		Number { StyleValue(NumberStyleValue.create(value.value())) }
		Percentage { StyleValue(PercentageStyleValue.create(value)) }
		Length { StyleValue(LengthStyleValue.create(value)) }
		else { none }
	}
}

fn computed_interpolation_style_value_from_css_numeric_value(value CSSNumericValue) ?StyleValue {
	if value is CSSUnitValue {
		primitive := create_numeric_value(value.value(), value.unit()) or { return none }
		return computed_interpolation_style_value_from_numeric_primitive(primitive)
	}

	sum := value.create_a_sum_value() or { return none }
	if sum.len != 1 {
		return none
	}
	unit_value := CSSUnitValue.create_from_sum_value_item(sum[0]) or { return none }
	primitive := create_numeric_value(unit_value.value(), unit_value.unit()) or { return none }
	return computed_interpolation_style_value_from_numeric_primitive(primitive)
}

fn computed_interpolation_number_from_dom_style_value(style_value &dom.StyleValue) ?f64 {
	mut parser := Parser.from_css_text(style_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed_value := parser.parse_number_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() || parsed_value !is NumberStyleValue {
		return none
	}
	return (parsed_value as NumberStyleValue).number()
}

fn computed_interpolation_integer_from_dom_style_value(style_value &dom.StyleValue) ?i64 {
	parsed_value := parse_css_value_logic(.math_depth, style_value.css_text) or { return none }
	if parsed_value.is_integer() || parsed_value.is_calculated() {
		return int_from_style_value(parsed_value)
	}
	return none
}

fn computed_interpolation_percentage_from_dom_style_value(style_value &dom.StyleValue) ?Percentage {
	mut parser := Parser.from_css_text(style_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed_value := parser.parse_percentage_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() || parsed_value !is PercentageStyleValue {
		return none
	}
	return (parsed_value as PercentageStyleValue).percentage()
}

fn computed_interpolation_calculated_style_value_from_dom_style_value(style_value &dom.StyleValue) ?StyleValue {
	numeric_value := CSSNumericValue.parse(style_value.css_text) or { return none }
	return computed_interpolation_style_value_from_css_numeric_value(numeric_value)
}

fn computed_interpolation_calculated_number_from_dom_style_value(style_value &dom.StyleValue, computed_font_size CSSPixels) ?f64 {
	parsed_value := computed_interpolation_calculated_style_value_from_dom_style_value(style_value) or {
		return none
	}
	if parsed_value is NumberStyleValue {
		return parsed_value.number()
	}
	if parsed_value is CalculatedStyleValue {
		return parsed_value.resolve_number(CalculationResolutionContext{
			percentage_basis: Length.make_css_px(computed_font_size)
		})
	}
	return none
}

fn computed_interpolation_calculated_percentage_from_dom_style_value(style_value &dom.StyleValue) ?Percentage {
	parsed_value := computed_interpolation_calculated_style_value_from_dom_style_value(style_value) or {
		return none
	}
	if parsed_value is PercentageStyleValue {
		return parsed_value.percentage()
	}
	if parsed_value is CalculatedStyleValue {
		return parsed_value.resolve_percentage(CalculationResolutionContext{})
	}
	return none
}

fn computed_interpolation_calculated_length_from_dom_style_value(style_value &dom.StyleValue, computed_font_size CSSPixels) ?Length {
	parsed_value := computed_interpolation_calculated_style_value_from_dom_style_value(style_value) or {
		return none
	}
	if parsed_value is LengthStyleValue {
		return parsed_value.length()
	}
	if parsed_value is PercentageStyleValue {
		return Length.make_px(computed_font_size.to_double() * parsed_value.percentage().as_fraction())
	}
	if parsed_value is CalculatedStyleValue {
		return parsed_value.resolve_length(CalculationResolutionContext{
			percentage_basis: Length.make_css_px(computed_font_size)
		})
	}
	return none
}

fn computed_interpolation_font_width_keyword_to_percentage(value string) ?Percentage {
	return match to_ascii_lowercase(value.trim_space()) {
		// ultra-condensed 50%
		'ultra-condensed' { Percentage.new(50) }
		// extra-condensed 62.5%
		'extra-condensed' { Percentage.new(62.5) }
		// condensed 75%
		'condensed' { Percentage.new(75) }
		// semi-condensed 87.5%
		'semi-condensed' { Percentage.new(87.5) }
		// normal 100%
		'normal' { Percentage.new(100) }
		// semi-expanded 112.5%
		'semi-expanded' { Percentage.new(112.5) }
		// expanded 125%
		'expanded' { Percentage.new(125) }
		// extra-expanded 150%
		'extra-expanded' { Percentage.new(150) }
		// ultra-expanded 200%
		'ultra-expanded' { Percentage.new(200) }
		else { none }
	}
}

pub fn StyleComputer.compute_font_width(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-fonts-4/#font-width-prop
	// a percentage, see below

	// <percentage [0,∞]>
	if percentage := computed_interpolation_percentage_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(percentage)))
	}

	// AD-HOC: We support calculated percentages as well
	if calculated_percentage := computed_interpolation_calculated_percentage_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(calculated_percentage)))
	}

	percentage := computed_interpolation_font_width_keyword_to_percentage(absolutized_value.css_text) or {
		return unsafe { absolutized_value }
	}
	return dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(percentage)))
}

pub fn StyleComputer.compute_font_variation_settings(absolutized_value &dom.StyleValue, computation_context StyleComputationContextStub) &dom.StyleValue {
	_ = computation_context
	// https://drafts.csswg.org/css-fonts-4/#font-variation-settings-def
	// https://drafts.csswg.org/css-fonts/#font-feature-settings-prop
	// NB: The computation logic is the same for both font-feature-settings and font-variation-settings, first we
	//     deduplicate feature tags (with latter taking precedence), then we sort them in ascending order by code unit
	return computed_interpolation_compute_font_feature_tag_value_list(absolutized_value,
		.font_variation_settings) or { unsafe { absolutized_value } }
}

pub fn StyleComputer.compute_line_height(absolutized_value &dom.StyleValue, computed_font_size CSSPixels) &dom.StyleValue {
	// https://drafts.csswg.org/css-inline-3/#line-height-property

	// normal
	// <length [0,∞]>
	// <number [0,∞]>
	if equals_ignoring_ascii_case(absolutized_value.css_text.trim_space(), 'normal') {
		return unsafe { absolutized_value }
	}
	if length := computed_interpolation_length_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(length)))
	}
	if number := computed_interpolation_number_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(number)))
	}

	// NOTE: We also support calc()'d lengths (percentages resolve to lengths so we don't have to handle them separately)
	if calculated_length := computed_interpolation_calculated_length_from_dom_style_value(absolutized_value,
		computed_font_size)
	{
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(calculated_length)))
	}

	// NOTE: We also support calc()'d numbers
	if calculated_number := computed_interpolation_calculated_number_from_dom_style_value(absolutized_value,
		computed_font_size)
	{
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(calculated_number)))
	}

	// <percentage [0,∞]>
	if percentage := computed_interpolation_percentage_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(computed_font_size.to_double() * percentage.as_fraction()))))
	}

	return unsafe { absolutized_value }
}

fn computed_interpolation_opacity_value_from_numeric_value(numeric_value CSSNumericValue) ?f64 {
	if numeric_value is CSSUnitValue {
		unit := numeric_value.unit()
		if unit == 'number' {
			return clamp_f64(numeric_value.value(), 0.0, 1.0)
		}
		if unit == 'percent' {
			return clamp_f64(numeric_value.value() / 100.0, 0.0, 1.0)
		}
	}

	sum := numeric_value.create_a_sum_value() or { return none }
	if sum.len != 1 {
		return none
	}
	item := sum[0]
	if item.unit_map.len == 0 {
		return clamp_f64(item.value, 0.0, 1.0)
	}
	if item.unit_map.len == 1 {
		if exponent := item.unit_map['percent'] {
			if exponent == 1 {
				return clamp_f64(item.value / 100.0, 0.0, 1.0)
			}
		}
	}
	return none
}

pub fn StyleComputer.compute_opacity(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-color-4/#transparency
	// specified number, clamped to the range [0,1]
	numeric_value := CSSNumericValue.parse(absolutized_value.css_text) or {
		return unsafe { absolutized_value }
	}
	value := computed_interpolation_opacity_value_from_numeric_value(numeric_value) or {
		return unsafe { absolutized_value }
	}
	return &dom.StyleValue{
		css_text: serialize_a_number(value)
	}
}

pub fn StyleComputer.compute_position_area(absolutized_value &dom.StyleValue) &dom.StyleValue {
	return unsafe { absolutized_value }
}

pub fn (s &StyleComputer) build_matching_rule_set(abstract_element dom.AbstractElement, mut attempted_pseudo_class_matches PseudoClassBitmap, did_match_any_pseudo_element_rules &bool, mode ComputeStyleMode, scope &StyleScope) MatchingRuleSet {
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
	// https://www.w3.org/TR/css-overflow-3/#overflow-control
	// The visible/clip values of overflow compute to auto/hidden (respectively)
	// if one of overflow-x or overflow-y is neither visible nor clip.
	overflow_x := computed_properties.overflow_x()
	overflow_y := computed_properties.overflow_y()
	overflow_x_is_visible_or_clip := overflow_x == .visible || overflow_x == .clip
	overflow_y_is_visible_or_clip := overflow_y == .visible || overflow_y == .clip
	if !overflow_x_is_visible_or_clip || !overflow_y_is_visible_or_clip {
		if overflow_x == .visible {
			computed_properties.set_property_without_modifying_flags(.overflow_x,
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))))
		}
		if overflow_x == .clip {
			computed_properties.set_property_without_modifying_flags(.overflow_x,
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.hidden))))
		}
		if overflow_y == .visible {
			computed_properties.set_property_without_modifying_flags(.overflow_y,
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))))
		}
		if overflow_y == .clip {
			computed_properties.set_property_without_modifying_flags(.overflow_y,
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.hidden))))
		}
	}
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

			StyleComputer.for_each_property_expanding_shorthands(property_id, property_value, fn [mut cascaded_properties, important, origin, layer_name, declaration] (longhand_id PropertyID, longhand_value &dom.StyleValue) {
				// Upstream only suppresses a previously-seen longhand when the later declaration is a
				// PendingSubstitutionStyleValue. DOM-side StyleValue does not expose that typed state here yet,
				// so concrete later declarations keep overriding earlier ones.
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
	return StyleComputationContextStub{
		property_id:      property_id
		abstract_element: abstract_element
	}
}
