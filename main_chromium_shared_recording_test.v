module main

import layout
import math
import painting
import html
import os

fn shared_recording_test_commands() []layout.PaintCommand {
	return [layout.PaintCommand{ kind: 'fill_rect' }, layout.PaintCommand{
		kind:       'draw_replaced_image'
		image_data: &layout.PaintImageData{ image_url: 'https://example.test/vector.svg?version=2' }
	}]
}

fn test_shared_recording_requires_supported_contiguous_root_drawing_with_vectors() {
	commands := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0]
	}
	assert chromium_shared_recording_supported(commands, plan)
	assert !chromium_shared_recording_supported([commands[0]], layout.ChromiumRasterLayerPlan{
		layers:         plan.layers
		command_layers: [0]
	})
	assert !chromium_shared_recording_supported(commands, layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{ legacy_raster: true }]
		command_layers: [0, 0]
	})
	assert !chromium_shared_recording_supported([commands[0], commands[0], commands[1]], layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{}]
		command_layers: [0, 1, 0]
	})
}

fn test_culled_commands_do_not_interrupt_the_supported_root_picture() {
	base := shared_recording_test_commands()
	commands := [layout.PaintCommand{kind: 'unrepresented_offscreen_draw'}, base[0],
		layout.PaintCommand{kind: 'unrepresented_offscreen_draw'}, base[1]]
	plan := layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{command_indices: [1, 3]}]
		command_layers: [-1, 0, -1, 0]
	}
	assert chromium_shared_recording_supported(commands, plan)
	assert !chromium_shared_recording_supported(commands, layout.ChromiumRasterLayerPlan{
		...plan
		command_layers: [0, 0, -1, 0]
	})
}

fn test_shared_recording_keeps_clips_effects_and_unrepresented_draws_on_the_leaf_path() {
	base := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0]
	}
	for unsupported in [
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ kind: 'draw_text', blur: 1 },
		layout.PaintCommand{
			kind:        'fill_rect'
			has_clip:    true
			clip_width:  1
			clip_height: 1
			clip_list:   &layout.PaintClipList{ items: [layout.PaintClip{ is_path: true }] }
		},
		layout.PaintCommand{ kind: 'fill_rect', clip_outs: [
			f64(0),
			0,
			10,
			10,
		] },
	] {
		assert !chromium_shared_recording_supported([unsupported, base[1]], plan)
	}
}

fn test_shared_recording_accepts_vector_image_display_lists_but_rejects_nested_documents() {
	image := layout.PaintCommand{
		kind:                      'paint_nested_display_list'
		width:                     80
		height:                    86
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{0, 0, 80, 86}
		}
		nested_viewport_commands:  [layout.PaintCommand{
			kind:     'draw_svg_path'
			svg_data: &layout.PaintSVGPathData{
				path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			}
		}]
	}
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0]
	}
	assert chromium_shared_recording_supported([image], plan)
	assert !chromium_shared_recording_supported([layout.PaintCommand{
		...image
		nested_viewport_commands: [layout.PaintCommand{ kind: 'draw_text' }]
	}], plan)
}

fn test_shared_recording_ignores_empty_clipped_leaves_but_keeps_effect_boundaries() {
	base := shared_recording_test_commands()
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0, 0]
	}
	for kind in ['fill_rect', 'stroke_rounded_rect'] {
		for size in [[f64(0), 1]!, [f64(1), 0]!, [f64(-1), 1]!] {
			hidden := layout.PaintCommand{
				kind:        kind
				has_clip:    true
				clip_width:  size[0]
				clip_height: size[1]
				clip_list:   &layout.PaintClipList{ items: [layout.PaintClip{}] }
			}
			assert chromium_shared_recording_supported([base[0], hidden, base[1]], plan)
		}
	}
	for kind in ['begin_css_effect_layer', 'end_css_effect_layer', 'begin_svg_mask_layer'] {
		assert !chromium_shared_recording_supported([base[0], layout.PaintCommand{
			kind:     kind
			has_clip: true
		}, base[1]], plan)
	}
	assert !chromium_shared_recording_supported([layout.PaintCommand{
		...base[1]
		has_clip: true
	}], layout.ChromiumRasterLayerPlan{
		layers:         plan.layers
		command_layers: [0]
	})
}

