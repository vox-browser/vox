module layout

import dom
import css

// The real Layout::Node base: tree structure (parent/children/siblings), DOM back-pointer, and flags.
fn test_layout_node_tree() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	mut root := Node.new(doc, el.as_node())
	mut child1 := Node.new(doc, none) // anonymous box (no DOM node)
	child1.anonymous_ = true
	mut child2 := Node.new(doc, none)

	root.append_child(child1)
	root.append_child(child2)

	assert root.child_count() == 2
	assert root.has_children()
	assert !child1.has_children()

	c1_parent := child1.parent() or { panic('child1 has no parent') }
	assert layout_nodes_same(c1_parent, root)

	assert layout_nodes_same(root.first_child() or { panic('no first child') }, child1)
	assert layout_nodes_same(root.last_child() or { panic('no last child') }, child2)

	assert layout_nodes_same(child1.next_sibling() or { panic('child1 has no next sibling') }, child2)
	if _ := child2.next_sibling() {
		panic('child2 should have no next sibling')
	}
	assert layout_nodes_same(child2.previous_sibling() or { panic('child2 has no prev sibling') }, child1)
	if _ := child1.previous_sibling() {
		panic('child1 should have no previous sibling')
	}

	dn := root.dom_node() or { panic('root has no dom node') }
	if _ := dn.as_element() {
	} else {
		panic('root dom node is not an element')
	}
	if _ := child1.dom_node() {
		panic('anonymous child should have no dom node')
	}

	assert child1.is_anonymous()
	assert !root.is_anonymous()
	el.set_attribute_value('id', 'root')
	el.set_attribute_value('class', 'one two')
	assert root.debug_description() == 'Node<div>#root.one.two'
	assert child1.debug_description() == 'Node(anonymous)'
}

fn test_root_element_requires_non_anonymous_html_html_element() {
	doc := dom.Document.create(dom.url_about_blank())
	html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut html_node := Node.new(doc, html.as_node())
	assert html_node.is_root_element()

	mut anonymous_html_node := Node.new(doc, html.as_node())
	anonymous_html_node.anonymous_ = true
	assert !anonymous_html_node.is_root_element()

	xml_html := doc.create_element_ns('urn:example', 'html') or { panic('${err}') }
	xml_html_node := Node.new(doc, xml_html.as_node())
	assert !xml_html_node.is_root_element()

	div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div_node := Node.new(doc, div.as_node())
	assert !div_node.is_root_element()
}

fn test_math_auto_text_transform_includes_ladybird_greek_mappings() {
	input := 'AazıȷΑΡϴΣΩ∇αςω∂ϵϑϰϕϱϖ!'
	expected := [
		rune(0x1d434),
		rune(0x1d44e),
		rune(0x1d467),
		rune(0x1d6a4),
		rune(0x1d6a5),
		rune(0x1d6e2),
		rune(0x1d6f2),
		rune(0x1d6f3),
		rune(0x1d6f4),
		rune(0x1d6fa),
		rune(0x1d6fb),
		rune(0x1d6fc),
		rune(0x1d70d),
		rune(0x1d714),
		rune(0x1d715),
		rune(0x1d716),
		rune(0x1d717),
		rune(0x1d718),
		rune(0x1d719),
		rune(0x1d71a),
		rune(0x1d71b),
		`!`,
	].string()
	assert apply_math_auto_text_transform(input) == expected
}

// NodeWithStyle embeds Node (so it participates in the tree) and holds the computed style; a &Node in the
// tree can be cast back to &NodeWithStyle to read it.
fn test_node_with_style() {
	doc := dom.Document.create(dom.url_about_blank())
	root_style := css.ComputedProperties.new()
	child_style := css.ComputedProperties.new()

	mut root := NodeWithStyle.new(doc, none, root_style)
	mut child := NodeWithStyle.new(doc, none, child_style)

	root_cv := root.computed_values()
	assert voidptr(root_cv) == voidptr(root_style)
	assert root.has_style()

	root.append_child(unsafe { &Node(child) })
	assert root.child_count() == 1
	first := root.first_child() or { panic('no first child') }
	first_styled := first.as_node_with_style() or { panic('child is not a NodeWithStyle') }
	first_cv := first_styled.computed_values()
	assert voidptr(first_cv) == voidptr(child_style)

	bare := Node.new(doc, none)
	if _ := bare.as_node_with_style() {
		panic('a styleless Node should not cast to NodeWithStyle')
	}
}

