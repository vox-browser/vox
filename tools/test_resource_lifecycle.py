#!/usr/bin/env python3
"""Exercise the production resource scope and curl transport without a window.

Run with `python3 tools/test_resource_lifecycle.py`. A C compiler and libcurl
headers/library are required. All requests stay on an in-process loopback
server; the C shim includes the production headers without copying their logic.
"""

import ctypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shlex
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest


SHIM = r'''
#include <stdatomic.h>
#include "browsernet/cancellable_transport.h"

typedef struct {
    _Atomic int phase;
    _Atomic size_t body_bytes;
} ResourceProbe;
static unsigned test_peak;

void *test_scope_create(void) { return vox_resource_scope_create(); }
void test_scope_retain(void *scope) { vox_resource_scope_retain(scope); }
int test_scope_release(void *scope) { return vox_resource_scope_release(scope); }
void test_scope_cancel(void *scope) { vox_resource_scope_cancel(scope); }
int test_begin_publication(void *scope) { return vox_resource_scope_begin_publication(scope); }
void test_end_publication(void *scope) { vox_resource_scope_end_publication(scope); }

void *test_probe_create(void) { return calloc(1, sizeof(ResourceProbe)); }
void test_probe_free(void *probe) { free(probe); }
int test_probe_phase(void *probe) { return atomic_load(&((ResourceProbe *)probe)->phase); }
size_t test_probe_body_bytes(void *probe) { return atomic_load(&((ResourceProbe *)probe)->body_bytes); }
unsigned test_active_count(void) {
    pthread_mutex_lock(&vox_resource_slots_mutex);
    unsigned value = vox_resource_slots_active;
    pthread_mutex_unlock(&vox_resource_slots_mutex);
    return value;
}
unsigned test_peak_count(void) {
    pthread_mutex_lock(&vox_resource_slots_mutex);
    unsigned value = test_peak;
    pthread_mutex_unlock(&vox_resource_slots_mutex);
    return value;
}
void test_reset_peak(void) {
    pthread_mutex_lock(&vox_resource_slots_mutex);
    test_peak = 0;
    pthread_mutex_unlock(&vox_resource_slots_mutex);
}
static size_t test_header(void *data, size_t size, size_t count, void *owner) {
    (void)data; (void)owner;
    return size * count;
}
static size_t test_body(void *data, size_t size, size_t count, void *owner) {
    (void)data;
    atomic_fetch_add(&((ResourceProbe *)owner)->body_bytes, size * count);
    return size * count;
}
int test_fetch(void *scope, const char *url, void *owner) {
    ResourceProbe *probe = owner;
    atomic_store(&probe->phase, 1);
    if (!vox_resource_scope_acquire_slot(scope, 16)) {
        atomic_store(&probe->phase, 3);
        return CURLE_ABORTED_BY_CALLBACK;
    }
    pthread_mutex_lock(&vox_resource_slots_mutex);
    if (vox_resource_slots_active > test_peak) test_peak = vox_resource_slots_active;
    pthread_mutex_unlock(&vox_resource_slots_mutex);
    atomic_store(&probe->phase, 2);
    char error_buffer[CURL_ERROR_SIZE] = {0};
    int protocol = 0;
    int result = vox_resource_curl_fetch(url, "", "", "Vox lifecycle test", NULL,
        owner, scope, test_header, test_body, error_buffer, true, &protocol);
    vox_resource_release_slot();
    atomic_store(&probe->phase, 3);
    return result;
}
'''


class NativeBridge:
    def __init__(self):
        self.directory = tempfile.TemporaryDirectory(prefix="vox-resource-lifecycle-")
        temporary = Path(self.directory.name)
        source = temporary / "probe.c"
        source.write_text(SHIM)
        library = temporary / "probe.so"
        repo = Path(__file__).resolve().parent.parent
        flags = ["-dynamiclib"] if sys.platform == "darwin" else ["-shared", "-fPIC"]
        command = shlex.split(os.environ.get("CC", "cc")) + [
            "-std=c11", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function",
            "-pthread", *flags, "-I", str(repo), str(source), "-lcurl", "-o", str(library),
        ]
        subprocess.run(command, check=True)
        self.api = ctypes.CDLL(str(library))
        pointer = ctypes.c_void_p
        declarations = {
            "test_scope_create": (pointer, []),
            "test_scope_retain": (None, [pointer]),
            "test_scope_release": (ctypes.c_int, [pointer]),
            "test_scope_cancel": (None, [pointer]),
            "test_begin_publication": (ctypes.c_int, [pointer]),
            "test_end_publication": (None, [pointer]),
            "test_probe_create": (pointer, []),
            "test_probe_free": (None, [pointer]),
            "test_probe_phase": (ctypes.c_int, [pointer]),
            "test_probe_body_bytes": (ctypes.c_size_t, [pointer]),
            "test_active_count": (ctypes.c_uint, []),
            "test_peak_count": (ctypes.c_uint, []),
            "test_reset_peak": (None, []),
            "test_fetch": (ctypes.c_int, [pointer, ctypes.c_char_p, pointer]),
        }
        for name, (result, arguments) in declarations.items():
            function = getattr(self.api, name)
            function.restype = result
            function.argtypes = arguments

    def close(self):
        self.directory.cleanup()


