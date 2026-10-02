module requestserver

import css
import dom
import html
import net
import os
import time
import webidl

fn serve_native_font(mut listener net.TcpListener, bytes []u8) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: font/ttf\r\nContent-Length: ${bytes.len}\r\nConnection: close\r\n\r\n') or {
		panic(err)
	}
	// Exercise the streamed body receiver rather than one synthetic response.
	_ := socket.write(bytes[..64]) or { panic(err) }
	time.sleep(20 * time.millisecond)
	mut offset := 64
	for offset < bytes.len {
		offset += socket.write(bytes[offset..]) or { panic(err) }
	}
}

fn native_font_document(address string) (&dom.Document, &html.EventLoop, &css.FontComputer, &css.FontFaceSet) {
	mut document := html.parse_document_with_url('<!doctype html><body>native font</body>', dom.URL{
		value: address
	})
	document.set_origin(document.url.origin())
	_ := html.WindowModel.create_top_level(document, none, 'native-font') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	computer := css.FontComputer.create_for_document(document)
	return document, settings.responsible_event_loop(), computer, css.FontFaceSet.create_for_font_computer(computer)
}

fn test_font_set_load_uses_real_curl_stream_and_owning_source_tasks() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	server := spawn serve_native_font(mut listener, bytes)
	_, mut owner, mut computer, mut set := native_font_document('http://${listener.addr()!}/owner')
	mut transport := NativeFontFetchTransport.create()!
	defer { transport.close() }
	computer.set_fetch_host(transport.fetch_host())
	face := css.FontFaceObject.construct_impl('Native streamed font',
		css.FontFaceSource.from_string('url("font.ttf")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := set.load('16px "Native streamed font"', 'A')!
	assert promise.state == .pending
	assert face.status() == .unloaded
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [promise, deadline] () bool {
		return promise.state != .pending || time.sys_mono_now() >= deadline
	})
	assert promise.state == .fulfilled, 'face=${face.status()}, active=${transport.connection.active_request_count()}, queue_empty=${owner.task_queue().is_empty()}'
	assert face.status() == .loaded
	assert face.parsed_font != unsafe { nil }
	assert promise.result.sequence_value.map(it.opaque_id) == [u64(voidptr(face))]
	assert transport.connection.active_request_count() == 0
	server.wait()
}

fn test_document_font_file_transport_remains_deferred_and_uses_fetch_body_sniffing() {
	$if !darwin { return }
	_, mut owner, mut computer, mut set :=
		native_font_document('file:///System/Library/Fonts/Supplemental/fixture.html')
	mut transport := NativeFontFetchTransport.create()!
	defer { transport.close() }
	computer.set_fetch_host(transport.fetch_host())
	mut face := css.FontFaceObject.construct_impl('Native file font',
		css.FontFaceSource.from_string('url("Arial.ttf")'), css.FontFaceDescriptors{})
	set.add(face)!
	promise := face.load()
	assert face.status() == .loading
	assert promise.state == .pending
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [promise, deadline] () bool {
		return promise.state != .pending || time.sys_mono_now() >= deadline
	})
	assert promise.state == webidl.PromiseState.fulfilled
	assert face.status() == .loaded
}
