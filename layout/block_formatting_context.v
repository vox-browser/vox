module layout

import css

// Translation of Ladybird's BlockFormattingContext normal-flow core:
// margin collapsing, floats and clearance, independent contexts, list-item
// markers, and out-of-flow descendants. Multicol and non-horizontal writing
// modes remain separate parity work tracked in layout/PORT_STATUS.md.

// BlockFormattingContext::BlockMarginState — accumulates the collapsible top/bottom margins of adjoining
// block boxes so their margins collapse to a single value (the larger positive plus the smaller negative).
struct BlockMarginState {
mut:
	current_positive_collapsible_margin f64
	current_negative_collapsible_margin f64
	// The single block container (if any) whose final Y-position is still being determined because its top
	// margin may collapse with the top margins of its in-flow children. C++ stores an escaping callback
	// (`register_block_container_y_position_update_callback`) that repositions the box; V closures capture
	// value types by value, so the port stores the box's UsedValues and the base Y the callback repositions
	// it to, and re-runs the placement in update_block_waiting_for_final_y_position.
	waiting_box        ?&UsedValues
	waiting_box_base_y f64
	// A waiting box with clearance never moves above its clearance position.
	waiting_box_min_y ?f64
	// Whether the last in-flow child's bottom margin has already been collapsed into the running state (so
	// the parent must not reset it when finishing that child).
	box_last_in_flow_child_margin_bottom_collapsed bool
}

// BlockMarginState::add_margin — fold a margin into the collapsible state (positives keep the max, negatives
// keep the min).
fn (mut m BlockMarginState) add_margin(margin f64) {
	if margin < 0 {
		if margin < m.current_negative_collapsible_margin {
			m.current_negative_collapsible_margin = margin
		}
	} else {
		if margin > m.current_positive_collapsible_margin {
			m.current_positive_collapsible_margin = margin
		}
	}
}

// BlockMarginState::current_collapsed_margin.
fn (m &BlockMarginState) current_collapsed_margin() f64 {
	return m.current_positive_collapsible_margin + m.current_negative_collapsible_margin
}

// The next in-flow placement consumes the pending collapsed margin unless a
// block container is still waiting for that margin to settle its own position.
fn (m &BlockMarginState) pending_margin_for_next_box() f64 {
	if m.has_block_container_waiting_for_final_y_position() {
		return 0
	}
	return m.current_collapsed_margin()
}

// BlockMarginState::has_block_container_waiting_for_final_y_position.
fn (m &BlockMarginState) has_block_container_waiting_for_final_y_position() bool {
	return m.waiting_box != none
}

// BlockMarginState::register_block_container_y_position_update_callback (port form: store the box + base Y).
fn (mut m BlockMarginState) register_block_container_y_position_update(box &UsedValues, base_y f64) {
	m.waiting_box = box
	m.waiting_box_base_y = base_y
	m.waiting_box_min_y = none
}

// CSS 2.1 §9.5.2: a box with clearance keeps its top margin collapsing with its
// first in-flow children, but its top border edge is the greater of the
// clearance position and its hypothetical position after those margins.
fn (mut m BlockMarginState) register_cleared_block_container_y_position_update(box &UsedValues, clearance ClearanceIntroduction) {
	m.waiting_box = box
	m.waiting_box_base_y = clearance.hypothetical_base_y
	m.waiting_box_min_y = clearance.y
	m.current_positive_collapsible_margin = clearance.positive_margin
	m.current_negative_collapsible_margin = clearance.negative_margin
}

// BlockMarginState::unregister_block_container_y_position_update_callback.
fn (mut m BlockMarginState) unregister_block_container_y_position_update() {
	m.waiting_box = none
}

// BlockMarginState::update_block_waiting_for_final_y_position — reposition the waiting block container using
// the now-known collapsed margin (the port form of invoking the stored callback, which called
// place_block_level_element_in_normal_flow_vertically(box, base_y + collapsed_margin)).
fn (m &BlockMarginState) update_block_waiting_for_final_y_position() {
	mut box := m.waiting_box or { return }
	mut y := m.waiting_box_base_y + m.current_collapsed_margin()
	if min_y := m.waiting_box_min_y {
		if y < min_y {
			y = min_y
		}
	}
	place_block_level_element_in_normal_flow_vertically(mut box, y)
}

// BlockMarginState::reset.
fn (mut m BlockMarginState) reset() {
	m.waiting_box = none
	m.waiting_box_min_y = none
	m.current_positive_collapsible_margin = 0
	m.current_negative_collapsible_margin = 0
}

// FormattingContext::creates_block_formatting_context.
fn creates_block_formatting_context(box &NodeWithStyle) bool {
	node := unsafe { &Node(box) }
	if !node.is_box() {
		return false
	}
	if node.is_list_item_marker_box() {
		return true
	}
	display := node.display()
	// Replaced elements do not create BFCs. None of the generic Box subclasses
	// are replaced; concrete replaced boxes set this flag when constructed.
	if node.is_replaced_box() {
		return false
	}
	if display.is_table_inside() || display.is_flex_inside() || display.is_grid_inside() {
		return false
	}
	if node.is_root_element() || node.is_floating() || node.is_absolutely_positioned()
		|| display.is_inline_block() || display.is_table_cell() || display.is_table_caption() {
		return true
	}
	computed := box.computed_values()
	overflow_x := computed.overflow_x()
	overflow_y := computed.overflow_y()
	if (overflow_x != .visible && overflow_x != .clip)
		|| (overflow_y != .visible && overflow_y != .clip) {
		return true
	}
	if display.is_flow_root_inside() || node.has_layout_containment()
		|| node.has_paint_containment() {
		return true
	}
	continue_value := computed.continue_value()
	if continue_value == .collapse || continue_value == .discard {
		return true
	}
	// https://drafts.csswg.org/css-conditional-5/#valdef-container-type-size
	// Size and inline-size containers establish an independent formatting context.
	container_type := computed.container_type()
	if container_type.is_size_container || container_type.is_inline_size_container {
		return true
	}
	if parent := node.parent() {
		parent_display := parent.display()
		if parent_display.is_flex_inside() || parent_display.is_grid_inside() {
			return true
		}
	}
	if computed.establishes_multi_column_container() {
		return true
	}
	if node.is_fieldset_box() {
		return true
	}
	// https://html.spec.whatwg.org/multipage/rendering.html#button-layout
	// An element using button layout establishes a new formatting context for
	// its contents.
	if node_uses_button_layout(node) {
		return true
	}
	return false
}

fn computed_multicol_column_count(computed &css.ComputedValues) ?int {
	return computed.column_count()
}

// https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk
// Find the ancestor whose used height supplies the percentage basis, walking
// through auto-height block containers until the initial containing block.
fn containing_block_height_to_resolve_percentage_in_quirks_mode(state &LayoutState, box &Node) CSSPixels {
	mut containing_block := box.containing_block()
	for containing_block != none {
		current_box := containing_block or { break }
		current := unsafe { &Node(current_box) }
		styled := current.as_node_with_style() or { return CSSPixels.new(0) }
		used_values := state.try_get(styled) or { return CSSPixels.new(0) }
		if current.is_viewport() {
			return used_values.content_height()
		}
		if current.display().is_table_cell() {
			return CSSPixels.new(0)
		}
		if !property_is_auto(current.computed_values(), .height) {
			return used_values.content_height()
		}
		if current.is_absolutely_positioned() || current.as_block_container() == none
			|| current.is_table_wrapper() {
			return used_values.content_height()
		}
		containing_block = current.containing_block()
	}
	return CSSPixels.new(0)
}

fn percentage_height_quirk_applies(box &Node, computed &css.ComputedProperties) bool {
	if !box.document().in_quirks_mode() || box.is_anonymous() || box.is_in_ua_internal_shadow_tree()
		|| !property_is_percentage(computed, .height) || box.is_absolutely_positioned() {
		return false
	}
	display := box.display()
	if display.is_table_inside() || display.is_table_row() || display.is_table_row_group()
		|| display.is_table_header_group() || display.is_table_footer_group()
		|| display.is_table_cell() || display.is_table_caption() {
		return false
	}
	if parent := box.parent() {
		if parent.display().is_flex_inside() || parent.display().is_grid_inside() {
			return false
		}
	}
	return true
}

