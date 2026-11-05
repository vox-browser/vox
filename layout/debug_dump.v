// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import svg

// Serialize the translated typed Layout tree in the same first-section format used by
// Tests/LibWeb/Layout/expected. Keeping this separate from BlockBox.tree_repr() is important: the
// latter is a renderer transport and intentionally omits anonymous, inline, text, and viewport
// nodes which are part of Layout's observable regression-test surface.
pub fn dump_document_layout_tree(document &dom.Document, viewport_width f64, viewport_height f64) ?string {
	result := run_document_layout(document, viewport_width, viewport_height) or { return none }
	return dump_typed_layout_tree(result.root, result.state)
}

// Serialize the retained tree produced by Document::update_layout without
// triggering a second style/layout pass. This is the V browser equivalent of
// Ladybird's `--headless=layout-tree` output path and keeps profiling scoped to
// the single production layout performed while loading the page.
pub fn dump_current_document_layout_tree(document &dom.Document) ?string {
	result := document_layout_result(document) or { return none }
	return dump_typed_layout_tree(result.root, result.state)
}

// LayoutTest snapshots contain the Layout tree and stacking-context tree. Ladybird
// stopped dumping the intermediate paint tree in 980be4b6b2d; retain the typed paint
// dump as a focused diagnostic API, but keep the corpus snapshot format source-faithful.
pub fn dump_document_layout_snapshot(document &dom.Document, viewport_width f64, viewport_height f64) ?string {
	result := run_document_layout(document, viewport_width, viewport_height) or { return none }
	mut layout_lines := []string{}
	append_typed_layout_node(result.root, result.state, 0, mut layout_lines)
	// Dump.cpp retains a final blank line produced by a recursively dumped
	// navigable layout root. The focused tree API trims it; a full snapshot does not.
	layout_tree := layout_lines.join('\n')
	stacking_context_tree := dump_typed_stacking_context_tree(result.root, result.state)
	return '${layout_tree}\n\n${stacking_context_tree}'
}

pub fn dump_typed_layout_tree(root &Node, state &LayoutState) string {
	mut lines := []string{}
	append_typed_layout_node(root, state, 0, mut lines)
	return lines.join('\n').trim_right('\n')
}

