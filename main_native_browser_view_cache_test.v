module main
$if macos {
 #include "tools/native_browser_view_cache_test.h"
 fn C.vox_test_replaced_browser_view() int
}
fn test_native_browser_view_cache_follows_the_current_window_tree() {
 $if macos { assert C.vox_test_replaced_browser_view() == 1 }
}
