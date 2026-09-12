// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/PrincipalHostDefined.{h,cpp}.
module bindings

import dom
import html

@[heap]
pub struct PrincipalHostDefined {
	HostDefined
pub:
	environment_settings_object &html.EnvironmentSettingsObject
	page                        &dom.Page
}

pub fn PrincipalHostDefined.create(environment_settings_object &html.EnvironmentSettingsObject, intrinsics &Intrinsics, wrapper_world &WrapperWorld, page &dom.Page) &PrincipalHostDefined {
	base := HostDefined.create(intrinsics, wrapper_world, environment_settings_object.realm(), .yes)
	return &PrincipalHostDefined{
		HostDefined: *base
		environment_settings_object: environment_settings_object
		page: page
	}
}

pub fn (_ &PrincipalHostDefined) is_principal_host_defined() bool {
	return true
}

pub fn create_principal_host_defined(environment_settings_object &html.EnvironmentSettingsObject, intrinsics &Intrinsics, page &dom.Page) &PrincipalHostDefined {
	wrapper_world := main_wrapper_world_for_agent(html.relevant_agent())
	host_defined := PrincipalHostDefined.create(environment_settings_object, intrinsics, wrapper_world, page)
	mut realm := unsafe { &html.ScriptingRealm(environment_settings_object.realm()) }
	install_host_defined(mut realm, unsafe { &HostDefined(host_defined) })
	return host_defined
}

fn principal_host_defined_for_realm(realm &html.ScriptingRealm) &PrincipalHostDefined {
	host_defined := host_defined_for_realm(realm) or { panic('realm has no HostDefined state') }
	if host_defined.is_principal_host_defined() {
		return unsafe { &PrincipalHostDefined(host_defined) }
	}
	return principal_host_defined_for_realm(host_defined.principal_realm)
}

pub fn principal_host_defined_environment_settings_object(realm &html.ScriptingRealm) &html.EnvironmentSettingsObject {
	return principal_host_defined_for_realm(realm).environment_settings_object
}

pub fn principal_host_defined_page(realm &html.ScriptingRealm) &dom.Page {
	return principal_host_defined_for_realm(realm).page
}
