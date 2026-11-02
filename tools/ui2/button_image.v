module ui2

import math

// Explicit button icons keep the same logical size on native and custom
// backends, independently of the source bitmap's resolution or button height.
pub fn embedded_button_image_frame(el Element) Rect {
	size := math.max(0.0, math.min(el.button_image_size,
		math.min(el.frame.width - 10, el.frame.height - 4)))
	return rect(if el.text == '' { (el.frame.width - size) / 2 } else { 5.0 },
		(el.frame.height - size) / 2, size, size)
}
