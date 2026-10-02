module page

import fetch
import streams

fn download_test_reader() (&streams.ReadableStream, &streams.ReadableStreamDefaultReader) {
	mut stream := streams.ReadableStream.construct_impl(streams.UnderlyingSource{}, streams.QueuingStrategy{}) or { panic(err) }
	return stream, stream.get_default_reader() or { panic(err) }
}

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
	controller := fetch.FetchController.create()
	_, reader := download_test_reader()
	client.page_did_register_download_controller(id, controller)
	client.page_did_register_download_reader(id, reader)
	client.page_did_receive_download_data(id, [u8(3), 4, 5])
	active := client.download(id) or { panic('download was not retained') }
	assert active.data == [u8(1), 2, 3, 4, 5]
	assert active.controller_registered
	assert active.reader_registered
	assert !client.page_is_download_canceled(id)

	client.page_did_finish_download(id)
	assert (client.download(id)?).status == .finished
	assert id !in client.download_controllers_
	assert id !in client.download_readers_
	client.page_did_fail_download(id, 'too late')
	assert (client.download(id)?).status == .finished
	client.page_did_unregister_download(id)
	assert (client.download(id)?).status == .finished
}

fn test_page_client_canceled_and_failed_downloads_stop_accepting_data() {
	mut client := PageClient.create()
	canceled_id := client.page_did_start_download_from_url('https://example.test/a', 'a', none) or {
		panic('download hand-off was rejected')
	}
	client.cancel_download(canceled_id)
	assert !client.page_is_download_canceled(canceled_id) // No live transfer to cancel.
	controller := fetch.FetchController.create()
	stream, reader := download_test_reader()
	client.page_did_register_download_controller(canceled_id, controller)
	client.page_did_register_download_reader(canceled_id, reader)
	client.cancel_download(canceled_id)
	assert client.page_is_download_canceled(canceled_id)
	assert controller.state() == .stopped
	assert stream.state() == .closed
	assert reader.closed().state() == .fulfilled
	assert canceled_id !in client.download_controllers_
	assert canceled_id !in client.download_readers_
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

fn test_live_download_handles_can_be_canceled_without_a_local_archive() {
	mut client := PageClient.create()
	controller := fetch.FetchController.create()
	stream, reader := download_test_reader()
	client.page_did_register_download_controller(99, controller)
	client.page_did_register_download_reader(99, reader)
	client.cancel_download(99)
	assert controller.state() == .stopped
	assert stream.state() == .closed
	assert client.page_is_download_canceled(99)
	client.page_did_unregister_download(99)
	assert !client.page_is_download_canceled(99)
}
