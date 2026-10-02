module webcrypto

import webidl

@[heap]
struct CryptoBindingTestHost {
mut:
	deferred     []fn ()
	crypto_tasks []fn ()
	jobs         []fn ()
	seen         []string
}

fn (mut host CryptoBindingTestHost) binding() &SubtleCryptoBinding {
	return SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{
		realm_id:      91
		job_scheduler: fn [mut host] (job fn ()) { host.jobs << job }
	}, fn [mut host] (task fn ()) { host.deferred << task },
		fn [mut host] (task fn ()) { host.crypto_tasks << task })
}

fn (mut host CryptoBindingTestHost) work() {
	task := host.deferred[0]
	host.deferred.delete(0)
	task()
}

fn (mut host CryptoBindingTestHost) settle() {
	task := host.crypto_tasks[0]
	host.crypto_tasks.delete(0)
	task()
}

fn (mut host CryptoBindingTestHost) react() {
	task := host.jobs[0]
	host.jobs.delete(0)
	task()
}

fn binding_test_bytes(promise &webidl.Promise) []u8 {
	return webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('missing buffer') })
}

fn binding_test_error(promise &webidl.Promise) string {
	return promise.result.object_value['name'].string_value
}

fn test_async_digest_copies_view_and_settles_crypto_task_before_reaction_job() {
	mut host := &CryptoBindingTestHost{}
	binding := host.binding()
	mut data := webidl.BufferSource.view(.data_view, 'xabcx'.bytes(), 1, 3)!
	mut promise := binding.digest(webidl.object_value({
		'name': webidl.string_value('sHa-256')
		'iv':   webidl.string_value('ignored extra field')
	}), data)
	child := promise.upon_fulfillment(fn [mut host] (value webidl.Value) !webidl.Value {
		host.seen << 'fulfilled'
		return value
	})
	data.write('xyz'.bytes(), 0)!
	assert promise.state == .pending
	assert host.deferred.len == 1
	host.work()
	assert promise.state == .pending
	assert host.crypto_tasks.len == 1
	assert host.jobs.len == 0
	host.settle()
	assert promise.state == .fulfilled
	assert binding_test_bytes(promise).hex() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
	assert child.state == .pending
	assert webidl.promise_realm(child) == 91
	host.react()
	assert child.state == .fulfilled
	assert host.seen == ['fulfilled']
}

fn test_async_normalization_errors_are_immediate_and_key_errors_are_crypto_tasks() {
	mut host := &CryptoBindingTestHost{}
	binding := host.binding()
	data := webidl.BufferSource.array_buffer([]u8{})
	unknown := binding.digest(webidl.string_value('missing'), data)
	assert unknown.state == .rejected
	assert binding_test_error(unknown) == 'NotSupportedError'
	missing_params := binding.digest(webidl.string_value('cSHAKE128'), data)
	assert missing_params.state == .rejected
	assert binding_test_error(missing_params) == 'TypeError'
	key := CryptoKey.create(.secret, false, KeyAlgorithm{ name: 'AES-CBC' }, [.encrypt], []u8{len: 16})
	bad_params := binding.encrypt(webidl.object_value({
		'name': webidl.string_value('AES-CBC')
		'iv':   webidl.string_value('must be buffer')
	}), key, data)
	assert bad_params.state == .rejected
	assert host.deferred.len == 0
	key_error := binding.sign(webidl.string_value('HMAC'), key, data)
	assert key_error.state == .pending
	host.work()
	assert key_error.state == .pending
	host.settle()
	assert key_error.state == .rejected
	assert binding_test_error(key_error) == 'InvalidAccessError'
	assert key_error.result.object_value['message'].string_value == 'Algorithm mismatch'
}

fn test_async_aes_copies_normalized_iv_and_data_before_deferral() {
	mut host := &CryptoBindingTestHost{}
	binding := host.binding()
	key := import_secret_key('AES-CBC', []u8{len: 16}, true, [.encrypt, .decrypt], '')!
	mut iv := webidl.BufferSource.array_buffer([]u8{len: 16})
	mut data := webidl.BufferSource.array_buffer('copied before deferral'.bytes())
	algorithm := webidl.object_value({
		'name': webidl.string_value('AES-CBC')
		'iv':   webidl.buffer_source_value(iv)
	})
	promise := binding.encrypt(algorithm, key, data)
	iv.write([]u8{len: 16, init: 255}, 0)!
	data.write([]u8{len: 22, init: 255}, 0)!
	host.work()
	host.settle()
	ciphertext := binding_test_bytes(promise)
	assert aes_cbc_decrypt(AesCbcParams{ iv: []u8{len: 16} }, key, ciphertext)!.bytestr() == 'copied before deferral'
}

