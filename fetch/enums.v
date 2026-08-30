// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Fetch's generated binding enums and infrastructure enums have the same V
// representation except where an internal-only value must be rejected.
module fetch

pub fn from_bindings_referrer_policy(policy string) string {
	return policy
}

pub fn from_bindings_request_mode(mode Mode) Mode {
	if mode == .websocket {
		panic('websocket is not a RequestMode binding value')
	}
	return mode
}

pub fn from_bindings_request_credentials(credentials CredentialsMode) CredentialsMode {
	return credentials
}

pub fn from_bindings_request_cache(cache CacheMode) CacheMode {
	return cache
}

pub fn from_bindings_request_redirect(redirect RedirectMode) RedirectMode {
	return redirect
}

pub fn from_bindings_request_priority(priority Priority) Priority {
	return priority
}

pub fn to_bindings_referrer_policy(policy string) string {
	return policy
}

pub fn to_bindings_request_destination(destination ?Destination) string {
	value := destination or { return '' }
	if value in [Destination.service_worker, .web_identity] {
		panic('${value} is not observable as a RequestDestination binding value')
	}
	return request_destination_to_string(value)
}

pub fn to_bindings_request_mode(mode Mode) Mode {
	if mode == .websocket {
		panic('websocket is not observable as a RequestMode binding value')
	}
	return mode
}

pub fn to_bindings_request_credentials(credentials CredentialsMode) CredentialsMode {
	return credentials
}

pub fn to_bindings_request_cache(cache CacheMode) CacheMode {
	return cache
}

pub fn to_bindings_request_redirect(redirect RedirectMode) RedirectMode {
	return redirect
}

pub fn to_bindings_response_type(response_type ResponseType) ResponseType {
	return response_type
}

pub fn initiator_type_to_string(initiator InitiatorType) string {
	return match initiator {
		.audio { 'audio' }
		.beacon { 'beacon' }
		.body { 'body' }
		.css { 'css' }
		.early_hint { 'early-hints' }
		.embed { 'embed' }
		.fetch { 'fetch' }
		.font { 'font' }
		.frame { 'frame' }
		.iframe { 'iframe' }
		.image { 'image' }
		.img { 'img' }
		.input { 'input' }
		.link { 'link' }
		.object { 'object' }
		.ping { 'ping' }
		.script { 'script' }
		.track { 'track' }
		.video { 'video' }
		.xml_http_request { 'xmlhttprequest' }
		.other { 'other' }
	}
}
