module adblock

// Request and response checks call the engine's functions with JSON
// arguments; the replies equal evaluating the same call as a script.
fn test_engine_calls_with_json_arguments_match_script_evaluation() {
	mut engine := new_engine('||ads.example^\$script\n||via.example^\$script,header=via:1.1 google\n')!
	defer { engine.close() }
	blocked := Request{
		url:          'https://ads.example/a.js'
		source_url:   'https://site.example/'
		request_type: 'script'
	}
	check := 'voxAdblockCheck(${encode_transport_json(blocked)})'
	direct := call_engine_function(engine.context, check) or { panic('the direct call was declined') }
	// A parenthesized call is not recognized and takes the script path.
	assert direct == evaluate_context(engine.context, '(${check})')!
	assert direct.contains('"blocked":true')
	via := Request{
		url:          'https://via.example/v.js'
		source_url:   'https://site.example/'
		request_type: 'script'
	}
	response := 'voxAdblockCheckResponse(${encode_transport_json(via)},${encode_transport_json([
		ResponseHeader{ name: 'Via', value: '1.1 google' },
	])})'
	direct_response := call_engine_function(engine.context, response) or { panic('the response call was declined') }
	assert direct_response == evaluate_context(engine.context, '(${response})')!
	assert direct_response.contains('"blocked":true')
	// Arguments that are not JSON, and calls that throw, are evaluated as
	// scripts, which report the same values and errors as before.
	literal := 'voxAdblockCheck({url:"https://ads.example/a.js",source_url:"https://site.example/",request_type:"script"})'
	assert call_engine_function(engine.context, literal) == none
	assert evaluate_context(engine.context, literal)!.contains('"blocked":true')
	assert call_engine_function(engine.context, 'voxAdblockCheck(null)') == none
	if _ := evaluate_context(engine.context, 'voxAdblockCheck(null)') {
		assert false, 'a throwing check must report its error'
	}
}
