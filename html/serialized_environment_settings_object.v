// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/Scripting/SerializedEnvironmentSettingsObject.{h,cpp} and
// HTML/Scripting/EnvironmentSettingsSnapshot.{h,cpp}.
module html

import dom
import math

pub enum CanUseCrossOriginIsolatedAPIs as u8 {
	no
	yes
}

pub struct SerializedDocument {
pub:
	url                                        dom.URL
	relevant_settings_object_is_secure_context bool
}

pub struct SerializedWindow {
pub:
	associated_document SerializedDocument
}

pub struct SerializedWorkerGlobalScope {
pub:
	relevant_settings_object_is_secure_context bool
}

pub type SerializedGlobal = SerializedWindow | SerializedWorkerGlobalScope

pub struct SerializedEnvironmentSettingsObject {
pub:
	id                               string
	creation_url                     dom.URL
	top_level_creation_url           ?dom.URL
	top_level_origin                 ?dom.Origin
	api_base_url                     dom.URL
	origin                           dom.Origin
	has_cross_site_ancestor          bool
	policy_container                 SerializedPolicyContainer
	cross_origin_isolated_capability CanUseCrossOriginIsolatedAPIs
	time_origin                      f64
	global                           SerializedGlobal
}

// EnvironmentSettingsSnapshot is an EnvironmentSettingsObject whose values are
// detached from a live Window/Worker. JS realm and execution-context ownership
// stay at the embedding boundary of this V port.
@[heap]
pub struct EnvironmentSettingsSnapshot {
pub:
	id                       string
	creation_url             dom.URL
	top_level_creation_url   ?dom.URL
	top_level_origin         ?dom.Origin
	api_base_url_            dom.URL
	origin_                  dom.Origin
	has_cross_site_ancestor_ bool
	policy_container_        PolicyContainer
	time_origin_             f64
}

pub fn EnvironmentSettingsSnapshot.create(serialized SerializedEnvironmentSettingsObject) &EnvironmentSettingsSnapshot {
	return &EnvironmentSettingsSnapshot{
		id:                       serialized.id
		creation_url:             serialized.creation_url
		top_level_creation_url:   serialized.top_level_creation_url
		top_level_origin:         serialized.top_level_origin
		api_base_url_:            serialized.api_base_url
		origin_:                  serialized.origin
		has_cross_site_ancestor_: serialized.has_cross_site_ancestor
		policy_container_:        create_a_policy_container_from_serialized_policy_container(serialized.policy_container)
		time_origin_:             serialized.time_origin
	}
}

pub fn (snapshot &EnvironmentSettingsSnapshot) responsible_document() ?&dom.Document {
	return none
}

pub fn (snapshot &EnvironmentSettingsSnapshot) api_base_url() dom.URL {
	return snapshot.api_base_url_
}

pub fn (snapshot &EnvironmentSettingsSnapshot) origin() dom.Origin {
	return snapshot.origin_
}

pub fn (snapshot &EnvironmentSettingsSnapshot) has_cross_site_ancestor() bool {
	return snapshot.has_cross_site_ancestor_
}

pub fn (snapshot &EnvironmentSettingsSnapshot) policy_container() &PolicyContainer {
	return &snapshot.policy_container_
}

pub fn (snapshot &EnvironmentSettingsSnapshot) cross_origin_isolated_capability() CanUseCrossOriginIsolatedAPIs {
	// This deliberately matches EnvironmentSettingsSnapshot.cpp, rather than the
	// capability in the serialized object.
	return .no
}

pub fn (snapshot &EnvironmentSettingsSnapshot) time_origin() f64 {
	return snapshot.time_origin_
}

fn environment_append_u32(mut output []u8, value u32) {
	output << u8(value)
	output << u8(value >> 8)
	output << u8(value >> 16)
	output << u8(value >> 24)
}

fn environment_append_u64(mut output []u8, value u64) {
	for shift in 0 .. 8 {
		output << u8(value >> (shift * 8))
	}
}

fn environment_append_string(mut output []u8, value string) {
	environment_append_u32(mut output, u32(value.len))
	output << value.bytes()
}

fn environment_append_bool(mut output []u8, value bool) {
	output << u8(value)
}

fn environment_append_optional_url(mut output []u8, value ?dom.URL) {
	if url := value {
		environment_append_bool(mut output, true)
		environment_append_string(mut output, url.value)
	} else {
		environment_append_bool(mut output, false)
	}
}

fn environment_append_optional_origin(mut output []u8, value ?dom.Origin) {
	if origin := value {
		environment_append_bool(mut output, true)
		environment_append_string(mut output, origin.serialize_for_ipc())
	} else {
		environment_append_bool(mut output, false)
	}
}