class RequestScope:
    def __init__(self, api):
        self.api = api
        self.handle = api.test_scope_create()
        self.closed = False

    def cancel(self):
        self.api.test_scope_cancel(self.handle)

    def close(self):
        if not self.closed:
            self.cancel()
            self.api.test_scope_release(self.handle)
            self.closed = True


class Transfer:
    def __init__(self, api, scope, address):
        self.api = api
        self.scope = scope.handle
        self.probe = api.test_probe_create()
        self.done = threading.Event()
        self.result = None
        self.last_release = None
        api.test_scope_retain(self.scope)

        def run():
            try:
                self.result = api.test_fetch(self.scope, address.encode(), self.probe)
            finally:
                self.last_release = api.test_scope_release(self.scope)
                self.done.set()

        self.thread = threading.Thread(target=run, daemon=True)
        self.thread.start()

    @property
    def phase(self):
        return self.api.test_probe_phase(self.probe)

    @property
    def body_bytes(self):
        return self.api.test_probe_body_bytes(self.probe)

    def close(self):
        if not self.done.wait(3):
            raise RuntimeError("resource worker did not retire after cancellation")
        self.thread.join()
        self.api.test_probe_free(self.probe)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def do_GET(self):
        server = self.server
        with server.changed:
            server.paths.append(self.path)
            server.changed.notify_all()
        if self.path.startswith("/ok"):
            self.send_response(200)
            self.send_header("Content-Length", "2")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b"ok")
            return
        if self.path.startswith("/body"):
            self.send_response(200)
            self.send_header("Content-Length", "1048576")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b"x")
            self.wfile.flush()
        # Headers, or the remainder of a declared body, never arrive. Observe
        # an actual closed connection rather than only a discarded completion.
        self.connection.settimeout(4)
        closed = False
        try:
            while self.connection.recv(1024):
                pass
            closed = True
        except (ConnectionResetError, BrokenPipeError):
            closed = True
        except socket.timeout:
            pass
        finally:
            if closed:
                with server.changed:
                    server.closed_paths.add(self.path)
                    server.changed.notify_all()


class LoopbackServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 128

    def __init__(self):
        self.paths = []
        self.closed_paths = set()
        self.changed = threading.Condition()
        super().__init__(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.serve_forever,
                                       kwargs={"poll_interval": 0.01}, daemon=True)
        self.thread.start()

    def address(self, path):
        return f"http://127.0.0.1:{self.server_port}{path}"

    def wait_for(self, predicate, timeout=2):
        with self.changed:
            return self.changed.wait_for(predicate, timeout)

    def close(self):
        self.shutdown()
        self.server_close()
        self.thread.join()


class ResourceLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = NativeBridge()
        cls.api = cls.bridge.api

    @classmethod
    def tearDownClass(cls):
        cls.bridge.close()

    def setUp(self):
        self.scopes = []
        self.transfers = []
        self.server = LoopbackServer()
        self.assertEqual(self.api.test_active_count(), 0)
        self.api.test_reset_peak()

    def tearDown(self):
        for scope in self.scopes:
            scope.close()
        try:
            for transfer in self.transfers:
                transfer.close()
            self.assertEqual(self.api.test_active_count(), 0)
        finally:
            self.server.close()

    def scope(self):
        scope = RequestScope(self.api)
        self.scopes.append(scope)
        return scope

    def transfer(self, scope, path):
        transfer = Transfer(self.api, scope, self.server.address(path))
        self.transfers.append(transfer)
        return transfer

    def until(self, predicate, timeout=2):
        deadline = time.monotonic() + timeout
        while not predicate():
            if time.monotonic() >= deadline:
                self.fail("resource lifecycle condition did not settle")
            time.sleep(0.005)

    def assert_stalled_request_cancelled(self, path):
        scope = self.scope()
        transfer = self.transfer(scope, path)
        self.assertTrue(self.server.wait_for(lambda: path in self.server.paths))
        if path.startswith("/body"):
            self.until(lambda: transfer.body_bytes > 0)
        started = time.monotonic()
        scope.cancel()
        self.assertTrue(transfer.done.wait(2), "active request still waiting for the ten-second timeout")
        self.assertLess(time.monotonic() - started, 2)
        self.assertEqual(transfer.result, 42)  # CURLE_ABORTED_BY_CALLBACK
        self.assertTrue(self.server.wait_for(lambda: path in self.server.closed_paths))
        self.assertEqual(self.api.test_active_count(), 0)

    def test_cancel_closes_a_connection_stalled_before_response_headers(self):
        self.assert_stalled_request_cancelled("/headers")

    def test_cancel_closes_a_connection_stalled_during_response_body(self):
        self.assert_stalled_request_cancelled("/body")

    def test_overlapping_batches_share_capacity_and_cancelled_queued_work_never_starts(self):
        first, second, queued = self.scope(), self.scope(), self.scope()
        active = [self.transfer(scope, f"/batch-{batch}/{index}")
                  for batch, scope in enumerate((first, second)) for index in range(12)]
        self.until(lambda: self.api.test_active_count() == 16)
        self.assertTrue(self.server.wait_for(lambda: len(self.server.paths) == 16))
        waiting = [self.transfer(queued, f"/cancelled-queue/{index}") for index in range(4)]
        self.until(lambda: all(transfer.phase == 1 for transfer in waiting))
        queued.cancel()
        deadline = time.monotonic() + 2
        for transfer in waiting:
            self.assertTrue(transfer.done.wait(max(0, deadline - time.monotonic())))
            self.assertEqual(transfer.result, 42)
        self.assertFalse(any(path.startswith("/cancelled-queue/") for path in self.server.paths))
        self.assertEqual(self.api.test_active_count(), 16)
        self.assertEqual(self.api.test_peak_count(), 16)
        first.cancel()
        second.cancel()
        deadline = time.monotonic() + 2
        for transfer in active:
            self.assertTrue(transfer.done.wait(max(0, deadline - time.monotonic())))
            self.assertEqual(transfer.result, 42)
        self.assertEqual(self.api.test_active_count(), 0)
        fresh = self.transfer(self.scope(), "/ok/after-cancellation")
        self.assertTrue(fresh.done.wait(2))
        self.assertEqual(fresh.result, 0)
        self.assertEqual(fresh.body_bytes, 2)

    def test_owner_release_keeps_a_cancelled_worker_handle_alive(self):
        scope = self.scope()
        transfer = self.transfer(scope, "/owner-retirement")
        self.assertTrue(self.server.wait_for(lambda: "/owner-retirement" in self.server.paths))
        scope.close()
        self.assertTrue(transfer.done.wait(2))
        self.assertEqual(transfer.result, 42)
        self.assertTrue(self.server.wait_for(lambda: "/owner-retirement" in self.server.closed_paths))

    def test_scope_releases_native_storage_after_its_final_reference(self):
        handle = self.api.test_scope_create()
        self.api.test_scope_retain(handle)
        self.assertFalse(self.api.test_scope_release(handle))
        self.api.test_scope_cancel(handle)
        self.assertTrue(self.api.test_scope_release(handle))

    def test_cancellation_waits_for_an_existing_publication_and_rejects_later_ones(self):
        scope = self.scope()
        entered, finish, cancelled = threading.Event(), threading.Event(), threading.Event()
        acquired = []

        def publish():
            acquired.append(bool(self.api.test_begin_publication(scope.handle)))
            entered.set()
            finish.wait(3)
            if acquired[0]:
                self.api.test_end_publication(scope.handle)

        def cancel():
            scope.cancel()
            cancelled.set()

        writer = threading.Thread(target=publish, daemon=True)
        canceller = threading.Thread(target=cancel, daemon=True)
        writer.start()
        try:
            self.assertTrue(entered.wait(2))
            self.assertEqual(acquired, [True])
            canceller.start()
            self.assertFalse(cancelled.wait(0.05))
        finally:
            finish.set()
            writer.join(2)
            if canceller.ident is not None:
                canceller.join(2)
        self.assertTrue(cancelled.is_set())
        self.assertFalse(self.api.test_begin_publication(scope.handle))


if __name__ == "__main__":
    unittest.main(verbosity=2)
