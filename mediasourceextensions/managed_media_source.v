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
	mut source := &ManagedMediaSource{
		MediaSource: MediaSource{
			EventTarget: dom.EventTarget{}
			source_buffers_: SourceBufferList.create_internal()
			active_source_buffers_: SourceBufferList.create_internal()
		}
	}
	mut source_buffers := source.source_buffers_
	source_buffers.set_media_source(&source.MediaSource)
	mut active_source_buffers := source.active_source_buffers_
	active_source_buffers.set_media_source(&source.MediaSource)
	return source
}

pub fn ManagedMediaSource.construct_impl() !&ManagedMediaSource {
	return ManagedMediaSource.create()
}

pub fn ManagedMediaSource.create_for_constructor(relevant_global_object &dom.EventTarget) &ManagedMediaSource {
	mut source := ManagedMediaSource.create()
	source.relevant_global_object_ = relevant_global_object
	return source
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
