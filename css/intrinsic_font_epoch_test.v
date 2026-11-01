module css

import dom

fn intrinsic_epoch_style(family string) &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: family})
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{css_text: '16px'})
	return style
}

fn test_intrinsic_font_epoch_keeps_an_original_live_cascade_after_unrelated_completions() {
	mut computer := FontComputer.create()
	mut style := intrinsic_epoch_style('monospace')
	list := style.computed_font_list(computer)
	generation := computer.environment_generation()
	assert style.cached_font_inputs_are_unchanged_since(computer, generation)
	computer.did_load_font('UnrelatedIntrinsicFamily')
	assert computer.environment_generation() > generation
	assert style.cached_font_inputs_are_unchanged_since(computer, generation)
	assert voidptr(style.computed_font_list(computer)) == voidptr(list)
	// Updating the style's last-used stamp must not hide the cascade's origin.
	assert style.cached_font_inputs_are_unchanged_since(computer, generation)
}

fn test_intrinsic_font_epoch_rejects_a_replacement_already_refreshed_by_another_consumer() {
	mut computer := FontComputer.create()
	mut style := intrinsic_epoch_style('monospace')
	previous := style.computed_font_list(computer)
	generation := computer.environment_generation()
	computer.clear_computed_font_cache('monospace')
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	replacement := style.computed_font_list(computer)
	assert voidptr(previous) != voidptr(replacement)
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
	assert style.cached_font_inputs_are_unchanged_since(computer, computer.environment_generation())
}

fn test_intrinsic_font_epoch_rejects_unknown_and_foreign_cascades() {
	mut computer := FontComputer.create()
	mut style := intrinsic_epoch_style('monospace')
	assert !style.cached_font_inputs_are_unchanged_since(computer, computer.environment_generation())
	_ = style.computed_font_list(computer)
	other := FontComputer.create()
	assert !style.cached_font_inputs_are_unchanged_since(other, computer.environment_generation())
	face := FontFaceObject.construct_impl('PendingIntrinsicFamily', FontFaceSource.from_string('url("pending-intrinsic.ttf")'), FontFaceDescriptors{})
	computer.register_font_face(face)
	mut pending := intrinsic_epoch_style('PendingIntrinsicFamily')
	assert pending.computed_font_list(computer).pending_faces.len == 1
	assert pending.cached_font_inputs_are_unchanged_since(computer, computer.environment_generation()) == !disable_pending_intrinsic_font_reuse
}

fn test_intrinsic_font_epoch_rejects_a_changed_font_rendering_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	computer := FontComputer.create_for_document(document)
	mut style := intrinsic_epoch_style('monospace')
	_ = style.computed_font_list(computer)
	generation := computer.environment_generation()
	document.set_font_rendering_policy(.chromium)
	assert !style.cached_font_inputs_are_unchanged_since(computer, generation)
}
