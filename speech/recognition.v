// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SpeechRecognition, SpeechRecognitionEvent, and
// SpeechRecognitionPhrase .h/.cpp/.idl units.
module speech

import dom

@[heap]
pub struct SpeechRecognition {
	dom.EventTarget
mut:
	grammars_         &SpeechGrammarList = unsafe { nil }
	lang_             string
	continuous_       bool
	interim_results_  bool
	max_alternatives_ u32 = 1
}

pub fn SpeechRecognition.new() &SpeechRecognition {
	return SpeechRecognition.create()
}

pub fn SpeechRecognition.construct_impl() &SpeechRecognition {
	return SpeechRecognition.create()
}

pub fn SpeechRecognition.create() &SpeechRecognition {
	return &SpeechRecognition{
		EventTarget: dom.EventTarget{}
		grammars_: SpeechGrammarList.create()
	}
}

pub fn SpeechRecognition.grammars_offset() uint {
	return uint(__offsetof(SpeechRecognition, grammars_))
}

pub fn (recognition &SpeechRecognition) grammars() &SpeechGrammarList {
	return recognition.grammars_
}

pub fn (mut recognition SpeechRecognition) set_grammars(grammars &SpeechGrammarList) {
	recognition.grammars_ = grammars
}

pub fn (recognition &SpeechRecognition) lang() string {
	return recognition.lang_
}

pub fn (mut recognition SpeechRecognition) set_lang(lang string) {
	recognition.lang_ = lang
}

pub fn (recognition &SpeechRecognition) continuous() bool {
	return recognition.continuous_
}

pub fn (mut recognition SpeechRecognition) set_continuous(value bool) {
	recognition.continuous_ = value
}

pub fn (recognition &SpeechRecognition) interim_results() bool {
	return recognition.interim_results_
}

pub fn (mut recognition SpeechRecognition) set_interim_results(value bool) {
	recognition.interim_results_ = value
}

pub fn (recognition &SpeechRecognition) max_alternatives() u32 {
	return recognition.max_alternatives_
}

pub fn (mut recognition SpeechRecognition) set_max_alternatives(value u32) {
	recognition.max_alternatives_ = value
}

fn (recognition &SpeechRecognition) set_handler(name string, value ?&dom.CallbackType) {
	recognition.EventTarget.set_event_handler_attribute(name, value)
}

fn (recognition &SpeechRecognition) handler(name string) ?&dom.CallbackType {
	return recognition.EventTarget.event_handler_attribute(name)
}

pub fn (r &SpeechRecognition) set_onaudiostart(v ?&dom.CallbackType) {
	r.set_handler('audiostart', v)
}

pub fn (r &SpeechRecognition) onaudiostart() ?&dom.CallbackType {
	return r.handler('audiostart')
}

pub fn (r &SpeechRecognition) set_onsoundstart(v ?&dom.CallbackType) {
	r.set_handler('soundstart', v)
}

pub fn (r &SpeechRecognition) onsoundstart() ?&dom.CallbackType {
	return r.handler('soundstart')
}

pub fn (r &SpeechRecognition) set_onspeechstart(v ?&dom.CallbackType) {
	r.set_handler('speechstart', v)
}

pub fn (r &SpeechRecognition) onspeechstart() ?&dom.CallbackType {
	return r.handler('speechstart')
}

pub fn (r &SpeechRecognition) set_onspeechend(v ?&dom.CallbackType) {
	r.set_handler('speechend', v)
}

pub fn (r &SpeechRecognition) onspeechend() ?&dom.CallbackType {
	return r.handler('speechend')
}

pub fn (r &SpeechRecognition) set_onsoundend(v ?&dom.CallbackType) {
	r.set_handler('soundend', v)
}

pub fn (r &SpeechRecognition) onsoundend() ?&dom.CallbackType {
	return r.handler('soundend')
}

pub fn (r &SpeechRecognition) set_onaudioend(v ?&dom.CallbackType) {
	r.set_handler('audioend', v)
}

pub fn (r &SpeechRecognition) onaudioend() ?&dom.CallbackType {
	return r.handler('audioend')
}

pub fn (r &SpeechRecognition) set_onresult(v ?&dom.CallbackType) {
	r.set_handler('result', v)
}

