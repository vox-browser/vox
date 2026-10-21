module css

import dom
import platform

fn initial_snapshot_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(true)
	return document
}

fn initial_snapshot_set(mut style ComputedProperties, property PropertyID, source string) {
	style.set_property(property, parse_css_value(ParsingParams{}, source, property) or { panic('invalid ${property}: ${source}') }, .no, .no)
}

fn initial_snapshot_resolve_ordinary(mut style ComputedProperties, document &dom.Document) {
	// An enclosing writer owns the durable record and excludes the temporary
	// publication scope, just as it does for nested production cache writes.
	owns := style.begin_computed_layout_cache_write()
	_ = resolve_computed_values_for_document(style, document)
	style.finish_computed_layout_cache_write(owns)
}

fn test_initial_native_snapshots_share_equal_values_but_keep_each_raw_graph_proof() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(first, document)
	_ = resolve_computed_values_for_document(second, document)
	$if prealloc {
		assert voidptr(first.computed_layout_cache()) == voidptr(second.computed_layout_cache())
		assert first.computed_layout_cache().owner_identity == 0
		assert first.computed_layout_cache().resolution_provenance == unsafe { nil }
	}
	assert first.geometry_provenance().matches(first)
	assert second.geometry_provenance().matches(second)
	assert voidptr(first.geometry_provenance()) != voidptr(second.geometry_provenance())
	assert voidptr(first.geometry_provenance().document) == voidptr(document)
	assert layout_inheritance_can_capture(first, document)
	cache := first.computed_layout_cache()
	proof := first.geometry_provenance()
	for _ in 0 .. 3 { _ = resolve_computed_values_for_document(first, document) }
	assert voidptr(first.computed_layout_cache()) == voidptr(cache)
	assert voidptr(first.geometry_provenance()) == voidptr(proof)
	scope.finish()
	document.release_native_storage()
}

fn test_shared_initial_snapshots_detach_on_direct_writes_and_raw_style_changes() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	mut first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(first, document)
	_ = resolve_computed_values_for_document(second, document)
	snapshot := second.computed_layout_cache()
	mut values := unsafe { &MutableComputedValues(first) }
	values.set_color(Color{1, 2, 3, 255})
	assert first.computed_layout_cache().computed_values_color_ == Color{1, 2, 3, 255}
	assert snapshot.computed_values_color_ == Color{0, 0, 0, 255}
	assert voidptr(first.computed_layout_cache()) != voidptr(snapshot)
	initial_snapshot_set(mut first, .width, '73px')
	_ = resolve_computed_values_for_document(first, document)
	assert first.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(73))
	assert snapshot.computed_values_width_ != first.computed_layout_cache().computed_values_width_
	assert first.geometry_provenance().matches(first)
	assert second.geometry_provenance().matches(second)
	scope.finish()
	document.release_native_storage()
}

fn test_initial_snapshot_values_match_the_existing_resolver_for_rare_and_ordinary_styles() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	for declarations in [map[PropertyID]string{}, {.width:'35px', .margin_left:'2px', .color:'red'},
		{.transform:'translateX(7px)', .clip_path:'inset(2px)', .background_image:'url(image.svg)'},
		{.direction:'rtl', .writing_mode:'vertical-rl', .font_size:'19px', .stroke_width:'3px'}] {
		mut expected := computed_properties_with_initial_values()
		mut actual := computed_properties_with_initial_values()
		for property, text in declarations {
			initial_snapshot_set(mut expected, property, text)
			initial_snapshot_set(mut actual, property, text)
		}
		initial_snapshot_resolve_ordinary(mut expected, document)
		_ = resolve_computed_values_for_document(actual, document)
		// Include every resolved field rather than selecting only the ones set
		// by this fixture. Provenance and write ownership intentionally differ.
		assert idle_layout_snapshots_equal(expected.computed_layout_cache(), actual.computed_layout_cache())
		assert actual.geometry_provenance().matches(actual)
		if actual.computed_layout_cache().rare_data_ != unsafe { nil } {
			assert voidptr(actual.computed_layout_cache()) != voidptr(expected.computed_layout_cache())
		}
	}
	scope.finish()
	document.release_native_storage()
}

