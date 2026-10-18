module http

import time

fn vox_waiting_writer(mut transport H2PooledTransport, started chan bool, order chan string) {
    started <- true
    transport.vox_lock_io()
    order <- 'writer'
    transport.io_mu.unlock()
}

fn test_idle_reader_cannot_reenter_tls_ahead_of_an_admitted_writer() {
    mut transport := &H2PooledTransport{}
    transport.vox_lock_io()
    started := chan bool{cap: 1}
    order := chan string{cap: 2}
    writer := spawn vox_waiting_writer(mut transport, started, order)
    assert <-started
    deadline := time.sys_mono_now() + time.second
    for {
        if !transport.vox_admission_mu.try_lock() { break }
        transport.vox_admission_mu.unlock()
        assert time.sys_mono_now() < deadline, 'Writer never reached the admission gate'
        time.sleep(time.millisecond)
    }
    // Simulate the idle reader immediately requesting another TLS read.
    transport.io_mu.unlock()
    transport.vox_lock_io()
    order <- 'reader'
    transport.io_mu.unlock()
    assert <-order == 'writer'
    assert <-order == 'reader'
    writer.wait()
}
