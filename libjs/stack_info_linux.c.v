module libjs

#include <pthread.h>

@[typedef]
struct C.pthread_attr_t {}

// C.pthread_self comes from vlib's os module, whose declared return type
// differs across V versions and platforms; cast its result.
fn C.pthread_getattr_np(thread voidptr, attr &C.pthread_attr_t) int
fn C.pthread_attr_getstack(attr &C.pthread_attr_t, stack_address &voidptr, stack_size &usize) int
fn C.pthread_attr_destroy(attr &C.pthread_attr_t) int

fn native_stack_bounds() (usize, usize) {
	attr := C.pthread_attr_t{}
	if C.pthread_getattr_np(voidptr(C.pthread_self()), &attr) != 0 {
		panic('pthread_getattr_np failed')
	}
	mut base := unsafe { nil }
	mut size := usize(0)
	if C.pthread_attr_getstack(&attr, &base, &size) != 0 {
		panic('pthread_attr_getstack failed')
	}
	C.pthread_attr_destroy(&attr)
	return usize(base), size
}
