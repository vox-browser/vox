module buildtools

#include <CommonCrypto/CommonDigest.h>

@[typedef]
struct C.CC_SHA256_CTX {}

fn C.CC_SHA256_Init(&C.CC_SHA256_CTX) i32
fn C.CC_SHA256_Update(&C.CC_SHA256_CTX, voidptr, u32) i32
fn C.CC_SHA256_Final(&u8, &C.CC_SHA256_CTX) i32

// A checkout can contain individual files larger than CommonCrypto's
// per-update 32-bit length.
const build_digest_chunk_limit = 1 << 30

struct BuildDigest {
mut:
	context C.CC_SHA256_CTX
}

fn new_build_digest() !BuildDigest {
	mut state := BuildDigest{}
	if C.CC_SHA256_Init(&state.context) != 1 { return error('Cannot initialize build SHA-256') }
	return state
}

fn (mut digest BuildDigest) add(data string) ! {
	mut offset := 0
	for offset < data.len {
		remaining := data.len - offset
		count := if remaining > build_digest_chunk_limit { build_digest_chunk_limit } else { remaining }
		address := unsafe { data.str + offset }
		if C.CC_SHA256_Update(&digest.context, address, u32(count)) != 1 {
			return error('Cannot update build SHA-256')
		}
		offset += count
	}
}

fn (digest BuildDigest) hex() !string {
	mut context := digest.context
	mut output := [32]u8{}
	if C.CC_SHA256_Final(&output[0], &context) != 1 { return error('Cannot finalize build SHA-256') }
	return output[..].hex()
}
