module http

import platform
import strings

struct VoxReceiveFixture {
    bytes []u8
    chunk int = 4093
    fail_after bool
mut:
    offset int
}

fn vox_receive_fixture_read(owner voidptr, output &u8, capacity int) !int {
    mut fixture := unsafe { &VoxReceiveFixture(owner) }
    if fixture.offset >= fixture.bytes.len {
        if fixture.fail_after { return error_with_code('owned transport failure'.clone(), 73) }
        return 0
    }
    count := int_min(capacity, int_min(fixture.chunk, fixture.bytes.len - fixture.offset))
    unsafe { vmemcpy(output, &u8(fixture.bytes.data) + fixture.offset, count) }
    fixture.offset += count
    return count
}

fn vox_receive_retained_trial(raw []u8, control bool) i64 {
    mut arena := platform.new_arena('HTTP receive retention')
    entry := arena.enter()
    mut fixture := VoxReceiveFixture{bytes:raw}
    mut content := strings.new_builder(4096)
    if control {
        for offset := 0; offset < raw.len; offset += 4093 {
            count := int_min(4093, raw.len - offset)
            unsafe { content.write_ptr(&u8(raw.data) + offset, count) }
        }
    } else {
        request := Request{}
        info := request.receive_all_data_from_cb_in_builder(mut content, &fixture,
            vox_receive_fixture_read) or { panic(err) }
        assert info.reusable
    }
    assert content.len == raw.len
    same := unsafe { content.data.vbytes(content.len) } == raw
    assert same
    retained := arena.usage().used
    arena.leave(entry)
    arena.release()
    return retained
}

fn test_receive_growth_retains_only_the_published_buffer() {
    $if prealloc {
        payload := []u8{len:8 * 1024 * 1024, init:u8(index % 251)}
        header := 'HTTP/1.1 200 OK\r\nContent-Length: ${payload.len}\r\n\r\n'
        mut raw := header.bytes()
        raw << payload
        control := vox_receive_retained_trial(raw, true)
        candidate := vox_receive_retained_trial(raw, false)
        println('# HTTP receive retained bytes: control=${control} candidate=${candidate}')
        assert candidate < i64(raw.len) + 65536
        assert 2 * candidate <= control
    }
}

fn test_receive_errors_publish_partial_bytes_and_preserve_existing_content() {
    raw := 'HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\npartial body'.bytes()
    mut fixture := VoxReceiveFixture{bytes:raw, chunk:7, fail_after:true}
    mut content := strings.new_builder(1)
    content.write_string('prefix:')
    request := Request{}
    request.receive_all_data_from_cb_in_builder(mut content, &fixture,
        vox_receive_fixture_read) or {
        assert err.code() == 73
        assert err.msg() == 'owned transport failure'
        assert content.str() == 'prefix:' + raw.bytestr()
        return
    }
    assert false, 'transport error lost'
}

struct VoxReceiveProgress {
mut:
    chunks []string
}

fn vox_receive_owned_progress(request &Request, bytes []u8, received u64,
    expected u64, status int) ! {
    assert received <= expected
    assert status == 200
    mut owner := unsafe { &VoxReceiveProgress(request.user_ptr) }
    owner.chunks << bytes.bytestr()
}

fn test_receive_progress_and_prior_responses_keep_their_ordinary_owners() {
    payloads := ['persistent callback data\x00\xff'.repeat(4096),
        'replacement bytes\xff\x00'.repeat(4096)]
    mut progress := VoxReceiveProgress{}
    request := Request{on_progress_body:vox_receive_owned_progress, user_ptr:&progress}
    mut content := strings.new_builder(1)
    mut bodies := []string{}
    for payload in payloads {
        raw := ('HTTP/1.1 200 OK\r\nContent-Length: ${payload.len}\r\n\r\n' + payload).bytes()
        mut fixture := VoxReceiveFixture{bytes:raw}
        info := request.receive_all_data_from_cb_in_builder(mut content, &fixture,
            vox_receive_fixture_read)!
        response := parse_received_response(content.str(), info)!
        assert response.body == payload
        bodies << response.body
        assert progress.chunks.join('') == payload
        progress.chunks.clear()
    }
    assert bodies == payloads
    assert content.len == 0
}
