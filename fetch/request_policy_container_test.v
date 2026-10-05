module fetch

import dom

struct PolicyContainerTestClient {
	referrer_policy string
}

fn (_ &PolicyContainerTestClient) fetch_request_client_api_base_url() dom.URL {
	return dom.URL{value: 'https://client.test/page'}
}

fn (client &PolicyContainerTestClient) fetch_request_client_policy_container() RequestPolicyContainer {
	return RequestPolicyContainer{
		referrer_policy: client.referrer_policy
	}
}

fn (_ &PolicyContainerTestClient) fetch_request_client_is_window() bool {
	return true
}

fn (_ &PolicyContainerTestClient) fetch_request_client_is_top_level_window() bool {
	return true
}

fn (_ &PolicyContainerTestClient) fetch_request_client_origin() dom.Origin {
	return dom.Origin{
		value: 'https://client.test'
	}
}

fn (_ &PolicyContainerTestClient) fetch_request_client_document_url() ?dom.URL {
	return dom.URL{value: 'https://client.test/page'}
}

fn (_ &PolicyContainerTestClient) fetch_request_client_creation_url() dom.URL {
	return dom.URL{value: 'https://client.test/page'}
}

fn (_ &PolicyContainerTestClient) fetch_request_client_embedder_policy_credentialless() bool {
	return false
}

fn (_ &PolicyContainerTestClient) fetch_request_client_top_level_origin() ?dom.Origin {
	return none
}

fn (_ &PolicyContainerTestClient) fetch_request_client_top_level_creation_url() ?dom.URL {
	return none
}

fn (_ &PolicyContainerTestClient) fetch_request_client_cross_origin_isolated_capability() bool {
	return false
}

fn policy_container_test_host(request &Request) !&Response {
	mut response := Response.create()
	response.url_list = request.url_list.clone()
	return response
}

fn test_an_empty_request_referrer_policy_takes_the_client_policy_container_policy() {
	mut request := Request.create()
	request.set_client(&PolicyContainerTestClient{
		referrer_policy: 'no-referrer'
	})
	request.set_url(dom.URL{value: 'https://client.test/resource'})
	populate_request_from_client(mut request)
	resolved := request.resolved_policy_container or { panic('policy container was not resolved') }
	assert resolved.referrer_policy == 'no-referrer'

	_ := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: policy_container_test_host
	})
	assert request.referrer_policy == 'no-referrer'
}

fn test_a_request_without_a_client_gets_a_new_policy_container() {
	mut request := Request.create()
	request.set_url(dom.URL{value: 'https://client.test/resource'})
	request.origin = RequestOrigin{
		is_client: false
		origin: dom.Origin{
			value: 'https://client.test'
		}
	}
	populate_request_from_client(mut request)
	resolved := request.resolved_policy_container or { panic('policy container was not resolved') }
	assert resolved.referrer_policy == 'strict-origin-when-cross-origin'
}
