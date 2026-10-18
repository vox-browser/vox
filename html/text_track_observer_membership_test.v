module html

import os

@[heap]
struct ObserverMembershipProbe {
mut:
	states []TextTrackReadinessState
}

fn observer_membership_child(case_name string, expected string) {
	mut environment := os.environ()
	environment['VOX2_TRACK_OBSERVER_MEMBERSHIP_PROBE'] = case_name
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains(expected), output
	process.close()
}

fn test_text_track_observers_preserve_distinct_identity_and_detach_only_the_finalized_observer() {
	if os.getenv('VOX2_TRACK_OBSERVER_MEMBERSHIP_PROBE') != '' { return }
	mut track := TextTrack.create()
	mut first := TextTrackObserver.create(mut track)
	mut second := TextTrackObserver.create(mut track)
	assert voidptr(first) != voidptr(second)
	assert voidptr(first.text_track_) == voidptr(track) && voidptr(second.text_track_) == voidptr(track)
	assert track.observers_.len == 2
	first_probe := &ObserverMembershipProbe{}
	second_probe := &ObserverMembershipProbe{}
	first.set_track_readiness_observer(fn [first_probe] (state TextTrackReadinessState) {
		mut probe := unsafe { &ObserverMembershipProbe(first_probe) }
		probe.states << state
	})
	second.set_track_readiness_observer(fn [second_probe] (state TextTrackReadinessState) {
		mut probe := unsafe { &ObserverMembershipProbe(second_probe) }
		probe.states << state
	})
	for state in [TextTrackReadinessState.loading, .loaded, .loaded] {
		track.set_readiness_state(state)
	}
	assert first_probe.states == [TextTrackReadinessState.loading, .loaded, .loaded]
	assert second_probe.states == first_probe.states
	first.finalize()
	assert track.observers_.len == 1 && voidptr(track.observers_[0]) == voidptr(second)
	track.set_readiness_state(.failed_to_load)
	assert first_probe.states.len == 3 && second_probe.states.last() == .failed_to_load
	second.set_track_readiness_observer(none)
	track.set_readiness_state(.not_loaded)
	assert second_probe.states.len == 4 && track.readiness_state() == .not_loaded
	second.finalize()
	assert track.observers_.len == 0
	track.set_readiness_state(.loaded)
	assert first_probe.states.len == 3 && second_probe.states.len == 4
	// Equal observer fields must not make detaching one remove the other.
	mut third := TextTrackObserver.create(mut track)
	mut fourth := TextTrackObserver.create(mut track)
	third.finalize()
	assert track.observers_.len == 1 && voidptr(track.observers_[0]) == voidptr(fourth)
	fourth.finalize()
	assert track.observers_.len == 0
}

fn test_text_track_duplicate_observer_registration_is_a_fatal_source_verification() {
	case_name := os.getenv('VOX2_TRACK_OBSERVER_MEMBERSHIP_PROBE')
	if case_name != '' {
		if case_name != 'duplicate' { return }
		mut track := TextTrack.create()
		observer := TextTrackObserver.create(mut track)
		assert track.observers_.len == 1 && voidptr(track.observers_[0]) == voidptr(observer)
		track.register_observer(observer)
		panic('Duplicate observer passed verification')
	}
	observer_membership_child('duplicate', 'Source VERIFY: TextTrack observer must be registered only once')
}

fn test_text_track_missing_observer_removal_and_double_finalization_are_fatal_source_verifications() {
	case_name := os.getenv('VOX2_TRACK_OBSERVER_MEMBERSHIP_PROBE')
	if case_name != '' {
		if case_name !in ['wrong-owner', 'double-finalize'] { return }
		mut track := TextTrack.create()
		mut observer := TextTrackObserver.create(mut track)
		if case_name == 'wrong-owner' {
			mut other := TextTrack.create()
			other.unregister_observer(observer)
		} else {
			observer.finalize()
			assert track.observers_.len == 0
			observer.finalize()
		}
		panic('Unregistered observer passed verification')
	}
	for probe in ['wrong-owner', 'double-finalize'] {
		observer_membership_child(probe, 'Source VERIFY: TextTrack observer removal requires a registered observer')
	}
}
