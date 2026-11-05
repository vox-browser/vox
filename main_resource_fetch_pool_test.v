module main

import html
import os
import time

fn test_resource_fetch_workers_are_bounded_and_cover_each_job_once() {
	assert resource_fetch_worker_count(0) == 0
	assert resource_fetch_worker_count(3) == 3
	assert resource_fetch_worker_count(650) == max_concurrent_resource_fetches
	mut jobs := []ResourceFetchJob{}
	for index in 0 .. 37 {
		jobs << ResourceFetchJob{ url: 'https://example.com/${index}.css', request_type: 'stylesheet' }
	}
	workers := resource_fetch_worker_count(jobs.len)
	mut seen := map[string]int{}
	for worker in 0 .. workers {
		assigned := resource_fetch_worker_jobs(jobs, worker, workers)
		// Round-robin assignment starts the leading stylesheets first.
		assert assigned[0].url == 'https://example.com/${worker}.css'
		for job in assigned {
			seen[job.url]++
		}
	}
	assert seen.len == jobs.len
	for _, count in seen {
		assert count == 1
	}
}

fn test_resource_fetch_workers_deliver_every_result_once() {
	directory := os.join_path(os.temp_dir(), 'vox-fetch-pool-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	defer { os.rmdir_all(directory) or {} }
	count := max_concurrent_resource_fetches * 2 + 3
	mut jobs := []ResourceFetchJob{}
	for index in 0 .. count {
		path := os.join_path(directory, '${index}.css')
		os.write_file(path, 'a${index}{}') or { panic(err) }
		jobs << ResourceFetchJob{ url: 'file://${path}', request_type: 'stylesheet' }
	}
	jobs << ResourceFetchJob{ url: 'file://${directory}/missing.js', request_type: 'script' }
	results := chan PreloadedResource{cap: jobs.len}
	spawn_resource_fetch_workers(jobs, 'file://${directory}/index.html', false, results)
	mut received := map[string]PreloadedResource{}
	for _ in 0 .. jobs.len {
		resource := <-results
		assert resource.url !in received
		received[resource.url] = resource
	}
	for index in 0 .. count {
		resource := received['file://${os.join_path(directory, '${index}.css')}']
		assert resource.error == ''
		assert resource.body == 'a${index}{}'
		assert resource.request_type == 'stylesheet'
	}
	assert received['file://${directory}/missing.js'].error != ''
}

fn test_document_preloads_every_stylesheet_and_bounds_images() {
	mut markup := '<html><head>'
	for index in 0 .. max_preloaded_resources + 5 {
		markup += '<link rel="stylesheet" href="/${index}.css">'
	}
	markup += '</head><body><img src="/late.png"></body></html>'
	document := html.parse_document(markup)
	urls := document_preload_resource_urls(document, 'https://example.com/')
	// Stylesheets beyond the image budget would otherwise be fetched serially
	// on the UI thread while the page is installed.
	assert urls.len == max_preloaded_resources + 5
	assert urls[0] == 'https://example.com/0.css'
	assert urls[urls.len - 1] == 'https://example.com/${max_preloaded_resources + 4}.css'
	mut small := '<html><head><link rel="stylesheet" href="/a.css"></head><body>'
	for index in 0 .. max_preloaded_resources + 5 {
		small += '<img src="/${index}.png">'
	}
	small += '</body></html>'
	images := document_preload_resource_urls(html.parse_document(small), 'https://example.com/')
	assert images.len == max_preloaded_resources
	assert images[0] == 'https://example.com/a.css'
	assert images[images.len - 1] == 'https://example.com/${max_preloaded_resources - 2}.png'
}
