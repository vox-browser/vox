// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IntersectionObserver/IntersectionObserver.{h,cpp,idl} and
// IntersectionObserverRegistration.h.
module intersectionobserver

import dom
import geometry
import math
import strconv

pub enum MarginUnit {
	px
	percent
}

pub struct LengthPercentage {
pub:
	value f64
	unit  MarginUnit
}

fn serialize_number(value f64) string {
	if value == f64(i64(value)) {
		return i64(value).str()
	}
	return value.str()
}

pub fn (value LengthPercentage) serialize() string {
	suffix := if value.unit == .px { 'px' } else { '%' }
	return '${serialize_number(value.value)}${suffix}'
}

fn absolute_length_to_px(value f64, unit string) ?f64 {
	return match unit.to_lower() {
		'px' { value }
		'cm' { value * 96.0 / 2.54 }
		'mm' { value * 96.0 / 25.4 }
		'q' { value * 96.0 / 101.6 }
		'in' { value * 96.0 }
		'pc' { value * 16.0 }
		'pt' { value * 96.0 / 72.0 }
		else { none }
	}
}

fn parse_margin_token(token string) ?LengthPercentage {
	if token.ends_with('%') {
		number := strconv.atof64(token[..token.len - 1]) or { return none }
		if math.is_nan(number) || math.is_inf(number, 0) {
			return none
		}
		return LengthPercentage{number, .percent}
	}
	mut split := 0
	for split < token.len && (token[split].is_digit()
		|| token[split] in [`+`, `-`, `.`] || token[split] in [`e`, `E`]) {
		// A sign after e is part of the number; atof64 performs the final grammar
		// validation, so scanning through it is harmless.
		split++
	}
	if split == 0 || split == token.len {
		return none
	}
	number := strconv.atof64(token[..split]) or { return none }
	if math.is_nan(number) || math.is_inf(number, 0) {
		return none
	}
	px := absolute_length_to_px(number, token[split..]) or { return none }
	return LengthPercentage{px, .px}
}

// https://w3c.github.io/IntersectionObserver/#parse-a-margin
pub fn parse_a_margin(input string) ?[]LengthPercentage {
	parts := input.fields()
	if parts.len > 4 {
		return none
	}
	mut values := []LengthPercentage{}
	if parts.len == 0 {
		values << LengthPercentage{0, .px}
	} else {
		for part in parts {
			values << (parse_margin_token(part) or { return none })
		}
	}
	match values.len {
		1 {
			values << values[0]
			values << values[0]
			values << values[0]
		}
		2 {
			values << values[0]
			values << values[1]
		}
		3 {
			values << values[1]
		}
		else {}
	}
	return values
}

pub enum ObserverRootKind {
	implicit
	element
	document
}

pub struct ObserverRoot {
pub:
	kind     ObserverRootKind
	element  ?&dom.Element
	document ?&dom.Document
}

pub struct IntersectionObserverInit {
pub:
	root             ObserverRoot
	root_margin      string = '0px'
	scroll_margin    string = '0px'
	thresholds       []f64  = [0.0]
	delay            i64
	track_visibility bool
}

// Web IDL callback: undefined (sequence<IntersectionObserverEntry> entries,
// IntersectionObserver observer).
pub type IntersectionObserverCallback = fn ([]&IntersectionObserverEntry, &IntersectionObserver)

@[heap]
pub struct IntersectionObserver {
	callback_         IntersectionObserverCallback @[required]
	root_             ObserverRoot
	root_margin_      []LengthPercentage
	scroll_margin_    []LengthPercentage
	thresholds_       []f64
	delay_            i64
	track_visibility_ bool
mut:
	queued_entries_      []&IntersectionObserverEntry
	observation_targets_ []&dom.Element
}

// https://w3c.github.io/IntersectionObserver/#initialize-a-new-intersectionobserver
pub fn IntersectionObserver.construct(callback IntersectionObserverCallback, options IntersectionObserverInit) !&IntersectionObserver {
	root_margin := parse_a_margin(options.root_margin) or {
		return error('IntersectionObserver: Cannot parse root margin as a margin')
	}
	scroll_margin := parse_a_margin(options.scroll_margin) or {
		return error('IntersectionObserver: Cannot parse scroll margin as a margin')
	}
	mut thresholds := options.thresholds.clone()
	for value in thresholds {
		// Preserve the C++ comparison-only check. NaN compares false in both
		// directions and consequently passes this implementation layer.
		if value < 0.0 || value > 1.0 {
			return error('Threshold values must be between 0.0 and 1.0 inclusive')
		}
	}
	thresholds.sort(a < b)
	if thresholds.len == 0 {
		thresholds << 0.0
	}
	delay := if options.track_visibility && options.delay < 100 { i64(100) } else { options.delay }
	return &IntersectionObserver{
		callback_:         callback
		root_:             options.root
		root_margin_:      root_margin
		scroll_margin_:    scroll_margin
		thresholds_:       thresholds
		delay_:            delay
		track_visibility_: options.track_visibility
	}
}