fn multicol_column_gap(node &Node, available_width CSSPixels) CSSPixels {
	gap := node.computed_values().gap_value(.column_gap)
	if gap.is_normal {
		return node.computed_values().font_size()
	}
	return gap.length_percentage.to_px(layout_length_resolution_context(node), available_width)
}

fn multicol_specified_column_width(node &Node, available_width CSSPixels) CSSPixels {
	width := resolve_layout_size(node, node.computed_values().column_width(), available_width) or { CSSPixels.new(1) }
	return css_pixels_max(CSSPixels.new(1), width)
}

// https://drafts.csswg.org/css-multicol/#pseudo-algorithm
fn determine_used_multicol_column_count(node &Node, available_width CSSPixels) ?int {
	computed := node.computed_values()
	column_width_is_auto := computed.column_width().is_auto()
	column_count := computed_multicol_column_count(computed)
	if !computed.establishes_multi_column_container() {
		return none
	}
	if column_width_is_auto {
		return column_count
	}
	gap := multicol_column_gap(node, available_width)
	column_width := multicol_specified_column_width(node, available_width)
	fit_count := (available_width.plus(gap).divided_by(column_width.plus(gap))).to_int()
	clamped_fit_count := if fit_count > 1 { fit_count } else { 1 }
	if specified_count := column_count {
		return if specified_count < clamped_fit_count { specified_count } else { clamped_fit_count }
	}
	return clamped_fit_count
}

fn determine_used_multicol_column_width(node &Node, available_width CSSPixels, column_count int) CSSPixels {
	gap := multicol_column_gap(node, available_width)
	width := available_width.plus(gap).divided_by_float(f64(column_count)).minus(gap)
	return css_pixels_max(CSSPixels.new(0), width)
}

fn box_should_avoid_floats(box &Node) bool {
	if box.is_floating() || box.is_absolutely_positioned() {
		return false
	}
	if box.display().is_flex_inside() || box.display().is_grid_inside()
		|| box.display().is_table_inside() || box.is_replaced_box() {
		return true
	}
	styled := box.as_node_with_style() or { return false }
	return creates_block_formatting_context(styled)
}

// BlockFormattingContext::margins_collapse_through (CSS 2.1 §8.3.1) — whether a box's own top and bottom
// margins are adjoining (they collapse "through" the box): it establishes no BFC, has zero border-box
// height, has no clearance, and every in-flow child also collapses through.
fn margins_collapse_through(box &NodeWithStyle, state &LayoutState) bool {
	if box.computed_values().clear() != .none_ {
		return false
	}
	if creates_block_formatting_context(box) {
		return false
	}
	display := box.computed_values().display()
	if display.is_flex_inside() || display.is_grid_inside() {
		return false
	}
	box_state := state.try_get(box) or { return false }
	if box_state.border_box_height().to_double() != 0 {
		return false
	}
	box_node := unsafe { &Node(box) }
	for child in box_node.children() {
		if !child.is_box() || child.is_out_of_flow() {
			continue
		}
		child_nws := child.as_node_with_style() or { continue }
		if !margins_collapse_through(child_nws, state) {
			return false
		}
	}
	return true
}

// BlockFormattingContext::compute_auto_height_for_block_level_element,
// CSS 2.2 10.6.3. The bottom margin of the last in-flow child collapses
// through a borderless, paddingless parent and therefore is not part of that
// parent's content height.
fn (mut bfc BlockFormattingContext) compute_auto_height_for_block_level_element(mut state LayoutState, box &NodeWithStyle) CSSPixels {
	box_node := unsafe { &Node(box) }
	if box_node.has_size_containment() {
		return box_node.explicit_intrinsic_inner_height() or { CSSPixels.new(0) }
	}
	box_state := state.get(box)
	children := box_node.children()
	for index := children.len - 1; index >= 0; index-- {
		child := children[index]
		if child.is_absolutely_positioned() || child.is_floating() {
			continue
		}
		if child.is_list_item_marker_box() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		if child_state := state.try_get(child_styled) {
			if child_state.is_invisible_for_line_clamp() {
				continue
			}
		}
		if margins_collapse_through(child_styled, state) {
			continue
		}
		child_state := state.get(child_styled)
		mut margin_bottom := css_px(bfc.margin_state.current_collapsed_margin())
		if box_state.padding_bottom.raw_value() == 0 && box_state.border_bottom.raw_value() == 0 {
			bfc.margin_state.set_box_last_in_flow_child_margin_bottom_collapsed(true)
			margin_bottom = CSSPixels.new(0)
		}
		return css_pixels_max(CSSPixels.new(0), child_state.offset.y().plus(child_state.content_height()).plus(child_state.border_box_bottom()).plus(margin_bottom))
	}
	// BlockFormattingContext::compute_auto_height_for_block_level_element:
	// empty editing hosts retain one line-height so they remain usable for text
	// input even though they have no line boxes or in-flow children.
	if dom_node := box_node.dom_node() {
		if dom_node.as_element() != none && dom_node.is_editing_host() {
			return box.computed_values().line_height()
		}
	}
	return CSSPixels.new(0)
}

// The trailing collapsed margin is output of this formatting-context run, not
// a used margin of its last real child. Trailing collapse-through siblings can
// enlarge this aggregate after that child has already been placed. Preserve
// the child's authored margin and let only the root's automatic height consume
// the aggregate.
fn (mut bfc BlockFormattingContext) record_trailing_collapsed_margin(state &LayoutState, root &Node) {
	collapsed_margin := bfc.margin_state.current_collapsed_margin()
	if collapsed_margin == 0 {
		return
	}
	children := root.children()
	for index := children.len - 1; index >= 0; index-- {
		child := children[index]
		if child.is_absolutely_positioned() || child.is_floating() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		if child_state := state.try_get(child_styled) {
			if child_state.is_invisible_for_line_clamp() {
				continue
			}
		}
		if margins_collapse_through(child_styled, state) {
			continue
		}
		bfc.trailing_collapsed_margin = TrailingCollapsedMargin{
			child: child
			margin: css_px(collapsed_margin)
		}
		return
	}
}

// BlockFormattingContext::place_block_level_element_in_normal_flow_vertically — set a box's content-box top
// to `y` plus the box's own top border+padding. `y` is the top of the box's border box (after collapsed
// margins).
fn place_block_level_element_in_normal_flow_vertically(mut box_state UsedValues, y f64) {
	box_state.set_content_y(css_px(y + box_state.border_box_top().to_double()))
}

// BlockFormattingContext::place_block_level_element_in_normal_flow_horizontally — set a box's content-box
// left within its containing block. Float avoidance is applied by the caller;
// the -libweb-center/right block-alignment quirks are handled here.
fn place_block_level_element_in_normal_flow_horizontally(mut box_state UsedValues, available_width f64) {
	mut x := CSSPixels.new(0)
	box_node := unsafe { &Node(box_state.node()) }
	if containing_block := box_node.containing_block() {
		text_align := containing_block.computed_values().text_align()
		if text_align == .libweb_center && box_state.content_width().to_double() <= available_width {
			x = css_px(available_width / 2.0 - box_state.content_width().to_double() / 2.0)
		} else if text_align == .libweb_right {
			x = css_px(available_width - box_state.content_width().to_double() - box_state.margin_box_left().to_double())
		} else {
			x = box_state.margin_box_left()
		}
	} else {
		x = box_state.margin_box_left()
	}
	box_state.set_content_x(x)
}