fn shared_recording_layer_commands(opacity f64) []layout.PaintCommand {
	data := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 7, opacity: opacity }
	return [
		layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: data },
		layout.PaintCommand{ kind: 'fill_rounded_rect' },
		layout.PaintCommand{ kind: 'draw_svg_path' },
		layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: data },
	]
}

fn shared_recording_layer_plan(count int) layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			command_indices: []int{len: count, init: index}
		}]
		command_layers: []int{len: count, init: 1}
	}
}

fn test_shared_recording_accepts_complete_rectangular_svg_clip_scopes() {
	stride := layout.compatibility_clip_path_segment_stride
	mut data := []f32{len: stride * 5}
	for i, point in [painting.Point{15, 16}, painting.Point{141, 16},
		painting.Point{141, 127}, painting.Point{15, 127}] {
		data[i * stride] = if i == 0 { f32(0) } else { f32(1) }
		data[i * stride + 1] = f32(point.x)
		data[i * stride + 2] = f32(point.y)
	}
	data[stride * 4] = 5
	clip := &layout.PaintClip{
		is_svg_mask: true
		cache_key: 7
		scope_id: 11
		path_components: [layout.PaintPath{path_data: data}]
	}
	mask := [
		layout.PaintCommand{kind: 'begin_svg_mask_layer', mask_clip_data: clip},
		layout.PaintCommand{kind: 'draw_svg_path', color: '#fff',
			svg_data: &layout.PaintSVGPathData{path_data: data}},
		layout.PaintCommand{kind: 'end_svg_mask_layer', mask_clip_data: clip},
	]
	root := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0, 0]
	}
	assert chromium_shared_recording_supported(mask, root)
	assert !chromium_shared_recording_layer_supported(mask, shared_recording_layer_plan(mask.len), 1)
	assert !chromium_shared_recording_supported(mask[..2], layout.ChromiumRasterLayerPlan{
		layers:         root.layers
		command_layers: [0, 0]
	})
	base := shared_recording_layer_commands(.5)
	commands := [base[0], base[1], mask[0], mask[1], mask[2], base[3]]
	plan := shared_recording_layer_plan(commands.len)
	assert chromium_shared_recording_layer_supported(commands, plan, 1)
	mut interrupted := commands.clone()
	interrupted[3] = layout.PaintCommand{ kind: 'begin_css_filter_layer' }
	assert !chromium_shared_recording_layer_supported(interrupted, plan, 1)
	assert !chromium_shared_recording_layer_supported(commands, layout.ChromiumRasterLayerPlan{
		layers:         plan.layers
		command_layers: [1, 1, 1, 2, 1, 1]
	}, 1)
}

fn test_shared_recording_accepts_complete_isolated_css_scopes() {
	for opacity in [0.0, 0.5, 1.0] {
		commands := shared_recording_layer_commands(opacity)
		plan := shared_recording_layer_plan(commands.len)
		assert chromium_shared_recording_layer_supported(commands, plan, 1)
		assert !chromium_shared_recording_layer_supported(commands, plan, 0)
		assert !chromium_shared_recording_layer_supported(commands, plan, -1)
		assert !chromium_shared_recording_layer_supported(commands, plan, 2)
		assert !chromium_shared_recording_supported(commands, plan)
	}
}

