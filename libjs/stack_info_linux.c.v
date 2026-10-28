module libjs

#flag linux -D_GNU_SOURCE=1
#include "@DIR/stack_info_host.h"

@[typedef]
struct C.pthread_attr_t {}

// Keep pthread_t inside C: it is an integer in glibc and a pointer in musl.
fn C.vox_ak_current_thread_attributes(attr &C.pthread_attr_t) int
fn C.pthread_attr_getstack(attr &C.pthread_attr_t, stack_address &voidptr, stack_size &uint) int
fn C.pthread_attr_destroy(attr &C.pthread_attr_t) int

fn native_stack_bounds() (uint, uint) {
	attr := C.pthread_attr_t{}
	if C.vox_ak_current_thread_attributes(&attr) != 0 {
		panic('pthread_getattr_np failed')
	}
	mut base := unsafe { nil }
	mut size := uint(0)
	if C.pthread_attr_getstack(&attr, &base, &size) != 0 {
		panic('pthread_attr_getstack failed')
	}
	C.pthread_attr_destroy(&attr)
	return uint(base), size
}
