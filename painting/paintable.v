module painting

import math
import platform

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
pub mut:
	paintable_id            string
	layout_node_id          string
	text_value              string
	offset                  Point
	size                    Size
	containing_block_offset Point
	start_offset            int
	length_in_code_units    int
	uses_text_mapping       bool
	rendered_start_offset   int
	source_range_start      int
	source_range_length     int
	text_mapping_edits      []platform.TextMappingEdit
	glyphs                  []GlyphMetric
	// The active layout bridge retains the shaped run exactly, matching C++'s
	// RefPtr<Gfx::GlyphRun>. Standalone painting callers can keep supplying the
	// compact GlyphMetric vector above.
	glyph_run               ?&platform.GlyphRun
	baseline                f64
	font_ascent             f64
	font_descent            f64
	orientation             Orientation
	has_trailing_whitespace bool
	space_width             f64
	shadow_values           []ShadowData
	decoration_thickness    f64
}

struct GlyphRunCluster {
	start int
	end   int
	width f64
}

struct GlyphRunClusterIterator {
	glyphs          []platform.Glyph
	fragment_length int
mut:
	glyph_index int
	cursor      int
}

fn (mut iterator GlyphRunClusterIterator) next() ?GlyphRunCluster {
	for iterator.glyph_index < iterator.glyphs.len {
		glyph := iterator.glyphs[iterator.glyph_index]
		iterator.glyph_index++
		if glyph.advance == 0 {
			continue
		}
		cluster_start := iterator.cursor
		cluster_end := min_int(iterator.cursor + glyph.length_in_code_units, iterator.fragment_length)
		iterator.cursor = cluster_end
		if cluster_end <= cluster_start {
			continue
		}
		return GlyphRunCluster{cluster_start, cluster_end, f64(glyph.advance)}
	}
	return none
}

struct FragmentGraphemeEdgeTracker {
	target_width f64
mut:
	left_edge           int
	right_edge          int
	width_to_left_edge  f64
	width_to_right_edge f64
}

fn (mut tracker FragmentGraphemeEdgeTracker) update(length_in_code_units int, width f64) bool {
	if width == 0 {
		return false
	}
	tracker.right_edge += length_in_code_units
	tracker.width_to_right_edge += width
	if tracker.width_to_right_edge >= tracker.target_width {
		return true
	}
	tracker.left_edge = tracker.right_edge
	tracker.width_to_left_edge = tracker.width_to_right_edge
	return false
}

fn (tracker FragmentGraphemeEdgeTracker) resolve() int {
	if tracker.target_width - tracker.width_to_left_edge < tracker.width_to_right_edge - tracker.target_width {
		return tracker.left_edge
	}
	return tracker.right_edge
}

fn fragment_utf16_length(text string) int {
	mut length := 0
	for code_point in text.runes() {
		length += if code_point > 0xffff { 2 } else { 1 }
	}
	return length
}

fn fragment_grapheme_boundaries(text string) []int {
	mut boundaries := [0]
	mut code_units := 0
	for grapheme in text.graphemes() {
		code_units += fragment_utf16_length(grapheme)
		boundaries << code_units
	}
	return boundaries
}

fn next_fragment_grapheme_boundary(boundaries []int, offset int) ?int {
	for boundary in boundaries {
		if boundary > offset {
			return boundary
		}
	}
	return none
}

pub fn (fragment PaintableFragment) absolute_rect() Rect {
	return Rect{fragment.offset.x + fragment.containing_block_offset.x, fragment.offset.y + fragment.containing_block_offset.y, fragment.size.width, fragment.size.height}
}

// Painting/text_fragment.rs converts retained rendered spans through the text
// snapshot's edit map, preserving source positions after expanding casing.
pub fn (fragment PaintableFragment) source_offset_for_local_rendered(offset int, boundary platform.TextMappingBoundary) int {
	if !fragment.uses_text_mapping { return fragment.start_offset + offset }
	return platform.source_offset_for_rendered_text_offset(fragment.text_mapping_edits,
		fragment.source_range_start, fragment.rendered_start_offset + offset, boundary)
}

