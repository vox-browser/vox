# Serial translation status

Upstream: `Libraries/LibWeb/Serial`

| Upstream unit | V implementation |
| --- | --- |
| `Serial.cpp` | `serial.v` |
| `SerialPort.cpp` | `serial_port.v` |

- Upstream: 2 `.cpp` files, 381 physical LOC.
- V implementation: 231 LOC.
- V tests: 33 LOC in 1 file.
- Status: complete.

All dictionaries, enums, state, information, streams, event handlers, and
promise-shaped APIs are represented. Methods whose algorithms are entirely
upstream FIXME preserve the current rejected `UnknownError` promise behavior.

Verification: `v test serial`, `v fmt -verify serial`, and scoped
`git diff --check` pass.
