module main

import platform
import browsernet
import css
import os
import time

// Resource batches can contain hundreds of jobs. A few workers drain each
// batch without starting a thread per resource. browsernet additionally owns
// the process-wide transport budget across all overlapping batches.
const max_concurrent_resource_fetches = browsernet.max_concurrent_requests

struct ResourceFetchJob {
	url          string
	request_type string
	// A cached response is filtered for this document instead of fetched again.
	cached []PreloadedResource
}

fn resource_fetch_worker_count(jobs int) int {
	return if jobs < max_concurrent_resource_fetches { jobs } else { max_concurrent_resource_fetches }
}

// Assign jobs round-robin so the leading stylesheets start first on every worker.
fn resource_fetch_worker_jobs(jobs []ResourceFetchJob, worker int, workers int) []ResourceFetchJob {
	mut assigned := []ResourceFetchJob{cap: jobs.len / workers + 1}
	for index := worker; index < jobs.len; index += workers {
		job := jobs[index]
		assigned << ResourceFetchJob{
			url: job.url.clone()
			request_type: job.request_type.clone()
			cached: job.cached.clone()
		}
	}
	return assigned
}

fn spawn_resource_fetch_workers(jobs []ResourceFetchJob, source_url string, wake bool, results chan PreloadedResource) {
	scope := browsernet.new_request_scope()
	defer { scope.release() }
	spawn_resource_fetch_workers_with_scope(jobs, source_url, wake, results, scope)
}

fn spawn_resource_fetch_workers_with_scope(jobs []ResourceFetchJob, source_url string, wake bool,
	results chan PreloadedResource, scope &browsernet.RequestScope) {
	if scope.is_cancelled() { return }
	// Copy worker descriptors outside an entered document or frame arena.
	// Cached payloads already belong to the persistent response cache.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owned_source := source_url.clone()
	workers := resource_fetch_worker_count(jobs.len)
	for worker in 0 .. workers {
		scope.retain()
		spawn resource_fetch_worker(resource_fetch_worker_jobs(jobs, worker, workers), owned_source,
			wake, results, scope)
	}
}

fn resource_fetch_worker(jobs []ResourceFetchJob, source_url string, wake bool,
	results chan PreloadedResource, scope &browsernet.RequestScope) {
	defer { scope.release() }
	fetch_resource_jobs_with_scope(jobs, source_url, wake, results, scope)
}

fn fetch_resource_jobs(jobs []ResourceFetchJob, source_url string, wake bool, results chan PreloadedResource) {
	scope := browsernet.new_request_scope()
	defer { scope.release() }
	fetch_resource_jobs_with_scope(jobs, source_url, wake, results, scope)
}

fn fetch_resource_jobs_with_scope(jobs []ResourceFetchJob, source_url string, wake bool,
	results chan PreloadedResource, scope &browsernet.RequestScope) {
	platform.retain_thread_allocations()
	for index, job in jobs {
		scope.check() or { return }
		resource := fetch_resource_job(job, source_url, scope)
		if !publish_resource_result(resource, results, scope) { return }
		if wake {
			$if macos {
				C.native_wake_browser()
			}
		}
		// The response and its wakeup must be visible before speculative parsing.
		// Use the end of this worker's batch so no queued request waits for it.
		if index == jobs.len - 1 && job.request_type == 'stylesheet'
			&& resource.error == '' && !scope.is_cancelled() {
			prepare_delivered_stylesheet(resource)
		}
	}
}

fn prepare_delivered_stylesheet(resource PreloadedResource) {
	scratch := platform.begin_thread_scratch('stylesheet response headers')
	defer { scratch.finish() }
	for header in resource.response_headers {
		if header.name.to_lower() == 'content-type'
			&& header.value.all_before(';').trim_space().to_lower() == 'text/css' {
			css.prepare_preloaded_stylesheet_syntax(resource.body)
			return
		}
	}
}

// VOX_RESOURCE_FETCH_LOG=PATH appends one JSON line per worker fetch (images,
// script-inserted stylesheets and other background resources) with
// wall-clock microseconds, comparable with VOX_CURL_TRANSFER_LOG.
const resource_fetch_log_path = os.getenv('VOX_RESOURCE_FETCH_LOG')

fn log_resource_fetch(job ResourceFetchJob, started_us i64, resource PreloadedResource) {
	finished_us := time.now().unix_micro()
	address := job.url.replace('\\', '\\\\').replace('"', '\\"')
	failure := resource.error.limit(80).replace('\\', '\\\\').replace('"', '\\"')
	mut file := os.open_append(resource_fetch_log_path) or { return }
	defer { file.close() }
	file.writeln('{"url":"${address}","type":"${job.request_type}","cached":${job.cached.len > 0},"started_us":${started_us},"finished_us":${finished_us},"bytes":${resource.body.len},"error":"${failure}"}') or {}
}

fn fetch_resource_job(job ResourceFetchJob, source_url string, scope &browsernet.RequestScope) PreloadedResource {
	// The worker's result outlives the thread. URL, header and transport
	// workspaces belong to the request that produced it.
	scratch := platform.begin_thread_scratch('resource fetch request')
	defer { scratch.finish() }
	started_us := if resource_fetch_log_path != '' { time.now().unix_micro() } else { i64(0) }
	resource := resolve_resource_fetch_job(job, source_url, scope) or {
		PreloadedResource{
			url: job.url
			error: err.msg()
			source_url: source_url
			request_type: job.request_type
		}
	}
	if resource_fetch_log_path != '' { log_resource_fetch(job, started_us, resource) }
	$if prealloc {
		// Filtering can return the same cache entry. Its original owner
		// already keeps the immutable result alive after this request.
		if !resource.retained_for_process {
			scratch.leave()
			return persistent_preloaded_resource(resource)
		}
	}
	return resource
}

fn resolve_resource_fetch_job(job ResourceFetchJob, source_url string, scope &browsernet.RequestScope) !PreloadedResource {
	if job.cached.len > 0 {
		return filter_preloaded_resource_with_scope(job.cached[0], source_url, job.request_type, scope)
	}
	return fetch_browser_resource_with_scope(job.url, '', source_url, job.request_type, scope)
}

fn publish_resource_result(resource PreloadedResource, results chan PreloadedResource,
	scope &browsernet.RequestScope) bool {
	return browsernet.publish_result[PreloadedResource](resource, results, scope)
}
