module css

import dom

fn cssom_no_box_fixture(parent_style string, target_style string) (&dom.Document, &dom.Element, &dom.Element, &CSSStyleProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut parent := document.create_element_ns(dom.namespace_html_uri, 'section') or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	parent.set_attribute_value('style', parent_style)
	target.set_attribute_value('style', target_style)
	target.set_attribute_value('class', 'target')
	mut docnode := unsafe { &dom.Node(document) }
	docnode.append_child(root.as_node()) or { panic(err) }
	mut rootnode := root.as_node()
	rootnode.append_child(parent.as_node()) or { panic(err) }
	mut parentnode := parent.as_node()
	parentnode.append_child(target.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	// These cache tests deliberately start with a completed record, including
	// when the ordinary rendering update deferred this hidden descendant.
	_ = up_to_date_computed_properties_for_element(target)
	return document, parent, target, CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target,
		none))
}

fn cssom_no_box_value(declaration &CSSStyleProperties, id PropertyID) &dom.StyleValue {
	return (declaration.get_direct_property(PropertyNameAndID.from_id(id)) or {
		panic('missing ${id}')
	}).value
}

fn test_cssom_hidden_and_contents_read_completed_records_and_stay_live() {
	for display in ['none', 'contents'] {
		mut document, parent, mut target, declaration := cssom_no_box_fixture('color:red;font-size:20px',
			'display:${display};width:50%')
		defer { document.finalize() }
		assert target.el_layout_node() == none
		assert !document.element_needs_style_update(target)
		before := computed_properties_for_element(target) or { panic('record') }
		display_value := cssom_no_box_value(declaration, .display)
		assert voidptr(display_value) == voidptr(before.property(.display, .yes) or {
			panic('display')
		})
		assert display_value.css_text == display
		assert declaration.get_property_value('font-size') == '20px'
		assert declaration.get_property_value('width') == '50%'
		add_document_author_style_sheet(document, '.changed .target {font-size:31px;color:blue}')
		document.needs_full_style_update = true
		document.update_style()
		mut mutable_parent := unsafe { &dom.Element(parent) }
		mutable_parent.set_attribute_value('class', 'changed')
		assert document.element_needs_style_update(target)
		assert declaration.get_property_value('font-size') == '31px'
		assert declaration.get_property_value('color') == 'rgb(0, 0, 255)'
		target.set_attribute_value('style', 'display:${display};font-size:43px;width:25%')
		assert declaration.get_property_value('font-size') == '43px'
		assert declaration.get_property_value('width') == '25%'
		assert display_value.css_text == display
	}
}

fn test_cssom_hidden_descendant_reads_dirty_inherited_ancestor_style() {
	mut document, mut parent, target, declaration := cssom_no_box_fixture('display:none;font-size:20px;color:red',
		'font-size:inherit')
	defer { document.finalize() }
	original := cssom_no_box_value(declaration, .font_size)
	assert original.css_text == '20px'
	parent.set_attribute_value('style', 'display:none;font-size:37px;color:blue')
	assert document.element_needs_style_update(target)
	assert declaration.get_property_value('font-size') == '37px'
	assert declaration.get_property_value('color') == 'rgb(0, 0, 255)'
	assert original.css_text == '20px'
	assert !document.element_needs_style_update(target)
}

fn test_cssom_unboxed_missing_or_untyped_record_keeps_seeded_fallback() {
	mut document, mut parent, mut target, declaration :=
		cssom_no_box_fixture('display:none;font-size:20px', '')
	defer { document.finalize() }
	parent.set_attribute_value('class', 'outer')
	target.set_attribute_value('class', 'target inner')
	add_document_author_style_sheet(document, '.outer .inner {font-size:39px}')
	document.update_style()
	target.set_computed_properties(none, none)
	assert !document.element_needs_style_update(target)
	assert declaration.get_property_value('font-size') == '39px'
	target.set_computed_properties(none, &dom.CSSComputedProperties_{})
	assert declaration.get_property_value('font-size') == '39px'
}

