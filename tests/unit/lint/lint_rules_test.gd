extends GdUnitTestSuite
## Lint self-tests (ADR-0007 Decision 8): every rule's seeded bad sample and near miss,
## plus the lexer cases of the catalogue's Section 5.

const Lexer := preload("res://tools/lint/lint_lexer.gd")
const LintEngine := preload("res://tools/lint/lint_engine.gd")
const Rules := preload("res://tools/lint/lint_rules.gd")
const Samples := preload("res://tests/helpers/lint_samples.gd")


func test_every_rule_has_a_sample() -> void:
	var samples: Dictionary = Samples.all()
	var missing: Array = []
	for rule in Rules.RULES:
		if not samples.has(rule):
			missing.append(rule)
	assert_array(missing).is_empty()


func test_no_sample_names_an_unknown_rule() -> void:
	var samples: Dictionary = Samples.all()
	var unknown: Array = []
	for rule in samples:
		if not Rules.RULES.has(rule):
			unknown.append(rule)
	assert_array(unknown).is_empty()


func test_bad_samples_yield_exactly_their_finding() -> void:
	var samples: Dictionary = Samples.all()
	var failures: Array = []
	for rule in samples:
		failures.append_array(Array(Samples.check_bad(str(rule), samples[rule])))
	assert_array(failures).is_empty()


func test_near_misses_yield_no_finding() -> void:
	var samples: Dictionary = Samples.all()
	var failures: Array = []
	for rule in samples:
		failures.append_array(Array(Samples.check_near(str(rule), samples[rule])))
	assert_array(failures).is_empty()


func test_pending_rule_is_off_by_default() -> void:
	var samples: Dictionary = Samples.all()
	var sample: Dictionary = samples["WIRE-5"]
	var case_entry: Array = sample["cases"][0]
	var sources: Dictionary = sample["others"].duplicate()
	sources[case_entry[0]] = case_entry[1]
	var index: Dictionary = LintEngine.build_index(sources)

	var found: Array[Dictionary] = LintEngine.check_source(str(case_entry[0]), str(case_entry[1]), index)

	assert_int(found.size()).is_equal(0)


func test_lexer_honours_escaped_quote_and_hash_in_string() -> void:
	var lexed: Dictionary = Lexer.lex('var s = "a\\"b # c"')

	assert_str(lexed["masked"]).is_equal('var s = "' + " ".repeat(8) + '"')
	assert_int((lexed["strings"] as Array).size()).is_equal(1)


func test_lexer_masks_hash_inside_triple_quotes() -> void:
	var lexed: Dictionary = Lexer.lex('var s = """a # b\nc"""\nvar x = 1')
	var masked: String = lexed["masked"]

	assert_bool(masked.contains("#")).is_false()
	assert_int(masked.count("\n")).is_equal(2)
	assert_bool(masked.ends_with("var x = 1")).is_true()
	assert_bool(lexed["strings"][0]["triple"]).is_true()


func test_lexer_reads_node_path_shorthands() -> void:
	var lexed: Dictionary = Lexer.lex('var n = $"A/B"\nvar m = %"Name"')
	var strings: Array = lexed["strings"]

	assert_str(strings[0]["content"]).is_equal("A/B")
	assert_str(strings[0]["prefix"]).is_equal("$")
	assert_str(strings[1]["content"]).is_equal("Name")
	assert_str(strings[1]["prefix"]).is_equal("%")
	assert_bool(str(lexed["masked"]).contains("A/B")).is_false()


func test_lexer_ignores_string_inside_comment() -> void:
	var lexed: Dictionary = Lexer.lex('var a = 1 # note "q"')

	assert_int((lexed["strings"] as Array).size()).is_equal(0)
	assert_bool(str(lexed["masked"]).contains("note")).is_false()


func test_lexer_raw_string_keeps_backslash() -> void:
	var lexed: Dictionary = Lexer.lex('var p = r"a\\b"')

	assert_str(lexed["strings"][0]["content"]).is_equal("a\\b")
	assert_str(lexed["strings"][0]["prefix"]).is_equal("r")


func test_logical_lines_join_a_multi_line_lambda() -> void:
	var lines: Array[Dictionary] = Lexer.logical_lines("sig.connect(func(a):\n\t\tcount += 1\n)\nvar x = 1")

	assert_int(lines.size()).is_equal(2)
	assert_int(lines[0]["line"]).is_equal(1)
	assert_bool(str(lines[0]["text"]).contains("count += 1")).is_true()
	assert_int(lines[1]["line"]).is_equal(4)


func test_logical_lines_join_a_backslash_continuation() -> void:
	var lines: Array[Dictionary] = Lexer.logical_lines("var a = 1 + \\\n\t2\nvar b = 3")

	assert_int(lines.size()).is_equal(2)
	assert_bool(str(lines[0]["text"]).contains("2")).is_true()


func test_logical_lines_record_the_enclosing_function() -> void:
	var lines: Array[Dictionary] = Lexer.logical_lines("var a = 1\nfunc f() -> void:\n\tpass\nvar b = 2")

	assert_str(lines[0]["func"]).is_equal("")
	assert_str(lines[2]["func"]).is_equal("f")
	assert_str(lines[3]["func"]).is_equal("")


func test_file_exceptions_stay_within_budget() -> void:
	assert_bool(Rules.FILE_EXCEPTIONS.size() <= Rules.MAX_FILE_EXCEPTIONS).is_true()
