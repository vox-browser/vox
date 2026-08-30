// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import math
import platform

pub enum InlineLevelItemType {
	text
	element
	forced_break
	absolutely_positioned_element
	floating_element
}

pub struct InlineLevelItem {
pub:
	type_                     InlineLevelItemType
	node                      ?&Node
	glyph_run                 ?&platform.GlyphRun
	offset_in_node            int
	length_in_node            int
	is_collapsible_whitespace bool
	can_break_before          bool
pub mut:
	width         CSSPixels
	padding_start CSSPixels
	padding_end   CSSPixels
	border_start  CSSPixels
	border_end    CSSPixels
	margin_start  CSSPixels
	margin_end    CSSPixels
}

pub fn (item &InlineLevelItem) border_box_width() CSSPixels {
	return css_pixels_sum([item.border_start, item.padding_start, item.width, item.padding_end,
		item.border_end])
}

struct InlineExtraBoxMetrics {
mut:
	margin  CSSPixels
	border  CSSPixels
	padding CSSPixels
}

@[heap]
struct InlineTextNodeContext {
mut:
	chunks                     []TextNodeChunk
	next_chunk_index           int
	should_collapse_whitespace bool
	should_wrap_lines          bool
	should_respect_linebreaks  bool
	last_known_direction       ?platform.GlyphRunTextType
}

// InlineLevelIterator is pre-generated exactly like LibWeb's iterator: next()
// and lookahead are O(1), while tabs retain the accumulated width at the point
// they are shaped.
@[heap]
pub struct InlineLevelIterator {
mut:
	state                          &LayoutState    = unsafe { nil }
	containing_block               &BlockContainer = unsafe { nil }
	containing_block_used_values   &UsedValues     = unsafe { nil }
	current_node                   ?&Node
	next_node                      ?&Node
	layout_mode                    LayoutMode
	available_space                AvailableSpace
	parent_block_context           ?&BlockFormattingContext
	text_node_context              ?&InlineTextNodeContext
	extra_leading_metrics          ?InlineExtraBoxMetrics
	extra_trailing_metrics         ?InlineExtraBoxMetrics
	box_model_node_stack           []&NodeWithStyleAndBoxModelMetrics
	items                          []InlineLevelItem
	next_item_index                int
	accumulated_width_for_tabs     CSSPixels
	previous_chunk_can_break_after bool
}

pub fn InlineLevelIterator.new(mut state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) &InlineLevelIterator {
	mut iterator := &InlineLevelIterator{
		state:                        state
		containing_block:             containing_block
		containing_block_used_values: containing_block_used_values
		next_node:                    unsafe { &Node(containing_block) }.first_child()
		layout_mode:                  layout_mode
		available_space:              available_space
		parent_block_context:         parent_block_context
	}
	iterator.skip_to_next()
	iterator.generate_all_items()
	return iterator
}

fn (mut iterator InlineLevelIterator) generate_all_items() {
	for {
		item := iterator.generate_next_item() or { break }
		if item.type_ == .forced_break {
			iterator.accumulated_width_for_tabs = CSSPixels.new(0)
		} else {
			iterator.accumulated_width_for_tabs =
				iterator.accumulated_width_for_tabs.plus(item.border_box_width())
		}
		iterator.items << item
	}
}

pub fn (mut iterator InlineLevelIterator) next() ?InlineLevelItem {
	if iterator.next_item_index >= iterator.items.len {
		return none
	}
	item := iterator.items[iterator.next_item_index]
	iterator.next_item_index++
	return item
}

pub fn (iterator &InlineLevelIterator) items() []InlineLevelItem {
	return iterator.items
}

pub fn (iterator &InlineLevelIterator) next_non_whitespace_sequence_width() CSSPixels {
	mut next_width := CSSPixels.new(0)
	for index := iterator.next_item_index; index < iterator.items.len; index++ {
		next_item := iterator.items[index]
		if next_item.type_ == .forced_break {
			break
		}
		node := next_item.node or { break }
		if node.computed_values().text_wrap_mode() == .wrap {
			if next_item.type_ != .text || next_item.is_collapsible_whitespace {
				break
			}
			text_node := node.as_text_node() or { break }
			view := utf16_substring_for_line_box(text_node.text_for_rendering(),
				next_item.offset_in_node, next_item.length_in_node)
			if string_is_ascii_whitespace(view) {
				break
			}
		}
		next_width = next_width.plus(next_item.border_box_width())
	}
	return next_width
}

