module libjs

#include <pthread.h>
#include <alloca.h>
#include <sys/resource.h>

fn C.pthread_self() voidptr
fn C.pthread_get_stackaddr_np(thread voidptr) voidptr
fn C.pthread_get_stacksize_np(thread voidptr) usize
fn C.pthread_main_np() int
fn C.alloca(size usize) voidptr

struct C.rlimit {
	rlim_cur u64
	rlim_max u64
}

fn C.getrlimit(resource int, limit &C.rlimit) int

const default_main_thread_stack_size = usize(8 * 1024 * 1024)

// NOTE: On macOS pthread_get_stackaddr_np returns the top of the stack, and the
//       main thread's size is only reliable through getrlimit.
fn native_stack_bounds() (usize, usize) {
	top_of_stack := usize(C.pthread_get_stackaddr_np(C.pthread_self()))
	mut size := C.pthread_get_stacksize_np(C.pthread_self())
	if C.pthread_main_np() == 1 {
		mut limit := C.rlimit{}
		C.getrlimit(C.RLIMIT_STACK, &limit)
		if limit.rlim_cur == u64(-1) {
			size = default_main_thread_stack_size
		} else {
			size = usize(limit.rlim_cur)
		}
	}
	return top_of_stack - size, size
}

// A fresh alloca block lives in the caller's frame, which keeps V from moving
// the marker to the heap.
@[noinline]
fn current_stack_pointer() usize {
	return usize(C.alloca(1))
}
