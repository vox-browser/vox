module adblock

#flag @DIR/worker_transport_native.o
#include "@DIR/worker_transport_api.h"

fn C.vox_adblock_self_executable_path(&&u8, &usize) int
fn C.vox_adblock_worker_configure(&u8, usize, int) int
fn C.vox_adblock_worker_is_configured() int
fn C.vox_adblock_worker_get_pid() int
fn C.vox_adblock_worker_memory_bytes(&u64) int
fn C.vox_adblock_worker_evaluate(&u8, usize, &&u8, &usize) int
fn C.vox_adblock_worker_release() int
fn C.vox_adblock_worker_begin_lifetime_watch() int
fn C.vox_adblock_worker_send_frame(int, int, u64, &u8, usize, int) int
fn C.vox_adblock_worker_read_frame(int, &int, &u64, &&u8, &usize, int) int

// Experimental explicit opt-in. Ordinary module users and custom Engines stay
// in process. The helper must implement the private worker role before any GUI
// or application initialization; passing a generic V test executable is invalid.
pub fn configure_default_worker(helper string) ! {
	configure_default_worker_with_deadline(helper, 0)!
}

// A nonzero deadline is useful for fault containment tests. Zero preserves the
// direct backend's unbounded evaluation semantics. Shutdown is always bounded.
pub fn configure_default_worker_with_deadline(helper string, timeout_ms int) ! {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	if C.vox_adblock_get_context() != unsafe { nil } || C.vox_adblock_worker_get_pid() != 0 {
		return error('Release the default adblock engine before changing its backend')
	}
	code := C.vox_adblock_worker_configure(helper.str, usize(helper.len), timeout_ms)
	if code != 0 { return error('Cannot configure adblock worker (${code})') }
}

pub fn default_worker_pid() int {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	return C.vox_adblock_worker_get_pid()
}

fn owned_worker_payload(bytes &u8, size usize) string {
	if bytes == unsafe { nil } { return '' }
	defer { unsafe { C.free(bytes) } }
	return unsafe { bytes.vstring_with_len(int(size)).clone() }
}

// Called only with the existing adblock lock held. Failed requests are never
// replayed. A later independent request may start a fresh helper after an I/O
// failure; initialization errors retain the direct backend's sticky state.
fn evaluate_default_worker(source string) !string {
	mut bytes := unsafe { &u8(nil) }
	mut size := usize(0)
	kind := C.vox_adblock_worker_evaluate(source.str, usize(source.len), &bytes, &size)
	message := owned_worker_payload(bytes, size)
	if kind == 4 { return message }
	if kind == 6 { C.vox_adblock_set_error(message.str) }
	return error(if message.len > 0 { message } else { 'Adblock worker transport failed' })
}

// Call at the very start of an explicitly worker-capable executable. An ordinary
// invocation returns none. No module initializer opts into subprocess behavior.
pub fn run_default_worker_role(arguments []string) ?int {
	if arguments.len < 2 || arguments[1] != '--vox-adblock-worker-v1' { return none }
	if arguments.len != 2 || C.vox_adblock_worker_begin_lifetime_watch() != 0 { return 64 }
	mut context := create_context(none) or {
		message := err.msg()
		_ = C.vox_adblock_worker_send_frame(4, 6, 0, message.str, usize(message.len), 0)
		return 70
	}
	defer { if context != unsafe { nil } { C.JSGlobalContextRelease(context) } }
	if C.vox_adblock_worker_send_frame(4, 3, 0, unsafe { nil }, 0, 0) != 0 { return 74 }
	mut previous := u64(0)
	for {
		mut kind := 0
		mut id := u64(0)
		mut bytes := unsafe { &u8(nil) }
		mut size := usize(0)
		status := C.vox_adblock_worker_read_frame(3, &kind, &id, &bytes, &size, 0)
		if status == 0 { return 0 }
		if status != 1 { return 65 }
		source := owned_worker_payload(bytes, size)
		if id == 0 || id <= previous { return 65 }
		previous = id
		if kind == 2 {
			if source.len != 0 { return 65 }
			C.JSGlobalContextRelease(context)
			context = unsafe { nil }
			if C.vox_adblock_worker_send_frame(4, 7, id, unsafe { nil }, 0, 0) != 0 { return 74 }
			return 0
		}
		if kind != 1 { return 65 }
		mut response_kind := 4
		message := evaluate_context(context, source) or {
			response_kind = 5
			err.msg()
		}
		if C.vox_adblock_worker_send_frame(4, response_kind, id, message.str, usize(message.len), 0) != 0 { return 74 }
	}
	return 0
}

// The native footer uses the same lifecycle-protected physical-footprint query.
// The helper remains a direct owned child until normal release/reap completes.
pub fn default_worker_memory_bytes() !u64 {
	mut bytes := u64(0)
	if C.vox_adblock_worker_memory_bytes(&bytes) != 0 {
		return error('Adblock worker physical footprint unavailable')
	}
	return bytes
}

// An explicitly worker-capable executable opts into using its own signed image.
// This avoids os.executable()'s dyld-image-order assumption under injection.
pub fn current_executable_path() !string {
	mut bytes := unsafe { &u8(nil) }
	mut size := usize(0)
	status := C.vox_adblock_self_executable_path(&bytes, &size)
	if status != 0 { return error('Cannot determine the adblock helper executable (${status})') }
	return owned_worker_payload(bytes, size)
}

pub fn configure_default_self_worker() ! {
	configure_default_worker(current_executable_path()!)!
}
