// Copyright (c) 2024, Andrew Kaster <andrew@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/Job.{h,cpp}. Fetching is an explicit injected
// result; queue equivalence, FIFO execution and current upstream failure
// surfaces remain deterministic.
module serviceworker

import dom

pub enum JobType {
	register
	update
	unregister
}

pub enum WorkerPromiseState {
	pending
	fulfilled
	rejected
}

@[heap]
pub struct WorkerPromise {
pub mut:
	state        WorkerPromiseState
	error        string
	registration ?&Registration
	bool_value   ?bool
}

@[heap]
pub struct Job {
pub:
	job_type    JobType
	storage_key string
	scope_url   string
	script_url  string
	promise     &WorkerPromise
pub mut:
	worker_type        WorkerType
	update_via_cache   ServiceWorkerUpdateViaCache = .imports
	referrer           ?string
	force_cache_bypass bool
	equivalent_jobs    []&Job
}

pub fn Job.create(job_type JobType, storage_key string, scope_url string, script_url string, referrer ?string) &Job {
	return &Job{
		job_type:    job_type
		storage_key: storage_key
		scope_url:   scope_url
		script_url:  script_url
		referrer:    referrer
		promise:     &WorkerPromise{}
	}
}

pub fn (a &Job) equivalent(b &Job) bool {
	if a.job_type != b.job_type {
		return false
	}
	if a.job_type == .unregister {
		return a.scope_url == b.scope_url
	}
	return a.scope_url == b.scope_url && a.script_url == b.script_url
		&& a.worker_type == b.worker_type && a.update_via_cache == b.update_via_cache
}

pub struct ScriptFetchResult {
pub:
	success                bool
	mime_type              string = 'text/javascript'
	response_url           string
	body                   []u8
	from_local_cache       bool
	service_worker_allowed ?string
}

@[heap]
pub struct ServiceWorkerAgent {
pub mut:
	store         &RegistrationStore
	queues        map[string][]&Job
	fetch_results map[string]ScriptFetchResult
	now_seconds   f64
}

pub fn ServiceWorkerAgent.create() &ServiceWorkerAgent {
	return &ServiceWorkerAgent{
		store: RegistrationStore.create()
	}
}

pub fn (mut agent ServiceWorkerAgent) set_time(seconds f64) {
	agent.now_seconds = seconds
}

pub fn (mut agent ServiceWorkerAgent) set_fetch_result(script_url string, result ScriptFetchResult) {
	agent.fetch_results[without_fragment(script_url)] = result
}

pub fn (agent &ServiceWorkerAgent) queue_length(scope string) int {
	return (agent.queues[scope] or { []&Job{} }).len
}

pub fn scope_to_job_queue_map(agent &ServiceWorkerAgent) map[string][]&Job {
	return agent.queues.clone()
}

pub fn (mut agent ServiceWorkerAgent) schedule_job(job &Job) {
	scope := job.scope_url
	mut queue := agent.queues[scope] or { []&Job{} }
	if queue.len > 0 {
		mut last := queue.last()
		if job.equivalent(last) && last.promise.state == .pending {
			last.equivalent_jobs << job
			agent.queues[scope] = queue
			return
		}
	}
	queue << job
	agent.queues[scope] = queue
}

fn is_potentially_trustworthy(url string) bool {
	parsed := dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8') or { return false }
	if parsed.scheme() == 'https' {
		return true
	}
	host := parsed.serialized_host()
	return parsed.scheme() == 'http' && (host == 'localhost' || host.ends_with('.localhost')
		|| host == '127.0.0.1' || host == '::1' || host == '[::1]')
}

fn same_origin(a string, b string) bool {
	first := dom.dom_url_parse(a, dom.url_about_blank(), 'UTF-8') or { return false }
	second := dom.dom_url_parse(b, dom.url_about_blank(), 'UTF-8') or { return false }
	return first.origin().is_same_origin(second.origin())
}

// Implements the currently translated Service-Worker-Allowed portion of the
// update fetch hook. Without the header a script may only control scopes below
// its own directory; a same-origin header can widen that maximum scope.
fn service_worker_scope_allowed(scope_url string, script_url string, allowed ?string) bool {
	script := dom.dom_url_parse(script_url, dom.url_about_blank(), 'UTF-8') or { return false }
	scope := dom.dom_url_parse(scope_url, dom.url_about_blank(), 'UTF-8') or { return false }
	maximum := if value := allowed {
		parsed := dom.dom_url_parse(value, script, 'UTF-8') or { return false }
		if !parsed.origin().is_same_origin(script.origin()) {
			return false
		}
		parsed
	} else {
		dom.dom_url_parse('./', script, 'UTF-8') or { return false }
	}
	return scope.serialize_path().starts_with(maximum.serialize_path())
}

fn (agent &ServiceWorkerAgent) resolve_job(job &Job, registration ?&Registration, value ?bool) {
	mut promise := job.promise
	promise.state = .fulfilled
	promise.registration = registration
	promise.bool_value = value
	for equivalent in job.equivalent_jobs {
		mut equivalent_promise := equivalent.promise
		equivalent_promise.state = .fulfilled
		equivalent_promise.registration = registration
		equivalent_promise.bool_value = value
	}
}

fn (agent &ServiceWorkerAgent) reject_job(job &Job, message string) {
	mut promise := job.promise
	promise.state = .rejected
	promise.error = message
	for equivalent in job.equivalent_jobs {
		mut equivalent_promise := equivalent.promise
		equivalent_promise.state = .rejected
		equivalent_promise.error = message
	}
}

pub fn resolve_job_promise(agent &ServiceWorkerAgent, job &Job, registration ?&Registration, value ?bool) {
	agent.resolve_job(job, registration, value)
}

