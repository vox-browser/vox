// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import math
import svg

fn paint_local_offset(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	mut offset := used.offset
	if coordinate := used.containing_line_box_fragment {
		if containing_block := node.containing_block() {
			containing_styled := unsafe { &NodeWithStyle(containing_block) }
			if containing_used := state.try_get(containing_styled) {
				if coordinate.line_box_index >= 0
					&& coordinate.line_box_index < containing_used.line_boxes.len {
					line_box := containing_used.line_boxes[coordinate.line_box_index]
					if coordinate.fragment_index >= 0
						&& coordinate.fragment_index < line_box.fragments_.len {
						offset = line_box.fragments_[coordinate.fragment_index].offset()
					}
				}
			}
		}
	}
	if used.node().computed_values().position() == .relative {
		offset = css_pixel_point_add(offset, css.CSSPixelPoint.from_values(used.inset_left.to_double(),
			used.inset_top.to_double()))
	}
	return offset
}

fn paint_cumulative_offset(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	offset := paint_local_offset(node, state, used)
	if containing := used.containing_block_used_values() {
		containing_node := unsafe { &Node(containing.node()) }
		return css_pixel_point_add(paint_cumulative_offset(containing_node, state, containing),
			offset)
	}
	return offset
}

fn inline_relative_offset(node &Node, state &LayoutState) css.CSSPixelPoint {
	mut result := css.CSSPixelPoint.from_values(0, 0)
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if !current.display().is_inline_outside() || !current.display().is_flow_inside() {
			break
		}
		if current.computed_values().position() == .relative {
			if styled := current.as_node_with_style() {
				if used := state.try_get(styled) {
					result = css_pixel_point_add(result, css.CSSPixelPoint.from_values(used.inset_left.to_double(),
						used.inset_top.to_double()))
				}
			}
		}
		ancestor = current.parent()
	}
	return result
}

// Build the renderer-facing box tree from the canonical typed Layout tree and
// LayoutState. BlockBox remains the display-list transport used by the native
// shell; it no longer runs an independent layout algorithm.
pub fn layout_document_typed_in_viewport(document &dom.Document, viewport_width f64, viewport_height f64) BlockBox {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{0, 0, viewport_width, viewport_height})
	result := run_document_layout(document, viewport_width, viewport_height) or {
		return BlockBox{}
	}
	author_rules := css.flatten_media_rules(collect_document_author_rules(document), viewport_width)
	root_layout_node := result.root.first_child() or { return BlockBox{} }
	mut root_box := block_box_from_typed_layout(root_layout_node, result.state, author_rules)

	mut canvas_background := root_box.background_color
	if canvas_background.a == 0 {
		for index, child in root_box.children {
			if child.tag_name == 'body' && child.background_color.a > 0 {
				canvas_background = child.background_color
				root_box.children[index].background_color = css.Color{0, 0, 0, 0}
				break
			}
		}
	}
	if canvas_background.a > 0 {
		root_box.canvas_background_color = canvas_background
		root_box.canvas_width = viewport_width
		root_box.canvas_height = viewport_height
		root_box.background_color = css.Color{0, 0, 0, 0}
	}
	return root_box
}

