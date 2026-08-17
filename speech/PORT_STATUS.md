# Speech translation status

Upstream: `Libraries/LibWeb/Speech`

| Upstream unit | V implementation |
| --- | --- |
| `SpeechGrammar.cpp` | `grammar_and_results.v` |
| `SpeechGrammarList.cpp` | `grammar_and_results.v` |
| `SpeechRecognitionAlternative.cpp` | `grammar_and_results.v` |
| `SpeechRecognitionResult.cpp` | `grammar_and_results.v` |
| `SpeechRecognitionResultList.cpp` | `grammar_and_results.v` |
| `SpeechRecognition.cpp` | `recognition.v` |
| `SpeechRecognitionEvent.cpp` | `recognition.v` |
| `SpeechRecognitionPhrase.cpp` | `recognition.v` |
| `SpeechSynthesis.cpp` | `synthesis.v` |
| `SpeechSynthesisUtterance.cpp` | `synthesis.v` |
| `SpeechSynthesisVoice.cpp` | `synthesis.v` |

- Upstream: 11 `.cpp` files, 504 physical LOC.
- V implementation: 596 LOC.
- V tests: 111 LOC in 1 file.
- Status: complete.

The translated surface includes collection getters, recognition state and all
handlers, concrete recognition events, phrases, synthesis state/voices,
utterance properties and all utterance handlers. Platform population helpers
stand in for the speech engine that current upstream does not implement.

Verification: `v test speech`, `v fmt -verify speech`, and scoped
`git diff --check` pass.
