module layout

import dom
import math
import painting
import platform

// The layerizer can merge chunks with a common property state until a
// different composited scroll/sticky state overlaps them. Raster origins and
// path-triggered MSAA then belong to each resulting layer, not the whole page.
pub struct ChromiumRasterLayer {
pub mut:
	bounds          LayoutRect
	command_indices []int
	// Non-composited effect groups retain the atomic native raster policy.
	legacy_raster bool
	// Composited scrolling contents need their own premultiplied raster.
	scroll_contents bool
	// Fixed, sticky and hinted contents likewise rasterize before compositing.
	composited_contents bool
	// A rounded clip below the picture's common property state is rasterized
	// inside that picture, preventing the single-image raster optimization.
	picture_local_rounded_clip bool
	// An opaque, flat scrolling background also paints inside the contents
	// picture. Its ordinary border-box paint remains in the parent layer.
	scroll_background_command int = -1
mut:
	unbounded_sticky_overlap bool
	unbounded_transform_overlap bool
}

pub struct ChromiumRasterLayerPlan {
pub mut:
	layers         []ChromiumRasterLayer
	command_layers []int
	has_paint_metadata bool
	has_picture_clip_metadata bool
mut:
	// Keep inactive slots too: their command vectors are reused if layers return.
	layer_storage []ChromiumRasterLayer
	paint_cull_rect ?LayoutRect
	paint_cull_viewport_size [2]f64
	paint_cull_contents LayoutRect
}

struct ChromiumRasterPropertyState {
mut:
	scroll_frame         int
	sticky_frame         int
	effect_scope         u64
	legacy_effect        bool
	atomic_mask          bool
	fixed_to_viewport    bool
	// Separate fixed containers own separate paint-offset transforms. A shared
	// boolean alone lets a sibling's paths change this container's MSAA coverage.
	fixed_raster_owner   u64
	requires_root_raster bool
	scrollbar            bool
	scroll_hit_test      int
}

struct ChromiumRasterChunk {
	state         ChromiumRasterPropertyState
	bounds        LayoutRect
	command_index int
	command_end   int
	unbounded_sticky_overlap bool
	unbounded_transform_overlap bool
}

// Working storage of chromium_raster_layer_plan, reused by every recording:
// without a collector, allocating it per recording grows memory every frame.
// Its capacity is reserved in persistent storage.
struct ChromiumRasterPlanScratch {
mut:
	properties         []ChromiumRasterPropertyState
	chunks             []ChromiumRasterChunk
	layer_states       []ChromiumRasterPropertyState
	composited_scrolls map[int]bool
	composited_stickies map[int]bool
	sticky_bounds      map[int]LayoutRect
	sticky_scroll_parents map[int]int
	fixed_bounds       map[u64]LayoutRect
	compositor_bounds  map[u64]LayoutRect
	compositor_fixed_raster_owners map[u64]u64
	compositor_unbounded_animations map[u64]bool
	compositor_scopes  []u64
	paint_metadata []ChromiumPaintMetadata
	paint_phase_firsts []int
	paint_chunks []ChromiumRasterChunk
	paint_chunk_contexts []int
	layer_recording_contexts []int
	chunk_picture_local_clips []bool
	command_chunk_groups []int
	paint_chunk_layers []int
	paint_chunk_context int = -1
	paint_chunk_client u64
	paint_visible_effects map[u64]bool
}

__global chromium_raster_plan_scratch_ = ChromiumRasterPlanScratch{}

// Leave `property_count` default states and no chunks, with room for
// `chunk_count` chunks.
fn (mut scratch ChromiumRasterPlanScratch) prepare(property_count int, chunk_count int) {
	if scratch.properties.cap < property_count || scratch.chunks.cap < chunk_count
		|| scratch.compositor_scopes.cap < property_count {
		persistent := platform.enter_persistent()
		if scratch.properties.cap < property_count {
			scratch.properties = []ChromiumRasterPropertyState{cap: property_count}
		}
		if scratch.chunks.cap < chunk_count {
			scratch.chunks = []ChromiumRasterChunk{cap: chunk_count}
		}
		if scratch.compositor_scopes.cap < property_count {
			scratch.compositor_scopes = []u64{cap: property_count}
		}
		platform.leave_persistent(persistent)
	}
	scratch.properties.clear()
	for _ in 0 .. property_count {
		scratch.properties << ChromiumRasterPropertyState{}
	}
	scratch.chunks.clear()
	scratch.compositor_scopes.clear()
}

