// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ResizeObserver/ResizeObserverSize.cpp,
// ResizeObservation.cpp, ResizeObserverEntry.cpp, and ResizeObserver.cpp.
module resizeobserver

import dom
import geometry

pub enum ResizeObserverBoxOptions {
	border_box
	content_box
	device_pixel_content_box
}

pub fn resize_observer_box_options_from_string(value string) !ResizeObserverBoxOptions {
	return match value {
		'border-box' { .border_box }
		'content-box' { .content_box }
		'device-pixel-content-box' { .device_pixel_content_box }
		else { error('Invalid ResizeObserverBoxOptions: ${value}') }
	}
}

pub fn (value ResizeObserverBoxOptions) str() string {
	return match value {
		.border_box { 'border-box' }
		.content_box { 'content-box' }
		.device_pixel_content_box { 'device-pixel-content-box' }
	}
}

pub struct ResizeObserverOptions {
pub:
	box ResizeObserverBoxOptions = .content_box
}

pub struct ResizeTargetMetrics {
pub mut:
	has_layout_box     bool
	is_svg_element     bool
	border_width       f64
	border_height      f64
	content_width      f64
	content_height     f64
	device_pixel_ratio f64 = 1
	absolute_padding_x f64
	absolute_padding_y f64
}

@[heap]
pub struct ResizeTarget {
pub:
	element &dom.Element
pub mut:
	metrics ResizeTargetMetrics
}

pub fn ResizeTarget.new(element &dom.Element, metrics ResizeTargetMetrics) &ResizeTarget {
	return &ResizeTarget{
		element: element
		metrics: metrics
	}
}

pub struct ResizeObserverSize {
pub:
	inline_size f64
	block_size  f64
}

pub fn ResizeObserverSize.compute_box_size(target &ResizeTarget, observed_box ResizeObserverBoxOptions) ResizeObserverSize {
	if !target.metrics.has_layout_box {
		return ResizeObserverSize{}
	}
	return match observed_box {
		.border_box {
			ResizeObserverSize{
				inline_size: target.metrics.border_width
				block_size:  target.metrics.border_height
			}
		}
		.content_box {
			ResizeObserverSize{
				inline_size: target.metrics.content_width
				block_size:  target.metrics.content_height
			}
		}
		.device_pixel_content_box {
			// Preserve current upstream: this multiplies border-box dimensions.
			ResizeObserverSize{
				inline_size: target.metrics.border_width * target.metrics.device_pixel_ratio
				block_size:  target.metrics.border_height * target.metrics.device_pixel_ratio
			}
		}
	}
}

pub fn (size ResizeObserverSize) equals(other ResizeObserverSize) bool {
	return size.inline_size == other.inline_size && size.block_size == other.block_size
}

@[heap]
pub struct ResizeObservation {
pub:
	target       &ResizeTarget
	observed_box ResizeObserverBoxOptions
pub mut:
	last_reported_sizes []ResizeObserverSize = [ResizeObserverSize{}]
}

pub fn ResizeObservation.new(target &ResizeTarget, observed_box ResizeObserverBoxOptions) &ResizeObservation {
	return &ResizeObservation{
		target:       target
		observed_box: observed_box
	}
}

pub fn (observation &ResizeObservation) is_active() bool {
	current := ResizeObserverSize.compute_box_size(observation.target, observation.observed_box)
	return !observation.last_reported_sizes[0].equals(current)
}

pub struct ResizeObserverEntry {
pub:
	target                        &ResizeTarget
	border_box_size               []ResizeObserverSize
	content_box_size              []ResizeObserverSize
	device_pixel_content_box_size []ResizeObserverSize
	content_rect                  &geometry.DOMRectReadOnly
}

pub fn ResizeObserverEntry.create_and_populate(target &ResizeTarget) &ResizeObserverEntry {
	border := ResizeObserverSize.compute_box_size(target, .border_box)
	content := ResizeObserverSize.compute_box_size(target, .content_box)
	device := ResizeObserverSize.compute_box_size(target, .device_pixel_content_box)
	mut x := 0.0
	mut y := 0.0
	if !target.metrics.is_svg_element && target.metrics.has_layout_box {
		x = target.metrics.absolute_padding_x
		y = target.metrics.absolute_padding_y
	}
	return &ResizeObserverEntry{
		target:                        target
		border_box_size:               [border]
		content_box_size:              [content]
		device_pixel_content_box_size: [device]
		content_rect:                  geometry.DOMRectReadOnly.construct(x, y,
			content.inline_size, content.block_size)
	}
}

pub type ResizeObserverCallback = fn ([]&ResizeObserverEntry, &ResizeObserver)

@[heap]
pub struct ResizeObserver {
mut:
	callback_            ResizeObserverCallback = unsafe { nil }
	observation_targets_ []&ResizeObservation
	active_targets_      []&ResizeObservation
	skipped_targets_     []&ResizeObservation
	registered_          bool
	last_entries_        []&ResizeObserverEntry
}

pub fn ResizeObserver.new(callback ResizeObserverCallback) &ResizeObserver {
	return &ResizeObserver{
		callback_: callback
	}
}

pub fn (observer &ResizeObserver) observation_targets() []&ResizeObservation {
	return observer.observation_targets_.clone()
}

pub fn (observer &ResizeObserver) active_targets() []&ResizeObservation {
	return observer.active_targets_.clone()
}

pub fn (observer &ResizeObserver) skipped_targets() []&ResizeObservation {
	return observer.skipped_targets_.clone()
}

pub fn (observer &ResizeObserver) is_registered() bool {
	return observer.registered_
}

pub fn (observer &ResizeObserver) last_entries() []&ResizeObserverEntry {
	return observer.last_entries_.clone()
}

pub fn (mut observer ResizeObserver) observe(target &ResizeTarget, options ResizeObserverOptions) {
	observer.unobserve(target)
	observer.observation_targets_ << ResizeObservation.new(target, options.box)
	observer.registered_ = true
}

pub fn (mut observer ResizeObserver) unobserve(target &ResizeTarget) {
	mut retained := []&ResizeObservation{}
	for observation in observer.observation_targets_ {
		if voidptr(observation.target.element) != voidptr(target.element) {
			retained << observation
		}
	}
	observer.observation_targets_ = retained
	if observer.observation_targets_.len == 0 { observer.registered_ = false }
}

pub fn (mut observer ResizeObserver) disconnect() {
	observer.observation_targets_.clear()
	observer.active_targets_.clear()
	observer.registered_ = false
}

pub fn (mut observer ResizeObserver) gather_active_observations() {
	observer.active_targets_.clear()
	for observation in observer.observation_targets_ {
		if observation.is_active() { observer.active_targets_ << observation }
	}
}

pub fn (mut observer ResizeObserver) broadcast_active_observations() {
	mut entries := []&ResizeObserverEntry{}
	for index in 0 .. observer.active_targets_.len {
		mut observation := observer.active_targets_[index]
		entries << ResizeObserverEntry.create_and_populate(observation.target)
		unsafe {
			observation.last_reported_sizes = [
				ResizeObserverSize.compute_box_size(observation.target, observation.observed_box),
			]
		}
	}
	observer.active_targets_.clear()
	observer.last_entries_ = entries.clone()
	if entries.len > 0 { observer.callback_(entries, observer) }
}
