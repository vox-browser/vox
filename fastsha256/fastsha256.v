// SPDX-License-Identifier: BSD-2-Clause
module fastsha256

import crypto.sha256
import os

// SHA-256 digests of response bodies, cache keys and image bytes. On macOS,
// CommonCrypto uses the processor's SHA-2 instructions; vlib's portable block
// function costs roughly an order of magnitude more per byte. The digests are
// identical, so on-disk cache records stay compatible.

// Same-binary control: hash with vlib's portable implementation.
const portable = os.getenv('VOX_PORTABLE_SHA256') != ''

$if macos {
	#include <CommonCrypto/CommonDigest.h>
}

@[typedef]
struct C.CC_SHA256_CTX {}

fn C.CC_SHA256_Init(ctx &C.CC_SHA256_CTX) int
fn C.CC_SHA256_Update(ctx &C.CC_SHA256_CTX, data voidptr, len u32) int
fn C.CC_SHA256_Final(md &u8, ctx &C.CC_SHA256_CTX) int

// CC_LONG is 32 bits wide; larger inputs are hashed in pieces.
const update_limit = u64(1) << 30

fn native_sum(data voidptr, len u64) []u8 {
	mut digest := []u8{len: sha256.size}
	$if macos {
		mut ctx := C.CC_SHA256_CTX{}
		C.CC_SHA256_Init(&ctx)
		mut offset := u64(0)
		for offset < len {
			piece := if len - offset > update_limit { update_limit } else { len - offset }
			C.CC_SHA256_Update(&ctx, unsafe { &u8(data) + offset }, u32(piece))
			offset += piece
		}
		C.CC_SHA256_Final(unsafe { &u8(digest.data) }, &ctx)
	}
	return digest
}

// The SHA-256 digest of `data`.
pub fn sum(data []u8) []u8 {
	$if macos {
		if !portable { return native_sum(data.data, u64(data.len)) }
	}
	return sha256.sum(data)
}

// The lowercase hexadecimal SHA-256 digest of `s`, as sha256.hexhash.
pub fn hexhash(s string) string {
	$if macos {
		if !portable { return native_sum(s.str, u64(s.len)).hex() }
	}
	return sha256.hexhash(s)
}
