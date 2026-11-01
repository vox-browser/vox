module browserui

import math

pub struct SwipeInput {
pub:
	phase     int // normalized: 0 none, 1 began, 2 changed, 3 ended, 4 cancelled
	momentum  bool
	precise   bool
	enabled   bool
	modifiers u32
	x         f64
	y         f64
}

pub struct Swipe {
pub mut:
	generation u64
	candidate  u64
	undecided  bool
	captured   bool
	tracking   bool
}

// 0 delivers the original event, 1 consumes it, +/-2 requests a V history begin.
pub fn (mut swipe Swipe) filter(event SwipeInput) int {
	if event.phase == 1 {
		swipe.generation++
		swipe.undecided = true
		swipe.captured = false
		swipe.tracking = false
	}
	if event.phase == 0 && !event.momentum {
		swipe.cancel()
		return 0
	}
	if swipe.captured { return if swipe.tracking { 0 } else { 1 } }
	if event.momentum {
		swipe.undecided = false
		return 0
	}
	if !event.enabled || !event.precise || event.modifiers != 0 || event.phase !in [1, 2] {
		swipe.undecided = false
		return 0
	}
	if !swipe.undecided || event.x == 0 && event.y == 0 { return 0 }
	swipe.undecided = false
	if math.abs(event.x) <= 2 * math.abs(event.y) { return 0 }
	swipe.candidate = swipe.generation
	return if event.x > 0 { -2 } else { 2 }
}

pub fn (mut swipe Swipe) capture() u64 { return swipe.capture_candidate(swipe.candidate) }

pub fn (mut swipe Swipe) capture_candidate(expected u64) u64 {
	if expected == 0 || expected != swipe.candidate || swipe.candidate != swipe.generation {
		return 0
	}
	swipe.captured = true
	swipe.tracking = true
	return swipe.generation
}

// -1 cancels/stops, 0 continues, 1 commits the matching captured navigation.
pub fn (mut swipe Swipe) progress(generation u64, amount f64, phase int, complete bool, delta int) int {
	if generation != swipe.generation || !swipe.tracking { return -1 }
	if phase == 4 {
		swipe.tracking = false
		return -1
	}
	if !complete { return 0 }
	swipe.tracking = false
	return if (delta < 0 && amount > 0.5) || (delta > 0 && amount < -0.5) { 1 } else { -1 }
}

pub fn (mut swipe Swipe) cancel() {
	swipe.generation++
	swipe.undecided = false
	swipe.captured = false
	swipe.tracking = false
}
