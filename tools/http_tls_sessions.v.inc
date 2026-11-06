@[has_globals]
module http

import net.ssl
import os

const disable_tls12_session_reuse = os.getenv('VOX_DISABLE_TLS12_SESSION_REUSE') != ''
const tls12_session_diagnostics = os.getenv('VOX_TLS12_SESSION_DIAGNOSTICS') != ''

$if macos || linux {
    $if use_openssl ? {
    } $else {
        #include "@DIR/vox_tls_sessions.h"
        fn C.vox_tls12_monotonic_ns() u64
        fn C.vox_tls12_session_identity(output &u8, identity voidptr, identity_length u64, protocols voidptr) bool
        fn C.vox_tls12_identity_cached(identity &u8, now u64) bool
        fn C.vox_tls12_session_key(output &u8, identity voidptr, identity_length u64, trust voidptr, protocols voidptr) bool
        fn C.vox_tls12_session_restore(context voidptr, key &u8, now u64) int
        fn C.vox_tls12_session_forget(key &u8)
        fn C.vox_tls12_authenticated(context voidptr) bool
        fn C.vox_tls12_session_save(context voidptr, key &u8, identity &u8, now u64) bool
    }
}

struct VoxTLS12SessionKey {
mut:
    bytes [32]u8
    identity [32]u8
    eligible bool
    valid bool
    offered bool
}

fn vox_http_prepare_tls_session(req &Request, host string, port int, allow_restore bool, mut connection ssl.SSLConn) !VoxTLS12SessionKey {
    mut result := VoxTLS12SessionKey{}
    $if macos || linux {
        $if use_openssl ? {
        } $else {
            if disable_tls12_session_reuse || req.disable_connection_reuse || !req.validate
                || req.cert != '' || req.cert_key != '' || connection.certs == unsafe { nil } {
                return result
            }
            identity := transport_pool_key(req, 'https', host, port)
            result.eligible = C.vox_tls12_session_identity(unsafe { &result.identity[0] },
                identity.str, u64(identity.len), voidptr(connection.alpn_list))
            now := C.vox_tls12_monotonic_ns()
            if allow_restore && result.eligible && C.vox_tls12_identity_cached(unsafe { &result.identity[0] }, now) {
                result.valid = C.vox_tls12_session_key(unsafe { &result.bytes[0] }, identity.str,
                    u64(identity.len), voidptr(&connection.certs.cacert), voidptr(connection.alpn_list))
                if tls12_session_diagnostics { eprintln('Vox TLS1.2 session: examined parsed trust') }
            }
            if result.valid {
                status := C.vox_tls12_session_restore(voidptr(&connection.ssl),
                    unsafe { &result.bytes[0] }, C.vox_tls12_monotonic_ns())
                if status < 0 {
                    return error_with_code('http: TLS session copy failed', status)
                }
                result.offered = status == 1
            }
        }
    }
    return result
}

fn vox_http_forget_tls_session(key VoxTLS12SessionKey) {
    $if macos || linux {
        $if use_openssl ? {
        } $else {
            if key.valid { C.vox_tls12_session_forget(unsafe { &key.bytes[0] }) }
        }
    }
}

fn vox_http_remember_tls_session(req &Request, host string, port int, key VoxTLS12SessionKey, connection &ssl.SSLConn) {
    $if macos || linux {
        $if use_openssl ? {
        } $else {
            if !key.eligible { return }
            // A resumed session may retain only its leaf certificate. Keep
            // the original full-handshake chain window and fixed expiry;
            // never extend it from a resumed or rejected-offer connection.
            if !key.offered && C.vox_tls12_authenticated(voidptr(&connection.ssl)) {
                mut bytes := key.bytes
                mut valid := key.valid
                if !valid {
                    identity := transport_pool_key(req, 'https', host, port)
                    valid = C.vox_tls12_session_key(unsafe { &bytes[0] }, identity.str,
                        u64(identity.len), voidptr(&connection.certs.cacert), voidptr(connection.alpn_list))
                    if tls12_session_diagnostics { eprintln('Vox TLS1.2 session: examined parsed trust') }
                }
                if valid {
                    C.vox_tls12_session_save(voidptr(&connection.ssl), unsafe { &bytes[0] },
                        unsafe { &key.identity[0] }, C.vox_tls12_monotonic_ns())
                }
            }
            if key.offered && tls12_session_diagnostics {
                // This witnesses the offer, not server acceptance. A separate
                // server-side diagnostic verifies actual workload resumption.
                eprintln('Vox TLS1.2 session: offered a verified cached session')
            }
        }
    }
}
