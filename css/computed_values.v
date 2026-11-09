module css

import dom
import platform

// CSS::InitialValues. Keeping the composite defaults in one translated table
// prevents layout materialization from growing a second, handwritten set of
// values as more ComputedValues slots are added.
pub struct InitialValues {}

fn initial_zero_length_box() LengthBox {
	zero := LengthPercentageOrAuto.from_length(Length.make_px(0))
	return LengthBox.with_values(zero, zero, zero, zero)
}

pub fn InitialValues.border_spacing() Length {
	return Length.make_px(0)
}

pub fn InitialValues.stop_color() Color {
	return Color{0, 0, 0, 255}
}

pub fn InitialValues.background_color() Color {
	return Color{0, 0, 0, 0}
}

pub fn InitialValues.flood_color() Color {
	return Color{0, 0, 0, 255}
}

pub fn InitialValues.stroke_dashoffset() LengthPercentage {
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn InitialValues.stroke_width() LengthPercentage {
	return LengthPercentage.from_length(Length.make_px(1))
}

pub fn InitialValues.border_radius() Length {
	return Length.make_px(0)
}

pub fn InitialValues.inset() LengthBox {
	return LengthBox.new()
}

pub fn InitialValues.position_anchor() ?string {
	return none
}

pub fn InitialValues.margin() LengthBox {
	return initial_zero_length_box()
}

pub fn InitialValues.padding() LengthBox {
	return initial_zero_length_box()
}

pub fn InitialValues.overflow_clip_margin() LengthBox {
	return initial_zero_length_box()
}

pub fn InitialValues.min_width() Size {
	return Size.make_auto()
}

pub fn InitialValues.max_width() Size {
	return Size.make_none()
}

pub fn InitialValues.min_height() Size {
	return Size.make_auto()
}

pub fn InitialValues.max_height() Size {
	return Size.make_none()
}

pub fn InitialValues.column_count() ?int {
	return none
}

pub fn InitialValues.column_gap() GapValue {
	return GapValue.normal()
}

pub fn InitialValues.column_width() Size {
	return Size.make_auto()
}

pub fn InitialValues.column_height() Size {
	return Size.make_auto()
}

pub fn InitialValues.column_rule_color() Color {
	return Color{0, 0, 0, 255}
}

pub fn InitialValues.column_rule_width() CSSPixels {
	return CSSPixels.new(3)
}

pub fn InitialValues.row_gap() GapValue {
	return GapValue.normal()
}

pub fn InitialValues.transition_delay() Time {
	return Time.make_seconds(0)
}

pub fn InitialValues.outline_color() Color {
	return Color{0, 0, 0, 255}
}

pub fn InitialValues.outline_width() CSSPixels {
	return CSSPixels.new(3)
}

pub fn InitialValues.text_underline_offset() CSSPixels {
	return CSSPixels.new(2)
}

pub fn InitialValues.cx() LengthPercentage {
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn InitialValues.cy() LengthPercentage {
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn InitialValues.r() LengthPercentage {
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn InitialValues.rx() LengthPercentageOrAuto {
	return LengthPercentageOrAuto.make_auto()
}

pub fn InitialValues.ry() LengthPercentageOrAuto {
	return LengthPercentageOrAuto.make_auto()
}

// ComputedValues.h and Layout::NodeWithStyle::apply_style(). The C++ layout
// tree resolves the property map once and then reads these typed slots during
// layout. ComputedValues is an alias in V so the DOM and layout tree can retain
// one allocation, but its accessors and mutators use the same resolved-value
// boundary as the upstream MutableComputedValues/ImmutableComputedValues pair.

pub fn LengthResolutionContext.for_computed_properties(values &ComputedProperties) LengthResolutionContext {
	return values.length_resolution_context()
}

fn computed_values_length_percentage(style &ComputedProperties, property_id PropertyID, fallback LengthPercentage) LengthPercentage {
	value := style.property(property_id, .yes) or { return fallback }
	parsed := style_value_logic_from_dom(property_id, value) or { return fallback }
	if parsed is LengthStyleValue || parsed is PercentageStyleValue
		|| (parsed is CalculatedStyleValue && parsed.resolves_to_length()) {
		return LengthPercentage.from_style_value_logic(parsed)
	}
	// SVG presentation attributes permit unitless numbers for these length
	// properties; ComputedValues stores the resulting user-unit CSS length.
	if parsed is NumberStyleValue && property_id in [.stroke_width, .stroke_dashoffset] {
		return LengthPercentage.from_length(Length.make_px(parsed.number()))
	}
	return fallback
}

fn computed_values_length_percentage_or_auto(style &ComputedProperties, property_id PropertyID) LengthPercentageOrAuto {
	value := style.property(property_id, .yes) or { return LengthPercentageOrAuto.make_auto() }
	if keyword := computed_interpolation_style_value_keyword(value) {
		if keyword == .auto {
			return LengthPercentageOrAuto.make_auto()
		}
	}
	parsed := style_value_logic_from_dom(property_id, value) or {
		return LengthPercentageOrAuto.make_auto()
	}
	if parsed is LengthStyleValue || parsed is PercentageStyleValue
		|| (parsed is CalculatedStyleValue && parsed.resolves_to_length()) {
		return LengthPercentageOrAuto.from_length_percentage(LengthPercentage.from_style_value_logic(parsed))
	}
	return LengthPercentageOrAuto.make_auto()
}

fn computed_values_column_count(style &ComputedProperties) ?int {
	value := style.property(.column_count, .yes) or { return none }
	parsed := style_value_logic_from_dom(.column_count, value) or { return none }
	if parsed is IntegerStyleValue && parsed.integer() > 0 {
		return int(parsed.integer())
	}
	return none
}

fn computed_values_position_anchor(style &ComputedProperties) ?string {
	value := style.typed_property_value(.position_anchor) or { return InitialValues.position_anchor() }
	if value is CustomIdentStyleValue {
		return value.custom_ident()
	}
	return InitialValues.position_anchor()
}

// NodeWithStyle::apply_style() materializes border geometry once. In
// particular, border-style gates the used border width before layout starts;
// retaining that result avoids reparsing both properties in every formatting
// context which asks for box-model edges.
fn computed_values_border_data(style &ComputedProperties, width_property PropertyID, style_property PropertyID) BorderData {
	line_style := style.line_style(style_property)
	if line_style in [.none_, .hidden] {
		return BorderData{
			line_style: line_style
		}
	}
	resolved_width := style.length(width_property).absolute_length_to_px()
	return BorderData{
		line_style: line_style
		width: if resolved_width.raw_value() < 0 {
			CSSPixels.new(0)
		} else {
			resolved_width
		}
	}
}

fn computed_values_border_radius(style &ComputedProperties, property_id PropertyID) BorderRadiusData {
	value := style.property(property_id, .yes) or { return BorderRadiusData{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return BorderRadiusData{} }
	if parsed is BorderRadiusStyleValue {
		return BorderRadiusData{
			horizontal_radius: LengthPercentage.from_style_value_logic(parsed.horizontal_radius_())
			vertical_radius: LengthPercentage.from_style_value_logic(parsed.vertical_radius_())
		}
	}
	return BorderRadiusData{}
}

fn computed_values_transition_delay(style &ComputedProperties) Time {
	value := style.property(.transition_delay, .yes) or { return InitialValues.transition_delay() }
	parsed := style_value_logic_from_dom(.transition_delay, value) or {
		return InitialValues.transition_delay()
	}
	mut first := parsed
	if parsed is StyleValueList {
		if parsed.values().len == 0 {
			return InitialValues.transition_delay()
		}
		first = parsed.values()[0]
	}
	return match first {
		TimeStyleValue { first.time() }
		CalculatedStyleValue {
			first.resolve_time(CalculationResolutionContext{
				length_resolution_context: style.length_resolution_context()
			}) or { InitialValues.transition_delay() }
		}
		else { InitialValues.transition_delay() }
	}
}

fn color_from_computed_value(color ComputedColor) Color {
	return Color{color.red(), color.green(), color.blue(), color.alpha()}
}

fn computed_values_svg_paint(style &ComputedProperties, property_id PropertyID, context ColorResolutionContext) ?SVGPaint {
	value := style.property(property_id, .yes) or { return none }
	parsed := style_value_logic_from_dom(property_id, value) or { return none }
	if parsed.has_color() {
		color := parsed.to_color(context) or { return none }
		return SVGPaint.from_color(color)
	}
	if parsed is StyleValueList {
		values := parsed.values()
		if values.len == 0 {
			return none
		}
		url := values[0].as_url() or { return none }
		fallback_color := if values.len > 1 { values[1].to_color(context) } else { none }
		return SVGPaint.from_url(url.url(), fallback_color)
	}
	return none
}

fn computed_values_first_style_value(style &ComputedProperties, property_id PropertyID) ?StyleValue {
	value := style.property(property_id, .yes) or { return none }
	parsed := style_value_logic_from_dom(property_id, value) or { return none }
	if parsed is StyleValueList {
		if parsed.values().len == 0 {
			return none
		}
		return parsed.values()[0]
	}
	return parsed
}

fn computed_values_mask_reference(style &ComputedProperties) ?MaskReference {
	value := computed_values_first_style_value(style, .mask_image) or { return none }
	if value is URLStyleValue {
		return MaskReference.from_url(value.url())
	}
	return none
}

fn computed_values_mask_image(style &ComputedProperties) ?ImageStyleValue {
	value := computed_values_first_style_value(style, .mask_image) or { return none }
	if value is ImageStyleValue {
		return value
	}
	return none
}

fn computed_values_clip_path(style &ComputedProperties) ?ClipPathReference {
	value := computed_values_first_style_value(style, .clip_path) or { return none }
	return match value {
		URLStyleValue { ClipPathReference.from_url(value.url()) }
		BasicShapeStyleValue { ClipPathReference.from_basic_shape(value) }
		else { none }
	}
}

fn computed_values_shadow(style &ComputedProperties, property_id PropertyID, context ColorResolutionContext) []ShadowData {
	value := style.property(property_id, .yes) or { return []ShadowData{} }
	parsed := style_value_logic_from_dom(property_id, value) or { return []ShadowData{} }
	if parsed.to_keyword() == .none_ {
		return []ShadowData{}
	}
	if parsed !is StyleValueList {
		return []ShadowData{}
	}
	list := parsed as StyleValueList
	mut result := []ShadowData{cap: list.values().len}
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
			color: ComputedColor.rgba(color.r, color.g, color.b, color.a)
			inset: shadow_value.placement() == .inner
		}
	}
	return result
}

fn computed_values_scrollbar_color(style &ComputedProperties, context ColorResolutionContext) ScrollbarColorData {
	value := style.property(.scrollbar_color, .yes) or { return ScrollbarColorData{} }
	parsed := style_value_logic_from_dom(.scrollbar_color, value) or {
		return ScrollbarColorData{}
	}
	if parsed.to_keyword() == .auto || parsed !is ScrollbarColorStyleValue {
		return ScrollbarColorData{}
	}
	colors := parsed as ScrollbarColorStyleValue
	thumb := colors.thumb_color().to_color(context) or { return ScrollbarColorData{} }
	track := colors.track_color().to_color(context) or { return ScrollbarColorData{} }
	return ScrollbarColorData{
		auto_: false
		thumb: ComputedColor.rgba(thumb.r, thumb.g, thumb.b, thumb.a)
		track: ComputedColor.rgba(track.r, track.g, track.b, track.a)
	}
}

// The color half of Layout::NodeWithStyle::apply_style(). It needs the
// document's used color scheme, so callers which own a layout document use
// this entry point after the geometry-only materialization above.
pub fn resolve_computed_values_for_document(style &ComputedProperties, document &dom.Document) &ComputedValues {
	return resolve_computed_values_for_document_impl(style, document, none)
}

// Anonymous inline-run wrappers are created immediately after their parent's
// style is materialized. Keep font discovery and document-dependent color and
// counter-style resolution identical to ordinary layout style application.
pub fn resolve_anonymous_block_values_for_document(source &ComputedProperties, document &dom.Document) &ComputedValues {
	style := source.clone_for_anonymous_block()
	// Capture the immutable geometry snapshot while it still matches this raw
	// clone. Font discovery below can invoke callbacks that change the parent.
	snapshot := source.anonymous_computed_geometry_source(style)
	return resolve_computed_values_for_document_impl(style, document, snapshot)
}

fn can_reuse_compositor_geometry(style &ComputedProperties, document &dom.Document,
	previous &ComputedGeometryProvenance) bool {
	computer := css_style_computer_for(document)
	if !computer.animation_layout_compositor_only_
		|| voidptr(computer.animation_layout_style_) != voidptr(style)
		|| !style.computed_values_resolved_ || style.line_height_ != none
		|| style.layout_coordinate_scale() != 1 || document.layout_coordinate_scale() != 1
		|| previous == unsafe { nil } || previous.generation == 0
		|| previous.raw_generation == 0 || !previous.compositor_only_animations
		|| voidptr(previous.document) != voidptr(document) {
		return false
	}
	context := ColorResolutionContext.for_computed_properties(style, document)
	// Compatibility color values can parse and yield too. A callback may
	// replace or invalidate the cache without changing the raw graph revision.
	if voidptr(style.geometry_provenance()) != voidptr(previous)
		|| !previous.matches_context(style) || previous.token.generation == 0
		|| previous.raw_generation != previous.token.raw_generation
		|| !style.has_only_compositor_animated_properties() {
		return false
	}
	cache := style.computed_layout_cache()
	return cache.computed_values_color_ == (context.current_color or { Color{0, 0, 0, 255} })
		&& cache.computed_values_color_scheme_ == (context.color_scheme or { PreferredColorScheme.light })
		&& cache.computed_values_accent_color_ == context.accent_color
}

fn resolve_computed_values_for_document_impl(style &ComputedProperties, document &dom.Document, anonymous_source ?AnonymousComputedGeometrySource) &ComputedValues {
	// Hidden SVG resources can first resolve while a paint projection is
	// entered. Every cache leaf and its provenance must share the durable
	// owner of the style, not just the outer ComputedLayoutCache record.
	owner := document.native_storage()
	use_document := owner != unsafe { nil }
		&& voidptr(owner) == voidptr(platform.current_retained_arena())
	persistent := platform.enter_persistent_if(!use_document && platform.transient_arena_entered())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	defer {
		retained.finish()
		platform.leave_persistent(persistent)
	}
 diagnostic_scope_start := begin_diagnostic_instruction_scope()
 defer { record_diagnostic_instruction_scope(10, diagnostic_scope_start) }

	mut computed_style := unsafe { &ComputedProperties(style) }
	previous_provenance := computed_style.geometry_provenance()
	font_list := computed_style.computed_font_list(css_style_computer_for(document).font_computer())
	// `line-height: normal` is derived from the selected font's ascent and
	// descent, so make that face available before resolving layout-facing slots.
	_ = computed_style.first_available_computed_font(css_style_computer_for(document).font_computer())
	cache := computed_style.computed_layout_cache()
	if anonymous_source == none && computed_style.computed_values_resolved_
		&& previous_provenance != unsafe { nil }
		&& voidptr(previous_provenance.document) == voidptr(document)
		&& voidptr(previous_provenance.token) == voidptr(computed_style.computed_property_graph_token_)
		&& voidptr(previous_provenance.font_computer) == voidptr(computed_style.cached_computed_font_list_owner_)
		&& previous_provenance.matches(computed_style)
		&& !computed_style.has_animated_properties() && !computed_style.has_animated_custom_properties()
		&& computed_style.line_height_ == none {
		context := ColorResolutionContext.for_computed_properties(style, document)
		scheme := context.color_scheme or { PreferredColorScheme.light }
		if cache.computed_values_color_ == (context.current_color or { Color{0, 0, 0, 255} })
			&& cache.computed_values_color_scheme_ == scheme
			&& cache.computed_values_accent_color_ == context.accent_color {
			// A tree rebuild need not rematerialize unchanged styles. The graph
			// epoch and font/context provenance protect copied styles; counter
			// definitions remain live independently of that raw property graph.
			mut values := unsafe { &MutableComputedValues(style) }
			values.set_list_style_type(style.list_style_type(document))
			return unsafe { &ComputedValues(style) }
		}
	}
	// Only a freshly materialized, nonanimated parent has the same effective
	// inherited property graph as clone_for_anonymous_block(). Animated sources
	// retain the ordinary resolver, which follows the raw anonymous clone.
	mut resolved_anonymous_source := ?&ComputedLayoutCache(none)
	if source := anonymous_source {
		if voidptr(source.font_list) == voidptr(font_list)
			&& voidptr(source.font_computer) == voidptr(computed_style.cached_computed_font_list_owner_)
			&& computed_style.font_geometry_generation_is_current(source.font_computer, source.font_generation, source.font_cascade_was_settled) {
			resolved_anonymous_source = source.cache
			layout_scale := computed_style.layout_coordinate_scale()
			computed_style.computed_layout_cache_ = initial_anonymous_geometry_cache()
			computed_style.computed_layout_cache_.layout_coordinate_scale_ = layout_scale
		}
	}
	// An animation frame re-resolves its target from fresh samples. The arrays
	// and typed copies stored in the snapshot are derived from them and are
	// replaced by the next resolve, so they are samples too.
	mut samples := css_style_computer_for(document).animation_layout_samples(style)
	samples.enter()
	reusing := samples != unsafe { nil }
	mut reuse_previous := unsafe { voidptr(0) }
	if reusing {
		reuse_previous = begin_layout_cache_reuse(computed_style)
	}
	defer {
		if reusing {
			end_layout_cache_reuse(reuse_previous)
		}
		samples.leave()
	}
	// Resolve counter definitions too before the pure geometry/color write
	// scope: loading a custom registry can parse CSS and yield to native work.
	resolved_list_style := style.list_style_type(document)
	if layout_input_diagnostics { report_layout_input_diagnostic(style) }
	if anonymous_source == none && consume_identical_layout_inputs(style, document) {
		mut values := unsafe { &MutableComputedValues(style) }
		values.set_list_style_type(resolved_list_style)
		return unsafe { &ComputedValues(style) }
	}
	// Counter/font discovery can run callbacks. Check the saved raw/context
	// proof only after discovery, immediately before the pure cache write.
	reuse_compositor := anonymous_source == none
		&& can_reuse_compositor_geometry(style, document, previous_provenance)
	// Font discovery is complete before the pure geometry/color write scope.
	mut initial_snapshot := begin_initial_layout_snapshot(computed_style, document)
	owns_cache_write := computed_style.begin_computed_layout_cache_write()
	defer {
		// No callbacks run in the pure geometry/color write scope. Publish the
		// final raw/context provenance, then freeze before returning any values.
		computed_style.computed_layout_cache_.document_resolution_owner = document
		computed_style.publish_computed_geometry_provenance(previous_provenance)
		computed_style.finish_computed_layout_cache_write(owns_cache_write)
		initial_snapshot.publish(mut computed_style)
		if anonymous_source == none { retain_identical_layout_inputs(style, document) }
	}
	if reuse_compositor {
		mut values := unsafe { &MutableComputedValues(style) }
		// Overwrite the whole domain, including removed animation properties,
		// whose effective getters now return the raw cascade again.
		values.set_opacity(style.opacity())
		values.set_transformations(style.transformations())
		values.set_translate(style.translate())
		values.set_rotate(style.rotate())
		values.set_scale(style.scale())
		values.set_transform_origin(style.transform_origin())
		values.set_list_style_type(resolved_list_style)
		return unsafe { &ComputedValues(style) }
	}
	values := if source := resolved_anonymous_source {
		resolve_anonymous_computed_geometry(style, source)
	} else {
		resolve_computed_values(style)
	}
	mut mutable_values := unsafe { &MutableComputedValues(values) }
	mutable_values.set_font_list(font_list)
	mut context := ColorResolutionContext.for_computed_properties(style, document)
	color := context.current_color or { Color{0, 0, 0, 255} }
	scheme := context.color_scheme or { PreferredColorScheme.light }
	accent_color := context.accent_color or { SystemColor.accent_color(scheme) }
	mutable_values.set_color_scheme(scheme)
	mutable_values.set_color(color)
	mutable_values.set_accent_color(accent_color)
	context.current_color = color
	context.accent_color = accent_color

	caret_property := style.property(.caret_color, .yes)
	caret_is_auto := if value := caret_property {
		computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .auto
	} else {
		false
	}
	mutable_values.set_caret_color(if caret_is_auto {
		color
	} else {
		color_from_computed_value(style.color_or_fallback(.caret_color, context, ComputedColor.black()))
	})
	mutable_values.set_background_color(color_from_computed_value(style.color_or_fallback(.background_color, context, ComputedColor.transparent())))
	mutable_values.set_text_decoration_color(color_from_computed_value(style.color_or_fallback(.text_decoration_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a))))
	mutable_values.set_webkit_text_fill_color(color_from_computed_value(style.color_or_fallback(.webkit_text_fill_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a))))
	mutable_values.set_stop_color(color_from_computed_value(style.color_or_fallback(.stop_color, context, ComputedColor.black())))
	mutable_values.set_flood_color(color_from_computed_value(style.color_or_fallback(.flood_color, context, ComputedColor.black())))
	mutable_values.set_outline_color(color_from_computed_value(style.color_or_fallback(.outline_color, context, ComputedColor.black())))
	mutable_values.set_column_rule_color(color_from_computed_value(style.color_or_fallback(.column_rule_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a))))
	mutable_values.ensure_computed_layout_cache().computed_values_fill_ = none
	mutable_values.ensure_computed_layout_cache().computed_values_stroke_ = none
	if fill := computed_values_svg_paint(style, .fill, context) {
		mutable_values.set_fill(fill)
	}
	if stroke := computed_values_svg_paint(style, .stroke, context) {
		mutable_values.set_stroke(stroke)
	}
	mutable_values.set_text_shadow(computed_values_shadow(style, .text_shadow, context))
	mutable_values.set_box_shadow(computed_values_shadow(style, .box_shadow, context))
	mutable_values.set_scrollbar_color(computed_values_scrollbar_color(style, context))
	mutable_values.set_list_style_type(resolved_list_style)

	mut left := values.border_left()
	left.color = color_from_computed_value(style.color_or_fallback(.border_left_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a)))
	mutable_values.set_border_left(left)
	mut top := values.border_top()
	top.color = color_from_computed_value(style.color_or_fallback(.border_top_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a)))
	mutable_values.set_border_top(top)
	mut right := values.border_right()
	right.color = color_from_computed_value(style.color_or_fallback(.border_right_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a)))
	mutable_values.set_border_right(right)
	mut bottom := values.border_bottom()
	bottom.color = color_from_computed_value(style.color_or_fallback(.border_bottom_color, context, ComputedColor.rgba(color.r, color.g, color.b, color.a)))
	mutable_values.set_border_bottom(bottom)
	return values
}

