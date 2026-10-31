// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import math
import platform

pub enum InlineLevelItemType {
	text
	element
	block_level_box
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
	is_all_whitespace         bool
	can_break_before          bool
	trailing_whitespace       TrailingWhitespace
	// Whether an enclosing inline box's start edge is still waiting to attach
	// to content when an out-of-flow item is emitted.
	preceded_by_unattached_inline_start_edges bool
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
	return css_pixels_sum5(item.border_start, item.padding_start, item.width, item.padding_end,
		item.border_end)
}

fn overflow_break_applies_to_style(style &css.ComputedProperties, available_width AvailableSize) bool {
	if style.text_wrap_mode() != .wrap {
		return false
	}
	if style.overflow_wrap() == .anywhere || style.word_break() == .break_word {
		return true
	}
	return style.overflow_wrap() == .break_word && !available_width.is_min_content()
}

fn (item &InlineLevelItem) allows_overflow_break(available_width AvailableSize) bool {
	if item.type_ != .text || item.is_collapsible_whitespace || item.is_all_whitespace {
		return false
	}
	node := item.node or { return false }
	return overflow_break_applies_to_style(node.computed_values(), available_width)
}

fn trailing_whitespace_from_shaped_text(shaped platform.ShapedText) TrailingWhitespace {
	return TrailingWhitespace{
		length_in_code_units: shaped.trailing_whitespace.length_in_code_units
		inline_size: inline_advance_to_css_pixels(shaped.trailing_whitespace.advance, shaped.glyph_run.font())
	}
}

struct OverflowItemSplit {
	prefix    InlineLevelItem
	remainder InlineLevelItem
}

fn overflow_split_items(item &InlineLevelItem, node &Node, split int,
	prefix_run &platform.GlyphRun, remainder_run &platform.GlyphRun,
	prefix_trailing TrailingWhitespace, remainder_trailing TrailingWhitespace) (InlineLevelItem, InlineLevelItem) {
	prefix := InlineLevelItem{
		type_: .text
		node: node
		glyph_run: prefix_run
		offset_in_node: item.offset_in_node
		length_in_node: split - item.offset_in_node
		can_break_before: item.can_break_before
		trailing_whitespace: prefix_trailing
		preceded_by_unattached_inline_start_edges: item.preceded_by_unattached_inline_start_edges
		width: shaped_inline_width(prefix_run, 0)
		padding_start: item.padding_start
		border_start: item.border_start
		margin_start: item.margin_start
	}
	remainder := InlineLevelItem{
		type_: .text
		node: node
		glyph_run: remainder_run
		offset_in_node: split
		length_in_node: item.offset_in_node + item.length_in_node - split
		trailing_whitespace: remainder_trailing
		width: shaped_inline_width(remainder_run, 0)
		padding_end: item.padding_end
		border_end: item.border_end
		margin_end: item.margin_end
	}
	return prefix, remainder
}

// The node retains a sorted, immutable boundary vector. Binary lookup avoids
// rescanning and copying the complete text for every overflowing remainder.
fn sorted_grapheme_boundary_index(boundaries []int, offset int, after_equal bool) int {
	mut first := 0
	mut last := boundaries.len
	for first < last {
		middle := first + (last - first) / 2
		boundary := boundaries[middle]
		if boundary < offset || (after_equal && boundary == offset) {
			first = middle + 1
		} else {
			last = middle
		}
	}
	return first
}

fn grapheme_boundaries_between(boundaries []int, start int, end int) []int {
	if end <= start { return []int{} }
	first := sorted_grapheme_boundary_index(boundaries, start, true)
	last := sorted_grapheme_boundary_index(boundaries, end, false)
	// Array slices retain the immutable buffer. Rendered-text invalidation
	// replaces that buffer instead of mutating it beneath existing consumers.
	return boundaries[first..last]
}

fn has_sorted_grapheme_boundary(boundaries []int, offset int) bool {
	index := sorted_grapheme_boundary_index(boundaries, offset, false)
	return index < boundaries.len && boundaries[index] == offset
}

