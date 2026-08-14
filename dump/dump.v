// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Dump.{h,cpp}.

module dump

import css
import dom
import layout
import namespace_
import strings

pub fn dump_indent(mut builder strings.Builder, indent_levels int) {
	for _ in 0 .. indent_levels {
		builder.write_string('  ')
	}
}

fn dom_namespace_prefix(node &dom.Node, element &dom.Element) string {
	namespace_uri := element.namespace_uri() or { return '' }
	if node.is_default_namespace(namespace_uri) {
		return ''
	}
	return match namespace_uri {
		namespace_.html { 'html:' }
		namespace_.svg { 'svg:' }
		namespace_.mathml { 'mathml:' }
		else { '${namespace_uri}:' }
	}
}

fn dump_dom_node_into(mut builder strings.Builder, node &dom.Node, indent int) {
	dump_indent(mut builder, indent)
	if element := node.as_element() {
		builder.write_string('<${dom_namespace_prefix(node, element)}${element.local_name()}')
		for name in element.get_attribute_names() {
			builder.write_string(' ${name}=${element.get_attribute(name) or { '' }}')
		}
		builder.write_string('>\n')
	} else if node.is_text() {
		text := unsafe { &dom.Text(node) }
		builder.write_string('"${text.data()}"\n')
	} else {
		builder.write_string('${node.node_name()}\n')
	}

	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			dump_dom_node_into(mut builder, shadow_root.as_node(), indent + 1)
		}
	}
	mut child := node.first_child()
	for child != none {
		current := child or { break }
		dump_dom_node_into(mut builder, current, indent + 1)
		child = current.next_sibling()
	}
}

pub fn dom_tree(node &dom.Node) string {
	mut builder := strings.new_builder(256)
	dump_dom_node_into(mut builder, node, 0)
	return builder.str()
}

pub fn print_dom_tree(node &dom.Node) {
	println(dom_tree(node))
}

fn layout_node_kind(node &layout.Node) string {
	if node.is_viewport_ {
		return 'Viewport'
	}
	if node.is_text_node_ {
		return 'TextNode'
	}
	if node.is_block_container_ {
		return 'BlockContainer'
	}
	if node.is_box_ {
		return 'Box'
	}
	return 'Node'
}

fn dump_layout_node_into(mut builder strings.Builder, node &layout.Node, show_cascaded_properties bool, indent int) {
	dump_indent(mut builder, indent)
	mut description := '(anonymous)'
	if dom_node := node.dom_node() {
		description = dom_node.debug_description()
	}
	mut flags := []string{}
	if node.children_are_inline() {
		flags << 'children-inline'
	}
	if node.is_flex_item() {
		flags << 'flex-item'
	}
	if node.is_grid_item() {
		flags << 'grid-item'
	}
	if node.needs_layout_update() {
		flags << 'needs-layout'
	}
	flag_text := if flags.len == 0 { '' } else { ' [${flags.join(', ')}]' }
	builder.write_string('${layout_node_kind(node)} ${description}${flag_text}\n')
	if show_cascaded_properties && node.has_style() {
		dump_indent(mut builder, indent + 1)
		builder.write_string('(computed style attached)\n')
	}
	for child in node.children() {
		dump_layout_node_into(mut builder, child, show_cascaded_properties, indent + 1)
	}
}

pub fn layout_tree(node &layout.Node, show_cascaded_properties bool) string {
	mut builder := strings.new_builder(256)
	dump_layout_node_into(mut builder, node, show_cascaded_properties, 0)
	return builder.str()
}

pub fn print_layout_tree(node &layout.Node, show_cascaded_properties bool) {
	println(layout_tree(node, show_cascaded_properties))
}

fn combinator_description(combinator css.Combinator) string {
	return match combinator {
		.no_combinator { 'None' }
		.immediate_child { 'ImmediateChild' }
		.descendant { 'Descendant' }
		.next_sibling { 'AdjacentSibling' }
		.subsequent_sibling { 'GeneralSibling' }
		.column { 'Column' }
	}
}