// BlockFormattingContext::layout_block_level_children — lay out `block_container`'s in-flow block children
// top-to-bottom, threading the margin state so adjacent-sibling and parent-child margins collapse. Returns
// the container's content height (the bottom edge of the lowest child margin box). `content_width` is the
// children's containing-block width; `cb_height_for_children` is the container's definite content height (for
// resolving the children's percentage heights).
fn (mut bfc BlockFormattingContext) layout_block_level_children(mut state LayoutState, block_container &NodeWithStyle, content_width f64, cb_height_for_children ?f64) f64 {
	// TemporaryChange<Optional<CSSPixels>> { m_y_offset_of_current_block_container, 0 }.
	saved_y_offset := bfc.y_offset_of_current_block_container
	bfc.y_offset_of_current_block_container = 0.0

	mut bottom_of_lowest_margin_box := 0.0
	block_container_node := unsafe { &Node(block_container) }
	for child_node in block_container_node.children() {
		// ListItemMarkerBoxes are positioned by their corresponding ListItemBox,
		// not as ordinary in-flow block children.
		if child_node.is_list_item_marker_box() {
			continue
		}
		// A referenced SVG mask can be attached beneath a foreignObject. It is
		// laid out by the surrounding SVG formatting context, not by this BFC.
		if child_node.is_svg_mask_box() {
			continue
		}
		if child_node.is_absolutely_positioned() {
			if child := child_node.as_node_with_style() {
				mut child_state := state.get_mutable(child)
				// The static position is where the next in-flow block would be
				// placed, including a collapsed margin pending from earlier siblings.
				mut static_position_x := CSSPixels.new(0)
				mut static_position_y := css_px(bfc.y_offset_of_current_block_container + bfc.margin_state.pending_margin_for_next_box())
				// Originally-inline abspos boxes are routed through the BFC after
				// anonymous-wrapper fixup. Consume the insertion point published by
				// the inline formatting context which laid out their preceding content.
				if child.computed_values().display_before_box_type_transformation().is_inline_outside() {
					if sibling := child_node.previous_sibling() {
						if sibling.is_anonymous() && sibling.children_are_inline() {
							if sibling_styled := sibling.as_node_with_style() {
								sibling_state := state.get(sibling_styled)
								if inline_end := sibling_state.inline_end_static_position_rect() {
									static_position_x = sibling_state.offset.x().plus(inline_end.rect.x)
									static_position_y = sibling_state.offset.y().plus(inline_end.rect.y)
								}
							}
						}
					}
				}
				child_state.set_static_position_rect(StaticPositionRect{
					rect: css.CSSPixelRect{
						x: static_position_x
						y: static_position_y
					}
				})
			}
			continue
		}
		invisible_for_line_clamp := bfc.line_clamp_reached()
		saved_y_offset_for_line_clamp := bfc.y_offset_of_current_block_container
		saved_margin_state_for_line_clamp := bfc.margin_state
		if invisible_for_line_clamp {
			bfc.laying_out_invisible_clamped_content = true
		}
		if child_node.is_floating() {
			margin_top := bfc.margin_state.pending_margin_for_next_box()
			bfc.layout_floating_box(mut state, child_node, block_container, css_px(content_width), if height := cb_height_for_children {
				?CSSPixels(css_px(height))
			} else {
				?CSSPixels(none)
			}, css_px(bfc.y_offset_of_current_block_container + margin_top), none)
			if invisible_for_line_clamp {
				bfc.laying_out_invisible_clamped_content = false
				bfc.y_offset_of_current_block_container = saved_y_offset_for_line_clamp
				bfc.margin_state = saved_margin_state_for_line_clamp
			}
			// Floats are out of flow and do not contribute to an ordinary
			// block container's auto height. A BFC root expands for all floating
			// descendants when its formatting-context result is finalized below.
			continue
		}
		child := child_node.as_node_with_style() or { continue }
		child_bottom := bfc.layout_block_level_box(mut state, child, block_container, content_width, cb_height_for_children)
		if invisible_for_line_clamp {
			bfc.laying_out_invisible_clamped_content = false
			bfc.y_offset_of_current_block_container = saved_y_offset_for_line_clamp
			bfc.margin_state = saved_margin_state_for_line_clamp
			continue
		}
		if child_bottom > bottom_of_lowest_margin_box {
			bottom_of_lowest_margin_box = child_bottom
		}
	}

	bfc.y_offset_of_current_block_container = saved_y_offset
	return bottom_of_lowest_margin_box
}

// Lay out an in-flow block that interrupts an inline formatting context, then
// hand its flow bottom back to the line builder so subsequent inline content
// resumes on a fresh line below it.
fn (mut bfc BlockFormattingContext) layout_interrupting_block_inside_inline_context(mut state LayoutState, box &Box, containing_block &BlockContainer, available_space AvailableSpace, mut line_builder LineBuilder) {
	box_node := unsafe { &Node(box) }
	box_styled := box_node.as_node_with_style() or { return }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return }
	containing_state := state.get(containing_styled)
	saved_y_offset := bfc.y_offset_of_current_block_container
	bfc.y_offset_of_current_block_container = line_builder.current_block_offset_value().to_double()
	_ = bfc.layout_block_level_box(mut state, box_styled, containing_styled,
		containing_state.content_width().to_double(), if available_space.height.is_definite() {
		?f64(available_space.height.to_px_or_zero().to_double())
	} else {
		none
	})
	block_bottom := css_px(bfc.y_offset_of_current_block_container)
	block_bottom_margin := css_px(bfc.margin_state.current_collapsed_margin())
	bfc.y_offset_of_current_block_container = saved_y_offset
	line_builder.append_block_level_box(box, block_bottom, block_bottom_margin)
}

// Commit a collapsed margin when inline content resumes after an interrupting
// block. A margin still collapsing with the containing block only repositions
// that block; otherwise it advances the next inline line.
fn (mut bfc BlockFormattingContext) commit_pending_margin_before_inline_content() CSSPixels {
	margin_collapses_with_block_container := bfc.margin_state.has_block_container_waiting_for_final_y_position()
	collapsed_margin := css_px(bfc.margin_state.current_collapsed_margin())
	bfc.margin_state.update_block_waiting_for_final_y_position()
	bfc.margin_state.reset()
	return if margin_collapses_with_block_container { CSSPixels.new(0) } else { collapsed_margin }
}

