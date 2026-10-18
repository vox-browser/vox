module layout

import css
import dom

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
		|| node.is_flex_item() || node.is_grid_item_ || used.has_scrollable_overflow()
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

fn ordinary_paint_box_from_typed_layout(node &Node, state &LayoutState,
	ancestor_transform [6]f64) BlockBox {
	styled := node.as_node_with_style() or {
		return uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	}
	used := state.try_get(styled) or {
		return uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	}
	if !affine_is_compact_identity(ancestor_transform) || !ordinary_paint_projection_eligible(node, used) {
		return uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	}
	computed := node.computed_values()
	revision := computed.mutation_revision()
	if revision == 0 {
		return uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	}
	geometry := ordinary_paint_geometry(used)
	font_generation := css.css_style_computer_for(node.document()).font_computer().environment_generation()
	position := paint_cumulative_offset(node, state, used)
	snapshot := node.ordinary_paint_box_
	if snapshot != unsafe { nil } && voidptr(snapshot.style) == voidptr(computed)
		&& snapshot.revision == revision && snapshot.geometry == geometry
		&& snapshot.has_children == node.has_children()
		&& snapshot.style_environment == node.document().style_environment_version()
		&& snapshot.font_generation == font_generation
		&& snapshot.font_policy == node.document().font_rendering_policy() {
		if box := rebase_retained_paint_box(&snapshot.paint, node, used, state, position) {
			return box
		}
	}
	box := uncached_block_box_from_typed_layout_shallow(node, state, ancestor_transform)
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.ordinary_paint_box_ = unsafe { nil }
	if retained_paint_box_can_share(&box) {
		mut template := box
		template.lines = []TextLine{}
		mutable_node.ordinary_paint_box_ = &OrdinaryPaintBoxProjection{
			style:             computed
			revision:          revision
			style_environment: node.document().style_environment_version()
			font_generation:   font_generation
			font_policy:       node.document().font_rendering_policy()
			geometry:          geometry
			has_children:      node.has_children()
			paint:             RetainedBlockPaintBox{ box: template, origin: position }
		}
	}
	return box
}

fn rebase_retained_paint_box(snapshot &RetainedBlockPaintBox, node &Node, used &UsedValues,
	state &LayoutState, position css.CSSPixelPoint) ?BlockBox {
	dx := position.x().to_double() - snapshot.origin.x().to_double()
	dy := position.y().to_double() - snapshot.origin.y().to_double()
	if clip := snapshot.box.overflow_clip {
		if !retained_paint_rect_can_translate(clip.rect, dx, dy) { return none }
	}
	if !retained_paint_rect_can_translate(snapshot.box.border_box(), dx, dy) { return none }
	mut box := snapshot.box
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
		box.overflow_clip = CompatibilityOverflowClip{
			...clip
			rect: LayoutRect{clip.rect.x + dx, clip.rect.y + dy, clip.rect.width, clip.rect.height}
		}
	}
	return box
}
