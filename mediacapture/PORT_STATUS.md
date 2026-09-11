# MediaCapture port status

| Upstream implementation | V translation |
| --- | --- |
| `MediaDeviceInfo.cpp` | `media_capture.v` |
| `MediaDevices.cpp` | `media_capture.v` |
| `MediaStream.cpp` | `media_capture.v` |
| `MediaStreamTrack.cpp` | `media_capture.v` |
| `MediaStreamTrackEvent.cpp` | `media_capture.v` |

The platform audio-device cache and capture stream are explicit injected
boundaries. Focused tests cover exposure/redaction, view/focus/cache gating,
constraint selection, stream and track lifetimes, events, frame chunking and
silence, capture-start races, and device-change notifications.
