// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
// Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TextTrack.cpp, TextTrackList.cpp, TextTrackCue.cpp,
// TextTrackCueList.cpp, and TextTrackObserver.cpp. These are DOM::EventTarget
// subclasses, so they embed dom.EventTarget and reuse its event-handler-attribute
// machinery (oncuechange/onenter/onchange/…). JS-binding-only overrides such as
// internal_get_own_property are represented by the item() indexed accessors.
module html

import dom
import math

// Bindings::TextTrackKind (generated from the IDL enum).
// https://html.spec.whatwg.org/multipage/media.html#texttrackkind
pub enum TextTrackKind {
	subtitles
	captions
	descriptions
	chapters
	metadata
}

// Bindings::TextTrackMode (generated from the IDL enum).
// https://html.spec.whatwg.org/multipage/media.html#texttrackmode
pub enum TextTrackMode {
	disabled
	hidden
	showing
}

// https://html.spec.whatwg.org/multipage/media.html#text-track-readiness-state
pub enum TextTrackReadinessState {
	not_loaded
	loading
	loaded
	failed_to_load
}

// --- TextTrack (HTML/TextTrack.h) ---
@[heap]
pub struct TextTrack {
	dom.EventTarget
mut:
	kind_            TextTrackKind = .subtitles
	label_           string
	language_        string
	id_              string
	mode_            TextTrackMode = .disabled
	readiness_state_ TextTrackReadinessState = .not_loaded
	observers_       []&TextTrackObserver
	cues_            &TextTrackCueList = unsafe { nil }
	media_element_   ?&HTMLMediaElement
}

