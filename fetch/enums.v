// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Fetch's generated binding enums and infrastructure enums have the same V
// representation except where an internal-only value must be rejected.
module fetch

fn referrer_policy_from_bindings(policy string) string {
	return policy
}

fn request_mode_from_bindings(mode Mode) Mode {
	if mode == .websocket {
		panic('websocket is not a RequestMode binding value')
	}
	return mode
}

fn request_credentials_from_bindings(credentials CredentialsMode) CredentialsMode {
	return credentials
}

fn request_cache_from_bindings(cache CacheMode) CacheMode {
	return cache
}

fn request_redirect_from_bindings(redirect RedirectMode) RedirectMode {
	return redirect
}

fn request_priority_from_bindings(priority Priority) Priority {
	return priority
}

fn referrer_policy_to_bindings(policy string) string {
	return policy
}

fn request_destination_to_bindings(destination ?Destination) string {
	value := destination or { return '' }
	if value in [Destination.service_worker, .web_identity] {
		panic('${value} is not observable as a RequestDestination binding value')
	}
	return request_destination_to_string(value)
}

fn request_mode_to_bindings(mode Mode) Mode {
	if mode == .websocket {
		panic('websocket is not observable as a RequestMode binding value')
	}
	return mode
}

fn request_credentials_to_bindings(credentials CredentialsMode) CredentialsMode {
	return credentials
}

fn request_cache_to_bindings(cache CacheMode) CacheMode {
	return cache
}

fn request_redirect_to_bindings(redirect RedirectMode) RedirectMode {
	return redirect
}

fn response_type_to_bindings(response_type ResponseType) ResponseType {
	return response_type
}

// Compatibility names retained for translated callers that still use the
// pre-Wrappable Fetch enum helpers.
pub fn from_bindings_referrer_policy(policy string) string {
	return referrer_policy_from_bindings(policy)
}

pub fn from_bindings_request_mode(mode Mode) Mode {
	return request_mode_from_bindings(mode)
}

pub fn from_bindings_request_credentials(credentials CredentialsMode) CredentialsMode {
	return request_credentials_from_bindings(credentials)
}

pub fn from_bindings_request_cache(cache CacheMode) CacheMode {
	return request_cache_from_bindings(cache)
}

pub fn from_bindings_request_redirect(redirect RedirectMode) RedirectMode {
	return request_redirect_from_bindings(redirect)
}

pub fn from_bindings_request_priority(priority Priority) Priority {
	return request_priority_from_bindings(priority)
}

pub fn to_bindings_referrer_policy(policy string) string {
	return referrer_policy_to_bindings(policy)
}

pub fn to_bindings_request_destination(destination ?Destination) string {
	return request_destination_to_bindings(destination)
}

pub fn to_bindings_request_mode(mode Mode) Mode {
	return request_mode_to_bindings(mode)
}

pub fn to_bindings_request_credentials(credentials CredentialsMode) CredentialsMode {
	return request_credentials_to_bindings(credentials)
}

pub fn to_bindings_request_cache(cache CacheMode) CacheMode {
	return request_cache_to_bindings(cache)
}

pub fn to_bindings_request_redirect(redirect RedirectMode) RedirectMode {
	return request_redirect_to_bindings(redirect)
}

pub fn to_bindings_response_type(response_type ResponseType) ResponseType {
	return response_type_to_bindings(response_type)
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