// The resolved property includes animation/transition and important precedence.
// A normal value clears previous settings without creating a temporary empty map.
fn apply_resolved_font_variation_settings(style &ComputedProperties, mut values MutableComputedValues) {
	value := style.property(.font_variation_settings, .yes) or {
		values.font_variation_storage_ = unsafe { nil }
		return
	}
	if computed_font_setting_is_normal(value) {
		values.font_variation_storage_ = unsafe { nil }
		return
	}
	values.set_font_variation_settings(style.font_variation_settings())
}

pub fn resolve_computed_values(style &ComputedProperties) &ComputedValues {
	// Preserve the dependency order from NodeWithStyle::apply_style(): font
	// metrics first, followed by the remaining layout-facing values.
	font_size := style.font_size()
	line_height := style.line_height()

	mut values := unsafe { &MutableComputedValues(style) }
	owns_cache_write := values.begin_computed_layout_cache_write()
	defer { values.finish_computed_layout_cache_write(owns_cache_write) }
	values.set_font_size(font_size)
	values.set_line_height(line_height)
	values.set_font_weight(style.font_weight())
	values.set_font_language_override(style.font_language_override())
	apply_resolved_font_variation_settings(style, mut values)
	values.set_display(style.display())
	values.set_display_before_box_type_transformation(style.display_before_box_type_transformation())
	values.set_position(style.position())
	values.set_position_anchor(computed_values_position_anchor(style))
	values.set_float(style.float_())
	values.set_clear(style.clear())
	values.set_direction(style.direction())
	values.set_writing_mode(style.writing_mode())
	values.set_overflow_x(style.overflow_x())
	values.set_overflow_y(style.overflow_y())
	values.set_width(style.size_value(.width))
	values.set_min_width(style.size_value(.min_width))
	values.set_max_width(style.size_value(.max_width))
	values.set_height(style.size_value(.height))
	values.set_min_height(style.size_value(.min_height))
	values.set_max_height(style.size_value(.max_height))
	values.set_inset(style.length_box(.left, .top, .right, .bottom, InitialValues.inset().top()))
	values.set_margin(style.length_box(.margin_left, .margin_top, .margin_right, .margin_bottom, InitialValues.margin().top()))
	values.set_padding(style.length_box(.padding_left, .padding_top, .padding_right, .padding_bottom, InitialValues.padding().top()))
	values.set_overflow_clip_margin(style.length_box(.overflow_clip_margin_left, .overflow_clip_margin_top, .overflow_clip_margin_right, .overflow_clip_margin_bottom, InitialValues.overflow_clip_margin().top()))
	values.set_border_left(computed_values_border_data(style, .border_left_width, .border_left_style))
	values.set_border_top(computed_values_border_data(style, .border_top_width, .border_top_style))
	values.set_border_right(computed_values_border_data(style, .border_right_width, .border_right_style))
	values.set_border_bottom(computed_values_border_data(style, .border_bottom_width, .border_bottom_style))
	values.set_border_bottom_left_radius(computed_values_border_radius(style, .border_bottom_left_radius))
	values.set_border_bottom_right_radius(computed_values_border_radius(style, .border_bottom_right_radius))
	values.set_border_top_left_radius(computed_values_border_radius(style, .border_top_left_radius))
	values.set_border_top_right_radius(computed_values_border_radius(style, .border_top_right_radius))
	values.set_flex_direction(style.flex_direction())
	values.set_flex_wrap(style.flex_wrap())
	values.set_flex_basis(style.flex_basis())
	values.set_flex_grow(style.flex_grow())
	values.set_flex_shrink(style.flex_shrink())
	values.set_order(style.order())
	values.set_align_content(style.align_content())
	values.set_align_items(style.align_items())
	values.set_align_self(style.align_self())
	values.set_justify_content(style.justify_content())
	values.set_justify_items(style.justify_items())
	values.set_justify_self(style.justify_self())
	values.set_text_align(style.text_align())
	values.set_text_justify(style.text_justify())
	values.set_text_transform(style.text_transform())
	values.set_text_wrap_mode(style.text_wrap_mode())
	values.set_white_space_collapse(style.white_space_collapse())
	values.set_word_break(style.word_break())
	values.set_hyphens(style.hyphens())
	values.set_visibility(style.visibility())
	values.set_box_sizing(style.box_sizing())
	values.set_vertical_align(style.vertical_align())
	values.set_caption_side(style.caption_side())
	values.set_content_visibility(style.content_visibility())
	values.set_user_select(style.user_select())
	values.set_table_layout(style.table_layout())
	values.set_border_collapse(style.border_collapse())
	values.set_contain(style.contain())
	values.set_aspect_ratio(style.aspect_ratio())
	values.set_column_gap(style.gap_value(.column_gap))
	values.set_row_gap(style.gap_value(.row_gap))
	values.set_grid_auto_columns(style.grid_auto_columns())
	values.set_grid_auto_rows(style.grid_auto_rows())
	values.set_grid_template_columns(style.grid_template_columns())
	values.set_grid_template_rows(style.grid_template_rows())
	values.set_grid_template_areas(style.grid_template_areas())
	values.set_grid_auto_flow(style.grid_auto_flow())
	values.set_appearance(style.appearance())
	values.set_opacity(style.opacity())
	values.set_z_index(style.z_index())
	values.set_image_rendering(style.image_rendering())
	values.set_pointer_events(style.pointer_events())
	values.set_list_style_position(style.list_style_position())
	values.set_counter_increment(style.counter_data(.counter_increment))
	values.set_counter_reset(style.counter_data(.counter_reset))
	values.set_counter_set(style.counter_data(.counter_set))
	values.set_grid_column_end(style.grid_column_end())
	values.set_grid_column_start(style.grid_column_start())
	values.set_grid_row_end(style.grid_row_end())
	values.set_grid_row_start(style.grid_row_start())
	values.set_column_span(style.column_span())
	values.set_break_after(style.break_between(.break_after))
	values.set_break_before(style.break_between(.break_before))
	values.set_break_inside(style.break_inside())
	values.set_box_decoration_break(style.box_decoration_break())
	values.set_column_fill(style.column_fill())
	values.set_block_ellipsis(style.block_ellipsis())
	values.set_continue_value(style.continue_value())
	values.set_max_lines(style.max_lines())
	values.set_webkit_box_orient(style.webkit_box_orient())
	values.set_empty_cells(style.empty_cells())
	values.set_object_fit(style.object_fit())
	values.set_object_position(style.object_position())
	values.set_unicode_bidi(style.unicode_bidi())
	values.set_isolation(style.isolation())
	values.set_mix_blend_mode(style.mix_blend_mode())
	values.set_mask_type(style.mask_type())
	values.set_cached_mask(computed_values_mask_reference(style))
	values.set_cached_mask_image(computed_values_mask_image(style))
	values.set_cached_clip_path(computed_values_clip_path(style))
	values.set_stop_opacity(style.stop_opacity())
	values.set_fill_opacity(style.fill_opacity())
	values.set_stroke_linecap(style.stroke_linecap())
	values.set_stroke_linejoin(style.stroke_linejoin())
	values.set_stroke_miterlimit(style.stroke_miterlimit())
	values.set_stroke_opacity(style.stroke_opacity())
	values.set_fill_rule(style.fill_rule())
	values.set_clip_rule(style.clip_rule())
	values.set_shape_rendering(style.shape_rendering())
	values.set_text_anchor(style.text_anchor())
	values.set_outline_offset(style.outline_offset())
	values.set_outline_style(style.outline_style())
	values.set_scrollbar_width(style.scrollbar_width())
	values.set_resize(style.resize())
	values.set_border_spacing_horizontal(style.border_spacing_horizontal())
	values.set_border_spacing_vertical(style.border_spacing_vertical())
	values.set_color_interpolation(style.color_interpolation())
	values.set_color_interpolation_filters(style.color_interpolation_filters())
	values.set_clip(style.clip())
	values.set_cursor(style.cursor())
	values.set_background_color_clip(style.background_color_clip())
	values.set_background_layers(style.background_layers())
	values.set_tab_size(style.tab_size())
	values.set_text_decoration_line(style.text_decoration_line())
	values.set_text_decoration_skip_ink(style.text_decoration_skip_ink())
	values.set_text_decoration_thickness(style.text_decoration_thickness())
	values.set_text_decoration_style(style.text_decoration_style())
	values.set_text_indent(style.text_indent())
	values.set_text_overflow(style.text_overflow())
	values.set_text_underline_offset(style.text_underline_offset())
	values.set_text_underline_position(style.text_underline_position())
	values.set_white_space_trim(style.white_space_trim())
	values.set_word_spacing(style.word_spacing())
	values.set_letter_spacing(style.letter_spacing())
	values.set_backdrop_filter(style.backdrop_filter())
	values.set_filter(style.filter())
	values.set_rotate(style.rotate())
	values.set_scale(style.scale())
	values.set_perspective(style.perspective())
	values.set_perspective_origin(style.perspective_origin())
	values.set_transformations(style.transformations())
	values.set_transform_box(style.transform_box())
	values.set_transform_origin(style.transform_origin())
	values.set_transform_style(style.transform_style())
	values.set_backface_visibility(style.backface_visibility())
	values.set_translate(style.translate())
	values.set_quotes(style.quotes())
	values.set_dominant_baseline(style.dominant_baseline())
	values.set_container_name(style.container_name())
	values.set_container_type(style.container_type())
	values.set_view_transition_name(style.view_transition_name())
	values.set_touch_action(style.touch_action())
	values.set_stroke_dasharray(style.stroke_dasharray())
	values.set_flood_opacity(style.flood_opacity())
	values.set_paint_order(style.paint_order())
	values.set_math_shift(style.math_shift())
	values.set_math_style(style.math_style())
	values.set_math_depth(style.math_depth())
	values.set_will_change(style.will_change())
	values.set_stroke_dashoffset(computed_values_length_percentage(style, .stroke_dashoffset, InitialValues.stroke_dashoffset()))
	values.set_stroke_width(computed_values_length_percentage(style, .stroke_width, InitialValues.stroke_width()))
	values.set_cx(computed_values_length_percentage(style, .cx, InitialValues.cx()))
	values.set_cy(computed_values_length_percentage(style, .cy, InitialValues.cy()))
	values.set_r(computed_values_length_percentage(style, .r, InitialValues.r()))
	values.set_rx(computed_values_length_percentage_or_auto(style, .rx))
	values.set_ry(computed_values_length_percentage_or_auto(style, .ry))
	values.set_x(computed_values_length_percentage(style, .x, LengthPercentage.from_length(Length.make_px(0))))
	values.set_y(computed_values_length_percentage(style, .y, LengthPercentage.from_length(Length.make_px(0))))
	values.set_column_count(computed_values_column_count(style))
	values.set_column_width(style.size_value(.column_width))
	values.set_column_height(style.size_value(.column_height))
	values.set_column_rule_style(style.line_style(.column_rule_style))
	mut column_rule_width := style.length(.column_rule_width).absolute_length_to_px()
	if column_rule_width.raw_value() < 0 {
		column_rule_width = CSSPixels.new(0)
	}
	values.set_column_rule_width(column_rule_width)
	mut outline_width := style.length(.outline_width).absolute_length_to_px()
	if outline_width.raw_value() < 0 {
		outline_width = CSSPixels.new(0)
	}
	values.set_outline_width(outline_width)
	values.set_transition_delay(computed_values_transition_delay(style))
	values.computed_values_resolved_ = true
	return unsafe { &ComputedValues(style) }
}

