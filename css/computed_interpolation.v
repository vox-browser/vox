module css

import processmetrics


import math
import dom
import os
import platform
import strconv
import svg
import time

// Translated scaffolding from:
// - LibWeb/CSS/ComputedProperties.h/cpp
// - LibWeb/CSS/Interpolation.h/cpp
// - LibWeb/CSS/StyleComputer.h/cpp
// - LibWeb/CSS/StyleInvalidation.h/cpp
// - LibWeb/CSS/StyleInvalidationData.h/cpp
// - LibWeb/CSS/InvalidationSet.h/cpp
//
// Generated property metadata, selector/parser types, style values, fonts, and
// animations are translated in the neighboring CSS files. Layout/rendering
// objects and DOM-owned opaque handles cross explicit typed adapters below.
pub const computed_properties_normal_line_height_scale = 1.15

const computed_property_flag_byte_count = (number_of_longhand_properties + 7) / 8

// --- Small support records for layout/rendering and DOM integration adapters ---
pub struct ComputedColor {
pub mut:
	red_   u8
	green_ u8
	blue_  u8
	alpha_ u8 = 255
}

pub fn ComputedColor.rgb(red u8, green u8, blue u8) ComputedColor {
	return ComputedColor{
		red_: red
		green_: green
		blue_: blue
		alpha_: 255
	}
}

pub fn ComputedColor.rgba(red u8, green u8, blue u8, alpha u8) ComputedColor {
	return ComputedColor{
		red_: red
		green_: green
		blue_: blue
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

pub enum ColorSyntax as u8 {
	legacy
	modern
}

pub struct NormalGap {}

pub struct GapValue {
pub mut:
	is_normal         bool = true
	length_percentage LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
}

pub fn GapValue.normal() GapValue {
	return GapValue{}
}

pub fn GapValue.from_length_percentage(length_percentage LengthPercentage) GapValue {
	return GapValue{
		is_normal: false
		length_percentage: length_percentage
	}
}

pub enum ColorInterpolation as u8 {
	auto_
	srgb
	srgb_linear
	oklab
}

pub enum TextAnchor as u8 {
	start
	middle
	end_
}

pub enum BaselineMetric as u8 {
	alphabetic
	central
	hanging
	ideographic
	mathematical
	middle
	text_top
	text_bottom
}

pub enum TextAlign as u8 {
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

pub enum TextJustify as u8 {
	auto_
	none_
	inter_word
	inter_character
}

pub enum TextOverflow as u8 {
	clip
	ellipsis
}

pub struct BackgroundLayerData {
pub mut:
	image      string
	attachment BackgroundAttachment
	blend_mode MixBlendMode
	clip       BackgroundBox
	origin     BackgroundBox
	position_x LengthPercentage = LengthPercentage.from_percentage(Percentage.new(0))
	position_y LengthPercentage = LengthPercentage.from_percentage(Percentage.new(0))
	repeat_x   Repetition
	repeat_y   Repetition
	size_type  BackgroundSize
	size_x     LengthPercentageOrAuto = LengthPercentageOrAuto.make_auto()
	size_y     LengthPercentageOrAuto = LengthPercentageOrAuto.make_auto()
}

pub enum BackgroundBox as u8 {
	border_box
	padding_box
	content_box
	text
}

pub enum BackgroundAttachment as u8 {
	scroll
	fixed
	local
}

pub enum BackgroundSize as u8 {
	length_percentage
	contain
	cover
}

pub enum CaptionSide as u8 {
	top
	bottom
}

pub enum Float as u8 {
	none_
	left
	right
	inline_start
	inline_end
}

pub enum Clear as u8 {
	none_
	left
	right
	both
	inline_start
	inline_end
}

pub enum ColumnSpan as u8 {
	none_
	all
}

pub enum BreakBetween as u8 {
	auto
	avoid
	avoid_page
	page
	left
	right
	recto
	verso
	avoid_column
	column
	avoid_region
	region
}

pub enum BreakInside as u8 {
	auto
	avoid
	avoid_page
	avoid_column
	avoid_region
}

pub enum BoxDecorationBreak as u8 {
	slice
	clone
}

pub enum ColumnFill as u8 {
	auto
	balance
	balance_all
}

pub enum BlockEllipsisType as u8 {
	no_ellipsis
	auto_
	string
}

pub struct BlockEllipsis {
pub:
	type_ BlockEllipsisType
	text_ string
}

pub fn (value BlockEllipsis) text() string {
	return value.text_
}

pub enum ContinueValue as u8 {
	auto_
	discard
	collapse
	webkit_legacy
}

pub enum WebkitBoxOrient as u8 {
	horizontal
	vertical
}

pub enum ContentDataType as u8 {
	normal
	none_
	list
}

pub enum ContentItemType as u8 {
	text
	image
}

pub struct ContentItem {
pub:
	type_ ContentItemType
	value string
	// The selected image-set() candidate's resolution in dots per CSS pixel.
	// Natural image sizes are divided by it.
	resolution f64 = 1.0
}

pub struct ContentData {
pub mut:
	type_                      ContentDataType
	text                       string
	alt_text                   string
	has_alt_text               bool
	items                      []ContentItem
	counter_style_dependencies []?CounterStyle
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
		length: value
	}
}

pub enum WhiteSpaceCollapse as u8 {
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

pub enum WordBreak as u8 {
	normal
	break_all
	keep_all
	break_word
}

pub enum OverflowWrap as u8 {
	normal
	anywhere
	break_word
}

pub enum LineStyle as u8 {
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

pub struct BorderData {
pub mut:
	color      Color
	line_style LineStyle
	width      CSSPixels
}

pub struct BorderRadiusData {
pub mut:
	horizontal_radius LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
	vertical_radius   LengthPercentage = LengthPercentage.from_length(Length.make_px(0))
}

pub fn (radius BorderRadiusData) is_initial() bool {
	return radius.horizontal_radius.is_length() && radius.horizontal_radius.length().is_px()
		&& radius.horizontal_radius.length().absolute_length_to_px().raw_value() == 0
		&& radius.vertical_radius.is_length() && radius.vertical_radius.length().is_px()
		&& radius.vertical_radius.length().absolute_length_to_px().raw_value() == 0
}

pub type SVGPaintValue = Color | URL

pub struct SVGPaint {
pub mut:
	value_          SVGPaintValue
	fallback_color_ ?Color
}

pub fn SVGPaint.from_color(color Color) SVGPaint {
	return SVGPaint{
		value_: color
	}
}

pub fn SVGPaint.from_url(url URL, fallback_color ?Color) SVGPaint {
	return SVGPaint{
		value_: url
		fallback_color_: fallback_color
	}
}

pub fn (paint SVGPaint) is_color() bool {
	return paint.value_ is Color
}

pub fn (paint SVGPaint) is_url() bool {
	return paint.value_ is URL
}

pub fn (paint SVGPaint) as_color() Color {
	if paint.value_ is Color {
		return paint.value_
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (paint SVGPaint) as_url() URL {
	if paint.value_ is URL {
		return paint.value_
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (paint SVGPaint) fallback_color() ?Color {
	return paint.fallback_color_
}

pub struct MaskReference {
pub mut:
	url_ URL
}

pub fn MaskReference.from_url(url URL) MaskReference {
	return MaskReference{
		url_: url
	}
}

pub fn (reference MaskReference) url() URL {
	return reference.url_
}

pub type ClipPathReferenceValue = BasicShapeStyleValue | URL

pub struct ClipPathReference {
pub mut:
	value_ ClipPathReferenceValue
	reference_box string = 'border-box'
}

pub fn ClipPathReference.from_url(url URL) ClipPathReference {
	return ClipPathReference{
		value_: url
	}
}

pub fn ClipPathReference.from_basic_shape(shape BasicShapeStyleValue) ClipPathReference {
	return ClipPathReference{
		value_: shape
	}
}

pub fn (reference ClipPathReference) is_basic_shape() bool {
	return reference.value_ is BasicShapeStyleValue
}

pub fn (reference ClipPathReference) is_url() bool {
	return reference.value_ is URL
}

pub fn (reference ClipPathReference) url() URL {
	if reference.value_ is URL {
		return reference.value_
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (reference ClipPathReference) basic_shape() BasicShapeStyleValue {
	if reference.value_ is BasicShapeStyleValue {
		return reference.value_
	}
	panic('VERIFY_NOT_REACHED')
}

pub enum OutlineStyle as u8 {
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

pub enum TextDecorationLine as u8 {
	none_
	underline
	overline
	line_through
	blink
	spelling_error
	grammar_error
}

pub enum TextDecorationSkipInk as u8 {
	auto
	all
	none_
}

pub enum TextDecorationStyle as u8 {
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

pub enum TextTransform as u8 {
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

pub enum TextWrapMode as u8 {
	wrap
	nowrap
}

pub enum TextWrapStyle as u8 {
	auto_
	balance
	stable
	pretty
}

pub enum ListStyleTypeKind as u8 {
	none_
	counter_style
	string
}

// CSS::ListStyleType is Variant<Empty, RefPtr<CounterStyle const>, String>
// upstream. Keep the kind even when a named counter style fails to resolve:
// a missing <counter-style> is distinct from `none` and falls back to decimal
// when its representation is generated.
pub struct ListStyleType {
pub mut:
	kind          ListStyleTypeKind
	name          string
	// An absent counter owns no algorithm or symbol storage.
	counter_style ?CounterStyle = ?CounterStyle(none)
}

pub enum ListStylePosition as u8 {
	outside
	inside
}

pub enum FlexDirection as u8 {
	row
	row_reverse
	column
	column_reverse
}

pub enum FlexWrap as u8 {
	nowrap
	wrap
	wrap_reverse
}

pub struct FlexBasis {
pub mut:
	is_content bool
	size       Size = Size.make_auto()
}

pub enum AlignContent as u8 {
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

pub enum AlignItems as u8 {
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

pub enum AlignSelf as u8 {
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

pub enum Appearance as u8 {
	none_
	auto_
	textfield
	menulist_button
}

pub enum Visibility as u8 {
	visible
	hidden
	collapse
}

pub enum ImageRendering as u8 {
	auto_
	crisp_edges
	high_quality
	pixelated
	smooth
}

pub enum JustifyContent as u8 {
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

pub enum JustifyItems as u8 {
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

pub enum JustifySelf as u8 {
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

pub enum Overflow as u8 {
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

pub enum BoxSizing as u8 {
	content_box
	border_box
}

pub enum PointerEvents as u8 {
	auto_
	all
	none_
	bounding_box
	visible_painted
	visible_fill
	visible_stroke
	visible
	painted
	fill
	stroke
}

pub enum VerticalAlign as u8 {
	baseline
	sub
	super_
	text_top
	text_bottom
	middle
	top
	bottom
}

pub struct GridAutoFlow {
pub mut:
	row   bool = true
	dense bool
}

pub enum BorderCollapse as u8 {
	separate
	collapse
}

pub enum EmptyCells as u8 {
	show
	hide
}

pub enum ObjectFit as u8 {
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

pub fn (position Position) resolved(context LengthResolutionContext, rect CSSPixelRect) CSSPixelPoint {
	x := position.offset_x.to_px(context, rect.width)
	y := position.offset_y.to_px(context, rect.height)
	return CSSPixelPoint.new(rect.x.plus(x), rect.y.plus(y))
}

pub enum TableLayout as u8 {
	auto_
	fixed
}

pub enum Direction as u8 {
	ltr
	rtl
}

pub enum UnicodeBidi as u8 {
	normal
	embed
	isolate
	bidi_override
	isolate_override
	plaintext
}

pub enum WritingMode as u8 {
	horizontal_tb
	vertical_rl
	vertical_lr
	sideways_rl
	sideways_lr
}

pub enum UserSelect as u8 {
	auto_
	text
	none_
	all
	contain
}

pub enum Isolation as u8 {
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
		allow_left: false
		allow_right: false
		allow_up: false
		allow_down: false
		allow_pinch_zoom: false
		allow_other: false
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

pub fn (containment Containment) is_empty() bool {
	return !(containment.size_containment || containment.inline_size_containment
		|| containment.layout_containment || containment.style_containment
		|| containment.paint_containment)
}

pub struct ContainerType {
pub mut:
	is_size_container         bool
	is_inline_size_container  bool
	is_scroll_state_container bool
}

pub fn (container_type ContainerType) is_empty() bool {
	return !(container_type.is_size_container || container_type.is_inline_size_container
		|| container_type.is_scroll_state_container)
}

pub enum MixBlendMode as u8 {
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

pub enum TransformBox as u8 {
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
	z Length = Length.make_px(0)
}

pub enum TransformStyle as u8 {
	flat
	preserve_3d
}

pub enum BackfaceVisibility as u8 {
	visible
	hidden
}

pub struct TransformationData {
pub mut:
	property_id PropertyID
	values      []&dom.StyleValue
}

pub enum MaskType as u8 {
	luminance
	alpha
}

pub enum MaskComposite as u8 {
	add
	subtract
	intersect
	exclude
}

pub enum MaskMode as u8 {
	alpha
	luminance
	match_source
}

pub enum MaskOrigin as u8 {
	content_box
	padding_box
	border_box
	fill_box
	stroke_box
	view_box
}

pub enum MaskClip as u8 {
	content_box
	padding_box
	border_box
	fill_box
	stroke_box
	view_box
	no_clip
}

pub enum BorderImageRepeat as u8 {
	stretch
	repeat
	round
	space
}

pub enum TimelineAxis as u8 {
	block
	inline_
	x
	y
}

pub enum PositionVisibility as u8 {
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

pub enum StrokeLinecap as u8 {
	butt
	round
	square
}

pub enum StrokeLinejoin as u8 {
	miter
	round
	bevel
}

pub enum FillRule as u8 {
	nonzero
	evenodd
}

pub enum ClipRule as u8 {
	nonzero
	evenodd
}

pub enum ShapeRendering as u8 {
	auto_
	optimize_speed
	crisp_edges
	geometric_precision
}

pub enum VectorEffect as u8 {
	none_
	non_scaling_stroke
}

pub enum PaintOrder as u8 {
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
	names []string
}

pub fn WillChange.make_auto() WillChange {
	return WillChange{}
}

pub fn (will_change &WillChange) is_auto() bool {
	return will_change.names.len == 0
}

pub fn (will_change &WillChange) has_contents() bool {
	return 'contents' in will_change.names
}

pub fn (will_change &WillChange) has_scroll_position() bool {
	return 'scroll-position' in will_change.names
}

pub fn (will_change &WillChange) has_property(property_id PropertyID) bool {
	if will_change.names.len == 0 { return false }
	return string_from_property_id(property_id) in will_change.names
}

pub struct FontData {
pub mut:
	monospace  bool
	bold       bool
	point_size f64
}

pub enum MathStyle as u8 {
	normal
	compact
}

pub enum MathShift as u8 {
	normal
	compact
}

pub enum Positioning as u8 {
	static_
	relative
	absolute
	sticky
	fixed
}

pub struct QuotesData {
pub mut:
	pairs []string
	none_ bool
}

pub struct CounterData {
pub mut:
	name        string
	is_reversed bool
	value       ?i32
}

pub struct ScrollbarColorData {
pub mut:
	auto_ bool = true
	thumb ComputedColor
	track ComputedColor
}

pub enum ScrollbarWidth as u8 {
	auto_
	thin
	none_
}

pub enum ScrollBehavior as u8 {
	auto_
	smooth
}

pub enum ScrollSnapAlign as u8 {
	none_
	start
	end_
	center
}

pub struct ScrollSnapAlignData {
pub:
	block_alignment  ScrollSnapAlign
	inline_alignment ScrollSnapAlign
}

pub enum ScrollSnapStop as u8 {
	normal
	always
}

pub enum ScrollSnapAxis as u8 {
	x
	y
	block
	inline_
	both
}

pub enum ScrollSnapStrictness as u8 {
	none_
	proximity
	mandatory
}

pub struct ScrollSnapType {
pub:
	axis       ScrollSnapAxis = .both
	strictness ScrollSnapStrictness
}

pub enum Resize as u8 {
	none_
	both
	horizontal
	vertical
	block
	inline_
}

pub enum AnimationDirection as u8 {
	normal
	reverse
	alternate
	alternate_reverse
}

pub enum AnimationPlayState as u8 {
	running
	paused
}

pub enum AnimationFillMode as u8 {
	none_
	forwards
	backwards
	both
}

pub enum AnimationComposition as u8 {
	replace
	add
	accumulate
}

pub enum AnimationTimelineKind as u8 {
	generic
	document
	scroll
}

@[heap]
pub struct AnimationTimeline {
pub mut:
	kind                AnimationTimelineKind
	anonymous_source    ?string
	scroll_scroller     Scroller = .nearest
	scroll_axis         Axis = .block
	scroll_subject_id   ?dom.UniqueNodeID
	current_time_ms_    ?f64
	origin_time_ms_     f64
	monotonic_          bool
	associated_document ?&dom.Document
}

// CSS owns a small, cycle-free view of an animation timeline because the
// animations module already imports css. Keep the state and update rules in
// lockstep with Animations::AnimationTimeline/DocumentTimeline rather than
// substituting a free-standing timestamp.
pub fn AnimationTimeline.document_timeline(document &dom.Document, origin_time_ms f64, timestamp_ms f64) &AnimationTimeline {
	mut timeline := &AnimationTimeline{
		kind: .document
		origin_time_ms_: origin_time_ms
		associated_document: document
	}
	timeline.update_current_time(timestamp_ms)
	return timeline
}

pub fn (timeline &AnimationTimeline) is_inactive() bool {
	if timeline.current_time_ms_ == none {
		return true
	}
	if timeline.kind == .document {
		if document := timeline.associated_document {
			return !document.is_active()
		}
	}
	return false
}

pub fn (timeline &AnimationTimeline) current_time_ms() ?f64 {
	if timeline.is_inactive() {
		return none
	}
	return timeline.current_time_ms_
}

pub fn (mut timeline AnimationTimeline) update_current_time(timestamp_ms f64) {
	next_time := if timeline.kind == .document {
		timestamp_ms - timeline.origin_time_ms_
	} else {
		timestamp_ms
	}
	if timeline.monotonic_ {
		if previous := timeline.current_time_ms_ {
			if next_time < previous {
				return
			}
		}
	}
	timeline.current_time_ms_ = next_time
	// Like DocumentTimeline, a document timeline becomes monotonically
	// increasing after its first active sample.
	if timeline.kind == .document && !timeline.monotonic_ && !timeline.is_inactive() {
		timeline.monotonic_ = true
	}
}

pub enum TransitionBehavior as u8 {
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
	scroll_range    ScrollAnimationRange
	duration        f64
	duration_string string
	timing_function EasingFunction = EasingFunction.linear()
	iteration_count f64 = 1
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

// Identity only replaces a deep self-comparison when that comparison is known
// to be reflexive. In particular NaN-bearing numeric trees remain changed,
// and complex/mutable typed bridges keep their existing equality semantics.
fn style_value_identity_is_reflexive(value StyleValue) bool {
	return match value {
		KeywordStyleValue, StringStyleValue, CustomIdentStyleValue,
		IntegerStyleValue, DisplayStyleValue, ColorStyleValue,
		GuaranteedInvalidStyleValue { true }
		NumberStyleValue { value.number() == value.number() }
		LengthStyleValue { value.raw_value() == value.raw_value() }
		AngleStyleValue { value.raw_value() == value.raw_value() }
		PercentageStyleValue { value.raw_value() == value.raw_value() }
		FlexStyleValue { value.raw_value() == value.raw_value() }
		FrequencyStyleValue { value.raw_value() == value.raw_value() }
		ResolutionStyleValue { value.raw_value() == value.raw_value() }
		TimeStyleValue { value.raw_value() == value.raw_value() }
		StyleValueList {
			mut reflexive := true
			for entry in value.values_ {
				if !style_value_identity_is_reflexive(entry) {
					reflexive = false
					break
				}
			}
			reflexive
		}
		else { false }
	}
}

fn style_value_option_changed(old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) bool {
	if old := old_value {
		if new := new_value {
			if !retain_invalidation_value_copies && old.css_value_handle != unsafe { nil }
				&& new.css_value_handle != unsafe { nil } {
				old_box := unsafe { &TypedStyleValueBox(old.css_value_handle) }
				new_box := unsafe { &TypedStyleValueBox(new.css_value_handle) }
				if changed := borrowed_scalar_style_values_changed(old_box, new_box) {
					record_borrowed_invalidation_value()
					return changed
				}
			}
			if old.css_value_handle != unsafe { nil } {
				if old.css_value_handle == new.css_value_handle {
					box := unsafe { &TypedStyleValueBox(old.css_value_handle) }
					if style_value_identity_is_reflexive(box.value) { return false }
				}
			} else if voidptr(old) == voidptr(new) {
				return false
			}
			if old_typed := typed_style_value_logic_from_dom(old) {
				if new_typed := typed_style_value_logic_from_dom(new) {
					return !old_typed.equals(new_typed)
				}
			}
			return old.css_text != new.css_text
		}
		return true
	}
	return new_value != none
}

type ComputedInterpolationPropertyIDs = []PropertyID

type ComputedInterpolationInvalidationProperties = []InvalidationProperty

fn computed_interpolation_longhand_property_ids() ComputedInterpolationPropertyIDs {
	if computed_interpolation_longhand_ids_cache.len == 0 {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut ids := []PropertyID{cap: number_of_longhand_properties}
		for index in 0 .. number_of_longhand_properties {
			if property_id := property_id_from_longhand_index(index) {
				ids << property_id
			}
		}
		computed_interpolation_longhand_ids_cache = ids.clone()
	}
	return computed_interpolation_longhand_ids_cache
}

__global computed_interpolation_longhand_ids_cache = []PropertyID{}

__global computed_interpolation_unresolved_style_template = unsafe { &ComputedProperties(nil) }

fn computed_interpolation_is_longhand_property(property_id PropertyID) bool {
	// PropertyID is generated with every longhand in one contiguous block followed by
	// the shorthand-only entries. This is the V equivalent of the constant-time
	// generated longhand-index validation used by upstream.
	return int(property_id) >= int(first_longhand_property_id()) && int(property_id) <= int(last_longhand_property_id())
}

fn computed_interpolation_verify_longhand_property(property_id PropertyID) {
	// All internal call sites traffic in generated longhand IDs. Keep the guard in
	// development and test builds, but do not repeat it for every property lookup
	// in optimized browser builds.
	$if !prod {
		if !computed_interpolation_is_longhand_property(property_id) {
			panic('PropertyID ${property_id} is not a translated longhand property')
		}
	}
}

fn computed_interpolation_property_computation_order() ComputedInterpolationPropertyIDs {
	if computed_interpolation_computation_order_cache.len != 0 {
		return computed_interpolation_computation_order_cache
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// GeneratedCSSPropertyID.cpp puts dependency-bearing properties first. writing-mode determines
	// the axes of logical viewport units, including font sizes; math-depth feeds font-size,
	// the font set feeds font-relative units, line-height feeds lh units, color-scheme feeds
	// light-dark(), and background-image determines coordinated background-list lengths.
	manual_order := [
		PropertyID.writing_mode,
		.math_depth,
		.font_family,
		.font_feature_settings,
		.font_kerning,
		.font_optical_sizing,
		.font_size,
		.font_style,
		.font_synthesis_weight,
		.font_synthesis_style,
		.font_synthesis_small_caps,
		.font_synthesis_position,
		.font_variant_alternates,
		.font_variant_caps,
		.font_variant_east_asian,
		.font_variant_emoji,
		.font_variant_ligatures,
		.font_variant_numeric,
		.font_variant_position,
		.font_variation_settings,
		.font_weight,
		.font_width,
		.text_rendering,
		.line_height,
		.color_scheme,
		.background_image,
	]
	mut order := manual_order.clone()
	for property_id in computed_interpolation_longhand_property_ids() {
		if property_id !in manual_order {
			order << property_id
		}
	}
	computed_interpolation_computation_order_cache = order.clone()
	return computed_interpolation_computation_order_cache
}

__global computed_interpolation_computation_order_cache = []PropertyID{}
// Generated property IDs form one contiguous longhand range. Upstream's
// property_initial_value() dispatches directly on that enum; keep the retained
// typed values in the same enum-indexed shape instead of paying a hash lookup
// for every property of every styled element.
__global computed_interpolation_initial_value_cache = []&dom.StyleValue{}
__global (
	computed_interpolation_initial_values_complete      bool
	computed_interpolation_default_work_cache           = []u8{}
	computed_interpolation_default_computed_value_cache = []&dom.StyleValue{}
)

fn computed_interpolation_property_initial_value(property_id PropertyID) &dom.StyleValue {
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	// Retained initial values need no allocation or arena switch on a hit.
	if computed_interpolation_initial_value_cache.len != 0 {
		cached := computed_interpolation_initial_value_cache[index]
		if cached != unsafe { nil } { return cached }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if computed_interpolation_initial_value_cache.len == 0 {
		computed_interpolation_initial_value_cache = []&dom.StyleValue{len: number_of_longhand_properties, init: unsafe { nil }}
	}
	initial_text := property_initial_value_string(property_id)

	value := parse_css_value(ParsingParams{}, initial_text, property_id) or {
		return computed_interpolation_empty_style_value()
	}
	computed_interpolation_initial_value_cache[index] = value
	update_initial_computed_property_page(index, value)
	return value
}

fn computed_interpolation_is_inherited_property(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	ensure_computed_interpolation_inherited_cache()
	index := int(property_id) - int(first_longhand_property_id())
	return computed_interpolation_inherited_cache[index] != 0
}

fn ensure_computed_interpolation_inherited_cache() {
	if !computed_interpolation_inherited_cache_initialized {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		computed_interpolation_inherited_cache = []u8{len: number_of_longhand_properties}
		for index in 0 .. number_of_longhand_properties {
			if id := property_id_from_longhand_index(index) {
				if is_inherited_property(id) {
					computed_interpolation_inherited_cache[index] = 1
				}
			}
		}
		computed_interpolation_inherited_cache_initialized = true
	}
}

__global (
	computed_interpolation_inherited_cache             = []u8{}
	computed_interpolation_inherited_cache_initialized bool
)

fn computed_interpolation_style_value_keyword(value &dom.StyleValue) ?Keyword {
	if value.css_value_handle != unsafe { nil } {
		// The DOM value owns this box throughout the read. Inspect its retained
		// value directly rather than copying an optional sum type and rooting it.
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		keyword := typed.value.to_keyword()
		if keyword != .invalid {
			return keyword
		}
		return none
	}
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

$if test {
	fn computed_interpolation_style_value_is_revert(value &dom.StyleValue) bool {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .revert
	}
}

$if test {
	fn computed_interpolation_style_value_is_revert_layer(value &dom.StyleValue) bool {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .revert_layer
	}
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

$if test {
	fn computed_interpolation_style_value_is_currentcolor(value &dom.StyleValue) bool {
		return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .currentcolor
	}
}

fn property_affects_computed_font_list(id PropertyID) bool {
	computed_interpolation_verify_longhand_property(id)
	return id in [.font_family, .font_size, .font_style, .font_weight, .font_width,
		.font_variation_settings, .font_optical_sizing, .font_feature_settings,
		.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
		.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
		.font_variant_position, .font_kerning, .text_rendering, .font_synthesis_weight,
		.font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position]
}

fn property_affects_font_metrics(id PropertyID) bool {
	return id in [.font_size, .line_height]
}

fn font_size_value_depends_on_inherited_font_size(value StyleValue) bool {
	return value is PercentageStyleValue
		|| (value is CalculatedStyleValue && value.contains_percentage())
		|| value.to_keyword() in [.larger, .smaller, .math]
}


// --- ComputedProperties ---
pub enum ComputedPropertyInheritance as u8 {
	no
	yes
}

pub enum AnimatedPropertyResultOfTransition as u8 {
	no
	yes
}

pub enum WithAnimationsApplied as u8 {
	no
	yes
}

@[heap]
pub struct ComputedProperties {
mut:
	highlight_originating_color_ ?Color
pub mut:
	property_store_                          &ComputedPropertyStore = unsafe { nil }
	property_important_                      [computed_property_flag_byte_count]u8
	property_inherited_                      [computed_property_flag_byte_count]u8
	animated_property_inherited_             [computed_property_flag_byte_count]u8
	animated_property_result_of_transition_  [computed_property_flag_byte_count]u8
	display_before_box_type_transformation_  Display = Display.new()
	cached_computed_font_list_               ?&FontCascadeList
	cached_computed_font_list_generation_    u64
	cached_computed_font_list_owner_         &FontComputer = unsafe { nil }
	cached_first_available_computed_font_    &PlatformFont = unsafe { nil }
	// Keep the font-only refresh's original inputs even when a synchronous
	// font query materializes a replacement before style invalidation runs.
	font_input_refresh_snapshot_ &FontCascadeList = unsafe { nil }
	line_height_                             ?CSSPixels
	attempted_pseudo_class_matches_          PseudoClassBitmap
	raw_cascaded_font_size_                  ?&dom.StyleValue
	depends_on_viewport_metrics_             bool
	font_metrics_depend_on_viewport_metrics_ bool
	font_input_refresh_safe_ bool
	font_input_depends_on_font_size_ bool
	font_input_parent_font_size_ ?&dom.StyleValue
	// Lengths whose computed value remains viewport- or root-font-relative
	// need the same style-computation context when Layout resolves their used
	// value. LibWeb carries that context through the layout node; retaining it
	// here avoids silently turning vw/vh/rem into zero at the V boundary.
	viewport_rect_                                CSSPixelRect
	root_font_size_px_                            f64 = 16.0
	root_line_height_px_                          f64 = 19.2
	root_font_metrics_depend_on_viewport_metrics_ bool
	subject_is_pseudo_                            bool
	subject_element_                              ?&dom.Element
	position_try_reference_scope_ ?&StyleScope
	position_try_was_rendered_ bool

	// Layout::NodeWithStyle resolves these values once in apply_style(). Keeping
	// the translated ComputedValues slots on the retained object avoids decoding
	// StyleValue objects on every layout query.
	computed_values_resolved_                      bool
	computed_values_line_height_                   CSSPixels

mut:
	// Generated content is absent on ordinary elements. Marker payloads are
	// immutable snapshots, with the common builtins shared between styles.
	computed_list_style_storage_ &ListStyleType = unsafe { nil }
	computed_content_storage_ &ContentData = unsafe { nil }
	computed_property_graph_token_ &ComputedPropertyGraphMutationToken = unsafe { nil }
	computed_layout_cache_ &ComputedLayoutCache = unsafe { nil }
	shared_geometry_provenance_ &ComputedGeometryProvenance = unsafe { nil }
	shared_geometry_cache_ &ComputedLayoutCache = unsafe { nil }
	// Density conversion is memoized independently of resolved layout values.
	device_layout_projection_ &DeviceLayoutStyleProjection = unsafe { nil }
	// Serial number pairing this style with the snapshots it may rewrite in
	// place; see computed_layout_cache.v.
	layout_cache_owner_serial_ u64
	animated_property_storage_     &ComputedPropertyValueMap       = unsafe { nil }
	animated_custom_storage_       &ComputedCustomPropertyValueMap = unsafe { nil }
	inheritance_specified_storage_ &ComputedPropertyValueMap       = unsafe { nil }
	font_variation_storage_        &ComputedFontVariationMap       = unsafe { nil }
}

pub type ComputedValues = ComputedProperties

pub type ImmutableComputedValues = ComputedValues

pub type MutableComputedValues = ComputedValues

pub struct ComputedValuesStatistics {
pub:
	live_instance_count     u64
	total_instances_created u64
}

__global css_computed_values_total_instances u64
__global css_longhand_wrappers_minted u64

pub fn longhand_wrappers_minted() u64 {
	return css_longhand_wrappers_minted
}

pub fn reset_longhand_wrappers_minted() {
	css_longhand_wrappers_minted = 0
}

fn note_computed_values_created() {
	css_computed_values_total_instances++
}

pub fn computed_values_statistics() ComputedValuesStatistics {
	// Computed values are GC-managed in V; every allocated instance remains live
	// until the collector's next reachability pass, for which no destructor hook
	// is exposed. The allocation count is therefore the observable live count.
	return ComputedValuesStatistics{
		live_instance_count: css_computed_values_total_instances
		total_instances_created: css_computed_values_total_instances
	}
}

pub fn ComputedProperties.new() &ComputedProperties {
	note_computed_values_created()
	return &ComputedProperties{
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		property_store_: new_empty_computed_property_store()
	}
}

fn computed_properties_with_initial_values() &ComputedProperties {
	// The generated C++ ComputedProperties constructor starts from generated
	// initial values. Parsing and assigning the same 313 values one property at
	// a time for every element is needless work in V; build the immutable value
	// pointer template once and clone its dense array for each computed style.
	if !computed_interpolation_initial_values_complete {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		computed_interpolation_default_work_cache = []u8{len: number_of_longhand_properties}
		computed_interpolation_default_computed_value_cache = []&dom.StyleValue{len: number_of_longhand_properties, init: unsafe { nil }}
		for property_id in computed_interpolation_longhand_property_ids() {
			computed_interpolation_property_initial_value(property_id)
			index := int(property_id) - int(first_longhand_property_id())
			if computed_interpolation_is_inherited_property(property_id)
				|| property_requires_computation_with_initial_value(property_id) {
				computed_interpolation_default_work_cache[index] = 1
			}
		}
		computed_interpolation_initial_values_complete = true
	}
	note_computed_values_created()
	if computed_interpolation_unresolved_style_template == unsafe { nil } {
		persistent := platform.enter_persistent()
		computed_interpolation_unresolved_style_template = &ComputedProperties{}
		platform.leave_persistent(persistent)
	}
	template := computed_interpolation_unresolved_style_template
	// The layout-cache defaults are immutable until resolve_computed_values()
	// replaces them. Reuse their value graphs instead of allocating every nested
	// length and optional payload for every element. Each mutable store remains
	// owned by the new style, including each lazily created metadata map.
	return &ComputedProperties{
		...template
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		property_store_: new_initial_computed_property_store()
	}
}

// ComputedValues::clone_inherited_values(), followed by the display override
// used by Layout::NodeWithStyle::create_anonymous_wrapper(). Anonymous layout
// boxes inherit inherited properties from their generator, reset every other
// property to its initial value, and propagate the text-decoration properties
// which CSS applies through the anonymous box even though they are formally
// non-inherited.
pub fn (c &ComputedProperties) clone_for_anonymous_block() &ComputedProperties {
	// Anonymous table/flex wrappers are frequent on real pages. Start from the
	// already parsed initial-value template, then copy only inherited slots.
	// The old path visited and assigned all 313 longhands for every wrapper.
	mut clone := computed_properties_with_initial_values()
	clone.viewport_rect_ = c.viewport_rect_
	clone.root_font_size_px_ = c.root_font_size_px_
	clone.root_line_height_px_ = c.root_line_height_px_
	clone.root_font_metrics_depend_on_viewport_metrics_ = c.root_font_metrics_depend_on_viewport_metrics_
	clone.subject_element_ = c.subject_element_
	clone.subject_is_pseudo_ = c.subject_is_pseudo_
	ensure_computed_interpolation_inherited_cache()
	for index, inherited in computed_interpolation_inherited_cache {
		if inherited == 0 {
			continue
		}
		value := c.raw_property_at_index(index)
		if value != unsafe { nil } {
			clone.set_raw_property_at_index(index, value)
		}
		clone.property_inherited_[index / 8] |= u8(1) << (index % 8)
	}
	for property_id in [PropertyID.text_decoration_line, .text_decoration_thickness,
		.text_decoration_color, .text_decoration_style] {
		index := int(property_id) - int(first_longhand_property_id())
		value := c.raw_property_at_index(index)
		if value != unsafe { nil } {
			clone.set_raw_property_at_index(index, value)
		}
	}
	display := Display.from_outside_inside(.block, .flow)
	display_index := int(PropertyID.display) - int(first_longhand_property_id())
	clone.set_raw_property_at_index(display_index, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(display))))
	clone.display_before_box_type_transformation_ = display
	clone.inherit_layout_coordinate_context(c)
	return clone
}

pub fn (c &ComputedProperties) clone_for_anonymous_with_display(display Display) &ComputedProperties {
	mut clone := c.clone_for_anonymous_block()
	clone.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(display))))
	clone.display_before_box_type_transformation_ = display
	return clone
}

// ComputedValues::inherit_from(), used by Layout::NodeWithStyle when a style
// update has to be propagated into an already-existing anonymous wrapper.
// Keep the target's non-inherited values (notably its generated display), but
// refresh every inherited property and the text-decoration values which CSS
// propagates through anonymous boxes despite being formally non-inherited.
pub fn (mut c ComputedProperties) inherit_from_for_layout(source &ComputedProperties) {
	c.viewport_rect_ = source.viewport_rect_
	c.root_font_size_px_ = source.root_font_size_px_
	c.root_line_height_px_ = source.root_line_height_px_
	c.root_font_metrics_depend_on_viewport_metrics_ = source.root_font_metrics_depend_on_viewport_metrics_
	for property_id in computed_interpolation_longhand_property_ids() {
		if !computed_interpolation_is_inherited_property(property_id) {
			continue
		}
		if value := source.property(property_id, .no) {
			c.set_property(property_id, value, .yes, .no)
		}
	}
	for property_id in [PropertyID.text_decoration_line, .text_decoration_thickness,
		.text_decoration_color, .text_decoration_style] {
		if value := source.property(property_id, .no) {
			c.set_property_without_modifying_flags(property_id, value)
		}
	}
	c.inherit_layout_coordinate_context(source)
}

// The anonymous flex wrapper mandated by HTML's button-layout algorithm.
// TreeBuilder.cpp overrides these computed values after creating an ordinary
// anonymous wrapper.
pub fn (c &ComputedProperties) clone_for_button_flex_wrapper() &ComputedProperties {
	mut clone := c.clone_for_anonymous_with_display(Display.from_outside_inside(.block, .flex))
	for property_id, css_text in {
		PropertyID.justify_content: 'center'
		PropertyID.flex_direction:  'column'
		PropertyID.height:          '100%'
	} {
		parsed := parse_css_value_logic(property_id, css_text) or { continue }
		clone.set_property_without_modifying_flags(property_id, dom_style_value_from_value_logic(parsed))
	}
	return clone
}

// AnonymousBoxStyle.cpp's ButtonContentBox: the button's content must be
// allowed to shrink below its intrinsic block size inside the flex wrapper.
pub fn (c &ComputedProperties) clone_for_button_content_box(display Display) &ComputedProperties {
	mut clone := c.clone_for_anonymous_with_display(display)
	clone.set_property_without_modifying_flags(.min_height, dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(0)))))
	return clone
}

// A fieldset keeps its special block layout so the rendered legend can be
// positioned independently. Flex layout and alignment apply to this anonymous
// content wrapper instead.
pub fn (mut c ComputedProperties) take_properties_for_fieldset_content_box() &ComputedProperties {
	display := if c.display().is_flex_inside() {
		Display.from_outside_inside(.block, .flex)
	} else {
		Display.from_short(.flow_root)
	}
	mut content := c.clone_for_anonymous_with_display(display)
	for property_id in [PropertyID.flex_direction, .flex_wrap, .align_content, .align_items,
		.justify_content, .justify_items, .row_gap, .column_gap] {
		if value := c.property(property_id, .no) {
			content.set_property_without_modifying_flags(property_id, value)
		}
	}
	for property_id in [PropertyID.overflow_x, .overflow_y] {
		if value := c.property(property_id, .no) {
			content.set_property_without_modifying_flags(property_id, value)
		}
		c.set_property_without_modifying_flags(property_id, computed_interpolation_property_initial_value(property_id))
	}
	return content
}

// NodeWithStyle::transfer_table_box_computed_values_to_wrapper_computed_values().
// CSS table wrapper properties live on the anonymous wrapper and are reset to
// their initial values on the table-root box itself.
pub fn (mut c ComputedProperties) take_properties_for_table_wrapper() &ComputedProperties {
	wrapper_display := if c.display().is_inline_outside() {
		Display.from_short(.inline_block)
	} else {
		Display.from_short(.flow_root)
	}
	mut wrapper := c.clone_for_anonymous_with_display(wrapper_display)
	// The wrapper is the positioned box, so its static position must keep
	// the table's original block- or inline-level display.
	wrapper.set_display_before_box_type_transformation(c.display_before_box_type_transformation())
	for property_id in [PropertyID.position, .position_anchor, .top, .right, .bottom, .left, .float_,
		.clear, .grid_column_end, .grid_column_start, .grid_row_end, .grid_row_start,
		.align_self, .justify_self, .baseline_source, .order, .margin_top, .margin_right, .margin_bottom,
		.margin_left, .z_index] {
		if value := c.property(property_id, .no) {
			wrapper.set_property_without_modifying_flags(property_id, value)
		}
		c.set_property_without_modifying_flags(property_id, computed_interpolation_property_initial_value(property_id))
	}
	return wrapper
}

// NodeWithStyle::transfer_table_box_computed_values_to_wrapper_computed_values()
// edits the table box's own computed values. A V layout box shares its
// element's ComputedProperties, so the transfer applies to a copy for the
// table box: the element keeps its margins for every later layout tree build.
pub fn (c &ComputedProperties) table_box_and_wrapper_properties() (&ComputedProperties, &ComputedProperties) {
	c.share_computed_layout_cache()
	mut table := &ComputedProperties{
		...c
		property_store_:                c.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
	}
	wrapper := table.take_properties_for_table_wrapper()
	return table, wrapper
}

pub fn (c &ComputedProperties) for_each_property(callback fn (PropertyID, &dom.StyleValue)) {
	for index in 0 .. c.raw_property_count() {
		value := c.raw_property_at_index(index)
		if value != unsafe { nil } {
			if property_id := property_id_from_longhand_index(index) {
				callback(property_id, value)
			}
		}
	}
}

pub fn (c &ComputedProperties) anchor_names() []string {
	value := c.property(.anchor_name, .yes) or { return []string{} }
	parsed := style_value_logic_from_dom(.anchor_name, value) or { return []string{} }
	if parsed is CustomIdentStyleValue {
		return [parsed.custom_ident()]
	}
	if parsed is StyleValueList {
		mut names := []string{cap: parsed.size()}
		for item in parsed.values() {
			if item is CustomIdentStyleValue {
				names << item.custom_ident()
			}
		}
		return names
	}
	return []string{}
}

pub fn (c &ComputedProperties) container_name() []string {
	value := c.property(.container_name, .yes) or { return []string{} }
	parsed := style_value_logic_from_dom(.container_name, value) or { return []string{} }
	if parsed is CustomIdentStyleValue {
		return [parsed.custom_ident()]
	}
	if parsed is StyleValueList {
		mut names := []string{cap: parsed.size()}
		for item in parsed.values() {
			if item is CustomIdentStyleValue {
				names << item.custom_ident()
			}
		}
		return names
	}
	return []string{}
}

pub fn (c &ComputedProperties) animated_property_values() map[PropertyID]&dom.StyleValue {
	if c.animated_property_storage_ == unsafe { nil } { return map[PropertyID]&dom.StyleValue{} }
	return c.animated_property_storage_.values.clone()
}

pub fn (c &ComputedProperties) animated_custom_property_values() map[string]&dom.StyleValue {
	if c.animated_custom_storage_ == unsafe { nil } { return map[string]&dom.StyleValue{} }
	return c.animated_custom_storage_.values.clone()
}

pub fn (c &ComputedProperties) inheritance_dependent_specified_values() map[PropertyID]&dom.StyleValue {
	if c.inheritance_specified_storage_ == unsafe { nil } {
		return map[PropertyID]&dom.StyleValue{}
	}
	return c.inheritance_specified_storage_.values.clone()
}

pub fn (mut c ComputedProperties) add_inheritance_dependent_specified_value(property_id PropertyID, value &dom.StyleValue) {
	mut storage := c.ensure_inheritance_specified_storage()
	storage.values[property_id] = unsafe { value }
}

pub fn (c &ComputedProperties) raw_cascaded_font_size() ?&dom.StyleValue {
	return c.raw_cascaded_font_size_
}

pub fn (mut c ComputedProperties) set_raw_cascaded_font_size(value &dom.StyleValue) {
	c.raw_cascaded_font_size_ = unsafe { value }
}

pub fn (mut c ComputedProperties) reset_non_inherited_animated_properties() {
	c.note_computed_property_graph_mutation()
	if c.animated_property_storage_ == unsafe { nil } { return }
	// Every animation sample resets and reinstalls these values. Removing the
	// most recently inserted entries first lets the map drop them from the end
	// of its storage instead of recording holes, so the reinstalled values
	// reuse that storage.
	mut removed := [32]PropertyID{}
	mut removed_count := 0
	mut overflow := []PropertyID{}
	for property_id, _ in c.animated_property_storage_.values {
		if !c.is_animated_property_inherited(property_id) {
			if removed_count < removed.len {
				removed[removed_count] = property_id
				removed_count++
			} else {
				overflow << property_id
			}
		}
	}
	for index := overflow.len - 1; index >= 0; index-- {
		c.animated_property_storage_.values.delete(overflow[index])
	}
	for index := removed_count - 1; index >= 0; index-- {
		c.animated_property_storage_.values.delete(removed[index])
	}
}

pub fn (mut c ComputedProperties) reset_animated_custom_properties() {
	c.note_computed_property_graph_mutation()
	if c.animated_custom_storage_ != unsafe { nil } { c.animated_custom_storage_.values.clear() }
}

pub fn (c &ComputedProperties) is_property_important(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	return c.property_important_[index / 8] & (u8(1) << (index % 8)) != 0
}

pub fn (c &ComputedProperties) depends_on_viewport_metrics() bool {
	return c.depends_on_viewport_metrics_
}

pub fn (c &ComputedProperties) font_metrics_depend_on_viewport_metrics() bool {
	return c.font_metrics_depend_on_viewport_metrics_
}

pub fn (mut c ComputedProperties) set_depends_on_viewport_metrics() {
	c.depends_on_viewport_metrics_ = true
}

pub fn (mut c ComputedProperties) set_font_metrics_depend_on_viewport_metrics() {
	c.font_metrics_depend_on_viewport_metrics_ = true
}

pub fn (c &ComputedProperties) is_property_inherited(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	return c.property_inherited_[index / 8] & (u8(1) << (index % 8)) != 0
}

pub fn (c &ComputedProperties) is_animated_property_inherited(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	return c.animated_property_inherited_[index / 8] & (u8(1) << (index % 8)) != 0
}

pub fn (c &ComputedProperties) is_animated_property_result_of_transition(property_id PropertyID) bool {
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	return c.animated_property_result_of_transition_[index / 8] & (u8(1) << (index % 8)) != 0
}

fn set_computed_property_flag(mut flags [computed_property_flag_byte_count]u8, property_id PropertyID, enabled bool) {
	index := int(property_id) - int(first_longhand_property_id())
	mask := u8(1) << (index % 8)
	if enabled {
		flags[index / 8] |= mask
	} else {
		flags[index / 8] &= ~mask
	}
}

pub fn (mut c ComputedProperties) set_property_important(property_id PropertyID, important Important) {
	computed_interpolation_verify_longhand_property(property_id)
	if c.is_property_important(property_id) != (important == .yes) {
		c.note_raw_computed_property_graph_mutation()
	}
	set_computed_property_flag(mut c.property_important_, property_id, important == .yes)
}

pub fn (mut c ComputedProperties) set_property_inherited(property_id PropertyID, inherited ComputedPropertyInheritance) {
	computed_interpolation_verify_longhand_property(property_id)
	if c.is_property_inherited(property_id) != (inherited == .yes) {
		c.note_raw_computed_property_graph_mutation()
	}
	set_computed_property_flag(mut c.property_inherited_, property_id, inherited == .yes)
}

pub fn (mut c ComputedProperties) set_animated_property_inherited(property_id PropertyID, inherited ComputedPropertyInheritance) {
	computed_interpolation_verify_longhand_property(property_id)
	set_computed_property_flag(mut c.animated_property_inherited_, property_id, inherited == .yes)
}

pub fn (mut c ComputedProperties) set_animated_property_result_of_transition(property_id PropertyID, result AnimatedPropertyResultOfTransition) {
	computed_interpolation_verify_longhand_property(property_id)
	set_computed_property_flag(mut c.animated_property_result_of_transition_, property_id, result == .yes)
}

pub fn (mut c ComputedProperties) set_property(property_id PropertyID, value &dom.StyleValue, inherited ComputedPropertyInheritance, important Important) {
	c.set_property_without_modifying_flags(property_id, value)
	c.set_property_important(property_id, important)
	c.set_property_inherited(property_id, inherited)
}

pub fn (mut c ComputedProperties) set_property_without_modifying_flags(property_id PropertyID, value &dom.StyleValue) {
	c.note_raw_computed_property_graph_mutation()
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	c.set_raw_property_at_index(index, value)
	if property_affects_computed_font_list(property_id) {
		c.clear_computed_font_list_cache()
	}
}

pub fn (mut c ComputedProperties) set_animated_property(property_id PropertyID, value &dom.StyleValue, result AnimatedPropertyResultOfTransition, inherited ComputedPropertyInheritance) {
	c.note_computed_property_graph_mutation()
	computed_interpolation_verify_longhand_property(property_id)
	mut storage := c.ensure_animated_property_storage()
	storage.values[property_id] = unsafe { value }
	c.set_animated_property_inherited(property_id, inherited)
	c.set_animated_property_result_of_transition(property_id, result)
	if property_affects_computed_font_list(property_id) {
		c.clear_computed_font_list_cache()
	}
}

pub fn (mut c ComputedProperties) set_animated_custom_property(name string, value &dom.StyleValue) {
	c.note_computed_property_graph_mutation()
	mut storage := c.ensure_animated_custom_storage()
	storage.values[name] = unsafe { value }
}

pub fn (mut c ComputedProperties) remove_animated_property(property_id PropertyID) {
	c.note_computed_property_graph_mutation()
	computed_interpolation_verify_longhand_property(property_id)
	if c.animated_property_storage_ != unsafe { nil } {
		c.animated_property_storage_.values.delete(property_id)
	}
}

@[inline]
pub fn (c &ComputedProperties) property(property_id PropertyID, return_animated_value WithAnimationsApplied) ?&dom.StyleValue {
	computed_interpolation_verify_longhand_property(property_id)
	// Important properties override animated but not transitioned properties.
	if return_animated_value == .yes && c.has_animated_properties()
		&& (!c.is_property_important(property_id)
			|| c.is_animated_property_result_of_transition(property_id)) {
		if animated := c.animated_property_value(property_id) {
			return animated
		}
	}

	// By the time C++ calls this method, the property should have been assigned.
	index := int(property_id) - int(first_longhand_property_id())
	value := c.raw_property_at_index(index)
	if value == unsafe { nil } {
		return none
	}
	return value
}

pub fn (mut c ComputedProperties) revert_property(property_id PropertyID, style_for_revert &ComputedProperties) {
	c.note_raw_computed_property_graph_mutation()
	computed_interpolation_verify_longhand_property(property_id)
	index := int(property_id) - int(first_longhand_property_id())
	c.set_raw_property_at_index(index, style_for_revert.raw_property_at_index(index))
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
	parsed_value := style_value_logic_from_dom(property_id, value) or {
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
	value := c.property(property_id, .yes) or { return Size.make_auto() }
	if value.css_value_handle != unsafe { nil } {
		return Size.from_style_value(unsafe { (&TypedStyleValueBox(value.css_value_handle)).value })
	}
	parsed := style_value_logic_from_dom(property_id, value) or { return Size.make_auto() }
	return Size.from_style_value(parsed)
}

pub fn (c &ComputedProperties) length(property_id PropertyID) Length {
	value := c.property(property_id, .yes) or { return Length.make_px(0) }
	// Read the existing retained length before constructing the optional
	// percentage basis used only by the general conversion fallback.
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if typed.value is LengthStyleValue {
			return typed.value.length()
		}
	}
	return Length.from_style_value(value, none)
}

pub fn (c &ComputedProperties) length_box(left_id PropertyID, top_id PropertyID, right_id PropertyID, bottom_id PropertyID, default_value LengthPercentageOrAuto) LengthBox {
	left := if value := c.property(left_id, .yes) {
		LengthPercentageOrAuto.from_style_value(value)
	} else {
		default_value
	}
	top := if value := c.property(top_id, .yes) {
		LengthPercentageOrAuto.from_style_value(value)
	} else {
		default_value
	}
	right := if value := c.property(right_id, .yes) {
		LengthPercentageOrAuto.from_style_value(value)
	} else {
		default_value
	}
	bottom := if value := c.property(bottom_id, .yes) {
		LengthPercentageOrAuto.from_style_value(value)
	} else {
		default_value
	}
	return LengthBox.with_values(top, right, bottom, left)
}

pub fn (c &ComputedProperties) color_or_fallback(property_id PropertyID, color_resolution_context ColorResolutionContext, fallback ComputedColor) ComputedColor {
	value := c.property(property_id, .yes) or { return fallback }
	// The DOM value owns this typed box throughout the synchronous conversion.
	// Avoid copying the entire StyleValue union through an optional on this path.
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		return computed_color_or_fallback(&typed.value, color_resolution_context, fallback)
	}
	parsed_value := style_value_logic_from_dom(property_id, value) or { return fallback }
	return computed_color_or_fallback(&parsed_value, color_resolution_context, fallback)
}

fn computed_color_or_fallback(parsed_value &StyleValue, color_resolution_context ColorResolutionContext, fallback ComputedColor) ComputedColor {
	if !parsed_value.has_color() {
		return fallback
	}
	color := parsed_value.to_color(color_resolution_context) or { return fallback }
	return ComputedColor.rgba(color.red(), color.green(), color.blue(), color.alpha())
}

fn color_scheme_style_value_from_dom_style_value(value &dom.StyleValue) ?ColorSchemeStyleValue {
	parsed_value := style_value_logic_from_dom(.color_scheme, value) or { return none }
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
		return computed_interpolation_default_color_scheme(preferred_scheme, document_supported_schemes)
	}
	scheme_value := color_scheme_style_value_from_dom_style_value(scheme_property) or {
		return computed_interpolation_default_color_scheme(preferred_scheme, document_supported_schemes)
	}

	if element_scheme := used_color_scheme_from_scheme_list(scheme_value.schemes(), preferred_scheme) {
		return element_scheme
	}

	// FIXME: We don't currently support setting an "overriding preference" for color schemes.
	// `normal` indicates that the element supports the page's supported color schemes, if they are set.
	return computed_interpolation_default_color_scheme(preferred_scheme, document_supported_schemes)
}

fn computed_interpolation_split_coordinating_list_value(value &dom.StyleValue) []&dom.StyleValue {
	// Coordinating list properties are represented by a comma-separated
	// StyleValueList. Preserve the typed values when they came through the CSS
	// bridge; falling back to text here would discard exactly the representation
	// that the computed style cache keeps alive.
	if typed := typed_style_value_logic_from_dom(value) {
		if typed is StyleValueList && typed.separator() == .comma {
			mut typed_values := []&dom.StyleValue{cap: typed.size()}
			for item in typed.values() {
				typed_values << dom_style_value_from_value_logic(item)
			}
			return typed_values
		}
	}

	// Hand-authored DOM bridge values have no typed handle, so subdivide the
	// serialized list. Commas inside nested functions or strings belong to the
	// item rather than the coordinating list.
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

pub fn (c &ComputedProperties) color_interpolation_filters() ColorInterpolation {
	value := c.property(.color_interpolation_filters, .yes) or { return .srgb_linear }
	keyword := computed_interpolation_style_value_keyword(value) or { return .srgb_linear }
	return match keyword {
		.auto { ColorInterpolation.auto_ }
		.srgb { ColorInterpolation.srgb }
		.linearrgb { ColorInterpolation.srgb_linear }
		else { ColorInterpolation.srgb_linear }
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
	value := c.property(.dominant_baseline, .yes) or { return none }
	keyword := computed_interpolation_style_value_keyword(value) or { return none }
	return match keyword {
		.alphabetic {
			.alphabetic
		}
		.central {
			.central
		}
		.hanging {
			.hanging
		}
		.ideographic {
			.ideographic
		}
		.mathematical {
			.mathematical
		}
		.middle {
			.middle
		}
		else {
			match value.css_text {
				'text-before-edge' { BaselineMetric.text_top }
				'text-after-edge' { BaselineMetric.text_bottom }
				else { none }
			}
		}
	}
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

pub fn (c &ComputedProperties) font_smoothing() FontSmoothing {
	value := c.property(.webkit_font_smoothing, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return match keyword {
		.auto { FontSmoothing.auto_ }
		.none_ { FontSmoothing.none_ }
		.antialiased { FontSmoothing.antialiased }
		.subpixel_antialiased { FontSmoothing.subpixel_antialiased }
		else { FontSmoothing.auto_ }
	}
}

pub fn (c &ComputedProperties) text_underline_offset() CSSPixels {
	value := c.property(.text_underline_offset, .yes) or {
		return InitialValues.text_underline_offset()
	}
	if computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .auto {
		return InitialValues.text_underline_offset()
	}
	parsed := style_value_logic_from_dom(.text_underline_offset, value) or {
		return InitialValues.text_underline_offset()
	}
	return Length.from_style_value_logic(parsed, Length.make_css_px(c.font_size())).absolute_length_to_px()
}

pub fn (c &ComputedProperties) text_underline_position() TextUnderlinePosition {
	value := c.property(.text_underline_position, .yes) or { return TextUnderlinePosition{} }
	parsed := style_value_logic_from_dom(.text_underline_position, value) or {
		return TextUnderlinePosition{}
	}
	if parsed is TextUnderlinePositionStyleValue {
		return TextUnderlinePosition{
			horizontal: parsed.horizontal()
			vertical: parsed.vertical()
		}
	}
	return TextUnderlinePosition{}
}

pub struct TextUnderlinePosition {
pub mut:
	horizontal TextUnderlinePositionHorizontal
	vertical   TextUnderlinePositionVertical
}

pub fn (c &ComputedProperties) background_layers() []BackgroundLayerData {
	image_property := c.property(.background_image, .yes) or { return []BackgroundLayerData{} }
	if computed_coordinating_value_is_none(image_property) { return []BackgroundLayerData{} }
	image_values := computed_interpolation_split_coordinating_list_value(image_property)
	mut any_image := false
	for image_value in image_values {
		if computed_interpolation_style_value_keyword(image_value) or { Keyword.invalid } != .none_ {
			any_image = true
			break
		}
	}
	if !any_image {
		return []BackgroundLayerData{}
	}
	coordinated := c.assemble_coordinated_value_list(.background_image, [
		PropertyID.background_attachment,
		.background_blend_mode,
		.background_clip,
		.background_image,
		.background_origin,
		.background_position_x,
		.background_position_y,
		.background_repeat,
		.background_size,
	])
	images := coordinated[.background_image] or { return []BackgroundLayerData{} }
	mut layers := []BackgroundLayerData{}
	for index, image in images {
		if computed_interpolation_style_value_keyword(image) or { Keyword.invalid } == .none_ {
			continue
		}
		attachments := coordinated[.background_attachment] or { continue }
		blends := coordinated[.background_blend_mode] or { continue }
		clips := coordinated[.background_clip] or { continue }
		origins := coordinated[.background_origin] or { continue }
		positions_x := coordinated[.background_position_x] or { continue }
		positions_y := coordinated[.background_position_y] or { continue }
		repeats := coordinated[.background_repeat] or { continue }
		sizes := coordinated[.background_size] or { continue }
		if index >= attachments.len || index >= blends.len || index >= clips.len || index >= origins.len || index >= positions_x.len || index >= positions_y.len || index >= repeats.len || index >= sizes.len {
			continue
		}
		attachment_value := attachments[index]
		blend_value := blends[index]
		clip_value := clips[index]
		origin_value := origins[index]
		position_x_value := positions_x[index]
		position_y_value := positions_y[index]
		repeat_value := repeats[index]
		size_value := sizes[index]

		mut layer := BackgroundLayerData{
			image: image.css_text
			attachment: keyword_to_background_attachment_for_computed_properties(computed_interpolation_style_value_keyword(attachment_value) or {
				Keyword.scroll
			}) or { BackgroundAttachment.scroll }
			blend_mode: keyword_to_mix_blend_mode_for_computed_properties(computed_interpolation_style_value_keyword(blend_value) or {
				Keyword.normal
			}) or { MixBlendMode.normal }
			clip: keyword_to_background_box_for_computed_properties(computed_interpolation_style_value_keyword(clip_value) or {
				Keyword.border_box
			}, .border_box)
			origin: keyword_to_background_box_for_computed_properties(computed_interpolation_style_value_keyword(origin_value) or {
				Keyword.padding_box
			}, .padding_box)
		}
		if parsed_x := style_value_logic_from_dom(.background_position_x, position_x_value) {
			if parsed_x is EdgeStyleValue {
				layer.position_x = LengthPercentage.from_style_value_logic(parsed_x.with_resolved_keywords().offset())
			}
		}
		if parsed_y := style_value_logic_from_dom(.background_position_y, position_y_value) {
			if parsed_y is EdgeStyleValue {
				layer.position_y = LengthPercentage.from_style_value_logic(parsed_y.with_resolved_keywords().offset())
			}
		}
		if repeat := style_value_logic_from_dom(.background_repeat, repeat_value) {
			if repeat is RepeatStyleStyleValue {
				layer.repeat_x = repeat.repeat_x()
				layer.repeat_y = repeat.repeat_y()
			}
		}
		if size := style_value_logic_from_dom(.background_size, size_value) {
			if size is BackgroundSizeStyleValue {
				layer.size_type = .length_percentage
				layer.size_x = LengthPercentageOrAuto.from_style_value_logic(size.size_x())
				layer.size_y = LengthPercentageOrAuto.from_style_value_logic(size.size_y())
			} else if size.to_keyword() == .contain {
				layer.size_type = .contain
			} else if size.to_keyword() == .cover {
				layer.size_type = .cover
			}
		}
		layers << layer
	}
	return layers
}

pub fn (c &ComputedProperties) background_color_clip() BackgroundBox {
	image_property := c.property(.background_image, .yes) or { return .border_box }
	clip_property := c.property(.background_clip, .yes) or { return .border_box }
	if image_count := typed_coordinating_value_count(image_property) {
		if clip_count := typed_coordinating_value_count(clip_property) {
			if image_count == 0 || clip_count == 0 { return .border_box }
			if keyword := typed_coordinating_keyword_at(clip_property, (image_count - 1) % clip_count) {
				return keyword_to_background_box_for_computed_properties(keyword, .border_box)
			}
		}
	}
	images := computed_interpolation_split_coordinating_list_value(image_property)
	clips := computed_interpolation_split_coordinating_list_value(clip_property)
	if images.len == 0 || clips.len == 0 {
		return .border_box
	}
	index := (images.len - 1) % clips.len
	keyword := computed_interpolation_style_value_keyword(clips[index]) or { return .border_box }
	return keyword_to_background_box_for_computed_properties(keyword, .border_box)
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
	value := c.property(.border_spacing, .yes) or { return Length.make_px(0) }
	parsed := style_value_logic_from_dom(.border_spacing, value) or { return Length.make_px(0) }
	if parsed is StyleValueList && parsed.size() > 0 {
		return Length.from_style_value_logic(parsed.value_at(0, false), none)
	}
	return Length.from_style_value_logic(parsed, none)
}

pub fn (c &ComputedProperties) border_spacing_vertical() Length {
	value := c.property(.border_spacing, .yes) or { return Length.make_px(0) }
	parsed := style_value_logic_from_dom(.border_spacing, value) or { return Length.make_px(0) }
	if parsed is StyleValueList && parsed.size() > 0 {
		return Length.from_style_value_logic(parsed.value_at(if parsed.size() > 1 { 1 } else { 0 }, false), none)
	}
	return Length.from_style_value_logic(parsed, none)
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
	value := c.property(.clip, .yes) or { return Clip.make_auto() }
	parsed := style_value_logic_from_dom(.clip, value) or { return Clip.make_auto() }
	if parsed is RectStyleValue {
		return Clip.from_rect(parsed.rect())
	}
	return Clip.make_auto()
}

pub fn (c &ComputedProperties) display() Display {
	// The Display property is always represented by DisplayStyleValue. Empty
	// hand-built ComputedProperties used by low-level tests retain the initial fallback.
	value := c.property(.display, .yes) or { return Display.from_short(.inline_) }
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if typed.value is DisplayStyleValue {
			return typed.value.display()
		}
	}
	typed := style_value_logic_from_dom(.display, value) or {
		panic('Computed display value is not a typed StyleValue')
	}
	if typed is DisplayStyleValue {
		return typed.display()
	}
	panic('Computed display value is not a DisplayStyleValue')
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

pub fn (c &ComputedProperties) break_between(property_id PropertyID) BreakBetween {
	if property_id !in [.break_after, .break_before] {
		return .auto
	}
	value := c.property(property_id, .yes) or { return .auto }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto }
	return match keyword {
		.auto { BreakBetween.auto }
		.avoid { BreakBetween.avoid }
		.avoid_page { BreakBetween.avoid_page }
		.page { BreakBetween.page }
		.left { BreakBetween.left }
		.right { BreakBetween.right }
		.recto { BreakBetween.recto }
		.verso { BreakBetween.verso }
		.avoid_column { BreakBetween.avoid_column }
		.column { BreakBetween.column }
		.avoid_region { BreakBetween.avoid_region }
		.region { BreakBetween.region }
		else { BreakBetween.auto }
	}
}

pub fn (c &ComputedProperties) break_inside() BreakInside {
	value := c.property(.break_inside, .yes) or { return .auto }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto }
	return match keyword {
		.auto { BreakInside.auto }
		.avoid { BreakInside.avoid }
		.avoid_page { BreakInside.avoid_page }
		.avoid_column { BreakInside.avoid_column }
		.avoid_region { BreakInside.avoid_region }
		else { BreakInside.auto }
	}
}

pub fn (c &ComputedProperties) box_decoration_break() BoxDecorationBreak {
	value := c.property(.box_decoration_break, .yes) or { return .slice }
	keyword := computed_interpolation_style_value_keyword(value) or { return .slice }
	return if keyword == .clone { .clone } else { .slice }
}

pub fn (c &ComputedProperties) column_fill() ColumnFill {
	value := c.property(.column_fill, .yes) or { return .balance }
	keyword := computed_interpolation_style_value_keyword(value) or { return .balance }
	return match keyword {
		.auto { ColumnFill.auto }
		.balance_all { ColumnFill.balance_all }
		else { ColumnFill.balance }
	}
}

pub fn (c &ComputedProperties) block_ellipsis() BlockEllipsis {
	value := c.property(.block_ellipsis, .yes) or {
		return BlockEllipsis{
			type_: .no_ellipsis
		}
	}
	parsed := style_value_logic_from_dom(.block_ellipsis, value) or {
		return BlockEllipsis{
			type_: .no_ellipsis
		}
	}
	if parsed is StringStyleValue {
		return BlockEllipsis{
			type_: .string
			text_: parsed.string_value()
		}
	}
	if parsed.to_keyword() == .auto {
		return BlockEllipsis{
			type_: .auto_
		}
	}
	return BlockEllipsis{
		type_: .no_ellipsis
	}
}

pub fn (c &ComputedProperties) continue_value() ContinueValue {
	value := c.property(.continue_, .yes) or { return .auto_ }
	return match computed_interpolation_style_value_keyword(value) or { Keyword.auto } {
		.discard { ContinueValue.discard }
		.collapse { ContinueValue.collapse }
		.webkit_legacy { ContinueValue.webkit_legacy }
		else { ContinueValue.auto_ }
	}
}

pub fn (c &ComputedProperties) max_lines() ?int {
	value := c.property(.max_lines, .yes) or { return none }
	if integer := computed_interpolation_integer_from_dom_style_value(value) {
		return int(integer)
	}
	return none
}

pub fn (c &ComputedProperties) webkit_box_orient() WebkitBoxOrient {
	value := c.property(.webkit_box_orient, .yes) or { return .horizontal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .horizontal }
	return if keyword == .vertical { .vertical } else { .horizontal }
}

pub fn (c &ComputedProperties) content(abstract_element &dom.AbstractElement, initial_quote_nesting_level u32, registered_counter_styles map[string]CounterStyle) ContentDataAndQuoteNestingLevel {
	value := c.property(.content, .yes) or {
		return ContentDataAndQuoteNestingLevel{
			final_quote_nesting_level: initial_quote_nesting_level
		}
	}
	parsed := style_value_logic_from_dom(.content, value) or {
		return ContentDataAndQuoteNestingLevel{
			final_quote_nesting_level: initial_quote_nesting_level
		}
	}
	keyword := parsed.to_keyword()
	if keyword == .none_ || keyword == .normal {
		return ContentDataAndQuoteNestingLevel{
			content_data: ContentData{
				type_: if keyword == .none_ {
					ContentDataType.none_
				} else {
					ContentDataType.normal
				}
			}
			final_quote_nesting_level: initial_quote_nesting_level
		}
	}
	if parsed !is ContentStyleValue {
		return ContentDataAndQuoteNestingLevel{
			final_quote_nesting_level: initial_quote_nesting_level
		}
	}
	content_value := parsed as ContentStyleValue
	quotes := c.quotes()
	mut nesting := initial_quote_nesting_level
	mut text := ''
	mut items := []ContentItem{}
	mut counter_style_dependencies := []?CounterStyle{}
	for item in content_value.content().values() {
		if item is StringStyleValue {
			string_item := item.string_value()
			text += string_item
			items << ContentItem{
				type_: .text
				value: string_item
			}
			continue
		}
		if item is ImageStyleValue {
			items << ContentItem{
				type_: .image
				value: item.url_.url()
			}
			continue
		}
		// https://drafts.csswg.org/css-content-3/#typedef-content-list
		// https://drafts.csswg.org/css-images-4/#typedef-image
		// <content-list> accepts <image>, and image-set() is an <image>.
		if item is ImageSetStyleValue {
			device_pixels_per_css_pixel := abstract_element.element().document().device_pixels_per_css_pixel()
			if index := item.select_image_index(device_pixels_per_css_pixel) {
				option := item.options_[index]
				if option.image is ImageStyleValue {
					items << ContentItem{
						type_: .image
						value: option.image.url_.url()
						resolution: option.resolution.dots_per_pixel() or { 1.0 }
					}
				}
			}
			continue
		}
		if item is CounterStyleValue {
			counter_style_dependencies << item.counter_style().resolve_counter_style(registered_counter_styles)
			counter_text := item.resolve_for_abstract_element(abstract_element, registered_counter_styles)
			text += counter_text
			items << ContentItem{
				type_: .text
				value: counter_text
			}
			continue
		}
		item_keyword := item.to_keyword()
		if item_keyword == .open_quote || item_keyword == .close_quote {
			if item_keyword == .close_quote && nesting == 0 {
				continue
			}
			is_open := item_keyword == .open_quote
			if !is_open {
				nesting--
			}
			depth := nesting
			mut quote_text := ''
			if quotes.none_ {
				quote_text = ''
			} else if quotes.pairs.len >= 2 {
				pair_count := quotes.pairs.len / 2
				pair_index := if int(depth) < pair_count { int(depth) } else { pair_count - 1 }
				quote_text = quotes.pairs[pair_index * 2 + if is_open { 0 } else { 1 }]
			} else if is_open {
				quote_text = if depth == 0 { '“' } else { '‘' }
			} else {
				quote_text = if depth == 0 { '”' } else { '’' }
			}
			if quote_text.len > 0 {
				text += quote_text
				items << ContentItem{
					type_: .text
					value: quote_text
				}
			}
			if is_open {
				nesting++
			}
		} else if item_keyword == .no_open_quote {
			nesting++
		} else if item_keyword == .no_close_quote && nesting > 0 {
			nesting--
		}
	}
	mut alt_text := ''
	has_alt_text := content_value.alt_text() != none
	if alt := content_value.alt_text() {
		for item in alt.values() {
			if item is StringStyleValue {
				alt_text += item.string_value()
			} else if item is CounterStyleValue {
				counter_style_dependencies << item.counter_style().resolve_counter_style(registered_counter_styles)
				alt_text += item.resolve_for_abstract_element(abstract_element, registered_counter_styles)
			}
		}
	}
	return ContentDataAndQuoteNestingLevel{
		content_data: ContentData{
			type_: .list
			text: text
			alt_text: alt_text
			has_alt_text: has_alt_text
			items: items
			counter_style_dependencies: counter_style_dependencies
		}
		final_quote_nesting_level: nesting
	}
}

// A single authored <image> is a content replacement. Inspect the computed
// content list before quote controls and counters are resolved, since an item
// such as no-open-quote must still prevent replacement even though it emits no
// text node.
pub fn (c &ComputedProperties) content_replacement_image(abstract_element &dom.AbstractElement) ?ContentItem {
	value := c.property(.content, .yes) or { return none }
	parsed := style_value_logic_from_dom(.content, value) or { return none }
	if parsed !is ContentStyleValue {
		return none
	}
	items := (parsed as ContentStyleValue).content().values()
	if items.len != 1 {
		return none
	}
	item := items[0]
	if item is ImageStyleValue {
		return ContentItem{
			type_: .image
			value: item.url_.url()
		}
	}
	if item is ImageSetStyleValue {
		device_pixels_per_css_pixel := abstract_element.element().document().device_pixels_per_css_pixel()
		index := item.select_image_index(device_pixels_per_css_pixel) or { return none }
		option := item.options_[index]
		if option.image is ImageStyleValue {
			return ContentItem{
				type_:      .image
				value:      option.image.url_.url()
				resolution: option.resolution.dots_per_pixel() or { 1.0 }
			}
		}
	}
	return none
}

// Resolve a URL-backed abstract image to the same generated-content record
// used by ImageBox. This is also used by list-style-image marker content.
pub fn content_item_for_abstract_image(value StyleValue, device_pixels_per_css_pixel f64) ?ContentItem {
	if value is ImageStyleValue {
		return ContentItem{
			type_: .image
			value: value.url_.url()
		}
	}
	if value is ImageSetStyleValue {
		index := value.select_image_index(device_pixels_per_css_pixel) or { return none }
		option := value.options_[index]
		if option.image is ImageStyleValue {
			return ContentItem{
				type_: .image
				value: option.image.url_.url()
				resolution: option.resolution.dots_per_pixel() or { 1.0 }
			}
		}
	}
	return none
}

pub fn (c &ComputedProperties) content_visibility() ContentVisibility {
	if value := c.property(.content_visibility, .yes) {
		return content_visibility_from_style_value(value) or { ContentVisibility.visible }
	}
	return .visible
}

pub fn (c &ComputedProperties) cursor() []CursorData {
	value := c.property(.cursor, .yes) or { return [CursorData{ keyword: 'auto' }] }
	parsed := style_value_logic_from_dom(.cursor, value) or {
		return [CursorData{ keyword: 'auto' }]
	}
	mut result := []CursorData{}
	if parsed is StyleValueList {
		for item in parsed.values() {
			result << CursorData{
				keyword: item.serialize(.normal)
			}
		}
	} else {
		result << CursorData{
			keyword: parsed.serialize(.normal)
		}
	}
	if result.len == 0 {
		result << CursorData{
			keyword: 'auto'
		}
	}
	return result
}

pub fn (c &ComputedProperties) tab_size() TabSize {
	value := c.property(.tab_size, .yes) or { return TabSize.number(8) }
	parsed := style_value_logic_from_dom(.tab_size, value) or { return TabSize.number(8) }
	if parsed is LengthStyleValue {
		return TabSize.length(parsed.length())
	}
	if parsed is CalculatedStyleValue {
		if length := parsed.resolve_length(CalculationResolutionContext{}) {
			return TabSize.length(length)
		}
		if number := parsed.resolve_number(CalculationResolutionContext{}) {
			return TabSize.number(number)
		}
	}
	if parsed is NumberStyleValue {
		return TabSize.number(parsed.number())
	}
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
	parsed_value := style_value_logic_from_dom(.white_space_trim, value) or {
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
					.discard_before {
						trim_data.discard_before = true
					}
					.discard_after {
						trim_data.discard_after = true
					}
					.discard_inner {
						trim_data.discard_inner = true
					}
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
	parsed_value := style_value_logic_from_dom(.text_decoration_line, value) or {
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

pub fn (c &ComputedProperties) text_decoration_skip_ink() TextDecorationSkipInk {
	value := c.property(.text_decoration_skip_ink, .yes) or { return .auto }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto }
	return match keyword {
		.all { TextDecorationSkipInk.all }
		.none_ { TextDecorationSkipInk.none_ }
		else { TextDecorationSkipInk.auto }
	}
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
			is_auto: false
			from_font: true
		}
	}
	parsed_value := style_value_logic_from_dom(.text_decoration_thickness, value) or {
		return TextDecorationThickness{}
	}
	match parsed_value {
		LengthStyleValue, PercentageStyleValue, CalculatedStyleValue {
			return TextDecorationThickness{
				is_auto: false
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
	return c.shadow(.text_shadow, layout_node)
}

pub fn (c &ComputedProperties) text_indent() TextIndentData {
	value := c.property(.text_indent, .yes) or { return TextIndentData{} }
	parsed_value := style_value_logic_from_dom(.text_indent, value) or {
		return TextIndentData{}
	}
	if parsed_value is TextIndentStyleValue {
		return TextIndentData{
			length_percentage: LengthPercentage.from_style_value_logic(parsed_value.length_percentage())
			each_line: parsed_value.each_line()
			hanging: parsed_value.hanging()
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

// Layout reapplies list-style-type on every style update, including each
// animation sample; share the predefined styles instead of rebuilding their
// symbol lists. Nothing mutates a resolved counter style.
struct BuiltinCounterStyles {
	disc    CounterStyle
	decimal CounterStyle
	circle CounterStyle
	square CounterStyle
	disclosure_open CounterStyle
	disclosure_closed CounterStyle
mut:
	disc_list_style &ListStyleType = unsafe { nil }
	decimal_list_style &ListStyleType = unsafe { nil }
}

__global css_builtin_counter_styles_ = &BuiltinCounterStyles(unsafe { nil })

fn builtin_counter_styles() &BuiltinCounterStyles {
	if css_builtin_counter_styles_ == unsafe { nil } {
		persistent := platform.enter_persistent()
		css_builtin_counter_styles_ = &BuiltinCounterStyles{
			disc:    CounterStyle.disc()
			decimal: CounterStyle.decimal()
			circle: fixed_symbol_counter_style('circle', '◦')
			square: fixed_symbol_counter_style('square', '▪')
			disclosure_open: fixed_symbol_counter_style('disclosure-open', '▾')
			disclosure_closed: fixed_symbol_counter_style('disclosure-closed', '▸')
		}
		platform.leave_persistent(persistent)
	}
	return css_builtin_counter_styles_
}

pub fn (c &ComputedProperties) list_style_type_for_scope(scope &StyleScope) ListStyleType {
	value := c.property(.list_style_type, .yes) or {
		return ListStyleType{
			kind: .counter_style
			name: 'disc'
			counter_style: builtin_counter_styles().disc
		}
	}
	parsed := style_value_logic_from_dom(.list_style_type, value) or {
		return ListStyleType{
			kind: .counter_style
			name: 'disc'
			counter_style: builtin_counter_styles().disc
		}
	}
	if parsed.to_keyword() == .none_ {
		return ListStyleType{
			kind: .none_
		}
	}
	if parsed is StringStyleValue {
		return ListStyleType{
			kind: .string
			name: parsed.string_value()
		}
	}
	if parsed is CounterStyleStyleValue {
		name := parsed.serialize(.normal)
		mut counter_style := ?CounterStyle(none)
		match name {
			'disc' {
				counter_style = builtin_counter_styles().disc
			}
			'decimal' {
				counter_style = builtin_counter_styles().decimal
			}
			'circle' { counter_style = builtin_counter_styles().circle }
			'square' { counter_style = builtin_counter_styles().square }
			'disclosure-open' { counter_style = builtin_counter_styles().disclosure_open }
			'disclosure-closed' { counter_style = builtin_counter_styles().disclosure_closed }
			else {
				if resolved := registered_counter_styles_for_scope(scope)[name] {
					counter_style = resolved
				}
			}
		}
		return ListStyleType{
			kind: .counter_style
			name: name
			counter_style: counter_style
		}
	}
	return ListStyleType{
		kind: .counter_style
		name: 'disc'
		counter_style: builtin_counter_styles().disc
	}
}

pub fn (c &ComputedProperties) list_style_type(document &dom.Document) ListStyleType {
	return c.list_style_type_for_scope(css_style_scope_for_document(document))
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
	value := c.property(.flex_basis, .yes) or { return FlexBasis{} }
	if computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .content {
		return FlexBasis{
			is_content: true
		}
	}
	return FlexBasis{
		size: c.size_value(.flex_basis)
	}
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
	parsed_value := style_value_logic_from_dom(.accent_color, value) or { return none }
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
		.flex_start, .flow_start { AlignContent.flex_start }
		.end_ { AlignContent.end_ }
		.flex_end, .flow_end { AlignContent.flex_end }
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
		.flex_start, .flow_start { AlignItems.flex_start }
		.self_start { AlignItems.self_start }
		.end_ { AlignItems.end_ }
		.flex_end, .flow_end { AlignItems.flex_end }
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
		.flex_start, .flow_start { AlignSelf.flex_start }
		.self_start { AlignSelf.self_start }
		.end_ { AlignSelf.end_ }
		.flex_end, .flow_end { AlignSelf.flex_end }
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
	value := c.property(.backdrop_filter, .yes) or { return Filter.make_none() }
	parsed := style_value_logic_from_dom(.backdrop_filter, value) or {
		return Filter.make_none()
	}
	if parsed is FilterValueListStyleValue {
		return Filter.new(parsed.filter_value_list())
	}
	return Filter.make_none()
}

pub fn (c &ComputedProperties) filter() Filter {
	value := c.property(.filter, .yes) or { return Filter.make_none() }
	parsed := style_value_logic_from_dom(.filter, value) or { return Filter.make_none() }
	if parsed is FilterValueListStyleValue {
		return Filter.new(parsed.filter_value_list())
	}
	return Filter.make_none()
}

pub fn (c &ComputedProperties) opacity() f32 {
	value := c.property(.opacity, .yes) or { return 1 }
	return f32(computed_interpolation_number_from_dom_style_value(value) or { 1.0 })
}

pub fn (c &ComputedProperties) aspect_ratio() AspectRatio {
	value := c.property(.aspect_ratio, .yes) or { return AspectRatio{} }
	parsed := style_value_logic_from_dom(.aspect_ratio, value) or { return AspectRatio{} }
	if parsed is StyleValueList {
		values := parsed.values()
		if values.len == 2 && values[0].to_keyword() == .auto && values[1].is_ratio() {
			return AspectRatio{
				use_natural_aspect_ratio_if_available: true
				preferred_ratio: values[1].as_ratio().ratio()
			}
		}
		return AspectRatio{}
	}
	if parsed.to_keyword() == .auto {
		return AspectRatio{}
	}
	if parsed.is_ratio() {
		ratio := parsed.as_ratio().ratio()
		if ratio.is_degenerate() {
			return AspectRatio{}
		}
		return AspectRatio{
			use_natural_aspect_ratio_if_available: false
			preferred_ratio: ratio
		}
	}
	return AspectRatio{}
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
		.flex_start, .flow_start { JustifyContent.flex_start }
		.end_ { JustifyContent.end_ }
		.flex_end, .flow_end { JustifyContent.flex_end }
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
		.flex_start, .flow_start { JustifyItems.flex_start }
		.self_start { JustifyItems.self_start }
		.end_ { JustifyItems.end_ }
		.flex_end, .flow_end { JustifyItems.flex_end }
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
		.flex_start, .flow_start { JustifySelf.flex_start }
		.self_start { JustifySelf.self_start }
		.end_ { JustifySelf.end_ }
		.flex_end, .flow_end { JustifySelf.flex_end }
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
	return c.shadow(.box_shadow, layout_node)
}

fn (c &ComputedProperties) shadow(property_id PropertyID, layout_node &dom.LayoutNode) []ShadowData {
	value := c.property(property_id, .yes) or { return []ShadowData{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return []ShadowData{} }
	if parsed.to_keyword() == .none_ {
		return []ShadowData{}
	}
	if parsed !is StyleValueList {
		return []ShadowData{}
	}
	list := parsed as StyleValueList
	context := color_resolution_context_for_layout_node(layout_node)
	mut result := []ShadowData{}
	for layer in list.values() {
		if layer !is ShadowStyleValue {
			return []ShadowData{}
		}
		shadow_value := layer as ShadowStyleValue
		color := shadow_value.color().to_color(context) or { return []ShadowData{} }
		result << ShadowData{
			offset_x: Length.from_style_value_logic(shadow_value.offset_x(), none)
			offset_y: Length.from_style_value_logic(shadow_value.offset_y(), none)
			blur_radius: Length.from_style_value_logic(shadow_value.blur_radius(), none)
			spread_distance: Length.from_style_value_logic(shadow_value.spread_distance(), none)
			color: ComputedColor.rgba(color.red(), color.green(), color.blue(), color.alpha())
			inset: shadow_value.placement() == .inner
		}
	}
	return result
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
		.bounding_box { PointerEvents.bounding_box }
		.visible_painted { PointerEvents.visible_painted }
		.visible_fill { PointerEvents.visible_fill }
		.visible_stroke { PointerEvents.visible_stroke }
		.visible { PointerEvents.visible }
		.painted { PointerEvents.painted }
		.fill { PointerEvents.fill }
		.stroke { PointerEvents.stroke }
		else { none }
	}
}

pub fn (c &ComputedProperties) pointer_events() PointerEvents {
	value := c.property(.pointer_events, .yes) or { return .auto_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto_ }
	return keyword_to_pointer_events_for_computed_properties(keyword) or { PointerEvents.auto_ }
}

pub fn (c &ComputedProperties) vertical_align() VerticalAlign {
	value := c.property(.vertical_align, .yes) or { return .baseline }
	keyword := computed_interpolation_style_value_keyword(value) or { return .baseline }
	return match keyword {
		.baseline { .baseline }
		.sub { .sub }
		.super { .super_ }
		.text_top { .text_top }
		.text_bottom { .text_bottom }
		.middle { .middle }
		.top { .top }
		.bottom { .bottom }
		else { .baseline }
	}
}

pub fn (c &ComputedProperties) vertical_align_length_percentage() ?LengthPercentage {
	value := c.property(.vertical_align, .yes) or { return none }
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		return match typed.value {
			LengthStyleValue { LengthPercentage.from_length(typed.value.length()) }
			PercentageStyleValue { LengthPercentage.from_percentage(typed.value.percentage()) }
			CalculatedStyleValue { LengthPercentage.from_calculated(typed.value) }
			else { none }
		}
	}
	parsed_value := style_value_logic_from_dom(.vertical_align, value) or { return none }
	return match parsed_value {
		LengthStyleValue, PercentageStyleValue, CalculatedStyleValue {
			LengthPercentage.from_style_value_logic(parsed_value)
		}
		else {
			none
		}
	}
}

// TreeBuilder::missing_cells_fixup() overrides this non-inherited property on
// the generated anonymous table cells after cloning the row's inherited values.
pub fn (mut c ComputedProperties) set_vertical_align_for_anonymous_table_cell(value VerticalAlign) {
	keyword := match value {
		.baseline { Keyword.baseline }
		.sub { Keyword.sub }
		.super_ { Keyword.super }
		.text_top { Keyword.text_top }
		.text_bottom { Keyword.text_bottom }
		.middle { Keyword.middle }
		.top { Keyword.top }
		.bottom { Keyword.bottom }
	}
	c.set_property_without_modifying_flags(.vertical_align, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword))))
}

fn computed_font_setting_is_normal(value &dom.StyleValue) bool {
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		return typed.value.to_keyword() == .normal
	}
	text := value.css_text
	mut first := 0
	mut end := text.len
	for first < end && text[first] in [` `, `\n`, `\t`, `\v`, `\f`, `\r`] { first++ }
	for end > first && text[end - 1] in [` `, `\n`, `\t`, `\v`, `\f`, `\r`] { end-- }
	if end - first != 6 { return false }
	for i, expected in 'normal' {
		if (text[first + i] | u8(0x20)) != expected { return false }
	}
	return true
}

// Build the final u32 settings directly. The public u8 map getter remains an
// independent snapshot, including its original narrowing conversion semantics.
fn (c &ComputedProperties) copy_font_feature_settings_into(mut settings map[string]u32) {
	value := c.property(.font_feature_settings, .yes) or { return }
	if computed_font_setting_is_normal(value) { return }
	parsed := style_value_logic_from_dom(.font_feature_settings, value) or { return }
	if parsed is StyleValueList {
		for entry in parsed.values() {
			if entry is OpenTypeTaggedStyleValue {
				settings[entry.tag()] = u32(u8(int_from_style_value(entry.value())))
			}
		}
	}
}

pub fn (c &ComputedProperties) font_feature_data() FontFeatureData {
	mut settings := map[string]u32{}
	c.copy_font_feature_settings_into(mut settings)
	return c.font_feature_data_with_settings(settings)
}

fn (c &ComputedProperties) font_feature_data_with_settings(settings map[string]u32) FontFeatureData {
	return FontFeatureData{
		font_variant_alternates: c.font_variant_alternates()
		font_variant_caps: c.font_variant_caps()
		font_variant_east_asian: c.font_variant_east_asian()
		font_variant_emoji: c.font_variant_emoji()
		font_variant_ligatures: c.font_variant_ligatures()
		font_variant_numeric: c.font_variant_numeric()
		font_variant_position: c.font_variant_position()
		font_feature_settings: settings
		font_kerning: c.font_kerning()
		text_rendering: c.text_rendering()
	}
}

pub fn (c &ComputedProperties) font_variant_alternates() ?FontVariantAlternates {
	value := c.property(.font_variant_alternates, .yes) or { return none }
	parsed := style_value_logic_from_dom(.font_variant_alternates, value) or { return none }
	if parsed.to_keyword() == .normal || parsed !is StyleValueList {
		return none
	}
	list := parsed as StyleValueList
	mut result := FontVariantAlternates{}
	for entry in list.values() {
		if entry.to_keyword() == .historical_forms {
			result.historical_forms = true
		} else if entry is FunctionStyleValue {
			function_type := font_feature_value_type_from_string(entry.name()) or { continue }
			names_value := entry.value()
			names := match names_value {
				StyleValueList { names_value }
				else {
					continue
				}
			}
			for name in names.values() {
				result.font_feature_value_entries << FontFeatureValueKey{
					type_: function_type
					name: name.serialize(.normal)
				}
			}
		}
	}
	return result
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
	value := c.property(.font_variant_east_asian, .yes) or { return none }
	parsed := style_value_logic_from_dom(.font_variant_east_asian, value) or { return none }
	if parsed.to_keyword() == .normal || parsed !is TupleStyleValue {
		return none
	}
	tuple := (parsed as TupleStyleValue).tuple()
	mut result := FontVariantEastAsian{}
	if tuple.len > 0 {
		if item := tuple[0] {
			result.variant = match item.serialize(.normal) {
				'jis78' { EastAsianVariant.jis78 }
				'jis83' { EastAsianVariant.jis83 }
				'jis90' { EastAsianVariant.jis90 }
				'jis04' { EastAsianVariant.jis04 }
				'simplified' { EastAsianVariant.simplified }
				'traditional' { EastAsianVariant.traditional }
				else { none }
			}
		}
	}
	if tuple.len > 1 {
		if item := tuple[1] {
			result.width = match item.serialize(.normal) {
				'full-width' { EastAsianWidth.full_width }
				'proportional-width' { EastAsianWidth.proportional_width }
				else { none }
			}
		}
	}
	if tuple.len > 2 {
		result.ruby = tuple[2] != none
	}
	return result
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
	value := c.property(.font_variant_ligatures, .yes) or { return none }
	parsed := style_value_logic_from_dom(.font_variant_ligatures, value) or { return none }
	if parsed.to_keyword() == .normal {
		return none
	}
	if parsed.to_keyword() == .none_ {
		return FontVariantLigatures{
			none_: true
		}
	}
	if parsed !is TupleStyleValue {
		return none
	}
	tuple := (parsed as TupleStyleValue).tuple()
	mut result := FontVariantLigatures{}
	if tuple.len > 0 {
		if item := tuple[0] {
			result.common = if item.serialize(.normal) == 'common-ligatures' {
				CommonLigValue.common_ligatures
			} else {
				CommonLigValue.no_common_ligatures
			}
		}
	}
	if tuple.len > 1 {
		if item := tuple[1] {
			result.discretionary = if item.serialize(.normal) == 'discretionary-ligatures' {
				DiscretionaryLigValue.discretionary_ligatures
			} else {
				DiscretionaryLigValue.no_discretionary_ligatures
			}
		}
	}
	if tuple.len > 2 {
		if item := tuple[2] {
			result.historical = if item.serialize(.normal) == 'historical-ligatures' {
				HistoricalLigValue.historical_ligatures
			} else {
				HistoricalLigValue.no_historical_ligatures
			}
		}
	}
	if tuple.len > 3 {
		if item := tuple[3] {
			result.contextual = if item.serialize(.normal) == 'contextual' {
				ContextualAltValue.contextual
			} else {
				ContextualAltValue.no_contextual
			}
		}
	}
	return result
}

pub fn (c &ComputedProperties) font_variant_numeric() ?FontVariantNumeric {
	value := c.property(.font_variant_numeric, .yes) or { return none }
	parsed := style_value_logic_from_dom(.font_variant_numeric, value) or { return none }
	if parsed.to_keyword() == .normal || parsed !is TupleStyleValue {
		return none
	}
	tuple := (parsed as TupleStyleValue).tuple()
	mut result := FontVariantNumeric{}
	if tuple.len > 0 {
		if item := tuple[0] {
			result.figure = if item.serialize(.normal) == 'oldstyle-nums' {
				NumericFigureValue.oldstyle_nums
			} else {
				NumericFigureValue.lining_nums
			}
		}
	}
	if tuple.len > 1 {
		if item := tuple[1] {
			result.spacing = if item.serialize(.normal) == 'proportional-nums' {
				NumericSpacingValue.proportional_nums
			} else {
				NumericSpacingValue.tabular_nums
			}
		}
	}
	if tuple.len > 2 {
		if item := tuple[2] {
			result.fraction = if item.serialize(.normal) == 'diagonal-fractions' {
				NumericFractionValue.diagonal_fractions
			} else {
				NumericFractionValue.stacked_fractions
			}
		}
	}
	if tuple.len > 3 {
		result.ordinal = tuple[3] != none
	}
	if tuple.len > 4 {
		result.slashed_zero = tuple[4] != none
	}
	return result
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
	parsed_value := style_value_logic_from_dom(.font_language_override, value) or {
		return none
	}
	if parsed_value is StringStyleValue {
		return parsed_value.string_value()
	}
	return none
}

pub fn (c &ComputedProperties) font_feature_settings() map[string]u8 {
	value := c.property(.font_feature_settings, .yes) or { return map[string]u8{} }
	parsed := style_value_logic_from_dom(.font_feature_settings, value) or {
		return map[string]u8{}
	}
	if parsed !is StyleValueList {
		return map[string]u8{}
	}
	list := parsed as StyleValueList
	mut result := map[string]u8{}
	for entry in list.values() {
		if entry is OpenTypeTaggedStyleValue {
			result[entry.tag()] = u8(int_from_style_value(entry.value()))
		}
	}
	return result
}

pub fn (c &ComputedProperties) font_variation_settings() map[string]f64 {
	value := c.property(.font_variation_settings, .yes) or { return map[string]f64{} }
	parsed := style_value_logic_from_dom(.font_variation_settings, value) or {
		return map[string]f64{}
	}
	if parsed !is StyleValueList {
		return map[string]f64{}
	}
	list := parsed as StyleValueList
	mut result := map[string]f64{}
	for entry in list.values() {
		if entry is OpenTypeTaggedStyleValue {
			result[entry.tag()] = number_from_style_value(entry.value())
		}
	}
	return result
}

pub fn (c &ComputedProperties) grid_auto_columns() GridTrackSizeList {
	return c.grid_track_size_list(.grid_auto_columns)
}

pub fn (c &ComputedProperties) grid_auto_rows() GridTrackSizeList {
	return c.grid_track_size_list(.grid_auto_rows)
}

pub fn (c &ComputedProperties) grid_template_columns() GridTrackSizeList {
	return c.grid_track_size_list(.grid_template_columns)
}

pub fn (c &ComputedProperties) grid_template_rows() GridTrackSizeList {
	return c.grid_track_size_list(.grid_template_rows)
}

fn (c &ComputedProperties) grid_track_size_list(property_id PropertyID) GridTrackSizeList {
	value := c.property(property_id, .yes) or { return GridTrackSizeList{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return GridTrackSizeList{} }
	if parsed is GridTrackSizeListStyleValue {
		return parsed.grid_track_size_list()
	}
	return GridTrackSizeList{}
}

pub fn (c &ComputedProperties) grid_auto_flow() GridAutoFlow {
	value := c.property(.grid_auto_flow, .yes) or { return GridAutoFlow{} }
	parsed := style_value_logic_from_dom(.grid_auto_flow, value) or { return GridAutoFlow{} }
	if parsed is GridAutoFlowStyleValue {
		return GridAutoFlow{
			row: parsed.is_row()
			dense: parsed.is_dense()
		}
	}
	return GridAutoFlow{}
}

pub fn (c &ComputedProperties) grid_column_end() GridTrackPlacement {
	return c.grid_track_placement(.grid_column_end)
}

pub fn (c &ComputedProperties) grid_column_start() GridTrackPlacement {
	return c.grid_track_placement(.grid_column_start)
}

pub fn (c &ComputedProperties) grid_row_end() GridTrackPlacement {
	return c.grid_track_placement(.grid_row_end)
}

pub fn (c &ComputedProperties) grid_row_start() GridTrackPlacement {
	return c.grid_track_placement(.grid_row_start)
}

fn (c &ComputedProperties) grid_track_placement(property_id PropertyID) GridTrackPlacement {
	value := c.property(property_id, .yes) or { return GridTrackPlacement.make_auto() }
	parsed := style_value_logic_from_dom(property_id, value) or {
		return GridTrackPlacement.make_auto()
	}
	if parsed is GridTrackPlacementStyleValue {
		return parsed.grid_track_placement()
	}
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
	value := c.property(.grid_template_areas, .yes) or { return GridTemplateAreas{} }
	parsed := style_value_logic_from_dom(.grid_template_areas, value) or {
		return GridTemplateAreas{}
	}
	if parsed is GridTemplateAreaStyleValue {
		return GridTemplateAreas{
			areas: parsed.grid_areas()
			row_count: parsed.row_count()
			column_count: parsed.column_count()
		}
	}
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
	return c.position_value(.object_position)
}

fn (c &ComputedProperties) position_value(property_id PropertyID) Position {
	value := c.property(property_id, .yes) or { return Position{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return Position{} }
	if parsed is PositionStyleValue {
		x := parsed.edge_x().with_resolved_keywords().offset()
		y := parsed.edge_y().with_resolved_keywords().offset()
		return Position{
			offset_x: LengthPercentage.from_style_value_logic(x)
			offset_y: LengthPercentage.from_style_value_logic(y)
		}
	}
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
	parsed_value := style_value_logic_from_dom(.touch_action, value) or {
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
	parsed_value := style_value_logic_from_dom(.contain, value) or { return Containment{} }
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

fn computed_contain_intrinsic_length(value StyleValue, context CalculationResolutionContext) ?CSSPixels {
	return match value {
		LengthStyleValue { value.length().to_px(context.length_resolution_context) }
		CalculatedStyleValue {
			value.resolve_length(context)?.to_px(context.length_resolution_context)
		}
		else { none }
	}
}

// https://drafts.csswg.org/css-sizing-4/#intrinsic-size-override
pub fn (c &ComputedProperties) contain_intrinsic_size(property_id PropertyID) ComputedContainIntrinsicSize {
	if property_id !in [.contain_intrinsic_width, .contain_intrinsic_height] {
		return ComputedContainIntrinsicSize{}
	}
	value := c.property(property_id, .yes) or { return ComputedContainIntrinsicSize{} }
	mut parsed := style_value_logic_from_dom(property_id, value) or {
		return ComputedContainIntrinsicSize{}
	}
	mut has_auto := false
	if parsed is StyleValueList {
		items := parsed.values()
		if items.len != 2 || items[0].to_keyword() != .auto {
			return ComputedContainIntrinsicSize{}
		}
		has_auto = true
		parsed = items[1]
	}
	if parsed.to_keyword() == .none_ {
		return ComputedContainIntrinsicSize{
			has_auto: has_auto
		}
	}
	length := computed_contain_intrinsic_length(parsed, CalculationResolutionContext{
		length_resolution_context: c.length_resolution_context()
	}) or { return ComputedContainIntrinsicSize{} }
	return ComputedContainIntrinsicSize{
		has_auto: has_auto
		has_length: true
		length: length
	}
}

pub fn (c &ComputedProperties) contain_intrinsic_width() ComputedContainIntrinsicSize {
	return c.contain_intrinsic_size(.contain_intrinsic_width)
}

pub fn (c &ComputedProperties) contain_intrinsic_height() ComputedContainIntrinsicSize {
	return c.contain_intrinsic_size(.contain_intrinsic_height)
}

pub fn (c &ComputedProperties) container_type() ContainerType {
	value := c.property(.container_type, .yes) or { return ContainerType{} }
	parsed_value := style_value_logic_from_dom(.container_type, value) or {
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
	parsed_value := style_value_logic_from_dom(.view_transition_name, value) or { return none }
	if parsed_value is CustomIdentStyleValue {
		return parsed_value.custom_ident()
	}
	return none
}

pub fn (c &ComputedProperties) animations(abstract_element &dom.AbstractElement) []ComputedAnimationProperties {
	animation_name_property := c.property(.animation_name, .yes) or {
		return []ComputedAnimationProperties{}
	}
	if computed_animation_names_are_none(animation_name_property) {
		return []ComputedAnimationProperties{}
	}
	animation_name_values := computed_interpolation_split_coordinating_list_value(animation_name_property)

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
		.animation_range_start,
		.animation_range_end,
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
	range_starts := coordinated_properties[.animation_range_start] or { return []ComputedAnimationProperties{} }
	range_ends := coordinated_properties[.animation_range_end] or { return []ComputedAnimationProperties{} }

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
		duration := computed_interpolation_animation_duration_to_milliseconds(animation_duration_style_value)
		duration_keyword := computed_interpolation_style_value_keyword(animation_duration_style_value) or {
			Keyword.invalid
		}

		animations << ComputedAnimationProperties{
			scroll_range: scroll_animation_range_from_values(range_starts[i], range_ends[i])
			duration: duration
			duration_string: if duration_keyword == .auto {
				'auto'
			} else {
				''
			}
			timing_function: EasingFunction.from_style_value(timing_function_values[i])
			iteration_count: computed_interpolation_animation_iteration_count_from_style_value(iteration_count_values[i])
			direction: computed_interpolation_animation_direction_from_style_value(direction_values[i])
			play_state: computed_interpolation_animation_play_state_from_style_value(play_state_values[i])
			delay: computed_interpolation_time_value_to_milliseconds(delay_values[i])
			fill_mode: computed_interpolation_animation_fill_mode_from_style_value(fill_mode_values[i])
			composition: computed_interpolation_animation_composition_from_style_value(composition_values[i])
			name: computed_interpolation_animation_name_from_style_value(name_values[i])
			timeline: computed_interpolation_animation_timeline_from_style_value(timeline_values[i], abstract_element)
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
	keyword := computed_interpolation_style_value_keyword(value) or { Keyword.invalid }

	// https://drafts.csswg.org/css-animations-2/#animation-timeline
	if keyword == .auto {
		// auto
		// The animation's timeline is a DocumentTimeline, more specifically the default document timeline.
		style_computer := css_style_computer_for(abstract_element.document())
		return style_computer.document_timeline_
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

	parsed_value := style_value_logic_from_dom(.animation_timeline, value) or {
		return none
	}
	typed_value := if parsed_value is StyleValueList && parsed_value.size() == 1 {
		parsed_value.value_at(0, false)
	} else {
		parsed_value
	}
	if typed_value is FunctionStyleValue && typed_value.name() == 'scroll' {
		// <scroll()>
		// Use the scroll progress timeline indicated by the given scroll() function. See Scroll-driven Animations
		// § 2.2.1 The scroll() notation.
		arguments_value := typed_value.value()
		call_arguments := match arguments_value {
			TupleStyleValue { arguments_value.tuple() }
			else {
				return none
			}
		}
		if call_arguments.len != 2 {
			return none
		}
		mut scroller := Scroller.nearest
		mut axis := Axis.block
		if scroller_value := call_arguments[tuple_scroll_function_scroller_index] {
			scroller = scroller_from_identifier_for_value_logic(scroller_value.serialize(.normal)) or {
				return none
			}
		}
		if axis_value := call_arguments[tuple_scroll_function_axis_index] {
			axis = axis_from_identifier_for_value_logic(axis_value.serialize(.normal)) or {
				return none
			}
		}
		mut document := unsafe { &dom.Document(abstract_element.document()) }
		document.note_scroll_driven_animation()
		return &AnimationTimeline{
			kind: .scroll
			anonymous_source: '${voidptr(abstract_element.element())}:${scroller_to_string(scroller)}'
			scroll_scroller: scroller
			scroll_axis: axis
			scroll_subject_id: abstract_element.element().as_node().unique_id()
			associated_document: abstract_element.document()
		}
	}

	// <view()>
	// FIXME: Use the view progress timeline indicated by the given view() function. See Scroll-driven Animations § 3.3.1
	//        The view() notation.
	//
	// FIXME: We fall back to document timeline for now as though we don't support the `animation-timeline` property at
	//        all
	style_computer := css_style_computer_for(abstract_element.document())
	return style_computer.document_timeline_
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
				candidates := if property_is_shorthand(transition_property) {
					generated_expanded_longhands_for_shorthand(transition_property)
				} else {
					[transition_property]
				}
				mapping_context := LogicalAliasMappingContext{
					writing_mode: c.writing_mode()
					direction: c.direction()
				}
				for candidate in candidates {
					physical := if property_is_logical_alias(candidate) {
						map_logical_alias_to_physical_property(candidate, mapping_context)
					} else {
						candidate
					}
					if physical !in properties {
						properties << physical
					}
				}
			}
		}

		transitions << TransitionProperties{
			properties: properties
			duration: computed_interpolation_time_value_to_milliseconds(duration_values[i])
			timing_function: EasingFunction.from_style_value(timing_function_values[i])
			delay: computed_interpolation_time_value_to_milliseconds(delay_values[i])
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
		values: values
	}
}

pub fn ComputedProperties.transformations_for_style_value(value &dom.StyleValue) []TransformationData {
	parsed_value := style_value_logic_from_dom(.transform, value) or {
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
	value := c.property(.transform_origin, .yes) or { return TransformOrigin{} }
	parsed := style_value_logic_from_dom(.transform_origin, value) or {
		return TransformOrigin{}
	}
	if parsed !is StyleValueList {
		return TransformOrigin{}
	}
	list := parsed as StyleValueList
	if list.size() != 3 {
		return TransformOrigin{}
	}
	resolve_axis := fn (axis StyleValue) LengthPercentage {
		return match axis.to_keyword() {
			.left, .top { LengthPercentage.from_percentage(Percentage.new(0)) }
			.center { LengthPercentage.from_percentage(Percentage.new(50)) }
			.right, .bottom { LengthPercentage.from_percentage(Percentage.new(100)) }
			else { LengthPercentage.from_style_value_logic(axis) }
		}
	}
	return TransformOrigin{
		x: resolve_axis(list.value_at(0, false))
		y: resolve_axis(list.value_at(1, false))
		z: Length.from_style_value_logic(list.value_at(2, false), none)
	}
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

pub fn (c &ComputedProperties) backface_visibility() BackfaceVisibility {
	value := c.property(.backface_visibility, .yes) or { return .visible }
	keyword := computed_interpolation_style_value_keyword(value) or { return .visible }
	return match keyword {
		.hidden { BackfaceVisibility.hidden }
		.visible { BackfaceVisibility.visible }
		else { BackfaceVisibility.visible }
	}
}

pub fn (c &ComputedProperties) rotate() ?TransformationData {
	value := c.property(.rotate, .yes) or { return none }
	parsed_value := style_value_logic_from_dom(.rotate, value) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
	return none
}

pub fn (c &ComputedProperties) translate() ?TransformationData {
	value := c.property(.translate, .yes) or { return none }
	parsed_value := style_value_logic_from_dom(.translate, value) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
	return none
}

pub fn (c &ComputedProperties) scale() ?TransformationData {
	value := c.property(.scale, .yes) or { return none }
	parsed_value := style_value_logic_from_dom(.scale, value) or { return none }
	if parsed_value is TransformationStyleValue {
		return transformation_data_from_transformation_style_value(parsed_value)
	}
	return none
}

pub fn (c &ComputedProperties) perspective() ?CSSPixels {
	value := c.property(.perspective, .yes) or { return none }
	if computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .none_ {
		return none
	}
	return c.length(.perspective).absolute_length_to_px()
}

pub fn (c &ComputedProperties) perspective_origin() Position {
	return c.position_value(.perspective_origin)
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
	parsed_value := style_value_logic_from_dom(property_id, value) or {
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
	parsed_value := style_value_logic_from_dom(property_id, value) or {
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
	value := c.property(.stroke_dasharray, .yes) or { return []StrokeDasharrayItem{} }
	parsed := style_value_logic_from_dom(.stroke_dasharray, value) or {
		return []StrokeDasharrayItem{}
	}
	if parsed.to_keyword() == .none_ || parsed !is StyleValueList {
		return []StrokeDasharrayItem{}
	}
	list := parsed as StyleValueList
	mut result := []StrokeDasharrayItem{}
	for dash in list.values() {
		if dash is LengthStyleValue || dash is PercentageStyleValue || (dash is CalculatedStyleValue && dash.resolves_to_length()) {
			result << StrokeDasharrayItem{
				is_length_percentage: true
				length_percentage: LengthPercentage.from_style_value_logic(dash)
			}
		} else if dash is CalculatedStyleValue {
			result << StrokeDasharrayItem{
				number: dash.resolve_number(CalculationResolutionContext{}) or { 0.0 }
			}
		} else if dash is NumberStyleValue {
			result << StrokeDasharrayItem{
				number: dash.number()
			}
		}
	}
	return result
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

pub fn (c &ComputedProperties) vector_effect() VectorEffect {
	value := c.property(.vector_effect, .yes) or { return .none_ }
	keyword := computed_interpolation_style_value_keyword(value) or { return .none_ }
	return match keyword {
		.non_scaling_stroke { VectorEffect.non_scaling_stroke }
		else { VectorEffect.none_ }
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
	parsed_value := style_value_logic_from_dom(.paint_order, value) or {
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
	value := c.property(.will_change, .yes) or { return WillChange.make_auto() }
	parsed := style_value_logic_from_dom(.will_change, value) or {
		return WillChange.make_auto()
	}
	if parsed.to_keyword() == .auto {
		return WillChange.make_auto()
	}
	if parsed !is StyleValueList {
		return WillChange.make_auto()
	}
	list := parsed as StyleValueList
	mut names := []string{}
	for entry in list.values() {
		name := entry.serialize(.normal)
		if name in ['contents', 'scroll-position'] || property_id_from_string(name) != none {
			names << name
		}
	}
	return WillChange{
		names: names
	}
}

pub fn (c &ComputedProperties) cached_computed_font_list() ?&FontCascadeList {
	return c.cached_computed_font_list_
}

const disable_pending_intrinsic_font_reuse = os.getenv('VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE') != ''
const pending_intrinsic_font_reuse_diagnostics = os.getenv('VOX_PENDING_INTRINSIC_FONT_REUSE_DIAGNOSTICS') != ''

__global pending_intrinsic_font_reuse_reported bool

// Geometry recorded at `generation` can survive unrelated font completions
// only when its original cascade is still live. A newly computed replacement
// cannot establish what fonts the older geometry used, even if it is current.
pub fn (c &ComputedProperties) cached_font_inputs_are_unchanged_since(computer &FontComputer, generation u64) bool {
	list := c.cached_computed_font_list_ or { return false }
	if list.computed_cache_created_generation_ > generation
		|| !computer.cached_cascade_is_current(list) { return false }
	if list.pending_faces.len != 0 {
		if disable_pending_intrinsic_font_reuse { return false }
		// Loads, failures and display-period transitions expire every cached
		// cascade that selected the changing face. A still-live original list
		// therefore retains both fallback metrics and its visibility state.
		if pending_intrinsic_font_reuse_diagnostics && !pending_intrinsic_font_reuse_reported {
			pending_intrinsic_font_reuse_reported = true
			eprintln('Vox intrinsic pending font reuse: original cascade is live')
		}
	}
	return true
}

pub fn (mut c ComputedProperties) clear_computed_font_list_cache() {
	c.cached_computed_font_list_ = none
	c.cached_computed_font_list_generation_ = 0
	c.cached_computed_font_list_owner_ = unsafe { nil }
	c.cached_first_available_computed_font_ = unsafe { nil }
}

fn (mut c ComputedProperties) reuse_unchanged_font_cache(previous &ComputedProperties,
	font_computer &FontComputer) bool {
	font_list := previous.cached_computed_font_list_ or { return false }
	generation := font_computer.environment_generation()
	if voidptr(previous.cached_computed_font_list_owner_) != voidptr(font_computer)
		|| (previous.cached_computed_font_list_generation_ != generation
			&& !font_computer.cached_cascade_is_current(font_list)) {
		return false
	}
	if !computed_font_inputs_match(previous, &c) {
		return false
	}
	c.cached_computed_font_list_ = font_list
	c.cached_computed_font_list_generation_ = generation
	c.cached_computed_font_list_owner_ = font_computer
	c.cached_first_available_computed_font_ = previous.cached_first_available_computed_font_
	return true
}

pub fn (mut c ComputedProperties) computed_font_list(font_computer &FontComputer) &FontCascadeList {
	mut font_environment_changed := false
	if font_list := c.cached_computed_font_list_ {
		generation := font_computer.environment_generation()
		if voidptr(c.cached_computed_font_list_owner_) == voidptr(font_computer)
			&& (c.cached_computed_font_list_generation_ == generation
				|| font_computer.cached_cascade_is_current(font_list)) {
			// A different family/weight can finish without expiring this cascade.
			// Keep its resolved inputs instead of rebuilding the same cache key.
			c.cached_computed_font_list_generation_ = generation
			if c.font_input_refresh_snapshot_ == unsafe { nil } {
				c.font_input_refresh_snapshot_ = font_list
			}
			return font_list
		}
		c.clear_computed_font_list_cache()
		font_environment_changed = true
	}
	mut mutable_font_computer := unsafe { &FontComputer(font_computer) }
	mut inputs := mutable_font_computer.acquire_font_input_scratch()
	defer { inputs.finish() }
	value := c.property(.font_family, .yes) or {
		&dom.StyleValue{
			css_text: 'sans-serif'
		}
	}
	parsed := style_value_logic_from_dom(.font_family, value) or {
		StyleValue(KeywordStyleValue.create(.sans_serif))
	}
	mut families := []string{}
	values := if parsed is StyleValueList { parsed.values() } else { [parsed] }
	for family in values {
		match family {
			StringStyleValue { families << family.string_value() }
			CustomIdentStyleValue { families << family.custom_ident() }
			else { families << family.serialize(.normal) }
		}
	}
	if families.len == 0 {
		families << 'sans-serif'
	}
	font_size_px := if font_computer.font_rendering_policy() == .chromium { c.resolved_font_size_px() } else { c.font_size().to_double() }
	font_list := mutable_font_computer.compute_font_for_style_values_with_synthesis(families, font_size_px, c.font_slope(), c.font_weight(), c.font_width(), c.font_optical_sizing(), font_computer.variation_settings_for_computation(c), font_computer.feature_data_for_computation(c), c.disabled_font_synthesis())
	inputs.finish()
	assert !font_list.is_empty()
	c.cached_computed_font_list_ = font_list
	c.cached_computed_font_list_generation_ = font_computer.environment_generation()
	c.cached_computed_font_list_owner_ = font_computer
	if c.font_input_refresh_snapshot_ == unsafe { nil } {
		c.font_input_refresh_snapshot_ = font_list
	}
	if font_environment_changed {
		// A face loaded after this style was materialized. Refresh the selected
		// face and the layout-facing line height together so the current shaping
		// pass cannot combine author-font glyphs with fallback line metrics.
		c.cached_first_available_computed_font_ = font_list.font_for_code_point(u32(` `))
		c.computed_values_line_height_ = c.line_height()
	}
	return font_list
}

pub fn (mut c ComputedProperties) first_available_computed_font(font_computer &FontComputer) &PlatformFont {
	font_list := c.computed_font_list(font_computer)
	if c.cached_first_available_computed_font_ != unsafe { nil } {
		return c.cached_first_available_computed_font_
	}
	persistent := platform.enter_persistent()
	selected_font := font_list.font_for_code_point(u32(` `))
	platform.leave_persistent(persistent)
	// The cascade and its entries are heap-backed. Cache the selected entry by
	// identity so its nested typeface and feature storage remain owned by the
	// cascade under the old no-GC backend.
	c.cached_first_available_computed_font_ = selected_font
	return selected_font
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

// Whether line-height resolves to `normal`, as line_height() decides it.
pub fn (c &ComputedProperties) line_height_is_normal() bool {
	value := c.property(.line_height, .yes) or { return true }
	if length := computed_interpolation_length_from_dom_style_value(value) {
		return !length.is_absolute()
	}
	return computed_interpolation_number_from_dom_style_value(value) == none
}

pub fn (c &ComputedProperties) line_height() CSSPixels {
	if line_height := c.line_height_ {
		return line_height
	}
	if value := c.property(.line_height, .yes) {
		if length := computed_interpolation_length_from_dom_style_value(value) {
			if length.is_absolute() {
				return length.absolute_length_to_px()
			}
		}
		if number := computed_interpolation_number_from_dom_style_value(value) {
			if c.chromium_line_height_policy() {
				// Blink's ComputedLineHeightAsFixed first converts the font size
				// to LayoutUnit, then applies the unitless percentage. Anonymous
				// styles retain this policy through their font owner too.
				font_size := CSSPixels.nearest_value_for(f64(f32(c.resolved_font_size_px())))
				pixels := f32(font_size.to_double()) * f32(number)
				return CSSPixels.from_raw(int(pixels * 64))
			}
			return c.font_size().times_float(number)
		}
	}
	// Since upstream 0e6db9d9, `normal` is the sum of the selected face's
	// independently rounded ascent and descent. The font list is materialized
	// before layout-facing values in resolve_computed_values_for_document().
	if c.font_size().raw_value()==0 { return CSSPixels.new(0) }
	if c.cached_first_available_computed_font_ != unsafe { nil } {
		computed_font := c.cached_first_available_computed_font_
		font := computed_font.font_for_metrics()
		mut scale := 1.0
		if subject := c.subject_element_ {
			scale = subject.document().display_device_pixel_ratio() / c.layout_coordinate_scale()
		}
		metrics := font.inline_metrics_at_scale(scale)
		if metrics.floor_inline_leading && metrics.inline_leading_scale != 1 {
			return CSSPixels.nearest_value_for(f64(metrics.ascent + metrics.descent + metrics.line_gap))
		}
		gap := if metrics.floor_inline_leading { int(metrics.line_gap) } else { 0 }
		return CSSPixels.new(int(math.round_to_even(f64(metrics.ascent))) + int(math.round_to_even(f64(metrics.descent))) + gap)
	}
	// Geometry-only callers do not own a document font resolver. Retain the
	// former scale as their deterministic fallback.
	return CSSPixels.new(int(math.round_to_even(c.font_size().to_double() * computed_properties_normal_line_height_scale)))
}

pub fn (c &ComputedProperties) font_size() CSSPixels {
	if value := c.property(.font_size, .yes) {
		if length := computed_interpolation_length_from_dom_style_value(value) {
			if length.is_absolute() {
				return length.absolute_length_to_px()
			}
		}
	}
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
	if value := c.property(.font_width, .yes) {
		if percentage := computed_interpolation_percentage_from_dom_style_value(value) {
			return percentage
		}
	}
	return Percentage.new(100)
}

pub fn (c &ComputedProperties) font_slope() int {
	value := c.property(.font_style, .yes) or { return 0 }
	parsed := style_value_logic_from_dom(.font_style, value) or { return 0 }
	if parsed is FontStyleStyleValue {
		return parsed.to_font_slope()
	}
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
	if c.raw_property_count() != other.raw_property_count() {
		return false
	}
	for index in 0 .. c.raw_property_count() {
		value := c.raw_property_at_index(index)
		other_value := other.raw_property_at_index(index)
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

	parsed_value := style_value_logic_from_dom(.z_index, value) or { return none }
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
	value := c.property(.quotes, .yes) or { return QuotesData{} }
	parsed := style_value_logic_from_dom(.quotes, value) or { return QuotesData{} }
	if parsed !is StyleValueList {
		return QuotesData{
			none_: parsed.to_keyword() == .none_
		}
	}
	list := parsed as StyleValueList
	mut pairs := []string{}
	for item in list.values() {
		if item is StringStyleValue {
			pairs << item.string_value()
		}
	}
	return QuotesData{
		pairs: pairs
	}
}

pub fn (c &ComputedProperties) counter_data(property_id PropertyID) []CounterData {
	value := c.property(property_id, .yes) or { return []CounterData{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return []CounterData{} }
	if parsed !is CounterDefinitionsStyleValue {
		return []CounterData{}
	}
	definitions := parsed as CounterDefinitionsStyleValue
	mut result := []CounterData{}
	for definition in definitions.counter_definitions() {
		mut number := ?i32(none)
		if specified := definition.value {
			number = i32(int_from_style_value(specified))
		}
		result << CounterData{
			name: definition.name
			is_reversed: definition.is_reversed
			value: number
		}
	}
	return result
}

pub fn (c &ComputedProperties) scrollbar_color(layout_node &dom.LayoutNode) ScrollbarColorData {
	value := c.property(.scrollbar_color, .yes) or { return ScrollbarColorData{} }
	parsed := style_value_logic_from_dom(.scrollbar_color, value) or {
		return ScrollbarColorData{}
	}
	if parsed.to_keyword() == .auto || parsed !is ScrollbarColorStyleValue {
		return ScrollbarColorData{}
	}
	colors := parsed as ScrollbarColorStyleValue
	context := color_resolution_context_for_layout_node(layout_node)
	thumb := colors.thumb_color().to_color(context) or { return ScrollbarColorData{} }
	track := colors.track_color().to_color(context) or { return ScrollbarColorData{} }
	return ScrollbarColorData{
		auto_: false
		thumb: ComputedColor.rgba(thumb.red(), thumb.green(), thumb.blue(), thumb.alpha())
		track: ComputedColor.rgba(track.red(), track.green(), track.blue(), track.alpha())
	}
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

fn scroll_snap_align_from_keyword(keyword Keyword) ScrollSnapAlign {
	return match keyword {
		.start { .start }
		.end_ { .end_ }
		.center { .center }
		else { .none_ }
	}
}

pub fn (c &ComputedProperties) scroll_snap_align() ScrollSnapAlignData {
	value := c.property(.scroll_snap_align, .yes) or { return ScrollSnapAlignData{} }
	parsed := style_value_logic_from_dom(.scroll_snap_align, value) or {
		return ScrollSnapAlignData{}
	}
	if parsed is StyleValueList {
		values := parsed.values()
		if values.len == 2 {
			return ScrollSnapAlignData{
				block_alignment: scroll_snap_align_from_keyword(values[0].to_keyword())
				inline_alignment: scroll_snap_align_from_keyword(values[1].to_keyword())
			}
		}
	}
	alignment := scroll_snap_align_from_keyword(parsed.to_keyword())
	return ScrollSnapAlignData{
		block_alignment: alignment
		inline_alignment: alignment
	}
}

pub fn (c &ComputedProperties) scroll_snap_stop() ScrollSnapStop {
	value := c.property(.scroll_snap_stop, .yes) or { return .normal }
	keyword := computed_interpolation_style_value_keyword(value) or { return .normal }
	return match keyword {
		.always { ScrollSnapStop.always }
		else { ScrollSnapStop.normal }
	}
}

fn scroll_snap_axis_from_keyword(keyword Keyword) ScrollSnapAxis {
	return match keyword {
		.x { .x }
		.y { .y }
		.block { .block }
		.inline_ { .inline_ }
		else { .both }
	}
}

pub fn (c &ComputedProperties) scroll_snap_type() ScrollSnapType {
	value := c.property(.scroll_snap_type, .yes) or { return ScrollSnapType{} }
	parsed := style_value_logic_from_dom(.scroll_snap_type, value) or { return ScrollSnapType{} }
	if parsed.to_keyword() == .none_ {
		return ScrollSnapType{}
	}
	if parsed is StyleValueList {
		values := parsed.values()
		if values.len == 2 {
			return ScrollSnapType{
				axis: scroll_snap_axis_from_keyword(values[0].to_keyword())
				strictness: if values[1].to_keyword() == .mandatory {
					ScrollSnapStrictness.mandatory
				} else {
					ScrollSnapStrictness.proximity
				}
			}
		}
	}
	return ScrollSnapType{
		axis: scroll_snap_axis_from_keyword(parsed.to_keyword())
		strictness: .proximity
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
		monospace: monospace
		bold: bold
		point_size: f64(point_size)
	}
}

pub fn (c &ComputedProperties) has_attempted_match_against_pseudo_class(pseudo_class PseudoClass) bool {
	return c.attempted_pseudo_class_matches_.get(pseudo_class)
}

pub fn (mut c ComputedProperties) set_attempted_pseudo_class_matches(results PseudoClassBitmap) {
	c.attempted_pseudo_class_matches_ = results
}

// --- Interpolation ---
pub enum AllowDiscrete as u8 {
	yes
	no
}

pub enum AnimationType as u8 {
	by_computed_value
	none_
	repeatable_list
	custom
	discrete
}

pub enum CompositeOperation as u8 {
	replace
	add
	accumulate
}

pub enum InterpolableValueType as u8 {
	angle
	length
	percentage
	number
	integer
}

pub struct InterpolationCalculationContext {
pub mut:
	property               PropertyID
	percentages_resolve_as ?ValueType
	accepted_type_ranges   map[InterpolableValueType]AcceptedTypeRange
	color_resolution       ?ColorResolutionContext
}

pub fn InterpolationCalculationContext.for_property(property PropertyID) InterpolationCalculationContext {
	calculation_context := CalculationContext.for_property(PropertyNameAndID.from_id(property))
	mut accepted_type_ranges := map[InterpolableValueType]AcceptedTypeRange{}
	for value_type, accepted_range in calculation_context.accepted_type_ranges {
		// The keys name InterpolableValueType explicitly: inside a match on
		// ValueType, the compiler resolved enum shorthands in the index
		// expression to the wrong enum, so no range was ever found.
		key := match value_type {
			.angle { InterpolableValueType.angle }
			.length { InterpolableValueType.length }
			.percentage { InterpolableValueType.percentage }
			.number { InterpolableValueType.number }
			.integer { InterpolableValueType.integer }
			else { continue }
		}
		accepted_type_ranges[key] = accepted_range
	}
	return InterpolationCalculationContext{
		property: property
		percentages_resolve_as: calculation_context.percentages_resolve_as
		accepted_type_ranges: accepted_type_ranges
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
	result := f64(round_to_nearest_integer(f64(from) + (f64(to) - f64(from)) * delta))
	return int(clamp_f64(result, min, max))
}

fn with_keyword_values_resolved_boundary(element &dom.Element, property_id PropertyID, value &dom.StyleValue) &dom.StyleValue {
	if typed := typed_style_value_logic_from_dom(value) {
		if typed is GuaranteedInvalidStyleValue {
			return computed_interpolation_property_initial_value(property_id)
		}
	}
	unset := computed_interpolation_style_value_is_unset(value)
	if computed_interpolation_style_value_is_initial(value)
		|| (unset && !is_inherited_property(property_id)) {
		return computed_interpolation_property_initial_value(property_id)
	}
	if computed_interpolation_style_value_is_inherit(value) || unset {
		return StyleComputer.get_non_animated_inherit_value(property_id, dom.AbstractElement.new(element, none))
	}
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

pub fn interpolate_property(element &dom.Element, property_id PropertyID, a_from &dom.StyleValue, a_to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	from := with_keyword_values_resolved_boundary(element, property_id, a_from)
	to := with_keyword_values_resolved_boundary(element, property_id, a_to)
	if property_id == .font_palette {
		if delta <= 0 { return from }
		if delta >= 1 { return to }
		first := style_value_logic_from_dom(property_id,from) or { return none }
		second := style_value_logic_from_dom(property_id,to) or { return none }
		return dom_style_value_from_value_logic(font_palette_mix_value(first,second,delta*100,ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(RectangularColorSpace.oklab))))
	}
	// Anchor functions produce lengths at used-value time. Retain both live
	// queries in the interpolated calculation instead of treating them as
	// discrete keywords or freezing their current geometry.
	if property_id in [.left,.right,.top,.bottom,.width,.height,.min_width,.max_width,.min_height,.max_height,.margin_left,.margin_right,.margin_top,.margin_bottom] {
		from_value := style_value_logic_from_dom(property_id,from) or { return none }
		to_value := style_value_logic_from_dom(property_id,to) or { return none }
		from_anchor := from_value is AnchorStyleValue || from_value is AnchorSizeStyleValue
			|| (from_value is CalculatedStyleValue && from_value.contains_anchor_functions())
		to_anchor := to_value is AnchorStyleValue || to_value is AnchorSizeStyleValue
			|| (to_value is CalculatedStyleValue && to_value.contains_anchor_functions())
		if from_anchor || to_anchor {
			if delta == 0 { return unsafe { from } }
			if delta == 1 { return unsafe { to } }
			text := 'calc(${serialize_a_number(1-delta)} * (${from_value.serialize(.normal)}) + ${serialize_a_number(delta)} * (${to_value.serialize(.normal)}))'
			value := parse_css_value_logic(property_id,text) or { return none }
			return dom_style_value_from_value_logic(value)
		}
	}
	if property_id == .clip_path {
		first := style_value_logic_from_dom(property_id,from) or { return none }
		last := style_value_logic_from_dom(property_id,to) or { return none }
		if clip_path_reference_box(first) != clip_path_reference_box(last) { return interpolate_discrete(from,to,delta,allow_discrete) }
	}
	// https://drafts.csswg.org/css-values-5/#interpolate-calc-size
	if property_accepts_calc_size(property_id)
		&& animation_type_from_longhand_property(property_id) == .by_computed_value {
		if value := interpolate_calc_size_values(element, property_id, from, to, delta) {
			return value
		}
	}
	calculation_context := InterpolationCalculationContext.for_property(property_id)

	match animation_type_from_longhand_property(property_id) {
		.by_computed_value {
			return interpolate_value(element, calculation_context, from, to, delta, allow_discrete)
		}
		.none_ {
			return unsafe { to }
		}
		.repeatable_list {
			return interpolate_repeatable_list(element, calculation_context, from, to, delta, allow_discrete)
		}
		.custom {
			if property_id == .transform {
				return interpolate_transform(element, calculation_context, from, to, delta, allow_discrete)
			}
			if property_id in [.box_shadow, .text_shadow] {
				if result := interpolate_box_shadow(element, calculation_context, from, to, delta, allow_discrete) {
					return result
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			if property_id == .font_style {
				return interpolate_font_style_property(calculation_context, from, to, delta, allow_discrete)
			}
			if property_id == .font_variation_settings {
				if result := interpolate_value(element, calculation_context, from, to, delta, allow_discrete) {
					return result
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			if property_id == .scale {
				return interpolate_scale_property(calculation_context, from, to, delta, allow_discrete)
			}
			if property_id == .translate {
				return interpolate_translate_property(calculation_context, from, to, delta, allow_discrete)
			}
			if property_id == .rotate {
				return interpolate_rotate_property(calculation_context, from, to, delta, allow_discrete)
			}
			if property_id in [.filter, .backdrop_filter] {
				if result := interpolate_filter_value_list(element, calculation_context, from, to, delta, allow_discrete) {
					return result
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			if property_id in [.grid_template_rows, .grid_template_columns] {
				from_value := style_value_logic_from_dom(property_id, from) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				to_value := style_value_logic_from_dom(property_id, to) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				if from_value is GridTrackSizeListStyleValue && to_value is GridTrackSizeListStyleValue {
					interpolated := interpolate_grid_track_size_list(calculation_context, from_value.grid_track_size_list(), to_value.grid_track_size_list(), delta) or {
						return interpolate_discrete(from, to, delta, allow_discrete)
					}
					return dom_style_value_from_value_logic(StyleValue(GridTrackSizeListStyleValue.create(interpolated)))
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			if property_id == .stroke_dasharray {
				// SVG dash patterns are repeatable lists. `none` and any other
				// non-list endpoint combine discretely instead.
				from_value := style_value_logic_from_dom(property_id, from) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				to_value := style_value_logic_from_dom(property_id, to) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				if from_value !is StyleValueList || to_value !is StyleValueList {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				if result := interpolate_repeatable_list(element, calculation_context, from, to, delta, allow_discrete) {
					return result
				}
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
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
			// https://drafts.csswg.org/css-display-4/#display-animation
			if property_id == .display {
				// In general, display animates discretely. Between `none` and any
				// other display value, however, progress values in (0, 1) map to
				// the non-none value so the element remains rendered.
				// FIXME: Keep the element inert while its display value would compute
				// to none when ignoring the animations and transitions origins.
				from_value := style_value_logic_from_dom(.display, from) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				to_value := style_value_logic_from_dom(.display, to) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
				if from_value is DisplayStyleValue && to_value is DisplayStyleValue {
					from_display := from_value.display()
					to_display := to_value.display()
					if from_display == to_display {
						return unsafe { from }
					}
					from_is_none := from_display.is_none()
					to_is_none := to_display.is_none()
					if from_is_none || to_is_none {
						non_none_value := if from_is_none { to } else { from }
						if delta <= 0 {
							return unsafe { from }
						}
						if delta >= 1 {
							return unsafe { to }
						}
						return unsafe { non_none_value }
					}
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
	if animation_type == .none_ || (transition_behavior != .allow_discrete && animation_type == .discrete) {
		return false
	}

	// Even when a property is transitionable, the two values may not be. The spec uses the example of inset/non-inset shadows.
	if transition_behavior != .allow_discrete && interpolate_property(element, property_id, old_value, new_value, 0.5, .no) == none {
		return false
	}
	return true
}

pub fn interpolate_length_percentage(calculation_context InterpolationCalculationContext, from LengthPercentage, to LengthPercentage, delta f64) ?LengthPercentage {
	if from.is_length() && to.is_length() {
		range := interpolation_accepted_type_range(calculation_context, .length)
		return LengthPercentage.from_length(Length.make_px(interpolate_raw(from.length().raw_value(), to.length().raw_value(), delta, range)))
	}
	if from.is_percentage() && to.is_percentage() {
		range := interpolation_accepted_type_range(calculation_context, .percentage)
		return LengthPercentage.from_percentage(Percentage.new(interpolate_raw(from.percentage().value(), to.percentage().value(), delta, range)))
	}

	from_value := interpolation_length_percentage_to_style_value(from)
	to_value := interpolation_length_percentage_to_style_value(to)
	interpolated := interpolate_mixed_style_value(calculation_context, from_value, to_value, delta) or {
		return none
	}
	if interpolated is LengthStyleValue || interpolated is PercentageStyleValue || interpolated is CalculatedStyleValue {
		return LengthPercentage.from_style_value_logic(interpolated)
	}
	return none
}

pub fn interpolate_length_percentage_or_auto(calculation_context InterpolationCalculationContext, from LengthPercentageOrAuto, to LengthPercentageOrAuto, delta f64) ?LengthPercentageOrAuto {
	if from.is_auto() && to.is_auto() {
		return LengthPercentageOrAuto.make_auto()
	}
	if from.is_length() && to.is_length() {
		range := interpolation_accepted_type_range(calculation_context, .length)
		return LengthPercentageOrAuto.from_length(Length.make_px(interpolate_raw(from.length().raw_value(), to.length().raw_value(), delta, range)))
	}
	if from.is_percentage() && to.is_percentage() {
		range := interpolation_accepted_type_range(calculation_context, .percentage)
		return LengthPercentageOrAuto.from_percentage(Percentage.new(interpolate_raw(from.percentage().value(), to.percentage().value(), delta, range)))
	}

	from_value := interpolation_length_percentage_or_auto_to_style_value(from)
	to_value := interpolation_length_percentage_or_auto_to_style_value(to)
	interpolated := interpolate_mixed_style_value(calculation_context, from_value, to_value, delta) or {
		return none
	}
	if interpolated is LengthStyleValue || interpolated is PercentageStyleValue || interpolated is CalculatedStyleValue {
		return LengthPercentageOrAuto.from_style_value_logic(interpolated)
	}
	return none
}

struct ExpandedGridTracksAndLines {
mut:
	tracks     []ExplicitGridTrack
	line_names []?GridLineNames
}

fn append_expanded_grid_track(mut result ExpandedGridTracksAndLines, track ExplicitGridTrack, line_names ?GridLineNames) {
	result.tracks << track
	result.line_names << line_names
}

fn expand_grid_tracks_and_lines(list GridTrackSizeList) ExpandedGridTracksAndLines {
	mut result := ExpandedGridTracksAndLines{}
	mut current_track := ?ExplicitGridTrack(none)
	mut current_line_names := ?GridLineNames(none)
	for component in list.list() {
		match component {
			GridLineNames {
				assert current_line_names == none
				current_line_names = component
			}
			ExplicitGridTrack {
				if track := current_track {
					append_expanded_grid_track(mut result, track, current_line_names)
					current_line_names = none
				}
				current_track = component
			}
		}
		if track := current_track {
			if line_names := current_line_names {
				append_expanded_grid_track(mut result, track, line_names)
				current_track = none
				current_line_names = none
			}
		}
	}
	if track := current_track {
		append_expanded_grid_track(mut result, track, current_line_names)
	}
	return result
}

fn append_grid_track_with_line_names(mut list GridTrackSizeList, track ExplicitGridTrack, line_names ?GridLineNames) {
	list.append_explicit_track(track)
	if names := line_names {
		list.append_line_names(names)
	}
}

fn interpolate_grid_css_size(calculation_context InterpolationCalculationContext, from Size, to Size, delta f64) Size {
	if from.is_length_percentage() && to.is_length_percentage() {
		if interpolated := interpolate_length_percentage(calculation_context, from.length_percentage(), to.length_percentage(), delta) {
			return Size.make_length_percentage(interpolated)
		}
	}
	if from.type_() != to.type_() {
		return if delta < 0.5 { from } else { to }
	}
	if from.is_fit_content() && to.is_fit_content() {
		from_available_space := from.fit_content_available_space() or {
			return if delta < 0.5 { from } else { to }
		}
		to_available_space := to.fit_content_available_space() or {
			return if delta < 0.5 { from } else { to }
		}
		if interpolated := interpolate_length_percentage(calculation_context, from_available_space, to_available_space, delta) {
			return Size.make_fit_content(interpolated)
		}
	}
	return if delta < 0.5 { from } else { to }
}

fn interpolate_grid_size(calculation_context InterpolationCalculationContext, from GridSize, to GridSize, delta f64) GridSize {
	if from.is_flexible_length() || to.is_flexible_length() {
		if from.is_flexible_length() && to.is_flexible_length() {
			return GridSize.from_flex(Flex.make_fr(interpolate_raw(from.flex_factor(), to.flex_factor(), delta, none)))
		}
	} else {
		return GridSize.from_size(interpolate_grid_css_size(calculation_context, from.css_size(), to.css_size(), delta))
	}
	return if delta < 0.5 { from } else { to }
}

fn interpolate_grid_track_size_list(calculation_context InterpolationCalculationContext, from GridTrackSizeList, to GridTrackSizeList, delta f64) ?GridTrackSizeList {
	if from.is_subgrid() || to.is_subgrid() {
		return none
	}
	expanded_from := expand_grid_tracks_and_lines(from)
	expanded_to := expand_grid_tracks_and_lines(to)
	if expanded_from.tracks.len != expanded_to.tracks.len {
		return none
	}

	mut result := GridTrackSizeList{}
	for i in 0 .. expanded_from.tracks.len {
		from_track := expanded_from.tracks[i]
		to_track := expanded_to.tracks[i]
		line_names := if delta < 0.5 {
			expanded_from.line_names[i]
		} else {
			expanded_to.line_names[i]
		}

		if from_track.is_repeat() || to_track.is_repeat() {
			if !from_track.is_repeat() || !to_track.is_repeat() {
				return none
			}
			from_repeat := from_track.repeat()
			to_repeat := to_track.repeat()
			if !from_repeat.is_fixed() || !to_repeat.is_fixed()
				|| from_repeat.repeat_count() != to_repeat.repeat_count()
				|| from_repeat.grid_track_size_list().track_list().len != to_repeat.grid_track_size_list().track_list().len {
				return none
			}
			interpolated_tracks := interpolate_grid_track_size_list(calculation_context, from_repeat.grid_track_size_list(), to_repeat.grid_track_size_list(), delta) or {
				return none
			}
			track := ExplicitGridTrack.from_repeat(GridRepeat.new(from_repeat.type_(), interpolated_tracks, StyleValue(IntegerStyleValue.create(i64(from_repeat.repeat_count())))))
			append_grid_track_with_line_names(mut result, track, line_names)
		} else if from_track.is_minmax() && to_track.is_minmax() {
			from_minmax := from_track.minmax()
			to_minmax := to_track.minmax()
			track := ExplicitGridTrack.from_minmax(GridMinMax.new(interpolate_grid_size(calculation_context, from_minmax.min_grid_size(), to_minmax.min_grid_size(), delta), interpolate_grid_size(calculation_context, from_minmax.max_grid_size(), to_minmax.max_grid_size(), delta)))
			append_grid_track_with_line_names(mut result, track, line_names)
		} else if from_track.is_default() && to_track.is_default() {
			track := ExplicitGridTrack.from_grid_size(interpolate_grid_size(calculation_context, from_track.grid_size(), to_track.grid_size(), delta))
			append_grid_track_with_line_names(mut result, track, line_names)
		} else {
			append_grid_track_with_line_names(mut result, if delta < 0.5 {
				from_track
			} else {
				to_track
			}, line_names)
		}
	}
	return result
}

fn interpolation_length_percentage_to_style_value(value LengthPercentage) StyleValue {
	if value.is_length() {
		return StyleValue(LengthStyleValue.create(value.length()))
	}
	if value.is_percentage() {
		return StyleValue(PercentageStyleValue.create(value.percentage()))
	}
	return StyleValue(value.calculated())
}

fn interpolation_length_percentage_or_auto_to_style_value(value LengthPercentageOrAuto) StyleValue {
	if value.is_auto() {
		return StyleValue(KeywordStyleValue.create(.auto))
	}
	return interpolation_length_percentage_to_style_value(value.length_percentage())
}

fn interpolation_calculation_operand(value StyleValue) string {
	serialized := value.serialize(.normal).trim_space()
	if value is CalculatedStyleValue && serialized.starts_with('calc(') && serialized.ends_with(')') {
		return serialized[5..serialized.len - 1]
	}
	return serialized
}

fn get_value_type_of_numeric_style_value(value StyleValue, calculation_context CalculationContext) ?ValueType {
	return match value {
		AngleStyleValue { ValueType.angle }
		FrequencyStyleValue { ValueType.frequency }
		IntegerStyleValue { ValueType.integer }
		LengthStyleValue { ValueType.length }
		NumberStyleValue { ValueType.number }
		PercentageStyleValue {
			calculation_context.percentages_resolve_as or { ValueType.percentage }
		}
		ResolutionStyleValue { ValueType.resolution }
		TimeStyleValue { ValueType.time }
		CalculatedStyleValue {
			numeric_type := value.numeric_type() or { return none }
			percentages_resolve_as := calculation_context.percentages_resolve_as
			if numeric_type.matches_angle_percentage(percentages_resolve_as) {
				ValueType.angle
			} else if numeric_type.matches_frequency_percentage(percentages_resolve_as) {
				ValueType.frequency
			} else if numeric_type.matches_length_percentage(percentages_resolve_as) {
				ValueType.length
			} else if numeric_type.matches_resolution(percentages_resolve_as) {
				ValueType.resolution
			} else if numeric_type.matches_number(percentages_resolve_as) {
				if calculation_context.resolve_numbers_as_integers {
					ValueType.integer
				} else {
					ValueType.number
				}
			} else if numeric_type.matches_percentage() {
				percentages_resolve_as or { ValueType.percentage }
			} else if numeric_type.matches_time_percentage(percentages_resolve_as) {
				ValueType.time
			} else {
				return none
			}
		}
		else {
			return none
		}
	}
}

fn interpolate_mixed_style_value(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64) ?StyleValue {
	mut numeric_context := CalculationContext.for_property(PropertyNameAndID.from_id(calculation_context.property))
	if percentages_resolve_as := calculation_context.percentages_resolve_as {
		numeric_context.percentages_resolve_as = percentages_resolve_as
	}
	from_type := get_value_type_of_numeric_style_value(from, numeric_context) or { return none }
	to_type := get_value_type_of_numeric_style_value(to, numeric_context) or { return none }
	if from_type != to_type {
		return none
	}
	if from is PercentageStyleValue && to.is_dimension() && to !is PercentageStyleValue {
		dimension_component := to.as_dimension().raw_value() * delta
		if dimension_component == 0 {
			return StyleValue(PercentageStyleValue.create(Percentage.new(from.raw_value() * (1.0 - delta))))
		}
	} else if to is PercentageStyleValue && from.is_dimension()
		&& from !is PercentageStyleValue {
		dimension_component := from.as_dimension().raw_value() * (1.0 - delta)
		if dimension_component == 0 {
			return StyleValue(PercentageStyleValue.create(Percentage.new(to.raw_value() * delta)))
		}
	}
	from_weight := serialize_a_number(1.0 - delta)
	to_weight := serialize_a_number(delta)
	serialization := 'calc(${from_weight} * (${interpolation_calculation_operand(from)}) + ${to_weight} * (${interpolation_calculation_operand(to)}))'
	// This helper interpolates a numeric component, which may be nested inside a
	// list-valued property such as grid-template-columns. Parsing the calculation
	// as the whole property would wrap it in that property's list style value.
	mut parser := Parser.from_css_text(serialization)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_calculated_value_with_context(mut tokens, numeric_context, true) or {
		return none
	}
	if tokens.has_more_tokens() {
		return none
	}
	return value
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

fn interpolate_raw_i64(from i64, to i64, delta f64, accepted_type_range ?AcceptedTypeRange) i64 {
	// Without an accepted range the result is not clamped. The previous
	// default bounds, written as i64 literals, produced a lower bound above
	// every result.
	mut result := f64(round_to_nearest_integer(f64(from) + (f64(to) - f64(from)) * delta))
	if range := accepted_type_range {
		result = clamp_f64(result, range.min, range.max)
	}
	return i64(result)
}

fn normalized_superellipse_half_corner(parameter f64) f64 {
	if math.is_inf(parameter, -1) {
		return 0
	}
	if math.is_inf(parameter, 1) {
		return 1
	}
	k := math.pow(0.5, math.abs(parameter))
	convex_half_corner := math.pow(0.5, k)
	return if parameter < 0 { 1.0 - convex_half_corner } else { convex_half_corner }
}

fn superellipse_parameter_from_interpolation_value(value f64) f64 {
	if value == 0 {
		return math.inf(-1)
	}
	if value == 0.5 {
		return 0
	}
	if value == 1 {
		return math.inf(1)
	}
	convex_half_corner := if value < 0.5 { 1.0 - value } else { value }
	k := math.log(0.5) / math.log(convex_half_corner)
	mut parameter := math.log(k) / math.log(2.0)
	if math.abs(math.round(parameter) - parameter) < 1e-7 {
		parameter = math.round(parameter)
	}
	return if value < 0.5 { -parameter } else { parameter }
}

fn interpolate_basic_shape_circle(calculation_context InterpolationCalculationContext, from BasicShapeCircle, to BasicShapeCircle, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	radius := interpolate_style_value_impl(calculation_context, from.radius, to.radius, delta, .no) or { return none }
	if from.position == none && to.position == none {
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeCircle{
			radius: radius
		})))
	}
	center := StyleValue(PositionStyleValue.create_computed_center())
	from_position := from.position or { center }
	to_position := to.position or { center }
	position := interpolate_style_value(calculation_context, from_position, to_position, delta, allow_discrete) or { return none }
	return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeCircle{
		radius: radius
		position: position
	})))
}

fn interpolate_basic_shape_ellipse(calculation_context InterpolationCalculationContext, from BasicShapeEllipse, to BasicShapeEllipse, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	radius := interpolate_style_value_impl(calculation_context, from.radius, to.radius, delta, .no) or { return none }
	if from.position == none && to.position == none {
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeEllipse{
			radius: radius
		})))
	}
	center := StyleValue(PositionStyleValue.create_computed_center())
	from_position := from.position or { center }
	to_position := to.position or { center }
	position := interpolate_style_value(calculation_context, from_position, to_position, delta, allow_discrete) or { return none }
	return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeEllipse{
		radius: radius
		position: position
	})))
}

fn interpolate_style_value_impl(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64, allow_discrete AllowDiscrete) ?StyleValue {
	if from.type_() != to.type_() || from.is_calculated() || to.is_calculated() {
		// Handle mixed percentages and dimensions by constructing the same weighted
		// calculation tree represented by the C++ Sum/Product calculation nodes.
		return interpolate_mixed_style_value(calculation_context, from, to, delta)
	}

	if from.type_() == .color {
		// The element-aware entry points install the layout color context used during style interpolation.
		color_resolution_context := calculation_context.color_resolution or {
			ColorResolutionContext{}
		}
		if interpolated := interpolate_style_values_color(from, to, delta, none, color_resolution_context) {
			return interpolated
		}
		return StyleValue(ColorStyleValue.create_from_color(Color.black(), .modern, none))
	}

	return match from {
		AngleStyleValue {
			if to is AngleStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .angle)
				interpolated_value := interpolate_raw(from.angle().to_degrees(), to.angle().to_degrees(), delta, range)
				StyleValue(AngleStyleValue.create(Angle.make_degrees(interpolated_value)))
			} else {
				none
			}
		}
		BackgroundSizeStyleValue {
			if to is BackgroundSizeStyleValue {
				x := interpolate_style_value(calculation_context, from.size_x(), to.size_x(), delta, allow_discrete) or { return none }
				y := interpolate_style_value(calculation_context, from.size_y(), to.size_y(), delta, allow_discrete) or { return none }
				StyleValue(BackgroundSizeStyleValue.create(x, y))
			} else {
				none
			}
		}
		BorderImageSliceStyleValue {
			if to is BorderImageSliceStyleValue {
				if from.fill() != to.fill() {
					return none
				}
				top := interpolate_style_value(calculation_context, from.top(), to.top(), delta, allow_discrete) or { return none }
				right := interpolate_style_value(calculation_context, from.right(), to.right(), delta, allow_discrete) or { return none }
				bottom := interpolate_style_value(calculation_context, from.bottom(), to.bottom(), delta, allow_discrete) or { return none }
				left := interpolate_style_value(calculation_context, from.left(), to.left(), delta, allow_discrete) or { return none }
				StyleValue(BorderImageSliceStyleValue.create(top, right, bottom, left, from.fill()))
			} else {
				none
			}
		}
		BasicShapeStyleValue {
			if to is BasicShapeStyleValue {
				basic_shape_context := InterpolationCalculationContext{
					property: calculation_context.property
					percentages_resolve_as: ValueType.length
				}
				from_basic_shape := from as BasicShapeStyleValue
				to_basic_shape := to as BasicShapeStyleValue
				mut from_shape := from_basic_shape.basic_shape()
				mut to_shape := to_basic_shape.basic_shape()
				if from_shape is BasicShapeCommands && to_shape is BasicShapePath { to_shape=BasicShape(shape_commands_from_svg_path(to_shape) or { return none }) }
				if from_shape is BasicShapePath && to_shape is BasicShapeCommands { from_shape=BasicShape(shape_commands_from_svg_path(from_shape) or { return none }) }
				mut interpolated_shape := ?BasicShape(none)
				match from_shape {
					BasicShapePath {
						if to_shape !is BasicShapePath { return none }
						interpolated_shape = BasicShape(interpolate_basic_shape_path(from_shape, to_shape, delta) or { return none })
					}
					BasicShapeCommands {
						if to_shape !is BasicShapeCommands { return none }
						interpolated_shape = BasicShape(interpolate_shape_commands(basic_shape_context,from_shape,to_shape,delta) or { return none })
					}
					BasicShapeInset {
						if to_shape !is BasicShapeInset {
							return none
						}
						from_inset := from_shape as BasicShapeInset
						to_inset := to_shape as BasicShapeInset
						top := interpolate_style_value(basic_shape_context, from_inset.top, to_inset.top, delta, allow_discrete) or { return none }
						right := interpolate_style_value(basic_shape_context, from_inset.right, to_inset.right, delta, allow_discrete) or { return none }
						bottom := interpolate_style_value(basic_shape_context, from_inset.bottom, to_inset.bottom, delta, allow_discrete) or { return none }
						left := interpolate_style_value(basic_shape_context, from_inset.left, to_inset.left, delta, allow_discrete) or { return none }
						border_radius := interpolate_style_value(basic_shape_context, from_inset.border_radius, to_inset.border_radius, delta, allow_discrete) or {
							return none
						}
						interpolated_shape = BasicShape(BasicShapeInset{
							top: top
							right: right
							bottom: bottom
							left: left
							border_radius: border_radius
						})
					}
					BasicShapeCircle {
						if to_shape !is BasicShapeCircle {
							return none
						}
						from_circle := from_shape as BasicShapeCircle
						to_circle := to_shape as BasicShapeCircle
						return interpolate_basic_shape_circle(basic_shape_context, from_circle, to_circle, delta, allow_discrete)
					}
					BasicShapeEllipse {
						if to_shape !is BasicShapeEllipse {
							return none
						}
						from_ellipse := from_shape as BasicShapeEllipse
						to_ellipse := to_shape as BasicShapeEllipse
						return interpolate_basic_shape_ellipse(basic_shape_context, from_ellipse, to_ellipse, delta, allow_discrete)
					}
					BasicShapePolygon {
						if to_shape !is BasicShapePolygon {
							return none
						}
						from_polygon := from_shape as BasicShapePolygon
						to_polygon := to_shape as BasicShapePolygon
						if from_polygon.fill_rule != to_polygon.fill_rule
							|| from_polygon.points.len != to_polygon.points.len {
							return none
						}
						mut points := []BasicShapePolygonPoint{cap: from_polygon.points.len}
						for index, from_point in from_polygon.points {
							to_point := to_polygon.points[index]
							x := interpolate_style_value(basic_shape_context, from_point.x, to_point.x, delta, allow_discrete) or { return none }
							y := interpolate_style_value(basic_shape_context, from_point.y, to_point.y, delta, allow_discrete) or { return none }
							points << BasicShapePolygonPoint{
								x: x
								y: y
							}
						}
						interpolated_shape = BasicShape(BasicShapePolygon{
							fill_rule: from_polygon.fill_rule
							round_radius:interpolate_style_value(basic_shape_context,from_polygon.round_radius,to_polygon.round_radius,delta,allow_discrete) or { return none }
							points: points
						})
					}
					else {
						return none
					}
				}
				shape := interpolated_shape or { return none }
				StyleValue(BasicShapeStyleValue.create(shape))
			} else {
				none
			}
		}
		BorderRadiusStyleValue {
			if to is BorderRadiusStyleValue {
				interpolated_horizontal_radius := interpolate_style_value_impl(calculation_context, from.horizontal_radius_(), to.horizontal_radius_(), delta, allow_discrete) or {
					return none
				}
				interpolated_vertical_radius := interpolate_style_value_impl(calculation_context, from.vertical_radius_(), to.vertical_radius_(), delta, allow_discrete) or {
					return none
				}
				StyleValue(BorderRadiusStyleValue.create(interpolated_horizontal_radius, interpolated_vertical_radius))
			} else {
				none
			}
		}
		BorderRadiusRectStyleValue {
			if to is BorderRadiusRectStyleValue {
				mut border_radius_rect_context := InterpolationCalculationContext{
					property: calculation_context.property
					percentages_resolve_as: ValueType.length
				}
				border_radius_rect_context.accepted_type_ranges[.length] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				border_radius_rect_context.accepted_type_ranges[.percentage] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				interpolated_top_left := interpolate_style_value_impl(border_radius_rect_context, from.top_left(), to.top_left(), delta, allow_discrete) or { return none }
				interpolated_top_right := interpolate_style_value_impl(border_radius_rect_context, from.top_right(), to.top_right(), delta, allow_discrete) or { return none }
				interpolated_bottom_right := interpolate_style_value_impl(border_radius_rect_context, from.bottom_right(), to.bottom_right(), delta, allow_discrete) or {
					return none
				}
				interpolated_bottom_left := interpolate_style_value_impl(border_radius_rect_context, from.bottom_left(), to.bottom_left(), delta, allow_discrete) or { return none }
				StyleValue(BorderRadiusRectStyleValue.create(interpolated_top_left, interpolated_top_right, interpolated_bottom_right, interpolated_bottom_left))
			} else {
				none
			}
		}
		EdgeStyleValue {
			if to is EdgeStyleValue {
				offset := interpolate_style_value_impl(calculation_context, from.offset(), to.offset(), delta, allow_discrete) or { return none }
				StyleValue(EdgeStyleValue.create(none, offset))
			} else {
				none
			}
		}
		FlexStyleValue {
			if to is FlexStyleValue {
				StyleValue(FlexStyleValue.create(Flex.new(interpolate_raw(from.raw_value(), to.raw_value(), delta, none), from.flex().unit())))
			} else {
				none
			}
		}
		FunctionStyleValue {
			if to is FunctionStyleValue && from.name() == to.name() {
				interpolated_value := interpolate_style_value(calculation_context, from.value(), to.value(), delta, allow_discrete) or {
					return none
				}
				StyleValue(FunctionStyleValue.create(from.name(), interpolated_value))
			} else {
				none
			}
		}
		FontStyleStyleValue {
			if to is FontStyleStyleValue {
				font_style := if from.font_style() == to.font_style() {
					from.font_style()
				} else {
					if allow_discrete == .no {
						return none
					}
					if delta >= 0.5 { to.font_style() } else { from.font_style() }
				}
				from_angle := from.angle()
				to_angle := to.angle()
				if from_angle != none && to_angle != none {
					mut angle_context := InterpolationCalculationContext{}
					angle_context.accepted_type_ranges[.angle] = AcceptedTypeRange{
						min: -90
						max: 90
					}
					angle := interpolate_style_value_impl(angle_context, from_angle, to_angle, delta, allow_discrete) or { return none }
					StyleValue(FontStyleStyleValue.create(font_style, angle))
				} else {
					StyleValue(FontStyleStyleValue.create(font_style, none))
				}
			} else {
				none
			}
		}
		FrequencyStyleValue {
			if to is FrequencyStyleValue {
				StyleValue(FrequencyStyleValue.create(Frequency.new(interpolate_raw(from.raw_value(), to.raw_value(), delta, none), from.frequency().unit())))
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
				StyleValue(IntegerStyleValue.create(interpolate_raw_i64(from.integer(), to.integer(), delta, range)))
			} else {
				none
			}
		}
		LengthStyleValue {
			if to is LengthStyleValue {
				from_length := from.length()
				to_length := to.length()
				range := interpolation_accepted_type_range(calculation_context, .length)
				interpolated_value := interpolate_raw(from_length.raw_value(), to_length.raw_value(), delta, range)
				StyleValue(LengthStyleValue.create(Length.new(interpolated_value, from_length.unit())))
			} else {
				none
			}
		}
		NumberStyleValue {
			if to is NumberStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .number)
				StyleValue(NumberStyleValue.create(interpolate_raw(from.number(), to.number(), delta, range)))
			} else {
				none
			}
		}
		OpenTypeTaggedStyleValue {
			if to is OpenTypeTaggedStyleValue {
				if from.tag() != to.tag() {
					return none
				}
				value := interpolate_style_value(calculation_context, from.value(), to.value(), delta, allow_discrete) or { return none }
				StyleValue(OpenTypeTaggedStyleValue.create(.font_variation_settings, from.tag(), value))
			} else {
				none
			}
		}
		PercentageStyleValue {
			if to is PercentageStyleValue {
				range := interpolation_accepted_type_range(calculation_context, .percentage)
				StyleValue(PercentageStyleValue.create(Percentage.new(interpolate_raw(from.percentage().value(), to.percentage().value(), delta, range))))
			} else {
				none
			}
		}
		PositionStyleValue {
			if to is PositionStyleValue {
				x := interpolate_style_value(calculation_context, StyleValue(from.edge_x()), StyleValue(to.edge_x()), delta, allow_discrete) or { return none }
				y := interpolate_style_value(calculation_context, StyleValue(from.edge_y()), StyleValue(to.edge_y()), delta, allow_discrete) or { return none }
				if x is EdgeStyleValue && y is EdgeStyleValue {
					StyleValue(PositionStyleValue.create(x, y))
				} else {
					none
				}
			} else {
				none
			}
		}
		RadialSizeStyleValue {
			if to is RadialSizeStyleValue {
				mut radial_size_context := InterpolationCalculationContext{
					property: calculation_context.property
					percentages_resolve_as: ValueType.length
				}
				radial_size_context.accepted_type_ranges[.length] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				from_components := from.components()
				to_components := to.components()
				for component in from_components {
					if component is RadialExtentComponent {
						return none
					}
				}
				for component in to_components {
					if component is RadialExtentComponent {
						return none
					}
				}
				from_x := from_components[0] as StyleValue
				to_x := to_components[0] as StyleValue
				from_y := if from_components.len > 1 {
					from_components[1] as StyleValue
				} else {
					from_x
				}
				to_y := if to_components.len > 1 { to_components[1] as StyleValue } else { to_x }
				x := interpolate_style_value(radial_size_context, from_x, to_x, delta, allow_discrete) or { return none }
				y := interpolate_style_value(radial_size_context, from_y, to_y, delta, allow_discrete) or { return none }
				if from_components.len == 1 && to_components.len == 1 {
					StyleValue(RadialSizeStyleValue.create([
						RadialSizeStyleValueComponent(x),
					]))
				} else {
					StyleValue(RadialSizeStyleValue.create([
						RadialSizeStyleValueComponent(x),
						RadialSizeStyleValueComponent(y),
					]))
				}
			} else {
				none
			}
		}
		RatioStyleValue {
			if to is RatioStyleValue {
				from_ratio := from.ratio()
				to_ratio := to.ratio()
				if from_ratio.is_degenerate() || to_ratio.is_degenerate() {
					return none
				}
				value := math.exp(interpolate_raw(math.log(from_ratio.value()), math.log(to_ratio.value()), delta, none))
				StyleValue(RatioStyleValue.create(Ratio.new_single(value)))
			} else {
				none
			}
		}
		RectStyleValue {
			if to is RectStyleValue {
				top := interpolate_rect_edge(calculation_context, from.top(), to.top(), delta, allow_discrete) or { return none }
				right := interpolate_rect_edge(calculation_context, from.right(), to.right(), delta, allow_discrete) or { return none }
				bottom := interpolate_rect_edge(calculation_context, from.bottom(), to.bottom(), delta, allow_discrete) or { return none }
				left := interpolate_rect_edge(calculation_context, from.left(), to.left(), delta, allow_discrete) or { return none }
				StyleValue(RectStyleValue.create(top, right, bottom, left))
			} else {
				none
			}
		}
		ResolutionStyleValue {
			if to is ResolutionStyleValue {
				StyleValue(ResolutionStyleValue.create(Resolution.new(interpolate_raw(from.raw_value(), to.raw_value(), delta, none), from.resolution().unit())))
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
					interpolated := interpolate_style_value(calculation_context, from.values()[i], to.values()[i], delta, .no) or { return none }
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
				interpolated_length_percentage := interpolate_style_value(calculation_context, from.length_percentage(), to.length_percentage(), delta, allow_discrete) or {
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
		SuperellipseStyleValue {
			if to is SuperellipseStyleValue {
				from_value := normalized_superellipse_half_corner(from.parameter())
				to_value := normalized_superellipse_half_corner(to.parameter())
				interpolated := interpolate_raw(from_value, to_value, delta, AcceptedTypeRange{
					min: 0
					max: 1
				})
				StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(superellipse_parameter_from_interpolation_value(interpolated)))))
			} else {
				none
			}
		}
		TimeStyleValue {
			if to is TimeStyleValue {
				interpolated_value := interpolate_raw(from.raw_value(), to.raw_value(), delta, none)
				unit := from.time().unit()
				interpolated_time := Time.new(interpolated_value, unit)
				StyleValue(TimeStyleValue.create(interpolated_time))
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
	if calculation_context.property == .shape_outside {
		first := shape_outside_without_default_box(from)
		last := shape_outside_without_default_box(to)
		if shape_outside_reference_box(first) != shape_outside_reference_box(last) {
			return interpolate_discrete_style_value(first, last, delta, allow_discrete)
		}
		if value := interpolate_style_value_impl(calculation_context, first, last, delta, allow_discrete) { return value }
		return interpolate_discrete_style_value(first, last, delta, allow_discrete)
	}
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
		value := interpolate_style_value(calculation_context, from_list.value_at(i, true), to_list.value_at(i, true), delta, .no) or {
			return interpolate_discrete_style_value(from_original, to_original, delta, allow_discrete)
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
			return interpolate_repeatable_style_value_lists(calculation_context, from, to, from, to, delta, allow_discrete)
		}
		to_list := interpolation_make_single_value_list(to, from.size(), from.separator())
		return interpolate_repeatable_style_value_lists(calculation_context, from, to_list, from, to, delta, allow_discrete)
	}
	if to is StyleValueList {
		from_list := interpolation_make_single_value_list(from, to.size(), to.separator())
		return interpolate_repeatable_style_value_lists(calculation_context, from_list, to, from, to, delta, allow_discrete)
	}
	return interpolate_style_value(calculation_context, from, to, delta, allow_discrete)
}

pub fn interpolate_value(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	mut context := calculation_context
	if layout_node := element.as_node().unsafe_layout_node() {
		context.color_resolution = color_resolution_context_for_layout_node(layout_node)
	}
	from_value := style_value_logic_from_dom(calculation_context.property, from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := style_value_logic_from_dom(calculation_context.property, to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	interpolated := interpolate_style_value(context, from_value, to_value, delta, allow_discrete) or {
		return none
	}
	return dom_style_value_from_value_logic(interpolated)
}

pub fn interpolate_repeatable_list(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	mut context := calculation_context
	if layout_node := element.as_node().unsafe_layout_node() {
		context.color_resolution = color_resolution_context_for_layout_node(layout_node)
	}
	from_value := style_value_logic_from_dom(calculation_context.property, from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := style_value_logic_from_dom(calculation_context.property, to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	interpolated := interpolate_repeatable_style_value_list(context, from_value, to_value, delta, allow_discrete) or { return none }
	return dom_style_value_from_value_logic(interpolated)
}

fn interpolation_font_style_with_normal_as_oblique_zero(value StyleValue) ?StyleValue {
	if value !is FontStyleStyleValue {
		return none
	}
	font_style := value as FontStyleStyleValue
	if font_style.font_style() == .normal {
		return StyleValue(FontStyleStyleValue.create(.oblique, StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))))
	}
	return value
}

fn interpolate_font_style_property(calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	parsed_from := style_value_logic_from_dom(.font_style, from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	parsed_to := style_value_logic_from_dom(.font_style, to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	if parsed_from is FontStyleStyleValue && parsed_to is FontStyleStyleValue {
		if parsed_from.font_style() == .italic || parsed_to.font_style() == .italic {
			return interpolate_discrete(from,to,delta,allow_discrete)
		}
	}
	normalized_from := interpolation_font_style_with_normal_as_oblique_zero(parsed_from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	normalized_to := interpolation_font_style_with_normal_as_oblique_zero(parsed_to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	result := interpolate_style_value(calculation_context, normalized_from, normalized_to, delta, allow_discrete) or { return none }
	return dom_style_value_from_value_logic(result)
}

fn interpolation_transform_or_identity(property_id PropertyID, value &dom.StyleValue, identity TransformationStyleValue) ?TransformationStyleValue {
	parsed := style_value_logic_from_dom(property_id, value) or { return none }
	if parsed.to_keyword() == .none_ {
		return identity
	}
	if parsed is TransformationStyleValue {
		return parsed
	}
	return none
}

fn interpolate_scale_property(calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	if from.css_text.trim_space().to_lower() == 'none' && to.css_text.trim_space().to_lower() == 'none' {
		return unsafe { from }
	}
	one := StyleValue(NumberStyleValue.create(1))
	identity := TransformationStyleValue.create(.scale, .scale, [one, one])
	from_transform := interpolation_transform_or_identity(.scale, from, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_transform := interpolation_transform_or_identity(.scale, to, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	from_values := from_transform.values()
	to_values := to_transform.values()
	from_x := from_values[0]
	to_x := to_values[0]
	from_y := if from_values.len > 1 { from_values[1] } else { from_x }
	to_y := if to_values.len > 1 { to_values[1] } else { to_x }
	x := interpolate_style_value(calculation_context, from_x, to_x, delta, allow_discrete) or {
		return none
	}
	y := interpolate_style_value(calculation_context, from_y, to_y, delta, allow_discrete) or {
		return none
	}
	mut values := [x, y]
	if from_values.len == 3 || to_values.len == 3 {
		from_z := if from_values.len == 3 { from_values[2] } else { one }
		to_z := if to_values.len == 3 { to_values[2] } else { one }
		z := interpolate_style_value(calculation_context, from_z, to_z, delta, allow_discrete) or {
			return none
		}
		values << z
	}
	result := TransformationStyleValue.create(.scale, if values.len == 3 {
		.scale3d
	} else {
		.scale
	}, values)
	return dom_style_value_from_value_logic(StyleValue(result))
}

fn interpolate_translate_property(calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	if from.css_text.trim_space().to_lower() == 'none' && to.css_text.trim_space().to_lower() == 'none' {
		return unsafe { from }
	}
	zero := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	identity := TransformationStyleValue.create(.translate, .translate, [zero, zero])
	from_transform := interpolation_transform_or_identity(.translate, from, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_transform := interpolation_transform_or_identity(.translate, to, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	from_values := from_transform.values()
	to_values := to_transform.values()
	from_x := from_values[0]
	to_x := to_values[0]
	from_y := if from_values.len > 1 { from_values[1] } else { zero }
	to_y := if to_values.len > 1 { to_values[1] } else { zero }
	x := interpolate_style_value(calculation_context, from_x, to_x, delta, allow_discrete) or {
		return none
	}
	y := interpolate_style_value(calculation_context, from_y, to_y, delta, allow_discrete) or {
		return none
	}
	mut values := [x, y]
	if from_values.len == 3 || to_values.len == 3 {
		from_z := if from_values.len == 3 { from_values[2] } else { zero }
		to_z := if to_values.len == 3 { to_values[2] } else { zero }
		z := interpolate_style_value(calculation_context, from_z, to_z, delta, allow_discrete) or {
			return none
		}
		values << z
	}
	result := TransformationStyleValue.create(.translate, if values.len == 3 {
		.translate3d
	} else {
		.translate
	}, values)
	return dom_style_value_from_value_logic(StyleValue(result))
}

fn interpolation_rotation_axis_and_angle(transform TransformationStyleValue) (FloatVector3, f64) {
	values := transform.values()
	if values.len == 4 {
		return FloatVector3{
			x: number_from_style_value(values[0], none)
			y: number_from_style_value(values[1], none)
			z: number_from_style_value(values[2], none)
		}, Angle.from_style_value(values[3], none).to_radians()
	}
	mut axis := FloatVector3{
		z: 1
	}
	match transform.transform_function() {
		.rotate_x {
			axis = FloatVector3{
				x: 1
			}
		}
		.rotate_y {
			axis = FloatVector3{
				y: 1
			}
		}
		else {}
	}
	return axis, Angle.from_style_value(values[0], none).to_radians()
}

fn interpolation_slerp(from []f64, to []f64, delta f64) []f64 {
	mut product := 0.0
	for i in 0 .. 4 {
		product += from[i] * to[i]
	}
	product = clamp_f64(product, -1, 1)
	if math.abs(product) >= 1 {
		return from.clone()
	}
	theta := math.acos(product)
	denominator := math.sqrt(1 - product * product)
	if denominator == 0 {
		return from.clone()
	}
	w := math.sin(delta * theta) / denominator
	from_multiplier := math.cos(delta * theta) - product * w
	mut result := []f64{len: 4}
	for i in 0 .. 4 {
		result[i] = from[i] * from_multiplier + to[i] * w
	}
	return result
}

struct InterpolationDecomposedMatrix {
	translation FloatVector3
	scale       FloatVector3
	skew        FloatVector3
	rotation    []f64
	perspective []f64
}

fn interpolation_float_matrix_rows(matrix FloatMatrix4x4) [4][4]f64 {
	return [
		[matrix.m11, matrix.m12, matrix.m13, matrix.m14]!,
		[matrix.m21, matrix.m22, matrix.m23, matrix.m24]!,
		[matrix.m31, matrix.m32, matrix.m33, matrix.m34]!,
		[matrix.m41, matrix.m42, matrix.m43, matrix.m44]!,
	]!
}

fn interpolation_float_matrix_from_rows(rows [4][4]f64) FloatMatrix4x4 {
	return FloatMatrix4x4.from_values(rows[0][0], rows[0][1], rows[0][2], rows[0][3], rows[1][0], rows[1][1], rows[1][2], rows[1][3], rows[2][0], rows[2][1], rows[2][2], rows[2][3], rows[3][0], rows[3][1], rows[3][2], rows[3][3])
}

fn interpolation_inverse_matrix(rows [4][4]f64) ?[4][4]f64 {
	mut augmented := [4][8]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			augmented[row][column] = rows[row][column]
			augmented[row][column + 4] = if row == column { 1 } else { 0 }
		}
	}

	for column in 0 .. 4 {
		mut pivot_row := column
		for row in column + 1 .. 4 {
			if math.abs(augmented[row][column]) > math.abs(augmented[pivot_row][column]) {
				pivot_row = row
			}
		}
		if math.abs(augmented[pivot_row][column]) < 1e-12 {
			return none
		}
		if pivot_row != column {
			for entry in 0 .. 8 {
				temporary := augmented[column][entry]
				augmented[column][entry] = augmented[pivot_row][entry]
				augmented[pivot_row][entry] = temporary
			}
		}

		pivot := augmented[column][column]
		for entry in 0 .. 8 {
			augmented[column][entry] /= pivot
		}
		for row in 0 .. 4 {
			if row == column {
				continue
			}
			factor := augmented[row][column]
			for entry in 0 .. 8 {
				augmented[row][entry] -= factor * augmented[column][entry]
			}
		}
	}

	mut inverse := [4][4]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			inverse[row][column] = augmented[row][column + 4]
		}
	}
	return inverse
}

fn interpolation_vector_dot(a FloatVector3, b FloatVector3) f64 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

fn interpolation_vector_cross(a FloatVector3, b FloatVector3) FloatVector3 {
	return FloatVector3{
		x: a.y * b.z - a.z * b.y
		y: a.z * b.x - a.x * b.z
		z: a.x * b.y - a.y * b.x
	}
}

fn interpolation_combine_vectors(a FloatVector3, b FloatVector3, a_scale f64, b_scale f64) FloatVector3 {
	return FloatVector3{
		x: a_scale * a.x + b_scale * b.x
		y: a_scale * a.y + b_scale * b.y
		z: a_scale * a.z + b_scale * b.z
	}
}

fn interpolation_vector_divided(vector FloatVector3, divisor f64) FloatVector3 {
	return FloatVector3{
		x: vector.x / divisor
		y: vector.y / divisor
		z: vector.z / divisor
	}
}

fn interpolation_decompose_matrix(matrix FloatMatrix4x4) ?InterpolationDecomposedMatrix {
	mut rows := interpolation_float_matrix_rows(matrix)
	if rows[3][3] == 0 {
		return none
	}
	normalization := rows[3][3]
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			rows[row][column] /= normalization
		}
	}

	mut perspective_matrix := rows
	for column in 0 .. 3 {
		perspective_matrix[3][column] = 0
	}
	perspective_matrix[3][3] = 1
	inverse_perspective := interpolation_inverse_matrix(perspective_matrix) or { return none }

	mut perspective := [f64(0), 0, 0, 1]
	if rows[3][0] != 0 || rows[3][1] != 0 || rows[3][2] != 0 {
		bottom_side := [rows[3][0], rows[3][1], rows[3][2], rows[3][3]]
		perspective = []f64{len: 4}
		for row in 0 .. 4 {
			for column in 0 .. 4 {
				perspective[row] += inverse_perspective[column][row] * bottom_side[column]
			}
		}
	}

	translation := FloatVector3{
		x: rows[0][3]
		y: rows[1][3]
		z: rows[2][3]
	}
	mut basis := [
		FloatVector3{ x: rows[0][0], y: rows[1][0], z: rows[2][0] },
		FloatVector3{ x: rows[0][1], y: rows[1][1], z: rows[2][1] },
		FloatVector3{ x: rows[0][2], y: rows[1][2], z: rows[2][2] },
	]!

	mut scale := FloatVector3{}
	mut skew := FloatVector3{}
	scale.x = basis[0].length()
	if scale.x == 0 {
		return none
	}
	basis[0] = interpolation_vector_divided(basis[0], scale.x)

	skew.x = interpolation_vector_dot(basis[0], basis[1])
	basis[1] = interpolation_combine_vectors(basis[1], basis[0], 1, -skew.x)
	scale.y = basis[1].length()
	if scale.y == 0 {
		return none
	}
	basis[1] = interpolation_vector_divided(basis[1], scale.y)
	skew.x /= scale.y

	skew.y = interpolation_vector_dot(basis[0], basis[2])
	basis[2] = interpolation_combine_vectors(basis[2], basis[0], 1, -skew.y)
	skew.z = interpolation_vector_dot(basis[1], basis[2])
	basis[2] = interpolation_combine_vectors(basis[2], basis[1], 1, -skew.z)
	scale.z = basis[2].length()
	if scale.z == 0 {
		return none
	}
	basis[2] = interpolation_vector_divided(basis[2], scale.z)
	skew.y /= scale.z
	skew.z /= scale.z

	if interpolation_vector_dot(basis[0], interpolation_vector_cross(basis[1], basis[2])) < 0 {
		scale.x = -scale.x
		scale.y = -scale.y
		scale.z = -scale.z
		for index in 0 .. 3 {
			basis[index].x = -basis[index].x
			basis[index].y = -basis[index].y
			basis[index].z = -basis[index].z
		}
	}

	mut rotation := [
		0.5 * math.sqrt(math.max(1 + basis[0].x - basis[1].y - basis[2].z, 0)),
		0.5 * math.sqrt(math.max(1 - basis[0].x + basis[1].y - basis[2].z, 0)),
		0.5 * math.sqrt(math.max(1 - basis[0].x - basis[1].y + basis[2].z, 0)),
		0.5 * math.sqrt(math.max(1 + basis[0].x + basis[1].y + basis[2].z, 0)),
	]
	if basis[2].y > basis[1].z {
		rotation[0] = -rotation[0]
	}
	if basis[0].z > basis[2].x {
		rotation[1] = -rotation[1]
	}
	if basis[1].x > basis[0].y {
		rotation[2] = -rotation[2]
	}

	return InterpolationDecomposedMatrix{
		translation: translation
		scale: scale
		skew: skew
		rotation: rotation
		perspective: perspective
	}
}

fn interpolation_recompose_matrix(values InterpolationDecomposedMatrix) FloatMatrix4x4 {
	mut rows := interpolation_float_matrix_rows(FloatMatrix4x4.identity())
	for column in 0 .. 4 {
		rows[3][column] = values.perspective[column]
	}
	translation := [values.translation.x, values.translation.y, values.translation.z]
	for row in 0 .. 4 {
		for column in 0 .. 3 {
			rows[row][3] += translation[column] * rows[row][column]
		}
	}

	x := values.rotation[0]
	y := values.rotation[1]
	z := values.rotation[2]
	w := values.rotation[3]
	// The rotation matrix is indexed by row and then column, the inverse of
	// how decomposition reads the rotation out of the matrix columns.
	mut rotation := interpolation_float_matrix_rows(FloatMatrix4x4.identity())
	rotation[0][0] = 1 - 2 * (y * y + z * z)
	rotation[0][1] = 2 * (x * y - z * w)
	rotation[0][2] = 2 * (x * z + y * w)
	rotation[1][0] = 2 * (x * y + z * w)
	rotation[1][1] = 1 - 2 * (x * x + z * z)
	rotation[1][2] = 2 * (y * z - x * w)
	rotation[2][0] = 2 * (x * z - y * w)
	rotation[2][1] = 2 * (y * z + x * w)
	rotation[2][2] = 1 - 2 * (x * x + y * y)
	mut recomposed := cssom_multiply_transform_matrices(interpolation_float_matrix_from_rows(rows), interpolation_float_matrix_from_rows(rotation))

	// As in the specification's pseudo-code, one temporary matrix carries the
	// skews, and each step only clears the entry the previous step set.
	mut skew := interpolation_float_matrix_rows(FloatMatrix4x4.identity())
	if values.skew.z != 0 {
		skew[1][2] = values.skew.z
		recomposed = cssom_multiply_transform_matrices(recomposed, interpolation_float_matrix_from_rows(skew))
	}
	if values.skew.y != 0 {
		skew[1][2] = 0
		skew[0][2] = values.skew.y
		recomposed = cssom_multiply_transform_matrices(recomposed, interpolation_float_matrix_from_rows(skew))
	}
	if values.skew.x != 0 {
		skew[0][2] = 0
		skew[0][1] = values.skew.x
		recomposed = cssom_multiply_transform_matrices(recomposed, interpolation_float_matrix_from_rows(skew))
	}

	mut result := interpolation_float_matrix_rows(recomposed)
	scales := [values.scale.x, values.scale.y, values.scale.z]
	for column in 0 .. 3 {
		for row in 0 .. 4 {
			result[row][column] *= scales[column]
		}
	}
	return interpolation_float_matrix_from_rows(result)
}

fn interpolate_matrices(from FloatMatrix4x4, to FloatMatrix4x4, delta f64) ?FloatMatrix4x4 {
	from_values := interpolation_decompose_matrix(from) or { return none }
	to_values := interpolation_decompose_matrix(to) or { return none }
	rotation := interpolation_slerp(from_values.rotation, to_values.rotation, delta)
	mut perspective := []f64{len: 4}
	for index in 0 .. 4 {
		perspective[index] = interpolate_raw(from_values.perspective[index], to_values.perspective[index], delta, none)
	}
	return interpolation_recompose_matrix(InterpolationDecomposedMatrix{
		translation: FloatVector3{
			x: interpolate_raw(from_values.translation.x, to_values.translation.x, delta, none)
			y: interpolate_raw(from_values.translation.y, to_values.translation.y, delta, none)
			z: interpolate_raw(from_values.translation.z, to_values.translation.z, delta, none)
		}
		scale: FloatVector3{
			x: interpolate_raw(from_values.scale.x, to_values.scale.x, delta, none)
			y: interpolate_raw(from_values.scale.y, to_values.scale.y, delta, none)
			z: interpolate_raw(from_values.scale.z, to_values.scale.z, delta, none)
		}
		skew: FloatVector3{
			x: interpolate_raw(from_values.skew.x, to_values.skew.x, delta, none)
			y: interpolate_raw(from_values.skew.y, to_values.skew.y, delta, none)
			z: interpolate_raw(from_values.skew.z, to_values.skew.z, delta, none)
		}
		rotation: rotation
		perspective: perspective
	})
}

fn matrix_to_style_value_vector(matrix FloatMatrix4x4) StyleValueVector {
	mut values := []StyleValue{cap: 16}
	for index in 0 .. 16 {
		values << StyleValue(NumberStyleValue.create(matrix.at(index % 4, index / 4)))
	}
	return values
}

fn interpolate_transform_matrix_suffix(from []TransformationStyleValue, to []TransformationStyleValue, start_index int, prefix []StyleValue, delta f64) ?StyleValue {
	mut from_matrix := FloatMatrix4x4.identity()
	mut to_matrix := FloatMatrix4x4.identity()
	for index in start_index .. from.len {
		from_component := from[index].to_matrix(none) or { return none }
		to_component := to[index].to_matrix(none) or { return none }
		from_matrix = cssom_multiply_transform_matrices(from_matrix, from_component)
		to_matrix = cssom_multiply_transform_matrices(to_matrix, to_component)
	}
	interpolated := interpolate_matrices(from_matrix, to_matrix, delta) or { return none }
	mut result := prefix.clone()
	result << StyleValue(TransformationStyleValue.create(.transform, .matrix3d, matrix_to_style_value_vector(interpolated)))
	return StyleValue(StyleValueList.create(result, .space, .yes))
}

fn interpolation_axis_angle_to_quaternion(axis FloatVector3, angle f64) []f64 {
	normalized := if axis.length() > 1e-5 {
		axis.normalized()
	} else {
		FloatVector3{
			z: 1
		}
	}
	sin_half := math.sin(angle / 2)
	return [normalized.x * sin_half, normalized.y * sin_half, normalized.z * sin_half,
		math.cos(angle / 2)]
}

fn interpolation_rotation_transform(from TransformationStyleValue, to TransformationStyleValue, delta f64, allow_discrete AllowDiscrete) ?TransformationStyleValue {
	from_axis, from_angle := interpolation_rotation_axis_and_angle(from)
	to_axis, to_angle := interpolation_rotation_axis_and_angle(to)
	from_normalized := if from_axis.length() > 1e-5 {
		from_axis.normalized()
	} else {
		FloatVector3{
			z: 1
		}
	}
	to_normalized := if to_axis.length() > 1e-5 {
		to_axis.normalized()
	} else {
		FloatVector3{
			z: 1
		}
	}
	difference := FloatVector3{
		x: from_normalized.x - to_normalized.x
		y: from_normalized.y - to_normalized.y
		z: from_normalized.z - to_normalized.z
	}
	if difference.length() < 1e-5 || from_angle == 0 || to_angle == 0 {
		axis := if to_angle != 0 {
			to_normalized
		} else if from_angle != 0 {
			from_normalized
		} else {
			FloatVector3{
				z: 1
			}
		}
		angle := interpolate_raw(from_angle, to_angle, delta, none) * 180.0 / math.pi
		return TransformationStyleValue.create(.rotate, .rotate3d, [
			StyleValue(NumberStyleValue.create(axis.x)),
			StyleValue(NumberStyleValue.create(axis.y)),
			StyleValue(NumberStyleValue.create(axis.z)),
			StyleValue(AngleStyleValue.create(Angle.make_degrees(angle))),
		])
	}
	mut from_quaternion := interpolation_axis_angle_to_quaternion(from_axis, from_angle)
	to_quaternion := interpolation_axis_angle_to_quaternion(to_axis, to_angle)
	// A quaternion and its negation are the same rotation. A negative dot
	// product would slerp the long way around, so negate one input to take
	// the shortest path, as other engines do.
	mut product := 0.0
	for index in 0 .. 4 {
		product += from_quaternion[index] * to_quaternion[index]
	}
	if product < 0 {
		for index in 0 .. 4 {
			from_quaternion[index] = -from_quaternion[index]
		}
	}
	quaternion := interpolation_slerp(from_quaternion, to_quaternion, delta)
	sin_half_angle := math.sqrt(math.max(0.0, 1.0 - quaternion[3] * quaternion[3]))
	mut axis := FloatVector3{
		x: quaternion[0]
		y: quaternion[1]
		z: quaternion[2]
	}
	if sin_half_angle >= 1e-5 {
		axis.x /= sin_half_angle
		axis.y /= sin_half_angle
		axis.z /= sin_half_angle
	} else {
		// The rotation angle is zero, so the axis is arbitrary.
		axis = FloatVector3{
			z: 1
		}
	}
	angle := 2.0 * math.acos(clamp_f64(quaternion[3], -1, 1)) * 180.0 / math.pi
	_ = allow_discrete
	return TransformationStyleValue.create(.rotate, .rotate3d, [
		StyleValue(NumberStyleValue.create(axis.x)),
		StyleValue(NumberStyleValue.create(axis.y)),
		StyleValue(NumberStyleValue.create(axis.z)),
		StyleValue(AngleStyleValue.create(Angle.make_degrees(angle))),
	])
}

fn interpolate_rotate_property(calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	if from.css_text.trim_space().to_lower() == 'none' && to.css_text.trim_space().to_lower() == 'none' {
		return unsafe { from }
	}
	zero_angle := StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
	identity := TransformationStyleValue.create(.rotate, .rotate, [zero_angle])
	from_transform := interpolation_transform_or_identity(.rotate, from, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_transform := interpolation_transform_or_identity(.rotate, to, identity) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	if from_transform.transform_function() == to_transform.transform_function() && from_transform.values().len == 1 && to_transform.values().len == 1 {
		angle := interpolate_style_value(calculation_context, from_transform.values()[0], to_transform.values()[0], delta, allow_discrete) or { return none }
		return dom_style_value_from_value_logic(StyleValue(TransformationStyleValue.create(.rotate, from_transform.transform_function(), [
			angle,
		])))
	}
	result := interpolation_rotation_transform(from_transform, to_transform, delta, allow_discrete) or {
		return none
	}
	return dom_style_value_from_value_logic(StyleValue(result))
}

fn interpolation_filter_list(value StyleValue) ?[]FilterStyleValue {
	if value.to_keyword() == .none_ {
		return []FilterStyleValue{}
	}
	if value is FilterValueListStyleValue && !value.contains_url() {
		return value.filter_value_list()
	}
	return none
}

fn interpolation_filter_initial_value(value FilterStyleValue) ?FilterStyleValue {
	zero_length := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	return match value {
		FilterOperationBlur {
			FilterStyleValue(FilterOperationBlur{
				radius: zero_length
			})
		}
		FilterOperationDropShadow {
			FilterStyleValue(FilterOperationDropShadow{
				offset_x: zero_length
				offset_y: zero_length
				radius: zero_length
				color: StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 0, 0)))
			})
		}
		FilterOperationHueRotate {
			FilterStyleValue(FilterOperationHueRotate{
				angle: StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
			})
		}
		FilterOperationColor {
			FilterStyleValue(FilterOperationColor{
				operation: value.operation
				amount: StyleValue(NumberStyleValue.create(if value.operation in [
					.grayscale,
					.invert,
					.sepia,
				] {
					0
				} else {
					1
				}))
			})
		}
		URL {
			none
		}
	}
}

fn interpolate_filter_function(calculation_context InterpolationCalculationContext, from FilterStyleValue, to FilterStyleValue, delta f64, allow_discrete AllowDiscrete, color_context ColorResolutionContext) ?FilterStyleValue {
	return match from {
		FilterOperationBlur {
			if to is FilterOperationBlur {
				mut blur_context := calculation_context
				blur_context.accepted_type_ranges = calculation_context.accepted_type_ranges.clone()
				blur_context.accepted_type_ranges[.length] = AcceptedTypeRange{
					min: 0
					max: math.max_f64
				}
				radius := interpolate_style_value(blur_context, from.radius, to.radius, delta, allow_discrete) or { return none }
				FilterStyleValue(FilterOperationBlur{
					radius: radius
				})
			} else {
				none
			}
		}
		FilterOperationHueRotate {
			if to is FilterOperationHueRotate {
				angle := interpolate_style_value(calculation_context, from.angle, to.angle, delta, allow_discrete) or { return none }
				FilterStyleValue(FilterOperationHueRotate{
					angle: angle
				})
			} else {
				none
			}
		}
		FilterOperationColor {
			// Different color filter functions, such as brightness() and
			// contrast(), do not interpolate. The caller then makes the whole
			// list discrete, as upstream does.
			if to is FilterOperationColor && to.operation == from.operation {
				operation := from.operation
				mut filter_context := calculation_context
				filter_context.accepted_type_ranges = calculation_context.accepted_type_ranges.clone()
				filter_context.accepted_type_ranges[.number] = AcceptedTypeRange{
					min: 0
					max: if operation in [.grayscale, .invert, .opacity, .sepia] {
						1
					} else {
						math.max_f64
					}
				}
				amount := interpolate_style_value(filter_context, from.amount, to.amount, delta, allow_discrete) or { return none }
				FilterStyleValue(FilterOperationColor{
					operation: operation
					amount: amount
				})
			} else {
				none
			}
		}
		FilterOperationDropShadow {
			if to is FilterOperationDropShadow {
				keeps_radius := if delta >= 0.5 { to.radius != none } else { from.radius != none }
				x := interpolate_style_value(calculation_context, from.offset_x, to.offset_x, delta, allow_discrete) or { return none }
				y := interpolate_style_value(calculation_context, from.offset_y, to.offset_y, delta, allow_discrete) or { return none }
				zero := StyleValue(LengthStyleValue.create(Length.make_px(0)))
				from_radius := from.radius or { zero }
				to_radius := to.radius or { zero }
				interpolated_radius := interpolate_style_value(calculation_context, from_radius, to_radius, delta, allow_discrete) or { return none }
				transparent := StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 0, 0)))
				from_color_value := from.color or { transparent }
				to_color_value := to.color or { transparent }
				interpolated_color_value := interpolate_style_values_color(from_color_value, to_color_value, delta, none, color_context) or {
					StyleValue(ColorStyleValue.create_from_color(Color.black(), .modern, none))
				}
				FilterStyleValue(FilterOperationDropShadow{
					offset_x: x
					offset_y: y
					radius: if keeps_radius {
						interpolated_radius
					} else {
						none
					}
					color: interpolated_color_value
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

fn interpolate_filter_value_list(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	from_value := style_value_logic_from_dom(calculation_context.property, from) or {
		return none
	}
	to_value := style_value_logic_from_dom(calculation_context.property, to) or { return none }
	mut from_list := interpolation_filter_list(from_value) or { return none }
	mut to_list := interpolation_filter_list(to_value) or { return none }
	if from_list.len == 0 && to_list.len == 0 {
		return unsafe { from }
	}
	for i := from_list.len; i < to_list.len; i++ {
		from_list << (interpolation_filter_initial_value(to_list[i]) or { return none })
	}
	for i := to_list.len; i < from_list.len; i++ {
		to_list << (interpolation_filter_initial_value(from_list[i]) or { return none })
	}
	mut color_context := ColorResolutionContext{}
	if layout_node := element.as_node().unsafe_layout_node() {
		color_context = color_resolution_context_for_layout_node(layout_node)
	}
	mut result := []FilterStyleValue{cap: from_list.len}
	for i in 0 .. from_list.len {
		result << (interpolate_filter_function(calculation_context, from_list[i], to_list[i], delta, allow_discrete, color_context) or { return none })
	}
	return dom_style_value_from_value_logic(StyleValue(FilterValueListStyleValue.create(result)))
}

pub fn interpolate_box_shadow(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	from_value := style_value_logic_from_dom(.box_shadow, from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := style_value_logic_from_dom(.box_shadow, to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}

	mut from_shadows := interpolation_shadow_list(from_value) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	mut to_shadows := interpolation_shadow_list(to_value) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	interpolation_extend_shadow_list(mut from_shadows, to_shadows)
	interpolation_extend_shadow_list(mut to_shadows, from_shadows)

	mut color_context := ColorResolutionContext{}
	if layout_node := element.as_node().unsafe_layout_node() {
		color_context = color_resolution_context_for_layout_node(layout_node)
	}

	mut blur_context := calculation_context
	blur_context.accepted_type_ranges = calculation_context.accepted_type_ranges.clone()
	blur_context.accepted_type_ranges[.length] = AcceptedTypeRange{
		min: 0
		max: math.max_f64
	}
	mut result := []StyleValue{cap: from_shadows.len}
	for i in 0 .. from_shadows.len {
		from_shadow := from_shadows[i]
		to_shadow := to_shadows[i]
		if from_shadow.shadow_type() != to_shadow.shadow_type() {
			return interpolate_discrete(from, to, delta, allow_discrete)
		}

		offset_x := interpolate_style_value(calculation_context, from_shadow.offset_x(), to_shadow.offset_x(), delta, allow_discrete) or { return none }
		offset_y := interpolate_style_value(calculation_context, from_shadow.offset_y(), to_shadow.offset_y(), delta, allow_discrete) or { return none }
		// A blur radius is never negative, even when extrapolating.
		blur_radius := interpolate_style_value(blur_context, from_shadow.blur_radius(), to_shadow.blur_radius(), delta, allow_discrete) or { return none }
		spread_distance := interpolate_style_value(calculation_context, from_shadow.spread_distance(), to_shadow.spread_distance(), delta, allow_discrete) or {
			return none
		}

		interpolated_color_value := interpolate_style_values_color(from_shadow.color(), to_shadow.color(), delta, none, color_context) or {
			StyleValue(ColorStyleValue.create_from_color(Color.black(), .modern, none))
		}
		placement := if delta >= 0.5 { to_shadow.placement() } else { from_shadow.placement() }
		result << StyleValue(ShadowStyleValue.create(from_shadow.shadow_type(), interpolated_color_value, offset_x, offset_y, blur_radius, spread_distance, placement))
	}

	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(result, .comma, .yes)))
}

fn interpolation_shadow_list(value StyleValue) ?[]ShadowStyleValue {
	if value.to_keyword() == .none_ {
		return []ShadowStyleValue{}
	}
	if value is ShadowStyleValue {
		return [value]
	}
	if value is StyleValueList {
		mut shadows := []ShadowStyleValue{cap: value.size()}
		for item in value.values() {
			if item !is ShadowStyleValue {
				return none
			}
			shadows << (item as ShadowStyleValue)
		}
		return shadows
	}
	return none
}

fn interpolation_extend_shadow_list(mut values []ShadowStyleValue, other []ShadowStyleValue) {
	for i := values.len; i < other.len; i++ {
		other_shadow := other[i]
		values << ShadowStyleValue.create(other_shadow.shadow_type(), StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 0, 0))), zero_length_style_value(), zero_length_style_value(), zero_length_style_value(), zero_length_style_value(), other_shadow.placement())
	}
}

pub fn interpolate_transform(element &dom.Element, calculation_context InterpolationCalculationContext, from &dom.StyleValue, to &dom.StyleValue, delta f64, allow_discrete AllowDiscrete) ?&dom.StyleValue {
	_ = element
	from_value := style_value_logic_from_dom(.transform, from) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	to_value := style_value_logic_from_dom(.transform, to) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	mut from_transformations := interpolation_transform_list(from_value) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	mut to_transformations := interpolation_transform_list(to_value) or {
		return interpolate_discrete(from, to, delta, allow_discrete)
	}
	if from_transformations.len == 0 && to_transformations.len == 0 {
		return &dom.StyleValue{
			css_text: 'none'
		}
	}
	interpolation_extend_transform_list(mut from_transformations, to_transformations)
	interpolation_extend_transform_list(mut to_transformations, from_transformations)

	mut result := []StyleValue{cap: from_transformations.len}
	for i in 0 .. from_transformations.len {
		mut from_transform := from_transformations[i]
		mut to_transform := to_transformations[i]
		from_function := from_transform.transform_function()
		to_function := to_transform.transform_function()
		if from_function == .perspective && to_function == .perspective {
			if perspective := interpolate_perspective_functions(from_transform, to_transform, delta) {
				result << StyleValue(perspective)
				continue
			}
		}
		// https://drafts.csswg.org/css-transforms-2/#interpolation-of-transform-functions
		// matrix() and matrix3d() get converted into 4x4 matrices first and
		// interpolated as matrices. A pair of the same matrix function is a
		// pair like any other, so the functions after it still pair up.
		if from_function == to_function && from_function in [.matrix, .matrix3d] {
			matrix := interpolate_transform_matrix_pair(from_transform, to_transform, delta) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			result << StyleValue(matrix)
			continue
		}
		if from_function in [.matrix, .matrix3d, .perspective]
			|| to_function in [.matrix, .matrix3d, .perspective] {
			matrix_result := interpolate_transform_matrix_suffix(from_transformations, to_transformations, i, result, delta) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			return dom_style_value_from_value_logic(matrix_result)
		}

		// https://drafts.csswg.org/css-transforms-1/#interpolation-of-transform-functions
		// Two transform functions with the same name and the same number of
		// arguments are interpolated numerically without a former conversion,
		// and the result keeps their type.
		same_function := from_function == to_function
			&& from_transform.values().len == to_transform.values().len
		if same_function {
			// Both already share their function and argument count.
		} else if interpolation_is_2d_transform(from_function) && interpolation_is_2d_transform(to_function) {
			from_transform = interpolation_convert_to_2d_primitive(from_transform)
			to_transform = interpolation_convert_to_2d_primitive(to_transform)
		} else if interpolation_is_3d_transform(from_function) || interpolation_is_3d_transform(to_function) {
			if !interpolation_is_3d_primitive(from_function) {
				from_transform = interpolation_convert_to_3d_primitive(from_transform) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
			}
			if !interpolation_is_3d_primitive(to_function) {
				to_transform = interpolation_convert_to_3d_primitive(to_transform) or {
					return interpolate_discrete(from, to, delta, allow_discrete)
				}
			}
		}

		function := from_transform.transform_function()
		if function != to_transform.transform_function() {
			matrix_result := interpolate_transform_matrix_suffix(from_transformations, to_transformations, i, result, delta) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			return dom_style_value_from_value_logic(matrix_result)
		}
		from_values := from_transform.values()
		to_values := to_transform.values()
		if from_values.len != to_values.len {
			matrix_result := interpolate_transform_matrix_suffix(from_transformations, to_transformations, i, result, delta) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			return dom_style_value_from_value_logic(matrix_result)
		}

		if function == .rotate3d {
			rotation := interpolation_rotation_transform(from_transform, to_transform, delta, .no) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			result << StyleValue(TransformationStyleValue.create(.transform, .rotate3d, rotation.values()))
			continue
		}

		is_translation := function in [.translate, .translate3d, .translate_x, .translate_y, .translate_z]
		mut values := []StyleValue{cap: from_values.len}
		mut interpolation_failed := false
		for value_index in 0 .. from_values.len {
			value := interpolate_transform_argument(calculation_context, is_translation, from_values[value_index], to_values[value_index], delta) or {
				interpolation_failed = true
				break
			}
			values << value
		}
		if interpolation_failed {
			matrix_result := interpolate_transform_matrix_suffix(from_transformations, to_transformations, i, result, delta) or {
				return interpolate_discrete(from, to, delta, allow_discrete)
			}
			return dom_style_value_from_value_logic(matrix_result)
		}
		result << StyleValue(TransformationStyleValue.create(.transform, function, values))
	}

	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(result, .space, .yes)))
}

// https://drafts.csswg.org/css-values-4/#combine-mixed
// A mix of a percentage and a dimension computes to a percentage when the
// dimension component is zero, so translate(0px) to translate(50%) passes
// through translate(25%) rather than calc(25% + 0px).
fn interpolate_translation_argument(calculation_context InterpolationCalculationContext, from StyleValue, to StyleValue, delta f64) ?StyleValue {
	if from is LengthStyleValue && to is PercentageStyleValue {
		if from.length().raw_value() * (1 - delta) == 0 {
			return StyleValue(PercentageStyleValue.create(Percentage.new(to.raw_value() * delta)))
		}
	}
	if from is PercentageStyleValue && to is LengthStyleValue {
		if to.length().raw_value() * delta == 0 {
			return StyleValue(PercentageStyleValue.create(Percentage.new(from.raw_value() * (1 - delta))))
		}
	}
	return interpolate_style_value(calculation_context, from, to, delta, .no)
}

fn interpolate_transform_argument(calculation_context InterpolationCalculationContext, is_translation bool, from StyleValue, to StyleValue, delta f64) ?StyleValue {
	if is_translation {
		return interpolate_translation_argument(calculation_context, from, to, delta)
	}
	return interpolate_style_value(calculation_context, from, to, delta, .no)
}

// The depth of perspective() as the negated m34 of its matrix: zero for
// perspective(none), and depths below 1px count as 1px.
fn perspective_reciprocal_depth(transform TransformationStyleValue) ?f64 {
	values := transform.values()
	if values.len != 1 {
		return none
	}
	argument := values[0]
	if style_value_is_keyword_none(argument) {
		return 0
	}
	if argument is LengthStyleValue && argument.length().is_absolute() {
		return 1 / math.max(argument.length().absolute_length_to_px_without_rounding(), 1)
	}
	return none
}

// https://drafts.csswg.org/css-transforms-2/#interpolation-of-transform-functions
// perspective() interpolates as a matrix, whose only varying component is
// the negated reciprocal of the depth. Interpolating that reciprocal gives the
// same result without decomposing two matrices; a depth that is not positive
// has no perspective effect, which perspective(none) expresses.
fn interpolate_perspective_functions(from TransformationStyleValue, to TransformationStyleValue, delta f64) ?TransformationStyleValue {
	from_reciprocal := perspective_reciprocal_depth(from) or { return none }
	to_reciprocal := perspective_reciprocal_depth(to) or { return none }
	reciprocal := interpolate_raw(from_reciprocal, to_reciprocal, delta, none)
	argument := if reciprocal <= 0 {
		StyleValue(KeywordStyleValue.create(.none_))
	} else {
		StyleValue(LengthStyleValue.create(Length.make_px(1 / reciprocal)))
	}
	return TransformationStyleValue.create(.transform, .perspective, [argument])
}

// Interpolates a matrix() or matrix3d() pair as matrices. Two matrix()
// functions stay two-dimensional.
fn interpolate_transform_matrix_pair(from TransformationStyleValue, to TransformationStyleValue, delta f64) ?TransformationStyleValue {
	from_matrix := from.to_matrix(none) or { return none }
	to_matrix := to.to_matrix(none) or { return none }
	matrix := interpolate_matrices(from_matrix, to_matrix, delta) or { return none }
	if from.transform_function() == .matrix && to.transform_function() == .matrix {
		mut values := []StyleValue{cap: 6}
		for entry in [matrix.at(0, 0), matrix.at(1, 0), matrix.at(0, 1), matrix.at(1, 1), matrix.at(0, 3), matrix.at(1, 3)] {
			values << StyleValue(NumberStyleValue.create(entry))
		}
		return TransformationStyleValue.create(.transform, .matrix, values)
	}
	return TransformationStyleValue.create(.transform, .matrix3d, matrix_to_style_value_vector(matrix))
}

fn interpolation_transform_list(value StyleValue) ?[]TransformationStyleValue {
	if value.to_keyword() == .none_ {
		return []TransformationStyleValue{}
	}
	if value is TransformationStyleValue {
		return [value]
	}
	if value is StyleValueList {
		mut result := []TransformationStyleValue{cap: value.size()}
		for item in value.values() {
			if item !is TransformationStyleValue {
				return none
			}
			result << (item as TransformationStyleValue)
		}
		return result
	}
	return none
}

fn interpolation_extend_transform_list(mut values []TransformationStyleValue, other []TransformationStyleValue) {
	for i := values.len; i < other.len; i++ {
		values << TransformationStyleValue.identity_transformation(other[i].transform_function())
	}
}

fn interpolation_is_2d_primitive(function TransformFunction) bool {
	return function in [.rotate, .scale, .translate]
}

fn interpolation_is_2d_transform(function TransformFunction) bool {
	return interpolation_is_2d_primitive(function)
		|| function in [.scale_x, .scale_y, .translate_x, .translate_y]
}

fn interpolation_is_3d_primitive(function TransformFunction) bool {
	return function in [.rotate3d, .scale3d, .translate3d]
}

fn interpolation_is_3d_transform(function TransformFunction) bool {
	return interpolation_is_2d_transform(function) || interpolation_is_3d_primitive(function)
		|| function in [.rotate_x, .rotate_y, .rotate_z, .scale_z, .translate_z]
}

fn interpolation_convert_to_2d_primitive(transform TransformationStyleValue) TransformationStyleValue {
	values := transform.values()
	zero := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	one := StyleValue(NumberStyleValue.create(1))
	return match transform.transform_function() {
		.rotate {
			TransformationStyleValue.create(.transform, .rotate, [values[0]])
		}
		.scale {
			TransformationStyleValue.create(.transform, .scale, [values[0], if values.len > 1 {
				values[1]
			} else {
				values[0]
			}])
		}
		.scale_x {
			TransformationStyleValue.create(.transform, .scale, [values[0], one])
		}
		.scale_y {
			TransformationStyleValue.create(.transform, .scale, [one, values[0]])
		}
		.translate {
			TransformationStyleValue.create(.transform, .translate, [values[0], if values.len > 1 {
				values[1]
			} else {
				zero
			}])
		}
		.translate_x {
			TransformationStyleValue.create(.transform, .translate, [values[0], zero])
		}
		.translate_y {
			TransformationStyleValue.create(.transform, .translate, [zero, values[0]])
		}
		else {
			transform
		}
	}
}

fn interpolation_convert_to_3d_primitive(original_transform TransformationStyleValue) ?TransformationStyleValue {
	transform := if interpolation_is_2d_transform(original_transform.transform_function()) {
		interpolation_convert_to_2d_primitive(original_transform)
	} else {
		original_transform
	}
	values := transform.values()
	zero_number := StyleValue(NumberStyleValue.create(0))
	one_number := StyleValue(NumberStyleValue.create(1))
	zero_length := StyleValue(LengthStyleValue.create(Length.make_px(0)))

	return match transform.transform_function() {
		.rotate, .rotate_z {
			TransformationStyleValue.create(.transform, .rotate3d, [zero_number, zero_number,
				one_number, values[0]])
		}
		.rotate_x {
			TransformationStyleValue.create(.transform, .rotate3d, [one_number, zero_number,
				zero_number, values[0]])
		}
		.rotate_y {
			TransformationStyleValue.create(.transform, .rotate3d, [zero_number, one_number,
				zero_number, values[0]])
		}
		.scale {
			TransformationStyleValue.create(.transform, .scale3d, [values[0], values[1], one_number])
		}
		.scale_z {
			TransformationStyleValue.create(.transform, .scale3d, [one_number, one_number, values[0]])
		}
		.translate {
			TransformationStyleValue.create(.transform, .translate3d, [values[0], values[1],
				zero_length])
		}
		.translate_z {
			TransformationStyleValue.create(.transform, .translate3d, [zero_length, zero_length,
				values[0]])
		}
		else {
			matrix := transform.to_matrix(none) or { return none }
			TransformationStyleValue.create(.transform, .matrix3d, matrix_to_style_value_vector(matrix))
		}
	}
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
				radius: filter_style_value_zero_length()
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
				amount: filter_style_value_number(default_amount)
			})
		}
		URL {
			none
		}
	}
}

fn filter_style_value_add_lengths(a StyleValue, b StyleValue) StyleValue {
	a_value := style_values_extra_length_from_style_value(a).absolute_length_to_px_without_rounding()
	b_value := style_values_extra_length_from_style_value(b).absolute_length_to_px_without_rounding()
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

fn filter_style_value_accumulate_colors(underlying ?StyleValue, animated ?StyleValue) ?StyleValue {
	underlying_value := underlying or { return animated }
	animated_value := animated or { return underlying }
	// Keep out-of-gamut endpoints until the sampled color is interpolated.
	// Adding quantized channels here both clamps too early and ignores alpha.
	return composite_colors(underlying_value, animated_value, ColorResolutionContext{}) or { return animated }
}

fn filter_style_value_accumulate_filter(underlying FilterStyleValue, animated FilterStyleValue) ?FilterStyleValue {
	return match underlying {
		FilterOperationBlur {
			if animated is FilterOperationBlur {
				FilterStyleValue(FilterOperationBlur{
					radius: StyleValue(LengthStyleValue.create(Length.make_px(underlying.resolved_radius() + animated.resolved_radius())))
				})
			} else {
				none
			}
		}
		FilterOperationHueRotate {
			if animated is FilterOperationHueRotate {
				FilterStyleValue(FilterOperationHueRotate{
					angle: StyleValue(AngleStyleValue.create(Angle.make_degrees(underlying.angle_degrees() + animated.angle_degrees())))
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
					amount: filter_style_value_number(accumulated)
				})
			} else {
				none
			}
		}
		FilterOperationDropShadow {
			if animated is FilterOperationDropShadow {
				accumulated_color := filter_style_value_accumulate_colors(underlying.color, animated.color)
				FilterStyleValue(FilterOperationDropShadow{
					offset_x: filter_style_value_add_lengths(underlying.offset_x, animated.offset_x)
					offset_y: filter_style_value_add_lengths(underlying.offset_y, animated.offset_y)
					radius: filter_style_value_add_optional_lengths(underlying.radius, animated.radius)
					color: accumulated_color
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
		accumulated := filter_style_value_accumulate_filter(extended_underlying[i], extended_animated[i]) or { return []FilterStyleValue{} }
		result << accumulated
	}
	return result
}

pub fn composite_value(property_id PropertyID, underlying_value &dom.StyleValue, animated_value &dom.StyleValue, composite_operation CompositeOperation) ?&dom.StyleValue {
	if composite_operation == .replace {
		return none
	}
	underlying := style_value_logic_from_dom(property_id, underlying_value) or { return none }
	animated := style_value_logic_from_dom(property_id, animated_value) or { return none }
	if property_id == .transform {
		result := composite_transform_lists(underlying, animated, composite_operation) or {
			return none
		}
		return dom_style_value_from_value_logic(result)
	}
	if property_id in [.box_shadow, .text_shadow] {
		result := composite_shadow_lists(property_id, underlying, animated, composite_operation) or {
			return none
		}
		return dom_style_value_from_value_logic(result)
	}
	if property_accepts_calc_size(property_id) {
		if result := composite_calc_size_values(property_id, underlying, animated) {
			return dom_style_value_from_value_logic(result)
		}
	}
	if property_id == .font_size_adjust {
		if result := composite_font_size_adjust_metric(underlying,animated,composite_operation) {
			return dom_style_value_from_value_logic(result)
		}
	}
	composited := composite_style_value(property_id, underlying, animated, composite_operation) or {
		return none
	}
	return dom_style_value_from_value_logic(composited)
}

fn add_length_percentages(calculation_context InterpolationCalculationContext, a LengthPercentage, b LengthPercentage) ?LengthPercentage {
	if a.is_length() && b.is_length() && a.length().unit() == b.length().unit() {
		return LengthPercentage.from_length(Length.new(a.length().raw_value() + b.length().raw_value(), a.length().unit()))
	}
	if a.is_percentage() && b.is_percentage() {
		return LengthPercentage.from_percentage(Percentage.new(a.percentage().value() + b.percentage().value()))
	}

	a_value := interpolation_length_percentage_to_style_value(a)
	b_value := interpolation_length_percentage_to_style_value(b)
	composited := composite_mixed_style_value(calculation_context.property, a_value, b_value) or {
		return none
	}
	if composited is LengthStyleValue || composited is PercentageStyleValue
		|| composited is CalculatedStyleValue {
		return LengthPercentage.from_style_value_logic(composited)
	}
	return none
}

fn composite_grid_css_size(calculation_context InterpolationCalculationContext, underlying Size, animated Size) ?Size {
	if underlying.is_length_percentage() && animated.is_length_percentage() {
		composited := add_length_percentages(calculation_context, underlying.length_percentage(), animated.length_percentage()) or {
			return none
		}
		return Size.make_length_percentage(composited)
	}
	if underlying.is_fit_content() && animated.is_fit_content() {
		underlying_available_space := underlying.fit_content_available_space() or { return none }
		animated_available_space := animated.fit_content_available_space() or { return none }
		composited := add_length_percentages(calculation_context, underlying_available_space, animated_available_space) or {
			return none
		}
		return Size.make_fit_content(composited)
	}
	return none
}

fn composite_grid_size(calculation_context InterpolationCalculationContext, underlying GridSize, animated GridSize) ?GridSize {
	if underlying.is_flexible_length() && animated.is_flexible_length() {
		return GridSize.from_flex(Flex.make_fr(underlying.flex_factor() + animated.flex_factor()))
	}
	if !underlying.is_flexible_length() && !animated.is_flexible_length() {
		composited := composite_grid_css_size(calculation_context, underlying.css_size(), animated.css_size()) or {
			return none
		}
		return GridSize.from_size(composited)
	}
	return none
}

fn composite_grid_track_size_list(calculation_context InterpolationCalculationContext, underlying GridTrackSizeList, animated GridTrackSizeList) ?GridTrackSizeList {
	if underlying.is_subgrid() || animated.is_subgrid() {
		return none
	}
	expanded_underlying := expand_grid_tracks_and_lines(underlying)
	expanded_animated := expand_grid_tracks_and_lines(animated)
	if expanded_underlying.tracks.len != expanded_animated.tracks.len {
		return none
	}

	mut result := GridTrackSizeList{}
	for i in 0 .. expanded_underlying.tracks.len {
		underlying_track := expanded_underlying.tracks[i]
		animated_track := expanded_animated.tracks[i]
		line_names := expanded_animated.line_names[i]

		if underlying_track.is_repeat() || animated_track.is_repeat() {
			if !underlying_track.is_repeat() || !animated_track.is_repeat() {
				return none
			}
			underlying_repeat := underlying_track.repeat()
			animated_repeat := animated_track.repeat()
			if !underlying_repeat.is_fixed() || !animated_repeat.is_fixed()
				|| underlying_repeat.repeat_count() != animated_repeat.repeat_count()
				|| underlying_repeat.grid_track_size_list().track_list().len != animated_repeat.grid_track_size_list().track_list().len {
				return none
			}
			tracks := composite_grid_track_size_list(calculation_context, underlying_repeat.grid_track_size_list(), animated_repeat.grid_track_size_list()) or {
				return none
			}
			track := ExplicitGridTrack.from_repeat(GridRepeat.new(underlying_repeat.type_(), tracks, StyleValue(IntegerStyleValue.create(i64(underlying_repeat.repeat_count())))))
			append_grid_track_with_line_names(mut result, track, line_names)
			continue
		}

		if underlying_track.is_minmax() && animated_track.is_minmax() {
			underlying_minmax := underlying_track.minmax()
			animated_minmax := animated_track.minmax()
			min_size := composite_grid_size(calculation_context, underlying_minmax.min_grid_size(), animated_minmax.min_grid_size()) or {
				animated_minmax.min_grid_size()
			}
			max_size := composite_grid_size(calculation_context, underlying_minmax.max_grid_size(), animated_minmax.max_grid_size()) or {
				animated_minmax.max_grid_size()
			}
			append_grid_track_with_line_names(mut result, ExplicitGridTrack.from_minmax(GridMinMax.new(min_size, max_size)), line_names)
			continue
		}

		if underlying_track.is_default() && animated_track.is_default() {
			if grid_size := composite_grid_size(calculation_context, underlying_track.grid_size(), animated_track.grid_size()) {
				append_grid_track_with_line_names(mut result, ExplicitGridTrack.from_grid_size(grid_size), line_names)
				continue
			}
		}
		append_grid_track_with_line_names(mut result, animated_track, line_names)
	}
	return result
}

fn composite_mixed_style_value(property_id PropertyID, underlying StyleValue, animated StyleValue) ?StyleValue {
	calculation_context := CalculationContext.for_property(PropertyNameAndID.from_id(property_id))
	underlying_type := get_value_type_of_numeric_style_value(underlying, calculation_context) or {
		return none
	}
	animated_type := get_value_type_of_numeric_style_value(animated, calculation_context) or {
		return none
	}
	if underlying_type != animated_type {
		return none
	}
	if underlying is PercentageStyleValue && animated.is_dimension()
		&& animated !is PercentageStyleValue && animated.as_dimension().raw_value() == 0 {
		return underlying
	}
	if animated is PercentageStyleValue && underlying.is_dimension()
		&& underlying !is PercentageStyleValue && underlying.as_dimension().raw_value() == 0 {
		return animated
	}
	serialization := 'calc((${interpolation_calculation_operand(underlying)}) + (${interpolation_calculation_operand(animated)}))'
	numeric := CSSNumericValue.parse(serialization) or { return none }
	return numeric.create_an_internal_representation(PropertyNameAndID.from_id(property_id), .no) or {
		none
	}
}

fn composite_basic_shape_circle(property_id PropertyID, underlying BasicShapeCircle, animated BasicShapeCircle, operation CompositeOperation) ?StyleValue {
	radius := composite_style_value(property_id, underlying.radius, animated.radius, operation) or {
		return none
	}
	if underlying.position == none && animated.position == none {
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeCircle{
			radius: radius
		})))
	}
	center := StyleValue(PositionStyleValue.create_computed_center())
	underlying_position := underlying.position or { center }
	animated_position := animated.position or { center }
	position := composite_style_value(property_id, underlying_position, animated_position, operation) or { return none }
	return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeCircle{
		radius: radius
		position: position
	})))
}

fn composite_basic_shape_ellipse(property_id PropertyID, underlying BasicShapeEllipse, animated BasicShapeEllipse, operation CompositeOperation) ?StyleValue {
	radius := composite_style_value(property_id, underlying.radius, animated.radius, operation) or {
		return none
	}
	if underlying.position == none && animated.position == none {
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeEllipse{
			radius: radius
		})))
	}
	center := StyleValue(PositionStyleValue.create_computed_center())
	underlying_position := underlying.position or { center }
	animated_position := animated.position or { center }
	position := composite_style_value(property_id, underlying_position, animated_position, operation) or { return none }
	return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeEllipse{
		radius: radius
		position: position
	})))
}

fn composite_style_value(property_id PropertyID, underlying StyleValue, animated StyleValue, operation CompositeOperation) ?StyleValue {
	if operation == .replace {
		return none
	}
	if underlying.type_() == .color && animated.type_() == .color {
		return composite_colors(underlying, animated, ColorResolutionContext{})
	}
	if underlying.type_() != animated.type_() || underlying.is_calculated() || animated.is_calculated() {
		return composite_mixed_style_value(property_id, underlying, animated)
	}

	return match underlying {
		AngleStyleValue {
			if animated is AngleStyleValue && underlying.angle().unit() == animated.angle().unit() {
				StyleValue(AngleStyleValue.create(Angle.new(underlying.raw_value() + animated.raw_value(), underlying.angle().unit())))
			} else {
				none
			}
		}
		BasicShapeStyleValue {
			if animated is BasicShapeStyleValue {
				underlying_basic_shape := underlying as BasicShapeStyleValue
				animated_basic_shape := animated as BasicShapeStyleValue
				underlying_shape := underlying_basic_shape.basic_shape()
				animated_shape := animated_basic_shape.basic_shape()
				mut composited_shape := ?BasicShape(none)
				match underlying_shape {
					BasicShapeInset {
						if animated_shape !is BasicShapeInset {
							return none
						}
						underlying_inset := underlying_shape as BasicShapeInset
						animated_inset := animated_shape as BasicShapeInset
						top := composite_style_value(property_id, underlying_inset.top, animated_inset.top, operation) or { return none }
						right := composite_style_value(property_id, underlying_inset.right, animated_inset.right, operation) or { return none }
						bottom := composite_style_value(property_id, underlying_inset.bottom, animated_inset.bottom, operation) or { return none }
						left := composite_style_value(property_id, underlying_inset.left, animated_inset.left, operation) or { return none }
						border_radius := composite_style_value(property_id, underlying_inset.border_radius, animated_inset.border_radius, operation) or {
							return none
						}
						composited_shape = BasicShape(BasicShapeInset{
							top: top
							right: right
							bottom: bottom
							left: left
							border_radius: border_radius
						})
					}
					BasicShapeCircle {
						if animated_shape !is BasicShapeCircle {
							return none
						}
						underlying_circle := underlying_shape as BasicShapeCircle
						animated_circle := animated_shape as BasicShapeCircle
						return composite_basic_shape_circle(property_id, underlying_circle, animated_circle, operation)
					}
					BasicShapeEllipse {
						if animated_shape !is BasicShapeEllipse {
							return none
						}
						underlying_ellipse := underlying_shape as BasicShapeEllipse
						animated_ellipse := animated_shape as BasicShapeEllipse
						return composite_basic_shape_ellipse(property_id, underlying_ellipse, animated_ellipse, operation)
					}
					BasicShapePolygon {
						if animated_shape !is BasicShapePolygon {
							return none
						}
						underlying_polygon := underlying_shape as BasicShapePolygon
						animated_polygon := animated_shape as BasicShapePolygon
						if underlying_polygon.fill_rule != animated_polygon.fill_rule
							|| underlying_polygon.points.len != animated_polygon.points.len {
							return none
						}
						mut points := []BasicShapePolygonPoint{cap: underlying_polygon.points.len}
						for index, underlying_point in underlying_polygon.points {
							animated_point := animated_polygon.points[index]
							x := composite_style_value(property_id, underlying_point.x, animated_point.x, operation) or { return none }
							y := composite_style_value(property_id, underlying_point.y, animated_point.y, operation) or { return none }
							points << BasicShapePolygonPoint{
								x: x
								y: y
							}
						}
						composited_shape = BasicShape(BasicShapePolygon{
							fill_rule: underlying_polygon.fill_rule
							round_radius:composite_style_value(property_id,underlying_polygon.round_radius,animated_polygon.round_radius,operation) or { return none }
							points: points
						})
					}
					else {
						return none
					}
				}
				shape := composited_shape or { return none }
				StyleValue(BasicShapeStyleValue.create(shape))
			} else {
				none
			}
		}
		FlexStyleValue {
			if animated is FlexStyleValue && underlying.flex().unit() == animated.flex().unit() {
				StyleValue(FlexStyleValue.create(Flex.new(underlying.raw_value() + animated.raw_value(), underlying.flex().unit())))
			} else {
				none
			}
		}
		FunctionStyleValue {
			if animated is FunctionStyleValue && underlying.name() == animated.name() {
				composited_value := composite_style_value(property_id, underlying.value(), animated.value(), operation) or {
					return none
				}
				StyleValue(FunctionStyleValue.create(underlying.name(), composited_value))
			} else {
				none
			}
		}
		FrequencyStyleValue {
			if animated is FrequencyStyleValue && underlying.frequency().unit() == animated.frequency().unit() {
				StyleValue(FrequencyStyleValue.create(Frequency.new(underlying.raw_value() + animated.raw_value(), underlying.frequency().unit())))
			} else {
				none
			}
		}
		GridTrackSizeListStyleValue {
			if animated is GridTrackSizeListStyleValue {
				context := InterpolationCalculationContext.for_property(property_id)
				list := composite_grid_track_size_list(context, underlying.grid_track_size_list(), animated.grid_track_size_list()) or {
					return none
				}
				StyleValue(GridTrackSizeListStyleValue.create(list))
			} else {
				none
			}
		}
		IntegerStyleValue {
			if animated is IntegerStyleValue {
				StyleValue(IntegerStyleValue.create(underlying.integer() + animated.integer()))
			} else {
				none
			}
		}
		LengthStyleValue {
			if animated is LengthStyleValue && underlying.length().unit() == animated.length().unit() {
				StyleValue(LengthStyleValue.create(Length.new(underlying.raw_value() + animated.raw_value(), underlying.length().unit())))
			} else {
				none
			}
		}
		NumberStyleValue {
			if animated is NumberStyleValue {
				StyleValue(NumberStyleValue.create(underlying.number() + animated.number()))
			} else {
				none
			}
		}
		PercentageStyleValue {
			if animated is PercentageStyleValue {
				StyleValue(PercentageStyleValue.create(Percentage.new(underlying.raw_value() + animated.raw_value())))
			} else {
				none
			}
		}
		ResolutionStyleValue {
			if animated is ResolutionStyleValue && underlying.resolution().unit() == animated.resolution().unit() {
				StyleValue(ResolutionStyleValue.create(Resolution.new(underlying.raw_value() + animated.raw_value(), underlying.resolution().unit())))
			} else {
				none
			}
		}
		TimeStyleValue {
			if animated is TimeStyleValue && underlying.time().unit() == animated.time().unit() {
				StyleValue(TimeStyleValue.create(Time.new(underlying.raw_value() + animated.raw_value(), underlying.time().unit())))
			} else {
				none
			}
		}
		BorderImageSliceStyleValue {
			if animated is BorderImageSliceStyleValue && underlying.fill() == animated.fill() {
				top := composite_style_value(property_id, underlying.top(), animated.top(), operation) or { return none }
				right := composite_style_value(property_id, underlying.right(), animated.right(), operation) or { return none }
				bottom := composite_style_value(property_id, underlying.bottom(), animated.bottom(), operation) or { return none }
				left := composite_style_value(property_id, underlying.left(), animated.left(), operation) or { return none }
				StyleValue(BorderImageSliceStyleValue.create(top, right, bottom, left, underlying.fill()))
			} else {
				none
			}
		}
		RectStyleValue {
			if animated is RectStyleValue {
				top := composite_rect_edge(property_id,underlying.top(),animated.top(),operation) or { return none }
				right := composite_rect_edge(property_id,underlying.right(),animated.right(),operation) or { return none }
				bottom := composite_rect_edge(property_id,underlying.bottom(),animated.bottom(),operation) or { return none }
				left := composite_rect_edge(property_id,underlying.left(),animated.left(),operation) or { return none }
				StyleValue(RectStyleValue.create(top,right,bottom,left))
			} else { none }
		}
		BorderRadiusStyleValue {
			if animated is BorderRadiusStyleValue {
				horizontal := composite_style_value(property_id, underlying.horizontal_radius_(), animated.horizontal_radius_(), operation) or { return none }
				vertical := composite_style_value(property_id, underlying.vertical_radius_(), animated.vertical_radius_(), operation) or { return none }
				StyleValue(BorderRadiusStyleValue.create(horizontal, vertical))
			} else {
				none
			}
		}
		BorderRadiusRectStyleValue {
			if animated is BorderRadiusRectStyleValue {
				top_left := composite_style_value(property_id, underlying.top_left(), animated.top_left(), operation) or { return none }
				top_right := composite_style_value(property_id, underlying.top_right(), animated.top_right(), operation) or { return none }
				bottom_right := composite_style_value(property_id, underlying.bottom_right(), animated.bottom_right(), operation) or { return none }
				bottom_left := composite_style_value(property_id, underlying.bottom_left(), animated.bottom_left(), operation) or { return none }
				StyleValue(BorderRadiusRectStyleValue.create(top_left, top_right, bottom_right, bottom_left))
			} else {
				none
			}
		}
		EdgeStyleValue {
			if animated is EdgeStyleValue && underlying.offset_ != unsafe { nil } && animated.offset_ != unsafe { nil } {
				offset := composite_style_value(property_id, underlying.offset(), animated.offset(), operation) or { return none }
				StyleValue(EdgeStyleValue.create(none, offset))
			} else {
				none
			}
		}
		OpenTypeTaggedStyleValue {
			if animated is OpenTypeTaggedStyleValue && underlying.tag() == animated.tag() {
				value := composite_style_value(property_id, underlying.value(), animated.value(), operation) or { return none }
				StyleValue(OpenTypeTaggedStyleValue.create(.font_variation_settings, underlying.tag(), value))
			} else {
				none
			}
		}
		PositionStyleValue {
			if animated is PositionStyleValue {
				x := composite_style_value(property_id, StyleValue(underlying.edge_x()), StyleValue(animated.edge_x()), operation) or { return none }
				y := composite_style_value(property_id, StyleValue(underlying.edge_y()), StyleValue(animated.edge_y()), operation) or { return none }
				if x is EdgeStyleValue && y is EdgeStyleValue {
					StyleValue(PositionStyleValue.create(x, y))
				} else {
					none
				}
			} else {
				none
			}
		}
		RadialSizeStyleValue {
			if animated is RadialSizeStyleValue {
				underlying_components := underlying.components()
				animated_components := animated.components()
				for component in underlying_components {
					if component is RadialExtentComponent {
						return none
					}
				}
				for component in animated_components {
					if component is RadialExtentComponent {
						return none
					}
				}
				underlying_x := underlying_components[0] as StyleValue
				animated_x := animated_components[0] as StyleValue
				if underlying_components.len == 1 && animated_components.len == 1 {
					value := composite_style_value(property_id, underlying_x, animated_x, operation) or { return none }
					StyleValue(RadialSizeStyleValue.create([
						RadialSizeStyleValueComponent(value),
					]))
				} else {
					underlying_y := if underlying_components.len > 1 {
						underlying_components[1] as StyleValue
					} else {
						underlying_x
					}
					animated_y := if animated_components.len > 1 {
						animated_components[1] as StyleValue
					} else {
						animated_x
					}
					x := composite_style_value(property_id, underlying_x, animated_x, operation) or { return none }
					y := composite_style_value(property_id, underlying_y, animated_y, operation) or { return none }
					StyleValue(RadialSizeStyleValue.create([
						RadialSizeStyleValueComponent(x),
						RadialSizeStyleValueComponent(y),
					]))
				}
			} else {
				none
			}
		}
		StyleValueList {
			if animated is StyleValueList && underlying.size() == animated.size() && underlying.separator() == animated.separator() {
				mut values := []StyleValue{cap: underlying.size()}
				for i in 0 .. underlying.size() {
					values << (composite_style_value(property_id, underlying.value_at(i, false), animated.value_at(i, false), operation) or { return none })
				}
				StyleValue(StyleValueList.create(values, underlying.separator(), .yes))
			} else {
				none
			}
		}
		FilterValueListStyleValue {
			if animated is FilterValueListStyleValue {
				if operation == .add {
					mut filters := underlying.filter_value_list()
					filters << animated.filter_value_list()
					StyleValue(FilterValueListStyleValue.create(filters))
				} else {
					filters := accumulate_filter_function(underlying.filter_value_list(), animated.filter_value_list())
					if filters.len == 0 {
						none
					} else {
						StyleValue(FilterValueListStyleValue.create(filters))
					}
				}
			} else {
				none
			}
		}
		else {
			none
		}
	}
}

// --- Style invalidation after style changes ---

fn is_stacking_context_creating_value_boundary(property_id PropertyID, value ?&dom.StyleValue) bool {
	if value == none {
		return false
	}
	parsed := style_value_logic_from_dom(property_id, value) or { return true }
	keyword := parsed.to_keyword()
	return match property_id {
		.opacity {
			if !parsed.is_number() {
				true
			} else {
				number_from_style_value(parsed) != 1.0
			}
		}
		.transform {
			if keyword == .none_ {
				false
			} else if parsed is StyleValueList {
				parsed.size() > 0
			} else {
				parsed.type_() == .transformation
			}
		}
		.translate, .rotate, .scale {
			keyword != .none_
		}
		.filter, .backdrop_filter {
			if parsed.is_keyword() {
				keyword != .none_
			} else {
				parsed is FilterValueListStyleValue
			}
		}
		.clip_path, .mask, .mask_image, .view_transition_name {
			keyword != .none_
		}
		.isolation {
			keyword == .isolate
		}
		.mix_blend_mode {
			keyword != .normal
		}
		.z_index {
			keyword != .auto
		}
		.perspective, .transform_style {
			keyword != .none_ && keyword != .flat
		}
		.backface_visibility {
			keyword == .hidden
		}
		else {
			true
		}
	}
}

fn property_rebuilds_accumulated_visual_contexts(property_id PropertyID) bool {
	return match property_id {
		.backface_visibility, .background_attachment, .clip, .filter, .mask_image, .mix_blend_mode,
		.opacity, .overflow_x, .overflow_y, .perspective, .perspective_origin, .rotate, .scale, .transform,
		.transform_origin, .transform_style, .translate {
			true
		}
		.accent_color, .anchor_name, .anchor_scope, .animation_composition, .animation_delay,
		.animation_direction, .animation_duration, .animation_fill_mode,
		.animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline,
		.animation_range_start, .animation_range_end,
		.animation_timing_function, .aspect_ratio, .background_blend_mode, .background_clip,
		.background_color, .background_image, .background_origin, .background_position_x,
		.background_position_y, .background_repeat, .background_size, .border_bottom_color,
		.border_bottom_style, .border_bottom_width, .border_bottom_left_radius,
		.border_bottom_right_radius, .border_collapse, .border_image_outset, .border_image_repeat,
		.border_image_slice, .border_image_source, .border_image_width, .border_left_color,
		.border_left_style, .border_left_width, .border_right_color, .border_right_style,
		.border_right_width, .border_top_color, .border_top_style, .border_top_width,
		.border_top_left_radius, .border_top_right_radius, .box_sizing, .caption_side,
		.caret_color, .clear, .clip_rule, .color, .color_interpolation,
		.color_interpolation_filters, .color_scheme, .content_visibility,
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_top_left_shape,
		.corner_top_right_shape, .fill_opacity, .fill_rule, .flood_color, .flood_opacity, .float_,
		.direction, .empty_cells, .font_feature_settings, .font_kerning, .font_language_override,
		.font_optical_sizing, .font_style, .font_variant_caps, .font_variant_emoji,
		.font_variant_position, .font_variation_settings, .font_weight, .font_width, .flex_grow,
		.flex_shrink, .flex_direction, .flex_wrap, .align_content, .align_items, .align_self,
		.justify_content, .justify_items, .justify_self, .appearance, .column_span, .column_count,
		.column_width, .column_height, .column_gap, .row_gap, .contain, .container_type,
		.image_rendering, .isolation, .letter_spacing, .line_height, .list_style_image,
		.list_style_position, .mask_clip, .mask_composite, .mask_mode, .mask_origin,
		.mask_position, .mask_repeat, .mask_size, .mask_type, .math_depth, .math_shift,
		.math_style, .object_fit, .object_position, .order, .orphans, .widows, .outline_color,
		.outline_offset, .outline_style, .outline_width, .overflow_block,
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap,
		.pointer_events, .position_area, .position_try_fallbacks,
		.position_try_order, .scroll_behavior, .scroll_timeline_axis, .scrollbar_color,
		.scrollbar_gutter, .shape_margin, .shape_rendering, .position, .position_anchor,
		.position_visibility, .scroll_timeline_name, .shape_image_threshold, .stop_color,
		.stop_opacity, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity,
		.stroke_width, .stroke_dashoffset, .tab_size, .table_layout, .text_align, .text_anchor,
		.text_justify, .text_overflow, .text_decoration_color, .text_decoration_line,
		.text_decoration_style, .text_decoration_thickness, .text_underline_offset,
		.text_underline_position, .text_indent, .paint_order, .text_rendering, .text_transform,
		.text_wrap_mode, .text_wrap_style, .timeline_scope, .transform_box, .touch_action,
		.transition_behavior, .transition_delay, .transition_duration, .transition_property,
		.transition_timing_function, .unicode_bidi, .user_select, .vertical_align,
		.view_timeline_axis, .view_timeline_inset, .view_timeline_name, .view_transition_name,
		.will_change, .writing_mode, .scrollbar_width, .resize, .visibility,
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
		// Counter operations alter generated content throughout their scope.
		.counter_increment, .counter_reset, .counter_set, .float_, .overflow_block, .overflow_inline, .overflow_x, .overflow_y, .position {
			true
		}
		else {
			false
		}
	}
}

fn display_from_invalidation_style_value(value ?&dom.StyleValue) ?Display {
	if value == none {
		return none
	}
	typed := style_value_logic_from_dom(.display, value) or { return none }
	if typed is DisplayStyleValue {
		return typed.display()
	}
	return none
}

// Generated from Properties.json's `affects-hit-testing` metadata.
pub fn property_affects_hit_testing(property_id PropertyID) bool {
	return property_id in [
		.border_bottom_left_radius,
		.border_bottom_right_radius,
		.border_top_left_radius,
		.border_top_right_radius,
		.fill,
		.fill_rule,
		.pointer_events,
		.resize,
		.visibility,
	]
}

pub fn compute_property_invalidation(property_id PropertyID, old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}

	property_value_changed := style_value_option_changed(old_value, new_value)
	if !property_value_changed {
		return invalidation
	}

	// A principal box appearing or disappearing leaves the sibling box kinds
	// intact. Preserve that narrower upstream rebuild root even though the V tree
	// builder currently consumes it through its conservative parent rebuild.
	if property_id == .display {
		old_display := display_from_invalidation_style_value(old_value) or {
			return required_invalidation_after_style_change_full()
		}
		new_display := display_from_invalidation_style_value(new_value) or {
			return required_invalidation_after_style_change_full()
		}
		if old_display.is_none() != new_display.is_none() {
			box_display := if old_display.is_none() { new_display } else { old_display }
			if box_display.is_outside_and_inside() {
				return RequiredInvalidationAfterStyleChange.rebuild_layout_tree_from(.box_presence_change)
			}
		}
		return required_invalidation_after_style_change_full()
	}

	// Generated content and text transformation only replace the originating
	// element's own layout subtree.
	if property_id in [.content, .content_visibility, .text_transform] {
		return RequiredInvalidationAfterStyleChange.rebuild_layout_tree_from(.self)
	}

	if property_requires_full_invalidation(property_id) {
		return required_invalidation_after_style_change_full()
	}

	if property_id in [.container_name, .container_type] {
		invalidation.recompute_descendant_styles = true
	}
	// overflow:clip expands the existing visual clip by these margins. Layout
	// alone does not refresh the accumulated visual-context values.
	if property_id in [.overflow_clip_margin_top, .overflow_clip_margin_right,
		.overflow_clip_margin_bottom, .overflow_clip_margin_left,
		.overflow_clip_margin_block_start, .overflow_clip_margin_block_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_inline_end] {
		invalidation.ensure_accumulated_visual_contexts_at_least(.update_values)
	}
	if property_affects_hit_testing(property_id) {
		invalidation.affects_hit_testing = true
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
			invalidation.ensure_at_least(.relayout)
		}
		// Visibility also controls whether the box owns a backdrop filter. Keep
		// retained effect values in sync when this changes without a relayout.
		invalidation.ensure_accumulated_visual_contexts_at_least(.update_values)
		// Of course, we still have to repaint on any visibility change.
		invalidation.ensure_at_least(.repaint)
	} else if property_affects_layout(property_id) {
		invalidation.ensure_at_least(.relayout)
	}

	if property_affects_stacking_context(property_id) {
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
			invalidation.set_needs_stacking_context_tree_rebuild()
		} else {
			// OPTIMIZATION: Only rebuild stacking context tree when property crosses from a neutral value
			// (doesn't create stacking context) to a creating value or vice versa.
			old_creates := is_stacking_context_creating_value_boundary(property_id, old_value)
			new_creates := is_stacking_context_creating_value_boundary(property_id, new_value)
			if old_creates != new_creates {
				invalidation.set_needs_stacking_context_tree_rebuild()
			}
		}
	}

	if property_rebuilds_accumulated_visual_contexts(property_id) {
		invalidation.ensure_accumulated_visual_contexts_at_least(.rebuild)
	}

	invalidation.ensure_at_least(.repaint)
	return invalidation
}

pub fn required_invalidation_after_style_change_full() RequiredInvalidationAfterStyleChange {
	return RequiredInvalidationAfterStyleChange.full()
}

pub fn required_invalidation_after_style_change_is_full(invalidation RequiredInvalidationAfterStyleChange) bool {
	return invalidation.needs_repaint() && invalidation.needs_stacking_context_tree_rebuild()
		&& invalidation.needs_relayout() && invalidation.needs_layout_tree_rebuild()
}

pub fn required_invalidation_after_style_change_or(left RequiredInvalidationAfterStyleChange, right RequiredInvalidationAfterStyleChange) RequiredInvalidationAfterStyleChange {
	mut result := left
	if right.needs_layout_tree_rebuild() {
		if result.needs_layout_tree_rebuild() {
			if int(right.layout_tree_rebuild_root_) > int(result.layout_tree_rebuild_root_) {
				result.layout_tree_rebuild_root_ = right.layout_tree_rebuild_root_
			}
		} else {
			result.layout_tree_rebuild_root_ = right.layout_tree_rebuild_root_
		}
	}
	if int(right.level_) > int(result.level_) {
		result.level_ = right.level_
	}
	if int(right.accumulated_visual_contexts_) > int(result.accumulated_visual_contexts_) {
		result.accumulated_visual_contexts_ = right.accumulated_visual_contexts_
	}
	result.rebuild_stacking_context_tree_ = result.rebuild_stacking_context_tree_
		|| right.rebuild_stacking_context_tree_
	result.needs_scrollable_overflow_recalculation_ = result.needs_scrollable_overflow_recalculation_
		|| right.needs_scrollable_overflow_recalculation_
	result.needs_scroll_container_resnap = result.needs_scroll_container_resnap
		|| right.needs_scroll_container_resnap
	result.recompute_descendant_styles = result.recompute_descendant_styles
		|| right.recompute_descendant_styles
	result.inherited_style_groups_changed_ |= right.inherited_style_groups_changed_
	result.changes_containing_block_establishment = result.changes_containing_block_establishment
		|| right.changes_containing_block_establishment
	result.repaint_propagated_text_decorations = result.repaint_propagated_text_decorations
		|| right.repaint_propagated_text_decorations
	result.repaint_selection = result.repaint_selection || right.repaint_selection
	result.affects_hit_testing = result.affects_hit_testing || right.affects_hit_testing
	result.non_inherited_property_inheritance_sources_changed = result.non_inherited_property_inheritance_sources_changed
		|| right.non_inherited_property_inheritance_sources_changed
	return result
}

// --- InvalidationSet ---
pub enum CSSPseudoClass as u8 {
	enabled
	disabled
	defined
	placeholder_shown
	checked
	dir
	empty
	lang
	required
	optional
	read_only
	read_write
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
	hover
	focus
	focus_visible
	focus_within
	active
	target
	host
	root
	first_child
	last_child
	only_child
	paused
	playing
	muted
	seeking
	buffering
	stalled
	other
}

pub fn pseudo_class_name(pseudo_class CSSPseudoClass) string {
	return match pseudo_class {
		.enabled { 'enabled' }
		.disabled { 'disabled' }
		.defined { 'defined' }
		.placeholder_shown { 'placeholder-shown' }
		.checked { 'checked' }
		.dir { 'dir' }
		.empty { 'empty' }
		.lang { 'lang' }
		.required { 'required' }
		.optional { 'optional' }
		.read_only { 'read-only' }
		.read_write { 'read-write' }
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
		.hover { 'hover' }
		.focus { 'focus' }
		.focus_visible { 'focus-visible' }
		.focus_within { 'focus-within' }
		.active { 'active' }
		.target { 'target' }
		.host { 'host' }
		.root { 'root' }
		.first_child { 'first-child' }
		.last_child { 'last-child' }
		.only_child { 'only-child' }
		.paused { 'paused' }
		.playing { 'playing' }
		.muted { 'muted' }
		.seeking { 'seeking' }
		.buffering { 'buffering' }
		.stalled { 'stalled' }
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
		'dir' { .dir }
		'empty' { .empty }
		'lang' { .lang }
		'required' { .required }
		'optional' { .optional }
		'read-only' { .read_only }
		'read-write' { .read_write }
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
		'hover' { .hover }
		'focus' { .focus }
		'focus-visible' { .focus_visible }
		'focus-within' { .focus_within }
		'active' { .active }
		'target' { .target }
		'host' { .host }
		'root' { .root }
		'first-child' { .first_child }
		'last-child' { .last_child }
		'only-child' { .only_child }
		'paused' { .paused }
		'playing' { .playing }
		'muted' { .muted }
		'seeking' { .seeking }
		'buffering' { .buffering }
		'stalled' { .stalled }
		else { .other }
	}
}

pub enum InvalidationPropertyType as u8 {
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
		type_: .pseudo_class
		pseudo_class: pseudo_class
	}
}

pub fn (p InvalidationProperty) name() string {
	return p.value
}

pub fn (p InvalidationProperty) key() string {
	return match p.type_ {
		.invalidate_self { '\$' }
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
		.invalidate_self { '\$' }
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
	has_first_property_             bool
	first_property_key_             string
	first_property_                 InvalidationProperty
	// Most selector match sets contain zero or one property. Keep that first
	// property inline and allocate an ordered hash map only for overflow.
	additional_properties_ ?map[string]InvalidationProperty
}

pub fn (mut s InvalidationSet) include_all_from(other InvalidationSet) {
	s.needs_invalidate_self_ = s.needs_invalidate_self_ || other.needs_invalidate_self_
	s.needs_invalidate_whole_subtree_ = s.needs_invalidate_whole_subtree_ || other.needs_invalidate_whole_subtree_
	if other.has_first_property_ {
		s.add_stored_property(other.first_property_key_, other.first_property_)
	}
	if properties := other.additional_properties_ {
		for key, property in properties {
			s.add_stored_property(key, property)
		}
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

fn (mut s InvalidationSet) add_stored_property(key string, property InvalidationProperty) {
	if !s.has_first_property_ {
		s.has_first_property_ = true
		s.first_property_key_ = key
		s.first_property_ = property
		return
	}
	if key == s.first_property_key_ {
		return
	}
	// Preserve the previous map field's shallow value-header semantics. The
	// pinned compiler copies an optional binding's header, even with `if mut`,
	// so this private synchronous method writes the changed header back. No
	// callback can observe it between extraction and writeback; no map is cloned.
	mut properties := unsafe { s.additional_properties_ or { map[string]InvalidationProperty{} } }
	if key in properties {
		return
	}
	properties[key] = property
	s.additional_properties_ = unsafe { properties }
}

fn (mut s InvalidationSet) add_property(property InvalidationProperty) {
	s.add_stored_property(property.key(), property)
}

fn (s &InvalidationSet) property_count() int {
	mut count := if s.has_first_property_ { 1 } else { 0 }
	if properties := s.additional_properties_ {
		count += properties.len
	}
	return count
}

fn (mut s InvalidationSet) clear_properties() {
	s.has_first_property_ = false
	s.first_property_key_ = ''
	s.first_property_ = InvalidationProperty{}
	s.additional_properties_ = none
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
	return !s.needs_invalidate_self_ && !s.needs_invalidate_whole_subtree_ && !s.has_properties()
}

pub fn (s &InvalidationSet) has_properties() bool {
	return s.has_first_property_
}

pub fn (s &InvalidationSet) properties() ComputedInterpolationInvalidationProperties {
	mut result := []InvalidationProperty{cap: s.property_count()}
	if s.has_first_property_ {
		result << s.first_property_
	}
	if properties := s.additional_properties_ {
		for _, property in properties {
			result << property
		}
	}
	return result
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
	// Match the old map iteration's entry snapshot: flag callbacks can still
	// replace properties before iteration starts, while a property callback
	// replacing this set must not replace the remaining entries being visited.
	additional_properties := unsafe { s.additional_properties_ }
	if s.has_first_property_ && !callback(s.first_property_) {
		return
	}
	if properties := additional_properties {
		for _, property in properties {
			if !callback(property) {
				return
			}
		}
	}
}

pub fn (s &InvalidationSet) to_string() string {
	mut parts := []string{}
	if s.needs_invalidate_self_ {
		parts << InvalidationProperty.invalidate_self().to_string()
	}
	if s.needs_invalidate_whole_subtree_ {
		parts << InvalidationProperty.invalidate_whole_subtree().to_string()
	}
	if s.has_first_property_ {
		parts << s.first_property_.to_string()
	}
	if properties := s.additional_properties_ {
		for _, property in properties {
			parts << property.to_string()
		}
	}
	return parts.join(', ')
}

// --- StyleInvalidationData ---
pub enum ExcludePropertiesNestedInNotPseudoClass as u8 {
	no
	yes
}

pub enum InsideNthChildPseudoClass as u8 {
	no
	yes
}

pub enum SiblingInvalidationReach as u8 {
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
	return !p.invalidate_self && !p.invalidate_whole_subtree && p.descendant_rules.len == 0 && p.sibling_rules.len == 0
}

pub fn (mut p InvalidationPlan) include_all_from(other &InvalidationPlan) {
	if voidptr(&p) == voidptr(other) { return }
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

	for rule in other.descendant_rules {
		append_or_merge_descendant_invalidation_rule(mut p.descendant_rules, rule)
	}
	for rule in other.sibling_rules {
		append_or_merge_sibling_invalidation_rule(mut p.sibling_rules, rule)
	}
}

pub struct StyleInvalidationData {
pub mut:
	invalidation_plans                                     map[string]&InvalidationPlan
	invalidation_plan_properties                           map[string]InvalidationProperty
	ids_used_in_has_selectors                              map[string]bool
	class_names_used_in_has_selectors                      map[string]bool
	attribute_names_used_in_has_selectors                  map[string]bool
	tag_names_used_in_has_selectors                        map[string]bool
	pseudo_classes_used_in_has_selectors                   map[CSSPseudoClass]bool
	has_selectors_sensitive_to_featureless_subtree_changes bool
}

pub fn (s &StyleInvalidationData) plan_for_property(property InvalidationProperty) ?&InvalidationPlan {
	return s.invalidation_plans[property.key()] or { return none }
}

pub fn (mut s StyleInvalidationData) build_invalidation_sets_for_selector(selector Selector) {
	$if prealloc {
		build_owned_selector_invalidation(mut s, selector, false)
		return
	}
	_ = build_invalidation_sets_for_selector_impl(mut s, selector, .no, make_invalidate_self_invalidation())
}

pub fn (mut s StyleInvalidationData) build_invalidation_sets_for_scope_boundary_selector(selector Selector) {
	$if prealloc {
		build_owned_selector_invalidation(mut s, selector, true)
		return
	}
	_ = build_invalidation_sets_for_selector_impl(mut s, selector, .no, make_invalidate_whole_subtree_invalidation())
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

fn copy_invalidation_plan(plan &InvalidationPlan) &InvalidationPlan {
	return &InvalidationPlan{
		invalidate_self: plan.invalidate_self
		invalidate_whole_subtree: plan.invalidate_whole_subtree
		descendant_rules: plan.descendant_rules.clone()
		sibling_rules: plan.sibling_rules.clone()
	}
}

fn add_invalidation_plan_for_properties(mut style_invalidation_data StyleInvalidationData, invalidation_properties InvalidationSet, plan &InvalidationPlan) {
	// Flags are not property dependencies. Consume the stored canonical keys
	// directly, preserving first-property order without a snapshot or callback.
	if invalidation_properties.has_first_property_ {
		add_invalidation_plan_for_property(mut style_invalidation_data,
			invalidation_properties.first_property_key_, invalidation_properties.first_property_, plan)
	}
	if properties := invalidation_properties.additional_properties_ {
		for key, property in properties {
			add_invalidation_plan_for_property(mut style_invalidation_data, key, property, plan)
		}
	}
}

fn add_invalidation_plan_for_property(mut style_invalidation_data StyleInvalidationData, key string, invalidation_property InvalidationProperty, plan &InvalidationPlan) {
	if !should_register_invalidation_property(invalidation_property) {
		return
	}
	if key !in style_invalidation_data.invalidation_plans {
		style_invalidation_data.invalidation_plans[key] = InvalidationPlan.create()
		style_invalidation_data.invalidation_plan_properties[key] = invalidation_property
	}
	mut stored_invalidation := style_invalidation_data.invalidation_plans[key] or { return }
	stored_invalidation.include_all_from(plan)
}

pub enum SelectorCombinator as u8 {
	none_
	immediate_child
	descendant
	next_sibling
	subsequent_sibling
	column
}

pub enum InvalidationSimpleSelectorType as u8 {
	universal
	class
	id
	tag_name
	attribute
	pseudo_class
	pseudo_element
	other
}

pub struct InvalidationSimpleSelector {
pub mut:
	type_            InvalidationSimpleSelectorType
	name             string
	pseudo_class     CSSPseudoClass
	pseudo_element   PseudoElement
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
		.dir { .dir }
		.empty { .empty }
		.lang { .lang }
		.required { .required }
		.optional { .optional }
		.read_only { .read_only }
		.read_write { .read_write }
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
		.hover { .hover }
		.focus { .focus }
		.focus_visible { .focus_visible }
		.focus_within { .focus_within }
		.active { .active }
		.target { .target }
		.host { .host }
		.root { .root }
		.first_child { .first_child }
		.last_child { .last_child }
		.only_child { .only_child }
		.paused { .paused }
		.playing { .playing }
		.muted { .muted }
		.seeking { .seeking }
		.buffering { .buffering }
		.stalled { .stalled }
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

fn simple_selector_for_invalidation(simple_selector &SimpleSelector) InvalidationSimpleSelector {
	match simple_selector.type_ {
		.universal {
			return InvalidationSimpleSelector{
				type_: .universal
			}
		}
		.class {
			return InvalidationSimpleSelector{
				type_: .class
				name: simple_selector.name().name
			}
		}
		.id {
			return InvalidationSimpleSelector{
				type_: .id
				name: simple_selector.name().name
			}
		}
		.tag_name {
			return InvalidationSimpleSelector{
				type_: .tag_name
				name: simple_selector.qualified_name().name.lowercase_name
			}
		}
		.attribute {
			return InvalidationSimpleSelector{
				type_: .attribute
				name: simple_selector.attribute().qualified_name.name.lowercase_name
			}
		}
		.pseudo_class {
			return InvalidationSimpleSelector{
				type_: .pseudo_class
				name: selector_pseudo_class_name(simple_selector.pseudo_class().type_)
				pseudo_class: css_pseudo_class_from_selector_pseudo_class(simple_selector.pseudo_class().type_)
				nested_selectors: simple_selector.pseudo_class().argument_selector_list.selectors.clone()
			}
		}
		.pseudo_element {
			mut nested_selectors := []Selector{}
			if simple_selector.pseudo_element().type_ == .slotted {
				if argument_selector := simple_selector.pseudo_element().compound_selector {
					nested_selectors << argument_selector
				}
			}
			return InvalidationSimpleSelector{
				type_: .pseudo_element
				pseudo_element: simple_selector.pseudo_element().type_
				nested_selectors: nested_selectors
			}
		}

		// Boundary: nesting selectors and parser-invalid pieces
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
		for simple_index in 0 .. compound_selector.simple_selectors.len {
			simple := unsafe { &compound_selector.simple_selectors[simple_index] }
			simple_selectors << simple_selector_for_invalidation(simple)
		}
		if simple_selectors.len == 0 {
			continue
		}
		groups << InvalidationSimpleSelectorGroup{
			simple_selectors: simple_selectors
			combinator: selector_combinator_for_invalidation(compound_selector.combinator)
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
			if in_has && selector.pseudo_class in [.active, .enabled, .disabled, .defined, .placeholder_shown,
				.checked, .required, .optional, .read_only, .read_write, .link, .any_link, .local_link,
				.paused, .playing, .muted, .seeking, .buffering, .stalled] {
				style_invalidation_data.pseudo_classes_used_in_has_selectors[selector.pseudo_class] = true
			} else if in_has && selector.pseudo_class !in [.has, .is_, .where] {
				// The structural subtree filter can only compare concrete features and the pseudo-classes above.
				// Stateful and validation pseudo-classes must retain the conservative ancestor walk.
				style_invalidation_data.has_selectors_sensitive_to_featureless_subtree_changes = true
			}
			for child_selector in selector.nested_selectors {
				if selector.pseudo_class == .has
					&& selector_contains_featureless_subtree_sensitive_selector(child_selector) {
					style_invalidation_data.has_selectors_sensitive_to_featureless_subtree_changes = true
				}
				for group in selector_groups_for_invalidation(child_selector) {
					for simple_selector in group.simple_selectors {
						collect_properties_used_in_has(simple_selector, mut style_invalidation_data, in_has || selector.pseudo_class == .has)
					}
				}
			}
		}
		.pseudo_element {
			if selector.pseudo_element == .slotted {
				for child_selector in selector.nested_selectors {
					for group in selector_groups_for_invalidation(child_selector) {
						for simple_selector in group.simple_selectors {
							collect_properties_used_in_has(simple_selector, mut style_invalidation_data, in_has)
						}
					}
				}
			}
		}
		else {}
	}
}

fn simple_selector_is_featureless_subtree_sensitive(selector InvalidationSimpleSelector) bool {
	if selector.type_ == .universal {
		return true
	}
	if selector.type_ != .pseudo_class {
		return false
	}
	if selector.name in ['not', 'empty', 'first-child', 'last-child', 'only-child', 'first-of-type',
		'last-of-type', 'only-of-type', 'nth-child', 'nth-last-child', 'nth-of-type', 'nth-last-of-type'] {
		return true
	}
	if selector.pseudo_class in [.is_, .where] {
		for child_selector in selector.nested_selectors {
			if selector_contains_featureless_subtree_sensitive_selector(child_selector) {
				return true
			}
		}
	}
	return false
}

fn selector_contains_featureless_subtree_sensitive_selector(selector Selector) bool {
	for group in selector_groups_for_invalidation(selector) {
		for simple_selector in group.simple_selectors {
			if simple_selector_is_featureless_subtree_sensitive(simple_selector) {
				return true
			}
		}
	}
	return false
}

fn build_invalidation_set_for_simple_selectors(simple_selectors []InvalidationSimpleSelector, exclude_properties_nested_in_not_pseudo_class ExcludePropertiesNestedInNotPseudoClass, mut style_invalidation_data StyleInvalidationData, inside_nth_child_pseudo_class InsideNthChildPseudoClass, root_invalidation_plan &InvalidationPlan) InvalidationSet {
	mut invalidation_set := InvalidationSet{}
	for simple_selector in simple_selectors {
		build_invalidation_sets_for_simple_selector_impl(simple_selector, mut invalidation_set, exclude_properties_nested_in_not_pseudo_class, mut style_invalidation_data, inside_nth_child_pseudo_class, root_invalidation_plan)
	}
	return invalidation_set
}

fn simple_selector_group_matches_any(simple_selectors []InvalidationSimpleSelector) bool {
	return simple_selectors.len == 1 && simple_selectors[0].type_ == .universal
}

fn build_invalidation_for_combinator(combinator SelectorCombinator, righthand SelectorRighthand) &InvalidationPlan {
	if righthand.payload.invalidate_whole_subtree || (!righthand.subject_matches_any && righthand.subject_match_set.is_empty()) {
		return make_invalidate_whole_subtree_invalidation()
	}

	mut invalidation := InvalidationPlan.create()
	match combinator {
		.immediate_child, .descendant {
			invalidation.descendant_rules << DescendantInvalidationRule{
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload: righthand.payload
			}
		}
		.next_sibling {
			invalidation.sibling_rules << SiblingInvalidationRule{
				reach: .adjacent
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload: righthand.payload
			}
		}
		.subsequent_sibling {
			invalidation.sibling_rules << SiblingInvalidationRule{
				reach: .subsequent
				match_set: righthand.subject_match_set
				match_any: righthand.subject_matches_any
				payload: righthand.payload
			}
		}
		else {
			invalidation.invalidate_whole_subtree = true
		}
	}

	return invalidation
}

fn build_invalidation_sets_for_simple_selector_impl(selector InvalidationSimpleSelector, mut invalidation_set InvalidationSet, exclude_properties_nested_in_not_pseudo_class ExcludePropertiesNestedInNotPseudoClass, mut style_invalidation_data StyleInvalidationData, inside_nth_child_selector InsideNthChildPseudoClass, root_invalidation_plan &InvalidationPlan) {
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
				.enabled, .defined, .disabled, .empty, .placeholder_shown, .checked, .has {
					if pseudo_class == .has {
						for nested_selector in selector.nested_selectors {
							add_invalidation_sets_to_cover_scope_leakage_of_relative_selector_in_has_pseudo_class(nested_selector, mut style_invalidation_data)
						}
					}
					invalidation_set.set_needs_invalidate_pseudo_class(pseudo_class)
				}
				.link, .any_link, .local_link, .required, .optional, .read_only, .read_write, .hover, .focus,
				.focus_visible, .focus_within, .active, .target, .host, .root,
				.paused, .playing, .muted, .seeking, .buffering, .stalled {
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
				rightmost_set := build_invalidation_sets_for_selector_impl(mut style_invalidation_data, nested_selector, inside_nested, root_invalidation_plan)
				invalidation_set.include_all_from(rightmost_set)

				if selector_contains_pseudo_class(nested_selector, .has) {
					invalidation_set.set_needs_invalidate_pseudo_class(.has)
					if selector_groups_for_invalidation(nested_selector).len > 1 {
						mut has_only := InvalidationSet{}
						has_only.set_needs_invalidate_pseudo_class(.has)
						add_invalidation_plan_for_properties(mut style_invalidation_data, has_only, make_invalidate_whole_subtree_invalidation())
					}
				}
			}
		}
		.pseudo_element {
			if selector.pseudo_element == .slotted {
				for child_selector in selector.nested_selectors {
					for group in selector_groups_for_invalidation(child_selector) {
						for simple_selector in group.simple_selectors {
							build_invalidation_sets_for_simple_selector_impl(simple_selector, mut invalidation_set, exclude_properties_nested_in_not_pseudo_class, mut style_invalidation_data, inside_nth_child_selector, root_invalidation_plan)
						}
					}
				}
			}
		}
		else {}
	}
}

pub fn build_invalidation_sets_for_simple_selector(selector InvalidationSimpleSelector, mut invalidation_set InvalidationSet, exclude_properties_nested_in_not_pseudo_class ExcludePropertiesNestedInNotPseudoClass, mut style_invalidation_data StyleInvalidationData, inside_nth_child_selector InsideNthChildPseudoClass) {
	build_invalidation_sets_for_simple_selector_impl(selector, mut invalidation_set, exclude_properties_nested_in_not_pseudo_class, mut style_invalidation_data, inside_nth_child_selector, make_invalidate_self_invalidation())
}

fn selector_contains_pseudo_class(selector Selector, pseudo_class CSSPseudoClass) bool {
	// This predicate only reads membership. Traverse the retained typed selectors
	// directly instead of allocating invalidation groups and cloned argument lists.
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_class {
				if css_pseudo_class_from_selector_pseudo_class(simple_selector.pseudo_class().type_) == pseudo_class {
					return true
				}
				for nested_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					if selector_contains_pseudo_class(nested_selector, pseudo_class) {
						return true
					}
				}
			} else if simple_selector.type_ == .pseudo_element
				&& simple_selector.pseudo_element().type_ == .slotted {
				if argument_selector := simple_selector.pseudo_element().compound_selector {
					if selector_contains_pseudo_class(argument_selector, pseudo_class) {
						return true
					}
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

		invalidation_set := build_invalidation_set_for_simple_selectors(group.simple_selectors, .no, mut style_invalidation_data, .no, make_invalidate_self_invalidation())
		add_invalidation_plan_for_properties(mut style_invalidation_data, invalidation_set, make_invalidate_whole_subtree_invalidation())
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
					add_whole_subtree_invalidation_for_non_subject_complex_selector_properties(nested_selector, mut style_invalidation_data)
				}
			}
		}
	}
}

fn build_invalidation_sets_for_selector_impl(mut style_invalidation_data StyleInvalidationData, selector Selector, inside_nth_child_pseudo_class InsideNthChildPseudoClass, root_invalidation_plan &InvalidationPlan) InvalidationSet {
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

		invalidation_properties := build_invalidation_set_for_simple_selectors(group.simple_selectors, .no, mut style_invalidation_data, inside_nth_child_pseudo_class, root_invalidation_plan)
		mut subject_match_set := build_invalidation_set_for_simple_selectors(group.simple_selectors, .yes, mut style_invalidation_data, inside_nth_child_pseudo_class, root_invalidation_plan)
		subject_matches_any := subject_match_set.is_empty() && simple_selector_group_matches_any(group.simple_selectors)

		if is_rightmost {
			mut root_plan := copy_invalidation_plan(root_invalidation_plan)
			if inside_nth_child_pseudo_class == .yes {
				// When invalidation property is nested in nth-child selector like
				// p:nth-child(even of #t1, #t2, #t3), we need to make sure all affected siblings are invalidated.
				root_plan.invalidate_whole_subtree = true
			}
			add_invalidation_plan_for_properties(mut style_invalidation_data, invalidation_properties, root_plan)
			invalidation_set_for_rightmost_selector = subject_match_set
			selector_righthand = SelectorRighthand{
				subject_match_set: subject_match_set
				subject_matches_any: subject_matches_any
				payload: root_plan
			}
		} else {
			righthand := selector_righthand or { break }
			mut plan := build_invalidation_for_combinator(previous_compound_combinator, righthand)
			add_invalidation_plan_for_properties(mut style_invalidation_data, invalidation_properties, plan)
			selector_righthand = SelectorRighthand{
				subject_match_set: subject_match_set
				subject_matches_any: subject_matches_any
				payload: plan
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
	ancestor_visits []AncestorFilterVisit
	ancestor_hashes []u32
	record_ancestor_hashes bool
	ancestor_hash_cache_ &AncestorHashCache = unsafe { nil }
	ancestor_hash_cache_document_ dom.UniqueNodeID
}

pub fn CountingBloomFilter.new() CountingBloomFilter {
	return CountingBloomFilter{
		buckets: []u8{len: counting_bloom_filter_bucket_count}
	}
}

pub fn (mut f CountingBloomFilter) clear() {
	f.ancestor_visits.clear()
	f.ancestor_hashes.clear()
	f.record_ancestor_hashes = false
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

@[heap]
pub struct MatchingRule {
pub mut:
	rule                         ?&CSSRule
	sheet                        ?&CSSStyleSheet
	default_namespace            ?string
	selector                     Selector
	style_sheet_index            uint
	rule_index                   uint
	specificity                  u32
	cascade_origin               CascadeOrigin
	contains_pseudo_element      bool
	pseudo_element               ?PseudoElement
	slotted                      bool
	contains_part_pseudo_element bool
	scope_rule                   ?&CSSRule
	container_rule               ?&CSSRule
}

// The rule cache owns MatchingRule entries independently of the style scope
// using it. Keep the effective shadow root and per-element @scope result on
// this transient wrapper instead.
pub struct ScopedMatchingRule {
pub mut:
	rule                &MatchingRule = unsafe { nil }
	shadow_root         ?&dom.ShadowRoot
	resolved_scope_root ?&dom.Element
	scope_proximity     int = int(0x3fffffff)
}

pub struct LayerMatchingRules {
pub mut:
	qualified_layer_name string
	rules                []ScopedMatchingRule
}

pub struct MatchingRuleSet {
pub mut:
	user_agent_rules []ScopedMatchingRule
	user_rules       []ScopedMatchingRule
	author_rules     []LayerMatchingRules
}

pub enum ComputeStyleMode as u8 {
	normal
	create_pseudo_element_style_if_needed
}

@[heap]
pub struct PendingHasInvalidationMutationFeatures {
pub mut:
	is_conservative                  bool
	may_affect_sibling_relationships bool
	may_affect_pseudo_classes        bool
	tag_names                        map[string]bool
	ids                              map[string]bool
	class_names                      map[string]bool
	attribute_names                  map[string]bool
	pseudo_classes                   map[CSSPseudoClass]bool
}

pub fn PendingHasInvalidationMutationFeatures.new() &PendingHasInvalidationMutationFeatures {
	return &PendingHasInvalidationMutationFeatures{
		tag_names: map[string]bool{}
		ids: map[string]bool{}
		class_names: map[string]bool{}
		attribute_names: map[string]bool{}
		pseudo_classes: map[CSSPseudoClass]bool{}
	}
}

@[heap]
pub struct StyleScope {
pub mut:
	rule_cache                                                  ?&StyleCache
	qualified_layer_names_in_order                              []string
	selector_insights                                           ?&SelectorInsights
	pseudo_class_rule_cache                                     map[PseudoClass]&RuleCache
	style_invalidation_data                                     ?&StyleInvalidationData
	author_rule_cache                                           ?&RuleCaches
	user_rule_cache                                             ?&RuleCaches
	user_agent_rule_cache                                       ?&RuleCaches
	user_style_sheet                                            ?&CSSStyleSheet
	user_style_source                                           ?string
	pending_nodes_for_style_invalidation_due_to_presence_of_has []&dom.Node
	pending_has_invalidation_features                           map[i64]&PendingHasInvalidationMutationFeatures
	node                                                        ?&dom.Node
	// Sheets installed directly by CSS-aware callers into a shadow-root scope.
	// Document scopes keep theirs in the document's author-sheet holder.
	author_style_sheets []&CSSStyleSheet
	// The list of document or shadow root CSS style sheets (StyleScope's
	// m_style_sheets upstream), created on first use.
	style_sheets                        ?&StyleSheetList
	registered_counter_styles           map[string]CounterStyle
	needs_counter_style_cache_update    bool = true
	is_doing_counter_style_cache_update bool
	has_size_container_queries          bool
mut:
	user_agent_only_shadow_cache_ &UserAgentOnlyShadowStyleCache = unsafe { nil }
	adopted_user_agent_only_shadow_cache_ &UserAgentOnlyShadowStyleCache = unsafe { nil }
	rule_cache_font_policy_ dom.FontRenderingPolicy
}

// A complete set of selector and cascade caches that can be shared by style
// scopes whose only author sheet is the same constructed stylesheet.
@[heap]
pub struct StyleCache {
pub mut:
	function_rules_by_name         map[string][]CachedFunctionDefinition
	qualified_layer_names_in_order []string
	selector_insights              &SelectorInsights = unsafe { nil }
	pseudo_class_rule_cache        map[PseudoClass]&RuleCache
	style_invalidation_data        &StyleInvalidationData = unsafe { nil }
	author_rule_cache              &RuleCaches = unsafe { nil }
	user_rule_cache                &RuleCaches = unsafe { nil }
	user_agent_rule_cache          &RuleCaches = unsafe { nil }
	has_size_container_queries     bool
}

pub struct LogicalAliasMappingContext {
pub mut:
	writing_mode WritingMode = .horizontal_tb
	direction    Direction = .ltr
}

pub struct RuleCache {
pub mut:
	fold_id_and_class_name_case   bool
	rules_by_id                  map[string][]&MatchingRule
	rules_by_class               map[string][]&MatchingRule
	rules_by_tag_name            map[string][]&MatchingRule
	rules_by_attribute_name      map[string][]&MatchingRule
	rules_by_pseudo_element      map[PseudoElement][]&MatchingRule
	root_rules                   []&MatchingRule
	slotted_rules                []&MatchingRule
	part_rules                   []&MatchingRule
	other_rules                  []&MatchingRule
	disjunctive_subject_masks_ &DisjunctiveSubjectMasks = unsafe { nil }
	disjunctive_subject_masks_trusted_ bool
	rules_by_animation_keyframes map[string]&KeyFrameSet
	pseudo_subject_index_ready_ bool
	pseudo_subject_rules_ map[PseudoElement]&RuleCache
}

@[heap]
pub struct StyleComputer {
pub mut:
	scroll_state_query_containers_ map[voidptr]&ScrollStateQueryContainer
	relative_scroll_query_directions_ map[u64]u8
	position_try_override_ ?PositionTryStyleOverride
	document_                                            &dom.Document = unsafe { nil }
	computed_property_page_interner_ &ComputedPropertyPageInterner = unsafe { nil }
	device_layout_property_pages_ &DeviceLayoutPropertyPages = unsafe { nil }
	computed_property_page_arena_ &platform.Arena = unsafe { nil }
	computed_property_page_batch_depth_ int
	computed_property_page_recycling_ &ComputedPropertyPageRecycling = unsafe { nil }
	default_font_metrics                                 LengthFontMetrics = LengthFontMetrics.default()
	root_element_font_metrics                            LengthFontMetrics = LengthFontMetrics.default()
	root_element_font_metrics_depend_on_viewport_metrics bool
	cached_font_computation_context                      ?ComputationContext
	cached_line_height_computation_context               ?ComputationContext
	cached_generic_computation_context                   ?ComputationContext
	viewport_rect_                                       CSSPixelRect
	ancestor_filter_                                     CountingBloomFilter = CountingBloomFilter.new()
	has_result_cache_                                    &HasResultCache = &HasResultCache{}
	deferred_hidden_styles_ map[u64]bool
	size_query_matches_ map[u64]RecordedSizeQueryMatches
	materializing_hidden_styles_ bool
	matching_rule_candidates_                            &MatchingRuleCandidateScratch = unsafe { nil }
	matching_rule_sets_ &MatchingRuleSetWorkspacePool = unsafe { nil }
	initial_layout_snapshots_ &InitialLayoutSnapshotPool = unsafe { nil }
	cascade_scratch_ &CascadeScratchPool = unsafe { nil }
	css_animation_storage_                               &CSSAnimationStorage = unsafe { nil }
	css_transition_storage_                              &CSSTransitionStorage = unsafe { nil }
	document_timeline_                                   &AnimationTimeline = unsafe { nil }
	font_computer_                                       &FontComputer = unsafe { nil }
	font_face_set_                                       &FontFaceSet = unsafe { nil }
	animation_time_ms_                                   f64
	animation_clock_demand_filter_                       AnimationClockDemandFilter = unsafe { nil }
	animation_clock_reader_                              AnimationClockReader = unsafe { nil }
	transition_generation_                               int
	// Arenas for animation samples (css/animation_samples.v), used while the
	// animated-style update samples targets.
	animation_samples_         &AnimationSampleStorage = unsafe { nil }
	animation_sample_arenas_disabled_ bool
	sampling_animation_frame_  bool
	animation_layout_style_    &ComputedProperties = unsafe { nil }
	// Only the exact target being installed may reuse its non-compositor slots.
	// Arena rotation always rebuilds them before old samples can be retired.
	animation_layout_compositor_only_ bool
	longhand_reuse_cache_ &ComputedLonghandReuseCache = unsafe { nil }
	simple_var_properties_ &SimpleVarPropertyCache = unsafe { nil }
	quirks_body_identity_ u64
	quirks_body_used_color_ ?Color
}

pub fn StyleComputer.new(document &dom.Document) &StyleComputer {
	initial_timeline_time := document.last_animation_frame_timestamp_value() or { 0.0 }
	mut font_computer := FontComputer.create_for_document(document)
	mut owner := unsafe { &dom.Document(document) }
	mut fonts := if existing := owner.existing_font_face_set() {
		unsafe { &FontFaceSet(existing.font_face_set_record()) }
	} else {
		FontFaceSet.create_for_font_computer(font_computer)
	}
	if existing := fonts.font_computer_ {
		font_computer = existing
	}
	fonts.associate_font_computer(font_computer)
	owner.set_font_face_set(fonts)
	return &StyleComputer{
		document_: unsafe { document }
		viewport_rect_: css_pixel_rect_from_dom_rect(document.viewport_rect())
		css_animation_storage_: &CSSAnimationStorage{}
		css_transition_storage_: &CSSTransitionStorage{}
		document_timeline_: AnimationTimeline.document_timeline(document, 0.0, initial_timeline_time)
		font_computer_: font_computer
		font_face_set_: fonts
	}
}

pub fn (computer &StyleComputer) font_computer() &FontComputer {
	return computer.font_computer_
}

struct DOMLonghandExpansionCallback {
	@[required]
	callback fn (PropertyID, &dom.StyleValue)
}

fn invoke_legacy_dom_longhand(context voidptr, property_id PropertyID, value &dom.StyleValue) {
	state := unsafe { &DOMLonghandExpansionCallback(context) }
	state.callback(property_id, value)
}

struct TypedDOMLonghandExpansionContext {
	context voidptr
	system_font string
	@[required]
	callback fn (voidptr, PropertyID, &dom.StyleValue)
}

fn bridge_typed_dom_longhand(context voidptr, property_id PropertyID, value StyleValue) {
	state := unsafe { &TypedDOMLonghandExpansionContext(context) }
	resolved := dom_style_value_from_value_logic(value)
	state.callback(state.context, property_id, if state.system_font != '' {
		&dom.StyleValue{ ...resolved, system_font: state.system_font }
	} else { resolved })
}

pub fn StyleComputer.for_each_property_expanding_shorthands(property_id PropertyID, value &dom.StyleValue, set_longhand_property fn (PropertyID, &dom.StyleValue)) {
	state := DOMLonghandExpansionCallback{callback: set_longhand_property}
	StyleComputer.for_each_property_expanding_shorthands_with_context(property_id, value, voidptr(&state), invoke_legacy_dom_longhand)
}

// Synchronous expansion keeps each borrowed receiver in the caller's graph.
pub fn StyleComputer.for_each_property_expanding_shorthands_with_context(property_id PropertyID, value &dom.StyleValue, context voidptr, set_longhand_property fn (voidptr, PropertyID, &dom.StyleValue)) {
	if property_is_shorthand(property_id) {
		if typed_value := style_value_logic_from_dom(property_id, value) {
			state := TypedDOMLonghandExpansionContext{context: context, callback: set_longhand_property, system_font: if typed_value is ShorthandStyleValue { typed_value.system_font_ } else { '' }}
			for_each_typed_property_expanding_shorthands_with_context(property_id, typed_value, voidptr(&state), bridge_typed_dom_longhand)
			return
		}
	}
	set_longhand_property(context, property_id, value)
}

pub fn StyleComputer.get_non_animated_inherit_value(property_id PropertyID, abstract_element dom.AbstractElement) &dom.StyleValue {
	return non_animated_inherit_value_from_parent(property_id, parent_computed_properties(abstract_element))
}

pub struct AnimatedInheritValue {
pub mut:
	value                   &dom.StyleValue = unsafe { nil }
	is_result_of_transition AnimatedPropertyResultOfTransition
}

pub fn StyleComputer.get_animated_inherit_value(property_id PropertyID, abstract_element dom.AbstractElement) ?AnimatedInheritValue {
	// This lookup runs once for every inherited property on every descendant.
	// The public accessor returns an owning copy for API callers; style
	// computation only needs one entry and must not clone the entire animation
	// map (usually empty) dozens of times per element.
	return animated_inherit_value_from_parent(property_id, parent_computed_properties(abstract_element))
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
	s.has_result_cache_.results.clear()
	s.has_result_cache_.attempted_pseudo_classes.clear()
}


fn (mut filter CountingBloomFilter) update_element_hash(hash u32, adding bool) {
	if adding {
		if filter.record_ancestor_hashes { filter.ancestor_hashes << hash }
		filter.increment(hash)
	} else {
		filter.decrement(hash)
	}
}

pub fn (mut s StyleComputer) push_ancestor(element &dom.Element) {
	s.push_ancestor_with_saved_hashes(element)
}

pub fn (mut s StyleComputer) pop_ancestor(element &dom.Element) {
	s.pop_ancestor_with_saved_hashes(element)
}

pub fn (s &StyleComputer) create_document_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	style.viewport_rect_ = s.viewport_rect_
	style.root_font_size_px_ = s.root_element_font_metrics.font_size.to_double()
	style.root_line_height_px_ = s.root_element_font_metrics.line_height.to_double()
	style.root_font_metrics_depend_on_viewport_metrics_ = s.root_element_font_metrics_depend_on_viewport_metrics
	for property_id in computed_interpolation_longhand_property_ids() {
		style.set_property_without_modifying_flags(property_id, computed_interpolation_property_initial_value(property_id))
	}
	s.compute_property_values(mut style, none)
	style.set_property_without_modifying_flags(.width, dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(s.viewport_rect_.width_value())))))
	style.set_property_without_modifying_flags(.height, dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(s.viewport_rect_.height_value())))))
	style.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block)))))
	s.clear_computation_context_caches()
	return style
}

pub fn (s &StyleComputer) compute_style(abstract_element dom.AbstractElement) &ComputedProperties {
	load_instruction_stage := processmetrics.begin_instruction_stage('style_computation')
	defer { load_instruction_stage.finish() }
	// StyleComputer::compute_style (StyleComputer.cpp:1780): resolve the element's style scope and run the
	// normal-mode style computation. In .normal mode compute_style_impl always yields a value; fall back to
	// an empty ComputedProperties defensively (upstream dereferences the returned pointer).
	scope := css_style_scope_for(abstract_element)
	return s.compute_style_impl(abstract_element, .normal, none, scope) or {
		ComputedProperties.new()
	}
}

pub fn (s &StyleComputer) compute_style_tracking_custom_property_changes(abstract_element dom.AbstractElement, did_change_custom_properties &bool) &ComputedProperties {
	scope := css_style_scope_for(abstract_element)
	return s.compute_style_impl(abstract_element, .normal, did_change_custom_properties, scope) or {
		ComputedProperties.new()
	}
}

pub fn (mut s StyleComputer) compute_style_with_seeded_ancestors(abstract_element dom.AbstractElement) &ComputedProperties {
	s.materialize_hidden_styles_for_query(abstract_element.element())
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
	scope := css_style_scope_for(abstract_element)
	return s.compute_style_impl(abstract_element, .create_pseudo_element_style_if_needed, none, scope)
}

pub fn (s &StyleComputer) compute_pseudo_element_style_if_needed_tracking_custom_property_changes(abstract_element dom.AbstractElement, did_change_custom_properties &bool) ?&ComputedProperties {
	scope := css_style_scope_for(abstract_element)
	return s.compute_style_impl(abstract_element, .create_pseudo_element_style_if_needed, did_change_custom_properties, scope)
}

pub fn (s &StyleComputer) collect_matching_rules(abstract_element dom.AbstractElement, origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string) []ScopedMatchingRule {
	return style_computer_collect_matching_rules_without_scope_boundary(s, abstract_element, origin, mut attempted_pseudo_class_matches, qualified_layer_name)
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

pub enum AbsoluteSize as u8 {
	xx_small
	x_small
	small
	medium
	large
	x_large
	xx_large
	xxx_large
}

pub enum RelativeSize as u8 {
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

fn is_monospace(value &dom.StyleValue) bool {
	style_value := typed_style_value_logic_from_dom(value) or { return false }
	if style_value !is StyleValueList {
		return false
	}

	value_list := style_value as StyleValueList
	values := value_list.values()
	return values.len == 1 && values[0].to_keyword() == .monospace
}

pub fn (s &StyleComputer) recascade_font_size_if_needed(abstract_element dom.AbstractElement, mut cascaded_properties CascadedProperties, depends_on_viewport_metrics &bool) ?&dom.StyleValue {
	font_family := cascaded_properties.property(.font_family) or { return none }
	if !is_monospace(font_family) {
		return none
	}

	mut ancestors := []dom.AbstractElement{}
	mut maybe_ancestor := abstract_element.element_to_inherit_style_from()
	for {
		ancestor := maybe_ancestor or { break }
		ancestors << ancestor
		maybe_ancestor = ancestor.element_to_inherit_style_from()
	}

	default_monospace_font_size := CSSPixels.nearest_value_for(13)
	mut current_size := default_monospace_font_size
	mut current_size_depends_on_viewport_metrics := false
	for index := ancestors.len - 1; index >= 0; index-- {
		ancestor := ancestors[index]
		ancestor_dom_computed := ancestor.computed_properties() or { continue }
		ancestor_computed := computed_properties_from_dom(ancestor_dom_computed) or { continue }
		font_size_value := ancestor_computed.raw_cascaded_font_size() or { continue }
		keyword := computed_interpolation_style_value_keyword(font_size_value) or {
			Keyword.invalid
		}
		if keyword in [.initial, .unset] {
			current_size = default_monospace_font_size
			current_size_depends_on_viewport_metrics = false
			continue
		}
		if keyword == .inherit || keyword == .math {
			continue
		}
		if absolute_size := computed_interpolation_keyword_to_absolute_size(keyword) {
			current_size = absolute_size_mapping_for_document(absolute_size, default_monospace_font_size, abstract_element.document())
			current_size_depends_on_viewport_metrics = false
			continue
		}
		if relative_size := computed_interpolation_keyword_to_relative_size(keyword) {
			current_size = StyleComputer.relative_size_mapping(relative_size, current_size)
			continue
		}
		if percentage := computed_interpolation_percentage_from_dom_style_value(font_size_value) {
			current_size = current_size.times_float(percentage.as_fraction())
			continue
		}
		length := computed_interpolation_length_from_dom_style_value(font_size_value) or {
			continue
		}
		mut font_metrics := computed_interpolation_font_metrics_for_size(current_size)
		mut inherited_font_metrics_depend_on_viewport_metrics := false
		if parent := ancestor.element_to_inherit_style_from() {
			if dom_computed := parent.computed_properties() {
				if computed := computed_properties_from_dom(dom_computed) {
					font_metrics.line_height = computed.line_height()
					inherited_font_metrics_depend_on_viewport_metrics = computed.font_metrics_depend_on_viewport_metrics()
				}
			}
		}
		mut did_resolve_viewport_relative_length := false
		mut resolution_context := LengthResolutionContext{
			viewport_rect: s.viewport_rect_
			font_metrics: font_metrics
			root_font_metrics: s.root_element_font_metrics
			font_metrics_depend_on_viewport_metrics: current_size_depends_on_viewport_metrics
				|| inherited_font_metrics_depend_on_viewport_metrics
			root_font_metrics_depend_on_viewport_metrics: s.root_element_font_metrics_depend_on_viewport_metrics
			subject_inline_axis_is_horizontal: ancestor_computed.writing_mode() == .horizontal_tb
		}
		resolution_context.set_did_resolve_viewport_relative_length(&did_resolve_viewport_relative_length)
		current_size = length.to_px(resolution_context)
		current_size_depends_on_viewport_metrics = did_resolve_viewport_relative_length
	}

	unsafe {
		*depends_on_viewport_metrics = current_size_depends_on_viewport_metrics
	}
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(current_size))))
}

fn compute_text_align(mut properties ComputedProperties, abstract_element dom.AbstractElement) {
	text_align_value := properties.property(.text_align, .no) or { return }
	text_align_keyword := computed_interpolation_style_value_keyword(text_align_value) or { return }
	if text_align_keyword == .match_parent {
		if parent := abstract_element.element_to_inherit_style_from() {
			if dom_computed := parent.computed_properties() {
				if parent_computed := computed_properties_from_dom(dom_computed) {
					parent_value := parent_computed.property(.text_align, .no) or { return }
					parent_keyword := computed_interpolation_style_value_keyword(parent_value) or {
						return
					}
					resolved := match parent_keyword {
						.start {
							if parent_computed.direction() == .ltr {
								Keyword.left
							} else {
								Keyword.right
							}
						}
						.end_ {
							if parent_computed.direction() == .ltr {
								Keyword.right
							} else {
								Keyword.left
							}
						}
						else {
							parent_keyword
						}
					}
					properties.set_property_without_modifying_flags(.text_align, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(resolved))))
					return
				}
			}
		}
		properties.set_property_without_modifying_flags(.text_align, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.start))))
		return
	}

	if text_align_keyword == .libweb_inherit_or_center && abstract_element.element().local_name() == 'th' {
		if parent := abstract_element.element_to_inherit_style_from() {
			if dom_computed := parent.computed_properties() {
				if parent_computed := computed_properties_from_dom(dom_computed) {
					if parent_value := parent_computed.property(.text_align, .no) {
						parent_keyword := computed_interpolation_style_value_keyword(parent_value) or {
							Keyword.start
						}
						if parent_keyword != .start {
							properties.set_property(.text_align, parent_value, .yes, .no)
							return
						}
					}
				}
			}
		}
		properties.set_property(.text_align, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.center))), .no, .no)
	}
}

pub fn (mut s StyleComputer) set_viewport_rect(viewport_rect CSSPixelRect) {
	s.viewport_rect_ = viewport_rect
}

fn (s &StyleComputer) compute_keyframe_values_with_id_map(abstract_element dom.AbstractElement, keyframe ResolvedKeyFrame, computed_properties &ComputedProperties) map[PropertyID]&dom.StyleValue {
	mut result := map[PropertyID]&dom.StyleValue{}
	// Native recascades retain resolved values, but use the lookup tables only
	// synchronously. Animation-frame samples already have their bounded owner.
	retire_lookup := !s.sampling_animation_frame_ && s.document_.native_storage() != unsafe { nil }
		&& voidptr(platform.current_retained_arena()) == voidptr(s.document_.native_storage())
	workspace := if retire_lookup { platform.begin_thread_scratch('keyframe property lookup') } else { platform.ThreadScratchScope{} }
	defer { workspace.finish() }
	mut property_ids := map[PropertyID]bool{}
	for property_id, _ in keyframe.properties {
		property_ids[property_id] = true
	}
	for property_id, _ in keyframe.use_initial_properties {
		property_ids[property_id] = true
	}

	mapping_context := LogicalAliasMappingContext{
		writing_mode: computed_properties.writing_mode()
		direction: computed_properties.direction()
	}
	mut specified_values := map[PropertyID]&dom.StyleValue{}
	for property_id, _ in property_ids {
		mut value := keyframe.properties[property_id] or {
			computed_properties.property(property_id, .no) or { continue }
		}
		mut owned := if retire_lookup { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		if typed := typed_style_value_logic_from_dom(value) {
			if typed is UnresolvedStyleValue && typed.substitution_functions_presence.has_any() {
				value = resolve_unresolved_style_value_for_property(abstract_element, property_id, typed)
			}
		}
		value = with_keyword_values_resolved_boundary(abstract_element.element(), property_id, value)
		owned.finish()
		physical_property_id := map_logical_alias_to_physical_property(property_id, mapping_context)
		specified_values[physical_property_id] = value
	}

	// The specified overlay lives for this synchronous computation only. Borrow
	// it once instead of retaining a captured map and base style per property.
	property_source := ComputedPropertyValueSource{
		properties: computed_properties
		specified_values: &specified_values
	}
	for property_id, value in specified_values {
		mut owned := if retire_lookup { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		mut computation_context := s.get_computation_context_for_property(property_id, computed_properties, abstract_element)
		computation_context.reset_viewport_metric_dependency_tracking()
		computed_value := compute_value_of_property_from_source(property_id, value,
			property_source, computation_context, 1.0)
		if computation_context.depends_on_viewport_metrics() {
			mut mutable_properties := unsafe { &ComputedProperties(computed_properties) }
			mutable_properties.set_depends_on_viewport_metrics()
			if property_affects_font_metrics(property_id) {
				mutable_properties.set_font_metrics_depend_on_viewport_metrics()
			}
		}
		result[property_id] = computed_value
		owned.finish()
	}
	return result
}

fn resolve_keyframe_easing(style_value &dom.StyleValue, abstract_element dom.AbstractElement) ?EasingFunction {
	mut resolved := unsafe { style_value }
	typed := style_value_logic_from_dom(.animation_timing_function, resolved) or { return none }
	if typed is UnresolvedStyleValue {
		resolved = resolve_unresolved_style_value_for_property(abstract_element, .animation_timing_function, typed)
	}
	mut resolved_typed := style_value_logic_from_dom(.animation_timing_function, resolved) or {
		return none
	}
	if resolved_typed is GuaranteedInvalidStyleValue {
		return none
	}
	if resolved_typed is StyleValueList {
		if resolved_typed.size() == 0 {
			return none
		}
		resolved_typed = resolved_typed.value_at(0, false)
	}
	if resolved_typed is EasingStyleValue || resolved_typed is KeywordStyleValue {
		return EasingFunction.from_css_style_value(resolved_typed)
	}
	return none
}

fn custom_property_animation_base(abstract_element dom.AbstractElement) ?&dom.CSSCustomPropertyData_ {
	data := abstract_element.custom_property_data() or { return none }
	if data.is_animation_overlay() {
		return data.parent
	}
	return data
}

fn custom_property_animation_underlying_value(abstract_element dom.AbstractElement, name string) &dom.StyleValue {
	if base := custom_property_animation_base(abstract_element) {
		if property := base.get_property(name) {
			return dom_style_value_from_custom_property_bridge(property.value) or {
				parse_custom_property_value(property.value.css_text)
			}
		}
	}
	return custom_property_initial_style_value(abstract_element.document(), name)
}

fn (s &StyleComputer) compute_animated_custom_property_value(abstract_element dom.AbstractElement, computed_properties &ComputedProperties, name string, specified_value &dom.StyleValue) &dom.StyleValue {
	registration := abstract_element.document().get_registered_custom_property(name)
	mut value := unsafe { specified_value }
	if typed := typed_style_value_logic_from_dom(value) {
		keyword := typed.to_keyword()
		if keyword == .initial || (keyword == .unset && if registered := registration {
			!registered.inherits
		} else {
			false
		}) {
			value = custom_property_initial_style_value(abstract_element.document(), name)
		} else if keyword in [.inherit, .unset] {
			if parent := abstract_element.element_to_inherit_style_from() {
				value = StyleComputer.compute_value_of_custom_property(parent, name)
			} else {
				value = custom_property_initial_style_value(abstract_element.document(), name)
			}
		} else if typed is UnresolvedStyleValue && typed.substitution_functions_presence.has_any() {
			mut guarded_contexts := GuardedSubstitutionContexts{}
			result := substitute_arbitrary_substitution_functions_for_element(abstract_element,
				mut guarded_contexts, typed.tokens, SubstitutionContext{
				dependency_type: .property
				first: name
			})
			if contains_guaranteed_invalid_value(result) {
				value = dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
			} else {
				value = dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create_with_presence(result,
					SubstitutionFunctionsPresence{}, none)))
			}
		}
	}

	registered := registration or { return value }
	syntax := style_query_registration_syntax(registered) or { return value }
	if syntax.type() == .universal {
		return value
	}
	mut typed_value := typed_style_value_logic_from_dom(value) or { return value }
	if typed_value is UnresolvedStyleValue {
		typed_value = parse_with_a_syntax(typed_value.tokenize(), syntax)
	}
	if typed_value is GuaranteedInvalidStyleValue {
		return dom_style_value_from_value_logic(typed_value)
	}
	computation_context := s.get_computation_context_for_property(.width, computed_properties,
		abstract_element)
	colors := ColorResolutionContext.for_computed_properties(computed_properties, abstract_element.document())
	base := value.base_url or { abstract_element.document().base_url().to_string() }
	with_urls := resolve_registered_property_urls(typed_value, base)
	return dom_style_value_from_value_logic(compute_registered_typed_value(with_urls, computation_context, colors))
}

fn interpolate_animated_custom_property(document &dom.Document, name string, from &dom.StyleValue, to &dom.StyleValue, delta f64) &dom.StyleValue {
	registration := document.get_registered_custom_property(name) or {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	syntax := style_query_registration_syntax(registration) or {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	if syntax.type() == .universal {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	from_typed := typed_style_value_logic_from_dom(from) or {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	to_typed := typed_style_value_logic_from_dom(to) or {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	interpolation_context := InterpolationCalculationContext{
		property: .width
	}
	interpolated := interpolate_style_value(interpolation_context, from_typed, to_typed,
		delta, .yes) or {
		return interpolate_discrete(from, to, delta, .yes) or { unsafe { from } }
	}
	return dom_style_value_from_value_logic(interpolated)
}

fn composite_animated_custom_property(underlying &dom.StyleValue, animated &dom.StyleValue, operation CompositeOperation) ?&dom.StyleValue {
	if operation == .replace {
		return none
	}
	underlying_typed := typed_style_value_logic_from_dom(underlying) or { return none }
	animated_typed := typed_style_value_logic_from_dom(animated) or { return none }
	composited := composite_style_value(.width, underlying_typed, animated_typed, operation) or {
		return none
	}
	return dom_style_value_from_value_logic(composited)
}

fn accumulate_custom_property_iterations(value &dom.StyleValue, final_value &dom.StyleValue, count f64) &dom.StyleValue {
	return accumulate_animation_iterations(none, value, final_value, count)
}

pub fn (s &StyleComputer) collect_animation_into(abstract_element dom.AbstractElement, animation voidptr, mut computed_properties ComputedProperties) {
	if animation == unsafe { nil } {
		return
	}
	effect := unsafe { &KeyframeEffect(animation) }
	output_progress := effect.output_progress or { return }
	key_frame_set := effect.key_frame_set or { return }
	// The element's interpolate-size governs keyword size interpolation.
	previous_interpolation_style := enter_calc_size_interpolation_style(&computed_properties)
	defer {
		leave_calc_size_interpolation_style(previous_interpolation_style)
	}
	if key_frame_set.keyframes_by_key.len < 2 {
		return
	}

	// During an animation frame, keyframe values and the interpolated results
	// are samples (animation_samples.v); installing them updates the target's
	// retained style, which stays in ordinary storage.
	mut samples := if s.sampling_animation_frame_ { s.animation_samples_ } else { unsafe { &AnimationSampleStorage(nil) } }
	samples.enter()
	defer {
		samples.leave()
		s.clear_computation_context_caches()
	}
	mut keys := key_frame_set.keyframes_by_key.keys()
	keys.sort()
	progress := math.round(output_progress * 100.0 * animation_key_frame_key_scale_factor)
	mut start_index := 0
	if output_progress > 0 {
		for i, key in keys {
			if f64(key) <= progress {
				start_index = i
			} else {
				break
			}
		}
		if start_index >= keys.len - 1 {
			start_index = keys.len - 2
		}
	}
	start_key := keys[start_index]
	end_key := keys[start_index + 1]
	start_keyframe := key_frame_set.keyframes_by_key[start_key] or { return }
	end_keyframe := key_frame_set.keyframes_by_key[end_key] or { return }
	mut interval_progress := (progress - f64(start_key)) / f64(end_key - start_key)
	mut keyframe_easing := effect.default_easing
	if easing := start_keyframe.easing {
		match easing {
			EasingFunction { keyframe_easing = easing }
			UnresolvedKeyframeEasing {
				if resolved_easing := resolve_keyframe_easing(easing.value, abstract_element) {
					keyframe_easing = resolved_easing
				}
			}
		}
	}
	interval_progress = keyframe_easing.evaluate_at(interval_progress, false)

	start_values := s.compute_keyframe_values(abstract_element, start_keyframe, computed_properties)
	end_values := s.compute_keyframe_values(abstract_element, end_keyframe, computed_properties)
	mut final_values := map[PropertyID]&dom.StyleValue{}
	if effect.iteration_composite_accumulate && effect.current_iteration > 0 {
		final_keyframe := key_frame_set.keyframes_by_key[keys.last()] or { end_keyframe }
		final_values = s.compute_keyframe_values(abstract_element, final_keyframe, computed_properties)
	}
	s.clear_computation_context_caches()
	for property_id, initial_start in start_values {
		mut start := unsafe { initial_start }
		mut end := unsafe { initial_start }
		if end_value := end_values[property_id] {
			end = unsafe { end_value }
		}
		if !effect.is_css_transition && computed_properties.is_property_important(property_id) {
			continue
		}
		// Rust css/animation.rs::apply_animation_batch keeps each sampled result
		// as the underlying value for the next effect in composite order.
		underlying := computed_properties.property(property_id, .yes) or { continue }
		start_operation := if property_id in start_keyframe.use_initial_properties { CompositeOperation.replace } else { start_keyframe.composite or { effect.composite } }
		end_operation := if property_id in end_keyframe.use_initial_properties { CompositeOperation.replace } else { end_keyframe.composite or { effect.composite } }
		if composited := composite_value(property_id, underlying, start, start_operation) {
			start = composited
		}
		if composited := composite_value(property_id, underlying, end, end_operation) {
			end = composited
		}
		if final_value := final_values[property_id] {
			start = accumulate_animation_iterations(property_id, start, final_value, effect.current_iteration)
			end = accumulate_animation_iterations(property_id, end, final_value, effect.current_iteration)
		}
		if interpolated := interpolate_property(abstract_element.element(), property_id, start, end, interval_progress, .yes) {
			installed := samples.adopt(interpolated)
			persistent := platform.enter_persistent()
			computed_properties.set_animated_property(property_id, installed, if effect.is_css_transition {
				AnimatedPropertyResultOfTransition.yes
			} else {
				AnimatedPropertyResultOfTransition.no
			}, .no)
			platform.leave_persistent(persistent)
		} else {
			hidden := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.hidden)))
			persistent := platform.enter_persistent()
			computed_properties.set_animated_property(.visibility, hidden, .no, .no)
			platform.leave_persistent(persistent)
		}
	}

	mut custom_property_names := map[string]bool{}
	for name, _ in start_keyframe.custom_properties {
		custom_property_names[name] = true
	}
	for name, _ in start_keyframe.use_initial_custom_properties {
		custom_property_names[name] = true
	}
	for name, _ in end_keyframe.custom_properties {
		custom_property_names[name] = true
	}
	for name, _ in end_keyframe.use_initial_custom_properties {
		custom_property_names[name] = true
	}
	base := custom_property_animation_base(abstract_element)
	for name, _ in custom_property_names {
		if !effect.is_css_transition {
			if base_data := base {
				if property := base_data.get_property(name) {
					if property.important {
						continue
					}
				}
			}
		}
		underlying_specified := custom_property_animation_underlying_value(abstract_element, name)
		base_underlying := s.compute_animated_custom_property_value(abstract_element,
			computed_properties, name, underlying_specified)
		underlying := computed_properties.animated_custom_property_value(name) or { base_underlying }
		start_specified := start_keyframe.custom_properties[name] or { base_underlying }
		end_specified := end_keyframe.custom_properties[name] or { base_underlying }
		mut start := s.compute_animated_custom_property_value(abstract_element, computed_properties,
			name, start_specified)
		mut end := s.compute_animated_custom_property_value(abstract_element, computed_properties,
			name, end_specified)
		// Generated neutral endpoints already represent the underlying value.
		// Applying add again would count that underlying value twice.
		start_operation := if name in start_keyframe.use_initial_custom_properties { CompositeOperation.replace } else { start_keyframe.composite or { effect.composite } }
		end_operation := if name in end_keyframe.use_initial_custom_properties { CompositeOperation.replace } else { end_keyframe.composite or { effect.composite } }
		if composited := composite_animated_custom_property(underlying, start, start_operation) {
			start = composited
		}
		if composited := composite_animated_custom_property(underlying, end, end_operation) {
			end = composited
		}
		if effect.iteration_composite_accumulate && effect.current_iteration > 0 {
			last_keyframe := key_frame_set.keyframes_by_key[keys.last()] or { end_keyframe }
			last_specified := last_keyframe.custom_properties[name] or { base_underlying }
			last := s.compute_animated_custom_property_value(abstract_element, computed_properties, name, last_specified)
			start = accumulate_custom_property_iterations(start, last, effect.current_iteration)
			end = accumulate_custom_property_iterations(end, last, effect.current_iteration)
		}
		interpolated := interpolate_animated_custom_property(abstract_element.document(), name,
			start, end, interval_progress)
		installed := samples.adopt(interpolated)
		persistent := platform.enter_persistent()
		computed_properties.set_animated_custom_property(name, installed)
		platform.leave_persistent(persistent)
	}
}

// Web Animations owns its concrete effect records and provides the same CSS
// keyframe view used by CSS animations through the document's cycle boundary.
fn web_animation_effects_for_style(abstract_element dom.AbstractElement) []&KeyframeEffect {
	document := abstract_element.document()
	hook := document.animations_hook_ or { return []&KeyframeEffect{} }
	if hook.effects_for_style == unsafe { nil } { return []&KeyframeEffect{} }
	mut effects := []&KeyframeEffect{}
	for handle in hook.effects_for_style(hook.target, abstract_element) {
		if handle != unsafe { nil } { effects << unsafe { &KeyframeEffect(handle) } }
	}
	return effects
}

fn publish_animated_custom_properties(computed_properties &ComputedProperties, abstract_element dom.AbstractElement) {
	data := abstract_element.custom_property_data()
	mut base := data
	if current := data {
		if current.is_animation_overlay() {
			base = current.parent
		}
	}
	if !computed_properties.has_animated_custom_properties() {
		if current := data {
			if current.is_animation_overlay() {
				mut mutable_element := abstract_element
				mutable_element.set_custom_property_data(base)
			}
		}
		return
	}
	animated_values := computed_properties.animated_custom_property_values()

	if current := data {
		if current.is_animation_overlay() && current.own_values.len == animated_values.len {
			mut values_unchanged := true
			for name, value in animated_values {
				existing := current.own_values[name] or {
					values_unchanged = false
					break
				}
				if !custom_property_bridge_values_equal(existing.value,
					custom_property_bridge_value(value)) {
					values_unchanged = false
					break
				}
			}
			if values_unchanged {
				return
			}
		}
	}

	// During an animation frame the overlay is built among the samples it
	// exposes; the element keeps it until the next update replaces it.
	style_computer := css_style_computer_for(abstract_element.document())
	mut samples := if style_computer.sampling_animation_frame_ {
		style_computer.animation_samples_
	} else {
		unsafe { &AnimationSampleStorage(nil) }
	}
	samples.enter()
	mut overlay_values := map[string]dom.CSSCustomProperty_{}
	for name, value in animated_values {
		overlay_values[name] = dom.CSSCustomProperty_{
			value: custom_property_bridge_value(value)
		}
	}
	overlay := dom.CSSCustomPropertyData_.create_animation_overlay(overlay_values, base)
	samples.leave()
	mut mutable_element := abstract_element
	mutable_element.set_custom_property_data(overlay)
}

pub fn (s &StyleComputer) compute_properties(abstract_element dom.AbstractElement, mut cascaded_properties CascadedProperties) &ComputedProperties {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_computed_properties')
	defer { load_instruction_stage.finish() }
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(4, diagnostic_scope_start) }

	// Resolve the UA winner after cascade rollback and before longhand caching.
	resolve_quirks_table_color(abstract_element, mut cascaded_properties)
	mut properties := computed_properties_with_initial_values()
	s.prepare_computed_property_page_recycling(properties)
	properties.viewport_rect_ = s.viewport_rect_
	properties.root_font_size_px_ = s.root_element_font_metrics.font_size.to_double()
	properties.root_line_height_px_ = s.root_element_font_metrics.line_height.to_double()
	properties.root_font_metrics_depend_on_viewport_metrics_ = s.root_element_font_metrics_depend_on_viewport_metrics
	properties.subject_element_ = abstract_element.element()
	properties.subject_is_pseudo_ = abstract_element.pseudo_element() != none
	properties.position_try_reference_scope_ = position_try_reference_scope(abstract_element,cascaded_properties)
	properties.position_try_was_rendered_ = position_try_target_has_geometry(abstract_element)
	if old_dom := abstract_element.computed_properties() {
		if old := computed_properties_from_dom(old_dom) {
			properties.position_try_was_rendered_ = properties.position_try_was_rendered_ || old.position_try_was_rendered_
		}
	}
	mut recascaded_font_size_depends_on_viewport_metrics := false
	recascaded_font_size := s.recascade_font_size_if_needed(abstract_element, mut cascaded_properties, &recascaded_font_size_depends_on_viewport_metrics)
	// Only unchanged, context-independent specified values can keep their style
	// record when a font face changes. Relative font recascading retains the
	// complete cascade path.
	properties.font_input_refresh_safe_ = recascaded_font_size == none
	if font_size := recascaded_font_size {
		properties.set_property(.font_size, font_size, .no, .no)
		if recascaded_font_size_depends_on_viewport_metrics {
			properties.set_depends_on_viewport_metrics()
			properties.set_font_metrics_depend_on_viewport_metrics()
		}
	}
	// Parent computed style to inherit from, bridged from the DOM-side placeholder. Available only if the
	// inheritance source element has already had its (bridged) computed style stored.
	inherited_computed := parent_computed_properties(abstract_element)
	properties.font_input_parent_font_size_ = if parent := inherited_computed {
		parent.property(.font_size, .no) or { computed_interpolation_property_initial_value(.font_size) }
	} else {
		computed_interpolation_property_initial_value(.font_size)
	}
	property_source := ComputedPropertyValueSource{properties: properties}
	mut inherited_source_available := false
	if _ := inherited_computed {
		inherited_source_available = true
	}

	key_scope_start := begin_diagnostic_instruction_scope()
	reuse_key := s.computed_longhand_reuse_key(abstract_element, cascaded_properties,
		inherited_computed, recascaded_font_size != none)
	mut reused_longhands := false
	if key := reuse_key {
		reused_longhands = s.restore_computed_longhands(key, cascaded_properties, mut properties)
		record_diagnostic_longhand_lookup(reused_longhands)
	}
	record_diagnostic_instruction_scope(14, key_scope_start)
	if !reused_longhands {
		loop_scope_start := begin_diagnostic_instruction_scope()
		for property_id in computed_interpolation_property_computation_order() {
			property_index := int(property_id) - int(first_longhand_property_id())
			has_cascaded_property := cascaded_properties.contained_properties_cache_[int(property_id)] != 0
			if !has_cascaded_property
				&& computed_interpolation_default_work_cache[property_index] == 0 {
				continue
			}
			property_is_inherited := computed_interpolation_is_inherited_property(property_id)
			// A non-inherited property's default is computed from the same generated
			// initial value on every element. Cache that typed result after the first
			// element; inherited defaults remain element-dependent through their parent.
			can_reuse_default_computed_value := !has_cascaded_property && !property_is_inherited
				&& property_requires_computation_with_initial_value(property_id)
			if can_reuse_default_computed_value {
				cached_default := computed_interpolation_default_computed_value_cache[property_index]
				if cached_default != unsafe { nil } {
					properties.note_raw_computed_property_graph_mutation()
					properties.set_raw_property_at_index(property_index, cached_default)
					continue
				}
			}
			mut value := ?&dom.StyleValue(none)
			mut requires_computation := false
			cascaded_style_property := if has_cascaded_property {
				cascaded_properties.style_property(property_id)
			} else {
				?StyleProperty(none)
			}

			if active_cascaded_property := cascaded_style_property {
				if active_cascaded_property.important == .yes {
					properties.set_property_important(property_id, .yes)
				}
				value = active_cascaded_property.value
				requires_computation = property_requires_computation_with_cascaded_value(property_id)
				if property_id == .font_size {
					properties.set_raw_cascaded_font_size(active_cascaded_property.value)
				}
			}
			if property_id == .font_size && value == none && recascaded_font_size != none {
				continue
			}

			mut should_inherit := value == none && property_is_inherited

			// Classify the cascaded value once for inherit/unset and color's
			// currentcolor inheritance rule. All three checks read the same value.
			if style_value := value {
				keyword := computed_interpolation_style_value_keyword(style_value) or { Keyword.invalid }
				should_inherit = should_inherit || keyword == .inherit
					|| (keyword == .unset && property_is_inherited)
					|| (property_id == .color && keyword == .currentcolor)
			}

			if should_inherit && inherited_source_available {
				properties.set_property_inherited(property_id, .yes)
				if src := inherited_computed {
					if inherited_value := src.property(property_id, .no) {
						value = inherited_value
					}
					if property_affects_font_metrics(property_id)
						&& src.font_metrics_depend_on_viewport_metrics() {
						properties.set_font_metrics_depend_on_viewport_metrics()
					}
				}
				requires_computation = property_requires_computation_with_inherited_value(property_id)
				if animated_inherit := StyleComputer.get_animated_inherit_value(property_id, abstract_element) {
					properties.set_animated_property(property_id, animated_inherit.value, animated_inherit.is_result_of_transition, .yes)
				}
			}

			if style_value := value {
				// Inheritance may have replaced the value; classify that result afresh.
				keyword := computed_interpolation_style_value_keyword(style_value) or { Keyword.invalid }
				if keyword == .initial || keyword == .unset || (should_inherit && !inherited_source_available) {
					value = computed_interpolation_property_initial_value(property_id)
					requires_computation = property_requires_computation_with_initial_value(property_id)
				}
			} else {
				value = computed_interpolation_property_initial_value(property_id)
				requires_computation = property_requires_computation_with_initial_value(property_id)
			}

			style_value := value or { continue }
			mut depends_on_inherited_info := false
			if property_id == .font_weight || property_id == .font_size {
				keyword := computed_interpolation_style_value_keyword(style_value) or { Keyword.invalid }
				depends_on_inherited_info = (property_id == .font_weight
					&& keyword in [.bolder, .lighter])
					|| (property_id == .font_size && keyword in [.larger, .smaller])
			}
			if length := computed_interpolation_length_from_dom_style_value(style_value) {
				depends_on_inherited_info = depends_on_inherited_info || length.is_font_relative()
			}
			if depends_on_inherited_info {
				properties.add_inheritance_dependent_specified_value(property_id, style_value)
			}
			mut computed_value := unsafe { style_value }
			if requires_computation && property_id in [.font_weight, .font_style, .font_width] {
				if scalar := compute_scalar_font_property(property_id, style_value,
					abstract_element.element_to_inherit_style_from()) {
					properties.set_property_without_modifying_flags(property_id, scalar)
					continue
				}
			}
			if requires_computation && property_id == .font_size {
				if absolute := compute_absolute_font_size(style_value, abstract_element.document()) {
					properties.set_property_without_modifying_flags(property_id, absolute)
					continue
				}
			}
			if requires_computation && computed_scalar_value_is_resolved(property_id, style_value) {
				properties.set_property_without_modifying_flags(property_id, style_value)
				if can_reuse_default_computed_value {
					computed_interpolation_default_computed_value_cache[property_index] = style_value
				}
				continue
			}
			if requires_computation {
				context_scope_start := begin_diagnostic_instruction_scope()
				mut computation_context := s.get_computation_context_for_property(property_id, properties, abstract_element)
				computation_context.reset_viewport_metric_dependency_tracking()
				record_diagnostic_instruction_scope(16, context_scope_start)
				value_scope_start := begin_diagnostic_instruction_scope()
				if can_reuse_default_computed_value {
					// This value is shared by all later documents. Only its calculation
					// escapes; the element's property pages remain document-owned.
					persistent := platform.enter_persistent()
					computed_value = compute_value_of_property_from_source(property_id, style_value, property_source,
						computation_context, 1.0)
					platform.leave_persistent(persistent)
				} else {
					computed_value = compute_value_of_property_from_source(property_id, style_value, property_source,
						computation_context, 1.0)
				}
				record_diagnostic_instruction_scope(17, value_scope_start)
				if computation_context.did_resolve_font_relative_length {
					properties.font_input_depends_on_font_size_ = true
				}
				if computation_context.did_resolve_font_face_relative_length {
					properties.font_input_refresh_safe_ = false
				}
				if property_id == .font_size {
					if typed := typed_style_value_logic_from_dom(style_value) {
						if font_size_value_depends_on_inherited_font_size(typed) {
							properties.font_input_refresh_safe_ = false
						}
					}
				}
				if computation_context.depends_on_viewport_metrics() {
					properties.set_depends_on_viewport_metrics()
					if property_affects_font_metrics(property_id) {
						properties.set_font_metrics_depend_on_viewport_metrics()
					}
				}
			}
			properties.set_property_without_modifying_flags(property_id, computed_value)
			if can_reuse_default_computed_value {
				computed_interpolation_default_computed_value_cache[property_index] = computed_value
			}
		}
		if key := reuse_key { s.remember_computed_longhands(key, cascaded_properties, properties) }
		record_diagnostic_instruction_scope(15, loop_scope_start)
	}

	s.compute_highlight_inherited_values(mut properties, cascaded_properties, abstract_element)
	// The root element establishes the root font metrics used by rem/rlh for every
	// subsequently computed descendant. This is the mutable update performed by
	// StyleComputer::compute_properties() after its longhand computation loop.
	if abstract_element.pseudo_element() == none && abstract_element.element().is_document_element() {
		mut mutable_computer := unsafe { &StyleComputer(s) }
		mutable_computer.root_element_font_metrics = s.calculate_root_element_font_metrics(properties)
		mutable_computer.root_element_font_metrics_depend_on_viewport_metrics = properties.font_metrics_depend_on_viewport_metrics()
		properties.root_font_size_px_ = mutable_computer.root_element_font_metrics.font_size.to_double()
		properties.root_line_height_px_ = mutable_computer.root_element_font_metrics.line_height.to_double()
		properties.root_font_metrics_depend_on_viewport_metrics_ = mutable_computer.root_element_font_metrics_depend_on_viewport_metrics
	}

	// Compute the value of custom properties.
	s.compute_custom_properties(mut properties, abstract_element)

	s.clear_computation_context_caches()
	s.process_animation_definitions(properties, cascaded_properties, abstract_element)
	if s.css_animation_storage_ != unsafe { nil } {
		for existing in s.css_animation_storage_.animations_for(abstract_element) {
			mut animation := unsafe { existing }
			if animation.sample_at(s.animation_time_ms_) != none {
				s.collect_animation_into(abstract_element, voidptr(animation.effect_), mut properties)
				publish_animated_custom_properties(properties, abstract_element)
			}
		}
	}
	underlying_transition_samples := capture_transition_underlying_samples(properties,abstract_element,s.css_transition_storage_)
	if s.css_transition_storage_ != unsafe { nil } {
		for existing in s.css_transition_storage_.transitions_for(abstract_element) {
			mut transition := unsafe { existing }
			if transition.sample_at(s.animation_time_ms_) != none {
				s.collect_animation_into(abstract_element, voidptr(transition.keyframe_effect_), mut properties)
				publish_animated_custom_properties(properties, abstract_element)
			}
		}
	}
	publish_animated_custom_properties(properties, abstract_element)

	// Run automatic box type transformations.
	for effect in web_animation_effects_for_style(abstract_element) {
		s.collect_animation_into(abstract_element, voidptr(effect), mut properties)
	}
	publish_animated_custom_properties(properties, abstract_element)

	s.transform_box_type_if_needed(mut properties, abstract_element)

	// Apply any property-specific computed value logic.
	s.resolve_effective_overflow_values(mut properties)
	compute_text_align(mut properties, abstract_element)
	compute_alignment_values(mut properties, abstract_element)
	if abstract_element.pseudo_element() == none {
		adjust_element_computed_style(mut properties, abstract_element.element())
	}
	if pseudo := abstract_element.pseudo_element() {
		if pseudo in [.before,.after] {
			if content := properties.property(.content,.no) {
				if computed_interpolation_style_value_keyword(content) or { Keyword.invalid } == .normal {
					properties.set_property_without_modifying_flags(.content,dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_))))
				}
			}
		}
	}
	adjust_chromium_input_placeholder_style(mut properties, abstract_element)

	if s.css_transition_storage_ != unsafe { nil } {
		mut transition_storage := s.css_transition_storage_
		compute_transitioned_properties(properties, abstract_element, mut transition_storage)
		if old_dom_style := abstract_element.computed_properties() {
			if old_style := computed_properties_from_dom(old_dom_style) {
				initial_fallback := s.position_try_override_ != none && !properties.position_try_was_rendered_
				if !initial_fallback { s.start_needed_transitions(old_style, mut properties, abstract_element) }
			}
		}
		restore_cancelled_transition_samples(mut properties,abstract_element,transition_storage,underlying_transition_samples)
	}

	return properties
}

// HTMLSelectElement::adjust_computed_style(). This class-specific boundary is
// called from the central DOM/CSS dispatch below to avoid a css -> html cycle.
pub fn html_select_element_adjust_computed_style(mut properties ComputedProperties, element &dom.Element) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
	display := properties.display()
	if display.is_inline_outside() && display.is_flow_inside() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_block)))))
	}
	// Blink's native menu-list theme resets line-height after the cascade.
	// Custom appearance and list boxes retain their author line-height.
	chromium_menu_list := properties.appearance() != .none_
		&& !element.has_attribute('multiple') && element.get_attribute_value('size').int() <= 1
	if element.document().font_rendering_policy() != .chromium || chromium_menu_list {
		properties.set_property_without_modifying_flags(.line_height, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.normal))))
	}
}

// HTMLTextAreaElement::adjust_computed_style(). This class-specific boundary
// is called from the central DOM/CSS dispatch below to avoid a css -> html cycle.
pub fn html_text_area_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
	display := properties.display()
	if display.is_inline_outside() && display.is_flow_inside() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_block)))))
	}
}

pub fn html_button_element_adjust_computed_style(mut properties ComputedProperties) {
	display := properties.display()
	if display.is_flex_inside() || display.is_grid_inside() || display.is_none() || display.is_contents() {
		return
	}
	adjusted := if display.is_inline_outside() {
		Display.from_short(.inline_block)
	} else {
		Display.from_short(.flow_root)
	}
	properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(adjusted))))
}

pub fn html_embed_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_iframe_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_canvas_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_image_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_object_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn htmli_frame_element_adjust_computed_style(mut properties ComputedProperties) {
	html_iframe_element_adjust_computed_style(mut properties)
}

pub fn html_frame_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_frame_set_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn htmlbr_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	} else if !properties.display().is_none() {
		// A <br> always produces a BreakNode when it generates a box. Prevent
		// table, flex, grid, and other display values from selecting another box type.
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_)))))
	}
}

pub fn html_br_element_adjust_computed_style(mut properties ComputedProperties) {
	htmlbr_element_adjust_computed_style(mut properties)
}

pub fn html_audio_element_adjust_computed_style(mut properties ComputedProperties, element &dom.HTMLAudioElement) {
	dom_element := unsafe { &dom.Element(element) }
	html_media_element_adjust_computed_style(mut properties)
	if !dom_element.has_attribute_ns(none, 'controls') {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

pub fn html_media_element_adjust_computed_style(mut properties ComputedProperties) {
	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
	display := properties.display()
	if display.is_inline_outside() && display.is_flow_inside() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_block)))))
	}
}

pub fn html_element_adjust_computed_style(mut properties ComputedProperties, element &dom.HTMLElement) {
	dom_element := unsafe { &dom.Element(element) }
	if dom_element.local_name() == 'wbr' && properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	}
}

// DOM::Element::adjust_computed_style() overrides implemented by the element
// classes. Keep this after the generic box-type transformations, matching
// StyleComputer::compute_properties().
pub fn is_outermost_svg_element_for_css_box_layout(element &dom.Element) bool {
	if !element.is_svg_element() || element.local_name() != 'svg' {
		return false
	}
	mut ancestor := element.as_node().parent_element()
	for ancestor != none {
		candidate := ancestor or { break }
		if candidate.is_svg_element() && candidate.local_name() == 'foreignObject' {
			break
		}
		if candidate.is_svg_element() && candidate.local_name() == 'svg' {
			return false
		}
		ancestor = candidate.as_node().parent_element()
	}
	return true
}

fn adjust_element_computed_style(mut properties ComputedProperties, element &dom.Element) {
	if element.is_svg_element() {
		// SVGElement::adjust_computed_style(): only the outermost <svg>
		// participates in CSS box positioning. Every other SVG element uses the
		// SVG coordinate system and is forced to position: static.
		is_outermost_svg := is_outermost_svg_element_for_css_box_layout(element)
		if !is_outermost_svg {
			properties.set_property_without_modifying_flags(.position, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.static_))))
		}
		// https://drafts.csswg.org/css-display-3/#unbox-svg
		// An SVG element with CSS box layout and non-container/renderable SVG
		// elements cannot be unboxed. The listed nested container and text-child
		// elements retain display:contents and hoist their rendered descendants.
		// The document element's authored `contents` value has already been
		// blockified by the generic root transformation at this point. Consult
		// the retained pre-transformation value as well so SVG unboxing wins.
		display_was_contents := properties.display().is_contents()
			|| properties.display_before_box_type_transformation().is_contents()
		if display_was_contents
			&& (is_outermost_svg || element.local_name() !in ['a', 'g', 'svg', 'switch', 'textPath',
				'tspan', 'use']) {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
		}
		if element.local_name() == 'symbol' && element.is_direct_child_of_svg_use_shadow_tree() {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_)))))
		}
		return
	}
	// https://drafts.csswg.org/css-display-3/#unbox-mathml
	namespace_ := element.namespace_uri() or { '' }
	if namespace_ == 'http://www.w3.org/1998/Math/MathML' {
		if properties.display().is_contents()
			|| properties.display_before_box_type_transformation().is_contents() {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
		}
		return
	}
	if !element.is_html_element() {
		return
	}
	html_element_adjust_computed_style(mut properties, unsafe { &dom.HTMLElement(element) })
	local_name := element.local_name().to_lower()
	if local_name == 'select' {
		html_select_element_adjust_computed_style(mut properties, element)
		return
	}
	if local_name == 'textarea' {
		html_text_area_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'button' {
		html_button_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'embed' {
		html_embed_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'iframe' {
		html_iframe_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'canvas' {
		html_canvas_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'img' {
		html_image_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'object' {
		html_object_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'video' {
		html_media_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'frame' {
		html_frame_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'frameset' {
		html_frame_set_element_adjust_computed_style(mut properties)
		return
	}
	if local_name == 'br' {
		htmlbr_element_adjust_computed_style(mut properties)
		return
	}
	// HTMLTableElement::recompute_style(): legacy -libweb-* alignment values
	// center/right-align the table wrapper but are not inherited by table
	// contents.
	if local_name == 'table' && properties.text_align() in [.libweb_left, .libweb_center,
		.libweb_right] {
		properties.set_property_without_modifying_flags(.text_align, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.start))))
	}
	// HTMLElement::adjust_computed_style() and the replaced/control element
	// overrides that implement CSS Display's display:contents unboxing rule.
	if local_name == 'wbr' || local_name in ['iframe', 'br', 'img', 'canvas', 'object', 'textarea',
		'meter', 'embed', 'progress', 'frame', 'frameset', 'select', 'audio', 'video'] {
		if properties.display().is_contents() {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
		}
	}
	// HTMLMediaElement, HTMLSelectElement and HTMLTextAreaElement need an
	// atomic inline box for their internal shadow-tree layout.
	if local_name in ['audio', 'video', 'select', 'textarea'] {
		display := properties.display()
		if display.is_inline_outside() && display.is_flow_inside() {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_block)))))
		}
	}
	if local_name == 'audio' && !element.has_attribute_ns(none, 'controls') {
		html_audio_element_adjust_computed_style(mut properties, unsafe { &dom.HTMLAudioElement(element) })
		return
	}
	if local_name == 'input' {
		html_input_element_adjust_computed_style(mut properties, element)
		return
	}
}

// HTMLInputElement::adjust_computed_style(). Keep the element-specific
// adjustments at the same post-computation boundary as the upstream style
// computer, after the generic box-type transformations have run.
fn html_input_element_adjust_computed_style(mut properties ComputedProperties, element &dom.Element) {
	mut type_ := element.get_attribute_value('type').trim_space().to_lower()
	if type_.len == 0 {
		type_ = 'text'
	}
	if type_ in ['hidden', 'submit', 'button', 'reset', 'image', 'checkbox', 'radio'] {
		return
	}

	if properties.display().is_contents() {
		properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))))
	} else {
		display := properties.display()
		if display.is_inline_outside() && display.is_flow_inside() {
			properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_block)))))
		}
	}

	// For web compatibility, these are the one-line plain-text controls used by
	// HTMLInputElement::is_single_line(). URL is intentionally not in this set.
	if type_ in ['text', 'search', 'password', 'email', 'tel', 'number'] {
		current_line_height := properties.line_height().to_double()
		minimum_line_height := properties.font_size().to_double() * computed_properties_normal_line_height_scale
		if current_line_height < minimum_line_height {
			if parsed := parse_css_value_logic(.line_height, 'normal') {
				properties.set_property_without_modifying_flags(.line_height, dom_style_value_from_value_logic(parsed))
			}
		}
	}
}

pub fn (s &StyleComputer) compute_property_values(mut computed_properties ComputedProperties, abstract_element ?dom.AbstractElement) {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_value_conversion')
	defer { load_instruction_stage.finish() }
	property_source := ComputedPropertyValueSource{properties: &computed_properties}
	for property_id in computed_interpolation_property_computation_order() {
		specified_value := computed_properties.property(property_id, .no) or {
			computed_interpolation_property_initial_value(property_id)
		}
		mut computation_context := s.get_computation_context_for_property(property_id, computed_properties, abstract_element)
		computation_context.reset_viewport_metric_dependency_tracking()
		computed_value := compute_value_of_property_from_source(property_id, specified_value,
			property_source, computation_context, 1.0)
		computed_properties.set_property_without_modifying_flags(property_id, computed_value)
		if computation_context.depends_on_viewport_metrics() {
			computed_properties.set_depends_on_viewport_metrics()
			if property_affects_font_metrics(property_id) {
				computed_properties.set_font_metrics_depend_on_viewport_metrics()
			}
		}
	}
}

fn (s &StyleComputer) find_animation_keyframes(name string, shadow_root ?&dom.ShadowRoot) ?&KeyFrameSet {
	cache := s.rule_cache_for_cascade_origin(.author, none, shadow_root) or { return none }
	return cache.rules_by_animation_keyframes[name] or { none }
}

fn (s &StyleComputer) resolve_animation_keyframes(name string, cascaded_properties &CascadedProperties, abstract_element dom.AbstractElement) ?&KeyFrameSet {
	if source_shadow_root := cascaded_properties.property_source_shadow_root(.animation_name) {
		if keyframes := s.find_animation_keyframes(name, source_shadow_root) {
			return keyframes
		}
	}
	if shadow_root := abstract_element.element().as_node().root().as_shadow_root() {
		if keyframes := s.find_animation_keyframes(name, shadow_root) {
			return keyframes
		}
	}
	return s.find_animation_keyframes(name, none)
}

pub fn (s &StyleComputer) process_animation_definitions(computed_properties &ComputedProperties, cascaded_properties &CascadedProperties, abstract_element dom.AbstractElement) {
	if s.css_animation_storage_ == unsafe { nil } {
		return
	}
	mut storage := s.css_animation_storage_
	animation_definitions := computed_properties.animations(&abstract_element)
	if animation_definitions.len == 0 {
		if storage.entries.len != 0 {
			storage.remove_animations_not_named(abstract_element, {})
		}
		return
	}
	mut defined_names := map[string]bool{}
	for animation_properties in animation_definitions {
		defined_names[animation_properties.name] = true
		if existing := storage.animation(abstract_element, animation_properties.name) {
			mut animation := unsafe { existing }
			mut effect := unsafe { &KeyframeEffect(animation.effect_) }
			effect.set_key_frame_set(s.resolve_animation_keyframes(animation_properties.name, cascaded_properties, abstract_element))
			animation.apply_css_properties(animation_properties)
			continue
		}

		mut animation := CSSAnimation.create()
		animation.set_animation_name(animation_properties.name)
		animation.set_owning_element(abstract_element)
		animation.start_time_ = s.animation_time_ms_
		mut effect := KeyframeEffect.create()
		animation.set_effect(effect)
		animation.apply_css_properties(animation_properties)

		effect.set_key_frame_set(s.resolve_animation_keyframes(animation_properties.name, cascaded_properties, abstract_element))
		effect.set_target(abstract_element)
		storage.set(abstract_element, animation_properties.name, animation)
	}
	storage.remove_animations_not_named(abstract_element, defined_names)
}

pub fn (s &StyleComputer) should_reject_with_ancestor_filter(selector Selector) bool {
	mut ancestor_hashes := selector.ancestor_hashes()
	if s.document_ != unsafe { nil } && s.document_.in_quirks_mode() {
		folded_hashes, _ := selector_ancestor_hashes_with_name_case(selector, true)
		ancestor_hashes = folded_hashes
	}
	for index in 0 .. selector_ancestor_hash_count {
		hash := ancestor_hashes[index]
		if hash == 0 {
			break
		}
		if !s.ancestor_filter_.may_contain(hash) {
			return true
		}
	}
	return false
}

enum ComputedCustomPropertyValueKind {
	existing
	substituted
	guaranteed_invalid
}

// Substitution produces owned tokens before an element decides whether its
// value differs from its parent's. Delay the DOM boxes and CSS serialization
// until that value actually needs to be retained or returned to a caller.
struct ComputedCustomPropertyValue {
	kind           ComputedCustomPropertyValueKind
	existing_value &dom.StyleValue = unsafe { nil }
	tokens         []ComponentValue
	base_url       ?string
}

fn (value ComputedCustomPropertyValue) materialize() &dom.StyleValue {
	return match value.kind {
		.existing { value.existing_value }
		.substituted {
			mut result := dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create_with_presence(
				value.tokens, SubstitutionFunctionsPresence{}, none)))
			result.base_url = value.base_url
			result
		}
		.guaranteed_invalid {
			dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
		}
	}
}

fn initial_computed_custom_property_value(document &dom.Document, name string) ComputedCustomPropertyValue {
	if initial_value := document.custom_property_initial_value(name) {
		return ComputedCustomPropertyValue{existing_value: parse_custom_property_value(initial_value)}
	}
	return ComputedCustomPropertyValue{kind: .guaranteed_invalid}
}

fn custom_property_initial_style_value(document &dom.Document, name string) &dom.StyleValue {
	return initial_computed_custom_property_value(document, name).materialize()
}

fn dom_style_value_from_custom_property_bridge(value &dom.CSSStyleValue_) ?&dom.StyleValue {
	if value.css_value_handle == unsafe { nil } {
		return none
	}
	return unsafe { &dom.StyleValue(value.css_value_handle) }
}

fn resolve_computed_custom_property_value(abstract_element dom.AbstractElement, custom_property string, mut guarded_contexts GuardedSubstitutionContexts) ComputedCustomPropertyValue {
	bridged_value := abstract_element.get_custom_property(custom_property) or {
		return initial_computed_custom_property_value(abstract_element.document(), custom_property)
	}
	if bridged_value.guaranteed_invalid {
		return initial_computed_custom_property_value(abstract_element.document(), custom_property)
	}
	value := dom_style_value_from_custom_property_bridge(bridged_value) or {
		parse_custom_property_value(bridged_value.css_text)
	}
	typed := typed_style_value_logic_from_dom(value) or {
		return ComputedCustomPropertyValue{existing_value: value}
	}
	keyword := typed.to_keyword()
	if keyword == .initial {
		return initial_computed_custom_property_value(abstract_element.document(), custom_property)
	}
	if keyword in [.inherit, .unset] {
		inherit_from := abstract_element.element_to_inherit_style_from() or {
			return initial_computed_custom_property_value(abstract_element.document(), custom_property)
		}
		inherited := inherit_from.get_custom_property(custom_property) or {
			return initial_computed_custom_property_value(abstract_element.document(), custom_property)
		}
		inherited_value := dom_style_value_from_custom_property_bridge(inherited) or {
			parse_custom_property_value(inherited.css_text)
		}
		return ComputedCustomPropertyValue{existing_value: inherited_value}
	}
	if typed !is UnresolvedStyleValue || !typed.substitution_functions_presence.has_any() {
		return ComputedCustomPropertyValue{existing_value: value}
	}

	result := substitute_arbitrary_substitution_functions_for_element(abstract_element, mut guarded_contexts, typed.tokens, SubstitutionContext{
		dependency_type: .property
		first: custom_property
	})
	if contains_guaranteed_invalid_value(result) {
		return ComputedCustomPropertyValue{kind: .guaranteed_invalid}
	}
	return ComputedCustomPropertyValue{kind: .substituted, tokens: result, base_url:value.base_url}
}

fn compute_value_of_custom_property_with_guarded_contexts(abstract_element dom.AbstractElement, custom_property string, mut guarded_contexts GuardedSubstitutionContexts) &dom.StyleValue {
	value := resolve_computed_custom_property_value(abstract_element, custom_property,
		mut guarded_contexts).materialize()
	registration := abstract_element.document().get_registered_custom_property(custom_property) or { return value }
	syntax := style_query_registration_syntax(registration) or { return value }
	if syntax.type() == .universal { return value }
	mut typed := typed_style_value_logic_from_dom(value) or { return value }
	if typed is UnresolvedStyleValue { typed = parse_with_a_syntax(typed.tokenize(), syntax) }
	base := value.base_url or { abstract_element.document().base_url().to_string() }
	return dom_style_value_from_value_logic(resolve_registered_property_urls(typed, base))
}

pub fn StyleComputer.compute_value_of_custom_property(abstract_element dom.AbstractElement, custom_property string) &dom.StyleValue {
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return compute_value_of_custom_property_with_guarded_contexts(abstract_element, custom_property, mut guarded_contexts)
}

fn repeat_style_value_list_to_n_elements(style_value &dom.StyleValue, n int) &dom.StyleValue {
	typed_value := typed_style_value_logic_from_dom(style_value) or {
		panic('repeat_style_value_list_to_n_elements requires a typed StyleValue')
	}
	if typed_value !is StyleValueList {
		panic('repeat_style_value_list_to_n_elements requires a StyleValueList')
	}
	value_list := typed_value as StyleValueList
	if value_list.size() == n {
		return unsafe { style_value }
	}

	mut repeated_values := []StyleValue{cap: n}
	for i := 0; i < n; i++ {
		repeated_values << value_list.value_at(i, true)
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create_collapsible(repeated_values, value_list.separator())))
}

// A property computation reads dependencies synchronously. Ordinary style passes
// borrow the live style instead of allocating a managed closure per property;
// callers with a custom lookup retain the public callback boundary below.
struct ComputedPropertyValueSource {
	properties       &ComputedProperties = unsafe { nil }
	specified_values &map[PropertyID]&dom.StyleValue = unsafe { nil }
	callback         fn (PropertyID) &dom.StyleValue = unsafe { nil }
	uses_callback    bool
}

fn (source ComputedPropertyValueSource) get(property_id PropertyID) &dom.StyleValue {
	if source.uses_callback {
		return source.callback(property_id)
	}
	if source.specified_values != unsafe { nil } {
		if value := (*source.specified_values)[property_id] {
			return value
		}
	}
	return source.properties.property(property_id, .no) or {
		computed_interpolation_property_initial_value(property_id)
	}
}

pub fn StyleComputer.compute_value_of_property(property_id PropertyID, specified_value &dom.StyleValue, get_property_specified_value fn (PropertyID) &dom.StyleValue, computation_context ComputationContext, device_pixels_per_css_pixel f64) &dom.StyleValue {
	return compute_value_of_property_from_source(property_id, specified_value,
		ComputedPropertyValueSource{callback: get_property_specified_value, uses_callback: true},
		computation_context, device_pixels_per_css_pixel)
}

fn compute_value_of_property_from_source(property_id PropertyID, specified_value &dom.StyleValue, property_source ComputedPropertyValueSource, computation_context ComputationContext, device_pixels_per_css_pixel f64) &dom.StyleValue {
	typed_specified_value := typed_style_value_logic_from_dom(specified_value) or {
		panic('StyleComputer.compute_value_of_property requires a typed StyleValue')
	}
	typed_absolutized_value := typed_specified_value.absolutized(computation_context)
	absolutized_value := if typed_absolutized_value == typed_specified_value {
		unsafe { specified_value }
	} else {
		dom_style_value_from_value_logic(typed_absolutized_value)
	}

	return match property_id {
		.shape_outside { dom_style_value_from_value_logic(shape_outside_without_default_box(typed_absolutized_value)) }
		.text_emphasis_style { compute_text_emphasis_style(absolutized_value, property_source.get(.writing_mode)) }
		.animation_range_start, .animation_range_end { compute_animation_range_endpoint(absolutized_value, property_id == .animation_range_start) }
		.animation_name {
			StyleComputer.compute_animation_name(absolutized_value)
		}

		// NB: The background properties are coordinated at compute time rather than use time,
		// unlike other coordinating list property groups.
		.background_attachment, .background_clip, .background_origin, .background_position_x,
		.background_position_y, .background_repeat, .background_size {
			background_image := property_source.get(.background_image)
			typed_background_image := typed_style_value_logic_from_dom(background_image) or {
				panic('background-image requires a typed StyleValue')
			}
			if typed_background_image !is StyleValueList {
				panic('background-image requires a StyleValueList')
			}
			repeat_style_value_list_to_n_elements(absolutized_value, (typed_background_image as StyleValueList).size())
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .column_rule_width, .outline_width {
			StyleComputer.compute_border_or_outline_width(absolutized_value, device_pixels_per_css_pixel, computation_context)
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			StyleComputer.compute_corner_shape(absolutized_value)
		}
		.font_feature_settings {
			StyleComputer.compute_font_feature_tag_value_list(absolutized_value, computation_context)
		}
		.font_size {
			math_depth_value := property_source.get(.math_depth)
			computed_math_depth := int(computed_interpolation_integer_from_dom_style_value(math_depth_value) or {
				0
			})
			inheritance_parent := style_computation_inheritance_parent(computation_context)
			if font_size_value_depends_on_inherited_font_size(typed_absolutized_value) {
				if parent := inheritance_parent {
					if dom_computed := parent.computed_properties() {
						if inherited := computed_properties_from_dom(dom_computed) {
							if inherited.font_metrics_depend_on_viewport_metrics() {
								computation_context.length_resolution_context.record_viewport_relative_length_resolution()
							}
						}
					}
				}
			}
			compute_font_size_with_document_policy(absolutized_value, computed_math_depth, inheritance_parent, computation_context)
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
			compute_line_height_with_document_policy(absolutized_value, computation_context)
		}
		.object_position, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .perspective, .perspective_origin,
		.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom,
		.scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left,
		.scroll_margin_right, .scroll_margin_top, .scroll_padding_block_end,
		.scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end,
		.scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right,
		.scroll_padding_top {
			StyleComputer.compute_absolutized_value(property_id, absolutized_value, computation_context)
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
			StyleComputer.compute_absolutized_value(property_id, absolutized_value, computation_context)
		}
		else {
			absolutized_value
		}
	}
}

fn style_computation_inheritance_parent(computation_context ComputationContext) ?dom.AbstractElement {
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
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(computed_entries, .comma, .yes)))
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
		if !is_valid_custom_ident(string_value, ['none']) {
			return entry
		}

		return StyleValue(CustomIdentStyleValue.create(string_value))
	}

	return none
}

pub fn StyleComputer.compute_animation_name(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-animations-1/#animation-name
	// list, each item either a case-sensitive css identifier or the keyword none
	return computed_interpolation_compute_style_value_list(absolutized_value, computed_interpolation_compute_animation_name_entry) or { unsafe { absolutized_value } }
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
	if style_value.css_value_handle != unsafe { nil } {
		// The DOM value owns the typed box throughout this synchronous read.
		// Avoid copying and rooting an optional StyleValue just to inspect its tag.
		typed := unsafe { &TypedStyleValueBox(style_value.css_value_handle) }
		if typed.value is LengthStyleValue {
			return typed.value.length()
		}
		return none
	}
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

pub fn StyleComputer.compute_border_or_outline_width(absolutized_value &dom.StyleValue, device_pixels_per_css_pixel f64, computation_context ComputationContext) &dom.StyleValue {
	// https://drafts.csswg.org/css-backgrounds/#border-width
	// absolute length, snapped as a border width
	mut absolute_length := computed_interpolation_line_width_keyword_to_css_pixels(absolutized_value.css_text) or {
		parsed_value := style_value_logic_from_dom(.border_top_width, absolutized_value) or {
			return unsafe { absolutized_value }
		}
		match parsed_value {
			LengthStyleValue {
				parsed_value.length().to_px(computation_context.length_resolution_context)
			}
			CalculatedStyleValue {
				length := parsed_value.resolve_length(CalculationResolutionContext{
					length_resolution_context: computation_context.length_resolution_context
				}) or { return unsafe { absolutized_value } }
				length.to_px(computation_context.length_resolution_context)
			}
			else {
				return unsafe { absolutized_value }
			}
		}
	}
	// The <line-width> grammar has the [0,∞] range restriction. Calculated values
	// are clamped at computed-value time before the border-width snapping steps.
	if absolute_length.raw_value() < 0 {
		absolute_length = CSSPixels.new(0)
	}
	snapped_length := computed_interpolation_snap_a_length_as_a_border_width(device_pixels_per_css_pixel, absolute_length)
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(snapped_length))))
}

pub fn StyleComputer.compute_length(absolutized_value &dom.StyleValue, computation_context ComputationContext) &dom.StyleValue {
	length := computed_interpolation_length_from_dom_style_value(absolutized_value) or {
		return unsafe { absolutized_value }
	}
	computed_length := LengthStyleValue.create(length).absolutized(ComputationContext{
		length_resolution_context: computation_context.length_resolution_context
	})
	return dom_style_value_from_value_logic(StyleValue(computed_length))
}

pub fn StyleComputer.compute_absolutized_value(property_id PropertyID, absolutized_value &dom.StyleValue, computation_context ComputationContext) &dom.StyleValue {
	parsed_value := style_value_logic_from_dom(property_id, absolutized_value) or {
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
	parsed_value := if typed := typed_style_value_logic_from_dom(absolutized_value) {
		typed
	} else {
		mut parser := Parser.from_css_text(absolutized_value.css_text)
		mut tokens := ComponentValueStream.new(parser.component_values)
		parsed := parser.parse_corner_shape_value(mut tokens) or {
			return unsafe { absolutized_value }
		}
		tokens.consume_whitespace()
		if tokens.has_more_tokens() {
			return unsafe { absolutized_value }
		}
		parsed
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
				else {
					return none
				}
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
	return OpenTypeTaggedStyleValue.create(.font_feature_settings, opentype_tag.string_value(), value)
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

	return OpenTypeTaggedStyleValue.create(.font_variation_settings, opentype_tag.string_value(), number)
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

	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(axis_tags, .comma, .yes)))
}

pub fn StyleComputer.compute_font_feature_tag_value_list(absolutized_value &dom.StyleValue, computation_context ComputationContext) &dom.StyleValue {
	_ = computation_context
	// https://drafts.csswg.org/css-fonts-4/#font-variation-settings-def
	// https://drafts.csswg.org/css-fonts/#font-feature-settings-prop
	// NB: The computation logic is the same for both font-feature-settings and font-variation-settings, first we
	//     deduplicate feature tags (with latter taking precedence), then we sort them in ascending order by code unit
	return computed_interpolation_compute_font_feature_tag_value_list(absolutized_value, .font_feature_settings) or { unsafe { absolutized_value } }
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

	parsed_value := style_value_logic_from_dom(.math_depth, absolutized_value) or {
		return unsafe { absolutized_value }
	}

	// The computed value of the math-depth value is determined as follows:
	// - If the specified value of math-depth is auto-add and the inherited value of math-style is compact
	//   then the computed value of math-depth of the element is its inherited value plus one.
	if parsed_value.to_keyword() == .auto_add && inherited_math_style == .compact {
		return dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(i64(inherited_math_depth + 1))))
	}

	// - If the specified value of math-depth is of the form add(<integer>) then the computed value of
	//   math-depth of the element is its inherited value plus the specified integer.
	if parsed_value is FunctionStyleValue {
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

fn computed_interpolation_keyword_to_absolute_size(keyword Keyword) ?AbsoluteSize {
	return match keyword {
		.xx_small { .xx_small }
		.x_small { .x_small }
		.small { .small }
		.medium { .medium }
		.large { .large }
		.x_large { .x_large }
		.xx_large { .xx_large }
		.xxx_large { .xxx_large }
		else { none }
	}
}

fn computed_interpolation_keyword_to_relative_size(keyword Keyword) ?RelativeSize {
	return match keyword {
		.smaller { .smaller }
		.larger { .larger }
		else { none }
	}
}

// css_length_font_metrics_cache memoizes LengthFontMetrics, a pure function of
// the font size. The cascade otherwise rebuilds it (constructing a
// platform.Font, reading face tables, and rounding four CSSPixels) hundreds of
// thousands of times per document; keying on the raw CSSPixels value makes each
// distinct size cost once.
__global css_length_font_metrics_cache = map[int]LengthFontMetrics{}

fn computed_interpolation_font_metrics_for_size(font_size CSSPixels) LengthFontMetrics {
	key := font_size.raw_value()
	if cached := css_length_font_metrics_cache[key] {
		return cached
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	ratio := font_size.to_double() / 16.0
	metrics := platform.fallback_font_pixel_metrics(f32(font_size.to_double()))
	result := LengthFontMetrics{
		font_size: font_size
		x_height: CSSPixels.nearest_value_for(f64(metrics.x_height))
		cap_height: CSSPixels.nearest_value_for(12.0 * ratio)
		zero_advance: CSSPixels.nearest_value_for(f64(metrics.advance_of_ascii_zero))
		line_height: CSSPixels.nearest_value_for(19.2 * ratio)
	}
	css_length_font_metrics_cache[key] = result
	return result
}

// Build the font-relative length context from the face selected by the
// element's computed font cascade. This mirrors Length::FontMetrics in
// upstream: ex/ch/cap units use the selected face, not the generic fallback
// used while the font properties themselves are still being computed.
fn computed_interpolation_font_metrics_for_style(computed_properties &ComputedProperties, font_computer &FontComputer) LengthFontMetrics {
	mut mutable_properties := unsafe { &ComputedProperties(computed_properties) }
	computed_font := mutable_properties.first_available_computed_font(font_computer)
	font := computed_font.font_for_metrics()
	metrics := font.pixel_metrics()
	return LengthFontMetrics{
		font_size: computed_properties.font_size()
		font_size_unrounded: if font.font_rendering_policy == .chromium { ?f64(computed_properties.resolved_font_size_px()) } else { none }
		x_height: CSSPixels.nearest_value_for(f64(metrics.x_height))
		x_height_unrounded: if font.font_rendering_policy == .chromium { ?f64(metrics.x_height) } else { none }
		cap_height: CSSPixels.nearest_value_for(f64(metrics.ascent))
		zero_advance: CSSPixels.nearest_value_for(f64(metrics.advance_of_ascii_zero))
		zero_advance_unrounded: if font.font_rendering_policy == .chromium { ?f64(metrics.advance_of_ascii_zero) } else { none }
		line_height: computed_properties.line_height()
	}
}

fn computed_interpolation_root_font_size(inheritance_parent ?dom.AbstractElement) CSSPixels {
	parent := inheritance_parent or { return StyleComputer.default_user_font_size() }
	root := parent.document().document_element() or {
		return StyleComputer.default_user_font_size()
	}
	root_abstract := dom.AbstractElement.new(root, none)
	dom_computed := root_abstract.computed_properties() or {
		return StyleComputer.default_user_font_size()
	}
	computed := computed_properties_from_dom(dom_computed) or {
		return StyleComputer.default_user_font_size()
	}
	return computed.font_size()
}

pub fn StyleComputer.compute_font_size(absolutized_value &dom.StyleValue, computed_math_depth int, inheritance_parent ?dom.AbstractElement) &dom.StyleValue {
	// https://drafts.csswg.org/css-fonts/#font-size-prop
	mut inherited_font_size := StyleComputer.default_user_font_size()
	mut inherited_math_depth := 0
	mut viewport_rect := CSSPixelRect{}
	if parent := inheritance_parent {
		viewport_rect = css_pixel_rect_from_dom_rect(parent.document().viewport_rect())
		if dom_computed := parent.computed_properties() {
			if computed := computed_properties_from_dom(dom_computed) {
				inherited_font_size = computed.font_size()
				inherited_math_depth = computed.math_depth()
			}
		}
	}

	parsed_value := style_value_logic_from_dom(.font_size, absolutized_value) or {
		return unsafe { absolutized_value }
	}
	keyword := parsed_value.to_keyword()
	if absolute_size := computed_interpolation_keyword_to_absolute_size(keyword) {
		font_size := StyleComputer.absolute_size_mapping(absolute_size, StyleComputer.default_user_font_size())
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(font_size))))
	}
	if relative_size := computed_interpolation_keyword_to_relative_size(keyword) {
		font_size := StyleComputer.relative_size_mapping(relative_size, inherited_font_size)
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(font_size))))
	}

	root_font_size := computed_interpolation_root_font_size(inheritance_parent)
	context := LengthResolutionContext{
		viewport_rect: viewport_rect
		font_metrics: computed_interpolation_font_metrics_for_size(inherited_font_size)
		root_font_metrics: computed_interpolation_font_metrics_for_size(root_font_size)
	}
	if parsed_value is LengthStyleValue {
		length := parsed_value.length()
		if length.is_absolute() || length.is_font_relative() || length.is_container_relative()
			|| length.is_viewport_relative() {
			font_size := length.to_px(context)
			return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(font_size))))
		}
	}
	if parsed_value is PercentageStyleValue {
		font_size := inherited_font_size.times_float(parsed_value.percentage().as_fraction())
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(font_size))))
	}
	if parsed_value is CalculatedStyleValue {
		font_size := parsed_value.resolve_length(CalculationResolutionContext{
			percentage_basis: Length.make_css_px(inherited_font_size)
			length_resolution_context: context
		}) or { return unsafe { absolutized_value } }
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(font_size)))
	}

	if keyword == .math {
		mut exponent := computed_math_depth - inherited_math_depth
		mut invert_scale_factor := false
		if exponent < 0 {
			exponent = -exponent
			invert_scale_factor = true
		}
		mut scale := math.pow(0.71, f64(exponent))
		if invert_scale_factor && scale != 0 {
			scale = 1.0 / scale
		}
		font_size := inherited_font_size.times_float(scale)
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(font_size))))
	}

	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_font_style(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-fonts-4/#font-style-prop
	// the keyword specified, plus angle in degrees if specified

	// NB: We always parse as a FontStyleStyleValue, but StylePropertyMap is able to set a KeywordStyleValue directly.
	parsed_value := if typed := typed_style_value_logic_from_dom(absolutized_value) {
		typed
	} else {
		mut parser := Parser.from_css_text(absolutized_value.css_text)
		mut tokens := ComponentValueStream.new(parser.component_values)
		parsed := parser.parse_font_style_value(mut tokens) or {
			return unsafe { absolutized_value }
		}
		tokens.consume_whitespace()
		if tokens.has_more_tokens() {
			return unsafe { absolutized_value }
		}
		parsed
	}
	if parsed_value !is FontStyleStyleValue {
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
	if calculated_number := computed_interpolation_calculated_number_from_dom_style_value(absolutized_value, CSSPixels.nearest_value_for(0)) {
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
	if style_value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(style_value.css_value_handle) }
		if typed.value is NumberStyleValue {
			return typed.value.number()
		}
		return none
	}
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
	parsed_value := style_value_logic_from_dom(.math_depth, style_value) or { return none }
	if parsed_value.is_integer() || parsed_value.is_calculated() {
		return int_from_style_value(parsed_value)
	}
	return none
}

fn computed_interpolation_percentage_from_dom_style_value(style_value &dom.StyleValue) ?Percentage {
	if style_value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(style_value.css_value_handle) }
		if typed.value is PercentageStyleValue {
			return typed.value.percentage()
		}
		return none
	}
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
	if parsed_value := typed_style_value_logic_from_dom(style_value) {
		return parsed_value
	}
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

pub fn StyleComputer.compute_font_variation_settings(absolutized_value &dom.StyleValue, computation_context ComputationContext) &dom.StyleValue {
	_ = computation_context
	// https://drafts.csswg.org/css-fonts-4/#font-variation-settings-def
	// https://drafts.csswg.org/css-fonts/#font-feature-settings-prop
	// NB: The computation logic is the same for both font-feature-settings and font-variation-settings, first we
	//     deduplicate feature tags (with latter taking precedence), then we sort them in ascending order by code unit
	return computed_interpolation_compute_font_feature_tag_value_list(absolutized_value, .font_variation_settings) or { unsafe { absolutized_value } }
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
		if length.is_absolute() {
			return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(length.absolute_length_to_px()))))
		}
		if length.is_font_relative() {
			font_metrics := computed_interpolation_font_metrics_for_size(computed_font_size)
			resolved := length.font_relative_length_to_px(font_metrics, LengthFontMetrics.default())
			return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(resolved))))
		}
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(length)))
	}
	if number := computed_interpolation_number_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(number)))
	}

	// NOTE: We also support calc()'d lengths (percentages resolve to lengths so we don't have to handle them separately)
	if calculated_length := computed_interpolation_calculated_length_from_dom_style_value(absolutized_value, computed_font_size) {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(calculated_length)))
	}

	// NOTE: We also support calc()'d numbers
	if calculated_number := computed_interpolation_calculated_number_from_dom_style_value(absolutized_value, computed_font_size) {
		return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(calculated_number)))
	}

	// <percentage [0,∞]>
	if percentage := computed_interpolation_percentage_from_dom_style_value(absolutized_value) {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(computed_font_size.to_double() * percentage.as_fraction()))))
	}

	return unsafe { absolutized_value }
}

pub fn StyleComputer.compute_opacity(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// https://drafts.csswg.org/css-color-4/#transparency
	// specified number, clamped to the range [0,1]
	typed := typed_style_value_logic_from_dom(absolutized_value) or {
		return unsafe { absolutized_value }
	}
	value := match typed {
		NumberStyleValue {
			clamp_f64(typed.number(), 0.0, 1.0)
		}
		CalculatedStyleValue {
			if typed.resolves_to_number() {
				typed.resolve_number(CalculationResolutionContext{}) or {
					return unsafe { absolutized_value }
				}
			} else if typed.resolves_to_percentage() {
				percentage := typed.resolve_percentage(CalculationResolutionContext{}) or {
					return unsafe { absolutized_value }
				}
				percentage.as_fraction()
			} else {
				return unsafe { absolutized_value }
			}
		}
		PercentageStyleValue {
			clamp_f64(typed.percentage().as_fraction(), 0.0, 1.0)
		}
		else {
			return unsafe { absolutized_value }
		}
	}
	return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(value)))
}

pub fn StyleComputer.compute_position_area(absolutized_value &dom.StyleValue) &dom.StyleValue {
	// The computed value has two axis keywords in grammar order, with the
	// long block/inline logical spellings converted to their short forms.
	typed := typed_style_value_logic_from_dom(absolutized_value) or {
		return unsafe { absolutized_value }
	}
	if typed is KeywordStyleValue {
		return unsafe { absolutized_value }
	}
	if typed !is StyleValueList {
		return unsafe { absolutized_value }
	}
	value_list := typed as StyleValueList
	if value_list.values_.len != 2 {
		return unsafe { absolutized_value }
	}

	block_value := value_list.values_[0]
	inline_value := value_list.values_[1]
	if block_value !is KeywordStyleValue {
		return unsafe { absolutized_value }
	}
	if inline_value !is KeywordStyleValue {
		return unsafe { absolutized_value }
	}
	block_keyword := (block_value as KeywordStyleValue).keyword()
	inline_keyword := (inline_value as KeywordStyleValue).keyword()

	if block_keyword == .span_all {
		keyword := match inline_keyword {
			.start { Keyword.inline_start }
			.end_ { Keyword.inline_end }
			.self_start { Keyword.self_inline_start }
			.self_end { Keyword.self_inline_end }
			.span_start { Keyword.span_inline_start }
			.span_end { Keyword.span_inline_end }
			.span_self_start { Keyword.span_self_inline_start }
			.span_self_end { Keyword.span_self_inline_end }
			else {
				return unsafe { absolutized_value }
			}
		}
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
	}
	if inline_keyword == .span_all {
		keyword := match block_keyword {
			.start { Keyword.block_start }
			.end_ { Keyword.block_end }
			.self_start { Keyword.self_block_start }
			.self_end { Keyword.self_block_end }
			.span_start { Keyword.span_block_start }
			.span_end { Keyword.span_block_end }
			.span_self_start { Keyword.span_self_block_start }
			.span_self_end { Keyword.span_self_block_end }
			else {
				return unsafe { absolutized_value }
			}
		}
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
	}

	short_block_keyword := position_area_short_keyword(block_keyword)
	short_inline_keyword := position_area_short_keyword(inline_keyword)
	if short_block_keyword == block_keyword && short_inline_keyword == inline_keyword {
		return unsafe { absolutized_value }
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create([
		StyleValue(KeywordStyleValue.create(short_block_keyword)),
		StyleValue(KeywordStyleValue.create(short_inline_keyword)),
	], .space, .yes)))
}

fn position_area_short_keyword(keyword Keyword) Keyword {
	return match keyword {
		.block_start, .inline_start { .start }
		.block_end, .inline_end { .end_ }
		.self_block_start, .self_inline_start { .self_start }
		.self_block_end, .self_inline_end { .self_end }
		.span_block_start, .span_inline_start { .span_start }
		.span_block_end, .span_inline_end { .span_end }
		.span_self_block_start, .span_self_inline_start { .span_self_start }
		.span_self_block_end, .span_self_inline_end { .span_self_end }
		else { keyword }
	}
}

pub fn (s &StyleComputer) build_matching_rule_set(abstract_element dom.AbstractElement, mut attempted_pseudo_class_matches PseudoClassBitmap, did_match_any_pseudo_element_rules &bool, mode ComputeStyleMode, scope &StyleScope) MatchingRuleSet {
	return style_computer_build_matching_rule_set_impl(s, abstract_element, mut attempted_pseudo_class_matches, did_match_any_pseudo_element_rules, mode, scope)
}

// The preliminary writing-mode/direction cascade is needed only when a declaration
// may map logical longhands. The complete cascade still computes both properties.
// HTML presentational hints use physical longhands; other namespaces stay conservative.
fn declaration_may_have_logical_aliases(declaration &CSSStyleProperties) bool {
	_ = declaration_style_properties(declaration)
	return declaration.typed_may_have_logical_aliases_
}

fn matching_rules_may_have_logical_aliases(rules []ScopedMatchingRule) bool {
	for scoped_rule in rules {
		rule := scoped_rule.rule.rule or { continue }
		declaration := rule.style() or { continue }
		if declaration_may_have_logical_aliases(declaration) {
			return true
		}
	}
	return false
}

fn cascade_may_have_logical_aliases(abstract_element dom.AbstractElement, matching_rule_set MatchingRuleSet) bool {
	if !abstract_element.element().is_html_element() {
		return true
	}
	if matching_rules_may_have_logical_aliases(matching_rule_set.user_agent_rules)
		|| matching_rules_may_have_logical_aliases(matching_rule_set.user_rules) {
		return true
	}
	for layer in matching_rule_set.author_rules {
		if matching_rules_may_have_logical_aliases(layer.rules) {
			return true
		}
	}
	if abstract_element.pseudo_element() == none {
		if inline_declaration := inline_style_for_abstract_element(abstract_element) {
			if declaration_may_have_logical_aliases(inline_declaration) {
				return true
			}
		}
	}
	return false
}

fn (s &StyleComputer) logical_alias_context_for_cascade(abstract_element dom.AbstractElement, mode ComputeStyleMode, matching_rule_set MatchingRuleSet) LogicalAliasMappingContext {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_logical_mapping')
	defer { load_instruction_stage.finish() }
	if cascade_may_have_logical_aliases(abstract_element, matching_rule_set) {
		return s.compute_logical_alias_mapping_context(abstract_element, mode, matching_rule_set)
	}
	// This context will not be consumed: the cascade has no logical aliases.
	return LogicalAliasMappingContext{}
}

pub fn (s &StyleComputer) compute_logical_alias_mapping_context(abstract_element dom.AbstractElement, mode ComputeStyleMode, matching_rule_set MatchingRuleSet) LogicalAliasMappingContext {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(7, diagnostic_scope_start) }

	// StyleComputer::compute_logical_alias_mapping_context (StyleComputer.cpp:1408): cascade only
	// writing-mode + direction, normalize each to a concrete keyword, and build the flow-relative context
	// used to resolve logical property aliases (e.g. margin-inline-start -> margin-left/right).
	did_match_any_pseudo_element_rules := false
	properties_to_cascade := [PropertyID.writing_mode, PropertyID.direction]
	mut cascade := s.acquire_cascade_scratch()
	defer { cascade.finish() }
	mut cascaded_properties := cascade.properties
	s.compute_cascaded_values_into(mut cascaded_properties, abstract_element, did_match_any_pseudo_element_rules, mode, matching_rule_set, none, properties_to_cascade)

	writing_mode_value := logical_alias_normalize_value(abstract_element, .writing_mode, cascaded_properties.property(.writing_mode))
	direction_value := logical_alias_normalize_value(abstract_element, .direction, cascaded_properties.property(.direction))

	writing_mode_keyword := computed_interpolation_style_value_keyword(writing_mode_value) or {
		Keyword.horizontal_tb
	}
	direction_keyword := computed_interpolation_style_value_keyword(direction_value) or {
		Keyword.ltr
	}

	return LogicalAliasMappingContext{
		writing_mode: keyword_to_writing_mode(writing_mode_keyword) or { WritingMode.horizontal_tb }
		direction: keyword_to_direction(direction_keyword) or { Direction.ltr }
	}
}

fn custom_property_bridge_value(value &dom.StyleValue) &dom.CSSStyleValue_ {
	// Cascade maps are temporary; values installed on an element are not.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	typed := typed_style_value_logic_from_dom(value)
	if resolved := typed {
		if resolved.type_() == .guaranteed_invalid {
			return &dom.CSSStyleValue_{
				guaranteed_invalid: true
				css_value_handle: voidptr(value)
			}
		}
	}
	return &dom.CSSStyleValue_{
		css_text: dom_style_value_to_css_text(value)
		css_value_handle: voidptr(value)
	}
}

fn custom_property_from_style_property(property StyleProperty) dom.CSSCustomProperty_ {
	return dom.CSSCustomProperty_{
		important: property.important == .yes
		value: custom_property_bridge_value(property.value)
	}
}

fn cascade_custom_properties_from_declaration(declaration &CSSStyleProperties, mut values map[string]dom.CSSCustomProperty_, mut important_values map[string]dom.CSSCustomProperty_) {
	for name, style_property in declaration.custom_properties {
		typed := typed_style_value_logic_from_dom(style_property.value)
		if value := typed {
			if value.to_keyword() == .revert_layer {
				continue
			}
		}
		property := custom_property_from_style_property(style_property)
		if property.important {
			important_values[name] = property
		}
		values[name] = property
	}
}

fn custom_property_bridge_values_equal(left &dom.CSSStyleValue_, right &dom.CSSStyleValue_) bool {
	if voidptr(left) == voidptr(right) {
		return true
	}
	if left.css_value_handle != unsafe { nil } && right.css_value_handle != unsafe { nil } {
		if left.css_value_handle == right.css_value_handle {
			return true
		}
		left_value := unsafe { &dom.StyleValue(left.css_value_handle) }
		right_value := unsafe { &dom.StyleValue(right.css_value_handle) }
		if left_typed := typed_style_value_logic_from_dom(left_value) {
			if right_typed := typed_style_value_logic_from_dom(right_value) {
				return left_typed.equals(right_typed)
			}
		}
		return voidptr(left_value) == voidptr(right_value)
	}
	return left.guaranteed_invalid == right.guaranteed_invalid && left.css_text == right.css_text
}

// A bridge without a typed handle must keep the CSS-text comparison above.
// All typed cases can be compared before allocating a temporary DOM bridge.
fn (value ComputedCustomPropertyValue) equals_typed_bridge(other &dom.CSSStyleValue_) ?bool {
	if other.css_value_handle == unsafe { nil } {
		return none
	}
	other_value := unsafe { &dom.StyleValue(other.css_value_handle) }
	if value.kind == .existing && voidptr(other_value) == voidptr(value.existing_value) {
		return true
	}
	other_typed := typed_style_value_logic_from_dom(other_value) or { return false }
	return match value.kind {
		.existing {
			typed := typed_style_value_logic_from_dom(value.existing_value) or { return false }
			other_typed.equals(typed)
		}
		.substituted {
			if other_typed is UnresolvedStyleValue {
				// This is precisely UnresolvedStyleValue.equals(), including token
				// payloads, source positions, nested values and attribute taint.
				other_typed.tokens == value.tokens
			} else {
				false
			}
		}
		.guaranteed_invalid { other_typed is GuaranteedInvalidStyleValue }
	}
}

fn custom_property_bridge_values_identical(left &dom.CSSStyleValue_, right &dom.CSSStyleValue_) bool {
	if left.css_value_handle != unsafe { nil } && right.css_value_handle != unsafe { nil } {
		return left.css_value_handle == right.css_value_handle
	}
	return voidptr(left) == voidptr(right)
}

fn custom_property_maps_equal(left map[string]dom.CSSCustomProperty_, right map[string]dom.CSSCustomProperty_) bool {
	return compare_custom_property_maps(left, right, false)
}

fn compare_custom_property_maps(left map[string]dom.CSSCustomProperty_,
	right map[string]dom.CSSCustomProperty_, require_retained_identity bool) bool {
	if left.len != right.len {
		return false
	}
	if left.len == 0 { return true }
	// V clones string map keys during iteration. Equality publishes only a
	// boolean, so those keys and temporary typed-value projections can be freed
	// after the comparison instead of accumulating in the style owner's arena.
	mut scratch := platform.begin_thread_scratch('custom property comparison')
	defer { scratch.finish() }
	for name, left_property in left {
		if name !in right { return false }
		// Compare the live map entry synchronously. Passing an optional value to
		// the bridge comparison heap-boxes it in the compatibility compiler.
		right_property := unsafe { &right[name] }
		if left_property.important != right_property.important
			|| (require_retained_identity && (left_property.value.css_text != right_property.value.css_text
				|| left_property.value.guaranteed_invalid != right_property.value.guaranteed_invalid))
			|| !(if require_retained_identity {
				custom_property_environment_values_equivalent(left_property.value, right_property.value)
			} else {
				custom_property_bridge_values_equal(left_property.value, right_property.value)
			}) {
			return false
		}
	}
	return true
}

// StyleComputer.cpp:cascade_custom_properties. Important declarations are
// collected while walking the matching rules and applied after normal ones.
fn custom_cascade_rule_declaration(rule &CSSRule) ?&CSSStyleProperties {
	// Deferred parsing and its CSSOM cache belong to the declaration owner.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	return rule.style()
}

fn custom_cascade_inline_declaration(element dom.AbstractElement) ?&CSSStyleProperties {
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	return inline_style_for_abstract_element(element)
}

fn cascade_custom_properties(abstract_element dom.AbstractElement, rules []ScopedMatchingRule, mut values map[string]dom.CSSCustomProperty_) {
	mut important_values := map[string]dom.CSSCustomProperty_{}
	for scoped_rule in rules {
		rule := scoped_rule.rule.rule or { continue }
		declaration := custom_cascade_rule_declaration(rule) or { continue }
		cascade_custom_properties_from_declaration(declaration, mut values, mut important_values)
	}
	if abstract_element.pseudo_element() == none {
		if inline_declaration := custom_cascade_inline_declaration(abstract_element) {
			cascade_custom_properties_from_declaration(inline_declaration, mut values, mut important_values)
		}
	}
	for name, property in important_values {
		values[name] = property
	}
}

fn custom_property_own_values_differ(left ?&dom.CSSCustomPropertyData_, right ?&dom.CSSCustomPropertyData_) bool {
	if left_data := left {
		if right_data := right {
			return !custom_property_maps_equal(left_data.own_values, right_data.own_values)
		}
		return left_data.own_values.len != 0
	}
	if right_data := right {
		return right_data.own_values.len != 0
	}
	return false
}

$if test {
	fn custom_property_own_values_equal(left ?&dom.CSSCustomPropertyData_, right ?&dom.CSSCustomPropertyData_) bool {
		return !custom_property_own_values_differ(left, right)
	}
}

fn optional_custom_property_data_identity_equal(left ?&dom.CSSCustomPropertyData_, right ?&dom.CSSCustomPropertyData_) bool {
	if left_data := left {
		right_data := right or { return false }
		return voidptr(left_data) == voidptr(right_data)
	}
	return right == none
}

fn custom_property_environment_under_overlay(data ?&dom.CSSCustomPropertyData_) ?&dom.CSSCustomPropertyData_ {
	if current := data {
		if current.is_animation_overlay() {
			return current.parent
		}
		return current
	}
	return none
}

fn report_custom_property_change(old_data ?&dom.CSSCustomPropertyData_, new_data ?&dom.CSSCustomPropertyData_) bool {
	if optional_custom_property_data_identity_equal(old_data, new_data) {
		return false
	}
	old_environment := custom_property_environment_under_overlay(old_data)
	new_environment := custom_property_environment_under_overlay(new_data)
	if !optional_custom_property_data_identity_equal(old_environment, new_environment) {
		mut old_inherited := ?&dom.CSSCustomPropertyData_(none)
		mut new_inherited := ?&dom.CSSCustomPropertyData_(none)
		if environment := old_environment {
			old_inherited = environment.parent
		}
		if environment := new_environment {
			new_inherited = environment.parent
		}
		if !optional_custom_property_data_identity_equal(old_inherited, new_inherited)
			|| custom_property_own_values_differ(old_environment, new_environment) {
			return true
		}
	}
	old_is_overlay := if current := old_data { current.is_animation_overlay() } else { false }
	new_is_overlay := if current := new_data { current.is_animation_overlay() } else { false }
	if !old_is_overlay && !new_is_overlay {
		return false
	}
	old_overlay := if old_is_overlay { old_data } else { ?&dom.CSSCustomPropertyData_(none) }
	new_overlay := if new_is_overlay { new_data } else { ?&dom.CSSCustomPropertyData_(none) }
	return custom_property_own_values_differ(old_overlay, new_overlay)
}

fn reuse_unchanged_custom_property_environment(previous ?&dom.CSSCustomPropertyData_,
	current ?&dom.CSSCustomPropertyData_) ?&dom.CSSCustomPropertyData_ {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(9, diagnostic_scope_start) }

	old_data := previous or { return current }
	new_data := current or { return current }
	if voidptr(old_data) == voidptr(new_data) { return current }
	// Animation samples own a distinct mutable overlay. Only ordinary resolved
	// environments can keep the prior record and its generation-checked cache.
	if old_data.is_animation_overlay() || new_data.is_animation_overlay()
		|| old_data.ancestor_count != new_data.ancestor_count
		|| !optional_custom_property_data_identity_equal(old_data.parent, new_data.parent)
		|| !compare_custom_property_maps(old_data.own_values, new_data.own_values, true) {
		return current
	}
	return previous
}

fn set_custom_properties_changed(did_change &bool) {
	unsafe {
		*did_change = true
	}
}

fn inheritable_custom_property_data(abstract_element dom.AbstractElement) ?&dom.CSSCustomPropertyData_ {
	data := abstract_element.custom_property_data() or { return none }
	return data.inheritable(abstract_element.document())
}

fn has_cascaded_custom_property_declarations(abstract_element dom.AbstractElement, matching_rule_set MatchingRuleSet) bool {
	for layer in matching_rule_set.author_rules {
		for scoped_rule in layer.rules {
			rule := scoped_rule.rule.rule or { continue }
			declaration := rule.style() or { continue }
			if declaration.custom_properties.len != 0 {
				return true
			}
		}
	}
	// Inline declarations enter the existing cascade through an author layer.
	if matching_rule_set.author_rules.len != 0 {
		if declaration := inline_style_for_abstract_element(abstract_element) {
			return declaration.custom_properties.len != 0
		}
	}
	return false
}

fn install_custom_property_data_for_style(abstract_element dom.AbstractElement, matching_rule_set MatchingRuleSet) {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_custom_properties')
	defer { load_instruction_stage.finish() }
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(8, diagnostic_scope_start) }

	// With no own declarations, inheritance is the complete result. Animation
	// overlays still use the ordinary path to retain their separate sampled layer.
	previous_data := abstract_element.custom_property_data()
	has_overlay := if data := previous_data { data.is_animation_overlay() } else { false }
	if !has_overlay && !has_cascaded_custom_property_declarations(abstract_element, matching_rule_set) {
		mut inherited := ?&dom.CSSCustomPropertyData_(none)
		if parent := abstract_element.element_to_inherit_style_from() {
			inherited = inheritable_custom_property_data(parent)
		}
		mut mutable_element := abstract_element
		mutable_element.set_custom_property_data(inherited)
		return
	}
	// Resolve inheritance before entering temporary storage: inheritable() can
	// publish a generation-checked cache on the parent's environment.
	mut parent_data := ?&dom.CSSCustomPropertyData_(none)
	if parent := abstract_element.element_to_inherit_style_from() {
		parent_data = inheritable_custom_property_data(parent)
	}
	scratch := if platform.current_retained_arena() != unsafe { nil } {
		platform.begin_thread_scratch('custom property cascade maps')
	} else {
		platform.ThreadScratchScope{}
	}
	defer { scratch.finish() }
	mut had_animation_overlay := false
	mut animated_values := map[string]dom.CSSCustomProperty_{}
	if existing := abstract_element.custom_property_data() {
		if existing.is_animation_overlay() {
			had_animation_overlay = true
			animated_values = existing.own_values
		}
	}
	mut cascaded_all := map[string]dom.CSSCustomProperty_{}
	for layer in matching_rule_set.author_rules {
		cascade_custom_properties(abstract_element, layer.rules, mut cascaded_all)
	}

	// Build own_values with only declarations whose retained StyleValue differs
	// from the parent's, matching the pointer-identity check in C++.
	mut cascaded_own := map[string]dom.CSSCustomProperty_{}
	for name, property in cascaded_all {
		if parent := parent_data {
			if parent_property := parent.get_property(name) {
				if custom_property_bridge_values_identical(parent_property.value, property.value) {
					continue
				}
			}
		}
		cascaded_own[name] = property
	}

	// create() copies the winning map, including keys, into the element owner.
	// Intermediate cascade maps can retire after publication.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut mutable_abstract_element := abstract_element
	if cascaded_own.len == 0 {
		if parent := parent_data {
			mutable_abstract_element.set_custom_property_data(parent)
		} else {
			mutable_abstract_element.set_custom_property_data(none)
		}
	} else {
		mutable_abstract_element.set_custom_property_data(dom.CSSCustomPropertyData_.create(cascaded_own, parent_data))
	}
	if had_animation_overlay {
		base := mutable_abstract_element.custom_property_data()
		mutable_abstract_element.set_custom_property_data(dom.CSSCustomPropertyData_.create_animation_overlay(animated_values,
			base))
	}
}

pub fn (s &StyleComputer) compute_style_impl(abstract_element dom.AbstractElement, mode ComputeStyleMode, did_change_custom_properties ?&bool, scope &StyleScope) ?&ComputedProperties {
	s.begin_computed_property_page_batch()
	defer { s.end_computed_property_page_batch() }
	computed := s.compute_style_impl_with_animated_custom_property_recompute(abstract_element, mode,
		did_change_custom_properties, scope, true) or { return none }
	s.publish_computed_property_pages(computed)
	return computed
}

fn (s &StyleComputer) compute_style_impl_with_animated_custom_property_recompute(abstract_element dom.AbstractElement, mode ComputeStyleMode, did_change_custom_properties ?&bool, scope &StyleScope, allow_animated_custom_property_recompute bool) ?&ComputedProperties {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_construction')
	defer { load_instruction_stage.finish() }
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(5, diagnostic_scope_start) }

	mut profile_checkpoint := if css_style_profile_enabled { time.sys_mono_now() } else { u64(0) }
	// StyleComputer::compute_style_impl (StyleComputer.cpp:1806).
	scope.build_rule_cache_if_needed()

	// Special path for elements representing a pseudo-element in an element's
	// internal user-agent shadow tree.
	if raw_pseudo_element := abstract_element.element().associated_shadow_host_pseudo_element() {
		if raw_pseudo_element >= 0 && raw_pseudo_element < int(PseudoElement.known_pseudo_element_count) {
			element := abstract_element.element()
			root := element.as_node().root()
			host_element := root.parent_or_shadow_host_element() or { return none }
			dom_pseudo_element := unsafe { dom.PseudoElement(raw_pseudo_element) }
			mut pseudo_abstract_element := dom.AbstractElement.new(host_element, dom_pseudo_element)
			if parent_element := element.as_node().parent_element() {
				pseudo_abstract_element.set_inheritance_override(parent_element)
			} else {
				pseudo_abstract_element.set_inheritance_override(host_element)
			}

			mut style := s.compute_style(pseudo_abstract_element)

			// Internal shadow-tree nodes may still carry inline declarations. Merge
			// those after the pseudo-element style, as upstream does. Logical aliases
			// are resolved against the inherited pseudo-element flow before entering
			// the physical computed-longhand table.
			if inline_declaration := inline_style_for_abstract_element(abstract_element) {
				logical_context := LogicalAliasMappingContext{
					writing_mode: style.writing_mode()
					direction: style.direction()
				}
				for property in declaration_style_properties(inline_declaration) {
					for longhand in expand_property_longhands(property.property_id, property.value) {
						physical_id := if property_is_logical_alias(longhand.id) {
							map_logical_alias_to_physical_property(longhand.id, logical_context)
						} else {
							longhand.id
						}
						style.set_property_without_modifying_flags(physical_id, longhand.value)
					}
				}
			}
			adjust_element_computed_style(mut style, element)
			return style
		}
	}

	defer {
		mut mutable_element := unsafe { &dom.Element(abstract_element.element()) }
		mutable_element.set_needs_style_update(false)
	}

	if mode == .create_pseudo_element_style_if_needed
		&& scope.generated_pseudo_has_no_content_candidates(abstract_element, s) {
		return none
	}

	// 1. Perform the cascade. This produces the "specified style".
	mut did_match_any_pseudo_element_rules := false
	mut attempted_pseudo_class_matches := PseudoClassBitmap{}
	mut matching_workspace := s.acquire_matching_rule_set_workspace()
	defer { matching_workspace.finish() }
	matching_instruction_stage := processmetrics.begin_thread_instruction_substage('style_rule_matching')
	matching_rule_set := build_matching_rule_set_with_storage(s, abstract_element,
		mut attempted_pseudo_class_matches, &did_match_any_pseudo_element_rules, mode, scope,
		matching_workspace.arena)
	matching_instruction_stage.finish()
	next_matching_checkpoint, matching_elapsed := css_style_profile_checkpoint(profile_checkpoint)
	profile_checkpoint = next_matching_checkpoint
	css_style_profile_matching_ns += matching_elapsed

	if mode == .create_pseudo_element_style_if_needed {
		pseudo_element := abstract_element.pseudo_element() or { return none }
		has_implicit_style := pseudo_element in [.details_content, .file_selector_button, .marker,
			.placeholder]
		if !did_match_any_pseudo_element_rules && !has_implicit_style {
			return none
		}
		if pseudo_element in [.before, .after]
			&& generated_pseudo_has_no_content_declaration(matching_rule_set) {
			return none
		}
	}

	old_custom_property_data := abstract_element.custom_property_data()
	install_custom_property_data_for_style(abstract_element, matching_rule_set)
	next_custom_checkpoint, custom_elapsed := css_style_profile_checkpoint(profile_checkpoint)
	profile_checkpoint = next_custom_checkpoint
	css_style_profile_custom_ns += custom_elapsed

	logical_alias_mapping_context := s.logical_alias_context_for_cascade(abstract_element, mode, matching_rule_set)
	next_logical_checkpoint, logical_elapsed := css_style_profile_checkpoint(profile_checkpoint)
	profile_checkpoint = next_logical_checkpoint
	css_style_profile_logical_ns += logical_elapsed
	mut cascade := s.acquire_cascade_scratch()
	defer { cascade.finish() }
	mut cascaded_properties := cascade.properties
	s.compute_cascaded_values_into(mut cascaded_properties, abstract_element, did_match_any_pseudo_element_rules, mode, matching_rule_set, logical_alias_mapping_context, []PropertyID{})
	next_cascade_checkpoint, cascade_elapsed := css_style_profile_checkpoint(profile_checkpoint)
	profile_checkpoint = next_cascade_checkpoint
	css_style_profile_cascade_ns += cascade_elapsed
	if mode == .create_pseudo_element_style_if_needed {
		pseudo_element := abstract_element.pseudo_element() or { return none }
		content_value := cascaded_properties.property(.content)
		mut content_is_normal := content_value == none
		if content := content_value {
			keyword := computed_interpolation_style_value_keyword(content) or { Keyword.invalid }
			if keyword == .none_ {
				return none
			}
			content_is_normal = keyword == .normal
		}
		if content_is_normal && pseudo_element in [.before, .after] {
			return none
		}
	}

	mut computed_properties := s.compute_properties(abstract_element, mut cascaded_properties)
	old_had_animation_overlay := if old_data := old_custom_property_data {
		old_data.is_animation_overlay()
	} else {
		false
	}
	new_has_animation_overlay := if new_data := abstract_element.custom_property_data() {
		new_data.is_animation_overlay()
	} else {
		false
	}
	if allow_animated_custom_property_recompute
		&& (computed_properties.has_animated_custom_properties()
			|| (old_had_animation_overlay && !new_has_animation_overlay)) {
		recomputed := s.compute_style_impl_with_animated_custom_property_recompute(abstract_element,
			mode, did_change_custom_properties, scope, false) or { return none }
		if did_change := did_change_custom_properties {
			if report_custom_property_change(old_custom_property_data,
				abstract_element.custom_property_data()) {
				unsafe { set_custom_properties_changed(did_change) }
			}
		}
		return recomputed
	}
	_, compute_elapsed := css_style_profile_checkpoint(profile_checkpoint)
	css_style_profile_compute_ns += compute_elapsed
	computed_properties.set_attempted_pseudo_class_matches(attempted_pseudo_class_matches)
	// Keep unchanged resolved environments shared with inherited descendants.
	// Replacing an equal root record would otherwise force every descendant to
	// compare the root's complete custom-property map during the same style pass.
	mut mutable_abstract_element := abstract_element
	mutable_abstract_element.set_custom_property_data(reuse_unchanged_custom_property_environment(
		old_custom_property_data, abstract_element.custom_property_data()))
	if did_change := did_change_custom_properties {
		new_custom_property_data := abstract_element.custom_property_data()
		if report_custom_property_change(old_custom_property_data, new_custom_property_data) {
			unsafe { set_custom_properties_changed(did_change) }
		}
	}
	return computed_properties
}

__global (
	css_style_profile_enabled     bool
	css_style_profile_matching_ns u64
	css_style_profile_custom_ns   u64
	css_style_profile_logical_ns  u64
	css_style_profile_cascade_ns  u64
	css_style_profile_compute_ns  u64
)

fn css_style_profile_checkpoint(previous u64) (u64, u64) {
	if !css_style_profile_enabled {
		return 0, 0
	}
	now := time.sys_mono_now()
	return now, now - previous
}

pub fn begin_style_profile() {
	css_style_profile_enabled = os.getenv('LADYBIRD_DEBUG_TIMING') != ''
	css_style_profile_matching_ns = 0
	css_style_profile_custom_ns = 0
	css_style_profile_logical_ns = 0
	css_style_profile_cascade_ns = 0
	css_style_profile_compute_ns = 0
}

pub fn end_style_profile() {
	if !css_style_profile_enabled {
		return
	}
	eprintln('Ladybird V timing:       match ${css_style_profile_matching_ns / 1_000_000} ms')
	eprintln('Ladybird V timing:       custom ${css_style_profile_custom_ns / 1_000_000} ms')
	eprintln('Ladybird V timing:       logical ${css_style_profile_logical_ns / 1_000_000} ms')
	eprintln('Ladybird V timing:       cascade ${css_style_profile_cascade_ns / 1_000_000} ms')
	eprintln('Ladybird V timing:       compute ${css_style_profile_compute_ns / 1_000_000} ms')
	css_style_profile_enabled = false
}

pub fn (s &StyleComputer) compute_cascaded_values(abstract_element dom.AbstractElement, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, matching_rule_set MatchingRuleSet, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade ComputedInterpolationPropertyIDs) &CascadedProperties {
	mut cascaded_properties := CascadedProperties.new()
	s.compute_cascaded_values_into(mut cascaded_properties, abstract_element, did_match_any_pseudo_element_rules, mode, matching_rule_set, logical_alias_mapping_context, properties_to_cascade)
	return cascaded_properties
}

fn (s &StyleComputer) compute_cascaded_values_into(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, matching_rule_set MatchingRuleSet, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade ComputedInterpolationPropertyIDs) {
	load_instruction_stage := processmetrics.begin_thread_instruction_substage('style_cascade')
	defer { load_instruction_stage.finish() }
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(6, diagnostic_scope_start) }

	if mode == .create_pseudo_element_style_if_needed {
		if !did_match_any_pseudo_element_rules {
			return
		}
	}

	// Normal user agent declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_agent_rules, .user_agent, .no, none, logical_alias_mapping_context, properties_to_cascade)

	// Normal user declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_rules, .user, .no, none, logical_alias_mapping_context, properties_to_cascade)

	// Element::apply_presentational_hints(). These occupy their own origin
	// between user and author rules and travel through the ordinary property
	// cascade so substitution and invalid-at-computed-value-time handling are
	// shared with declarations.
	if abstract_element.pseudo_element() == none {
		mut hints := []StyleProperty{}
		collect_element_presentational_hints(mut hints, abstract_element.element(), properties_to_cascade)
		if abstract_element.element().is_html_element() {
			collect_html_presentational_hints(mut hints, abstract_element.element(), properties_to_cascade)
		} else if abstract_element.element().is_svg_element() {
			collect_svg_presentational_hints(mut hints, abstract_element.element(), properties_to_cascade)
		}
		apply_property_list_to_cascade(mut cascaded_properties, abstract_element, hints, .author_presentational_hint, .no, none, unsafe { nil }, none, logical_alias_mapping_context, properties_to_cascade)
	}

	// Normal author declarations, ordered by @layer, with un-@layer-ed rules last.
	for layer in matching_rule_set.author_rules {
		s.cascade_declarations(mut cascaded_properties, abstract_element, layer.rules, .author, .no, layer.qualified_layer_name, logical_alias_mapping_context, properties_to_cascade)
	}
	if override := s.position_try_override_ {
		if voidptr(override.target.element()) == voidptr(abstract_element.element())
			&& override.target.pseudo_element() == abstract_element.pseudo_element() {
			cascade_one_declaration(mut cascaded_properties,abstract_element,override.declaration,none,.author,.no,'\x00position-try',logical_alias_mapping_context,properties_to_cascade)
		}
	}

	// Important author declarations, with un-@layer-ed rules first, followed by each @layer in reverse order.
	for i := matching_rule_set.author_rules.len - 1; i >= 0; i-- {
		layer := matching_rule_set.author_rules[i]
		s.cascade_declarations(mut cascaded_properties, abstract_element, layer.rules, .author, .yes, none, logical_alias_mapping_context, properties_to_cascade)
	}

	// Important user declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_rules, .user, .yes, none, logical_alias_mapping_context, properties_to_cascade)

	// Important user agent declarations
	s.cascade_declarations(mut cascaded_properties, abstract_element, matching_rule_set.user_agent_rules, .user_agent, .yes, none, logical_alias_mapping_context, properties_to_cascade)

}

fn set_html_presentational_hint(mut properties []StyleProperty, properties_to_cascade ComputedInterpolationPropertyIDs, property_id PropertyID, value StyleValue) {
	if properties_to_cascade.len > 0 && property_id !in properties_to_cascade {
		return
	}
	properties << StyleProperty{
		property_id: property_id
		value: dom_style_value_from_value_logic(value)
	}
}

// DOM::Element::apply_presentational_hints(). The DOM module cannot own this
// method directly because CSS style values depend on DOM, so keep the behavior
// at the existing cascade bridge.
fn collect_element_presentational_hints(mut properties []StyleProperty, element &dom.Element, properties_to_cascade ComputedInterpolationPropertyIDs) {
	if element.matches_link_pseudo_class() {
		if color := element.document().normal_link_color() {
			value := StyleValue(ColorStyleValue.create_from_color(Color.rgba(color.r, color.g, color.b, color.a), .legacy, none))
			set_html_presentational_hint(mut properties, properties_to_cascade, .color, value)
		}
	}
	if element.matches_visited_pseudo_class() {
		if color := element.document().visited_link_color() {
			value := StyleValue(ColorStyleValue.create_from_color(Color.rgba(color.r, color.g, color.b, color.a), .legacy, none))
			set_html_presentational_hint(mut properties, properties_to_cascade, .color, value)
		}
	}
	if element.is_being_activated()
		&& (element.matches_link_pseudo_class() || element.matches_visited_pseudo_class()) {
		if color := element.document().active_link_color() {
			value := StyleValue(ColorStyleValue.create_from_color(Color.rgba(color.r, color.g, color.b, color.a), .legacy, none))
			set_html_presentational_hint(mut properties, properties_to_cascade, .color, value)
		}
	}
}

fn html_dimension_presentational_hint(source string, property_id PropertyID, reject_zero bool) ?StyleValue {
	return html_dimension_presentational_hint_with_precision(source, property_id, reject_zero, false)
}

fn html_dimension_presentational_hint_with_precision(source string, property_id PropertyID, reject_zero bool, retain_fraction bool) ?StyleValue {
	_ = property_id
	// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-dimension-values
	mut position := 0
	for position < source.len && source[position] in [`\t`, `\n`, `\f`, `\r`, ` `] {
		position++
	}
	if position >= source.len || source[position] < `0` || source[position] > `9` {
		return none
	}
	start := position
	for position < source.len && source[position] >= `0` && source[position] <= `9` {
		position++
	}
	integer_value := strconv.atof64(source[start..position]) or { return none }
	mut value := f32(math.min(integer_value, f64(css_pixels_max_dimension_value)))

	if position < source.len && source[position] == `.` {
		position++
		if position < source.len && source[position] >= `0` && source[position] <= `9` {
			mut divisor := f32(1)
			for {
				divisor *= 10
				value += f32(source[position] - `0`) / divisor
				position++
				if position >= source.len || source[position] < `0` || source[position] > `9` {
					break
				}
			}
		}
	}
	if reject_zero && value == 0 {
		return none
	}
	if position < source.len && source[position] == `%` {
		return StyleValue(PercentageStyleValue.create(Percentage.new(f64(value))))
	}
	// Chromium quantizes used lengths after device projection. Rounding an
	// HTML image's fractional dimension here loses that native precision.
	pixels := if retain_fraction { f64(value) } else { CSSPixels.nearest_value_for(f64(value)).to_double() }
	return StyleValue(LengthStyleValue.create(Length.make_px(pixels)))
}

fn collect_dimension_attribute(mut properties []StyleProperty, element &dom.Element, attribute_name string, property_id PropertyID, properties_to_cascade ComputedInterpolationPropertyIDs) {
	attribute := element.get_attribute(attribute_name) or { return }
	parsed_value := html_dimension_presentational_hint_with_precision(attribute, property_id, false,
		element.document().font_rendering_policy() == .chromium) or { return }
	set_html_presentational_hint(mut properties, properties_to_cascade, property_id, parsed_value)
}

// https://html.spec.whatwg.org/multipage/rendering.html#rules-for-parsing-a-legacy-font-size
fn legacy_font_size_presentational_hint(source string) ?StyleValue {
	mut position := 0
	for position < source.len && source[position] in [`\t`, `\n`, `\f`, `\r`, ` `] {
		position++
	}
	if position == source.len {
		return none
	}
	mut mode := 0
	if source[position] == `+` {
		mode = 1
		position++
	} else if source[position] == `-` {
		mode = -1
		position++
	}
	start := position
	for position < source.len && source[position] >= `0` && source[position] <= `9` {
		position++
	}
	if position == start {
		return none
	}
	mut value := strconv.atoi(source[start..position]) or { return none }
	if mode == 1 {
		value += 3
	} else if mode == -1 {
		value = 3 - value
	}
	value = if value < 1 {
		1
	} else if value > 7 {
		7
	} else {
		value
	}
	keyword := ['x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'xxx-large'][value - 1]
	return parse_css_value_logic(.font_size, keyword)
}

fn nearest_ancestor_html_table(element &dom.Element) ?&dom.Element {
	mut ancestor := element.as_node().parent_element()
	for ancestor != none {
		candidate := ancestor or { break }
		if candidate.local_name() == 'table' {
			return candidate
		}
		ancestor = candidate.as_node().parent_element()
	}
	return none
}

fn legacy_unsigned_integer(source string) ?int {
	trimmed := source.trim_space()
	if trimmed.len == 0 {
		return none
	}
	for character in trimmed.bytes() {
		if character < `0` || character > `9` {
			return none
		}
	}
	return strconv.atoi(trimmed) or { return none }
}

fn legacy_non_negative_integer_prefix(source string) ?int {
	mut position := 0
	for position < source.len && source[position] in [`\t`, `\n`, `\f`, `\r`, ` `] {
		position++
	}
	mut sign := 1
	if position < source.len && source[position] in [`+`, `-`] {
		if source[position] == `-` {
			sign = -1
		}
		position++
	}
	start := position
	for position < source.len && source[position] >= `0` && source[position] <= `9` {
		position++
	}
	if position == start {
		return none
	}
	value := strconv.atoi(source[start..position]) or { return none }
	if sign < 0 && value != 0 {
		return none
	}
	return value
}

fn legacy_integer_prefix(source string) ?int {
	mut position := 0
	for position < source.len && source[position] in [`\t`, `\n`, `\f`, `\r`, ` `] {
		position++
	}
	mut sign := 1
	if position < source.len && source[position] in [`+`, `-`] {
		if source[position] == `-` {
			sign = -1
		}
		position++
	}
	start := position
	for position < source.len && source[position] >= `0` && source[position] <= `9` {
		position++
	}
	if position == start {
		return none
	}
	return sign * (strconv.atoi(source[start..position]) or { return none })
}

fn html_body_margin_source(element &dom.Element, first_attribute string, second_attribute string, container_attribute string) ?string {
	if value := element.get_attribute(first_attribute) {
		return value
	}
	if value := element.get_attribute(second_attribute) {
		return value
	}
	navigable := element.document().navigable() or { return none }
	container_node := navigable.container() or { return none }
	container := container_node.as_element() or { return none }
	return container.get_attribute(container_attribute)
}

fn set_html_table_border_hints(mut properties []StyleProperty, properties_to_cascade ComputedInterpolationPropertyIDs, style_keyword string, width string, color string) {
	for side in ['top', 'right', 'bottom', 'left'] {
		style_property := property_id_from_string('border-${side}-style') or { continue }
		width_property := property_id_from_string('border-${side}-width') or { continue }
		color_property := property_id_from_string('border-${side}-color') or { continue }
		if value := parse_css_value_logic(style_property, style_keyword) {
			set_html_presentational_hint(mut properties, properties_to_cascade, style_property, value)
		}
		if value := parse_css_value_logic(width_property, width) {
			set_html_presentational_hint(mut properties, properties_to_cascade, width_property, value)
		}
		if value := parse_css_value_logic(color_property, color) {
			set_html_presentational_hint(mut properties, properties_to_cascade, color_property, value)
		}
	}
}

fn collect_html_presentational_hints(mut cascaded_properties []StyleProperty, element &dom.Element, properties_to_cascade ComputedInterpolationPropertyIDs) {
	tag_name := element.local_name().to_lower()
	if tag_name == 'body' {
		if background_color := element.get_attribute('bgcolor') {
			if value := parse_css_value_logic(.background_color, background_color) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .background_color, value)
			}
		}
		if text_color := element.get_attribute('text') {
			if value := parse_css_value_logic(.color, text_color) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .color, value)
			}
		}
		if background := element.get_attribute('background') {
			if parsed_url := element.document().encoding_parse_url(background) {
				if value := parse_css_value_logic(.background_image, 'url("${parsed_url.serialize()}")') {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .background_image, value)
				}
			}
		}
		for property_id, source in {
			PropertyID.margin_top:    html_body_margin_source(element, 'marginheight', 'topmargin', 'marginheight')
			PropertyID.margin_bottom: html_body_margin_source(element, 'marginheight', 'bottommargin', 'marginheight')
			PropertyID.margin_left:   html_body_margin_source(element, 'marginwidth', 'leftmargin', 'marginwidth')
			PropertyID.margin_right:  html_body_margin_source(element, 'marginwidth', 'rightmargin', 'marginwidth')
		} {
			if source_value := source {
				if pixels := legacy_non_negative_integer_prefix(source_value) {
					if value := parse_css_value_logic(property_id, '${pixels}px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
	}
	if tag_name == 'font' {
		if color := element.get_attribute('color') {
			if value := parse_css_value_logic(.color, color) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .color, value)
			}
		}
		if size := element.get_attribute('size') {
			if value := legacy_font_size_presentational_hint(size) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .font_size, value)
			}
		}
		if face := element.get_attribute('face') {
			if value := parse_css_value_logic(.font_family, face) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .font_family, value)
			}
		}
	}
	if tag_name == 'hr' {
		has_solid_border := element.has_attribute('color') || element.has_attribute('noshade')
		if has_solid_border {
			for property_id in [PropertyID.border_top_style, .border_right_style, .border_bottom_style,
				.border_left_style] {
				if value := parse_css_value_logic(property_id, 'solid') {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
				}
			}
		}
		if align := element.get_attribute('align') {
			match align.to_lower() {
				'left' {
					if zero := parse_css_value_logic(.margin_left, '0px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_left, zero)
					}
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_right, StyleValue(KeywordStyleValue.create(.auto)))
				}
				'right' {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_left, StyleValue(KeywordStyleValue.create(.auto)))
					if zero := parse_css_value_logic(.margin_right, '0px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_right, zero)
					}
				}
				'center' {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_left, StyleValue(KeywordStyleValue.create(.auto)))
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_right, StyleValue(KeywordStyleValue.create(.auto)))
				}
				else {}
			}
		}
		if color_value := element.get_attribute('color') {
			if value := parse_css_value_logic(.color, color_value) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .color, value)
			}
		}
		if size_source := element.get_attribute('size') {
			if size := legacy_unsigned_integer(size_source) {
				if has_solid_border {
					for property_id in [PropertyID.border_top_width, .border_right_width,
						.border_bottom_width, .border_left_width] {
						if value := parse_css_value_logic(property_id, '${f64(size) / 2.0}px') {
							set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
						}
					}
				} else if size == 1 {
					if value := parse_css_value_logic(.border_bottom_width, '0px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .border_bottom_width, value)
					}
				} else if size > 1 {
					if value := parse_css_value_logic(.height, '${size - 2}px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .height, value)
					}
				}
			}
		}
		if width := element.get_attribute('width') {
			if value := html_dimension_presentational_hint(width, .width, false) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .width, value)
			}
		}
	}
	if tag_name == 'marquee' {
		if background_color := element.get_attribute('bgcolor') {
			if value := parse_css_value_logic(.background_color, background_color) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .background_color, value)
			}
		}
		for attribute, properties in {
			'height': [PropertyID.height]
			'width':  [PropertyID.width]
			'hspace': [PropertyID.margin_left, .margin_right]
			'vspace': [PropertyID.margin_top, .margin_bottom]
		} {
			if source := element.get_attribute(attribute) {
				for property_id in properties {
					if value := html_dimension_presentational_hint(source, property_id, false) {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
	}
	if tag_name == 'embed' {
		if align := element.get_attribute('align') {
			keyword := match align.to_lower() {
				'center' { Keyword.center }
				'middle' { Keyword.middle }
				else { Keyword.invalid }
			}
			if keyword != .invalid {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, StyleValue(KeywordStyleValue.create(keyword)))
			}
		}
		for attribute, properties in {
			'hspace': [PropertyID.margin_left, .margin_right]
			'vspace': [PropertyID.margin_top, .margin_bottom]
		} {
			if source := element.get_attribute(attribute) {
				for property_id in properties {
					if value := html_dimension_presentational_hint(source, property_id, false) {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
	}
	if tag_name == 'iframe' {
		if frameborder := element.get_attribute('frameborder') {
			parsed := legacy_integer_prefix(frameborder)
			if parsed == none || parsed or { 0 } == 0 {
				for property_id in [PropertyID.border_top_width, .border_right_width,
					.border_bottom_width, .border_left_width] {
					if zero := parse_css_value_logic(property_id, '0px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, zero)
					}
				}
			}
		}
	}
	if tag_name in ['pre', 'listing', 'xmp'] && element.has_attribute('wrap') {
		set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_wrap_mode, StyleValue(KeywordStyleValue.create(.wrap)))
	}
	if tag_name == 'caption' && element.get_attribute_value('align') == 'bottom' {
		set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .caption_side, StyleValue(KeywordStyleValue.create(.bottom)))
	}
	if tag_name in ['li', 'ol', 'ul'] {
		if type_value := element.get_attribute('type') {
			list_style_type := match type_value {
				'1' { 'decimal' }
				'a' { 'lower-alpha' }
				'A' { 'upper-alpha' }
				'i' { 'lower-roman' }
				'I' { 'upper-roman' }
				else { type_value.to_lower() }
			}
			numbered_style := list_style_type in ['decimal', 'lower-alpha', 'upper-alpha', 'lower-roman',
				'upper-roman']
			unordered_style := list_style_type in ['none', 'disc', 'circle', 'square']
			if (tag_name == 'ol' && numbered_style) || (tag_name == 'ul' && unordered_style) || (tag_name == 'li' && (numbered_style || unordered_style)) {
				if value := parse_css_value_logic(.list_style_type, list_style_type) {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .list_style_type, value)
				}
			}
		}
	}
	if tag_name == 'br' {
		if clear := element.get_attribute('clear') {
			keyword := match clear.to_lower() {
				'left' { Keyword.left }
				'right' { Keyword.right }
				'all', 'both' { Keyword.both }
				else { Keyword.invalid }
			}
			if keyword != .invalid {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .clear, StyleValue(KeywordStyleValue.create(keyword)))
			}
		}
	}
	if tag_name in ['div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'] {
		if align := element.get_attribute('align') {
			lowercase_align := align.to_lower()
			keyword := match lowercase_align {
				'left' {
					if tag_name == 'div' { Keyword.libweb_left } else { Keyword.left }
				}
				'right' {
					if tag_name == 'div' { Keyword.libweb_right } else { Keyword.right }
				}
				'center' {
					if tag_name == 'div' { Keyword.libweb_center } else { Keyword.center }
				}
				'justify' {
					Keyword.justify
				}
				else {
					Keyword.invalid
				}
			}
			if keyword != .invalid {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, StyleValue(KeywordStyleValue.create(keyword)))
			}
		}
	}
	input_accepts_dimensions := tag_name == 'input' && element.get_attribute_value('type').trim_space().to_lower() == 'image'
	if tag_name in ['table', 'td', 'th', 'tr', 'col', 'colgroup', 'embed', 'object'] {
		if width := element.get_attribute('width') {
			if value := html_dimension_presentational_hint(width, .width, tag_name in [
				'table',
				'td',
				'th',
				'col',
				'colgroup',
			]) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .width, value)
			}
		}
		if height := element.get_attribute('height') {
			if value := html_dimension_presentational_hint(height, .height, tag_name in [
				'td',
				'th',
			]) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .height, value)
			}
		}
	}
	if tag_name == 'canvas' {
		width := legacy_non_negative_integer_prefix(element.get_attribute_value('width'))
		height := legacy_non_negative_integer_prefix(element.get_attribute_value('height'))
		if w := width {
			if h := height {
				if value := parse_css_value_logic(.aspect_ratio, 'auto ${w} / ${h}') {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .aspect_ratio, value)
				}
			}
		}
	}
	if input_accepts_dimensions {
		if align := element.get_attribute('align') {
			keyword := match align.to_lower() {
				'center' { Keyword.center }
				'middle' { Keyword.middle }
				else { Keyword.invalid }
			}
			if keyword != .invalid {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, StyleValue(KeywordStyleValue.create(keyword)))
			}
		}
		if border := element.get_attribute('border') {
			if width := legacy_unsigned_integer(border) {
				for side in ['top', 'right', 'bottom', 'left'] {
					width_property := property_id_from_string('border-${side}-width') or { continue }
					style_property := property_id_from_string('border-${side}-style') or { continue }
					if value := parse_css_value_logic(width_property, '${width}px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, width_property, value)
					}
					if value := parse_css_value_logic(style_property, 'solid') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, style_property, value)
					}
				}
			}
		}
		for attribute, properties in {
			'hspace': [PropertyID.margin_left, .margin_right]
			'vspace': [PropertyID.margin_top, .margin_bottom]
		} {
			if source := element.get_attribute(attribute) {
				for property_id in properties {
					if value := html_dimension_presentational_hint(source, property_id, false) {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
	}
	if tag_name == 'img' {
		for attribute, properties in {
			'hspace': [PropertyID.margin_left, .margin_right]
			'vspace': [PropertyID.margin_top, .margin_bottom]
		} {
			if source := element.get_attribute(attribute) {
				for property_id in properties {
					if value := html_dimension_presentational_hint(source, property_id, false) {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
		if border := element.get_attribute('border') {
			if width := legacy_unsigned_integer(border) {
				for side in ['top', 'right', 'bottom', 'left'] {
					width_property := property_id_from_string('border-${side}-width') or { continue }
					style_property := property_id_from_string('border-${side}-style') or { continue }
					if value := parse_css_value_logic(width_property, '${width}px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, width_property, value)
					}
					if value := parse_css_value_logic(style_property, 'solid') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, style_property, value)
					}
				}
			}
		}
	}
	if tag_name == 'object' {
		if align := element.get_attribute('align') {
			keyword := match align.to_lower() {
				'center' { Keyword.center }
				'middle' { Keyword.middle }
				else { Keyword.invalid }
			}
			if keyword != .invalid {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, StyleValue(KeywordStyleValue.create(keyword)))
			}
		}
		for attribute, properties in {
			'hspace': [PropertyID.margin_left, .margin_right]
			'vspace': [PropertyID.margin_top, .margin_bottom]
		} {
			if source := element.get_attribute(attribute) {
				for property_id in properties {
					if value := html_dimension_presentational_hint(source, property_id, false) {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
		}
		if border := element.get_attribute('border') {
			if width := legacy_unsigned_integer(border) {
				for side in ['top', 'right', 'bottom', 'left'] {
					width_property := property_id_from_string('border-${side}-width') or { continue }
					style_property := property_id_from_string('border-${side}-style') or { continue }
					if value := parse_css_value_logic(width_property, '${width}px') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, width_property, value)
					}
					if value := parse_css_value_logic(style_property, 'solid') {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, style_property, value)
					}
				}
			}
		}
	}
	if tag_name in ['tr', 'thead', 'tbody', 'tfoot'] {
		if align := element.get_attribute('align') {
			if value := table_child_element_align_value(align) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, value)
			}
		}
		if height := element.get_attribute('height') {
			if value := html_dimension_presentational_hint(height, .height, false) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .height, value)
			}
		}
	}
	if tag_name == 'table' {
		if align := element.get_attribute('align') {
			if align.to_lower() == 'center' {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_left, StyleValue(KeywordStyleValue.create(.auto)))
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .margin_right, StyleValue(KeywordStyleValue.create(.auto)))
			} else if align.to_lower() in ['left', 'right'] {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .float_, StyleValue(KeywordStyleValue.create(if align.to_lower() == 'left' {
					.left
				} else {
					.right
				})))
			}
		}
		if cellspacing := element.get_attribute('cellspacing') {
			if value := html_dimension_presentational_hint(cellspacing, .border_spacing, false) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .border_spacing, value)
			}
		}
		if border := element.get_attribute('border') {
			if width := legacy_unsigned_integer(border) {
				if width > 0 {
					set_html_table_border_hints(mut cascaded_properties, properties_to_cascade, 'outset', '${width}px', 'rgb(128 128 128)')
				}
			}
		}
		if border_color := element.get_attribute('bordercolor') {
			for side in ['top', 'right', 'bottom', 'left'] {
				property_id := property_id_from_string('border-${side}-color') or { continue }
				if value := parse_css_value_logic(property_id, border_color) {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
				}
			}
		}
	}
	if tag_name in ['table', 'td', 'th', 'tr', 'thead', 'tbody', 'tfoot'] {
		if background_color := element.get_attribute('bgcolor') {
			if value := parse_css_value_logic(.background_color, background_color) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .background_color, value)
			}
		}
		if background := element.get_attribute('background') {
			if parsed_url := element.document().encoding_parse_url(background) {
				if value := parse_css_value_logic(.background_image, 'url("${parsed_url.serialize()}")') {
					set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .background_image, value)
				}
			}
		}
	}
	if tag_name in ['td', 'th'] {
		if align := element.get_attribute('align') {
			if value := table_child_element_align_value(align) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_align, value)
			}
		}
		if nowrap := element.get_attribute('nowrap') {
			_ = nowrap
			set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .text_wrap_mode, StyleValue(KeywordStyleValue.create(.nowrap)))
		}
	}
	if tag_name in ['td', 'th', 'tr'] {
		if valign := element.get_attribute('valign') {
			if value := parse_css_value_logic(.vertical_align, valign) {
				set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, .vertical_align, value)
			}
		}
	}
	if tag_name in ['td', 'th'] {
		if table := nearest_ancestor_html_table(element) {
			if cellpadding := table.get_attribute('cellpadding') {
				if value := html_dimension_presentational_hint(cellpadding, .padding_top, false) {
					for property_id in [PropertyID.padding_top, .padding_right, .padding_bottom,
						.padding_left] {
						set_html_presentational_hint(mut cascaded_properties, properties_to_cascade, property_id, value)
					}
				}
			}
			if table_border := table.get_attribute('border') {
				if width := legacy_unsigned_integer(table_border) {
					if width > 0 {
						color := table.get_attribute_value('bordercolor')
						set_html_table_border_hints(mut cascaded_properties, properties_to_cascade, 'inset', '1px', if color.len > 0 {
							color
						} else {
							'rgb(128 128 128)'
						})
					}
				}
			}
		}
	}

	if tag_name in ['img', 'iframe', 'video'] || input_accepts_dimensions {
		mut dimension_source := unsafe { element }
		if tag_name == 'img' && element.as_node().is_html_image_element() {
			image := unsafe { &dom.HTMLImageElement(element) }
			if source := image.dimension_attribute_source_ {
				dimension_source = source
			}
		}
		collect_dimension_attribute(mut cascaded_properties, dimension_source, 'width', .width, properties_to_cascade)
		collect_dimension_attribute(mut cascaded_properties, dimension_source, 'height', .height, properties_to_cascade)
	}
}

// https://html.spec.whatwg.org/multipage/rendering.html#tables-2
fn table_child_element_align_value(value string) ?StyleValue {
	keyword := match value.to_lower() {
		'center', 'middle' { Keyword.libweb_center }
		'left' { Keyword.libweb_left }
		'right' { Keyword.libweb_right }
		'justify' { Keyword.justify }
		else {
			return none
		}
	}
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn apply_html_presentational_hints_to_cascade(mut properties CascadedProperties, element &dom.Element) {
	mut hints := []StyleProperty{}
	collect_element_presentational_hints(mut hints, element, ComputedInterpolationPropertyIDs{})
	collect_html_presentational_hints(mut hints, element, ComputedInterpolationPropertyIDs{})
	apply_property_list_to_cascade(mut properties, dom.AbstractElement.new(element, none), hints, .author_presentational_hint, .no, none, unsafe { nil }, none, none, [])
}

pub fn html_div_element_is_presentational_hint(_ &dom.HTMLDivElement, name string) bool {
	return name == 'align'
}

pub fn html_div_element_apply_presentational_hints(element &dom.HTMLDivElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_hr_element_is_presentational_hint(_ &dom.HTMLHRElement, name string) bool {
	return name in ['align', 'color', 'noshade', 'width', 'size']
}

pub fn html_hr_element_apply_presentational_hints(element &dom.HTMLHRElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn htmlhr_element_is_presentational_hint(element &dom.HTMLHRElement, name string) bool {
	return html_hr_element_is_presentational_hint(element, name)
}

pub fn htmlhr_element_apply_presentational_hints(element &dom.HTMLHRElement, mut properties CascadedProperties) {
	html_hr_element_apply_presentational_hints(element, mut properties)
}

pub fn html_marquee_element_is_presentational_hint(_ &dom.HTMLMarqueeElement, name string) bool {
	return name in ['bgcolor', 'height', 'hspace', 'vspace', 'width']
}

pub fn html_marquee_element_apply_presentational_hints(element &dom.HTMLMarqueeElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_paragraph_element_is_presentational_hint(_ &dom.HTMLParagraphElement, name string) bool {
	return name == 'align'
}

pub fn html_paragraph_element_apply_presentational_hints(element &dom.HTMLParagraphElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_pre_element_is_presentational_hint(_ &dom.HTMLPreElement, name string) bool {
	return name == 'wrap'
}

pub fn html_pre_element_apply_presentational_hints(element &dom.HTMLPreElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_caption_element_is_presentational_hint(_ &dom.HTMLTableCaptionElement, name string) bool {
	return name == 'align'
}

pub fn html_table_caption_element_apply_presentational_hints(element &dom.HTMLTableCaptionElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_col_element_is_presentational_hint(_ &dom.HTMLTableColElement, name string) bool {
	return name == 'width'
}

pub fn html_table_col_element_apply_presentational_hints(element &dom.HTMLTableColElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_row_element_is_presentational_hint(_ &dom.HTMLTableRowElement, name string) bool {
	return name in ['align', 'bgcolor', 'background', 'height', 'valign']
}

pub fn html_table_row_element_apply_presentational_hints(element &dom.HTMLTableRowElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_section_element_is_presentational_hint(_ &dom.HTMLTableSectionElement, name string) bool {
	return name in ['align', 'background', 'bgcolor', 'height']
}

pub fn html_table_section_element_apply_presentational_hints(element &dom.HTMLTableSectionElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_ulist_element_is_presentational_hint(_ &dom.HTMLUListElement, name string) bool {
	return name == 'type'
}

pub fn html_ulist_element_apply_presentational_hints(element &dom.HTMLUListElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn htmlu_list_element_is_presentational_hint(element &dom.HTMLUListElement, name string) bool {
	return html_ulist_element_is_presentational_hint(element, name)
}

pub fn htmlu_list_element_apply_presentational_hints(element &dom.HTMLUListElement, mut properties CascadedProperties) {
	html_ulist_element_apply_presentational_hints(element, mut properties)
}

pub fn html_heading_element_is_presentational_hint(_ &dom.HTMLHeadingElement, name string) bool {
	return name == 'align'
}

pub fn html_heading_element_apply_presentational_hints(element &dom.HTMLHeadingElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_cell_element_is_presentational_hint(_ &dom.HTMLTableCellElement, name string) bool {
	return name in ['align', 'background', 'bgcolor', 'height', 'nowrap', 'valign', 'width']
}

pub fn html_table_cell_element_apply_presentational_hints(element &dom.HTMLTableCellElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_body_element_is_presentational_hint(_ &dom.HTMLBodyElement, name string) bool {
	return name in ['bgcolor', 'text', 'background', 'marginheight', 'marginwidth', 'topmargin',
		'rightmargin', 'bottommargin', 'leftmargin']
}

pub fn html_body_element_apply_presentational_hints(element &dom.HTMLBodyElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_li_element_is_presentational_hint(_ &dom.HTMLLIElement, name string) bool {
	return name == 'type'
}

pub fn html_li_element_apply_presentational_hints(element &dom.HTMLLIElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn htmlli_element_is_presentational_hint(element &dom.HTMLLIElement, name string) bool {
	return html_li_element_is_presentational_hint(element, name)
}

pub fn htmlli_element_apply_presentational_hints(element &dom.HTMLLIElement, mut properties CascadedProperties) {
	html_li_element_apply_presentational_hints(element, mut properties)
}

pub fn htmlol_list_element_is_presentational_hint(_ &dom.HTMLOListElement, name string) bool {
	return name == 'type'
}

pub fn htmlol_list_element_apply_presentational_hints(element &dom.HTMLOListElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn htmlo_list_element_is_presentational_hint(element &dom.HTMLOListElement, name string) bool {
	return htmlol_list_element_is_presentational_hint(element, name)
}

pub fn htmlo_list_element_apply_presentational_hints(element &dom.HTMLOListElement, mut properties CascadedProperties) {
	htmlol_list_element_apply_presentational_hints(element, mut properties)
}

pub fn htmlbr_element_is_presentational_hint(_ &dom.HTMLBRElement, name string) bool {
	return name == 'clear'
}

pub fn htmlbr_element_apply_presentational_hints(element &dom.HTMLBRElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_br_element_is_presentational_hint(element &dom.HTMLBRElement, name string) bool {
	return htmlbr_element_is_presentational_hint(element, name)
}

pub fn html_br_element_apply_presentational_hints(element &dom.HTMLBRElement, mut properties CascadedProperties) {
	htmlbr_element_apply_presentational_hints(element, mut properties)
}

pub fn html_embed_element_is_presentational_hint(_ &dom.HTMLEmbedElement, name string) bool {
	return name in ['align', 'height', 'hspace', 'vspace', 'width']
}

pub fn html_embed_element_apply_presentational_hints(element &dom.HTMLEmbedElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_iframe_element_is_presentational_hint(_ &dom.HTMLIFrameElement, name string) bool {
	return name == 'frameborder'
}

pub fn html_iframe_element_apply_presentational_hints(element &dom.HTMLIFrameElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_canvas_element_is_presentational_hint(_ &dom.HTMLCanvasElement, name string) bool {
	return name in ['width', 'height']
}

pub fn html_canvas_element_apply_presentational_hints(element &dom.HTMLCanvasElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_image_element_is_presentational_hint(_ &dom.HTMLImageElement, name string) bool {
	return name in ['hspace', 'vspace', 'border']
}

pub fn html_image_element_apply_presentational_hints(element &dom.HTMLImageElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_object_element_is_presentational_hint(_ &dom.HTMLObjectElement, name string) bool {
	return name in ['align', 'border', 'height', 'hspace', 'vspace', 'width']
}

pub fn html_object_element_apply_presentational_hints(element &dom.HTMLObjectElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn htmli_frame_element_is_presentational_hint(element &dom.HTMLIFrameElement, name string) bool {
	return html_iframe_element_is_presentational_hint(element, name)
}

pub fn htmli_frame_element_apply_presentational_hints(element &dom.HTMLIFrameElement, mut properties CascadedProperties) {
	html_iframe_element_apply_presentational_hints(element, mut properties)
}

pub fn html_font_element_is_presentational_hint(_ &dom.HTMLFontElement, name string) bool {
	return name in ['color', 'face', 'size']
}

pub fn html_font_element_apply_presentational_hints(element &dom.HTMLFontElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

pub fn html_table_element_is_presentational_hint(_ &dom.HTMLTableElement, name string) bool {
	return name in ['align', 'background', 'bgcolor', 'border', 'bordercolor', 'cellpadding',
		'cellspacing', 'height', 'width']
}

pub fn html_table_element_apply_presentational_hints(element &dom.HTMLTableElement, mut properties CascadedProperties) {
	apply_html_presentational_hints_to_cascade(mut properties, unsafe { &dom.Element(element) })
}

fn collect_svg_presentational_hints(mut properties []StyleProperty, element &dom.Element, properties_to_cascade ComputedInterpolationPropertyIDs) {
	tag_name := element.local_name()
	sizing_only := ['foreignObject', 'image', 'rect', 'svg', 'symbol', 'use']!
	attributes := element.attribute_list() or { return }
	for index := 0; index < attributes.length(); index++ {
		attribute := attributes.item(index) or { continue }
		// SVG presentation attribute names are case-sensitive, and attributes in
		// a namespace do not participate in the CSS cascade.
		if attribute.namespace_uri() != none {
			continue
		}
		attribute_name := attribute.local_name()
		mut property_name := attribute_name
		if attribute_name == 'gradientTransform' || attribute_name == 'patternTransform' {
			property_name = 'transform'
		} else if attribute_name == 'font-stretch' {
			property_name = 'font-width'
		}
		if attribute_name in ['cx', 'cy', 'd', 'r', 'rx', 'ry'] {
			// These fixed applicability sets need no per-element map or vectors,
			// including during the writing-mode/direction-only cascade probe.
			applies := match attribute_name {
				'cx', 'cy' { tag_name in ['circle', 'ellipse'] }
				'd' { tag_name == 'path' }
				'r' { tag_name == 'circle' }
				else { tag_name in ['ellipse', 'rect'] }
			}
			if !applies {
				continue
			}
		} else if attribute_name == 'transform'
			&& tag_name in ['linearGradient', 'radialGradient', 'pattern'] {
			// These elements expose gradientTransform/patternTransform instead.
			continue
		} else if attribute_name in ['height', 'width', 'x', 'y'] {
			if tag_name !in sizing_only {
				continue
			}
		} else if attribute_name !in ['fill', 'clip-path', 'clip-rule', 'color', 'color-interpolation',
			'color-interpolation-filters', 'cursor', 'direction', 'display', 'dominant-baseline',
			'fill-opacity', 'fill-rule', 'filter', 'flood-color', 'flood-opacity', 'font-family',
			'font-size', 'font-style', 'font-variant', 'font-weight', 'font-stretch', 'image-rendering',
			'letter-spacing', 'mask', 'mask-type', 'opacity', 'overflow', 'paint-order',
			'pointer-events', 'shape-rendering', 'stop-color', 'stop-opacity', 'stroke',
			'stroke-dasharray', 'stroke-dashoffset', 'stroke-linecap', 'stroke-linejoin',
			'stroke-miterlimit', 'stroke-opacity', 'stroke-width', 'vector-effect', 'text-anchor',
			'text-decoration', 'text-rendering', 'text-overflow', 'transform', 'gradientTransform',
			'patternTransform', 'transform-origin', 'unicode-bidi', 'visibility', 'white-space',
			'word-spacing', 'writing-mode'] {
			continue
		}
		property_id := property_id_from_string(property_name) or { continue }
		if properties_to_cascade.len > 0 && property_id !in properties_to_cascade {
			continue
		}
		attribute_value := attribute.value()
		value := parse_svg_presentation_attribute_value(element.document(), property_id, attribute_value) or {
			continue
		}
		properties << StyleProperty{
			property_id: property_id
			value: dom_style_value_from_value_logic(value)
		}
	}
}

fn parse_svg_presentation_attribute_value(document &dom.Document, property_id PropertyID, source string) ?StyleValue {
	if property_id == .d {
		return svg_presentation_path_value(source)
	}
	// SVG transform attributes use the transform-list grammar: unitless
	// translations, optional commas, and three-argument rotate(). Re-express
	// that grammar as the single matrix() value used by the CSS cascade.
	if property_id == .transform {
		transforms := svg.parse_transform(source) or { return none }
		matrix := svg.compose_transforms(transforms)
		parameters := [
			StyleValue(NumberStyleValue.create(matrix.a)),
			StyleValue(NumberStyleValue.create(matrix.b)),
			StyleValue(NumberStyleValue.create(matrix.c)),
			StyleValue(NumberStyleValue.create(matrix.d)),
			StyleValue(NumberStyleValue.create(matrix.e)),
			StyleValue(NumberStyleValue.create(matrix.f)),
		]
		return StyleValue(StyleValueList.create([
			StyleValue(TransformationStyleValue.create(.transform, .matrix, parameters)),
		], .space, .yes))
	}
	return parse_css_value_in_workspace(ParsingParams{
		document: document
		mode: .svg_presentation_attribute
	}, property_id, source)
}

pub fn (s &StyleComputer) compute_custom_properties(mut computed_properties ComputedProperties, abstract_element dom.AbstractElement) {
	_ = s
	_ = computed_properties
	installed_data := abstract_element.custom_property_data() or { return }
	data := if installed_data.is_animation_overlay() {
		installed_data.parent or { return }
	} else {
		installed_data
	}
	if installed_data.is_animation_overlay() {
		mut mutable_abstract_element := abstract_element
		mutable_abstract_element.set_custom_property_data(data)
	}
	if inherit_from := abstract_element.element_to_inherit_style_from() {
		if parent_data := inheritable_custom_property_data(inherit_from) {
			if voidptr(data) == voidptr(parent_data) {
				return
			}
		}
	}
	if data.own_values.len == 0 {
		return
	}

	mut parent_data := ?&dom.CSSCustomPropertyData_(none)
	if inherit_from := abstract_element.element_to_inherit_style_from() {
		parent_data = inheritable_custom_property_data(inherit_from)
	}
	mut resolved_own := map[string]dom.CSSCustomProperty_{}
	for name, property in data.own_values {
		mut guarded_contexts := GuardedSubstitutionContexts{}
		mut computed_value := resolve_computed_custom_property_value(abstract_element, name,
			mut guarded_contexts)
		// Registered declarations have computed typed values, just like animated
		// declarations. Publish them before descendants inherit their data.
		if abstract_element.document().get_registered_custom_property(name) != none {
			value := s.compute_animated_custom_property_value(abstract_element, computed_properties,
				name, computed_value.materialize())
			computed_value = ComputedCustomPropertyValue{existing_value: value}
		}
		mut serialized_value := ?&dom.CSSStyleValue_(none)
		if parent := parent_data {
			if parent_property := parent.get_property(name) {
				if equal := computed_value.equals_typed_bridge(parent_property.value) {
					if equal { continue }
				} else {
					// Hand-authored DOM bridges need the original text/invalidity
					// fallback. Retain this bridge if comparison does not discard it.
					resolved_value := custom_property_bridge_value(computed_value.materialize())
					if custom_property_bridge_values_equal(parent_property.value, resolved_value) {
						continue
					}
					serialized_value = resolved_value
				}
			}
		}
		resolved_value := serialized_value or {
			custom_property_bridge_value(computed_value.materialize())
		}
		resolved_own[name] = dom.CSSCustomProperty_{
			important: property.important
			value: resolved_value
		}
	}

	mut mutable_abstract_element := abstract_element
	if resolved_own.len == 0 {
		if parent := parent_data {
			mutable_abstract_element.set_custom_property_data(parent)
			return
		}
	}
	fallback_parent := if _ := parent_data { parent_data } else { data.parent }
	mutable_abstract_element.set_custom_property_data(dom.CSSCustomPropertyData_.create(resolved_own, fallback_parent))
}

pub fn (s &StyleComputer) start_needed_transitions(old_style &ComputedProperties, mut new_style ComputedProperties, abstract_element dom.AbstractElement) {
	if s.css_transition_storage_ == unsafe { nil } {
		return
	}
	mut storage := s.css_transition_storage_
	storage.transition_generation++
	start_needed_transitions_for_storage(old_style, mut new_style, abstract_element, storage.transition_generation, s.document_timeline_, mut storage)
}

pub fn (s &StyleComputer) resolve_effective_overflow_values(mut computed_properties ComputedProperties) {
	_ = s
	// https://www.w3.org/TR/css-overflow-3/#overflow-control
	// A visible axis computes to auto when the other axis is scrollable.
	// CSS Overflow 3 keeps clip non-scrollable, allowing single-axis scrolling.
	overflow_x := computed_properties.overflow_x()
	overflow_y := computed_properties.overflow_y()
	overflow_x_is_visible_or_clip := overflow_x == .visible || overflow_x == .clip
	overflow_y_is_visible_or_clip := overflow_y == .visible || overflow_y == .clip
	if !overflow_x_is_visible_or_clip || !overflow_y_is_visible_or_clip {
		if overflow_x == .visible {
			computed_properties.set_property_without_modifying_flags(.overflow_x, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))))
		}
		if overflow_y == .visible {
			computed_properties.set_property_without_modifying_flags(.overflow_y, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))))
		}
	}
}

enum BoxTypeTransformation {
	none_
	blockify
	inlinify
}

fn required_box_type_transformation(style &ComputedProperties, abstract_element dom.AbstractElement) BoxTypeTransformation {
	// NOTE: We never blockify <br> elements. They are always inline.
	//       There is currently no way to express in CSS how a <br> element really behaves.
	//       Spec issue: https://github.com/whatwg/html/issues/2291
	if abstract_element.pseudo_element() == none && abstract_element.element().is_html_element()
		&& to_ascii_lowercase(abstract_element.element().local_name()) == 'br' {
		return .none_
	}

	// Absolute positioning or floating an element blockifies the box's display type. [CSS2]
	if style.position() == .absolute || style.position() == .fixed || style.float_() != .none_ {
		return .blockify
	}

	// FIXME: Containment in a ruby container inlinifies the box's display type, as described in [CSS-RUBY-1].

	// NOTE: If we're computing style for a pseudo-element, the effective parent will be the originating element itself, not its parent.
	mut parent := abstract_element.element_to_inherit_style_from()

	// Climb out of `display: contents` context.
	for {
		current := parent or { break }
		dom_parent_style := current.computed_properties() or { break }
		parent_style := computed_properties_from_dom(dom_parent_style) or { break }
		if !parent_style.display().is_contents() {
			break
		}
		parent = current.element_to_inherit_style_from()
	}

	// A parent with a grid or flex display value blockifies the box's display type. [CSS-GRID-1] [CSS-FLEXBOX-1]
	if current := parent {
		if dom_parent_style := current.computed_properties() {
			if parent_style := computed_properties_from_dom(dom_parent_style) {
				parent_display := parent_style.display()
				if parent_display.is_grid_inside() || parent_display.is_flex_inside() {
					return .blockify
				}
			}
		}
	}

	return .none_
}

pub fn (s &StyleComputer) transform_box_type_if_needed(mut computed_properties ComputedProperties, abstract_element dom.AbstractElement) {
	_ = s
	adjust_grid_lanes_subgrid_axes(mut computed_properties,abstract_element)
	// 2.7. Automatic Box Type Transformations
	//
	// Some layout effects require blockification or inlinification of the box type,
	// which sets the box's computed outer display type to block or inline (respectively).
	// (This has no effect on display types that generate no box at all, such as none or contents.)
	display_before_transformation := computed_properties.display()
	computed_properties.set_display_before_box_type_transformation(display_before_transformation)
	mut display := display_before_transformation
	is_document_element := abstract_element.pseudo_element() == none
		&& abstract_element.element().is_document_element()
	// https://drafts.csswg.org/css-overflow-4/#webkit-line-clamp
	// A vertical legacy box with active clamping computes to a flow-root while
	// retaining its authored display for compatibility-sensitive layout.
	if computed_properties.webkit_box_orient() == .vertical
		&& computed_properties.continue_value() != .auto_
		&& display.is_webkit_box_inside() {
		display = if display.is_inline_outside() {
			Display.from_short(.inline_block)
		} else {
			Display.from_short(.flow_root)
		}
		computed_properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(display))))
	}
	if display.is_none() || (display.is_contents() && !is_document_element) {
		return
	}

	// https://drafts.csswg.org/css-display/#root
	// The root element's display type is always blockified, and its principal box always establishes an independent formatting context.
	if is_document_element && !display.is_block_outside() {
		computed_properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block)))))
		return
	}

	mut new_display := display

	if display.is_math_inside() {
		namespace_ := abstract_element.element().namespace_uri() or { '' }
		name := to_ascii_lowercase(abstract_element.element().local_name())
		if namespace_ != 'http://www.w3.org/1998/Math/MathML' {
			new_display = Display.from_outside_inside(display.outside(), .flow)
		} else if name == 'mtable' {
			new_display = Display.from_outside_inside(display.outside(), .table)
		} else if name == 'mtr' {
			new_display = Display.from_internal(.table_row)
		} else if name == 'mtd' {
			new_display = Display.from_internal(.table_cell)
		}
	}

	// https://www.w3.org/TR/CSS2/visuren.html#dis-pos-flo
	// If 'position' has the value 'absolute' or 'fixed', [...] 'float' is set to 'none'.
	if computed_properties.position() == .absolute || computed_properties.position() == .fixed {
		computed_properties.set_property_without_modifying_flags(.float_, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_))))
	}

	match required_box_type_transformation(computed_properties, abstract_element) {
		.none_ {}
		.blockify {
			if display.is_block_outside() {
				return
			}
			// If a layout-internal box is blockified, its inner display type converts to flow so that it becomes a block container.
			if display.is_internal() {
				new_display = Display.from_short(.block)
			} else {
				assert display.is_outside_and_inside()

				// For legacy reasons, if an inline block box (inline flow-root) is blockified, it becomes a block box (loses its flow-root nature).
				// For consistency, a run-in flow-root box also blockifies to a block box.
				if display.is_inline_block() {
					new_display = Display.from_outside_inside_and_list_item(.block, .flow, display.list_item())
				} else {
					new_display = Display.from_outside_inside_and_list_item(.block, display.inside(), display.list_item())
				}
			}
		}
		.inlinify {
			if display.is_inline_outside() {
				// FIXME: If an inline box (inline flow) is inlinified, it recursively inlinifies all of its in-flow children,
				//        so that no block-level descendants break up the inline formatting context in which it participates.
				if display.is_flow_inside() {
					eprintln('FIXME: Inlinify inline box children recursively')
				}
				return
			}
			if display.is_internal() {
				// Inlinification has no effect on layout-internal boxes. (However, placement in such an inline context will typically cause them
				// to be wrapped in an appropriately-typed anonymous inline-level box.)
			} else {
				assert display.is_outside_and_inside()

				// If a block box (block flow) is inlinified, its inner display type is set to flow-root so that it remains a block container.
				if display.is_block_outside() && display.is_flow_inside() {
					new_display = Display.from_outside_inside_and_list_item(.inline_, .flow_root, display.list_item())
				}

				new_display = Display.from_outside_inside_and_list_item(.inline_, display.inside(), display.list_item())
			}
		}
	}

	if new_display != display {
		computed_properties.set_property_without_modifying_flags(.display, dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(new_display))))
	}
}

pub fn (s &StyleComputer) viewport_rect() CSSPixelRect {
	return s.viewport_rect_
}

pub fn (s &StyleComputer) calculate_root_element_font_metrics(computed_properties &ComputedProperties) LengthFontMetrics {
	return computed_interpolation_font_metrics_for_style(computed_properties, s.font_computer_)
}


pub fn (s &StyleComputer) cascade_declarations(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, rules []ScopedMatchingRule, origin CascadeOrigin, important Important, layer_name ?string, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade ComputedInterpolationPropertyIDs) {
	_ = s
	// StyleComputer::cascade_declarations (StyleComputer.cpp:476): cascade each matching rule's
	// declaration, then — for the author origin on a non-pseudo element — the element's inline style.
	// Each declaration is handled by cascade_one_declaration (the inner cascade_style_declaration lambda),
	// which filters by importance / pseudo-element support / properties_to_cascade, expands shorthands,
	// maps logical aliases to physical properties, and reverts or sets each longhand.
	for scoped_rule in rules {
		rule := scoped_rule.rule.rule or { continue }
		declaration := rule.style() or { continue }
		cascade_one_declaration(mut cascaded_properties, abstract_element, declaration, scoped_rule.shadow_root, origin, important, layer_name, logical_alias_mapping_context, properties_to_cascade)
	}

	if origin == .author && abstract_element.pseudo_element() == none {
		if inline_declaration := inline_style_for_abstract_element(abstract_element) {
			cascade_one_declaration(mut cascaded_properties, abstract_element, inline_declaration, none, origin, important, layer_name, logical_alias_mapping_context, properties_to_cascade)
		}
	}
}

pub fn (s &StyleComputer) rule_cache_for_cascade_origin(origin CascadeOrigin, qualified_layer_name ?string, shadow_root ?&dom.ShadowRoot) ?&RuleCache {
	return style_computer_rule_cache_for_cascade_origin_without_scope_boundary(s, origin, qualified_layer_name, shadow_root)
}

pub fn (s &StyleComputer) clear_computation_context_caches() {
	mut mutable_s := unsafe { &StyleComputer(s) }
	mutable_s.cached_font_computation_context = none
	mutable_s.cached_line_height_computation_context = none
	mutable_s.cached_generic_computation_context = none
}

// Advance the deterministic CSS animation timeline used by this standalone
// port. Embedders can set it from their document timeline before a style pass.
pub fn (mut s StyleComputer) set_animation_time_ms(time_ms f64) {
	if s.document_timeline_ != unsafe { nil } {
		s.document_timeline_.update_current_time(time_ms)
		s.animation_time_ms_ = s.document_timeline_.current_time_ms() or { time_ms }
	} else {
		s.animation_time_ms_ = time_ms
	}
	if s.document_ != unsafe { nil } {
		mut document := unsafe { &dom.Document(s.document_) }
		// A document clock advances even on a static page. Only effect targets
		// can change animated style; dirtying an empty set requests another
		// rendering opportunity and turns slow static frames into a redraw loop.
		mut has_targets := false
		if s.css_animation_storage_ != unsafe { nil } {
			for entry in s.css_animation_storage_.entries {
				if s.animation_target_needs_rendering(entry.abstract_element) {
					has_targets = true
					break
				}
			}
		}
		if !has_targets && s.css_transition_storage_ != unsafe { nil } {
			for _, bucket in s.css_transition_storage_.associated_transitions {
				for entry in bucket.entries {
					if entry.transition.needs_style_sample_at(s.animation_time_ms_)
						&& s.animation_target_needs_rendering(entry.abstract_element) {
						has_targets = true
						break
					}
				}
				if has_targets { break }
			}
		}
		if !has_targets {
			if hook := document.animations_hook_ {
				if hook.effect_targets != unsafe { nil } {
					has_targets = hook.effect_targets(hook.target).len > 0
				}
			}
		}
		if has_targets && (s.animation_clock_demand_filter_ == unsafe { nil }
			|| s.animation_clock_demand_filter_(document, s.animation_time_ms_)) {
			document.set_needs_animated_style_update()
		}
	}
}

pub fn (s &StyleComputer) css_animation_for(abstract_element dom.AbstractElement, name string) ?&CSSAnimation {
	if s.css_animation_storage_ == unsafe { nil } {
		return none
	}
	return s.css_animation_storage_.animation(abstract_element, name)
}

pub fn (s &StyleComputer) computation_context_cache_is_empty() bool {
	return s.cached_font_computation_context == none && s.cached_line_height_computation_context == none && s.cached_generic_computation_context == none
}

pub fn (s &StyleComputer) get_computation_context_for_property(property_id PropertyID, computed_properties &ComputedProperties, abstract_element ?dom.AbstractElement) ComputationContext {
	// writing-mode precedes font computation. Use the inherited font context
	// here so it cannot populate the generic cache before font metrics are ready.
	font_computation_property := property_id in [.color_scheme, .font_family, .font_feature_settings,
		.font_kerning, .font_optical_sizing, .font_size, .font_style, .font_variant_alternates,
		.font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures,
		.font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight,
		.font_width, .math_depth, .text_rendering, .writing_mode]
	if font_computation_property {
		if cached := s.cached_font_computation_context {
			// The target writing mode may have been computed since this cache
			// was populated. Refresh its axis without changing inherited metrics.
			mut context := cached
			context.length_resolution_context.subject_inline_axis_is_horizontal = computed_properties.writing_mode() == .horizontal_tb
			return context
		}
		// StyleComputer::get_computation_context_for_property() deliberately
		// resolves font-relative units against the inheritance parent. The
		// partially built current style may contain the temporary 13px value used
		// by monospace font-size recascading and must not be used here.
		mut length_resolution_context := LengthResolutionContext.for_document(s.document_)
		mut font_metrics := LengthFontMetrics.default()
		if current := abstract_element {
			if parent := current.element_to_inherit_style_from() {
				length_resolution_context = LengthResolutionContext.for_element(&parent)
				if dom_computed := parent.computed_properties() {
					if inherited := computed_properties_from_dom(dom_computed) {
						font_metrics = computed_interpolation_font_metrics_for_style(inherited, s.font_computer_)
					}
				}
			}
		}
		length_resolution_context.font_metrics = font_metrics
		length_resolution_context.root_font_metrics = s.root_element_font_metrics
		length_resolution_context.font_metrics_depend_on_viewport_metrics = if current := abstract_element {
			if parent := current.element_to_inherit_style_from() {
				if dom_computed := parent.computed_properties() {
					if inherited := computed_properties_from_dom(dom_computed) {
						inherited.font_metrics_depend_on_viewport_metrics()
					} else {
						false
					}
				} else {
					false
				}
			} else {
				false
			}
		} else {
			false
		}
		length_resolution_context.root_font_metrics_depend_on_viewport_metrics = s.root_element_font_metrics_depend_on_viewport_metrics
		length_resolution_context.subject_inline_axis_is_horizontal = computed_properties.writing_mode() == .horizontal_tb
		length_resolution_context.subject_element = if current := abstract_element {
			?&dom.Element(current.element())
		} else {
			?&dom.Element(none)
		}
		length_resolution_context.subject_is_pseudo = if current := abstract_element { current.pseudo_element() != none } else { false }
		length_resolution_context.query_container_cache = if _ := abstract_element {
			?&LengthQueryContainerCache(&LengthQueryContainerCache{})
		} else {
			?&LengthQueryContainerCache(none)
		}
		context := ComputationContext{
			length_resolution_context: length_resolution_context
			abstract_element: abstract_element
		}
		mut mutable_s := unsafe { &StyleComputer(s) }
		mutable_s.cached_font_computation_context = context
		return context
	}

	if property_id == .line_height {
		if cached := s.cached_line_height_computation_context {
			mut context := cached
			context.length_resolution_context.subject_inline_axis_is_horizontal = computed_properties.writing_mode() == .horizontal_tb
			return context
		}
	} else if cached := s.cached_generic_computation_context {
		mut context := cached
		context.length_resolution_context.subject_inline_axis_is_horizontal = computed_properties.writing_mode() == .horizontal_tb
		return context
	}
	is_document_element := if current := abstract_element {
		current.pseudo_element() == none && current.element().is_document_element()
	} else {
		false
	}
	mut font_metrics := computed_interpolation_font_metrics_for_style(computed_properties, s.font_computer_)
	mut root_font_metrics := s.root_element_font_metrics
	if property_id == .line_height {
		// Line-height is the one font-adjacent property that resolves em units
		// against the element's newly computed font size, while lh inherits its
		// parent line height.
		if current := abstract_element {
			if parent := current.element_to_inherit_style_from() {
				if dom_computed := parent.computed_properties() {
					if inherited := computed_properties_from_dom(dom_computed) {
						font_metrics.line_height = inherited.line_height()
					}
				}
			}
		}
		if is_document_element {
			root_font_metrics = font_metrics
		}
	} else {
		font_metrics.line_height = computed_properties.line_height()
		if is_document_element {
			root_font_metrics = font_metrics
		} else if root := s.document_.document_element() {
			root_abstract := dom.AbstractElement.new(root, none)
			if root_dom_computed := root_abstract.computed_properties() {
				if root_computed := computed_properties_from_dom(root_dom_computed) {
					root_font_metrics = s.calculate_root_element_font_metrics(root_computed)
				}
			}
		}
	}
	context := ComputationContext{
		length_resolution_context: LengthResolutionContext{
			viewport_rect: s.viewport_rect_
			font_metrics: font_metrics
			root_font_metrics: root_font_metrics
			font_metrics_depend_on_viewport_metrics: computed_properties.font_metrics_depend_on_viewport_metrics()
			root_font_metrics_depend_on_viewport_metrics: if is_document_element {
				computed_properties.font_metrics_depend_on_viewport_metrics()
			} else {
				s.root_element_font_metrics_depend_on_viewport_metrics
			}
			subject_inline_axis_is_horizontal: computed_properties.writing_mode() == .horizontal_tb
			subject_is_pseudo: if current := abstract_element { current.pseudo_element() != none } else { false }
			subject_element: if current := abstract_element {
				?&dom.Element(current.element())
			} else {
				?&dom.Element(none)
			}
			query_container_cache: if _ := abstract_element {
				?&LengthQueryContainerCache(&LengthQueryContainerCache{})
			} else {
				?&LengthQueryContainerCache(none)
			}
		}
		color_scheme: computed_properties.color_scheme(preferred_color_scheme_from_string(s.document_.preferred_color_scheme()),s.document_.supported_color_schemes())
		abstract_element: abstract_element
	}
	mut mutable_s := unsafe { &StyleComputer(s) }
	if property_id == .line_height {
		mutable_s.cached_line_height_computation_context = context
	} else {
		mutable_s.cached_generic_computation_context = context
	}
	return context
}

fn composite_rect_edge(property PropertyID,underlying StyleValue,animated StyleValue,operation CompositeOperation) ?StyleValue {
 if underlying is KeywordStyleValue && animated is KeywordStyleValue && underlying.to_keyword()==.auto && animated.to_keyword()==.auto { return underlying }
 return composite_style_value(property,underlying,animated,operation)
}

fn interpolate_rect_edge(context InterpolationCalculationContext,from StyleValue,to StyleValue,delta f64,allow_discrete AllowDiscrete) ?StyleValue {
 if from is KeywordStyleValue && to is KeywordStyleValue && from.to_keyword()==.auto && to.to_keyword()==.auto { return from }
 return interpolate_style_value_impl(context,from,to,delta,allow_discrete)
}
