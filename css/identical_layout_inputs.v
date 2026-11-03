module css

import dom
import os
import platform

const disable_identical_layout_inputs = os.getenv('VOX_DISABLE_IDENTICAL_LAYOUT_INPUTS') != ''
const identical_layout_input_diagnostics = os.getenv('VOX_IDENTICAL_LAYOUT_INPUT_DIAGNOSTICS') != ''

struct IdenticalLayoutPage {
	page &ComputedPropertyPage
	generation u64
	index int
	safe bool
}

// Pages publish immutable typed values. Retain their identity and recycling
// epoch, rather than serializing and comparing every resolved geometry field.
// Only context-independent inputs participate; other styles use the resolver.
struct IdenticalLayoutInputs {
	pages [computed_property_page_count]&ComputedPropertyPage
	generations [computed_property_page_count]u64
	viewport CSSPixelRect
	root_font_size f64
	root_line_height f64
	root_font_viewport bool
	scale f64
	display Display
	fonts &FontCascadeList
	font_generation u64
	color Color
	scheme PreferredColorScheme
	accent ?Color
	cache &ComputedLayoutCache = unsafe { nil }
	line_height CSSPixels
}

fn identical_layout_value_is_safe(value &StyleValue) bool {
	return match value {
		LengthStyleValue { value.length_.is_absolute() }
		KeywordStyleValue, ColorStyleValue, NumberStyleValue, PercentageStyleValue,
		IntegerStyleValue, CustomIdentStyleValue, StringStyleValue, DisplayStyleValue { true }
		StyleValueList {
			mut safe := true
			for child in value.values_ {
				if !identical_layout_value_is_safe(&child) { safe = false; break }
			}
			safe
		}
		SuperellipseStyleValue {
			value.parameter_.len == 1 && identical_layout_value_is_safe(&value.parameter_[0])
		}
		RGBColorStyleValue {
			value.r_.len == 1 && value.g_.len == 1 && value.b_.len == 1 && value.alpha_.len == 1
				&& identical_layout_value_is_safe(&value.r_[0])
				&& identical_layout_value_is_safe(&value.g_[0])
				&& identical_layout_value_is_safe(&value.b_[0])
				&& identical_layout_value_is_safe(&value.alpha_[0])
		}
		GridTrackSizeListStyleValue { device_layout_grid_is_projection_invariant(value) }
		else { computed_page_value_is_scalar(value) && !device_layout_value_contains_lengths(value) }
	}
}

fn identical_layout_page_is_safe(mut pool InitialLayoutSnapshotPool, page &ComputedPropertyPage, index int) bool {
	if computed_initial_property_store != unsafe { nil }
		&& voidptr(page) == voidptr(computed_initial_property_store.pages[index]) { return true }
	key := u64(voidptr(page))
	if saved := pool.identical_pages[key] {
		if saved.generation != 0 && saved.generation == page.device_layout_generation_
			&& saved.index == index { return saved.safe }
	}
	mut safe := page.device_layout_generation_ != 0
	for slot, value in page.values {
		if !safe { break }
		if value == unsafe { nil } { continue }
		if computed_initial_property_store != unsafe { nil }
			&& voidptr(value) == voidptr(computed_initial_property_store.pages[index].values[slot]) { continue }
		if value.css_value_handle == unsafe { nil } { safe = false; break }
		box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if !identical_layout_value_is_safe(&box.value) { safe = false }
	}
	if pool.identical_pages.len < 4096 {
		pool.identical_pages[key] = IdenticalLayoutPage{page:page, generation:page.device_layout_generation_, index:index, safe:safe}
	}
	return safe
}

