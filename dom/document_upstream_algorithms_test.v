module dom

fn create_replacement_browsing_context(_ voidptr, _ &NavigationParams, _ &BrowsingContext) &BrowsingContext {
	return &BrowsingContext{
		is_top_level_: true
	}
}

fn consume_svg_relayout_callback(root &SVGSVGBox) {
	mut mutable_root := unsafe { &SVGSVGBox(root) }
	mutable_root.relayout_callback = unsafe { nil }
}

fn test_obtain_navigation_response_browsing_context_keeps_child_context() {
	child := &BrowsingContext{
		is_top_level_: false
	}
	params := &NavigationParams{
		browsing_context: child
		needs_a_browsing_context_group_switch: true
		create_top_level_browsing_context_callback: create_replacement_browsing_context
	}
	assert obtain_a_browsing_context_to_use_for_a_navigation_response(params) == child
}

fn test_obtain_navigation_response_browsing_context_keeps_top_level_without_group_switch() {
	context := &BrowsingContext{
		is_top_level_: true
		virtual_browsing_context_group_id_: 'existing-group'
	}
	params := &NavigationParams{
		browsing_context: context
		would_switch_due_to_report_only: true
	}
	assert obtain_a_browsing_context_to_use_for_a_navigation_response(params) == context
	// The corresponding C++ substep remains a FIXME and does not mutate this.
	assert context.virtual_browsing_context_group_id_ == 'existing-group'
}

fn test_obtain_navigation_response_browsing_context_switches_and_propagates_sandbox_flags() {
	context := &BrowsingContext{
		is_top_level_: true
	}
	params := &NavigationParams{
		browsing_context: context
		needs_a_browsing_context_group_switch: true
		final_sandboxing_flag_bits: 0x24
		opener_policy: OpenerPolicy{
			value: .unsafe_none
		}
		create_top_level_browsing_context_callback: create_replacement_browsing_context
	}
	replacement := obtain_a_browsing_context_to_use_for_a_navigation_response(params)
	assert replacement != context
	assert replacement.popup_sandboxing_flag_bits_ == 0x24
}

fn test_relayout_svg_root_delegates_to_layout_implementation() {
	root := &SVGSVGBox{
		relayout_callback: consume_svg_relayout_callback
	}
	relayout_svg_root(root)
	assert root.relayout_callback == unsafe { nil }
}

fn test_respond_to_base_url_changes_invalidates_document_style() {
	mut document := Document.create(url_about_blank())
	document.set_needs_full_style_update(false)

	document.respond_to_base_url_changes()

	assert document.needs_full_style_update()
}

struct ViewTransitionCallbackObservation {
mut:
	calls int
}

fn test_document_view_transition_runs_callback_and_frame_lifecycle() {
	mut document := Document.create(url_about_blank())
	document.visibility_state = .visible
	observation := &ViewTransitionCallbackObservation{}
	callback := &CallbackType{
		call_no_args: fn [observation] () JSValue {
			mut mutable_observation := unsafe { &ViewTransitionCallbackObservation(observation) }
			mutable_observation.calls++
			return js_undefined()
		}
	}

	transition := document.start_view_transition(callback)
	assert transition.phase() == .pending_capture
	assert document.get_active_view_transition()? == transition

	document.perform_pending_transition_operations()
	assert observation.calls == 1
	assert transition.phase() == .animating
	assert !document.rendering_suppression_for_view_transitions

	document.perform_pending_transition_operations()
	assert transition.phase() == .done
	assert document.get_active_view_transition() == none
}

fn test_document_view_transition_skips_hidden_and_replaced_transitions() {
	mut hidden_document := Document.create(url_about_blank())
	hidden_document.visibility_state = .hidden
	hidden := hidden_document.start_view_transition(none)
	assert hidden.phase() == .done
	assert hidden_document.get_active_view_transition() == none

	mut document := Document.create(url_about_blank())
	document.visibility_state = .visible
	first := document.start_view_transition(none)
	second := document.start_view_transition(none)
	assert first.phase() == .done
	assert second.phase() == .pending_capture
	assert document.get_active_view_transition()? == second
}

fn test_inactive_document_clears_stale_layout_and_paintable_nodes() {
	for should_destroy in [false, true] {
		mut document := Document.create(url_about_blank())
		mut root := document.create_element_ns(namespace_html_uri, 'html') or { panic(err) }
		mut child := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
		mut document_node := unsafe { &Node(document) }
		document_node.append_child(root.as_node()) or { panic(err) }
		mut root_node := root.as_node()
		root_node.append_child(child.as_node()) or { panic(err) }

		document_node.set_layout_node(&LayoutNode{})
		document_node.set_paintable(&Paintable{})
		root_node.set_layout_node(&LayoutNode{})
		root_node.set_paintable(&Paintable{})
		mut child_node := child.as_node()
		child_node.set_layout_node(&LayoutNode{})
		child_node.set_paintable(&Paintable{})
		child.set_pseudo_element_node(int(PseudoElement.before), &LayoutNodeWithStyle_{})

		if should_destroy {
			document.destroy()
		} else {
			document.did_stop_being_active_document_in_navigable()
		}

		assert document_node.layout_node() == none
		assert document_node.paintable() == none
		assert root_node.layout_node() == none
		assert root_node.paintable() == none
		assert child_node.layout_node() == none
		assert child_node.paintable() == none
		assert child.get_pseudo_element_node(int(PseudoElement.before)) == none
		assert document.needs_full_layout_tree_update()
	}
}
