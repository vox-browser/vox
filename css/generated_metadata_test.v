module css

import dom
import math

fn dark_page_preference_for_test(_ voidptr) string {
	return 'dark'
}

fn test_logical_alias_metadata_covers_generated_properties() {
	assert property_is_logical_alias(.margin_inline_start)
	assert property_is_logical_alias(.border_block_end_color)
	assert property_is_logical_alias(.border_start_end_radius)
	assert property_is_logical_alias(.overflow_block)
	assert property_is_logical_alias(.inline_size)
	assert !property_is_logical_alias(.margin_left)
	assert !property_is_logical_alias(.width)
}

fn test_logical_edges_map_in_horizontal_writing_mode() {
	ltr := LogicalAliasMappingContext{
		writing_mode: .horizontal_tb
		direction: .ltr
	}
	rtl := LogicalAliasMappingContext{
		writing_mode: .horizontal_tb
		direction: .rtl
	}
	assert map_logical_alias_to_physical_property(.margin_block_start, ltr) == .margin_top
	assert map_logical_alias_to_physical_property(.margin_block_end, ltr) == .margin_bottom
	assert map_logical_alias_to_physical_property(.margin_inline_start, ltr) == .margin_left
	assert map_logical_alias_to_physical_property(.margin_inline_end, ltr) == .margin_right
	assert map_logical_alias_to_physical_property(.margin_inline_start, rtl) == .margin_right
	assert map_logical_alias_to_physical_property(.margin_inline_end, rtl) == .margin_left
	assert map_logical_alias_to_physical_property(.block_size, ltr) == .height
	assert map_logical_alias_to_physical_property(.inline_size, ltr) == .width
}

fn test_logical_edges_map_in_vertical_and_sideways_writing_modes() {
	vertical_rl := LogicalAliasMappingContext{
		writing_mode: .vertical_rl
		direction: .ltr
	}
	vertical_lr_rtl := LogicalAliasMappingContext{
		writing_mode: .vertical_lr
		direction: .rtl
	}
	sideways_lr := LogicalAliasMappingContext{
		writing_mode: .sideways_lr
		direction: .ltr
	}
	assert map_logical_alias_to_physical_property(.padding_block_start, vertical_rl) == .padding_right
	assert map_logical_alias_to_physical_property(.padding_block_end, vertical_rl) == .padding_left
	assert map_logical_alias_to_physical_property(.padding_inline_start, vertical_rl) == .padding_top
	assert map_logical_alias_to_physical_property(.padding_inline_end, vertical_rl) == .padding_bottom
	assert map_logical_alias_to_physical_property(.inset_block_start, vertical_lr_rtl) == .left
	assert map_logical_alias_to_physical_property(.inset_inline_start, vertical_lr_rtl) == .bottom
	assert map_logical_alias_to_physical_property(.inset_inline_start, sideways_lr) == .bottom
	assert map_logical_alias_to_physical_property(.overflow_block, vertical_rl) == .overflow_x
	assert map_logical_alias_to_physical_property(.max_inline_size, vertical_rl) == .max_height
}

fn test_logical_corner_mapping() {
	horizontal_ltr := LogicalAliasMappingContext{}
	vertical_rl_rtl := LogicalAliasMappingContext{
		writing_mode: .vertical_rl
		direction: .rtl
	}
	assert map_logical_alias_to_physical_property(.border_start_start_radius, horizontal_ltr) == .border_top_left_radius
	assert map_logical_alias_to_physical_property(.border_end_end_radius, horizontal_ltr) == .border_bottom_right_radius
	assert map_logical_alias_to_physical_property(.corner_start_start_shape, vertical_rl_rtl) == .corner_bottom_right_shape
	assert map_logical_alias_to_physical_property(.corner_end_end_shape, vertical_rl_rtl) == .corner_top_left_shape
}

fn test_pseudo_element_property_whitelists() {
	assert pseudo_element_supports_property(.first_line, .font_size)
	assert pseudo_element_supports_property(.first_line, .background_color)
	assert pseudo_element_supports_property(.first_line, .line_height)
	assert !pseudo_element_supports_property(.first_line, .display)
	assert pseudo_element_supports_property(.first_letter, .margin_left)
	assert pseudo_element_supports_property(.first_letter, .border_top_width)
	assert !pseudo_element_supports_property(.placeholder, .margin_left)
	assert pseudo_element_supports_property(.selection, .color)
	assert pseudo_element_supports_property(.selection, .text_decoration_line)
	assert !pseudo_element_supports_property(.selection, .font_size)
	assert pseudo_element_supports_property(.before, .display)
	assert int(PseudoElement.after) == int(dom.PseudoElement.after)
	assert int(PseudoElement.placeholder) == int(dom.PseudoElement.placeholder)
	assert int(PseudoElement.details_content) == int(dom.PseudoElement.details_content)
	assert pseudo_element_from_string('slider-track') == .slider_track
	assert pseudo_element_from_string('-webkit-slider-thumb') == .slider_thumb
	assert !is_has_allowed_pseudo_element(.slotted)
	assert is_pseudo_element_root(.view_transition)
}

fn test_generated_property_computation_dependency_order() {
	order := computed_interpolation_property_computation_order()
	assert order.index(PropertyID.math_depth) < order.index(PropertyID.font_size)
	assert order.index(PropertyID.font_size) < order.index(PropertyID.line_height)
	assert order.index(PropertyID.background_image) < order.index(PropertyID.background_position_x)
	assert order.len == computed_interpolation_longhand_property_ids().len
}

fn test_generated_shorthand_relationship_metadata_matches_upstream_order() {
	assert generated_expanded_longhands_for_shorthand(.margin) == [
		PropertyID.margin_top,
		.margin_right,
		.margin_bottom,
		.margin_left,
	]
	assert generated_shorthands_for_longhand(.margin_top) == [PropertyID.all, .margin]
	assert generated_shorthands_for_longhand(.border_top_width) == [PropertyID.all, .border,
		.border_width, .border_top]
	assert generated_shorthands_for_longhand(.grid_column_start) == [PropertyID.all, .grid_area,
		.grid_column]
	assert PropertyID.direction !in generated_expanded_longhands_for_shorthand(.all)
	assert PropertyID.unicode_bidi !in generated_expanded_longhands_for_shorthand(.all)
	assert PropertyID.vector_effect in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.vector_effect) == [PropertyID.all]
}

fn test_computed_font_size_and_line_height_use_parent_metrics() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'font-size: 20px')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'font-size: 150%; line-height: 2em')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	assert parent_computed.raw_cascaded_font_size()?.css_text == '20px'
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))

	assert parent_computed.font_size().to_double() == 20.0
	assert child_computed.font_size().to_double() == 30.0
	assert child_computed.line_height().to_double() == 60.0
	font_size := child_computed.property(.font_size, .no) or { panic('font-size missing') }
	line_height := child_computed.property(.line_height, .no) or { panic('line-height missing') }
	assert font_size.css_text == '30px'
	assert line_height.css_text == '60px'
}

fn test_logical_alias_context_inherits_parent_writing_mode_and_direction() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'writing-mode: vertical-lr; direction: rtl')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_abstract := dom.AbstractElement.new(child, none)
	context := s.compute_logical_alias_mapping_context(child_abstract, .normal, MatchingRuleSet{
		author_rules: [LayerMatchingRules{}]
	})
	assert context.writing_mode == .vertical_lr
	assert context.direction == .rtl
}

fn test_create_document_style_uses_viewport_and_block_display() {
	doc := dom.Document.create(dom.url_about_blank())
	s := StyleComputer.new(doc)
	style := s.create_document_style()
	assert style.display() == Display.from_short(.block)
	width := style.property(.width, .no) or { panic('width missing') }
	height := style.property(.height, .no) or { panic('height missing') }
	assert width.css_text == '800px'
	assert height.css_text == '600px'
}

fn test_root_and_out_of_flow_elements_are_blockified() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'display: inline')
	mut absolute_child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	absolute_child.set_attribute_value('style', 'display: inline-block; position: absolute; float: left')
	mut root_node := root.as_node()
	root_node.append_child(absolute_child.as_node()) or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut root_abstract := dom.AbstractElement.new(root, none)
	root_computed := s.compute_style(root_abstract)
	root_abstract.set_computed_properties(computed_properties_to_dom(root_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(absolute_child, none))

	assert root_computed.display_before_box_type_transformation() == Display.from_short(.inline_)
	assert root_computed.display() == Display.from_short(.block)
	assert child_computed.display_before_box_type_transformation() == Display.from_short(.inline_block)
	assert child_computed.display() == Display.from_short(.block)
	assert child_computed.float_() == .none_
}

fn test_document_element_pseudo_element_is_not_blockified_as_the_root() {
	mut doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, 'html::first-letter { font-size: 2em; }')
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	root.set_attribute_value('style', 'font-size: 32px')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node()) or { panic(err) }

	s := StyleComputer.new(doc)
	mut root_abstract := dom.AbstractElement.new(root, none)
	root_computed := s.compute_style(root_abstract)
	root_abstract.set_computed_properties(computed_properties_to_dom(root_computed))
	first_letter := s.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(root, .first_letter)) or { panic('html::first-letter style was not generated') }

	assert first_letter.display_before_box_type_transformation() == Display.from_short(.inline_)
	assert first_letter.display() == Display.from_short(.inline_)
	assert first_letter.font_size().to_double() == 64
}

fn test_flex_container_blockifies_inline_child() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'display: flex')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'display: inline')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))
	assert child_computed.display_before_box_type_transformation() == Display.from_short(.inline_)
	assert child_computed.display() == Display.from_short(.block)
}

fn test_full_style_pipeline_resolves_inherited_custom_properties_and_shorthands() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', '--tone: rgb(10, 20, 30); --gap: 7px')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'color: var(--tone); margin: var(--gap)')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))

	color := child_computed.property(.color, .no) or { panic('color missing') }
	margin_top := child_computed.property(.margin_top, .no) or { panic('margin-top missing') }
	margin_right := child_computed.property(.margin_right, .no) or { panic('margin-right missing') }
	assert color.css_text == 'rgb(10, 20, 30)'
	assert margin_top.css_text == '7px'
	assert margin_right.css_text == '7px'
}