fn test_shared_recording_layer_requires_balanced_supported_commands_and_complete_ownership() {
	base := shared_recording_layer_commands(1)
	plan := shared_recording_layer_plan(base.len)
	for unsupported in [
		layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: base[0].visual_layer_data },
		layout.PaintCommand{ kind: 'draw_text', blur: 2 },
		layout.PaintCommand{
			kind:        'fill_rect'
			has_clip:    true
			clip_width:  4
			clip_height: 4
			clip_list:   &layout.PaintClipList{ items: [layout.PaintClip{ is_svg_mask: true }] }
		},
		layout.PaintCommand{ kind: 'draw_background_image' },
	] {
		mut commands := base.clone()
		commands[1] = unsupported
		assert !chromium_shared_recording_layer_supported(commands, plan, 1)
	}
	for kind in ['begin_css_filter_layer', 'end_css_effect_layer'] {
		mut commands := base.clone()
		commands[0] = layout.PaintCommand{ kind: kind, visual_layer_data: base[0].visual_layer_data }
		assert !chromium_shared_recording_layer_supported(commands, plan, 1)
	}
	for data in [
		&layout.PaintVisualLayer{ kind: .css_effect, scope_id: 8 },
		&layout.PaintVisualLayer{ kind: .css_effect, scope_id: 7, blend_mode: .multiply },
		&layout.PaintVisualLayer{ kind: .svg_mask, scope_id: 7 },
	] {
		mut commands := base.clone()
		commands[3] = layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: data }
		assert !chromium_shared_recording_layer_supported(commands, plan, 1)
	}
	mut no_vectors := base.clone()
	no_vectors[2] = layout.PaintCommand{ kind: 'fill_rect' }
	assert !chromium_shared_recording_layer_supported(no_vectors, plan, 1)
	for indices in [[0, 2, 3], [0, 1, 2], [-1, 1, 3], [0, 1, 4], [4, 1, 3], [0, 2, 1, 3], [0, 1, 1, 3]] {
		assert !chromium_shared_recording_layer_supported(base, layout.ChromiumRasterLayerPlan{
			layers:         [plan.layers[0], layout.ChromiumRasterLayer{ command_indices: indices }]
			command_layers: plan.command_layers
		}, 1)
	}
	assert !chromium_shared_recording_layer_supported(base, layout.ChromiumRasterLayerPlan{
		layers:         [plan.layers[0],
			layout.ChromiumRasterLayer{ legacy_raster: true, command_indices: [0, 1, 2, 3] }]
		command_layers: plan.command_layers
	}, 1)
}

fn test_shared_recording_accepts_painted_compositor_layers_with_svg_viewport_clips() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-shared-recording.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	for scale in [1.0, 2.0] {
		plan := layout.chromium_raster_layer_plan(document, commands, scale)
		assert plan.layers.len == 6
		assert !chromium_shared_recording_layer_supported(commands, plan, 1)
		for layer_index in 2 .. 6 {
			assert chromium_shared_recording_layer_supported(commands, plan, layer_index)
		}
		// Both a standalone path and rounded viewport clips retain their clip
		// when replayed into the complete compositor picture.
		indices := plan.layers[2].command_indices
		mut single := commands.clone()
		single[indices[4]] = layout.PaintCommand{ kind: 'fill_rect' }
		assert chromium_shared_recording_layer_supported(single, plan, 2)
		mut rounded := commands.clone()
		path_index := indices[3]
		path := commands[path_index]
		clip := path.clip_list.items[0]
		rounded[path_index] = layout.PaintCommand{
			...path
			clip_list: &layout.PaintClipList{
				items: [layout.PaintClip{
					...clip
					corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{ x: 1, y: 1 } }
				}]
			}
		}
		assert chromium_shared_recording_layer_supported(rounded, plan, 2)
	}
}

fn test_shared_recording_accepts_outer_shadows_only_in_complete_isolated_layers() {
	base := shared_recording_layer_commands(.5)
	shadow := layout.PaintCommand{
		kind:            'paint_outer_box_shadow'
		blur:            20
		box_shadow_data: &layout.PaintBoxShadowData{
			content_rect: layout.LayoutRect{0, 0, 100, 50}
		}
	}
	commands := [base[0], shadow, base[1], base[3]]
	plan := shared_recording_layer_plan(commands.len)
	assert chromium_shared_recording_layer_supported(commands, plan, 1)
	assert !chromium_shared_recording_supported([shadow, base[2]], layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}]
		command_layers: [0, 0]
	})
	for unsupported in [
		layout.PaintCommand{ ...shadow, box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...shadow, kind: 'paint_inner_box_shadow' },
		layout.PaintCommand{ ...shadow, has_clip: true, clip_width: 1, clip_height: 1 },
		layout.PaintCommand{ ...shadow, clip_list: &layout.PaintClipList{} },
		layout.PaintCommand{ ...shadow, clip_outs: [f64(0), 0, 1, 1] },
		layout.PaintCommand{ kind: 'fill_rect', outer_shadow: true },
	] {
		assert !chromium_shared_recording_layer_supported([base[0], unsupported, base[1], base[3]], plan, 1)
	}
}

