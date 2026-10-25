module main

import processmetrics

fn test_submission_requires_current_installation_and_a_staged_native_frame() {
	mut timing := DocumentSubmissionTiming{}
	assert timing.claim(1).installation == 0
	timing.begin_navigation(1, processmetrics.InstructionSnapshot{ instructions: 10, available: true })
	timing.begin_installation(1, processmetrics.InstructionSnapshot{ instructions: 20, available: true })
	claim := timing.claim(1)
	assert claim.installation == 1
	assert !timing.accept(claim, 1, 7).installation
	timing.stage(claim, 1, 0)
	assert !timing.accept(claim, 1, 0).installation
	timing.stage(claim, 1, 7)
	assert !timing.accept(claim, 1, 8).installation
	report := timing.accept(claim, 1, 7)
	assert report.installation
	assert report.navigation
	assert timing.installation_instructions.instructions == 20
	assert timing.navigation_instructions.instructions == 10
	assert !timing.accept(claim, 1, 7).installation
	assert timing.claim(1).installation == 0
}

fn test_submission_counts_navigation_once_but_each_replacement_installation() {
	mut timing := DocumentSubmissionTiming{}
	timing.begin_navigation(4, processmetrics.InstructionSnapshot{})
	for index in 1 .. 4 {
		timing.begin_installation(4, processmetrics.InstructionSnapshot{})
		claim := timing.claim(4)
		assert claim.installation == u64(index)
		timing.stage(claim, 4, u64(index))
		report := timing.accept(claim, 4, u64(index))
		assert report.installation
		assert report.navigation == (index == 1)
	}
}

fn test_navigation_replacement_history_and_disposal_cannot_reuse_old_clock_or_frame() {
	mut timing := DocumentSubmissionTiming{}
	timing.begin_navigation(1, processmetrics.InstructionSnapshot{})
	timing.begin_installation(1, processmetrics.InstructionSnapshot{})
	old := timing.claim(1)
	timing.stage(old, 1, 1)
	// Starting another navigation leaves the outgoing document installed.
	timing.begin_navigation(2, processmetrics.InstructionSnapshot{})
	assert timing.claim(2).installation == 0
	assert !timing.accept(old, 2, 1).installation
	timing.begin_installation(2, processmetrics.InstructionSnapshot{})
	current := timing.claim(2)
	timing.stage(current, 2, 2)
	// A replacement before native acknowledgment invalidates that image's claim.
	timing.begin_installation(2, processmetrics.InstructionSnapshot{})
	assert !timing.accept(current, 2, 2).installation
	replacement := timing.claim(2)
	timing.stage(replacement, 2, 3)
	assert timing.accept(replacement, 2, 3).navigation
	// History does not start the legacy navigation clock. Its installation has
	// its own scope but must not inherit navigation 2's start reading.
	timing.begin_installation(3, processmetrics.InstructionSnapshot{})
	history := timing.claim(3)
	timing.stage(history, 3, 4)
	report := timing.accept(history, 3, 4)
	assert report.installation
	assert !report.navigation
	timing.begin_installation(3, processmetrics.InstructionSnapshot{})
	closing := timing.claim(3)
	timing.stage(closing, 3, 5)
	assert !timing.accept(closing, 4, 5).installation
}

fn test_nested_frames_and_independent_tabs_do_not_consume_another_claim() {
	mut outer := DocumentSubmissionTiming{}
	mut other := DocumentSubmissionTiming{}
	outer.begin_installation(1, processmetrics.InstructionSnapshot{})
	other.begin_installation(1, processmetrics.InstructionSnapshot{})
	claim := outer.claim(1)
	outer.stage(claim, 1, 11)
	other.stage(other.claim(1), 1, 12)
	assert !other.accept(claim, 1, 11).installation
	assert other.accept(other.claim(1), 1, 12).installation
	assert outer.accept(claim, 1, 11).installation
	outer.begin_installation(1, processmetrics.InstructionSnapshot{})
	nested := outer.claim(1)
	outer.stage(nested, 1, 13)
	outer.stage(nested, 1, 14)
	assert outer.accept(nested, 1, 14).installation
	assert !outer.accept(nested, 1, 13).installation
}
