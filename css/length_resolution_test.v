module css

import dom

fn tracked_length_context(font_depends bool, root_font_depends bool) (LengthResolutionContext, &bool) {
	mut did_resolve_viewport_relative_length := false
	mut context := LengthResolutionContext{
		viewport_rect: CSSPixelRect.new(0, 0, 800, 600)
		font_metrics: LengthFontMetrics.default()
		root_font_metrics: LengthFontMetrics.default()
		font_metrics_depend_on_viewport_metrics: font_depends
		root_font_metrics_depend_on_viewport_metrics: root_font_depends
	}
	context.set_did_resolve_viewport_relative_length(&did_resolve_viewport_relative_length)
	return context, &did_resolve_viewport_relative_length
}

fn test_viewport_lengths_record_metric_dependencies() {
	context, dependency := tracked_length_context(false, false)
	assert Length.new(10, .vw).to_px(context).to_double() == 80
	assert *dependency
}

fn test_font_lengths_record_transitive_viewport_dependencies() {
	font_context, font_dependency := tracked_length_context(true, false)
	assert Length.new(2, .em).to_px(font_context).to_double() == 32
	assert *font_dependency

	root_context, root_dependency := tracked_length_context(false, true)
	assert Length.new(2, .rem).to_px(root_context).to_double() == 32
	assert *root_dependency
}

fn test_font_lengths_do_not_record_unrelated_metric_dependencies() {
	root_only_context, font_dependency := tracked_length_context(false, true)
	_ = Length.new(2, .em).to_px(root_only_context)
	assert !*font_dependency

	font_only_context, root_dependency := tracked_length_context(true, false)
	_ = Length.new(2, .rem).to_px(font_only_context)
	assert !*root_dependency
}

fn test_computation_context_resets_dependency_tracking() {
	mut context := ComputationContext{
		length_resolution_context: LengthResolutionContext{
			viewport_rect: CSSPixelRect.new(0, 0, 800, 600)
			font_metrics: LengthFontMetrics.default()
			root_font_metrics: LengthFontMetrics.default()
		}
	}
	context.reset_viewport_metric_dependency_tracking()
	assert context.length_resolution_context.viewport_metric_dependency_flag() != none
	assert !context.depends_on_viewport_metrics()
	_ = Length.new(25, .vh).to_px(context.length_resolution_context)
	assert context.depends_on_viewport_metrics()

	context.reset_viewport_metric_dependency_tracking()
	assert !context.depends_on_viewport_metrics()
}

fn test_style_computation_records_viewport_and_font_metric_dependencies() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 500, 300})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	root.set_attribute_value('style', 'font-size: 10vw')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'font-size: 2em; width: 20vh')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(document)
	root_style := computer.compute_style(dom.AbstractElement.new(root, none))
	root.set_computed_properties(none, computed_properties_to_dom(root_style))
	assert root_style.depends_on_viewport_metrics()
	assert root_style.font_metrics_depend_on_viewport_metrics()

	child_style := computer.compute_style(dom.AbstractElement.new(child, none))
	assert child_style.depends_on_viewport_metrics()
	assert child_style.font_metrics_depend_on_viewport_metrics()
	assert child_style.root_font_metrics_depend_on_viewport_metrics_
	assert child_style.font_size().to_double() == 100
	assert child_style.length_percentage_to_px(.width, 0) or { -1 } == 60
}

fn test_iframe_root_font_size_uses_its_document_viewport() {
	// An iframe's style computer can exist before layout assigns the child
	// document its viewport. Root font properties must therefore obtain the
	// current viewport from that document, rather than a cached/top-level one.
	mut child_document := dom.Document.create(dom.URL{value: 'about:srcdoc'})
	computer := StyleComputer.new(child_document)
	child_document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	mut root := child_document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	root.set_attribute_value('style', 'font-size: 10vw')
	mut child_document_node := unsafe { &dom.Node(child_document) }
	child_document_node.append_child(root.as_node()) or { panic('${err}') }

	computed := computer.compute_style(dom.AbstractElement.new(root, none))
	assert computed.font_size().to_double() == 40
}

