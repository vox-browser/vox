module main

import layout
import math

fn test_recorded_filter_clip_keeps_author_bounds_beyond_the_window() {
	command := layout.PaintCommand{
		has_clip:    true
		clip_x:      33
		clip_y:      451
		clip_width:  958
		clip_height: 341
		clip_list:   &layout.PaintClipList{
			items: [
				layout.PaintClip{ rect: layout.LayoutRect{33, 451.078125, 958, 3067} },
				layout.PaintClip{ rect: layout.LayoutRect{33, 451.078125, 958, 389.515625} },
			]
		}
	}
	clip := chromium_recorded_filter_clip(&command) or { panic('missing author clip') }
	assert clip == [f32(33), 451.078125, 991, 840.59375]!
	// The compatibility rectangle is a visible-window bound, not the retained
	// clip's raster extent. A shorter window must not move the blur grid.
	shorter := layout.PaintCommand{ ...command, clip_height: 100 }
	assert (chromium_recorded_filter_clip(&shorter) or { panic('missing clip') }) == clip
}

fn test_recorded_filter_clip_intersects_axis_aligned_ancestor_transforms() {
	command := layout.PaintCommand{
		clip_list: &layout.PaintClipList{
			items: [
				layout.PaintClip{
					rect:      layout.LayoutRect{0, 0, 100, 200}
					transform: [f64(2), 0, 0, 2, 20, 30]!
				},
				layout.PaintClip{
					rect:      layout.LayoutRect{0, 0, 80, 200}
					transform: [f64(-1), 0, 0, 1, 150, 100]!
				},
			]
		}
	}
	assert (chromium_recorded_filter_clip(&command) or { panic('missing clip') }) == [
		f32(70),
		100,
		150,
		300,
	]!
	plain := layout.PaintCommand{
		has_clip:    true
		clip_x:      2
		clip_y:      3
		clip_width:  5
		clip_height: 7
	}
	assert (chromium_recorded_filter_clip(&plain) or { panic('missing clip') }) == [
		f32(2),
		3,
		7,
		10,
	]!
}

fn test_recorded_filter_clip_declines_unknown_or_nonfinite_clips() {
	for clip in [layout.PaintClip{ is_path: true }, layout.PaintClip{ is_svg_mask: true },
		layout.PaintClip{ is_svg_content_mask: true },
		layout.PaintClip{ transform: [f64(1), .1, 0, 1, 0, 0]! },
		layout.PaintClip{ rect: layout.LayoutRect{0, 0, -1, 2} },
		layout.PaintClip{ rect: layout.LayoutRect{0, 0, math.inf(1), 2} },
		layout.PaintClip{ transform: [f64(1), 0, 0, 1, math.nan(), 0]! }] {
		command := layout.PaintCommand{ clip_list: &layout.PaintClipList{ items: [clip] } }
		if _ := chromium_recorded_filter_clip(&command) {
			assert false
		}
	}
	for command in [layout.PaintCommand{}, layout.PaintCommand{
		has_clip:   true
		clip_width: -1
	}, layout.PaintCommand{ has_clip: true, clip_width: math.inf(1) }] {
		if _ := chromium_recorded_filter_clip(&command) {
			assert false
		}
	}
}