pub fn (values &ComputedValues) display() Display {
	return values.computed_layout_cache().computed_values_display_
}

pub fn (values &ComputedValues) display_before_box_type_transformation() Display {
	return values.computed_layout_cache().computed_values_display_before_transformation_
}

pub fn (values &ComputedValues) position() Positioning {
	return values.computed_layout_cache().computed_values_position_
}

pub fn (values &ComputedValues) position_anchor() ?string {
	return values.computed_layout_cache().computed_values_position_anchor_
}

pub fn (values &ComputedValues) float_() Float {
	return values.computed_layout_cache().computed_values_float_
}

pub fn (values &ComputedValues) clear() Clear {
	return values.computed_layout_cache().computed_values_clear_
}

pub fn (values &ComputedValues) direction() Direction {
	return values.computed_layout_cache().computed_values_direction_
}

pub fn (values &ComputedValues) writing_mode() WritingMode {
	return values.computed_layout_cache().computed_values_writing_mode_
}

pub fn (values &ComputedValues) overflow_x() Overflow {
	return values.computed_layout_cache().computed_values_overflow_x_
}

pub fn (values &ComputedValues) overflow_y() Overflow {
	return values.computed_layout_cache().computed_values_overflow_y_
}

pub fn (values &ComputedValues) font_size() CSSPixels {
	return values.computed_layout_cache().computed_values_font_size_
}

pub fn (values &ComputedValues) resolved_font_size_px() f64 {
	return values.computed_layout_cache().computed_values_font_size_.to_double()
}

pub fn (values &ComputedValues) line_height() CSSPixels {
	return values.computed_values_line_height_
}

pub fn (values &ComputedValues) font_weight() f64 {
	return values.computed_layout_cache().computed_values_font_weight_
}

pub fn (values &ComputedValues) font_list() &FontCascadeList {
	return values.cached_computed_font_list_ or {
		panic('ComputedValues font list was not materialized for a document')
	}
}

pub fn (values &ComputedValues) font_language_override() ?string {
	return values.computed_layout_cache().computed_values_font_language_override_
}

pub fn (values &ComputedValues) font_variation_settings() map[string]f64 {
	if values.font_variation_storage_ == unsafe { nil } { return map[string]f64{} }
	return values.font_variation_storage_.values.clone()
}

pub fn (values &ComputedValues) caret_color() Color {
	return values.computed_layout_cache().computed_values_caret_color_
}

pub fn (values &ComputedValues) color() Color {
	return values.computed_layout_cache().computed_values_color_
}

pub fn (values &ComputedValues) accent_color() ?Color {
	return values.computed_layout_cache().computed_values_accent_color_
}

pub fn (values &ComputedValues) color_scheme() PreferredColorScheme {
	return values.computed_layout_cache().computed_values_color_scheme_
}

pub fn (values &ComputedValues) width() Size {
	return values.computed_layout_cache().computed_values_width_
}

pub fn (values &ComputedValues) min_width() Size {
	return values.computed_layout_cache().computed_values_min_width_
}

pub fn (values &ComputedValues) max_width() Size {
	return values.computed_layout_cache().computed_values_max_width_
}

pub fn (values &ComputedValues) height() Size {
	return values.computed_layout_cache().computed_values_height_
}

pub fn (values &ComputedValues) min_height() Size {
	return values.computed_layout_cache().computed_values_min_height_
}

pub fn (values &ComputedValues) max_height() Size {
	return values.computed_layout_cache().computed_values_max_height_
}

pub fn (values &ComputedValues) inset() LengthBox {
	return values.computed_layout_cache().computed_values_inset_
}

pub fn (values &ComputedValues) margin() LengthBox {
	return values.computed_layout_cache().computed_values_margin_
}

pub fn (values &ComputedValues) padding() LengthBox {
	return values.computed_layout_cache().computed_values_padding_
}

pub fn (values &ComputedValues) overflow_clip_margin() LengthBox {
	return values.computed_layout_cache().computed_values_overflow_clip_margin_
}

pub fn (values &ComputedValues) border_left() BorderData {
	return values.computed_layout_cache().computed_values_border_left_
}

pub fn (values &ComputedValues) border_top() BorderData {
	return values.computed_layout_cache().computed_values_border_top_
}

pub fn (values &ComputedValues) border_right() BorderData {
	return values.computed_layout_cache().computed_values_border_right_
}

pub fn (values &ComputedValues) border_bottom() BorderData {
	return values.computed_layout_cache().computed_values_border_bottom_
}

pub fn (values &ComputedValues) border_data(width_property PropertyID) BorderData {
	return match width_property {
		.border_left_width { values.computed_layout_cache().computed_values_border_left_ }
		.border_top_width { values.computed_layout_cache().computed_values_border_top_ }
		.border_right_width { values.computed_layout_cache().computed_values_border_right_ }
		.border_bottom_width { values.computed_layout_cache().computed_values_border_bottom_ }
		else { BorderData{} }
	}
}

pub fn (values &ComputedValues) has_noninitial_border_radii() bool {
	return values.computed_layout_cache().computed_values_has_noninitial_border_radii_
}

pub fn (values &ComputedValues) border_bottom_left_radius() BorderRadiusData {
	return values.computed_layout_cache().computed_values_border_bottom_left_radius_
}

pub fn (values &ComputedValues) border_bottom_right_radius() BorderRadiusData {
	return values.computed_layout_cache().computed_values_border_bottom_right_radius_
}

pub fn (values &ComputedValues) border_top_left_radius() BorderRadiusData {
	return values.computed_layout_cache().computed_values_border_top_left_radius_
}

pub fn (values &ComputedValues) border_top_right_radius() BorderRadiusData {
	return values.computed_layout_cache().computed_values_border_top_right_radius_
}

pub fn (values &ComputedValues) size_value(property_id PropertyID) Size {
	return match property_id {
		.width { values.computed_layout_cache().computed_values_width_ }
		.min_width { values.computed_layout_cache().computed_values_min_width_ }
		.max_width { values.computed_layout_cache().computed_values_max_width_ }
		.height { values.computed_layout_cache().computed_values_height_ }
		.min_height { values.computed_layout_cache().computed_values_min_height_ }
		.max_height { values.computed_layout_cache().computed_values_max_height_ }
		.column_width { values.computed_layout_cache().computed_values_column_width_ }
		.column_height { values.computed_layout_cache().computed_values_column_height_ }
		else { unsafe { &ComputedProperties(values) }.size_value(property_id) }
	}
}