fn chromium_layer_bounds_union(a LayoutRect, b LayoutRect) LayoutRect {
	if !(a.width > 0 && a.height > 0) { return b }
	if !(b.width > 0 && b.height > 0) { return a }
	x := math.min(a.x, b.x)
	y := math.min(a.y, b.y)
	return LayoutRect{
		x:      x
		y:      y
		width:  math.max(a.x + a.width, b.x + b.width) - x
		height: math.max(a.y + a.height, b.y + b.height) - y
	}
}

fn chromium_layer_bounds_overlap(a LayoutRect, b LayoutRect) bool {
	return a.width > 0 && a.height > 0 && b.width > 0 && b.height > 0 && a.x < b.x + b.width
		&& b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
}

// Explicitly updated plans lend their vectors until the next update. The
// value-returning API still produces independent snapshots.
fn (mut plan ChromiumRasterLayerPlan) prepare(count int) {
	for index in 0 .. plan.layer_storage.len {
		plan.layer_storage[index].bounds = LayoutRect{}
		plan.layer_storage[index].legacy_raster = false
		plan.layer_storage[index].scroll_contents = false
		plan.layer_storage[index].composited_contents = false
		plan.layer_storage[index].picture_local_rounded_clip = false
		plan.layer_storage[index].scroll_background_command = -1
		plan.layer_storage[index].unbounded_sticky_overlap = false
		plan.layer_storage[index].unbounded_transform_overlap = false
		plan.layer_storage[index].command_indices.clear()
	}
	plan.layers = []ChromiumRasterLayer{}
	plan.command_layers.clear()
	for _ in 0 .. count { plan.command_layers << 0 }
}

fn (mut plan ChromiumRasterLayerPlan) append_layer(legacy bool) {
	index := plan.layers.len
	if index == plan.layer_storage.len { plan.layer_storage << ChromiumRasterLayer{} }
	plan.layer_storage[index].legacy_raster = legacy
	plan.layer_storage[index].scroll_contents = false
	plan.layer_storage[index].composited_contents = false
	plan.layer_storage[index].picture_local_rounded_clip = false
	plan.layer_storage[index].unbounded_sticky_overlap = false
	plan.layer_storage[index].unbounded_transform_overlap = false
	plan.layers = unsafe { plan.layer_storage[..index + 1] }
}

$if test {
	fn chromium_layerize_chunks(chunks []ChromiumRasterChunk, count int, device_scale f64) ChromiumRasterLayerPlan {
		mut plan := ChromiumRasterLayerPlan{}
		mut states := []ChromiumRasterPropertyState{}
		chromium_layerize_chunks_into(chunks, count, device_scale, mut plan, mut states)
		return plan
	}
}

