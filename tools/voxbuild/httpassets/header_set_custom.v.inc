
pub fn (mut h Header) set_custom(key string, value string) ! {
    is_valid(key)!
    h.vox_replace_header_value(key, value)
}