fn identical_layout_inputs(style &ComputedProperties, document &dom.Document) ?(u64, IdenticalLayoutInputs) {
	$if !prealloc { return none }
	if disable_identical_layout_inputs || style.computed_values_resolved_
		|| style.property_store_ == unsafe { nil } || style.line_height_ != none
		|| style.font_variation_storage_ != unsafe { nil }
		|| style.has_animated_properties() || style.has_animated_custom_properties()
		|| platform.transient_arena_entered() { return none }
	owner := document.native_storage()
	if owner == unsafe { nil } || voidptr(owner) != voidptr(platform.current_retained_arena()) { return none }
	fonts := style.cached_computed_font_list_ or { return none }
	if fonts.pending_faces.len != 0 { return none }
	mut computer := css_style_computer_for(document)
	if computer.initial_layout_snapshots_ == unsafe { nil } {
		computer.initial_layout_snapshots_ = &InitialLayoutSnapshotPool{}
	}
	mut pool := computer.initial_layout_snapshots_
	mut generations := [computed_property_page_count]u64{}
	mut key := u64(14695981039346656037)
	for index, page in style.property_store_.pages {
		if !computer.can_retain_device_layout_page(page) { return none }
		if !identical_layout_page_is_safe(mut pool, page, index) { return none }
		generations[index] = page.device_layout_generation_
		key = layout_snapshot_mix(key, u64(voidptr(page)))
		key = layout_snapshot_mix(key, generations[index])
	}
	context := ColorResolutionContext.for_computed_properties(style, document)
	// Freeze pages before retaining their identity. Every later setter, even
	// through a value-copy alias of this store, must allocate its own page.
	mut store := unsafe { &ComputedPropertyStore(style.property_store_) }
	store.writable = 0
	return key, IdenticalLayoutInputs{
		pages:store.pages, generations:generations, viewport:style.viewport_rect_
		root_font_size:style.root_font_size_px_, root_line_height:style.root_line_height_px_
		root_font_viewport:style.root_font_metrics_depend_on_viewport_metrics_
		scale:style.layout_coordinate_scale(), display:style.display_before_box_type_transformation_
		fonts:fonts, font_generation:style.cached_computed_font_list_generation_
		color:context.current_color or { Color{0,0,0,255} }
		scheme:context.color_scheme or { PreferredColorScheme.light }, accent:context.accent_color
	}
}

fn (first &IdenticalLayoutInputs) matches(second &IdenticalLayoutInputs) bool {
	if first.viewport != second.viewport || first.root_font_size != second.root_font_size
		|| first.root_line_height != second.root_line_height || first.root_font_viewport != second.root_font_viewport
		|| first.scale != second.scale || first.display != second.display
		|| voidptr(first.fonts) != voidptr(second.fonts) || first.font_generation != second.font_generation
		|| first.color != second.color || first.scheme != second.scheme || first.accent != second.accent { return false }
	for index, page in first.pages {
		if voidptr(page) != voidptr(second.pages[index]) || first.generations[index] == 0
			|| first.generations[index] != second.generations[index] { return false }
	}
	return true
}

fn consume_identical_layout_inputs(style &ComputedProperties, document &dom.Document) bool {
	key, inputs := identical_layout_inputs(style, document) or { return false }
	pool := css_style_computer_for(document).initial_layout_snapshots_
	saved_inputs := pool.identical_inputs[key] or { return false }
	for saved in saved_inputs {
		if !saved.matches(&inputs) || saved.cache == unsafe { nil } { continue }
		mut target := unsafe { &ComputedProperties(style) }
		if target.mutation_revision() == 0 { return false }
		target.computed_layout_cache_ = saved.cache
		target.computed_values_line_height_ = saved.line_height
		target.computed_values_resolved_ = true
		target.shared_geometry_cache_ = saved.cache
		target.shared_geometry_provenance_ = &ComputedGeometryProvenance{
			document:document, token:target.computed_property_graph_token_, generation:target.mutation_revision()
			raw_generation:target.computed_property_graph_token_.raw_generation
			viewport:target.viewport_rect_, root_font_size:target.root_font_size_px_, root_line_height:target.root_line_height_px_
			root_font_depends_on_viewport:target.root_font_metrics_depend_on_viewport_metrics_, subject:target.subject_element_
			font_list:inputs.fonts, font_computer:target.cached_computed_font_list_owner_
			font_generation:target.cached_computed_font_list_generation_, font_cascade_was_settled:true
		}
		if identical_layout_input_diagnostics { eprintln('Vox identical layout inputs: reused immutable geometry') }
		return true
	}
	return false
}

fn retain_identical_layout_inputs(style &ComputedProperties, document &dom.Document) {
	// Input capture rejects resolved styles; use a value copy only to inspect
	// the raw pages. The retained entry contains no temporary style pointer.
	mut raw := ComputedProperties{...*style, computed_values_resolved_:false}
	key, inputs := identical_layout_inputs(raw, document) or { return }
	cache := style.computed_layout_cache()
	if cache.writable_owner_identity != 0 || cache.rare_data_writable_ { return }
	mut pool := css_style_computer_for(document).initial_layout_snapshots_
	mut saved := pool.identical_inputs[key] or { []IdenticalLayoutInputs{} }
	if pool.identical_inputs.len >= 4096 || saved.len >= 8 { return }
	saved << IdenticalLayoutInputs{...inputs, cache:cache, line_height:style.computed_values_line_height_}
	pool.identical_inputs[key] = saved
}
