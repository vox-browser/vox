// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SpeechSynthesis, SpeechSynthesisUtterance, and
// SpeechSynthesisVoice .h/.cpp/.idl units.
module speech

import dom

@[heap]
pub struct SpeechSynthesisVoice {
mut:
	voice_uri_     string
	name_          string
	lang_          string
	local_service_ bool
	is_default_    bool
}

pub fn SpeechSynthesisVoice.create() &SpeechSynthesisVoice {
	return &SpeechSynthesisVoice{}
}

pub fn SpeechSynthesisVoice.from_platform(voice_uri string, name string, lang string, local_service bool, is_default bool) &SpeechSynthesisVoice {
	return &SpeechSynthesisVoice{
		voice_uri_: voice_uri
		name_: name
		lang_: lang
		local_service_: local_service
		is_default_: is_default
	}
}

pub fn (voice &SpeechSynthesisVoice) voice_uri() string {
	return voice.voice_uri_
}

pub fn (voice &SpeechSynthesisVoice) name() string {
	return voice.name_
}

pub fn (voice &SpeechSynthesisVoice) lang() string {
	return voice.lang_
}

pub fn (voice &SpeechSynthesisVoice) local_service() bool {
	return voice.local_service_
}

pub fn (voice &SpeechSynthesisVoice) is_default() bool {
	return voice.is_default_
}

@[heap]
pub struct SpeechSynthesis {
	dom.EventTarget
mut:
	pending_  bool
	speaking_ bool
	paused_   bool
	voices_   []&SpeechSynthesisVoice
}

pub fn SpeechSynthesis.create() &SpeechSynthesis {
	return &SpeechSynthesis{
		EventTarget: dom.EventTarget{}
	}
}

pub fn (synthesis &SpeechSynthesis) pending() bool {
	return synthesis.pending_
}

pub fn (synthesis &SpeechSynthesis) speaking() bool {
	return synthesis.speaking_
}

pub fn (synthesis &SpeechSynthesis) paused() bool {
	return synthesis.paused_
}

pub fn (_ &SpeechSynthesis) cancel() {}

pub fn (synthesis &SpeechSynthesis) get_voices() []&SpeechSynthesisVoice {
	return synthesis.voices_.clone()
}

pub fn (mut synthesis SpeechSynthesis) replace_voices_from_platform(voices []&SpeechSynthesisVoice) {
	synthesis.voices_ = voices.clone()
}

pub fn (synthesis &SpeechSynthesis) set_onvoiceschanged(value ?&dom.CallbackType) {
	synthesis.EventTarget.set_event_handler_attribute('voiceschanged', value)
}

pub fn (synthesis &SpeechSynthesis) onvoiceschanged() ?&dom.CallbackType {
	return synthesis.EventTarget.event_handler_attribute('voiceschanged')
}

@[heap]
pub struct SpeechSynthesisUtterance {
	dom.EventTarget
mut:
	text_   string
	lang_   string
	voice_  ?&SpeechSynthesisVoice
	volume_ f32 = 1
	rate_   f32 = 1
	pitch_  f32 = 1
}

pub fn SpeechSynthesisUtterance.new(text string) &SpeechSynthesisUtterance {
	return SpeechSynthesisUtterance.create(text)
}

pub fn SpeechSynthesisUtterance.construct_impl(text string) &SpeechSynthesisUtterance {
	return SpeechSynthesisUtterance.create(text)
}

pub fn SpeechSynthesisUtterance.create(text string) &SpeechSynthesisUtterance {
	return &SpeechSynthesisUtterance{
		EventTarget: dom.EventTarget{}
		text_: text
	}
}

pub fn SpeechSynthesisUtterance.voice_offset() uint {
	return uint(__offsetof(SpeechSynthesisUtterance, voice_))
}

pub fn (u &SpeechSynthesisUtterance) text() string {
	return u.text_
}

pub fn (mut u SpeechSynthesisUtterance) set_text(value string) {
	u.text_ = value
}

pub fn (u &SpeechSynthesisUtterance) lang() string {
	return u.lang_
}

pub fn (mut u SpeechSynthesisUtterance) set_lang(value string) {
	u.lang_ = value
}

pub fn (u &SpeechSynthesisUtterance) voice() ?&SpeechSynthesisVoice {
	return u.voice_
}

pub fn (mut u SpeechSynthesisUtterance) set_voice(value ?&SpeechSynthesisVoice) {
	u.voice_ = value
}

pub fn (u &SpeechSynthesisUtterance) volume() f32 {
	return u.volume_
}

pub fn (mut u SpeechSynthesisUtterance) set_volume(value f32) {
	u.volume_ = value
}

pub fn (u &SpeechSynthesisUtterance) rate() f32 {
	return u.rate_
}

pub fn (mut u SpeechSynthesisUtterance) set_rate(value f32) {
	u.rate_ = value
}

pub fn (u &SpeechSynthesisUtterance) pitch() f32 {
	return u.pitch_
}

pub fn (mut u SpeechSynthesisUtterance) set_pitch(value f32) {
	u.pitch_ = value
}

fn (u &SpeechSynthesisUtterance) set_handler(name string, value ?&dom.CallbackType) {
	u.EventTarget.set_event_handler_attribute(name, value)
}

fn (u &SpeechSynthesisUtterance) handler(name string) ?&dom.CallbackType {
	return u.EventTarget.event_handler_attribute(name)
}

pub fn (u &SpeechSynthesisUtterance) set_onstart(v ?&dom.CallbackType) {
	u.set_handler('start', v)
}

pub fn (u &SpeechSynthesisUtterance) onstart() ?&dom.CallbackType {
	return u.handler('start')
}

pub fn (u &SpeechSynthesisUtterance) set_onend(v ?&dom.CallbackType) {
	u.set_handler('end', v)
}

pub fn (u &SpeechSynthesisUtterance) onend() ?&dom.CallbackType {
	return u.handler('end')
}

pub fn (u &SpeechSynthesisUtterance) set_onerror(v ?&dom.CallbackType) {
	u.set_handler('error', v)
}

pub fn (u &SpeechSynthesisUtterance) onerror() ?&dom.CallbackType {
	return u.handler('error')
}

pub fn (u &SpeechSynthesisUtterance) set_onpause(v ?&dom.CallbackType) {
	u.set_handler('pause', v)
}

pub fn (u &SpeechSynthesisUtterance) onpause() ?&dom.CallbackType {
	return u.handler('pause')
}

pub fn (u &SpeechSynthesisUtterance) set_onresume(v ?&dom.CallbackType) {
	u.set_handler('resume', v)
}

pub fn (u &SpeechSynthesisUtterance) onresume() ?&dom.CallbackType {
	return u.handler('resume')
}

pub fn (u &SpeechSynthesisUtterance) set_onmark(v ?&dom.CallbackType) {
	u.set_handler('mark', v)
}

pub fn (u &SpeechSynthesisUtterance) onmark() ?&dom.CallbackType {
	return u.handler('mark')
}

pub fn (u &SpeechSynthesisUtterance) set_onboundary(v ?&dom.CallbackType) {
	u.set_handler('boundary', v)
}

pub fn (u &SpeechSynthesisUtterance) onboundary() ?&dom.CallbackType {
	return u.handler('boundary')
}
