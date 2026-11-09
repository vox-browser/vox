module browsernet

import net.http
import time

// The same lazy libcurl ABI used by RequestServer. Its worker adapter owns
// only transport; redirect, filter, cookie and cache decisions stay in V.
#flag linux -lcurl
#flag windows -lcurl
#include "cancellable_transport.h"

fn C.vox_resource_curl_fetch(url &char, proxy &char, ca_bundle &char, user_agent &char,
	headers voidptr, owner voidptr, scope voidptr,
	receive_header fn (voidptr, uint, uint, voidptr) uint,
	receive_body fn (voidptr, uint, uint, voidptr) uint, error_buffer &char,
	enable_http2 bool, protocol &i32) i32
fn C.vox_curl_slist_append(list voidptr, value &char) voidptr
fn C.vox_curl_slist_free_all(list voidptr)

@[heap]
struct CancellableResponse {
	scope    &RequestScope
	progress &ResponseBodyProgress
mut:
	response      http.Response
	body          []u8
	response_time i64
	expected      u64
}

struct CancellableTransportResult {
	response      http.Response
	request_time  i64
	response_time i64
}

fn cancellable_response_header(buffer voidptr, size uint, count uint, owner voidptr) uint {
	mut state := unsafe { &CancellableResponse(owner) }
	if state.scope.is_cancelled() { return 0 }
	length := size * count
	line := unsafe { (&u8(buffer)).vbytes(int(length)).bytestr().clone() }.trim_right('\r\n')
	if line.starts_with('HTTP/') {
		parts := line.split_nth(' ', 3)
		if parts.len < 2 { return 0 }
		state.response = http.Response{
			http_version: parts[0].all_after('HTTP/')
			status_code:  parts[1].int()
			status_msg:   if parts.len > 2 { parts[2] } else { '' }
		}
		state.expected = 0
		state.response_time = 0
	} else if colon := line.index(':') {
		name := line[..colon].trim_space()
		value := line[colon + 1..].trim_space()
		state.response.header.add_custom(name, value) or { return 0 }
	} else if line == '' && state.response.status_code >= 200 && state.response_time == 0 {
		state.response_time = time.now().unix_milli()
		// libcurl delivers decoded bytes. A compressed Content-Length cannot
		// determine whether that decoded prefix was the final body delivery.
		if (state.response.header.get(.content_encoding) or { '' }) == '' {
			state.expected = (state.response.header.get(.content_length) or { '' }).u64()
		}
	}
	return length
}

fn cancellable_response_body(buffer voidptr, size uint, count uint, owner voidptr) uint {
	mut state := unsafe { &CancellableResponse(owner) }
	if state.scope.is_cancelled() { return 0 }
	length := size * count
	chunk := unsafe { (&u8(buffer)).vbytes(int(length)) }
	state.body << chunk
	state.progress.observe(chunk, u64(state.body.len), state.expected, state.response.status_code)
	return length
}

fn fetch_cancellable(config http.FetchConfig, scope &RequestScope, mut progress ResponseBodyProgress) !CancellableTransportResult {
	scope.check()!
	mut headers := voidptr(unsafe { nil })
	defer { if headers != unsafe { nil } { C.vox_curl_slist_free_all(headers) } }
	for name in config.header.keys() {
		for value in config.header.custom_values(name) {
			appended := C.vox_curl_slist_append(headers, '${name}: ${value}'.str)
			if appended == unsafe { nil } {
				return error('Failed to allocate resource request headers')
			}
			headers = appended
		}
	}
	mut proxy := if config.proxy == unsafe { nil } { '' } else { config.proxy.str() }
	// V's SOCKS5 proxy resolves hostnames remotely; curl spells that socks5h.
	if proxy.starts_with('socks5://') { proxy = 'socks5h://' + proxy['socks5://'.len..] }
	mut enable_http2 := config.enable_http2
	for attempt in 0 .. 2 {
		scope.check()!
		mut state := &CancellableResponse{ scope: scope, progress: &progress }
		mut error_buffer := []u8{len: 256}
		mut protocol := i32(0)
		request_time := time.now().unix_milli()
		code := C.vox_resource_curl_fetch(config.url.str, proxy.str, config.verify.str,
			config.user_agent.str, headers, state, scope.native,
			cancellable_response_header, cancellable_response_body, &char(error_buffer.data),
			enable_http2, &protocol)
		// Cancellation is control flow, never a transport failure to retry.
		scope.check()!
		if code != 0 {
			if attempt == 0 && config.method == .get && enable_http2
				&& config.url.starts_with('https://')
				&& code == C.CURLE_OPERATION_TIMEDOUT && protocol == C.CURL_HTTP_VERSION_2_0 {
				// Preserve the existing narrowly scoped GET recovery. Partial
				// bytes/headers of the abandoned HTTP/2 response cannot describe
				// the independent HTTP/1 response returned by this retry.
				progress.previous = 0
				progress.incomplete_prefix = 0
				progress.prefix.clear()
				enable_http2 = false
				continue
			}
			message := error_buffer.bytestr().all_before('\x00')
			return error('Resource transport failed (${code})${if message == '' {
				''
			} else {
				': ' + message
			}}')
		}
		state.response.body = state.body.bytestr()
		return CancellableTransportResult{
			response:      state.response
			request_time:  request_time
			response_time: if state.response_time > 0 {
				state.response_time
			} else {
				time.now().unix_milli()
			}
		}
	}
	return error('Resource transport recovery exhausted')
}
