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
	// Effect groups retain the existing atomic native raster policy.
	legacy_raster bool
}

pub struct ChromiumRasterLayerPlan {
pub mut:
	layers         []ChromiumRasterLayer
	command_layers []int
mut:
	// Keep inactive slots too: their command vectors are reused if layers return.
	layer_storage []ChromiumRasterLayer
}

struct ChromiumRasterPropertyState {
mut:
	scroll_frame      int
	sticky_frame      int
	effect_scope      u64
	fixed_to_viewport bool
}

struct ChromiumRasterChunk {
	state         ChromiumRasterPropertyState
	bounds        LayoutRect
	command_index int
	command_end   int
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
	fixed_bounds       map[u64]LayoutRect
}

__global chromium_raster_plan_scratch_ = ChromiumRasterPlanScratch{}

// Leave `property_count` default states and no chunks, with room for
// `chunk_count` chunks.
fn (mut scratch ChromiumRasterPlanScratch) prepare(property_count int, chunk_count int) {
	if scratch.properties.cap < property_count || scratch.chunks.cap < chunk_count {
		persistent := platform.enter_persistent()
		if scratch.properties.cap < property_count {
			scratch.properties = []ChromiumRasterPropertyState{cap: property_count}
		}
		if scratch.chunks.cap < chunk_count {
			scratch.chunks = []ChromiumRasterChunk{cap: chunk_count}
		}
		platform.leave_persistent(persistent)
	}
	scratch.properties.clear()
	for _ in 0 .. property_count {
		scratch.properties << ChromiumRasterPropertyState{}
	}
	scratch.chunks.clear()
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
	plan.layers = unsafe { plan.layer_storage[..index + 1] }
}

fn chromium_layerize_chunks(chunks []ChromiumRasterChunk, count int, device_scale f64) ChromiumRasterLayerPlan {
	mut plan := ChromiumRasterLayerPlan{}
	mut states := []ChromiumRasterPropertyState{}
	chromium_layerize_chunks_into(chunks, count, device_scale, mut plan, mut states)
	return plan
}

fn chromium_layerize_chunks_into(chunks []ChromiumRasterChunk, count int, device_scale f64,
	mut plan ChromiumRasterLayerPlan, mut states []ChromiumRasterPropertyState) {
	plan.prepare(count)
	plan.append_layer(false)
	states.clear()
	states << ChromiumRasterPropertyState{}
	for chunk in chunks {
		mut merged := -1
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
			if chromium_layer_bounds_overlap(plan.layers[index].bounds, chunk.bounds) {
				break
			}
		}
		if merged < 0 {
			merged = plan.layers.len
			plan.append_layer(chunk.state.effect_scope != 0)
			states << chunk.state
		}
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

fn chromium_root_raster_plan(count int) ChromiumRasterLayerPlan {
	mut plan := ChromiumRasterLayerPlan{}
	chromium_root_raster_plan_into(count, mut plan)
	return plan
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

fn chromium_raster_chunk_bounds(box &BlockBox, command &PaintCommand) LayoutRect {
	if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0) {
		return LayoutRect{}
	}
	mut rect := box.border_box()
	if !(rect.width > 0 && rect.height > 0) {
		rect = LayoutRect{
			x:      command.x
			y:      command.y
			width:  command.width
			height: command.height
		}
	}
	if command.paint_phase == .outline {
		outset := math.max(0.0, box.outline_width + box.outline_offset)
		rect = LayoutRect{
			x:      rect.x - outset
			y:      rect.y - outset
			width:  rect.width + 2 * outset
			height: rect.height + 2 * outset
		}
	}
	return compatibility_affine_map_rect(box.paint_transform, rect)
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
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	result := document_layout_result(document) or {
		chromium_root_raster_plan_into(commands.len, mut plan)
		return
	}
	mut scratch := unsafe { &chromium_raster_plan_scratch_ }
	scratch.composited_scrolls.clear()
	scratch.fixed_bounds.clear()
	for entry in result.paint_order {
		// Use the box pointer itself: reading its transform through the loop's
		// entry copy makes current V move every copy to the heap.
		box := entry.box
		if chromium_user_scrollable_box(box) {
			scratch.composited_scrolls[box.own_scroll_frame_index] = true
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
			if node.data.is_sticky {
				scratch.properties[index].sticky_frame = node.data.scroll_frame_index
			} else if scratch.composited_scrolls[node.data.scroll_frame_index] {
				scratch.properties[index].scroll_frame = node.data.scroll_frame_index
			}
		} else if node.data is painting.ScrollCompensationVisualData {
			// Compensated backgrounds need a separate transform/raster policy.
			chromium_root_raster_plan_into(commands.len, mut plan)
			return
		} else if node.data is painting.PerspectiveVisualData {
			chromium_root_raster_plan_into(commands.len, mut plan)
			return
		}
	}
	mut index := 0
	for index < commands.len {
		first := index
		mut end := index + 1
		mut effect_scope := u64(0)
		if layer := commands[index].visual_layer_data {
			if !commands[index].kind.starts_with('begin_') {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
			}
			effect_scope = layer.scope_id
			if effect_scope == 0 {
				chromium_root_raster_plan_into(commands.len, mut plan)
				return
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
		}
		mut bounds := LayoutRect{}
		mut state := ChromiumRasterPropertyState{}
		mut has_state := false
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
			if !has_state {
				state = scratch.properties[context]
				state.effect_scope = effect_scope
				state.fixed_to_viewport = command.fixed_to_viewport
				has_state = true
			}
			bounds = chromium_layer_bounds_union(bounds, chromium_raster_chunk_bounds(box, command))
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
			}
		}
		index = end
	}
	chromium_layerize_chunks_into(scratch.chunks, commands.len, device_scale, mut plan, mut scratch.layer_states)
}
