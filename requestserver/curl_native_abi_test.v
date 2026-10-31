module requestserver

#include "curl_native_abi_test.h"

fn C.vox_curl_abi_socket_pair(descriptors &i32) i32
fn C.vox_curl_abi_close(descriptor i32)
fn C.vox_curl_abi_call_socket(callback voidptr, owner voidptr, descriptor i32, flags i32) i32

fn test_native_curl_callbacks_receive_native_int_socket_and_interest_arguments() {
	$if !darwin {
		return
	}
	mut descriptors := [2]i32{}
	assert C.vox_curl_abi_socket_pair(&descriptors[0]) == 0
	defer {
		C.vox_curl_abi_close(descriptors[0])
		C.vox_curl_abi_close(descriptors[1])
	}
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	callback := unsafe { voidptr(curl_socket_callback) }
	assert C.vox_curl_abi_call_socket(callback, connection, descriptors[0], i32(C.CURL_POLL_IN)) == 0
	keys := connection.sockets_.keys()
	assert C.vox_curl_abi_call_socket(callback, connection, descriptors[0], i32(C.CURL_POLL_REMOVE)) == 0
	assert keys == [int(descriptors[0])]
	assert connection.sockets_.len == 0
}
