module main

import platform
import browsernet

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
	for job in jobs {
		scope.check() or { return }
		resource := if job.cached.len > 0 {
			filter_preloaded_resource_with_scope(job.cached[0], source_url, job.request_type, scope) or {
				PreloadedResource{ url: job.url, error: err.msg(), source_url: source_url, request_type: job.request_type }
			}
		} else {
			fetch_browser_resource_with_scope(job.url, '', source_url, job.request_type, scope) or {
				PreloadedResource{ url: job.url, error: err.msg(), source_url: source_url, request_type: job.request_type }
			}
		}
		if !publish_resource_result(resource, results, scope) { return }
		if wake {
			$if macos {
				C.native_wake_browser()
			}
		}
	}
}

fn publish_resource_result(resource PreloadedResource, results chan PreloadedResource,
	scope &browsernet.RequestScope) bool {
	return browsernet.publish_result[PreloadedResource](resource, results, scope)
}
