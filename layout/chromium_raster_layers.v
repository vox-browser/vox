module layout

import dom
import math
import painting

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
pub:
	layers         []ChromiumRasterLayer
	command_layers []int
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

fn chromium_layerize_chunks(chunks []ChromiumRasterChunk, count int, device_scale f64) ChromiumRasterLayerPlan {
	mut layers := [ChromiumRasterLayer{}]
	mut states := [ChromiumRasterPropertyState{}]
	mut command_layers := []int{len: count}
	for chunk in chunks {
		mut merged := -1
		for index := layers.len - 1; index >= 0; index-- {
			merged_bounds := chromium_layer_bounds_union(layers[index].bounds, chunk.bounds)
			home := layers[index].bounds
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
			if chromium_layer_bounds_overlap(layers[index].bounds, chunk.bounds) { break
			 }
		}
		if merged < 0 {
			merged = layers.len
			layers << ChromiumRasterLayer{
				legacy_raster: chunk.state.effect_scope != 0
			}
			states << chunk.state
		}
		layers[merged].bounds = chromium_layer_bounds_union(layers[merged].bounds, chunk.bounds)
		end := if chunk.command_end > chunk.command_index {
			chunk.command_end
		} else {
			chunk.command_index + 1
		}
		for index in chunk.command_index .. end {
			layers[merged].command_indices << index
			command_layers[index] = merged
		}
	}
	return ChromiumRasterLayerPlan{
		layers:         layers
		command_layers: command_layers
	}
}

fn chromium_root_raster_plan(count int) ChromiumRasterLayerPlan {
	return ChromiumRasterLayerPlan{
		layers:         [
			ChromiumRasterLayer{
				command_indices: []int{len: count, init: index}
			},
		]
		command_layers: []int{len: count}
	}
}

fn chromium_user_scrollable_box(box &BlockBox) bool {
	if box.own_scroll_frame_index <= 0 || box.is_viewport_scroller || !box.has_scrollable_overflow {
		return false
	}
	if box.layout_handle == unsafe { nil } { return false }
	node := unsafe { &Node(box.layout_handle) }
	if node.is_viewport() { return false }
	computed := node.computed_values()
	return computed.overflow_x() in [.auto_, .scroll] || computed.overflow_y() in [.auto_, .scroll]
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
	result := document_layout_result(document) or { return chromium_root_raster_plan(commands.len) }
	mut composited_scrolls := map[int]bool{}
	mut fixed_bounds := map[u64]LayoutRect{}
	for entry in result.paint_order {
		// Use the box pointer itself: reading its transform through the loop's
		// entry copy makes current V move every copy to the heap.
		box := entry.box
		if chromium_user_scrollable_box(box) {
			composited_scrolls[box.own_scroll_frame_index] = true
		}
		if box.fixed_to_viewport && box.layout_handle != unsafe { nil } {
			node := unsafe { &Node(box.layout_handle) }
			if node.is_fixed_position() {
				fixed_bounds[u64(voidptr(node))] = compatibility_affine_map_rect(box.paint_transform,
					box.border_box())
			}
		}
	}
	tree := result.visual_context_tree
	mut properties := []ChromiumRasterPropertyState{len: tree.nodes.len}
	for index in 1 .. tree.nodes.len {
		node := tree.nodes[index]
		if node.parent_index >= 0 && node.parent_index < index {
			properties[index] = properties[node.parent_index]
		}
		if node.data is painting.ScrollVisualData {
			if node.data.is_sticky {
				properties[index].sticky_frame = node.data.scroll_frame_index
			} else if composited_scrolls[node.data.scroll_frame_index] {
				properties[index].scroll_frame = node.data.scroll_frame_index
			}
		} else if node.data is painting.ScrollCompensationVisualData {
			// Compensated backgrounds need a separate transform/raster policy.
			return chromium_root_raster_plan(commands.len)
		} else if node.data is painting.PerspectiveVisualData {
			return chromium_root_raster_plan(commands.len)
		}
	}
	mut chunks := []ChromiumRasterChunk{cap: commands.len}
	mut index := 0
	for index < commands.len {
		first := index
		mut end := index + 1
		mut effect_scope := u64(0)
		if layer := commands[index].visual_layer_data {
			if !commands[index].kind.starts_with('begin_') {
				return chromium_root_raster_plan(commands.len)
			}
			effect_scope = layer.scope_id
			if effect_scope == 0 { return chromium_root_raster_plan(commands.len) }
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
			if depth != 0 { return chromium_root_raster_plan(commands.len) }
		}
		mut bounds := LayoutRect{}
		mut state := ChromiumRasterPropertyState{}
		mut has_state := false
		for position in first .. end {
			command := unsafe { &commands[position] }
			// Lowered begin/end commands own no box; their enclosed commands
			// supply geometry. Keep the complete effect group atomic while
			// allowing independent ordinary scroll/overlap chunks elsewhere.
			if command.visual_layer_data != none { continue
			 }
			if command.paint_box_index < 0 || command.paint_box_index >= result.paint_order.len {
				return chromium_root_raster_plan(commands.len)
			}
			box := result.paint_order[command.paint_box_index].box
			context := command.visual_context_index or {
				if command.paint_phase == .foreground {
					box.accumulated_visual_context_for_descendants_idx
				} else {
					box.accumulated_visual_context_index
				}
			}

			if context < 0 || context >= properties.len {
				return chromium_root_raster_plan(commands.len)
			}
			if !has_state {
				state = properties[context]
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
					if rect := fixed_bounds[u64(voidptr(node))] {
						bounds = chromium_layer_bounds_union(bounds, rect)
						break
					}
					ancestor = node.parent()
				}
			}
		}
		if has_state {
			chunks << ChromiumRasterChunk{
				state:         state
				bounds:        bounds
				command_index: first
				command_end:   end
			}
		}
		index = end
	}
	return chromium_layerize_chunks(chunks, commands.len, device_scale)
}
