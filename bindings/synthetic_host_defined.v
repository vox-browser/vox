// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/SyntheticHostDefined.{h,cpp}.
module bindings

import html

@[heap]
pub struct SyntheticHostDefined {
	HostDefined
pub:
	synthetic_realm_settings html.SyntheticRealmSettings
}

pub fn SyntheticHostDefined.create(settings html.SyntheticRealmSettings, intrinsics &Intrinsics) &SyntheticHostDefined {
	return &SyntheticHostDefined{
		HostDefined: HostDefined{
			intrinsics: intrinsics
			wrapper_world: WrapperWorld.create(.internal)
			principal_realm: settings.principal_realm
		}
		synthetic_realm_settings: settings
	}
}

pub fn (_ &SyntheticHostDefined) is_synthetic_host_defined() bool {
	return true
}