fn (item &InlineLevelItem) split_overflow_item_at_shaped_glyph(node &Node,
	boundaries []int, maximum_width CSSPixels,
	take_first_grapheme_when_none_fits bool) ?OverflowItemSplit {
	run := item.glyph_run or { return none }
	if run.text_type() == .rtl || run.glyphs_.len < 2 {
		return none
	}
	mut shaped_length := 0
	for glyph in run.glyphs_ {
		shaped_length += glyph.length_in_code_units
	}
	if shaped_length != item.length_in_node {
		return none
	}
	leading_width := css_pixels_sum3(item.margin_start, item.border_start, item.padding_start)
	mut split_glyph_index := -1
	mut split_code_units := 0
	mut code_units := run.glyphs_[0].length_in_code_units
	for glyph_index := 1; glyph_index < run.glyphs_.len; glyph_index++ {
		glyph := run.glyphs_[glyph_index]
		if glyph.length_in_code_units == 0 {
			continue
		}
		offset := item.offset_in_node + code_units
		if has_sorted_grapheme_boundary(boundaries, offset) {
			prefix_width := CSSPixels.nearest_value_for(f64(glyph.position.x))
			if leading_width.plus(prefix_width).raw_value() > maximum_width.raw_value() {
				if split_glyph_index < 0 && take_first_grapheme_when_none_fits {
					split_glyph_index = glyph_index
					split_code_units = code_units
				}
				break
			}
			split_glyph_index = glyph_index
			split_code_units = code_units
		}
		code_units += glyph.length_in_code_units
	}
	if split_glyph_index < 0 {
		return none
	}

	split_x := run.glyphs_[split_glyph_index].position.x
	mut prefix_run := run.slice_for_layout(0, split_glyph_index)
	mut remainder_run := run.translated_slice_for_layout(split_glyph_index,
		run.glyphs_.len - split_glyph_index, -split_x, 0)
	prefix_run.width_ = split_x
	remainder_run.width_ = run.width() - split_x
	prefix, remainder := overflow_split_items(item, node,
		item.offset_in_node + split_code_units, prefix_run, remainder_run, TrailingWhitespace{},
		TrailingWhitespace{})
	return OverflowItemSplit{prefix, remainder}
}

// Split an overflowing shaped text item only at extended grapheme boundaries.
// Reshaping both halves preserves ligatures and spacing at their new line edges.
fn (item &InlineLevelItem) split_for_overflow_break(maximum_width CSSPixels, take_first_grapheme_when_none_fits bool) ?(InlineLevelItem, InlineLevelItem) {
	node := item.node or { return none }
	text_node := node.as_text_node() or { return none }
	run := item.glyph_run or { return none }
	text := text_node.text_for_rendering()
	start := item.offset_in_node
	end := start + item.length_in_node
	if start < 0 || end <= start {
		return none
	}

	boundaries := grapheme_boundaries_between(text_node.grapheme_boundaries_for_rendered_text(),
		start, end)
	if boundaries.len == 0 {
		return none
	}
	if split := item.split_overflow_item_at_shaped_glyph(node, boundaries, maximum_width,
		take_first_grapheme_when_none_fits) {
		return split.prefix, split.remainder
	}
	if run.text_type() == .rtl {
		return none
	}

	letter_spacing := f32(resolved_text_spacing_for_shaping(node, .letter_spacing))
	word_spacing := f32(resolved_text_spacing_for_shaping(node, .word_spacing))
	leading_width := css_pixels_sum3(item.margin_start, item.border_start, item.padding_start)
	mut split := -1
	for boundary in boundaries {
		prefix_text := utf16_substring_for_line_box(text, start, boundary - start)
		shaped := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, prefix_text,
			run.font(), run.text_type())
		prefix_width := shaped_inline_width(shaped.glyph_run, 0)
		if leading_width.plus(prefix_width).raw_value() > maximum_width.raw_value() {
			break
		}
		split = boundary
	}
	if split < 0 {
		if !take_first_grapheme_when_none_fits {
			return none
		}
		split = boundaries[0]
	}

	prefix_text := utf16_substring_for_line_box(text, start, split - start)
	remainder_text := utf16_substring_for_line_box(text, split, end - split)
	prefix_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, prefix_text,
		run.font(), run.text_type())
	remainder_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
		remainder_text, run.font(), run.text_type())
	return overflow_split_items(item, node, split, prefix_shape.glyph_run,
		remainder_shape.glyph_run, trailing_whitespace_from_shaped_text(prefix_shape),
		trailing_whitespace_from_shaped_text(remainder_shape))
}

