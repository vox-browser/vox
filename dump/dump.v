// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Dump.{h,cpp}.

module dump

import css
import dom
import html
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
		if raw_pseudo_element := element.associated_shadow_host_pseudo_element() {
			if raw_pseudo_element >= 0 && raw_pseudo_element < int(dom.PseudoElement.known_pseudo_element_count) {
				dump_indent(mut builder, indent + 1)
				pseudo_element := unsafe { dom.PseudoElement(raw_pseudo_element) }
				builder.write_string('(pseudo-element: ${dom.pseudo_element_name(pseudo_element)})\n')
			}
		}
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

fn dump_session_history_entry_into(mut builder strings.Builder, entry &html.SessionHistoryEntry) {
	step := match entry.step() {
		int { entry.step() as int }
		html.SessionHistoryEntryPending {
			panic('cannot dump a pending session history entry')
		}
	}
	builder.write_string('step=(${step}) url=(${entry.url().serialize()})')
	if position := entry.scroll_position_data().viewport_scroll_position {
		builder.write_string(' viewport-scroll=(${position.x()}, ${position.y()})')
	}
	builder.write_u8(`\n`)
}

pub fn navigation_tree(navigable &html.NavigableModel) string {
	window := navigable.active_window() or { return '' }
	mut builder := strings.new_builder(128)
	for entry in window.navigation().entries() {
		dump_session_history_entry_into(mut builder, entry.session_history_entry())
	}
	return builder.str()
}

pub fn print_navigation_tree(navigable &html.NavigableModel) {
	print(navigation_tree(navigable))
}

pub fn layout_tree(node &layout.Node) string {
	result := layout.document_layout_result(node.document()) or { return '' }
	return layout.dump_typed_layout_tree(node, result.state)
}

pub fn print_layout_tree(node &layout.Node) {
	println(layout_tree(node))
}

pub fn serialized_selector(serialized string, indent_levels int) string {
	mut builder := strings.new_builder(128)
	dump_indent(mut builder, indent_levels)
	builder.write_string('CSS::Selector: ${serialized}\n')
	return builder.str()
}

pub fn selector(selector css.Selector, indent_levels int) string {
	return serialized_selector(selector.serialize(), indent_levels)
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
	for index := uint(0); index < descriptors_value.length(); index++ {
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
