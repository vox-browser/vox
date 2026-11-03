module layout

import dom
import math
import css
import painting

struct ChromiumPaintMetadata {
	at      int
	context int
	state   ChromiumRasterPropertyState
	bounds  LayoutRect
	client  u64
}

enum ChromiumPaintMetadataMode {
	none
	clipping
	geometry
}

// Chromium expands a vertical root scrollport by 4000 pixels and retains its
// preceding interest rect until an edge changes by at least 512 pixels.
// Scale-one documents use this projection. Higher scales retain the preceding
// picture policy until their direct-gradient raster phase is projected too.
fn chromium_root_paint_cull(viewport LayoutRect, contents LayoutRect, scale f64,
	plan &ChromiumRasterLayerPlan) ?LayoutRect {
	if scale != 1 || viewport.x != 0 || viewport.width <= 0 || viewport.height <= 0
		|| viewport.y < 0 || contents.x < 0 || contents.width > viewport.width
		|| contents.width <= 0 || contents.height <= 0 {
		return none
	}
	for value in [viewport.x, viewport.y, viewport.width, viewport.height, contents.x, contents.y,
		contents.width, contents.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	if contents.height <= viewport.height && viewport.y == 0 { return contents }
	if scale != 1 { return none }
	top := math.max(contents.y, viewport.y - 4000)
	bottom := math.min(contents.y + contents.height, viewport.y + viewport.height + 4000)
	if bottom <= top { return none }
	rect := LayoutRect{contents.x, top, contents.width, bottom - top}
	if old := plan.paint_cull_rect {
		if plan.paint_cull_viewport_size == [viewport.width, viewport.height]!
			&& plan.paint_cull_contents == contents
			&& math.abs(rect.y - old.y) < 512
			&& math.abs(rect.y + rect.height - old.y - old.height) < 512 {
			return old
		}
	}
	return rect
}

pub fn chromium_raster_cull_changed(document &dom.Document, viewport LayoutRect,
	scale f64, plan &ChromiumRasterLayerPlan) bool {
	result := document_layout_result(document) or { return false }
	contents := chromium_root_paint_contents(result, viewport)
	return chromium_root_paint_cull(viewport, contents,
		scale, plan) != plan.paint_cull_rect
}

fn chromium_root_paint_contents(result &DocumentLayoutResult, viewport LayoutRect) LayoutRect {
	if contents := result.paint_tree.scrollable_overflow {
		if contents.width > 0 && contents.height > 0 { return contents }
	}
	// Absolutely positioned contents need not give the root a used block size.
	// In the absence of a scrolling extent, its visible viewport is still a
	// finite interest rect for independently scrolling descendants.
	return LayoutRect{0, 0, viewport.width, viewport.height}
}

pub fn update_chromium_raster_layer_plan_for_viewport(document &dom.Document,
	commands []PaintCommand, scale f64, viewport LayoutRect, mut plan ChromiumRasterLayerPlan) {
	result := document_layout_result(document) or {
		update_chromium_raster_layer_plan(document, commands, scale, mut plan)
		return
	}
	contents := chromium_root_paint_contents(result, viewport)
	cull := chromium_root_paint_cull(viewport, contents, scale, &plan)
	plan.paint_cull_rect = cull
	plan.paint_cull_viewport_size = [viewport.width, viewport.height]!
	plan.paint_cull_contents = contents
	update_chromium_raster_layer_plan_with_cull(document, commands, scale, cull, mut plan)
	if plan.has_paint_metadata {
		chromium_assign_scroll_backgrounds(result, commands, mut plan)
	}
}

// Blink paints eligible solid backgrounds in scrolling contents space as well
// as border-box space on macOS. Retaining that opaque paint inside a complete
// picture avoids quantizing translucent descendants before their background.
// Image backgrounds, inset shadows and rounded clips keep the existing path.
fn chromium_assign_scroll_backgrounds(result &DocumentLayoutResult, commands []PaintCommand,
	mut plan ChromiumRasterLayerPlan) {
	scratch := unsafe { &chromium_raster_plan_scratch_ }
	for layer_index, state in scratch.layer_states {
		if state.scroll_frame <= 0 || state.legacy_effect { continue }
		for command_index, command in commands {
			if command.kind != 'fill_rect' || command.paint_phase != .background
				|| command.opacity != 1 || command.group_opacity != 1
				|| command.paint_box_index < 0 || command.paint_box_index >= result.paint_order.len {
				continue
			}
			box := result.paint_order[command.paint_box_index].box
			if box.own_scroll_frame_index != state.scroll_frame { continue }
			decoration := box.decorations()
			if decoration.background_images.len > 0 || decoration.background_gradient != none
				|| decoration.border_radius != 0 || !box_radii_are_zero(decoration.border_radii)
				|| decoration.background_color_clip !in ['border-box', 'padding-box']
				|| decoration.shadows.any(it.inset) {
				continue
			}
			if shadow := decoration.shadow {
				if shadow.inset { continue }
			}
			color := css.parse_color_string(command.color) or { continue }
			if color.a != 255 { continue }
			if command.srgb_color_data != unsafe { nil }
				&& command.srgb_color_data.components[3] != 1 {
				continue
			}
			plan.layers[layer_index].scroll_background_command = command_index
			break
		}
	}
}

fn chromium_metadata_state(box &BlockBox, result &DocumentLayoutResult,
	scratch &ChromiumRasterPlanScratch) (int, ChromiumRasterPropertyState) {
	context := box.accumulated_visual_context_index
	if context < 0 || context >= scratch.properties.len {
		return -1, ChromiumRasterPropertyState{}
	}
	mut state := scratch.properties[context]
	state.fixed_to_viewport = box.fixed_to_viewport
	// Hit-test-only chunks must share their fixed container's paint identity.
	// Otherwise their overlapping bounds split each descendant from the
	// background it needs during premultiplied rasterization.
	state.fixed_raster_owner = chromium_fixed_raster_owner(box)
	mut ancestor := context
	for ancestor > 0 && ancestor < result.visual_context_tree.nodes.len {
		if u64(ancestor) in scratch.compositor_bounds {
			state.effect_scope = u64(ancestor)
			break
		}
		ancestor = result.visual_context_tree.nodes[ancestor].parent_index
	}
	return context, state
}

fn chromium_hit_test_border_rect(box &BlockBox) LayoutRect {
	rect := box.border_box()
	own := normalized_affine(box.own_paint_transform)
	transform := normalized_affine(box.paint_transform)
	// A non-translation transform resolves its paint offset in a separate
	// property space. Keep those bounds until that offset has been applied.
	if !box.snaps_background_rect || own[0] != 1 || own[1] != 0
		|| own[2] != 0 || own[3] != 1
		|| transform[0] != 1 || transform[1] != 0
		|| transform[2] != 0 || transform[3] != 1 {
		return rect
	}
	return pixel_snapped_layout_rect(rect)
}

fn chromium_collect_paint_metadata(result &DocumentLayoutResult, commands []PaintCommand,
	cull LayoutRect, mut scratch ChromiumRasterPlanScratch) ChromiumPaintMetadataMode {
	scratch.paint_metadata.clear()
	count := result.paint_order.len * compatibility_paint_phase_count
	scratch.paint_phase_firsts.clear()
	for _ in 0 .. count { scratch.paint_phase_firsts << -1 }
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.visual_layer_data != none || command.paint_box_index < 0
			|| command.paint_box_index >= result.paint_order.len {
			continue
		}
		key := command.paint_box_index * compatibility_paint_phase_count + int(command.paint_phase)
		if scratch.paint_phase_firsts[key] < 0 { scratch.paint_phase_firsts[key] = index }
	}
	mut cursor := commands.len
	mut has_scroll_marker := false
	for index := result.paint_steps.len - 1; index >= 0; index-- {
		step := result.paint_steps[index]
		if step.entry_index < 0 || step.entry_index >= result.paint_order.len { continue }
		after := cursor
		key := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		if scratch.paint_phase_firsts[key] >= 0 { cursor = scratch.paint_phase_firsts[key] }
		// BoxFragmentPainter records hit-test data after the complete box
		// decoration, including its border, even when it painted no pixels.
		if step.phase != .border { continue }
		box := result.paint_order[step.entry_index].box
		if !box.visible { continue }
		// BoxFragmentPainter records hit-test data from ToPixelSnappedRect,
		// before mapping it through the paint property's transform.
		rect := chromium_hit_test_border_rect(box)
		bounds := compatibility_affine_map_rect(box.paint_transform, rect)
		context, state := chromium_metadata_state(box, result, &scratch)
		if context < 0 || state.requires_root_raster { continue }
		if !state.fixed_to_viewport && state.sticky_frame == 0
			&& !chromium_layer_bounds_overlap(bounds, cull) {
			continue
		}
		if scratch.composited_scrolls[box.own_scroll_frame_index] {
			padding := box.compatibility_absolute_padding_rect()
			marker := compatibility_affine_map_rect(box.paint_transform,
				LayoutRect{padding.x, padding.y, padding.width, padding.height})
			scratch.paint_metadata << ChromiumPaintMetadata{
				at:      after
				context: context
				state:   ChromiumRasterPropertyState{ ...state, scroll_hit_test: box.own_scroll_frame_index }
				bounds:  marker
				client:  chromium_paint_client(box)
			}
			has_scroll_marker = true
		}
		// Reverse traversal puts the ordinary background metadata first when
		// the vector is restored to paint order below.
		scratch.paint_metadata << ChromiumPaintMetadata{after, context, state, bounds,
			chromium_paint_client(box)}
	}
	scratch.paint_metadata.reverse_in_place()
	// A rounded image's ancestor can contribute a metadata-only chunk before
	// its overflow clip. It still determines the picture's common clip state,
	// even when the document has no independently scrolling contents.
	if !has_scroll_marker {
		for command in commands {
			if command.kind != 'draw_replaced_image' || command.clip_list == unsafe { nil } { continue }
			if command.clip_list.items.any(it.corner_radii != BoxRadii{}) { return .clipping }
		}
	}
	return if has_scroll_marker { .geometry } else { .none }
}

