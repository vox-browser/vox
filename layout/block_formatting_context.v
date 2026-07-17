module layout

// A faithful translation of the margin-collapsing core of Ladybird's BlockFormattingContext
// (Layout/BlockFormattingContext.{h,cpp}): the BlockMarginState accumulator, margins_collapse_through, and
// the layout_block_level_children / layout_block_level_box normal-flow block algorithm — enough to model
// CSS 2.1 §8.3.1 adjacent-sibling AND parent-child vertical margin collapsing.
//
// DEFERRED (stubbed or skipped, matching what the rest of the port models): floats, clearance,
// out-of-flow (absolute/fixed) positioning, independent formatting contexts other than the block/inline
// split, list-item markers, tables, fieldset legends, multicol, and writing modes.

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

// BlockMarginState::has_block_container_waiting_for_final_y_position.
fn (m &BlockMarginState) has_block_container_waiting_for_final_y_position() bool {
	return m.waiting_box != none
}

// BlockMarginState::register_block_container_y_position_update_callback (port form: store the box + base Y).
fn (mut m BlockMarginState) register_block_container_y_position_update(box &UsedValues, base_y f64) {
	m.waiting_box = box
	m.waiting_box_base_y = base_y
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
	place_block_level_element_in_normal_flow_vertically(mut box, m.waiting_box_base_y +
		m.current_collapsed_margin())
}

// BlockMarginState::reset.
fn (mut m BlockMarginState) reset() {
	m.waiting_box = none
	m.current_positive_collapsible_margin = 0
	m.current_negative_collapsible_margin = 0
}

// FormattingContext::creates_block_formatting_context — whether `box` establishes an independent block
// formatting context (and so its margins do not collapse with its children). FIXME: floats, overflow other
// than visible, display: flow-root / inline-block / table-cell / flex|grid item, and absolute positioning
// all establish one; none of those are modelled yet, so for now no box does.
fn creates_block_formatting_context(box &NodeWithStyle) bool {
	_ = box
	return false
}

// BlockFormattingContext::margins_collapse_through (CSS 2.1 §8.3.1) — whether a box's own top and bottom
// margins are adjoining (they collapse "through" the box): it establishes no BFC, has zero border-box
// height, and every in-flow child also collapses through. FIXME: the `clear` check is skipped (floats/clear
// aren't modelled).
fn margins_collapse_through(box &NodeWithStyle, state &LayoutState) bool {
	if creates_block_formatting_context(box) {
		return false
	}
	box_state := state.try_get(box) or { return false }
	if box_state.border_box_height().to_double() != 0 {
		return false
	}
	box_node := unsafe { &Node(box) }
	for child in box_node.children() {
		child_nws := child.as_node_with_style() or { continue }
		// FIXME: out-of-flow (absolute/floating) children are skipped in C++; not modelled here.
		if !margins_collapse_through(child_nws, state) {
			return false
		}
	}
	return true
}

// BlockFormattingContext::place_block_level_element_in_normal_flow_vertically — set a box's content-box top
// to `y` plus the box's own top border+padding. `y` is the top of the box's border box (after collapsed
// margins). Float bookkeeping is omitted (floats aren't modelled).
fn place_block_level_element_in_normal_flow_vertically(mut box_state UsedValues, y f64) {
	box_state.set_content_y(css_px(y + box_state.border_box_top().to_double()))
}

// BlockFormattingContext::place_block_level_element_in_normal_flow_horizontally — set a box's content-box
// left within its containing block. With no floats and no -libweb-center/right text-align, this is the box's
// left margin+border+padding. FIXME: floats and the block text-align quirks are not modelled.
fn place_block_level_element_in_normal_flow_horizontally(mut box_state UsedValues) {
	box_state.set_content_x(box_state.margin_box_left())
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
		child := child_node.as_node_with_style() or { continue }
		child_bottom := bfc.layout_block_level_box(mut state, child, block_container, content_width,
			cb_height_for_children)
		if child_bottom > bottom_of_lowest_margin_box {
			bottom_of_lowest_margin_box = child_bottom
		}
	}

	bfc.y_offset_of_current_block_container = saved_y_offset
	return bottom_of_lowest_margin_box
}