fn block_box_from_typed_layout(node &Node, state &LayoutState, author_rules []&css.CSSRule) BlockBox {
	styled := node.as_node_with_style() or { return BlockBox{} }
	used := state.try_get(styled) or { return BlockBox{} }
	if used.svg_rendering_disabled() {
		return BlockBox{}
	}
	computed := styled.computed_values()
	position := paint_cumulative_offset(node, state, used)
	mut element := ?&dom.Element(none)
	mut tag_name := ''
	mut node_id := i64(0)
	if dom_node := node.dom_node() {
		if dom_element := dom_node.as_element() {
			element = dom_element
			tag_name = dom_element.local_name()
			node_id = i64(dom_element.as_node().unique_id())
		}
	}

	mut background_color := css.Color{0, 0, 0, 0}
	mut text_color := css.Color{0, 0, 0, 255}
	mut border_color := text_color
	mut border_colors := BoxColors{text_color, text_color, text_color, text_color}
	mut border_radius := 0.0
	mut border_radii := BoxRadii{}
	mut outline_width := 0.0
	mut outline_offset := 0.0
	mut outline_color := text_color
	mut shadow := ?BoxShadow(none)
	mut shadows := []BoxShadow{}
	mut background_gradient := ?LinearGradient(none)
	mut background_images := []BackgroundImageLayer{}
	mut svg_path := ''
	mut svg_transform := [f64(1), 0, 0, 1, 0, 0]!
	mut svg_points := []f64{}
	mut svg_fill_color := ''
	mut svg_stroke_color := ''
	mut svg_stroke_width := 0.0
	mut svg_fill_opacity := 1.0
	mut svg_stroke_opacity := 1.0
	mut z_index := 0
	positioned := node.is_positioned()
	mut stacking_context := node.establishes_stacking_context()
	mut marker_shape := ''
	mut paint_transform := [6]f64{}
	if color_value := computed.property(.color, .yes) {
		text_color = css.parse_color_string(color_value.css_text) or { text_color }
	}
	if styled_element := element {
		background_color = css.computed_color(styled_element, .background_color, author_rules) or {
			background_color
		}
		text_color = css.computed_color(styled_element, .color, author_rules) or { text_color }
		border_color = css.computed_color(styled_element, .border_top_color, author_rules) or {
			text_color
		}
		border_colors = resolved_border_colors(styled_element, text_color, author_rules)
		border_color = border_colors.top
		border_radii = resolve_box_radii(styled_element, used.border_box_width().to_double(),
			used.border_box_height().to_double(), author_rules)
		border_radius = border_radii.top_left.x
		outline_width = used_outline_width(styled_element, author_rules)
		outline_offset = css.computed_length_px(styled_element, .outline_offset, author_rules) or {
			0.0
		}
		outline_color = css.computed_color(styled_element, .outline_color, author_rules) or {
			text_color
		}
		shadows = parse_box_shadows(styled_element, author_rules)
		if shadows.len > 0 {
			shadow = shadows[0]
		}
		background_gradient = parse_background_gradient(styled_element, author_rules)
		background_images = parse_background_image_layers(styled_element, author_rules)
		if node.is_positioned() {
			z_index_value := css.cascaded_value_with_ua(styled_element, .z_index, author_rules)
			if z_index_value != 'auto' {
				z_index = z_index_value.int()
			}
		}
		paint_transform = resolved_transform_matrix(styled_element, position.x().to_double() -
			used.padding_left.to_double() - used.border_left.to_double(),

			position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double(),
			used.border_box_width().to_double(), used.border_box_height().to_double(), author_rules)
	}
	if path := used.computed_svg_path() {
		svg_path = path.serialize()
		page_delta_x := position.x().to_double() - used.offset.x().to_double()
		page_delta_y := position.y().to_double() - used.offset.y().to_double()
		to_page :=
			svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(used.svg_transform())
		svg_transform = [to_page.a, to_page.b, to_page.c, to_page.d, to_page.e, to_page.f]!
		for point in path.endpoints() {
			mapped := to_page.map_point(point)
			svg_points << mapped.x
			svg_points << mapped.y
		}
		if fill_value := computed.property(.fill, .yes) {
			if fill_value.css_text.trim_space().to_lower() != 'none' {
				if fill_color := css.parse_color_string(fill_value.css_text) {
					svg_fill_color = fill_color.serialize()
				} else if fill_value.css_text.trim_space().to_lower() == 'currentcolor' {
					svg_fill_color = text_color.serialize()
				}
			}
		}
		if stroke_value := computed.property(.stroke, .yes) {
			if stroke_value.css_text.trim_space().to_lower() != 'none' {
				if stroke_color := css.parse_color_string(stroke_value.css_text) {
					svg_stroke_color = stroke_color.serialize()
				} else if stroke_value.css_text.trim_space().to_lower() == 'currentcolor' {
					svg_stroke_color = text_color.serialize()
				}
			}
		}
		diagonal := math.sqrt(used.content_width().to_double() * used.content_width().to_double() +
			used.content_height().to_double() * used.content_height().to_double())
		svg_stroke_width = computed.length_percentage_to_px(.stroke_width, diagonal) or { 1.0 }
		svg_fill_opacity = f64(computed.fill_opacity())
		svg_stroke_opacity = f64(computed.stroke_opacity())
	}
	if marker := node.as_list_item_marker_box() {
		if marker.text() == none {
			marker_shape = marker.list_style_type_.name
		}
	}

	mut children := []BlockBox{}
	for child in node.children() {
		if child.is_box() {
			if child_styled := child.as_node_with_style() {
				if state.try_get(child_styled) == none {
					children << typed_block_descendants(child, state, author_rules)
					continue
				}
			}
			child_box := block_box_from_typed_layout(child, state, author_rules)
			if child_box.tag_name != '' || child.is_anonymous()
				|| child.is_generated_for_pseudo_element() {
				children << child_box
			}
		} else if child.is_inline_node() {
			children << typed_block_descendants(child, state, author_rules)
		}
	}

	mut lines := text_lines_from_typed_layout(node, used, state, author_rules, position)
	if !affine_is_compact_identity(paint_transform) {
		children = children.map(apply_ancestor_affine(it, paint_transform))
	}
	if lines.len == 0 && used.svg_text().len > 0 {
		lines << TextLine{
			x:         position.x().to_double()
			y:         position.y().to_double()
			width:     used.content_width().to_double()
			height:    used.content_height().to_double()
			fragments: [
				TextFragment{
					x:         position.x().to_double()
					y:         position.y().to_double()
					width:     used.content_width().to_double()
					height:    used.content_height().to_double()
					text:      used.svg_text()
					color:     css.parse_color_string(svg_fill_color) or { text_color }
					font_size: computed.resolved_font_size_px()
				},
			]
		}
	}
	if list_item := node.as_list_item_box() {
		if marker_node := list_item.marker() {
			if marker := marker_node.as_list_item_marker_box() {
				if marker_text := marker.text() {
					if marker_styled := marker_node.as_node_with_style() {
						if marker_used := state.try_get(marker_styled) {
							marker_position := paint_cumulative_offset(marker_node, state,
								marker_used)
							lines.prepend(TextLine{
								x:         marker_position.x().to_double()
								y:         marker_position.y().to_double()
								width:     marker_used.content_width().to_double()
								height:    marker_used.content_height().to_double()
								fragments: [
									TextFragment{
										x:         marker_position.x().to_double()
										y:         marker_position.y().to_double()
										width:     marker_used.content_width().to_double()
										height:    marker_used.content_height().to_double()
										text:      marker_text.trim_right(' ')
										color:     text_color
										font_size: marker.computed_values().resolved_font_size_px()
									},
								]
							})
						}
					}
				}
			}
		}
	}
	return BlockBox{
		tag_name:            tag_name
		x:                   position.x().to_double()
		y:                   position.y().to_double()
		width:               used.content_width().to_double()
		height:              used.content_height().to_double()
		margin:              BoxEdges{used.margin_top.to_double(), used.margin_right.to_double(), used.margin_bottom.to_double(), used.margin_left.to_double()}
		border:              BoxEdges{used.border_top.to_double(), used.border_right.to_double(), used.border_bottom.to_double(), used.border_left.to_double()}
		padding:             BoxEdges{used.padding_top.to_double(), used.padding_right.to_double(), used.padding_bottom.to_double(), used.padding_left.to_double()}
		outer_top_margin:    used.margin_top.to_double()
		outer_bottom_margin: used.margin_bottom.to_double()
		z_index:             z_index
		positioned:          positioned
		stacking_context:    stacking_context
		background_color:    background_color
		text_color:          text_color
		border_color:        border_color
		border_colors:       border_colors
		border_radius:       border_radius
		border_radii:        border_radii
		outline_width:       outline_width
		outline_offset:      outline_offset
		outline_color:       outline_color
		shadow:              shadow
		shadows:             shadows
		background_gradient: background_gradient
		background_images:   background_images
		opacity:             f64(computed.opacity())
		visible:             computed.visibility() == .visible
		node_id:             node_id
		children:            children
		lines:               lines
		svg_path:            svg_path
		svg_transform:       svg_transform
		svg_points:          svg_points
		svg_fill_color:      svg_fill_color
		svg_stroke_color:    svg_stroke_color
		svg_stroke_width:    svg_stroke_width
		svg_fill_opacity:    svg_fill_opacity
		svg_stroke_opacity:  svg_stroke_opacity
		marker_shape:        marker_shape
		paint_transform:     paint_transform
	}
}

