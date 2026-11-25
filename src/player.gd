extends RefCounted
## The digger: a box that the world moves, plus the timers play reads.

var x := 0.0
var y := 0.0
var w := 10.0
var h := 15.0
var vx := 0.0
var vy := 0.0
var on_ground := false
var hit_x := 0
var hit_y := 0
var dir := 1        ## facing: 1 right, -1 left
var hp := 100.0
var safe := 0.0     ## seconds left unhurtable after a hit
var knock := 0.0    ## seconds left being thrown back, when the keys do not steer
var walk := 0.0     ## walk cycle position
var swing := 0.0    ## seconds left of the tool's swing pose
var cool := 0.0     ## seconds until the next swing


func rect() -> Rect2:
	return Rect2(x, y, w, h)


func centre() -> Vector2:
	return Vector2(x + w / 2, y + h / 2)