fn test_custom_property_important_wins_in_author_stylesheet() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '.target { --tone: red !important; } .target { --tone: blue; color: var(--tone); }')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('class', 'target')
	computed := StyleComputer.new(doc).compute_style(dom.AbstractElement.new(element, none))
	color := computed.property(.color, .no) or { panic('color missing') }
	assert color.css_text == 'rgb(255, 0, 0)'
}

fn test_custom_property_data_is_shared_with_descendants_without_own_values() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', '--tone: red')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_style := computer.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_style))
	child_abstract := dom.AbstractElement.new(child, none)
	_ = computer.compute_style(child_abstract)
	parent_data := parent_abstract.custom_property_data() or { panic('parent data missing') }
	child_data := child_abstract.custom_property_data() or { panic('child data missing') }
	assert parent_data == child_data
	assert (child_data.get('--tone') or { panic('--tone missing') }).css_text == 'red'
}

fn test_custom_property_data_is_shared_when_the_same_rule_matches_parent_and_child() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '.shared { --tone: var(--base, red); }')
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('class', 'shared')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('class', 'shared')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_style := computer.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_style))
	child_abstract := dom.AbstractElement.new(child, none)
	_ = computer.compute_style(child_abstract)
	parent_data := parent_abstract.custom_property_data() or { panic('parent data missing') }
	child_data := child_abstract.custom_property_data() or { panic('child data missing') }
	assert parent_data == child_data
	value := child_abstract.get_custom_property('--tone') or { panic('custom property missing') }
	assert value.css_value_handle != unsafe { nil }
	retained := dom_style_value_from_custom_property_bridge(value) or {
		panic('retained custom property value missing')
	}
	typed := typed_style_value_logic_from_dom(retained) or { panic('typed value missing') }
	assert typed is UnresolvedStyleValue
}

fn test_custom_property_css_wide_keywords_follow_upstream_computation() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', '--tone: green')
	mut inherited := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	inherited.set_attribute_value('style', '--tone: inherit; color: var(--tone)')
	mut initial := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	initial.set_attribute_value('style', '--tone: initial; color: var(--tone, blue)')
	mut parent_node := parent.as_node()
	parent_node.append_child(inherited.as_node()) or { panic('${err}') }
	parent_node.append_child(initial.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_style := computer.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_style))
	inherited_style := computer.compute_style(dom.AbstractElement.new(inherited, none))
	initial_style := computer.compute_style(dom.AbstractElement.new(initial, none))
	inherited_color := inherited_style.property(.color, .no) or { panic('inherited color missing') }
	initial_color := initial_style.property(.color, .no) or { panic('initial color missing') }
	assert inherited_color.css_text == 'rgb(0, 128, 0)'
	assert initial_color.css_text == 'rgb(0, 0, 255)'
}

fn test_custom_property_change_tracking_compares_resolved_own_values() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', '--tone: red')
	abstract_element := dom.AbstractElement.new(element, none)
	computer := StyleComputer.new(doc)

	mut changed := false
	_ = computer.compute_style_tracking_custom_property_changes(abstract_element, &changed)
	assert changed

	changed = false
	_ = computer.compute_style_tracking_custom_property_changes(abstract_element, &changed)
	assert !changed

	element.set_attribute_value('style', '--tone: blue')
	changed = false
	_ = computer.compute_style_tracking_custom_property_changes(abstract_element, &changed)
	assert changed
}

fn test_inline_style_retains_one_typed_declaration_across_cascades_and_mutations() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'color: red; --tone: 7px')
	abstract_element := dom.AbstractElement.new(element, none)
	first := inline_style_for_abstract_element(abstract_element) or {
		panic('inline style missing')
	}
	second := inline_style_for_abstract_element(abstract_element) or {
		panic('inline style missing on second lookup')
	}
	assert first == second
	custom := first.custom_property('--tone') or { panic('custom declaration missing') }
	assert custom.value.css_value_handle != unsafe { nil }

	element.set_attribute_value('style', 'color: blue; --tone: 9px')
	third := inline_style_for_abstract_element(abstract_element) or {
		panic('inline style missing after mutation')
	}
	assert first == third
	assert third.get_property_value('color') == 'blue'
	assert third.get_property_value('--tone') == '9px'

	mut declaration := third
	declaration.set_property('display', 'flex', '') or { panic('${err}') }
	assert (element.get_attribute('style') or { '' }).contains('display: flex')
	assert inline_style_for_abstract_element(abstract_element) or {
		panic('inline style missing after CSSOM mutation')
	} == first
}

fn test_pseudo_element_style_is_created_only_when_generated() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, 'div::before { content: "hello"; color: red; } div::after { content: none; color: blue; }')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	s := StyleComputer.new(doc)
	before := s.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(element, dom.PseudoElement.before)) or { panic('::before style was not generated') }
	before_color := before.property(.color, .no) or { panic('::before color missing') }
	assert before_color.css_text == 'rgb(255, 0, 0)'
	if _ := s.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(element, dom.PseudoElement.after)) {
		panic('content:none must suppress ::after')
	}

	plain_doc := dom.Document.create(dom.url_about_blank())
	plain := plain_doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	plain_computer := StyleComputer.new(plain_doc)
	if _ := plain_computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(plain, dom.PseudoElement.before)) {
		panic('unmatched ::before must not be generated')
	}
	if _ := plain_computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(plain, dom.PseudoElement.marker)) {
	} else {
		panic('::marker has implicit style')
	}
	for implicit in [dom.PseudoElement.details_content, .file_selector_button, .placeholder] {
		if _ := plain_computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(plain, implicit)) {
		} else {
			panic('${dom.pseudo_element_name(implicit)} must have implicit style')
		}
	}
}

fn test_internal_shadow_tree_element_uses_host_pseudo_element_style() {
	doc := dom.Document.create(dom.url_about_blank())
	mut host := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(host.as_node()) or { panic('${err}') }
	shadow_root := host.attach_a_user_agent_shadow_root(.named)
	mut internal := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(internal.as_node()) or { panic('${err}') }
	internal.set_associated_shadow_host_pseudo_element(int(PseudoElement.placeholder))
	internal.set_attribute_value('style', 'color: blue')
	add_document_author_style_sheet(doc, 'textarea::placeholder { color: red; opacity: .5; }')

	computed := StyleComputer.new(doc).compute_style(dom.AbstractElement.new(internal, none))
	assert (computed.property(.color, .no) or { panic('color missing') }).css_text == 'blue'
	assert (computed.property(.opacity, .no) or { panic('opacity missing') }).css_text == '0.5'
}

fn test_monospace_font_family_recascades_inherited_keyword_font_size() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'font-size: 150%')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'code') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'font-family: monospace')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))

	// The compatibility recascade uses the 13px monospace default as the base,
	// including for percentages that appeared earlier in the ancestor cascade.
	assert child_computed.font_size().to_double() == 19.5
}

fn test_font_relative_units_use_the_inheritance_parent_computation_context() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'font-size: 200%')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'font-size: 2em')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))

	assert parent_computed.font_size().to_double() == 32
	assert child_computed.font_size().to_double() == 64
}

fn test_own_monospace_font_size_does_not_use_the_recascade_placeholder_as_its_em_basis() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'font-family: monospace; font-size: 3em')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))

	assert child_computed.font_size().to_double() == 48
}

fn test_match_parent_text_align_resolves_against_parent_direction() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'direction: rtl; text-align: start')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'text-align: match-parent')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	s := StyleComputer.new(doc)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_computed))
	child_computed := s.compute_style(dom.AbstractElement.new(child, none))
	assert child_computed.text_align() == .right
}

fn test_computed_cssom_reads_regular_and_custom_properties() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', '--tone: red; color: var(--tone)')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(element.as_node()) or { panic('${err}') }
	mut abstract_element := dom.AbstractElement.new(element, none)
	computed := StyleComputer.new(doc).compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))

	resolved := CSSStyleProperties.create_resolved_style(abstract_element)
	assert resolved.get_property_value('color') == 'rgb(255, 0, 0)'
	assert resolved.get_property_value('--tone') == 'red'
	color_property := resolved.get_property(.color) or { panic('computed color missing') }
	assert color_property.value.css_text == 'rgb(255, 0, 0)'

	mut property_map := StylePropertyMapReadOnly.create_computed_style(abstract_element)
	color := property_map.get('color') or { panic('computed style map color missing') }
	custom := property_map.get('--tone') or { panic('computed style map custom value missing') }
	assert color.to_string() or { panic('${err}') } == 'rgb(255, 0, 0)'
	assert custom.to_string() or { panic('${err}') } == 'red'
	assert property_map.has('--tone')
}

fn test_stacking_context_neutral_values_are_detected() {
	assert !is_stacking_context_creating_value_boundary(.opacity, &dom.StyleValue{
		css_text: '1'
	})
	assert is_stacking_context_creating_value_boundary(.opacity, &dom.StyleValue{
		css_text: '0.5'
	})
	assert !is_stacking_context_creating_value_boundary(.transform, &dom.StyleValue{
		css_text: 'none'
	})
	assert is_stacking_context_creating_value_boundary(.transform, &dom.StyleValue{
		css_text: 'translateX(1px)'
	})
	assert !is_stacking_context_creating_value_boundary(.filter, &dom.StyleValue{
		css_text: 'none'
	})
	assert is_stacking_context_creating_value_boundary(.filter, &dom.StyleValue{
		css_text: 'blur(1px)'
	})
}

