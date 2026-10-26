module layout

// BoxPainterBase::ClipToBorderEdge() insets the cutout of an opaque box by
// one CSS pixel. The background subsequently covers that overlap, avoiding a
// second antialiased edge along rounded corners.
fn chromium_inset_opaque_shadow_clips(mut commands []PaintCommand, start int,
	layout_handle voidptr) {
	inset := if layout_handle == unsafe { nil } {
		1.0
	} else {
		unsafe { &Node(layout_handle) }.document().layout_coordinate_scale()
	}
	for index := start; index < commands.len; index++ {
		if commands[index].kind != 'paint_outer_box_shadow' {
			continue
		}
		geometry := commands[index].box_shadow()
		r := geometry.content_rect
		radii := geometry.content_radii
		clip := LayoutRect{r.x + inset, r.y + inset, non_negative(r.width - 2 * inset),
			non_negative(r.height - 2 * inset)}
		inset_radii := effective_box_radii(BoxRadii{
			top_left:     shrink_corner_radius(radii.top_left, inset, inset)
			top_right:    shrink_corner_radius(radii.top_right, inset, inset)
			bottom_right: shrink_corner_radius(radii.bottom_right, inset, inset)
			bottom_left:  shrink_corner_radius(radii.bottom_left, inset, inset)
		}, 0, clip.width, clip.height)
		commands[index].box_shadow_data = &PaintBoxShadowData{
			...geometry
			content_rect:  clip
			content_radii: inset_radii
			clip_radii:    inset_radii
		}
	}
}
