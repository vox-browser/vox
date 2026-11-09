

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
