// Services/RequestServer/{CURL,ConnectionFromClient,Request}.cpp native ABI.
module requestserver

#flag -lcurl
#flag darwin -framework CoreFoundation
#include "curl_bridge.h"

fn C.curl_global_init(flags i64) int
fn C.curl_multi_init() voidptr
fn C.curl_multi_cleanup(handle voidptr) int
fn C.curl_multi_socket_action(handle voidptr, socket int, events int, running &int) int
fn C.curl_multi_add_handle(multi voidptr, easy voidptr) int
fn C.curl_multi_remove_handle(multi voidptr, easy voidptr) int
fn C.curl_easy_init() voidptr
fn C.curl_easy_cleanup(handle voidptr)
fn C.curl_easy_pause(handle voidptr, flags int) int
fn C.curl_slist_append(list voidptr, value &char) voidptr
fn C.curl_slist_free_all(list voidptr)
fn C.vox_curl_setopt_long(handle voidptr, option int, value i64) int
fn C.vox_curl_setopt_pointer(handle voidptr, option int, value voidptr) int
fn C.vox_curl_setopt_write(handle voidptr, option int, callback fn (voidptr, uint, uint, voidptr) uint) int
fn C.vox_curl_multi_setopt_pointer(handle voidptr, option int, value voidptr) int
fn C.vox_curl_multi_setopt_socket(handle voidptr, callback fn (voidptr, int, int, voidptr, voidptr) int) int
fn C.vox_curl_multi_setopt_timer(handle voidptr, callback fn (voidptr, i64, voidptr) int) int
fn C.vox_curl_next_completion(handle voidptr, result &int) voidptr
fn C.vox_curl_status(handle voidptr) i64
fn C.vox_curl_version(handle voidptr) i64
fn C.vox_curl_time(handle voidptr, option int) i64
fn C.vox_curl_queue_time(handle voidptr) i64
fn C.vox_curl_socket_create(owner voidptr, socket int, callback fn (voidptr, int, int)) voidptr
fn C.vox_curl_socket_set_enabled(descriptor voidptr, flags int)
fn C.vox_curl_socket_destroy(descriptor voidptr)

// C++ VERIFY checks follow the native call. V removes assert expressions in
// production, so native mutations must execute before this ordinary check.
fn check_curl_result(result int, expected int) {
	if result != expected { panic('Native curl call failed (${result}, expected ${expected})') }
}
