// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import painting

// Ladybird 51929bd7fefea35081cf82a2b2b5d1ad6b97f4a3.
fn test_clips_apply_to_the_filtered_result() {
	for clip_kind in ['css', 'path', 'mask'] {
		mut box := BlockBox{
			opacity: 0.5
			own_paint_transform: [f64(2), 0, 0, 2, 0, 0]!
			filter_data: retained_block_box_filter(BlockBoxFilterData{
				filter: painting.ResolvedCSSFilter{
					operations: [painting.ResolvedFilterOperation(painting.BlurFilter{radius: 4})]
				}
			})
			clip_data: retained_block_box_clip(BlockBoxClipData{
				css_clip: if clip_kind == 'css' { ?&LayoutRect(&LayoutRect{0, 0, 100, 100}) } else { none }
				clip_path: if clip_kind == 'path' { ?&painting.ClipPathVisualData(&painting.ClipPathVisualData{}) } else { none }
				svg_mask: if clip_kind == 'mask' { ?&painting.SVGMaskVisualData(&painting.SVGMaskVisualData{}) } else { none }
			})
		}
		mut tree := painting.new_accumulated_visual_context_tree()
		assign_compatibility_visual_contexts(mut box, none, map[u64]&BlockBox{}, mut tree)
		effects := tree.node_at(box.own_effects_visual_context_idx)
		assert effects.data is painting.EffectsVisualData
		assert box.accumulated_visual_context_index == box.own_effects_visual_context_idx
		clip := tree.node_at(effects.parent_index)
		assert clip.data is painting.ClipVisualData || clip.data is painting.ClipPathVisualData
			|| clip.data is painting.SVGMaskVisualData
		assert clip.parent_index == box.own_transform_visual_context_idx
	}
}

fn test_unfiltered_opacity_keeps_the_existing_outer_effect_scope() {
	mut box := BlockBox{
		opacity: 0.5
		clip_data: retained_block_box_clip(BlockBoxClipData{
			css_clip: &LayoutRect{0, 0, 100, 100}
		})
	}
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut box, none, map[u64]&BlockBox{}, mut tree)
	assert tree.node_at(box.accumulated_visual_context_index).parent_index == box.own_effects_visual_context_idx
	assert tree.node_at(box.own_effects_visual_context_idx).parent_index == 0
}