fn test_shared_initial_snapshots_preserve_anonymous_inheritance_and_document_isolation() {
	mut first_document := initial_snapshot_document()
	mut second_document := initial_snapshot_document()
	mut first_scope := first_document.enter_native_storage()
	mut first := computed_properties_with_initial_values()
	initial_snapshot_set(mut first, .color, 'red')
	_ = resolve_computed_values_for_document(first, first_document)
	anonymous := resolve_anonymous_block_values_for_document(first, first_document)
	assert anonymous.color() == Color{255, 0, 0, 255}
	assert first.anonymous_computed_geometry_source(first.clone_for_anonymous_block()) != none
	first_scope.finish()
	mut second_scope := second_document.enter_native_storage()
	second := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(second, second_document)
	assert voidptr(first.computed_layout_cache()) != voidptr(second.computed_layout_cache())
	second_scope.finish()
	first_document.release_native_storage()
	assert second.computed_layout_cache().computed_values_color_ == Color{0, 0, 0, 255}
	second_document.release_native_storage()
}

fn test_initial_geometry_interning_avoids_duplicate_permanent_records() {
	$if !prealloc { return }
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	// Prime shared defaults and fonts before comparing retained allocations.
	warm := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(warm, document)
	before := document.native_storage().arena.usage().used
	for _ in 0 .. 64 {
		style := computed_properties_with_initial_values()
		_ = resolve_computed_values_for_document(style, document)
		assert voidptr(style.computed_layout_cache()) == voidptr(warm.computed_layout_cache())
	}
	actual := document.native_storage().arena.usage().used - before
	for _ in 0 .. 64 {
		mut style := computed_properties_with_initial_values()
		initial_snapshot_resolve_ordinary(mut style, document)
	}
	reference := document.native_storage().arena.usage().used - before - actual
	assert actual * 4 < reference * 3, '${actual} retained versus ${reference}'
	scope.finish()
	document.release_native_storage()
}

fn test_existing_native_snapshots_reuse_equal_resolutions_and_preserve_previous_values() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	mut style := computed_properties_with_initial_values()
	initial_snapshot_set(mut style, .width, '37px')
	_ = resolve_computed_values_for_document(style, document)
	first := style.computed_layout_cache()
	initial_snapshot_set(mut style, .width, '53px')
	_ = resolve_computed_values_for_document(style, document)
	second := style.computed_layout_cache()
	initial_snapshot_set(mut style, .width, '37px')
	_ = resolve_computed_values_for_document(style, document)
	$if prealloc {
		assert voidptr(style.computed_layout_cache()) == voidptr(first)
	}
	assert first.computed_values_width_ == Size.make_length(Length.make_px(37))
	assert second.computed_values_width_ == Size.make_length(Length.make_px(53))
	assert style.geometry_provenance().matches(style)
	// A rare record is excluded from interning, and its old payload stays frozen.
	initial_snapshot_set(mut style, .transform, 'translateX(17px)')
	_ = resolve_computed_values_for_document(style, document)
	rare := style.computed_layout_cache()
	old_transformations := unsafe { &ComputedValues(style) }.transformations()
	initial_snapshot_set(mut style, .transform, 'translateX(29px)')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache().rare_data_) != voidptr(rare.rare_data_)
	assert rare.rare_data().computed_values_transformations_ == old_transformations
	assert unsafe { &ComputedValues(style) }.transformations() != old_transformations
	scope.finish()
	document.release_native_storage()
}

fn test_anonymous_native_snapshots_share_and_inherit_without_changing_old_readers() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	mut parent := computed_properties_with_initial_values()
	initial_snapshot_set(mut parent, .color, 'red')
	initial_snapshot_set(mut parent, .width, '311px')
	_ = resolve_computed_values_for_document(parent, document)
	mut first := unsafe { &MutableComputedValues(resolve_anonymous_block_values_for_document(parent, document)) }
	second := resolve_anonymous_block_values_for_document(parent, document)
	old := first.computed_layout_cache()
	$if prealloc {
		assert voidptr(old) == voidptr(second.computed_layout_cache())
	}
	initial_snapshot_set(mut parent, .color, 'blue')
	initial_snapshot_set(mut parent, .font_size, '23px')
	_ = resolve_computed_values_for_document(parent, document)
	first.inherit_from(unsafe { &ComputedValues(parent) })
	updated := first.computed_layout_cache()
	first.inherit_from(unsafe { &ComputedValues(parent) })
	$if prealloc {
		assert voidptr(first.computed_layout_cache()) == voidptr(updated)
	}
	assert first.color() == Color{0, 0, 255, 255}
	assert first.font_size() == CSSPixels.nearest_value_for(23)
	assert first.computed_layout_cache().computed_values_width_ == old.computed_values_width_
	assert first.computed_layout_cache().computed_values_display_ == old.computed_values_display_
	assert old.computed_values_color_ == Color{255, 0, 0, 255}
	assert second.color() == Color{255, 0, 0, 255}
	assert second.font_size() != first.font_size()
	scope.finish()
	document.release_native_storage()
}

