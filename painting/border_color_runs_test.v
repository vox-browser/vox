module painting

fn test_zero_width_edges_end_a_border_color_run_before_the_next_visible_edge() {
	opaque := Color{30, 35, 41, 255}
	clear := Color{ a: 0 }
	for orientation in 0 .. 4 {
		mut sides := [DeviceBorderData{clear, .solid, 0}, DeviceBorderData{clear, .solid, 0},
			DeviceBorderData{clear, .solid, 0}, DeviceBorderData{clear, .solid, 0}]
		sides[orientation] = DeviceBorderData{opaque, .solid, 8}
		sides[(orientation + 1) % 4] = DeviceBorderData{clear, .solid, 8}
		commands := paint_all_borders(IntRect{20, 30, 8, 8}, CornerRadii{}, DeviceBordersData{sides[0], sides[1], sides[2], sides[3]})
		assert commands.len == 2
		mut opaque_paths := 0
		mut transparent_paths := 0
		for command in commands {
			assert command is FillPath
			path := command as FillPath
			assert path.path.segments.filter(it.kind == .move_to).len == 1
			if path.color == opaque { opaque_paths++ }
			if path.color == clear { transparent_paths++ }
		}
		assert opaque_paths == 1
		assert transparent_paths == 1
	}
}

fn test_empty_same_color_border_edges_still_flush_the_last_visible_path() {
	red := Color{200, 10, 20, 255}
	commands := paint_all_borders(IntRect{0, 0, 40, 30}, CornerRadii{}, DeviceBordersData{
		top:    DeviceBorderData{red, .solid, 4}
		right:  DeviceBorderData{red, .solid, 0}
		bottom: DeviceBorderData{red, .solid, 0}
		left:   DeviceBorderData{red, .solid, 0}
	})
	assert commands.len == 1
	assert commands[0] is FillPath
	assert (commands[0] as FillPath).color == red
	assert (commands[0] as FillPath).path.segments.filter(it.kind == .move_to).len == 1
}

fn test_hidden_edges_separate_border_paths_when_their_color_run_ends() {
	red := Color{200, 10, 20, 255}
	blue := Color{10, 20, 200, 255}
	for style in [LineStyle.none, .hidden] {
		commands := paint_all_borders(IntRect{0, 0, 40, 30}, CornerRadii{}, DeviceBordersData{
			top:    DeviceBorderData{red, .solid, 4}
			right:  DeviceBorderData{blue, .solid, 4}
			bottom: DeviceBorderData{blue, style, 0}
			left:   DeviceBorderData{blue, style, 0}
		})
		assert commands.len == 2
		for command in commands {
			assert command is FillPath
			assert (command as FillPath).path.segments.filter(it.kind == .move_to).len == 1
		}
	}
}