fn test_node_with_style_resolves_computed_values_once_per_style_application() {
	document := dom.Document.create(dom.url_about_blank())
	mut computed := css.ComputedProperties.new()
	computed.set_property_without_modifying_flags(.width, &dom.StyleValue{
		css_text: '10px'
	})
	mut node := NodeWithStyle.new(document, none, computed)
	assert node.computed_values().size_value(.width).length().absolute_length_to_px().to_double() == 10

	// ComputedValues is a resolved layout snapshot. Mutating the source property
	// graph does not affect it until NodeWithStyle::apply_style() runs again.
	computed.set_property_without_modifying_flags(.width, &dom.StyleValue{
		css_text: '99px'
	})
	assert node.computed_values().size_value(.width).length().absolute_length_to_px().to_double() == 10

	node.apply_style(computed)
	assert node.computed_values().size_value(.width).length().absolute_length_to_px().to_double() == 99

	inherited := node.computed_values().clone_inherited_values()
	assert inherited.font_size() == node.computed_values().font_size()
	assert inherited.width().is_auto()
}

fn test_node_has_css_transform_includes_individual_transform_properties() {
	document := dom.Document.create(dom.url_about_blank())
	mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	assert !node.has_css_transform()

	mut values := unsafe { &css.MutableComputedValues(node.computed_values()) }
	values.set_translate(css.TransformationData{
		property_id: .translate
	})
	assert node.has_css_transform()
}

fn test_first_available_font_uses_computed_font_cascade() {
	document := dom.Document.create(dom.url_about_blank())
	mut computed := css.ComputedProperties.new()
	computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'serif'
	})
	computed.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '20px'
	})
	computed.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{
		css_text: '700'
	})
	node := NodeWithStyle.new(document, none, computed)
	font := unsafe { &Node(node) }.first_available_font()
	assert font.point_size == 20
	assert font.weight == 700

	// A retained line-box fragment can outlive the style mutation that clears
	// ComputedProperties' cache. C++ keeps the cascade in immutable
	// ComputedValues; the V boundary rematerializes the same cascade on demand.
	mut retained_values := unsafe { &css.ComputedProperties(node.computed_values()) }
	retained_values.clear_computed_font_list_cache()
	rematerialized_list := unsafe { &Node(node) }.font_list()
	assert rematerialized_list.fonts.len > 0
	rematerialized := unsafe { &Node(node) }.first_available_font()
	assert rematerialized.family == font.family
	assert rematerialized.point_size == 20
	assert rematerialized.weight == 700
}

fn test_apply_style_propagates_to_anonymous_wrappers_and_continuations() {
	document := dom.Document.create(dom.url_about_blank())
	mut initial := css.ComputedProperties.new()
	initial.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '11px'
	})
	mut updated := css.ComputedProperties.new()
	updated.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '23px'
	})
	mut parent := NodeWithStyle.new(document, none, initial)
	anonymous_style := initial.clone_for_anonymous_with_display(css.Display.from_short(.block))
	mut anonymous_child := NodeWithStyle.new(document, none, anonymous_style)
	anonymous_child.anonymous_ = true
	parent.append_child(unsafe { &Node(anonymous_child) })

	parent.apply_style(updated)
	assert anonymous_child.computed_values().font_size().to_double() == 23
	assert anonymous_child.computed_values().display() == css.Display.from_short(.block)

	continuation_initial := node_test_computed_user_select('all')
	continuation_updated := node_test_computed_user_select('none')
	mut original := InlineNode.new(document, none, continuation_initial)
	mut continuation := InlineNode.new(document, none, continuation_initial)
	continuation.continuation_of_node_ = unsafe { &NodeWithStyleAndBoxModelMetrics(original) }
	continuation.apply_style(continuation_updated)
	assert original.computed_values().user_select() == .none_
}

fn test_apply_style_refreshes_an_existing_table_wrapper() {
	document := dom.Document.create(dom.url_about_blank())
	base := css.ComputedProperties.new()
	initial_table_style := base.clone_for_anonymous_with_display(css.Display.from_short(.table))
	mut table := BlockContainer.new(document, none, initial_table_style)
	mut initial_style_for_transfer := unsafe { &css.ComputedProperties(table.computed_values()) }
	wrapper_style := initial_style_for_transfer.take_properties_for_table_wrapper()
	mut wrapper := TableWrapper.new(document, none, wrapper_style)
	wrapper.append_child(unsafe { &Node(table) })

	mut updated_table_style := base.clone_for_anonymous_with_display(css.Display.from_short(.table))
	updated_table_style.set_property_without_modifying_flags(.position, &dom.StyleValue{
		css_text: 'absolute'
	})
	table.apply_style(updated_table_style)
	assert wrapper.computed_values().position() == .absolute
	assert table.computed_values().position() == .static_
}

