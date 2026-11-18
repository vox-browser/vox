module main

import adblock
import html
import net
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

fn serve_resource_fetch_result(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(3 * time.second)
	mut request := []u8{len: 8192}
	socket.read(mut request) or { panic(err) }
	socket.write_string('HTTP/1.1 200 OK\r\nCache-Control: no-store\r\nX-Resource: first\r\nX-Resource: second\r\nContent-Length: 3\r\nConnection: close\r\n\r\na\x00b') or { panic(err) }
}

fn test_background_resource_result_survives_request_and_worker_exit() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0') or { panic(err) }
	defer { listener.close() or {} }
	listener.set_accept_timeout(5 * time.second)
	host := listener.addr() or { panic(err) }
	origin := 'http://${host}'
	address := origin + '/resource'
	source := origin + '/document'
	server := spawn serve_resource_fetch_result(mut listener)
	results := chan PreloadedResource{cap: 1}
	worker := spawn fetch_resource_in_background(address, source, 'image', results)
	worker.wait()
	server.wait()
	assert results.len == 1
	resource := <-results
	assert resource.error == ''
	assert resource.url == address
	assert resource.source_url == source
	assert resource.final_url == address
	assert resource.request_type == 'image'
	assert resource.status_code == 200
	assert resource.body == 'a\x00b'
	tags := resource.response_headers.filter(it.name.to_lower() == 'x-resource')
	assert tags.map(it.value) == ['first', 'second']
	assert resource.response_time >= resource.request_time
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
