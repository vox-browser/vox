module browserjs

#include "@DIR/native_word_view.h"

fn C.vox_jsc_install_native_word_view(context voidptr, name &char, words voidptr, count uint) bool

// Publish `count` native 32-bit words, such as a counter the native side
// updates, as the global Uint32Array `name`: scripts poll it without a host
// call. The words must outlive the context.
pub fn (mut runtime Runtime) install_native_word_view(name string, words voidptr, count int) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		if !C.vox_jsc_install_native_word_view(runtime.context, &char(name.str), words, uint(count)) {
			return error('JavaScriptCore native word view installation failed')
		}
	}
}
