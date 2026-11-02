extends Node
## Typed signals for gameplay events shared by otherwise independent scenes.
## Keep persistent run state in Game; this node only distributes notifications.

signal enemy_defeated(world_position: Vector2)
signal pickup_collected(points: int, pickup_type: int)
signal powerup_collected
signal enemy_drop_collected(reward_type: int, magic_element: int, energy_amount: int)
signal relic_collected(relic_id: String)
signal player_hurt
