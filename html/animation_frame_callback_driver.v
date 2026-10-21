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
	running_                             bool
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
	if driver.callbacks_.len == 0 { return }
	if driver.running_ {
		// An embedding can reenter while a callback runs. Keep that exceptional
		// batch local, without clearing or replacing the outer executing map.
		callbacks := driver.callbacks_.clone()
		driver.callbacks_.clear()
		for _, callback in callbacks { callback(now) }
		return
	}
	// Move the pending batch and recycle the previous empty map. Registrations
	// made by a callback enter the other map and wait for the next frame.
	spare := driver.executing_callbacks_
	driver.executing_callbacks_ = driver.callbacks_
	driver.callbacks_ = spare
	driver.running_ = true
	defer {
		driver.executing_callbacks_.clear()
		driver.running_ = false
	}
	for _, callback in driver.executing_callbacks_ {
		callback(now)
	}
}