fn test_shared_recording_accepts_painted_compositor_box_shadows_at_both_scales() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-box-shadows.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.filter(it.kind == 'paint_outer_box_shadow').len == 3
	for scale in [1.0, 2.0] {
		plan := layout.chromium_raster_layer_plan(document, commands, scale)
		assert plan.layers.len == 2
		assert chromium_shared_recording_layer_supported(commands, plan, 1)
	}
}

fn test_shared_recording_preserves_supported_clip_stacks_and_bitmap_backgrounds() {
	base := shared_recording_layer_commands(1)
	clip := layout.PaintClip{
		rect:         layout.LayoutRect{4, 8, 40, 24}
		transform:    [f64(.8), .6, -.6, .8, 20, 30]!
		corner_radii: layout.BoxRadii{
			top_left: layout.CornerRadius{ x: 4, y: 6 }
		}
	}
	clipped := layout.PaintCommand{
		kind:        'draw_background_image'
		has_clip:    true
		clip_width:  40
		clip_height: 24
		clip_list:   &layout.PaintClipList{ items: [
			layout.PaintClip{ rect: layout.LayoutRect{0, 0, 100, 100} },
			clip,
		] }
		image_data:  &layout.PaintImageData{ image_url: 'data:image/png;base64,AA==' }
	}
	plan := shared_recording_layer_plan(4)
	assert chromium_shared_recording_layer_supported([base[0], clipped, base[2], base[3]], plan, 1)
	for invalid in [
		layout.PaintClip{ ...clip, is_path: true },
		layout.PaintClip{ ...clip, is_svg_mask: true },
		layout.PaintClip{ ...clip, is_svg_content_mask: true },
		layout.PaintClip{ ...clip, rect: layout.LayoutRect{math.nan(), 0, 40, 24} },
		layout.PaintClip{ ...clip, transform: [f64(1), 0, 0, 1, math.inf(1), 0]! },
		layout.PaintClip{ ...clip, corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{ x: -1 } } },
	] {
		command := layout.PaintCommand{ ...clipped, clip_list: &layout.PaintClipList{ items: [invalid] } }
		assert !chromium_shared_recording_layer_supported([base[0], command, base[2], base[3]], plan, 1)
	}
	for url in ['image.svg?x=1', 'image.svg#icon', 'data:image/svg+xml;base64,AA=='] {
		command := layout.PaintCommand{ ...clipped, image_data: &layout.PaintImageData{ image_url: url } }
		assert !chromium_shared_recording_layer_supported([base[0], command, base[2], base[3]], plan, 1)
	}
}

fn test_shared_recording_accepts_clipped_header_picture_at_both_scales() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-clipped-content.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.filter(it.kind == 'draw_background_image').len > 0
	assert commands.filter(it.kind == 'draw_svg_path' && it.has_clip).len > 0
	for scale in [1.0, 2.0] {
		plan := layout.chromium_raster_layer_plan(document, commands, scale)
		assert plan.layers.len == 2
		assert chromium_shared_recording_layer_supported(commands, plan, 1)
	}
}

