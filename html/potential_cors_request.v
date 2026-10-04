// Copyright (c) 2023, Srikavin Ramkumar <me@srikavin.me>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/PotentialCORSRequest.cpp.
module html

import dom
import fetch

pub enum SameOriginFallbackFlag {
	no
	yes
}

pub enum PotentialCORSRequestMode {
	same_origin
	cors
	no_cors
}

pub type RequestDestination = dom.RequestDestination

// This is the subset of Fetch::Infrastructure::Request initialized by the
// create-a-potential-CORS-request algorithm.
pub struct PotentialCORSRequest {
pub:
	url                 dom.URL
	destination         ?RequestDestination
	mode                PotentialCORSRequestMode
	credentials_mode    CredentialsMode
	use_url_credentials bool
	is_module_preload   bool
	cryptographic_nonce_metadata string
	integrity_metadata  string
	parser_metadata     fetch.ParserMetadata = .not_parser_inserted
	referrer_policy     string
	priority            fetch.Priority = .auto
}

pub struct PreloadKey {
pub:
	url              dom.URL
	destination      ?RequestDestination
	mode             PotentialCORSRequestMode
	credentials_mode CredentialsMode
}

// https://html.spec.whatwg.org/multipage/links.html#create-a-preload-key
pub fn PreloadKey.create(request PotentialCORSRequest) PreloadKey {
	return PreloadKey{
		url:              request.url
		destination:      request.destination
		mode:             request.mode
		credentials_mode: request.credentials_mode
	}
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#create-a-potential-cors-request
pub fn create_potential_cors_request(url dom.URL, destination ?RequestDestination, cors_attribute_state CORSSettingAttribute, same_origin_fallback_flag SameOriginFallbackFlag) PotentialCORSRequest {
	mut mode := if cors_attribute_state == .no_cors {
		PotentialCORSRequestMode.no_cors
	} else {
		PotentialCORSRequestMode.cors
	}
	if same_origin_fallback_flag == .yes && mode == .no_cors {
		mode = .same_origin
	}

	mut credentials_mode := CredentialsMode.include
	if cors_attribute_state == .anonymous {
		credentials_mode = .same_origin
	}

	return PotentialCORSRequest{
		url:                 url
		destination:         destination
		mode:                mode
		credentials_mode:    credentials_mode
		use_url_credentials: true
	}
}