fn chromium_layerize_chunks_into(chunks []ChromiumRasterChunk, count int, device_scale f64,
	mut plan ChromiumRasterLayerPlan, mut states []ChromiumRasterPropertyState) {
	plan.prepare(count)
	plan.append_layer(false)
	states.clear()
	states << ChromiumRasterPropertyState{}
	for chunk in chunks {
		mut merged := -1
		mut separated_by_overlap := false
		for index := plan.layers.len - 1; index >= 0; index-- {
			merged_bounds := chromium_layer_bounds_union(plan.layers[index].bounds, chunk.bounds)
			home := plan.layers[index].bounds
			// PendingLayer::CanMerge bounds extra raster area rather than
			// joining arbitrarily distant chunks with a common property state.
			extra_area := merged_bounds.width * merged_bounds.height - home.width * home.height -
				chunk.bounds.width * chunk.bounds.height
			if states[index] == chunk.state && extra_area <= 10000 * device_scale * device_scale {
				merged = index
				break
			}
			// A matching earlier layer cannot be reached through overlapping
			// independently scrolling content without changing paint order.
			// Chromium's overlap projection treats an unclipped sticky
			// translation as unbounded. Its current position cannot establish
			// that later content can be reordered behind it during scrolling.
			sticky_overlap := states[index].sticky_frame != chunk.state.sticky_frame
				&& (plan.layers[index].unbounded_sticky_overlap || chunk.unbounded_sticky_overlap)
			animation_overlap := states[index].effect_scope != chunk.state.effect_scope
				&& (plan.layers[index].unbounded_transform_overlap || chunk.unbounded_transform_overlap)
			if !states[index].atomic_mask
				&& (sticky_overlap || animation_overlap || chromium_layer_bounds_overlap(plan.layers[index].bounds, chunk.bounds)) {
				separated_by_overlap = true
				break
			}
		}
		if merged < 0 {
			merged = plan.layers.len
			plan.append_layer(chunk.state.legacy_effect)
			plan.layers[merged].composited_contents = separated_by_overlap && !chunk.state.legacy_effect
			states << chunk.state
		}
		plan.layers[merged].unbounded_sticky_overlap = plan.layers[merged].unbounded_sticky_overlap
			|| chunk.unbounded_sticky_overlap
		plan.layers[merged].unbounded_transform_overlap = plan.layers[merged].unbounded_transform_overlap
			|| chunk.unbounded_transform_overlap
		plan.layers[merged].bounds = chromium_layer_bounds_union(plan.layers[merged].bounds, chunk.bounds)
		end := if chunk.command_end > chunk.command_index {
			chunk.command_end
		} else {
			chunk.command_index + 1
		}
		for index in chunk.command_index .. end {
			plan.layers[merged].command_indices << index
			plan.command_layers[index] = merged
		}
	}
}

$if test {
	fn chromium_root_raster_plan(count int) ChromiumRasterLayerPlan {
		mut plan := ChromiumRasterLayerPlan{}
		chromium_root_raster_plan_into(count, mut plan)
		return plan
	}
}

fn chromium_root_raster_plan_into(count int, mut plan ChromiumRasterLayerPlan) {
	plan.prepare(count)
	plan.append_layer(false)
	for index in 0 .. count { plan.layers[0].command_indices << index }
}

fn chromium_user_scrollable_box(box &BlockBox) bool {
	if box.own_scroll_frame_index <= 0 || box.is_viewport_scroller || !box.has_scrollable_overflow {
		return false
	}
	if box.layout_handle == unsafe { nil } { return false }
	node := unsafe { &Node(box.layout_handle) }
	if node.is_viewport() { return false }
	computed := node.computed_values()
	return computed.overflow_x() in [.auto_, .scroll] || computed.overflow_y() in [
		.auto_,
		.scroll,
	]
}

fn chromium_scrollport_has_range(box &BlockBox) bool {
	overflow := box.scrollable_overflow or { return false }
	padding_width := if box.is_viewport_scroller {
		box.canvas().viewport_width
	} else {
		box.width + box.padding.left + box.padding.right
	}
	padding_height := if box.is_viewport_scroller {
		box.canvas().viewport_height
	} else {
		box.height + box.padding.top + box.padding.bottom
	}
	return overflow.width > padding_width || overflow.height > padding_height
}

fn chromium_fixed_raster_owner(box &BlockBox) u64 {
	if !box.fixed_to_viewport || box.layout_handle == unsafe { nil } { return 0 }
	mut ancestor := ?&Node(unsafe { &Node(box.layout_handle) })
	for {
		node := ancestor or { return 0 }
		if node.is_fixed_position() { return u64(voidptr(node)) }
		ancestor = node.parent()
	}
	return 0
}

