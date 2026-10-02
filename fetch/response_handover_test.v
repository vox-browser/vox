module fetch

import dom
import streams

@[heap]
struct ResponseHandoverObservation {
mut:
	chunks []string
	results []BodyBytes
	ends int
	errors []string
}

fn handover_test_params(state &ResponseHandoverObservation) &FetchParams {
	mut request := Request.create()
	request.url_list = [dom.URL{'https://example.test/streamed'}]
	request.origin = RequestOrigin{ is_client: false, origin: request.current_url().origin() }
	mut params := FetchParams.create(request, FetchTimingInfo.create())
	params.algorithms = FetchAlgorithms.create(FetchAlgorithmsInput{
		process_response_end_of_body: fn [state] (_ &Response) {
			mut observation := unsafe { &ResponseHandoverObservation(state) }
			observation.ends++
		}
	})
	return params
}

fn test_response_done_waits_for_the_identity_stream_to_reach_eof() {
	state := &ResponseHandoverObservation{}
	params := handover_test_params(state)
	mut response := Response.create()
	body := Body.streaming()
	mut producer := body.stream()
	response.body = body
	fetch_response_handover(params, response)
	assert !params.request.done
	mut consumer := response.body or { panic('missing response stream') }
	consumer.incrementally_read(fn [state] (bytes []u8) {
		mut observation := unsafe { &ResponseHandoverObservation(state) }
		observation.chunks << bytes.bytestr()
	}, fn () {}, fn [state] (reason string) {
		mut observation := unsafe { &ResponseHandoverObservation(state) }
		observation.errors << reason
	})
	producer.enqueue(streams.bytes_value('first'.bytes()))!
	assert state.chunks == ['first']
	assert !params.request.done
	assert state.ends == 0
	producer.enqueue(streams.bytes_value('second'.bytes()))!
	assert state.chunks == ['first', 'second']
	producer.close()
	assert params.request.done
	assert state.ends == 1
	assert state.errors.len == 0
}

fn test_consume_body_remains_pending_and_collects_future_chunks() {
	state := &ResponseHandoverObservation{}
	mut params := handover_test_params(state)
	params.algorithms = FetchAlgorithms.create(FetchAlgorithmsInput{
		process_response_consume_body: fn [state] (_ &Response, result BodyBytes) {
			mut observation := unsafe { &ResponseHandoverObservation(state) }
			observation.results << result
		}
	})
	params.controller.set_full_timing_info(params.timing_info)
	mut response := Response.create()
	body := Body.streaming()
	mut producer := body.stream()
	response.body = body
	fetch_response_handover(params, response)
	assert state.results.len == 0
	assert !params.request.done
	producer.enqueue(streams.bytes_value('first'.bytes()))!
	producer.enqueue(streams.bytes_value('second'.bytes()))!
	assert state.results.len == 0
	producer.close()
	assert state.results.len == 1
	assert state.results[0].kind == .bytes
	assert state.results[0].bytes == 'firstsecond'.bytes()
	assert params.request.done
}

fn test_consume_body_reports_late_stream_failure_without_a_successful_eof() {
	state := &ResponseHandoverObservation{}
	mut params := handover_test_params(state)
	params.controller.set_full_timing_info(params.timing_info)
	params.algorithms = FetchAlgorithms.create(FetchAlgorithmsInput{
		process_response_consume_body: fn [state] (_ &Response, result BodyBytes) {
			mut observation := unsafe { &ResponseHandoverObservation(state) }
			observation.results << result
		}
	})
	mut response := Response.create()
	body := Body.streaming()
	mut producer := body.stream()
	response.body = body
	fetch_response_handover(params, response)
	producer.enqueue(streams.bytes_value('partial'.bytes()))!
	producer.error('connection failed')
	assert state.results.len == 1
	assert state.results[0].kind == .failure
	assert !params.request.done
	params.controller.report_timing()
	assert params.timing_info.end_time > 0
}
