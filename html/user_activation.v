// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the executable getter logic in UserActivation.cpp. Both
// getters read the actual native Window's activation record.
module html

import dom

@[heap]
pub struct UserActivation {
pub:
	window &dom.Window
}

pub fn UserActivation.construct_impl(window &dom.Window) !&UserActivation {
	return &UserActivation{
		window: window
	}
}

pub fn (activation &UserActivation) has_been_active() bool {
	return activation.window.has_sticky_activation()
}

pub fn (activation &UserActivation) is_active() bool {
	return activation.window.has_transient_activation()
}

pub fn user_activation_has_been_active(window_has_sticky_activation bool) bool {
	return window_has_sticky_activation
}

pub fn user_activation_is_active(window_has_transient_activation bool) bool {
	return window_has_transient_activation
}
