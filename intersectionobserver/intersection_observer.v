// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IntersectionObserver/IntersectionObserver.{h,cpp,idl}.
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
	for split < token.len && (token[split].is_digit() || token[split] in [`+`, `-`, `.`] || token[split] in [
		`e`,
		`E`,
	]) {
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
	return IntersectionObserver.parse_a_margin(input)
}

// https://w3c.github.io/IntersectionObserver/#parse-a-margin
pub fn IntersectionObserver.parse_a_margin(input string) ?[]LengthPercentage {
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
	root ObserverRoot
	// Derived from the callback realm by C++; injected by the V host for an
	// implicit-root observer.
	relevant_document ?&dom.Document
	root_margin       string = '0px'
	scroll_margin     string = '0px'
	thresholds        []f64 = [0.0]
	delay             i64
	track_visibility  bool
}

// Web IDL callback: undefined (sequence<IntersectionObserverEntry> entries,
// IntersectionObserver observer).
pub type IntersectionObserverCallback = fn ([]&IntersectionObserverEntry, &IntersectionObserver)

pub fn create_lazy_load_intersection_observer_callback(callback IntersectionObserverCallback) IntersectionObserverCallback {
	// The HTML Document supplies its lazy-load resumption callback at this
	// cycle-breaking boundary; the typed V callback needs no JS wrapper.
	return callback
}

pub fn invoke_intersection_observer_callback(observer &IntersectionObserver, queue []&IntersectionObserverEntry) {
	observer.callback()(queue, observer)
}

struct ObservationTarget {
mut:
	target                   &dom.Element
	previous_threshold_index ?uint
	previous_is_intersecting bool
}

@[heap]
pub struct IntersectionObserver {
	callback_          IntersectionObserverCallback @[required]
	root_              ObserverRoot
	root_margin_       []LengthPercentage
	scroll_margin_     []LengthPercentage
	thresholds_        []f64
	delay_             i64
	track_visibility_  bool
	relevant_document_ ?&dom.Document
	document_          ?&dom.Document
mut:
	document_registration_ ?&dom.IntersectionObserver
	queued_entries_        []&IntersectionObserverEntry
	observation_targets_   []ObservationTarget
}

fn dom_observer_observation_targets(target voidptr) []dom.IntersectionObserverObservationTarget {
	observer := unsafe { &IntersectionObserver(target) }
	mut targets := []dom.IntersectionObserverObservationTarget{cap: observer.observation_targets_.len}
	for observed_target in observer.observation_targets_ {
		targets << dom.IntersectionObserverObservationTarget{
			target: observed_target.target
			previous_threshold_index: observed_target.previous_threshold_index
			previous_is_intersecting: observed_target.previous_is_intersecting
		}
	}
	return targets
}

fn dom_observer_update_target_state(target voidptr, observed_target_index uint, threshold_index uint, is_intersecting bool) {
	mut observer := unsafe { &IntersectionObserver(target) }
	if observed_target_index >= uint(observer.observation_targets_.len) {
		return
	}
	observer.observation_targets_[observed_target_index].previous_threshold_index = threshold_index
	observer.observation_targets_[observed_target_index].previous_is_intersecting = is_intersecting
}

fn dom_observer_observe(target voidptr, element &dom.Element) {
	mut observer := unsafe { &IntersectionObserver(target) }
	observer.observe(element)
}

fn dom_observer_unobserve(target voidptr, element &dom.Element) {
	mut observer := unsafe { &IntersectionObserver(target) }
	observer.unobserve(element)
}

fn dom_rect_to_geometry_rect(rect dom.Rect) geometry.DOMRectInit {
	return geometry.DOMRectInit{
		x: rect.x
		y: rect.y
		width: rect.width
		height: rect.height
	}
}

fn dom_observer_queue_entry(target voidptr, time f64, root_bounds dom.Rect, bounding_client_rect dom.Rect, intersection_rect dom.Rect, is_intersecting bool, intersection_ratio f64, element &dom.Element) {
	mut observer := unsafe { &IntersectionObserver(target) }
	entry := IntersectionObserverEntry.construct_impl(IntersectionObserverEntryInit{
		time: time
		root_bounds: dom_rect_to_geometry_rect(root_bounds)
		bounding_client_rect: dom_rect_to_geometry_rect(bounding_client_rect)
		intersection_rect: dom_rect_to_geometry_rect(intersection_rect)
		is_intersecting: is_intersecting
		intersection_ratio: intersection_ratio
		target: element
	}) or { return }
	observer.queue_entry(entry)
}

fn dom_observer_notify(target voidptr) {
	mut observer := unsafe { &IntersectionObserver(target) }
	queue := observer.take_records()
	if queue.len == 0 {
		return
	}
	invoke_intersection_observer_callback(observer, queue)
}

fn geometry_rect_to_dom_rect(rect geometry.DOMRectInit) dom.Rect {
	return dom.Rect{rect.x, rect.y, rect.width, rect.height}
}

