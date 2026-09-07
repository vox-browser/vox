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
