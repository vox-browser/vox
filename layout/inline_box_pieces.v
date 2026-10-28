module layout

import css
$if prealloc {
	import platform
}

// InlineFormattingContext's inline box pieces. Each fragmented inline box gets
// one piece per line it spans; the piece's border box covers the fragments the
// box directly parents plus the margin boxes of its nested inline boxes. The
// geometry of the box itself (InlinePaintable) is the union of its pieces.
// Logical line extents used to span an inline containing block's first and
// last content lines.
struct InlineBoxPieceCorners {
	inline_start CSSPixels
	inline_end   CSSPixels
	block_start  CSSPixels
	block_end    CSSPixels
}

struct InlineBoxPiece {
	node                         &Node = unsafe { nil }
	line_index                   int
	border_box_rect              css.CSSPixelRect
	has_low_edge                 bool
	has_high_edge                bool
	is_geometry_only_placeholder bool
	corners                      InlineBoxPieceCorners
}

struct InlineBoxPieceLine {
mut:
	line_index                              int
	has_contributions                       bool
	contributions_inline_start              CSSPixels
	contributions_inline_end                CSSPixels
	first_direct_fragment_block_start       ?CSSPixels
	max_direct_fragment_block_length        CSSPixels
	fallback_block_start_from_contributions ?CSSPixels
	interrupting_block_position             ?css.CSSPixelPoint
	interrupting_block_corners              InlineBoxPieceCorners
}

struct InlineBoxPieceNode {
mut:
	node                    &Node = unsafe { nil }
	parent_index            int   = -1
	depth                   int
	lines                   []InlineBoxPieceLine
	first_line_with_content int = -1
	last_line_with_content  int = -1
}

// Sort only scalar keys. Comparator callbacks must not retain the temporary
// per-node/piece arrays, whose nodes belong to this layout operation.
struct InlineBoxPieceDepthOrder {
	index int
	depth int
}

fn compare_inline_box_piece_depth(first &InlineBoxPieceDepthOrder, second &InlineBoxPieceDepthOrder) int {
	if first.depth != second.depth {
		return if first.depth > second.depth { -1 } else { 1 }
	}
	return if first.index < second.index {
		-1
	} else if first.index > second.index {
		1
	} else {
		0
	}
}

struct InlineBoxPieceEmissionOrder {
	index      int
	line_index int
	depth      int
	discovery  int
}

fn compare_inline_box_piece_emission(first &InlineBoxPieceEmissionOrder, second &InlineBoxPieceEmissionOrder) int {
	if first.line_index != second.line_index {
		return if first.line_index < second.line_index { -1 } else { 1 }
	}
	if first.depth != second.depth {
		return if first.depth < second.depth { -1 } else { 1 }
	}
	if first.discovery != second.discovery {
		return if first.discovery < second.discovery { -1 } else { 1 }
	}
	return 0
}

// Node::is_fragmented_inline().
fn is_fragmented_inline(node &Node) bool {
	return node.is_inline_node() || (node.is_list_item_box() && node.display().is_inline_outside()
		&& node.display().is_flow_inside())
}

// Node::nearest_fragmented_inline_ancestor().
fn nearest_fragmented_inline_ancestor(node &Node) ?&Node {
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if !current.display().is_inline_outside() || !current.display().is_flow_inside() {
			break
		}
		if is_fragmented_inline(current) {
			return current
		}
		ancestor = current.parent()
	}
	return none
}

fn fragmented_inline_nesting_depth(node &Node) int {
	mut depth := 1
	mut ancestor := nearest_fragmented_inline_ancestor(node)
	for ancestor != none {
		current := ancestor or { break }
		depth++
		ancestor = nearest_fragmented_inline_ancestor(current)
	}
	return depth
}

fn inline_box_piece_line_index(mut per_node InlineBoxPieceNode, line_index int) int {
	for index, line in per_node.lines {
		if line.line_index == line_index {
			return index
		}
	}
	per_node.lines << InlineBoxPieceLine{
		line_index: line_index
	}
	return per_node.lines.len - 1
}

fn (mut line InlineBoxPieceLine) note_contribution(inline_start CSSPixels, inline_end CSSPixels, block_start CSSPixels) {
	if !line.has_contributions || inline_start.raw_value() < line.contributions_inline_start.raw_value() {
		line.fallback_block_start_from_contributions = block_start
	}
	if !line.has_contributions {
		line.has_contributions = true
		line.contributions_inline_start = inline_start
		line.contributions_inline_end = inline_end
		return
	}
	line.contributions_inline_start = css_pixels_min(line.contributions_inline_start, inline_start)
	line.contributions_inline_end = css_pixels_max(line.contributions_inline_end, inline_end)
}

