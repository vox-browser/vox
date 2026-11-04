module browserui

import math
import ui2

fn test_address_info_icon_is_one_filled_ring_with_stem_and_dot_inside_its_frame() {
	frame := ui2.rect(78, 35, 18, 20)
	icon := address_info_icon('address-info', frame, 0x888888)
	assert icon.id == 'address-info' && icon.frame == frame && icon.text == ''
	assert icon.accessibility_label == 'Page information'
	path := icon.vector
	assert path.closed && path.fill_enabled && path.fill == 0x888888 && path.stroke_width == 0
	for point in path.points {
		assert point.x >= 0 && point.x <= frame.width && point.y >= 0 && point.y <= frame.height
	}
	// Shoelace area of the single contour: bridges cancel, the inner ring is a
	// hole, and the stem and dot add the same winding as the outer ring.
	mut doubled := 0.0
	for index, point in path.points {
		next := path.points[(index + 1) % path.points.len]
		doubled += point.x * next.y - next.x * point.y
	}
	polygon := 24.0 * math.sin(2 * math.pi / 48) // 48-gon area per unit radius squared
	expected := polygon * (6.15 * 6.15 - 5.15 * 5.15) + 1.3 * 5.13 + 1.3 * 1.25
	assert math.abs(math.abs(doubled / 2) - expected) < 0.01
}

fn test_address_info_mark_uses_the_vector_only_for_native_appkit() {
	mark := address_info_mark('address-info', ui2.rect(78, 35, 18, 20), 0x888888)
	$if macos && !ui2_custom_rendering ? {
		assert mark.text == '' && mark.vector.points.len > 0
	} $else {
		assert mark.text == 'ⓘ' && mark.vector.points.len == 0
	}
}
