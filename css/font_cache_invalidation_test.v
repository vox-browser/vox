module css

import dom

fn pending_font_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'Pending'
	})
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '16px'
	})
	return style
}

fn test_pending_font_cascade_is_reused_for_unchanged_style() {
	mut computer := FontComputer.create()
	face := FontFaceObject.construct_impl('Pending',
		FontFaceSource.from_string('url("pending.ttf")'), FontFaceDescriptors{})
	computer.register_font_face(face)
	mut previous := pending_font_style()
	previous_list := previous.computed_font_list(computer)
	assert previous_list.pending_faces.len == 1
	mut next := pending_font_style()
	assert !previous_list.equals(next.computed_font_list(computer))
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	abstract_element := dom.AbstractElement.new(element, none)
	invalidation := compute_required_invalidation(previous, next, computer, none, abstract_element)
	assert !invalidation.needs_relayout()
	assert voidptr(next.computed_font_list(computer)) == voidptr(previous_list)
	// The lower-level pending-cascade comparison keeps its upstream behavior.
	assert !previous_list.equals(previous_list)
}

fn test_font_cache_reuse_rejects_changed_inputs_and_environment() {
	mut computer := FontComputer.create()
	mut previous := pending_font_style()
	_ = previous.computed_font_list(computer)
	for property_id, text in {
		PropertyID.font_size:   '20px'
		.font_weight:           '700'
		.font_optical_sizing:   'none'
		.font_feature_settings: '"liga" 0'
		.font_variant_caps:     'small-caps'
		.font_kerning:          'none'
		.text_rendering:        'optimizeSpeed'
	} {
		mut changed := pending_font_style()
		changed.set_property_without_modifying_flags(property_id, &dom.StyleValue{
			css_text: text
		})
		assert !changed.reuse_unchanged_font_cache(previous, computer)
	}
	mut next := pending_font_style()
	computer.clear_computed_font_cache('Pending')
	assert !next.reuse_unchanged_font_cache(previous, computer)
	other_computer := FontComputer.create()
	assert !next.reuse_unchanged_font_cache(previous, other_computer)
}

fn test_font_feature_mutations_clear_the_cached_cascade() {
	computer := FontComputer.create()
	mut style := pending_font_style()
	for property_id in [PropertyID.font_optical_sizing, .font_feature_settings, .font_variant_caps,
		.font_variant_emoji, .font_kerning, .text_rendering] {
		_ = style.computed_font_list(computer)
		style.set_property_without_modifying_flags(property_id,
			&dom.StyleValue{
				css_text: 'normal'
			})
		assert style.cached_computed_font_list() == none
	}
}

fn test_unrelated_font_invalidation_preserves_live_cascade_inputs_across_style_copies() {
	mut computer := FontComputer.create()
	mut previous := pending_font_style()
	list := previous.computed_font_list(computer)
	generation := previous.cached_computed_font_list_generation_
	computer.did_load_font('Unrelated')
	assert computer.environment_generation() != generation
	assert computer.cached_cascade_is_current(list)
	mut next := pending_font_style()
	assert next.reuse_unchanged_font_cache(previous, computer)
	assert voidptr(next.computed_font_list(computer)) == voidptr(list)
	assert next.cached_computed_font_list_generation_ == computer.environment_generation()
	assert voidptr(previous.computed_font_list(computer)) == voidptr(list)
	assert previous.cached_computed_font_list_generation_ == computer.environment_generation()
}

fn test_expired_family_cascades_cannot_be_reused_after_their_cache_entry_is_removed() {
	mut computer := FontComputer.create()
	mut previous := pending_font_style()
	list := previous.computed_font_list(computer)
	computer.clear_computed_font_cache('Pending')
	assert !computer.cached_cascade_is_current(list)
	mut next := pending_font_style()
	assert !next.reuse_unchanged_font_cache(previous, computer)
	assert voidptr(previous.computed_font_list(computer)) != voidptr(list)
	assert computer.cached_cascade_is_current(previous.computed_font_list(computer))
}

fn test_cascade_liveness_requires_its_original_font_computer_and_rendering_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := FontComputer.create_for_document(document)
	mut style := pending_font_style()
	list := style.computed_font_list(computer)
	assert computer.cached_cascade_is_current(list)
	other := FontComputer.create()
	assert !other.cached_cascade_is_current(list)
	assert !computer.cached_cascade_is_current(FontCascadeList.create())
	document.set_font_rendering_policy(.chromium)
	assert !computer.cached_cascade_is_current(list)
	replacement := style.computed_font_list(computer)
	assert voidptr(replacement) != voidptr(list)
	assert computer.cached_cascade_is_current(replacement)
}

fn test_pending_face_completion_expires_only_cascades_that_selected_that_face() {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	regular := FontFaceObject.construct_impl('Pending', FontFaceSource.from_string('url("regular.ttf")'), FontFaceDescriptors{ weight: '400' })
	mut bold := FontFaceObject.construct_impl('Pending', FontFaceSource.from_string('url("bold.ttf")'), FontFaceDescriptors{ weight: '700' })
	set.add(regular)!
	set.add(bold)!
	mut regular_style := pending_font_style()
	mut bold_style := pending_font_style()
	bold_style.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{ css_text: '700' })
	regular_list := regular_style.computed_font_list(computer)
	bold_list := bold_style.computed_font_list(computer)
	assert regular_list.depends_on_pending_face(regular)
	assert bold_list.depends_on_pending_face(bold)
	bold.status_ = .loaded
	bold.parsed_font = &PlatformTypeface{ family_name: 'Pending', source_path: 'bold.ttf', weight_: 700 }
	computer.publish_loaded_font_face(bold)
	assert computer.cached_cascade_is_current(regular_list)
	assert !computer.cached_cascade_is_current(bold_list)
	assert voidptr(regular_style.computed_font_list(computer)) == voidptr(regular_list)
	assert voidptr(bold_style.computed_font_list(computer)) != voidptr(bold_list)
}
