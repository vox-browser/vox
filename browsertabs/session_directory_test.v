module browsertabs

import os
import rand

fn test_session_directories_remain_distinct_when_application_randomness_repeats() {
    // Reproduce a previously used directory-name sequence, as observed in
    // fresh-process startup probes, without touching any existing session.
    rand.seed([u32(1729), 42])
    mut first := create(Frame{ width: 800, height: 600 })!
    defer { first.leave() or {} }
    rand.seed([u32(1729), 42])
    mut second := create(Frame{ width: 1024, height: 768 })!
    defer { second.leave() or {} }
    assert first.folder != second.folder
    assert os.is_dir(first.folder)
    assert os.is_dir(second.folder)
    assert first.state.frame.width == 800
    assert second.state.frame.width == 1024
    assert (os.stat(first.folder)!.mode & 0o777) == 0o700
    assert (os.stat(second.folder)!.mode & 0o777) == 0o700
    first.poll('First', 'https://first.test', '', true)!
    second.poll('Second', 'https://second.test', '', true)!
    assert first.state.tabs[0].title == 'First'
    assert second.state.tabs[0].title == 'Second'
}

fn test_session_directory_failure_does_not_reuse_a_parent_directory() {
    root := create_session_directory(os.temp_dir())!
    defer { os.rmdir_all(root) or {} }
    missing := os.join_path(root, 'missing')
    if _ := create_session_directory(missing) {
        assert false
    }
    assert os.is_dir(root)
    assert !os.exists(missing)
    assert os.ls(root)!.len == 0
}