// BlockFormattingContext::layout_block_level_box — lay out one in-flow block-level child: resolve its box
// model + width, place it vertically (collapsing its top margin with preceding margins, and with the
// containing block's top margin when that block is waiting for its final position), lay out its own
// children, resolve its height, and fold its bottom margin back into the margin state. Returns the box's
// margin-box bottom edge (its contribution to the container's content height).
fn (mut bfc BlockFormattingContext) layout_block_level_box(mut state LayoutState, box &NodeWithStyle, block_container &NodeWithStyle, containing_block_width f64, containing_block_height ?f64) f64 {
	computed := box.computed_values()
	mut box_state := state.get_mutable(box)
	if bfc.laying_out_invisible_clamped_content {
		box_state.set_invisible_for_line_clamp(true)
	}
	resolve_box_model_edges(computed, mut box_state, containing_block_width)

	// Fold this box's top margin into the collapsible state, then reposition any waiting block container.
	bfc.margin_state.add_margin(box_state.margin_top.to_double())
	container_origin := state.get(block_container).cumulative_offset()
	clearance := bfc.introduce_clearance(computed.clear(), block_container.computed_values().direction(),
		container_origin.y(), box.document().font_rendering_policy() == .chromium)
	bfc.update_block_waiting_for_final_y_position()

	y := bfc.y_offset_of_current_block_container

	// If the containing block is waiting for its final Y (its top margin collapses with this, its first
	// in-flow child), this child's own top margin is absorbed there, so it sits at the container's top.
	margin_top := bfc.margin_state.pending_margin_for_next_box()

	place_block_level_element_in_normal_flow_vertically(mut box_state, y + margin_top)

	box_as_node := unsafe { &Node(box) }
	available_space := AvailableSpace.new(AvailableSize.make_definite(css_px(containing_block_width)), if height := containing_block_height {
		AvailableSize.make_definite(css_px(height))
	} else {
		AvailableSize.make_indefinite()
	})
	// BlockFormattingContext::compute_width() sizes every box that
	// box_is_sized_as_replaced_element() selects - which includes a non-replaced
	// box with a preferred aspect ratio and one specified axis - through the
	// replaced-element algorithm.
	sized_as_replaced := box_is_sized_as_replaced_element(state, box_as_node, available_space)
	if sized_as_replaced {
		replaced_box := box_as_node.as_box() or { panic('replaced node must be a box') }
		replaced_size := compute_size_for_block_level_replaced_element_in_normal_flow(replaced_box, box_state, available_space)
		box_state.set_content_width(replaced_size.width())
		box_state.set_content_height(replaced_size.height())
		box_state.set_has_definite_width(true)
		box_state.set_has_definite_height(true)
		// Block-level replaced boxes use their independently computed width as
		// the input to the CSS 2.1 block width equation so auto margins are
		// resolved exactly like non-replaced blocks.
		margin_width := replaced_width_for_margin_resolution(mut state, replaced_box, box_state, available_space.width, replaced_size.width())
		resolve_auto_margins(computed, mut box_state, containing_block_width, margin_width.to_double())
	} else if box_as_node.is_table_wrapper() {
		wrapper_width := compute_table_wrapper_content_width(mut state, box_as_node, mut box_state, css_px(containing_block_width))
		box_state.set_content_width(wrapper_width)
		if box_state.margin_box_width().to_double() <= containing_block_width {
			resolve_auto_margins(computed, mut box_state, containing_block_width, wrapper_width.to_double())
		}
	} else {
		compute_block_used_width_for_node(mut state, box, mut box_state, AvailableSize.make_definite(css_px(containing_block_width)))
		// The principal table is sized by its anonymous wrapper's intrinsic
		// table-width pass. In particular, percentages on the table are relative
		// to the wrapper's containing block, not to the wrapper itself. Keep the
		// generic width equation's used margins, but expose the already-computed
		// table border-box width before horizontal placement, matching the order
		// in which LibWeb's table width is observed by the parent BFC.
		if box_as_node.display().is_table_inside() {
			if parent := box_as_node.parent() {
				if parent.is_table_wrapper() {
					if wrapper_values := box_state.containing_block_used_values() {
						table_width := wrapper_values.content_width().minus(box_state.border_box_left()).minus(box_state.border_box_right())
						box_state.set_content_width(table_width)
					}
				}
			}
		}
	}
	box_state.set_containing_block_used_values(state.get_mutable(block_container))
	if box_should_avoid_floats(box_as_node) && bfc.floating_boxes.len > 0 {
		bfc.place_box_avoiding_float_intrusions(mut state, box_as_node, mut box_state, block_container,
			css_px(containing_block_width), computed, sized_as_replaced || box_as_node.is_table_wrapper())
	} else {
		place_block_level_element_in_normal_flow_horizontally(mut box_state, containing_block_width)
	}
	has_independent_formatting_context := creates_block_formatting_context(box)
		|| box_as_node.display().is_math_inside() || box_as_node.display().is_flex_inside()
		|| box_as_node.display().is_grid_inside() || box_as_node.display().is_table_inside()
		|| box_as_node.is_replaced_box_with_children()
	// This context only lays out markers of list items that participate in its
	// flow directly. A list item that establishes an independent formatting
	// context lays out its marker in its own run.
	if list_item := box_as_node.as_list_item_box() {
		if !has_independent_formatting_context {
			layout_list_item_marker(mut state, list_item, mut box_state, bfc)
		}
	}

	content_width := box_state.content_width().to_double()
	mut height_resolution_basis := containing_block_height
	if percentage_height_quirk_applies(box_as_node, computed) {
		height_resolution_basis = containing_block_height_to_resolve_percentage_in_quirks_mode(state, box_as_node).to_double()
	}
	mut html_quirk_min_height := ?f64(none)
	if box_as_node.document().in_quirks_mode() && box_as_node.is_root_element()
		&& property_is_auto(computed, .height) {
		if viewport_height := containing_block_height {
			minimum := viewport_height - box_state.margin_top.to_double() - box_state.margin_bottom.to_double()
			html_quirk_min_height = if minimum > 0 { minimum } else { 0.0 }
			box_state.set_content_height(css_px(html_quirk_min_height or { 0.0 }))
			box_state.set_has_definite_height(true)
		}
	}
	mut definite_content_height := resolve_content_height_for_node(mut state, box, box_state, height_resolution_basis)
	if resolved_height := definite_content_height {
		definite_content_height = clamp_content_height_for_node(mut state, box, box_state, css_px(resolved_height), height_resolution_basis).to_double()
	}
	if html_height := html_quirk_min_height {
		// The html height is definite for descendant percentage resolution, but
		// remains auto-sized so overflowing document content can increase it.
		definite_content_height = html_height
	}
	// BlockFormattingContext::resolve_used_height_if_not_treated_as_auto()
	// resolves a definite height before laying out descendants so their
	// percentage heights can use it.
	if resolved_height := definite_content_height {
		box_state.set_content_height(css_px(resolved_height))
		if computed_height_establishes_definite_containing_block_height(computed.size_value(.height)) {
			box_state.set_has_definite_height(true)
		}
	}
	// Flex resolves its own automatic block size from its items/line cross
	// sizes. An extra max-content layout here repeats the entire subtree before
	// its actual independent run (upstream's flex_root_resolves_own_auto_block_size).
	// Retain the provisional used height for percentage block-axis gaps, whose
	// translated resolution still precedes line sizing, and for native buttons
	// and writing modes which use the existing compatibility sizing path.
	if definite_content_height == none && box_as_node.display().is_flex_inside()
		&& (node_uses_button_layout(box_as_node)
			|| computed.gap_value(.row_gap).length_percentage.contains_percentage()
			|| computed.writing_mode() != .horizontal_tb) {
		if flex_box := box_as_node.as_box() {
			box_state.set_content_height(calculate_max_content_height(mut state, flex_box, css_px(content_width)))
		}
	}
	make_button_content_box_definite(mut state, box_as_node, mut box_state, if height := containing_block_height {
		?CSSPixels(css_px(height))
	} else {
		none
	})
	// Anonymous block wrappers pass through the containing block's available
	// space instead of introducing an independent percentage-height basis.
	height_establishes_definite_containing_block := definite_content_height != none
		&& (html_quirk_min_height != none
		|| computed_height_establishes_definite_containing_block_height(computed.size_value(.height)))
	children_containing_block_height := if box_as_node.is_anonymous() {
		containing_block_height
	} else if box_state.has_definite_height() {
		box_state.content_height().to_double()
	} else if height_establishes_definite_containing_block {
		definite_content_height
	} else {
		none
	}

	// The table context resolves its vertical origin together with captions.
	// Horizontal placement may already use collapsed borders installed by an
	// intrinsic probe. Rebase from the edge used for that placement, rather
	// than counting the authored, unsplit border again.
	pre_run_table_border_box_left := box_state.border_box_left()
	mut content_height_from_children := 0.0
	if box_as_node.is_replaced_box() && !box_as_node.is_replaced_box_with_children() {
		content_height_from_children = box_state.content_height().to_double()
	} else if has_independent_formatting_context {
		mut available_height := if resolved_height := children_containing_block_height {
			AvailableSize.make_definite(css_px(resolved_height))
		} else {
			AvailableSize.make_indefinite()
		}
		// A table wrapper stretched by flex/grid gives its principal table the
		// definite block space left for the table-and-caption flow. The table
		// context subtracts caption outer sizes before distributing the grid.
		if definite_content_height == none && box_as_node.display().is_table_inside() {
			if parent := box_as_node.parent() {
				if parent.is_table_wrapper() {
					if wrapper_height := containing_block_height {
						available_height = AvailableSize.make_definite(css_px(wrapper_height))
					}
				}
			}
		}
		// BlockFormattingContext::layout_block_level_box(): an independent
		// formatting context with auto height and a non-auto min-height is
		// measured first. If the result is smaller than the minimum, its real
		// layout receives that minimum as a definite available height.
		if definite_content_height == none && !property_is_auto(computed, .min_height) {
			mut measuring_state := state.new_measurement_for_subtree(box)
			defer { measuring_state.release_measurement() }
			measuring_state.populate_node_from(mut state, box)
			mut ancestor := box_as_node.containing_block()
			for ancestor != none {
				ancestor_node := ancestor or { break }
				ancestor_styled := unsafe { &Node(ancestor_node) }.as_node_with_style() or { break }
				measuring_state.populate_node_from(mut state, ancestor_styled)
				ancestor = unsafe { &Node(ancestor_node) }.containing_block()
			}
			mut measuring_values := measuring_state.get_mutable(box)
			measured := layout_inside_independent_formatting_context_with_mode(mut measuring_state, box_as_node, mut measuring_values, bfc.layout_mode, AvailableSpace.new(AvailableSize.make_definite(css_px(content_width)), AvailableSize.make_indefinite()))
			minimum := clamp_content_height_for_node(mut measuring_state, box, measuring_values, CSSPixels.new(0), containing_block_height)
			if measured.automatic_content_height.raw_value() < minimum.raw_value() {
				available_height = AvailableSize.make_definite(minimum)
			}
		}
		inside_result := layout_inside_independent_formatting_context_with_mode(mut state, box_as_node, mut box_state, bfc.layout_mode, AvailableSpace.new(AvailableSize.make_definite(css_px(content_width)), available_height))
		if box_as_node.display().is_table_inside() && box_state.use_collapsing_borders_model() {
			box_state.set_content_x(box_state.offset.x().plus(box_state.border_box_left().minus(pre_run_table_border_box_left)))
		}
		content_height_from_children = if box_as_node.is_replaced_box() {
			box_state.content_height().to_double()
		} else {
			inside_result.automatic_content_height.to_double()
		}
	} else {
		mut registered := false
		if box_state.border_top.to_double() > 0 || box_state.padding_top.to_double() > 0 {
			// A block container's top margin can't collapse with its children if it has top border/padding.
			bfc.margin_state.reset()
		} else if introduced := clearance {
			if introduced.collapses_with_children {
				bfc.margin_state.register_cleared_block_container_y_position_update(box_state,
					introduced)
			} else {
				bfc.margin_state.register_block_container_y_position_update(box_state, y)
			}
			registered = true
		} else if !bfc.margin_state.has_block_container_waiting_for_final_y_position() {
			// Otherwise the container's final Y is not yet known: register it so the first child's top margin
			// (and any deeper collapse) repositions it.
			bfc.margin_state.register_block_container_y_position_update(box_state, y)
			registered = true
		}
		if box_has_inline_content(box_as_node) {
			if inline_container := box_as_node.as_block_container() {
				available_height := if resolved_height := children_containing_block_height {
					AvailableSize.make_definite(css_px(resolved_height))
				} else {
					AvailableSize.make_indefinite()
				}
				inline_result := bfc.run_inline_formatting_context_with_floats(mut state, inline_container, mut box_state, bfc.layout_mode, AvailableSpace.new(AvailableSize.make_definite(css_px(content_width)), available_height))
				_ = inline_result
				content_height_from_children = if box_state.line_boxes.len > 0 {
					box_state.line_boxes.last().bottom().to_double()
				} else {
					0.0
				}
				// compute_auto_height_for_block_level_element(), rule 1: a
				// trailing interrupting block's pending bottom margin collapses
				// through this box unless bottom padding or border separates it.
				if (definite_content_height == none || html_quirk_min_height != none)
					&& box_state.line_boxes.len > 0 && box_state.line_boxes.last().has_block_level_box() {
					mut margin_bottom := bfc.margin_state.current_collapsed_margin()
					if box_state.padding_bottom.raw_value() == 0
						&& box_state.border_bottom.raw_value() == 0 {
						bfc.margin_state.set_box_last_in_flow_child_margin_bottom_collapsed(true)
						margin_bottom = 0.0
					}
					content_height_from_children += margin_bottom
					if content_height_from_children < 0 {
						content_height_from_children = 0
					}
				}
			} else {
				content_height_from_children = computed_line_height_px(computed)
			}
		} else {
			bfc.layout_block_level_children(mut state, box, content_width, children_containing_block_height)
			// Upstream only invokes the auto-height algorithm (which also records
			// whether the last child's bottom margin collapsed with this box) when
			// the used height is actually auto. A definite height must stop that
			// margin from leaking through this box.
			if definite_content_height == none || html_quirk_min_height != none {
				content_height_from_children =
					bfc.compute_auto_height_for_block_level_element(mut state, box).to_double()
			}
		}
		if registered {
			bfc.margin_state.unregister_block_container_y_position_update()
		}
	}
	if definite_content_height == none && box_as_node.has_size_containment() {
		intrinsic_height := box_as_node.explicit_intrinsic_inner_height() or { CSSPixels.new(0) }
		content_height_from_children = intrinsic_height.to_double()
	}
	content_height_from_children = floor_list_item_automatic_height_by_marker_line_height(box_as_node,
		css_px(content_height_from_children)).to_double()

	// A table formatting context computes the final table grid height itself.
	// The authored height is a minimum for that grid, and border spacing may
	// make the resulting content height larger than the authored value.
	mut height := if box_as_node.display().is_table_inside() {
		content_height_from_children
	} else {
		definite_content_height or { content_height_from_children }
	}
	if minimum := html_quirk_min_height {
		height = if content_height_from_children > minimum {
			content_height_from_children
		} else {
			minimum
		}
	}
	if box_as_node.document().in_quirks_mode() && box_as_node.is_body()
		&& property_is_auto(computed, .height) && !box_as_node.is_absolutely_positioned()
		&& !box_as_node.is_floating() && !box_as_node.is_inline() {
		if containing_values := box_state.containing_block_used_values() {
			fill_height := containing_values.content_height().to_double() - box_state.margin_top.to_double() - box_state.margin_bottom.to_double()
			if fill_height > height {
				height = fill_height
			}
		}
	}
	if !has_independent_formatting_context {
		place_list_item_marker_at_first_baseline(mut state, box_as_node)
	}
	height = clamp_content_height_for_node(mut state, box, box_state, css_px(height), height_resolution_basis).to_double()
	box_state.set_content_height(css_px(height))
	if height_establishes_definite_containing_block {
		box_state.set_has_definite_height(true)
	}

	// Finish the box's participation in the margin state (CSS 2.1 §8.3.1): unless its margins collapse
	// through, its bottom border edge becomes the new baseline for the next sibling and the running state is
	// reset; then fold in its bottom margin.
	if !margins_collapse_through(box, state) {
		if !bfc.margin_state.box_last_in_flow_child_margin_bottom_collapsed() {
			bfc.margin_state.reset()
		}
		bfc.y_offset_of_current_block_container = box_state.offset.y().to_double() + box_state.content_height().to_double() + box_state.border_box_bottom().to_double()
	}
	bfc.margin_state.set_box_last_in_flow_child_margin_bottom_collapsed(false)

	bfc.margin_state.add_margin(box_state.margin_bottom.to_double())
	bfc.update_block_waiting_for_final_y_position()

	flow_bottom := box_state.offset.y().to_double() + box_state.content_height().to_double() + box_state.margin_box_bottom().to_double()
	return flow_bottom
}

