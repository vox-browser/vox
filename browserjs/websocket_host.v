// WebSocket.idl binding for window realms. The browsernet connection owns the
// RFC 6455 transport on its own thread; this host delivers its events as
// WebSocket-task-source tasks on the owning event loop.
@[has_globals]
module browserjs

import browsernet
import dom
import html
import webidl

@[heap]
pub struct WebSocketHost {
	document  &dom.Document
	settings  &html.EnvironmentSettingsObject
	replay    ?AnimationFrameReplayHook
	ca_bundle string
mut:
	runtime   &Runtime = unsafe { nil }
	deliver   ?webidl.CallbackType
	function  voidptr
	sockets   map[int]&browsernet.WebSocketConnection
	next_id   int
	installed bool
	closed    bool
}

__global websocket_hosts_ = []&WebSocketHost{}
__global websocket_wake_ = fn () {}

// Embedders wake their frame loop so poll_websocket_hosts() runs promptly.
// The wake function is called on connection threads.
pub fn set_websocket_wake(wake fn ()) {
	websocket_wake_ = wake
}

// Queue every pending connection event as a task. Call on the owning thread.
pub fn poll_websocket_hosts() {
	for mut host in websocket_hosts_ {
		host.poll()
	}
}

pub fn WebSocketHost.create(document &dom.Document, ca_bundle string, replay ?AnimationFrameReplayHook) !&WebSocketHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	return &WebSocketHost{
		document:  document
		settings:  unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		replay:    replay
		ca_bundle: ca_bundle
	}
}

pub fn (mut host WebSocketHost) close() {
	if host.closed { return }
	host.closed = true
	for _, mut connection in host.sockets {
		connection.close(1001, '')
	}
	host.sockets = {}
	for index, other in websocket_hosts_ {
		if voidptr(other) == voidptr(&host) {
			websocket_hosts_.delete(index)
			break
		}
	}
	if host.function != unsafe { nil } && !host.runtime.closed {
		host.runtime.release_javascript_value(host.function)
	}
}

fn (mut host WebSocketHost) poll() {
	if host.closed { return }
	mut finished := []int{}
	for id, mut connection in host.sockets {
		for event in connection.take_events() {
			host_handle := voidptr(&host)
			html.queue_a_task(.web_socket, host.settings.responsible_event_loop(), host.document, fn [host_handle, id, event] () {
				mut owner := unsafe { &WebSocketHost(host_handle) }
				owner.dispatch(id, event)
			})
		}
		if connection.is_finished() { finished << id }
	}
	for id in finished {
		host.sockets.delete(id)
	}
}
