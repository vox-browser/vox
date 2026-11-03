module html

import dom
import encoding.base64

fn test_atob_preserves_padded_unpadded_and_binary_data() {
	scope := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, &ScriptingRealm{})
	for encoded in ['aGVsbG8=', 'aGVsbG8', ' aGVs\nbG8=\t'] {
		assert scope.atob(encoded)! == 'hello'
	}
	assert scope.atob('Zg==')! == 'f'
	assert scope.atob('Zg')! == 'f'
	assert scope.atob('Zh')! == 'f' // Unused padding bits are ignored.
	assert scope.atob('Zm8=')! == 'fo'
	assert scope.atob('Zm8')! == 'fo'
	assert scope.atob('')! == ''
	mut bytes := []u8{len: 256, init: u8(index)}
	encoded := base64.encode(bytes)
	decoded := scope.atob(encoded)!
	assert decoded.runes() == bytes.map(rune(it))
	assert scope.btoa(decoded)! == encoded
}

fn test_atob_keeps_forgiving_validation_before_decoder_padding() {
	scope := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, &ScriptingRealm{})
	for invalid in ['Z', 'Zg=', 'Zg===', '=Zg=', 'Z=g=', '====', 'Zg==x', 'Zg==\u00a0', '-w==', '_w=='] {
		if _ := scope.atob(invalid) {
			assert false, 'Accepted invalid base64 ${invalid}'
		} else {
			assert err.msg().starts_with('InvalidCharacterError:')
		}
	}
}