fn (mut iterator InlineLevelIterator) enter_node_with_box_model_metrics(node &NodeWithStyleAndBoxModelMetrics) {
	mut leading := iterator.extra_leading_metrics or { InlineExtraBoxMetrics{} }
	styled := unsafe { &NodeWithStyle(node) }
	mut used_values := iterator.state.get_mutable(styled)
	resolve_box_model_edges(styled.computed_values(), mut used_values,
		iterator.containing_block_used_values.content_width().to_double())
	leading.margin = leading.margin.plus(used_values.margin_left)
	leading.border = leading.border.plus(used_values.border_left)
	leading.padding = leading.padding.plus(used_values.padding_left)
	iterator.extra_leading_metrics = leading
	iterator.compute_relative_inset(styled, mut used_values)
	iterator.box_model_node_stack << node
}

fn (mut iterator InlineLevelIterator) exit_node_with_box_model_metrics() {
	if iterator.box_model_node_stack.len == 0 {
		return
	}
	mut trailing := iterator.extra_trailing_metrics or { InlineExtraBoxMetrics{} }
	node := iterator.box_model_node_stack.last()
	styled := unsafe { &NodeWithStyle(node) }
	used_values := iterator.state.get_mutable(styled)
	trailing.margin = trailing.margin.plus(used_values.margin_right)
	trailing.border = trailing.border.plus(used_values.border_right)
	trailing.padding = trailing.padding.plus(used_values.padding_right)
	iterator.extra_trailing_metrics = trailing
	iterator.box_model_node_stack.delete(iterator.box_model_node_stack.len - 1)
}

fn (mut iterator InlineLevelIterator) compute_relative_inset(node &NodeWithStyle, mut used_values UsedValues) {
	compute_relative_inset_for_node(node, mut used_values, iterator.containing_block_used_values)
}

fn (mut iterator InlineLevelIterator) next_inline_node_in_pre_order(current &Node, stay_within &Node) ?&Node {
	if child := current.first_child() {
		if child.display().is_inline_outside() && current.display().is_flow_inside()
			&& !current.is_replaced_box() && (!current.is_box() || !current.is_out_of_flow()) {
			return child
		}
	}
	mut node := current
	for {
		if next := node.next_sibling() {
			if iterator.stack_ends_with_node(node) {
				iterator.exit_node_with_box_model_metrics()
			}
			return next
		}
		parent := node.parent() or { return none }
		node = parent
		if iterator.stack_ends_with_node(node) {
			iterator.exit_node_with_box_model_metrics()
		}
		if layout_nodes_same(node, stay_within) {
			return none
		}
	}
	return none
}

fn (iterator &InlineLevelIterator) stack_ends_with_node(node &Node) bool {
	if iterator.box_model_node_stack.len == 0 {
		return false
	}
	last := iterator.box_model_node_stack.last()
	return layout_nodes_same(unsafe { &Node(last) }, node)
}

fn (mut iterator InlineLevelIterator) compute_next() {
	current := iterator.next_node or { return }
	mut next := iterator.next_inline_node_in_pre_order(current,
		unsafe { &Node(iterator.containing_block) })
	for {
		candidate := next or { break }
		// Referenced masks beneath a foreignObject belong to its surrounding SVG
		// formatting context and do not generate inline-level items here.
		if candidate.is_svg_mask_box() {
			next = candidate.next_sibling()
			continue
		}
		if candidate.is_inline() || candidate.is_out_of_flow() {
			break
		}
		next = iterator.next_inline_node_in_pre_order(candidate,
			unsafe { &Node(iterator.containing_block) })
	}
	iterator.next_node = next
}

fn (mut iterator InlineLevelIterator) skip_to_next() {
	if next := iterator.next_node {
		if box_model_node := next.as_node_with_style_and_box_model_metrics() {
			if next.display().is_flow_inside() && !next.is_out_of_flow() && !next.is_replaced_box() {
				iterator.enter_node_with_box_model_metrics(box_model_node)
			}
		}
	}
	iterator.current_node = iterator.next_node
	iterator.compute_next()
}

fn (mut iterator InlineLevelIterator) resolve_text_direction_from_context() platform.GlyphRunTextType {
	context := iterator.text_node_context or { return .context_dependent }
	mut next_known := ?platform.GlyphRunTextType(none)
	for index := context.next_chunk_index; index < context.chunks.len; index++ {
		type_ := context.chunks[index].text_type
		if type_ in [.ltr, .rtl] {
			next_known = type_
			break
		}
	}
	if last := context.last_known_direction {
		if next := next_known {
			if last != next {
				return if iterator.containing_block.computed_values().direction() == .ltr {
					.ltr
				} else {
					.rtl
				}
			}
		}
		return last
	}
	return next_known or { platform.GlyphRunTextType.context_dependent }
}