// Layout resolves the same typed fields that ComputedValues stores in C++.
// This avoids returning to the ComputedProperties StyleValue graph for every
// used-value query in block, flex, grid, and table layout.
pub fn (values &ComputedValues) length_percentage_to_px(property_id PropertyID, percentage_basis_px f64) ?f64 {
	mut length_percentage := ?LengthPercentage(none)
	match property_id {
		.width {
			length_percentage = values.width().length_percentage_
		}
		.min_width {
			length_percentage = values.min_width().length_percentage_
		}
		.max_width {
			length_percentage = values.max_width().length_percentage_
		}
		.height {
			length_percentage = values.height().length_percentage_
		}
		.min_height {
			length_percentage = values.min_height().length_percentage_
		}
		.max_height {
			length_percentage = values.max_height().length_percentage_
		}
		.left {
			length_percentage = values.inset().left().length_percentage_
		}
		.top {
			length_percentage = values.inset().top().length_percentage_
		}
		.right {
			length_percentage = values.inset().right().length_percentage_
		}
		.bottom {
			length_percentage = values.inset().bottom().length_percentage_
		}
		.margin_left {
			length_percentage = values.margin().left().length_percentage_
		}
		.margin_top {
			length_percentage = values.margin().top().length_percentage_
		}
		.margin_right {
			length_percentage = values.margin().right().length_percentage_
		}
		.margin_bottom {
			length_percentage = values.margin().bottom().length_percentage_
		}
		.padding_left {
			length_percentage = values.padding().left().length_percentage_
		}
		.padding_top {
			length_percentage = values.padding().top().length_percentage_
		}
		.padding_right {
			length_percentage = values.padding().right().length_percentage_
		}
		.padding_bottom {
			length_percentage = values.padding().bottom().length_percentage_
		}
		.overflow_clip_margin_left {
			length_percentage = values.overflow_clip_margin().left().length_percentage_
		}
		.overflow_clip_margin_top {
			length_percentage = values.overflow_clip_margin().top().length_percentage_
		}
		.overflow_clip_margin_right {
			length_percentage = values.overflow_clip_margin().right().length_percentage_
		}
		.overflow_clip_margin_bottom {
			length_percentage = values.overflow_clip_margin().bottom().length_percentage_
		}
		.stroke_dashoffset {
			length_percentage = values.stroke_dashoffset()
		}
		.stroke_width {
			length_percentage = values.stroke_width()
		}
		.cx {
			length_percentage = values.cx()
		}
		.cy {
			length_percentage = values.cy()
		}
		.r {
			length_percentage = values.r()
		}
		.rx {
			length_percentage = values.rx().length_percentage_
		}
		.ry {
			length_percentage = values.ry().length_percentage_
		}
		.x {
			length_percentage = values.x()
		}
		.y {
			length_percentage = values.y()
		}
		else {
			return computed_properties_length_percentage_to_px(unsafe { &ComputedProperties(values) }, property_id, percentage_basis_px)
		}
	}
	resolved := length_percentage or { return none }
	if resolved.is_calculated() {
		return computed_properties_length_percentage_to_px(unsafe { &ComputedProperties(values) },property_id,percentage_basis_px)
	}
	// Absolute lengths and percentages do not consume font, viewport or
	// container-query state. Preserve the shared fixed-point conversion while
	// avoiding a context and its query-cache allocation for these common cases.
	if resolved.is_length() {
		length := resolved.length()
		if length.is_absolute() {
			return unsafe { &ComputedProperties(values) }.absolute_layout_length_to_px(length).to_double()
		}
	} else if resolved.is_percentage() {
		return resolved.to_px(LengthResolutionContext{}, CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
	}
	context := unsafe { &ComputedProperties(values) }.length_resolution_context()
	return resolved.to_px(context, CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
}

pub fn (values &ComputedValues) length_box(left_id PropertyID, top_id PropertyID, right_id PropertyID, bottom_id PropertyID, default_value LengthPercentageOrAuto) LengthBox {
	if left_id == .left && top_id == .top && right_id == .right && bottom_id == .bottom {
		return values.computed_layout_cache().computed_values_inset_
	}
	if left_id == .margin_left && top_id == .margin_top && right_id == .margin_right
		&& bottom_id == .margin_bottom {
		return values.computed_layout_cache().computed_values_margin_
	}
	if left_id == .padding_left && top_id == .padding_top && right_id == .padding_right
		&& bottom_id == .padding_bottom {
		return values.computed_layout_cache().computed_values_padding_
	}
	if left_id == .overflow_clip_margin_left && top_id == .overflow_clip_margin_top
		&& right_id == .overflow_clip_margin_right && bottom_id == .overflow_clip_margin_bottom {
		return values.computed_layout_cache().computed_values_overflow_clip_margin_
	}
	return unsafe { &ComputedProperties(values) }.length_box(left_id, top_id, right_id, bottom_id, default_value)
}

pub fn (values &ComputedValues) flex_direction() FlexDirection {
	return values.computed_layout_cache().computed_values_flex_direction_
}

pub fn (values &ComputedValues) flex_wrap() FlexWrap {
	return values.computed_layout_cache().computed_values_flex_wrap_
}

pub fn (values &ComputedValues) flex_basis() FlexBasis {
	return values.computed_layout_cache().computed_values_flex_basis_
}

pub fn (values &ComputedValues) flex_grow() f32 {
	return values.computed_layout_cache().computed_values_flex_grow_
}

pub fn (values &ComputedValues) flex_shrink() f32 {
	return values.computed_layout_cache().computed_values_flex_shrink_
}

pub fn (values &ComputedValues) order() int {
	return values.computed_layout_cache().computed_values_order_
}

pub fn (values &ComputedValues) align_content() AlignContent {
	return values.computed_layout_cache().computed_values_align_content_
}

pub fn (values &ComputedValues) align_items() AlignItems {
	return values.computed_layout_cache().computed_values_align_items_
}

pub fn (values &ComputedValues) align_self() AlignSelf {
	return values.computed_layout_cache().computed_values_align_self_
}

pub fn (values &ComputedValues) justify_content() JustifyContent {
	return values.computed_layout_cache().computed_values_justify_content_
}

pub fn (values &ComputedValues) justify_items() JustifyItems {
	return values.computed_layout_cache().computed_values_justify_items_
}

pub fn (values &ComputedValues) justify_self() JustifySelf {
	return values.computed_layout_cache().computed_values_justify_self_
}

pub fn (values &ComputedValues) text_align() TextAlign {
	return values.computed_layout_cache().computed_values_text_align_
}

pub fn (values &ComputedValues) text_justify() TextJustify {
	return values.computed_layout_cache().computed_values_text_justify_
}

pub fn (values &ComputedValues) text_transform() TextTransform {
	return values.computed_layout_cache().computed_values_text_transform_
}

pub fn (values &ComputedValues) text_wrap_mode() TextWrapMode {
	return values.computed_layout_cache().computed_values_text_wrap_mode_
}

pub fn (values &ComputedValues) white_space_collapse() WhiteSpaceCollapse {
	return values.computed_layout_cache().computed_values_white_space_collapse_
}

pub fn (values &ComputedValues) word_break() WordBreak {
	return values.computed_layout_cache().computed_values_word_break_
}

pub fn (values &ComputedValues) visibility() Visibility {
	return values.computed_layout_cache().computed_values_visibility_
}

pub fn (values &ComputedValues) box_sizing() BoxSizing {
	return values.computed_layout_cache().computed_values_box_sizing_
}

// CSS Sizing 4 applies an `auto <ratio>` preferred aspect ratio to the content
// box. An author-specified ratio without `auto` follows `box-sizing`.
pub fn (values &ComputedValues) box_sizing_for_aspect_ratio() BoxSizing {
	if values.aspect_ratio().use_natural_aspect_ratio_if_available {
		return .content_box
	}
	return values.box_sizing()
}

pub fn (values &ComputedValues) vertical_align() VerticalAlign {
	return values.computed_layout_cache().computed_values_vertical_align_
}

pub fn (values &ComputedValues) caption_side() CaptionSide {
	return values.computed_layout_cache().computed_values_caption_side_
}

pub fn (values &ComputedValues) content_visibility() ContentVisibility {
	return values.computed_layout_cache().computed_values_content_visibility_
}

pub fn (values &ComputedValues) user_select() UserSelect {
	return values.computed_layout_cache().computed_values_user_select_
}

pub fn (values &ComputedValues) table_layout() TableLayout {
	return values.computed_layout_cache().computed_values_table_layout_
}

pub fn (values &ComputedValues) border_collapse() BorderCollapse {
	return values.computed_layout_cache().computed_values_border_collapse_
}

pub fn (values &ComputedValues) contain() Containment {
	return values.computed_layout_cache().computed_values_contain_
}

pub fn (values &ComputedValues) aspect_ratio() AspectRatio {
	return values.computed_layout_cache().computed_values_aspect_ratio_
}

pub fn (values &ComputedValues) gap_value(property_id PropertyID) GapValue {
	return match property_id {
		.column_gap { values.computed_layout_cache().computed_values_column_gap_ }
		.row_gap { values.computed_layout_cache().computed_values_row_gap_ }
		else { unsafe { &ComputedProperties(values) }.gap_value(property_id) }
	}
}

pub fn (values &ComputedValues) column_gap() GapValue {
	return values.computed_layout_cache().computed_values_column_gap_
}

pub fn (values &ComputedValues) row_gap() GapValue {
	return values.computed_layout_cache().computed_values_row_gap_
}

pub fn (values &ComputedValues) grid_auto_columns() GridTrackSizeList {
	return values.computed_layout_cache().computed_values_grid_auto_columns_
}

pub fn (values &ComputedValues) grid_auto_rows() GridTrackSizeList {
	return values.computed_layout_cache().computed_values_grid_auto_rows_
}

pub fn (values &ComputedValues) grid_template_columns() GridTrackSizeList {
	return values.computed_layout_cache().rare_data().computed_values_grid_template_columns_
}

pub fn (values &ComputedValues) grid_template_rows() GridTrackSizeList {
	return values.computed_layout_cache().rare_data().computed_values_grid_template_rows_
}

pub fn (values &ComputedValues) grid_template_areas() GridTemplateAreas {
	return values.computed_layout_cache().rare_data().computed_values_grid_template_areas_
}

pub fn (values &ComputedValues) grid_auto_flow() GridAutoFlow {
	return values.computed_layout_cache().computed_values_grid_auto_flow_
}

pub fn (values &ComputedValues) appearance() Appearance {
	return values.computed_layout_cache().computed_values_appearance_
}

pub fn (values &ComputedValues) opacity() f32 {
	return values.computed_layout_cache().computed_values_opacity_
}

pub fn (values &ComputedValues) z_index() ?int {
	return values.computed_layout_cache().computed_values_z_index_
}

pub fn (values &ComputedValues) image_rendering() ImageRendering {
	return values.computed_layout_cache().computed_values_image_rendering_
}

pub fn (values &ComputedValues) pointer_events() PointerEvents {
	return values.computed_layout_cache().computed_values_pointer_events_
}

pub fn (values &ComputedValues) list_style_position() ListStylePosition {
	return values.computed_layout_cache().computed_values_list_style_position_
}

pub fn (values &ComputedProperties) computed_list_style_type() ListStyleType {
	if voidptr(values.computed_list_style_storage_) == unsafe { nil } { return ListStyleType{} }
	return *values.computed_list_style_storage_
}

pub fn (values &ComputedProperties) computed_content() ?ContentData {
	if voidptr(values.computed_content_storage_) == unsafe { nil } { return none }
	return *values.computed_content_storage_
}

pub fn (values &ComputedValues) grid_column_end() GridTrackPlacement {
	return values.computed_layout_cache().computed_values_grid_column_end_
}

pub fn (values &ComputedValues) grid_column_start() GridTrackPlacement {
	return values.computed_layout_cache().computed_values_grid_column_start_
}

pub fn (values &ComputedValues) grid_row_end() GridTrackPlacement {
	return values.computed_layout_cache().computed_values_grid_row_end_
}

pub fn (values &ComputedValues) grid_row_start() GridTrackPlacement {
	return values.computed_layout_cache().computed_values_grid_row_start_
}

pub fn (values &ComputedValues) column_span() ColumnSpan {
	return values.computed_layout_cache().computed_values_column_span_
}

pub fn (values &ComputedValues) break_after() BreakBetween {
	return values.computed_layout_cache().computed_values_break_after_
}

pub fn (values &ComputedValues) break_before() BreakBetween {
	return values.computed_layout_cache().computed_values_break_before_
}

pub fn (values &ComputedValues) break_inside() BreakInside {
	return values.computed_layout_cache().computed_values_break_inside_
}

pub fn (values &ComputedValues) box_decoration_break() BoxDecorationBreak {
	return values.computed_layout_cache().computed_values_box_decoration_break_
}

pub fn (values &ComputedValues) column_fill() ColumnFill {
	return values.computed_layout_cache().computed_values_column_fill_
}

pub fn (values &ComputedValues) block_ellipsis() BlockEllipsis {
	return values.computed_layout_cache().computed_values_block_ellipsis_
}

pub fn (values &ComputedValues) continue_value() ContinueValue {
	return values.computed_layout_cache().computed_values_continue_
}

pub fn (values &ComputedValues) max_lines() ?int {
	return values.computed_layout_cache().computed_values_max_lines_
}

pub fn (values &ComputedValues) webkit_box_orient() WebkitBoxOrient {
	return values.computed_layout_cache().computed_values_webkit_box_orient_
}

pub fn (values &ComputedValues) effective_flex_direction() FlexDirection {
	if values.display_before_box_type_transformation().is_webkit_box_inside() {
		return if values.webkit_box_orient() == .vertical { .column } else { .row }
	}
	return values.flex_direction()
}

pub fn (values &ComputedValues) empty_cells() EmptyCells {
	return values.computed_layout_cache().computed_values_empty_cells_
}

pub fn (values &ComputedValues) object_fit() ObjectFit {
	return values.computed_layout_cache().computed_values_object_fit_
}

pub fn (values &ComputedValues) object_position() Position {
	return values.computed_layout_cache().computed_values_object_position_
}

pub fn (values &ComputedValues) unicode_bidi() UnicodeBidi {
	return values.computed_layout_cache().computed_values_unicode_bidi_
}

pub fn (values &ComputedValues) isolation() Isolation {
	return values.computed_layout_cache().computed_values_isolation_
}

pub fn (values &ComputedValues) mix_blend_mode() MixBlendMode {
	return values.computed_layout_cache().computed_values_mix_blend_mode_
}

pub fn (values &ComputedValues) mask_type() MaskType {
	return values.computed_layout_cache().computed_values_mask_type_
}

pub fn (values &ComputedValues) mask() ?MaskReference {
	return values.computed_layout_cache().rare_data().computed_values_mask_
}

pub fn (values &ComputedValues) mask_image() ?ImageStyleValue {
	return values.computed_layout_cache().rare_data().computed_values_mask_image_
}

pub fn (values &ComputedValues) clip_path() ?ClipPathReference {
	return values.computed_layout_cache().rare_data().computed_values_clip_path_
}

pub fn (values &ComputedValues) stop_opacity() f32 {
	return values.computed_layout_cache().computed_values_stop_opacity_
}

pub fn (values &ComputedValues) fill_opacity() f32 {
	return values.computed_layout_cache().computed_values_fill_opacity_
}

pub fn (values &ComputedValues) stroke_linecap() StrokeLinecap {
	return values.computed_layout_cache().computed_values_stroke_linecap_
}

pub fn (values &ComputedValues) stroke_linejoin() StrokeLinejoin {
	return values.computed_layout_cache().computed_values_stroke_linejoin_
}

pub fn (values &ComputedValues) stroke_miterlimit() f64 {
	return values.computed_layout_cache().computed_values_stroke_miterlimit_
}

pub fn (values &ComputedValues) stroke_opacity() f32 {
	return values.computed_layout_cache().computed_values_stroke_opacity_
}

pub fn (values &ComputedValues) fill_rule() FillRule {
	return values.computed_layout_cache().computed_values_fill_rule_
}

pub fn (values &ComputedValues) clip_rule() ClipRule {
	return values.computed_layout_cache().computed_values_clip_rule_
}

pub fn (values &ComputedValues) shape_rendering() ShapeRendering {
	return values.computed_layout_cache().computed_values_shape_rendering_
}

pub fn (values &ComputedValues) text_anchor() TextAnchor {
	return values.computed_layout_cache().computed_values_text_anchor_
}

pub fn (values &ComputedValues) outline_offset() Length {
	return values.computed_layout_cache().computed_values_outline_offset_
}

pub fn (values &ComputedValues) outline_style() OutlineStyle {
	return values.computed_layout_cache().computed_values_outline_style_
}

pub fn (values &ComputedValues) scrollbar_width() ScrollbarWidth {
	return values.computed_layout_cache().computed_values_scrollbar_width_
}

pub fn (values &ComputedValues) resize() Resize {
	return values.computed_layout_cache().computed_values_resize_
}

pub fn (values &ComputedValues) border_spacing_horizontal() Length {
	return values.computed_layout_cache().computed_values_border_spacing_horizontal_
}

pub fn (values &ComputedValues) border_spacing_vertical() Length {
	return values.computed_layout_cache().computed_values_border_spacing_vertical_
}

pub fn (values &ComputedValues) color_interpolation() ColorInterpolation {
	return values.computed_layout_cache().computed_values_color_interpolation_
}

pub fn (values &ComputedValues) color_interpolation_filters() ColorInterpolation {
	return values.computed_layout_cache().computed_values_color_interpolation_filters_
}

pub fn (values &ComputedValues) clip() Clip {
	return values.computed_layout_cache().computed_values_clip_
}

pub fn (values &ComputedValues) cursor() []CursorData {
	return values.computed_layout_cache().computed_values_cursor_
}

pub fn (values &ComputedValues) background_color_clip() BackgroundBox {
	return values.computed_layout_cache().computed_values_background_color_clip_
}

pub fn (values &ComputedValues) background_color() Color {
	return values.computed_layout_cache().computed_values_background_color_
}

pub fn (values &ComputedValues) background_layers() []BackgroundLayerData {
	return values.computed_layout_cache().computed_values_background_layers_
}

pub fn (values &ComputedValues) tab_size() TabSize {
	return values.computed_layout_cache().computed_values_tab_size_
}

pub fn (values &ComputedValues) text_decoration_line() []TextDecorationLine {
	return values.computed_layout_cache().computed_values_text_decoration_line_
}

pub fn (values &ComputedValues) text_decoration_skip_ink() TextDecorationSkipInk {
	return values.computed_layout_cache().computed_values_text_decoration_skip_ink_
}

pub fn (values &ComputedValues) text_decoration_thickness() TextDecorationThickness {
	return values.computed_layout_cache().computed_values_text_decoration_thickness_
}

pub fn (values &ComputedValues) text_decoration_style() TextDecorationStyle {
	return values.computed_layout_cache().computed_values_text_decoration_style_
}

pub fn (values &ComputedValues) text_decoration_color() Color {
	return values.computed_layout_cache().computed_values_text_decoration_color_
}

pub fn (values &ComputedValues) text_indent() TextIndentData {
	return values.computed_layout_cache().computed_values_text_indent_
}

pub fn (values &ComputedValues) text_overflow() TextOverflow {
	return values.computed_layout_cache().computed_values_text_overflow_
}

pub fn (values &ComputedValues) text_underline_offset() CSSPixels {
	return values.computed_layout_cache().computed_values_text_underline_offset_
}

pub fn (values &ComputedValues) text_underline_position() TextUnderlinePosition {
	return values.computed_layout_cache().computed_values_text_underline_position_
}

pub fn (values &ComputedValues) white_space_trim() WhiteSpaceTrimData {
	return values.computed_layout_cache().computed_values_white_space_trim_
}

pub fn (values &ComputedValues) word_spacing() CSSPixels {
	return values.computed_layout_cache().computed_values_word_spacing_
}

pub fn (values &ComputedValues) letter_spacing() CSSPixels {
	return values.computed_layout_cache().computed_values_letter_spacing_
}

pub fn (values &ComputedValues) backdrop_filter() Filter {
	return values.computed_layout_cache().rare_data().computed_values_backdrop_filter_
}

pub fn (values &ComputedValues) filter() Filter {
	return values.computed_layout_cache().rare_data().computed_values_filter_
}

pub fn (values &ComputedValues) rotate() ?TransformationData {
	return values.computed_layout_cache().rare_data().computed_values_rotate_
}

pub fn (values &ComputedValues) scale() ?TransformationData {
	return values.computed_layout_cache().rare_data().computed_values_scale_
}

pub fn (values &ComputedValues) perspective() ?CSSPixels {
	return values.computed_layout_cache().rare_data().computed_values_perspective_
}

pub fn (values &ComputedValues) perspective_origin() Position {
	return values.computed_layout_cache().rare_data().computed_values_perspective_origin_
}

pub fn (values &ComputedValues) transformations() []TransformationData {
	return values.computed_layout_cache().rare_data().computed_values_transformations_
}

pub fn (values &ComputedValues) transform_box() TransformBox {
	return values.computed_layout_cache().rare_data().computed_values_transform_box_
}

pub fn (values &ComputedValues) transform_origin() TransformOrigin {
	return values.computed_layout_cache().rare_data().computed_values_transform_origin_
}

pub fn (values &ComputedValues) transform_style() TransformStyle {
	return values.computed_layout_cache().rare_data().computed_values_transform_style_
}

pub fn (values &ComputedValues) backface_visibility() BackfaceVisibility {
	return values.computed_layout_cache().computed_values_backface_visibility_
}

pub fn (values &ComputedValues) translate() ?TransformationData {
	return values.computed_layout_cache().rare_data().computed_values_translate_
}

pub fn (values &ComputedValues) quotes() QuotesData {
	return values.computed_layout_cache().computed_values_quotes_
}

pub fn (values &ComputedValues) dominant_baseline() ?BaselineMetric {
	return values.computed_layout_cache().computed_values_dominant_baseline_
}

pub fn (values &ComputedValues) container_name() []string {
	return values.computed_layout_cache().computed_values_container_name_
}

pub fn (values &ComputedValues) container_type() ContainerType {
	return values.computed_layout_cache().computed_values_container_type_
}

pub fn (values &ComputedValues) view_transition_name() ?string {
	return values.computed_layout_cache().computed_values_view_transition_name_
}

pub fn (values &ComputedValues) touch_action() TouchActionData {
	return values.computed_layout_cache().computed_values_touch_action_
}

pub fn (values &ComputedValues) stroke_dasharray() []StrokeDasharrayItem {
	return values.computed_layout_cache().computed_values_stroke_dasharray_
}

pub fn (values &ComputedValues) flood_opacity() f32 {
	return values.computed_layout_cache().computed_values_flood_opacity_
}

pub fn (values &ComputedValues) paint_order() PaintOrderList {
	return values.computed_layout_cache().computed_values_paint_order_
}

pub fn (values &ComputedValues) math_shift() MathShift {
	return values.computed_layout_cache().computed_values_math_shift_
}

pub fn (values &ComputedValues) math_style() MathStyle {
	return values.computed_layout_cache().computed_values_math_style_
}

pub fn (values &ComputedValues) math_depth() int {
	return values.computed_layout_cache().computed_values_math_depth_
}

pub fn (values &ComputedValues) will_change() WillChange {
	return values.computed_layout_cache().computed_values_will_change_
}

pub fn (values &ComputedValues) stroke_dashoffset() LengthPercentage {
	return values.computed_layout_cache().computed_values_stroke_dashoffset_
}

pub fn (values &ComputedValues) stroke_width() LengthPercentage {
	return values.computed_layout_cache().computed_values_stroke_width_
}

pub fn (values &ComputedValues) cx() LengthPercentage {
	return values.computed_layout_cache().rare_data().computed_values_cx_
}

pub fn (values &ComputedValues) cy() LengthPercentage {
	return values.computed_layout_cache().rare_data().computed_values_cy_
}

pub fn (values &ComputedValues) r() LengthPercentage {
	return values.computed_layout_cache().rare_data().computed_values_r_
}

pub fn (values &ComputedValues) rx() LengthPercentageOrAuto {
	return values.computed_layout_cache().computed_values_rx_
}

pub fn (values &ComputedValues) ry() LengthPercentageOrAuto {
	return values.computed_layout_cache().computed_values_ry_
}

pub fn (values &ComputedValues) x() LengthPercentage {
	return values.computed_layout_cache().rare_data().computed_values_x_
}

pub fn (values &ComputedValues) y() LengthPercentage {
	return values.computed_layout_cache().rare_data().computed_values_y_
}

pub fn (values &ComputedValues) column_count() ?int {
	return values.computed_layout_cache().computed_values_column_count_
}

pub fn (values &ComputedValues) column_width() Size {
	return values.computed_layout_cache().computed_values_column_width_
}

pub fn (values &ComputedValues) column_height() Size {
	return values.computed_layout_cache().computed_values_column_height_
}

// https://drafts.csswg.org/css-multicol-2/#the-multi-column-model
pub fn (values &ComputedValues) establishes_multi_column_container() bool {
	return !values.column_width().is_auto() || values.column_count() != none
}

pub fn (values &ComputedValues) column_rule_color() Color {
	return values.computed_layout_cache().computed_values_column_rule_color_
}

pub fn (values &ComputedValues) column_rule_style() LineStyle {
	return values.computed_layout_cache().computed_values_column_rule_style_
}

pub fn (values &ComputedValues) column_rule_width() CSSPixels {
	return values.computed_layout_cache().computed_values_column_rule_width_
}

pub fn (values &ComputedValues) outline_width() CSSPixels {
	return values.computed_layout_cache().computed_values_outline_width_
}

pub fn (values &ComputedValues) outline_color() Color {
	return values.computed_layout_cache().computed_values_outline_color_
}

pub fn (values &ComputedValues) transition_delay() Time {
	return values.computed_layout_cache().computed_values_transition_delay_
}

pub fn (values &ComputedValues) webkit_text_fill_color() Color {
	return values.computed_layout_cache().computed_values_webkit_text_fill_color_
}

pub fn (values &ComputedValues) stop_color() Color {
	return values.computed_layout_cache().computed_values_stop_color_
}

pub fn (values &ComputedValues) flood_color() Color {
	return values.computed_layout_cache().computed_values_flood_color_
}

pub fn (values &ComputedValues) fill() ?SVGPaint {
	return values.computed_layout_cache().computed_values_fill_
}

pub fn (values &ComputedValues) stroke() ?SVGPaint {
	return values.computed_layout_cache().computed_values_stroke_
}

pub fn (values &ComputedValues) text_shadow() []ShadowData {
	return values.computed_layout_cache().computed_values_text_shadow_.clone()
}

pub fn (values &ComputedValues) box_shadow() []ShadowData {
	return values.computed_layout_cache().computed_values_box_shadow_.clone()
}

pub fn (values &ComputedValues) computed_scrollbar_color() ScrollbarColorData {
	return values.computed_layout_cache().computed_values_scrollbar_color_
}

pub fn (values &ComputedValues) counter_increment() []CounterData {
	return values.computed_layout_cache().computed_values_counter_increment_.clone()
}

pub fn (values &ComputedValues) counter_reset() []CounterData {
	return values.computed_layout_cache().computed_values_counter_reset_.clone()
}

pub fn (values &ComputedValues) counter_set() []CounterData {
	return values.computed_layout_cache().computed_values_counter_set_.clone()
}

pub fn (values &ComputedValues) clone_inherited_values() &ComputedValues {
	source := unsafe { &ComputedProperties(values) }
	mut clone := ComputedProperties.new()
	owns_cache_write := clone.begin_computed_layout_cache_write()
	defer { clone.finish_computed_layout_cache_write(owns_cache_write) }
	clone.viewport_rect_ = source.viewport_rect_
	clone.root_font_size_px_ = source.root_font_size_px_
	clone.root_line_height_px_ = source.root_line_height_px_
	for property_id in computed_interpolation_longhand_property_ids() {
		mut value := computed_interpolation_property_initial_value(property_id)
		mut inherited := ComputedPropertyInheritance.no
		if computed_interpolation_is_inherited_property(property_id) {
			if inherited_value := source.property(property_id, .yes) {
				value = inherited_value
				inherited = .yes
			}
		}
		clone.set_property(property_id, value, inherited, .no)
	}
	result := resolve_computed_values(clone)
	mut mutable_result := unsafe { &MutableComputedValues(result) }
	mutable_result.ensure_computed_layout_cache().computed_values_caret_color_ = values.computed_layout_cache().computed_values_caret_color_
	mutable_result.ensure_computed_layout_cache().computed_values_color_ = values.computed_layout_cache().computed_values_color_
	mutable_result.ensure_computed_layout_cache().computed_values_accent_color_ = values.computed_layout_cache().computed_values_accent_color_
	mutable_result.ensure_computed_layout_cache().computed_values_color_scheme_ = values.computed_layout_cache().computed_values_color_scheme_
	mutable_result.ensure_computed_layout_cache().computed_values_webkit_text_fill_color_ = values.computed_layout_cache().computed_values_webkit_text_fill_color_
	mutable_result.ensure_computed_layout_cache().computed_values_fill_ = values.computed_layout_cache().computed_values_fill_
	mutable_result.ensure_computed_layout_cache().computed_values_stroke_ = values.computed_layout_cache().computed_values_stroke_
	mutable_result.ensure_computed_layout_cache().computed_values_text_shadow_ = values.computed_layout_cache().computed_values_text_shadow_.clone()
	mutable_result.ensure_computed_layout_cache().computed_values_scrollbar_color_ = values.computed_layout_cache().computed_values_scrollbar_color_
	mutable_result.computed_list_style_storage_ = values.computed_list_style_storage_
	mutable_result.cached_computed_font_list_ = source.cached_computed_font_list_
	mutable_result.cached_computed_font_list_generation_ = source.cached_computed_font_list_generation_
	mutable_result.cached_first_available_computed_font_ = source.cached_first_available_computed_font_
	return result
}

pub fn (mut values MutableComputedValues) set_display(value Display) {
	values.ensure_computed_layout_cache().computed_values_display_ = value
}

pub fn (mut values MutableComputedValues) inherit_from(other &ComputedValues) {
	// This copies already materialized inherited values without invoking font
	// discovery or parsers. Intern the completed record in the source document
	// while preserving all snapshots retained by older anonymous wrappers.
	mut initial_snapshot := begin_inherited_layout_snapshot(unsafe { &ComputedProperties(values) },
		unsafe { &ComputedProperties(other) })
	owns_cache_write := values.begin_computed_layout_cache_write()
	defer {
		values.finish_computed_layout_cache_write(owns_cache_write)
		initial_snapshot.publish(mut values)
	}
	mut property_values := unsafe { &ComputedProperties(values) }
	property_values.inherit_from_for_layout(unsafe { &ComputedProperties(other) })

	// ComputedValues::inherit_from() copies the inherited-value record as one
	// operation. These are the translated fields currently materialized in V;
	// the retained property graph above carries the remaining inherited values.
	values.ensure_computed_layout_cache().computed_values_font_size_ = other.computed_layout_cache().computed_values_font_size_
	values.ensure_computed_layout_cache().computed_values_font_weight_ = other.computed_layout_cache().computed_values_font_weight_
	values.ensure_computed_layout_cache().computed_values_font_language_override_ = other.computed_layout_cache().computed_values_font_language_override_
	if other.font_variation_storage_ == unsafe { nil } {
		values.font_variation_storage_ = unsafe { nil }
	} else {
		values.set_font_variation_settings(other.font_variation_storage_.values)
	}
	values.computed_values_line_height_ = other.computed_values_line_height_
	values.cached_computed_font_list_ = other.cached_computed_font_list_
	values.cached_computed_font_list_generation_ = other.cached_computed_font_list_generation_
	values.cached_computed_font_list_owner_ = other.cached_computed_font_list_owner_
	values.cached_first_available_computed_font_ = other.cached_first_available_computed_font_
	values.ensure_computed_layout_cache().computed_values_caret_color_ = other.computed_layout_cache().computed_values_caret_color_
	values.ensure_computed_layout_cache().computed_values_color_ = other.computed_layout_cache().computed_values_color_
	values.ensure_computed_layout_cache().computed_values_accent_color_ = other.computed_layout_cache().computed_values_accent_color_
	values.ensure_computed_layout_cache().computed_values_color_scheme_ = other.computed_layout_cache().computed_values_color_scheme_
	values.ensure_computed_layout_cache().computed_values_webkit_text_fill_color_ = other.computed_layout_cache().computed_values_webkit_text_fill_color_
	values.ensure_computed_layout_cache().computed_values_fill_ = other.computed_layout_cache().computed_values_fill_
	values.ensure_computed_layout_cache().computed_values_stroke_ = other.computed_layout_cache().computed_values_stroke_
	values.ensure_computed_layout_cache().computed_values_text_shadow_ = other.computed_layout_cache().computed_values_text_shadow_.clone()
	values.ensure_computed_layout_cache().computed_values_scrollbar_color_ = other.computed_layout_cache().computed_values_scrollbar_color_
	values.ensure_computed_layout_cache().computed_values_border_collapse_ = other.computed_layout_cache().computed_values_border_collapse_
	values.ensure_computed_layout_cache().computed_values_caption_side_ = other.computed_layout_cache().computed_values_caption_side_
	values.ensure_computed_layout_cache().computed_values_empty_cells_ = other.computed_layout_cache().computed_values_empty_cells_
	values.ensure_computed_layout_cache().computed_values_content_visibility_ = other.computed_layout_cache().computed_values_content_visibility_
	values.ensure_computed_layout_cache().computed_values_image_rendering_ = other.computed_layout_cache().computed_values_image_rendering_
	values.ensure_computed_layout_cache().computed_values_pointer_events_ = other.computed_layout_cache().computed_values_pointer_events_
	values.ensure_computed_layout_cache().computed_values_text_align_ = other.computed_layout_cache().computed_values_text_align_
	values.ensure_computed_layout_cache().computed_values_text_justify_ = other.computed_layout_cache().computed_values_text_justify_
	values.ensure_computed_layout_cache().computed_values_text_transform_ = other.computed_layout_cache().computed_values_text_transform_
	values.ensure_computed_layout_cache().computed_values_text_wrap_mode_ = other.computed_layout_cache().computed_values_text_wrap_mode_
	values.ensure_computed_layout_cache().computed_values_white_space_collapse_ = other.computed_layout_cache().computed_values_white_space_collapse_
	values.ensure_computed_layout_cache().computed_values_word_break_ = other.computed_layout_cache().computed_values_word_break_
	values.ensure_computed_layout_cache().computed_values_hyphens_ = other.computed_layout_cache().computed_values_hyphens_
	values.ensure_computed_layout_cache().computed_values_list_style_position_ = other.computed_layout_cache().computed_values_list_style_position_
	values.computed_list_style_storage_ = other.computed_list_style_storage_
	values.ensure_computed_layout_cache().computed_values_visibility_ = other.computed_layout_cache().computed_values_visibility_
	values.ensure_computed_layout_cache().computed_values_direction_ = other.computed_layout_cache().computed_values_direction_
	values.ensure_computed_layout_cache().computed_values_writing_mode_ = other.computed_layout_cache().computed_values_writing_mode_
	values.ensure_computed_layout_cache().computed_values_fill_rule_ = other.computed_layout_cache().computed_values_fill_rule_
	values.ensure_computed_layout_cache().computed_values_stroke_linecap_ = other.computed_layout_cache().computed_values_stroke_linecap_
	values.ensure_computed_layout_cache().computed_values_fill_opacity_ = other.computed_layout_cache().computed_values_fill_opacity_
	values.ensure_computed_layout_cache().computed_values_stroke_linejoin_ = other.computed_layout_cache().computed_values_stroke_linejoin_
	values.ensure_computed_layout_cache().computed_values_text_anchor_ = other.computed_layout_cache().computed_values_text_anchor_
	values.ensure_computed_layout_cache().computed_values_clip_rule_ = other.computed_layout_cache().computed_values_clip_rule_
	values.ensure_computed_layout_cache().computed_values_stroke_miterlimit_ = other.computed_layout_cache().computed_values_stroke_miterlimit_
	values.ensure_computed_layout_cache().computed_values_stroke_opacity_ = other.computed_layout_cache().computed_values_stroke_opacity_
	values.ensure_computed_layout_cache().computed_values_border_spacing_horizontal_ = other.computed_layout_cache().computed_values_border_spacing_horizontal_
	values.ensure_computed_layout_cache().computed_values_border_spacing_vertical_ = other.computed_layout_cache().computed_values_border_spacing_vertical_
	values.ensure_computed_layout_cache().computed_values_color_interpolation_ = other.computed_layout_cache().computed_values_color_interpolation_
	values.ensure_computed_layout_cache().computed_values_color_interpolation_filters_ = other.computed_layout_cache().computed_values_color_interpolation_filters_
	values.ensure_computed_layout_cache().computed_values_backface_visibility_ = other.computed_layout_cache().computed_values_backface_visibility_
	values.ensure_computed_layout_cache().computed_values_cursor_ = other.computed_layout_cache().computed_values_cursor_
	values.ensure_computed_layout_cache().computed_values_tab_size_ = other.computed_layout_cache().computed_values_tab_size_
	values.ensure_computed_layout_cache().computed_values_text_indent_ = other.computed_layout_cache().computed_values_text_indent_
	values.ensure_computed_layout_cache().computed_values_text_underline_offset_ = other.computed_layout_cache().computed_values_text_underline_offset_
	values.ensure_computed_layout_cache().computed_values_text_underline_position_ = other.computed_layout_cache().computed_values_text_underline_position_
	values.ensure_computed_layout_cache().computed_values_word_spacing_ = other.computed_layout_cache().computed_values_word_spacing_
	values.ensure_computed_layout_cache().computed_values_letter_spacing_ = other.computed_layout_cache().computed_values_letter_spacing_
	values.ensure_computed_layout_cache().computed_values_quotes_ = other.computed_layout_cache().computed_values_quotes_
	values.ensure_computed_layout_cache().computed_values_dominant_baseline_ = other.computed_layout_cache().computed_values_dominant_baseline_
	values.ensure_computed_layout_cache().computed_values_stroke_dasharray_ = other.computed_layout_cache().computed_values_stroke_dasharray_
	values.ensure_computed_layout_cache().computed_values_paint_order_ = other.computed_layout_cache().computed_values_paint_order_
	values.ensure_computed_layout_cache().computed_values_math_shift_ = other.computed_layout_cache().computed_values_math_shift_
	values.ensure_computed_layout_cache().computed_values_math_style_ = other.computed_layout_cache().computed_values_math_style_
	values.ensure_computed_layout_cache().computed_values_math_depth_ = other.computed_layout_cache().computed_values_math_depth_
	values.ensure_computed_layout_cache().computed_values_stroke_dashoffset_ = other.computed_layout_cache().computed_values_stroke_dashoffset_
	values.ensure_computed_layout_cache().computed_values_stroke_width_ = other.computed_layout_cache().computed_values_stroke_width_
	values.computed_values_resolved_ = true
}

pub fn (mut values MutableComputedValues) set_display_before_box_type_transformation(value Display) {
	values.ensure_computed_layout_cache().computed_values_display_before_transformation_ = value
}

pub fn (mut values MutableComputedValues) set_position(value Positioning) {
	values.ensure_computed_layout_cache().computed_values_position_ = value
}

pub fn (mut values MutableComputedValues) set_position_anchor(value ?string) {
	values.ensure_computed_layout_cache().computed_values_position_anchor_ = value
}

pub fn (mut values MutableComputedValues) set_float(value Float) {
	values.ensure_computed_layout_cache().computed_values_float_ = value
}

pub fn (mut values MutableComputedValues) set_clear(value Clear) {
	values.ensure_computed_layout_cache().computed_values_clear_ = value
}

pub fn (mut values MutableComputedValues) set_direction(value Direction) {
	values.ensure_computed_layout_cache().computed_values_direction_ = value
}

pub fn (mut values MutableComputedValues) set_writing_mode(value WritingMode) {
	values.ensure_computed_layout_cache().computed_values_writing_mode_ = value
}

pub fn (mut values MutableComputedValues) set_overflow_x(value Overflow) {
	values.ensure_computed_layout_cache().computed_values_overflow_x_ = value
}

pub fn (mut values MutableComputedValues) set_overflow_y(value Overflow) {
	values.ensure_computed_layout_cache().computed_values_overflow_y_ = value
}

pub fn (mut values MutableComputedValues) set_font_size(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_font_size_ = value
}

pub fn (mut values MutableComputedValues) set_line_height(value CSSPixels) {
	values.computed_values_line_height_ = value
}

pub fn (mut values MutableComputedValues) set_font_weight(value f64) {
	values.ensure_computed_layout_cache().computed_values_font_weight_ = value
}

pub fn (mut values MutableComputedValues) set_font_language_override(value ?string) {
	values.ensure_computed_layout_cache().computed_values_font_language_override_ = value
}

pub fn (mut values MutableComputedValues) set_font_variation_settings(value map[string]f64) {
	if value.len == 0 {
		values.font_variation_storage_ = unsafe { nil }
		return
	}
	mut properties := unsafe { &ComputedProperties(values) }
	mut storage := properties.ensure_font_variation_storage()
	storage.values = value.clone()
}

pub fn (mut values MutableComputedValues) set_font_list(value &FontCascadeList) {
	values.cached_computed_font_list_ = value
	values.cached_first_available_computed_font_ = unsafe { nil }
}

pub fn (mut values MutableComputedValues) set_caret_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_caret_color_ = value
}

pub fn (mut values MutableComputedValues) set_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_color_ = value
}