pub fn (fragment PaintableFragment) source_end_offset() int {
	return fragment.source_offset_for_local_rendered(fragment.length_in_code_units, .end)
}

fn (fragment PaintableFragment) local_rendered_offset_for_source(offset int, boundary platform.TextMappingBoundary) int {
	if !fragment.uses_text_mapping {
		local := offset - fragment.start_offset
		return if local < 0 {
			0
		} else if local > fragment.length_in_code_units {
			fragment.length_in_code_units
		} else {
			local
		}
	}
	source_end := fragment.source_range_start + fragment.source_range_length
	clamped := if offset < fragment.source_range_start {
		fragment.source_range_start
	} else if offset > source_end {
		source_end
	} else {
		offset
	}
	rendered := platform.rendered_text_offset_for_source_offset(fragment.text_mapping_edits,
		fragment.source_range_start, clamped, boundary)
	local := rendered - fragment.rendered_start_offset
	return if local < 0 {
		0
	} else if local > fragment.length_in_code_units {
		fragment.length_in_code_units
	} else {
		local
	}
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
	if run := fragment.glyph_run {
		// Hit testing returns an offset, so grapheme decoding and boundary
		// vectors must not accumulate in the document or persistent arena.
		scratch := platform.begin_thread_scratch('fragment hit test')
		defer { scratch.finish() }
		mut tracker := FragmentGraphemeEdgeTracker{
			target_width: relative
		}
		boundaries := fragment_grapheme_boundaries(fragment.text_value)
		mut clusters := GlyphRunClusterIterator{
			glyphs: run.glyphs()
			fragment_length: fragment.length_in_code_units
		}
		for {
			cluster := clusters.next() or { break }
			per_unit_advance := cluster.width / f64(cluster.end - cluster.start)
			rendered_fragment_start := if fragment.uses_text_mapping {
				fragment.rendered_start_offset
			} else {
				fragment.start_offset
			}
			mut grapheme_start := rendered_fragment_start + cluster.start
			cluster_absolute_end := rendered_fragment_start + cluster.end
			for grapheme_start < cluster_absolute_end {
				grapheme_end := min_int(next_fragment_grapheme_boundary(boundaries, grapheme_start) or { cluster_absolute_end }, cluster_absolute_end)
				if grapheme_end <= grapheme_start {
					break
				}
				grapheme_units := grapheme_end - grapheme_start
				if tracker.update(grapheme_units, per_unit_advance * f64(grapheme_units)) {
					return fragment.source_offset_for_local_rendered(tracker.resolve(), .end)
				}
				grapheme_start = grapheme_end
			}
		}
		return fragment.source_offset_for_local_rendered(min_int(tracker.resolve(), fragment.length_in_code_units), .end)
	} else {
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
		return fragment.source_offset_for_local_rendered(min_int(consumed_units, fragment.length_in_code_units), .end)
	}
}

