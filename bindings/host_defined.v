// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/HostDefined.{h,cpp}.
module bindings

@[heap]
pub struct HostDefined {
pub:
	intrinsics &Intrinsics
}

pub fn HostDefined.create(intrinsics &Intrinsics) &HostDefined {
	return &HostDefined{
		intrinsics: intrinsics
	}
}

pub fn host_defined_intrinsics(host_defined &HostDefined) &Intrinsics {
	return host_defined.intrinsics
}