// Keep each paint client's hit-test and drawing bounds together. Combining
// unrelated clients before layerization can promote a later, disjoint SVG or
// decoration along with an overlapping scroller overlay. Layerization may still
// merge their compatible chunks after considering the intervening geometry.
fn chromium_paint_client(box &BlockBox) u64 {
	mut positioned := u64(0)
	if box.layout_handle != unsafe { nil } {
		mut ancestor := ?&Node(unsafe { &Node(box.layout_handle) })
		for {
			node := ancestor or { break }
			// Blink records an inline SVG viewport as one paint client. Its
			// individual paths must not merge into unrelated overlap layers.
			if node.is_svg_svg_box() { return u64(voidptr(node)) }
			// Out-of-flow metadata must not expand the following normal-flow
			// chunk into an otherwise disjoint scroll overlay's bounds.
			if positioned == 0 && node.is_absolutely_positioned() {
				positioned = u64(voidptr(node))
			}
			ancestor = node.parent()
		}
		if viewport := chromium_single_svg_content(unsafe { &Node(box.layout_handle) }) {
			return u64(voidptr(viewport))
		}
	}
	if positioned != 0 { return positioned }
	// Ordinary boxes retain their shared property-state chunk. An SVG
	// viewport contributes a distinct transform/recording client.
	return 1
}

