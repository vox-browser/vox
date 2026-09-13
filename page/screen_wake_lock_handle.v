// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/ScreenWakeLockHandle.{h,cpp}. V does not expose C++-style
// deterministic destructors, so owners release the handle explicitly when the
// corresponding Optional is cleared.
module page

@[heap]
pub struct ScreenWakeLockHandle {
mut:
	page_   &Page = unsafe { nil }
	active_ bool
}

pub fn ScreenWakeLockHandle.create(mut model Page) &ScreenWakeLockHandle {
	model.acquire_screen_wake_lock()
	return &ScreenWakeLockHandle{
		page_: model
		active_: true
	}
}

pub fn (mut handle ScreenWakeLockHandle) release() {
	if !handle.active_ {
		return
	}
	handle.active_ = false
	mut model := unsafe { &Page(handle.page_) }
	model.release_screen_wake_lock()
}

pub fn (mut handle ScreenWakeLockHandle) finalize() {
	handle.release()
}

pub fn (handle &ScreenWakeLockHandle) is_active() bool {
	return handle.active_
}
