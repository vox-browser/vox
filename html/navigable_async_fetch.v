module html

import dom
import fetch
import platform

@[heap]
struct PendingNavigableFetch {
	model   &NavigableModel
	entry   &SessionHistoryEntry
	params  NavigableNavigateParams
	source  SourceSnapshotParams
	target  TargetSnapshotParams
	history HistoryHandlingBehavior
	id      string
	host    &fetch.FetchHost
	request &fetch.Request
mut:
	redirects int
}

// The native browser's RequestServer completes on the owning event loop. The
// synchronous hook remains available to standalone translated-model callers.
pub fn (mut model NavigableModel) set_navigation_fetch_host(host ?&fetch.FetchHost) {
	model.navigation_fetch_host_ = host
}

pub fn (mut model NavigableModel) set_document_created_hook(hook ?fn (&dom.Document)) {
	model.document_created_hook_ = hook
}

fn (mut model NavigableModel) start_navigation_fetch(entry &SessionHistoryEntry, params NavigableNavigateParams, source SourceSnapshotParams, target TargetSnapshotParams, history HistoryHandlingBehavior, id string, host &fetch.FetchHost) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	request := create_navigation_fetch_request(entry, &model, source) or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	model.set_delaying_load_events(true)
	mut pending := &PendingNavigableFetch{
		model:   &model
		entry:   entry
		params:  params
		source:  source
		target:  target
		history: history
		id:      id
		host:    host
		request: request
	}
	pending.start()
}

fn (pending &PendingNavigableFetch) is_current() bool {
	return !pending.model.has_been_destroyed() && pending.model.active_browsing_context() != none
		&& pending.model.ongoing_navigation_.kind == .navigation
		&& pending.model.ongoing_navigation_.id == pending.id
}

fn (mut pending PendingNavigableFetch) start() {
	if !pending.is_current() { return }
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response_consume_body: fn [pending] (response &fetch.Response, bytes fetch.BodyBytes) {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut current := unsafe { &PendingNavigableFetch(pending) }
			current.complete(response, bytes)
		}
	})
	mut model := unsafe { &NavigableModel(pending.model) }
	model.navigation_fetch_controller_ = fetch.fetch_with_parallel_queue(pending.request,
		algorithms, pending.host, .yes, .no)
}

fn (mut pending PendingNavigableFetch) complete(response &fetch.Response, bytes fetch.BodyBytes) {
	if !pending.is_current() { return }
	mut model := unsafe { &NavigableModel(pending.model) }
	model.navigation_fetch_controller_ = none
	if response.is_network_error() || bytes.kind == .failure {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	mut raw := unsafe { &fetch.Response(response.unsafe_response()) }
	if raw.url_list.len == 0 { raw.url_list = pending.request.url_list.clone() }
	location_result := raw.location_url(pending.request.current_url().fragment()) or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	if location := location_result.url {
		if fetch.is_http_or_https_scheme(location.scheme()) {
			if pending.redirects == 20 {
				model.set_ongoing_navigation(NavigableOngoingNavigation{})
				return
			}
			pending.redirects++
			mut request := unsafe { &fetch.Request(pending.request) }
			request.url_list << location
			pending.start()
			return
		}
		mut request := unsafe { &fetch.Request(pending.request) }
		request.url_list << location
	}
	// Own the completed bytes independently of the RequestServer stream before
	// the common navigation path parses them and publishes its Document.
	raw.set_body_bytes(bytes.bytes.clone())
	received := navigation_params_from_fetch_response(pending.entry, pending.model,
		pending.source, pending.target, pending.params.user_involvement, pending.id,
		pending.request, raw) or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	model.finish_navigation_fetch(pending.entry, pending.params, pending.source, pending.target,
		pending.history, pending.id, received)
}
