module webcrypto

import webidl

fn support_test_algorithm(name string, fields map[string]webidl.Value) webidl.Value {
 mut values := fields.clone()
 values['name'] = webidl.string_value(name)
 return webidl.object_value(values)
}

fn test_supports_parameters_validate_without_generating_keys_or_deriving_bytes() {
 for n in [0,100,128,192,256,512] {
  alg := support_test_algorithm('AES-GCM', {'length':webidl.number_value(n)})
  assert supports_parameters('generateKey', alg, none) == (n in [128,192,256])
 }
 for size in [0,15,16,17] {
  alg := support_test_algorithm('AES-CBC', {'iv':webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len:size}))})
  assert supports_parameters('encrypt', alg, none) == (size == 16)
 }
 alg := support_test_algorithm('HKDF', {'hash':webidl.string_value('SHA-256'),'salt':webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{})),'info':webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{}))})
 assert supports_parameters('deriveBits', alg, u32(65280))
 assert !supports_parameters('deriveBits', alg, u32(65288))
 assert !supports_parameters('deriveBits', alg, none)
 assert !supports_parameters('deriveBits', alg, u32(7))
 assert supports_operation('getPublicKey') && !supports_operation('GENERATEKEY')
 assert !supports_parameters('generateKey', webidl.string_value('missing'), none)
}

fn test_supports_validates_rsa_exponents_and_shared_secret_import_lengths() {
 for exponent in [[u8(1)],[u8(2)],[u8(3)],[u8(4)],[u8(15)],[u8(17)]] {
  alg := support_test_algorithm('RSA-PSS', {'modulusLength':webidl.number_value(4),'publicExponent':webidl.buffer_source_value(webidl.BufferSource.view(.uint8_array, exponent,0,u32(exponent.len))!),'hash':webidl.string_value('SHA-256')})
  assert supports_parameters('generateKey', alg, none) == (exponent == [u8(3)])
 }
 for bits in [128,256,512] {
  alg := support_test_algorithm('HMAC', {'hash':webidl.string_value('SHA-256'),'length':webidl.number_value(bits)})
  assert supports_shared_key_import(alg,256) == (bits == 256)
 }
 assert !supports_shared_key_import(webidl.string_value('Ed25519'),256)
}
