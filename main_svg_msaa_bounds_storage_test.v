module main

import layout
import painting
import platform

fn test_svg_msaa_bounds_match_complete_nested_replay_without_retaining_clip_copies() {
	commands := [
		layout.PaintCommand{kind:'draw_svg_path', stroke_width:3,
			svg_data:&layout.PaintSVGPathData{path_data:[f32(0),2,3,0,0,0,0,0,0,0,0,0,
				1,21,37,0,0,0,0,0,0,0,0,0], path_transform:[f64(2),0,0,3,4,5]!},
			transform:[f64(1),0.25,0,1,7,9]!,
			clip_list:&layout.PaintClipList{items:[layout.PaintClip{rect:layout.LayoutRect{x:1,y:2,width:20,height:30}}]}},
		layout.PaintCommand{kind:'fill_rect', x:1,y:3,width:5,height:7,clip_outs:[f64(1),2,3,4,5,6,7,8]},
		layout.PaintCommand{kind:'fill_rect', width:5,height:7},
	]
	origin := painting.IntPoint{11,13}
	for outer in [[f64(0),0,0,0,0,0]!, [f64(2),0.5,-0.25,3,17,19]!] {
		for command in commands {
			expected := chromium_msaa_trigger_rect(layout.paint_command_for_nested_viewport(command, outer, origin, .5))
			actual := chromium_nested_svg_msaa_trigger_rect(command, outer, origin)
			assert actual == expected
		}
	}
	mut storage := platform.new_arena('SVG MSAA bounds queries')
	entry := storage.enter()
	for _ in 0 .. 256 {
		bounds := chromium_nested_svg_msaa_trigger_rect(commands[0], [f64(1),0,0,1,0,0]!, origin) or { panic('missing bounds') }
		assert bounds.width > 0 && bounds.height > 0
	}
	storage.leave(entry)
	$if prealloc { assert storage.usage().used == 0 }
	storage.release()
	assert commands[0].clip_list.items[0].rect.x == 1
	assert commands[0].transform == [f64(1),0.25,0,1,7,9]!
}
