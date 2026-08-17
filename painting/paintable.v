module painting

import math

pub enum PaintPhase {
	background
	border
	table_collapsed_border
	foreground
	outline
	overlay
}

pub enum SelectionState {
	none
	start
	end
	start_and_end
	full
}

pub enum HitTestType {
	exact
	text_cursor
}

pub enum InternalPosition {
	none
	before
	inside
	after
}

pub struct HitTestResult {
pub:
	paintable_id        string
	chrome_widget_id    string
	index_in_node       int
	vertical_distance   ?f64
	horizontal_distance ?f64
	internal_position   InternalPosition
}

pub struct GlyphMetric {
pub:
	length_in_code_units int = 1
	width                f64
}

pub struct SelectionOffsets {
pub:
	start                       int
	end                         int
	include_trailing_whitespace bool
}

pub struct PaintableFragment {
pub:
	paintable_id            string
	offset                  Point
	size                    Size
	containing_block_offset Point
	start_offset            int
	length_in_code_units    int
	glyphs                  []GlyphMetric
	baseline                f64
	font_ascent             f64
	font_descent            f64
	orientation             Orientation
	has_trailing_whitespace bool
	space_width             f64
}

pub fn (fragment PaintableFragment) absolute_rect() Rect {
	return Rect{fragment.offset.x + fragment.containing_block_offset.x, fragment.offset.y +
		fragment.containing_block_offset.y, fragment.size.width, fragment.size.height}
}

pub fn (fragment PaintableFragment) index_in_node_for_point(position Point) int {
	rect := fragment.absolute_rect()
	relative := if fragment.orientation == .horizontal {
		position.x - rect.x
	} else {
		position.y - rect.y
	}
	if relative < 0 {
		return 0
	}
	mut consumed_width := f64(0)
	mut consumed_units := 0
	for glyph in fragment.glyphs {
		if relative < consumed_width + glyph.width / 2.0 {
			break
		}
		consumed_width += glyph.width
		consumed_units += glyph.length_in_code_units
		if relative < consumed_width {
			break
		}
	}
	return fragment.start_offset + min_int(consumed_units, fragment.length_in_code_units)
}

pub fn (fragment PaintableFragment) compute_selection_offsets(state SelectionState,
	start_offset int, end_offset int) ?SelectionOffsets {
	start_index := fragment.start_offset
	end_index := fragment.start_offset + fragment.length_in_code_units
	return match state {
		.none {
			none
		}
		.full {
			SelectionOffsets{0, fragment.length_in_code_units, true}
		}
		.start_and_end {
			if start_index > end_offset || end_index < start_offset {
				none
			} else {
				SelectionOffsets{
					start:                       start_offset - min_int(start_offset,
						fragment.start_offset)
					end:                         min_int(end_offset - fragment.start_offset,
						fragment.length_in_code_units)
					include_trailing_whitespace: end_offset >= end_index
				}
			}
		}
		.start {
			if end_index < start_offset {
				none
			} else {
				SelectionOffsets{start_offset - min_int(start_offset, fragment.start_offset), fragment.length_in_code_units, true}
			}
		}
		.end {
			if start_index > end_offset {
				none
			} else {
				SelectionOffsets{0, min_int(end_offset - fragment.start_offset,
					fragment.length_in_code_units), end_offset >= end_index}
			}
		}
	}
}

pub fn (fragment PaintableFragment) range_rect(state SelectionState, start_offset int,
	end_offset int) Rect {
	offsets := fragment.compute_selection_offsets(state, start_offset, end_offset) or {
		return Rect{}
	}
	mut rect := fragment.absolute_rect()
	mut pixel_offset := f64(0)
	mut pixel_width := f64(0)
	if offsets.start == 0 && offsets.end == fragment.length_in_code_units
		&& fragment.length_in_code_units > 0 {
		pixel_width = if fragment.orientation == .horizontal { rect.width } else { rect.height }
	} else {
		mut units_seen := 0
		for glyph in fragment.glyphs {
			if units_seen < offsets.start {
				pixel_offset += glyph.width
			} else if units_seen < offsets.end {
				pixel_width += glyph.width
			}
			units_seen += glyph.length_in_code_units
		}
	}
	if offsets.start == offsets.end {
		pixel_width = 1
	}
	if offsets.start != offsets.end && fragment.has_trailing_whitespace
		&& offsets.include_trailing_whitespace {
		pixel_width += fragment.space_width
	}
	if fragment.orientation == .horizontal {
		rect = Rect{rect.x + pixel_offset, rect.y, pixel_width, rect.height}
	} else {
		rect = Rect{rect.x, rect.y + pixel_offset, rect.width, pixel_width}
	}
	if fragment.font_ascent > 0 || fragment.font_descent > 0 {
		secondary_size := if fragment.orientation == .horizontal { rect.height } else { rect.width }
		overflow_top := math.max(0.0, fragment.font_ascent - fragment.baseline)
		overflow_bottom := math.max(0.0, fragment.font_descent - secondary_size + fragment.baseline)
		if fragment.orientation == .horizontal {
			rect = rect.inflated(overflow_top, 0, overflow_bottom, 0)
		} else {
			rect = rect.inflated(0, overflow_bottom, 0, overflow_top)
		}
	}
	return rect
}

pub struct PaintableNode {
pub:
	id                       string
	parent_index             int = -1
	rect                     Rect
	visible                  bool = true
	pointer_events_enabled   bool = true
	non_invertible_transform bool
	z_index                  int
	tree_order               int
	fragments                []PaintableFragment
	children                 []int
}

pub struct PaintableTree {
pub:
	nodes []PaintableNode
}