// Transparent links, flex wrappers and button content boxes around one inline
// SVG belong to its recording too. Out-of-flow accessibility labels and hit
// targets do not turn that sole principal child into a mixed text/SVG client.
fn chromium_single_svg_content(node &Node) ?&Node {
	mut current := node
	for {
		if current.is_svg_svg_box() { return current }
		if current.is_text_node() { return none }
		mut principal := ?&Node(none)
		for child in current.children() {
			if child.is_absolutely_positioned() { continue }
			if child.is_text_node() {
				text := unsafe { &TextNode(child) }
				if text.source_text_.trim_space() == '' { continue }
				return none
			}
			if principal != none { return none }
			principal = child
		}
		current = principal or { return none }
	}
	return none
}

fn chromium_append_paint_chunk(bounds LayoutRect, state ChromiumRasterPropertyState,
	context int, client u64, mut scratch ChromiumRasterPlanScratch) int {
	if context >= 0 && context == scratch.paint_chunk_context && state.scroll_hit_test == 0
		&& client != 0 && client == scratch.paint_chunk_client
		&& !state.legacy_effect && scratch.paint_chunks.len > 0
		&& scratch.paint_chunks.last().state == state {
		index := scratch.paint_chunks.len - 1
		last := scratch.paint_chunks[index]
		scratch.paint_chunks[index] = ChromiumRasterChunk{
			...last
			bounds: chromium_layer_bounds_union(last.bounds, bounds)
		}
		return index
	}
	index := scratch.paint_chunks.len
	scratch.paint_chunks << ChromiumRasterChunk{
		state:         state
		bounds:        bounds
		command_index: index
		command_end:   index + 1
	}
	scratch.paint_chunk_contexts << context
	scratch.paint_chunk_context = if state.scroll_hit_test > 0 { -1 } else { context }
	scratch.paint_chunk_client = client
	return index
}