fn test_cssom_disconnected_and_contextless_elements_do_not_expose_retained_style() {
	mut document, parent, target, declaration := cssom_no_box_fixture('display:none;font-size:20px',
		'font-size:inherit')
	defer { document.finalize() }
	assert declaration.get_property_value('font-size') == '20px'
	mut parentnode := parent.as_node()
	parentnode.remove_child(target.as_node()) or { panic(err) }
	assert !target.is_connected()
	assert declaration.get_property_value('font-size') == ''
	mut contextless := dom.Document.create(dom.url_about_blank())
	defer { contextless.finalize() }
	mut element := contextless.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut docnode := unsafe { &dom.Node(contextless) }
	docnode.append_child(element.as_node()) or { panic(err) }
	mut owner := dom.AbstractElement.new(element, none)
	owner.set_computed_properties(computed_properties_to_dom(computed_properties_with_initial_values()))
	assert CSSStyleProperties.create_resolved_style(owner).get_property_value('display') == ''
}

fn test_cssom_synthetic_pseudo_ignores_retained_record_without_refresh() {
	mut document, _, target, _ := cssom_no_box_fixture('display:none', '')
	defer { document.finalize() }
	add_document_author_style_sheet(document, '.target::selection {color:rgb(12,34,56)}')
	document.update_style()
	mut owner := dom.AbstractElement.new(target, .selection)
	mut stale := computed_properties_with_initial_values()
	stale.set_property(.color, parse_css_value(ParsingParams{}, 'blue', .color) or {
		panic('color')
	}, .no, .no)
	owner.set_computed_properties(computed_properties_to_dom(stale))
	assert owner.layout_node() == none
	assert !document.element_needs_style_update(target)
	declaration := CSSStyleProperties.create_resolved_style(owner)
	assert declaration.get_property_value('color') == 'rgb(12, 34, 56)'
	assert (computed_properties_from_dom(owner.computed_properties() or { panic('bridge') }) or {
		panic('record')
	}).property(.color, .yes)?.css_text == 'blue'
}

@[heap]
struct CSSOMNoBoxRedirtyState {
	target &dom.Element
mut:
	calls     int
	was_dirty bool
}

fn cssom_no_box_redirty_after_style(target voidptr, _ &dom.Document) {
	mut state := unsafe { &CSSOMNoBoxRedirtyState(target) }
	state.calls++
	if state.calls != 1 { return }
	mut element := unsafe { &dom.Element(state.target) }
	element.set_attribute_value('style', 'display:none;font-size:47px')
	state.was_dirty = element.document().element_needs_style_update(element)
}

fn test_cssom_postflush_redirty_uses_fresh_fallback_instead_of_stale_record() {
	mut document, _, mut target, declaration := cssom_no_box_fixture('font-size:20px',
		'display:none;font-size:21px')
	defer { document.finalize() }
	state := &CSSOMNoBoxRedirtyState{
		target: target
	}
	document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{
		target:           state
		style_did_update: cssom_no_box_redirty_after_style
	})
	target.set_attribute_value('style', 'display:none;font-size:33px')
	assert declaration.get_property_value('font-size') == '47px'
	assert state.calls == 1
	assert state.was_dirty
	retained := computed_properties_for_element(target) or { panic('record') }
	assert retained.property(.font_size, .yes)?.css_text == '33px'
}

fn test_cssom_unboxed_animation_flush_reads_current_animated_value() {
	mut document, _, target, declaration := cssom_no_box_fixture('', 'display:contents;opacity:1')
	defer { document.finalize() }
	mut computer := css_style_computer_for(document)
	owner := dom.AbstractElement.new(target, none)
	low := parse_css_value(ParsingParams{}, '0.2', .opacity) or { panic('low') }
	high := parse_css_value(ParsingParams{}, '0.8', .opacity) or { panic('high') }
	mut effect := KeyframeEffect.create()
	effect.set_target(owner)
	effect.set_specified_iteration_duration(100)
	effect.set_timing_function(EasingFunction.linear())
	effect.set_default_easing(EasingFunction.linear())
	effect.set_fill_mode(.both)
	effect.set_key_frame_set(&KeyFrameSet{
		keyframes_by_key: {
			0:      ResolvedKeyFrame{
				properties: {
					PropertyID.opacity: low
				}
			}
			100000: ResolvedKeyFrame{
				properties: {
					PropertyID.opacity: high
				}
			}
		}
	})
	mut animation := CSSAnimation.create()
	animation.set_animation_name('cssom-no-box')
	animation.set_owning_element(owner)
	animation.set_effect(effect)
	animation.set_timeline(computer.document_timeline_)
	animation.play() or { panic(err) }
	computer.css_animation_storage_.set(owner, 'cssom-no-box', animation)
	computer.set_animation_time_ms(50)
	assert document.element_needs_style_update(target)
	assert declaration.get_property_value('opacity') == '0.5'
	computer.set_animation_time_ms(100)
	assert declaration.get_property_value('opacity') == '0.8'
	assert target.el_layout_node() == none
	assert (computed_properties_for_element(target) or { panic('record') }).property(.opacity, .no)?.css_text == '1'
}

