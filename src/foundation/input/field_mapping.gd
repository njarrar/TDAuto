class_name FieldMapping extends RefCounted
## Pure display helpers for the input adapter (ADR-0003 Decision 5). Static
## functions only, no state, float types only. Field size comes from FieldBounds.

## Input GDD target_ok floor: 48 dp at radius 36. A platform floor, not a tuning value.
const MIN_FIELD_WIDTH_DP := 360


## Pixels per field unit under the `keep` stretch aspect. 0.0 or less means unusable.
static func field_scale(window_size: Vector2) -> float:
	if not (is_finite(window_size.x) and is_finite(window_size.y)):
		return 0.0
	return minf(window_size.x / FieldBounds.WIDTH, window_size.y / FieldBounds.HEIGHT)


## Safe-area insets in field units. `safe` is the display safe area in screen
## pixels, `window_pos` the window origin in screen pixels. Letterbox bars absorb
## insets first. A scale of 0 or less gives all zeros.
static func insets_from_safe_area(safe: Rect2, window_pos: Vector2, window_size: Vector2) -> FieldInsets:
	var s: float = field_scale(window_size)
	if not (s > 0.0):
		return FieldInsets.new()
	var fx: float = FieldBounds.WIDTH
	var fy: float = FieldBounds.HEIGHT
	var ox: float = (window_size.x - fx * s) / 2.0
	var oy: float = (window_size.y - fy * s) / 2.0
	var sx0: float = safe.position.x - window_pos.x
	var sy0: float = safe.position.y - window_pos.y
	var sx1: float = safe.end.x - window_pos.x
	var sy1: float = safe.end.y - window_pos.y
	var top: float = maxf(0.0, (sy0 - oy) / s)
	var bottom: float = maxf(0.0, (oy + fy * s - sy1) / s)
	var left: float = maxf(0.0, (sx0 - ox) / s)
	var right: float = maxf(0.0, (ox + fx * s - sx1) / s)
	return FieldInsets.new(top, bottom, left, right)


## False when the press is outside the field, inside the edge-reject strips or
## inside the top or bottom insets. Boundaries themselves are allowed.
static func press_allowed(pos: Vector2, insets: FieldInsets, edge_reject_margin: float) -> bool:
	if not (is_finite(pos.x) and is_finite(pos.y)):
		return false
	if pos.x < 0.0 or pos.x > FieldBounds.WIDTH or pos.y < 0.0 or pos.y > FieldBounds.HEIGHT:
		return false
	var used: FieldInsets = insets if insets != null else FieldInsets.new()
	if pos.x < edge_reject_margin + used.left:
		return false
	if pos.x > FieldBounds.WIDTH - (edge_reject_margin + used.right):
		return false
	if pos.y < used.top:
		return false
	if pos.y > FieldBounds.HEIGHT - used.bottom:
		return false
	return true


## Field width in dp: F.x * s / px_per_dp. -1.0 when the scale or density is unusable.
static func field_width_dp(window_size: Vector2, px_per_dp: float) -> float:
	var s: float = field_scale(window_size)
	if not (s > 0.0) or not (px_per_dp > 0.0) or not is_finite(px_per_dp):
		return -1.0
	return FieldBounds.WIDTH * s / px_per_dp


## True when the width is at least the floor. Call with floori(field_width_dp(...)).
static func width_supported(width_dp: int) -> bool:
	return width_dp >= MIN_FIELD_WIDTH_DP
