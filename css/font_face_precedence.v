module css

import platform

// CSS Fonts' composite face searches matching @font-face rules in reverse
// definition order. Keep FontFaceSet iteration in source order; only reverse
// the rendering cascade, including pending faces and overlapping subsets.
// The LibWeb policy retains its upstream cascade order.
fn font_faces_in_rendering_order(faces []&FontFaceObject, policy platform.FontRenderingPolicy) []&FontFaceObject {
	return if policy == .chromium { faces.reverse() } else { faces.clone() }
}