fn is_inline_flow_interrupting_block(node &Node) bool {
	metrics := node.as_node_with_style_and_box_model_metrics() or { return false }
	return metrics.is_inline_flow_interrupting_block()
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
	chromium_context_run       ?&platform.GlyphRun
	chromium_segment_runs      []ChromiumTextContextRun
	chromium_slice_cursor      ChromiumContextSliceCursor
	chunks                     []TextNodeChunk
	next_chunk_index           int
	should_collapse_whitespace bool
	should_wrap_lines          bool
	should_respect_linebreaks  bool
	last_known_direction       ?platform.GlyphRunTextType
	spacing_resolved           bool
	letter_spacing             f64
	word_spacing               f64
}

struct IntrinsicTextShapeCacheEntry {
	initial_x           f32
	letter_spacing      f32
	word_spacing        f32
	text                string
	font                &platform.Font = unsafe { nil }
	text_type           platform.GlyphRunTextType
	glyph_run           &platform.GlyphRun = unsafe { nil }
	trailing_whitespace platform.TrailingWhitespace
}

// InlineLevelIterator is pre-generated exactly like LibWeb's iterator: next()
// and lookahead are O(1), while tabs retain the accumulated width at the point
// they are shaped.
@[heap]
pub struct InlineLevelIterator {
mut:
	state                          &LayoutState = unsafe { nil }
	containing_block               &BlockContainer = unsafe { nil }
	containing_block_used_values   &UsedValues = unsafe { nil }
	current_node                   ?&Node
	next_node                      ?&Node
	layout_mode                    LayoutMode
	available_space                AvailableSpace
	parent_block_context           ?&BlockFormattingContext
	text_node_context              InlineTextNodeContext
	has_text_node_context          bool
	is_unidirectional_left_to_right bool
	extra_leading_metrics          ?InlineExtraBoxMetrics
	extra_trailing_metrics         ?InlineExtraBoxMetrics
	box_model_node_stack           []&NodeWithStyleAndBoxModelMetrics
	item_storage_                  &platform.Arena = unsafe { nil }
	items                          []InlineLevelItem
	next_item_index                int
	accumulated_width_for_tabs     CSSPixels
	previous_chunk_can_break_after bool
}

pub fn InlineLevelIterator.new(mut state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) &InlineLevelIterator {
	return new_inline_iterator_with_item_storage(mut state, containing_block, containing_block_used_values, layout_mode, available_space, parent_block_context, unsafe { nil })
}

fn new_inline_iterator_with_item_storage(mut state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext, storage &platform.Arena) &InlineLevelIterator {
	mut record_storage := unsafe { &platform.Arena(storage) }
	entry := if record_storage != unsafe { nil } { record_storage.enter() } else { platform.ArenaEntry{} }
	mut iterator := &InlineLevelIterator{
		item_storage_: storage
		state: state
		containing_block: containing_block
		containing_block_used_values: containing_block_used_values
		next_node: unsafe { &Node(containing_block) }.first_child()
		layout_mode: layout_mode
		available_space: available_space
		parent_block_context: parent_block_context
	}
	if record_storage != unsafe { nil } { record_storage.leave(entry) }
	// The iterator record has the same synchronous reader as its item vector.
	// Shaping and layout below publish separately owned state and glyphs, so
	// their allocations must use the caller again before generation starts.
	iterator.is_unidirectional_left_to_right = iterator.compute_is_unidirectional_left_to_right()
	iterator.skip_to_next()
	iterator.generate_all_items()
	iterator.shape_across_compatible_inline_nodes()
	return iterator
}

fn text_may_require_bidi_processing(text_node &TextNode) bool {
	text := text_node.text_for_rendering()
	if text.is_ascii() {
		return false
	}
	for code_point in text.runes() {
		bidi_class := dom.unicode_bidirectional_class(u32(code_point))
		if bidi_class in [
			.right_to_left,
			.right_to_left_arabic,
			.right_to_left_embedding,
			.right_to_left_isolate,
			.right_to_left_override,
			.left_to_right_embedding,
			.left_to_right_isolate,
			.left_to_right_override,
			.first_strong_isolate,
			.pop_directional_format,
			.pop_directional_isolate,
		] {
			return true
		}
	}
	return false
}

