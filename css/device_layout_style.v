module css

import dom
import platform

@[heap]
struct DeviceLayoutStyleProjection {
	scale      f64
	provenance &ComputedGeometryProvenance
	style      &ComputedProperties
}

pub fn (style &ComputedProperties) layout_coordinate_scale() f64 {
	return style.computed_layout_cache().layout_coordinate_scale_
}

// Anonymous table, button and fieldset styles also pass through the ordinary
// layout resolver. Keep their inherited physical font and coordinate marker
// together so they are never projected a second time.
fn (mut style ComputedProperties) inherit_layout_coordinate_context(source &ComputedProperties) {
	scale := source.layout_coordinate_scale()
	if scale == 1 { return }
	style.ensure_computed_layout_cache().layout_coordinate_scale_ = scale
	style.cached_computed_font_list_ = source.cached_computed_font_list_
	style.cached_computed_font_list_generation_ = source.cached_computed_font_list_generation_
	style.cached_computed_font_list_owner_ = source.cached_computed_font_list_owner_
	style.cached_first_available_computed_font_ = source.cached_first_available_computed_font_
	style.cached_length_metrics_ = unsafe { nil }
}

fn device_layout_font(font PlatformFont, factor f64, pixel_size f64) PlatformFont {
	return PlatformFont{
		...font
		point_size:           f32(f64(font.point_size) * factor)
		pixel_size_override_: if font.font_rendering_policy == .chromium {
			?f32(browser_font_size_for_rendering(pixel_size))
		} else {
			none
		}
		metrics_font_:        unsafe { nil }
	}
}

fn device_layout_fonts(source &FontCascadeList, factor f64, pixel_size f64) &FontCascadeList {
	mut result := FontCascadeList.create()
	for entry in source.fonts {
		result.add(device_layout_font(entry.font, factor, pixel_size), entry.unicode_ranges)
	}
	result.pending_faces = source.pending_faces.clone()
	if source.last_resort_font != unsafe { nil } {
		last_resort := device_layout_font(*source.last_resort_font, factor, pixel_size)
		result.last_resort_font = &PlatformFont{ ...last_resort }
	}
	return result
}

fn device_layout_value_contains_lengths(value StyleValue) bool {
	return match value {
		LengthStyleValue, CalculatedStyleValue, BackgroundSizeStyleValue, BasicShapeStyleValue,
		BorderRadiusRectStyleValue, BorderRadiusStyleValue, ConicGradientStyleValue,
		EdgeStyleValue, FilterValueListStyleValue, FunctionStyleValue, GridTrackSizeListStyleValue,
		LinearGradientStyleValue, PositionStyleValue, RadialGradientStyleValue,
		RadialSizeStyleValue, RectStyleValue, ShadowStyleValue, ShorthandStyleValue,
		StyleValueList, TextIndentStyleValue, TransformationStyleValue, TupleStyleValue {
			true
		}
		else { false }
	}
}