fn chromium_single_svg_opacity_group(commands []PaintCommand, first int, end int,
	layer &PaintVisualLayer) bool {
	if layer.kind != .css_effect || layer.opacity <= 0 || layer.opacity >= 1
		|| layer.blend_mode != .normal || layer.filter != none || end != first + 3 {
		return false
	}
	command := unsafe { &commands[first + 1] }
	if command.kind != 'draw_svg_path' || command.svg_data == unsafe { nil }
		|| command.color == '' || (command.stroke_color != '' && command.stroke_width > 0)
		|| (command.opacity != 1 && f32(command.opacity) != f32(layer.opacity))
		|| f32(command.group_opacity) != f32(layer.opacity) {
		return false
	}
	data := command.svg_data
	return data.fill_pattern == none && data.stroke_pattern == none && data.svg_gradient_data == none
}

// A sticky scroll frame exists even when its scrollport has no scroll range.
// Only a scrolling nearest container promotes that sticky content. Inert
// overflow containers must stop the search rather than borrowing the viewport's
// range, and a fixed ancestor cannot move with an outside viewport scroll.
fn chromium_sticky_needs_compositing(box &BlockBox, boxes_by_layout map[u64]&BlockBox) bool {
	if box.layout_handle == unsafe { nil } { return false }
	node := unsafe { &Node(box.layout_handle) }
	mut containing_block := node.containing_block()
	for containing_block != none {
		ancestor := containing_block or { break }
		if ancestor_box := boxes_by_layout[u64(voidptr(ancestor))] {
			if ancestor_box.is_viewport_scroller || ancestor.is_scroll_container() {
				// Hidden overflow can still scroll programmatically. Promotion
				// depends on its range rather than its wheel-input policy.
				return chromium_scrollport_has_range(ancestor_box)
			}
		}
		if ancestor.is_fixed_position() { return false }
		containing_block = ancestor.containing_block()
	}
	return false
}

fn chromium_raster_chunk_bounds(box &BlockBox, command &PaintCommand) LayoutRect {
	return chromium_raster_chunk_bounds_with_root_scroll(box, command, 0)
}

fn chromium_animated_transform_has_no_ancestor_clip(box &BlockBox,
	result &DocumentLayoutResult) bool {
	// A clip within the animated box moves with it. Only a clip above the
	// animation can bound its possible movement in the parent's raster space.
	mut context := if box.own_transform_visual_context_idx > 0 {
		box.own_transform_visual_context_idx
	} else { box.own_effects_visual_context_idx }
	if context <= 0 || context >= result.visual_context_tree.nodes.len { return false }
	context = result.visual_context_tree.nodes[context].parent_index
	for context > 0 {
		data := result.visual_context_tree.nodes[context].data
		if data is painting.ClipVisualData || data is painting.ClipPathVisualData
			|| data is painting.SVGClipVisualData { return false }
		context = result.visual_context_tree.nodes[context].parent_index
	}
	return true
}

fn chromium_raster_chunk_bounds_with_root_scroll(box &BlockBox, command &PaintCommand,
	root_scroll_y f64) LayoutRect {
	if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0) {
		return LayoutRect{}
	}
	mut rect := box.border_box()
	// Canvas backgrounds cover the viewport and scrollable overflow, rather
	// than only the root box. Layer merging must see that painted extent too;
	// otherwise ordinary page chunks can be split by the sparsity threshold.
	if command.paint_phase == .background && box.canvas().paints_canvas_background {
		canvas := box.canvas()
		rect = chromium_layer_bounds_union(rect, LayoutRect{
			x:      canvas.canvas_x
			y:      canvas.canvas_y
			width:  canvas.canvas_width
			height: canvas.canvas_height
		})
	}
	if !(rect.width > 0 && rect.height > 0) {
		rect = LayoutRect{
			x:      command.x
			y:      command.y
			width:  command.width
			height: command.height
		}
	}
	if command.paint_phase == .outline {
		outset := math.max(0.0, box.decorations().outline_width + box.decorations().outline_offset)
		rect = LayoutRect{
			x:      rect.x - outset
			y:      rect.y - outset
			width:  rect.width + 2 * outset
			height: rect.height + 2 * outset
		}
	}
	if command.kind == 'paint_outer_box_shadow' {
		// Overlap promotion uses painted ink, including the blur outside the
		// border box. Adjacent boxes can overlap through their shadows.
		outset := math.ceil(math.max(0.0, command.blur) * 1.5)
		rect = chromium_layer_bounds_union(rect, LayoutRect{
			x:      command.x - outset
			y:      command.y - outset
			width:  command.width + 2 * outset
			height: command.height + 2 * outset
		})
	}
	mut mapped := compatibility_affine_map_rect(box.paint_transform, rect)
	if command.has_clip {
		// Flattened clips include the live root scroll, while retained box
		// geometry remains in document space. Restore that translation before
		// intersecting them; fixed content already uses viewport coordinates.
		clip_y := command.clip_y + if command.fixed_to_viewport { 0.0 } else { root_scroll_y }
		// Offscreen SVG geometry must
		// not inflate a chunk's visible extent and split its enclosing picture
		// at the sparsity threshold, especially under a rotated overflow clip.
		x := math.max(mapped.x, command.clip_x)
		y := math.max(mapped.y, clip_y)
		mapped = LayoutRect{
			x:      x
			y:      y
			width:  math.max(0.0, math.min(mapped.x + mapped.width,
				command.clip_x + command.clip_width) - x)
			height: math.max(0.0, math.min(mapped.y + mapped.height,
				clip_y + command.clip_height) - y)
		}
	}
	return mapped
}

