// Copyright (c) 2022, the SerenityOS developers.
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/AnimationFrameCallbackDriver.cpp.
// The GC::Function<void(double)> callbacks become plain `fn (f64)` handlers.
// V maps preserve insertion order, matching the C++ OrderedHashMap iteration.
module html

pub type AnimationFrameCallback = fn (f64)

@[heap]
pub struct AnimationFrameCallbackDriver {
mut:
	// https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frame-callback-identifier
	animation_frame_callback_identifier_ u32
	callbacks_                           map[u32]AnimationFrameCallback
	executing_callbacks_                 map[u32]AnimationFrameCallback
}

pub fn (mut driver AnimationFrameCallbackDriver) add(handler AnimationFrameCallback) u32 {
	driver.animation_frame_callback_identifier_ += 1
	id := driver.animation_frame_callback_identifier_
	driver.callbacks_[id] = handler
	return id
}

pub fn (mut driver AnimationFrameCallbackDriver) remove(id u32) bool {
	if id in driver.callbacks_ {
		driver.callbacks_.delete(id)
		return true
	}
	return false
}

pub fn (driver &AnimationFrameCallbackDriver) has_callbacks() bool {
	return driver.callbacks_.len > 0
}

// Native binding retention follows the source pending map, independently of
// the moved executing snapshot. Cancelling an executing entry cannot remove it.
pub fn (driver &AnimationFrameCallbackDriver) has_pending_callback(id u32) bool {
	return id in driver.callbacks_
}

pub fn (mut driver AnimationFrameCallbackDriver) run(now f64) {
	// Move the pending callbacks into m_executing_callbacks so that callbacks scheduled from within
	// a callback are deferred to the next frame; clear the executing set afterwards (the C++
	// ScopeGuard).
	driver.executing_callbacks_ = driver.callbacks_.clone()
	driver.callbacks_.clear()
	for _, callback in driver.executing_callbacks_ {
		callback(now)
	}
	driver.executing_callbacks_.clear()
}
