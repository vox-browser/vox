// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IntersectionObserver/IntersectionObserverEntry.{h,cpp,idl}.
module intersectionobserver

import dom
import geometry

pub struct IntersectionObserverEntryInit {
pub:
	time                 f64
	root_bounds          ?geometry.DOMRectInit
	bounding_client_rect geometry.DOMRectInit
	intersection_rect    geometry.DOMRectInit
	is_intersecting      bool
	intersection_ratio   f64
	target               &dom.Element = unsafe { nil }
}

@[heap]
pub struct IntersectionObserverEntry {
	time_                 f64
	root_bounds_          ?&geometry.DOMRectReadOnly
	bounding_client_rect_ &geometry.DOMRectReadOnly
	intersection_rect_    &geometry.DOMRectReadOnly
	is_intersecting_      bool
	intersection_ratio_   f64
	target_               &dom.Element
}

pub fn IntersectionObserverEntry.construct(options IntersectionObserverEntryInit) !&IntersectionObserverEntry {
	return IntersectionObserverEntry.construct_impl(options)
}

pub fn IntersectionObserverEntry.construct_impl(options IntersectionObserverEntryInit) !&IntersectionObserverEntry {
	if options.target == unsafe { nil } {
		return error('IntersectionObserverEntry target is required')
	}
	mut root_bounds := ?&geometry.DOMRectReadOnly(none)
	if bounds := options.root_bounds {
		root_bounds = geometry.DOMRectReadOnly.from_rect(bounds)
	}
	return IntersectionObserverEntry.create(options.time, root_bounds, geometry.DOMRectReadOnly.from_rect(options.bounding_client_rect), geometry.DOMRectReadOnly.from_rect(options.intersection_rect), options.is_intersecting, options.intersection_ratio, options.target)
}

pub fn IntersectionObserverEntry.create(time f64, root_bounds ?&geometry.DOMRectReadOnly, bounding_client_rect &geometry.DOMRectReadOnly, intersection_rect &geometry.DOMRectReadOnly, is_intersecting bool, intersection_ratio f64, target &dom.Element) &IntersectionObserverEntry {
	return &IntersectionObserverEntry{
		time_: time
		root_bounds_: root_bounds
		bounding_client_rect_: bounding_client_rect
		intersection_rect_: intersection_rect
		is_intersecting_: is_intersecting
		intersection_ratio_: intersection_ratio
		target_: target
	}
}

pub fn IntersectionObserverEntry.root_bounds_offset() uint {
	return uint(__offsetof(IntersectionObserverEntry, root_bounds_))
}

pub fn IntersectionObserverEntry.bounding_client_rect_offset() uint {
	return uint(__offsetof(IntersectionObserverEntry, bounding_client_rect_))
}

pub fn IntersectionObserverEntry.intersection_rect_offset() uint {
	return uint(__offsetof(IntersectionObserverEntry, intersection_rect_))
}

pub fn IntersectionObserverEntry.target_offset() uint {
	return uint(__offsetof(IntersectionObserverEntry, target_))
}

pub fn (entry &IntersectionObserverEntry) time() f64 {
	return entry.time_
}

pub fn (entry &IntersectionObserverEntry) root_bounds() ?&geometry.DOMRectReadOnly {
	return entry.root_bounds_
}

pub fn (entry &IntersectionObserverEntry) bounding_client_rect() &geometry.DOMRectReadOnly {
	return entry.bounding_client_rect_
}

pub fn (entry &IntersectionObserverEntry) intersection_rect() &geometry.DOMRectReadOnly {
	return entry.intersection_rect_
}

pub fn (entry &IntersectionObserverEntry) is_intersecting() bool {
	return entry.is_intersecting_
}

pub fn (entry &IntersectionObserverEntry) intersection_ratio() f64 {
	return entry.intersection_ratio_
}

pub fn (entry &IntersectionObserverEntry) target() &dom.Element {
	return entry.target_
}