fn test_async_generation_import_export_use_direct_deferred_settlement_and_key_identity() {
	mut host := &CryptoBindingTestHost{}
	binding := host.binding()
	mut usages := [KeyUsage.encrypt]
	generated := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.number_value(128)
	}), true, usages)
	usages[0] = .sign
	assert generated.state == .pending
	host.work()
	assert generated.state == .fulfilled
	assert host.crypto_tasks.len == 0
	key := crypto_key_from_value(generated.result)!
	assert key.usages == [.encrypt]
	assert key.handle_.len == 16
	exported := binding.export_key(.jwk, key)
	assert exported.state == .pending
	host.work()
	assert exported.state == .fulfilled
	assert exported.result.object_value['alg'].string_value == 'A128GCM'
	imported := binding.import_key(.jwk, exported.result, webidl.string_value('AES-GCM'), true, [.encrypt])
	host.work()
	assert imported.state == .fulfilled
	other := crypto_key_from_value(imported.result)!
	assert other.handle_ == key.handle_
	assert crypto_key('91', other) == imported.result
	invalid := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.number_value(129)
	}), true, [.encrypt])
	assert invalid.state == .pending
	host.work()
	assert invalid.state == .rejected
	assert binding_test_error(invalid) == 'OperationError'
	invalid_empty := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.number_value(129)
	}), true, []KeyUsage{})
	host.work()
	assert binding_test_error(invalid_empty) == 'OperationError'
	invalid_usage := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.number_value(129)
	}), true, [.sign])
	host.work()
	assert binding_test_error(invalid_usage) == 'SyntaxError'
	invalid_jwk := binding.import_key(.jwk, webidl.object_value({}), webidl.string_value('AES-GCM'), true, [.encrypt])
	assert invalid_jwk.state == .pending
	host.work()
	assert invalid_jwk.state == .rejected
}

fn test_async_hmac_sign_verify_derive_key_and_wrap_fallback() {
	mut host := &CryptoBindingTestHost{}
	binding := host.binding()
	hmac_key := import_secret_key('HMAC', 'secret'.bytes(), true, [.sign, .verify], 'SHA-256')!
	data := webidl.BufferSource.array_buffer('message'.bytes())
	signature := binding.sign(webidl.string_value('HMAC'), hmac_key, data)
	host.work()
	host.settle()
	verified := binding.verify(webidl.string_value('HMAC'), hmac_key, signature.result.buffer_value or { panic('signature') }, data)
	host.work()
	host.settle()
	assert verified.result.boolean_value
	base_key := import_secret_key('HKDF', 'secret'.bytes(), false, [.derive_key, .derive_bits], '')!
	hkdf := webidl.object_value({
		'name': webidl.string_value('HKDF')
		'hash': webidl.string_value('SHA-256')
		'salt': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{}))
		'info': webidl.buffer_source_value(webidl.BufferSource.array_buffer('context'.bytes()))
	})
	derived := binding.derive_key(hkdf, base_key, webidl.object_value({
		'name':   webidl.string_value('AES-CBC')
		'length': webidl.number_value(128)
	}), true, [.encrypt])
	host.work()
	assert derived.state == .fulfilled
	key := crypto_key_from_value(derived.result)!
	bits := binding.derive_bits(hkdf, base_key, u32(128))
	host.work()
	assert binding_test_bytes(bits) == key.handle_
	wrapping := import_secret_key('AES-CBC', []u8{len: 16}, true, [.wrap_key, .unwrap_key], '')!
	cbc := webidl.object_value({
		'name': webidl.string_value('AES-CBC')
		'iv':   webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 16}))
	})
	wrapped := binding.wrap_key(.raw, key, wrapping, cbc)
	host.work()
	assert wrapped.state == .fulfilled
	unwrapped := binding.unwrap_key(.raw, wrapped.result.buffer_value or { panic('wrapped') }, wrapping, cbc, webidl.string_value('AES-CBC'), true, [.encrypt])
	host.work()
	assert unwrapped.state == .fulfilled
	assert crypto_key_from_value(unwrapped.result)!.handle_ == key.handle_
	assert host.crypto_tasks.len == 0
}
