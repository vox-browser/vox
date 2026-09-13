// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Browser-process requests for external navigation, transport failure, HSTS,
// cookies, storage usage, and cross-context storage notifications.
module page

pub struct ExternalURLRequest {
pub:
	url                      string
	initiator_origin         string
	has_transient_activation bool
}

pub struct HSTSPolicy {
pub:
	max_age_seconds    u64
	include_subdomains bool
}

pub struct StorageChange {
pub:
	endpoint  string
	url       string
	key       ?string
	old_value ?string
	new_value ?string
}

pub struct IndexedDatabaseUpdate {
pub:
	url     string
	changes string
}

pub fn (mut client PageClient) page_did_request_external_url(url string, initiator_origin string, has_transient_activation bool) {
	client.external_url_requests_ << ExternalURLRequest{
		url: url
		initiator_origin: initiator_origin
		has_transient_activation: has_transient_activation
	}
	client.record('request-external-url', '${url}:${initiator_origin}:${has_transient_activation}')
}

pub fn (client &PageClient) external_url_requests() []ExternalURLRequest {
	return client.external_url_requests_.clone()
}

pub fn (mut client PageClient) page_did_delete_all_cookies(url string) {
	client.record('delete-all-cookies', url)
}

pub fn (mut client PageClient) page_did_lose_request_server_connection() {
	if client.request_server_connection_lost_ {
		return
	}
	client.request_server_connection_lost_ = true
	client.record('lose-request-server-connection', '')
}

pub fn (client &PageClient) request_server_connection_lost() bool {
	return client.request_server_connection_lost_
}

pub fn (mut client PageClient) page_did_simulate_worker_request_server_connection_loss() {
	client.worker_request_server_loss_count_++
	client.record('simulate-worker-request-server-connection-loss', '')
}

pub fn (client &PageClient) worker_request_server_loss_count() u64 {
	return client.worker_request_server_loss_count_
}

pub fn (mut client PageClient) page_did_store_hsts_policy(domain string, policy HSTSPolicy) {
	normalized_domain := domain.to_lower().trim_right('.')
	if normalized_domain == '' {
		return
	}
	if policy.max_age_seconds == 0 {
		client.hsts_policies_.delete(normalized_domain)
	} else {
		client.hsts_policies_[normalized_domain] = policy
	}
	client.record('store-hsts-policy', '${normalized_domain}:${policy.max_age_seconds}:${policy.include_subdomains}')
}

pub fn (client &PageClient) page_did_is_known_hsts_host(domain string) bool {
	mut candidate := domain.to_lower().trim_right('.')
	for candidate != '' {
		if policy := client.hsts_policies_[candidate] {
			if candidate == domain.to_lower().trim_right('.') || policy.include_subdomains {
				return true
			}
		}
		dot := candidate.index('.') or { break }
		candidate = candidate[dot + 1..]
	}
	return false
}

pub fn (mut client PageClient) set_storage_usage(storage_key string, usage u64) {
	client.storage_usage_[storage_key] = usage
}

pub fn (client &PageClient) page_did_request_storage_usage(storage_key string) u64 {
	return client.storage_usage_[storage_key] or { 0 }
}

pub fn (mut client PageClient) page_did_broadcast_storage_change(endpoint string, url string, key ?string, old_value ?string, new_value ?string) {
	client.storage_changes_ << StorageChange{
		endpoint: endpoint
		url: url
		key: key
		old_value: old_value
		new_value: new_value
	}
	client.record('broadcast-storage-change', '${endpoint}:${url}:${key or { '' }}')
}

pub fn (client &PageClient) storage_changes() []StorageChange {
	return client.storage_changes_.clone()
}

pub fn (mut client PageClient) page_did_update_indexed_database(url string, changes string) {
	client.indexed_database_updates_ << IndexedDatabaseUpdate{
		url: url
		changes: changes
	}
	client.record('update-indexed-database', '${url}:${changes}')
}

pub fn (client &PageClient) indexed_database_updates() []IndexedDatabaseUpdate {
	return client.indexed_database_updates_.clone()
}
