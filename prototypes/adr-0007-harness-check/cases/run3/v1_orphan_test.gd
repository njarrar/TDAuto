# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 run 3: every assertion passes but a Node is never freed.
extends GdUnitTestSuite


func test_leaked_node_is_not_null() -> void:
	var leaked: Node = Node.new()
	assert_object(leaked).is_not_null()
