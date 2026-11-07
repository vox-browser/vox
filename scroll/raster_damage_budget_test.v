module main

import layout

fn budget_previous(keys []ScrollRasterCommandKey) ScrollRasterKeyFrame {
	return ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200, keys: keys}
}

fn test_damage_budget_counts_overlapping_old_and_new_ink_once() {
	ink := layout.LayoutRect{20, 40, 140, 90}
	previous := budget_previous([ScrollRasterCommandKey{hash: 1, kind: 'fill_rect', has_ink: true, ink: ink}])
	current := [ScrollRasterCommandKey{hash: 2, kind: 'fill_rect', has_ink: true, ink: ink}]
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, current, 7, 0, 200, 200, mut stats) or {
		panic('overlapping old/new ink is below half the viewport')
	}
	assert stats.changed == 2
	assert rects == [layout.LayoutRect{17, 37, 146, 96}]
}

fn test_many_changed_commands_repaint_one_bounded_region() {
	mut old := []ScrollRasterCommandKey{}
	mut current := []ScrollRasterCommandKey{}
	for i in 0 .. 320 {
		ink := layout.LayoutRect{20 + f64(i % 5), 40 + f64(i % 3), 30, 20}
		old << ScrollRasterCommandKey{hash: u64(i + 1), kind: 'fill_rect', has_ink: true, ink: ink}
		current << ScrollRasterCommandKey{hash: u64(i + 1000), kind: 'fill_rect', has_ink: true, ink: ink}
	}
	previous := budget_previous(old)
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, current, 7, 0, 200, 200, mut stats) or {
		panic('640 changed commands still cover one small region')
	}
	assert stats.changed == 640
	assert rects == [layout.LayoutRect{17, 37, 40, 28}]
}

fn test_damage_rect_limit_matches_native_capacity_after_coalescing() {
	for count in [48, 49] {
		mut old := []ScrollRasterCommandKey{}
		mut current := []ScrollRasterCommandKey{}
		for i in 0 .. count {
			ink := layout.LayoutRect{10 + f64(i % 7) * 25, 10 + f64(i / 7) * 25, 2, 2}
			old << ScrollRasterCommandKey{hash: u64(i + 1), kind: 'fill_rect', has_ink: true, ink: ink}
			current << ScrollRasterCommandKey{hash: u64(i + 1000), kind: 'fill_rect', has_ink: true, ink: ink}
		}
		previous := budget_previous(old)
		mut stats := ScrollRasterDiffStats{}
		result := scroll_raster_content_damage(&previous, current, 7, 0, 200, 200, mut stats)
		if count == 48 {
			rects := result or { panic('48 rectangles must fit') }
			assert rects.len == 48
		} else {
			assert result == none
			assert stats.fallback == 'too-many-damage-rects'
		}
	}
}

fn test_coalesced_damage_still_refuses_large_unbounded_and_reordered_changes() {
	ink := layout.LayoutRect{0, 0, 200, 120}
	previous := budget_previous([ScrollRasterCommandKey{hash: 1, kind: 'fill_rect', has_ink: true, ink: ink}])
	mut stats := ScrollRasterDiffStats{}
	assert scroll_raster_content_damage(&previous,
		[ScrollRasterCommandKey{hash: 2, kind: 'fill_rect', has_ink: true, ink: ink}],
		7, 0, 200, 200, mut stats) == none
	assert stats.fallback == 'damage-too-large'
	mut unbounded := ScrollRasterDiffStats{}
	assert scroll_raster_content_damage(&previous,
		[ScrollRasterCommandKey{hash: 2, kind: 'draw_text'}], 7, 0, 200, 200, mut unbounded) == none
	assert unbounded.fallback == 'unbounded-new-draw_text'
	a := ScrollRasterCommandKey{hash: 1, kind: 'fill_rect', has_ink: true, ink: layout.LayoutRect{20, 40, 10, 10}}
	b := ScrollRasterCommandKey{...a, hash: 2}
	ordered := budget_previous([a, b])
	mut order := ScrollRasterDiffStats{}
	assert scroll_raster_content_damage(&ordered, [b, a], 7, 0, 200, 200, mut order) == none
	assert order.fallback == 'paint-order-changed'
}

