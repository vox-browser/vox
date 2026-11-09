
pub fn new_header(kvs ...HeaderConfig) Header {
    mut h := Header{}
    for kv in kvs { h.add(kv.key, kv.value) }
    return h
}