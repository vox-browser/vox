// Services/RequestServer/{CURL,ConnectionFromClient,Request}.cpp native ABI.
module requestserver

#flag -lcurl
#flag darwin -framework CoreFoundation
#include "curl_bridge.h"

fn C.curl_global_init(flags i64) i32
fn C.curl_multi_init() voidptr
fn C.curl_multi_cleanup(handle voidptr) i32
fn C.curl_multi_socket_action(handle voidptr, socket i32, events i32, running &i32) i32
fn C.curl_multi_add_handle(multi voidptr, easy voidptr) i32
fn C.curl_multi_remove_handle(multi voidptr, easy voidptr) i32
fn C.curl_easy_init() voidptr
fn C.curl_easy_cleanup(handle voidptr)
fn C.curl_easy_pause(handle voidptr, flags i32) i32
fn C.curl_slist_append(list voidptr, value &char) voidptr
fn C.curl_slist_free_all(list voidptr)
fn C.vox_curl_setopt_long(handle voidptr, option i32, value i64) i32
fn C.vox_curl_setopt_pointer(handle voidptr, option i32, value voidptr) i32
fn C.vox_curl_setopt_write(handle voidptr, option i32, callback fn (voidptr, uint, uint, voidptr) uint) i32
fn C.vox_curl_multi_setopt_pointer(handle voidptr, option i32, value voidptr) i32
fn C.vox_curl_multi_setopt_socket(handle voidptr, callback fn (voidptr, i32, i32, voidptr, voidptr) i32) i32
fn C.vox_curl_multi_setopt_timer(handle voidptr, callback fn (voidptr, i64, voidptr) i32) i32
fn C.vox_curl_next_completion(handle voidptr, result &i32) voidptr
fn C.vox_curl_status(handle voidptr) i64
fn C.vox_curl_version(handle voidptr) i64
fn C.vox_curl_time(handle voidptr, option i32) i64
fn C.vox_curl_queue_time(handle voidptr) i64
fn C.vox_curl_socket_create(owner voidptr, socket i32, callback fn (voidptr, i32, i32)) voidptr
fn C.vox_curl_socket_set_enabled(descriptor voidptr, flags i32)
fn C.vox_curl_socket_destroy(descriptor voidptr)

// C++ VERIFY checks follow the native call. V removes assert expressions in
// production, so native mutations must execute before this ordinary check.
fn check_curl_result(result int, expected int) {
	if result != expected { panic('Native curl call failed (${result}, expected ${expected})') }
}
