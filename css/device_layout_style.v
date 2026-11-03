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
}

fn device_layout_font(font PlatformFont, factor f64, pixel_size f64) PlatformFont {
	mut projected := PlatformFont{
		...font
		point_size:           f32(f64(font.point_size) * factor)
		// Native Chromium layout measures the selected physical face. Rounding
		// CSS metrics first changes a 12px Verdana strut from 29 to 30 at 2x.
		pixel_size_override_: if font.font_rendering_policy == .chromium {
			?f32(browser_font_size_for_rendering(pixel_size))
		} else {
			none
		}
		metrics_font_:        unsafe { nil }
		shaping_ptem_: if font.font_rendering_policy == .chromium {
			?f32(font.shaping_ptem_ or { font.pixel_size_override_ or { font.point_size / 0.75 } })
		} else { font.shaping_ptem_ }
	}
	if factor != 1 && font.font_rendering_policy == .chromium {
		original := font.font_for_rendering()
		if original.point_size > 0 {
			if face := original.system_face() {
				if face.variations.any(it.tag == 0x6f70737a) {
					// Device layout scales glyphs and metrics, not the optical
					// instance selected at the CSS font size.
					native := projected.font_for_rendering()
					ratio := f64(native.point_size) / f64(original.point_size)
					persistent := platform.enter_persistent()
					projected.metrics_font_ = &platform.Font{
						family: native.family
						point_size: native.point_size
						shaping_ptem: native.shaping_ptem
						weight: native.weight
						italic: native.italic
						source_path: native.source_path
						requested_variations: native.requested_variations
						is_invisible: native.is_invisible
						font_rendering_policy: native.font_rendering_policy
						font_synthesis_disabled: native.font_synthesis_disabled
						system_face_override: platform.SystemFontFace{
							...face
							metrics: device_layout_font_metrics(face.metrics, ratio)
						}
					}
					platform.leave_persistent(persistent)
				}
			}
		}
	}
	return projected
}

fn device_layout_font_metrics(metrics platform.SystemFontMetrics, scale f64) platform.SystemFontMetrics {
	return platform.SystemFontMetrics{
		ascent: metrics.ascent * scale
		descent: metrics.descent * scale
		leading: metrics.leading * scale
		x_height: metrics.x_height * scale
		cap_height: metrics.cap_height * scale
		bbox_x_min: metrics.bbox_x_min * scale
		bbox_x_max: metrics.bbox_x_max * scale
		bbox_y_min: metrics.bbox_y_min * scale
		bbox_y_max: metrics.bbox_y_max * scale
	}
}

fn device_layout_font_matches_projection(source &PlatformFont, projected &PlatformFont, factor f64, pixel_size f64) bool {
	expected_pixel_size := if source.font_rendering_policy == .chromium {
		?f32(browser_font_size_for_rendering(pixel_size))
	} else {
		none
	}
	return voidptr(source.typeface) == voidptr(projected.typeface)
		&& projected.point_size == f32(f64(source.point_size) * factor)
		&& projected.pixel_size_override_ == expected_pixel_size
		&& projected.shaping_ptem_ == if source.font_rendering_policy == .chromium {
			?f32(source.shaping_ptem_ or { source.pixel_size_override_ or { source.point_size / 0.75 } })
		} else { source.shaping_ptem_ }
		&& source.variations.weight == projected.variations.weight
		&& source.variations.width == projected.variations.width
		&& source.variations.opsz == projected.variations.opsz
		&& source.variations.axis_values_equal(&projected.variations)
		&& source.features == projected.features
		&& source.is_invisible == projected.is_invisible
		&& source.font_rendering_policy == projected.font_rendering_policy
		&& source.italic == projected.italic
		&& source.font_synthesis_disabled == projected.font_synthesis_disabled
}

