module libjs

import crypto.sha256

$if test {
	__global native_cache_digests_disabled bool
	pub fn set_native_cache_digests_for_testing(enabled bool) {
		native_cache_digests_disabled = !enabled
	}
}

fn use_native_cache_digests() bool {
	$if macos {
		$if test { if native_cache_digests_disabled { return false } }
		return true
	}
	return false
}

// CommonCrypto takes a 32-bit byte count. Larger inputs and other platforms
// retain the portable SHA-256 implementation. Both produce the same digest.
fn native_cache_digest_string(text string) string {
	$if macos {
		if use_native_cache_digests() && u64(text.len) <= 0xffffffff {
			mut digest := [32]u8{}
			C.CC_SHA256(text.str, u32(text.len), &digest[0])
			return digest[..].hex()
		}
	}
	return sha256.hexhash(text)
}

fn native_cache_digest_bytes(bytes []u8) string {
	$if macos {
		if use_native_cache_digests() && u64(bytes.len) <= 0xffffffff {
			mut digest := [32]u8{}
			C.CC_SHA256(bytes.data, u32(bytes.len), &digest[0])
			return digest[..].hex()
		}
	}
	return sha256.sum(bytes).hex()
}
