module adblock

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
	result := evaluate_filter_decision('voxAdblockCheckResponse(${encode_transport_json(request)},${encode_transport_json(headers)})') or {
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