fn inline_box_piece_node_index(mut per_nodes []InlineBoxPieceNode, mut node_to_index map[u64]int, node &Node) int {
	key := u64(voidptr(node))
	if index := node_to_index[key] {
		return index
	}
	per_nodes << InlineBoxPieceNode{
		node: unsafe { node }
		depth: fragmented_inline_nesting_depth(node)
	}
	node_to_index[key] = per_nodes.len - 1
	return per_nodes.len - 1
}

// InlineFormattingContext::compute_inline_box_pieces(). Rectangles are relative
// to the containing block's content origin and exclude relative positioning.
fn compute_inline_box_pieces(container &Node, used &UsedValues, state &LayoutState) []InlineBoxPiece {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('inline box pieces')
		pieces := compute_inline_box_pieces_in_workspace(container, used, state)
		scratch.leave()
		// Pieces contain retained node pointers and scalar geometry only. The
		// per-node line vectors, lookup map and sorting keys have no later users.
		owned := pieces.clone()
		scratch.finish()
		return owned
	}
	return compute_inline_box_pieces_in_workspace(container, used, state)
}

fn compute_inline_box_pieces_in_workspace(container &Node, used &UsedValues, state &LayoutState) []InlineBoxPiece {
	horizontal := container.computed_values().writing_mode() == .horizontal_tb
	mut per_nodes := []InlineBoxPieceNode{}
	mut node_to_index := map[u64]int{}
	for line_index, line_box in used.line_boxes {
		for fragment in line_box.fragments() {
			if fragment.is_fully_truncated() || fragment.is_block_ellipsis() {
				continue
			}
			fragment_node := fragment.layout_node()
			interrupting := line_box.has_block_level_box()
			position := fragment.offset()
			size := fragment.size()
			mut inline_start := if horizontal { position.x() } else { position.y() }
			mut inline_end := inline_start.plus(if horizontal { size.width() } else { size.height() })
			block_start := if horizontal { position.y() } else { position.x() }
			block_length := if fragment_node.is_generated_for_pseudo_element()
				&& fragment_node.is_text_node() && fragment.length_in_code_units() == 0 {
				CSSPixels.new(0)
			} else if horizontal {
				size.height()
			} else {
				size.width()
			}
			// An atomic inline's fragment covers only its content box; its margin
			// box is what contributes to ancestor extents on the inline axis.
			if !interrupting && fragment.is_atomic_inline() {
				if atomic_styled := fragment_node.as_node_with_style() {
					if atomic_used := state.try_get(atomic_styled) {
						if horizontal {
							inline_start = inline_start.minus(atomic_used.margin_box_left())
							inline_end = inline_end.plus(atomic_used.margin_box_right())
						} else {
							inline_start = inline_start.minus(atomic_used.margin_box_top())
							inline_end = inline_end.plus(atomic_used.margin_box_bottom())
						}
					}
				}
			}
			mut interrupting_corners := InlineBoxPieceCorners{}
			if interrupting {
				if block_styled := fragment_node.as_node_with_style() {
					if block_used := state.try_get(block_styled) {
						extent_inline_start := inline_start.minus(if horizontal {
							block_used.border_box_left()
						} else {
							block_used.border_box_top()
						})
						extent_block_start := block_start.minus(if horizontal {
							block_used.border_box_top()
						} else {
							block_used.border_box_left()
						})
						interrupting_corners = InlineBoxPieceCorners{
							inline_start: extent_inline_start
							inline_end: extent_inline_start.plus(if horizontal {
								block_used.border_box_width()
							} else {
								block_used.border_box_height()
							})
							block_start: extent_block_start
							block_end: extent_block_start.plus(if horizontal {
								block_used.border_box_height()
							} else {
								block_used.border_box_width()
							})
						}
					}
				}
			}
			mut direct := true
			mut previous := -1
			mut ancestor := nearest_fragmented_inline_ancestor(fragment_node)
			for ancestor != none {
				current := ancestor or { break }
				node_index := inline_box_piece_node_index(mut per_nodes, mut node_to_index, current)
				if previous >= 0 {
					per_nodes[previous].parent_index = node_index
				}
				previous = node_index
				mut per_node := unsafe { &per_nodes[node_index] }
				line_slot := inline_box_piece_line_index(mut per_node, line_index)
				mut line := unsafe { &per_node.lines[line_slot] }
				if interrupting {
					if line.interrupting_block_position == none {
						line.interrupting_block_position = position
						line.interrupting_block_corners = interrupting_corners
					}
					ancestor = nearest_fragmented_inline_ancestor(current)
					continue
				}
				if direct {
					line.note_contribution(inline_start, inline_end, block_start)
					if line.first_direct_fragment_block_start == none {
						line.first_direct_fragment_block_start = block_start
					}
					line.max_direct_fragment_block_length = css_pixels_max(line.max_direct_fragment_block_length,
						block_length)
				} else if line.fallback_block_start_from_contributions == none {
					line.fallback_block_start_from_contributions = block_start
				}
				if per_node.first_line_with_content < 0 {
					per_node.first_line_with_content = line_index
				}
				per_node.last_line_with_content = line_index
				direct = false
				ancestor = nearest_fragmented_inline_ancestor(current)
			}
		}
	}

	// Nested boxes' pieces expand their ancestors' extents, so emit the deepest
	// boxes first.
	mut order := []InlineBoxPieceDepthOrder{cap: per_nodes.len}
	for index, per_node in per_nodes {
		order << InlineBoxPieceDepthOrder{ index: index, depth: per_node.depth }
	}
	order.sort_with_compare(compare_inline_box_piece_depth)

	mut pieces := []InlineBoxPiece{}
	mut piece_depths := []int{}
	mut piece_discovery := []int{}
	for entry in order {
		node_index := entry.index
		node := per_nodes[node_index].node
		node_styled := node.as_node_with_style() or { continue }
		node_used := state.try_get(node_styled) or { continue }
		reversed := node.computed_values().direction() == .rtl
		border_padding_low := if horizontal { node_used.border_box_left() } else { node_used.border_box_top() }
		border_padding_high := if horizontal {
			node_used.border_box_right()
		} else {
			node_used.border_box_bottom()
		}
		border_padding_block_low := if horizontal {
			node_used.border_box_top()
		} else {
			node_used.border_box_left()
		}
		border_padding_block_high := if horizontal {
			node_used.border_box_bottom()
		} else {
			node_used.border_box_right()
		}
		margin_low := if horizontal { node_used.margin_left } else { node_used.margin_top }
		margin_high := if horizontal { node_used.margin_right } else { node_used.margin_bottom }
		first_line_with_content := per_nodes[node_index].first_line_with_content
		last_line_with_content := per_nodes[node_index].last_line_with_content
		parent_index := per_nodes[node_index].parent_index
		depth := per_nodes[node_index].depth
		lines := per_nodes[node_index].lines.clone()
		for line in lines {
			if !line.has_contributions {
				if block_position := line.interrupting_block_position {
					pieces << InlineBoxPiece{
						node: node
						line_index: line.line_index
						border_box_rect: css.CSSPixelRect{
							x: block_position.x()
							y: block_position.y()
						}
						has_low_edge: true
						has_high_edge: true
						is_geometry_only_placeholder: true
						corners: line.interrupting_block_corners
					}
					piece_depths << depth
					piece_discovery << node_index
				}
				continue
			}
			is_first_content_line := first_line_with_content == line.line_index
			is_last_content_line := last_line_with_content == line.line_index
			has_low_edge := if reversed { is_last_content_line } else { is_first_content_line }
			has_high_edge := if reversed { is_first_content_line } else { is_last_content_line }
			content_block_start := line.first_direct_fragment_block_start or {
				line.fallback_block_start_from_contributions or { CSSPixels.new(0) }
			}
			content_block_length := if line.first_direct_fragment_block_start != none {
				line.max_direct_fragment_block_length
			} else {
				node.computed_values().line_height()
			}
			border_inline_start := line.contributions_inline_start.minus(if has_low_edge {
				border_padding_low
			} else {
				CSSPixels.new(0)
			})
			border_inline_end := line.contributions_inline_end.plus(if has_high_edge {
				border_padding_high
			} else {
				CSSPixels.new(0)
			})
			border_block_start := content_block_start.minus(border_padding_block_low)
			border_block_length :=
				content_block_length.plus(border_padding_block_low).plus(border_padding_block_high)
			rect := if horizontal {
				css.CSSPixelRect{
					x: border_inline_start
					y: border_block_start
					width: border_inline_end.minus(border_inline_start)
					height: border_block_length
				}
			} else {
				css.CSSPixelRect{
					x: border_block_start
					y: border_inline_start
					width: border_block_length
					height: border_inline_end.minus(border_inline_start)
				}
			}
			pieces << InlineBoxPiece{
				node: node
				line_index: line.line_index
				border_box_rect: rect
				has_low_edge: has_low_edge
				has_high_edge: has_high_edge
				corners: InlineBoxPieceCorners{
					inline_start: border_inline_start
					inline_end: border_inline_end
					block_start: border_block_start
					block_end: border_block_start.plus(border_block_length)
				}
			}
			piece_depths << depth
			piece_discovery << node_index
			if parent_index >= 0 {
				mut parent := unsafe { &per_nodes[parent_index] }
				parent_line_slot := inline_box_piece_line_index(mut parent, line.line_index)
				margin_box_inline_start := border_inline_start.minus(if has_low_edge {
					margin_low
				} else {
					CSSPixels.new(0)
				})
				margin_box_inline_end := border_inline_end.plus(if has_high_edge {
					margin_high
				} else {
					CSSPixels.new(0)
				})
				parent.lines[parent_line_slot].note_contribution(margin_box_inline_start,
					margin_box_inline_end, content_block_start)
			}
		}
	}
	// Emit in line order, then outermost box first, then discovery order.
	mut emission := []InlineBoxPieceEmissionOrder{cap: pieces.len}
	for index, piece in pieces {
		emission << InlineBoxPieceEmissionOrder{
			index:      index
			line_index: piece.line_index
			depth:      piece_depths[index]
			discovery:  piece_discovery[index]
		}
	}
	emission.sort_with_compare(compare_inline_box_piece_emission)
	return emission.map(pieces[it.index])
}

