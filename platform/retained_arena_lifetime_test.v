module platform

struct SharedArenaPayload {
	value int
}

struct SharedArenaCleanupProbe {
mut:
	calls int
}

fn shared_arena_payload(mut storage RetainedArena, value int) &SharedArenaPayload {
	mut scope := storage.enter()
	payload := &SharedArenaPayload{value: value}
	scope.finish()
	return payload
}

fn shared_arena_probe(mut storage RetainedArena, probe &SharedArenaCleanupProbe) {
	storage.add_cleanup(fn [probe] () {
		mut observation := unsafe { &SharedArenaCleanupProbe(probe) }
		observation.calls++
	})
}

fn test_shared_arenas_keep_every_payload_through_cleanup_in_either_release_order() {
	for source_first in [false, true] {
		mut source := new_retained_arena('shared source')
		mut destination := new_retained_arena('shared destination')
		source_payload := shared_arena_payload(mut source, 17)
		destination_payload := shared_arena_payload(mut destination, 29)
		probe := &SharedArenaCleanupProbe{}
		mut owners := [source, destination]
		for mut owner in owners {
			owner.add_cleanup(fn [source, destination, source_payload, destination_payload, probe] () {
				assert source_payload.value == 17 && destination_payload.value == 29
				$if prealloc {
					assert source.arena.usage().used > 0
					assert destination.arena.usage().used > 0
				}
				mut observation := unsafe { &SharedArenaCleanupProbe(probe) }
				observation.calls++
			})
		}
		destination.share_lifetime(source)
		if source_first { source.release() } else { destination.release() }
		assert probe.calls == 0
		assert source_payload.value == 17 && destination_payload.value == 29
		if source_first { destination.release() } else { source.release() }
		assert probe.calls == 2
		assert source.arena.usage().used == 0
		assert destination.arena.usage().used == 0
	}
}

fn test_reciprocal_and_repeated_sharing_add_no_unreleasable_references() {
	mut first := new_retained_arena('reciprocal first')
	mut second := new_retained_arena('reciprocal second')
	first_payload := shared_arena_payload(mut first, 41)
	second_payload := shared_arena_payload(mut second, 53)
	probe := &SharedArenaCleanupProbe{}
	shared_arena_probe(mut first, probe)
	shared_arena_probe(mut second, probe)
	first.share_lifetime(first)
	for _ in 0 .. 4 {
		first.share_lifetime(second)
		second.share_lifetime(first)
	}
	first.release()
	assert probe.calls == 0
	assert first_payload.value == 41 && second_payload.value == 53
	second.release()
	assert probe.calls == 2
	assert first.arena.usage().used == 0 && second.arena.usage().used == 0
}

fn test_transitive_sharing_waits_for_the_final_external_reader() {
	mut first := new_retained_arena('transitive first')
	mut second := new_retained_arena('transitive second')
	mut third := new_retained_arena('transitive third')
	first_payload := shared_arena_payload(mut first, 61)
	second_payload := shared_arena_payload(mut second, 67)
	third_payload := shared_arena_payload(mut third, 71)
	probe := &SharedArenaCleanupProbe{}
	shared_arena_probe(mut first, probe)
	shared_arena_probe(mut second, probe)
	shared_arena_probe(mut third, probe)
	second.share_lifetime(first)
	third.share_lifetime(second)
	first.retain() // A scene or task can outlive all three document owners.
	first.release()
	second.release()
	third.release()
	assert probe.calls == 0
	assert first_payload.value == 61 && second_payload.value == 67 && third_payload.value == 71
	first.release()
	assert probe.calls == 3
	assert first.arena.usage().used == 0
	assert second.arena.usage().used == 0
	assert third.arena.usage().used == 0
}

fn test_a_live_group_member_without_local_leases_can_be_shared_and_retained() {
	mut first := new_retained_arena('retired document member')
	mut second := new_retained_arena('live adopting document')
	mut third := new_retained_arena('new adopting document')
	payload := shared_arena_payload(mut first, 79)
	probe := &SharedArenaCleanupProbe{}
	shared_arena_probe(mut second, probe)
	shared_arena_probe(mut third, probe)
	first.share_lifetime(second)
	first.release()
	// The first document is gone, but adopted nodes still identify its arena.
	// A new adoption and reader must not depend on its local lease count.
	first.share_lifetime(third)
	shared_arena_probe(mut first, probe)
	first.retain()
	second.release()
	third.release()
	assert probe.calls == 0 && payload.value == 79
	first.release()
	assert probe.calls == 3
	assert first.arena.usage().used == 0
	assert second.arena.usage().used == 0
	assert third.arena.usage().used == 0
}

fn test_shared_lifetime_is_not_released_until_its_entered_scope_finishes() {
	$if prealloc {
		mut first := new_retained_arena('entered shared member')
		mut second := new_retained_arena('other shared member')
		probe := &SharedArenaCleanupProbe{}
		shared_arena_probe(mut first, probe)
		shared_arena_probe(mut second, probe)
		mut scope := first.enter()
		payload := &SharedArenaPayload{value: 83}
		first.share_lifetime(second)
		first.release()
		second.release()
		assert probe.calls == 0 && payload.value == 83
		scope.finish()
		assert probe.calls == 2
		assert first.arena.usage().used == 0 && second.arena.usage().used == 0
	}
}
