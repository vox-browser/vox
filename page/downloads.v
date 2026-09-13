// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient's download hand-off boundary. Fetch controllers and stream
// readers remain host-owned; their registrations and cancellation lifetime
// are retained here alongside the byte stream.
module page

pub enum DownloadStatus {
	in_progress
	finished
	failed
}

pub struct DownloadRequest {
pub:
	navigable_id              ?u64
	navigation_id             ?string
	url                       string
	suggested_filename        string
	total_size                ?u64
	request_server_client_id  ?int
	request_server_request_id ?u64
	initial_data              []u8
}

pub struct DownloadState {
pub:
	request DownloadRequest
pub mut:
	data                  []u8
	status                DownloadStatus
	error                 string
	canceled              bool
	controller_registered bool
	reader_registered     bool
}

pub fn (mut client PageClient) page_did_start_download(request DownloadRequest) ?u64 {
	download_id := client.next_download_id_
	client.next_download_id_++
	client.downloads_[download_id] = DownloadState{
		request: request
		data: request.initial_data.clone()
	}
	client.record('start-download', '${download_id}:${request.url}:${request.suggested_filename}')
	return download_id
}

pub fn (mut client PageClient) page_did_start_download_from_url(url string, suggested_filename string, total_size ?u64) ?u64 {
	return client.page_did_start_download(DownloadRequest{
		url: url
		suggested_filename: suggested_filename
		total_size: total_size
	})
}

pub fn (mut client PageClient) page_did_receive_download_data(download_id u64, data []u8) {
	mut download := client.downloads_[download_id] or { return }
	if download.status != .in_progress || download.canceled {
		return
	}
	download.data << data
	client.downloads_[download_id] = download
	client.record('receive-download-data', '${download_id}:${data.len}')
}

pub fn (mut client PageClient) page_did_finish_download(download_id u64) {
	mut download := client.downloads_[download_id] or { return }
	if download.status != .in_progress {
		return
	}
	download.status = .finished
	client.downloads_[download_id] = download
	client.record('finish-download', download_id.str())
}

pub fn (mut client PageClient) page_did_fail_download(download_id u64, error_message string) {
	mut download := client.downloads_[download_id] or { return }
	if download.status != .in_progress {
		return
	}
	download.status = .failed
	download.error = error_message
	client.downloads_[download_id] = download
	client.record('fail-download', '${download_id}:${error_message}')
}

pub fn (mut client PageClient) page_did_register_download_controller(download_id u64) {
	mut download := client.downloads_[download_id] or { return }
	download.controller_registered = true
	client.downloads_[download_id] = download
	client.record('register-download-controller', download_id.str())
}

pub fn (mut client PageClient) page_did_register_download_reader(download_id u64) {
	mut download := client.downloads_[download_id] or { return }
	download.reader_registered = true
	client.downloads_[download_id] = download
	client.record('register-download-reader', download_id.str())
}

pub fn (mut client PageClient) cancel_download(download_id u64) {
	mut download := client.downloads_[download_id] or { return }
	download.canceled = true
	client.downloads_[download_id] = download
	client.record('cancel-download', download_id.str())
}

pub fn (client &PageClient) page_is_download_canceled(download_id u64) bool {
	download := client.downloads_[download_id] or { return false }
	return download.canceled
}

pub fn (client &PageClient) download(download_id u64) ?DownloadState {
	download := client.downloads_[download_id] or { return none }
	return download
}

pub fn (mut client PageClient) page_did_unregister_download(download_id u64) {
	if download_id !in client.downloads_ {
		return
	}
	client.downloads_.delete(download_id)
	client.record('unregister-download', download_id.str())
}
