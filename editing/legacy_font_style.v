// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/LegacyFontStyle.{h,cpp}.
module editing

import color
import css
import dom

enum ChildRunMaterialization {
	preserve_text_node_seams
	preserve_all_child_runs
}

fn single_legacy_font_run(node &dom.Node) ?&dom.Element {
	if node.child_count() != 1 {
		return none
	}
	child := node.last_child() or { return none }
	element := child.as_element() or { return none }
	if !element.is_html_element() || element.local_name() != 'font' {
		return none
	}
	return element
}

pub fn remove_single_run_legacy_font_style(mut node dom.Node) {
	font := single_legacy_font_run(node) or { return }
	mut font_node := font.as_node()
	for child in font_node.children_as_vector() {
		node.insert_before(child, font.as_node(), false)
	}
	font_node.remove(false)
}

fn materialize_legacy_font_run(mut node dom.Node, font &dom.Element, materialized_color string, child_run_materialization ChildRunMaterialization) {
	mut font_node := font.as_node()
	if !font_node.has_children() {
		font_node.remove(false)
		return
	}

	mut preserve_child_runs := font_node.child_count() > 1
	if child_run_materialization == .preserve_text_node_seams && preserve_child_runs {
		for child in font_node.children_as_vector() {
			if !child.is_text() {
				preserve_child_runs = false
				break
			}
		}
	}

	if first_child := font_node.first_child() {
		if first_child.is_text() && first_child.next_sibling() == none {
			mut text := unsafe { &dom.Text(first_child) }
			data := text.data()
			mut trailing_whitespace_length := 0
			for character in data.runes().reverse() {
				if character !in [` `, `\t`, `\n`, `\v`, `\f`, `\r`, `\u00a0`] {
					break
				}
				trailing_whitespace_length++
			}
			if trailing_whitespace_length > 0 && trailing_whitespace_length < data.runes().len {
				text.split_text(text.length_in_utf16_code_units() - trailing_whitespace_length) or { return }
				preserve_child_runs = true
			}
		}
	}

	for font_child in font_node.children_as_vector() {
		mut span := node.document().create_element('span') or { return }
		span.set_attribute_value('style', 'color: ${materialized_color};')
		mut span_node := span.as_node()
		node.insert_before(span.as_node(), font.as_node(), false)
		span_node.append_child(font_child) or { return }
		if !preserve_child_runs {
			for remaining_child in font_node.children_as_vector() {
				span_node.append_child(remaining_child) or { return }
			}
			break
		}
	}
	font_node.remove(false)
}

pub fn materialize_single_run_legacy_font_style(mut node dom.Node) {
	font := single_legacy_font_run(node) or { return }
	color_attribute := font.get_attribute('color') or { return }
	mut materialized_color := color_attribute
	if font.as_node().document().in_quirks_mode() {
		legacy_color := color.parse_legacy_color_value(color_attribute) or { return }
		css_color := css.parse_color_string(color_attribute)
		if css_color == none || (css_color or { return }).r != legacy_color.red
			|| (css_color or { return }).g != legacy_color.green
			|| (css_color or { return }).b != legacy_color.blue {
			materialized_color = css.Color.rgb(legacy_color.red, legacy_color.green,
				legacy_color.blue).serialize_a_srgb_value()
		}
	}
	materialize_legacy_font_run(mut node, font, materialized_color, .preserve_text_node_seams)
}

pub fn materialize_single_run_legacy_font_style_from_rendered_source(mut node dom.Node, rendered_style_source &dom.Node) {
	font := single_legacy_font_run(node) or { return }
	style_element := if element := rendered_style_source.as_element() {
		element
	} else {
		rendered_style_source.parent_element() or { return }
	}
	materialized_color := css.computed_value_for(style_element, .color) or { return }
	materialize_legacy_font_run(mut node, font, materialized_color, .preserve_all_child_runs)
}
