module svg

import platform

fn test_viewbox_fixed_coordinates_preserve_number_sequence_syntax() {
	for source in ['0 1 640 480', ' 0,1,640,480 ', '0, 1 640,480,', '+0 1e0 .64e3 480.'] {
		value := parse_viewbox(source) or { panic('valid viewBox rejected: ${source}') }
		assert value == ViewBox{min_y:1,width:640,height:480}
	}
	for source in ['', '0 1 640', '0 1 640 480 1', '0 1 640 480,1', '0 1 640 480junk', '0,,1 640 480', '0 1 640 480,,'] {
		assert parse_viewbox(source) == none
	}
}

fn test_repeated_viewbox_reads_do_not_allocate_coordinate_vectors() {
	mut arena := platform.new_arena('viewbox allocation test')
	before := platform.thread_arena_usage().used
	mut total := 0.0
	for _ in 0 .. 1024 {
		value := parse_viewbox('0 1 640 480') or { panic('invalid viewBox') }
		total += value.width
	}
	assert total == 655360
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
	arena.release()
}
