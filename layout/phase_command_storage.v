module layout

import dom

// Phase buckets are private recording caches. Display lists own copies of the
// command records and continue to share only their immutable payloads.
fn take_document_phase_command_storage(document &dom.Document) [][]PaintCommand {
	mut previous := document_layout_result(document) or { return [][]PaintCommand{} }
	mut storage := unsafe { previous.paint_phase_commands }
	previous.paint_phase_commands = [][]PaintCommand{}
	previous.paint_phase_entry_valid = []bool{}
	previous.paint_phase_command_count = 0
	previous.paint_phase_cache_valid = false
	clear_phase_command_storage(mut storage)
	return storage
}

fn clear_phase_command_storage(mut storage [][]PaintCommand) {
	for mut bucket in storage {
		// Every record is overwritten before publication. Zero only the live
		// prefix to release old payload roots without constructing defaults.
		if bucket.len > 0 {
			unsafe { vmemset(bucket.data, 0, isize(bucket.len) * isize(sizeof(PaintCommand))) }
		}
		bucket.clear()
	}
}

fn new_reusing_paint_phase_command_recorder(entry_count int, storage [][]PaintCommand) PaintPhaseCommandRecorder {
	bucket_count := entry_count * compatibility_paint_phase_count
	mut buckets := unsafe { storage }
	if buckets.len > bucket_count {
		for index in bucket_count .. buckets.len { buckets[index] = []PaintCommand{} }
		buckets.trim(bucket_count)
	}
	if buckets.cap < bucket_count {
		// A small amount of spare header capacity handles inserted/removed boxes
		// without another document-sized allocation on the next relayout.
		extra := if bucket_count / 8 > compatibility_paint_phase_count * 8 {
			bucket_count / 8
		} else { compatibility_paint_phase_count * 8 }
		mut next := [][]PaintCommand{cap: bucket_count + extra}
		next << buckets
		buckets = unsafe { next }
	}
	for buckets.len < bucket_count { buckets << []PaintCommand{} }
	clear_phase_command_storage(mut buckets)
	return PaintPhaseCommandRecorder{
		phase_commands: buckets
		bucket_counts: []int{len: bucket_count}
		touched_buckets: []int{cap: compatibility_paint_phase_count}
	}
}

fn (mut recorder PaintPhaseCommandRecorder) reserve_phase_bucket(bucket int, additional int) {
	current := unsafe { recorder.phase_commands[bucket] }
	needed := current.len + additional
	capacity_limit := if needed > 32 { needed * 2 } else { 64 }
	if current.cap >= needed && current.cap <= capacity_limit { return }
	mut next := []PaintCommand{cap: needed}
	next << current
	recorder.phase_commands[bucket] = next
}

fn (box &BlockBox) build_reusing_paint_phase_command_cache(entries []PaintOrderEntry, storage [][]PaintCommand) ([][]PaintCommand, int) {
	return box.build_selected_paint_phase_command_cache(entries, storage, []bool{})
}

fn (box &BlockBox) build_selected_paint_phase_command_cache(entries []PaintOrderEntry, storage [][]PaintCommand, selected []bool) ([][]PaintCommand, int) {
	mut recorder := new_reusing_paint_phase_command_recorder(entries.len, storage)
	box.record_paint_commands_for_entries(entries, selected, mut recorder)
	return recorder.phase_commands, recorder.command_count
}