// BlockFormattingContext::layout_block_level_box — lay out one in-flow block-level child: resolve its box
// model + width, place it vertically (collapsing its top margin with preceding margins, and with the
// containing block's top margin when that block is waiting for its final position), lay out its own
// children, resolve its height, and fold its bottom margin back into the margin state. Returns the box's
// margin-box bottom edge (its contribution to the container's content height).
fn (mut bfc BlockFormattingContext) layout_block_level_box(mut state LayoutState, box &NodeWithStyle, block_container &NodeWithStyle, containing_block_width f64, containing_block_height ?f64) f64 {
	computed := box.computed_values()
	mut box_state := state.get_mutable(box)
	resolve_box_model_edges(computed, mut box_state, containing_block_width)

	// Fold this box's top margin into the collapsible state, then reposition any waiting block container.
	bfc.margin_state.add_margin(box_state.margin_top.to_double())
	bfc.margin_state.update_block_waiting_for_final_y_position()

	y := bfc.y_offset_of_current_block_container

	// If the containing block is waiting for its final Y (its top margin collapses with this, its first
	// in-flow child), this child's own top margin is absorbed there, so it sits at the container's top.
	mut margin_top := bfc.margin_state.current_collapsed_margin()
	if bfc.margin_state.has_block_container_waiting_for_final_y_position() {
		margin_top = 0.0
	}

	place_block_level_element_in_normal_flow_vertically(mut box_state, y + margin_top)

	compute_block_used_width(computed, mut box_state, containing_block_width)
	place_block_level_element_in_normal_flow_horizontally(mut box_state)
	box_state.set_containing_block_used_values(state.get_mutable(block_container))

	content_width := box_state.content_width().to_double()
	definite_content_height := resolve_definite_content_height(computed, containing_block_height)

	box_as_node := unsafe { &Node(box) }
	mut content_height_from_children := 0.0
	if box_has_inline_content(box_as_node) {
		// Inline formatting context (first slice): a single line box of the computed line-height. The box's
		// top margin cannot collapse with inline content, so nothing is registered here.
		content_height_from_children = computed_line_height_px(computed)
	} else {
		mut registered := false
		if box_state.border_top.to_double() > 0 || box_state.padding_top.to_double() > 0 {
			// A block container's top margin can't collapse with its children if it has top border/padding.
			bfc.margin_state.reset()
		} else if !bfc.margin_state.has_block_container_waiting_for_final_y_position() {
			// Otherwise the container's final Y is not yet known: register it so the first child's top margin
			// (and any deeper collapse) repositions it.
			bfc.margin_state.register_block_container_y_position_update(box_state, y)
			registered = true
		}
		content_height_from_children = bfc.layout_block_level_children(mut state, box, content_width,
			definite_content_height)
		if registered {
			bfc.margin_state.unregister_block_container_y_position_update()
		}
	}

	mut height := definite_content_height or { content_height_from_children }
	height = clamp_to_min_max(computed, .min_height, .max_height, height, containing_block_height or {
		0.0
	})
	box_state.set_content_height(css_px(height))

	// Finish the box's participation in the margin state (CSS 2.1 §8.3.1): unless its margins collapse
	// through, its bottom border edge becomes the new baseline for the next sibling and the running state is
	// reset; then fold in its bottom margin.
	if !margins_collapse_through(box, state) {
		if !bfc.margin_state.box_last_in_flow_child_margin_bottom_collapsed() {
			bfc.margin_state.reset()
		}
		bfc.y_offset_of_current_block_container = box_state.offset.y().to_double() +
			box_state.content_height().to_double() + box_state.border_box_bottom().to_double()
	}
	bfc.margin_state.set_box_last_in_flow_child_margin_bottom_collapsed(false)

	bfc.margin_state.add_margin(box_state.margin_bottom.to_double())
	bfc.margin_state.update_block_waiting_for_final_y_position()

	return box_state.offset.y().to_double() + box_state.content_height().to_double() +
		box_state.margin_box_bottom().to_double()
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
	margin_state                        BlockMarginState
	y_offset_of_current_block_container f64
}
