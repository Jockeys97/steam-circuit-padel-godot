## Measurements at 1280x720 (bodies=rig, frozen tick 420)

### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band

| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |
|---|---|---:|---:|---:|---:|---:|---:|---|
| current-composition | near player | 1232 | 1232 | 0 | 0.0 | 100.0 | 0.0 | YES |
| current-composition | near partner | 1600 | 0 | 1600 | 100.0 | 100.0 | 0.0 | YES |
| current-composition | far player | 1264 | 474 | 790 | 62.5 | 100.0 | 100.0 | no |
| current-composition | far partner | 1118 | 0 | 1118 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near player | 698 | 0 | 698 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near partner | 812 | 0 | 812 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far player | 716 | 0 | 716 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far partner | 659 | 0 | 659 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near player | 1232 | 0 | 1232 | 100.0 | 100.0 | 0.0 | YES |
| slim-bottom-band | near partner | 1600 | 987 | 613 | 38.3 | 100.0 | 21.2 | YES |
| slim-bottom-band | far player | 1264 | 474 | 790 | 62.5 | 100.0 | 100.0 | no |
| slim-bottom-band | far partner | 1118 | 0 | 1118 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near player | 909 | 0 | 909 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near partner | 1109 | 0 | 1109 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far player | 939 | 0 | 939 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far partner | 833 | 0 | 833 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near player | 590 | 0 | 590 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near partner | 712 | 0 | 712 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far player | 637 | 0 | 637 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far partner | 577 | 0 | 577 | 100.0 | 100.0 | 100.0 | no |
| behind-the-baseline | near player | 0 | 0 | 0 | 0.0 | 32.7 | 0.0 | YES |
| behind-the-baseline | near partner | 0 | 0 | 0 | 0.0 | 39.4 | 0.0 | YES |
| behind-the-baseline | far player | 4054 | 67 | 3987 | 98.3 | 100.0 | 100.0 | no |
| behind-the-baseline | far partner | 3214 | 0 | 3214 | 100.0 | 100.0 | 100.0 | no |

### Court, ball and the bottom band

| option | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| current-composition | 100.0 | 559644 | 106916 | 10.2 | 9.7 | 190 | 26.4 | 252336 |
| raised-backed-off | 100.0 | 331036 | 40565 | 7.7 | 7.5 | 190 | 26.4 | 252336 |
| slim-bottom-band | 100.0 | 559644 | 67390 | 10.2 | 9.7 | 168 | 23.3 | 230104 |
| raised-and-slim-band | 100.0 | 422462 | 31022 | 8.9 | 8.4 | 168 | 23.3 | 230104 |
| tactical-wide | 100.0 | 279960 | 19654 | 7.3 | 7.0 | 207 | 28.8 | 252336 |
| behind-the-baseline | 1.0 | 506567 | 115120 | 16.8 | 14.5 | 190 | 26.4 | 252336 |

### Deltas against `current-composition` (positive = more of it)

| option | near-pair readable px | ball diameter px | court in frame pp | court bed px under HUD | HUD area px |
|---|---:|---:|---:|---:|---:|
| current-composition | +0 | +0.0 | +0.0 | +0 | +0 |
| raised-backed-off | -90 | -2.5 | +0.0 | -66351 | +0 |
| slim-bottom-band | +245 | +0.0 | +0.0 | -39526 | -22232 |
| raised-and-slim-band | +418 | -1.3 | +0.0 | -75894 | -22232 |
| tactical-wide | -298 | -2.9 | +0.0 | -87262 | +0 |
| behind-the-baseline | -1600 | +6.6 | -99.0 | +8204 | +0 |

### HUD panels, per option (engine rectangles, x y w h)

| option | panel | rect | court bed px it covers |
|---|---|---|---:|
| current-composition | ScorePanel | 280 10 720 125 | 720 |
| current-composition | FeedbackPanel | 506 530 268 160 | 42880 |
| current-composition | LogPanel | 12 538 420 172 | 56833 |
| current-composition | DebugPanel | 12 10 196 91 | 0 |
| current-composition | HintPanel | 1008 148 260 113 | 6483 |
| raised-backed-off | ScorePanel | 280 10 720 125 | 0 |
| raised-backed-off | FeedbackPanel | 506 530 268 160 | 23584 |
| raised-backed-off | LogPanel | 12 538 420 172 | 16981 |
| raised-backed-off | DebugPanel | 12 10 196 91 | 0 |
| raised-backed-off | HintPanel | 1008 148 260 113 | 0 |
| slim-bottom-band | ScorePanel | 280 10 720 125 | 720 |
| slim-bottom-band | FeedbackPanel | 996 552 272 160 | 29643 |
| slim-bottom-band | LogPanel | 12 618 408 121 | 30544 |
| slim-bottom-band | DebugPanel | 12 10 196 91 | 0 |
| slim-bottom-band | HintPanel | 1008 148 260 113 | 6483 |
| raised-and-slim-band | ScorePanel | 280 10 720 125 | 0 |
| raised-and-slim-band | FeedbackPanel | 996 552 272 160 | 12779 |
| raised-and-slim-band | LogPanel | 12 591 408 121 | 17149 |
| raised-and-slim-band | DebugPanel | 12 10 196 91 | 0 |
| raised-and-slim-band | HintPanel | 1008 148 260 113 | 1094 |
| tactical-wide | ScorePanel | 280 10 720 125 | 0 |
| tactical-wide | FeedbackPanel | 506 530 268 160 | 9916 |
| tactical-wide | LogPanel | 12 513 420 172 | 9738 |
| tactical-wide | DebugPanel | 12 10 196 91 | 0 |
| tactical-wide | HintPanel | 1008 148 260 113 | 0 |
| behind-the-baseline | ScorePanel | 280 10 720 125 | 0 |
| behind-the-baseline | FeedbackPanel | 506 530 268 160 | 42880 |
| behind-the-baseline | LogPanel | 12 538 420 172 | 72240 |
| behind-the-baseline | DebugPanel | 12 10 196 91 | 0 |
| behind-the-baseline | HintPanel | 1008 148 260 113 | 0 |

Unclassified mask pixels (neither a subject nor background): current-composition 38.700%, raised-backed-off 63.762%, slim-bottom-band 38.700%, raised-and-slim-band 53.742%, tactical-wide 69.345%, behind-the-baseline 44.221%
