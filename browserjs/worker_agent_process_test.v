module browserjs

import html
import dom
import fetch
import http
import platform

fn worker_child_test_start(source string) !&WorkerChildSession {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	url := dom.URL{value: 'https://worker-agent.test/entry.js'}
	transport := &fetch.FetchHost{
		perform: fn [source, url] (request &fetch.Request) !&fetch.Response {
			assert request.current_url() == url
			mut response := fetch.Response.create()
			response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
			response.set_body_bytes(source.bytes())
			return response
		}
	}
	mut child := WorkerChildSession.create(transport)
	child.accept(WorkerProcessFrame{
		kind: u32(WorkerAgentFrameKind.start)
		bytes: encode_worker_startup(WorkerStartup{
			url: url
			outside: html.SerializedEnvironmentSettingsObject{
				creation_url: url
				api_base_url: url
				origin: url.origin()
				global: html.SerializedWindow{associated_document: html.SerializedDocument{
					url: url
					relevant_settings_object_is_secure_context: true
				}}
			}
			options: html.WorkerOptions{name: 'map child'}
			creation_time: 12
		})!
	})!
	return child
}

fn test_worker_child_session_initializes_once_and_delivers_frames_in_the_actual_worker_realm() {
	mut child := worker_child_test_start('postMessage("entry");onmessage=event=>postMessage(event.data);')!
	defer { child.close() }
	mut frames := child.take_outgoing()
	assert frames.len == 2
	assert frames[0].kind == u32(WorkerAgentFrameKind.ready) && frames[0].bytes.len == 0
	assert frames[1].kind == u32(WorkerAgentFrameKind.message)
	mut receiver := Runtime.create()
	defer { receiver.close() }
	bridge := ArrayBufferTransferBridge.create(receiver)!
	entry := bridge.deserialize(decode_worker_message(frames[1].bytes)!)!
	assert receiver.binding_dom_string(entry)! == 'entry'
	payload := bridge.serialize(receiver.evaluate_host_value('({text:"Санкт-Петербург 😀"})')!, [])!
	child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.message), bytes: encode_worker_message(payload)!})!
	assert child.take_outgoing().len == 0
	child.process()
	frames = child.take_outgoing()
	assert frames.len == 1 && frames[0].kind == u32(WorkerAgentFrameKind.message)
	message := bridge.deserialize(decode_worker_message(frames[0].bytes)!)!
	assert receiver.binding_dom_string(receiver.binding_property(message, 'text')!)! == 'Санкт-Петербург 😀'
	assert !child.is_finished()
	if _ := child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.start)}) { assert false }
}

fn test_worker_child_session_reports_load_failures_without_publishing_ready_or_messages() {
	mut child := worker_child_test_start('postMessage("unreachable"); const = ;')!
	defer { child.close() }
	assert child.is_finished()
	frames := child.take_outgoing()
	assert frames.len == 1 && frames[0].kind == u32(WorkerAgentFrameKind.load_failure)
	assert frames[0].bytes.len == 0
	child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.message), bytes: [u8(255)]})!
	child.process()
	assert child.take_outgoing().len == 0
}

fn test_worker_child_session_drains_messages_posted_in_the_task_that_closes_the_worker() {
	mut child := worker_child_test_start('close();postMessage("last");')!
	defer { child.close() }
	assert child.is_finished()
	frames := child.take_outgoing()
	assert frames.len == 2
	assert frames[0].kind == u32(WorkerAgentFrameKind.ready)
	assert frames[1].kind == u32(WorkerAgentFrameKind.message)
	child.process()
	assert child.take_outgoing().len == 0
}

fn test_worker_child_session_rejects_parent_protocol_errors_and_shutdown_discards_queued_work() {
	mut unstarted := WorkerChildSession.create(none)
	defer { unstarted.close() }
	for kind in [u32(0), u32(WorkerAgentFrameKind.message), u32(WorkerAgentFrameKind.ready), u32(999)] {
		if _ := unstarted.accept(WorkerProcessFrame{kind: kind}) { assert false }
	}
	mut child := worker_child_test_start('onmessage=event=>postMessage(event.data);setInterval(()=>{},1);')!
	assert child.take_outgoing().len == 1
	if _ := child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.shutdown), bytes: [u8(1)]}) { assert false }
	child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.shutdown)})!
	assert child.is_finished()
	assert child.agent?.state() == .closed
	assert child.take_outgoing().len == 0
	child.close()
	assert run_worker_process_role(['vox']) == none
	assert run_worker_process_role(['vox', '--headless-smoke']) == none
	assert run_worker_process_role(['vox', '--vox-script-worker-v1', 'invalid'])? == 2
}

fn test_worker_child_session_owns_received_frames_and_output_across_scratch_resets() {
	mut caller := platform.begin_thread_scratch('worker child caller')
	mut child := worker_child_test_start('postMessage({name,url:location.href});')!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker child delivery')
	frames := child.take_outgoing()
	delivery.finish()
	assert frames.len == 2
	mut receiver := Runtime.create()
	bridge := ArrayBufferTransferBridge.create(receiver)!
	message := bridge.deserialize(decode_worker_message(frames[1].bytes)!)!
	assert receiver.binding_dom_string(receiver.binding_property(message, 'name')!)! == 'map child'
	assert receiver.binding_dom_string(receiver.binding_property(message, 'url')!)! == 'https://worker-agent.test/entry.js'
	child.close()
	receiver.close()
}
