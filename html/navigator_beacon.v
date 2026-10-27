// Copyright (c) 2023, Bastiaan van der Plaat <bastiaan.v.d.plaat@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorBeacon.{h,cpp}.
module html

import dom
import fetch
import http

pub const keepalive_maximum_size = uint(64 * 1024)

pub struct BeaconBody {
pub:
	bytes        []u8
	content_type ?string
}

pub type BeaconFetchHook = fn (&fetch.Request)

@[heap]
pub struct NavigatorBeaconContext {
pub:
	base_url dom.URL
	origin   dom.Origin
pub mut:
	queued_keepalive_bytes uint
	fetch_hook             ?BeaconFetchHook
}

pub fn NavigatorBeaconContext.create(base_url dom.URL, origin dom.Origin) &NavigatorBeaconContext {
	return &NavigatorBeaconContext{
		base_url: base_url
		origin:   origin
	}
}

pub fn (mut context NavigatorBeaconContext) send_beacon(url string, data ?BeaconBody) !bool {
	parsed_url := dom.dom_url_parse(url, context.base_url, 'UTF-8') or {
		return error('TypeError: Beacon URL ${url} is invalid.')
	}
	if parsed_url.scheme() !in ['http', 'https'] {
		return error('TypeError: Beacon URL ${url} must be either http:// or https://.')
	}
	mut mode := fetch.Mode.no_cors
	mut header_list := http.HeaderList.create()
	mut request_body := fetch.RequestBody{}
	if body := data {
		if context.queued_keepalive_bytes + uint(body.bytes.len) > keepalive_maximum_size {
			return false
		}
		request_body = fetch.RequestBody{
			kind:  .bytes
			bytes: body.bytes.clone()
		}
		if content_type := body.content_type {
			header := http.Header{'Content-Type', content_type}
			mode = .cors
			if fetch.is_cors_safelisted_request_header(header) {
				mode = .no_cors
			}
			header_list.append(header)
		}
		context.queued_keepalive_bytes += uint(body.bytes.len)
	}
	request := &fetch.Request{
		method:           'POST'
		header_list:      header_list
		body:             request_body
		keepalive:        true
		initiator_type:   .beacon
		origin:           fetch.RequestOrigin{
			is_client: false
			origin:    context.origin
		}
		mode:             mode
		credentials_mode: .include
		url_list:         [parsed_url]
	}
	if hook := context.fetch_hook {
		hook(request)
	}
	return true
}

pub fn (mut navigator Navigator) configure_beacon_context(context &NavigatorBeaconContext) {
	navigator.beacon_context_ = context
}

pub fn (mut navigator Navigator) send_beacon(url string, data ?BeaconBody) !bool {
	mut context := navigator.beacon_context_ or {
		return error('InvalidStateError: Navigator has no associated environment settings object')
	}

	return context.send_beacon(url, data)
}

pub fn navigator_beacon_partial_send_beacon(mut navigator Navigator, url string, data ?BeaconBody) !bool {
	return navigator.send_beacon(url, data)
}