fn test_shared_recording_accepts_gradient_fills_and_strokes_with_safe_fallbacks() {
	base := shared_recording_layer_commands(1)
	for gradients in [
		&layout.PaintSVGGradientData{ fill_linear_gradient: painting.SVGLinearGradientPaintStyle{} },
		&layout.PaintSVGGradientData{ stroke_linear_gradient: painting.SVGLinearGradientPaintStyle{} },
		&layout.PaintSVGGradientData{ fill_radial_gradient: painting.SVGRadialGradientPaintStyle{} },
		&layout.PaintSVGGradientData{ stroke_radial_gradient: painting.SVGRadialGradientPaintStyle{} },
	] {
		data := &layout.PaintSVGPathData{ svg_gradient_data: gradients }
		command := layout.PaintCommand{ kind: 'draw_svg_path', svg_data: data }
		assert chromium_shared_recording_layer_supported([base[0], base[1], command, base[3]], shared_recording_layer_plan(4), 1)
		assert chromium_shared_recording_supported([command], layout.ChromiumRasterLayerPlan{
			layers: [layout.ChromiumRasterLayer{}]
			command_layers: [0]
		})
		for unsupported in [
			&layout.PaintSVGPathData{ ...data, non_scaling_stroke: true },
			&layout.PaintSVGPathData{ ...data, stroke_dasharray: [f64(2), 3] },
			&layout.PaintSVGPathData{ ...data, fill_pattern: &painting.SVGPatternPaintStyle{} },
			&layout.PaintSVGPathData{ ...data, stroke_pattern: &painting.SVGPatternPaintStyle{} },
		] {
			assert !chromium_shared_recording_layer_supported([base[0], base[1], layout.PaintCommand{
				...command
				svg_data: unsupported
			}, base[3]], shared_recording_layer_plan(4), 1)
		}
	}
}

fn test_shared_recording_accepts_painted_gradient_header_at_both_scales() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-svg-gradients.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.filter(it.kind == 'draw_svg_path' && it.svg_data != unsafe { nil } && it.svg_data.svg_gradient_data != none).len >= 4
	for scale in [1.0, 2.0] {
		plan := layout.chromium_raster_layer_plan(document, commands, scale)
		assert plan.layers.len == 2
		assert chromium_shared_recording_layer_supported(commands, plan, 1)
	}
}

fn test_shared_recording_full_opacity_scope_can_cross_an_empty_child_layer() {
	for opacity in [1.0, .5] {
		base := shared_recording_layer_commands(opacity)
		child := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 8, opacity: 1 }
		commands := [base[0], base[2],
			layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: child },
			layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: child },
			base[2], base[3]]
		plan := layout.ChromiumRasterLayerPlan{
			layers: [layout.ChromiumRasterLayer{},
				layout.ChromiumRasterLayer{ command_indices: [0, 1] },
				layout.ChromiumRasterLayer{ command_indices: [2, 3] },
				layout.ChromiumRasterLayer{ command_indices: [4, 5] }]
			command_layers: [1, 1, 2, 2, 3, 3]
		}
		assert chromium_shared_recording_layer_supported(commands, plan, 1) == (opacity == 1)
		assert !chromium_shared_recording_layer_supported(commands, plan, 2)
		assert chromium_shared_recording_layer_supported(commands, plan, 3) == (opacity == 1)
		mut broken := commands.clone()
		broken[5] = layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: child }
		assert !chromium_shared_recording_layer_supported(broken, plan, 1)
		assert !chromium_shared_recording_layer_supported(broken, plan, 3)
	}
}

fn test_shared_recording_rejects_unscoped_vectors_and_content_after_scope_end() {
	base := shared_recording_layer_commands(1)
	assert !chromium_shared_recording_layer_supported([base[2]], layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{ command_indices: [0] }]
		command_layers: [1]
	}, 1)
	assert !chromium_shared_recording_layer_supported([base[0], base[2], base[3], base[2]], shared_recording_layer_plan(4), 1)
}

