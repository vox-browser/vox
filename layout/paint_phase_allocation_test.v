module layout

import css
import html
import painting
import platform

fn test_phase_recorder_reuses_one_entry_buffer_and_retains_exact_buckets() {
	mut recorder := new_paint_phase_command_recorder(100)
	mut commands := []PaintCommand{}
	for entry_index in 0 .. 100 {
		commands << PaintCommand{kind: 'background', text: '${entry_index}', paint_box_index: entry_index}
		commands << PaintCommand{kind: 'guide', line_box_debug: true,
			points: [f64(entry_index), 2, 3, 4], paint_box_index: entry_index, paint_phase: .foreground}
		commands << PaintCommand{kind: 'text', text: '${entry_index}', paint_box_index: entry_index,
			paint_phase: .foreground}
		recorder.publish_commands(mut commands)
		assert commands.len == 0
	}
	assert recorder.command_count == 300
	assert commands.cap < recorder.command_count
	assert recorder.touched_buckets.len == 0
	assert recorder.bucket_counts.all(it == 0)
	for entry_index in 0 .. 100 {
		background := recorder.phase_commands[entry_index * compatibility_paint_phase_count]
		foreground := recorder.phase_commands[entry_index * compatibility_paint_phase_count + int(CompatibilityPaintPhase.foreground)]
		assert background.cap == background.len
		assert background[0].text == '${entry_index}'
		assert foreground.cap == foreground.len
		assert foreground.map(it.kind) == ['guide', 'text']
		assert foreground[0].line_box_debug
		assert foreground[0].points == [f64(entry_index), 2, 3, 4]
		assert foreground[1].text == '${entry_index}'
	}
}

fn test_entry_phase_recording_matches_flat_command_order_and_payloads() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{border:2px solid blue;outline:1px solid red;background:#ccc}span{color:green}</style><div><span>first line</span><br>second line</div><div style="background:yellow">last</div>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	entries, _ := result.paint_tree.compatibility_paint_plan()
	flat := result.paint_tree.flat_paint_commands(entries)
	phase_commands, command_count := result.paint_tree.build_paint_phase_command_cache(entries)
	assert command_count == flat.len
	assert flat.any(it.line_box_debug)
	for bucket_index, bucket in phase_commands {
		assert bucket.cap == bucket.len
		expected := flat.filter(it.paint_box_index * compatibility_paint_phase_count + int(it.paint_phase) == bucket_index)
		assert bucket.len == expected.len
		for index, command in bucket {
			source := expected[index]
			assert command.kind == source.kind
			assert command.text == source.text
			assert command.color == source.color
			assert command.line_box_debug == source.line_box_debug
			assert command.points == source.points
			assert command.x == source.x
			assert command.y == source.y
			assert command.width == source.width
			assert command.height == source.height
			assert command.transform == source.transform
		}
	}
}

fn test_phase_refresh_keeps_valid_storage_and_earlier_replayed_commands() {
	mut root := BlockBox{
		visible: true
		width: 100
		height: 100
		background_color: css.Color{r: 255, a: 255}
		children: [BlockBox{visible: true, width: 20, height: 20,
			background_color: css.Color{g: 255, a: 255}}]
	}
	entries, steps := root.compatibility_paint_plan()
	mut buckets, count := root.build_paint_phase_command_cache(entries)
	initial := replay_cached_paint_commands(steps, buckets, count, false)
	assert initial.map(it.color) == ['rgb(255 0 0)', 'rgb(0 255 0)']
	valid_storage := buckets[0].data
	mut valid := []bool{len: entries.len, init: true}
	valid[1] = false
	for phase in 0 .. compatibility_paint_phase_count {
		buckets[compatibility_paint_phase_count + phase].clear()
	}
	root.children[0].background_color = css.Color{b: 255, a: 255}
	added := root.refresh_paint_phase_command_cache(entries, mut buckets, mut valid)
	assert added == 1
	assert valid.all(it)
	assert buckets[0].data == valid_storage
	assert buckets[compatibility_paint_phase_count].cap == 1
	updated := replay_cached_paint_commands(steps, buckets, count, false)
	assert updated.map(it.color) == ['rgb(255 0 0)', 'rgb(0 0 255)']
	assert initial.map(it.color) == ['rgb(255 0 0)', 'rgb(0 255 0)']
	assert root.refresh_paint_phase_command_cache(entries, mut buckets, mut valid) == 0
}

fn test_recording_atomic_only_lines_borrows_headers_without_empty_outline_storage() {
	box := BlockBox{ visible: true, skip_background_paint: true,
		lines: []TextLine{len: 512, init: TextLine{ width: 1, height: 1 }} }
	entries := [PaintOrderEntry{ box: &box, opacity: 1 }]
	mut recorder := PaintPhaseCommandRecorder{ include_line_box_debug: false }
	mut arena := platform.new_arena('borrowed recording lines')
	entry := arena.enter()
	commands := box.record_paint_commands_for_entries(entries, []bool{}, mut recorder)
	arena.leave(entry)
	used := arena.usage().used
	assert commands.len == 0
	$if prealloc {
		// Atomic-only lines publish no commands. Copying each wide TextLine or
		// reserving an empty outline vector for every line exceeds this bound.
		assert used < 4096, '${used} bytes for 512 atomic-only lines'
	}
	arena.release()
}

fn test_sparse_inline_outlines_preserve_border_text_order_and_previous_commands() {
	mut box := BlockBox{ visible: true, width: 100, height: 60 }
	for index in 0 .. 3 {
		box.lines << TextLine{
			fragments: [TextFragment{
				text:             ['first', 'middle', 'last'][index]
				x:                0
				y:                f64(index * 20)
				width:            40
				height:           16
				color:            css.Color{ a: 255 }
				inline_node_id:   index + 1
				background_color: css.Color{ r: u8(50 + index), a: 255 }
				outline_width:    if index == 1 { 1.0 } else { 0.0 }
				outline_color:    css.Color{ b: 255, a: 255 }
				outline_style:    painting.LineStyle.solid
			}]
		}
	}
	entries := [PaintOrderEntry{ box: &box, opacity: 1 }]
	mut recorder := PaintPhaseCommandRecorder{ include_line_box_debug: false }
	commands := box.record_paint_commands_for_entries(entries, []bool{}, mut recorder)
	mut backgrounds := []int{}
	mut texts := []int{}
	mut outlines := []int{}
	for index, command in commands {
		if command.kind == 'draw_text' { texts << index }
		if command.color == 'rgb(0 0 255)' { outlines << index }
		if command.kind == 'fill_rect' && command.color.starts_with('rgb(5') {
			backgrounds << index
		}
	}
	assert backgrounds.len == 3
	assert texts.len == 3
	assert outlines.len > 0
	assert backgrounds.last() < texts[0]
	assert texts[0] < outlines[0]
	assert outlines.last() < texts[1]
	assert texts[1] < texts[2]
	assert commands[texts[0]].text == 'first'
	assert commands[texts[1]].text == 'middle'
	assert commands[texts[2]].text == 'last'
	box.lines[1].fragments = [TextFragment{ ...box.lines[1].fragments[0], text: 'changed', outline_width: 0 }]
	updated := box.record_paint_commands_for_entries(entries, []bool{}, mut recorder)
	assert updated.any(it.text == 'changed')
	assert commands[texts[1]].text == 'middle'
	assert commands[outlines[0]].color == 'rgb(0 0 255)'
}
