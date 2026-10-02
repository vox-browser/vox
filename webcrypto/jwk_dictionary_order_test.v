// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import x.json2

fn test_jwk_generated_dictionary_conversion_creates_present_members_in_source_order() {
	key := JsonWebKey{
		alg:     'RS256'
		crv:     'P-256'
		d:       'd'
		dp:      'dp'
		dq:      'dq'
		e:       'e'
		ext:     false
		k:       'k'
		key_ops: ['verify', 'sign']
		kty:     'RSA'
		n:       'n'
		oth:     [RsaOtherPrimesInfo{ d: 'd2', r: 'r2', t: 't2' }]
		p:       'p'
		priv:    'priv'
		pub_:    'pub'
		q:       'q'
		qi:      'qi'
		use:     'sig'
		x:       'x'
		y:       'y'
	}
	order := ['alg', 'crv', 'd', 'dp', 'dq', 'e', 'ext', 'k', 'key_ops', 'kty', 'n', 'oth', 'p',
		'priv', 'pub', 'q', 'qi', 'use', 'x', 'y']
	assert key.to_object().keys() == order
	converted := export_key_result_to_js_value('', ExportKeyResult(key))!
	assert converted.object_value.keys() == order
	assert converted.object_value['oth'].sequence_value[0].object_value.keys() == ['d', 'r', 't']
	object := key.to_object()
	primes := object['oth']! as []json2.Any
	prime := primes[0] as map[string]json2.Any
	assert prime == {
		'd': json2.Any('d2')
		'r': json2.Any('r2')
		't': json2.Any('t2')
	}
	assert JsonWebKey{ kty: 'oct', ext: false, key_ops: []string{}, k: 'AA' }.to_object().keys() == [
		'ext',
		'k',
		'key_ops',
		'kty',
	]
	assert JsonWebKey{}.to_object().len == 0
}
