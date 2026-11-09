// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
// Copyright (c) 2024, Shannon Booth <shannon@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BroadcastChannel.{h,cpp}.
@[has_globals]
module html

import dom
import os

__global (
	html_broadcast_channels = []&BroadcastChannel{}
)

@[heap]
pub struct BroadcastChannelRepository {
mut:
	channels         map[string][]&BroadcastChannel
	next_channel_id_ u64
}

fn (mut repository BroadcastChannelRepository) next_channel_id() u64 {
	repository.next_channel_id_++
	return repository.next_channel_id_
}

pub fn BroadcastChannelRepository.create() &BroadcastChannelRepository {
	return &BroadcastChannelRepository{
		channels: map[string][]&BroadcastChannel{}
	}
}

pub fn (mut repository BroadcastChannelRepository) register_channel(channel &BroadcastChannel) {
	mut channels := repository.channels[channel.storage_key_] or { []&BroadcastChannel{} }
	for candidate in channels {
		if voidptr(candidate) == voidptr(channel) {
			return
		}
	}
	channels << channel
	repository.channels[channel.storage_key_] = channels
}

pub fn (mut repository BroadcastChannelRepository) unregister_channel(channel &BroadcastChannel) {
	for key in repository.channels.keys() {
		mut channels := repository.channels[key] or { continue }
		for index, candidate in channels {
			if voidptr(candidate) == voidptr(channel) {
				channels.delete(index)
				if channels.len == 0 {
					repository.channels.delete(key)
				} else {
					repository.channels[key] = channels
				}
				return
			}
		}
	}
}

pub fn (repository &BroadcastChannelRepository) registered_channels_for_key(key string) []&BroadcastChannel {
	channels := repository.channels[key] or { return []&BroadcastChannel{} }
	return channels.clone()
}

pub type BroadcastChannelMessageForwarder = fn (BroadcastChannelMessage)

__global (
	html_broadcast_channel_repository   &BroadcastChannelRepository
	broadcast_channel_message_forwarder ?BroadcastChannelMessageForwarder = ?BroadcastChannelMessageForwarder(none)
)

@[heap]
pub struct BroadcastChannel {
	dom.EventTarget
mut:
	channel_name_ string
	channel_id_   u64
	closed_flag_  bool
	eligible_     bool = true
	origin_       dom.Origin
	storage_key_  string
}

pub fn BroadcastChannel.construct_impl(name string) &BroadcastChannel {
	mut repository := html_broadcast_channel_repository
	channel := &BroadcastChannel{
		channel_name_: name
		channel_id_: repository.next_channel_id()
		origin_: dom.Origin{
			value: 'opaque'
		}
		storage_key_: 'default'
	}
	html_broadcast_channels << channel
	repository.register_channel(channel)
	return channel
}

pub fn (channel &BroadcastChannel) name() string {
	return channel.channel_name_
}

pub fn (channel &BroadcastChannel) channel_id() u64 {
	return channel.channel_id_
}

pub fn (channel &BroadcastChannel) is_closed() bool {
	return channel.closed_flag_
}

pub fn (channel &BroadcastChannel) is_eligible_for_messaging() bool {
	return channel.eligible_
}

// Embeddings set the storage partition and origin normally obtained from the
// relevant environment settings object.
pub fn (mut channel BroadcastChannel) set_messaging_environment(origin dom.Origin, storage_key string, eligible bool) {
	mut repository := html_broadcast_channel_repository
	repository.unregister_channel(&channel)
	channel.origin_ = origin
	channel.storage_key_ = storage_key
	channel.eligible_ = eligible
	repository.register_channel(&channel)
}

pub fn set_broadcast_channel_message_forwarder(forwarder ?BroadcastChannelMessageForwarder) {
	broadcast_channel_message_forwarder = forwarder
}

pub fn (channel &BroadcastChannel) post_message(message dom.JSValue) ! {
	if !channel.is_eligible_for_messaging() {
		return
	}
	if channel.closed_flag_ {
		return error('InvalidStateError: BroadcastChannel.postMessage() on a closed channel')
	}
	serialized := structured_serialize(message)!
	message_to_send := BroadcastChannelMessage{
		storage_key: channel.storage_key_
		channel_name: channel.channel_name_
		source_origin: channel.origin_
		serialized_message: serialized
		source_process_id: os.getpid()
		source_channel_id: channel.channel_id_
	}
	BroadcastChannel.deliver_message_locally(message_to_send)
	if forwarder := broadcast_channel_message_forwarder {
		forwarder(message_to_send)
	}
}

pub fn BroadcastChannel.deliver_message_locally(message BroadcastChannelMessage) {
	repository := html_broadcast_channel_repository
	for candidate in repository.registered_channels_for_key(message.storage_key) {
		if (message.source_process_id == os.getpid()
			&& candidate.channel_id_ == message.source_channel_id) || candidate.closed_flag_
			|| !candidate.is_eligible_for_messaging()
			|| candidate.channel_name_ != message.channel_name
			|| candidate.storage_key_ != message.storage_key {
			continue
		}
		destination := candidate
		source_origin := message.source_origin
		serialized := message.serialized_message
		queue_a_task(.dom_manipulation, main_thread_event_loop(), none, fn [destination, source_origin, serialized] () {
			if destination.closed_flag_ {
				return
			}
			data := structured_deserialize(serialized) or {
				mut error_event := MessageEvent.create('messageerror', MessageEventInit{
					origin: source_origin
				})
				error_event.set_is_trusted(true)
				event_target := unsafe { &dom.EventTarget(destination) }
				base_event := unsafe { &dom.Event(error_event) }
				event_target.dispatch_event(base_event)
				return
			}
			mut event := MessageEvent.create('message', MessageEventInit{
				data:   data
				origin: source_origin
			})
			event.set_is_trusted(true)
			event_target := unsafe { &dom.EventTarget(destination) }
			base_event := unsafe { &dom.Event(event) }
			event_target.dispatch_event(base_event)
		})
	}
}

pub fn (mut channel BroadcastChannel) close() {
	channel.closed_flag_ = true
	mut repository := html_broadcast_channel_repository
	repository.unregister_channel(&channel)
	for index, candidate in html_broadcast_channels {
		if voidptr(candidate) == voidptr(channel) {
			html_broadcast_channels.delete(index)
			break
		}
	}
}

pub fn (channel &BroadcastChannel) set_onmessage(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(channel) }.set_event_handler_attribute('message', handler)
}

pub fn (channel &BroadcastChannel) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(channel) }.event_handler_attribute('message')
}

pub fn (channel &BroadcastChannel) set_onmessageerror(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(channel) }.set_event_handler_attribute('messageerror', handler)
}

pub fn (channel &BroadcastChannel) onmessageerror() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(channel) }.event_handler_attribute('messageerror')
}