// A list item that establishes an independent formatting context lays out its
// own marker, so markers of floating, absolutely positioned, and flex- or
// grid-item list items are placed too. Upstream runs this in the epilogue of
// the list item's block formatting context run. V sizes the marker and
// resolves its inline position before the children instead, where no float of
// the run can intrude and an in-flow root has already been placed beside its
// parent's floats; place_list_item_marker_at_first_baseline() then resolves
// the block offset once the children are laid out.
fn (bfc &BlockFormattingContext) layout_marker_of_list_item_root(mut state LayoutState, box &Node, mut box_state UsedValues) {
	list_item := box.as_list_item_box() or { return }
	layout_list_item_marker(mut state, list_item, mut box_state, bfc)
}

// floor_list_item_automatic_block_size_by_marker_line_height(). A list item's
// automatic block size is at least its marker's line height, so an empty list
// item or one containing only floats still stacks like a line. A specified
// height or max-height is not an automatic size and wins over this floor.
fn floor_list_item_automatic_height_by_marker_line_height(box &Node, automatic_height CSSPixels) CSSPixels {
	list_item := box.as_list_item_box() or { return automatic_height }
	marker := list_item.marker() or { return automatic_height }
	return css_pixels_max(automatic_height, marker.computed_values().line_height())
}

// The block-offset half of layout_list_item_marker(). An outside marker whose
// content has a baseline aligns it with the list item's first baseline; a
// marker without one, or one whose list item has none, stays centered in its
// line height.
fn place_list_item_marker_at_first_baseline(mut state LayoutState, box &Node) {
	list_item := box.as_list_item_box() or { return }
	marker_node := list_item.marker() or { return }
	marker := marker_node.as_list_item_marker_box() or { return }
	if marker.list_style_position() == .inside {
		return
	}
	marker_styled := marker_node.as_node_with_style() or { return }
	mut marker_state := state.try_get_mutable(marker_styled) or { return }
	list_item_baseline := layout_box_first_content_baseline(state, box) or { return }
	marker_baseline := layout_box_first_content_baseline(state, marker_node) or { return }
	marker_state.set_content_y(list_item_baseline.minus(marker_baseline))
}