fn typed_block_descendants(node &Node, state &LayoutState, author_rules []&css.CSSRule) []BlockBox {
	mut descendants := []BlockBox{}
	for child in node.children() {
		if child.is_box() {
			if styled := child.as_node_with_style() {
				if state.try_get(styled) == none {
					descendants << typed_block_descendants(child, state, author_rules)
					continue
				}
			}
			descendants << block_box_from_typed_layout(child, state, author_rules)
		} else {
			descendants << typed_block_descendants(child, state, author_rules)
		}
	}
	return descendants
}

fn text_lines_from_typed_layout(container &Node, used &UsedValues, state &LayoutState, author_rules []&css.CSSRule, container_position css.CSSPixelPoint) []TextLine {
	mut lines := []TextLine{}
	for line_box in used.line_boxes {
		mut fragments := []TextFragment{}
		for fragment in line_box.fragments_ {
			text := fragment.text() or { continue }
			computed := fragment.layout_node_.computed_values()
			owner_element := painted_owner_element(fragment.layout_node_)
			mut color := css.Color{0, 0, 0, 255}
			mut background := css.Color{0, 0, 0, 0}
			mut border_color := color
			mut border_colors := BoxColors{color, color, color, color}
			mut decoration_color := color
			mut decoration_style := 'solid'
			mut decoration_thickness := 0.0
			mut border := BoxEdges{}
			mut radius := 0.0
			mut radii := BoxRadii{}
			mut inline_shadow := ?BoxShadow(none)
			mut inline_shadows := []BoxShadow{}
			mut inline_node_id := i64(0)
			if owner := owner_element {
				color = css.computed_color(owner, .color, author_rules) or { color }
				background = css.computed_color(owner, .background_color, author_rules) or {
					background
				}
				border_color = css.computed_color(owner, .border_top_color, author_rules) or {
					color
				}
				border_colors = resolved_border_colors(owner, color, author_rules)
				border_color = border_colors.top
				decoration_color = css.computed_color(owner, .text_decoration_color, author_rules) or {
					color
				}
				decoration_style = css.cascaded_value_with_ua(owner, .text_decoration_style,
					author_rules)
				decoration_thickness = resolve_text_decoration_thickness(owner,
					computed.font_size().to_double(), author_rules)
				inline_node_id = i64(owner.as_node().unique_id())
				radii = resolve_box_radii(owner, fragment.width().to_double(),
					fragment.height().to_double(), author_rules)
				radius = radii.top_left.x
				inline_shadows = parse_box_shadows(owner, author_rules)
				if inline_shadows.len > 0 {
					inline_shadow = inline_shadows[0]
				}
			}
			if parent := fragment.layout_node_.parent() {
				if parent_styled := parent.as_node_with_style() {
					if inline_used := state.try_get(parent_styled) {
						border =
							BoxEdges{inline_used.border_top.to_double(), inline_used.border_right.to_double(), inline_used.border_bottom.to_double(), inline_used.border_left.to_double()}
					}
				}
			}
			offset := css_pixel_point_add(fragment.offset(), inline_relative_offset(fragment.layout_node_,
				state))
			transport_fragment := TextFragment{
				x:                    container_position.x().plus(offset.x()).to_double()
				y:                    container_position.y().plus(offset.y()).to_double()
				width:                fragment.width().to_double()
				height:               fragment.height().to_double()
				text:                 text
				color:                color
				font_size:            computed.font_size().to_double()
				bold:                 computed.font_weight() >= 600
				italic:               computed.property(.font_style, .yes) or { &dom.StyleValue{} }.css_text.contains('italic')
				mono:                 (computed.property(.font_family, .yes) or {
					&dom.StyleValue{}
				}).css_text.to_lower().contains('mono')
				text_run_id:          text_run_identity(fragment.layout_node_)
				shape_as_run:
					resolved_text_spacing_for_node(fragment.layout_node_, .letter_spacing).raw_value() == 0
					&& resolved_text_spacing_for_node(fragment.layout_node_, .word_spacing).raw_value() == 0
				inline_node_id:       inline_node_id
				background_color:     background
				border:               border
				border_color:         border_color
				border_colors:        border_colors
				border_radius:        radius
				border_radii:         radii
				shadow:               inline_shadow
				shadows:              inline_shadows
				decoration:           text_decoration_string(computed.text_decoration_line())
				decoration_color:     decoration_color
				decoration_color_set: true
				decoration_style:     decoration_style
				decoration_thickness: decoration_thickness
			}
			fragments << split_transport_text_fragment(transport_fragment, fragment)
		}
		mut line_x := container_position.x().to_double()
		mut line_y :=
			container_position.y().plus(CSSPixels.nearest_value_for(line_box.bottom().to_double() - line_box.height().to_double())).to_double()
		if fragments.len > 0 {
			line_x = fragments[0].x
			line_y = fragments[0].y
		}
		lines << TextLine{
			x:         line_x
			y:         line_y
			width:     line_box.width().to_double()
			height:    line_box.height().to_double()
			fragments: fragments
		}
	}
	_ = container
	return lines
}

