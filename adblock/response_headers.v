module adblock

import os

// Same-binary control: send every response through the engine's header stage.
const check_all_adblock_responses = os.getenv('VOX_CHECK_ALL_ADBLOCK_RESPONSES') != ''

// Responses whose header stage was answered from the request stage's verdict.
__global skipped_adblock_response_checks u64

// The request stage's verdict on header filters (voxAdblockCheck): whether no
// headers-realm filter could match the request with any response headers.
struct HeaderFilterCandidacy {
	no_header_filters bool
}

// uBO's header stage can only block a request that some headers-realm filter
// matches apart from its header conditions. The request stage records that
// for the same request, so a response without such a candidate needs neither
// its headers serialized nor the engine asked. A request whose decision is no
// longer retained keeps the complete check.
fn response_cannot_match_header_filters(request_source string) bool {
	if check_all_adblock_responses { return false }
	result := retained_filter_decision('voxAdblockCheck(${request_source})') or { return false }
	candidacy := decode_transport_json[HeaderFilterCandidacy](result) or { return false }
	return candidacy.no_header_filters
}

// Preserve separate repeated fields. Full uBO's response-header matcher uses
// the first matching field, with case-insensitive names.
pub struct ResponseHeader {
pub:
	name  string
	value string
}

// Response-header filters run before response bytes enter a consumer or cache.
// In particular, RU AdList identifies Pikabu ad payloads by a custom header.
pub fn check_response(request Request, headers []ResponseHeader) Decision {
	if !is_enabled() { return Decision{} }
	if !(request.url.starts_with('http://') || request.url.starts_with('https://')
		|| request.url.starts_with('ws://') || request.url.starts_with('wss://')) {
		return Decision{}
	}
	request_source := encode_transport_json(request)
	if response_cannot_match_header_filters(request_source) {
		skipped_adblock_response_checks++
		decision := Decision{}
		record_response(request, headers, decision)
		return decision
	}
	result := evaluate_filter_decision('voxAdblockCheckResponse(${request_source},${encode_transport_json(headers)})') or {
		decision := Decision{
			error: err.msg()
		}
		record_response(request, headers, decision)
		return decision
	}
	decision := decode_transport_json[Decision](result) or {
		Decision{
			error: err.msg()
		}
	}
	record_response(request, headers, decision)
	return decision
}

pub fn (mut engine Engine) check_response(request Request, headers []ResponseHeader) Decision {
	result := evaluate_custom_engine(engine.context,
		'voxAdblockCheckResponse(${encode_transport_json(request)},${encode_transport_json(headers)})') or {
		return Decision{
			error: err.msg()
		}
	}
	return decode_transport_json[Decision](result) or {
		Decision{
			error: err.msg()
		}
	}
}