fn chromium_chunk_context(chunk ChromiumRasterChunk, result &DocumentLayoutResult,
	commands []PaintCommand) (int, u64) {
	mut context := -1
	mut client := u64(0)
	mut multiple_clients := false
	for index in chunk.command_index .. chunk.command_end {
		command := unsafe { &commands[index] }
		if command.visual_layer_data != none { continue }
		if command.paint_box_index < 0 || command.paint_box_index >= result.paint_order.len {
			return -1, 0
		}
		box := result.paint_order[command.paint_box_index].box
		current := command.visual_context_index or {
			if command.paint_phase == .foreground {
				box.accumulated_visual_context_for_descendants_idx
			} else {
				box.accumulated_visual_context_index
			}
		}
		if context >= 0 && context != current { return -1, 0 }
		current_client := chromium_paint_client(box)
		if client != 0 && client != current_client { multiple_clients = true }
		client = current_client
		context = current
	}
	return context, if multiple_clients { u64(0) } else { client }
}

fn chromium_paint_chunk_is_interested(chunk ChromiumRasterChunk, cull LayoutRect) bool {
	return chunk.state.fixed_to_viewport || chunk.state.sticky_frame > 0 || chunk.unbounded_transform_overlap
		|| chromium_layer_bounds_overlap(chunk.bounds, cull)
}

fn chromium_paint_chunk_has_pending_image(chunk ChromiumRasterChunk, commands []PaintCommand) bool {
	for index in chunk.command_index .. chunk.command_end {
		command := unsafe { &commands[index] }
		// An undecoded generated image can have no intrinsic size yet. Native
		// replay starts its request before checking that geometry; dropping the
		// command here would prevent the completion that gives it a real size.
		if command.kind == 'draw_replaced_image' && command.image_data != unsafe { nil }
			&& command.image_data.image_url != '' && command.replaced_image_bitmap == none
			&& (command.width <= 0 || command.height <= 0) { return true }
	}
	return false
}

fn chromium_layerize_visible_paint_chunks(result &DocumentLayoutResult,
	commands []PaintCommand, cull LayoutRect, scale f64,
	mut scratch ChromiumRasterPlanScratch, mut plan ChromiumRasterLayerPlan) {
	scratch.paint_visible_effects.clear()
	for chunk in scratch.chunks {
		if chunk.state.effect_scope == 0 || !chromium_paint_chunk_is_interested(chunk, cull) {
			continue
		}
		mut scope := chunk.state.effect_scope
		for scope > 0 {
			scratch.paint_visible_effects[scope] = true
			if scope >= u64(result.visual_context_tree.nodes.len) { break }
			parent := result.visual_context_tree.nodes[int(scope)].parent_index
			if parent <= 0 || u64(parent) >= scope { break }
			scope = u64(parent)
		}
	}
	// Captured masks and filters already form balanced atomic chunks. Their
	// descendants' metadata is skipped below, just like their enclosed paint;
	// ordinary siblings still need their own hit-test geometry and tile origin.
	// Other legacy effects retain the preceding planner.
	for chunk in scratch.chunks {
		if chunk.state.legacy_effect && chromium_paint_chunk_is_interested(chunk, cull)
			&& commands[chunk.command_index].kind !in ['begin_svg_mask_layer', 'begin_css_filter_layer'] {
			chromium_layerize_chunks_into(scratch.chunks, commands.len, scale, mut plan, mut scratch.layer_states)
			return
		}
	}
	metadata_mode := chromium_collect_paint_metadata(result, commands, cull, mut scratch)
	if metadata_mode == .none {
		chromium_layerize_chunks_into(scratch.chunks, commands.len, scale, mut plan, mut scratch.layer_states)
		return
	}
	plan.has_paint_metadata = metadata_mode == .geometry
	scratch.paint_chunks.clear()
	scratch.paint_chunk_contexts.clear()
	scratch.command_chunk_groups.clear()
	mut metadata_index := 0
	scratch.paint_chunk_context = -1
	scratch.paint_chunk_client = 0
	for chunk in scratch.chunks {
		for metadata_index < scratch.paint_metadata.len
			&& scratch.paint_metadata[metadata_index].at <= chunk.command_index {
			metadata := scratch.paint_metadata[metadata_index]
			chromium_append_paint_chunk(metadata.bounds, metadata.state, metadata.context, metadata.client,
				mut scratch)
			metadata_index++
		}
		if !chromium_paint_chunk_is_interested(chunk, cull)
			&& !scratch.paint_visible_effects[chunk.state.effect_scope]
			&& !chromium_paint_chunk_has_pending_image(chunk, commands) {
			scratch.command_chunk_groups << -1
		} else {
			context, client := chromium_chunk_context(chunk, result, commands)
			group := chromium_append_paint_chunk(chunk.bounds, chunk.state, context, client,
				mut scratch)
			if chunk.unbounded_sticky_overlap {
				last := scratch.paint_chunks[group]
				scratch.paint_chunks[group] = ChromiumRasterChunk{ ...last, unbounded_sticky_overlap: true }
			}
			if chunk.unbounded_transform_overlap {
				last := scratch.paint_chunks[group]
				scratch.paint_chunks[group] = ChromiumRasterChunk{ ...last, unbounded_transform_overlap: true }
			}
			scratch.command_chunk_groups << group
		}
		// The retained atomic run already owns its descendants' geometry.
		for metadata_index < scratch.paint_metadata.len
			&& scratch.paint_metadata[metadata_index].at < chunk.command_end {
			metadata_index++
		}
	}
	for metadata_index < scratch.paint_metadata.len {
		metadata := scratch.paint_metadata[metadata_index]
		chromium_append_paint_chunk(metadata.bounds, metadata.state, metadata.context, metadata.client,
			mut scratch)
		metadata_index++
	}
	// Layerize geometry first. Group IDs retain disjoint command spans without
	// copying a command vector for every chunk or filling in culled gaps.
	chromium_layerize_chunks_into(scratch.paint_chunks, scratch.paint_chunks.len,
		scale, mut plan, mut scratch.layer_states)
	scratch.paint_chunk_layers.clear()
	scratch.paint_chunk_layers << plan.command_layers
	chromium_record_picture_clip_states(result, commands, mut scratch, mut plan)
	plan.has_picture_clip_metadata = true
	if metadata_mode == .clipping {
		// Clip ancestry is useful independently of hit-test raster geometry.
		// Preserve the existing no-scroll layer placement and tile origins;
		// metadata-only boxes must not change unrelated native pictures.
		scratch.chunk_picture_local_clips.clear()
		for group in scratch.command_chunk_groups {
			scratch.chunk_picture_local_clips << if group < 0 { true } else {
				plan.layers[scratch.paint_chunk_layers[group]].picture_local_rounded_clip
			}
		}
		chromium_layerize_chunks_into(scratch.chunks, commands.len, scale, mut plan, mut scratch.layer_states)
		for chunk_index, chunk in scratch.chunks {
			if scratch.chunk_picture_local_clips[chunk_index] {
				layer := plan.command_layers[chunk.command_index]
				plan.layers[layer].picture_local_rounded_clip = true
			}
		}
		return
	}
	plan.command_layers.clear()
	for _ in 0 .. commands.len { plan.command_layers << -1 }
	for index in 0 .. plan.layers.len { plan.layers[index].command_indices.clear() }
	for index, chunk in scratch.chunks {
		group := scratch.command_chunk_groups[index]
		if group < 0 { continue }
		layer := scratch.paint_chunk_layers[group]
		for command_index in chunk.command_index .. chunk.command_end {
			plan.command_layers[command_index] = layer
			plan.layers[layer].command_indices << command_index
		}
	}
}