pub fn TextTrack.create() &TextTrack {
	return &TextTrack{
		EventTarget: dom.EventTarget{}
		cues_: &TextTrackCueList{
			EventTarget: dom.EventTarget{}
		}
	}
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-kind
pub fn (t &TextTrack) kind() TextTrackKind {
	return t.kind_
}

pub fn (mut t TextTrack) set_kind(kind TextTrackKind) {
	t.kind_ = kind
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-label
pub fn (t &TextTrack) label() string {
	return t.label_
}

pub fn (mut t TextTrack) set_label(label string) {
	t.label_ = label
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-language
pub fn (t &TextTrack) language() string {
	return t.language_
}

pub fn (mut t TextTrack) set_language(language string) {
	t.language_ = language
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-id
pub fn (t &TextTrack) id() string {
	return t.id_
}

pub fn (mut t TextTrack) set_id(id string) {
	t.id_ = id
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode
pub fn (t &TextTrack) mode() TextTrackMode {
	return t.mode_
}

pub fn (mut t TextTrack) set_mode(mode TextTrackMode) {
	t.mode_ = mode
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttrack-oncuechange
pub fn (mut t TextTrack) set_oncuechange(event_handler ?&dom.CallbackType) {
	t.set_event_handler_attribute(event_cuechange, event_handler)
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttrack-oncuechange
pub fn (t &TextTrack) oncuechange() ?&dom.CallbackType {
	return t.event_handler_attribute(event_cuechange)
}

pub fn (t &TextTrack) readiness_state() TextTrackReadinessState {
	return t.readiness_state_
}

pub fn (mut t TextTrack) set_readiness_state(readiness_state TextTrackReadinessState) {
	t.readiness_state_ = readiness_state
	for observer in t.observers_ {
		if callback := observer.track_readiness_observer() {
			callback(t.readiness_state_)
		}
	}
}

pub fn (mut t TextTrack) register_observer(observer &TextTrackObserver) {
	for registered in t.observers_ {
		if voidptr(registered) == voidptr(observer) { panic('Source VERIFY: TextTrack observer must be registered only once') }
	}
	t.observers_ << observer
}

pub fn (mut t TextTrack) unregister_observer(observer &TextTrackObserver) {
	for index, registered in t.observers_ {
		if voidptr(registered) == voidptr(observer) {
			t.observers_.delete(index)
			return
		}
	}
	panic('Source VERIFY: TextTrack observer removal requires a registered observer')
}

pub fn (t &TextTrack) cues() &TextTrackCueList {
	return t.cues_
}

pub fn (mut t TextTrack) add_cue(mut cue TextTrackCue) {
	cue.track_ = t
	t.cues_.add_cue(cue)
}

pub fn (mut t TextTrack) clear_cues() {
	for mut cue in t.cues_.cues_ {
		if owner := cue.track_ {
			if voidptr(owner) == voidptr(&t) {
				cue.track_ = none
			}
		}
	}
	t.cues_.cues_.clear()
}

pub fn (mut t TextTrack) set_media_element(media_element &HTMLMediaElement) {
	t.media_element_ = media_element
}

fn (t &TextTrack) media_element() ?&HTMLMediaElement {
	return t.media_element_
}

// https://html.spec.whatwg.org/multipage/media.html#attr-track-kind
pub fn text_track_kind_from_string(value string) TextTrackKind {
	normalized := value.to_lower_ascii()
	if normalized.len == 0 || normalized == 'subtitles' {
		return .subtitles
	}
	if normalized == 'captions' {
		return .captions
	}
	if normalized == 'descriptions' {
		return .descriptions
	}
	if normalized == 'chapters' {
		return .chapters
	}
	if normalized == 'metadata' {
		return .metadata
	}
	return .metadata
}

// --- TextTrackObserver (HTML/TextTrackObserver.h) ---
pub type TrackReadinessObserver = fn(TextTrackReadinessState)

@[heap]
pub struct TextTrackObserver {
mut:
	text_track_               &TextTrack = unsafe { nil }
	track_readiness_observer_ ?TrackReadinessObserver
}

pub fn TextTrackObserver.create(mut text_track TextTrack) &TextTrackObserver {
	mut observer := &TextTrackObserver{
		text_track_: text_track
	}
	text_track.register_observer(observer)
	return observer
}

pub fn (o &TextTrackObserver) track_readiness_observer() ?TrackReadinessObserver {
	return o.track_readiness_observer_
}

pub fn (mut o TextTrackObserver) set_track_readiness_observer(callback ?TrackReadinessObserver) {
	o.track_readiness_observer_ = callback
}

// C++ unregisters on GC finalize; this port has no finalizer, so callers detach explicitly.
pub fn (mut o TextTrackObserver) finalize() {
	mut track := o.text_track_
	track.unregister_observer(o)
}

// --- TextTrackCue (HTML/TextTrackCue.h) ---
@[heap]
pub struct TextTrackCue {
	dom.EventTarget
mut:
	track_         ?&TextTrack
	identifier_    string
	start_time_    f64
	end_time_      f64
	pause_on_exit_ bool
	text_          string
}

pub fn TextTrackCue.create(start_time f64, end_time f64, text string) !&TextTrackCue {
	if end_time == math.inf(-1) || math.is_nan(end_time) {
		return error('Value is negative infinity or NaN')
	}
	return &TextTrackCue{
		EventTarget: dom.EventTarget{}
		start_time_: start_time
		end_time_: end_time
		text_: text
	}
}

pub fn (c &TextTrackCue) track() ?&TextTrack {
	return c.track_
}

// https://html.spec.whatwg.org/multipage/media.html#text-track-cue-identifier
pub fn (c &TextTrackCue) id() string {
	return c.identifier_
}

pub fn (mut c TextTrackCue) set_id(id string) {
	c.identifier_ = id
}

pub fn (c &TextTrackCue) start_time() f64 {
	return c.start_time_
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrackcue-starttime
pub fn (mut c TextTrackCue) set_start_time(start_time f64) {
	// On setting, the text track cue start time must be set to the new value, interpreted in seconds;
	c.start_time_ = start_time
	c.run_time_marches_on_if_needed()
}

pub fn (c &TextTrackCue) end_time() f64 {
	return c.end_time_
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrackcue-endtime
pub fn (mut c TextTrackCue) set_end_time(end_time f64) ! {
	// On setting, if the new value is negative Infinity or a NaN value, then throw a TypeError exception.
	if end_time == math.inf(-1) || math.is_nan(end_time) {
		return error('Value is negative infinity or NaN')
	}
	// Otherwise, the text track cue end time must be set to the new value.
	c.end_time_ = end_time
	c.run_time_marches_on_if_needed()
}

fn (c &TextTrackCue) run_time_marches_on_if_needed() {
	track := c.track_ or { return }
	media_element := track.media_element() or { return }
	if media_element.show_poster() {
		return
	}
	mut mutable_media_element := unsafe { &HTMLMediaElement(media_element) }
	mutable_media_element.time_marches_on(.other)
}

pub fn (c &TextTrackCue) pause_on_exit() bool {
	return c.pause_on_exit_
}

pub fn (mut c TextTrackCue) set_pause_on_exit(pause_on_exit bool) {
	c.pause_on_exit_ = pause_on_exit
}

pub fn (c &TextTrackCue) text() string {
	return c.text_
}

pub fn (mut c TextTrackCue) set_text(text string) {
	c.text_ = text
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttrackcue-onenter
pub fn (c &TextTrackCue) onenter() ?&dom.CallbackType {
	return c.event_handler_attribute(event_enter)
}

pub fn (mut c TextTrackCue) set_onenter(event_handler ?&dom.CallbackType) {
	c.set_event_handler_attribute(event_enter, event_handler)
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttrackcue-onexit
pub fn (c &TextTrackCue) onexit() ?&dom.CallbackType {
	return c.event_handler_attribute(event_exit)
}

pub fn (mut c TextTrackCue) set_onexit(event_handler ?&dom.CallbackType) {
	c.set_event_handler_attribute(event_exit, event_handler)
}

// --- TextTrackCueList (HTML/TextTrackCueList.h) ---
@[heap]
pub struct TextTrackCueList {
	dom.EventTarget
mut:
	cues_ []&TextTrackCue
}

pub fn (mut l TextTrackCueList) add_cue(cue &TextTrackCue) {
	l.cues_ << cue
}

// The indexed-property getter (internal_get_own_property): the indexth cue in the list.
// https://html.spec.whatwg.org/multipage/media.html#dom-texttrackcuelist-item
pub fn (l &TextTrackCueList) item(index int) ?&TextTrackCue {
	if index >= 0 && index < l.cues_.len {
		return l.cues_[index]
	}
	return none
}

pub fn (list &TextTrackCueList) internal_get_own_property(property_name dom.JSValue) ?&TextTrackCue {
	if property_name.kind != .number
		|| !(property_name.number_data >= 0 && property_name.number_data < f64(list.length())) {
		return none
	}
	index := int(property_name.number_data)
	if f64(index) != property_name.number_data {
		return none
	}
	return list.item(index)
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrackcuelist-length
pub fn (l &TextTrackCueList) length() int {
	return l.cues_.len
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttrackcuelist-getcuebyid
pub fn (l &TextTrackCueList) get_cue_by_id(id string) ?&TextTrackCue {
	// If the argument is the empty string, then the method must return null.
	if id.len == 0 {
		return none
	}
	// Return the first cue whose identifier is id, if any, or null otherwise.
	for cue in l.cues_ {
		if cue.id() == id {
			return cue
		}
	}
	return none
}

// --- TextTrackList (HTML/TextTrackList.h) ---
@[heap]
pub struct TextTrackList {
	dom.EventTarget
mut:
	text_tracks_ []&TextTrack
}

pub fn (mut l TextTrackList) add_track(track &TextTrack) {
	l.text_tracks_ << track
}

// The indexed-property getter (internal_get_own_property): the indexth track in the list.
// https://html.spec.whatwg.org/multipage/media.html#dom-texttracklist-item
pub fn (l &TextTrackList) item(index int) ?&TextTrack {
	if index >= 0 && index < l.text_tracks_.len {
		return l.text_tracks_[index]
	}
	return none
}

pub fn (list &TextTrackList) internal_get_own_property(property_name dom.JSValue) ?&TextTrack {
	if property_name.kind != .number
		|| !(property_name.number_data >= 0 && property_name.number_data < f64(list.length())) {
		return none
	}
	index := int(property_name.number_data)
	if f64(index) != property_name.number_data {
		return none
	}
	return list.item(index)
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttracklist-length
pub fn (l &TextTrackList) length() int {
	return l.text_tracks_.len
}

// https://html.spec.whatwg.org/multipage/media.html#dom-texttracklist-gettrackbyid
pub fn (l &TextTrackList) get_track_by_id(id string) ?&TextTrack {
	// Return the first TextTrack whose id would return a value equal to id.
	for text_track in l.text_tracks_ {
		if text_track.id() == id {
			return text_track
		}
	}
	// When no tracks match, return null.
	return none
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttracklist-onchange
pub fn (l &TextTrackList) onchange() ?&dom.CallbackType {
	return l.event_handler_attribute(event_change)
}

pub fn (mut l TextTrackList) set_onchange(event_handler ?&dom.CallbackType) {
	l.set_event_handler_attribute(event_change, event_handler)
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttracklist-onaddtrack
pub fn (l &TextTrackList) onaddtrack() ?&dom.CallbackType {
	return l.event_handler_attribute(event_addtrack)
}

pub fn (mut l TextTrackList) set_onaddtrack(event_handler ?&dom.CallbackType) {
	l.set_event_handler_attribute(event_addtrack, event_handler)
}

// https://html.spec.whatwg.org/multipage/media.html#handler-texttracklist-onremovetrack
pub fn (l &TextTrackList) onremovetrack() ?&dom.CallbackType {
	return l.event_handler_attribute(event_removetrack)
}

pub fn (mut l TextTrackList) set_onremovetrack(event_handler ?&dom.CallbackType) {
	l.set_event_handler_attribute(event_removetrack, event_handler)
}