fn simple_selector_description(type_ css.SimpleSelectorType) string {
	return match type_ {
		.universal { 'Universal' }
		.id { 'Id' }
		.class { 'Class' }
		.tag_name { 'TagName' }
		.attribute { 'Attribute' }
		.pseudo_class { 'PseudoClassSelector' }
		.pseudo_element { 'PseudoElement' }
		.nesting { 'Nesting' }
		.invalid { 'INVALID' }
	}
}

pub fn selector(selector css.Selector, indent_levels int) string {
	mut builder := strings.new_builder(128)
	dump_indent(mut builder, indent_levels)
	builder.write_string('CSS::Selector:\n')
	for compound in selector.compound_selectors() {
		dump_indent(mut builder, indent_levels + 1)
		builder.write_string('{${combinator_description(compound.combinator)}} ')
		mut parts := []string{}
		for simple in compound.simple_selectors {
			parts << '${simple_selector_description(simple.type_)}:${simple.serialize()}'
		}
		builder.write_string(parts.join(', '))
		builder.write_u8(`\n`)
	}
	return builder.str()
}

pub fn print_selector(selector_value css.Selector) {
	println(selector(selector_value, 0))
}

pub fn rule(rule &css.CSSRule, indent_levels int) string {
	return rule.dump(indent_levels)
}

pub fn print_rule(rule_value &css.CSSRule) {
	println(rule(rule_value, 0))
}

pub fn style_properties(properties &css.CSSStyleProperties, indent_levels int) string {
	mut builder := strings.new_builder(128)
	dump_indent(mut builder, indent_levels)
	builder.write_string('Declarations (${properties.length()}):\n')
	for property in properties.properties {
		dump_indent(mut builder, indent_levels)
		builder.write_string("  ${property.name}: '${property.value}'")
		if property.important {
			builder.write_string(' !important')
		}
		builder.write_u8(`\n`)
	}
	mut custom_names := properties.custom_properties.keys()
	custom_names.sort()
	for name in custom_names {
		dump_indent(mut builder, indent_levels)
		builder.write_string("  ${name}: '${properties.custom_properties[name]}'\n")
	}
	return builder.str()
}

pub fn descriptors(descriptors_value &css.CSSDescriptors, indent_levels int) string {
	mut builder := strings.new_builder(128)
	dump_indent(mut builder, indent_levels)
	builder.write_string('Declarations (${descriptors_value.length()}):\n')
	for index := usize(0); index < descriptors_value.length(); index++ {
		name := descriptors_value.item(index)
		dump_indent(mut builder, indent_levels)
		builder.write_string("  ${name}: '${descriptors_value.get_property_value(name)}'\n")
	}
	return builder.str()
}

pub fn sheet(sheet_value &css.CSSStyleSheet, indent_levels int) string {
	mut builder := strings.new_builder(256)
	dump_indent(mut builder, indent_levels)
	rules := sheet_value.css_rules().rules
	builder.write_string('CSSStyleSheet: ${rules.len} rule(s)\n')
	for rule_value in rules {
		builder.write_string(rule_value.dump(indent_levels + 1))
	}
	return builder.str()
}

pub fn print_sheet(sheet_value &css.CSSStyleSheet) {
	println(sheet(sheet_value, 0))
}

// Painting::Paintable is currently represented by a leaf object in the V DOM
// port. This dump covers all state available until its child/layout links land.
pub fn paintable(paintable_value &dom.Paintable, indent_levels int) string {
	mut builder := strings.new_builder(64)
	dump_indent(mut builder, indent_levels)
	kind := if paintable_value.is_paintable_box() { 'PaintableBox' } else { 'Paintable' }
	builder.write_string('${kind} needs-repaint=${paintable_value.needs_repaint}\n')
	return builder.str()
}