fn test_computed_values_composite_initial_values_match_upstream() {
	assert InitialValues.border_spacing().absolute_length_to_px().to_double() == 0
	assert InitialValues.background_color() == Color{0, 0, 0, 0}
	assert InitialValues.stroke_width().to_string() == '1px'
	assert InitialValues.inset().top().is_auto()
	assert InitialValues.margin().top().length_percentage().to_string() == '0px'
	assert InitialValues.min_width().is_auto()
	assert InitialValues.max_width().is_none()
	assert InitialValues.column_count() == none
	assert InitialValues.column_gap().is_normal
	assert InitialValues.transition_delay().to_seconds() == 0
	assert InitialValues.outline_width().to_double() == 3
	assert InitialValues.text_underline_offset().to_double() == 2
	assert InitialValues.rx().is_auto()

	position := Position{
		offset_x: LengthPercentage.from_percentage(Percentage.new(25))
		offset_y: LengthPercentage.from_length(Length.make_px(5))
	}
	resolved := position.resolved(LengthResolutionContext{}, CSSPixelRect.new(10, 20, 200, 100))
	assert resolved.x().to_double() == 60
	assert resolved.y().to_double() == 25
}

fn test_computed_property_accessors_return_typed_values() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', [
		'color: rgb(1 2 3)',
		'background-color: currentcolor',
		'border-right-color: currentcolor',
		'text-decoration-color: currentcolor',
		'outline-color: rgb(4 5 6)',
		'caret-color: auto',
		'-webkit-text-fill-color: currentcolor',
		'stop-color: rgb(7 8 9)',
		'flood-color: rgb(10 11 12)',
		'fill: url("#gradient") rgb(20 21 22)',
		'stroke: rgb(30 31 32)',
		'mask-image: url("#mask")',
		'clip-path: circle(50%)',
		'scrollbar-color: rgb(40 41 42) rgb(50 51 52)',
		'list-style-type: upper-roman',
		'counter-reset: section 2',
		'counter-increment: section 3',
		'counter-set: section 4',
		'width: min-content',
		'margin: 1px 2px 3px 4px',
		'border-spacing: 5px 6px',
		'clip: rect(1px 2px 3px 4px)',
		'tab-size: 7px',
		'flex-basis: content',
		'opacity: .4',
		'filter: blur(2px)',
		'backdrop-filter: brightness(50%)',
		'text-underline-position: under right',
		'font-feature-settings: "liga" 0, "kern"',
		'font-language-override: "SRB"',
		'font-variation-settings: "wght" 625',
		'transition-delay: calc(1s + 250ms), 9s',
		'grid-auto-flow: column dense',
		'grid-column-start: span 2',
		'object-position: right 10px bottom 20px',
	].join('; '))
	computed := StyleComputer.new(doc).compute_style(dom.AbstractElement.new(element, none))

	assert computed.size_value(.width).type_ == .min_content
	box := computed.length_box(.margin_left, .margin_top, .margin_right, .margin_bottom, LengthPercentageOrAuto.make_auto())
	assert box.top().length_percentage().to_string() == '1px'
	assert box.right().length_percentage().to_string() == '2px'
	assert box.bottom().length_percentage().to_string() == '3px'
	assert box.left().length_percentage().to_string() == '4px'
	assert computed.border_spacing_horizontal().absolute_length_to_px().to_double() == 5.0
	assert computed.border_spacing_vertical().absolute_length_to_px().to_double() == 6.0
	clip_value := computed.property(.clip, .no) or { panic('clip missing') }
	assert clip_value.css_text == 'rect(1px, 2px, 3px, 4px)'
	assert computed.clip().is_rect()
	assert computed.tab_size().is_length
	assert computed.tab_size().length.absolute_length_to_px().to_double() == 7.0
	assert computed.flex_basis().is_content
	assert computed.opacity() == f32(0.4)
	assert computed.filter().has_filters()
	filters := computed.filter().filters()
	assert filters.len == 1
	assert filters[0] is FilterOperationBlur
	assert (filters[0] as FilterOperationBlur).radius.serialize(.normal) == '2px'
	backdrop_filters := computed.backdrop_filter().filters()
	assert backdrop_filters.len == 1
	assert backdrop_filters[0] is FilterOperationColor
	assert (backdrop_filters[0] as FilterOperationColor).operation == .brightness
	assert (backdrop_filters[0] as FilterOperationColor).amount.serialize(.normal) == '0.5'
	underline := computed.text_underline_position()
	assert underline.horizontal == .under
	assert underline.vertical == .right
	assert computed.font_feature_settings()['liga'] == 0
	assert computed.font_feature_settings()['kern'] == 1
	assert computed.font_variation_settings()['wght'] == 625.0
	values := resolve_computed_values_for_document(computed, doc)
	assert values.font_language_override() or { '' } == 'SRB'
	assert values.font_variation_settings()['wght'] == 625.0
	assert math.abs(values.transition_delay().to_seconds() - 1.25) < 0.001
	assert values.color() == Color{1, 2, 3, 255}
	assert values.caret_color() == Color{1, 2, 3, 255}
	assert values.background_color() == Color{1, 2, 3, 255}
	assert values.border_right().color == Color{1, 2, 3, 255}
	assert values.text_decoration_color() == Color{1, 2, 3, 255}
	assert values.webkit_text_fill_color() == Color{1, 2, 3, 255}
	assert values.outline_color() == Color{4, 5, 6, 255}
	assert values.stop_color() == Color{7, 8, 9, 255}
	assert values.flood_color() == Color{10, 11, 12, 255}
	fill := values.fill() or { panic('missing SVG fill') }
	assert fill.is_url()
	assert fill.fallback_color() or { Color{} } == Color{20, 21, 22, 255}
	stroke := values.stroke() or { panic('missing SVG stroke') }
	assert stroke.is_color()
	assert stroke.as_color() == Color{30, 31, 32, 255}
	mask_image := values.mask_image() or { panic('missing mask image') }
	assert mask_image.url_.url() == '#mask'
	clip_path := values.clip_path() or { panic('missing clip path') }
	assert clip_path.is_basic_shape()
	scrollbar_color := values.computed_scrollbar_color()
	assert !scrollbar_color.auto_
	assert scrollbar_color.thumb == ComputedColor.rgba(40, 41, 42, 255)
	assert scrollbar_color.track == ComputedColor.rgba(50, 51, 52, 255)
	list_style_type := values.computed_list_style_type()
	assert list_style_type.kind == .counter_style
	assert list_style_type.name == 'upper-roman'
	assert (list_style_type.counter_style or { panic('upper-roman did not resolve') }).name() == 'upper-roman'
	assert values.counter_reset().len == 1
	assert values.counter_reset()[0].name == 'section'
	assert values.counter_reset()[0].value or { 0 } == 2
	assert values.counter_increment()[0].value or { 0 } == 3
	assert values.counter_set()[0].value or { 0 } == 4
	assert !computed.grid_auto_flow().row
	assert computed.grid_auto_flow().dense
	assert !computed.grid_column_start().is_auto()
	position := computed.object_position()
	assert position.offset_x.to_string() == 'calc(100% - 10px)'
	assert position.offset_y.to_string() == 'calc(100% - 20px)'
}

fn test_box_shadow_interpolation_uses_typed_shadow_components() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	from := &dom.StyleValue{
		css_text: 'rgb(255, 0, 0) 0px 0px 0px 0px'
	}
	to := &dom.StyleValue{
		css_text: 'rgb(0, 0, 255) 10px 20px 30px 40px inset'
	}
	interpolated := interpolate_box_shadow(element, InterpolationCalculationContext.for_property(.box_shadow), from, to, 0.5, .no) or {
		panic('box-shadow interpolation failed')
	}
	assert interpolated.css_text == 'rgb(128, 0, 128) 5px 10px 15px 20px inset'
	parsed := parse_css_value_logic(.box_shadow, interpolated.css_text) or {
		panic('interpolated box-shadow did not parse')
	}
	assert parsed is StyleValueList
	list := parsed as StyleValueList
	assert list.size() == 1
	assert list.value_at(0, false) is ShadowStyleValue
	shadow := list.value_at(0, false) as ShadowStyleValue
	assert shadow.offset_x().serialize(.normal) == '5px'
	assert shadow.offset_y().serialize(.normal) == '10px'
	assert shadow.blur_radius().serialize(.normal) == '15px'
	assert shadow.spread_distance().serialize(.normal) == '20px'
	assert shadow.placement() == .inner
	shadow_color := shadow.color().to_color(ColorResolutionContext{}) or {
		panic('interpolated shadow color did not resolve')
	}
	assert shadow_color.red() == 128
	assert shadow_color.green() == 0
	assert shadow_color.blue() == 128

	// `none` is a zero-item list and is padded with a transparent zero shadow.
	from_none := &dom.StyleValue{
		css_text: 'none'
	}
	extended := interpolate_box_shadow(element, InterpolationCalculationContext.for_property(.box_shadow), from_none, to, 0.5, .no) or {
		panic('box-shadow list extension failed')
	}
	extended_value := parse_css_value_logic(.box_shadow, extended.css_text) or {
		panic('extended box-shadow did not parse')
	}
	assert extended_value is StyleValueList
	assert (extended_value as StyleValueList).size() == 1
}

fn test_mixed_length_percentage_interpolation_builds_a_calculation() {
	context := InterpolationCalculationContext.for_property(.width)
	interpolated := interpolate_length_percentage(context, LengthPercentage.from_length(Length.make_px(10)), LengthPercentage.from_percentage(Percentage.new(50)), 0.5) or {
		panic('mixed length-percentage interpolation failed')
	}
	assert interpolated.is_calculated()
	resolved := interpolated.resolved(LengthResolutionContext.default(), CSSPixels.nearest_value_for(200))
	assert resolved.absolute_length_to_px().to_double() == 55.0

	from := StyleValue(LengthStyleValue.create(Length.make_px(20)))
	to := StyleValue(PercentageStyleValue.create(Percentage.new(25)))
	mixed := interpolate_style_value(context, from, to, 0.25, .no) or {
		panic('mixed StyleValue interpolation failed')
	}
	assert mixed is CalculatedStyleValue
	assert LengthPercentage.from_style_value_logic(mixed).resolved(LengthResolutionContext.default(), CSSPixels.nearest_value_for(400)).absolute_length_to_px().to_double() == 40.0
}