fn chromium_common_recording_context(result &DocumentLayoutResult, first int, second int) int {
	if first < 0 || second < 0 { return 0 }
	mut left := first
	mut right := second
	// Visual contexts are appended after their parents. Raising the larger
	// index therefore finds the common ancestor without allocating a path.
	for left != right {
		if left > right {
			left = result.visual_context_tree.nodes[left].parent_index
		} else {
			right = result.visual_context_tree.nodes[right].parent_index
		}
		if left < 0 || right < 0 { return 0 }
	}
	return left
}

fn chromium_record_picture_clip_states(result &DocumentLayoutResult, commands []PaintCommand,
	mut scratch ChromiumRasterPlanScratch, mut plan ChromiumRasterLayerPlan) {
	scratch.layer_recording_contexts.clear()
	for _ in plan.layers { scratch.layer_recording_contexts << -1 }
	for group, context in scratch.paint_chunk_contexts {
		layer := scratch.paint_chunk_layers[group]
		old := scratch.layer_recording_contexts[layer]
		scratch.layer_recording_contexts[layer] = if old < 0 {
			if context < 0 { 0 } else { context }
		} else {
			chromium_common_recording_context(result, old, context)
		}
	}
	for chunk_index, chunk in scratch.chunks {
		group := scratch.command_chunk_groups[chunk_index]
		if group < 0 { continue }
		layer := scratch.paint_chunk_layers[group]
		context, _ := chromium_chunk_context(chunk, result, commands)
		mut cursor := context
		stop := scratch.layer_recording_contexts[layer]
		for cursor > 0 && cursor != stop {
			node := result.visual_context_tree.nodes[cursor]
			if node.data is painting.ClipVisualData {
				if node.data.corner_radii != painting.CornerRadii{} {
					plan.layers[layer].picture_local_rounded_clip = true
				}
			}
			cursor = node.parent_index
		}
	}
}