// BlockFormattingContext::ensure_sizes_correct_for_left_offset_calculation()
// and layout_list_item_marker().
fn layout_list_item_marker(mut state LayoutState, list_item &ListItemBox, mut list_item_state UsedValues, bfc &BlockFormattingContext) {
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	marker_node := list_item.marker() or { return }
	marker := marker_node.as_list_item_marker_box() or { return }
	marker_styled := marker_node.as_node_with_style() or { return }
	mut marker_state := state.get_mutable(marker_styled)
	marker_state.set_containing_block_used_values(list_item_state)
	marker_text := marker.text()
	if text := marker_text {
		if child := marker_node.first_child() {
			if generated_text := child.as_text_node() {
				mut mutable_text := unsafe { &TextNode(generated_text) }
				mutable_text.source_text_ = text
				mutable_text.invalidate_text_for_rendering()
			}
		}
	}
	marker_box := marker_node.as_box() or { return }
	// Intrinsic probes of a shrink-to-fit list item can visit its outside marker
	// before the marker gets an independent used-value entry. Upstream keeps
	// those probe results in the run-scoped sizing state; do not reuse a stale
	// persistent zero after generated marker content is ready for its own run.
	mut mutable_marker_box := unsafe { &Box(marker_box) }
	mutable_marker_box.reset_cached_intrinsic_sizes()
	marker_state.set_content_width(calculate_max_content_width(mut state, marker_box))
	if marker.chromium_symbol_marker() {
		ascent := marker.chromium_symbol_ascent()
		marker_state.set_content_width(CSSPixels.new((ascent * 2 / 3 + 1) / 2 + 2))
	}
	if marker_node.has_children() {
		if block_container := marker_node.as_block_container() {
			inline_result := run_inline_formatting_context(mut state, block_container, mut marker_state, bfc.layout_mode, AvailableSpace.new(AvailableSize.make_definite(marker_state.content_width()), AvailableSize.make_indefinite()))
			marker_state.set_content_height(inline_result.automatic_content_height)
		}
	}
	offset_y := css.css_pixels_round(css_pixels_max(CSSPixels.new(0), marker.computed_values().line_height().minus(marker_state.content_height()).divided_by_float(2)))
	// Capture both inline-side float intrusions before laying out list-item
	// descendants. In particular, floats inside the item must not displace its
	// marker away from the first line's original inline edge.
	direction := list_item.computed_values().direction()
	content_width_before_marker := list_item_state.content_width()
	left_boundary, right_boundary, _ := bfc.float_boundaries_at(offset_y, marker_state.content_height(), content_width_before_marker, direction, list_item_state.cumulative_offset())
	right_intrusion := content_width_before_marker.minus(right_boundary)
	marker_offset_x := if marker.list_style_position() == .inside {
		CSSPixels.new(0)
	} else if marker.chromium_symbol_marker() {
		// ListMarker::InlineMarginsForOutside(): offset plus 7px padding
		// and the symbol rectangle's additional 1px inline inset.
		left_boundary.minus(CSSPixels.new(marker.chromium_symbol_ascent() * 2 / 3 + 8))
	} else if direction == .ltr {
		left_boundary.minus(marker_state.content_width())
	} else {
		content_width_before_marker.minus(right_intrusion)
	}
	offset_x := if marker.document().font_rendering_policy() == .chromium {
		marker_offset_x
	} else { css.css_pixels_round(marker_offset_x) }
	marker_state.set_content_offset(css.CSSPixelPoint.new(offset_x, offset_y))
}

fn (m &BlockMarginState) box_last_in_flow_child_margin_bottom_collapsed() bool {
	return m.box_last_in_flow_child_margin_bottom_collapsed
}

fn (mut m BlockMarginState) set_box_last_in_flow_child_margin_bottom_collapsed(value bool) {
	m.box_last_in_flow_child_margin_bottom_collapsed = value
}

// The block formatting context's running state (the BlockFormattingContext members that the normal-flow
// block path threads). One instance drives a whole subtree of non-BFC-establishing block containers, which
// is what lets margins collapse across nesting levels.
struct BlockFormattingContext {
mut:
	margin_state                         BlockMarginState
	// Explicit none avoids constructing the absent record's child/style in the
	// compatibility compiler. A real trailing margin still owns its child.
	trailing_collapsed_margin            ?TrailingCollapsedMargin = ?TrailingCollapsedMargin(none)
	y_offset_of_current_block_container  f64
	floating_boxes                       []FloatingBoxRecord
	float_bands                          []BFCFloatBand = [BFCFloatBand{}]
	layout_mode                          LayoutMode
	root                                 ?&Node
	is_line_clamp_container              bool
	max_lines                            ?int
	line_clamp_line_count                int
	line_clamp_reached_                  bool
	laying_out_invisible_clamped_content bool
}

struct TrailingCollapsedMargin {
	child  &Node
	margin CSSPixels
}

fn BlockFormattingContext.for_root(root &Node, layout_mode LayoutMode, has_definite_inline_size bool) BlockFormattingContext {
	computed := root.computed_values()
	active := line_clamp_is_active(computed)
	return BlockFormattingContext{
		layout_mode: layout_mode
		root: root
		is_line_clamp_container: active
		// Intrinsic measurements at a definite inline size need the clamped
		// block size just like committed layout. Measurements at an intrinsic
		// inline constraint still leave clamping to the final layout pass.
		max_lines: if active && (layout_mode != .intrinsic_sizing || has_definite_inline_size) {
			computed.max_lines()
		} else {
			none
		}
	}
}

fn (bfc &BlockFormattingContext) has_line_clamp() bool {
	return bfc.is_line_clamp_container && bfc.max_lines != none
}

fn (bfc &BlockFormattingContext) line_clamp_reached() bool {
	return bfc.has_line_clamp() && bfc.line_clamp_reached_
}

struct FloatingBoxRecord {
	box &Node
mut:
	left    CSSPixels
	top     CSSPixels
	right   CSSPixels
	bottom  CSSPixels
	side    css.Float
	is_left bool
}

struct BFCFloatBand {
mut:
	block_start CSSPixels
	left_edge   ?CSSPixels
	right_edge  ?CSSPixels
}

// A margin-collapsing block container may acquire its final block offset only
// after floats inside it have already been placed. Upstream keeps float boxes
// tied to live layout geometry; update this port's cached root-space records by
// the same delta whenever that ancestor moves.
fn (mut bfc BlockFormattingContext) update_block_waiting_for_final_y_position() {
	mut waiting := bfc.margin_state.waiting_box or { return }
	old_y := waiting.offset.y()
	bfc.margin_state.update_block_waiting_for_final_y_position()
	delta := waiting.offset.y().minus(old_y)
	if delta.raw_value() == 0 {
		return
	}
	waiting_node := unsafe { &Node(waiting.node()) }
	for index, record in bfc.floating_boxes {
		if waiting_node.is_inclusive_ancestor_of(record.box) {
			bfc.floating_boxes[index].top = record.top.plus(delta)
			bfc.floating_boxes[index].bottom = record.bottom.plus(delta)
		}
	}
	bfc.rebuild_float_bands()
}

fn float_side_is_left(side css.Float, direction css.Direction) bool {
	return side == .left || (side == .inline_start && direction == .ltr)
		|| (side == .inline_end && direction == .rtl)
}

fn clear_applies_to_float(clear css.Clear, side css.Float, direction css.Direction) bool {
	if clear == .both {
		return true
	}
	left := float_side_is_left(side, direction)
	return (left && (clear == .left || (clear == .inline_start && direction == .ltr)
		|| (clear == .inline_end && direction == .rtl)))
		|| (!left && (clear == .right || (clear == .inline_end && direction == .ltr)
			|| (clear == .inline_start && direction == .rtl)))
}

fn (bfc &BlockFormattingContext) clearance_y(clear css.Clear, direction css.Direction, container_root_y CSSPixels, current_y CSSPixels) CSSPixels {
	if clear == .none_ {
		return current_y
	}
	mut y := current_y
	// Clearance has to pass every preceding float in this context, including
	// floats that no longer occupy the current placement band.
	for floating in bfc.floating_boxes {
		local_bottom := floating.bottom.minus(container_root_y)
		if clear_applies_to_float(clear, floating.side, direction)
			&& local_bottom.raw_value() > y.raw_value() {
			y = local_bottom
		}
	}
	return y
}

