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
