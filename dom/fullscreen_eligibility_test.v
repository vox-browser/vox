module dom

const fullscreen_eligibility_mathml_namespace = 'http://www.w3.org/1998/Math/MathML'

fn test_mathml_math_is_a_supported_fullscreen_element_type() {
	document := Document.create(url_about_blank())
	math := document.create_element_ns(fullscreen_eligibility_mathml_namespace, 'math')!
	mrow := document.create_element_ns(fullscreen_eligibility_mathml_namespace, 'mrow')!

	// Both elements are detached, so the supported math element reaches the
	// fullscreen-ready check while any other MathML element is rejected first.
	assert math.is_element_allowed_to_enter_fullscreen(.web_driver) == .element_ready_check_failed
	assert mrow.is_element_allowed_to_enter_fullscreen(.web_driver) == .unsupported_element
}

fn test_fullscreen_bindings_require_transient_activation_but_webdriver_does_not() {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	document_node.append_child(element.as_node())!
	document.set_browsing_context(&BrowsingContext{
		active_document_: document
	})
	mut navigable := &Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	document.window = &Window{
		associated_document_: document
	}

	assert element.is_element_allowed_to_enter_fullscreen(.bindings) == .no_transient_user_activation
	assert element.is_element_allowed_to_enter_fullscreen(.web_driver) == .false_

	mut window := document.window
	window.set_last_activation_timestamp(current_high_resolution_time(window))
	assert element.is_element_allowed_to_enter_fullscreen(.bindings) == .false_
}