pub fn (mut values MutableComputedValues) set_accent_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_accent_color_ = value
}

pub fn (mut values MutableComputedValues) set_color_scheme(value PreferredColorScheme) {
	values.ensure_computed_layout_cache().computed_values_color_scheme_ = value
}

pub fn (mut values MutableComputedValues) set_width(value Size) {
	values.ensure_computed_layout_cache().computed_values_width_ = value
}

pub fn (mut values MutableComputedValues) set_min_width(value Size) {
	values.ensure_computed_layout_cache().computed_values_min_width_ = value
}

pub fn (mut values MutableComputedValues) set_max_width(value Size) {
	values.ensure_computed_layout_cache().computed_values_max_width_ = value
}

pub fn (mut values MutableComputedValues) set_height(value Size) {
	values.ensure_computed_layout_cache().computed_values_height_ = value
}

pub fn (mut values MutableComputedValues) set_min_height(value Size) {
	values.ensure_computed_layout_cache().computed_values_min_height_ = value
}

pub fn (mut values MutableComputedValues) set_max_height(value Size) {
	values.ensure_computed_layout_cache().computed_values_max_height_ = value
}

pub fn (mut values MutableComputedValues) set_inset(value LengthBox) {
	values.ensure_computed_layout_cache().computed_values_inset_ = value
}

