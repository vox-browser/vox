module webcrypto

import webidl

fn test_usage_normalization_is_a_sorted_intersection_without_duplicates() {
	input := [KeyUsage.verify, .sign, .verify, .encrypt, .sign, .decrypt, .encrypt]
	assert normalize_key_usages(input) == [.encrypt, .decrypt, .sign, .verify]
	assert usage_intersection(input, [.verify, .sign, .sign]) == [.sign, .verify]
	assert input == [.verify, .sign, .verify, .encrypt, .sign, .decrypt, .encrypt]
}

@[heap]
struct UsageNormalizationWork {
mut:
	jobs []fn ()
}

fn test_generation_and_import_bindings_publish_deduplicated_frozen_key_usages() {
	mut work := &UsageNormalizationWork{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{},
		fn [mut work] (task fn ()) { work.jobs << task },
		fn [mut work] (task fn ()) { work.jobs << task })
	algorithm := webidl.object_value({
		'name': webidl.string_value('KMAC128')
		'length': webidl.number_value(128)
	})
	generated := binding.generate_key(algorithm, true, [.verify, .sign, .sign, .verify])
	imported := binding.import_key(.raw_secret,
		webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 16})), algorithm, true,
		[.verify, .sign, .verify, .sign])
	for _ in 0 .. 20 {
		if work.jobs.len == 0 { break }
		job := work.jobs[0]
		work.jobs.delete(0)
		job()
	}
	for promise in [generated, imported] {
		assert promise.state == .fulfilled
		key := crypto_key_from_value(promise.result)!
		assert key.usages == [.sign, .verify]
		frozen := key.usages_for_realm('usage-normalization')
		assert frozen.sequence_value.len == 2
		assert frozen.sequence_value[0].string_value == 'sign'
		assert frozen.sequence_value[1].string_value == 'verify'
	}
}
