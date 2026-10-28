module html

import dom
import fetch
import http
import mixedcontentcore
import url as liburl

fn snapshot_fetch_serialized() SerializedEnvironmentSettingsObject {
	creation := dom.URL{value: 'https://snapshot.test/original'}
	return SerializedEnvironmentSettingsObject{
		id: 'outside-parent'
		creation_url: creation
		top_level_creation_url: dom.URL{value: 'https://top.test/start'}
		top_level_origin: dom.URL{value: 'https://top.test/'}.origin()
		api_base_url: dom.URL{value: 'https://snapshot.test/assets/'}
		origin: creation.origin()
		policy_container: SerializedPolicyContainer{
			embedder_policy: EmbedderPolicy{value: .credentialless}
			referrer_policy: .same_origin
		}
		cross_origin_isolated_capability: .yes
		global: SerializedWindow{
			associated_document: SerializedDocument{
				url: dom.URL{value: 'https://user:secret@snapshot.test/current?map=2#private'}
				relevant_settings_object_is_secure_context: true
			}
		}
	}
}

fn test_snapshot_worker_fetch_uses_current_document_referrer_without_changing_parent() {
	serialized := snapshot_fetch_serialized()
	ordinary := EnvironmentSettingsSnapshot.create(serialized)
	snapshot := EnvironmentSettingsSnapshot.create_for_worker_fetch(serialized)
	assert ordinary.creation_url == serialized.creation_url
	assert serialized.creation_url.value == 'https://snapshot.test/original'
	assert snapshot.api_base_url() == serialized.api_base_url
	assert snapshot.creation_url.value == 'https://user:secret@snapshot.test/current?map=2#private'
	assert snapshot.responsible_document() == none
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value: 'https://snapshot.test/worker.js'})
	request.set_client(snapshot)
	request.destination = .worker
	request.cache_mode = .no_store
	assert request.client_present && !request.client_is_window && !request.client_is_top_level_window
	assert request.client_document_url == none
	assert (request.client_creation_url or { panic("Missing client creation URL") }) == snapshot.creation_url
	assert request.embedder_policy_credentialless
	fetch.populate_request_from_client(mut request)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: fn (request &fetch.Request) !&fetch.Response {
			assert request.header_list.get('Referer')? == 'https://snapshot.test/current?map=2'
			return fetch.Response.create()
		}
	}).response()?
	assert !response.is_network_error()
}

fn test_snapshot_nested_worker_keeps_creation_url_and_top_level_client_metadata() {
	window := snapshot_fetch_serialized()
	serialized := SerializedEnvironmentSettingsObject{
		...window
		global: SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}
	}
	snapshot := EnvironmentSettingsSnapshot.create_for_worker_fetch(serialized)
	client := fetch.RequestClient(snapshot)
	assert client.fetch_request_client_creation_url() == serialized.creation_url
	assert client.fetch_request_client_api_base_url() == serialized.api_base_url
	assert client.fetch_request_client_origin().is_same_origin(serialized.origin)
	assert client.fetch_request_client_top_level_creation_url()? == serialized.top_level_creation_url?
	assert client.fetch_request_client_top_level_origin()?.is_same_origin(serialized.top_level_origin?)
	assert !client.fetch_request_client_cross_origin_isolated_capability()
	without_top := EnvironmentSettingsSnapshot.create_for_worker_fetch(SerializedEnvironmentSettingsObject{
		...serialized
		top_level_creation_url: none
		top_level_origin: none
	})
	assert without_top.fetch_request_client_top_level_creation_url() == none
	assert without_top.fetch_request_client_top_level_origin() == none
}

fn snapshot_fetch_forbidden_transport(_ &fetch.Request) !&fetch.Response {
	panic('snapshot policy must block before reaching transport')
}

fn test_snapshot_client_enforces_its_cloned_parent_csp_in_actual_fetch() {
	parent := snapshot_fetch_serialized()
	mut directives := [SerializedCSPDirective{name: 'worker-src', value: ["'none'"]}]
	serialized := SerializedEnvironmentSettingsObject{
		...parent
		policy_container: SerializedPolicyContainer{
			csp_list: [SerializedCSPPolicy{
				directives: directives
				disposition: .enforce
				source: .header
				self_origin: parent.origin
				pre_parsed_policy_string: "worker-src 'none'"
			}]
			referrer_policy: .no_referrer
		}
	}
	snapshot := EnvironmentSettingsSnapshot.create_for_worker_fetch(serialized)
	directives[0] = SerializedCSPDirective{name: 'worker-src', value: ['*']}
	projected := snapshot.fetch_request_client_policy_container()
	assert projected.referrer_policy == 'no-referrer'
	assert projected.csp_list.policies[0].directives()[0].value() == ["'none'"]
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value: 'https://snapshot.test/worker.js'})
	request.set_client(snapshot)
	request.destination = .worker
	request.cache_mode = .no_store
	fetch.populate_request_from_client(mut request)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: snapshot_fetch_forbidden_transport
	}).response()?
	assert response.is_network_error()
}

