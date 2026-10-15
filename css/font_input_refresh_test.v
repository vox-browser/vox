module css

import dom

fn font_input_fixture() (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	root.set_attribute_value('style', 'font-family: FontInputFixture, sans-serif; font-size:20px; line-height:normal; padding:8px')
	mut subject := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	subject.set_attribute_value('style', 'font-size:20px;width:120px;padding:4px')
	mut unrelated := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	unrelated.set_attribute_value('style', 'font-family:serif;font-size:20px;width:120px')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(subject.as_node()) or { panic(err) }
	root_node.append_child(unrelated.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	for element in [root, subject, unrelated] {
		style := font_input_style(element, none)
		_ = resolve_computed_values_for_document(style, document)
	}
	document.reset_style_invalidation_counters()
	return document, root, subject, unrelated
}

fn font_input_style(element &dom.Element, pseudo ?dom.PseudoElement) &ComputedProperties {
	bridge := dom.AbstractElement.new(element, pseudo).computed_properties() or { panic('missing style') }
	return computed_properties_from_dom(bridge) or { panic('missing style owner') }
}

fn font_input_install_real_face(document &dom.Document) {
	computer := css_style_computer_for(document).font_computer()
	mut face := FontFaceObject.construct_impl_for_font_computer(computer,
		'FontInputFixture', FontFaceSource.from_string('url("late-font.ttf")'), FontFaceDescriptors{})
	typeface := platform_load_font_from_url_boundary('file:///System/Library/Fonts/Supplemental/Arial.ttf', 'FontInputFixture')
	assert typeface != unsafe { nil }
	// Complete through the same callback as a late font-loading task.
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(face) or { panic(err) }
	assert face.begin_url_load()
	face.finish_loading_from_typeface(typeface)
	assert face.status() == .loaded
}

fn font_input_assert_full_cascade_oracle(element &dom.Element, pseudo ?dom.PseudoElement) {
	computer := css_style_computer_for(element.document())
	actual := font_input_style(element, pseudo)
	expected := computer.compute_style(dom.AbstractElement.new(element, pseudo))
	for id in computed_interpolation_longhand_property_ids() {
		assert (actual.property(id, .no) or { panic('missing actual') }).css_text ==
			(expected.property(id, .no) or { panic('missing expected') }).css_text, '${id}'
	}
	actual_values := resolve_computed_values_for_document(actual, element.document())
	expected_values := resolve_computed_values_for_document(expected, element.document())
	assert actual_values.line_height() == expected_values.line_height()
	assert actual_values.font_size() == expected_values.font_size()
	assert actual_values.font_list().equals(expected_values.font_list())
}

fn test_font_inputs_refresh_retains_styles_and_normal_metrics_after_real_face_load() {
	$if macos {
		mut document, root, subject, unrelated := font_input_fixture()
		before := font_input_style(subject, none)
		original_bridge := subject.el_computed_properties() or { panic('missing bridge') }
		unrelated_before := font_input_style(unrelated, none)
		font_input_install_real_face(document)
		assert root.has_pending_font_input_update()
		assert subject.has_pending_font_input_update()
		assert !subject.needs_style_update()
		assert unrelated.has_pending_font_input_update()
		assert !document.needs_full_style_update()
		assert document.element_needs_style_update(subject)
		document.update_style()
		after := font_input_style(subject, none)
		assert voidptr(after) == voidptr(before)
		assert voidptr(subject.el_computed_properties() or { panic('bridge') }) == voidptr(original_bridge)
		assert voidptr(font_input_style(unrelated, none)) == voidptr(unrelated_before)
		assert !subject.has_pending_font_input_update()
		assert document.style_invalidation_counters().element_style_recomputations == 0
		assert document.style_invalidation_counters().element_inherited_style_recomputations > 0
		mut mutable_after := unsafe { &ComputedProperties(after) }
		selected := mutable_after.first_available_computed_font(css_style_computer_for(document).font_computer())
		assert selected.typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		root_style := font_input_style(root, none)
		assert after.root_line_height_px_ == root_style.line_height().to_double()
		font_input_assert_full_cascade_oracle(root, none)
		font_input_assert_full_cascade_oracle(subject, none)
		font_input_assert_full_cascade_oracle(unrelated, none)
	}
}

fn test_font_input_guard_tracks_nested_font_lengths_and_relative_font_size() {
	document := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(document)
	for text in ['width:2ch', 'width:calc(2ch + 3px)',
		'background-image:linear-gradient(red 1em, blue 2em)', 'box-shadow:1em 2px black',
		'font-size:125%', 'font-family:monospace'] {
		mut element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
		element.set_attribute_value('style', text)
		computed := computer.compute_style(dom.AbstractElement.new(element, none))
		assert !computed.font_input_refresh_safe_, text
	}
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	element.set_attribute_value('style', 'width:calc(30px + 10%);font-size:20px;line-height:normal')
	assert computer.compute_style(dom.AbstractElement.new(element, none)).font_input_refresh_safe_
}

fn test_font_input_refresh_preserves_simultaneous_dom_style_mutation() {
	$if macos {
		mut document, _, subject, _ := font_input_fixture()
		before := font_input_style(subject, none)
		font_input_install_real_face(document)
		mut mutable_subject := unsafe { &dom.Element(subject) }
		mutable_subject.set_attribute_value('style', 'font-size:20px;width:231px;padding:4px')
		assert subject.needs_style_update()
		assert subject.has_pending_font_input_update()
		document.update_style()
		after := font_input_style(subject, none)
		assert voidptr(after) != voidptr(before)
		assert (after.property(.width, .no) or { panic('width') }).css_text == '231px'
		font_input_assert_full_cascade_oracle(subject, none)
	}
}

fn test_font_input_guard_keeps_relative_lengths_on_the_full_cascade_path() {
	$if macos {
		mut document, _, subject, _ := font_input_fixture()
		mut mutable_subject := unsafe { &dom.Element(subject) }
		mutable_subject.set_attribute_value('style', 'font-size:20px;width:calc(2ch + 3px);padding:4px')
		document.update_style()
		before := font_input_style(subject, none)
		assert !before.font_input_refresh_safe_
		font_input_install_real_face(document)
		document.update_style()
		assert voidptr(font_input_style(subject, none)) != voidptr(before)
		font_input_assert_full_cascade_oracle(subject, none)
	}
}

fn test_font_input_family_fanout_includes_shadow_and_pseudo_styles() {
	$if macos {
		mut document, root, subject, unrelated := font_input_fixture()
		mut mutable_root := unsafe { &dom.Element(root) }
		mutable_root.set_attribute_value('style', 'font-family:serif;font-size:20px;line-height:normal;padding:8px')
		mut mutable_subject := unsafe { &dom.Element(subject) }
		mutable_subject.set_attribute_value('id', 'pseudo-host')
		mutable_subject.set_attribute_value('style', 'font-family:serif;font-size:20px;width:120px')
		shadow := mutable_subject.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
		mut shadow_child := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
		shadow_child.set_attribute_value('style', 'font-family:FontInputFixture,sans-serif;font-size:20px;width:100px')
		mut shadow_node := unsafe { &dom.Node(shadow) }
		shadow_node.append_child(shadow_child.as_node()) or { panic(err) }
		add_document_author_style_sheet(document, '#pseudo-host::before{content:"x";font-family:FontInputFixture,sans-serif;font-size:20px;width:10px}')
		document.update_style()
		_ = root
		_ = resolve_computed_values_for_document(font_input_style(subject, .before), document)
		_ = resolve_computed_values_for_document(font_input_style(shadow_child, none), document)
		prior_pseudo := font_input_style(subject, .before)
		prior_shadow := font_input_style(shadow_child, none)
		font_input_install_real_face(document)
		assert subject.has_pending_font_input_update()
		assert shadow_child.has_pending_font_input_update()
		assert !unrelated.has_pending_font_input_update()
		document.update_style()
		assert voidptr(font_input_style(subject, .before)) == voidptr(prior_pseudo)
		assert voidptr(font_input_style(shadow_child, none)) == voidptr(prior_shadow)
		font_input_assert_full_cascade_oracle(subject, .before)
		font_input_assert_full_cascade_oracle(shadow_child, none)
	}
}

fn test_font_length_dependency_tracking_is_independent_of_viewport_tracking() {
	mut did_resolve_font := false
	mut context := LengthResolutionContext.default()
	context.set_did_resolve_font_relative_length(&did_resolve_font)
	_ = Length.new(2, .em).to_px(context)
	assert did_resolve_font
	mut computation := ComputationContext{}
	computation.reset_viewport_metric_dependency_tracking()
	_ = Length.new(2, .ch).to_px(computation.length_resolution_context)
	assert computation.did_resolve_font_relative_length
	assert !computation.depends_on_viewport_metrics()
	computation.reset_viewport_metric_dependency_tracking()
	assert !computation.did_resolve_font_relative_length
}

fn test_font_input_guard_keeps_running_transitions_on_the_full_cascade_path() {
	$if macos {
		mut document, _, subject, _ := font_input_fixture()
		mut target := unsafe { &dom.Element(subject) }
		target.set_attribute_value('style', 'font-size:20px;width:120px;opacity:0;transition:opacity 1s linear')
		document.update_style()
		target.set_attribute_value('style', 'font-size:20px;width:120px;opacity:1;transition:opacity 1s linear')
		document.update_style()
		before := font_input_style(subject, none)
		assert before.has_animated_properties()
		computer := css_style_computer_for(document)
		assert !computer.can_refresh_font_inputs(dom.AbstractElement.new(subject, none))
		font_input_install_real_face(document)
		document.update_style()
		assert voidptr(font_input_style(subject, none)) != voidptr(before)
		font_input_assert_full_cascade_oracle(subject, none)
	}
}

fn test_font_input_guard_rejects_changed_inherited_values_before_mutating_style() {
	mut document, root, subject, _ := font_input_fixture()
	mut target := unsafe { &dom.Element(subject) }
	target.set_attribute_value('style', 'width:120px;padding:4px')
	document.update_style()
	before := font_input_style(subject, none)
	computer := css_style_computer_for(document)
	assert computer.can_refresh_font_inputs(dom.AbstractElement.new(subject, none))
	mut parent := unsafe { &ComputedProperties(font_input_style(root, none)) }
	parent.set_property(.font_size, parse_css_value(ParsingParams{}, '40px', .font_size) or { panic('font size') }, .no, .no)
	assert !computer.can_refresh_font_inputs(dom.AbstractElement.new(subject, none))
	assert before.font_size() == CSSPixels.new(20)
}

fn test_font_input_fanout_refreshes_other_family_root_relative_lengths() {
	$if macos {
		for text in ['width:2rex', 'width:2rch', 'height:1rlh', 'width:calc(2rch + 3px)'] {
			mut document, _, _, unrelated := font_input_fixture()
			mut target := unsafe { &dom.Element(unrelated) }
			target.set_attribute_value('style', 'font-family:serif;font-size:20px;${text}')
			document.update_style()
			prior := font_input_style(unrelated, none)
			assert !prior.font_input_refresh_safe_
			font_input_install_real_face(document)
			assert unrelated.has_pending_font_input_update()
			document.update_style()
			assert voidptr(font_input_style(unrelated, none)) != voidptr(prior)
			font_input_assert_full_cascade_oracle(unrelated, none)
		}
	}
}

fn test_other_family_deferred_length_context_receives_refreshed_root_metrics() {
	$if macos {
		mut document, root, _, unrelated := font_input_fixture()
		prior := font_input_style(unrelated, none)
		_ = prior.length_resolution_context()
		font_input_install_real_face(document)
		document.update_style()
		current := font_input_style(unrelated, none)
		assert voidptr(current) == voidptr(prior)
		root_metrics := css_style_computer_for(document).root_element_font_metrics
		context := current.length_resolution_context()
		assert context.root_font_metrics.font_size == root_metrics.font_size
		assert context.root_font_metrics.line_height == root_metrics.line_height
		assert Length.new(1, .rlh).to_px(context) == root_metrics.line_height
		assert current.root_line_height_px_ == font_input_style(root, none).line_height().to_double()
		font_input_assert_full_cascade_oracle(unrelated, none)
	}
}
