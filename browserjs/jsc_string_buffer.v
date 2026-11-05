module browserjs

import os
import sync.stdatomic

const retain_heap_jsc_string_buffer = os.getenv('VOX_RETAIN_HEAP_JSC_STRING_BUFFER') != ''
const inline_jsc_string_buffer_diagnostics = os.getenv('VOX_INLINE_JSC_STRING_BUFFER_DIAGNOSTICS') != ''
__global inline_jsc_string_buffer_reported stdatomic.AtomicVal[bool]

fn note_inline_jsc_string_buffer() {
	if inline_jsc_string_buffer_diagnostics && inline_jsc_string_buffer_reported.compare_and_swap(false, true) {
		eprintln('Vox JSC string conversion: bounded stack buffer copied into caller storage')
	}
}
