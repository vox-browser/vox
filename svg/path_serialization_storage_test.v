module svg

import platform

fn test_serialized_path_keeps_only_owned_output_after_numeric_formatting() {
	path := parse_path_data('M0 0 ' + 'c1.25 2.5 -3.75 4.125 5.5 6.25 '.repeat(2048))
	before := platform.thread_arena_usage().used
	serialized := path.serialize()
	after := platform.thread_arena_usage().used
	assert serialized.starts_with('M 0 0 c 1.25 2.5 -3.75 4.125 5.5 6.25')
	assert serialized.ends_with('c 1.25 2.5 -3.75 4.125 5.5 6.25')
	$if prealloc { assert after - before < serialized.len + 1024 }
	mut reuse := platform.begin_thread_scratch('reuse retired serialization')
	_ = []u8{len: serialized.len * 4, init: 0xa5}
	reuse.finish()
	assert parse_path_data(serialized).instructions.len == path.instructions.len
	assert unsafe { serialized.str[serialized.len] } == 0
}
