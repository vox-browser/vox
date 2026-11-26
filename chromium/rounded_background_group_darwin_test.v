// vtest build: macos
module main

import html
import layout
import math
import os

fn test_rounded_background_group_rejects_independent_clip_and_sample_state() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:50px;top:50px;width:217px;height:52px;box-sizing:border-box;border:1px solid #528fd4;background:#467fc2;border-radius:10px 0 0 10px}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	layers := []int{len: commands.len}
	mut pairs := 0
	for i, c in commands {
		if c.kind != 'fill_rounded_rect' || c.color != 'rgb(70 127 194)' { continue }
		assert rounded_background_group_end(commands, layers, i) == i + 2
		pairs++
		for replacement in [layout.PaintCommand{ ...commands[i + 1], has_clip: true },
			layout.PaintCommand{ ...commands[i + 1], disable_antialias: true },
			layout.PaintCommand{ ...commands[i + 1], group_opacity: .5 },
			layout.PaintCommand{ ...commands[i + 1], clip_outs: [f64(0), 0, 10, 10] },
			layout.PaintCommand{ ...commands[i + 1], scrollbar_axis: 'vertical' }] {
			mut changed := commands.clone()
			changed[i + 1] = replacement
			assert rounded_background_group_end(changed, layers, i) == i
		}
		mut separate := layers.clone()
		separate[i + 1] = 1
		assert rounded_background_group_end(commands, separate, i) == i
	}
	assert pairs == 1
	assert rounded_background_group_end(commands, layers, -1) == -1
	assert rounded_background_group_end(commands, layers, commands.len) == commands.len
}

fn test_partial_background_border_and_header_keep_one_resolve() {
	mut document := html.parse_document(os.read_file(@VMODROOT + '/Tests/Browser/Brave/input/rounded-card-header-samples.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	layers := []int{len: commands.len}
	mut groups := 0
	for index, command in commands {
		if command.kind != 'paint_partial_rounded_border' { continue }
		start := index - 1
		assert chromium_partial_decoration_end(commands, layers, start) == start + 3
		assert rounded_background_group_end(commands, layers, start) == start + 3
		groups++
		for member in start .. start + 3 {
			for replacement in [
				layout.PaintCommand{ ...commands[member], has_clip: true },
				layout.PaintCommand{ ...commands[member], disable_antialias: true },
				layout.PaintCommand{ ...commands[member], group_opacity: .5 },
			] {
				mut changed := commands.clone()
				changed[member] = replacement
				assert rounded_background_group_end(changed, layers, start) == start
			}
		}
		promoted := []int{len: commands.len, init: 1}
		assert rounded_background_group_end(commands, promoted, start) == start
		mut clipped := commands.clone()
		for member in start .. start + 3 {
			clipped[member] = layout.PaintCommand{
				...clipped[member]
				has_clip:    true
				clip_x:      700
				clip_y:      90
				clip_width:  300
				clip_height: 570
				clip_list:   &layout.PaintClipList{
					items: [layout.PaintClip{
						rect: layout.LayoutRect{700, 90, 300, 570}
					}]
				}
			}
		}
		assert rounded_background_group_end(clipped, layers, start) == start + 3
	}
	assert groups == 1
}

fn test_partial_background_clip_intersection_preserves_local_geometry() {
	outer := layout.PaintClip{ rect: layout.LayoutRect{10, 20, 100, 80} }
	inner := layout.PaintClip{ rect: layout.LayoutRect{30, 10, 100, 50} }
	command := layout.PaintCommand{
		has_clip:    true
		clip_x:      10
		clip_y:      20
		clip_width:  100
		clip_height: 80
		clip_list:   &layout.PaintClipList{ items: [outer, inner] }
	}
	assert rounded_background_local_clip(&command)? == [f32(30), 20, 110, 60]!
	for replacement in [
		layout.PaintClip{ ...inner, is_path: true },
		layout.PaintClip{ ...inner, is_svg_mask: true },
		layout.PaintClip{ ...inner, is_svg_content_mask: true },
		layout.PaintClip{
			...inner
			corner_radii: layout.BoxRadii{
				top_left: layout.CornerRadius{1, 1}
			}
		},
		layout.PaintClip{ ...inner, transform: [f64(1), 0, 0, 1, 2, 0]! },
		layout.PaintClip{ rect: layout.LayoutRect{math.nan(), 0, 10, 10} },
		layout.PaintClip{ rect: layout.LayoutRect{0, 0, 0, 10} },
		layout.PaintClip{ rect: layout.LayoutRect{200, 0, 10, 10} },
	] {
		changed := layout.PaintCommand{
			...command
			clip_list: &layout.PaintClipList{ items: [outer, replacement] }
		}
		assert rounded_background_local_clip(&changed) == none
	}
	assert rounded_background_local_clip(&layout.PaintCommand{ ...command, has_clip: false }) == none
	assert rounded_background_local_clip(&layout.PaintCommand{ ...command, clip_width: 0 }) == none
	assert rounded_background_local_clip(&layout.PaintCommand{ ...command, clip_height: -1 }) == none
	assert rounded_background_local_clip(&layout.PaintCommand{ ...command, clip_x: math.nan() }) == none
	assert rounded_background_local_clip(&layout.PaintCommand{ ...command, clip_list: unsafe { nil } }) == none
	assert rounded_background_local_clip(&layout.PaintCommand{
		...command
		recording_clip: layout.LayoutRect{0, 0, 100, 100}
	}) == none
}
