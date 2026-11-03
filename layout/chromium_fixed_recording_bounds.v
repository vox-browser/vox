module layout

// Fixed containers can contribute hit-test geometry before any descendant
// paints. Insert those bounds without regrouping ordinary drawing clients.
fn chromium_layerize_fixed_container_metadata(command_count int,
	mut scratch ChromiumRasterPlanScratch, mut plan ChromiumRasterLayerPlan, scale f64) {
	scratch.paint_chunks.clear()
	mut metadata_index := 0
	for chunk in scratch.chunks {
		for metadata_index < scratch.paint_metadata.len
			&& scratch.paint_metadata[metadata_index].at <= chunk.command_index {
			metadata := scratch.paint_metadata[metadata_index]
			if metadata.fixed_container {
				scratch.paint_chunks << ChromiumRasterChunk{
					state:         metadata.state
					bounds:        metadata.bounds
					command_index: -1
					draws_content: false
				}
			}
			metadata_index++
		}
		scratch.paint_chunks << chunk
	}
	for metadata_index < scratch.paint_metadata.len {
		metadata := scratch.paint_metadata[metadata_index]
		if metadata.fixed_container {
			scratch.paint_chunks << ChromiumRasterChunk{
				state:         metadata.state
				bounds:        metadata.bounds
				command_index: -1
				draws_content: false
			}
		}
		metadata_index++
	}
	chromium_layerize_chunks_into(scratch.paint_chunks, command_count, scale,
		mut plan, mut scratch.layer_states)
}

fn chromium_fixed_raster_group(box &BlockBox, node &Node) int {
	transform := normalized_affine(box.paint_transform)
	if transform[0] != 1 || transform[1] != 0 || transform[2] != 0 || transform[3] != 1 {
		return 0
	}
	inset := node.computed_values().inset()
	mut group := 1
	if inset.left().is_auto() && !inset.right().is_auto() { group += 1 }
	if inset.top().is_auto() && !inset.bottom().is_auto() { group += 2 }
	return group
}

fn chromium_raster_states_mergeable(home ChromiumRasterPropertyState,
	guest ChromiumRasterPropertyState) bool {
	if home == guest { return true }
	if !home.fixed_to_viewport || !guest.fixed_to_viewport || home.legacy_effect
		|| guest.legacy_effect || home.effect_scope != 0 || guest.effect_scope != 0
		|| home.scroll_frame != 0 || guest.scroll_frame != 0
		|| home.sticky_frame != 0 || guest.sticky_frame != 0
		|| home.fixed_raster_group == 0 || home.fixed_raster_group != guest.fixed_raster_group {
		return false
	}
	return home == ChromiumRasterPropertyState{ ...guest, fixed_raster_owner: home.fixed_raster_owner }
}