fn test_cssom_hidden_font_load_refreshes_retained_relative_lengths() {
	$if macos {
		mut document, _, target, declaration := cssom_no_box_fixture('display:none',
			'font-family:CSSOMNoBoxFont,monospace;font-size:20px;width:2ch')
		defer { document.finalize() }
		before := declaration.get_property_value('width')
		computer := css_style_computer_for(document).font_computer()
		mut face := FontFaceObject.construct_impl_for_font_computer(computer, 'CSSOMNoBoxFont',
			FontFaceSource.from_string('url("cssom-font.ttf")'), FontFaceDescriptors{})
		typeface := platform_load_font_from_url_boundary('file:///System/Library/Fonts/Supplemental/Arial.ttf',
			'CSSOMNoBoxFont')
		assert typeface != unsafe { nil }
		mut set := FontFaceSet.create_for_font_computer(computer)
		set.add(face) or { panic(err) }
		assert face.begin_url_load()
		face.finish_loading_from_typeface(typeface)
		assert document.element_needs_style_update(target)
		after := declaration.get_property_value('width')
		assert before != after
		mut retained := computed_properties_for_element(target) or { panic('record') }
		selected := retained.first_available_computed_font(computer)
		assert selected.typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		assert !document.element_needs_style_update(target)
	}
}

fn test_cssom_unboxed_slot_reassignment_refreshes_flat_tree_inheritance() {
	mut document, mut host, mut target, declaration := cssom_no_box_fixture('font-size:20px',
		'display:contents;font-size:inherit')
	defer { document.finalize() }
	target.set_attribute_value('slot', 'first')
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut first := document.create_element_ns(dom.namespace_html_uri, 'slot') or { panic(err) }
	first.set_attribute_value('name', 'first')
	first.set_attribute_value('style', 'font-size:28px')
	mut second := document.create_element_ns(dom.namespace_html_uri, 'slot') or { panic(err) }
	second.set_attribute_value('name', 'second')
	second.set_attribute_value('style', 'font-size:44px')
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(first.as_node()) or { panic(err) }
	shadow_node.append_child(second.as_node()) or { panic(err) }
	assert declaration.get_property_value('font-size') == '28px'
	assert target.as_node().assigned_slot_internal() != none
	target.set_attribute_value('slot', 'second')
	assert document.element_needs_style_update(target)
	assert declaration.get_property_value('font-size') == '44px'
	assert !document.element_needs_style_update(target)
}

fn test_cssom_saved_unboxed_declaration_follows_adoption_into_another_document() {
	mut source, _, target, declaration := cssom_no_box_fixture('display:none;font-size:20px',
		'font-size:inherit')
	defer { source.finalize() }
	assert declaration.get_property_value('font-size') == '20px'
	mut destination := dom.Document.create(dom.url_about_blank())
	defer { destination.finalize() }
	destination.set_browsing_context(&dom.BrowsingContext{ active_document_: destination })
	mut root := destination.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	root.set_attribute_value('style', 'display:none;font-size:48px')
	mut docnode := unsafe { &dom.Node(destination) }
	docnode.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(destination)
	destination.adopt_node(target.as_node())
	assert declaration.get_property_value('font-size') == ''
	mut rootnode := root.as_node()
	rootnode.append_child(target.as_node()) or { panic(err) }
	assert declaration.get_property_value('font-size') == '48px'
	assert voidptr(target.document()) == voidptr(destination)
	assert !destination.element_needs_style_update(target)
}