// InlinePaintable geometry: the unions of a box's piece content, padding, and
// border rectangles. A degenerate placeholder only establishes a position; the
// first one wins and any real rectangle takes precedence.
struct InlineBoxGeometry {
	content_rect css.CSSPixelRect
	padding_rect css.CSSPixelRect
	border_rect  css.CSSPixelRect
}

fn unite_inline_piece_rect(target ?css.CSSPixelRect, rect css.CSSPixelRect) css.CSSPixelRect {
	current := target or { return rect }
	if rect.width.raw_value() <= 0 || rect.height.raw_value() <= 0 {
		return current
	}
	if current.width.raw_value() <= 0 || current.height.raw_value() <= 0 {
		return rect
	}
	left := css_pixels_min(current.x, rect.x)
	top := css_pixels_min(current.y, rect.y)
	right := css_pixels_max(current.x.plus(current.width), rect.x.plus(rect.width))
	bottom := css_pixels_max(current.y.plus(current.height), rect.y.plus(rect.height))
	return css.CSSPixelRect{
		x: left
		y: top
		width: right.minus(left)
		height: bottom.minus(top)
	}
}

// Shrink a piece's border box by the node's border and padding on its present
// edges. Block-axis edges are present on every piece.
fn inline_piece_inner_rect(piece InlineBoxPiece, horizontal bool, used &UsedValues, include_padding bool) css.CSSPixelRect {
	mut left := used.border_left
	mut right := used.border_right
	mut top := used.border_top
	mut bottom := used.border_bottom
	if include_padding {
		left = left.plus(used.padding_left)
		right = right.plus(used.padding_right)
		top = top.plus(used.padding_top)
		bottom = bottom.plus(used.padding_bottom)
	}
	if horizontal {
		if !piece.has_low_edge {
			left = CSSPixels.new(0)
		}
		if !piece.has_high_edge {
			right = CSSPixels.new(0)
		}
	} else {
		if !piece.has_low_edge {
			top = CSSPixels.new(0)
		}
		if !piece.has_high_edge {
			bottom = CSSPixels.new(0)
		}
	}
	rect := piece.border_box_rect
	return css.CSSPixelRect{
		x: rect.x.plus(left)
		y: rect.y.plus(top)
		width: css_pixels_max(CSSPixels.new(0), rect.width.minus(left).minus(right))
		height: css_pixels_max(CSSPixels.new(0), rect.height.minus(top).minus(bottom))
	}
}