fn test_additive_composition_uses_typed_css_values() {
	opacity := composite_value(.opacity, &dom.StyleValue{
		css_text: '0.25'
	}, &dom.StyleValue{
		css_text: '0.5'
	}, .add) or { panic('number composition failed') }
	assert opacity.css_text == '0.75'

	width := composite_value(.width, &dom.StyleValue{
		css_text: '10px'
	}, &dom.StyleValue{
		css_text: '20%'
	}, .accumulate) or { panic('mixed composition failed') }
	width_value := parse_css_value_logic(.width, width.css_text) or {
		panic('composited width did not parse')
	}
	assert width_value is CalculatedStyleValue
	assert LengthPercentage.from_style_value_logic(width_value).resolved(LengthResolutionContext.default(), CSSPixels.nearest_value_for(100)).absolute_length_to_px().to_double() == 30.0

	radius := composite_value(.border_top_left_radius, &dom.StyleValue{
		css_text: '1px 2px'
	}, &dom.StyleValue{
		css_text: '3px 4px'
	}, .add) or { panic('border-radius composition failed') }
	assert radius.css_text == '4px 6px'

	filters := composite_value(.filter, &dom.StyleValue{
		css_text: 'blur(1px)'
	}, &dom.StyleValue{
		css_text: 'blur(2px)'
	}, .add) or { panic('filter-list composition failed') }
	assert filters.css_text == 'blur(1px) blur(2px)'
	accumulated_shadow := composite_value(.filter, &dom.StyleValue{
		css_text: 'drop-shadow(1px 2px red)'
	}, &dom.StyleValue{
		css_text: 'drop-shadow(3px 4px blue)'
	}, .accumulate) or { panic('drop-shadow accumulation failed') }
	assert accumulated_shadow.css_text == 'drop-shadow(rgb(255, 0, 255) 4px 6px)'

	grid_tracks := composite_value(.grid_template_columns, &dom.StyleValue{
		css_text: '10px 1fr'
	}, &dom.StyleValue{
		css_text: '20px 2fr'
	}, .add) or { panic('grid-track composition failed') }
	assert grid_tracks.css_text == '30px 3fr'

	assert composite_value(.opacity, &dom.StyleValue{
		css_text: '0.25'
	}, &dom.StyleValue{
		css_text: '0.5'
	}, .replace) == none
}

fn transform_interpolation_test_matrix(value &dom.StyleValue) FloatMatrix4x4 {
	parsed := parse_css_value_logic(.transform, value.css_text) or {
		panic('interpolated transform did not parse')
	}
	if parsed is TransformationStyleValue {
		return parsed.to_matrix(none) or { panic('interpolated transform did not resolve') }
	}
	if parsed is StyleValueList && parsed.size() == 1 {
		item := parsed.value_at(0, false)
		if item is TransformationStyleValue {
			return item.to_matrix(none) or { panic('interpolated transform did not resolve') }
		}
	}
	panic('interpolated value was not a single transform')
}

fn test_transform_interpolation_matches_primitives_and_pads_none() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	context := InterpolationCalculationContext.for_property(.transform)
	interpolated := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'translateX(0px) scaleX(1)'
	}, &dom.StyleValue{
		css_text: 'translate(10px, 20px)'
	}, 0.5, .no) or { panic('transform primitive interpolation failed') }
	assert interpolated.css_text == 'translate(5px, 10px) scale(1, 1)'

	from_none := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'none'
	}, &dom.StyleValue{
		css_text: 'translate(10px, 20px)'
	}, 0.5, .no) or { panic('transform none padding failed') }
	assert from_none.css_text == 'translate(5px, 10px)'

	rotation := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'rotate(0deg)'
	}, &dom.StyleValue{
		css_text: 'rotateZ(90deg)'
	}, 0.5, .no) or { panic('rotation primitive interpolation failed') }
	assert rotation.css_text == 'rotate3d(0, 0, 1, 45deg)'

	mixed_scale := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'scaleX(2)'
	}, &dom.StyleValue{
		css_text: 'scaleZ(3)'
	}, 0.5, .no) or { panic('3D scale primitive interpolation failed') }
	assert mixed_scale.css_text == 'scale3d(1.5, 1, 2)'

	mixed_translate := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'translateY(10px)'
	}, &dom.StyleValue{
		css_text: 'translateZ(30px)'
	}, 0.5, .no) or { panic('3D translate primitive interpolation failed') }
	assert mixed_translate.css_text == 'translate3d(0px, 5px, 15px)'

	axis_rotation := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'rotate3d(1, 0, 0, 30deg)'
	}, &dom.StyleValue{
		css_text: 'rotate3d(0, 1, 0, 60deg)'
	}, 0.5, .no) or { panic('3D rotation interpolation failed') }
	axis_matrix := transform_interpolation_test_matrix(axis_rotation)
	assert math.abs(axis_matrix.m11 - 0.863873) < 1e-6
	assert math.abs(axis_matrix.m21 - 0.070465) < 1e-6
	assert math.abs(axis_matrix.m31 + 0.498757) < 1e-6
	assert math.abs(axis_matrix.m12 - 0.070465) < 1e-6
	assert math.abs(axis_matrix.m22 - 0.963525) < 1e-6
	assert math.abs(axis_matrix.m32 - 0.258176) < 1e-6
	assert math.abs(axis_matrix.m13 - 0.498757) < 1e-6
	assert math.abs(axis_matrix.m23 + 0.258176) < 1e-6
	assert math.abs(axis_matrix.m33 - 0.827397) < 1e-6

	matrix_interpolation := interpolate_transform(element, context, &dom.StyleValue{
		css_text: 'matrix(1, 0, 0, 1, 0, 0)'
	}, &dom.StyleValue{
		css_text: 'matrix(1, 0, 0, 1, 10, 20)'
	}, 0.5, .no) or { panic('matrix interpolation failed') }
	matrix_value := parse_css_value_logic(.transform, matrix_interpolation.css_text) or {
		panic('interpolated matrix did not parse')
	}
	assert matrix_value is StyleValueList
	matrix_list := matrix_value as StyleValueList
	assert matrix_list.size() == 1
	assert matrix_list.value_at(0, false) is TransformationStyleValue
	matrix := (matrix_list.value_at(0, false) as TransformationStyleValue).to_matrix(none) or {
		panic('interpolated matrix did not resolve')
	}
	assert math.abs(matrix.m14 - 5) < 1e-9
	assert math.abs(matrix.m24 - 10) < 1e-9

	grid_tracks := interpolate_property(element, .grid_template_columns, &dom.StyleValue{
		css_text: '10px 1fr'
	}, &dom.StyleValue{
		css_text: '30px 3fr'
	}, 0.5, .no) or { panic('grid-track interpolation failed') }
	assert grid_tracks.css_text == '20px 2fr'
}

fn test_grid_track_interpolation_handles_mixed_values_and_repeats() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	mixed := interpolate_property(element, .grid_template_columns, &dom.StyleValue{
		css_text: '10px 20px 30px'
	}, &dom.StyleValue{
		css_text: '20% 30% 40px'
	}, 0.4, .yes) or { panic('mixed grid-track interpolation failed') }
	assert mixed.css_text == 'calc(8% + 6px) calc(12% + 12px) 34px'

	zero_dimension := interpolate_property(element, .grid_template_columns, &dom.StyleValue{
		css_text: '0px'
	}, &dom.StyleValue{
		css_text: '20%'
	}, 0.5, .yes) or { panic('zero-dimension grid-track interpolation failed') }
	assert zero_dimension.css_text == '10%'

	repeated := interpolate_property(element, .grid_template_columns, &dom.StyleValue{
		css_text: '1fr repeat(2, 2fr auto 30px) 1fr'
	}, &dom.StyleValue{
		css_text: '2fr repeat(2, 3fr 30px 40px) 2fr'
	}, 0.6, .yes) or { panic('repeated grid-track interpolation failed') }
	assert repeated.css_text == '1.6fr repeat(2, 2.6fr 30px 36px) 1.6fr'

	incompatible := interpolate_property(element, .grid_template_columns, &dom.StyleValue{
		css_text: '1fr repeat(2, 2fr 30px) 1fr'
	}, &dom.StyleValue{
		css_text: '2fr repeat(2, 3fr 40px 50px) 2fr'
	}, 0.4, .yes) or { panic('incompatible grid-track interpolation failed') }
	assert incompatible.css_text == '1fr repeat(2, 2fr 30px) 1fr'

	composited := composite_value(.grid_template_columns, &dom.StyleValue{
		css_text: '10px'
	}, &dom.StyleValue{
		css_text: '20%'
	}, .add) or { panic('mixed grid-track composition failed') }
	assert composited.css_text == 'calc(20% + 10px)'
}

fn test_ratio_parser_preserves_number_calculations_until_computed_value_time() {
	value := parse_css_value_logic(.aspect_ratio, 'calc(1 + 1) / calc(2 * 2)') or {
		panic('calculated ratio did not parse')
	}
	assert value is RatioStyleValue
	ratio := value as RatioStyleValue
	assert ratio.numerator() is CalculatedStyleValue
	assert ratio.denominator() is CalculatedStyleValue
	assert value.serialize(.normal) == 'calc(2) / calc(4)'
	assert ratio.absolutized(ComputationContext{}).serialize(.normal) == '2 / 4'
}

fn test_border_and_list_style_shorthand_special_resets() {
	border := parse_css_value_logic(.border, '2px solid red') or {
		panic('border shorthand did not parse')
	}
	assert border is ShorthandStyleValue
	border_shorthand := border as ShorthandStyleValue
	assert border_shorthand.sub_properties().last() == .border_image
	border_image := border_shorthand.longhand(.border_image) or {
		panic('border shorthand did not reset border-image')
	}
	assert border_image is ShorthandStyleValue

	list_style := parse_css_value_logic(.list_style, 'inside none') or {
		panic('list-style shorthand did not parse')
	}
	assert list_style is ShorthandStyleValue
	list_shorthand := list_style as ShorthandStyleValue
	image := list_shorthand.longhand(.list_style_image) or { panic('list-style-image missing') }
	type_ := list_shorthand.longhand(.list_style_type) or { panic('list-style-type missing') }
	assert image.to_keyword() == .none_
	assert type_.to_keyword() == .none_
	assert parse_css_value_logic(.list_style, 'none none none') == none
}

