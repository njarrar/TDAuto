# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 9: a passing suite that preloads a broken helper.
extends GdUnitTestSuite

const Broken := preload("res://tests/helpers/v1_broken_helper.gd")


func test_preloads_broken_helper() -> void:
	assert_int(1).is_equal(1)