fn dom_observer_root_bounds(target voidptr) dom.Rect {
	observer := unsafe { &IntersectionObserver(target) }
	root := observer.intersection_root()
	mut base := geometry.DOMRectInit{}
	mut root_document := ?&dom.Document(none)
	mut has_layout_box := false
	if document := root.document {
		viewport := document.viewport_rect()
		base = geometry.DOMRectInit{0, 0, viewport.width, viewport.height}
		root_document = document
		has_layout_box = unsafe { &dom.Node(document) }.layout_node() != none
	} else if element := root.element {
		rect := element.bounding_client_rect_assuming_layout_clean()
		base = geometry.DOMRectInit{rect.x, rect.y, rect.width, rect.height}
		root_document = element.document()
		has_layout_box = element.el_layout_node() != none
	}
	same_origin := if document := observer.document_ {
		if candidate := root_document {
			candidate.origin().is_same_origin(document.origin())
		} else {
			false
		}
	} else {
		false
	}
	is_scrollable := if root.document != none {
		true
	} else if element := root.element {
		element.is_scroll_container()
	} else {
		false
	}
	return geometry_rect_to_dom_rect(observer.root_intersection_rectangle(RootGeometry{
		rect: base
		same_origin: same_origin
		has_layout_box: has_layout_box
		is_scrollable: is_scrollable
	}))
}

fn dom_observer_root_node(target voidptr) ?&dom.Node {
	return unsafe { &IntersectionObserver(target) }.intersection_root_node()
}

fn dom_observer_is_implicit_root(target voidptr) bool {
	return unsafe { &IntersectionObserver(target) }.is_implicit_root()
}

fn dom_observer_root_is_element(target voidptr) bool {
	return unsafe { &IntersectionObserver(target) }.intersection_root().kind == .element
}

fn dom_observer_thresholds(target voidptr) []f64 {
	return unsafe { &IntersectionObserver(target) }.thresholds()
}

fn dom_observer_scroll_margins(target voidptr) []dom.IntersectionObserverMarginValue {
	observer := unsafe { &IntersectionObserver(target) }
	return observer.scroll_margin_values().map(dom.IntersectionObserverMarginValue{
		value: it.value
		is_percentage: it.unit == .percent
	})
}

// https://w3c.github.io/IntersectionObserver/#initialize-a-new-intersectionobserver
pub fn IntersectionObserver.construct(callback IntersectionObserverCallback, options IntersectionObserverInit) !&IntersectionObserver {
	return IntersectionObserver.construct_impl(callback, options)
}

pub fn IntersectionObserver.construct_impl(callback IntersectionObserverCallback, options IntersectionObserverInit) !&IntersectionObserver {
	if document := options.relevant_document {
		return IntersectionObserver.create_with_implicit_root_document(callback, options, document)
	}
	return IntersectionObserver.create_internal(callback, options)
}

pub fn IntersectionObserver.create_with_implicit_root_document(callback IntersectionObserverCallback, options IntersectionObserverInit, implicit_root_document &dom.Document) !&IntersectionObserver {
	return IntersectionObserver.create_internal(callback, IntersectionObserverInit{
		...options
		relevant_document: implicit_root_document
	})
}

pub fn IntersectionObserver.create_for_constructor(callback IntersectionObserverCallback, options IntersectionObserverInit, implicit_root_document &dom.Document) !&IntersectionObserver {
	return IntersectionObserver.create_with_implicit_root_document(callback, options, implicit_root_document)
}