fn (mut iterator InlineLevelIterator) generate_next_item() ?InlineLevelItem {
	current := iterator.current_node or { return none }
	if text_node := current.as_text_node() {
		if iterator.text_node_context == none {
			iterator.enter_text_node(text_node)
		}
		mut context := iterator.text_node_context or { return none }
		is_first_chunk := context.next_chunk_index == 0
		if context.next_chunk_index >= context.chunks.len {
			iterator.text_node_context = none
			iterator.previous_chunk_can_break_after = false
			iterator.skip_to_next()
			return iterator.generate_next_item()
		}
		chunk := context.chunks[context.next_chunk_index]
		context.next_chunk_index++
		is_last_chunk := context.next_chunk_index >= context.chunks.len
		mut text_type := chunk.text_type
		if text_type in [.ltr, .rtl] {
			context.last_known_direction = text_type
		}
		if context.should_respect_linebreaks && chunk.has_breaking_newline {
			text_type = if chunk.is_all_whitespace { .end_padding } else { text_type }
		}
		if text_type == .context_dependent {
			text_type = iterator.resolve_text_direction_from_context()
		}
		if context.should_respect_linebreaks && chunk.has_breaking_newline {
			return InlineLevelItem{
				type_: .forced_break
			}
		}
		computed := text_node.Node.computed_values()
		letter_spacing := resolved_text_spacing_for_node(unsafe { &Node(text_node) },
			.letter_spacing).to_double()
		word_spacing :=
			resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .word_spacing).to_double()
		mut shaped_text := chunk.view
		mut x := 0.0
		if chunk.has_breaking_tab {
			tab_size := computed.tab_size()
			tab_width := if tab_size.is_length {
				resolve_font_dependent_length_for_node(unsafe { &Node(text_node) }, tab_size.length).to_double()
			} else {
				tab_size.number * (f64(chunk.font.glyph_width(u32(` `))) + word_spacing +
					letter_spacing)
			}
			accumulated := iterator.accumulated_width_for_tabs.to_double()
			mut stop_distance := if accumulated > 0 && tab_width > 0 {
				math.ceil(accumulated / tab_width) * tab_width - accumulated
			} else {
				tab_width
			}
			if stop_distance < f64(chunk.font.glyph_width(u32(`0`))) * 0.5 {
				stop_distance += tab_width
			}
			mut tab_count := 0
			for character in shaped_text.runes() {
				if character != `\t` {
					break
				}
				tab_count++
			}
			stop_distance *= tab_count
			units := utf16_code_units_for_line_box(shaped_text)
			shaped_text = string_from_utf16_code_units_for_line_box(units[tab_count..])
			x = stop_distance
		}
		glyph_run := platform.shape_text(f32(x), f32(letter_spacing), shaped_text, chunk.font,
			text_type)
		// The translated GlyphRun stores absolute glyph positions, so width()
		// already includes the initial tab-stop offset when glyphs follow the
		// tab. A tab-only chunk has no glyph from which to recover that offset.
		chunk_width := CSSPixels.nearest_value_for(if glyph_run.glyphs().len == 0 {
			x
		} else {
			f64(glyph_run.width())
		})
		is_empty_editable := chunk.length == 0 && text_node_is_inside_mutable_control(text_node)
		is_generated_empty_string := is_empty_editable
			|| (current.is_generated_for_pseudo_element() && chunk.length == 0)
		mut item := InlineLevelItem{
			type_:                     .text
			node:                      current
			glyph_run:                 glyph_run
			offset_in_node:            chunk.start
			length_in_node:            chunk.length
			width:                     chunk_width
			is_collapsible_whitespace: context.should_collapse_whitespace && chunk.is_all_whitespace
				&& !is_generated_empty_string
			can_break_before:          iterator.previous_chunk_can_break_after
		}
		iterator.previous_chunk_can_break_after = chunk.can_break_after
		iterator.add_extra_box_model_metrics_to_item(mut item, is_first_chunk, is_last_chunk)
		return item
	}

	if current.is_absolutely_positioned() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .absolutely_positioned_element
			node:  current
		}
	}
	if current.is_floating() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .floating_element
			node:  current
		}
	}
	if current.is_break_node() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .forced_break
			node:  current
		}
	}
	if current.is_list_item_marker_box() || !current.is_box() {
		iterator.skip_to_next()
		return iterator.generate_next_item()
	}

	box := current.as_box() or { return none }
	iterator.dimension_box_on_line(box)
	styled := current.as_node_with_style() or { return none }
	box_state := iterator.state.get(styled)
	mut item := InlineLevelItem{
		type_:         .element
		node:          current
		width:         box_state.content_width()
		padding_start: box_state.padding_left
		padding_end:   box_state.padding_right
		border_start:  box_state.border_left
		border_end:    box_state.border_right
		margin_start:  box_state.margin_left
		margin_end:    box_state.margin_right
	}
	iterator.add_extra_box_model_metrics_to_item(mut item, true, true)
	iterator.skip_to_next()
	return item
}