fn container_length_test_tree(container_style_text string, subject_style_text string, width f64, height f64, has_geometry bool) (&dom.Document, &dom.Element, &dom.Element, LengthResolutionContext) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut container := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	container.set_attribute_value('style', container_style_text)
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	subject.set_attribute_value('style', subject_style_text)
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(container.as_node()) or { panic('${err}') }
	mut container_node := container.as_node()
	container_node.append_child(subject.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(document)
	container_computed := computer.compute_style(dom.AbstractElement.new(container, none))
	container.set_computed_properties(none, computed_properties_to_dom(container_computed))
	container_node.set_layout_node(&dom.LayoutNode{
		dom_node_: container.as_node()
		has_geometry_: has_geometry
		content_width_: width
		content_height_: height
	})
	subject_computed := computer.compute_style(dom.AbstractElement.new(subject, none))
	subject.set_computed_properties(none, computed_properties_to_dom(subject_computed))
	abstract_subject := dom.AbstractElement.new(subject, none)
	return document, container, subject, LengthResolutionContext.for_element(&abstract_subject)
}

fn test_style_computation_resolves_container_relative_lengths() {
	_, _, subject, _ := container_length_test_tree('container-type: size', 'width: 10cqw; height: 20cqh', 400, 250, true)
	dom_computed := subject.el_computed_properties() or { panic('missing subject style') }
	computed := computed_properties_from_dom(dom_computed) or { panic('missing CSS style handle') }
	assert computed.length_percentage_to_px(.width, 0) or { -1 } == 40
	assert computed.length_percentage_to_px(.height, 0) or { -1 } == 50
}

fn test_container_relative_units_parse_classify_and_serialize() {
	for name in ['cqb', 'cqh', 'cqi', 'cqmax', 'cqmin', 'cqw'] {
		unit := string_to_length_unit(name) or { panic('missing ${name}') }
		assert length_unit_name(unit) == name
		assert is_container_relative_length_unit(unit)
		assert is_relative_length_unit(unit)
		assert Length.new(12.5, unit).serialize(.normal) == '12.5${name}'
	}
}

fn test_container_relative_units_resolve_physical_and_logical_axes() {
	_, container, subject, context := container_length_test_tree('container-type: size', 'writing-mode: vertical-rl', 400, 250, true)
	assert Length.new(10, .cqw).to_px(context).to_double() == 40
	assert Length.new(10, .cqh).to_px(context).to_double() == 25
	assert Length.new(10, .cqi).to_px(context).to_double() == 25
	assert Length.new(10, .cqb).to_px(context).to_double() == 40
	assert Length.new(10, .cqmin).to_px(context).to_double() == 25
	assert Length.new(10, .cqmax).to_px(context).to_double() == 40
	assert subject.style_depends_on_size_container_query()
	assert container.is_size_query_container()
	cache := context.query_container_cache or { panic('missing query-container cache') }
	assert cache.width_was_computed
	assert cache.height_was_computed
	assert voidptr(cache.width_container or { panic('missing width container') }) == voidptr(container)
	assert voidptr(cache.height_container or { panic('missing height container') }) == voidptr(container)
}

fn test_inline_size_container_eligibility_follows_its_writing_mode() {
	_, horizontal, _, horizontal_context := container_length_test_tree('container-type: inline-size', '', 400, 250, true)
	assert query_container_is_eligible_for_axis(horizontal, .width)
	assert !query_container_is_eligible_for_axis(horizontal, .height)
	assert Length.new(10, .cqw).to_px(horizontal_context).to_double() == 40
	assert Length.new(10, .cqh).to_px(horizontal_context).to_double() == 60

	_, vertical, _, vertical_context := container_length_test_tree('container-type: inline-size; writing-mode: vertical-rl', '', 400, 250, true)
	assert !query_container_is_eligible_for_axis(vertical, .width)
	assert query_container_is_eligible_for_axis(vertical, .height)
	assert Length.new(10, .cqw).to_px(vertical_context).to_double() == 80
	assert Length.new(10, .cqh).to_px(vertical_context).to_double() == 25
}

fn test_container_units_without_a_subject_use_the_viewport_and_record_dependency() {
	mut dependency := false
	mut context := LengthResolutionContext{
		viewport_rect: CSSPixelRect.new(0, 0, 800, 600)
		font_metrics: LengthFontMetrics.default()
		root_font_metrics: LengthFontMetrics.default()
	}
	context.set_did_resolve_viewport_relative_length(&dependency)
	assert Length.new(10, .cqw).to_px(context).to_double() == 80
	assert Length.new(10, .cqh).to_px(context).to_double() == 60
	assert dependency
}

fn test_container_units_queue_post_layout_evaluation_without_committed_geometry() {
	document, container, _, context := container_length_test_tree('container-type: size', '', 400, 250, false)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.is_running_update_layout_ = true
	assert Length.new(10, .cqw).to_px(context).to_double() == 0
	assert document.needs_container_query_evaluation_after_layout(container)
}
