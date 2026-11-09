// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

const codestream_signature = [u8(0xff), 0x0a]
const container_signature = [u8(0), 0, 0, 12, 0x4a, 0x58, 0x4c, 0x20, 13, 10, 0x87, 10]

pub enum SignatureStatus {
	invalid
	incomplete
	codestream
	container
}

pub struct SignatureProbe {
pub:
	status  SignatureStatus
	missing int
}

pub fn check_signature(prefix []u8) SignatureProbe {
	for index, signature in [codestream_signature, container_signature] {
		length := if prefix.len < signature.len { prefix.len } else { signature.len }
		if prefix[..length] == signature[..length] {
			if prefix.len < signature.len {
				return SignatureProbe{ status: .incomplete, missing: signature.len - prefix.len }
			}
			return SignatureProbe{ status: if index == 0 { .codestream } else { .container } }
		}
	}
	return SignatureProbe{ status: .invalid }
}
