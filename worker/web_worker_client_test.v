module worker

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
