// SPDX-License-Identifier: BSD-2-Clause
// EnvironmentSettingsSnapshot's Fetch client projection and WorkerHost's
// initial-script referrer adjustment. No live parent Window crosses processes.
module html

import contentsecuritypolicy as csp
import dom
import fetch
import mixedcontentcore
import securecontexts
import url as liburl

pub fn EnvironmentSettingsSnapshot.create_for_worker_fetch(serialized SerializedEnvironmentSettingsObject) &EnvironmentSettingsSnapshot {
	creation_url := if serialized.global is SerializedWindow {
		serialized.global.associated_document.url
	} else {
		serialized.creation_url
	}
	// WorkerHost.cpp substitutes the current Document URL because the snapshot
	// has no Window. Referrer Policy otherwise uses its original creation URL,
	// which can differ after same-document navigation or document replacement.
	return EnvironmentSettingsSnapshot.create(SerializedEnvironmentSettingsObject{
		...serialized
		creation_url: creation_url
	})
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_api_base_url() dom.URL {
	return snapshot.api_base_url()
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_is_window() bool {
	return false
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_is_top_level_window() bool {
	return false
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_origin() dom.Origin {
	return snapshot.origin()
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_document_url() ?dom.URL {
	return none
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_creation_url() dom.URL {
	return snapshot.creation_url
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_embedder_policy_credentialless() bool {
	return snapshot.policy_container().embedder_policy.value == .credentialless
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_top_level_origin() ?dom.Origin {
	return snapshot.top_level_origin
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_top_level_creation_url() ?dom.URL {
	return snapshot.top_level_creation_url
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_cross_origin_isolated_capability() bool {
	return snapshot.cross_origin_isolated_capability() == .yes
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_policy_container() fetch.RequestPolicyContainer {
	container := snapshot.policy_container()
	return fetch.RequestPolicyContainer{
		referrer_policy: container.referrer_policy.to_string()
		csp_list: fetch_csp_policy_list(container.csp_list)
		integrity_policy: fetch_integrity_policy(container.integrity_policy)
		report_only_integrity_policy: fetch_integrity_policy(container.report_only_integrity_policy)
	}
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_mixed_security_context() mixedcontentcore.EnvironmentSettings {
	return mixedcontentcore.EnvironmentSettings{
		origin_potentially_trustworthy: securecontexts.is_origin_potentially_trustworthy(snapshot.origin()) == .potentially_trustworthy
		global_kind: .worker
	}
}

pub fn (snapshot &EnvironmentSettingsSnapshot) fetch_request_client_csp_global() &csp.GlobalContext {
	return &csp.GlobalContext{
		url: liburl.parse(snapshot.creation_url.serialize()) or { panic('invalid snapshot CSP URL') }
		policy_list: fetch_csp_policy_list(snapshot.policy_container().csp_list)
	}
}