// PaintableWithLines::assign_inline_box_geometry() for a single box.
// Rectangles are relative to the containing block's content origin.
fn inline_box_geometry_from_pieces(node &Node, pieces []InlineBoxPiece, horizontal bool, used &UsedValues) ?InlineBoxGeometry {
	mut content_union := ?css.CSSPixelRect(none)
	mut padding_union := ?css.CSSPixelRect(none)
	mut border_union := ?css.CSSPixelRect(none)
	for piece in pieces {
		if !layout_nodes_same(piece.node, node) {
			continue
		}
		if piece.is_geometry_only_placeholder {
			// Placeholder pieces carry the degenerate content rect directly.
			content_rect := piece.border_box_rect
			padding_rect := css.CSSPixelRect{
				x: content_rect.x.minus(used.padding_left)
				y: content_rect.y.minus(used.padding_top)
				width: content_rect.width.plus(used.padding_left).plus(used.padding_right)
				height: content_rect.height.plus(used.padding_top).plus(used.padding_bottom)
			}
			border_rect := css.CSSPixelRect{
				x: padding_rect.x.minus(used.border_left)
				y: padding_rect.y.minus(used.border_top)
				width: padding_rect.width.plus(used.border_left).plus(used.border_right)
				height: padding_rect.height.plus(used.border_top).plus(used.border_bottom)
			}
			content_union = unite_inline_piece_rect(content_union, content_rect)
			padding_union = unite_inline_piece_rect(padding_union, padding_rect)
			border_union = unite_inline_piece_rect(border_union, border_rect)
			continue
		}
		content_union = unite_inline_piece_rect(content_union, inline_piece_inner_rect(piece,
			horizontal, used, true))
		padding_union = unite_inline_piece_rect(padding_union, inline_piece_inner_rect(piece,
			horizontal, used, false))
		border_union = unite_inline_piece_rect(border_union, piece.border_box_rect)
	}
	content := content_union or { return none }
	return InlineBoxGeometry{
		content_rect: content
		padding_rect: padding_union or { content }
		border_rect: border_union or { content }
	}
}

