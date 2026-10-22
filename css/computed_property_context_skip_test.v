module css

import dom

fn computation_skip_element(document &dom.Document, name string, style string) &dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, name) or { panic(err) }
	element.set_attribute_value('style', style)
	return element
}

fn computation_skip_append(parent &dom.Element, child &dom.Element) {
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
}

fn computation_skip_install(computer &StyleComputer, mut element dom.AbstractElement) &ComputedProperties {
	computed := computer.compute_style(element)
	element.set_computed_properties(computed_properties_to_dom(computed))
	return computed
}

fn test_context_skip_preserves_inherited_value_identity_and_flags() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	root := computation_skip_element(document, 'html',
		'font-size:20px;line-height:1.5;font-weight:700;font-style:italic;color:blue;visibility:hidden')
	child := computation_skip_element(document, 'div',
		'font-size:inherit;line-height:inherit;font-weight:inherit;font-style:inherit;color:inherit;visibility:inherit;width:2em')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	computation_skip_append(root, child)
	computer := StyleComputer.new(document)
	mut root_abstract := dom.AbstractElement.new(root, none)
	parent_style := computation_skip_install(computer, mut root_abstract)
	mut child_abstract := dom.AbstractElement.new(child, none)
	child_style := computation_skip_install(computer, mut child_abstract)
	for property in [PropertyID.font_size, .line_height, .font_weight, .font_style, .color,
		.visibility] {
		assert !property_requires_computation_with_inherited_value(property)
		assert child_style.is_property_inherited(property)
		assert child_style.property(property, .no)? == parent_style.property(property, .no)?
	}
	assert child_style.font_size().to_double() == 20
	assert child_style.line_height().to_double() == 30
	assert child_style.length_percentage_to_px(.width, 0)? == 40
	assert !child_style.depends_on_viewport_metrics()
	assert !child_style.font_metrics_depend_on_viewport_metrics()
	gc_collect()
	assert child_style.property(.color, .no)?.css_text == 'rgb(0, 0, 255)'
	assert parent_style.property(.color, .no)?.css_text == 'rgb(0, 0, 255)'
}

fn test_context_skip_keeps_computed_font_and_viewport_dependencies_through_inheritance() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	root := computation_skip_element(document, 'html', 'font-size:10vw;line-height:2')
	child := computation_skip_element(document, 'div',
		'font-size:inherit;line-height:inherit;width:2em;margin-left:1rem')
	grandchild := computation_skip_element(document, 'span',
		'font-size:150%;line-height:2em;width:calc(1em + 10px);height:25vh')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	computation_skip_append(root, child)
	computation_skip_append(child, grandchild)
	mut computer := StyleComputer.new(document)
	mut previous_child := ?&ComputedProperties(none)
	mut previous_grandchild := ?&ComputedProperties(none)
	for width in [960, 480] {
		height := width * 2 / 3
		document.set_viewport_rect(dom.Rect{ width: f64(width), height: f64(height) })
		computer.set_viewport_rect(CSSPixelRect.new(0, 0, width, height))
		mut root_abstract := dom.AbstractElement.new(root, none)
		root_style := computation_skip_install(computer, mut root_abstract)
		mut child_abstract := dom.AbstractElement.new(child, none)
		child_style := computation_skip_install(computer, mut child_abstract)
		mut grandchild_abstract := dom.AbstractElement.new(grandchild, none)
		grandchild_style := computation_skip_install(computer, mut grandchild_abstract)
		root_font := f64(width) / 10
		assert root_style.font_size().to_double() == root_font
		assert child_style.font_size().to_double() == root_font
		assert child_style.property(.font_size, .no)? == root_style.property(.font_size, .no)?
		assert child_style.line_height().to_double() == root_font * 2
		assert child_style.length_percentage_to_px(.width, 0)? == root_font * 2
		assert child_style.length_percentage_to_px(.margin_left, 0)? == root_font
		assert grandchild_style.font_size().to_double() == root_font * 1.5
		assert grandchild_style.line_height().to_double() == root_font * 3
		assert grandchild_style.length_percentage_to_px(.width, 0)? == root_font * 1.5 + 10
		assert grandchild_style.length_percentage_to_px(.height, 0)? == f64(height) / 4
		for style in [root_style, child_style, grandchild_style] {
			assert style.depends_on_viewport_metrics()
			assert style.font_metrics_depend_on_viewport_metrics()
			assert style.root_font_metrics_depend_on_viewport_metrics_
		}
		if old_child := previous_child {
			assert old_child.font_size().to_double() == 96
			invalidation := compute_required_invalidation(old_child, child_style,
				computer.font_computer(), none, child_abstract)
			assert invalidation.needs_relayout()
		}
		if old_grandchild := previous_grandchild {
			assert old_grandchild.font_size().to_double() == 144
			invalidation := compute_required_invalidation(old_grandchild, grandchild_style,
				computer.font_computer(), none, grandchild_abstract)
			assert invalidation.needs_relayout()
		}
		previous_child = child_style
		previous_grandchild = grandchild_style
		gc_collect()
	}
}

fn test_context_skip_drops_old_viewport_dependency_after_fixed_value_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	root := computation_skip_element(document, 'html', 'font-size:20px;line-height:1.5;color:green')
	mut child := computation_skip_element(document, 'div',
		'width:10vw;height:20vh;display:block;color:inherit')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	computation_skip_append(root, child)
	mut computer := StyleComputer.new(document)
	mut root_abstract := dom.AbstractElement.new(root, none)
	_ = computation_skip_install(computer, mut root_abstract)
	mut child_abstract := dom.AbstractElement.new(child, none)
	relative := computation_skip_install(computer, mut child_abstract)
	assert relative.depends_on_viewport_metrics()
	assert relative.length_percentage_to_px(.width, 0)? == 80
	assert relative.length_percentage_to_px(.height, 0)? == 120
	child.set_attribute_value('style', 'width:40px;height:30px;display:block;color:inherit')
	fixed := computation_skip_install(computer, mut child_abstract)
	assert !fixed.depends_on_viewport_metrics()
	assert !fixed.font_metrics_depend_on_viewport_metrics()
	assert fixed.is_property_inherited(.color)
	assert fixed.length_percentage_to_px(.width, 0)? == 40
	assert fixed.length_percentage_to_px(.height, 0)? == 30
	assert compute_required_invalidation(relative, fixed, computer.font_computer(), none,
		child_abstract).needs_relayout()
	document.set_viewport_rect(dom.Rect{ width: 400, height: 300 })
	computer.set_viewport_rect(CSSPixelRect.new(0, 0, 400, 300))
	resized := computation_skip_install(computer, mut child_abstract)
	assert !resized.depends_on_viewport_metrics()
	assert resized.length_percentage_to_px(.width, 0)? == 40
	assert resized.length_percentage_to_px(.height, 0)? == 30
	assert !compute_required_invalidation(fixed, resized, computer.font_computer(), none,
		child_abstract).needs_relayout()
	assert relative.length_percentage_to_px(.width, 0)? == 80
}