fn test_should_create_inline_continuation_matches_upstream_guards() {
	document := dom.Document.create(dom.url_about_blank())
	base_style := css.ComputedProperties.new()
	inline_style := base_style.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
	block_style := base_style.clone_for_anonymous_with_display(css.Display.from_short(.block))
	contents_style := base_style.clone_for_anonymous_with_display(css.Display.from_short(.contents))
	table_cell_style :=
		base_style.clone_for_anonymous_with_display(css.Display.from_internal(.table_cell))

	mut inline_parent := InlineNode.new(document, none, inline_style)
	block_child := BlockContainer.new(document, none, block_style)
	inline_parent.append_child(unsafe { &Node(block_child) })
	block_metrics := unsafe { &Node(block_child) }.as_node_with_style_and_box_model_metrics() or {
		panic('block child has no box metrics')
	}
	assert block_metrics.should_create_inline_continuation()

	mut inline_parent_for_inline := InlineNode.new(document, none, inline_style)
	inline_child := InlineNode.new(document, none, inline_style)
	inline_parent_for_inline.append_child(unsafe { &Node(inline_child) })
	assert !inline_child.should_create_inline_continuation()

	mut inline_parent_for_contents := InlineNode.new(document, none, inline_style)
	contents_child := InlineNode.new(document, none, contents_style)
	inline_parent_for_contents.append_child(unsafe { &Node(contents_child) })
	assert !contents_child.should_create_inline_continuation()

	mut inline_parent_for_table := InlineNode.new(document, none, inline_style)
	table_child := BlockContainer.new(document, none, table_cell_style)
	inline_parent_for_table.append_child(unsafe { &Node(table_child) })
	table_metrics := unsafe { &Node(table_child) }.as_node_with_style_and_box_model_metrics() or {
		panic('table child has no box metrics')
	}
	assert !table_metrics.should_create_inline_continuation()

	mut absolute_style :=
		base_style.clone_for_anonymous_with_display(css.Display.from_short(.block))
	absolute_style.set_property_without_modifying_flags(.position, &dom.StyleValue{
		css_text: 'absolute'
	})
	mut inline_parent_for_abspos := InlineNode.new(document, none, inline_style)
	abspos_child := BlockContainer.new(document, none, absolute_style)
	inline_parent_for_abspos.append_child(unsafe { &Node(abspos_child) })
	abspos_metrics := unsafe { &Node(abspos_child) }.as_node_with_style_and_box_model_metrics() or {
		panic('absolutely positioned child has no box metrics')
	}
	assert !abspos_metrics.should_create_inline_continuation()

	svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	mut inline_parent_for_svg := InlineNode.new(document, none, inline_style)
	top_level_svg := SVGSVGBox.new(document, svg_element, block_style)
	inline_parent_for_svg.append_child(unsafe { &Node(top_level_svg) })
	top_level_svg_metrics := unsafe { &Node(top_level_svg) }.as_node_with_style_and_box_model_metrics() or {
		panic('SVG root has no box metrics')
	}
	assert top_level_svg_metrics.should_create_inline_continuation()

	g_element := document.create_element_ns('http://www.w3.org/2000/svg', 'g')!
	mut svg_parent := SVGBox.new(document, g_element, inline_style)
	nested_svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	nested_svg := SVGSVGBox.new(document, nested_svg_element, block_style)
	svg_parent.append_child(unsafe { &Node(nested_svg) })
	nested_svg_metrics := unsafe { &Node(nested_svg) }.as_node_with_style_and_box_model_metrics() or {
		panic('nested SVG root has no box metrics')
	}
	assert !nested_svg_metrics.should_create_inline_continuation()
}