pub fn (observer &IntersectionObserver) root() ObserverRoot {
	return observer.root_
}

pub fn (observer &IntersectionObserver) root_margin() string {
	return observer.root_margin_.map(it.serialize()).join(' ')
}

pub fn (observer &IntersectionObserver) scroll_margin() string {
	return observer.scroll_margin_.map(it.serialize()).join(' ')
}

pub fn (observer &IntersectionObserver) scroll_margin_values() []LengthPercentage {
	return observer.scroll_margin_.clone()
}

pub fn (observer &IntersectionObserver) thresholds() []f64 {
	return observer.thresholds_.clone()
}

pub fn (observer &IntersectionObserver) delay() i64 {
	return observer.delay_
}

pub fn (observer &IntersectionObserver) track_visibility() bool {
	return observer.track_visibility_
}

pub fn (observer &IntersectionObserver) is_implicit_root() bool {
	return observer.root_.kind == .implicit
}

pub fn (observer &IntersectionObserver) callback() IntersectionObserverCallback {
	return observer.callback_
}

pub fn (observer &IntersectionObserver) observation_targets() []&dom.Element {
	return observer.observation_targets_.clone()
}

pub fn (mut observer IntersectionObserver) observe(target &dom.Element) {
	for candidate in observer.observation_targets_ {
		// DOM object identity is pointer identity. Struct equality would wrongly
		// collapse two distinct, currently equivalent Element objects.
		if voidptr(candidate) == voidptr(target) {
			return
		}
	}
	mut mutable_target := target
	mutable_target.register_intersection_observer(dom.IntersectionObserverRegistration_{
		observer: voidptr(observer)
	})
	observer.observation_targets_ << target
}

pub fn (mut observer IntersectionObserver) unobserve(target &dom.Element) {
	for index, candidate in observer.observation_targets_ {
		if voidptr(candidate) == voidptr(target) {
			mut mutable_target := target
			mutable_target.unregister_intersection_observer(voidptr(observer))
			observer.observation_targets_.delete(index)
			return
		}
	}
}

pub fn (mut observer IntersectionObserver) disconnect() {
	for target in observer.observation_targets_ {
		mut mutable_target := target
		mutable_target.unregister_intersection_observer(voidptr(observer))
	}
	observer.observation_targets_.clear()
}

pub fn (mut observer IntersectionObserver) queue_entry(entry &IntersectionObserverEntry) {
	observer.queued_entries_ << entry
}

pub fn (mut observer IntersectionObserver) take_records() []&IntersectionObserverEntry {
	queue := observer.queued_entries_.clone()
	observer.queued_entries_.clear()
	return queue
}

pub struct IntersectionObserverRegistration {
pub:
	observer                 &IntersectionObserver
	previous_threshold_index ?usize
	previous_is_intersecting bool
}

pub struct RootGeometry {
pub:
	rect           geometry.DOMRectInit
	same_origin    bool = true
	has_layout_box bool = true
}

fn margin_to_px(value LengthPercentage, reference f64) f64 {
	return if value.unit == .px { value.value } else { value.value * reference / 100.0 }
}

// The caller supplies the viewport or element bounding rectangle selected by
// the C++ root-kind branches. Margin expansion retains Ladybird's current
// vertical-height/horizontal-width percentage resolution.
pub fn (observer &IntersectionObserver) root_intersection_rectangle(root RootGeometry) geometry.DOMRectInit {
	if !root.same_origin || !root.has_layout_box {
		return root.rect
	}
	top := margin_to_px(observer.root_margin_[0], root.rect.height)
	right := margin_to_px(observer.root_margin_[1], root.rect.width)
	bottom := margin_to_px(observer.root_margin_[2], root.rect.height)
	left := margin_to_px(observer.root_margin_[3], root.rect.width)
	return geometry.DOMRectInit{
		x:      root.rect.x - left
		y:      root.rect.y - top
		width:  root.rect.width + left + right
		height: root.rect.height + top + bottom
	}
}
