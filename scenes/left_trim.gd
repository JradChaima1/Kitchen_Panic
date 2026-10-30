@tool
extends MeshInstance3D

@export var size := Vector3(0.6, 0.3, 12.3)
@export_range(0.001, 0.1, 0.001) var bevel := 0.03
@export_range(1, 5, 1) var bevel_segments := 3

func _ready() -> void:
	mesh = make_rounded_box(size, bevel, bevel_segments)

func make_rounded_box(box_size: Vector3, radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := box_size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.95)
	segments = maxi(1, segments)

	# Build six gridded faces. Shrinking the core leaves room for the bevel.
	var inner := half - Vector3.ONE * r

	_add_rounded_face(st, Vector3.RIGHT, Vector3.UP, Vector3.BACK, inner, r, segments)
	_add_rounded_face(st, Vector3.LEFT, Vector3.UP, Vector3.FORWARD, inner, r, segments)
	_add_rounded_face(st, Vector3.UP, Vector3.BACK, Vector3.LEFT, inner, r, segments)
	_add_rounded_face(st, Vector3.DOWN, Vector3.FORWARD, Vector3.LEFT, inner, r, segments)
	_add_rounded_face(st, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, inner, r, segments)
	_add_rounded_face(st, Vector3.BACK, Vector3.UP, Vector3.LEFT, inner, r, segments)

	st.generate_normals()
	return st.commit()

func _add_rounded_face(
	st: SurfaceTool,
	normal: Vector3,
	u_axis: Vector3,
	v_axis: Vector3,
	inner: Vector3,
	radius: float,
	segments: int
) -> void:
	var points_per_side := segments + 1
	var grid: Array[Vector3] = []

	for y in range(points_per_side + 1):
		for x in range(points_per_side + 1):
			var u := lerpf(-1.0, 1.0, float(x) / points_per_side)
			var v := lerpf(-1.0, 1.0, float(y) / points_per_side)
			var p := normal * _axis_extent(normal, inner)
			p += u_axis * (u * _axis_extent(u_axis, inner))
			p += v_axis * (v * _axis_extent(v_axis, inner))
			var closest := Vector3(
				clampf(p.x, -inner.x, inner.x),
				clampf(p.y, -inner.y, inner.y),
				clampf(p.z, -inner.z, inner.z)
			)
			grid.append(closest + (p - closest).normalized() * radius)

	for y in range(points_per_side):
		for x in range(points_per_side):
			var i := y * (points_per_side + 1) + x
			var a := grid[i]
			var b := grid[i + 1]
			var c := grid[i + points_per_side + 1]
			var d := grid[i + points_per_side + 2]
			st.set_normal((b - a).cross(c - a).normalized())
			st.add_vertex(a)
			st.set_normal((b - a).cross(c - a).normalized())
			st.add_vertex(b)
			st.set_normal((b - a).cross(c - a).normalized())
			st.add_vertex(c)
			st.set_normal((d - b).cross(c - b).normalized())
			st.add_vertex(b)
			st.set_normal((d - b).cross(c - b).normalized())
			st.add_vertex(d)
			st.set_normal((d - b).cross(c - b).normalized())
			st.add_vertex(c)

func _axis_extent(axis: Vector3, extents: Vector3) -> float:
	if absf(axis.x) > 0.5:
		return extents.x
	if absf(axis.y) > 0.5:
		return extents.y
	return extents.z
