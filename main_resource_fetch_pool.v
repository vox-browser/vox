module main

import platform

// Navigation fetches every render-blocking stylesheet and script before it
// commits a page; some pages list hundreds. A few workers drain each batch:
// pooled HTTP/2 connections multiplex their requests, and a large page does
// not start one thread per resource.
const max_concurrent_resource_fetches = 16

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
		assigned << jobs[index]
	}
	return assigned
}

fn spawn_resource_fetch_workers(jobs []ResourceFetchJob, source_url string, wake bool, results chan PreloadedResource) {
	workers := resource_fetch_worker_count(jobs.len)
	for worker in 0 .. workers {
		spawn fetch_resource_jobs(resource_fetch_worker_jobs(jobs, worker, workers), source_url, wake,
			results)
	}
}

fn fetch_resource_jobs(jobs []ResourceFetchJob, source_url string, wake bool, results chan PreloadedResource) {
	platform.retain_thread_allocations()
	for job in jobs {
		resource := if job.cached.len > 0 {
			filter_preloaded_resource(job.cached[0], source_url, job.request_type) or {
				PreloadedResource{ url: job.url, error: err.msg(), source_url: source_url, request_type: job.request_type }
			}
		} else {
			fetch_browser_resource(job.url, '', source_url, job.request_type) or {
				PreloadedResource{ url: job.url, error: err.msg(), source_url: source_url, request_type: job.request_type }
			}
		}
		results <- resource
		if wake {
			$if macos {
				C.native_wake_browser()
			}
		}
	}
}
