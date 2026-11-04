module painting

fn test_fractional_svg_clip_is_not_empty_when_integer_bounds_collapse() {
	clip := ClipVisualData{layout_rect_override: Rect{0, 0, 0.25, 0.25}}
	assert clip.contains_layout_point(Point{0.125, 0.125})
	assert !clip.contains_layout_point(Point{0.3, 0.125})
	mut tree := new_accumulated_visual_context_tree()
	index := tree.append(clip, 0)
	assert !tree.has_empty_effective_clip(index)
}

fn test_device_clip_hit_testing_keeps_fractional_layout_edges() {
	clip := ClipVisualData{rect: IntRect{21, 41, 201, 61}, device_pixel_scale: 2}
	assert clip.layout_rect() == Rect{10.5, 20.5, 100.5, 30.5}
	assert !clip.contains_layout_point(Point{10.25, 30})
	assert !clip.contains_layout_point(Point{20, 20.25})
	assert clip.contains_layout_point(Point{10.5, 20.5})
	assert clip.contains_layout_point(Point{110.75, 50.75})
	assert !clip.contains_layout_point(Point{111, 30})
	assert !clip.contains_layout_point(Point{20, 51})
	assert !clip.contains(IntPoint{10, 30})
	assert clip.contains(IntPoint{11, 30})
	rounded := ClipVisualData{...clip, corner_radii: CornerRadii{
		top_left: CornerRadius{10, 10}, bottom_right: CornerRadius{10, 10}
	}}
	assert !rounded.contains_layout_point(Point{10.75, 20.75})
	assert rounded.contains_layout_point(Point{15.5, 20.5})
	mut tree := new_accumulated_visual_context_tree()
	index := tree.append(clip, 0)
	assert tree.transform_point_for_hit_test_through_node(index, Point{10.25, 30}, ScrollStateSnapshot{}) == none
	assert tree.transform_point_for_hit_test_through_node(index, Point{10.75, 30}, ScrollStateSnapshot{}) != none
}
