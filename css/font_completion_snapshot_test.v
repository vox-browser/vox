module css

import dom
import os

fn completion_snapshot_fixture() (&dom.Document, &dom.Element, &ComputedProperties, &FontFaceObject) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := css_style_computer_for(document).font_computer()
	mut set := FontFaceSet.create_for_font_computer(computer)
	mut face := FontFaceObject.construct_impl_for_font_computer(computer, 'CompletionSnapshot',
		FontFaceSource.from_string('url(late.ttf)'), FontFaceDescriptors{ display: 'swap' })
	set.add(face) or { panic(err) }
	face.status_ = .loading
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font:16px/20px CompletionSnapshot,Arial')
	mut subject := dom.AbstractElement.new(element, none)
	style := css_style_computer_for(document).compute_style(subject)
	subject.set_computed_properties(computed_properties_to_dom(style))
	_ = resolve_computed_values_for_document(style, document)
	assert style.font_input_refresh_safe_
	assert (style.cached_computed_font_list() or { panic('missing pending cascade') }).pending_faces.len == 1
	return document, element, style, face
}

fn test_selected_face_invalidation_keeps_the_geometry_snapshot_after_an_early_font_query() {
	document, element, mut style, mut face := completion_snapshot_fixture()
	defer { document.finalize() }
	original := style.font_input_refresh_snapshot_
	assert original != unsafe { nil }
	assert original.depends_on_pending_face(face)
	face.finish_loading_from_typeface(&PlatformTypeface{
		family_name: 'CompletionSnapshot'
		source_path: os.join_path(@VMODROOT, 'Tests', 'Browser', 'Brave', 'resources', 'Ahem.ttf')
		weight_:     400
	})
	assert face.status() == .loaded
	computer := css_style_computer_for(document)
	current := style.computed_font_list(computer.font_computer())
	assert current.pending_faces.len == 0
	assert voidptr(current) != voidptr(original)
	assert voidptr(style.font_input_refresh_snapshot_) == voidptr(original)
	bridge := element.el_computed_properties() or { panic('missing bridge') }
	assert retained_style_needs_changed_font_inputs(bridge, 'CompletionSnapshot', face)
	invalidation := computer.refresh_font_inputs(dom.AbstractElement.new(element, none))
	assert !invalidation.is_none()
	assert voidptr(style.font_input_refresh_snapshot_) == voidptr(current)
	assert !retained_style_needs_changed_font_inputs(bridge, 'CompletionSnapshot', face)
}

fn test_font_completion_snapshot_does_not_add_an_unselected_face_dependency() {
	document, element, _, selected := completion_snapshot_fixture()
	defer { document.finalize() }
	other := FontFaceObject.construct_impl('CompletionSnapshot',
		FontFaceSource.from_string('url(other.ttf)'), FontFaceDescriptors{ weight: '700' })
	bridge := element.el_computed_properties() or { panic('missing bridge') }
	assert retained_style_needs_changed_font_inputs(bridge, 'CompletionSnapshot', selected)
	assert !retained_style_needs_changed_font_inputs(bridge, 'CompletionSnapshot', other)
}
