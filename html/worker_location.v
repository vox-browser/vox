// Copyright (c) 2022, Ben Abraham <ben.d.abraham@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/WorkerLocation.cpp.
// C++ reads its WorkerGlobalScope's url() live. WorkerGlobalScope is not translated in this port,
// so WorkerLocation holds the dom.URL it reflects directly; the getter logic is otherwise a
// faithful translation.
module html

import dom

@[heap]
pub struct WorkerLocation {
mut:
	url_ dom.URL
}

pub fn WorkerLocation.create(url dom.URL) &WorkerLocation {
	return &WorkerLocation{
		url_: url
	}
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-href
pub fn (location &WorkerLocation) href() string {
	// The href getter steps are to return this's WorkerGlobalScope object's url, serialized.
	return location.url_.serialize()
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-origin
pub fn (location &WorkerLocation) origin() string {
	// The origin getter steps are to return the serialization of this's url's origin.
	return location.url_.origin().serialize()
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-protocol
pub fn (location &WorkerLocation) protocol() string {
	// The protocol getter steps are to return this's url's scheme, followed by ":".
	return '${location.url_.scheme()}:'
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-host
pub fn (location &WorkerLocation) host() string {
	// 1. Let url be this's url.
	url := location.url_
	// 2. If url's host is null, return the empty string.
	if url.host() == none {
		return ''
	}
	// 3. If url's port is null, return url's host, serialized.
	port := url.port() or { return url.serialized_host() }
	// 4. Return url's host, serialized, followed by ":" and url's port, serialized.
	return '${url.serialized_host()}:${port}'
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-hostname
pub fn (location &WorkerLocation) hostname() string {
	// 1. Let host be this's url's host.
	// 2. If host is null, return the empty string.
	host := location.url_.host() or { return '' }
	// 3. Return host, serialized.
	return host
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-port
pub fn (location &WorkerLocation) port() string {
	// 1. Let port be this's url's port.
	// 2. If port is null, return the empty string.
	port := location.url_.port() or { return '' }
	// 3. Return port, serialized.
	return port.str()
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-pathname
pub fn (location &WorkerLocation) pathname() string {
	// The pathname getter steps are to return the result of URL path serializing this's url.
	return location.url_.serialize_path()
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-search
pub fn (location &WorkerLocation) search() string {
	// 1. Let query be this's url's query.
	// 2. If query is either null or the empty string, return the empty string.
	query := location.url_.query() or { return '' }
	if query.len == 0 {
		return ''
	}
	// 3. Return "?", followed by query.
	return '?${query}'
}

// https://html.spec.whatwg.org/multipage/workers.html#dom-workerlocation-hash
pub fn (location &WorkerLocation) hash() string {
	// 1. Let fragment be this's url's fragment.
	// 2. If fragment is either null or the empty string, return the empty string.
	fragment := location.url_.fragment() or { return '' }
	if fragment.len == 0 {
		return ''
	}
	// 3. Return "#", followed by fragment.
	return '#${fragment}'
}