// Writing Modes' bidi paragraph classification. Keeping a provably LTR
// paragraph unidirectional prevents neutral punctuation from splitting shaping
// runs while retaining per-code-point direction for mixed and RTL content.
fn (mut iterator InlineLevelIterator) compute_is_unidirectional_left_to_right() bool {
	if iterator.containing_block.computed_values().direction() == .rtl {
		return false
	}
	chromium := unsafe { &Node(iterator.containing_block) }.document().font_rendering_policy() == .chromium
	mut node := unsafe { &Node(iterator.containing_block) }.first_child()
	for node != none {
		current := node or { break }
		if styled := current.as_node_with_style() {
			values := styled.computed_values()
			// Blink resolves an LTR isolate, as the UA style sheet makes every div
			// and every element with a dir attribute, of LTR text to LTR levels.
			// Only that text, checked below, can make its paragraph bidirectional.
			ltr_isolate := chromium && values.unicode_bidi() == .isolate
			if values.direction() == .rtl || (values.unicode_bidi() != .normal && !ltr_isolate) {
				return false
			}
		} else if text_node := current.as_text_node() {
			if text_may_require_bidi_processing(text_node) {
				return false
			}
		}

		mut next := iterator.next_inline_node_in_pre_order(current,
			unsafe { &Node(iterator.containing_block) })
		for {
			candidate := next or { break }
			if candidate.is_svg_mask_box() {
				next = candidate.next_sibling()
				continue
			}
			if candidate.is_inline() || candidate.is_out_of_flow()
				|| is_inline_flow_interrupting_block(candidate) {
				break
			}
			next = iterator.next_inline_node_in_pre_order(candidate,
				unsafe { &Node(iterator.containing_block) })
		}
		node = next
	}
	return true
}

fn (mut iterator InlineLevelIterator) generate_all_items() {
	for {
		item := iterator.generate_next_item() or { break }
		if item.type_ in [.forced_break, .block_level_box] {
			iterator.accumulated_width_for_tabs = CSSPixels.new(0)
		} else {
			iterator.accumulated_width_for_tabs =
				iterator.accumulated_width_for_tabs.plus(item.border_box_width())
		}
		reserve_inline_items_in_storage(mut iterator.items, 1, iterator.item_storage_)
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
		// Borrow the item so current V does not heap-promote a copy.
		next_item := unsafe { &iterator.items[index] }
		// Atomic inlines allow a break at their outer boundary even when their
		// own contents are nowrap. Do not reserve the following badge's width
		// while deciding whether the preceding word fits on this line.
		if next_item.type_ in [.forced_break, .block_level_box, .element] {
			break
		}
		node := next_item.node or { break }
		if node.computed_values().text_wrap_mode() == .wrap {
			if node.document().font_rendering_policy() == .chromium
				&& index > iterator.next_item_index && next_item.can_break_before { break }
			if next_item.type_ != .text || next_item.is_collapsible_whitespace {
				break
			}
			if next_item.is_all_whitespace {
				break
			}
		}
		next_width = next_width.plus(next_item.border_box_width())
	}
	return next_width
}

fn (iterator &InlineLevelIterator) next_non_whitespace_sequence_items() []InlineLevelItem {
	mut end := iterator.next_item_index
	for end < iterator.items.len {
		item := iterator.items[end]
		if item.type_ in [.forced_break, .block_level_box, .element] { break }
		node := item.node or { break }
		if node.document().font_rendering_policy() == .chromium
			&& node.computed_values().text_wrap_mode() == .wrap
			&& end > iterator.next_item_index && item.can_break_before { break }
		if node.computed_values().text_wrap_mode() == .wrap
			&& (item.type_ != .text || item.is_collapsible_whitespace || item.is_all_whitespace) { break }
		end++
	}
	return iterator.items[iterator.next_item_index..end]
}

pub fn (iterator &InlineLevelIterator) next_non_whitespace_text_allows_overflow_break() bool {
	if iterator.next_item_index >= iterator.items.len {
		return false
	}
	return iterator.items[iterator.next_item_index].allows_overflow_break(iterator.available_space.width)
}

fn (mut iterator InlineLevelIterator) enter_node_with_box_model_metrics(node &NodeWithStyleAndBoxModelMetrics) {
	mut leading := iterator.extra_leading_metrics or { InlineExtraBoxMetrics{} }
	styled := unsafe { &NodeWithStyle(node) }
	mut used_values := iterator.state.get_mutable(styled)
	resolve_box_model_edges(styled.computed_values(), mut used_values, iterator.containing_block_used_values.content_width().to_double())
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
		if (child.display().is_inline_outside() || child.is_out_of_flow()
			|| is_inline_flow_interrupting_block(child))
			&& current.display().is_flow_inside()
			&& !is_inline_flow_interrupting_block(current) && !current.is_atomic_inline()
			&& (!current.is_box() || !current.is_out_of_flow()) {
			return child
		}
	}
	mut node := unsafe { current }
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
	mut next := iterator.next_inline_node_in_pre_order(current, unsafe { &Node(iterator.containing_block) })
	for {
		candidate := next or { break }
		// Referenced masks beneath a foreignObject belong to its surrounding SVG
		// formatting context and do not generate inline-level items here.
		if candidate.is_svg_mask_box() {
			next = candidate.next_sibling()
			continue
		}
		if candidate.is_inline() || candidate.is_out_of_flow()
			|| is_inline_flow_interrupting_block(candidate) {
			break
		}
		next = iterator.next_inline_node_in_pre_order(candidate, unsafe { &Node(iterator.containing_block) })
	}
	iterator.next_node = next
}

