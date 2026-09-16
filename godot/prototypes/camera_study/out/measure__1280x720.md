## Measurements at 1280x720 (bodies=game, frozen tick 420)

### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band

| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |
|---|---|---:|---:|---:|---:|---:|---:|---|
| current-composition | near player | 1232 | 1232 | 0 | 0.0 | 100.0 | 0.0 | YES |
| current-composition | near partner | 1600 | 0 | 1600 | 100.0 | 100.0 | 0.0 | YES |
| current-composition | far player | 1017 | 502 | 515 | 50.6 | 100.0 | 100.0 | no |
| current-composition | far partner | 896 | 0 | 896 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near player | 698 | 0 | 698 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near partner | 812 | 0 | 812 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far player | 816 | 0 | 816 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far partner | 539 | 0 | 539 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near player | 1232 | 0 | 1232 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near partner | 1600 | 0 | 1600 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | far player | 1008 | 421 | 587 | 58.2 | 100.0 | 100.0 | no |
| slim-bottom-band | far partner | 898 | 0 | 898 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near player | 621 | 0 | 621 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near partner | 693 | 0 | 693 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far player | 533 | 0 | 533 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far partner | 469 | 0 | 469 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near player | 590 | 0 | 590 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near partner | 712 | 0 | 712 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far player | 491 | 0 | 491 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far partner | 460 | 0 | 460 | 100.0 | 100.0 | 100.0 | no |
| behind-the-baseline | near player | 0 | 0 | 0 | 0.0 | 32.7 | 0.0 | YES |
| behind-the-baseline | near partner | 0 | 0 | 0 | 0.0 | 39.4 | 0.0 | YES |
| behind-the-baseline | far player | 3649 | 7 | 3642 | 99.8 | 100.0 | 100.0 | no |
| behind-the-baseline | far partner | 2893 | 0 | 2893 | 100.0 | 100.0 | 100.0 | no |

### Court, ball and the bottom band

| option | court surface in frame % | near half in frame % | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| current-composition | 100.0 | 100.0 | 100.0 | 560142 | 106917 | 8.2 | 9.7 | 190 | 26.4 | 252336 |
| raised-backed-off | 100.0 | 100.0 | 100.0 | 331056 | 40565 | 7.7 | 7.5 | 190 | 26.4 | 252336 |
| slim-bottom-band | 100.0 | 100.0 | 100.0 | 560120 | 66377 | 10.2 | 9.7 | 108 | 15.0 | 204336 |
| raised-and-slim-band | 100.0 | 100.0 | 100.0 | 294584 | 0 | 7.1 | 7.1 | 108 | 15.0 | 204336 |
| tactical-wide | 100.0 | 100.0 | 100.0 | 280223 | 15227 | 7.3 | 7.0 | 190 | 26.4 | 252336 |
| behind-the-baseline | 57.6 | 22.5 | 1.0 | 506602 | 115120 | 16.8 | 14.5 | 190 | 26.4 | 252336 |

`court surface in frame %` is a 41x27 grid of points on the court floor: the share of the playing surface the camera can see. `court quad in frame %` is the projected corner quad clipped to the frame - correct for the top-down options and meaningless for a low camera, where the near corners project thousands of pixels off-screen and blow the denominator up. Both are printed so the failure is visible instead of silent.

### Cameras

| option | mode | solve | dolly back m | position | pitch deg | fov |
|---|---|---|---:|---|---:|---:|
| current-composition | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-backed-off | dolly-solved | near-feet | 4.487 | (0.00, 18.53, 8.28) | -65.20 | 50.87 |
| slim-bottom-band | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-and-slim-band | dolly-solved | near-baseline | 5.682 | (0.00, 19.61, 8.78) | -65.20 | 50.87 |
| tactical-wide | preset-wide | - | 0.000 | (0.00, 16.62, 7.40) | -68.00 | 60.00 |
| behind-the-baseline | preset-playable | - | 0.000 | (0.00, 3.20, 5.80) | -18.69 | 60.00 |

### Deltas against `current-composition` (positive = more of it)

| option | near-pair readable px | ball diameter px | court surface in frame pp | court bed px under HUD | HUD area px |
|---|---:|---:|---:|---:|---:|
| current-composition | +0 | +0.0 | +0.0 | +0 | +0 |
| raised-backed-off | -90 | -0.5 | +0.0 | -66352 | +0 |
| slim-bottom-band | +1232 | +2.0 | +0.0 | -40540 | -48000 |
| raised-and-slim-band | -286 | -1.1 | +0.0 | -106917 | -48000 |
| tactical-wide | -298 | -0.9 | +0.0 | -91690 | +0 |
| behind-the-baseline | -1600 | +8.6 | -42.4 | +8203 | +0 |

### HUD panels, per option (engine rectangles, x y w h)

| option | panel | rect | court bed px it covers |
|---|---|---|---:|
| current-composition | ScorePanel | 280 10 720 125 | 720 |
| current-composition | FeedbackPanel | 506 530 268 160 | 42880 |
| current-composition | LogPanel | 12 538 420 172 | 56833 |
| current-composition | DebugPanel | 12 10 196 91 | 0 |
| current-composition | HintPanel | 1008 148 260 113 | 6484 |
| raised-backed-off | ScorePanel | 280 10 720 125 | 0 |
| raised-backed-off | FeedbackPanel | 506 530 268 160 | 23584 |
| raised-backed-off | LogPanel | 12 538 420 172 | 16981 |
| raised-backed-off | DebugPanel | 12 10 196 91 | 0 |
| raised-backed-off | HintPanel | 1008 148 260 113 | 0 |
| slim-bottom-band | ScorePanel | 280 10 720 125 | 720 |
| slim-bottom-band | FeedbackPanel | 506 612 268 100 | 25460 |
| slim-bottom-band | LogPanel | 12 612 420 96 | 33661 |
| slim-bottom-band | DebugPanel | 12 10 196 91 | 0 |
| slim-bottom-band | HintPanel | 1008 148 260 113 | 6536 |
| raised-and-slim-band | ScorePanel | 280 10 720 125 | 0 |
| raised-and-slim-band | FeedbackPanel | 506 612 268 100 | 0 |
| raised-and-slim-band | LogPanel | 12 612 420 96 | 0 |
| raised-and-slim-band | DebugPanel | 12 10 196 91 | 0 |
| raised-and-slim-band | HintPanel | 1008 148 260 113 | 0 |
| tactical-wide | ScorePanel | 280 10 720 125 | 0 |
| tactical-wide | FeedbackPanel | 506 530 268 160 | 9916 |
| tactical-wide | LogPanel | 12 538 420 172 | 5311 |
| tactical-wide | DebugPanel | 12 10 196 91 | 0 |
| tactical-wide | HintPanel | 1008 148 260 113 | 0 |
| behind-the-baseline | ScorePanel | 280 10 720 125 | 0 |
| behind-the-baseline | FeedbackPanel | 506 530 268 160 | 42880 |
| behind-the-baseline | LogPanel | 12 538 420 172 | 72240 |
| behind-the-baseline | DebugPanel | 12 10 196 91 | 0 |
| behind-the-baseline | HintPanel | 1008 148 260 113 | 0 |

Unclassified mask pixels (neither a subject nor the black background, i.e. the classifier's own error bar): current-composition 0.0000% (0 px), raised-backed-off 0.0000% (0 px), slim-bottom-band 0.0000% (0 px), raised-and-slim-band 0.0000% (0 px), tactical-wide 0.0000% (0 px), behind-the-baseline 0.0000% (0 px)
