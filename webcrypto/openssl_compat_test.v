module webcrypto

fn test_system_openssl_keeps_ed25519_and_kdf_available() {
	private_bytes := native_edwards_private('Ed25519')!
	public_bytes := native_edwards_public('Ed25519', private_bytes)!
	message := 'Linux OpenSSL compatibility'.bytes()
	signature := native_ed25519_sign(private_bytes, message)!
	assert native_ed25519_verify(public_bytes, signature, message)!
	assert !native_ed25519_verify(public_bytes, signature, 'different'.bytes())!
	derived := native_kdf_derive(true, 'SHA256', 'password'.bytes(), 'salt'.bytes(), [], 1, 32)!
	assert derived.hex() == '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'
}

fn test_older_openssl_reports_unavailable_algorithms_and_rejects_signature_context() {
	if C.OPENSSL_VERSION_MAJOR != 3 { return }
	if C.OPENSSL_VERSION_MINOR < 2 {
		if _ := native_argon2(Argon2Params{name: 'Argon2id', nonce: 'salt1234'.bytes(), parallelism: 1, memory: 8, passes: 1}, 'password'.bytes(), 32) {
			assert false
		} else { assert err.msg().contains('requires OpenSSL 3.2') }
	}
	if C.OPENSSL_VERSION_MINOR < 5 {
		if _ := native_mlkem_generate('ML-KEM-768', []) {
			assert false
		} else { assert err.msg().contains('requires OpenSSL 3.5') || err.msg().contains('require OpenSSL 3.5') }
	}
	// An unavailable context parameter must never be silently ignored.
	if C.OPENSSL_VERSION_MINOR < 2 {
		key := native_edwards_private('Ed448')!
		if _ := native_ed448_sign(key, 'message'.bytes(), 'context'.bytes()) {
			assert false
		}
	}
}
