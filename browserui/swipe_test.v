module browserui

fn test_swipe_classifier_locks_vertical_gestures_and_excludes_modifiers_and_momentum() {
	mut swipe := Swipe{}
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, x: 8, y: 5 }) == 0
	assert swipe.filter(SwipeInput{ phase: 2, precise: true, enabled: true, x: 100 }) == 0
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, modifiers: 1, x: 100 }) == 0
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, momentum: true, x: 100 }) == 0
	assert swipe.filter(SwipeInput{ phase: 0, precise: true, enabled: true, x: 100 }) == 0
}

fn test_swipe_capture_commit_cancellation_and_stale_generation() {
	mut swipe := Swipe{}
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, x: 100 }) == -2
	token := swipe.capture()
	assert swipe.progress(token, 0.3, 2, false, -1) == 0
	assert swipe.progress(token, 0.7, 3, true, -1) == 1
	assert swipe.filter(SwipeInput{ momentum: true }) == 1
	swipe.cancel()
	assert swipe.progress(token, 1, 3, true, -1) == -1
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, x: -100 }) == 2
	assert swipe.capture() > token
	assert swipe.progress(swipe.generation, -0.8, 4, true, 1) == -1
}

fn test_swipe_zero_delta_begin_and_superseded_candidate_cannot_capture() {
	mut swipe := Swipe{}
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true }) == 0
	assert swipe.filter(SwipeInput{ phase: 2, precise: true, enabled: true, x: 12 }) == -2
	old := swipe.candidate
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, x: -12 }) == 2
	assert swipe.capture_candidate(old) == 0
	token := swipe.capture()
	assert swipe.progress(token, 0.8, 3, true, 1) == -1 // Reversal cannot commit forward.
	assert swipe.filter(SwipeInput{ momentum: true }) == 1
	assert swipe.filter(SwipeInput{}) == 0
	assert swipe.filter(SwipeInput{ phase: 1, precise: true, enabled: true, x: 12 }) == -2
	assert swipe.progress(swipe.capture(), 0.5, 3, true, -1) == -1
}
