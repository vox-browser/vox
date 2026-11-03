module adblock

fn test_private_base64_codecs_load_on_use_and_restore_with_a_fresh_engine() {
	_ = release_unused_engine()
	defer { _ = release_unused_engine() }
	for _ in 0 .. 2 {
		assert evaluate_engine('globalThis.voxAdblockBase64Loaded===true')! == 'false'
		assert evaluate_engine('btoa(String.fromCharCode(0,127,128,255))')! == 'AH+A/w=='
		assert evaluate_engine('atob(" d m9 4\\n")')! == 'vox'
		assert evaluate_engine('globalThis.voxAdblockBase64Loaded===true')! == 'true'
		assert evaluate_engine('(()=>{try{atob("!")}catch(error){return error instanceof DOMException && error.name==="InvalidCharacterError"}})()')! == 'true'
		assert evaluate_engine('(()=>{try{btoa("😀")}catch(error){return error.name==="InvalidCharacterError"}})()')! == 'true'
		assert evaluate_engine('(()=>{try{atob()}catch(error){return error.name==="TypeError"}})()')! == 'true'
		assert evaluate_engine('atob.length===1 && btoa.length===1 && Object.getOwnPropertyDescriptor(globalThis,"atob").enumerable')! == 'true'
		assert release_unused_engine()
	}
}
