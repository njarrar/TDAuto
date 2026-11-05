# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 1, 6, 8.
extends GdUnitTestSuite


func test_one_plus_one_is_two() -> void:
	assert_int(1 + 1).is_equal(2)