fn environment_append_policy_container(mut output []u8, container SerializedPolicyContainer) {
	environment_append_u32(mut output, u32(container.csp_list.len))
	for policy in container.csp_list {
		environment_append_u32(mut output, u32(policy.directives.len))
		for directive in policy.directives {
			environment_append_string(mut output, directive.name)
			environment_append_u32(mut output, u32(directive.value.len))
			for value in directive.value {
				environment_append_string(mut output, value)
			}
		}
		output << u8(policy.disposition)
		output << u8(policy.source)
		environment_append_string(mut output, policy.self_origin.serialize_for_ipc())
		environment_append_string(mut output, policy.pre_parsed_policy_string)
	}
	output << u8(container.embedder_policy.value)
	output << u8(container.embedder_policy.report_only_value)
	environment_append_string(mut output, container.embedder_policy.reporting_endpoint)
	environment_append_string(mut output, container.embedder_policy.report_only_reporting_endpoint)
	output << u8(container.referrer_policy)
}

pub fn encode_serialized_window(window SerializedWindow) []u8 {
	mut output := []u8{}
	environment_append_string(mut output, window.associated_document.url.value)
	environment_append_bool(mut output,
		window.associated_document.relevant_settings_object_is_secure_context)
	return output
}

pub fn encode_serialized_worker_global_scope(scope SerializedWorkerGlobalScope) []u8 {
	return [u8(scope.relevant_settings_object_is_secure_context)]
}

pub fn encode_serialized_environment_settings_object(object SerializedEnvironmentSettingsObject) []u8 {
	mut output := []u8{}
	environment_append_string(mut output, object.id)
	environment_append_string(mut output, object.creation_url.value)
	environment_append_optional_url(mut output, object.top_level_creation_url)
	environment_append_optional_origin(mut output, object.top_level_origin)
	environment_append_string(mut output, object.api_base_url.value)
	environment_append_string(mut output, object.origin.serialize_for_ipc())
	environment_append_bool(mut output, object.has_cross_site_ancestor)
	environment_append_policy_container(mut output, object.policy_container)
	output << u8(object.cross_origin_isolated_capability)
	environment_append_u64(mut output, math.f64_bits(object.time_origin))
	match object.global {
		SerializedWindow {
			output << u8(0)
			output << encode_serialized_window(object.global)
		}
		SerializedWorkerGlobalScope {
			output << u8(1)
			output << encode_serialized_worker_global_scope(object.global)
		}
	}
	return output
}

struct EnvironmentSettingsDecoder {
	data []u8
mut:
	offset int
}

