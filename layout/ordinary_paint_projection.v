module layout

import css
import dom
import platform

struct OrdinaryPaintBoxGeometry {
	width   f64
	height  f64
	margin  BoxEdges
	border  BoxEdges
	padding BoxEdges
}

@[heap]
struct OrdinaryPaintBoxProjection {
	style             &css.ComputedValues
	revision          u64
	style_environment u64
	font_generation   u64
	font_policy       dom.FontRenderingPolicy
	geometry          OrdinaryPaintBoxGeometry
	has_children      bool
	flex_item         bool
	grid_item         bool
	paint             RetainedBlockPaintBox
}

fn ordinary_paint_geometry(used &UsedValues) OrdinaryPaintBoxGeometry {
	return OrdinaryPaintBoxGeometry{
		width:   used.content_width().to_double()
		height:  used.content_height().to_double()
		margin:  BoxEdges{used.margin_top.to_double(), used.margin_right.to_double(), used.margin_bottom.to_double(), used.margin_left.to_double()}
		border:  compatibility_paint_border_edges(used)
		padding: BoxEdges{used.padding_top.to_double(), used.padding_right.to_double(), used.padding_bottom.to_double(), used.padding_left.to_double()}
	}
}

fn ordinary_paint_projection_eligible(node &Node, used &UsedValues) bool {
	if node.is_root_element() || node.is_body() || node.is_viewport() || node.is_anonymous()
		|| node.is_generated_for_pseudo_element() || node.is_generated_text_node()
		|| node.is_in_ua_internal_shadow_tree() || node.is_replaced_box()
		|| node.is_floating() || node.is_positioned() || node.is_list_item_box()
		|| node.is_list_item_marker_box() || node.is_fieldset_box()
		|| (retain_uncached_item_paint && (node.is_flex_item() || node.is_grid_item_))
		|| used.has_scrollable_overflow()
		|| used.svg_rendering_disabled() || node.computed_values().has_animated_properties()
		|| (!node.display().is_flow_inside() && !node.display().is_flow_root_inside()) {
		return false
	}
	owner := node.dom_node() or { return false }
	element := owner.as_element() or { return false }
	if !element.is_html_element() || element.rendered_in_top_layer() { return false }
	mut ancestor := ?&Node(node)
	for ancestor != none {
		current := ancestor or { break }
		if current.is_svg_box() { return false }
		ancestor = current.parent()
	}
	return true
}

$if test {
	fn ordinary_paint_box_from_typed_layout(node &Node, state &LayoutState,
		ancestor_transform [6]f64) BlockBox {
		mut box := BlockBox{}
		fill_ordinary_paint_box(node, state, ancestor_transform, mut box)
		return box
	}
}

fn fill_ordinary_paint_box(node &Node, state &LayoutState,
	ancestor_transform [6]f64, mut output BlockBox) {
	styled := node.as_node_with_style() or {
		output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
		return
	}
	used := state.try_get(styled) or {
		output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
		return
	}
	if !affine_is_compact_identity(ancestor_transform) || !ordinary_paint_projection_eligible(node, used) {
		output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
		return
	}
	computed := node.computed_values()
	revision := computed.mutation_revision()
	if revision == 0 {
		output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
		return
	}
	geometry := ordinary_paint_geometry(used)
	font_generation := css.css_style_computer_for(node.document()).font_computer().environment_generation()
	position := paint_cumulative_offset(node, state, used)
	snapshot := node.ordinary_paint_box_
	if snapshot != unsafe { nil } && voidptr(snapshot.style) == voidptr(computed)
		&& snapshot.revision == revision && snapshot.geometry == geometry
		&& snapshot.has_children == node.has_children()
		&& snapshot.flex_item == node.is_flex_item() && snapshot.grid_item == node.is_grid_item_
		&& snapshot.style_environment == node.document().style_environment_version()
		&& snapshot.font_generation == font_generation
		&& snapshot.font_policy == node.document().font_rendering_policy() {
		if rebase_retained_paint_box_into(&snapshot.paint, node, used, state, position, mut output) {
			if node.is_flex_item() || node.is_grid_item_ { report_item_paint_projection(node) }
			return
		}
	}
	// Nodes retain this template across independently owned paint trees.
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	output = uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.ordinary_paint_box_ = unsafe { nil }
	if retained_paint_box_can_share(&output) {
		mut template := output
		template.lines = []TextLine{}
		mutable_node.ordinary_paint_box_ = &OrdinaryPaintBoxProjection{
			style:             computed
			revision:          revision
			style_environment: node.document().style_environment_version()
			font_generation:   font_generation
			font_policy:       node.document().font_rendering_policy()
			geometry:          geometry
			has_children:      node.has_children()
			flex_item:         node.is_flex_item()
			grid_item:         node.is_grid_item_
			paint:             RetainedBlockPaintBox{ box: template, origin: position }
		}
	}
}

// Fill the caller's final slot without returning a several-kilobyte optional
// record through each layer of the projection pipeline.
fn rebase_retained_paint_box_into(snapshot &RetainedBlockPaintBox, node &Node, used &UsedValues,
	state &LayoutState, position css.CSSPixelPoint, mut box BlockBox) bool {
	dx := position.x().to_double() - snapshot.origin.x().to_double()
	dy := position.y().to_double() - snapshot.origin.y().to_double()
	if snapshot.box.snaps_background_rect {
		if snapshot.box.background_color.a > 0 || snapshot.box.decorations().background_images.len > 0 {
			if chromium_contained_fragment_adjustment(node, state) != snapshot.box.decorations().background_paint_offset {
				return false
			}
		}
		if old_clip := snapshot.box.overflow_clip {
			styled := node.as_node_with_style() or { return false }
			fresh_clip := compatibility_overflow_clip(node, styled.computed_values(), used,
				position, snapshot.box.decorations().border_radii) or { return false }
			adjustment := chromium_contained_fragment_adjustment(node, state)
			if fresh_clip.rect.x + adjustment.x != old_clip.rect.x + dx
				|| fresh_clip.rect.y + adjustment.y != old_clip.rect.y + dy { return false }
		}
	}
	if clip := snapshot.box.overflow_clip {
		if !retained_paint_rect_can_translate(clip.rect, dx, dy) { return false }
	}
	if !retained_paint_rect_can_translate(snapshot.box.border_box(), dx, dy) { return false }
	box = snapshot.box
	box.x += dx
	box.y += dy
	box.lines = text_lines_from_typed_layout(node, used, state, position)
	box.pointer_events_enabled = paintable_visible_for_hit_testing(node, node.computed_values())
	box.scrollable_overflow = if overflow := used.scrollable_overflow_rect() {
		?LayoutRect(LayoutRect{overflow.x.to_double(), overflow.y.to_double(), overflow.width.to_double(), overflow.height.to_double()})
	} else {
		none
	}
	if clip := box.overflow_clip {
		box.overflow_clip = &CompatibilityOverflowClip{
			...clip
			rect: LayoutRect{clip.rect.x + dx, clip.rect.y + dy, clip.rect.width, clip.rect.height}
		}
	}
	return true
}