fn device_layout_fonts_match_projection(source &FontCascadeList, projected &FontCascadeList, factor f64, pixel_size f64) bool {
	if source.pending_faces.len != 0 || projected.pending_faces.len != 0
		|| source.fonts.len != projected.fonts.len {
		return false
	}
	for index, entry in source.fonts {
		other := projected.fonts[index]
		if entry.unicode_ranges != other.unicode_ranges
			|| !device_layout_font_matches_projection(&entry.font, &other.font, factor, pixel_size) {
			return false
		}
	}
	if source.last_resort_font != unsafe { nil } {
		return projected.last_resort_font != unsafe { nil }
			&& device_layout_font_matches_projection(source.last_resort_font,
				projected.last_resort_font, factor, pixel_size)
	}
	return projected.last_resort_font == unsafe { nil }
}

fn device_layout_fonts_can_cache(source &FontCascadeList) bool {
	$if prealloc {
		owner := platform.current_retained_arena()
		if owner != unsafe { nil } {
			// A standalone computer can outlive the current document. Its source
			// cascade must never retain a pointer into that document's arena.
			return owner.arena.contains(voidptr(source))
		}
		return !platform.transient_arena_entered()
	}
	return true
}

fn device_layout_fonts(source &FontCascadeList, factor f64, pixel_size f64) &FontCascadeList {
	can_cache := source.pending_faces.len == 0 && device_layout_fonts_can_cache(source)
	previous := source.device_layout_font_projection_
	if can_cache && previous != unsafe { nil }
		&& device_layout_fonts_match_projection(source, previous, factor, pixel_size) {
		return previous
	}
	mut retained := if can_cache {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	defer { retained.finish() }
	mut result := FontCascadeList.create()
	for entry in source.fonts {
		result.add(device_layout_font(entry.font, factor, pixel_size), entry.unicode_ranges)
	}
	result.pending_faces = source.pending_faces.clone()
	if source.last_resort_font != unsafe { nil } {
		last_resort := device_layout_font(*source.last_resort_font, factor, pixel_size)
		result.last_resort_font = owned_platform_font_ref(&last_resort)
	}
	if can_cache {
		mut mutable_source := unsafe { &FontCascadeList(source) }
		mutable_source.device_layout_font_projection_ = result
	}
	return result
}

fn device_layout_value_contains_lengths(value &StyleValue) bool {
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

fn device_layout_edge_is_projection_invariant(value &EdgeStyleValue) bool {
	// Even a dimensionless edge keyword must first become its computed offset.
	if value.edge_ != none { return false }
	if offset := style_value_from_optional_storage(value.offset_) {
		return device_layout_value_is_projection_invariant(&offset)
	}
	return false
}

fn device_layout_grid_is_projection_invariant(value &GridTrackSizeListStyleValue) bool {
	tracks := value.grid_track_size_list_
	// Empty initial lists and plain auto tracks contain no lengths. Reject line
	// names: absolutization can merge adjacent name sets while rebuilding them.
	for item in tracks.list_ {
		if item !is ExplicitGridTrack { return false }
		track := item.value_
		if track !is GridSize { return false }
		size := track.value_
		if size is Size {
			if !size.is_auto() { return false }
		} else { return false }
	}
	return true
}

// Only recognize values whose absolutized() result is already identical.
// Compound initial values otherwise allocate wrappers and compare whole value
// graphs, even when all their leaves are percentages, keywords or zero pixels.
fn device_layout_value_is_projection_invariant(value &StyleValue) bool {
	return match value {
		LengthStyleValue { value.length_.is_px() && value.raw_value() == 0 }
		KeywordStyleValue { value.keyword() == .currentcolor || !value.has_color() }
		NumberStyleValue { value.number() == value.number() }
		PercentageStyleValue { value.raw_value() == value.raw_value() }
		ColorStyleValue, CustomIdentStyleValue, IntegerStyleValue, StringStyleValue,
		RepeatStyleStyleValue { true }
		StyleValueList {
			mut invariant := true
			for child in value.values_ {
				if !device_layout_value_is_projection_invariant(&child) {
					invariant = false
					break
				}
			}
			invariant
		}
		BackgroundSizeStyleValue {
			device_layout_value_is_projection_invariant(&value.size_x_[0])
				&& device_layout_value_is_projection_invariant(&value.size_y_[0])
		}
		BorderRadiusStyleValue {
			device_layout_value_is_projection_invariant(&value.horizontal_radius[0])
				&& device_layout_value_is_projection_invariant(&value.vertical_radius[0])
		}
		BorderRadiusRectStyleValue {
			device_layout_value_is_projection_invariant(&value.top_left_[0])
				&& device_layout_value_is_projection_invariant(&value.top_right_[0])
				&& device_layout_value_is_projection_invariant(&value.bottom_right_[0])
				&& device_layout_value_is_projection_invariant(&value.bottom_left_[0])
		}
		EdgeStyleValue { device_layout_edge_is_projection_invariant(value) }
		PositionStyleValue {
			device_layout_edge_is_projection_invariant(&value.edge_x_)
				&& device_layout_edge_is_projection_invariant(&value.edge_y_)
		}
		TextIndentStyleValue {
			device_layout_value_is_projection_invariant(&value.length_percentage_[0])
		}
		GridTrackSizeListStyleValue { device_layout_grid_is_projection_invariant(value) }
		// Calculations, colors, transforms (including dimensionless matrix
		// translations), and unknown containers retain ordinary absolutization.
		else { false }
	}
}

fn device_layout_value_needs_projection(property_id PropertyID, value &StyleValue) bool {
	if device_layout_value_contains_lengths(value) {
		return !device_layout_value_is_projection_invariant(value)
	}
	return property_id in [.border_top_width, .border_right_width, .border_bottom_width,
		.border_left_width, .outline_width, .column_rule_width]
		&& value is KeywordStyleValue && value.keyword() in [.thin, .medium, .thick]
}

// Preserve the CSSOM's original style. Only the layout projection changes
// units; its fonts keep the source face, optical axes and shaping features.
pub fn computed_style_in_layout_coordinates(source &ComputedProperties,
	document &dom.Document) &ComputedProperties {
	mut scale := document.layout_coordinate_scale()
	if scale != 1 {
		if element := source.subject_element_ {
			// The outer SVG viewport participates in HTML box layout. Its
			// descendants keep SVG user units; the viewport CTM scales their
			// lengths, fonts and strokes when painting.
			if element.is_svg_element() && !is_outermost_svg_element_for_css_box_layout(element) {
				scale = 1
			}
		}
	}
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
	style_computer := css_style_computer_for(document)
	computer := style_computer.font_computer()
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
		font_input_refresh_safe_:       false
		// This is a layout snapshot of the already selected cascade values.
		// CSS-coordinate animation overlays must not replace its scaled values.
		animated_property_storage_:     unsafe { nil }
		animated_property_inherited_:   [computed_property_flag_byte_count]u8{}
		animated_property_result_of_transition_: [computed_property_flag_byte_count]u8{}
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
	if source.has_animated_properties() {
		for property_id, value in source.animated_property_storage_.values {
			if source.is_property_important(property_id)
				&& !source.is_animated_property_result_of_transition(property_id) { continue }
			// Materialize dimensionless samples too: colors and opacity do not
			// need scaling, but still replace their underlying static values.
			target.set_property_without_modifying_flags(property_id, value)
			target.set_property_inherited(property_id,
				if source.is_animated_property_inherited(property_id) { .yes } else { .no })
		}
	}
	font_page := (int(PropertyID.font_size) - int(first_longhand_property_id())) / computed_property_page_size
	mut reused_font_page := false
	if !source.has_animated_properties() && source.property_store_ != unsafe { nil } {
		if page := style_computer.device_layout_page(source.property_store_.pages[font_page], font_page, factor) {
			target.property_store_.pages[font_page] = page
			target.property_store_.writable &= ~(u32(1) << font_page)
			reused_font_page = true
		}
	}
	if !reused_font_page {
		target.set_property_without_modifying_flags(.font_size,
			dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(pixel_size)))))
	}
	// Installing font-size invalidates the inherited font cache. Seed the
	// scaled faces only after that setter, preserving the CSS optical axes.
	target.cached_computed_font_list_ = scaled_fonts
	target.cached_computed_font_list_generation_ = source.cached_computed_font_list_generation_
	target.cached_computed_font_list_owner_ = source.cached_computed_font_list_owner_
	target.cached_first_available_computed_font_ = scaled_fonts.font_for_code_point(u32(` `))
	// Absolutization only consumes the used scheme. Resolving current/accent
	// colors would also build an unused source length context for every style.
	mut context := ComputationContext{
		length_resolution_context: LengthResolutionContext{ absolute_length_scale: factor }
		color_scheme:              source.color_scheme(
			preferred_color_scheme_from_string(document.preferred_color_scheme()),
			document.supported_color_schemes())
	}
	mut has_length_context := false
	if element := source.subject_element_ {
		context.abstract_element = dom.AbstractElement.new(element, none)
	}
	property_ids := computed_interpolation_longhand_property_ids()
	use_page_candidates := !source.has_animated_properties() && source.property_store_ != unsafe { nil }
	for page_index in 0 .. computed_property_page_count {
		mask := if use_page_candidates {
			source.property_store_.pages[page_index].device_layout_candidates()
		} else { u16(0xffff) }
		if mask == 0 { continue }
		if use_page_candidates {
			if page := style_computer.device_layout_page(source.property_store_.pages[page_index], page_index, factor) {
				target.property_store_.pages[page_index] = page
				target.property_store_.writable &= ~(u32(1) << page_index)
				continue
			}
		}
		for slot in 0 .. computed_property_page_size {
			if mask & (u16(1) << slot) == 0 { continue }
			index := page_index * computed_property_page_size + slot
			if index >= property_ids.len { break }
			property_id := property_ids[index]
			if property_id == .font_size { continue }
			value := source.property(property_id, .yes) or { continue }
			// Inspect retained typed values before conversion and dispatch.
			// Dimensionless values and zero pixels already belong to the cloned
			// store. Untyped values still take the parser path.
			if value.css_value_handle != unsafe { nil } {
				box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
				if !device_layout_value_needs_projection(property_id, &box.value) { continue }
			}
			typed := style_value_logic_from_dom(property_id, value) or { continue }
			mut scaled := typed
			if device_layout_value_contains_lengths(typed) {
				// Apply the same check to values received through the parser path.
				if device_layout_value_is_projection_invariant(&typed) {
					continue
				}
				// Bare absolute lengths consume only the coordinate scale. Relative
				// and nested values still resolve against the complete physical context.
				needs_length_context := match typed {
					LengthStyleValue { !typed.length_.is_absolute() }
					else { !device_layout_value_is_scale_only(typed) }
				}
				if needs_length_context && !has_length_context {
					context.length_resolution_context = target.length_resolution_context()
					context.length_resolution_context.absolute_length_scale = factor
					has_length_context = true
				}
				scaled = typed.absolutized(context)
			} else if property_id in [.border_top_width, .border_right_width, .border_bottom_width,
				.border_left_width, .outline_width, .column_rule_width] {
				width := match typed.to_keyword() {
					.thin { 1.0 }
					.medium { 3.0 }
					.thick { 5.0 }
					else { 0.0 }
				}
				if width == 0 { continue }
				scaled = StyleValue(LengthStyleValue.create(Length.make_px(width * factor)))
			} else {
				// Colors, keywords, numbers and other dimensionless values are already
				// shared by the clone. Avoid comparing their unchanged value graphs.
				continue
			}
			if !scaled.equals(typed) {
				target.set_property_without_modifying_flags(property_id, dom_style_value_from_value_logic(scaled))
			}
		}
		if use_page_candidates {
			style_computer.retain_device_layout_page(source.property_store_.pages[page_index],
				mut target.property_store_, page_index, factor, mask)
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
