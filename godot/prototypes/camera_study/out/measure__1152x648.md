## Measurements at 1152x648 (bodies=game, frozen tick 420)

### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band

| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |
|---|---|---:|---:|---:|---:|---:|---:|---|
| current-composition | near player | 1006 | 1006 | 0 | 0.0 | 100.0 | 0.0 | YES |
| current-composition | near partner | 1305 | 0 | 1305 | 100.0 | 100.0 | 0.0 | YES |
| current-composition | far player | 815 | 782 | 33 | 4.0 | 100.0 | 100.0 | no |
| current-composition | far partner | 730 | 0 | 730 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near player | 422 | 0 | 422 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near partner | 468 | 0 | 468 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far player | 480 | 0 | 480 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far partner | 320 | 0 | 320 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near player | 1006 | 0 | 1006 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near partner | 1305 | 0 | 1305 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | far player | 817 | 811 | 6 | 0.7 | 100.0 | 100.0 | no |
| slim-bottom-band | far partner | 729 | 0 | 729 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near player | 446 | 0 | 446 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near partner | 503 | 0 | 503 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far player | 387 | 0 | 387 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far partner | 345 | 0 | 345 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near player | 475 | 0 | 475 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near partner | 582 | 0 | 582 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far player | 401 | 0 | 401 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far partner | 368 | 0 | 368 | 100.0 | 100.0 | 100.0 | no |
| behind-the-baseline | near player | 0 | 0 | 0 | 0.0 | 32.7 | 0.0 | YES |
| behind-the-baseline | near partner | 0 | 0 | 0 | 0.0 | 39.4 | 0.0 | YES |
| behind-the-baseline | far player | 2965 | 723 | 2242 | 75.6 | 100.0 | 100.0 | no |
| behind-the-baseline | far partner | 2341 | 0 | 2341 | 100.0 | 100.0 | 100.0 | no |

### Court, ball and the bottom band

| option | court surface in frame % | near half in frame % | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| current-composition | 100.0 | 100.0 | 100.0 | 453094 | 120663 | 7.5 | 8.7 | 190 | 29.3 | 252336 |
| raised-backed-off | 100.0 | 100.0 | 100.0 | 202190 | 27720 | 6.2 | 5.9 | 190 | 29.3 | 252336 |
| slim-bottom-band | 100.0 | 100.0 | 100.0 | 453070 | 79614 | 9.2 | 8.7 | 108 | 16.7 | 204336 |
| raised-and-slim-band | 100.0 | 100.0 | 100.0 | 215662 | 0 | 6.3 | 6.1 | 108 | 16.7 | 204336 |
| tactical-wide | 100.0 | 100.0 | 100.0 | 227372 | 23477 | 6.4 | 6.3 | 190 | 29.3 | 252336 |
| behind-the-baseline | 57.6 | 22.5 | 1.0 | 410605 | 115120 | 15.3 | 13.1 | 190 | 29.3 | 252336 |

`court surface in frame %` is a 41x27 grid of points on the court floor: the share of the playing surface the camera can see. `court quad in frame %` is the projected corner quad clipped to the frame - correct for the top-down options and meaningless for a low camera, where the near corners project thousands of pixels off-screen and blow the denominator up. Both are printed so the failure is visible instead of silent.

### Cameras

| option | mode | solve | dolly back m | position | pitch deg | fov |
|---|---|---|---:|---|---:|---:|
| current-composition | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-backed-off | dolly-solved | near-feet | 7.486 | (0.00, 21.25, 9.54) | -65.20 | 50.87 |
| slim-bottom-band | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-and-slim-band | dolly-solved | near-baseline | 6.761 | (0.00, 20.59, 9.24) | -65.20 | 50.87 |
| tactical-wide | preset-wide | - | 0.000 | (0.00, 16.62, 7.40) | -68.00 | 60.00 |
| behind-the-baseline | preset-playable | - | 0.000 | (0.00, 3.20, 5.80) | -18.69 | 60.00 |

### Deltas against `current-composition` (positive = more of it)

| option | near-pair readable px | ball diameter px | court surface in frame pp | court bed px under HUD | HUD area px |
|---|---:|---:|---:|---:|---:|
| current-composition | +0 | +0.0 | +0.0 | +0 | +0 |
| raised-backed-off | -415 | -1.3 | +0.0 | -92943 | +0 |
| slim-bottom-band | +1006 | +1.8 | +0.0 | -41049 | -48000 |
| raised-and-slim-band | -356 | -1.2 | +0.0 | -120663 | -48000 |
| tactical-wide | -248 | -1.1 | +0.0 | -97186 | +0 |
| behind-the-baseline | -1305 | +7.8 | -42.4 | -5543 | +0 |

### HUD panels, per option (engine rectangles, x y w h)

| option | panel | rect | court bed px it covers |
|---|---|---|---:|
| current-composition | ScorePanel | 216 10 720 125 | 10080 |
| current-composition | FeedbackPanel | 442 458 268 160 | 42880 |
| current-composition | LogPanel | 12 466 420 172 | 58450 |
| current-composition | DebugPanel | 12 10 196 91 | 0 |
| current-composition | HintPanel | 880 148 260 113 | 9253 |
| raised-backed-off | ScorePanel | 216 10 720 125 | 0 |
| raised-backed-off | FeedbackPanel | 442 458 268 160 | 17420 |
| raised-backed-off | LogPanel | 12 466 420 172 | 10300 |
| raised-backed-off | DebugPanel | 12 10 196 91 | 0 |
| raised-backed-off | HintPanel | 880 148 260 113 | 0 |
| slim-bottom-band | ScorePanel | 216 10 720 125 | 10080 |
| slim-bottom-band | FeedbackPanel | 442 540 268 100 | 25728 |
| slim-bottom-band | LogPanel | 12 540 420 96 | 34605 |
| slim-bottom-band | DebugPanel | 12 10 196 91 | 0 |
| slim-bottom-band | HintPanel | 880 148 260 113 | 9201 |
| raised-and-slim-band | ScorePanel | 216 10 720 125 | 0 |
| raised-and-slim-band | FeedbackPanel | 442 540 268 100 | 0 |
| raised-and-slim-band | LogPanel | 12 540 420 96 | 0 |
| raised-and-slim-band | DebugPanel | 12 10 196 91 | 0 |
| raised-and-slim-band | HintPanel | 880 148 260 113 | 0 |
| tactical-wide | ScorePanel | 216 10 720 125 | 0 |
| tactical-wide | FeedbackPanel | 442 458 268 160 | 14204 |
| tactical-wide | LogPanel | 12 466 420 172 | 9273 |
| tactical-wide | DebugPanel | 12 10 196 91 | 0 |
| tactical-wide | HintPanel | 880 148 260 113 | 0 |
| behind-the-baseline | ScorePanel | 216 10 720 125 | 0 |
| behind-the-baseline | FeedbackPanel | 442 458 268 160 | 42880 |
| behind-the-baseline | LogPanel | 12 466 420 172 | 72240 |
| behind-the-baseline | DebugPanel | 12 10 196 91 | 0 |
| behind-the-baseline | HintPanel | 880 148 260 113 | 0 |

Unclassified mask pixels (neither a subject nor the black background, i.e. the classifier's own error bar): current-composition 0.0000% (0 px), raised-backed-off 0.0000% (0 px), slim-bottom-band 0.0000% (0 px), raised-and-slim-band 0.0000% (0 px), tactical-wide 0.0000% (0 px), behind-the-baseline 0.0000% (0 px)