fn test_shape_outside_accepts_images_shape_boxes_and_combined_shapes() {
	image := parse_css_value_logic(.shape_outside, 'url(shape.png)') or {
		panic('shape image did not parse')
	}
	assert image is ImageStyleValue
	shape_box := parse_css_value_logic(.shape_outside, 'margin-box') or {
		panic('shape-box did not parse')
	}
	assert shape_box.to_keyword() == .margin_box
	combined := parse_css_value_logic(.shape_outside, 'circle(20px) border-box') or {
		panic('combined basic-shape and shape-box did not parse')
	}
	assert combined is StyleValueList
	assert (combined as StyleValueList).size() == 2
	assert parse_css_value_logic(.shape_outside, 'margin-box content-box') == none
}

fn test_rule_cache_retains_resolved_keyframes_and_endpoint_markers() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '@keyframes pulse {
		from { opacity: 0; --phase: start; animation-timing-function: linear; animation-composition: add; }
		50% { transform: translateX(10px); }
	}')
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	abstract_element := dom.AbstractElement.new(element, none)
	scope := css_style_scope_for(abstract_element)
	cache := scope.rule_cache_for_cascade_origin(.author, none) or {
		panic('author rule cache missing')
	}
	keyframes := cache.rules_by_animation_keyframes['pulse'] or {
		panic('resolved @keyframes missing from rule cache')
	}
	assert 0 in keyframes.keyframes_by_key
	assert 50 * animation_key_frame_key_scale_factor in keyframes.keyframes_by_key
	assert 100 * animation_key_frame_key_scale_factor in keyframes.keyframes_by_key
	initial := keyframes.keyframes_by_key[0] or { panic('initial keyframe missing') }
	final := keyframes.keyframes_by_key[100 * animation_key_frame_key_scale_factor] or {
		panic('final keyframe missing')
	}
	assert PropertyID.opacity in initial.properties
	assert (initial.custom_properties['--phase'] or {
		panic('initial custom property missing')
	}).css_text == 'start'
	assert initial.use_initial_properties[.transform]
	assert final.use_initial_properties[.opacity]
	assert final.use_initial_properties[.transform]
	assert final.use_initial_custom_properties['--phase']
	assert initial.composite or { panic('keyframe composition missing') } == .add
	assert (initial.easing or { panic('keyframe easing missing') }).to_string() == 'linear'
}

fn test_custom_properties_declared_in_keyframes_are_sampled_and_published() {
	mut doc := dom.Document.create(dom.url_about_blank())
	register_property_for_document(mut doc, PropertyDefinition{
		name: '--angle'
		syntax: '<angle>'
		inherits: false
		initial_value: '0deg'
	}) or { panic('${err}') }
	register_property_for_document(mut doc, PropertyDefinition{
		name: '--size'
		syntax: '<length>'
		inherits: false
		initial_value: '0px'
	}) or { panic('${err}') }
	register_property_for_document(mut doc, PropertyDefinition{
		name: '--reset'
		syntax: '<number>'
		inherits: false
		initial_value: '20'
	}) or { panic('${err}') }
	register_property_for_document(mut doc, PropertyDefinition{
		name: '--guarded'
		syntax: '<number>'
		inherits: false
		initial_value: '0'
	}) or { panic('${err}') }
	register_property_for_document(mut doc, PropertyDefinition{
		name: '--added'
		syntax: '<number>'
		inherits: false
		initial_value: '10'
	}) or { panic('${err}') }
	add_document_author_style_sheet(doc, '@property --angle {
		syntax: "<angle>"; inherits: false; initial-value: 0deg;
	}
	@property --size {
		syntax: "<length>"; inherits: false; initial-value: 0px;
	}
	@property --reset {
		syntax: "<number>"; inherits: false; initial-value: 20;
	}
	@property --guarded {
		syntax: "<number>"; inherits: false; initial-value: 0;
	}
	@keyframes spin {
		from { --angle: 0deg; --plain: aaa; }
		to { --angle: 360deg; --plain: bbb; }
	}
	@keyframes grow { to { --size: 100px; } }
	@keyframes to-initial { from { --reset: 80; } to { --reset: initial; } }
	@keyframes guarded-run { from { --guarded: 0; } to { --guarded: 100; } }
	@keyframes add-values {
		from { --added: 1; animation-composition: add; }
		to { --added: 3; animation-composition: add; }
	}
	.halfway, .implicit, .keyword, .important, .additive {
		animation-duration: 10000ms; animation-timing-function: linear; animation-fill-mode: both;
	}
	.halfway { animation-name: spin; }
	.implicit { --size: 50px; width: var(--size); margin: var(--size); animation-name: grow; }
	.keyword { animation-name: to-initial; }
	.important { --guarded: 10 !important; animation-name: guarded-run; }
	.additive { animation-name: add-values; animation-composition: add; }')

	mut computer := StyleComputer.new(doc)
	for class_name in ['halfway', 'implicit', 'keyword', 'important', 'additive'] {
		computer.set_animation_time_ms(0)
		mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			panic('${err}')
		}
		element.set_attribute_value('class', class_name)
		mut abstract_element := dom.AbstractElement.new(element, none)
		initial := computer.compute_style(abstract_element)
		abstract_element.set_computed_properties(computed_properties_to_dom(initial))
		computer.set_animation_time_ms(5000)
		computed := computer.compute_style(abstract_element)
		abstract_element.set_computed_properties(computed_properties_to_dom(computed))
		data := abstract_element.custom_property_data() or {
			panic('${class_name} custom property data missing')
		}
		if class_name == 'important' {
			assert !data.is_animation_overlay()
		} else {
			assert data.is_animation_overlay()
		}
		match class_name {
			'halfway' {
				assert (data.get('--angle') or { panic('--angle missing') }).css_text == '180deg'
				assert (data.get('--plain') or { panic('--plain missing') }).css_text == 'bbb'
			}
			'implicit' {
				assert (data.get('--size') or { panic('--size missing') }).css_text == '75px'
				assert (computed.property(.width, .no) or { panic('width missing') }).css_text == '75px'
				assert (computed.property(.margin_left, .no) or {
					panic('margin-left missing')
				}).css_text == '75px'
			}
			'keyword' {
				assert (data.get('--reset') or { panic('--reset missing') }).css_text == '50'
			}
			'important' {
				assert (data.get('--guarded') or { panic('--guarded missing') }).css_text == '10'
			}
			'additive' {
				assert (data.get('--added') or { panic('--added missing') }).css_text == '12'
			}
			else {}
		}
	}
}

fn test_inherited_custom_property_change_passes_through_animation_overlay() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	add_document_author_style_sheet(document, '@keyframes animate-y {
		from { --y: 0; } to { --y: 1; }
	}
	#parent { --x: 10px; }
	#middle { animation: animate-y 1s infinite; }
	#child { width: var(--x); }')
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('id', 'parent')
	mut middle := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	middle.set_attribute_value('id', 'middle')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('id', 'child')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic('${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(middle.as_node()) or { panic('${err}') }
	mut middle_node := middle.as_node()
	middle_node.append_child(child.as_node()) or { panic('${err}') }

	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(child, .width) or { '' } == '10px'
	middle_data := dom.AbstractElement.new(middle, none).custom_property_data() or {
		panic('animated middle custom property data missing')
	}
	assert middle_data.is_animation_overlay()

	parent.set_attribute_value('style', '--x: 20px')
	document.update_style()
	assert computed_value_for(child, .width) or { '' } == '20px'
	updated_middle_data := dom.AbstractElement.new(middle, none).custom_property_data() or {
		panic('updated middle custom property data missing')
	}
	assert updated_middle_data.is_animation_overlay()
	assert (updated_middle_data.get('--y') or { panic('--y missing') }).css_text == '0'
}

fn test_animation_refresh_recomputes_standard_property_using_animated_custom_property() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	register_property_for_document(mut document, PropertyDefinition{
		name: '--animated-width'
		syntax: '<length>'
		inherits: false
		initial_value: '0px'
	}) or { panic('${err}') }
	add_document_author_style_sheet(document, '@keyframes grow-width {
		from { --animated-width: 0px; }
		to { --animated-width: 100px; }
	}
	#target {
		width: var(--animated-width);
		animation-name: grow-width;
		animation-duration: 1000ms;
		animation-timing-function: linear;
		animation-fill-mode: none;
	}')
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	target.set_attribute_value('id', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic('${err}') }

	mut computer := css_style_computer_for(document)
	computer.set_animation_time_ms(0)
	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(target, .width) or { '' } == '0px'
	computer.set_animation_time_ms(500)
	document.update_animated_style_if_needed()
	assert computed_value_for(target, .width) or { '' } == '50px'
	computer.set_animation_time_ms(1500)
	document.update_animated_style_if_needed()
	assert computed_value_for(target, .width) or { '' } == '0px'
}

fn test_animated_registered_custom_property_can_reference_another_animation() {
	mut document := dom.Document.create(dom.url_about_blank())
	for definition in [
		PropertyDefinition{
			name: '--static'
			syntax: '<number>'
			inherits: false
			initial_value: '0'
		},
		PropertyDefinition{
			name: '--animated'
			syntax: '<number>'
			inherits: false
			initial_value: '0'
		},
		PropertyDefinition{
			name: '--test'
			syntax: '<number>'
			inherits: false
			initial_value: '0'
		},
	] {
		register_property_for_document(mut document, definition) or { panic('${err}') }
	}
	add_document_author_style_sheet(document, '@keyframes referenced-value {
		from { --animated: 200; } to { --animated: 300; }
	}
	@keyframes dependent-value {
		from { --test: var(--static); } to { --test: var(--animated); }
	}
	.target {
		--static: 100;
		animation-name: referenced-value, dependent-value;
		animation-duration: 1000ms, 1000ms;
		animation-timing-function: linear, linear;
		animation-fill-mode: both, both;
	}')
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('class', 'target')
	mut abstract_element := dom.AbstractElement.new(element, none)
	mut computer := StyleComputer.new(document)
	computer.set_animation_time_ms(0)
	initial := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(initial))
	computer.set_animation_time_ms(250)
	computed := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
	data := abstract_element.custom_property_data() or { panic('animation overlay missing') }
	assert (data.get('--animated') or { panic('--animated missing') }).css_text == '225'
	assert (data.get('--test') or { panic('--test missing') }).css_text == '131.25'
}

