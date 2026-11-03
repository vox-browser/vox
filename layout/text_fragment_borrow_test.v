module layout

import css
import platform

fn test_text_recording_borrows_fragments_without_retaining_wide_heap_copies() {
	count := 512
	fragments := []TextFragment{len: count, init: TextFragment{
		text:      'Retained text'
		x:         f64(index)
		y:         12
		width:     50
		height:    16
		color:     css.Color{ r: 23, g: 45, b: 67, a: 255 }
		font_size: 14
	}}
	mut commands := []PaintCommand{cap: count}
	mut arena := platform.new_arena('text recording fragment regression')
	entry := arena.enter()
	append_unselected_text_fragment_commands(mut commands, fragments, 0.75, false)
	arena.leave(entry)
	defer { arena.release() }
	assert commands.len == count
	for index, command in commands {
		assert command.kind == 'draw_text'
		assert command.text == 'Retained text'
		assert command.x == f64(index)
		assert command.y == 12 && command.width == 50 && command.height == 16
		assert command.color == 'rgb(23 45 67)'
		assert command.opacity == 0.75
		assert command.font_size == 14
		assert fragments[index].text == command.text
	}
	$if prealloc {
		used := arena.usage().used
		copy_bytes := i64(count * int(sizeof(TextFragment)))
		println('Text recording: ${used} payload bytes; ${copy_bytes} bytes for wide fragment copies')
		assert used < copy_bytes / 4, '${used} bytes for ${count} borrowed text fragments'
	}
}

fn test_borrowed_text_run_recording_preserves_joined_whitespace_and_rtl_geometry() {
	for rtl in [false, true] {
		fragments := [TextFragment{
			text:             'first'
			separator_after:  '  '
			x:                20
			y:                10
			width:            10
			height:           16
			text_run_id:      1
			shape_as_run:     true
			preserves_spaces: true
			rtl:              rtl
		}, TextFragment{
			text:                  'second'
			separator_after:       ' '
			separator_width_after: 3
			x:                     35
			y:                     10
			width:                 15
			height:                16
			text_run_id:           1
			shape_as_run:          true
			preserves_spaces:      true
			rtl:                   rtl
		}]
		commands := unselected_text_fragment_commands(fragments, 1)
		assert commands.len == 1
		assert commands[0].text == 'first  second '
		assert commands[0].x == if rtl { 17 } else { 20 }
		assert commands[0].width == 33
		assert commands[0].rtl == rtl
	}
}
