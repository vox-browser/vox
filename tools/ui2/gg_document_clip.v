module canvas

// Document tiles share multisampling with clips that need the path renderer.
pub fn document_image_clip_requires_msaa(rect Rect, radii [4]Point) bool {
	return can_apply_analytic_clip(rrect_shape(RRect.rect_radii(rect, radii)),
		Transform.new(Matrix.identity())).is_empty()
}