fn IntersectionObserver.create_internal(callback IntersectionObserverCallback, options IntersectionObserverInit) !&IntersectionObserver {
	root_margin := IntersectionObserver.parse_a_margin(options.root_margin) or {
		return error('IntersectionObserver: Cannot parse root margin as a margin')
	}
	scroll_margin := IntersectionObserver.parse_a_margin(options.scroll_margin) or {
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
	document := match options.root.kind {
		.element {
			if element := options.root.element {
				?&dom.Document(element.document())
			} else {
				?&dom.Document(none)
			}
		}
		.document { options.root.document }
		.implicit { options.relevant_document }
	}
	mut observer := &IntersectionObserver{
		callback_: callback
		root_: options.root
		root_margin_: root_margin
		scroll_margin_: scroll_margin
		thresholds_: thresholds
		delay_: delay
		track_visibility_: options.track_visibility
		relevant_document_: options.relevant_document
		document_: document
	}
	if mut observer_document := document {
		registration := &dom.IntersectionObserver{
			target: voidptr(observer)
			observation_targets_: dom_observer_observation_targets
			observe_target: dom_observer_observe
			unobserve_target: dom_observer_unobserve
			queue_entry_: dom_observer_queue_entry
			notify: dom_observer_notify
			root_bounds: dom_observer_root_bounds
			root_node: dom_observer_root_node
			is_implicit_root: dom_observer_is_implicit_root
			root_is_element: dom_observer_root_is_element
			thresholds: dom_observer_thresholds
			scroll_margins: dom_observer_scroll_margins
			update_target_state: dom_observer_update_target_state
		}
		observer.document_registration_ = registration
		observer_document.register_intersection_observer(registration)
	}
	return observer
}

// Mirrors IntersectionObserver::finalize(): the document registry must not
// retain an observer after its platform object is finalized.
pub fn (mut observer IntersectionObserver) finalize() {
	registration := observer.document_registration_ or { return }
	if mut document := observer.document_ {
		document.unregister_intersection_observer(registration)
	}
	observer.document_registration_ = none
}

pub fn (observer &IntersectionObserver) root() ObserverRoot {
	return observer.root_
}

pub fn (observer &IntersectionObserver) root_margin() string {
	mut values := []string{cap: observer.root_margin_.len}
	for value in observer.root_margin_ {
		append_margin_value(mut values, value)
	}
	return values.join(' ')
}

pub fn (observer &IntersectionObserver) scroll_margin() string {
	mut values := []string{cap: observer.scroll_margin_.len}
	for value in observer.scroll_margin_ {
		append_margin_value(mut values, value)
	}
	return values.join(' ')
}

fn append_margin_value(mut values []string, value LengthPercentage) {
	values << value.serialize()
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

// https://www.w3.org/TR/intersection-observer/#intersectionobserver-intersection-root
pub fn (observer &IntersectionObserver) intersection_root() ObserverRoot {
	if !observer.is_implicit_root() {
		return observer.root_
	}
	return ObserverRoot{
		kind: .document
		document: observer.relevant_document_
	}
}

pub fn (observer &IntersectionObserver) intersection_root_node() ?&dom.Node {
	root := observer.intersection_root()
	if element := root.element {
		return element.as_node()
	}
	if document := root.document {
		return unsafe { &dom.Node(document) }
	}
	return none
}

pub fn (observer &IntersectionObserver) callback() IntersectionObserverCallback {
	return observer.callback_
}

pub fn (observer &IntersectionObserver) observation_targets() []&dom.Element {
	return observer.observation_targets_.map(it.target)
}

pub fn (mut observer IntersectionObserver) observe(target &dom.Element) {
	for candidate in observer.observation_targets_ {
		// DOM object identity is pointer identity. Struct equality would wrongly
		// collapse two distinct, currently equivalent Element objects.
		if voidptr(candidate.target) == voidptr(target) {
			return
		}
	}
	mut mutable_target := target
	mutable_target.register_intersection_observer(voidptr(observer))
	observer.observation_targets_ << ObservationTarget{
		target: target
	}
	if document := observer.document_ {
		document.request_frame()
	}
}

pub fn (mut observer IntersectionObserver) unobserve(target &dom.Element) {
	for index, candidate in observer.observation_targets_ {
		if voidptr(candidate.target) == voidptr(target) {
			mut mutable_target := target
			mutable_target.unregister_intersection_observer(voidptr(observer))
			observer.observation_targets_.delete(index)
			return
		}
	}
}

pub fn (mut observer IntersectionObserver) disconnect() {
	for target in observer.observation_targets_ {
		mut mutable_target := target.target
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

pub struct RootGeometry {
pub:
	rect           geometry.DOMRectInit
	same_origin    bool = true
	has_layout_box bool = true
	is_scrollable  bool
}

fn margin_to_px(value LengthPercentage, reference f64) f64 {
	return if value.unit == .px { value.value } else { value.value * reference / 100.0 }
}

// The caller supplies the viewport or element bounding rectangle selected by
// the C++ root-kind branches. Margin expansion retains Ladybird's current
// vertical-height/horizontal-width percentage resolution.
pub fn (observer &IntersectionObserver) root_intersection_rectangle(root RootGeometry) geometry.DOMRectInit {
	if !root.same_origin {
		return root.rect
	}
	top := margin_to_px(observer.root_margin_[0], root.rect.height)
	right := margin_to_px(observer.root_margin_[1], root.rect.width)
	bottom := margin_to_px(observer.root_margin_[2], root.rect.height)
	left := margin_to_px(observer.root_margin_[3], root.rect.width)
	mut expanded_top := top
	mut expanded_right := right
	mut expanded_bottom := bottom
	mut expanded_left := left
	if root.is_scrollable {
		expanded_top += margin_to_px(observer.scroll_margin_[0], root.rect.width)
		expanded_right += margin_to_px(observer.scroll_margin_[1], root.rect.width)
		expanded_bottom += margin_to_px(observer.scroll_margin_[2], root.rect.width)
		expanded_left += margin_to_px(observer.scroll_margin_[3], root.rect.width)
	}
	return geometry.DOMRectInit{
		x: root.rect.x - expanded_left
		y: root.rect.y - expanded_top
		width: root.rect.width + expanded_left + expanded_right
		height: root.rect.height + expanded_top + expanded_bottom
	}
}