fn test_snapshot_client_blocks_mixed_worker_script_requests_before_transport() {
	snapshot := EnvironmentSettingsSnapshot.create_for_worker_fetch(snapshot_fetch_serialized())
	security := fetch.RequestSecurityClient(snapshot)
	context := security.fetch_request_client_mixed_security_context()
	assert context.global_kind == .worker
	assert mixedcontentcore.does_settings_prohibit_mixed_security_contexts(&context) == .prohibits_mixed_security_contexts
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value: 'http://snapshot.test/worker.js'})
	request.set_client(snapshot)
	request.destination = .worker
	request.cache_mode = .no_store
	fetch.populate_request_from_client(mut request)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: snapshot_fetch_forbidden_transport
	}).response()?
	assert response.is_network_error()
}

fn test_snapshot_csp_projection_preserves_opaque_origin_identity() {
	parent := snapshot_fetch_serialized()
	origin := liburl.Origin.opaque([u8(71), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]!, .standard)
	snapshot := EnvironmentSettingsSnapshot.create_for_worker_fetch(SerializedEnvironmentSettingsObject{
		...parent
		origin: dom.origin_from_liburl(origin)
		policy_container: SerializedPolicyContainer{
			csp_list: [SerializedCSPPolicy{
				self_origin: dom.origin_from_liburl(origin)
				disposition: .report
				source: .meta
			}]
		}
	})
	global := snapshot.fetch_request_client_csp_global()
	assert global.url.serialize(false) == snapshot.creation_url.serialize()
	assert global.policy_list.policies[0].self_origin?.is_same_origin(origin)
	assert global.policy_list.policies[0].disposition() == .report
	assert global.policy_list.policies[0].source() == .meta
	assert !snapshot.fetch_request_client_mixed_security_context().origin_potentially_trustworthy
}

@[heap]
struct SnapshotFetchScriptResult {
mut:
	script ?&Script
	called bool
}

fn test_classic_worker_entry_fetch_accepts_snapshot_and_compiles_in_the_inside_realm() {
	outside := EnvironmentSettingsSnapshot.create_for_worker_fetch(snapshot_fetch_serialized())
	entry := dom.URL{value: 'https://snapshot.test/assets/entry.js'}
	mut realm := &ScriptingRealm{}
	scope := DedicatedWorkerGlobalScope.create(entry, WorkerOptions{}, realm)
	environment := WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		snapshot_fetch_serialized(), 18)
	for mime in ['text/javascript', 'text/plain'] {
		result := &SnapshotFetchScriptResult{}
		result_ptr := voidptr(result)
		perform := fn [mime, outside] (request &fetch.Request, top TopLevelModule) !&fetch.Response {
			assert top == .yes
			assert (request.destination or { panic("Missing script destination") }) == fetch.Destination.worker
			assert request.mode == .same_origin && request.credentials_mode == .same_origin
			assert (request.parser_metadata or { panic("Missing parser metadata") }) == fetch.ParserMetadata.not_parser_inserted
			assert request.use_url_credentials && !request.client_is_window
			assert (request.client_creation_url or { panic("Missing client creation URL") }) == outside.creation_url
			mut response := fetch.Response.create()
			response.url_list = [dom.URL{value: 'https://snapshot.test/final/entry.js'}]
			response.header_list.append(http.Header{name: 'Content-Type', value: mime})
			response.set_body_bytes('postMessage("Санкт-Петербург");'.bytes())
			return response
		}
		complete := fn [result_ptr] (script ?&Script) {
			mut result := unsafe { &SnapshotFetchScriptResult(result_ptr) }
			result.called = true
			result.script = script
		}
		fetch_classic_worker_script(entry, outside, .worker, environment.settings, perform, complete)!
		assert result.called
		if mime == 'text/plain' {
			assert result.script == none
		} else {
			script := unsafe { &ClassicScript(result.script?) }
			assert script.source == 'postMessage("Санкт-Петербург");'
			assert script.filename() == 'https://snapshot.test/final/entry.js'
			assert voidptr(script.realm) == voidptr(realm)
		}
	}
}