struct ClearanceIntroduction {
	y                       f64
	hypothetical_base_y     f64
	positive_margin         f64
	negative_margin         f64
	collapses_with_children bool
}

// Chromium follows CSS 2.1 §9.5.2: clearance is introduced only when the box's
// hypothetical top border edge, after its collapsed top margin, is not past the
// relevant floats. The box is then placed at the clearance position and stops
// collapsing with preceding margins; margins of its first in-flow children can
// lower it only beyond that position. LibWeb compares the floats with the flow
// position before margins and lets those child margins lower the cleared box.
fn (mut bfc BlockFormattingContext) introduce_clearance(clear css.Clear, direction css.Direction, container_root_y CSSPixels, chromium bool) ?ClearanceIntroduction {
	if clear == .none_ {
		return none
	}
	current_y := css_px(bfc.y_offset_of_current_block_container)
	hypothetical_y := if chromium {
		current_y.plus(css_px(bfc.margin_state.current_collapsed_margin()))
	} else {
		current_y
	}
	y := bfc.clearance_y(clear, direction, container_root_y, hypothetical_y)
	if y.raw_value() <= hypothetical_y.raw_value() {
		return none
	}
	introduced := ClearanceIntroduction{
		y:                       y.to_double()
		hypothetical_base_y:     current_y.to_double()
		positive_margin:         bfc.margin_state.current_positive_collapsible_margin
		negative_margin:         bfc.margin_state.current_negative_collapsible_margin
		collapses_with_children: chromium
	}
	bfc.y_offset_of_current_block_container = y.to_double()
	bfc.margin_state.reset()
	return introduced
}

fn (bfc &BlockFormattingContext) float_band_index_at(y CSSPixels) int {
	mut index := 0
	for candidate in 1 .. bfc.float_bands.len {
		if bfc.float_bands[candidate].block_start.raw_value() > y.raw_value() {
			break
		}
		index = candidate
	}
	return index
}

fn (bfc &BlockFormattingContext) next_float_band_start_after(y CSSPixels) ?CSSPixels {
	for band in bfc.float_bands {
		if band.block_start.raw_value() > y.raw_value() {
			return band.block_start
		}
	}
	return none
}

fn (mut bfc BlockFormattingContext) ensure_float_band_boundary(block_start CSSPixels) {
	for index, band in bfc.float_bands {
		if band.block_start.raw_value() == block_start.raw_value() {
			return
		}
		if band.block_start.raw_value() > block_start.raw_value() {
			mut inserted := if index == 0 { BFCFloatBand{} } else { bfc.float_bands[index - 1] }
			inserted.block_start = block_start
			bfc.float_bands.insert(index, inserted)
			return
		}
	}
	mut inserted := bfc.float_bands.last()
	inserted.block_start = block_start
	bfc.float_bands << inserted
}

fn (mut bfc BlockFormattingContext) add_float_to_bands(floating FloatingBoxRecord) {
	if floating.bottom.raw_value() <= floating.top.raw_value() {
		return
	}
	bfc.ensure_float_band_boundary(floating.top)
	bfc.ensure_float_band_boundary(floating.bottom)
	for index in 0 .. bfc.float_bands.len {
		band_start := bfc.float_bands[index].block_start
		if band_start.raw_value() < floating.top.raw_value() {
			continue
		}
		if band_start.raw_value() >= floating.bottom.raw_value() {
			break
		}
		if floating.is_left {
			current := bfc.float_bands[index].left_edge or { CSSPixels.min() }
			bfc.float_bands[index].left_edge = css_pixels_max(current, floating.right)
		} else {
			current := bfc.float_bands[index].right_edge or { CSSPixels.max() }
			bfc.float_bands[index].right_edge = css_pixels_min(current, floating.left)
		}
	}
}

fn (mut bfc BlockFormattingContext) rebuild_float_bands() {
	bfc.float_bands = [BFCFloatBand{}]
	for floating in bfc.floating_boxes {
		bfc.add_float_to_bands(floating)
	}
}

fn (bfc &BlockFormattingContext) float_boundaries_at(y CSSPixels, height CSSPixels, container_width CSSPixels, direction css.Direction, container_root_offset CSSPixelPoint) (CSSPixels, CSSPixels, CSSPixels) {
	_ = direction
	root_start := container_root_offset.y().plus(y)
	root_end := root_start.plus(height)
	mut left_edge := ?CSSPixels(none)
	mut right_edge := ?CSSPixels(none)
	start_index := bfc.float_band_index_at(root_start)
	for index in start_index .. bfc.float_bands.len {
		band := bfc.float_bands[index]
		if height.raw_value() > 0 && band.block_start.raw_value() >= root_end.raw_value() {
			break
		}
		if edge := band.left_edge {
			left_edge = if current := left_edge { css_pixels_max(current, edge) } else { edge }
		}
		if edge := band.right_edge {
			right_edge = if current := right_edge { css_pixels_min(current, edge) } else { edge }
		}
		if height.raw_value() <= 0 {
			break
		}
	}
	left := if edge := left_edge {
		css_pixels_max(CSSPixels.new(0), edge.minus(container_root_offset.x()))
	} else {
		CSSPixels.new(0)
	}
	right := if edge := right_edge {
		css_pixels_min(container_width, edge.minus(container_root_offset.x()))
	} else {
		container_width
	}
	next_y := if boundary := bfc.next_float_band_start_after(root_start) {
		boundary.minus(container_root_offset.y())
	} else {
		CSSPixels.max()
	}
	return left, right, next_y
}

// BlockFormattingContext::border_box_left_of_box_avoiding_floats(). A
// non-negative left margin may overlap the floats as far as possible; a
// negative one cannot pull the border box into an adjacent float.
fn border_box_left_of_box_avoiding_floats(computed &css.ComputedProperties, box_state &UsedValues, space_used_left CSSPixels, space_used_right CSSPixels) CSSPixels {
	if property_is_auto(computed, .margin_left) {
		return space_used_left.plus(box_state.margin_left)
	}
	if box_state.margin_left.raw_value() >= 0 {
		return css_pixels_max(space_used_left, box_state.margin_left)
	}
	if space_used_left.raw_value() > 0 || space_used_right.raw_value() > 0 {
		return space_used_left
	}
	return space_used_left.plus(box_state.margin_left)
}

