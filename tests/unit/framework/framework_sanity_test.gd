## Example unit test. It proves gdUnit4 loads, finds this suite and runs it.
## It tests no game code. Copy its shape for the first real test, then delete
## it or keep it as a canary for the test runner.
extends GdUnitTestSuite

const LEFT := 2
const RIGHT := 3
const EXPECTED_SUM := 5


func test_int_addition_returns_sum() -> void:
	# Arrange
	var left := LEFT
	var right := RIGHT

	# Act
	var result := left + right

	# Assert
	assert_int(result).is_equal(EXPECTED_SUM)


func test_auto_freed_node_leaves_no_orphan() -> void:
	# Arrange: auto_free stops the node from leaking (exit 101).
	var node: Node = auto_free(Node.new())

	# Act
	node.name = "Probe"

	# Assert
	assert_str(String(node.name)).is_equal("Probe")