fn test_rule_cache_merges_duplicate_keyframe_offsets_in_source_order() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '@keyframes merged {
		0% { opacity: 0.1; animation-timing-function: ease; animation-composition: add; }
		from { transform: translateX(10px); opacity: 0.5; animation-timing-function: linear; animation-composition: accumulate; }
		50% { background-color: green; animation-timing-function: ease-in; animation-composition: add; }
		50% { transform: translateX(20px); }
	}')
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	scope := css_style_scope_for(dom.AbstractElement.new(element, none))
	cache := scope.rule_cache_for_cascade_origin(.author, none) or {
		panic('author rule cache missing')
	}
	keyframes := cache.rules_by_animation_keyframes['merged'] or {
		panic('merged @keyframes missing from rule cache')
	}

	initial := keyframes.keyframes_by_key[0] or { panic('initial keyframe missing') }
	assert (initial.properties[.opacity] or { panic('initial opacity missing') }).css_text == '0.5'
	assert (initial.properties[.transform] or { panic('initial transform missing') }).css_text == 'translateX(10px)'
	assert (initial.easing or { panic('initial easing missing') }).to_string() == 'linear'
	assert initial.composite or { panic('initial composite missing') } == .accumulate

	middle := keyframes.keyframes_by_key[50 * animation_key_frame_key_scale_factor] or {
		panic('middle keyframe missing')
	}
	assert (middle.properties[.background_color] or { panic('middle background missing') }).css_text == 'green'
	assert (middle.properties[.transform] or { panic('middle transform missing') }).css_text == 'translateX(20px)'
	assert (middle.easing or { panic('middle easing missing') }).to_string() == 'ease-in'
	assert middle.composite or { panic('middle composite missing') } == .add
}

fn test_css_animation_definitions_are_stored_and_sampled() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '@keyframes fade {
		from { opacity: 0; }
		to { opacity: 1; }
	}
	.target {
		animation-name: fade;
		animation-duration: 1000ms;
		animation-timing-function: linear;
		animation-fill-mode: both;
	}')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('class', 'target')
	mut computer := StyleComputer.new(doc)
	mut abstract_element := dom.AbstractElement.new(element, none)
	initial := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(initial))
	if _ := computer.css_animation_for(abstract_element, 'fade') {
	} else {
		panic('CSS animation was not retained for the element')
	}

	computer.set_animation_time_ms(500)
	midpoint := computer.compute_style(abstract_element)
	opacity := midpoint.property(.opacity, .yes) or { panic('animated opacity missing') }
	assert opacity.css_text == '0.5'
}

fn test_keyframe_animation_timing_function_resolves_custom_properties_when_sampled() {
	doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, '@keyframes resolved-easing {
		from { opacity: 0; animation-timing-function: var(--keyframe-easing); }
		to { opacity: 1; }
	}
	@keyframes fallback-easing {
		from { opacity: 0; animation-timing-function: var(--missing-easing, linear); }
		to { opacity: 1; }
	}
	.resolved { --keyframe-easing: linear; animation: resolved-easing 1s ease both; }
	.fallback { animation: fallback-easing 1s ease both; }')
	mut resolved_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	resolved_element.set_attribute_value('class', 'resolved')
	mut fallback_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	fallback_element.set_attribute_value('class', 'fallback')
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(resolved_element.as_node()) or { panic('${err}') }
	root_node.append_child(fallback_element.as_node()) or { panic('${err}') }

	mut computer := StyleComputer.new(doc)
	mut resolved_abstract := dom.AbstractElement.new(resolved_element, none)
	resolved_initial := computer.compute_style(resolved_abstract)
	resolved_abstract.set_computed_properties(computed_properties_to_dom(resolved_initial))
	mut fallback_abstract := dom.AbstractElement.new(fallback_element, none)
	fallback_initial := computer.compute_style(fallback_abstract)
	fallback_abstract.set_computed_properties(computed_properties_to_dom(fallback_initial))

	computer.set_animation_time_ms(500)
	resolved_midpoint := computer.compute_style(resolved_abstract)
	fallback_midpoint := computer.compute_style(fallback_abstract)
	assert (resolved_midpoint.property(.opacity, .yes) or {
		panic('resolved opacity missing')
	}).css_text == '0.5'
	assert (fallback_midpoint.property(.opacity, .yes) or {
		panic('fallback opacity missing')
	}).css_text == '0.5'
}

fn test_css_animation_sampling_holds_paused_progress_and_applies_direction_at_boundaries() {
	mut animation := CSSAnimation.create()
	mut effect := KeyframeEffect.create()
	effect.set_specified_iteration_duration(1000)
	effect.set_iteration_count(2)
	effect.set_fill_mode(.both)
	effect.set_playback_direction(.alternate)
	animation.set_effect(effect)
	animation.set_timeline(&AnimationTimeline{})
	animation.play() or { panic('${err}') }

	// An exact iteration boundary is the end of the preceding iteration.
	assert animation.sample_at(1000) or { -1 } == 1.0
	animation.pause() or { panic('${err}') }
	assert animation.sample_at(1500) or { -1 } == 1.0
	assert animation.sample_at(1900) or { -1 } == 1.0

	animation.play() or { panic('${err}') }
	// Resuming at 2000ms preserves the 1000ms current time, then advances.
	assert animation.sample_at(2000) or { -1 } == 1.0
	assert animation.sample_at(2250) or { -1 } == 0.75

	effect.set_playback_direction(.reverse)
	animation.start_time_ = 3000
	assert animation.sample_at(2500) or { -1 } == 1.0
	animation.cancel()
	assert animation.sample_at(3500) == none
}

fn test_layout_node_resolution_context_uses_installed_element_and_root_styles() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'font-size: 10px')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	child.set_attribute_value('style', 'font-size: 20px; line-height: 30px; color: rgb(1, 2, 3); accent-color: rgb(4, 5, 6); color-scheme: dark')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	mut computer := StyleComputer.new(doc)
	recompute_style_for_subtree(mut computer, root.as_node())
	layout_node := &dom.LayoutNode{
		dom_node_: child.as_node()
	}
	length_context := LengthResolutionContext.for_layout_node(layout_node)
	assert length_context.font_metrics.font_size.to_double() == 20.0
	assert length_context.font_metrics.line_height.to_double() == 30.0
	assert length_context.root_font_metrics.font_size.to_double() == 10.0
	assert Length.new(2, .em).to_px(length_context).to_double() == 40.0
	assert Length.new(2, .rem).to_px(length_context).to_double() == 20.0

	color_context := color_resolution_context_for_layout_node(layout_node)
	assert (color_context.color_scheme or { PreferredColorScheme.light }) == .dark
	current_color := color_context.current_color or { panic('current color missing') }
	assert current_color.r == 1 && current_color.g == 2 && current_color.b == 3
	accent_color := color_context.accent_color or { panic('accent color missing') }
	assert accent_color.r == 4 && accent_color.g == 5 && accent_color.b == 6
}

fn test_color_resolution_uses_the_page_preferred_color_scheme() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut page_target := 0
	dom_page := &dom.Page{
		target: unsafe { voidptr(&page_target) }
		preferred_color_scheme_callback: dark_page_preference_for_test
	}
	doc.set_page(dom_page)
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'color-scheme: light dark; color: light-dark(rgb(1 2 3), rgb(4 5 6))')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(element.as_node()) or { panic('${err}') }

	mut computer := StyleComputer.new(doc)
	recompute_style_for_subtree(mut computer, element.as_node())
	layout_node := &dom.LayoutNode{
		dom_node_: element.as_node()
	}
	context := color_resolution_context_for_layout_node(layout_node)
	assert (context.color_scheme or { PreferredColorScheme.light }) == .dark
	color := context.current_color or { panic('current color missing') }
	assert color.r == 4 && color.g == 5 && color.b == 6
}

fn test_unresolved_css_functions_record_dom_style_dependencies() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	abstract_element := dom.AbstractElement.new(element, none)
	for function_name in ['attr', 'if', 'inherit', 'var'] {
		unresolved := UnresolvedStyleValue.create(parse_component_values_for_value_logic('${function_name}(--x)'))
		resolve_unresolved_style_value_for_property(abstract_element, .width, unresolved)
	}
	assert element.style_uses_attr_css_function()
	assert element.style_uses_if_css_function()
	assert element.style_uses_inherit_css_function()
	assert element.style_uses_var_css_function()
	element.reset_style_dependency_flags()
	assert !element.style_uses_attr_css_function()
	assert !element.style_uses_if_css_function()
	assert !element.style_uses_inherit_css_function()
	assert !element.style_uses_var_css_function()
}

fn test_css_transitions_are_retained_and_sampled() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{
		active_document_: doc
	})
	doc.set_navigable(&dom.Navigable{active_document_: doc})
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'opacity: 0; transition-property: opacity; transition-duration: 1000ms; transition-timing-function: linear')
	mut computer := StyleComputer.new(doc)
	computer.set_animation_time_ms(0)
	mut abstract_element := dom.AbstractElement.new(element, none)
	initial := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(initial))

	element.set_attribute_value('style', 'opacity: 1; transition-property: opacity; transition-duration: 1000ms; transition-timing-function: linear')
	started := computer.compute_style(abstract_element)
	assert (started.property(.opacity, .yes) or { panic('starting opacity missing') }).css_text == '0'
	abstract_element.set_computed_properties(computed_properties_to_dom(started))

	computer.set_animation_time_ms(500)
	midpoint := computer.compute_style(abstract_element)
	assert (midpoint.property(.opacity, .yes) or { panic('transition opacity missing') }).css_text == '0.5'
}