// This query runs after display-list recording. It reads the retained property
// tree, so absolutely positioned descendants which escape a scroller keep the
// same scroll ancestry used by painting and hit testing.
pub fn chromium_raster_layer_plan(document &dom.Document, commands []PaintCommand, device_scale f64) ChromiumRasterLayerPlan {
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan(document, commands, device_scale, mut plan)
	return plan
}

// Reuse a shell-owned plan after its previous replay has finished.
pub fn update_chromium_raster_layer_plan(document &dom.Document, commands []PaintCommand,
	device_scale f64, mut plan ChromiumRasterLayerPlan) {
	plan.paint_cull_rect = none
	update_chromium_raster_layer_plan_with_cull(document, commands, device_scale, none, mut plan)
}

fn update_chromium_raster_layer_plan_with_cull(document &dom.Document, commands []PaintCommand,
	device_scale f64, cull ?LayoutRect, mut plan ChromiumRasterLayerPlan) {
	plan.has_paint_metadata = false
	plan.has_picture_clip_metadata = false
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	result := document_layout_result(document) or {
		chromium_root_raster_plan_into(commands.len, mut plan)
		return
	}
	mut scratch := unsafe { &chromium_raster_plan_scratch_ }
	scratch.composited_scrolls.clear()
	scratch.composited_stickies.clear()
	scratch.sticky_bounds.clear()
	scratch.sticky_scroll_parents.clear()
	scratch.fixed_bounds.clear()
	scratch.compositor_bounds.clear()
	scratch.compositor_fixed_raster_owners.clear()
	scratch.compositor_unbounded_animations.clear()
	for entry in result.paint_order {
		// Use the box pointer itself: reading its transform through the loop's
		// entry copy makes current V move every copy to the heap.
		box := entry.box
		if box.chromium_compositor_surface && box.own_effects_visual_context_idx > 0 {
			// The compositor owns the complete container, including empty space.
			// Tightening its raster extent to a painted descendant changes tile
			// origins and GPU edge coverage.
			scratch.compositor_bounds[u64(box.own_effects_visual_context_idx)] =
				compatibility_affine_map_rect(box.paint_transform, box.border_box())
			scratch.compositor_fixed_raster_owners[u64(box.own_effects_visual_context_idx)] =
				chromium_fixed_raster_owner(box)
			if box.layout_handle != unsafe { nil } {
				node := unsafe { &Node(box.layout_handle) }
				if chromium_compositor_animation_properties(node).transform {
					scratch.compositor_unbounded_animations[u64(box.own_effects_visual_context_idx)] =
						chromium_animated_transform_has_no_ancestor_clip(box, result)
				}
			}
		}
		if chromium_user_scrollable_box(box) {
			scratch.composited_scrolls[box.own_scroll_frame_index] = true
		}
		if box.sticky_scroll_frame_index > 0
			&& chromium_sticky_needs_compositing(box, result.boxes_by_layout_cache) {
			scratch.composited_stickies[box.sticky_scroll_frame_index] = true
			scratch.sticky_bounds[box.sticky_scroll_frame_index] =
				compatibility_affine_map_rect(box.paint_transform, box.border_box())
		}
		if box.fixed_to_viewport && box.layout_handle != unsafe { nil } {
			node := unsafe { &Node(box.layout_handle) }
			if node.is_fixed_position() {
				scratch.fixed_bounds[u64(voidptr(node))] = compatibility_affine_map_rect(box.paint_transform,
					box.border_box())
			}
		}
	}
	tree := result.visual_context_tree
	scratch.prepare(tree.nodes.len, commands.len)
	for index in 1 .. tree.nodes.len {
		node := tree.nodes[index]
		if node.parent_index >= 0 && node.parent_index < index {
			scratch.properties[index] = scratch.properties[node.parent_index]
		}
		if node.data is painting.ScrollVisualData {
			if node.data.is_sticky && scratch.composited_stickies[node.data.scroll_frame_index] {
				scratch.properties[index].sticky_frame = node.data.scroll_frame_index
				scratch.sticky_scroll_parents[node.data.scroll_frame_index] = scratch.properties[index].scroll_frame
			} else if !node.data.is_sticky && scratch.composited_scrolls[node.data.scroll_frame_index] {
				scratch.properties[index].scroll_frame = node.data.scroll_frame_index
			}
		} else if node.data is painting.ScrollCompensationVisualData
			|| node.data is painting.PerspectiveVisualData {
			// These contexts need a separate transform/raster policy only when
			// painting uses them. Empty perspective containers still contribute
			// retained nodes, but must not disable independent page layers.
			scratch.properties[index].requires_root_raster = true
		}
	}
	// Only captured vector SVG viewports can join the isolated parent raster.
	// Other nested content retains the preceding atomic raster policy.
	mut can_embed_svg_opacity := true
	for command_index in 0 .. commands.len {
		if commands[command_index].kind == 'paint_nested_display_list'
			&& !chromium_nested_svg_raster_supported(&commands[command_index]) {
			can_embed_svg_opacity = false
			break
		}
	}
	mut index := 0
	root_scroll_y := if cull != none { document.viewport_rect().y } else { 0.0 }
	for index < commands.len {
		first := index
		mut end := index + 1
		mut effect_scope := if scratch.compositor_scopes.len > 0 {
			scratch.compositor_scopes.last()
		} else {
			u64(0)
		}
		mut legacy_effect := false
		mut compositor_bounds := LayoutRect{}
		if layer := commands[index].visual_layer_data {
			if commands[index].kind == 'end_css_effect_layer' && scratch.compositor_scopes.len > 0 {
				if layer.scope_id != scratch.compositor_scopes.last() || scratch.chunks.len == 0 {
					chromium_root_raster_plan_into(commands.len, mut plan)
					return
				}
				scratch.compositor_scopes.delete_last()
				// An end marker has no ink. Replay it after the last enclosed
				// chunk, even when that chunk was promoted above an earlier layer.
				last := scratch.chunks.last()
				scratch.chunks[scratch.chunks.len - 1] = ChromiumRasterChunk{
					...last
					command_end: end
				}
				index = end
				continue
			}
			if !commands[index].kind.starts_with('begin_') {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			effect_scope = layer.scope_id
			legacy_effect = true
			if layer.kind == .css_effect {
				if rect := scratch.compositor_bounds[effect_scope] {
					legacy_effect = false
					compositor_bounds = rect
				}
			}
			if effect_scope == 0 {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			if !legacy_effect && layer.opacity == 1 && layer.blend_mode == .normal {
				context := int(effect_scope)
				if context >= scratch.properties.len || scratch.properties[context].requires_root_raster
					|| effect_scope in scratch.compositor_scopes {
					chromium_root_raster_plan_into(commands.len, mut plan)
					return
				}
				mut state := scratch.properties[context]
				state.effect_scope = effect_scope
				state.fixed_to_viewport = commands[index].fixed_to_viewport
				state.fixed_raster_owner = if state.fixed_to_viewport {
					scratch.compositor_fixed_raster_owners[effect_scope]
				} else { u64(0) }
				scratch.compositor_scopes << effect_scope
				// Even an empty will-change layer is an overlap barrier. Keep
				// its container extent on this marker, not on every later chunk.
				scratch.chunks << ChromiumRasterChunk{
					state:         state
					bounds:        compositor_bounds
					command_index: first
					command_end:   end
					unbounded_transform_overlap: scratch.compositor_unbounded_animations[effect_scope]
				}
				index = end
				continue
			}
			mut depth := 1
			for end < commands.len && depth > 0 {
				if commands[end].visual_layer_data != none {
					if commands[end].kind.starts_with('begin_') {
						depth++
					} else if commands[end].kind.starts_with('end_') {
						depth--
					}
				}
				end++
			}
			if depth != 0 {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			// Static filters, SVG clips and masks remain atomic paint runs
			// inside their surrounding raster instead of promoting overlapping
			// content into another compositor surface.
			if can_embed_svg_opacity && chromium_single_svg_opacity_group(commands, first, end, layer) {
				// An ordinary SVG opacity group is painted atomically inside
				// its parent raster; it does not create a compositor boundary.
				effect_scope = if scratch.compositor_scopes.len > 0 {
					scratch.compositor_scopes.last()
				} else { u64(0) }
				legacy_effect = false
			} else if layer.kind == .css_filter && scratch.compositor_scopes.len == 0 {
				// A static filter is an atomic paint effect in the surrounding
				// raster. It does not promote every later overlapping chunk.
				effect_scope = 0
				legacy_effect = false
			} else if layer.kind != .css_effect && scratch.compositor_scopes.len > 0 {
				effect_scope = scratch.compositor_scopes.last()
				legacy_effect = false
			}
		}
		mut bounds := compositor_bounds
		mut state := ChromiumRasterPropertyState{}
		mut has_state := false
		mut unbounded_sticky_overlap := false
		for position in first .. end {
			command := unsafe { &commands[position] }
			// Lowered begin/end commands own no box; their enclosed commands
			// supply geometry. Keep the complete effect group atomic while
			// allowing independent ordinary scroll/overlap chunks elsewhere.
			if command.visual_layer_data != none {
				continue
			}
			if command.paint_box_index < 0 || command.paint_box_index >= result.paint_order.len {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			box := result.paint_order[command.paint_box_index].box
			context := command.visual_context_index or {
				if command.paint_phase == .foreground {
					box.accumulated_visual_context_for_descendants_idx
				} else {
					box.accumulated_visual_context_index
				}
			}

			if context < 0 || context >= scratch.properties.len {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			if scratch.properties[context].requires_root_raster {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			if !has_state {
				state = scratch.properties[context]
				state.effect_scope = effect_scope
				state.legacy_effect = legacy_effect
				// Captured SVG masks replay at this exact point in their parent
				// raster. They are not compositor overlap barriers for that
				// parent's subsequent metadata or decoration commands.
				state.atomic_mask = legacy_effect && commands[first].kind == 'begin_svg_mask_layer'
				state.fixed_to_viewport = command.fixed_to_viewport
				state.fixed_raster_owner = if state.fixed_to_viewport {
					chromium_fixed_raster_owner(box)
				} else { u64(0) }
				// Scrollbars retain their own raster identity; appending one
				// must not turn preceding overlap text into a mixed paint run.
				state.scrollbar = command.scrollbar_axis != ''
				has_state = true
			}
			if state.sticky_frame > 0 && !state.legacy_effect && !command.has_clip {
				unbounded_sticky_overlap = true
			}
			bounds = chromium_layer_bounds_union(bounds,
				chromium_raster_chunk_bounds_with_root_scroll(box, command, root_scroll_y))
			// A fixed container establishes its compositor layer even when only
			// a small descendant paints. Keep the container's empty space in the
			// raster extent; tightening it to that descendant changes GPU coverage.
			if command.fixed_to_viewport && box.layout_handle != unsafe { nil } {
				mut ancestor := ?&Node(unsafe { &Node(box.layout_handle) })
				for {
					node := ancestor or { break }
					if rect := scratch.fixed_bounds[u64(voidptr(node))] {
						bounds = chromium_layer_bounds_union(bounds, rect)
						break
					}
					ancestor = node.parent()
				}
			}
		}
		if has_state {
			scratch.chunks << ChromiumRasterChunk{
				state:         state
				bounds:        bounds
				command_index: first
				command_end:   end
				unbounded_sticky_overlap: unbounded_sticky_overlap
				unbounded_transform_overlap: scratch.compositor_unbounded_animations[effect_scope]
			}
		}
		index = end
	}
	if scratch.compositor_scopes.len > 0 {
		chromium_root_raster_plan_into(commands.len, mut plan)
		return
	}
	if rect := cull {
		chromium_layerize_visible_paint_chunks(result, commands, rect, device_scale, mut scratch, mut plan)
	} else {
		chromium_layerize_chunks_into(scratch.chunks, commands.len, device_scale, mut plan, mut scratch.layer_states)
	}
	for layer_index, state in scratch.layer_states {
		plan.layers[layer_index].scroll_contents = state.scroll_frame > 0
		plan.layers[layer_index].composited_contents = !state.legacy_effect
			&& (plan.layers[layer_index].composited_contents
				|| state.scroll_frame > 0 || state.sticky_frame > 0 || state.fixed_to_viewport
				|| state.effect_scope != 0)
		// PictureLayerTiling::ComputeTilingRect snaps partial recordings in
		// the complete layer's coordinate space, not at their tight ink origin.
		// Nested surfaces and independently scrolling descendants own their
		// own recordings rather than borrowing this sticky container's extent.
		if state.effect_scope == 0 && !state.legacy_effect && !state.fixed_to_viewport
			&& state.scroll_frame == scratch.sticky_scroll_parents[state.sticky_frame] {
			if rect := scratch.sticky_bounds[state.sticky_frame] {
				plan.layers[layer_index].bounds = chromium_recorded_tiling_rect(rect,
					plan.layers[layer_index].bounds, device_scale)
			}
		}
		if state.effect_scope != 0 && !state.legacy_effect {
			// Compositor rasters enclose fractional geometry, independently of
			// paint's nearest-pixel snapping. Round after unioning descendant ink.
			plan.layers[layer_index].bounds = chromium_enclosing_raster_rect(plan.layers[layer_index].bounds)
		}
	}
}

fn chromium_recorded_tiling_rect(container LayoutRect, recorded LayoutRect, scale f64) LayoutRect {
	if !(scale > 0) || math.is_inf(scale, 0) || math.is_nan(scale)
		|| !(recorded.width > 0 && recorded.height > 0) { return recorded }
	layer := chromium_enclosing_raster_rect(chromium_layer_bounds_union(container, recorded))
	ink := chromium_enclosing_raster_rect(recorded)
	left := math.floor(math.floor((ink.x - layer.x) * scale) / 128) * 128
	top := math.floor(math.floor((ink.y - layer.y) * scale) / 128) * 128
	layer_right := math.ceil(layer.width * scale)
	layer_bottom := math.ceil(layer.height * scale)
	right := math.ceil((ink.x + ink.width - layer.x) * scale)
	bottom := math.ceil((ink.y + ink.height - layer.y) * scale)
	return LayoutRect{
		x: layer.x + left / scale
		y: layer.y + top / scale
		width: ((if right + 128 > layer_right { layer_right } else { right }) - left) / scale
		height: ((if bottom + 128 > layer_bottom { layer_bottom } else { bottom }) - top) / scale
	}
}

fn chromium_enclosing_raster_rect(rect LayoutRect) LayoutRect {
	left := math.floor(rect.x)
	top := math.floor(rect.y)
	return LayoutRect{
		x:      left
		y:      top
		width:  math.ceil(rect.x + rect.width) - left
		height: math.ceil(rect.y + rect.height) - top
	}
}
