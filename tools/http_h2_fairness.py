"""Keep an idle HTTP/2 TLS reader from barging ahead of waiting writers."""


def patch_h2_pooled_transport(source):
    field = '\tio_mu  &sync.Mutex  = sync.new_mutex()'
    if source.count(field) != 1 or source.count('t.io_mu.lock()') != 4:
        raise RuntimeError('Unsupported V HTTP/2 pooled transport locking layout')
    source = source.replace(field, field + '\n\tvox_admission_mu &sync.Mutex = sync.new_mutex()', 1)
    source = source.replace('t.io_mu.lock()', 't.vox_lock_io()')
    return source + '''

// Admit the next I/O caller before it waits for the TLS lock. In particular,
// an idle read holds io_mu across its bounded WANT_READ poll, but leaves the
// admission gate open. A writer can then hold that gate while waiting for
// the current read, preventing the reader from repeatedly reacquiring io_mu.
// All TLS calls remain serialized; buffered TLS data, timeout propagation,
// write-stall budgets and close/error handling keep their original behavior.
fn (mut t H2PooledTransport) vox_lock_io() {
    t.vox_admission_mu.lock()
    t.io_mu.lock()
    t.vox_admission_mu.unlock()
}
'''