pub fn (mut values MutableComputedValues) set_margin(value LengthBox) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_margin_ = value
	cache.resolved_edge_memo_.valid = false
	cache.resolved_edge_memo_.kind = .unclassified
}

pub fn (mut values MutableComputedValues) set_padding(value LengthBox) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_padding_ = value
	cache.resolved_edge_memo_.valid = false
	cache.resolved_edge_memo_.kind = .unclassified
}

pub fn (mut values MutableComputedValues) set_overflow_clip_margin(value LengthBox) {
	values.ensure_computed_layout_cache().computed_values_overflow_clip_margin_ = value
}

pub fn (mut values MutableComputedValues) set_border_left(value BorderData) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_border_left_ = value
	cache.resolved_edge_memo_.valid = false
}

pub fn (mut values MutableComputedValues) set_border_top(value BorderData) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_border_top_ = value
	cache.resolved_edge_memo_.valid = false
}

pub fn (mut values MutableComputedValues) set_border_right(value BorderData) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_border_right_ = value
	cache.resolved_edge_memo_.valid = false
}

pub fn (mut values MutableComputedValues) set_border_bottom(value BorderData) {
	mut cache := values.ensure_computed_layout_cache()
	cache.computed_values_border_bottom_ = value
	cache.resolved_edge_memo_.valid = false
}

