module browserjs

#include "@DIR/runtime_bootstrap_windows.h"

fn C.vox_browserjs_initialize_windows_main_thread() i32

// Module initialization runs on the application thread, before worker agents.
fn init() {
	if C.vox_browserjs_initialize_windows_main_thread() == 0 {
		panic('Windows JavaScriptCore lacks WTF::initializeMainThread; check the runtime DLL')
	}
}
