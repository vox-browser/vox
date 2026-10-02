// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_mlkem_source_format_specific_metadata_defaults_and_common_installation() {
	subtle := SubtleCrypto.create()
	seed := []u8{len: 64, init: u8(index)}
	for name in ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024'] {
		params := AlgorithmParams{ name: name }
		source := MLKEM.create()
		class_seed := source.import_key(params, .raw_seed, seed, true, [
			.decapsulate_bits,
			.decapsulate_key,
		])!
		assert class_seed.type_ == .private_key && !class_seed.extractable && class_seed.usages.len == 0
		assert (class_seed.internal_handle() as MlkemPrivateKeyHandle).seed == seed
		private_der := source.export_key(.pkcs8, class_seed)!
		class_der := source.import_key(params, .pkcs8, private_der, true, [.decapsulate_bits])!
		assert !class_der.extractable && class_der.usages.len == 0 && class_der.internal_handle() == class_seed.internal_handle()
		for format in [KeyFormat.raw_seed, .pkcs8] {
			bytes := if format == .raw_seed { seed } else { private_der }
			common := subtle.import_key(format, bytes, name, true, [.decapsulate_bits,
				.decapsulate_key, .decapsulate_bits], '')!
			assert common.extractable && common.usages == [.decapsulate_key, .decapsulate_bits,
				.decapsulate_bits]
			assert common.internal_handle() == class_seed.internal_handle()
			assert source.import_key(params, format, bytes, true, [])!.usages.len == 0
			if _ := subtle.import_key(format, bytes, name, true, [], '') {
				assert false
			} else {
				assert err.msg() == 'SyntaxError: usages must not be empty'
			}
		}
		public_bytes := (class_seed.internal_handle() as MlkemPrivateKeyHandle).public_key
		raw_public := source.import_key(params, .raw_public, public_bytes, true, [
			.encapsulate_bits,
			.encapsulate_key,
		])!
		assert !raw_public.extractable && raw_public.usages.len == 0
		public_der := source.export_key(.spki, raw_public)!
		// This source SPKI branch explicitly sets supplied metadata itself.
		spki := source.import_key(params, .spki, public_der, true, [.encapsulate_bits,
			.encapsulate_key])!
		assert spki.extractable && spki.usages == [.encapsulate_bits, .encapsulate_key]
		for format in [KeyFormat.raw_public, .spki] {
			bytes := if format == .raw_public { public_bytes } else { public_der }
			common := subtle.import_key(format, bytes, name, true, [.encapsulate_bits,
				.encapsulate_key], '')!
			assert common.extractable && common.usages == [.encapsulate_key, .encapsulate_bits]
			assert common.internal_handle() == raw_public.internal_handle()
			empty := subtle.import_key(format, bytes, name, true, [], '')!
			assert empty.extractable && empty.usages.len == 0
		}
	}
}

@[heap]
struct MlkemMetadataHost {
mut:
	work []fn ()
}

fn test_mlkem_async_seed_import_copies_input_and_installs_common_metadata() {
	mut host := &MlkemMetadataHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn (_ fn ()) {})
	seed := []u8{len: 64, init: u8(index)}
	mut material := webidl.BufferSource.array_buffer(seed)
	imported := binding.import_key(.raw_seed, webidl.buffer_source_value(material), webidl.string_value('ML-KEM-768'), true, [.decapsulate_bits])
	material.write([]u8{len: 64}, 0)!
	host.work[0]()
	assert imported.state == .fulfilled
	key := crypto_key_from_value(imported.result)!
	assert key.extractable && key.usages == [.decapsulate_bits]
	assert (key.internal_handle() as MlkemPrivateKeyHandle).seed == seed
	empty := binding.import_key(.raw_seed, webidl.buffer_source_value(webidl.BufferSource.array_buffer(seed)), webidl.string_value('ML-KEM-768'), true, [])
	host.work[1]()
	assert empty.state == .rejected && empty.result.object_value['message'].string_value == 'usages must not be empty'
}