fn (mut decoder EnvironmentSettingsDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.data.len {
		return error('truncated environment settings IPC data')
	}
	value := decoder.data[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder EnvironmentSettingsDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len {
		return error('truncated environment settings IPC data')
	}
	mut value := u32(0)
	for shift in 0 .. 4 {
		value |= u32(decoder.data[decoder.offset + shift]) << (shift * 8)
	}
	decoder.offset += 4
	return value
}

fn (mut decoder EnvironmentSettingsDecoder) read_u64() !u64 {
	if decoder.offset + 8 > decoder.data.len {
		return error('truncated environment settings IPC data')
	}
	mut value := u64(0)
	for shift in 0 .. 8 {
		value |= u64(decoder.data[decoder.offset + shift]) << (shift * 8)
	}
	decoder.offset += 8
	return value
}

fn (mut decoder EnvironmentSettingsDecoder) read_bool() !bool {
	value := decoder.read_u8()!
	if value > 1 {
		return error('invalid environment settings IPC boolean')
	}
	return value == 1
}

fn (mut decoder EnvironmentSettingsDecoder) read_string() !string {
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset + length > decoder.data.len {
		return error('truncated environment settings IPC string')
	}
	value := decoder.data[decoder.offset..decoder.offset + length].bytestr()
	decoder.offset += length
	return value
}

fn environment_csp_disposition(value u8) !CSPPolicyDisposition {
	return match value {
		0 { CSPPolicyDisposition.enforce }
		1 { CSPPolicyDisposition.report }
		else { error('invalid CSP policy disposition') }
	}
}

fn environment_csp_source(value u8) !CSPPolicySource {
	return match value {
		0 { CSPPolicySource.header }
		1 { CSPPolicySource.meta }
		else { error('invalid CSP policy source') }
	}
}

fn environment_embedder_policy_value(value u8) !EmbedderPolicyValue {
	return match value {
		0 { EmbedderPolicyValue.unsafe_none }
		1 { EmbedderPolicyValue.require_corp }
		2 { EmbedderPolicyValue.credentialless }
		else { error('invalid embedder policy value') }
	}
}

fn environment_referrer_policy(value u8) !ReferrerPolicy {
	return match value {
		0 { ReferrerPolicy.empty_string }
		1 { ReferrerPolicy.no_referrer }
		2 { ReferrerPolicy.no_referrer_when_downgrade }
		3 { ReferrerPolicy.same_origin }
		4 { ReferrerPolicy.origin }
		5 { ReferrerPolicy.strict_origin }
		6 { ReferrerPolicy.origin_when_cross_origin }
		7 { ReferrerPolicy.strict_origin_when_cross_origin }
		8 { ReferrerPolicy.unsafe_url }
		else { error('invalid referrer policy') }
	}
}

fn (mut decoder EnvironmentSettingsDecoder) read_policy_container() !SerializedPolicyContainer {
	policy_count := int(decoder.read_u32()!)
	mut csp_list := []dom.SerializedCSPPolicy{cap: policy_count}
	for _ in 0 .. policy_count {
		directive_count := int(decoder.read_u32()!)
		mut directives := []dom.SerializedCSPDirective{cap: directive_count}
		for _ in 0 .. directive_count {
			name := decoder.read_string()!
			value_count := int(decoder.read_u32()!)
			mut values := []string{cap: value_count}
			for _ in 0 .. value_count {
				values << decoder.read_string()!
			}
			directives << dom.SerializedCSPDirective{
				name:  name
				value: values
			}
		}
		csp_list << dom.SerializedCSPPolicy{
			directives:               directives
			disposition:              environment_csp_disposition(decoder.read_u8()!)!
			source:                   environment_csp_source(decoder.read_u8()!)!
			self_origin:              dom.origin_from_ipc(decoder.read_string()!)
			pre_parsed_policy_string: decoder.read_string()!
		}
	}
	embedder_policy := dom.EmbedderPolicy{
		value:                          environment_embedder_policy_value(decoder.read_u8()!)!
		report_only_value:              environment_embedder_policy_value(decoder.read_u8()!)!
		reporting_endpoint:             decoder.read_string()!
		report_only_reporting_endpoint: decoder.read_string()!
	}
	return dom.SerializedPolicyContainer{
		csp_list:        csp_list
		embedder_policy: embedder_policy
		referrer_policy: environment_referrer_policy(decoder.read_u8()!)!
	}
}

fn (mut decoder EnvironmentSettingsDecoder) read_serialized_window() !SerializedWindow {
	return SerializedWindow{
		associated_document: SerializedDocument{
			url:                                        dom.URL{
				value: decoder.read_string()!
			}
			relevant_settings_object_is_secure_context: decoder.read_bool()!
		}
	}
}

fn (mut decoder EnvironmentSettingsDecoder) read_serialized_worker_global_scope() !SerializedWorkerGlobalScope {
	return SerializedWorkerGlobalScope{
		relevant_settings_object_is_secure_context: decoder.read_bool()!
	}
}

pub fn decode_serialized_window(data []u8) !SerializedWindow {
	mut decoder := EnvironmentSettingsDecoder{
		data: data
	}
	window := decoder.read_serialized_window()!
	if decoder.offset != data.len {
		return error('trailing serialized window IPC data')
	}
	return window
}

pub fn decode_serialized_worker_global_scope(data []u8) !SerializedWorkerGlobalScope {
	mut decoder := EnvironmentSettingsDecoder{
		data: data
	}
	scope := decoder.read_serialized_worker_global_scope()!
	if decoder.offset != data.len {
		return error('trailing serialized worker global scope IPC data')
	}
	return scope
}

pub fn decode_serialized_environment_settings_object(data []u8) !SerializedEnvironmentSettingsObject {
	mut decoder := EnvironmentSettingsDecoder{
		data: data
	}
	id := decoder.read_string()!
	creation_url := dom.URL{
		value: decoder.read_string()!
	}
	top_level_creation_url := if decoder.read_bool()! {
		?dom.URL(dom.URL{
			value: decoder.read_string()!
		})
	} else {
		?dom.URL(none)
	}
	top_level_origin := if decoder.read_bool()! {
		?dom.Origin(dom.origin_from_ipc(decoder.read_string()!))
	} else {
		?dom.Origin(none)
	}
	api_base_url := dom.URL{
		value: decoder.read_string()!
	}
	origin := dom.origin_from_ipc(decoder.read_string()!)
	has_cross_site_ancestor := decoder.read_bool()!
	policy_container := decoder.read_policy_container()!
	capability_byte := decoder.read_u8()!
	capability := match capability_byte {
		0 { CanUseCrossOriginIsolatedAPIs.no }
		1 { CanUseCrossOriginIsolatedAPIs.yes }
		else { return error('invalid cross-origin isolated capability') }
	}
	time_origin := math.f64_from_bits(decoder.read_u64()!)
	global := match decoder.read_u8()! {
		0 { SerializedGlobal(decoder.read_serialized_window()!) }
		1 { SerializedGlobal(decoder.read_serialized_worker_global_scope()!) }
		else { return error('invalid serialized global tag') }
	}
	if decoder.offset != data.len {
		return error('trailing serialized environment settings IPC data')
	}
	return SerializedEnvironmentSettingsObject{
		id:                               id
		creation_url:                     creation_url
		top_level_creation_url:           top_level_creation_url
		top_level_origin:                 top_level_origin
		api_base_url:                     api_base_url
		origin:                           origin
		has_cross_site_ancestor:          has_cross_site_ancestor
		policy_container:                 policy_container
		cross_origin_isolated_capability: capability
		time_origin:                      time_origin
		global:                           global
	}
}