// The InlinePaintable geometry of `node` in absolute (layout-space)
// coordinates, including the relative offsets of the box and its inline
// ancestors. Fragmented inlines with a DOM node but no fragments get a
// placeholder at the containing block's content origin with the box's line
// height, so DOM geometry queries have something to answer from.
fn inline_box_absolute_geometry(node &Node, state &LayoutState) ?InlineBoxGeometry {
	mut pieces_by_container := map[u64][]InlineBoxPiece{}
	return inline_box_absolute_geometry_cached(node, state, mut pieces_by_container)
}

// As above, reusing pieces already computed for the same containing block
// during one traversal of a laid-out tree.
fn inline_box_absolute_geometry_cached(node &Node, state &LayoutState, mut pieces_by_container map[u64][]InlineBoxPiece) ?InlineBoxGeometry {
	containing_block := node.containing_block() or { return none }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return none }
	containing_used := state.try_get(containing_styled) or { return none }
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	horizontal := containing_node.computed_values().writing_mode() == .horizontal_tb
	container_position := layout_offset_in_svg_user_space(containing_node, state, containing_used)
	container_key := u64(voidptr(containing_node))
	if container_key !in pieces_by_container {
		pieces_by_container[container_key] = compute_inline_box_pieces(containing_node,
			containing_used, state)
	}
	pieces := pieces_by_container[container_key] or { []InlineBoxPiece{} }
	local := inline_box_geometry_from_pieces(node, pieces, horizontal, used) or {
		if node.dom_node() == none && !node.is_generated_for_pseudo_element() {
			return none
		}
		// Generated pseudo boxes whose quote controls resolve to no text remain
		// visible in the layout-tree dump, but do not acquire a line-height box.
		line_height := if node.dom_node() == none {
			CSSPixels.new(0)
		} else {
			node.computed_values().line_height()
		}
		placeholder := InlineBoxPiece{
			node: node
			border_box_rect: css.CSSPixelRect{
				width: if horizontal { CSSPixels.new(0) } else { line_height }
				height: if horizontal { line_height } else { CSSPixels.new(0) }
			}
			has_low_edge: true
			has_high_edge: true
			is_geometry_only_placeholder: true
		}
		inline_box_geometry_from_pieces(node, [placeholder], horizontal, used) or { return none }
	}
	own_relative := if node.computed_values().position() == .relative {
		css.CSSPixelPoint.from_values(used.inset_left.to_double(), used.inset_top.to_double())
	} else {
		css.CSSPixelPoint.from_values(0, 0)
	}
	offset := css_pixel_point_add(css_pixel_point_add(container_position, own_relative),
		inline_relative_offset(node, state))
	return InlineBoxGeometry{
		content_rect: translate_css_pixel_rect(local.content_rect, offset)
		padding_rect: translate_css_pixel_rect(local.padding_rect, offset)
		border_rect: translate_css_pixel_rect(local.border_rect, offset)
	}
}

