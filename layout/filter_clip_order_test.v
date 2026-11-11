// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import painting

// Ladybird 51929bd7fefea35081cf82a2b2b5d1ad6b97f4a3.
fn test_clips_apply_to_the_filtered_result_without_moving_blending_inside_the_clip() {
	for clip_kind in ['css', 'path', 'mask'] {
		mut box := BlockBox{
			opacity: 0.5
			mix_blend_mode: .multiply
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

		inner := tree.node_at(box.accumulated_visual_context_index)
		assert inner.data is painting.EffectsVisualData
		inner_effects := inner.data as painting.EffectsVisualData
		assert inner_effects.filter != none
		assert inner_effects.opacity == 1.0
		assert inner_effects.blend_mode == .normal

		clip := tree.node_at(inner.parent_index)
		assert clip.data is painting.ClipVisualData || clip.data is painting.ClipPathVisualData
			|| clip.data is painting.SVGMaskVisualData
		assert clip.parent_index == box.own_transform_visual_context_idx

		transform := tree.node_at(box.own_transform_visual_context_idx)
		outer := tree.node_at(transform.parent_index)
		assert outer.data is painting.EffectsVisualData
		outer_effects := outer.data as painting.EffectsVisualData
		assert outer_effects.filter == none
		assert outer_effects.opacity == 0.5
		assert outer_effects.blend_mode == .multiply
		assert box.own_effects_visual_context_idx == transform.parent_index
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
