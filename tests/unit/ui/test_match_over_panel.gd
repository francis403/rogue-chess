extends GutTest
## MatchOverPanel: the headline names what decided the match, and the big score
## shows only when the score decided it.


func test_king_capture_leads_with_king_captured() -> void:
	assert_eq(MatchOverPanel.headline("king", true), "King captured: you took their king")
	assert_eq(MatchOverPanel.headline("king", false), "King captured: you lost your king")


func test_other_reasons_use_the_reason_text() -> void:
	for reason in ["score", "no_moves", "turn_limit"]:
		assert_eq(MatchOverPanel.headline(reason, true), EventText.reason_text(reason, true).trim_suffix("."))
		assert_ne(MatchOverPanel.headline(reason, true), MatchOverPanel.headline(reason, false))


func test_big_score_only_when_the_score_decided_it() -> void:
	assert_true(MatchOverPanel.is_score_the_story("score", [10, 4]))
	assert_true(MatchOverPanel.is_score_the_story("turn_limit", [3, 3]), "a tie at the turn limit is the story")
	assert_false(MatchOverPanel.is_score_the_story("turn_limit", [0, 0]), "0–0 is never shown big")
	assert_false(MatchOverPanel.is_score_the_story("king", [5, 2]), "a king capture outranks the score")
	assert_false(MatchOverPanel.is_score_the_story("no_moves", [1, 0]))
