// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/HostDefined.{h,cpp}.
module bindings

import html

pub enum PrincipalRealmUnderConstruction {
	no
	yes
}

@[heap]
pub struct HostDefined {
pub:
	intrinsics      &Intrinsics
	wrapper_world   &WrapperWorld
	principal_realm &html.ScriptingRealm
pub mut:
	// WebAssembly owns the typed cache in its module. This opaque edge mirrors
	// the realm-owned cache slot without introducing a V import cycle.
	wasm_cache_handle ?voidptr
mut:
	principal_ bool
}

pub fn HostDefined.create(intrinsics &Intrinsics, wrapper_world &WrapperWorld, principal_realm &html.ScriptingRealm, principal_realm_under_construction PrincipalRealmUnderConstruction) &HostDefined {
	if principal_realm_under_construction == .no {
		principal_host := host_defined_for_realm(principal_realm) or {
			panic('non-principal realm requires an initialized principal realm')
		}
		assert principal_host.is_principal_host_defined()
	}
	return &HostDefined{
		intrinsics: intrinsics
		wrapper_world: wrapper_world
		principal_realm: principal_realm
		principal_: principal_realm_under_construction == .yes
	}
}

pub fn (host_defined &HostDefined) is_principal_host_defined() bool {
	return host_defined.principal_
}

pub fn install_host_defined(mut realm html.ScriptingRealm, host_defined &HostDefined) {
	if realm.host_defined_handle != unsafe { nil } {
		assert realm.host_defined_handle == voidptr(host_defined)
		return
	}
	realm.host_defined_handle = voidptr(host_defined)
	realm.principal_realm_ = host_defined.principal_realm
	register_wrapper_world_for_realm(realm, host_defined.wrapper_world)
}

pub fn host_defined_for_realm(realm &html.ScriptingRealm) ?&HostDefined {
	if realm.host_defined_handle == unsafe { nil } {
		return none
	}
	return unsafe { &HostDefined(realm.host_defined_handle) }
}

pub fn host_defined_intrinsics(realm &html.ScriptingRealm) &Intrinsics {
	host_defined := host_defined_for_realm(realm) or { panic('realm has no HostDefined state') }
	return host_defined.intrinsics
}