fn test_bounding_damage_joins_convert_newly_intersected_video_restores() {
	inks := [layout.LayoutRect{20, 20, 80, 5}, layout.LayoutRect{20, 20, 5, 80},
		layout.LayoutRect{60, 60, 10, 10}, layout.LayoutRect{130, 130, 10, 10}]
	mut old := []ScrollRasterCommandKey{}
	mut current := []ScrollRasterCommandKey{}
	for i, ink in inks {
		kind := if i < 2 { 'fill_rect' } else { 'draw_video' }
		old << ScrollRasterCommandKey{hash: u64(i + 1), kind: kind, has_ink: true, ink: ink}
		current << ScrollRasterCommandKey{hash: u64(i + 100), kind: kind, has_ink: true,
			ink: ink, video_backdrop: i >= 2}
	}
	previous := budget_previous(old)
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, current, 7, 0, 200, 200, mut stats) or {
		panic('bounded L-shaped damage must reconcile')
	}
	assert rects == [layout.LayoutRect{17, 17, 86, 86}]
	// The first restore lies in the bounding join's extra area, while the
	// second video's saved backdrop remains independent of ordinary damage.
	assert stats.restores.len == 1
	assert stats.restores[0].index == 3
}

// A full repaint is the oracle. The retained frame shifts with the viewport,
// then only the exposed strip and planned rectangles are cleared and repainted
// in paint order. This includes erased content, moving overlap and new content.
fn budget_raster(commands []layout.PaintCommand, mut pixels []u32, region []layout.LayoutRect) {
	for y in 0 .. 200 {
		for x in 0 .. 200 {
			if !region.any(f64(x) >= it.x && f64(x) < it.x + it.width
				&& f64(y) >= it.y && f64(y) < it.y + it.height) { continue }
			mut color := u32(0xffffffff)
			for command in commands {
				left := command.x + command.transform[4]
				top := command.y + command.transform[5]
				if f64(x) >= left && f64(x) < left + command.width
					&& f64(y) >= top && f64(y) < top + command.height {
					color = if command.color == 'red' { u32(0xffff0000) } else { u32(0xff0000ff) }
				}
			}
			pixels[y * 200 + x] = color
		}
	}
}

fn test_coalesced_scroll_replay_equals_complete_repaint() {
	for delta in [-11, 0, 13] {
		mut before := []layout.PaintCommand{}
		mut after := []layout.PaintCommand{}
		for i in 0 .. 180 {
			command := layout.PaintCommand{kind: 'fill_rect', x: 20 + f64(i % 5),
				y: 40 + f64(i % 7), width: 70, height: 30, color: 'red',
				transform: [f64(1), 0, 0, 1, 0, 0]!}
			before << command
			if i % 3 != 0 {
				after << layout.PaintCommand{...command, x: command.x + 10, color: 'blue',
					transform: [f64(1), 0, 0, 1, 0, -f64(delta)]!}
			}
		}
		after << layout.PaintCommand{kind: 'fill_rect', x: 140, y: 160, width: 12, height: 12,
			color: 'blue', transform: [f64(1), 0, 0, 1, 0, -f64(delta)]!}
		previous := budget_previous(scroll_raster_frame_keys(before, 0, 1, 200, 200))
		keys := scroll_raster_frame_keys(after, delta, 1, 200, 200)
		mut stats := ScrollRasterDiffStats{}
		rects := scroll_raster_content_damage(&previous, keys, 7, delta, 200, 200, mut stats) or {
			panic('bounded paint changes must reconcile')
		}
		full := [layout.LayoutRect{0, 0, 200, 200}]
		mut old_pixels := []u32{len: 40000}
		budget_raster(before, mut old_pixels, full)
		mut actual := []u32{len: 40000, init: u32(0xffffffff)}
		for y in 0 .. 200 {
			if y + delta < 0 || y + delta >= 200 { continue }
			for x in 0 .. 200 { actual[y * 200 + x] = old_pixels[(y + delta) * 200 + x] }
		}
		mut damage := scroll_raster_strip_region(delta, 200, 200)
		damage << rects
		budget_raster(after, mut actual, damage)
		mut expected := []u32{len: 40000}
		budget_raster(after, mut expected, full)
		assert actual == expected
	}
}
