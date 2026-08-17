// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorEncryptedMediaExtensionsPartial.cpp and its IDL.
module encryptedmediaextensions

import dom
import html

@[heap]
pub struct MediaKeySystemAccessPromise {
mut:
	state_  dom.PromiseState
	value_  ?&MediaKeySystemAccess
	reason_ string
}

pub fn MediaKeySystemAccessPromise.pending() &MediaKeySystemAccessPromise {
	return &MediaKeySystemAccessPromise{
		value_: none
	}
}

pub fn (promise &MediaKeySystemAccessPromise) state() dom.PromiseState {
	return promise.state_
}

pub fn (promise &MediaKeySystemAccessPromise) value() ?&MediaKeySystemAccess {
	return promise.value_
}

pub fn (promise &MediaKeySystemAccessPromise) reason() string {
	return promise.reason_
}

fn (mut promise MediaKeySystemAccessPromise) resolve(value &MediaKeySystemAccess) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .fulfilled
	promise.value_ = value
}

fn (mut promise MediaKeySystemAccessPromise) reject(reason string) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .rejected
	promise.reason_ = reason
}

pub struct NavigatorEncryptedMediaExtensionsContext {
pub:
	encrypted_media_allowed bool = true
	origin                  dom.Origin
	document                ?&dom.Document
	event_loop              ?&html.EventLoop
}

@[heap]
pub struct NavigatorEncryptedMediaExtensionsPartial {
	context NavigatorEncryptedMediaExtensionsContext
}

pub fn NavigatorEncryptedMediaExtensionsPartial.create(context NavigatorEncryptedMediaExtensionsContext) &NavigatorEncryptedMediaExtensionsPartial {
	return &NavigatorEncryptedMediaExtensionsPartial{
		context: context
	}
}

// https://w3c.github.io/encrypted-media/#dom-navigator-requestmediakeysystemaccess
pub fn (navigator &NavigatorEncryptedMediaExtensionsPartial) request_media_key_system_access(key_system string, supported_configurations []MediaKeySystemConfiguration) !&MediaKeySystemAccessPromise {
	if !navigator.context.encrypted_media_allowed {
		return error('SecurityError: This document is not allowed to use the encrypted-media feature')
	}
	mut promise := MediaKeySystemAccessPromise.pending()
	if key_system.len == 0 {
		promise.reject('TypeError: keySystem must not be empty')
		return promise
	}
	if supported_configurations.len == 0 {
		promise.reject('TypeError: supportedConfigurations must not be empty')
		return promise
	}
	origin := navigator.context.origin
	// WebIDL sequence/dictionary conversion produces values independent of the
	// caller. V arrays share backing storage by default, so make that copy
	// explicit before the deferred algorithm captures the candidates.
	configurations := supported_configurations.map(it.clone())
	html.queue_a_task(.media_capabilities, navigator.context.event_loop, none, fn [key_system, configurations, origin, promise] () {
		// Match Algorithms.cpp's two distinct steps: reject unsupported names,
		// then call the infallible factory for the supported key system.
		if !is_supported_key_system(key_system) {
			mut mutable_promise := unsafe { &MediaKeySystemAccessPromise(promise) }
			mutable_promise.reject('NotSupportedError: Unsupported key system')
			return
		}
		implementation := key_system_from_string(key_system)
		for candidate_configuration in configurations {
			supported := get_supported_configuration(implementation, candidate_configuration,
				origin) or { continue }
			configuration := supported.configuration or { continue }
			access := MediaKeySystemAccess.create(key_system, configuration, implementation)
			mut mutable_promise := unsafe { &MediaKeySystemAccessPromise(promise) }
			mutable_promise.resolve(access)
			return
		}
		mut mutable_promise := unsafe { &MediaKeySystemAccessPromise(promise) }
		mutable_promise.reject('NotSupportedError: No supported configurations found for the requested key system')
	})
	return promise
}
