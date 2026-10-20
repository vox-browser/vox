module layout

import css
import platform

struct RetainedBlockPaintLines {
	lines  []TextLine
	origin css.CSSPixelPoint
}

struct RetainedBlockPaintBox {
	box    BlockBox
	origin css.CSSPixelPoint
}

// The independent-context snapshot proves local geometry for every descendant,
// including atomic inline menus. Validate its styles once per paint-tree build.
fn prepare_retained_block_paint_owners(state &LayoutState) {
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	mut current := unsafe { &LayoutState(state) }
	current.block_paint_owners_ = map[u64]&RetainedBlockLayout{}
	for _, cache in state.block_layouts_ {
		if cache.inputs.len == 0 { continue }
		root := cache.inputs[0].node
		if cache.style_environment != root.document().style_environment_version()
			|| cache.font_generation != css.css_style_computer_for(root.document()).font_computer().environment_generation()
			|| cache.font_policy != root.document().font_rendering_policy()
			|| !retained_inline_inputs_are_current(cache.inputs) {
			continue
		}
		mut ancestor := root.parent()
		mut inside_svg := false
		for ancestor != none {
			parent := ancestor or { break }
			if parent.is_svg_box() {
				inside_svg = true
				break
			}
			ancestor = parent.parent()
		}
		if inside_svg { continue }
		for input in cache.inputs {
			if input.node.as_node_with_style() == none { continue }
			key := u64(voidptr(input.node))
			if previous := current.block_paint_owners_[key] {
				if previous.inputs.len >= cache.inputs.len { continue }
			}
			current.block_paint_owners_[key] = cache
		}
	}
}

fn retained_block_text_lines(container &Node, used &UsedValues, state &LayoutState,
	position css.CSSPixelPoint) []TextLine {
	key := u64(voidptr(container))
	if mut owner := state.block_paint_owners_[key] {
		if snapshot := owner.paint_lines_[key] {
			dx := position.x().to_double() - snapshot.origin.x().to_double()
			dy := position.y().to_double() - snapshot.origin.y().to_double()
			if lines := rebase_retained_inline_lines(snapshot.lines, dx, dy) { return lines }
		}
		persistent := platform.enter_persistent_if(platform.transient_arena_entered())
		defer { platform.leave_persistent(persistent) }
		lines := uncached_text_lines_from_typed_layout(container, used, state, position)
		if lines.len > 0 && retained_inline_paint_can_share(lines) {
			if snapshot := rebase_retained_inline_lines(lines, 0, 0) {
				owner.paint_lines_[key] = &RetainedBlockPaintLines{ lines: snapshot, origin: position }
			}
		}
		return lines
	}
	return uncached_text_lines_from_typed_layout(container, used, state, position)
}

fn retained_paint_box_can_share(box &BlockBox) bool {
	return box.background_images.len == 0 && box.background_gradient == none
		&& box.replaced_image_url == '' && box.replaced_image_paintable == none
		&& box.canvas_paintable == none && box.video_paintable == none
		&& box.nested_viewport_paintable == none && box.form_control_kind == ''
		&& box.fieldset_paintable == none && !box.has_svg_path && !box.is_svg_image
		&& box.marker_shape == '' && box.overlay == none && !box.has_scrollable_overflow
		&& box.css_clip == none && box.clip_path == none && box.svg_clip == none && box.svg_mask == none
		&& !box.filter.has_filters() && !box.backdrop_filter.has_filters()
		&& !box.uses_own_paint_transform_4x4 && affine_is_compact_identity(box.paint_transform)
		&& retained_paint_rect_can_translate(box.border_box(), 0, 0)
}

fn retained_paint_rect_can_translate(rect LayoutRect, dx f64, dy f64) bool {
	for value in [rect.x, rect.y, rect.x + rect.width, rect.y + rect.height, rect.x + dx, rect.y + dy,
		rect.x + rect.width + dx, rect.y + rect.height + dy] {
		if CSSPixels.nearest_value_for(value).might_be_saturated() { return false }
	}
	return true
}

fn block_box_from_typed_layout_shallow(node &Node, state &LayoutState,
	ancestor_transform [6]f64) BlockBox {
	mut box := BlockBox{}
	fill_block_box_from_typed_layout_shallow(node, state, ancestor_transform, mut box)
	return box
}

fn fill_block_box_from_typed_layout_shallow(node &Node, state &LayoutState,
	ancestor_transform [6]f64, mut output BlockBox) {
	key := u64(voidptr(node))
	if mut owner := state.block_paint_owners_[key] {
		// A parent's final placement can change its own margins after layout of
		// its contents. Descendant snapshots keep the complete local box model.
		if voidptr(node) != voidptr(owner.inputs[0].node) && !node.is_body() && !node.is_root_element()
			&& affine_is_compact_identity(ancestor_transform) {
			styled := node.as_node_with_style() or {
				output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
				return
			}
			used := state.try_get(styled) or {
				output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
				return
			}
			position := paint_cumulative_offset(node, state, used)
			if snapshot := owner.paint_boxes_[key] {
				if rebase_retained_paint_box_into(snapshot, node, used, state, position, mut output) {
					return
				}
			}
			persistent := platform.enter_persistent_if(platform.transient_arena_entered())
			defer { platform.leave_persistent(persistent) }
			output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
			if retained_paint_box_can_share(&output) {
				mut template := output
				template.lines = []TextLine{}
				owner.paint_boxes_[key] = &RetainedBlockPaintBox{ box: template, origin: position }
			}
			return
		}
	}
	fill_ordinary_paint_box(node, state, ancestor_transform, mut output)
}