pub fn (r &SpeechRecognition) onresult() ?&dom.CallbackType {
	return r.handler('result')
}

pub fn (r &SpeechRecognition) set_onnomatch(v ?&dom.CallbackType) {
	r.set_handler('nomatch', v)
}

pub fn (r &SpeechRecognition) onnomatch() ?&dom.CallbackType {
	return r.handler('nomatch')
}

pub fn (r &SpeechRecognition) set_onerror(v ?&dom.CallbackType) {
	r.set_handler('error', v)
}

pub fn (r &SpeechRecognition) onerror() ?&dom.CallbackType {
	return r.handler('error')
}

pub fn (r &SpeechRecognition) set_onstart(v ?&dom.CallbackType) {
	r.set_handler('start', v)
}

pub fn (r &SpeechRecognition) onstart() ?&dom.CallbackType {
	return r.handler('start')
}

pub fn (r &SpeechRecognition) set_onend(v ?&dom.CallbackType) {
	r.set_handler('end', v)
}

pub fn (r &SpeechRecognition) onend() ?&dom.CallbackType {
	return r.handler('end')
}

pub struct SpeechRecognitionEventInit {
pub:
	bubbles      bool
	cancelable   bool
	composed     bool
	result_index u32
	results      &SpeechRecognitionResultList = unsafe { nil }
}

@[heap]
pub struct SpeechRecognitionEvent {
	dom.Event
mut:
	result_index_ u32
	results_      &SpeechRecognitionResultList = unsafe { nil }
}

pub fn SpeechRecognitionEvent.new(event_name string, init SpeechRecognitionEventInit) &SpeechRecognitionEvent {
	return SpeechRecognitionEvent.construct_impl(event_name, init)
}

pub fn SpeechRecognitionEvent.construct_impl(event_name string, init SpeechRecognitionEventInit) &SpeechRecognitionEvent {
	return SpeechRecognitionEvent.create(event_name, init)
}

pub fn SpeechRecognitionEvent.create(event_name string, init SpeechRecognitionEventInit) &SpeechRecognitionEvent {
	return SpeechRecognitionEvent.create_with_timestamp(event_name, init, 0)
}

pub fn SpeechRecognitionEvent.create_with_timestamp(event_name string, init SpeechRecognitionEventInit, time_stamp f64) &SpeechRecognitionEvent {
	base := dom.Event.new_with_init(event_name, dom.EventInit{
		bubbles: init.bubbles
		cancelable: init.cancelable
		composed: init.composed
	})
	mut event := &SpeechRecognitionEvent{
		Event: dom.Event{
			...*base
			interface_: .speech_recognition_event
		}
		result_index_: init.result_index
		results_: init.results
	}
	event.set_time_stamp(time_stamp)
	return event
}

pub fn SpeechRecognitionEvent.results_offset() uint {
	return uint(__offsetof(SpeechRecognitionEvent, results_))
}

pub fn (event &SpeechRecognitionEvent) result_index() u32 {
	return event.result_index_
}

pub fn (event &SpeechRecognitionEvent) results() &SpeechRecognitionResultList {
	return event.results_
}

pub struct SpeechRecognitionPhrase {
mut:
	phrase_ string
	boost_  f32 = 1
}

pub fn SpeechRecognitionPhrase.new(phrase string, boost f32) &SpeechRecognitionPhrase {
	return SpeechRecognitionPhrase.create(phrase, boost)
}

pub fn SpeechRecognitionPhrase.construct_impl(phrase string, boost f32) &SpeechRecognitionPhrase {
	return SpeechRecognitionPhrase.create(phrase, boost)
}

pub fn SpeechRecognitionPhrase.create(phrase string, boost f32) &SpeechRecognitionPhrase {
	return &SpeechRecognitionPhrase{
		phrase_: phrase
		boost_: boost
	}
}

pub fn SpeechRecognitionPhrase.new_with_default_boost(phrase string) &SpeechRecognitionPhrase {
	return SpeechRecognitionPhrase.create(phrase, 1)
}

pub fn (recognition_phrase &SpeechRecognitionPhrase) phrase() string {
	return recognition_phrase.phrase_
}

pub fn (recognition_phrase &SpeechRecognitionPhrase) boost() f32 {
	return recognition_phrase.boost_
}
