// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom
import html
import painting

fn line_clamp_hit_id(mut document dom.Document, x f64, y f64) string {
	element := document.element_from_point(x, y) or { return '' }
	return element.get_attribute_value('id')
}

// Ladybird 715cb96bf1843aa9a2e2434d58024c1b20079245 and its cleaned
// regression fixtures in f00e167d31a616c292785c32dc8d61716c5e3c44.
fn test_line_clamp_clips_only_floats_in_its_own_formatting_context() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}.line{display:inline-block;width:150px;height:20px}
			#container{width:200px;line-clamp:2 no-ellipsis;font-size:0}
			#float{float:left;width:50px;height:100px}
			#host{position:absolute;left:300px;top:0;width:200px}
			#clamping-float{float:left;width:150px;padding-bottom:20px;line-clamp:1 no-ellipsis;font-size:0}
			#nested-container{position:absolute;left:0;top:200px;width:200px;line-clamp:2 no-ellipsis;font-size:0}
			.nested{height:10px}#flow-root{display:flow-root}
			#block-float{float:right;width:40px;height:100px}
			#flow-root-float{float:left;width:40px;height:100px}
			</style>
			<div id="container"><div id="float"></div><div class="line"></div><div class="line"></div><div class="line"></div><div class="line"></div></div>
			<div id="host"><div id="clamping-float"><div class="line"></div><div class="line"></div></div></div>
			<div id="nested-container"><div class="nested"><div id="block-float"></div></div><div id="flow-root" class="nested"><div id="flow-root-float"></div></div><div class="line"></div><div class="line"></div><div class="line"></div><div class="line"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert line_clamp_hit_id(mut document, 25, 30) == 'float'
		assert line_clamp_hit_id(mut document, 25, 50) != 'float'
		mut container := document.get_element_by_id('container') or { panic('container') }
		container.set_attribute_value('style', 'line-clamp:3 no-ellipsis')
		assert line_clamp_hit_id(mut document, 25, 50) == 'float'
		assert line_clamp_hit_id(mut document, 25, 70) != 'float'
		assert line_clamp_hit_id(mut document, 325, 30) == 'clamping-float'
		assert line_clamp_hit_id(mut document, 180, 250) == 'block-float'
		assert line_clamp_hit_id(mut document, 180, 270) != 'block-float'
		assert line_clamp_hit_id(mut document, 20, 280) == 'flow-root-float'
		mut nested := document.get_element_by_id('nested-container') or { panic('nested') }
		nested.set_attribute_value('style', 'line-clamp:3 no-ellipsis')
		assert line_clamp_hit_id(mut document, 180, 270) == 'block-float'
		assert line_clamp_hit_id(mut document, 180, 290) != 'block-float'
	}
}

fn test_vertical_line_clamp_uses_the_block_end_edge() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#vertical{position:absolute;left:300px;top:100px;height:200px;writing-mode:vertical-rl;line-clamp:2 no-ellipsis;font-size:0}
		#float{float:left;width:100px;height:30px}
		.line{display:inline-block;width:20px;height:150px}</style>
		<div id="vertical"><div id="float"></div><div class="line"></div><div class="line"></div><div class="line"></div><div class="line"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert line_clamp_hit_id(mut document, 330, 115) == 'float'
	assert line_clamp_hit_id(mut document, 270, 115) != 'float'
}

fn test_parent_decided_clip_precedes_own_sticky_effects_and_transform() {
	mut box := BlockBox{
		opacity: 0.5
		sticky_scroll_frame_index: 1
		own_paint_transform: [f64(1), 0, 0, 1, 0, -20]!
		clip_data: retained_block_box_clip(BlockBoxClipData{
			clip_decided_by_parent: &LayoutRect{-100, -100, 200, 140}
		})
	}
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut box, none, map[u64]&BlockBox{}, mut tree)
	transform := tree.node_at(box.own_transform_visual_context_idx)
	effects := tree.node_at(transform.parent_index)
	sticky := tree.node_at(effects.parent_index)
	clip := tree.node_at(sticky.parent_index)
	assert effects.data is painting.EffectsVisualData
	assert sticky.data is painting.ScrollVisualData
	assert clip.data is painting.ClipVisualData
	assert clip.parent_index == 0
}