// LineBox intentionally coalesces adjacent shaped chunks from one text node.
// BlockBox is an older renderer/CSSOM transport whose callers address words as
// individual fragments. Split only collapsible LTR text here; the shared run
// identity makes text_fragment_commands() shape and paint it as one run again.
fn split_transport_text_fragment(base TextFragment, source LineBoxFragment) []TextFragment {
	if !base.text.contains_any(' \t\n\r\f')
		|| source.layout_node_.computed_values().direction() != .ltr
		|| source.layout_node_.computed_values().white_space_collapse() !in [.collapse, .preserve_breaks] {
		return [base]
	}
	run := source.glyph_run() or { return [base] }
	runes := base.text.runes()
	glyphs := run.glyphs()
	if runes.len != glyphs.len {
		return [base]
	}
	mut result := []TextFragment{}
	mut word_start := -1
	for index in 0 .. runes.len + 1 {
		is_space_or_end := index == runes.len || runes[index].str().trim_space().len == 0
		if !is_space_or_end && word_start < 0 {
			word_start = index
		}
		if is_space_or_end && word_start >= 0 {
			last_index := index - 1
			start_x := f64(glyphs[word_start].position.x)
			end_x := f64(glyphs[last_index].position.x + glyphs[last_index].advance)
			result << TextFragment{
				x:                    base.x + start_x
				y:                    base.y
				width:                end_x - start_x
				height:               base.height
				text:                 runes[word_start..index].string()
				color:                base.color
				font_size:            base.font_size
				bold:                 base.bold
				italic:               base.italic
				mono:                 base.mono
				text_run_id:          base.text_run_id
				shape_as_run:         base.shape_as_run
				separator_after:      if index < runes.len { ' ' } else { '' }
				inline_node_id:       base.inline_node_id
				background_color:     base.background_color
				border:               base.border
				border_color:         base.border_color
				border_colors:        base.border_colors
				border_radius:        base.border_radius
				border_radii:         base.border_radii
				shadow:               base.shadow
				shadows:              base.shadows.clone()
				decoration:           base.decoration
				decoration_color:     base.decoration_color
				decoration_color_set: base.decoration_color_set
				decoration_style:     base.decoration_style
				decoration_thickness: base.decoration_thickness
			}
			word_start = -1
		}
	}
	return if result.len > 0 { result } else { [base] }
}

fn painted_owner_element(node &Node) ?&dom.Element {
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			return element
		}
		if parent := dom_node.parent_element() {
			return parent
		}
	}
	mut next_ancestor := node.parent()
	for {
		ancestor := next_ancestor or { break }
		if dom_node := ancestor.dom_node() {
			if element := dom_node.as_element() {
				return element
			}
		}
		next_ancestor = ancestor.parent()
	}
	return none
}

fn text_run_identity(node &Node) i64 {
	dom_node := node.dom_node() or { return 0 }
	return i64(dom_node.unique_id())
}

fn text_decoration_string(lines []css.TextDecorationLine) string {
	mut names := []string{}
	for line in lines {
		match line {
			.underline { names << 'underline' }
			.overline { names << 'overline' }
			.line_through { names << 'line-through' }
			.spelling_error { names << 'spelling-error' }
			.grammar_error { names << 'grammar-error' }
			else {}
		}
	}
	return if names.len == 0 { 'none' } else { names.join(' ') }
}