pub fn (mut values MutableComputedValues) set_border_bottom_left_radius(value BorderRadiusData) {
	if value.is_initial() && !values.computed_layout_cache().computed_values_has_noninitial_border_radii_ {
		return
	}
	values.ensure_computed_layout_cache().computed_values_has_noninitial_border_radii_ = true
	values.ensure_computed_layout_cache().computed_values_border_bottom_left_radius_ = value
}

pub fn (mut values MutableComputedValues) set_border_bottom_right_radius(value BorderRadiusData) {
	if value.is_initial() && !values.computed_layout_cache().computed_values_has_noninitial_border_radii_ {
		return
	}
	values.ensure_computed_layout_cache().computed_values_has_noninitial_border_radii_ = true
	values.ensure_computed_layout_cache().computed_values_border_bottom_right_radius_ = value
}

pub fn (mut values MutableComputedValues) set_border_top_left_radius(value BorderRadiusData) {
	if value.is_initial() && !values.computed_layout_cache().computed_values_has_noninitial_border_radii_ {
		return
	}
	values.ensure_computed_layout_cache().computed_values_has_noninitial_border_radii_ = true
	values.ensure_computed_layout_cache().computed_values_border_top_left_radius_ = value
}

pub fn (mut values MutableComputedValues) set_border_top_right_radius(value BorderRadiusData) {
	if value.is_initial() && !values.computed_layout_cache().computed_values_has_noninitial_border_radii_ {
		return
	}
	values.ensure_computed_layout_cache().computed_values_has_noninitial_border_radii_ = true
	values.ensure_computed_layout_cache().computed_values_border_top_right_radius_ = value
}

pub fn (mut values MutableComputedValues) set_flex_direction(value FlexDirection) {
	values.ensure_computed_layout_cache().computed_values_flex_direction_ = value
}

pub fn (mut values MutableComputedValues) set_flex_wrap(value FlexWrap) {
	values.ensure_computed_layout_cache().computed_values_flex_wrap_ = value
}

pub fn (mut values MutableComputedValues) set_flex_basis(value FlexBasis) {
	values.ensure_computed_layout_cache().computed_values_flex_basis_ = value
}

pub fn (mut values MutableComputedValues) set_flex_grow(value f32) {
	values.ensure_computed_layout_cache().computed_values_flex_grow_ = value
}

pub fn (mut values MutableComputedValues) set_flex_shrink(value f32) {
	values.ensure_computed_layout_cache().computed_values_flex_shrink_ = value
}

pub fn (mut values MutableComputedValues) set_order(value int) {
	values.ensure_computed_layout_cache().computed_values_order_ = value
}

pub fn (mut values MutableComputedValues) set_align_content(value AlignContent) {
	values.ensure_computed_layout_cache().computed_values_align_content_ = value
}

pub fn (mut values MutableComputedValues) set_align_items(value AlignItems) {
	values.ensure_computed_layout_cache().computed_values_align_items_ = value
}

pub fn (mut values MutableComputedValues) set_align_self(value AlignSelf) {
	values.ensure_computed_layout_cache().computed_values_align_self_ = value
}

pub fn (mut values MutableComputedValues) set_justify_content(value JustifyContent) {
	values.ensure_computed_layout_cache().computed_values_justify_content_ = value
}

pub fn (mut values MutableComputedValues) set_justify_items(value JustifyItems) {
	values.ensure_computed_layout_cache().computed_values_justify_items_ = value
}

pub fn (mut values MutableComputedValues) set_justify_self(value JustifySelf) {
	values.ensure_computed_layout_cache().computed_values_justify_self_ = value
}

pub fn (mut values MutableComputedValues) set_text_align(value TextAlign) {
	values.ensure_computed_layout_cache().computed_values_text_align_ = value
}

pub fn (mut values MutableComputedValues) set_text_justify(value TextJustify) {
	values.ensure_computed_layout_cache().computed_values_text_justify_ = value
}

pub fn (mut values MutableComputedValues) set_text_transform(value TextTransform) {
	values.ensure_computed_layout_cache().computed_values_text_transform_ = value
}

pub fn (mut values MutableComputedValues) set_text_wrap_mode(value TextWrapMode) {
	values.ensure_computed_layout_cache().computed_values_text_wrap_mode_ = value
}

pub fn (mut values MutableComputedValues) set_white_space_collapse(value WhiteSpaceCollapse) {
	values.ensure_computed_layout_cache().computed_values_white_space_collapse_ = value
}

pub fn (mut values MutableComputedValues) set_word_break(value WordBreak) {
	values.ensure_computed_layout_cache().computed_values_word_break_ = value
}

pub fn (mut values MutableComputedValues) set_visibility(value Visibility) {
	values.ensure_computed_layout_cache().computed_values_visibility_ = value
}

pub fn (mut values MutableComputedValues) set_box_sizing(value BoxSizing) {
	values.ensure_computed_layout_cache().computed_values_box_sizing_ = value
}

pub fn (mut values MutableComputedValues) set_vertical_align(value VerticalAlign) {
	values.ensure_computed_layout_cache().computed_values_vertical_align_ = value
}

pub fn (mut values MutableComputedValues) set_caption_side(value CaptionSide) {
	values.ensure_computed_layout_cache().computed_values_caption_side_ = value
}

pub fn (mut values MutableComputedValues) set_content_visibility(value ContentVisibility) {
	values.ensure_computed_layout_cache().computed_values_content_visibility_ = value
}

pub fn (mut values MutableComputedValues) set_user_select(value UserSelect) {
	values.ensure_computed_layout_cache().computed_values_user_select_ = value
}

pub fn (mut values MutableComputedValues) set_table_layout(value TableLayout) {
	values.ensure_computed_layout_cache().computed_values_table_layout_ = value
}

pub fn (mut values MutableComputedValues) set_border_collapse(value BorderCollapse) {
	values.ensure_computed_layout_cache().computed_values_border_collapse_ = value
}

pub fn (mut values MutableComputedValues) set_contain(value Containment) {
	values.ensure_computed_layout_cache().computed_values_contain_ = value
}

pub fn (mut values MutableComputedValues) set_aspect_ratio(value AspectRatio) {
	values.ensure_computed_layout_cache().computed_values_aspect_ratio_ = value
}

pub fn (mut values MutableComputedValues) set_column_gap(value GapValue) {
	values.ensure_computed_layout_cache().computed_values_column_gap_ = value
}

pub fn (mut values MutableComputedValues) set_row_gap(value GapValue) {
	values.ensure_computed_layout_cache().computed_values_row_gap_ = value
}

pub fn (mut values MutableComputedValues) set_grid_auto_columns(value GridTrackSizeList) {
	values.ensure_computed_layout_cache().computed_values_grid_auto_columns_ = value
}

pub fn (mut values MutableComputedValues) set_grid_auto_rows(value GridTrackSizeList) {
	values.ensure_computed_layout_cache().computed_values_grid_auto_rows_ = value
}

pub fn (mut values MutableComputedValues) set_grid_template_columns(value GridTrackSizeList) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_grid_template_columns_ { return }
	cache.ensure_rare_data().computed_values_grid_template_columns_ = value
}

pub fn (mut values MutableComputedValues) set_grid_template_rows(value GridTrackSizeList) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_grid_template_rows_ { return }
	cache.ensure_rare_data().computed_values_grid_template_rows_ = value
}

pub fn (mut values MutableComputedValues) set_grid_template_areas(value GridTemplateAreas) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_grid_template_areas_ { return }
	cache.ensure_rare_data().computed_values_grid_template_areas_ = value
}

pub fn (mut values MutableComputedValues) set_grid_auto_flow(value GridAutoFlow) {
	values.ensure_computed_layout_cache().computed_values_grid_auto_flow_ = value
}

pub fn (mut values MutableComputedValues) set_appearance(value Appearance) {
	values.ensure_computed_layout_cache().computed_values_appearance_ = value
}

pub fn (mut values MutableComputedValues) set_opacity(value f32) {
	values.ensure_computed_layout_cache().computed_values_opacity_ = value
}

pub fn (mut values MutableComputedValues) set_z_index(value ?int) {
	values.ensure_computed_layout_cache().computed_values_z_index_ = value
}

pub fn (mut values MutableComputedValues) set_image_rendering(value ImageRendering) {
	values.ensure_computed_layout_cache().computed_values_image_rendering_ = value
}

pub fn (mut values MutableComputedValues) set_pointer_events(value PointerEvents) {
	values.ensure_computed_layout_cache().computed_values_pointer_events_ = value
}

pub fn (mut values MutableComputedValues) set_list_style_position(value ListStylePosition) {
	values.ensure_computed_layout_cache().computed_values_list_style_position_ = value
}

pub fn (mut values ComputedProperties) set_list_style_type(value ListStyleType) {
	values.computed_list_style_storage_ = stored_list_style_type(value)
}

__global computed_normal_content_ = &ContentData{type_:.normal}
__global computed_none_content_ = &ContentData{type_:.none_}

fn stored_content_data(content ContentData) &ContentData {
	if content.text.len == 0 && content.alt_text.len == 0 && content.items.len == 0
		&& content.counter_style_dependencies.len == 0 {
		if content.type_ == .normal { return computed_normal_content_ }
		if content.type_ == .none_ { return computed_none_content_ }
	}
	return &ContentData{...content}
}

pub fn (mut values ComputedProperties) set_content(value ?ContentData) {
	// These keyword results contain no mutable payload. The getter returns a
	// value snapshot, and every later install replaces rather than mutates it.
	values.computed_content_storage_ = if content := value { stored_content_data(content) } else { unsafe { nil } }
}

pub fn (mut values MutableComputedValues) set_grid_column_end(value GridTrackPlacement) {
	values.ensure_computed_layout_cache().computed_values_grid_column_end_ = value
}

pub fn (mut values MutableComputedValues) set_grid_column_start(value GridTrackPlacement) {
	values.ensure_computed_layout_cache().computed_values_grid_column_start_ = value
}

pub fn (mut values MutableComputedValues) set_grid_row_end(value GridTrackPlacement) {
	values.ensure_computed_layout_cache().computed_values_grid_row_end_ = value
}

pub fn (mut values MutableComputedValues) set_grid_row_start(value GridTrackPlacement) {
	values.ensure_computed_layout_cache().computed_values_grid_row_start_ = value
}

pub fn (mut values MutableComputedValues) set_column_span(value ColumnSpan) {
	values.ensure_computed_layout_cache().computed_values_column_span_ = value
}

pub fn (mut values MutableComputedValues) set_break_after(value BreakBetween) {
	values.ensure_computed_layout_cache().computed_values_break_after_ = value
}

pub fn (mut values MutableComputedValues) set_break_before(value BreakBetween) {
	values.ensure_computed_layout_cache().computed_values_break_before_ = value
}

pub fn (mut values MutableComputedValues) set_break_inside(value BreakInside) {
	values.ensure_computed_layout_cache().computed_values_break_inside_ = value
}

pub fn (mut values MutableComputedValues) set_box_decoration_break(value BoxDecorationBreak) {
	values.ensure_computed_layout_cache().computed_values_box_decoration_break_ = value
}

pub fn (mut values MutableComputedValues) set_column_fill(value ColumnFill) {
	values.ensure_computed_layout_cache().computed_values_column_fill_ = value
}

pub fn (mut values MutableComputedValues) set_block_ellipsis(value BlockEllipsis) {
	values.ensure_computed_layout_cache().computed_values_block_ellipsis_ = value
}

pub fn (mut values MutableComputedValues) set_continue_value(value ContinueValue) {
	values.ensure_computed_layout_cache().computed_values_continue_ = value
}

pub fn (mut values MutableComputedValues) set_max_lines(value ?int) {
	values.ensure_computed_layout_cache().computed_values_max_lines_ = value
}

pub fn (mut values MutableComputedValues) set_webkit_box_orient(value WebkitBoxOrient) {
	values.ensure_computed_layout_cache().computed_values_webkit_box_orient_ = value
}

pub fn (mut values MutableComputedValues) set_empty_cells(value EmptyCells) {
	values.ensure_computed_layout_cache().computed_values_empty_cells_ = value
}

pub fn (mut values MutableComputedValues) set_object_fit(value ObjectFit) {
	values.ensure_computed_layout_cache().computed_values_object_fit_ = value
}

pub fn (mut values MutableComputedValues) set_object_position(value Position) {
	values.ensure_computed_layout_cache().computed_values_object_position_ = value
}

pub fn (mut values MutableComputedValues) set_unicode_bidi(value UnicodeBidi) {
	values.ensure_computed_layout_cache().computed_values_unicode_bidi_ = value
}

pub fn (mut values MutableComputedValues) set_isolation(value Isolation) {
	values.ensure_computed_layout_cache().computed_values_isolation_ = value
}

pub fn (mut values MutableComputedValues) set_mix_blend_mode(value MixBlendMode) {
	values.ensure_computed_layout_cache().computed_values_mix_blend_mode_ = value
}

pub fn (mut values MutableComputedValues) set_mask_type(value MaskType) {
	values.ensure_computed_layout_cache().computed_values_mask_type_ = value
}

pub fn (mut values MutableComputedValues) set_mask(value MaskReference) {
	values.set_cached_mask(value)
}

pub fn (mut values MutableComputedValues) set_mask_image(value ImageStyleValue) {
	values.set_cached_mask_image(value)
}

pub fn (mut values MutableComputedValues) set_clip_path(value ClipPathReference) {
	values.set_cached_clip_path(value)
}

pub fn (mut values MutableComputedValues) set_stop_opacity(value f32) {
	values.ensure_computed_layout_cache().computed_values_stop_opacity_ = value
}

