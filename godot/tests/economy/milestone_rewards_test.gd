extends SceneTree
const Store = preload("res://src/save/save_store.gd")
const Economy = preload("res://src/economy/economy_service.gd")
const Audit = preload("res://src/audits/audit_base.gd")
const Rules = preload("res://src/modes/career_rules.gd")
const ModeScreen = preload("res://game/mode_screen.gd")
func _initialize():
	var audit = Audit.new("milestone_rewards")
	var path = "user://milestone-test-%d" % Time.get_ticks_usec()
	var store = Store.new(path)
	Economy.ensure_initialized(store)
	var tournament = {"mode": "tournament", "won": true, "round": 2}
	var first = Economy.award_completion(store, "t1", 11, true, tournament)
	audit.check_eq(first.awarded, 507, "first tournament includes 450 bonus")
	audit.check_eq(Economy.award_completion(store, "t1", 11, true, tournament).awarded, 0, "same result never pays twice")
	store = Store.new(path)
	audit.check_eq(Economy.award_completion(store, "t2", 11, true, tournament).awarded, 257, "reload retains first clear")
	var career = {"mode": "career", "season": 1, "outcome": {"seasonEnded": true, "seasonWon": false, "outcome": "promoted"}}
	audit.check_eq(Economy.award_completion(store, "c1", 11, false, career).awarded, 267, "promotion can occur after last-match loss")
	career.outcome = {"seasonEnded": true, "seasonWon": true, "outcome": "trophy"}
	audit.check_eq(Economy.award_completion(store, "c2", 11, true, career).awarded, 307, "same season first clear not repeated")
	career.season = 6
	career.outcome.outcome = "finale"
	audit.check_eq(Economy.award_completion(store, "c3", 11, true, career).awarded, 1007, "finale first clear")
	audit.check_eq(Economy.award_completion(store, "c4", 11, true, career).awarded, 307, "finale bonus permanent receipt")
	audit.check_eq(Economy.award_completion(store, "q1", 11, true).awarded, 57, "quick reward unchanged")
	audit.check_true(Rules.master_cup(6).is_empty(), "original six seasons unchanged")
	audit.check_eq(Rules.master_cup(7).id, Rules.master_cup(10).id, "cups cycle every three seasons")
	var pool = [{"id": "officina"}, {"id": "cattedrale"}, {"id": "caldera"}]
	audit.check_eq(Rules.career_fixture(7, 0, pool).arena.id, "officina", "industry opening fixture")
	audit.check_eq(Rules.career_fixture(7, 1, pool).arena.id, "cattedrale", "industry uses available themed court")
	audit.check_eq(Rules.career_fixture(8, 0, pool).arena.id, "caldera", "elements themed court")
	audit.check_eq(Rules.career_fixture(9, 0, [{"id": "officina"}]).arena.id, "officina", "no locked courts granted")
	career.season = 7
	career.outcome.outcome = "trophy"
	audit.check_eq(Economy.award_completion(store, "cup1", 11, true, career).awarded, 707, "first master cup bonus")
	career.season = 10
	audit.check_eq(Economy.award_completion(store, "cup2", 11, true, career).awarded, 407, "master cup first prize not farmed on next cycle")
	var dir = DirAccess.open(path)
	for file in dir.get_files(): dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(audit.finish())
