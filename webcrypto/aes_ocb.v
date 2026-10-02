// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// CryptoAlgorithms.cpp AesOcb operations, using upstream's EVP AES-OCB backend.
module webcrypto

fn aes_ocb_crypt(params AeadParams, key &CryptoKey, data []u8, decrypt bool) ![]u8 {
	if params.iv.len > 15 { return error('OperationError: IV must have a length of 15 bytes') }
	tag_length := params.tag_length or { u8(128) }
	if tag_length !in [u8(64), 96, 128] { return error('OperationError: Invalid tag length') }
	if decrypt && data.len < int(tag_length / 8) {
		return error('OperationError: Ciphertext is less than tagLength bits')
	}
	return native_aes_ocb(decrypt, key.handle_, data, params.iv, params.additional_data or { []u8{} }, int(tag_length / 8))
}

fn import_aes_ocb_key(format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
    return import_aes_key('AES-OCB', format, material, extractable, usages)
}

fn export_aes_ocb_key(format KeyFormat, key &CryptoKey) ![]u8 {
    return export_aes_key(format, key)
}

fn aes_ocb_key_length(params AesKeyGenParams) !u32 {
    if params.length !in [u16(128), 192, 256] { return error('OperationError: Invalid key length: ${params.length}') }
    return u32(params.length)
}
