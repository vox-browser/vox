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

pub fn PrincipalHostDefined.create(environment_settings_object &html.EnvironmentSettingsObject, intrinsics &Intrinsics, page &dom.Page) &PrincipalHostDefined {
	return &PrincipalHostDefined{
		HostDefined:                 HostDefined{
			intrinsics: intrinsics
		}
		environment_settings_object: environment_settings_object
		page:                        page
	}
}

pub fn (_ &PrincipalHostDefined) is_principal_host_defined() bool {
	return true
}

pub fn principal_host_defined_environment_settings_object(host_defined &PrincipalHostDefined) &html.EnvironmentSettingsObject {
	return host_defined.environment_settings_object
}

pub fn principal_host_defined_page(host_defined &PrincipalHostDefined) &dom.Page {
	return host_defined.page
}