// Box / BlockContainer embed the Node->NodeWithStyle chain; the type-discriminant flags let a tree &Node
// be identified and down-cast to the right subclass.
fn test_box_hierarchy() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()

	mut root := BlockContainer.new(doc, none, style)
	mut inner_box := Box.new(doc, none, style)

	// A BlockContainer is a Box is a NodeWithStyle is a Node.
	root_as_node := unsafe { &Node(root) }
	assert root_as_node.is_box()
	assert root_as_node.is_block_container()
	assert root_as_node.has_style()

	// A plain Box is a box but not a block container.
	inner_as_node := unsafe { &Node(inner_box) }
	assert inner_as_node.is_box()
	assert !inner_as_node.is_block_container()

	// Tree + down-casts: append the box under the block container, then recover the subclasses.
	root.append_child(inner_as_node)
	assert root.child_count() == 1
	first := root.first_child() or { panic('no first child') }
	recovered_box := first.as_box() or { panic('child is not a Box') }
	assert voidptr(recovered_box.computed_values()) == voidptr(style)
	if _ := first.as_block_container() {
		panic('a plain Box should not cast to BlockContainer')
	}

	mut recovered_bc := root_as_node.as_block_container() or {
		panic('root is not a BlockContainer')
	}
	recovered_bc.add_contained_abspos_child(inner_as_node)
	assert recovered_bc.contained_abspos_children().len == 1
}

fn test_containing_blocks_follow_positioning_rules() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	body.set_attribute_value('style', 'position: relative')
	mut absolute := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	absolute.set_attribute_value('style', 'position: absolute')
	mut fixed := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	fixed.set_attribute_value('style', 'position: fixed')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html.as_node()) or { panic('${err}') }
	mut html_node := html.as_node()
	html_node.append_child(body.as_node()) or { panic('${err}') }
	mut body_node := body.as_node()
	body_node.append_child(absolute.as_node()) or { panic('${err}') }
	body_node.append_child(fixed.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	html_box := root.first_child() or { panic('no html box') }
	body_box := html_box.first_child() or { panic('no body box') }
	abs_box := body_box.children()[0]
	fixed_box := body_box.children()[1]
	abs_containing_block := abs_box.containing_block() or {
		panic('absolute box has no containing block')
	}
	assert voidptr(abs_containing_block) == voidptr(body_box)
	fixed_containing_block := fixed_box.containing_block() or {
		panic('fixed box has no containing block')
	}
	assert voidptr(fixed_containing_block) == voidptr(root)
}

fn node_test_computed_user_select(value string) &css.ComputedProperties {
	mut computed := css.ComputedProperties.new()
	computed.set_property_without_modifying_flags(.user_select, &dom.StyleValue{
		css_text: value
	})
	return computed
}

fn test_user_select_used_value_matches_upstream_resolution() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	child_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut parent := NodeWithStyle.new(document, parent_element.as_node(), node_test_computed_user_select('all'))
	child := NodeWithStyle.new(document, child_element.as_node(), node_test_computed_user_select('auto'))
	parent.append_child(unsafe { &Node(child) })
	assert unsafe { &Node(child) }.user_select_used_value() == .all

	mut pseudo := NodeWithStyle.new(document, none, node_test_computed_user_select('auto'))
	pseudo.set_generated_for(.before, parent_element)
	assert unsafe { &Node(pseudo) }.user_select_used_value() == .none_

	mut editing_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	editing_host.set_attribute_value('contenteditable', 'true')
	editing_node := NodeWithStyle.new(document, editing_host.as_node(), node_test_computed_user_select('none'))
	assert unsafe { &Node(editing_node) }.user_select_used_value() == .contain

	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input_node := NodeWithStyle.new(document, input.as_node(), node_test_computed_user_select('none'))
	assert unsafe { &Node(input_node) }.user_select_used_value() == .contain
	input.set_attribute_value('readonly', '')
	assert unsafe { &Node(input_node) }.user_select_used_value() == .none_
}

fn test_set_needs_layout_update_propagates_and_clears_intrinsic_caches() {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut root := BlockContainer.new(document, none, style)
	mut child := BlockContainer.new(document, none, style)
	mut anonymous := Box.new(document, none, style)
	mut anonymous_node := unsafe { &Node(anonymous) }
	anonymous_node.anonymous_ = true
	child.append_child(unsafe { &Node(anonymous) })
	root.append_child(unsafe { &Node(child) })

	root.cached_intrinsic_sizes().min_content_width = CSSPixels.new(10)
	child.cached_intrinsic_sizes().min_content_width = CSSPixels.new(20)
	mut child_node := unsafe { &Node(child) }
	child_node.set_needs_layout_update(true)

	assert child_node.needs_layout_update()
	assert unsafe { &Node(root) }.needs_layout_update()
	assert unsafe { &Node(anonymous) }.needs_layout_update()
	assert root.cached_intrinsic_sizes_ == none
	assert child.cached_intrinsic_sizes_ == none
}
