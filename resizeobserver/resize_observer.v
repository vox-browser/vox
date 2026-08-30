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
mut:
	inline_size_ f64
	block_size_  f64
}

pub fn ResizeObserverSize.compute_box_size(target &ResizeTarget, observed_box ResizeObserverBoxOptions) ResizeObserverSize {
	if !target.metrics.has_layout_box {
		return ResizeObserverSize{}
	}
	return match observed_box {
		.border_box {
			ResizeObserverSize{
				inline_size_: target.metrics.border_width
				block_size_:  target.metrics.border_height
			}
		}
		.content_box {
			ResizeObserverSize{
				inline_size_: target.metrics.content_width
				block_size_:  target.metrics.content_height
			}
		}
		.device_pixel_content_box {
			// Preserve current upstream: this multiplies border-box dimensions.
			ResizeObserverSize{
				inline_size_: target.metrics.border_width * target.metrics.device_pixel_ratio
				block_size_:  target.metrics.border_height * target.metrics.device_pixel_ratio
			}
		}
	}
}

pub fn ResizeObserverSize.calculate_box_size(target &ResizeTarget, observed_box ResizeObserverBoxOptions) ResizeObserverSize {
	computed := ResizeObserverSize.compute_box_size(target, observed_box)
	mut size := ResizeObserverSize{}
	size.set_inline_size(computed.inline_size())
	size.set_block_size(computed.block_size())
	return size
}

pub fn (size &ResizeObserverSize) inline_size() f64 {
	return size.inline_size_
}

pub fn (mut size ResizeObserverSize) set_inline_size(inline_size f64) {
	size.inline_size_ = inline_size
}

pub fn (size &ResizeObserverSize) block_size() f64 {
	return size.block_size_
}

pub fn (mut size ResizeObserverSize) set_block_size(block_size f64) {
	size.block_size_ = block_size
}

pub fn (size ResizeObserverSize) equals(other ResizeObserverSize) bool {
	return size.inline_size_ == other.inline_size_ && size.block_size_ == other.block_size_
}

@[heap]
pub struct ResizeObservation {
mut:
	target_              &ResizeTarget
	observed_box_        ResizeObserverBoxOptions
	last_reported_sizes_ []ResizeObserverSize = [ResizeObserverSize{}]
}

pub fn ResizeObservation.new(target &ResizeTarget, observed_box ResizeObserverBoxOptions) &ResizeObservation {
	return ResizeObservation.create(target, observed_box)
}

pub fn ResizeObservation.create(target &ResizeTarget, observed_box ResizeObserverBoxOptions) &ResizeObservation {
	return &ResizeObservation{
		target_:       target
		observed_box_: observed_box
	}
}

pub fn (observation &ResizeObservation) target() &ResizeTarget {
	return observation.target_
}

pub fn (observation &ResizeObservation) observed_box() ResizeObserverBoxOptions {
	return observation.observed_box_
}

pub fn (observation &ResizeObservation) last_reported_sizes() []ResizeObserverSize {
	return observation.last_reported_sizes_.clone()
}

pub fn (observation &ResizeObservation) is_active() bool {
	current := ResizeObserverSize.compute_box_size(observation.target_, observation.observed_box_)
	return !observation.last_reported_sizes_[0].equals(current)
}

pub struct ResizeObserverEntry {
mut:
	target_                        &ResizeTarget
	border_box_size_               []ResizeObserverSize
	content_box_size_              []ResizeObserverSize
	device_pixel_content_box_size_ []ResizeObserverSize
	content_rect_                  &geometry.DOMRectReadOnly
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
		target_:                        target
		border_box_size_:               [border]
		content_box_size_:              [content]
		device_pixel_content_box_size_: [device]
		content_rect_:                  geometry.DOMRectReadOnly.construct(x, y,
			content.inline_size(), content.block_size())
	}
}

pub fn to_js_array(sizes []ResizeObserverSize) []ResizeObserverSize {
	return sizes.clone()
}

pub fn (entry &ResizeObserverEntry) border_box_size_js_array() []ResizeObserverSize {
	return to_js_array(entry.border_box_size_)
}

pub fn (entry &ResizeObserverEntry) content_box_size_js_array() []ResizeObserverSize {
	return to_js_array(entry.content_box_size_)
}

pub fn (entry &ResizeObserverEntry) device_pixel_content_box_size_js_array() []ResizeObserverSize {
	return to_js_array(entry.device_pixel_content_box_size_)
}

pub fn (entry &ResizeObserverEntry) content_rect() &geometry.DOMRectReadOnly {
	return entry.content_rect_
}

pub fn (entry &ResizeObserverEntry) target() &ResizeTarget {
	return entry.target_
}

pub fn (entry &ResizeObserverEntry) border_box_size() []ResizeObserverSize {
	return entry.border_box_size_.clone()
}

pub fn (entry &ResizeObserverEntry) content_box_size() []ResizeObserverSize {
	return entry.content_box_size_.clone()
}

pub fn (entry &ResizeObserverEntry) device_pixel_content_box_size() []ResizeObserverSize {
	return entry.device_pixel_content_box_size_.clone()
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

pub fn ResizeObserver.construct_impl(callback ResizeObserverCallback) &ResizeObserver {
	return ResizeObserver.new(callback)
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
		if voidptr(observation.target().element) != voidptr(target.element) {
			retained << observation
		}
	}
	observer.observation_targets_ = retained
	observer.unregister_observer_if_needed()
}

pub fn (mut observer ResizeObserver) disconnect() {
	observer.observation_targets_.clear()
	observer.active_targets_.clear()
	observer.unregister_observer_if_needed()
}

pub fn (mut observer ResizeObserver) unregister_observer_if_needed() {
	if observer.observation_targets_.len == 0 {
		observer.registered_ = false
	}
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
		entries << ResizeObserverEntry.create_and_populate(observation.target())
		unsafe {
			observation.last_reported_sizes_ = [
				ResizeObserverSize.compute_box_size(observation.target(), observation.observed_box()),
			]
		}
	}
	observer.active_targets_.clear()
	observer.last_entries_ = entries.clone()
	if entries.len > 0 { observer.callback_(entries, observer) }
}
