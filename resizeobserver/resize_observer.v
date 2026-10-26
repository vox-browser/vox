// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ResizeObserver/ResizeObserverSize.cpp,
// ResizeObservation.cpp, ResizeObserverEntry.cpp, and ResizeObserver.cpp.
@[has_globals]
module resizeobserver

import dom
import geometry
import platform

// Ladybird keeps weak pointers here and prunes them after a GC sweep. V does
// not expose a weak-reference container, so raw pointers plus the explicit
// finalize bit preserve the same non-rooting ownership model.
__global resizeobserver_live_observer_pointers = []voidptr{}

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
	element       &dom.Element
	live_metrics_ bool
pub mut:
	metrics ResizeTargetMetrics
	alive_  bool = true
}

pub fn (target &ResizeTarget) is_alive() bool {
	return target.alive_
}

// The DOM/GC bridge calls this when the weak Element target is swept. It is
// also exposed so lifetime behavior can be tested without forcing a GC cycle.
pub fn (mut target ResizeTarget) mark_dead() {
	target.alive_ = false
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
	metrics := target.resolved_metrics()
	if !metrics.has_layout_box {
		return ResizeObserverSize{}
	}
	return match observed_box {
		.border_box {
			ResizeObserverSize{
				inline_size_: metrics.border_width
				block_size_:  metrics.border_height
			}
		}
		.content_box {
			ResizeObserverSize{
				inline_size_: metrics.content_width
				block_size_:  metrics.content_height
			}
		}
		.device_pixel_content_box {
			// Preserve current upstream: this multiplies border-box dimensions.
			ResizeObserverSize{
				inline_size_: metrics.border_width * metrics.device_pixel_ratio
				block_size_:  metrics.border_height * metrics.device_pixel_ratio
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
		target_: target
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

pub fn (mut observation ResizeObservation) set_last_reported_sizes(sizes []ResizeObserverSize) {
	observation.last_reported_sizes_ = sizes.clone()
}

pub fn (observation &ResizeObservation) has_live_target() bool {
	return observation.target_.is_alive()
}

pub fn (observation &ResizeObservation) is_active() bool {
	if !observation.has_live_target() {
		return false
	}
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
	metrics := target.resolved_metrics()
	if !metrics.is_svg_element && metrics.has_layout_box {
		x = metrics.absolute_padding_x
		y = metrics.absolute_padding_y
	}
	return &ResizeObserverEntry{
		target_:                        target
		border_box_size_:               [border]
		content_box_size_:              [content]
		device_pixel_content_box_size_: [device]
		content_rect_:                  geometry.DOMRectReadOnly.construct(x, y, content.inline_size(), content.block_size())
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

pub fn ResizeObserverEntry.target_offset() usize {
	return usize(__offsetof(ResizeObserverEntry, target_))
}

pub fn ResizeObserverEntry.content_rect_offset() usize {
	return usize(__offsetof(ResizeObserverEntry, content_rect_))
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
	document_            ?&dom.Document
	dom_registration_    &dom.ResizeObserver = unsafe { nil }
	activity_root_       bool
	live_                bool = true
}

fn create_resize_observer(callback ResizeObserverCallback, document ?&dom.Document) &ResizeObserver {
	mut observer := &ResizeObserver{
		callback_: callback
		document_: document
	}
	observer.dom_registration_ = &dom.ResizeObserver{
		target: voidptr(observer)
		gather_at_depth: resize_observer_gather_at_depth_callback
		broadcast: resize_observer_broadcast_callback
		has_active: resize_observer_has_active_callback
		has_skipped: resize_observer_has_skipped_callback
		document_was_destroyed: resize_observer_document_was_destroyed_callback
	}
	resizeobserver_live_observer_pointers << voidptr(observer)
	prune_live_resize_observers()
	return observer
}

fn live_resize_observers() []&ResizeObserver {
	mut observers := []&ResizeObserver{cap: resizeobserver_live_observer_pointers.len}
	for pointer in resizeobserver_live_observer_pointers {
		observer := unsafe { &ResizeObserver(pointer) }
		if observer.live_ {
			observers << observer
		}
	}
	return observers
}

fn prune_live_resize_observers() {
	mut retained := []voidptr{cap: resizeobserver_live_observer_pointers.len}
	for pointer in resizeobserver_live_observer_pointers {
		observer := unsafe { &ResizeObserver(pointer) }
		if observer.live_ {
			retained << pointer
		}
	}
	resizeobserver_live_observer_pointers = retained.clone()
}

pub fn ResizeObserver.new(callback ResizeObserverCallback) &ResizeObserver {
	return create_resize_observer(callback, none)
}

pub fn ResizeObserver.create(callback ResizeObserverCallback, document &dom.Document) &ResizeObserver {
	return create_resize_observer(callback, document)
}

// The JS binding supplies its relevant Window's associated document. Keeping
// that conversion at the binding boundary avoids a resizeobserver -> HTML
// dependency cycle in V.
pub fn ResizeObserver.create_for_constructor(document &dom.Document, callback ResizeObserverCallback) &ResizeObserver {
	return ResizeObserver.create(callback, document)
}

pub fn ResizeObserver.construct_impl(callback ResizeObserverCallback) &ResizeObserver {
	return ResizeObserver.new(callback)
}

pub fn (observer &ResizeObserver) callback() ResizeObserverCallback {
	return observer.callback_
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

pub fn (observer &ResizeObserver) has_activity_root() bool {
	return observer.activity_root_
}

fn (mut observer ResizeObserver) register_with_document_if_needed(document &dom.Document) {
	if registered_document := observer.document_ {
		_ = registered_document
	} else {
		observer.document_ = document
	}
	if observer.registered_ {
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.register_resize_observer(observer.dom_registration_)
	observer.registered_ = true
}

pub fn (mut observer ResizeObserver) observe(target &ResizeTarget, options ResizeObserverOptions) {
	observer.unobserve(target)
	observer.observation_targets_ << ResizeObservation.new(target, options.box)
	observer.register_with_document_if_needed(target.element.document())
	observer.update_activity_root()
	target.element.document().request_frame()
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
	observer.update_activity_root()
}

pub fn (mut observer ResizeObserver) disconnect() {
	observer.observation_targets_.clear()
	observer.active_targets_.clear()
	observer.unregister_observer_if_needed()
	observer.update_activity_root()
}

// C++: ResizeObserver::invoke_callback(ReadonlySpan<...>) const. The V
// callback receives the already-wrapped entry vector directly; exception
// reporting is owned by the scripting bridge that constructs this callback.
pub fn (observer &ResizeObserver) invoke_callback(entries []&ResizeObserverEntry) {
	invoke_resize_observer_callback(observer, entries)
}

pub fn invoke_resize_observer_callback(observer &ResizeObserver, entries []&ResizeObserverEntry) {
	callback := observer.callback()
	if callback != unsafe { nil } {
		callback(entries, observer)
	}
}

pub fn (mut observer ResizeObserver) document_was_destroyed() {
	observer.activity_root_ = false
	observer.registered_ = false
	observer.document_ = none
	observer.active_targets_.clear()
	observer.skipped_targets_.clear()
}

pub fn (mut observer ResizeObserver) remove_dead_observations() {
	mut observations := []&ResizeObservation{}
	for observation in observer.observation_targets_ {
		if observation.has_live_target() {
			observations << observation
		}
	}
	observer.observation_targets_ = observations
	mut active := []&ResizeObservation{}
	for observation in observer.active_targets_ {
		if observation.has_live_target() {
			active << observation
		}
	}
	observer.active_targets_ = active
	mut skipped := []&ResizeObservation{}
	for observation in observer.skipped_targets_ {
		if observation.has_live_target() {
			skipped << observation
		}
	}
	observer.skipped_targets_ = skipped
	observer.unregister_observer_if_needed()
	observer.update_activity_root()
}

pub fn ResizeObserver.release_activity_roots_with_dead_documents() {
	prune_live_resize_observers()
	for observer in live_resize_observers() {
		if observer.has_activity_root() && observer.document_ == none {
			mut mutable_observer := unsafe { &ResizeObserver(observer) }
			mutable_observer.activity_root_ = false
		}
	}
}

pub fn (mut observer ResizeObserver) update_activity_root() {
	document := observer.document_ or {
		observer.activity_root_ = false
		return
	}
	if document.has_been_destroyed() {
		observer.activity_root_ = false
		return
	}
	for observation in observer.observation_targets_ {
		if observation.has_live_target() {
			observer.activity_root_ = true
			return
		}
	}
	observer.activity_root_ = false
}

pub fn (mut observer ResizeObserver) unregister_observer_if_needed() {
	if observer.observation_targets_.len == 0 && observer.registered_ {
		if document := observer.document_ {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.unregister_resize_observer(observer.dom_registration_)
		}
		observer.registered_ = false
	}
}

pub fn (mut observer ResizeObserver) gather_active_observations_at_depth(depth int) {
	mut allocations := observer.enter_storage()
	defer { allocations.finish() }
	observer.remove_dead_observations()
	observer.active_targets_.clear()
	observer.skipped_targets_.clear()
	for observation in observer.observation_targets_ {
		if !observation.is_active() {
			continue
		}
		target_depth := dom.calculate_depth_for_node(observation.target().element.as_node())
		if target_depth > depth {
			observer.active_targets_ << observation
		} else {
			observer.skipped_targets_ << observation
		}
	}
}

pub fn (mut observer ResizeObserver) broadcast_active_resize_observations() int {
	mut allocations := observer.enter_storage()
	defer { allocations.finish() }
	if observer.active_targets_.len == 0 {
		return max_int
	}
	mut shallowest_target_depth := max_int
	mut entries := []&ResizeObserverEntry{cap: observer.active_targets_.len}
	for observation in observer.active_targets_ {
		if !observation.has_live_target() {
			continue
		}
		entry := ResizeObserverEntry.create_and_populate(observation.target())
		entries << entry
		matching_sizes := match observation.observed_box() {
			.border_box { entry.border_box_size() }
			.content_box { entry.content_box_size() }
			.device_pixel_content_box { entry.device_pixel_content_box_size() }
		}
		mut mutable_observation := unsafe { &ResizeObservation(observation) }
		mutable_observation.set_last_reported_sizes(matching_sizes)
		target_depth := dom.calculate_depth_for_node(observation.target().element.as_node())
		if target_depth < shallowest_target_depth {
			shallowest_target_depth = target_depth
		}
	}
	if entries.len == 0 {
		observer.active_targets_.clear()
		return max_int
	}
	observer.last_entries_ = entries.clone()
	invoke_resize_observer_callback(observer, entries)
	observer.active_targets_.clear()
	return shallowest_target_depth
}

pub fn (observer &ResizeObserver) has_active_observations() bool {
	return observer.active_targets_.len > 0
}

pub fn (observer &ResizeObserver) has_skipped_observations() bool {
	return observer.skipped_targets_.len > 0
}

pub fn (mut observer ResizeObserver) gather_active_observations() {
	mut allocations := observer.enter_storage()
	defer { allocations.finish() }
	observer.remove_dead_observations()
	observer.active_targets_.clear()
	for observation in observer.observation_targets_ {
		if observation.is_active() { observer.active_targets_ << observation }
	}
}

fn (observer &ResizeObserver) enter_storage() platform.RetainedArenaScope {
	if document := observer.document_ { return document.enter_native_storage() }
	return platform.RetainedArenaScope{}
}

// Mirrors the GC finalizer: unregister document ownership and release the
// activity root before the weak live-observer list is pruned.
pub fn (mut observer ResizeObserver) finalize() {
	if observer.registered_ {
		if document := observer.document_ {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.unregister_resize_observer(observer.dom_registration_)
		}
	}
	observer.registered_ = false
	observer.activity_root_ = false
	observer.live_ = false
	prune_live_resize_observers()
}

pub fn (mut observer ResizeObserver) broadcast_active_observations() {
	_ = observer.broadcast_active_resize_observations()
}

fn resize_observer_gather_at_depth_callback(target voidptr, depth int) {
	mut observer := unsafe { &ResizeObserver(target) }
	observer.gather_active_observations_at_depth(depth)
}

fn resize_observer_broadcast_callback(target voidptr) int {
	mut observer := unsafe { &ResizeObserver(target) }
	return observer.broadcast_active_resize_observations()
}

fn resize_observer_has_active_callback(target voidptr) bool {
	observer := unsafe { &ResizeObserver(target) }
	return observer.has_active_observations()
}

fn resize_observer_has_skipped_callback(target voidptr) bool {
	observer := unsafe { &ResizeObserver(target) }
	return observer.has_skipped_observations()
}

fn resize_observer_document_was_destroyed_callback(target voidptr) {
	mut observer := unsafe { &ResizeObserver(target) }
	observer.document_was_destroyed()
}
