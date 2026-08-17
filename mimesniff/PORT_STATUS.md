# MIME Sniff translation status

Complete, independently audited translation of `Libraries/LibWeb/MimeSniff`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `MimeType.cpp` | `mime_type.v` |
| `Resource.cpp` | `resource.v` |

The resource sniffing contexts, supplied-type handling, Apache bug behavior,
signature tables, feed/end-of-file lifecycle, and text-versus-binary selection
are covered by the typed V implementation and tests. MIME parsing performs the
same full UTF-8 scalar-value validation as upstream `Utf8View`.

- Upstream: 2 `.cpp` files, 1,357 LOC; both adjacent headers audited.
- V implementation: 1,035 LOC in 2 files.
- V tests: 269 LOC in 2 files (31 test functions).
- Verification: `v test mimesniff` and `v fmt -verify mimesniff`.