fn test_zero_duration_transitions_do_not_allocate_registration_storage() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{
		active_document_: doc
	})
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut computer := StyleComputer.new(doc)
	mut abstract_element := dom.AbstractElement.new(element, none)
	initial := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(initial))

	_ = computer.compute_style(abstract_element)
	key := abstract_element_storage_key(abstract_element)
	assert key !in computer.css_transition_storage_.registered_transition_attributes
}

fn test_shadow_root_author_stylesheet_uses_its_own_css_scope() {
	doc := dom.Document.create(dom.url_about_blank())
	mut host := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic('${err}') }
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	child.set_attribute_value('class', 'inside')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(child.as_node()) or { panic('${err}') }
	add_shadow_root_author_style_sheet(shadow_root, '.inside { color: red; }')

	computer := StyleComputer.new(doc)
	abstract_child := dom.AbstractElement.new(child, none)
	mut attempted_pseudo_class_matches := PseudoClassBitmap{}
	matching_rules := computer.collect_matching_rules(abstract_child, .author, mut attempted_pseudo_class_matches, none)
	assert matching_rules.len == 1
	assert matching_rules[0].shadow_root != none
	assert voidptr(matching_rules[0].shadow_root or { panic('missing rule scope') }) == voidptr(shadow_root)

	computed := computer.compute_style(abstract_child)
	assert (computed.property(.color, .no) or { panic('shadow color missing') }).css_text == 'rgb(255, 0, 0)'
}

fn test_svg_symbol_instance_root_adjusts_display_and_position() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/image.svg' })
	mut svg_root := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		panic('${err}')
	}
	mut symbol := document.create_element_ns('http://www.w3.org/2000/svg', 'symbol') or {
		panic('${err}')
	}
	symbol.set_attribute_value('id', 'icon')
	mut use_element := document.create_element_ns('http://www.w3.org/2000/svg', 'use') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(svg_root.as_node()) or { panic('${err}') }
	mut svg_root_node := svg_root.as_node()
	svg_root_node.append_child(symbol.as_node()) or { panic('${err}') }
	svg_root_node.append_child(use_element.as_node()) or { panic('${err}') }
	use_element.set_attribute_value('href', '#icon')

	shadow_root := use_element.shadow_root() or { panic('use shadow root missing') }
	clone_node := unsafe { &dom.Node(shadow_root) }.first_child() or {
		panic('symbol instance root missing')
	}
	clone := clone_node.as_element() or { panic('symbol instance root is not an element') }
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(clone, none))
	assert computed.display() == Display.from_short(.inline_)
	assert computed.position() == .static_
}

fn test_subtree_style_recompute_installs_pseudos_and_walks_shadow_tree() {
	doc := dom.Document.create(dom.url_about_blank())
	mut host := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(host.as_node()) or { panic('${err}') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic('${err}') }
	child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(child.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, 'div::before { content: "generated"; color: blue; }')
	add_shadow_root_author_style_sheet(shadow_root, 'span { color: red; }')

	mut computer := StyleComputer.new(doc)
	recompute_style_for_subtree(mut computer, host.as_node())
	before := dom.AbstractElement.new(host, dom.PseudoElement.before)
	assert before.computed_properties() != none
	child_style := computed_properties_from_dom(dom.AbstractElement.new(child, none).computed_properties() or {
		panic('shadow child was not styled')
	}) or { panic('shadow child CSS handle missing') }
	assert (child_style.property(.color, .no) or { panic('shadow child color missing') }).css_text == 'rgb(255, 0, 0)'
}

fn test_subtree_style_recompute_filters_pseudos_without_skipping_bucketed_rules() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or { panic('${err}') }
	mut matched := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	matched.set_attribute_value('class', 'generated')
	plain := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(matched.as_node()) or { panic('${err}') }
	root_node.append_child(plain.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, '.generated::before { content: "generated"; color: blue; }')

	mut computer := StyleComputer.new(doc)
	recompute_style_for_subtree(mut computer, root.as_node())
	assert dom.AbstractElement.new(matched, dom.PseudoElement.before).computed_properties() != none
	assert dom.AbstractElement.new(plain, dom.PseudoElement.before).computed_properties() == none
}

fn test_document_user_stylesheet_participates_in_user_cascade() {
	doc := dom.Document.create(dom.url_about_blank())
	set_document_user_style_sheet(doc, '.target { color: green !important; }')
	add_document_author_style_sheet(doc, '.target { color: red !important; }')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('class', 'target')
	computed := StyleComputer.new(doc).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.color, .no) or { panic('user color missing') }).css_text == 'rgb(0, 128, 0)'
}

fn page_user_style_for_test(_ voidptr) ?string {
	return '.target { color: green !important; }'
}

fn test_page_user_stylesheet_crosses_dom_bridge_and_can_be_invalidated() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_page(&dom.Page{
		target: voidptr(doc)
		user_style_callback: page_user_style_for_test
	})
	add_document_author_style_sheet(doc, '.target { color: red !important; }')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('class', 'target')
	computed := StyleComputer.new(doc).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.color, .no) or { panic('page user color missing') }).css_text == 'rgb(0, 128, 0)'

	scope := css_style_scope_for_document(doc)
	assert scope.user_style_sheet != none
	doc.style_scope().invalidate_user_style_sheet()
	assert scope.user_style_sheet == none
	assert !scope.has_valid_rule_cache()
}

fn interpolate_test_property(element &dom.Element, property_id PropertyID, from_text string, to_text string, delta f64) string {
	from_value := parse_css_value_logic(property_id, from_text) or {
		panic('could not parse ${property_id}: ${from_text}')
	}
	to_value := parse_css_value_logic(property_id, to_text) or {
		panic('could not parse ${property_id}: ${to_text}')
	}
	from := dom_style_value_from_value_logic(from_value)
	to := dom_style_value_from_value_logic(to_value)
	return (interpolate_property(element, property_id, from, to, delta, .no) or {
		panic('could not interpolate ${property_id}: ${from_text} -> ${to_text}')
	}).css_text
}

fn test_computed_value_flag_helpers_match_computed_values_contract() {
	assert Containment{}.is_empty()
	assert !Containment{
		paint_containment: true
	}.is_empty()
	assert ContainerType{}.is_empty()
	assert !ContainerType{
		is_inline_size_container: true
	}.is_empty()

	auto := WillChange.make_auto()
	assert auto.is_auto()
	assert !auto.has_contents()
	assert !auto.has_scroll_position()

	will_change := WillChange{
		names: ['contents', 'scroll-position', 'opacity']
	}
	assert !will_change.is_auto()
	assert will_change.has_contents()
	assert will_change.has_scroll_position()
	assert will_change.has_property(.opacity)

	mask_reference := MaskReference.from_url(URL.from_url('#mask'))
	assert mask_reference.url().url() == '#mask'
}

fn test_custom_property_interpolation_matches_css_animation_rules() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	assert interpolate_test_property(element, .color, 'red', 'blue', 0.5) == 'rgb(128, 0, 128)'
	interpolated_color := interpolate_property(element, .color, &dom.StyleValue{
		css_text: 'red'
	}, &dom.StyleValue{
		css_text: 'blue'
	}, 0.5, .no) or { panic('legacy color interpolation failed') }
	interpolated_color_value := style_value_logic_from_dom(.color, interpolated_color) or {
		panic('interpolated color did not round-trip')
	}
	assert interpolated_color_value is RGBColorStyleValue
	assert (interpolated_color_value as RGBColorStyleValue).color_syntax() == .legacy
	assert interpolate_test_property(element, .opacity, '0.2', '0.8', 2) == '1'
	assert interpolate_test_property(element, .width, '10px', '20px', -2) == '0px'
	assert interpolate_test_property(element, .margin_left, '10px', '20px', -2) == '-10px'
	assert interpolate_test_property(element, .column_count, '2', '4', -1) == '1'
	assert interpolate_test_property(element, .scale, 'none', '2 4', 0.5) == '1.5 2.5'
	assert interpolate_test_property(element, .translate, 'none', '20px 40px', 0.5) == '10px 20px'
	assert interpolate_test_property(element, .rotate, 'none', '90deg', 0.5) == '45deg'
	assert interpolate_test_property(element, .font_style, 'normal', 'oblique 20deg', 0.5) == 'oblique 10deg'
	italic_font_style := dom_style_value_from_value_logic(parse_css_value_logic(.font_style, 'italic') or { panic('could not parse italic font style') })
	angled_oblique_font_style := dom_style_value_from_value_logic(parse_css_value_logic(.font_style, 'oblique 20deg') or { panic('could not parse angled oblique font style') })
	assert (interpolate_property(element, .font_style, italic_font_style, angled_oblique_font_style, 0.25, .yes) or {
		panic('could not discretely interpolate italic font style')
	}).css_text == 'italic'
	assert (interpolate_property(element, .font_style, italic_font_style, angled_oblique_font_style, 0.75, .yes) or {
		panic('could not discretely interpolate oblique font style')
	}).css_text == 'oblique 20deg'
	assert interpolate_property(element, .font_style, italic_font_style, angled_oblique_font_style, 0.75, .no) == none
	assert interpolate_test_property(element, .font_variation_settings, '"wght" 100', '"wght" 900', 0.5) == '"wght" 500'
	assert interpolate_test_property(element, .filter, 'none', 'blur(10px)', 0.5) == 'blur(5px)'
	assert interpolate_test_property(element, .filter, 'blur(6px)', 'blur(10px)', -2) == 'blur(0px)'
	assert interpolate_test_property(element, .filter, 'opacity(0.2)', 'opacity(0.8)', 2) == 'opacity(1)'
	assert interpolate_test_property(element, .filter, 'brightness(1)', 'brightness(2)', -2) == 'brightness(0)'
	assert interpolate_test_property(element, .filter, 'drop-shadow(0px 0px red)', 'drop-shadow(10px 20px blue)', 0.5) == 'drop-shadow(rgb(128, 0, 128) 5px 10px)'
}

