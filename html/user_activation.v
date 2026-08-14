// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the executable getter logic in UserActivation.cpp. Window
// activation state is supplied by the caller until Window is translated.
module html

pub fn user_activation_has_been_active(window_has_sticky_activation bool) bool {
	return window_has_sticky_activation
}

pub fn user_activation_is_active(window_has_transient_activation bool) bool {
	return window_has_transient_activation
}
