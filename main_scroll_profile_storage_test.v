module main

import platform

fn test_replay_allocation_totals_survive_command_scratch_reuse() {
	mut profile := BrowserScrollProfile{}
	for frame in 0 .. 80 {
		mut scratch := platform.begin_thread_scratch('replay allocation diagnostic')
		for index in 0 .. 24 {
			profile.record_replay_allocation('draw_${index}', i64(index + 1))
		}
		scratch.finish()
		// Overwrite the arena that held the command names. Totals and the map
		// entries must remain readable both here and in the following frame.
		mut overwrite := platform.begin_thread_scratch('replay diagnostic overwrite')
		mut bytes := []u8{len: 64 * 1024, init: u8(frame)}
		assert bytes[123] == u8(frame)
		overwrite.finish()
		assert profile.replay_kind_bytes.len == 24
		for index in 0 .. 24 {
			assert profile.replay_kind_bytes['draw_${index}'] == i64((frame + 1) * (index + 1))
		}
	}
}