pub fn reject_job_promise(agent &ServiceWorkerAgent, job &Job, message string) {
	agent.reject_job(job, message)
}

fn javascript_mime_type(mime string) bool {
	essence := mime.to_lower().all_before(';').trim_space()
	return essence in ['application/ecmascript', 'application/javascript', 'application/x-ecmascript',
		'application/x-javascript', 'text/ecmascript', 'text/javascript', 'text/javascript1.0',
		'text/javascript1.1', 'text/javascript1.2', 'text/javascript1.3', 'text/javascript1.4',
		'text/javascript1.5', 'text/jscript', 'text/livescript', 'text/x-ecmascript',
		'text/x-javascript']
}

fn (mut agent ServiceWorkerAgent) update(job &Job) {
	mut registration := agent.store.get(job.storage_key, job.scope_url) or {
		agent.reject_job(job, 'TypeError: Service Worker registration not found on update')
		return
	}
	newest := registration.newest_worker()
	had_newest := newest != none
	if job.job_type == .update {
		if worker := newest {
			if without_fragment(worker.script_url) != without_fragment(job.script_url) {
				agent.reject_job(job, 'TypeError: Service Worker script URL mismatch on update')
				return
			}
		}
	}
	response := agent.fetch_results[without_fragment(job.script_url)] or {
		if !had_newest {
			agent.store.remove(registration.storage_key(), registration.scope_url())
		}
		agent.reject_job(job, 'NetworkError: Service Worker script fetch has no host result')
		return
	}
	if !response.success {
		if !had_newest {
			agent.store.remove(registration.storage_key(), registration.scope_url())
		}
		agent.reject_job(job, 'NetworkError: Service Worker script fetch failed')
		return
	}
	if !javascript_mime_type(response.mime_type) {
		if !had_newest {
			agent.store.remove(registration.storage_key(), registration.scope_url())
		}
		agent.reject_job(job,
			'SecurityError: Service Worker script response is not a JavaScript MIME type')
		return
	}
	response_url := if response.response_url == '' { job.script_url } else { response.response_url }
	if !same_origin(response_url, job.script_url) {
		if !had_newest {
			agent.store.remove(registration.storage_key(), registration.scope_url())
		}
		agent.reject_job(job,
			'SecurityError: Service Worker script response has a different origin')
		return
	}
	if !service_worker_scope_allowed(job.scope_url, job.script_url, response.service_worker_allowed) {
		if !had_newest {
			agent.store.remove(registration.storage_key(), registration.scope_url())
		}
		agent.reject_job(job,
			'SecurityError: Service Worker script scope does not match Service-Worker-Allowed header')
		return
	}
	if !response.from_local_cache {
		registration.set_last_update_check_time(agent.now_seconds)
	}
	if worker := newest {
		// Upstream does not yet implement the byte-for-byte body comparison.
		// Its hasUpdatedResources flag therefore remains false when URL and
		// worker type are unchanged, regardless of the returned body bytes.
		if without_fragment(worker.script_url) == without_fragment(job.script_url)
			&& worker.worker_type == job.worker_type {
			registration.set_update_via_cache(job.update_via_cache)
			agent.resolve_job(job, registration, none)
			return
		}
	}
	// This is the exact current C++ frontier after byte comparison: creation,
	// Run Service Worker and Install remain FIXME and reject NotImplemented.
	agent.reject_job(job, 'NotImplemented: Run Service Worker')
}

fn (mut agent ServiceWorkerAgent) register(job &Job) {
	referrer := job.referrer or {
		agent.reject_job(job, 'SecurityError: Service Worker registration has no referrer')
		return
	}

	if !is_potentially_trustworthy(job.script_url) {
		agent.reject_job(job,
			'SecurityError: Service Worker registration has untrustworthy script origin')
		return
	}
	if !same_origin(job.script_url, referrer) {
		agent.reject_job(job,
			'SecurityError: Service Worker registration has incompatible script and referrer origins')
		return
	}
	if !same_origin(job.scope_url, referrer) {
		agent.reject_job(job,
			'SecurityError: Service Worker registration has incompatible scope and referrer origins')
		return
	}
	if mut registration := agent.store.get(job.storage_key, job.scope_url) {
		if worker := registration.newest_worker() {
			if without_fragment(worker.script_url) == without_fragment(job.script_url)
				&& worker.worker_type == job.worker_type
				&& registration.update_via_cache() == job.update_via_cache {
				agent.resolve_job(job, registration, none)
				return
			}
		}
	} else {
		agent.store.set(job.storage_key, job.scope_url, job.update_via_cache)
	}
	agent.update(job)
}

pub fn (mut agent ServiceWorkerAgent) process_scope(scope string) bool {
	mut queue := agent.queues[scope] or { return false }
	if queue.len == 0 {
		return false
	}
	job := queue[0]
	match job.job_type {
		.register { agent.register(job) }
		.update { agent.update(job) }
		.unregister { agent.reject_job(job, 'NotImplemented: Service Worker unregistration') }
	}
	queue.delete(0)
	agent.queues[scope] = queue
	return true
}

pub fn run_job(mut agent ServiceWorkerAgent, scope string) bool {
	return agent.process_scope(scope)
}

pub fn finish_job(mut agent ServiceWorkerAgent, job &Job) bool {
	mut queue := agent.queues[job.scope_url] or { return false }
	if queue.len == 0 || voidptr(queue[0]) != voidptr(job) {
		return false
	}
	queue.delete(0)
	agent.queues[job.scope_url] = queue
	return true
}

pub fn (mut agent ServiceWorkerAgent) process_all() {
	for {
		mut processed := false
		for scope, queue in agent.queues {
			if queue.len > 0 {
				agent.process_scope(scope)
				processed = true
			}
		}
		if !processed {
			break
		}
	}
}