fn (mut iterator InlineLevelIterator) skip_to_next() {
	if next := iterator.next_node {
		if box_model_node := next.as_node_with_style_and_box_model_metrics() {
			if !next.is_break_node() && !next.is_list_item_marker_box() && next.is_inline()
				&& next.display().is_flow_inside()
				&& !next.is_out_of_flow() && !next.is_atomic_inline() {
				iterator.enter_node_with_box_model_metrics(box_model_node)
			}
		}
	}
	iterator.current_node = iterator.next_node
	iterator.compute_next()
}

fn (mut iterator InlineLevelIterator) resolve_text_direction_from_context() platform.GlyphRunTextType {
	if !iterator.has_text_node_context { return .context_dependent }
	context := &iterator.text_node_context
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
		if !iterator.has_text_node_context {
			iterator.enter_text_node(text_node)
		}
		mut context := &iterator.text_node_context
		is_first_chunk := context.next_chunk_index == 0
		if context.next_chunk_index >= context.chunks.len {
			iterator.has_text_node_context = false
			iterator.text_node_context = InlineTextNodeContext{}
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
		// Item generation is synchronous. Resolve immutable text-node spacing
		// once for this context, after preserved-break-only chunks return.
		if !context.spacing_resolved {
			context.letter_spacing = resolved_text_spacing_for_shaping(unsafe { &Node(text_node) }, .letter_spacing)
			context.word_spacing = resolved_text_spacing_for_shaping(unsafe { &Node(text_node) }, .word_spacing)
			context.spacing_resolved = true
		}
		letter_spacing := context.letter_spacing
		word_spacing := context.word_spacing
		mut shaped_text := chunk.view
		mut x := 0.0
		if chunk.has_breaking_tab {
			tab_size := computed.tab_size()
			tab_width := if tab_size.is_length {
				resolve_font_dependent_length_for_node(unsafe { &Node(text_node) }, tab_size.length).to_double()
			} else {
				tab_size.number * (f64(chunk.font.glyph_width(u32(` `))) + word_spacing + letter_spacing)
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
		shaped := if run := context.chromium_context_run {
			chromium_context_slice_with_cursor(run, chunk, mut context.chromium_slice_cursor) or {
				iterator.shape_text_for_layout(text_node, f32(x), f32(letter_spacing), f32(word_spacing), shaped_text, chunk.font, text_type)
			}
		} else {
			chromium_segmented_context_slice_with_cursor(context.chromium_segment_runs, chunk,
				mut context.chromium_slice_cursor) or {
				iterator.shape_text_for_layout(text_node, f32(x), f32(letter_spacing), f32(word_spacing), shaped_text, chunk.font, text_type)
			}
		}
		glyph_run := shaped.glyph_run
		chunk_width := shaped_inline_width(glyph_run, x)
		is_empty_editable := chunk.length == 0 && text_node.produces_line_box_fragment_when_empty_
		is_generated_empty_string := is_empty_editable
			|| (text_node.retains_empty_generated_fragment_ && chunk.length == 0)
		mut item := InlineLevelItem{
			type_: .text
			node: current
			glyph_run: glyph_run
			offset_in_node: chunk.start
			length_in_node: chunk.length
			width: chunk_width
			is_collapsible_whitespace: context.should_collapse_whitespace && chunk.is_all_whitespace
				&& !is_generated_empty_string
			is_all_whitespace: chunk.is_all_whitespace
			can_break_before: iterator.previous_chunk_can_break_after
			trailing_whitespace: if chunk.is_all_whitespace {
				TrailingWhitespace{
					length_in_code_units: chunk.length
					inline_size: chunk_width
				}
			} else {
				TrailingWhitespace{
					length_in_code_units: shaped.trailing_whitespace.length_in_code_units
					inline_size: CSSPixels.nearest_value_for(shaped.trailing_whitespace.advance)
				}
			}
		}
		iterator.previous_chunk_can_break_after = chunk.can_break_after
		iterator.add_extra_box_model_metrics_to_item(mut item, is_first_chunk, is_last_chunk)
		// The zero-length generated fragment anchors its inline ancestor's box
		// geometry. Its closing edges are derived from that ancestor's used values;
		// they do not advance the following text in upstream's retained line.
		if text_node.retains_empty_generated_fragment_ && chunk.length == 0 {
			item.padding_end = CSSPixels.new(0)
			item.border_end = CSSPixels.new(0)
			item.margin_end = CSSPixels.new(0)
		}
		return item
	}

	if current.is_absolutely_positioned() {
		mut has_unattached_inline_start_edges := false
		if leading := iterator.extra_leading_metrics {
			has_unattached_inline_start_edges = leading.margin.raw_value() != 0
				|| leading.border.raw_value() != 0 || leading.padding.raw_value() != 0
		}
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .absolutely_positioned_element
			node: current
			preceded_by_unattached_inline_start_edges: has_unattached_inline_start_edges
		}
	}
	if current.is_floating() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .floating_element
			node: current
		}
	}
	if current.is_break_node() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .forced_break
			node: current
		}
	}
	if current.is_list_item_marker_box() {
		marker := current.as_list_item_marker_box() or { return none }
		if marker.list_style_position() != .inside {
			// An outside marker owns an independent inline formatting context and
			// does not participate in the list item's principal inline run.
		iterator.next_node = current.next_sibling()
		iterator.skip_to_next()
		return iterator.generate_next_item()
	}
	}
	if !current.is_box() {
		iterator.skip_to_next()
		return iterator.generate_next_item()
	}

	box := current.as_box() or { return none }
	if is_inline_flow_interrupting_block(current) && !current.is_list_item_marker_box() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .block_level_box
			node: current
		}
	}
	iterator.dimension_box_on_line(box)
	styled := current.as_node_with_style() or { return none }
	box_state := iterator.state.get(styled)
	mut item := InlineLevelItem{
		type_: .element
		node: current
		width: box_state.content_width()
		padding_start: box_state.padding_left
		padding_end: box_state.padding_right
		border_start: box_state.border_left
		border_end: box_state.border_right
		margin_start: box_state.margin_left
		margin_end: box_state.margin_right
	}
	iterator.add_extra_box_model_metrics_to_item(mut item, true, true)
	if current.is_list_item_marker_box() {
		// Treat an inside marker atomically in its list item's IFC; its own text
		// was already laid out by layout_list_item_marker().
		iterator.next_node = current.next_sibling()
	}
	// Blink's line breaker always offers a soft wrap opportunity after an
	// atomic inline, whatever character follows it, such as 4chan's thread
	// status icon followed by `&nbsp;[Reply]`.
	iterator.previous_chunk_can_break_after = current.document().font_rendering_policy() == .chromium
	iterator.skip_to_next()
	return item
}