// BlockFormattingContext::compute_width() and avoid_float_intrusions() for a
// box that establishes a formatting context: its border box must not overlap
// the margin box of any float. Its width is resolved against the space next to
// the floats in its band, reduced by negative margins, and the box is moved to
// the next float band until it fits without overlapping a float. Replaced
// boxes keep the width already resolved in normal flow. A table wrapper's own
// width is auto; its used width is the table's, which is sized again against
// the space beside the floats. Auto margins of both are resolved in that space.
fn (bfc &BlockFormattingContext) place_box_avoiding_float_intrusions(mut state LayoutState, box &Node, mut box_state UsedValues, block_container &NodeWithStyle, container_width CSSPixels, computed &css.ComputedProperties, width_is_resolved bool) {
	container_state := box_state.containing_block_used_values() or { return }
	container_root_offset := container_state.cumulative_offset()
	direction := block_container.computed_values().direction()
	// Normal flow may already have stretched a resolved-width box's end margin
	// to fill the line; beside floats, start again from the specified margins.
	specified_margin_left := css_px(computed.length_percentage_to_px(.margin_left, container_width.to_double()) or {
		0.0
	})
	specified_margin_right := css_px(computed.length_percentage_to_px(.margin_right,
		container_width.to_double()) or { 0.0 })
	margin_left := if property_is_auto(computed, .margin_left) {
		CSSPixels.new(0)
	} else if width_is_resolved {
		specified_margin_left
	} else {
		box_state.margin_left
	}
	margin_right := if property_is_auto(computed, .margin_right) {
		CSSPixels.new(0)
	} else if width_is_resolved {
		specified_margin_right
	} else {
		box_state.margin_right
	}
	negative_margin_sum := css_pixels_min(margin_left, CSSPixels.new(0)).plus(css_pixels_min(margin_right,
		CSSPixels.new(0)))
	normal_flow_margin_left := box_state.margin_left
	normal_flow_margin_right := box_state.margin_right
	normal_flow_width := box_state.content_width()
	mut border_box_y := box_state.offset.y().minus(box_state.border_box_top())
	for {
		left, right, next_y := bfc.float_boundaries_at(border_box_y, CSSPixels.new(1), container_width,
			direction, container_root_offset)
		space_used_left := left
		space_used_right := container_width.minus(right)
		constrained_by_floats := space_used_left.raw_value() > 0 || space_used_right.raw_value() > 0
		mut remaining := right.minus(left)
		if constrained_by_floats {
			// Positive margins overlap the intrusion on their own side. Only
			// the part extending past the float consumes the remaining width.
			remaining = remaining.plus(css_pixels_min(space_used_left,
				css_pixels_max(margin_left, CSSPixels.new(0))))
			remaining = remaining.plus(css_pixels_min(space_used_right,
				css_pixels_max(margin_right, CSSPixels.new(0))))
			// Negative margins do not create additional space next to a float.
			remaining = css_pixels_max(remaining.plus(negative_margin_sum), CSSPixels.new(0))
		}
		if width_is_resolved {
			box_state.margin_left = normal_flow_margin_left
			box_state.margin_right = normal_flow_margin_right
			box_state.set_content_width(normal_flow_width)
			if constrained_by_floats {
				box_state.margin_left = specified_margin_left
				box_state.margin_right = specified_margin_right
				if box.is_table_wrapper() {
					box_state.set_content_width(compute_table_wrapper_content_width(mut state,
						box, mut box_state, remaining))
				}
				resolve_auto_margins(computed, mut box_state, remaining.to_double(),
					box_state.content_width().to_double())
			}
		} else if property_is_auto(computed, .width) {
			compute_block_used_width(computed, mut box_state, remaining.to_double())
		} else {
			node := box_state.node()
			if resolved_width := resolve_layout_content_size(unsafe { &Node(node) }, computed.size_value(.width), container_width, box_state, true) {
				compute_block_used_width_with_override(computed, mut box_state, remaining.to_double(), resolved_width)
			}
		}
		border_box_left := border_box_left_of_box_avoiding_floats(computed, box_state, space_used_left,
			space_used_right)
		mut must_clear := constrained_by_floats
			&& border_box_left.plus(box_state.border_box_width()).raw_value() > right.raw_value()
		if !must_clear {
			root_left := container_root_offset.x().plus(border_box_left)
			root_top := container_root_offset.y().plus(border_box_y)
			root_right := root_left.plus(box_state.border_box_width())
			root_bottom := root_top.plus(box_state.border_box_height())
			for floating in bfc.floating_boxes {
				if floating.left.raw_value() < root_right.raw_value()
					&& root_left.raw_value() < floating.right.raw_value()
					&& floating.top.raw_value() < root_bottom.raw_value()
					&& root_top.raw_value() < floating.bottom.raw_value() {
					must_clear = true
					break
				}
			}
		}
		if !must_clear || next_y.might_be_saturated() {
			box_state.set_content_x(border_box_left.plus(box_state.border_box_left()))
			box_state.set_content_y(border_box_y.plus(box_state.border_box_top()))
			return
		}
		border_box_y = next_y
	}
}

fn (mut bfc BlockFormattingContext) layout_floating_box(mut state LayoutState, box &Node, block_container &NodeWithStyle, container_width CSSPixels, container_height ?CSSPixels, start_y CSSPixels, line_builder ?&LineBuilder) CSSPixels {
	styled := box.as_node_with_style() or { return CSSPixels.new(0) }
	mut initial_state := state.get_mutable(styled)
	if bfc.laying_out_invisible_clamped_content {
		initial_state.set_invisible_for_line_clamp(true)
	}
	mut container_state := state.get_mutable(block_container)
	initial_state.set_containing_block_used_values(container_state)
	resolve_box_model_edges(styled.computed_values(), mut initial_state, container_width.to_double())
	float_available_space := AvailableSpace.new(AvailableSize.make_definite(container_width), if height := container_height {
		AvailableSize.make_definite(height)
	} else {
		AvailableSize.make_indefinite()
	})
	// BlockFormattingContext::compute_width() runs
	// compute_width_for_block_level_replaced_element_in_normal_flow() for a
	// replaced-sized float and returns before the shrink-to-fit path.
	mut forced_height := ?CSSPixels(none)
	mut forced_width := ?CSSPixels(none)
	if box.is_table_wrapper() {
		forced_width = compute_table_wrapper_content_width(mut state, box, mut initial_state, container_width)
	} else if box_is_sized_as_replaced_element(state, box, float_available_space) {
		replaced_box := box.as_box() or { panic('replaced node must be a box') }
		replaced_size := compute_size_for_block_level_replaced_element_in_normal_flow(replaced_box, initial_state, float_available_space)
		forced_width = replaced_size.width()
		forced_height = replaced_size.height()
	} else {
		forced_width = resolve_layout_content_size(box, styled.computed_values().size_value(.width), container_width, initial_state, true)
	}
	// Replaced floats are sized by the replaced-element algorithm. Their
	// intrinsic width must not be converted into a forced shrink-to-fit width,
	// since a block-axis min/max constraint can transfer through the preferred
	// aspect ratio and change the inline size as well.
	if forced_width == none && !box.is_replaced_box() {
		if box_as_box := box.as_box() {
			forced_width = calculate_fit_content_width(mut state, box_as_box, AvailableSize.make_definite(container_width))
		}
	}
	// CSS 2.1 §10.3.5 applies max-width and then min-width to the
	// shrink-to-fit result (and to a specified float width). Replaced floats
	// already apply these constraints as part of compute_replaced_size().
	if width := forced_width {
		if !box.is_replaced_box() {
			forced_width = clamp_layout_content_size(box, width, container_width, initial_state, true)
		}
	}
	mut box_state := layout_independent_child(mut state, box, mut container_state, container_width, container_height, forced_width, forced_height)
	container_root_offset := container_state.cumulative_offset()
	direction := block_container.computed_values().direction()
	side := styled.computed_values().float_()
	is_left := float_side_is_left(side, direction)
	mut y := if builder := line_builder {
		builder.y_for_float_to_be_inserted_here(box_state, bfc)
	} else {
		start_y
	}
	clear := styled.computed_values().clear()
	if clear_applies_to_float(clear, side, direction) {
		y = bfc.clearance_y(clear, direction, container_root_offset.y(), y)
	}
	// A later float may not be higher than a preceding float, regardless of
	// which inline side it uses.
	if bfc.floating_boxes.len > 0 {
		last_top := bfc.floating_boxes.last().top.minus(container_root_offset.y())
		y = css_pixels_max(y, last_top)
	}
	// Search the shared band map at each candidate block start. If both sides
	// leave too little inline space, retry at the next band boundary.
	for {
		left, right, next_y := bfc.float_boundaries_at(y, box_state.margin_box_height(), container_width, direction, container_root_offset)
		root_y := container_root_offset.y().plus(y)
		band := bfc.float_bands[bfc.float_band_index_at(root_y)]
		has_floats_present := band.left_edge != none || band.right_edge != none
		if right.minus(left).raw_value() >= box_state.margin_box_width().raw_value()
			|| !has_floats_present || next_y.might_be_saturated() {
			margin_left := if float_side_is_left(side, direction) {
				left
			} else {
				right.minus(box_state.margin_box_width())
			}
			box_state.set_content_x(margin_left.plus(box_state.margin_box_left()))
			box_state.set_content_y(y.plus(box_state.margin_box_top()))
			record := FloatingBoxRecord{
				left: container_root_offset.x().plus(margin_left)
				top: container_root_offset.y().plus(y)
				right: container_root_offset.x().plus(margin_left).plus(box_state.margin_box_width())
				bottom: container_root_offset.y().plus(y).plus(box_state.margin_box_height())
				side: side
				is_left: is_left
				box: box
			}
			bfc.floating_boxes << record
			bfc.add_float_to_bands(record)
			return y.plus(box_state.margin_box_height())
		}
		y = next_y
	}
	return y
}
