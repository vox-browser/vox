module page

fn test_page_client_tracks_download_stream_lifetime() {
	mut client := PageClient.create()
	id := client.page_did_start_download(DownloadRequest{
		navigable_id: 9
		navigation_id: 'navigation-1'
		url: 'https://example.test/report.pdf'
		suggested_filename: 'report.pdf'
		total_size: 5
		request_server_client_id: 3
		request_server_request_id: 17
		initial_data: [u8(1), 2]
	}) or { panic('download hand-off was rejected') }
	assert id == 1
	client.page_did_register_download_controller(id)
	client.page_did_register_download_reader(id)
	client.page_did_receive_download_data(id, [u8(3), 4, 5])
	active := client.download(id) or { panic('download was not retained') }
	assert active.data == [u8(1), 2, 3, 4, 5]
	assert active.controller_registered
	assert active.reader_registered
	assert !client.page_is_download_canceled(id)

	client.page_did_finish_download(id)
	assert (client.download(id)?).status == .finished
	client.page_did_fail_download(id, 'too late')
	assert (client.download(id)?).status == .finished
	client.page_did_unregister_download(id)
	assert client.download(id) == none
}

fn test_page_client_canceled_and_failed_downloads_stop_accepting_data() {
	mut client := PageClient.create()
	canceled_id := client.page_did_start_download_from_url('https://example.test/a', 'a', none) or {
		panic('download hand-off was rejected')
	}
	client.cancel_download(canceled_id)
	assert client.page_is_download_canceled(canceled_id)
	client.page_did_receive_download_data(canceled_id, [u8(9)])
	assert (client.download(canceled_id)?).data.len == 0

	failed_id := client.page_did_start_download_from_url('https://example.test/b', 'b', 10) or {
		panic('download hand-off was rejected')
	}
	client.page_did_fail_download(failed_id, 'network disconnected')
	failed := client.download(failed_id) or { panic('failed download was not retained') }
	assert failed.status == .failed
	assert failed.error == 'network disconnected'
	client.page_did_receive_download_data(failed_id, [u8(8)])
	assert (client.download(failed_id)?).data.len == 0
	assert client.events.map(it.name).contains('fail-download')
}
