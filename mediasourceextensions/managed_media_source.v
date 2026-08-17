// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ManagedMediaSource.{h,cpp,idl}.
module mediasourceextensions

import dom

@[heap]
pub struct ManagedMediaSource {
	MediaSource
}

pub fn ManagedMediaSource.create() &ManagedMediaSource {
	return &ManagedMediaSource{
		MediaSource: MediaSource{
			EventTarget: dom.EventTarget{}
		}
	}
}

pub fn ManagedMediaSource.construct_impl() !&ManagedMediaSource {
	return ManagedMediaSource.create()
}

pub fn (source &ManagedMediaSource) set_onstartstreaming(handler ?&dom.CallbackType) {
	source.set_event_handler_attribute('startstreaming', handler)
}

pub fn (source &ManagedMediaSource) onstartstreaming() ?&dom.CallbackType {
	return source.event_handler_attribute('startstreaming')
}

pub fn (source &ManagedMediaSource) set_onendstreaming(handler ?&dom.CallbackType) {
	source.set_event_handler_attribute('endstreaming', handler)
}

pub fn (source &ManagedMediaSource) onendstreaming() ?&dom.CallbackType {
	return source.event_handler_attribute('endstreaming')
}

// streaming remains [FIXME] in the current upstream IDL, so it is not exposed
// as a fabricated value.