fn test_shared_recording_parent_resumes_after_complete_clipped_and_translucent_children() {
	for parent_opacity in [1.0, .5] {
		base := shared_recording_layer_commands(parent_opacity)
		child := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 8, opacity: 1 }
		inner := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 9, opacity: .8 }
		commands := [base[0], base[2],
			layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: child,
				has_clip: true, clip_width: 30, clip_height: 40 },
			layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: inner },
			// Unsupported parent-picture drawing is legal inside the separately
			// replayed child; it must not be incorporated into the parent picture.
			layout.PaintCommand{ kind: 'draw_text', blur: 2 },
			layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: inner },
			layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: child },
			base[2], base[3]]
		plan := layout.ChromiumRasterLayerPlan{
			layers: [layout.ChromiumRasterLayer{},
				layout.ChromiumRasterLayer{ command_indices: [0, 1, 7, 8] },
				layout.ChromiumRasterLayer{ command_indices: [2, 3, 4, 5, 6] }]
			command_layers: [1, 1, 2, 2, 2, 2, 2, 1, 1]
		}
		assert chromium_shared_recording_layer_supported(commands, plan, 1) == (parent_opacity == 1)
		if parent_opacity != 1 { continue }
		// A gap may contain several complete effects and more than one child
		// owner, but may neither omit a parent command nor cross a scope edge.
		for owners in [[1, 1, 2, 2, 2, 2, 2, 1, 1], [1, 1, 2, 3, 3, 3, 2, 1, 1]] {
			assert chromium_shared_recording_layer_supported(commands, layout.ChromiumRasterLayerPlan{
				layers: [plan.layers[0], plan.layers[1], plan.layers[2], layout.ChromiumRasterLayer{}]
				command_layers: owners
			}, 1)
		}
		for owner in [0, 1, -1, 3] {
			mut owners := plan.command_layers.clone()
			owners[4] = owner
			assert !chromium_shared_recording_layer_supported(commands, layout.ChromiumRasterLayerPlan{
				layers: plan.layers
				command_layers: owners
			}, 1)
		}
		for change_index in [2, 3, 5, 6] {
			for replacement in [
				layout.PaintCommand{ kind: 'fill_rect' },
				layout.PaintCommand{ kind: 'begin_css_filter_layer' },
				layout.PaintCommand{ kind: commands[change_index].kind, visual_layer_data: base[0].visual_layer_data },
			] {
				mut broken := commands.clone()
				broken[change_index] = replacement
				assert !chromium_shared_recording_layer_supported(broken, plan, 1)
			}
		}
		mut crossed := commands.clone()
		crossed[5], crossed[6] = crossed[6], crossed[5]
		assert !chromium_shared_recording_layer_supported(crossed, plan, 1)
		// Flush and resume twice, with ordinary drawing between child scopes.
		twice := [commands[0], commands[1], commands[2], commands[6], commands[7],
			commands[3], commands[4], commands[5], commands[7], commands[8]]
		assert chromium_shared_recording_layer_supported(twice, layout.ChromiumRasterLayerPlan{
			layers: [plan.layers[0], layout.ChromiumRasterLayer{ command_indices: [0, 1, 4, 8, 9] }, plan.layers[2]]
			command_layers: [1, 1, 2, 2, 1, 2, 2, 2, 1, 1]
		}, 1)
	}
}

fn test_shared_recording_rounded_border_sides_require_four_finite_nonnegative_widths() {
	base := shared_recording_layer_commands(1)
	for side in ['top', 'right', 'bottom', 'left'] {
		border := layout.PaintCommand{ kind: 'paint_rounded_border_${side}', points: [f64(1), 2, 3, 4] }
		assert chromium_shared_recording_layer_supported([base[0], border, base[2], base[3]], shared_recording_layer_plan(4), 1)
		for widths in [ []f64{}, [f64(1)], [f64(1), 2, 3], [f64(1), 2, 3, 4, 5],
			[f64(1), -1, 3, 4], [f64(1), 2, math.nan(), 4], [f64(1), 2, 3, math.inf(1)] ] {
			assert !chromium_shared_recording_layer_supported([base[0], layout.PaintCommand{
				...border
				points: widths
			}, base[2], base[3]], shared_recording_layer_plan(4), 1)
		}
	}
}

fn test_shared_recording_painted_parent_resumes_after_child_effects_at_both_scales() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/compositor-parent-resume.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	for scale in [1.0, 2.0] {
		plan := layout.chromium_raster_layer_plan(document, commands, scale)
		assert plan.layers.len > 2
		indices := plan.layers[1].command_indices
		mut gaps := 0
		mut borders := 0
		for position, index in indices {
			if position > 0 && index > indices[position - 1] + 1 { gaps++ }
			if commands[index].kind == 'paint_rounded_border_bottom' { borders++ }
		}
		assert gaps >= 3
		assert borders == 4
		assert chromium_shared_recording_layer_supported(commands, plan, 1)
	}
}
