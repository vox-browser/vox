module libjs

#include <windows.h>

fn C.GetCurrentThreadStackLimits(low &uint, high &uint)

fn native_stack_bounds() (uint, uint) {
	mut low := uint(0)
	mut high := uint(0)
	C.GetCurrentThreadStackLimits(&low, &high)
	return low, high - low
}
