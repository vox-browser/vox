module css

import dom
import os

fn recompute_snapshot_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	for id, value in {
		PropertyID.font_family: 'RecomputeSnapshot,Arial'
		.font_size:             '16px'
		.font_weight:           '500'
	} {
		style.set_property_without_modifying_flags(id, &dom.StyleValue{ css_text: value })
	}
	return style
}

fn recompute_snapshot_load(mut face FontFaceObject) {
	face.finish_loading_from_typeface(&PlatformTypeface{
		family_name: 'RecomputeSnapshot'
		source_path: os.join_path(@VMODROOT, 'Tests', 'Browser', 'Brave', 'resources', 'Ahem.ttf')
		weight_:     500
	})
	assert face.status() == .loaded
}

fn test_full_cascade_invalidates_fallback_geometry_after_its_selected_face_finishes() {
	for early_query in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		mut computer := FontComputer.create_for_document(document)
		mut face := FontFaceObject.construct_impl_for_font_computer(computer, 'RecomputeSnapshot',
			FontFaceSource.from_string('url(late.ttf)'), FontFaceDescriptors{ weight: '500' })
		mut set := FontFaceSet.create_for_font_computer(computer)
		set.add(face) or { panic(err) }
		face.status_ = .loading
		mut previous := recompute_snapshot_style()
		original := previous.computed_font_list(computer)
		assert original.pending_faces.len == 1
		recompute_snapshot_load(mut face)
		assert !computer.cached_cascade_is_current(original)
		if early_query {
			current := previous.computed_font_list(computer)
			assert current.pending_faces.len == 0
			assert voidptr(current) != voidptr(original)
		}
		assert voidptr(previous.font_input_refresh_snapshot_) == voidptr(original)
		next := recompute_snapshot_style()
		element := document.create_element('div') or { panic(err) }
		invalidation := compute_required_invalidation(previous, next, computer, none,
			dom.AbstractElement.new(element, none))
		assert invalidation.needs_relayout()
	}
}

fn test_full_cascade_keeps_unchanged_pending_geometry_after_unrelated_font_completion() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut face := FontFaceObject.construct_impl_for_font_computer(computer, 'RecomputeSnapshot',
		FontFaceSource.from_string('url(late.ttf)'), FontFaceDescriptors{ weight: '500' })
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(face) or { panic(err) }
	face.status_ = .loading
	mut previous := recompute_snapshot_style()
	original := previous.computed_font_list(computer)
	computer.did_load_font('OtherFamily')
	mut next := recompute_snapshot_style()
	element := document.create_element('div') or { panic(err) }
	invalidation := compute_required_invalidation(previous, next, computer, none,
		dom.AbstractElement.new(element, none))
	assert !invalidation.needs_relayout()
	assert voidptr(next.computed_font_list(computer)) == voidptr(original)
}

fn test_full_cascade_keeps_identical_settled_font_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut face := FontFaceObject.construct_impl_for_font_computer(computer, 'RecomputeSnapshot',
		FontFaceSource.from_string('url(late.ttf)'), FontFaceDescriptors{ weight: '500' })
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(face) or { panic(err) }
	recompute_snapshot_load(mut face)
	mut previous := recompute_snapshot_style()
	assert previous.computed_font_list(computer).pending_faces.len == 0
	next := recompute_snapshot_style()
	element := document.create_element('div') or { panic(err) }
	invalidation := compute_required_invalidation(previous, next, computer, none,
		dom.AbstractElement.new(element, none))
	assert !invalidation.needs_relayout()
}
