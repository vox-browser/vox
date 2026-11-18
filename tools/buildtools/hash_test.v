module buildtools

import crypto.sha256

fn test_build_digest_preserves_binary_segments_and_observation() ! {
	mut state := new_build_digest()!
	assert state.hex()! == sha256.hexhash('')
	state.add('regular-file\x00')!
	payload := 'bytes\x00between separators\xff'.repeat(8192)
	state.add(payload)!
	expected := sha256.hexhash('regular-file\x00' + payload)
	assert state.hex()! == expected
	assert state.hex()! == expected
	state.add('link\x00target')!
	assert state.hex()! == sha256.hexhash('regular-file\x00' + payload + 'link\x00target')
	assert hash(payload) == sha256.hexhash(payload)
}