fn append_typed_layout_node(node &Node, state &LayoutState, depth int, mut lines []string) {
	indent := '  '.repeat(depth)
	mut line := '${indent}${layout_debug_class_name(node)} <${layout_debug_tag(node)}${layout_debug_identifier(node)}> '
	mut skip_anonymous_item := false
	mut skip_table_whitespace := false
	mut emitted_inline_block := false
	if parent := node.parent() {
		skip_anonymous_item =
			(parent.display().is_flex_inside() || parent.display().is_grid_inside())
				&& can_skip_anonymous_text_run(node)
				&& !(parent.display().is_grid_inside() && parent.display().is_inline_outside())
				&& !(parent.display().is_flex_inside() && parent.display().is_inline_outside()
					&& node.next_sibling() == none)
		skip_table_whitespace = ignorable_table_whitespace(node)
			&& (parent.display().is_table_inside() || parent.display().is_table_row_group()
				|| parent.display().is_table_header_group()
				|| parent.display().is_table_footer_group()
				|| parent.display().is_table_row()) && !is_trailing_whitespace_of_inline_table(node)
	}
	if node.is_text_node() || node.is_break_node() || skip_anonymous_item || skip_table_whitespace {
		line += '(not painted)'
	} else if node.is_inline_node() {
		if metrics := layout_debug_inline_metrics(node, state) {
			line += 'at ${layout_debug_point(metrics.position)}'
			if styled := node.as_node_with_style() {
				if used := state.try_get(styled) {
					line += layout_debug_box_model_with_size(used, metrics.width, metrics.height)
				}
			}
		} else {
			line += '(not painted)'
		}
	} else if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			if used.svg_rendering_disabled() {
				line += '(not painted)'
			} else {
				position := layout_offset_in_svg_user_space(node, state, used)
				line += 'at ${layout_debug_point(position)}'
				if node.is_box() {
					if node.is_positioned() {
						line += ' positioned'
					}
					if node.is_floating() {
						line += ' floating'
					}
					if node.is_inline_block() {
						line += ' inline-block'
						emitted_inline_block = true
					}
					if node.is_inline_table() {
						line += ' inline-table'
					}
					if node.display().is_flex_inside() {
						line += ' flex-container(${layout_debug_flex_direction(node.computed_values().flex_direction())})'
					}
					if node.is_flex_item() {
						line += ' flex-item'
					}
					if node.display().is_table_inside() {
						line += ' table-box'
					}
					if node.display().is_table_row_group() {
						line += ' table-row-group'
					}
					if node.display().is_table_column_group() {
						line += ' table-column-group'
					}
					if node.display().is_table_header_group() {
						line += ' table-header-group'
					}
					if node.display().is_table_footer_group() {
						line += ' table-footer-group'
					}
					if node.display().is_table_row() {
						line += ' table-row'
					}
					if node.display().is_table_cell() {
						line += ' table-cell'
					}
				}
				line += layout_debug_box_model(used)
			}
		} else {
			line += '(not painted)'
		}
	} else {
		line += '(not painted)'
	}
	// Box classification is part of the layout-tree identity even when an
	// anonymous flex item was skipped and consequently has no used values.
	if node.is_box() && node.is_inline_block() && !emitted_inline_block {
		line += ' inline-block'
	}
	if node.is_box() {
		if styled := node.as_node_with_style() {
			if used := state.try_get(styled) {
				if viewport_transform := used.svg_viewport_transform() {
					line += ' viewport-transform=${layout_debug_affine_transform(viewport_transform)}'
				}
			}
		}
		if context_name := layout_debug_formatting_context(node) {
			line += ' [${context_name}]'
		}
		line += if node.children_are_inline() {
			' children: inline'
		} else {
			' children: not-inline'
		}
	}
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none {
			line += ' continuation'
		}
	}
	if node.is_navigable_container_viewport() {
		viewport := unsafe { &NavigableContainerViewport(node) }
		if content := viewport.content_document() {
			line += ' (url: ${content.url.serialize()})'
		}
	}
	// LayoutTest asks Painting for scrollable overflow while serializing each
	// layout node. The upstream query measures lazily; V commits the same data
	// at the end of layout, so expose the retained rectangle here.
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			if used.has_scrollable_overflow() {
				if overflow_rect := used.scrollable_overflow_rect() {
					line += ' overflow: ${layout_debug_css_rect(overflow_rect)}'
				}
			}
		}
	}
	lines << line

	if node.is_navigable_container_viewport() {
		viewport := unsafe { &NavigableContainerViewport(node) }
		if styled := node.as_node_with_style() {
			if used := state.try_get(styled) {
				if content := viewport.content_document() {
					if nested := run_document_layout_for_tree_dump(content, used.content_width().to_double(), used.content_height().to_double()) {
						append_typed_layout_node(nested.root, nested.state, depth + 1, mut lines)
						lines << ''
					}
				}
			}
		}
	}

	// SVG image data owns a separate, non-scriptable document. It is laid out
	// using the replaced element's concrete viewport, and the upstream layout
	// dump exposes that otherwise isolated context directly below ImageBox.
	if image_box := node.as_image_box() {
		if !node.is_generated_for_pseudo_element() && !image_box.uses_content_replacement() {
			if svg_document := image_box.svg_image_document() {
				if styled := node.as_node_with_style() {
					if used := state.try_get(styled) {
						mut width := used.content_width().to_double()
						mut height := used.content_height().to_double()
						// The SVG image decoder retains its 32x32 fallback raster for an
						// empty document. Upstream's diagnostic tree exposes that retained
						// image viewport rather than resizing the isolated document to the
						// CSS object box.
						if root := svg_document.document_element() {
							view_box_is_degenerate := if view_box := svg.parse_viewbox(root.get_attribute_value('viewBox')) {
								view_box.width <= 0 || view_box.height <= 0
							} else {
								false
							}
							if root.as_node().child_count() == 0 && !view_box_is_degenerate {
								width = 32
								height = 32
							}
						}
						if width <= 0 || height <= 0 {
							return
						}
						mut mutable_svg_document := unsafe { &dom.Document(svg_document) }
						mutable_svg_document.set_viewport_rect(dom.Rect{0, 0, width, height})
						if svg_result := run_document_layout_for_tree_dump(svg_document, width,
							height) {
							lines << '${'  '.repeat(depth + 1)}(SVG-as-image isolated context)'
							append_typed_layout_node(svg_result.root, svg_result.state, depth + 1,
								mut lines)
						}
					}
				}
			}
		}
	}

	if node.is_block_container() && node.children_are_inline() {
		if styled := node.as_node_with_style() {
			if used := state.try_get(styled) {
				append_typed_block_line_fragments(node, state, used, depth, mut lines)
			}
		}
	} else if node.is_inline_node() {
		append_typed_inline_line_fragments(node, state, depth, mut lines)
	}
	for child in node.children() {
		append_typed_layout_node(child, state, depth + 1, mut lines)
	}
}