// Preserve the CSSOM's original style. Only the layout projection changes
// units; its fonts keep the source face, optical axes and shaping features.
pub fn computed_style_in_layout_coordinates(source &ComputedProperties,
	document &dom.Document) &ComputedProperties {
	scale := document.layout_coordinate_scale()
	current_scale := source.layout_coordinate_scale()
	if scale == current_scale { return unsafe { source } }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	owner := document.native_storage()
	use_document := owner != unsafe { nil }
		&& voidptr(owner) == voidptr(platform.current_retained_arena())
	persistent := platform.enter_persistent_if(!use_document && platform.transient_arena_entered())
	mut retained := if use_document {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	defer {
		retained.finish()
		platform.leave_persistent(persistent)
	}
	mut original := unsafe { &ComputedProperties(source) }
	computer := css_style_computer_for(document).font_computer()
	fonts := original.computed_font_list(computer)
	_ = original.first_available_computed_font(computer)
	previous := original.device_layout_projection_
	if previous != unsafe { nil }
		&& previous.scale == scale && previous.provenance.matches(original) {
		return previous.style
	}
	factor := scale / current_scale
	pixel_size := source.resolved_font_size_px() * factor
	scaled_fonts := device_layout_fonts(fonts, factor, pixel_size)
	mut target := &ComputedProperties{
		...*source
		property_store_:                source.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		computed_layout_cache_:         unsafe { nil }
		device_layout_projection_:      unsafe { nil }
		layout_cache_owner_serial_:     0
		computed_values_resolved_:      false
		cached_length_metrics_:         unsafe { nil }
		font_input_refresh_safe_:       false
		root_font_size_px_:             source.root_font_size_px_ * factor
		root_line_height_px_:           source.root_line_height_px_ * factor
		viewport_rect_:                 CSSPixelRect.new(source.viewport_rect_.left_value() * factor,
			source.viewport_rect_.top_value() * factor,
			source.viewport_rect_.width_value() * factor,
			source.viewport_rect_.height_value() * factor)
		line_height_:                   if height := source.line_height_ {
			?CSSPixels(height.scaled(factor))
		} else {
			none
		}
	}
	target.set_property_without_modifying_flags(.font_size,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(pixel_size)))))
	// Installing font-size invalidates the inherited font cache. Seed the
	// scaled faces only after that setter, preserving the CSS optical axes.
	target.cached_computed_font_list_ = scaled_fonts
	target.cached_computed_font_list_generation_ = source.cached_computed_font_list_generation_
	target.cached_computed_font_list_owner_ = source.cached_computed_font_list_owner_
	target.cached_first_available_computed_font_ = scaled_fonts.font_for_code_point(u32(` `))
	color_context := ColorResolutionContext.for_computed_properties(source, document)
	mut context := ComputationContext{
		length_resolution_context: target.length_resolution_context()
		color_scheme:              color_context.color_scheme
	}
	context.length_resolution_context.absolute_length_scale = factor
	if element := source.subject_element_ {
		context.abstract_element = dom.AbstractElement.new(element, none)
	}
	for property_id in computed_interpolation_longhand_property_ids() {
		if property_id == .font_size { continue }
		value := source.property(property_id, .yes) or { continue }
		typed := style_value_logic_from_dom(property_id, value) or { continue }
		mut scaled := typed
		if property_id in [.border_top_width, .border_right_width, .border_bottom_width,
			.border_left_width, .outline_width, .column_rule_width] {
			width := match typed.to_keyword() {
				.thin { 1.0 }
				.medium { 3.0 }
				.thick { 5.0 }
				else { 0.0 }
			}
			if width != 0 {
				scaled = StyleValue(LengthStyleValue.create(Length.make_px(width * factor)))
			}
		}
		if device_layout_value_contains_lengths(typed) {
			scaled = typed.absolutized(context)
		}
		if !scaled.equals(typed) {
			target.set_property_without_modifying_flags(property_id, dom_style_value_from_value_logic(scaled))
		}
	}
	target.ensure_computed_layout_cache().layout_coordinate_scale_ = scale
	if source.mutation_revision() != 0 {
		provenance := &ComputedGeometryProvenance{
			token:                         source.computed_property_graph_token_
			generation:                    source.mutation_revision()
			viewport:                      source.viewport_rect_
			root_font_size:                source.root_font_size_px_
			root_line_height:              source.root_line_height_px_
			root_font_depends_on_viewport: source.root_font_metrics_depend_on_viewport_metrics_
			subject:                       source.subject_element_
			font_list:                     fonts
			font_computer:                 source.cached_computed_font_list_owner_
			font_generation:               source.cached_computed_font_list_generation_
		}
		original.device_layout_projection_ = &DeviceLayoutStyleProjection{
			scale:      scale
			provenance: provenance
			style:      target
		}
	}
	return target
}