fn (tree PaintableTree) hit_test_node(index int, position Point, hit_type HitTestType) ?HitTestResult {
	if index < 0 || index >= tree.nodes.len {
		return none
	}
	node := tree.nodes[index]
	if node.non_invertible_transform {
		return none
	}
	mut ordered_children := node.children.clone()
	ordered_children.sort_with_compare(fn [tree] (a &int, b &int) int {
		first := tree.nodes[*a]
		second := tree.nodes[*b]
		if first.z_index != second.z_index {
			return second.z_index - first.z_index
		}
		return second.tree_order - first.tree_order
	})
	for child in ordered_children {
		if hit := tree.hit_test_node(child, position, hit_type) {
			return hit
		}
	}
	if !node.visible || !node.pointer_events_enabled {
		return none
	}
	for fragment in node.fragments.reverse() {
		if fragment.absolute_rect().contains(position) || hit_type == .text_cursor {
			return HitTestResult{
				paintable_id:      node.id
				index_in_node:     fragment.index_in_node_for_point(position)
				internal_position: .inside
			}
		}
	}
	if node.rect.contains(position) {
		return HitTestResult{
			paintable_id:      node.id
			internal_position: .inside
		}
	}
	return none
}

pub fn (tree PaintableTree) hit_test(root int, position Point, hit_type HitTestType) ?HitTestResult {
	return tree.hit_test_node(root, position, hit_type)
}

pub struct OverflowData {
pub:
	scrollable_overflow_rect Rect
	has_scrollable_overflow  bool
}

pub struct PaintableBox {
pub:
	id                        string
	offset                    Point
	content_size              Size
	containing_block_position Point
	box_model                 BoxModelMetrics
	overflow                  ?OverflowData
pub mut:
	scroll_offset   Point
	cached_commands map[PaintPhase][]DisplayListCommand
}

pub fn (box PaintableBox) absolute_rect() Rect {
	return Rect{box.containing_block_position.x + box.offset.x, box.containing_block_position.y +
		box.offset.y, box.content_size.width, box.content_size.height}
}

pub fn (box PaintableBox) absolute_padding_box_rect() Rect {
	content := box.absolute_rect()
	padding := box.box_model.padding
	return content.inflated(padding.top, padding.right, padding.bottom, padding.left)
}

pub fn (box PaintableBox) absolute_border_box_rect() Rect {
	padding := box.absolute_padding_box_rect()
	border := box.box_model.border
	return padding.inflated(border.top, border.right, border.bottom, border.left)
}

pub fn (mut box PaintableBox) set_scroll_offset(offset Point) bool {
	overflow := box.overflow or { return false }
	if !overflow.has_scrollable_overflow {
		return false
	}
	padding := box.absolute_padding_box_rect()
	max_x := math.max(overflow.scrollable_overflow_rect.width - padding.width, 0.0)
	max_y := math.max(overflow.scrollable_overflow_rect.height - padding.height, 0.0)
	constrained := Point{math.max(0.0, math.min(max_x, offset.x)), math.max(0.0, math.min(max_y,
		offset.y))}
	if constrained == box.scroll_offset {
		return false
	}
	box.scroll_offset = constrained
	return true
}

pub fn (mut box PaintableBox) scroll_by(delta_x int, delta_y int) bool {
	return box.set_scroll_offset(box.scroll_offset.add(Point{delta_x, delta_y}))
}

pub fn (mut box PaintableBox) scroll_into_view(rect Rect) bool {
	scrollport := box.absolute_padding_box_rect()
	content := rect.translated(Point{-scrollport.x, -scrollport.y})
	mut target := box.scroll_offset
	if content.right() > target.x + scrollport.width {
		target = Point{content.right() - scrollport.width, target.y}
	} else if content.left() < target.x {
		target = Point{content.left(), target.y}
	}
	if content.bottom() > target.y + scrollport.height {
		target = Point{target.x, content.bottom() - scrollport.height}
	} else if content.top() < target.y {
		target = Point{target.x, content.top()}
	}
	return box.set_scroll_offset(target)
}

pub fn (mut box PaintableBox) cache_commands(phase PaintPhase, commands []DisplayListCommand) {
	box.cached_commands[phase] = commands.clone()
}

pub fn (mut box PaintableBox) invalidate_paint_cache() {
	box.cached_commands.clear()
}

pub struct StackingContext {
pub:
	paintable_id string
	z_index      int
	tree_order   int
pub mut:
	children                 []StackingContext
	last_paint_generation_id ?u64
}

pub fn (mut context StackingContext) sort() {
	context.children.sort_with_compare(fn (a &StackingContext, b &StackingContext) int {
		if a.z_index != b.z_index {
			return a.z_index - b.z_index
		}
		return a.tree_order - b.tree_order
	})
	for mut child in context.children {
		child.sort()
	}
}

pub fn (mut context StackingContext) set_last_paint_generation_id(id u64) bool {
	if previous := context.last_paint_generation_id {
		if previous >= id {
			return false
		}
	}
	context.last_paint_generation_id = id
	return true
}

pub fn stacking_paint_order(context StackingContext) []string {
	mut negative := []StackingContext{}
	mut zero := []StackingContext{}
	mut positive := []StackingContext{}
	for child in context.children {
		if child.z_index < 0 {
			negative << child
		} else if child.z_index == 0 {
			zero << child
		} else {
			positive << child
		}
	}
	mut order := [context.paintable_id]
	for child in negative {
		order << child.paintable_id
	}
	for child in zero {
		order << child.paintable_id
	}
	for child in positive {
		order << child.paintable_id
	}
	return order
}
