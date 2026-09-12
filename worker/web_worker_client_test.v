module worker

import dom
import html

__global (
	posted_broadcast_channel_names   = []string{}
	received_broadcast_channel_names = []string{}
)

fn record_posted_broadcast_message(message html.BroadcastChannelMessage) {
	posted_broadcast_channel_names << message.channel_name
}

fn record_received_broadcast_message(message html.BroadcastChannelMessage) {
	received_broadcast_channel_names << message.channel_name
}

fn cookie_callback(url string, source CookieSource) VersionedCookie {
	return VersionedCookie{
		name:    url
		value:   source.str()
		version: 7
	}
}

fn agent_callback(_ AgentType) WorkerAgentResponse {
	return WorkerAgentResponse{
		client: TransportHandle{
			id: 1
		}
		server: TransportHandle{
			id: 2
		}
	}
}

fn test_endpoint_fallbacks_and_callbacks() {
	mut client := &WebWorkerClient{}
	assert client.pid() == -1
	client.set_pid(4242)
	assert client.pid() == 4242
	assert client.did_request_cookie('https://example.test', .http) == VersionedCookie{}
	assert client.request_worker_agent(.dedicated_worker).client.id == 0
	client.on_request_cookie = cookie_callback
	client.on_request_worker_agent = agent_callback
	assert client.did_request_cookie('cookie', .non_http).version == 7
	assert client.request_worker_agent(.shared_worker).server.id == 2
	client.die()
	// Upstream die() is deliberately a no-op until WorkerAgent notification exists.
	assert client.did_request_cookie('still connected', .http).version == 7
}

fn test_worker_clients_forward_broadcast_channel_messages_in_both_directions() {
	posted_broadcast_channel_names.clear()
	received_broadcast_channel_names.clear()
	mut first := WebWorkerClient.create()
	mut second := WebWorkerClient.create()
	first.on_post_broadcast_message = record_posted_broadcast_message
	first.on_broadcast_message = record_received_broadcast_message
	second.on_broadcast_message = record_received_broadcast_message
	message := html.BroadcastChannelMessage{
		storage_key: 'partition'
		channel_name: 'worker-updates'
		source_origin: dom.Origin{ value: 'https://example.test' }
		source_process_id: 7
		source_channel_id: 9
	}
	first.did_post_broadcast_channel_message(message)
	assert posted_broadcast_channel_names == ['worker-updates']
	forward_broadcast_channel_message_to_workers(message)
	assert received_broadcast_channel_names == ['worker-updates', 'worker-updates']
	first.close()
	second.close()
}
