# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 7: two failing tests.
extends GdUnitTestSuite


func test_first_fails() -> void:
	assert_int(1).is_equal(2)


func test_second_fails() -> void:
	assert_int(3).is_equal(4)
