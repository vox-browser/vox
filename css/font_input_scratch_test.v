module css

import dom
import platform

fn test_font_input_cache_hits_do_not_retain_formatting_inputs() {
	mut thread_owner := platform.new_arena('font input owner')
	mut computer := FontComputer.create()
	mut style := computed_properties_with_initial_values()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text:'missing-example, serif'})
	style.set_property_without_modifying_flags(.font_feature_settings, &dom.StyleValue{css_text:'"liga" 0, "kern" 1'})
	style.set_property_without_modifying_flags(.font_variation_settings, &dom.StyleValue{css_text:'"wght" 450'})
	cascade := style.computed_font_list(computer)
	assert !cascade.is_empty()
	for _ in 0 .. 2 { style.clear_computed_font_list_cache(); _ = style.computed_font_list(computer) }
	before := platform.thread_arena_usage().used
	mut matches := 0
	for _ in 0 .. 256 {
		style.clear_computed_font_list_cache()
		found := style.computed_font_list(computer)
		if voidptr(found) == voidptr(cascade) { matches++ }
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
	assert matches == 256
	assert cascade.font_for_code_point(u32(`a`)).point_size > 0
	thread_owner.release()
}

fn test_nested_font_input_scopes_preserve_document_owned_cache_misses() {
	mut document := dom.Document.create(dom.URL{value:'https://font-inputs.test/'})
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	mut computer := FontComputer.create_for_document(document)
	mut outer := computer.acquire_font_input_scratch()
	mut style := computed_properties_with_initial_values()
	cascade := style.computed_font_list(computer)
	outer.finish()
	assert !cascade.is_empty()
	assert cascade.font_for_code_point(u32(`x`)).point_size > 0
	$if prealloc {
		assert document.native_storage().arena.contains(voidptr(cascade))
		assert computer.font_input_scratch_.depth == 0
		assert computer.font_input_scratch_.arenas.len == 2
	}
	scope.finish()
	$if prealloc {
		pool := computer.font_input_scratch_
		document.release_native_storage()
		for arena in pool.arenas { assert arena.usage().capacity == 0 }
	} $else { document.release_native_storage() }
}

fn font_input_worker_lookup() bool {
	mut computer := FontComputer.create()
	cascade := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400, Percentage{value_:100}, .auto_, map[string]f64{}, FontFeatureData{})
	return !cascade.is_empty() && computer.font_input_scratch_ == unsafe { nil } && computer.font_key_scratch_ == unsafe { nil }
}

fn test_font_computation_workers_do_not_enter_ui_input_arenas() {
	mut owner := platform.new_arena('font worker input ownership')
	worker := spawn font_input_worker_lookup()
	assert worker.wait()
	owner.release()
}