pub fn (fragment PaintableFragment) compute_selection_offsets(state SelectionState,
	start_offset int, end_offset int) ?SelectionOffsets {
	start_index := fragment.start_offset
	end_index := fragment.source_end_offset()
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
					start:                       fragment.local_rendered_offset_for_source(start_offset,
						.start)
					end:                         fragment.local_rendered_offset_for_source(end_offset,
						.end)
					include_trailing_whitespace: end_offset >= end_index
				}
			}
		}
		.start {
			if end_index < start_offset {
				none
			} else {
				SelectionOffsets{fragment.local_rendered_offset_for_source(start_offset, .start), fragment.length_in_code_units, true}
			}
		}
		.end {
			if start_index > end_offset {
				none
			} else {
				SelectionOffsets{0, fragment.local_rendered_offset_for_source(end_offset, .end), end_offset >= end_index}
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
	if offsets.start == 0 && offsets.end == fragment.length_in_code_units && fragment.length_in_code_units > 0 {
		pixel_width = if fragment.orientation == .horizontal { rect.width } else { rect.height }
	} else {
		if run := fragment.glyph_run {
			mut clusters := GlyphRunClusterIterator{
				glyphs: run.glyphs()
				fragment_length: fragment.length_in_code_units
			}
			for {
				cluster := clusters.next() or { break }
				if cluster.end <= offsets.start {
					pixel_offset += cluster.width
					continue
				}
				if cluster.start >= offsets.end {
					continue
				}
				per_unit_advance := cluster.width / f64(cluster.end - cluster.start)
				if cluster.start < offsets.start {
					pixel_offset += per_unit_advance * f64(offsets.start - cluster.start)
				}
				in_selection_start := max_int(cluster.start, offsets.start)
				in_selection_end := min_int(cluster.end, offsets.end)
				pixel_width += per_unit_advance * f64(in_selection_end - in_selection_start)
			}
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
	}
	if offsets.start == offsets.end {
		pixel_width = 1
	}
	if offsets.start != offsets.end && fragment.has_trailing_whitespace && offsets.include_trailing_whitespace {
		pixel_width += if run := fragment.glyph_run {
			f64(run.glyph_width(u16(` `)))
		} else {
			fragment.space_width
		}
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
				paintable_id: node.id
				index_in_node: fragment.index_in_node_for_point(position)
				internal_position: .inside
			}
		}
	}
	if node.rect.contains(position) {
		return HitTestResult{
			paintable_id: node.id
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
	return Rect{box.containing_block_position.x + box.offset.x, box.containing_block_position.y + box.offset.y, box.content_size.width, box.content_size.height}
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
	constrained := Point{math.max(0.0, math.min(max_x, offset.x)), math.max(0.0, math.min(max_y, offset.y))}
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
	paintable_id             string
	parent_id                string
	paintable_box_id         string
	z_index                  int
	tree_order               int
	opacity                  f64 = 1.0
	non_invertible_transform bool
pub mut:
	children                 []StackingContext
	last_paint_generation_id ?u64
}

pub fn (context StackingContext) parent() string {
	return context.parent_id
}

pub fn (context StackingContext) paintable_box() string {
	return if context.paintable_box_id.len > 0 {
		context.paintable_box_id
	} else {
		context.paintable_id
	}
}

pub fn (context StackingContext) paint_node() []string {
	return [context.paintable_id]
}

pub fn (context StackingContext) paint_node_as_stacking_context() []string {
	return stacking_paint_order(context)
}

pub fn (context StackingContext) paint_svg() []string {
	return stacking_paint_order(context)
}

pub fn (context StackingContext) paint_descendants() []string {
	mut sorted_context := context
	sorted_context.sort()
	mut result := []string{}
	for child in sorted_context.children {
		append_stacking_paint_order(child, mut result)
	}
	return result
}

pub fn (context StackingContext) paint_child(index int) []string {
	return if index >= 0 && index < context.children.len {
		context.children[index].paint()
	} else {
		[]
	}
}

pub fn (context StackingContext) paint_internal() []string {
	return stacking_paint_order(context)
}

pub fn (context StackingContext) paint() []string {
	// StackingContext::paint() rejects non-invertible transforms and fully
	// transparent contexts before recording any descendant commands.
	if context.non_invertible_transform || context.opacity == 0 {
		return []string{}
	}
	return stacking_paint_order(context)
}

pub fn (context StackingContext) hit_test(id string) ?string {
	if context.paintable_id == id {
		return id
	}
	for child in context.children.reverse() {
		if found := child.hit_test(id) {
			return found
		}
	}
	return none
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
	mut sorted_context := context
	sorted_context.sort()
	mut order := []string{}
	append_stacking_paint_order(sorted_context, mut order)
	return order
}

fn append_stacking_paint_order(context StackingContext, mut order []string) {
	if context.non_invertible_transform || context.opacity == 0 {
		return
	}
	order << context.paintable_id
	for child in context.children {
		if child.z_index < 0 {
			append_stacking_paint_order(child, mut order)
		}
	}
	for child in context.children {
		if child.z_index == 0 {
			append_stacking_paint_order(child, mut order)
		}
	}
	for child in context.children {
		if child.z_index > 0 {
			append_stacking_paint_order(child, mut order)
		}
	}
}