fn test_repeated_native_reresolution_does_not_retain_duplicate_cache_records() {
	$if !prealloc { return }
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	mut style := computed_properties_with_initial_values()
	widths := [parse_css_value(ParsingParams{}, '37px', .width) or { panic('width') },
		parse_css_value(ParsingParams{}, '53px', .width) or { panic('width') }]
	for width in widths {
		style.set_property(.width, width, .no, .no)
		_ = resolve_computed_values_for_document(style, document)
	}
	before := document.native_storage().arena.usage().used
	for index in 0 .. 64 {
		style.set_property(.width, widths[index % 2], .no, .no)
		_ = resolve_computed_values_for_document(style, document)
	}
	actual := document.native_storage().arena.usage().used - before
	for index in 0 .. 64 {
		style.set_property(.width, widths[index % 2], .no, .no)
		initial_snapshot_resolve_ordinary(mut style, document)
	}
	reference := document.native_storage().arena.usage().used - before - actual
	assert actual * 4 < reference, '${actual} retained versus ${reference}'
	scope.finish()
	document.release_native_storage()
}

fn test_scripted_initial_snapshot_aliases_survive_animation_and_raw_style_mutations() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	assert document.as_node().is_scripting_enabled()
	mut first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(first, document)
	_ = resolve_computed_values_for_document(second, document)
	original := second.computed_layout_cache()
	$if prealloc {
		assert voidptr(first.computed_layout_cache()) == voidptr(original)
	}
	initial_snapshot_set(mut first, .width, '37px')
	_ = resolve_computed_values_for_document(first, document)
	changed := first.computed_layout_cache()
	assert changed.computed_values_width_ == Size.make_length(Length.make_px(37))
	assert original.computed_values_width_ != changed.computed_values_width_
	first.set_animated_property(.width, parse_css_value(ParsingParams{}, '81px', .width) or { panic('width') }, .no, .no)
	_ = resolve_computed_values_for_document(first, document)
	assert first.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(81))
	assert changed.computed_values_width_ == Size.make_length(Length.make_px(37))
	first.remove_animated_property(.width)
	_ = resolve_computed_values_for_document(first, document)
	assert first.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(37))
	assert second.geometry_provenance().matches(second)
	assert voidptr(second.computed_layout_cache()) == voidptr(original)
	assert original.computed_values_width_ != Size.make_length(Length.make_px(37))
	scope.finish()
	document.release_native_storage()
}

fn test_scripted_typed_styles_share_but_animated_and_untyped_styles_keep_the_ordinary_path() {
	mut document := initial_snapshot_document()
	mut scope := document.enter_native_storage()
	document.set_scripting_enabled_by_embedder(true)
	assert document.as_node().is_scripting_enabled()
	scripted := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(scripted, document)
	$if prealloc {
		assert scripted.shared_geometry_cache_ != unsafe { nil }
	}
	mut untyped := computed_properties_with_initial_values()
	untyped.set_property(.width, &dom.StyleValue{css_text:'53px'}, .no, .no)
	_ = resolve_computed_values_for_document(untyped, document)
	assert untyped.shared_geometry_cache_ == unsafe { nil }
	assert untyped.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(53))
	mut animated := computed_properties_with_initial_values()
	animated.set_animated_property(.width, parse_css_value(ParsingParams{}, '67px', .width) or { panic('width') }, .no, .no)
	_ = resolve_computed_values_for_document(animated, document)
	assert animated.shared_geometry_cache_ == unsafe { nil }
	assert animated.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(67))
	scope.finish()
	document.release_native_storage()
}
