module ui2

import math

// A shared image child also works on backends whose native buttons own their
// image directly rather than mounting child views inside the button cell.
fn embedded_button_image_element(el Element) Element {
	if el.kind == .button && el.text == '' && el.image_path == '' && el.children.len == 1
		&& el.children[0].kind == .image {
		icon := el.children[0]
		return Element{ ...el, image_path: icon.image_path,
			button_image_size: math.min(icon.frame.width, icon.frame.height) }
	}
	return el
}

// Explicit button icons keep the same logical size on native and custom
// backends, independently of the source bitmap's resolution or button height.
pub fn embedded_button_image_frame(el Element) Rect {
	size := math.max(0.0, math.min(el.button_image_size,
		math.min(el.frame.width - if el.text == '' { 4 } else { 10 }, el.frame.height - 4)))
	return rect(if el.text == '' { (el.frame.width - size) / 2 } else { 5.0 },
		(el.frame.height - size) / 2, size, size)
}
