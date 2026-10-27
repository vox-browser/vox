module libjs

#include <pthread.h>
#include <sys/resource.h>

// C.pthread_self comes from vlib's os module, whose declared return type
// differs across V versions and platforms; cast its result.
fn C.pthread_get_stackaddr_np(thread voidptr) voidptr
fn C.pthread_get_stacksize_np(thread voidptr) uint
fn C.pthread_main_np() int

struct C.rlimit {
	rlim_cur u64
	rlim_max u64
}

fn C.getrlimit(resource int, limit &C.rlimit) int

const default_main_thread_stack_size = uint(8 * 1024 * 1024)

// NOTE: On macOS pthread_get_stackaddr_np returns the top of the stack, and the
//       main thread's size is only reliable through getrlimit.
fn native_stack_bounds() (uint, uint) {
	top_of_stack := uint(C.pthread_get_stackaddr_np(voidptr(C.pthread_self())))
	mut size := C.pthread_get_stacksize_np(voidptr(C.pthread_self()))
	if C.pthread_main_np() == 1 {
		mut limit := C.rlimit{}
		C.getrlimit(C.RLIMIT_STACK, &limit)
		if limit.rlim_cur == u64(-1) {
			size = default_main_thread_stack_size
		} else {
			size = uint(limit.rlim_cur)
		}
	}
	return top_of_stack - size, size
}