fn (iterator &InlineLevelIterator) shape_text_for_layout(text_node &TextNode, initial_x f32, letter_spacing f32, word_spacing f32, text string, font &platform.Font, text_type platform.GlyphRunTextType) platform.ShapedText {
	cache_start, cache_end := intrinsic_shape_cache_range(text_node, text)
	for cache_position := cache_start; cache_position < cache_end; cache_position++ {
		cached := text_node.cached_intrinsic_text_shapes_[intrinsic_shape_cache_entry_index(text_node, cache_position)]
		if cached.initial_x == initial_x && cached.letter_spacing == letter_spacing
			&& cached.word_spacing == word_spacing
			&& cached.text == text && voidptr(cached.font) == voidptr(font)
			&& cached.text_type == text_type {
			return platform.ShapedText{
				glyph_run: cached.glyph_run.fork_for_layout()
				trailing_whitespace: cached.trailing_whitespace
			}
		}
	}

	if iterator.layout_mode == .intrinsic_sizing {
		use_document := cache_uses_entered_document_storage(text_node.Node.document())
		mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		persistent := platform.enter_persistent_if(!use_document)
		shaped := platform.shape_text_with_spacing(initial_x, letter_spacing, word_spacing, text, font, text_type)
		mut mutable_text_node := unsafe { &TextNode(text_node) }
		mutable_text_node.cached_intrinsic_text_shapes_ << IntrinsicTextShapeCacheEntry{
			initial_x: initial_x
			letter_spacing: letter_spacing
			word_spacing: word_spacing
			text: text.clone()
			font: font
			text_type: text_type
			glyph_run: shaped.glyph_run
			trailing_whitespace: shaped.trailing_whitespace
		}
		append_intrinsic_shape_cache_order(mut mutable_text_node)
		platform.leave_persistent(persistent)
		retained.finish()
		return platform.ShapedText{
			glyph_run: shaped.glyph_run.fork_for_layout()
			trailing_whitespace: shaped.trailing_whitespace
		}
	}
	return platform.shape_text_with_spacing(initial_x, letter_spacing, word_spacing, text, font, text_type)
}

