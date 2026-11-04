class_name FieldInsets extends RefCounted
## Safe-area insets in field units (ADR-0003 Decision 5). Four floats, all 0 on
## desktop. Built by FieldMapping, read by the HUD as I_top and I_bottom.

## Distance from the top field edge to the usable area.
var top: float = 0.0
## Distance from the bottom field edge to the usable area.
var bottom: float = 0.0
## Distance from the left field edge to the usable area.
var left: float = 0.0
## Distance from the right field edge to the usable area.
var right: float = 0.0


func _init(p_top: float = 0.0, p_bottom: float = 0.0, p_left: float = 0.0, p_right: float = 0.0) -> void:
	top = p_top
	bottom = p_bottom
	left = p_left
	right = p_right


## True when all four values equal the other's.
func is_equal_to(other: FieldInsets) -> bool:
	if other == null:
		return false
	return top == other.top and bottom == other.bottom and left == other.left and right == other.right
