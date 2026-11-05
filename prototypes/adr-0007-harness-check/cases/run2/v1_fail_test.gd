# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 2.
extends GdUnitTestSuite


func test_one_is_two_fails() -> void:
	assert_int(1).is_equal(2)