fn (mut iterator InlineLevelIterator) enter_text_node(text_node &TextNode) {
	computed := text_node.Node.computed_values()
	white_space_collapse := computed.white_space_collapse()
	should_wrap_lines := computed.text_wrap_mode() == .wrap
	should_respect_linebreaks := white_space_collapse in [.preserve, .preserve_breaks, .break_spaces]
	mut chunk_iterator := TextNodeChunkIterator.new(text_node, should_wrap_lines,
		should_respect_linebreaks)
	mut chunks := []TextNodeChunk{}
	for {
		chunk := chunk_iterator.next() or { break }
		chunks << chunk
	}
	// InlineLevelIterator::generate_next_item() synthesizes one empty chunk for
	// mutable form-control editing text. The V DOM does not materialize the
	// closed UA shadow root, so TreeBuilder records that fact on its equivalent
	// internal TextNode.
	if chunks.len == 0 && text_node.text_for_rendering().len == 0
		&& text_node_is_inside_mutable_control(text_node) {
		chunks << chunk_iterator.create_empty_chunk()
	}
	iterator.text_node_context = &InlineTextNodeContext{
		chunks:                     chunks
		should_collapse_whitespace: chunk_iterator.should_collapse_whitespace()
		should_wrap_lines:          should_wrap_lines
		should_respect_linebreaks:  should_respect_linebreaks
	}
}

// The upstream predicate reaches the shadow root host. UA shadow roots are
// represented directly in the V layout tree, so walk to the equivalent host.
fn text_node_is_inside_mutable_control(text_node &TextNode) bool {
	mut ancestor := unsafe { &Node(text_node) }.parent()
	for ancestor != none {
		current := ancestor or { break }
		if dom_node := current.dom_node() {
			if element := dom_node.as_element() {
				if element.is_html_element() && element.local_name() in ['input', 'textarea'] {
					return true
				}
			}
			if dom_node.is_editing_host() {
				return true
			}
		}
		ancestor = current.parent()
	}
	return false
}