fn (mut iterator InlineLevelIterator) enter_text_node(text_node &TextNode) {
	refresh_inline_chunk_font_owner(text_node)
	computed := text_node.Node.computed_values()
	white_space_collapse := computed.white_space_collapse()
	should_wrap_lines := computed.text_wrap_mode() == .wrap
	should_respect_linebreaks := white_space_collapse in [.preserve, .preserve_breaks, .break_spaces]
	mut chunks := []TextNodeChunk{}
	mut cached_chunks_valid := false
	font_generation := css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
	if cached := text_node.cached_inline_chunks_ {
		// The cached chunks are immutable after construction; sharing their
		// backing array avoids copying it for each intrinsic-sizing pass. A font
		// load replaces the cascade, so chunks retaining the previous platform
		// fonts must be shaped again.
		if text_node.cached_font_environment_generation_ == font_generation {
		chunks = unsafe { cached }
		cached_chunks_valid = true
		}
	}
	if !cached_chunks_valid {
		use_document := cache_uses_entered_document_storage(text_node.Node.document())
		mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		persistent := platform.enter_persistent_if(!use_document)
		chunks = retained_text_node_chunks(text_node, should_wrap_lines, should_respect_linebreaks,
			if iterator.is_unidirectional_left_to_right {
				TextDirectionMode.unidirectional_left_to_right
			} else {
				TextDirectionMode.per_code_point
			})
		mut mutable_text_node := unsafe { &TextNode(text_node) }
		mutable_text_node.cached_inline_chunks_ = chunks
		mutable_text_node.cached_font_environment_generation_ = css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
		mutable_text_node.cached_intrinsic_text_shapes_.clear()
		platform.leave_persistent(persistent)
		retained.finish()
	}
	// Every retained chunk emits exactly one item, including whitespace and
	// forced line breaks. Reserve their known demand once instead of growing
	// and copying the wide item vector while emitting that text node.
	reserve_inline_items_in_storage(mut iterator.items, chunks.len, iterator.item_storage_)
	context_run := iterator.chromium_single_script_context_run(text_node, chunks)
	segment_runs := if context_run == none
		&& text_node.Node.document().font_rendering_policy() == .chromium {
		iterator.chromium_segmented_context_runs(text_node, chunks)
	} else { []ChromiumTextContextRun{} }
	iterator.has_text_node_context = true
	iterator.text_node_context = InlineTextNodeContext{
		chromium_context_run: context_run
		chromium_segment_runs: segment_runs
		chunks: chunks
		should_collapse_whitespace: white_space_collapse in [.collapse, .preserve_breaks]
		should_wrap_lines: should_wrap_lines
		should_respect_linebreaks: should_respect_linebreaks
	}
}

fn is_native_form_control_box(node &Node) bool {
	if node.is_text_input_box() || node.is_textarea_box() {
		return true
	}
	dom_node := node.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'input'
		&& element.get_attribute_value('type').trim_space().to_lower() == 'range'
}