fn translate_css_pixel_rect(rect css.CSSPixelRect, offset css.CSSPixelPoint) css.CSSPixelRect {
	return css.CSSPixelRect{
		x: rect.x.plus(offset.x())
		y: rect.y.plus(offset.y())
		width: rect.width
		height: rect.height
	}
}

// CSS 2 10.1: an inline containing block's rectangle spans the padding boxes
// of its first and last content lines. Borders contract the inline edges only
// when the box and its container share an inline direction. The rectangle is
// relative to the IFC root's content origin and includes the relative offsets
// of the box and its inline ancestors.
fn inline_containing_block_padding_rect(node &Node, state &LayoutState) ?css.CSSPixelRect {
	containing_block := node.containing_block() or { return none }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return none }
	containing_used := state.try_get(containing_styled) or { return none }
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	horizontal := containing_node.computed_values().writing_mode() == .horizontal_tb
	pieces := compute_inline_box_pieces(containing_node, containing_used, state)
	mut first := ?InlineBoxPieceCorners(none)
	mut last := ?InlineBoxPieceCorners(none)
	for piece in pieces {
		if !layout_nodes_same(piece.node, node) {
			continue
		}
		if first == none {
			first = piece.corners
		}
		last = piece.corners
	}
	mut rect := css.CSSPixelRect{}
	if first_corners := first {
		last_corners := last or { first_corners }
		border_inline_low := if horizontal { used.border_left } else { used.border_top }
		border_inline_high := if horizontal { used.border_right } else { used.border_bottom }
		border_block_low := if horizontal { used.border_top } else { used.border_left }
		border_block_high := if horizontal { used.border_bottom } else { used.border_right }
		reversed := node.computed_values().direction() == .rtl
		container_reversed := containing_node.computed_values().direction() == .rtl
		direction_matches := reversed == container_reversed
		contracted_inline_low := if direction_matches { border_inline_low } else { CSSPixels.new(0) }
		contracted_inline_high := if direction_matches {
			border_inline_high
		} else {
			CSSPixels.new(0)
		}
		block_start := first_corners.block_start.plus(border_block_low)
		block_size := css_pixels_max(CSSPixels.new(0), last_corners.block_end.minus(border_block_high).minus(block_start))
		mut inline_low := CSSPixels.new(0)
		mut inline_size := CSSPixels.new(0)
		if !container_reversed {
			start := first_corners.inline_start.plus(contracted_inline_low)
			end := last_corners.inline_end.minus(contracted_inline_high)
			inline_low = start
			inline_size = css_pixels_max(CSSPixels.new(0), end.minus(start))
		} else {
			start := first_corners.inline_end.minus(contracted_inline_high)
			end := last_corners.inline_start.plus(contracted_inline_low)
			inline_size = css_pixels_max(CSSPixels.new(0), start.minus(end))
			inline_low = start.minus(inline_size)
		}
		rect = if horizontal {
			css.CSSPixelRect{
				x: inline_low
				y: block_start
				width: inline_size
				height: block_size
			}
		} else {
			css.CSSPixelRect{
				x: block_start
				y: inline_low
				width: block_size
				height: inline_size
			}
		}
	} else {
		if node.dom_node() == none {
			return none
		}
		line_height := node.computed_values().line_height()
		rect = css.CSSPixelRect{
			width: if horizontal { CSSPixels.new(0) } else { line_height }
			height: if horizontal { line_height } else { CSSPixels.new(0) }
		}
	}
	own_relative := if node.computed_values().position() == .relative {
		css.CSSPixelPoint.from_values(used.inset_left.to_double(), used.inset_top.to_double())
	} else {
		css.CSSPixelPoint.from_values(0, 0)
	}
	return translate_css_pixel_rect(rect, css_pixel_point_add(own_relative, inline_relative_offset(node,
		state)))
}
