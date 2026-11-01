module browserui

import ui2

fn test_tabs_share_controls_actions_and_accessibility() {
	strip := tab_strip(800, [Tab{ index: 2, title: 'Saved', x: 62, width: 184, selected: true, icon: '/icon.png' }], 258)
	assert strip.id == 'tab-strip'
	assert strip.children[0].id == 'window-close'
	tab := strip.children[3]
	assert tab.clickable && tab.draggable
	assert tab.action_id == 'tabdrag-2'
	assert tab.accessibility_value == 'selected'
	assert tab.children[0].image_path == '/icon.png'
	assert tab.children[2].id == 'tab-close:2'
	assert strip.children.last().id == 'tab-new'
}

fn test_shortcuts_share_platform_policy_and_preserve_editing_commands() {
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true }, true, true) == 'bookmark-add'
	assert shortcut(ui2.KeyEvent{ code: .d, ctrl: true }, true, false) == 'bookmark-add'
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true, shift: true }, false, true) == 'debug-toggle'
	assert shortcut(ui2.KeyEvent{ code: .tab, ctrl: true, shift: true }, false, true) == 'tab-previous'
	assert shortcut(ui2.KeyEvent{ code: ._8, cmd: true }, false, true) == 'tab-select:7'
	assert shortcut(ui2.KeyEvent{ code: .escape }, true, true) == 'address-cancel'
	assert shortcut(ui2.KeyEvent{ code: .left, cmd: true }, true, true) == ''
	assert shortcut(ui2.KeyEvent{ code: .kp_add, cmd: true }, true, true) == 'zoom-in'
	assert shortcut(ui2.KeyEvent{ code: .kp_subtract, cmd: true }, true, true) == 'zoom-out'
	assert shortcut(ui2.KeyEvent{ code: .kp_0, cmd: true }, true, true) == 'zoom-reset'
	assert shortcut(ui2.KeyEvent{ code: .c, cmd: true }, true, true) == ''
	assert shortcut(ui2.KeyEvent{ code: .comma, ctrl: true }, false, false) == 'settings-open'
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true, alt: true }, false, true) == ''
}

fn vector_area(points []ui2.VectorPoint) f64 {
	mut area := 0.0
	for i, p in points {
		q := points[(i + 1) % points.len]
		area += p.x * q.y - q.x * p.y
	}
	return if area < 0 { -area / 2 } else { area / 2 }
}

fn test_vector_tessellation_keeps_concave_cutouts_in_both_windings() {
	points := [ui2.VectorPoint{ x: 0, y: 0 }, ui2.VectorPoint{ x: 10, y: 0 },
		ui2.VectorPoint{ x: 10, y: 4 }, ui2.VectorPoint{ x: 4, y: 4 }, ui2.VectorPoint{ x: 4, y: 10 },
		ui2.VectorPoint{ x: 0, y: 10 }]
	for contour in [points, points.reverse(), classic_tab_outline(194), classic_tab_outline(82)] {
		path := ui2.VectorPath{ points: contour }
		triangles := path.triangles()
		assert triangles.len == (contour.len - 2) * 3
		mut filled := 0.0
		for i := 0; i < triangles.len; i += 3 {
			filled += vector_area([contour[triangles[i]], contour[triangles[i + 1]],
				contour[triangles[i + 2]]])
		}
		delta := filled - vector_area(contour)
		assert delta > -0.00001 && delta < 0.00001
	}
	assert ui2.VectorPath{ points: points, closed: false }.triangles() == []
}

fn test_classic_tabs_overlap_with_the_active_tab_above_its_neighbors() {
	strip := tab_strip(800, [
		Tab{ index: 0, title: 'First', x: 62, width: 184, selected: true },
		Tab{ index: 1, title: 'Second', x: 246, width: 184 },
	], 442)
	assert strip.children[3].id == 'tab-1'
	active := strip.children[4]
	assert active.id == 'tab-0' && active.frame.width == 194
	assert active.box.transparent && active.box.radius == 0
	assert active.vector.stroke_width == 1 && active.vector.stroke == 0xadadad
	assert active.vector.points[0].x == 0.5 && active.vector.points[0].y == 23.5
	assert active.children.last().id == 'tab-seam-0'
	assert strip.children.last().frame.height == 14 && strip.children.last().text == ''
	assert strip.children.last().vector.points.len == 4
}
