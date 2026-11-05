# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 4: does not parse on purpose (missing colon).
extends GdUnitTestSuite


func test_never_runs() -> void
	assert_int(1).is_equal(1)
