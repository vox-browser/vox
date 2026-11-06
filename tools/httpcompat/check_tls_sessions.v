// Run against the generated HTTP adapter; the Python fixture independently
// checks whether each fresh TLS connection actually resumed on the server.
module main

import net.http
import os
import time

struct TLSFocusAction {
    url string
    verify string
    proxy string
    cert string
    cert_key string
    copy_ca_from string
    copy_ca_to string
    enable_http2 bool = true
    validate bool = true
    disable_connection_reuse bool
    require_success bool = true
    parallel int = 1
    contains string
    post bool
}

struct TLSFocusSpec {
    name string
    actions []TLSFocusAction
}

struct TLSFocusResult {
    action int
    worker int
    success bool
    status int
}

fn tls_focus_request(name string, action TLSFocusAction, index int, worker int) TLSFocusResult {
    mut header := http.new_header(key: .connection, value: 'close')
    header.add_custom('X-Vox-TLS-Case', name) or { panic(err) }
    header.add_custom('X-Vox-TLS-Action', '${index}-${worker}') or { panic(err) }
    response := http.fetch(
        url: action.url
        method: if action.post { http.Method.post } else { http.Method.get }
        data: if action.post { 'once' } else { '' }
        verify: action.verify
        validate: action.validate
        cert: action.cert
        cert_key: action.cert_key
        proxy: if action.proxy == '' { unsafe { nil } } else { http.new_http_proxy(action.proxy) or { panic(err) } }
        enable_http2: action.enable_http2
        disable_connection_reuse: action.disable_connection_reuse
        max_retries: 1
        allow_redirect: false
        read_timeout: 2 * time.second
        write_timeout: 2 * time.second
        header: header
    ) or {
        if action.require_success { panic(err) }
        return TLSFocusResult{action:index, worker:worker}
    }
    if !action.require_success { panic('Untrusted TLS request unexpectedly succeeded') }
    correct_body := if action.contains == '' { response.body == 'ok' } else { response.body.contains(action.contains) }
    if response.status_code != 200 || !correct_body {
        panic('TLS fixture returned an incorrect status or body')
    }
    return TLSFocusResult{action:index, worker:worker, success:true, status:response.status_code}
}

fn tls_focus_report(result TLSFocusResult) {
    success := if result.success { '1' } else { '0' }
    println('TLS_RESULT\t${result.action}\t${result.worker}\t${success}\t${result.status}')
}

fn main() {
    if os.args.len != 2 { panic('Expected one TLS fixture specification') }
    lines := os.read_lines(os.args[1])!
    if lines.len < 2 { panic('Empty TLS fixture specification') }
    mut actions := []TLSFocusAction{}
    for line in lines[1..] {
        fields := line.split('\t')
        if fields.len != 14 { panic('Invalid TLS fixture specification') }
        actions << TLSFocusAction{
            url:fields[0], verify:fields[1], proxy:fields[2], cert:fields[3], cert_key:fields[4]
            copy_ca_from:fields[5], copy_ca_to:fields[6], enable_http2:fields[7]=='1'
            validate:fields[8]=='1', disable_connection_reuse:fields[9]=='1'
            require_success:fields[10]=='1', parallel:fields[11].int()
            contains:fields[12], post:fields[13]=='1'
        }
    }
    spec := TLSFocusSpec{name:lines[0], actions:actions}
    for index, action in spec.actions {
        if action.copy_ca_from != '' {
            os.cp(action.copy_ca_from, action.copy_ca_to)!
        }
        if action.parallel <= 1 {
            tls_focus_report(tls_focus_request(spec.name, action, index, 0))
        } else {
            mut jobs := []thread TLSFocusResult{}
            for worker in 0 .. action.parallel {
                jobs << spawn tls_focus_request(spec.name, action, index, worker)
            }
            for job in jobs { tls_focus_report(job.wait()) }
        }
    }
}
