extends Node
## Typed signals for gameplay events shared by otherwise independent scenes.
## Keep persistent run state in Game; this node only distributes notifications.

@warning_ignore("unused_signal")
signal enemy_defeated(world_position: Vector2)
@warning_ignore("unused_signal")
signal pickup_collected(points: int, pickup_type: int)
@warning_ignore("unused_signal")
signal powerup_collected
@warning_ignore("unused_signal")
signal enemy_drop_collected(reward_type: int, magic_element: int, energy_amount: int)
@warning_ignore("unused_signal")
signal relic_collected(relic_id: String)
@warning_ignore("unused_signal")
signal player_hurt