fn (mut iterator InlineLevelIterator) dimension_box_on_line(box &Box) {
	styled := unsafe { &NodeWithStyle(box) }
	mut state := iterator.state.get_mutable(styled)
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
		computed := styled.computed_values()
		if is_native_form_control_box(box_node) {
			if auto_height := auto_size.height {
				preferred_height := computed.size_value(.height)
				minimum_height := computed.size_value(.min_height)
				maximum_height := computed.size_value(.max_height)
				minimum_constraint_is_active := !minimum_height.is_auto()
					&& size.height().raw_value() > auto_height.raw_value()
				maximum_constraint_is_active := !maximum_height.is_auto()
					&& !maximum_height.is_none()
					&& !should_treat_replaced_max_as_none(maximum_height, iterator.available_space.height)
					&& size.height().raw_value() < auto_height.raw_value()
				if !preferred_height.is_intrinsic_sizing_constraint()
					&& (minimum_constraint_is_active || maximum_constraint_is_active) {
					state.set_has_definite_height(true)
				}
			}
		}
		result := layout_inside_independent_formatting_context_with_mode(mut iterator.state, unsafe { &Node(box) }, mut state, iterator.layout_mode, AvailableSpace.new(AvailableSize.make_definite(size.width()), AvailableSize.make_definite(size.height())))
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
	if box_node.is_table_wrapper() {
		// BlockFormattingContext::compute_width() gives a table wrapper the width
		// its table box's own algorithm produces, before any shrink-to-fit pass.
		// An inline-table therefore honours an intrinsic sizing keyword on the
		// table box, which the wrapper's own max-content measure would discard.
		width = compute_table_wrapper_content_width(mut iterator.state, box_node, mut state, iterator.available_space.width.to_px_or_zero())
	} else if preferred_width.is_min_content() {
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
		width = resolve_layout_content_size(unsafe { &Node(box) }, preferred_width, iterator.available_space.width.to_px_or_zero(), state, true) or { CSSPixels.new(0) }
	}
	// A percentage maximum is cyclic while measuring an atomic inline's
	// intrinsic contribution. Keep its initial 'none' value in that pass;
	// resolving it against the placeholder zero erases the containing flex
	// item's content width. The final definite layout still applies the maximum.
	if computed.size_value(.max_width).contains_percentage()
		&& should_treat_max_width_as_none(iterator.state, box_node, iterator.available_space.width) {
		minimum := resolve_layout_content_size(box_node, computed.size_value(.min_width),
			iterator.available_space.width.to_px_or_zero(), state, true) or { CSSPixels.new(0) }
		width = css_pixels_max(width, minimum)
	} else {
		width = clamp_layout_content_size(box_node, width, iterator.available_space.width.to_px_or_zero(), state, true)
	}
	state.set_content_width(width)

	preferred_height := computed.size_value(.height)
	mut definite_height := ?CSSPixels(none)
	if !preferred_height.is_auto() && (!preferred_height.contains_percentage()
		|| iterator.available_space.height.is_definite()) {
		if resolved := resolve_layout_content_size(unsafe { &Node(box) }, preferred_height, iterator.available_space.height.to_px_or_zero(), state, false) {
			definite_height = clamp_layout_content_size(unsafe { &Node(box) }, resolved, iterator.available_space.height.to_px_or_zero(), state, false)
		}
	} else if preferred_height.is_auto() && box.preferred_aspect_ratio() != none {
		mut containing_block_height := ?f64(none)
		if iterator.available_space.height.is_definite() {
			containing_block_height = iterator.available_space.height.to_px_or_zero().to_double()
		}
		if resolved := resolve_content_height_for_node(mut iterator.state, styled, state, containing_block_height) {
			definite_height = clamp_layout_content_size(unsafe { &Node(box) }, css_px(resolved), iterator.available_space.height.to_px_or_zero(), state, false)
		}
	}
	mut height_establishes_definite_containing_block := definite_height != none
		&& computed_height_establishes_definite_containing_block_height(preferred_height)
	if height := definite_height {
		state.set_content_height(height)
		if height_establishes_definite_containing_block {
			state.set_has_definite_height(true)
		}
	}
	button_content_box_became_definite := make_button_content_box_definite(mut iterator.state,
		box_node, mut state,
		if iterator.available_space.height.is_definite() {
			?CSSPixels(iterator.available_space.height.to_px_or_zero())
		} else {
			none
		})
	if button_content_box_became_definite {
		definite_height = state.content_height()
		height_establishes_definite_containing_block = true
	}
	available_height := if height := definite_height {
		state.set_content_height(height)
		if height_establishes_definite_containing_block {
			state.set_has_definite_height(true)
			AvailableSize.make_definite(height)
		} else {
			AvailableSize.make_indefinite()
		}
	} else {
		AvailableSize.make_indefinite()
	}
	inside := layout_inside_independent_formatting_context_with_mode(mut iterator.state, unsafe { &Node(box) }, mut state, iterator.layout_mode, AvailableSpace.new(AvailableSize.make_definite(width), available_height))
	if definite_height == none {
		// The independent formatting run already resolved the atomic root's auto
		// height. Rewalking its children through the enclosing BFC would leak that
		// context's still-pending collapsed margin across the atomic boundary.
		automatic_height := clamp_layout_content_size(unsafe { &Node(box) }, inside.automatic_content_height, iterator.available_space.height.to_px_or_zero(), state, false)
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
