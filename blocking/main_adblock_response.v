module main

import adblock

// Cache and preload consumers repeat the response-header gate with their own
// document/type context before exposing any retained bytes.
fn filter_browser_response_headers(request adblock.Request, headers []adblock.ResponseHeader) ! {
	decision := adblock.check_response(request, headers)
	if decision.error != '' { return error('Adblock unavailable: ${decision.error}') }
	if decision.blocked { return error('Blocked by adblock: ${decision.rule}') }
}
