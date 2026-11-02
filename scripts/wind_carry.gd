extends RefCounted
class_name WindCarry
## Shared, collision-aware movement while the wind attack carries an enemy.

const CARRY_DRAG := 200.0
const MAX_CARRY_SPEED := 190.0


static func freeze(body: CharacterBody2D, duration: float) -> void:
	var previous_until := int(body.get_meta("wind_frozen_until_msec", 0))
	var new_until := Time.get_ticks_msec() + roundi(maxf(duration, 0.0) * 1000.0)
	body.set_meta("wind_frozen_until_msec", maxi(previous_until, new_until))
	cancel(body)
	body.velocity = Vector2.ZERO


static func cancel(body: CharacterBody2D) -> void:
	if body.has_meta("wind_carry_remaining"):
		body.remove_meta("wind_carry_remaining")
	if body.has_meta("wind_carry_flying"):
		body.remove_meta("wind_carry_flying")


static func is_frozen(body: CharacterBody2D) -> bool:
	return int(body.get_meta("wind_frozen_until_msec", 0)) > Time.get_ticks_msec()


static func start(body: CharacterBody2D, direction_x: float, mass: float, sweep_speed_world: float, flying: bool) -> void:
	if is_frozen(body):
		cancel(body)
		return
	var safe_mass := maxf(mass, 0.5)
	var push_speed := minf(MAX_CARRY_SPEED / safe_mass, sweep_speed_world * 0.64)
	var carry_duration := clampf(0.72 / sqrt(safe_mass), 0.22, 0.8)
	body.set_meta("wind_carry_remaining", carry_duration)
	body.set_meta("wind_carry_flying", flying)
	body.velocity.x = signf(direction_x) * push_speed
	if flying:
		body.velocity.y *= 0.25


static func move_if_active(body: CharacterBody2D, delta: float) -> bool:
	if is_frozen(body):
		cancel(body)
		return false
	if not body.has_meta("wind_carry_remaining"):
		return false
	var remaining := float(body.get_meta("wind_carry_remaining"))
	if remaining <= 0.0:
		body.remove_meta("wind_carry_remaining")
		body.remove_meta("wind_carry_flying")
		return false
	body.set_meta("wind_carry_remaining", maxf(remaining - delta, 0.0))
	var flying := bool(body.get_meta("wind_carry_flying", false))
	body.velocity.x = move_toward(body.velocity.x, 0.0, CARRY_DRAG * delta)
	if flying:
		body.velocity.y = move_toward(body.velocity.y, 0.0, CARRY_DRAG * delta)
	elif not body.is_on_floor():
		body.velocity += body.get_gravity() * delta
	body.move_and_slide()
	return true
