module layout

// BoxPainterBase::ClipToBorderEdge() insets the cutout of an opaque box by
// one CSS pixel. The background subsequently covers that overlap, avoiding a
// second antialiased edge along rounded corners.
fn chromium_inset_opaque_shadow_clips(mut commands []PaintCommand, start int) {
	for index := start; index < commands.len; index++ {
		if commands[index].kind != 'paint_outer_box_shadow' { continue
		 }
		geometry := commands[index].box_shadow()
		r := geometry.content_rect
		radii := geometry.content_radii
		clip := LayoutRect{r.x + 1, r.y + 1, non_negative(r.width - 2), non_negative(r.height - 2)}
		inset_radii := effective_box_radii(BoxRadii{
			top_left:     shrink_corner_radius(radii.top_left, 1, 1)
			top_right:    shrink_corner_radius(radii.top_right, 1, 1)
			bottom_right: shrink_corner_radius(radii.bottom_right, 1, 1)
			bottom_left:  shrink_corner_radius(radii.bottom_left, 1, 1)
		}, 0, clip.width, clip.height)
		commands[index].box_shadow_data = &PaintBoxShadowData{
			...geometry
			content_rect:  clip
			content_radii: inset_radii
			clip_radii:    inset_radii
		}
	}
}
