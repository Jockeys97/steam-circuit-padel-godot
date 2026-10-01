# Bruno announcer cues

These ten English WAVs were generated locally with VoiceStudio 0.5.6 using the
`expr-voice-3-m` preset (the `Bruno` alias in the model's
[config.json](https://huggingface.co/KittenML/kitten-tts-mini-0.8/blob/main/config.json))
of `KittenML/kitten-tts-mini-0.8` (model card:
https://huggingface.co/KittenML/kitten-tts-mini-0.8, listed as Apache-2.0).
They are 24 kHz, mono, 16-bit PCM. No model weights or VoiceStudio code are
included in the game.

Use `voice: "expr-voice-3-m"` with VoiceStudio's speech API. Passing the
display name `Bruno` to this API is not recognized and silently falls back to
the female `expr-voice-2-f` preset. All ten clips were regenerated with the
internal Bruno ID after that fallback was discovered; the earlier versions
were replaced.

| File | Spoken line |
| --- | --- |
| `announcer-game-point-bruno-en.wav` | “Game point!” |
| `announcer-break-point-bruno-en.wav` | “Break point!” |
| `announcer-ace-bruno-en.wav` | “Ace!” |
| `announcer-set-point-bruno-en.wav` | “Set point!” |
| `announcer-tie-break-bruno-en.wav` | “Tie-break!” |
| `announcer-match-point-bruno-en.wav` | “Match point! The whole Circuit holds its breath.” |
| `announcer-match-over-bruno-en.wav` | “Match over!” |
| `announcer-career-season-bruno-en.wav` | “New season. Make every match count.” |
| `announcer-tournament-opening-bruno-en.wav` | “Welcome to the Circuit. The run begins.” |
| `announcer-tournament-final-bruno-en.wav` | “One match. One trophy. Your moment.” |

The spoken lines are English in both English and Italian UI locales; Italian
recordings have not been made yet. The in-game mute and SFX volume still apply.
The tournament opening clip fits the existing five-second cinematic without
extending the wait to play.
