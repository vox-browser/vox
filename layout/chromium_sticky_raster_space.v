module layout

import painting

// A sticky box's live offset belongs to the scroll property tree, not its
// retained author transform. Raster bounds must use the same space as replay
// before choosing a tile origin. Walk without allocating ancestor vectors.
fn chromium_sticky_raster_transform(box &BlockBox, result &DocumentLayoutResult) [6]f64 {
	if box.sticky_scroll_frame_index <= 0 { return box.paint_transform }
	mut transform := [f64(1), 0, 0, 1, 0, 0]!
	mut context := box.accumulated_visual_context_index
	for context > 0 && context < result.visual_context_tree.nodes.len {
		node := &result.visual_context_tree.nodes[context]
		match node.data {
			painting.TransformVisualData {
				matrix := [node.data.matrix.a, node.data.matrix.b, node.data.matrix.c,
					node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!
				transform = multiply_affine(affine_around_origin(matrix,
					node.data.origin.x, node.data.origin.y), transform)
			}
			painting.PerspectiveVisualData {
				transform = multiply_affine([node.data.matrix.a, node.data.matrix.b,
					node.data.matrix.c, node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!, transform)
			}
			painting.ScrollVisualData, painting.ScrollCompensationVisualData {
				offset := result.scroll_state_snapshot.device_offset_for_index(node.data.scroll_frame_index)
				sign := if node.data is painting.ScrollCompensationVisualData { -1.0 } else { 1.0 }
				transform = multiply_affine(translated_affine(sign * offset.x, sign * offset.y), transform)
			}
			else {}
		}
		context = node.parent_index
	}
	if !box.fixed_to_viewport {
		viewport := result.document.viewport_rect()
		transform[4] += viewport.x
		transform[5] += viewport.y
	}
	return transform
}