pub fn (mut values MutableComputedValues) set_fill_opacity(value f32) {
	values.ensure_computed_layout_cache().computed_values_fill_opacity_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_linecap(value StrokeLinecap) {
	values.ensure_computed_layout_cache().computed_values_stroke_linecap_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_linejoin(value StrokeLinejoin) {
	values.ensure_computed_layout_cache().computed_values_stroke_linejoin_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_miterlimit(value f64) {
	values.ensure_computed_layout_cache().computed_values_stroke_miterlimit_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_opacity(value f32) {
	values.ensure_computed_layout_cache().computed_values_stroke_opacity_ = value
}

pub fn (mut values MutableComputedValues) set_fill_rule(value FillRule) {
	values.ensure_computed_layout_cache().computed_values_fill_rule_ = value
}

pub fn (mut values MutableComputedValues) set_clip_rule(value ClipRule) {
	values.ensure_computed_layout_cache().computed_values_clip_rule_ = value
}

pub fn (mut values MutableComputedValues) set_shape_rendering(value ShapeRendering) {
	values.ensure_computed_layout_cache().computed_values_shape_rendering_ = value
}

pub fn (mut values MutableComputedValues) set_text_anchor(value TextAnchor) {
	values.ensure_computed_layout_cache().computed_values_text_anchor_ = value
}

pub fn (mut values MutableComputedValues) set_outline_offset(value Length) {
	values.ensure_computed_layout_cache().computed_values_outline_offset_ = value
}

pub fn (mut values MutableComputedValues) set_outline_style(value OutlineStyle) {
	values.ensure_computed_layout_cache().computed_values_outline_style_ = value
}

pub fn (mut values MutableComputedValues) set_scrollbar_width(value ScrollbarWidth) {
	values.ensure_computed_layout_cache().computed_values_scrollbar_width_ = value
}

pub fn (mut values MutableComputedValues) set_resize(value Resize) {
	values.ensure_computed_layout_cache().computed_values_resize_ = value
}

pub fn (mut values MutableComputedValues) set_border_spacing_horizontal(value Length) {
	values.ensure_computed_layout_cache().computed_values_border_spacing_horizontal_ = value
}

pub fn (mut values MutableComputedValues) set_border_spacing_vertical(value Length) {
	values.ensure_computed_layout_cache().computed_values_border_spacing_vertical_ = value
}

pub fn (mut values MutableComputedValues) set_color_interpolation(value ColorInterpolation) {
	values.ensure_computed_layout_cache().computed_values_color_interpolation_ = value
}

pub fn (mut values MutableComputedValues) set_color_interpolation_filters(value ColorInterpolation) {
	values.ensure_computed_layout_cache().computed_values_color_interpolation_filters_ = value
}

pub fn (mut values MutableComputedValues) set_clip(value Clip) {
	values.ensure_computed_layout_cache().computed_values_clip_ = value
}

pub fn (mut values MutableComputedValues) set_cursor(value []CursorData) {
	values.ensure_computed_layout_cache().computed_values_cursor_ = value
}

pub fn (mut values MutableComputedValues) set_background_color_clip(value BackgroundBox) {
	values.ensure_computed_layout_cache().computed_values_background_color_clip_ = value
}

pub fn (mut values MutableComputedValues) set_background_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_background_color_ = value
}

pub fn (mut values MutableComputedValues) set_background_layers(value []BackgroundLayerData) {
	values.ensure_computed_layout_cache().computed_values_background_layers_ = value
}

pub fn (mut values MutableComputedValues) set_tab_size(value TabSize) {
	values.ensure_computed_layout_cache().computed_values_tab_size_ = value
}

pub fn (mut values MutableComputedValues) set_text_decoration_line(value []TextDecorationLine) {
	values.ensure_computed_layout_cache().computed_values_text_decoration_line_ = value
}

pub fn (mut values MutableComputedValues) set_text_decoration_skip_ink(value TextDecorationSkipInk) {
	values.ensure_computed_layout_cache().computed_values_text_decoration_skip_ink_ = value
}

pub fn (mut values MutableComputedValues) set_text_decoration_thickness(value TextDecorationThickness) {
	values.ensure_computed_layout_cache().computed_values_text_decoration_thickness_ = value
}

pub fn (mut values MutableComputedValues) set_text_decoration_style(value TextDecorationStyle) {
	values.ensure_computed_layout_cache().computed_values_text_decoration_style_ = value
}

pub fn (mut values MutableComputedValues) set_text_decoration_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_text_decoration_color_ = value
}

pub fn (mut values MutableComputedValues) set_text_indent(value TextIndentData) {
	values.ensure_computed_layout_cache().computed_values_text_indent_ = value
}

pub fn (mut values MutableComputedValues) set_text_overflow(value TextOverflow) {
	values.ensure_computed_layout_cache().computed_values_text_overflow_ = value
}

pub fn (mut values MutableComputedValues) set_text_underline_offset(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_text_underline_offset_ = value
}

pub fn (mut values MutableComputedValues) set_text_underline_position(value TextUnderlinePosition) {
	values.ensure_computed_layout_cache().computed_values_text_underline_position_ = value
}

pub fn (mut values MutableComputedValues) set_white_space_trim(value WhiteSpaceTrimData) {
	values.ensure_computed_layout_cache().computed_values_white_space_trim_ = value
}

pub fn (mut values MutableComputedValues) set_word_spacing(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_word_spacing_ = value
}

pub fn (mut values MutableComputedValues) set_letter_spacing(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_letter_spacing_ = value
}

pub fn (mut values MutableComputedValues) set_backdrop_filter(value Filter) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_backdrop_filter_ { return }
	cache.ensure_rare_data().computed_values_backdrop_filter_ = value
}

pub fn (mut values MutableComputedValues) set_filter(value Filter) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_filter_ { return }
	cache.ensure_rare_data().computed_values_filter_ = value
}

pub fn (mut values MutableComputedValues) set_rotate(value ?TransformationData) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_rotate_ { return }
	cache.ensure_rare_data().computed_values_rotate_ = value
}

pub fn (mut values MutableComputedValues) set_scale(value ?TransformationData) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_scale_ { return }
	cache.ensure_rare_data().computed_values_scale_ = value
}

pub fn (mut values MutableComputedValues) set_perspective(value ?CSSPixels) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_perspective_ { return }
	cache.ensure_rare_data().computed_values_perspective_ = value
}

pub fn (mut values MutableComputedValues) set_perspective_origin(value Position) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_perspective_origin_ { return }
	cache.ensure_rare_data().computed_values_perspective_origin_ = value
}

pub fn (mut values MutableComputedValues) set_transformations(value []TransformationData) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_transformations_ { return }
	cache.ensure_rare_data().computed_values_transformations_ = value
}

pub fn (mut values MutableComputedValues) set_transform_box(value TransformBox) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_transform_box_ { return }
	cache.ensure_rare_data().computed_values_transform_box_ = value
}

pub fn (mut values MutableComputedValues) set_transform_origin(value TransformOrigin) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_transform_origin_ { return }
	cache.ensure_rare_data().computed_values_transform_origin_ = value
}

pub fn (mut values MutableComputedValues) set_transform_style(value TransformStyle) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_transform_style_ { return }
	cache.ensure_rare_data().computed_values_transform_style_ = value
}

pub fn (mut values MutableComputedValues) set_backface_visibility(value BackfaceVisibility) {
	values.ensure_computed_layout_cache().computed_values_backface_visibility_ = value
}

pub fn (mut values MutableComputedValues) set_translate(value ?TransformationData) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_translate_ { return }
	cache.ensure_rare_data().computed_values_translate_ = value
}

pub fn (mut values MutableComputedValues) set_quotes(value QuotesData) {
	values.ensure_computed_layout_cache().computed_values_quotes_ = value
}

pub fn (mut values MutableComputedValues) set_dominant_baseline(value ?BaselineMetric) {
	values.ensure_computed_layout_cache().computed_values_dominant_baseline_ = value
}

pub fn (mut values MutableComputedValues) set_container_name(value []string) {
	values.ensure_computed_layout_cache().computed_values_container_name_ = value
}

pub fn (mut values MutableComputedValues) set_container_type(value ContainerType) {
	values.ensure_computed_layout_cache().computed_values_container_type_ = value
}

pub fn (mut values MutableComputedValues) set_view_transition_name(value ?string) {
	values.ensure_computed_layout_cache().computed_values_view_transition_name_ = value
}

pub fn (mut values MutableComputedValues) set_touch_action(value TouchActionData) {
	values.ensure_computed_layout_cache().computed_values_touch_action_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_dasharray(value []StrokeDasharrayItem) {
	values.ensure_computed_layout_cache().computed_values_stroke_dasharray_ = value
}

pub fn (mut values MutableComputedValues) set_flood_opacity(value f32) {
	values.ensure_computed_layout_cache().computed_values_flood_opacity_ = value
}

pub fn (mut values MutableComputedValues) set_paint_order(value PaintOrderList) {
	values.ensure_computed_layout_cache().computed_values_paint_order_ = value
}

pub fn (mut values MutableComputedValues) set_math_shift(value MathShift) {
	values.ensure_computed_layout_cache().computed_values_math_shift_ = value
}

pub fn (mut values MutableComputedValues) set_math_style(value MathStyle) {
	values.ensure_computed_layout_cache().computed_values_math_style_ = value
}

pub fn (mut values MutableComputedValues) set_math_depth(value int) {
	values.ensure_computed_layout_cache().computed_values_math_depth_ = value
}

pub fn (mut values MutableComputedValues) set_will_change(value WillChange) {
	values.ensure_computed_layout_cache().computed_values_will_change_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_dashoffset(value LengthPercentage) {
	values.ensure_computed_layout_cache().computed_values_stroke_dashoffset_ = value
}

pub fn (mut values MutableComputedValues) set_stroke_width(value LengthPercentage) {
	values.ensure_computed_layout_cache().computed_values_stroke_width_ = value
}

pub fn (mut values MutableComputedValues) set_cx(value LengthPercentage) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_cx_ { return }
	cache.ensure_rare_data().computed_values_cx_ = value
}

pub fn (mut values MutableComputedValues) set_cy(value LengthPercentage) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_cy_ { return }
	cache.ensure_rare_data().computed_values_cy_ = value
}

pub fn (mut values MutableComputedValues) set_r(value LengthPercentage) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_r_ { return }
	cache.ensure_rare_data().computed_values_r_ = value
}

pub fn (mut values MutableComputedValues) set_rx(value LengthPercentageOrAuto) {
	values.ensure_computed_layout_cache().computed_values_rx_ = value
}

pub fn (mut values MutableComputedValues) set_ry(value LengthPercentageOrAuto) {
	values.ensure_computed_layout_cache().computed_values_ry_ = value
}

pub fn (mut values MutableComputedValues) set_x(value LengthPercentage) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_x_ { return }
	cache.ensure_rare_data().computed_values_x_ = value
}

pub fn (mut values MutableComputedValues) set_y(value LengthPercentage) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_y_ { return }
	cache.ensure_rare_data().computed_values_y_ = value
}

pub fn (mut values MutableComputedValues) set_column_count(value ?int) {
	values.ensure_computed_layout_cache().computed_values_column_count_ = value
}

pub fn (mut values MutableComputedValues) set_column_width(value Size) {
	values.ensure_computed_layout_cache().computed_values_column_width_ = value
}

pub fn (mut values MutableComputedValues) set_column_height(value Size) {
	values.ensure_computed_layout_cache().computed_values_column_height_ = value
}

pub fn (mut values MutableComputedValues) set_column_rule_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_column_rule_color_ = value
}

pub fn (mut values MutableComputedValues) set_column_rule_style(value LineStyle) {
	values.ensure_computed_layout_cache().computed_values_column_rule_style_ = value
}

pub fn (mut values MutableComputedValues) set_column_rule_width(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_column_rule_width_ = value
}

pub fn (mut values MutableComputedValues) set_outline_width(value CSSPixels) {
	values.ensure_computed_layout_cache().computed_values_outline_width_ = value
}

pub fn (mut values MutableComputedValues) set_transition_delay(value Time) {
	values.ensure_computed_layout_cache().computed_values_transition_delay_ = value
}

pub fn (mut values MutableComputedValues) set_webkit_text_fill_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_webkit_text_fill_color_ = value
}

pub fn (mut values MutableComputedValues) set_stop_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_stop_color_ = value
}

pub fn (mut values MutableComputedValues) set_flood_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_flood_color_ = value
}

pub fn (mut values MutableComputedValues) set_outline_color(value Color) {
	values.ensure_computed_layout_cache().computed_values_outline_color_ = value
}

pub fn (mut values MutableComputedValues) set_fill(value SVGPaint) {
	values.ensure_computed_layout_cache().computed_values_fill_ = value
}

pub fn (mut values MutableComputedValues) set_stroke(value SVGPaint) {
	values.ensure_computed_layout_cache().computed_values_stroke_ = value
}

pub fn (mut values MutableComputedValues) set_text_shadow(value []ShadowData) {
	values.ensure_computed_layout_cache().computed_values_text_shadow_ = value.clone()
}

pub fn (mut values MutableComputedValues) set_box_shadow(value []ShadowData) {
	values.ensure_computed_layout_cache().computed_values_box_shadow_ = value.clone()
}

pub fn (mut values MutableComputedValues) set_scrollbar_color(value ScrollbarColorData) {
	values.ensure_computed_layout_cache().computed_values_scrollbar_color_ = value
}

pub fn (mut values MutableComputedValues) set_counter_increment(value []CounterData) {
	values.ensure_computed_layout_cache().computed_values_counter_increment_ = value.clone()
}

pub fn (mut values MutableComputedValues) set_counter_reset(value []CounterData) {
	values.ensure_computed_layout_cache().computed_values_counter_reset_ = value.clone()
}

pub fn (mut values MutableComputedValues) set_counter_set(value []CounterData) {
	values.ensure_computed_layout_cache().computed_values_counter_set_ = value.clone()
}

fn (mut values MutableComputedValues) set_cached_mask(value ?MaskReference) {
	mut cache := values.ensure_computed_layout_cache()
	if cache.rare_data_ == unsafe { nil } && value == initial_computed_layout_rare_data.computed_values_mask_ { return }
	cache.ensure_rare_data().computed_values_mask_ = value
}

fn (mut values MutableComputedValues) set_cached_mask_image(value ?ImageStyleValue) {
	mut cache := values.ensure_computed_layout_cache()
	// The initial value is none; comparing image values would deep-compare
	// the style sheets they reference.
	if cache.rare_data_ == unsafe { nil } && value == none { return }
	cache.ensure_rare_data().computed_values_mask_image_ = value
}

fn (mut values MutableComputedValues) set_cached_clip_path(value ?ClipPathReference) {
	mut cache := values.ensure_computed_layout_cache()
	// The initial value is none.
	if cache.rare_data_ == unsafe { nil } && value == none { return }
	cache.ensure_rare_data().computed_values_clip_path_ = value
}
