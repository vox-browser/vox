module layout

import css
import html
import platform

fn opacity_measurement_run(mut source LayoutState, root &Node, kind string) bool {
	return if kind == 'grid' {
		grid_measurement_test_compare(mut source, root, 240, 0, 500)
	} else {
		flex_measurement_test_compare(mut source, root, 240, 0, .normal, '')
	}
}

fn test_opacity_measurements_reuse_owned_grid_and_flex_geometry_after_probe_retirement() {
	for kind in ['grid', 'flex'] {
		mut document := html.parse_document('<!doctype html><section id="root" style="display:${kind};width:240px;gap:7px;grid-template-columns:1fr 1fr"><div id="fade"><span>Animated opacity wrapping text alpha beta 😀.</span></div><div>Other wrapping words and text.</div></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'root')
		fade := grid_measurement_test_node(document, 'fade')
		mut style := unsafe { &css.ComputedProperties(fade.computed_values()) }
		alpha := css.parse_css_value(css.ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
		style.set_animated_property(.opacity, alpha, .yes, .no)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		defer { source.release_measurement_chunk_pool() }
		assert !opacity_measurement_run(mut source, root, kind)
		assert !opacity_measurement_run(mut source, root, kind)
		for _ in 0 .. 3 {
			gc_collect()
			assert opacity_measurement_run(mut source, root, kind) == !retain_animated_opacity_measurements
		}
		assert (style.property(.opacity, .yes) or { panic('missing opacity') }).css_text == alpha.css_text
		// Across-pass retained layout must still reject the animated subtree.
		mut persistent_inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert !collect_retained_block_inputs(root, mut persistent_inputs, mut rejected)
	}
}

fn test_opacity_measurements_invalidate_after_sample_replacement_and_raw_alias_writes() {
	for kind in ['grid', 'flex'] {
		mut document := html.parse_document('<!doctype html><section id="root" style="display:${kind};width:240px;grid-template-columns:1fr 1fr"><div id="fade">Several wrapping words for independent lines.</div><div>More text.</div></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'root')
		fade := grid_measurement_test_node(document, 'fade')
		mut style := unsafe { &css.ComputedProperties(fade.computed_values()) }
		initial := css.parse_css_value(css.ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
		style.set_animated_property(.opacity, initial, .no, .no)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		defer { source.release_measurement_chunk_pool() }
		assert !opacity_measurement_run(mut source, root, kind)
		assert !opacity_measurement_run(mut source, root, kind)
		assert opacity_measurement_run(mut source, root, kind) == !retain_animated_opacity_measurements
		for alpha in ['0.5', '0.75'] {
			replacement := css.parse_css_value(css.ParsingParams{}, alpha, .opacity) or { panic('opacity') }
			style.set_animated_property(.opacity, replacement, .no, .no)
			assert !opacity_measurement_run(mut source, root, kind)
			assert !opacity_measurement_run(mut source, root, kind)
		}
		mut alias := *style
		width := css.parse_css_value(css.ParsingParams{}, '55px', .width) or { panic('width') }
		alias.set_property(.width, width, .no, .no)
		assert !opacity_measurement_run(mut source, root, kind)
		assert !opacity_measurement_run(mut source, root, kind)
	}
}

fn test_opacity_measurements_keep_other_animations_and_custom_properties_on_full_layout() {
	for extra in ['width', 'transform', 'custom'] {
		mut document := html.parse_document('<!doctype html><section id="root" style="display:grid;width:240px"><div id="fade">Animated content.</div></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'root')
		fade := grid_measurement_test_node(document, 'fade')
		mut style := unsafe { &css.ComputedProperties(fade.computed_values()) }
		alpha := css.parse_css_value(css.ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
		style.set_animated_property(.opacity, alpha, .no, .no)
		if extra == 'custom' { style.set_animated_custom_property('--x', alpha) }
		else {
			property := if extra == 'width' { css.PropertyID.width } else { css.PropertyID.transform }
			value := css.parse_css_value(css.ParsingParams{}, if extra == 'width' { '50px' } else { 'translateX(7px)' }, property) or { panic('animation') }
			style.set_animated_property(property, value, .no, .no)
		}
		assert !measurement_style_has_reusable_animation(fade.computed_values())
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		defer { source.release_measurement_chunk_pool() }
		for _ in 0 .. 2 { assert !opacity_measurement_run(mut source, root, 'grid') }
	}
}

fn test_opacity_measurement_entries_do_not_outlive_the_pass_pool() {
	mut document := html.parse_document('<!doctype html><section id="root" style="display:grid;width:240px"><div id="fade">Text for a retained line.</div></section>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'root')
	fade := grid_measurement_test_node(document, 'fade')
	mut style := unsafe { &css.ComputedProperties(fade.computed_values()) }
	alpha := css.parse_css_value(css.ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
	style.set_animated_property(.opacity, alpha, .no, .no)
	for _ in 0 .. 3 {
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		assert !opacity_measurement_run(mut source, root, 'grid')
		assert !opacity_measurement_run(mut source, root, 'grid')
		assert opacity_measurement_run(mut source, root, 'grid') == !retain_animated_opacity_measurements
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert source.measurement_chunk_pool_ == unsafe { nil }
		assert pool.closed && pool.opacity_measurement_seen_.len == 0
	}
	// Neither the borrowed eligibility query nor a hit can retain more data.
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1000 { assert measurement_style_has_reusable_animation(fade.computed_values()) == !retain_animated_opacity_measurements }
	assert platform.thread_arena_usage().used == before
}
