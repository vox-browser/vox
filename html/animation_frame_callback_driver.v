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
struct AnimationFrameCallbackBatch {
mut:
	callbacks map[u32]AnimationFrameCallback
}

@[heap]
pub struct AnimationFrameCallbackDriver {
mut:
	// https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frame-callback-identifier
	animation_frame_callback_identifier_ u32
	callbacks_                           map[u32]AnimationFrameCallback
	executing_callbacks_                 map[u32]AnimationFrameCallback
	executing_callback_order_            []u32
	nested_batches_                      []&AnimationFrameCallbackBatch
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
	if id in driver.executing_callbacks_ {
		driver.executing_callbacks_.delete(id)
		return true
	}
	for mut batch in driver.nested_batches_ {
		if id in batch.callbacks {
			batch.callbacks.delete(id)
			return true
		}
	}
	return false
}

pub fn (driver &AnimationFrameCallbackDriver) has_callbacks() bool {
	return driver.callbacks_.len > 0
}

// A selected callback remains pending until its turn begins. Native bindings
// can release a canceled callback even when the frame's batch is already running.
pub fn (driver &AnimationFrameCallbackDriver) has_pending_callback(id u32) bool {
	if id in driver.callbacks_ || id in driver.executing_callbacks_ {
		return true
	}
	for batch in driver.nested_batches_ {
		if id in batch.callbacks { return true }
	}
	return false
}

pub fn (mut driver AnimationFrameCallbackDriver) run(now f64) {
	if driver.callbacks_.len == 0 { return }
	if driver.running_ {
		// Reentrant frames keep a distinct live batch so a callback can cancel
		// another callback in either the nested frame or an outer frame.
		mut batch := &AnimationFrameCallbackBatch{callbacks: driver.callbacks_.clone()}
		driver.callbacks_.clear()
		driver.nested_batches_ << batch
		defer { driver.nested_batches_.delete(driver.nested_batches_.len - 1) }
		order := batch.callbacks.keys()
		for id in order {
			callback := batch.callbacks[id] or { continue }
			batch.callbacks.delete(id)
			callback(now)
		}
		return
	}
	// Move the pending batch and recycle the previous empty map. Registrations
	// made by a callback enter the other map and wait for the next frame.
	spare := driver.executing_callbacks_
	driver.executing_callbacks_ = driver.callbacks_
	driver.callbacks_ = spare
	driver.executing_callback_order_.clear()
	for id, _ in driver.executing_callbacks_ {
		driver.executing_callback_order_ << id
	}
	driver.running_ = true
	defer {
		driver.executing_callbacks_.clear()
		driver.running_ = false
	}
	for id in driver.executing_callback_order_ {
		callback := driver.executing_callbacks_[id] or { continue }
		// Remove before invoking: cancellation during its own invocation must
		// not release the native callback a second time.
		driver.executing_callbacks_.delete(id)
		callback(now)
	}
}
