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

pub fn remove_single_run_legacy_font_style(node &dom.Node) {
	font := single_legacy_font_run(node) or { return }
	unwrap_node_preserving_ranges(font.as_node())
}

fn materialize_legacy_font_run(node &dom.Node, font &dom.Element, materialized_color string, child_run_materialization ChildRunMaterialization) {
	// INTEROP: Blink and WebKit traverse a rendered range when serializing editing content. If that traversal contains
	//          one presentational wrapper, the wrapper is omitted and supplies CSS to the serialized content. A range
	//          which crosses multiple inline runs includes their elements directly, so their legacy markup remains.
	font_node := font.as_node()
	if !font_node.has_children() {
		remove_node(font_node)
		return
	}

	// INTEROP: Serialized paragraph moves protect trailing collapsible whitespace as a separate text run. Blink and
	//          WebKit materialize each resulting run in its own style span, and later whitespace cleanup decides
	//          whether the protected space becomes ordinary without erasing that observable node seam.
	mut preserve_child_runs := font_node.child_count() > 1
	if child_run_materialization == .preserve_text_node_seams {
		for child in font_node.children_as_vector() {
			if !preserve_child_runs {
				break
			}
			preserve_child_runs = child.is_text()
		}
	}

	if first_child := font_node.first_child() {
		if first_child.is_text() && first_child.next_sibling() == none {
			text := unsafe { &dom.Text(first_child) }
			// NB: Every trailing whitespace code point is a single UTF-16 code unit.
			data_length := text.length_in_utf16_code_units()
			mut trailing_whitespace_start := data_length
			for code_point in text.data().runes().reverse() {
				if !is_ascii_space_character(code_point) && code_point != `\u00a0` {
					break
				}
				trailing_whitespace_start--
			}
			if trailing_whitespace_start > 0 && trailing_whitespace_start < data_length {
				split_text(text, trailing_whitespace_start) or { panic(err) }
				preserve_child_runs = true
			}
		}
	}

	for {
		span := node.document().create_element('span') or { panic(err) }
		span_node := span.as_node()
		{
			// NB: The span is detached staging content. Its eventual insertion is recorded as a whole, so construction
			//     of its inline style must not be diagnosed as an unrecorded mutation of the edited document.
			history := begin_editing_proxy_mutation(span_node)
			mut style := css.element_style(span)
			style.set_property('color', materialized_color, '') or {}
			end_editing_proxy_mutation(history)
		}
		insert_node_before(span_node, node, font_node)
		first_font_child := font_node.first_child() or { break }
		move_node_preserving_ranges(first_font_child, span_node, 0)
		if !preserve_child_runs {
			for font_node.first_child() != none {
				font_child := font_node.first_child() or { break }
				move_node_preserving_ranges(font_child, span_node, span_node.child_count())
			}
		}
		if font_node.first_child() == none {
			break
		}
	}
	remove_node(font_node)
}

pub fn materialize_single_run_legacy_font_style(node &dom.Node) {
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
	materialize_legacy_font_run(node, font, materialized_color, .preserve_text_node_seams)
}

pub fn materialize_single_run_legacy_font_style_from_rendered_source(node &dom.Node, rendered_style_source &dom.Node) {
	font := single_legacy_font_run(node) or { return }
	materialized_color := resolved_value(rendered_style_source, 'color') or { return }

	// The serializer has already isolated protected whitespace in child wrappers. Materializing each child as its own
	// styled run lets fragment cleanup discard those transport wrappers without erasing the inherited style seam.
	materialize_legacy_font_run(node, font, materialized_color, .preserve_all_child_runs)
}
