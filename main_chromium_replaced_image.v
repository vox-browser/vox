module main

import math
import painting

struct ReplacedImageReplay {
	destination painting.IntRect
	source      [4]f32
}

// Blink's ImagePainter trims object-fit overflow before recording the image.
// Map the snapped crop relative to the full destination, as gfx::MapRect does.
// Mapping document-space edges and subtracting afterwards loses source texels
// at large scroll offsets. Ancestor overflow clips do not participate here.
fn replaced_image_replay_rects(destination painting.IntRect, content painting.IntRect,
	width int, height int, chromium bool) ?ReplacedImageReplay {
	if destination.width <= 0 || destination.height <= 0 || width <= 0 || height <= 0 {
		return none
	}
	if !chromium {
		return ReplacedImageReplay{destination, [f32(0), 0, f32(width), f32(height)]!}
	}
	left := math.max(destination.x, content.x)
	top := math.max(destination.y, content.y)
	right := math.min(destination.right(), content.right())
	bottom := math.min(destination.bottom(), content.bottom())
	if right <= left || bottom <= top { return none }
	if left == destination.x && top == destination.y
		&& right == destination.right() && bottom == destination.bottom() {
		return ReplacedImageReplay{destination, [f32(0), 0, f32(width), f32(height)]!}
	}
	sx := f32(width) / f32(destination.width)
	sy := f32(height) / f32(destination.height)
	return ReplacedImageReplay{
		destination: painting.IntRect{left, top, right - left, bottom - top}
		source:      [f32(left - destination.x) * sx, f32(top - destination.y) * sy,
			f32(right - left) * sx, f32(bottom - top) * sy]!
	}
}
