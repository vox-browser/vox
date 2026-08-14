module fetch

import dom

fn test_response_defaults() {
	response := Response.create()
	assert response.response_type == .default
	assert response.status == u16(200)
	assert response.status_message == ''
	assert response.request_includes_credentials == true
	assert response.redirect_taint == .same_origin
	assert response.aborted == false
	assert response.is_network_error() == false
	assert response.is_aborted_network_error() == false
}

fn test_network_error() {
	response := Response.network_error('boom')
	assert response.response_type == .error
	assert response.status == u16(0)
	assert response.network_error_message? == 'boom'
	assert response.is_network_error() == true
	assert response.is_aborted_network_error() == false
}

fn test_aborted_network_error() {
	response := Response.aborted_network_error()
	assert response.aborted == true
	assert response.is_aborted_network_error() == true
	// An aborted network error is still a network error.
	assert response.is_network_error() == true
}

fn test_is_network_error_requires_all_conditions() {
	// A default 200 response is not a network error.
	assert Response.create().is_network_error() == false
	// An error response with a non-empty status message is not a network error.
	mut r := Response.network_error('x')
	r.status_message = 'Not Found'
	assert r.is_network_error() == false
	// An error response with a body is not a network error.
	mut r2 := Response.network_error('x')
	r2.body = 'data'.bytes()
	assert r2.is_network_error() == false
}

fn test_response_url() {
	mut response := Response.create()
	assert response.url() == none
	response.url_list << dom.URL{
		value: 'https://a/1'
	}
	response.url_list << dom.URL{
		value: 'https://a/2'
	}
	// A response's URL is the last URL in its URL list.
	assert response.url()?.value == 'https://a/2'
}
