// The full uBlock Origin static engine is isolated from all page scripts.
module adblock

import os

fn C.vox_adblock_log_lock()
fn C.vox_adblock_log_unlock()

pub const engine_version = '1.75.0'
pub const default_list_count = 10

pub struct Request {
pub:
	url          string
	source_url   string
	request_type string = 'other'
	method       string = 'GET'
}

pub struct Decision {
pub:
	blocked      bool
	exception    bool
	rule         string
	redirect_url string
	error        string
}

// Engine is an independent filter set, useful for user filters and diagnostics.
// The browser's default engine is process-wide and enabled on startup.
pub struct Engine {
mut:
	context voidptr
}

struct RequestLog {
	phase        string = 'request'
	response_headers []ResponseHeader
	method       string
	url          string
	source_url   string
	request_type string
	blocked      bool
	exception    bool
	rule         string
	redirect_url string
	error        string
}

fn record_response(request Request, headers []ResponseHeader, decision Decision) {
	path := os.getenv('VOX_ADBLOCK_LOG')
	if path == '' { return }
	C.vox_adblock_log_lock()
	defer { C.vox_adblock_log_unlock() }
	mut file := os.open_append(path) or { return }
	defer { file.close() }
	file.writeln(encode_transport_json(RequestLog{
		phase: 'response'
		response_headers: headers
		method: request.method
		url: request.url
		source_url: request.source_url
		request_type: request.request_type
		blocked: decision.blocked
		exception: decision.exception
		rule: decision.rule
		redirect_url: decision.redirect_url
		error: decision.error
	})) or {}
}

fn record_request(request Request, decision Decision) {
	path := os.getenv('VOX_ADBLOCK_LOG')
	if path == '' {
		return
	}
	C.vox_adblock_log_lock()
	defer { C.vox_adblock_log_unlock() }
	mut file := os.open_append(path) or { return }
	defer { file.close() }
	file.writeln(encode_transport_json(RequestLog{
		method: request.method
		url: request.url
		source_url: request.source_url
		request_type: request.request_type
		blocked: decision.blocked
		exception: decision.exception
		rule: decision.rule
		redirect_url: decision.redirect_url
		error: decision.error
	})) or {}
}

// check evaluates one request. It never fetches a URL or changes the filter set.
// VOX_ADBLOCK_LOG optionally records JSON lines for a live comparison to uBO.
pub fn check(request Request) Decision {
	if !is_enabled() {
		return Decision{}
	}
	if !(request.url.starts_with('http://') || request.url.starts_with('https://')
		|| request.url.starts_with('ws://') || request.url.starts_with('wss://')) {
		return Decision{}
	}
	result := evaluate_engine('voxAdblockCheck(${encode_transport_json(request)})') or {
		decision := Decision{error: err.msg()}
		record_request(request, decision)
		return decision
	}
	decision := decode_transport_json[Decision](result) or { Decision{error: err.msg()} }
	record_request(request, decision)
	return decision
}

pub fn (mut engine Engine) check(request Request) Decision {
	result := evaluate_custom_engine(engine.context, 'voxAdblockCheck(${encode_transport_json(request)})') or {
		return Decision{error: err.msg()}
	}
	return decode_transport_json[Decision](result) or { Decision{error: err.msg()} }
}