fn is_trailing_whitespace_of_inline_table(node &Node) bool {
	if !has_only_ignorable_table_whitespace_after(node) {
		return false
	}
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if current.display().is_table_inside() {
			return current.is_inline_table()
		}
		if !has_only_ignorable_table_whitespace_after(current) {
			return false
		}
		ancestor = current.parent()
	}
	return false
}

fn has_only_ignorable_table_whitespace_after(node &Node) bool {
	mut sibling := node.next_sibling()
	for sibling != none {
		current := sibling or { break }
		if !ignorable_table_whitespace(current) {
			return false
		}
		sibling = current.next_sibling()
	}
	return true
}

fn layout_debug_flex_direction(direction css.FlexDirection) string {
	return match direction {
		.row { 'row' }
		.row_reverse { 'row-reverse' }
		.column { 'column' }
		.column_reverse { 'column-reverse' }
	}
}

fn append_typed_block_line_fragments(node &Node, state &LayoutState, used &UsedValues, depth int, mut lines []string) {
	container_position := layout_offset_in_svg_user_space(node, state, used)
	mut fragment_index := 0
	for line_box in used.line_boxes {
		for fragment in line_box.fragments() {
			if fragment_inline_paintable_target(fragment.layout_node()) != none {
				continue
			}
			offset := css_pixel_point_add(css_pixel_point_add(container_position, fragment.offset()), inline_relative_offset(fragment.layout_node(), state))
			append_typed_fragment(fragment, offset, fragment_index, depth, mut lines)
			fragment_index++
		}
	}
}

fn append_typed_inline_line_fragments(node &Node, state &LayoutState, depth int, mut lines []string) {
	containing_block := node.containing_block() or { return }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return }
	containing_used := state.try_get(containing_styled) or { return }
	container_position := layout_offset_in_svg_user_space(containing_node, state, containing_used)
	for line_box in containing_used.line_boxes {
		mut fragment_index := 0
		for fragment in line_box.fragments() {
			if fragment.layout_node().is_generated_for_pseudo_element()
				&& fragment.layout_node().is_text_node()
				&& fragment.length_in_code_units() == 0 {
				continue
			}
			target := fragment_inline_paintable_target(fragment.layout_node()) or { continue }
			if !layout_nodes_same(target, node) {
				continue
			}
			offset := css_pixel_point_add(css_pixel_point_add(container_position, fragment.offset()), inline_relative_offset(fragment.layout_node(), state))
			append_typed_fragment(fragment, offset, fragment_index, depth, mut lines)
			fragment_index++
		}
	}
}

fn append_typed_fragment(fragment &LineBoxFragment, offset css.CSSPixelPoint, fragment_index int, depth int, mut lines []string) {
	indent := '  '.repeat(depth)
	lines << '${indent}  frag ${fragment_index} from ${layout_debug_class_name(fragment.layout_node())} start: ${fragment.start()}, length: ${fragment.length_in_code_units()}, rect: ${layout_debug_rect(offset, fragment.width(), fragment.height())} baseline: ${layout_debug_pixels(fragment.baseline())}'
	if text := fragment.text() {
		if fragment.length_in_code_units() > 0 {
			lines << '${indent}      "${layout_debug_text(text)}"'
		}
	}
}

