# Gate — verdetti espliciti, forma `--headless --script res://tests/ui/<f>.gd`

Unica passata seriale, un audit alla volta (nessuna scrittura concorrente sui log).
Generato dai file `gate-*.log` di questa cartella. Una riga è verde SOLO se l'audit stampa
il proprio verdetto con il conteggio; un `exit=0` senza verdetto è **non verificato**.

| audit | verdetto |
|---|---|
| `theme_probe` | **PASS 305/305** |
| `menu_hover_audit` | **PASS 50/50** |
| `menu_hover_probe` | **PASS 5/5** |
| `screen_characters_audit` | **PASS 183/183** |
| `screen_arena_audit` | **PASS 180/180** |
| `screen_modes_audit` | **PASS 119/119** |
| `screen_menu_audit` | **PASS 97/97** |
| `ui_legibility_audit` | **PASS 676/676** |
| `input_a11y_audit` | **PASS 159/159** |
| `controller_cards_test` | **PASS (formato proprio)** |
| `router_audit` | **PASS 86/86** |
| `uir_route_audit` | **PASS 51/51** |
| `uir22_integration_audit` | **PASS 75/75** |
| `data_audit` | **FAIL 130/131** |
| `hud_audit` | **PASS 172/172** |
| `menu_pad_single_dispatch_test` | **PASS (formato proprio)** |
| `result_coach_audit` | **PASS 120/120** |
| `screen_challenges_audit` | **PASS 73/73** |
| `screen_drill_audit` | **PASS 120/120** |
| `screen_feedback_audit` | **PASS 119/119** |
| `screen_help_audit` | **PASS 91/91** |
| `screen_history_audit` | **PASS 56/56** |
| `screen_profile_audit` | **PASS 74/74** |
| `screen_result_audit` | **PASS 176/176** |
| `screen_settings_audit` | **PASS 91/91** |
| `ui_visibility_audit` | **PASS 146/146** |
| `arena_selector_contract_test` | **PASS 30/30** |
| `clean_mode_audit` | **PASS 64/64** |
| `controller_identity_audit` | **CONTROLLER_IDENTITY PASS** |
| `demo_matrix_audit` | **PASS 133/133** |

Con verdetto esplicito: **30/30**.

**La forma `--quit-after 3000 <f>.tscn` NON è un gate**: produce verdetto vuoto (il timer
chiude il processo prima del verdetto) oppure un `PASS 8/8` che è la SmokeTest dell'engine
(versione, physics tick), non l'audit. Vedi REPORT.md §4.1.
