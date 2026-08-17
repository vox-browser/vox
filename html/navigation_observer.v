// Copyright (c) 2024, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigationObserver.{h,cpp}.
module html

import dom

@[heap]
pub struct NavigationObserver {
mut:
	navigable_                  &dom.Navigable
	navigation_complete_        ?fn ()
	ongoing_navigation_changed_ ?fn ()
	registered_                 bool
}

pub fn NavigationObserver.create(navigable &dom.Navigable) &NavigationObserver {
	observer := &NavigationObserver{
		navigable_:  navigable
		registered_: true
	}
	mut mutable_navigable := unsafe { &dom.Navigable(navigable) }
	mutable_navigable.navigation_observer_handles << voidptr(observer)
	return observer
}

pub fn (observer &NavigationObserver) navigation_complete() ?fn () {
	return observer.navigation_complete_
}

pub fn (mut observer NavigationObserver) set_navigation_complete(callback ?fn ()) {
	observer.navigation_complete_ = callback
}

pub fn (observer &NavigationObserver) ongoing_navigation_changed() ?fn () {
	return observer.ongoing_navigation_changed_
}

pub fn (mut observer NavigationObserver) set_ongoing_navigation_changed(callback ?fn ()) {
	observer.ongoing_navigation_changed_ = callback
}

pub fn (mut observer NavigationObserver) finalize() {
	if !observer.registered_ {
		return
	}
	mut navigable := unsafe { &dom.Navigable(observer.navigable_) }
	navigable.navigation_observer_handles =
		navigable.navigation_observer_handles.filter(it != voidptr(&observer))
	observer.registered_ = false
}

pub fn notify_navigation_complete(navigable &dom.Navigable) {
	for handle in navigable.navigation_observer_handles.clone() {
		if handle == unsafe { nil } { continue
		 }
		observer := unsafe { &NavigationObserver(handle) }
		if callback := observer.navigation_complete_ { callback() }
	}
}

pub fn notify_ongoing_navigation_changed(navigable &dom.Navigable) {
	for handle in navigable.navigation_observer_handles.clone() {
		if handle == unsafe { nil } { continue
		 }
		observer := unsafe { &NavigationObserver(handle) }
		if callback := observer.ongoing_navigation_changed_ { callback() }
	}
}
