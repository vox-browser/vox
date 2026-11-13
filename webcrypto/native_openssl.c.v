// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

$if macos {
	// WebCrypto loads libcrypto dynamically. Only the headers are needed here.
	$if arm64 {
		#flag -I$when_first_existing('/opt/homebrew/opt/openssl@3/include','/opt/homebrew/opt/openssl/include','/usr/local/opt/openssl@3/include','/usr/local/opt/openssl/include')
	} $else {
		#flag -I$when_first_existing('/usr/local/opt/openssl@3/include','/usr/local/opt/openssl/include','/opt/homebrew/opt/openssl@3/include','/opt/homebrew/opt/openssl/include')
	}
} $else {
	#pkgconfig openssl
}
