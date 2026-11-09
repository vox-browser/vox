

#include "@DIR/vox_h2_wake.h"
fn C.vox_h2_wake_create() voidptr
fn C.vox_h2_wake_retain(voidptr) voidptr
fn C.vox_h2_wake_signal(voidptr)
fn C.vox_h2_wake_close(voidptr)
fn C.vox_h2_wake_wait(voidptr, i32, i32) i32

fn (t &H2PooledTransport) vox_read_timeout() time.Duration {
    return if t.vox_wake != unsafe { nil } { 5 * time.millisecond } else { h2_pooled_io_timeout }
}
