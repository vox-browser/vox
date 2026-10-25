module main

import processmetrics

// Scalar identities only: a pending native frame never owns a retired Document.
struct DocumentSubmissionClaim {
	navigation   int
	installation u64
}

struct DocumentSubmissionReport {
	installation bool
	navigation   bool
}

struct DocumentSubmissionTiming {
mut:
	navigation                int
	clock_navigation          int
	installation              u64
	staged_frame              u64
	clock_started             bool
	navigation_submitted      bool
	installation_submitted    bool
	navigation_instructions   processmetrics.InstructionSnapshot
	installation_instructions processmetrics.InstructionSnapshot
}

fn (mut timing DocumentSubmissionTiming) begin_navigation(generation int, start processmetrics.InstructionSnapshot) {
	timing.clock_navigation = generation
	timing.clock_started = true
	timing.navigation_submitted = false
	timing.navigation_instructions = start
	timing.staged_frame = 0
}

fn (mut timing DocumentSubmissionTiming) begin_installation(generation int, start processmetrics.InstructionSnapshot) {
	timing.navigation = generation
	timing.installation++
	timing.installation_submitted = false
	timing.installation_instructions = start
	timing.staged_frame = 0
}

fn (timing &DocumentSubmissionTiming) claim(generation int) DocumentSubmissionClaim {
	if generation != timing.navigation || timing.installation == 0 || timing.installation_submitted {
		return DocumentSubmissionClaim{}
	}
	return DocumentSubmissionClaim{generation, timing.installation}
}

fn (timing &DocumentSubmissionTiming) matches(claim DocumentSubmissionClaim, generation int) bool {
	return claim.installation != 0 && claim.installation == timing.installation
		&& claim.navigation == generation && timing.navigation == generation
		&& !timing.installation_submitted
}

fn (mut timing DocumentSubmissionTiming) stage(claim DocumentSubmissionClaim, generation int, frame u64) {
	if frame != 0 && timing.matches(claim, generation) {
		timing.staged_frame = frame
	}
}

fn (mut timing DocumentSubmissionTiming) accept(claim DocumentSubmissionClaim, generation int, frame u64) DocumentSubmissionReport {
	if frame == 0 || frame != timing.staged_frame || !timing.matches(claim, generation) {
		return DocumentSubmissionReport{}
	}
	timing.staged_frame = 0
	timing.installation_submitted = true
	navigation := timing.clock_started && timing.clock_navigation == generation
		&& !timing.navigation_submitted
	if navigation { timing.navigation_submitted = true }
	return DocumentSubmissionReport{true, navigation}
}
