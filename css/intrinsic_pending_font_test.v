module css

import dom

fn intrinsic_pending_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'IntrinsicPending, monospace'})
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{css_text: '16px'})
	return style
}

fn intrinsic_pending_fixture() (&FontComputer, &FontFaceObject, &ComputedProperties) {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	mut face := FontFaceObject.construct_impl('IntrinsicPending', FontFaceSource.from_string('url("pending.ttf")'), FontFaceDescriptors{ display: 'fallback' })
	set.add(face) or { panic(err) }
	// Hold transport pending so display transitions can be tested deterministically.
	face.status_ = .loading
	face.set_font_display_time_for_testing(0)
	mut style := intrinsic_pending_style()
	list := style.computed_font_list(computer)
	assert list.pending_faces.len == 1
	return computer, face, style
}

fn test_pending_intrinsic_fonts_reuse_original_fallback_metrics_after_unrelated_completions() {
	mut computer, face, style := intrinsic_pending_fixture()
	list := style.computed_font_list(computer)
	assert face.font_download_timer_start_ns_ == none
	metrics := list.font_for_code_point(`A`)
	blocked := list.font_for_code_point_for_shaping(`A`)
	assert blocked.is_invisible && !metrics.is_invisible
	generation := computer.environment_generation()
	computer.did_load_font('UnrelatedIntrinsic')
	assert style.cached_font_inputs_are_unchanged_since(computer, generation) == !disable_pending_intrinsic_font_reuse
	assert voidptr(style.computed_font_list(computer)) == voidptr(list)
	assert list.font_for_code_point(`A`).point_size == metrics.point_size
	assert list.font_for_code_point_for_shaping(`A`).is_invisible
}

fn test_pending_intrinsic_fonts_expire_on_block_to_swap_and_swap_to_failure() {
	mut computer, mut face, style := intrinsic_pending_fixture()
	list := style.computed_font_list(computer)
	assert list.font_for_code_point_for_shaping(`A`).is_invisible
	generation := computer.environment_generation()
	face.set_font_display_time_for_testing(100)
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	swap := style.computed_font_list(computer)
	assert swap.pending_faces.len == 1
	assert !swap.font_for_code_point_for_shaping(`A`).is_invisible
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	swap_generation := computer.environment_generation()
	computer.did_load_font('UnrelatedIntrinsic')
	assert style.cached_font_inputs_are_unchanged_since(computer, swap_generation) == !disable_pending_intrinsic_font_reuse
	face.set_font_display_time_for_testing(3100)
	assert !style.cached_font_inputs_are_unchanged_since(computer, swap_generation)
	assert style.computed_font_list(computer).pending_faces.len == 0
}

fn test_pending_intrinsic_fonts_expire_on_download_failure() {
	mut computer, mut face, style := intrinsic_pending_fixture()
	list := style.computed_font_list(computer)
	_ = list.font_for_code_point_for_shaping(`A`)
	generation := computer.environment_generation()
	face.finish_loading_from_typeface(unsafe { nil })
	assert face.status() == .error
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	assert style.computed_font_list(computer).pending_faces.len == 0
}

fn test_pending_intrinsic_fonts_expire_on_selected_completion_but_keep_other_weights() {
	mut computer, mut face, style := intrinsic_pending_fixture()
	mut other := FontFaceObject.construct_impl('IntrinsicPending', FontFaceSource.from_string('url("bold.ttf")'), FontFaceDescriptors{ weight: '700' })
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(other) or { panic(err) }
	_ = style.computed_font_list(computer)
	generation := computer.environment_generation()
	other.status_ = .loaded
	other.parsed_font = &PlatformTypeface{ family_name: 'IntrinsicPending', source_path: 'bold.ttf', weight_: 700 }
	computer.publish_loaded_font_face(other)
	assert style.cached_font_inputs_are_unchanged_since(computer, generation) == !disable_pending_intrinsic_font_reuse
	face.status_ = .loaded
	face.parsed_font = &PlatformTypeface{ family_name: 'IntrinsicPending', source_path: 'regular.ttf', weight_: 400 }
	computer.publish_loaded_font_face(face)
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	assert style.computed_font_list(computer).pending_faces.len == 0
}

fn test_pending_intrinsic_fonts_do_not_start_loading_during_cache_validation() {
	mut computer, face, style := intrinsic_pending_fixture()
	_ = style.computed_font_list(computer)
	generation := computer.environment_generation()
	computer.did_load_font('UnrelatedIntrinsic')
	assert style.cached_font_inputs_are_unchanged_since(computer, generation) == !disable_pending_intrinsic_font_reuse
	assert face.font_download_timer_start_ns_ == none
	assert face.font_loader_ == none
	computer.clear_computed_font_cache('IntrinsicPending')
	_ = style.computed_font_list(computer)
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
}