fn (mut iterator InlineLevelIterator) dimension_box_on_line(box &Box) {
	styled := unsafe { &NodeWithStyle(box) }
	mut state := iterator.state.get_mutable(styled)
	// Empty button content is skipped by intrinsic sizing. Seed its UsedValues
	// before entering the nested BFC/FFC so V's value-passed LayoutState keeps
	// the same stable slot that C++'s LayoutState reference would expose.
	button_node := unsafe { &Node(box) }
	if node_uses_button_layout(button_node) {
		for wrapper in button_node.children() {
			for content in wrapper.children() {
				if !content.is_button_content_box_ {
					continue
				}
				content_styled := content.as_node_with_style() or { continue }
				iterator.state.get_mutable(content_styled)
			}
		}
	}
	available_width := iterator.available_space.width.to_px_or_zero().to_double()
	resolve_box_model_edges(styled.computed_values(), mut state, available_width)
	box_node := unsafe { &Node(box) }
	auto_size := box.auto_content_box_size()
	ratio_only_auto_box := !box_node.is_replaced_box() && box.preferred_aspect_ratio() != none
		&& styled.computed_values().size_value(.width).is_auto()
		&& styled.computed_values().size_value(.height).is_auto() && auto_size.width == none
		&& auto_size.height == none
	if !ratio_only_auto_box && (box_node.is_replaced_box() || box.has_auto_content_box_size()
		|| box.preferred_aspect_ratio() != none) {
		size := compute_replaced_size(box, iterator.available_space)
		state.set_content_width(size.width())
		state.set_content_height(size.height())
		result := layout_inside_independent_formatting_context_with_mode(mut iterator.state,
			unsafe { &Node(box) }, mut state, iterator.layout_mode, AvailableSpace.new(AvailableSize.make_definite(size.width()),
			AvailableSize.make_definite(size.height())))
		if box_node.is_replaced_box() && box_node.can_have_children()
			&& !box.has_auto_content_box_size()
			&& styled.computed_values().size_value(.height).is_auto() {
			state.set_content_height(result.automatic_content_height)
		}
		return
	}
	computed := styled.computed_values()
	preferred_width := computed.size_value(.width)
	mut width := CSSPixels.new(0)
	if preferred_width.is_min_content() {
		width = calculate_min_content_width(mut iterator.state, box)
	} else if preferred_width.is_max_content() {
		width = calculate_max_content_width(mut iterator.state, box)
	} else if preferred_width.is_fit_content() {
		width = calculate_fit_content_width(mut iterator.state, box, iterator.available_space.width)
	} else if preferred_width.is_auto()
		|| (preferred_width.contains_percentage() && !iterator.available_space.width.is_definite()) {
		minimum := calculate_min_content_width(mut iterator.state, box)
		maximum := calculate_max_content_width(mut iterator.state, box)
		if iterator.available_space.width.is_definite() {
			available :=
				iterator.available_space.width.to_px_or_zero().minus(state.margin_left).minus(state.border_left).minus(state.padding_left).minus(state.padding_right).minus(state.border_right).minus(state.margin_right)
			width = css_pixels_min(css_pixels_max(minimum, available), maximum)
		} else if iterator.available_space.width.is_min_content() {
			width = minimum
		} else {
			width = maximum
		}
	} else {
		width = resolve_layout_content_size(unsafe { &Node(box) }, preferred_width,
			iterator.available_space.width.to_px_or_zero(), state, true) or { CSSPixels.new(0) }
	}
	width = clamp_layout_content_size(unsafe { &Node(box) }, width,
		iterator.available_space.width.to_px_or_zero(), state, true)
	state.set_content_width(width)

	preferred_height := computed.size_value(.height)
	mut definite_height := ?CSSPixels(none)
	if !preferred_height.is_auto() && (!preferred_height.contains_percentage()
		|| iterator.available_space.height.is_definite()) {
		if resolved := resolve_layout_content_size(unsafe { &Node(box) }, preferred_height,
			iterator.available_space.height.to_px_or_zero(), state, false)
		{
			definite_height = clamp_layout_content_size(unsafe { &Node(box) }, resolved,
				iterator.available_space.height.to_px_or_zero(), state, false)
		}
	} else if preferred_height.is_auto() && box.preferred_aspect_ratio() != none {
		if resolved := resolve_content_height_for_node(mut iterator.state, styled, state, if iterator.available_space.height.is_definite() {
			iterator.available_space.height.to_px_or_zero().to_double()
		} else {
			none
		})
		{
			definite_height = clamp_layout_content_size(unsafe { &Node(box) }, css_px(resolved),
				iterator.available_space.height.to_px_or_zero(), state, false)
		}
	}
	available_height := if height := definite_height {
		state.set_content_height(height)
		state.set_has_definite_height(true)
		AvailableSize.make_definite(height)
	} else {
		AvailableSize.make_indefinite()
	}
	inside := layout_inside_independent_formatting_context_with_mode(mut iterator.state,
		unsafe { &Node(box) }, mut state, iterator.layout_mode, AvailableSpace.new(AvailableSize.make_definite(width),
		available_height))
	if definite_height == none {
		mut automatic_content_height := inside.automatic_content_height
		// FormattingContext::formatting_context_type_created_by_box() selects a
		// BlockFormattingContext for `display: math`, while
		// creates_block_formatting_context() deliberately remains false. The
		// parent BFC therefore resolves its auto height with CSS 2.2 10.6.3.
		if computed.display().is_math_inside() {
			if parent_context := iterator.parent_block_context {
				mut mutable_parent := unsafe { &BlockFormattingContext(parent_context) }
				automatic_content_height = mutable_parent.compute_auto_height_for_block_level_element(mut iterator.state,
					styled)
			}
		}
		automatic_height := clamp_layout_content_size(unsafe { &Node(box) },
			automatic_content_height, iterator.available_space.height.to_px_or_zero(), state, false)
		state.set_content_height(automatic_height)
	}
}

fn (mut iterator InlineLevelIterator) add_extra_box_model_metrics_to_item(mut item InlineLevelItem, add_leading_metrics bool, add_trailing_metrics bool) {
	if add_leading_metrics {
		if leading := iterator.extra_leading_metrics {
			item.margin_start = item.margin_start.plus(leading.margin)
			item.border_start = item.border_start.plus(leading.border)
			item.padding_start = item.padding_start.plus(leading.padding)
			iterator.extra_leading_metrics = none
		}
	}
	if add_trailing_metrics {
		if trailing := iterator.extra_trailing_metrics {
			item.margin_end = item.margin_end.plus(trailing.margin)
			item.border_end = item.border_end.plus(trailing.border)
			item.padding_end = item.padding_end.plus(trailing.padding)
			iterator.extra_trailing_metrics = none
		}
	}
}