fn test_stroke_dasharray_interpolation_repeats_patterns_and_handles_none_discretely() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/2000/svg', 'path') or { panic('${err}') }
	assert interpolate_test_property(element, .stroke_dasharray, '10px 20px', '20px 40px 60px',
		0.5) == '15px, 30px, 35px, 20px, 25px, 40px'

	none_value := dom_style_value_from_value_logic(parse_css_value_logic(.stroke_dasharray,
		'none') or { panic('could not parse none stroke dasharray') })
	list_value := dom_style_value_from_value_logic(parse_css_value_logic(.stroke_dasharray,
		'10px 20px') or { panic('could not parse stroke dasharray list') })
	assert interpolate_property(element, .stroke_dasharray, none_value, list_value, 0.25,
		.no) == none
	assert (interpolate_property(element, .stroke_dasharray, none_value, list_value, 0.25,
		.yes) or { panic('could not discretely interpolate stroke dasharray') }).css_text == 'none'
	assert (interpolate_property(element, .stroke_dasharray, none_value, list_value, 0.75,
		.yes) or { panic('could not discretely interpolate stroke dasharray') }).css_text == '10px, 20px'
}

fn test_nested_style_value_interpolation_uses_component_fallback() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	background_from := parse_css_value_logic(.background_size, '10px auto') or {
		panic('could not parse initial background size')
	}
	background_to := parse_css_value_logic(.background_size, '20px 30px') or {
		panic('could not parse final background size')
	}
	assert background_from is StyleValueList
	assert background_to is StyleValueList
	background := interpolate_style_value(InterpolationCalculationContext.for_property(.background_size), (background_from as StyleValueList).value_at(0, false), (background_to as StyleValueList).value_at(0, false), 0.75, .yes) or {
		panic('could not interpolate background-size components')
	}
	assert background.serialize(.normal) == '17.5px 30px'

	border_from := dom_style_value_from_value_logic(parse_css_value_logic(.border_image_slice, '10 20') or { panic('could not parse initial border image slice') })
	border_to := dom_style_value_from_value_logic(parse_css_value_logic(.border_image_slice, '30% 40') or { panic('could not parse final border image slice') })
	border := interpolate_property(element, .border_image_slice, border_from, border_to, 0.75, .yes) or { panic('could not interpolate border image slice components') }
	assert border.css_text == '30% 35'

	feature := composite_value(.font_feature_settings, &dom.StyleValue{
		css_text: '"kern" 0'
	}, &dom.StyleValue{
		css_text: '"kern" 1'
	}, .add) or { panic('could not compose OpenType feature values') }
	assert feature.css_text == '"kern" 1'
}

fn test_color_interpolation_uses_the_elements_color_resolution_context() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	element.set_attribute_value('style', 'color-scheme: dark')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(element.as_node()) or { panic('${err}') }
	mut abstract_element := dom.AbstractElement.new(element, none)
	computed := StyleComputer.new(doc).compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
	layout_node := &dom.LayoutNode{
		dom_node_: element.as_node()
	}
	mut node := element.as_node()
	node.set_layout_node(layout_node)

	assert interpolate_test_property(element, .background_color, 'light-dark(red, green)', 'light-dark(blue, white)', 0) == 'oklab(0.519752 -0.140302 0.107676)'
}

fn test_animation_keyword_resolution_matches_upstream_boundaries() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	zero := dom_style_value_from_value_logic(parse_css_value_logic(.opacity, '0') or {
		panic('could not parse zero opacity')
	})
	guaranteed_invalid := dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	assert (interpolate_property(element, .opacity, guaranteed_invalid, zero, 0.5, .no) or {
		panic('could not interpolate guaranteed-invalid as the initial value')
	}).css_text == '0.5'

	unset := dom_style_value_from_value_logic(parse_css_value_logic(.opacity, 'unset') or {
		panic('could not parse unset opacity')
	})
	assert (interpolate_property(element, .opacity, unset, zero, 0.25, .no) or {
		panic('could not interpolate unset as the initial value')
	}).css_text == '0.75'

	for keyword in ['revert', 'revert-layer'] {
		keyword_value := dom_style_value_from_value_logic(parse_css_value_logic(.opacity, keyword) or {
			panic('could not parse ${keyword} opacity')
		})
		assert (interpolate_property(element, .opacity, keyword_value, zero, 0.25, .yes) or {
			panic('could not discretely interpolate ${keyword}')
		}).css_text == keyword
	}
}

fn test_basic_shape_interpolation_and_composition() {
	doc := dom.Document.create(dom.url_about_blank())
	element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	parsed_circle := parse_css_value_logic(.clip_path, 'circle(10px at 20% 30%)') or {
		panic('circle with position did not parse')
	}
	assert parsed_circle.serialize(.normal) == 'circle(10px at 20% 30%)'
	assert parsed_circle is BasicShapeStyleValue
	parsed_shape := (parsed_circle as BasicShapeStyleValue).basic_shape()
	assert parsed_shape is BasicShapeCircle
	assert (parsed_shape as BasicShapeCircle).position != none
	assert parsed_circle.absolutized(ComputationContext{}).serialize(.normal) == 'circle(10px at 20% 30%)'
	round_tripped_circle := style_value_logic_from_dom(.clip_path, dom_style_value_from_value_logic(parsed_circle)) or { panic('circle did not round-trip') }
	round_tripped_shape := (round_tripped_circle as BasicShapeStyleValue).basic_shape()
	assert (round_tripped_shape as BasicShapeCircle).position != none
	assert interpolate_test_property(element, .object_position, '20% 30%', '40% 50%', 0.5) == '30% 40%'

	assert interpolate_test_property(element, .clip_path, 'circle(10px at 20% 30%)', 'circle(30px at 40% 50%)', 0.5) == 'circle(20px at 30% 40%)'
	assert interpolate_test_property(element, .clip_path, 'circle(10px)', 'circle(30px at 70% 90%)', 0.5) == 'circle(20px at 60% 70%)'
	assert interpolate_test_property(element, .clip_path, 'circle(10px)', 'circle(20px)', -2) == 'circle(0px)'
	assert interpolate_test_property(element, .clip_path, 'ellipse(10px 20px at 10% 20%)', 'ellipse(30px 40px at 30% 60%)', 0.5) == 'ellipse(20px 30px at 20% 40%)'
	assert interpolate_test_property(element, .clip_path, 'polygon(evenodd, 0% 0%, 100% 0%, 100% 100%)', 'polygon(evenodd, 20% 40%, 80% 20%, 60% 80%)', 0.5) == 'polygon(evenodd, 10% 20%, 90% 10%, 80% 90%)'
	mixed := interpolate_test_property(element, .clip_path, 'circle(10px)', 'circle(30%)', 0.5)
	assert mixed == 'circle(calc(15% + 5px))'

	composited_circle := composite_value(.clip_path, &dom.StyleValue{
		css_text: 'circle(10px at 20% 30%)'
	}, &dom.StyleValue{
		css_text: 'circle(5px at 40% 10%)'
	}, .add) or { panic('circle composition failed') }
	assert composited_circle.css_text == 'circle(15px at 60% 40%)'
	composited_ellipse := composite_value(.clip_path, &dom.StyleValue{
		css_text: 'ellipse(10px 20px at 20% 30%)'
	}, &dom.StyleValue{
		css_text: 'ellipse(5px 10px at 40% 10%)'
	}, .add) or { panic('ellipse composition failed') }
	assert composited_ellipse.css_text == 'ellipse(15px 30px at 60% 40%)'
	composited_polygon := composite_value(.clip_path, &dom.StyleValue{
		css_text: 'polygon(0% 0%, 20% 40%, 50% 60%)'
	}, &dom.StyleValue{
		css_text: 'polygon(10% 20%, 30% 40%, 25% 10%)'
	}, .add) or { panic('polygon composition failed') }
	assert composited_polygon.css_text == 'polygon(10% 20%, 50% 80%, 75% 70%)'

	// inset() exercises both basic-shape and four-corner border-radius composition.
	composited_inset := composite_value(.clip_path, &dom.StyleValue{
		css_text: 'inset(1px 2px 3px 4px round 1px 2px 3px 4px / 5px 6px 7px 8px)'
	}, &dom.StyleValue{
		css_text: 'inset(10px 20px 30px 40px round 2px 3px 4px 5px / 6px 7px 8px 9px)'
	}, .add) or { panic('inset composition failed') }
	assert composited_inset.css_text == 'inset(11px 22px 33px 44px round 3px 5px 7px 9px / 11px 13px 15px 17px)'

	underlying_radial_size := StyleValue(RadialSizeStyleValue.create([
		RadialSizeStyleValueComponent(StyleValue(LengthStyleValue.create(Length.make_px(10)))),
	]))
	animated_radial_size := StyleValue(RadialSizeStyleValue.create([
		RadialSizeStyleValueComponent(StyleValue(LengthStyleValue.create(Length.make_px(20)))),
		RadialSizeStyleValueComponent(StyleValue(LengthStyleValue.create(Length.make_px(30)))),
	]))
	composited_radial_size := composite_style_value(.background_image, underlying_radial_size, animated_radial_size, .add) or { panic('radial-size composition failed') }
	assert composited_radial_size.serialize(.normal) == '30px 40px'

	radial_extent := StyleValue(RadialSizeStyleValue.create([
		RadialSizeStyleValueComponent(RadialExtentComponent{
			extent: .closest_side
		}),
	]))
	assert composite_style_value(.background_image, radial_extent, animated_radial_size, .add) == none
}

fn test_inline_style_priority_and_css_text() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	style := inline_style(element)
	style.set_property_with_priority('color', 'red', 'important')
	assert style.get_property_value('color') == 'red'
	assert style.get_property_priority('color') == 'important'
	assert style.item(0) == 'color'
	style.set_css_text('width: 10vw; height: 25vh')
	assert style.length() == 2
}
