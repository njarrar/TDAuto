# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 3b: a failure and a leak in one run (100 should win over 101).
extends GdUnitTestSuite


func test_leak_and_fail() -> void:
	var leaked: Node = Node.new()
	assert_object(leaked).is_not_null()
	assert_int(1).is_equal(2)
