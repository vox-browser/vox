module html

import dom
import fetch

@[heap]
struct ParallelFetchObservation {
mut:
	pending ?&fetch.PendingResponse
	callbacks []string
}

fn start_parallel_fetch(state &ParallelFetchObservation) &fetch.FetchController {
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{value: 'https://example.test/parallel'}]
	request.origin = fetch.RequestOrigin{ is_client: false, origin: request.current_url().origin() }
	request.mode = .same_origin
	request.cache_mode = .no_store
	host := &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('blocking host was called') }
		perform_async: fn [state] (request &fetch.Request) &fetch.PendingResponse {
			mut observation := unsafe { &ParallelFetchObservation(state) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			observation.pending = pending
			return pending
		}
	}
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response: fn [state] (_ &fetch.Response) {
			mut observation := unsafe { &ParallelFetchObservation(state) }
			observation.callbacks << 'response'
		}
		process_response_consume_body: fn [state] (_ &fetch.Response, bytes fetch.BodyBytes) {
			assert bytes.kind == .empty
			mut observation := unsafe { &ParallelFetchObservation(state) }
			observation.callbacks << 'body'
		}
	})
	return fetch.fetch_with_parallel_queue(request, algorithms, host, .yes, .no)
}

fn test_parallel_fetch_queues_real_main_loop_tasks_instead_of_running_callbacks_inline() {
	mut owner := main_thread_event_loop()
	mut queue := owner.task_queue()
	queue.remove_tasks_matching(fn (_ &Task) bool { return true })
	state := &ParallelFetchObservation{}
	controller := start_parallel_fetch(state)
	mut pending := state.pending or { panic('network response is not pending') }
	pending.resolve(fetch.Response.create())
	assert state.callbacks.len == 0
	assert controller.ongoing_task_count() == 3
	source := queue.last_added_task()?.source()
	assert int(source) >= int(TaskSource.unique_task_source_start)
	for i := 0; i < 3; i++ {
		mut task := queue.take_first_runnable() or { panic('parallel fetch task missing') }
		assert task.source() == source
		assert task.document() == none
		task.execute()
	}
	assert state.callbacks == ['response', 'body']
	assert controller.ongoing_task_count() == 0
}

fn test_parallel_queues_have_distinct_source_ids_from_the_source_allocator() {
	first := ParallelQueue.create()
	second := ParallelQueue.create()
	assert first.task_source() != second.task_source()
	assert int(first.task_source()) >= int(TaskSource.unique_task_source_start)
	assert html_allocated_unique_task_sources_[int(first.task_source())]
	first.finalize()
	assert int(first.task_source()) !in html_allocated_unique_task_sources_
	second.finalize()
}

fn test_stopping_a_parallel_fetch_removes_its_exact_queued_tasks() {
	mut owner := main_thread_event_loop()
	mut queue := owner.task_queue()
	queue.remove_tasks_matching(fn (_ &Task) bool { return true })
	state := &ParallelFetchObservation{}
	mut controller := start_parallel_fetch(state)
	mut pending := state.pending or { panic('network response is not pending') }
	pending.resolve(fetch.Response.create())
	assert controller.ongoing_task_count() == 3
	controller.stop_fetch()
	assert queue.is_empty()
	assert controller.ongoing_task_count() == 0
	assert state.callbacks.len == 0
}
