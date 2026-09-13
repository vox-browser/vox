module page

fn test_page_client_external_url_and_request_server_boundaries() {
	mut client := PageClient.create()
	client.page_did_request_external_url('mailto:test@example.com', 'https://example.test', true)
	assert client.external_url_requests() == [ExternalURLRequest{
		url: 'mailto:test@example.com'
		initiator_origin: 'https://example.test'
		has_transient_activation: true
	}]
	client.page_did_lose_request_server_connection()
	client.page_did_lose_request_server_connection()
	assert client.request_server_connection_lost()
	assert client.events.filter(it.name == 'lose-request-server-connection').len == 1
	client.page_did_simulate_worker_request_server_connection_loss()
	client.page_did_simulate_worker_request_server_connection_loss()
	assert client.worker_request_server_loss_count() == 2
	client.page_did_delete_all_cookies('https://example.test')
	assert client.events.last().name == 'delete-all-cookies'
}

fn test_page_client_hsts_policy_includes_subdomains_and_honors_removal() {
	mut client := PageClient.create()
	client.page_did_store_hsts_policy('Example.TEST.', HSTSPolicy{
		max_age_seconds: 3600
		include_subdomains: true
	})
	assert client.page_did_is_known_hsts_host('example.test')
	assert client.page_did_is_known_hsts_host('www.example.test')
	assert !client.page_did_is_known_hsts_host('other.test')
	client.page_did_store_hsts_policy('example.test', HSTSPolicy{})
	assert !client.page_did_is_known_hsts_host('example.test')
	assert !client.page_did_is_known_hsts_host('www.example.test')
}

fn test_page_client_storage_usage_and_change_notifications_are_retained() {
	mut client := PageClient.create()
	assert client.page_did_request_storage_usage('https://example.test') == 0
	client.set_storage_usage('https://example.test', 4096)
	assert client.page_did_request_storage_usage('https://example.test') == 4096
	client.page_did_broadcast_storage_change('local', 'https://example.test/page', 'theme',
		'light', 'dark')
	assert client.storage_changes() == [StorageChange{
		endpoint: 'local'
		url: 'https://example.test/page'
		key: 'theme'
		old_value: 'light'
		new_value: 'dark'
	}]
	client.page_did_update_indexed_database('https://example.test', 'put:people:7')
	assert client.indexed_database_updates() == [IndexedDatabaseUpdate{
		url: 'https://example.test'
		changes: 'put:people:7'
	}]
}