fn layout_debug_fragment_is_in_inline_subtree(fragment_node &Node, inline_node &Node) bool {
	if is_inline_flow_interrupting_block(fragment_node) {
		return false
	}
	mut ancestor := fragment_node.parent()
	for ancestor != none {
		current := ancestor or { break }
		// LayoutState::commit() skips the complete BlockContainer paintable
		// subtree while sizing an inline paintable. Its internal line fragments
		// use a different containing block and must not enlarge the outer inline.
		if current.is_block_container() || current.is_atomic_inline() {
			return false
		}
		if layout_nodes_same(current, inline_node) {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

fn layout_debug_interrupting_block_is_in_inline_subtree(fragment_node &Node, inline_node &Node) bool {
	if !is_inline_flow_interrupting_block(fragment_node) {
		return false
	}
	mut ancestor := fragment_node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if layout_nodes_same(current, inline_node) {
			return true
		}
		if current.is_block_container() || current.is_atomic_inline() {
			return false
		}
		ancestor = current.parent()
	}
	return false
}

struct LayoutDebugInlineMetrics {
	position css.CSSPixelPoint
	width    CSSPixels
	height   CSSPixels
}

fn inline_descendant_horizontal_edges(fragment_node &Node, inline_node &Node, state &LayoutState) (CSSPixels, CSSPixels) {
	mut leading := CSSPixels.new(0)
	mut trailing := CSSPixels.new(0)
	mut ancestor := fragment_node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if layout_nodes_same(current, inline_node) {
			break
		}
		if current.is_atomic_inline() {
			break
		}
		if current.is_inline_node() {
			if styled := current.as_node_with_style() {
				if used := state.try_get(styled) {
					leading =
						leading.plus(used.margin_left).plus(used.border_left).plus(used.padding_left)
					trailing =
						trailing.plus(used.padding_right).plus(used.border_right).plus(used.margin_right)
				}
			}
		}
		ancestor = current.parent()
	}
	return leading, trailing
}

// InlinePaintable geometry as dumped by upstream: the union of the box's
// per-line piece content rectangles.
fn layout_debug_inline_metrics(node &Node, state &LayoutState) ?LayoutDebugInlineMetrics {
	geometry := inline_box_absolute_geometry(node, state) or { return none }
	return LayoutDebugInlineMetrics{
		position: css.CSSPixelPoint.new(geometry.content_rect.x, geometry.content_rect.y)
		width: geometry.content_rect.width
		height: geometry.content_rect.height
	}
}

fn layout_debug_box_model(used &UsedValues) string {
	return layout_debug_box_model_with_size(used, used.content_width(), used.content_height())
}

fn layout_debug_box_model_with_size(used &UsedValues, width CSSPixels, height CSSPixels) string {
	return ' [${layout_debug_pixels(used.margin_left)}+${layout_debug_pixels(used.border_left)}+${layout_debug_pixels(used.padding_left)} ${layout_debug_pixels(width)} ${layout_debug_pixels(used.padding_right)}+${layout_debug_pixels(used.border_right)}+${layout_debug_pixels(used.margin_right)}]' + ' [${layout_debug_pixels(used.margin_top)}+${layout_debug_pixels(used.border_top)}+${layout_debug_pixels(used.padding_top)} ${layout_debug_pixels(height)} ${layout_debug_pixels(used.padding_bottom)}+${layout_debug_pixels(used.border_bottom)}+${layout_debug_pixels(used.margin_bottom)}]'
}

fn layout_debug_formatting_context(node &Node) ?string {
	if node.is_svg_svg_box() {
		return 'SVG'
	}
	// Replaced boxes without children never create an independent formatting
	// context, regardless of the inner display type computed for the element.
	if node.is_replaced_box() && !node.is_replaced_box_with_children() {
		return none
	}
	if node.display().is_flex_inside() {
		return 'FFC'
	}
	if node.display().is_grid_inside() {
		return 'GFC'
	}
	if node.display().is_table_inside() {
		return 'TFC'
	}
	if node.display().is_math_inside() {
		return 'BFC'
	}
	styled := node.as_node_with_style() or { return none }
	if node.is_viewport() {
		return 'BFC'
	}
	if creates_block_formatting_context(styled) {
		return 'BFC'
	}
	return none
}

fn layout_debug_class_name(node &Node) string {
	if node.is_viewport() {
		return 'Viewport'
	}
	if node.is_navigable_container_viewport() {
		return 'NavigableContainerViewport'
	}
	if node.is_svg_foreign_object_box() {
		return 'SVGForeignObjectBox'
	}
	if node.is_svg_text_path_box() {
		return 'SVGTextPathBox'
	}
	if node.is_svg_text_box() {
		return 'SVGTextBox'
	}
	if node.is_svg_image_box() {
		return 'SVGImageBox'
	}
	if node.is_svg_geometry_box() {
		return 'SVGGeometryBox'
	}
	if node.is_svg_mask_box() {
		return 'SVGMaskBox'
	}
	if node.is_svg_pattern_box() {
		return 'SVGPatternBox'
	}
	if node.is_svg_clip_box() {
		return 'SVGClipBox'
	}
	if node.is_svg_graphics_box() {
		return 'SVGGraphicsBox'
	}
	if node.is_svg_box() {
		return 'SVGBox'
	}
	if node.is_svg_svg_box() {
		return 'SVGSVGBox'
	}
	if node.is_generated_text_node() {
		return 'GeneratedTextNode'
	}
	if node.is_text_node() {
		return 'TextNode'
	}
	if node.is_break_node() {
		return 'BreakNode'
	}
	if node.is_inline_node() {
		return 'InlineNode'
	}
	if node.is_table_wrapper() {
		return 'TableWrapper'
	}
	if node.is_list_item_marker_box() {
		return 'ListItemMarkerBox'
	}
	if node.is_list_item_box() {
		return 'ListItemBox'
	}
	if node.is_fieldset_box() {
		return 'FieldSetBox'
	}
	if node.is_legend_box() {
		return 'LegendBox'
	}
	if node.is_textarea_box() {
		return 'TextAreaBox'
	}
	if node.is_text_input_box() {
		return 'TextInputBox'
	}
	if node.is_range_input_box() {
		return 'RangeInputBox'
	}
	if node.is_replaced_box() {
		return layout_debug_replaced_class_name(node)
	}
	if node.is_block_container() {
		return 'BlockContainer'
	}
	if node.is_box() {
		return 'Box'
	}
	return 'Node'
}

fn layout_debug_replaced_class_name(node &Node) string {
	if node.is_image_box() {
		return 'ImageBox'
	}
	dom_node := node.dom_node() or { return 'ReplacedBox' }
	element := dom_node.as_element() or { return 'ReplacedBox' }
	return match element.local_name().to_lower() {
		'img' {
			'ImageBox'
		}
		'canvas' {
			'CanvasBox'
		}
		'audio' {
			'AudioBox'
		}
		'video' {
			'VideoBox'
		}
		'input' {
			match element.get_attribute_value('type').to_lower() {
				'checkbox' { 'CheckBox' }
				'radio' { 'RadioButton' }
				'image' { 'ImageBox' }
				else { 'ReplacedBox' }
			}
		}
		else {
			'ReplacedBox'
		}
	}
}

fn layout_debug_tag(node &Node) string {
	if node.is_generated_text_node() {
		return '(anonymous)'
	}
	if node.is_text_node() {
		return '#text'
	}
	if node.is_anonymous() || node.dom_node() == none {
		return '(anonymous)'
	}
	dom_node := node.dom_node() or { return '(anonymous)' }
	if element := dom_node.as_element() {
		return element.local_name()
	}
	return dom_node.node_name()
}

fn layout_debug_identifier(node &Node) string {
	dom_node := node.dom_node() or { return '' }
	element := dom_node.as_element() or { return '' }
	mut result := ''
	if id := element.id() {
		if id.len > 0 {
			result += '#${id}'
		}
	}
	for class_name in element.get_attribute_value('class').fields() {
		result += '.${class_name}'
	}
	return result
}

fn layout_debug_point(point css.CSSPixelPoint) string {
	return '[${layout_debug_pixels(point.x())},${layout_debug_pixels(point.y())}]'
}

fn layout_debug_rect(point css.CSSPixelPoint, width CSSPixels, height CSSPixels) string {
	return '[${layout_debug_pixels(point.x())},${layout_debug_pixels(point.y())} ${layout_debug_pixels(width)}x${layout_debug_pixels(height)}]'
}

fn layout_debug_affine_transform(transform svg.AffineTransform) string {
	return '[${layout_debug_float(f32(transform.a))} ${layout_debug_float(f32(transform.b))} ${layout_debug_float(f32(transform.c))} ${layout_debug_float(f32(transform.d))} ${layout_debug_float(f32(transform.e))} ${layout_debug_float(f32(transform.f))}]'
}

fn layout_debug_float(value f32) string {
	if value == 0 {
		return '0'
	}
	integer := int(value)
	if value == f32(integer) {
		return integer.str()
	}
	return value.str()
}

fn layout_debug_pixels(value CSSPixels) string {
	if value.raw_value() % 64 == 0 {
		return (value.raw_value() / 64).str()
	}
	return value.to_double().str()
}

fn layout_debug_text(text string) string {
	// Dump.cpp appends fragment.text() directly between quotes; control
	// characters are deliberately not escaped in Layout corpus snapshots.
	return text
}
