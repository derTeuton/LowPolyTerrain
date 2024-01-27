@tool
class_name LowPolyTerrain extends MeshInstance3D

signal generate

#region Klassen variablen

#region Export variablen

@export var heightmap_texture : Texture2D:
	set(_value): if not _value == null:
		heightmap_texture = _value
		heightmap_image = _value.get_image()
		if heightmap_image.is_compressed(): heightmap_image.decompress()
		heightmap_height = heightmap_image.get_height()
		heightmap_width = heightmap_image.get_width()
	else: heightmap_texture = _value
#@export var colormap_texture : Texture2D:
	#set(_value):
		#colormap_texture = _value
		#colormap_image = _value.get_image()
		#if colormap_image.is_compressed(): colormap_image.decompress()

@export var generate_button : Button

@export_subgroup("Materials")
@export var seabed_material : Material = preload("res://addons/LowPolyTerrain/materials/seabed_material.tres"):
	set(_value): 
		seabed_material = _value
		self.emit_signal("generate")
@export var ground_material : Material = preload("res://addons/LowPolyTerrain/materials/ground_material.tres"):
	set(_value): 
		ground_material = _value
		self.emit_signal("generate")
@export var mountain_material : Material = preload("res://addons/LowPolyTerrain/materials/mountain_material.tres"):
	set(_value): 
		mountain_material = _value
		self.emit_signal("generate")
@export_subgroup("Settings")
@export var max_height : float = 10.0
@export var terrain_size : Vector2i = Vector2i(150,150):
	set(_value): if _value.x == 0 or _value.y == 0: return
	else:
		terrain_size = _value
		terrain_height = _value.y
		terrain_width = _value.x
@export var sea_level : float = 1.2: # schieberegler
	set(_value): if 0 <= _value and _value <= max_height: sea_level = _value
	elif _value > max_height: sea_level = max_height
	elif _value < 0: sea_level = 0
@export var mountain_gradient : float = 1.1: # schieberegler
	set(_value): if 0 <= _value: mountain_gradient = _value
	elif _value < 0: mountain_gradient = 0

#endregion

#region Interne variablen

var heightmap_image : Image
#var colormap_image : Image
var terrain_height : int
var terrain_width : int
var heightmap_height : int
var heightmap_width : int
var heightmap_one_y : float
var heightmap_one_x : float

#endregion

#endregion

#region Klassen spezifizierung

func _enter_tree(): generate.connect(_on_generate)

func _exit_tree(): generate.disconnect(_on_generate)

func _ready():
	terrain_height = 150
	terrain_width = 150
	heightmap_height = 230
	heightmap_width = 230

#func _get( _property ): if _property == "mesh": return generate_mesh()

func _on_generate(): self.mesh = self.generate_mesh()

#endregion

#region Klassen methoden

func generate_mesh() -> ArrayMesh:
	heightmap_one_x = float(heightmap_width) / float(terrain_width)
	heightmap_one_y = float(heightmap_height) / float(terrain_height)
	
	var terrain_mesh : ArrayMesh = ArrayMesh.new()
	var terrain_seabed_surface : SurfaceTool = SurfaceTool.new()
	var terrain_ground_surface : SurfaceTool = SurfaceTool.new()
	var terrain_mountain_surface : SurfaceTool = SurfaceTool.new()
	var terrain_vertices : Array[PackedVector3Array] = self.get_vertices()
	
	terrain_seabed_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	terrain_ground_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	terrain_mountain_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for _index : int in terrain_vertices.size():
		var triangle_vertices : PackedVector3Array = terrain_vertices[_index]
		var vertices_y_level : PackedFloat32Array = PackedFloat32Array([
			triangle_vertices[0].y,triangle_vertices[1].y,triangle_vertices[2].y])
		vertices_y_level.sort()
		var y_level_top : float = vertices_y_level[-1]
		var y_level_bottom : float = vertices_y_level[0]
		
		if y_level_top < sea_level: handle_surfacetool(
			terrain_seabed_surface,
			terrain_vertices[_index],
			seabed_material )
		
		elif y_level_top - y_level_bottom < mountain_gradient: handle_surfacetool(
			terrain_ground_surface,
			terrain_vertices[_index],
			ground_material )
		
		else: handle_surfacetool(
			terrain_mountain_surface,
			terrain_vertices[_index],
			mountain_material )
	
	terrain_mesh = terrain_seabed_surface.commit(terrain_mesh)
	terrain_mesh = terrain_ground_surface.commit(terrain_mesh)
	terrain_mesh = terrain_mountain_surface.commit(terrain_mesh)
	
	return terrain_mesh

func handle_surfacetool( _surface_tool : SurfaceTool, _vertices : PackedVector3Array, _material : Material ):
	var normal : Vector3 = self.get_normal(_vertices)
	_surface_tool.set_normal(normal)
	_surface_tool.set_material(_material)
	for _idx : int in 3: _surface_tool.add_vertex(_vertices[_idx])

#region Getters

## Erzeugt die Höhe aus der Heightmap am geg. Punkt 
func get_height( _heightmap_position : Vector2i ) -> float:
	var heightmap_position : Vector2i = _heightmap_position
	
	if _heightmap_position.x < 0: heightmap_position.x = 0
	if _heightmap_position.y < 0: heightmap_position.y = 0
	if _heightmap_position.x >= heightmap_width: heightmap_position.x = heightmap_width - 1
	if _heightmap_position.y >= heightmap_height: heightmap_position.y = heightmap_height - 1
	
	var pixel_color : Color = heightmap_image.get_pixelv(heightmap_position)
	var height : float = pixel_color.get_luminance()
	return height

## Erzeugt den Gradienten aus der Heightmap am geg. Punkt 
func get_gradient( _heightmap_position : Vector2i ) -> Vector2:
	var height_x1 : float = get_height(_heightmap_position - Vector2i(1,0))
	var height_x2 : float = get_height(_heightmap_position + Vector2i(1,0))
	var height_y1 : float = get_height(_heightmap_position - Vector2i(0,1))
	var height_y2 : float = get_height(_heightmap_position + Vector2i(0,1))
	
	var derivative_x : float = height_x2 - height_x1
	var derivative_y : float = height_y2 - height_y1
	var derivative : Vector2 = Vector2(derivative_x,derivative_y) / 2
	
	return derivative

## Erzeugt das Interpolationspolynom für die waagrechte Richtung
func interpolated_polynom_x( _local_position_x : float, _heightmap_position : Vector2i ) -> float:
	var start_position : Vector2i = _heightmap_position + Vector2i(0,0)
	var end_position   : Vector2i = _heightmap_position + Vector2i(1,0)
	
	var derivative_x1 : float = get_gradient(start_position).x
	var derivative_x2 : float = get_gradient(end_position).x
	
	var height_x1 : float = get_height(start_position)
	var height_x2 : float = get_height(end_position)
	
	var height_dif : float = height_x2 - height_x1
	
	var coefficient0 : float = height_x1
	var coefficient1 : float = derivative_x1
	var coefficient2 : float = height_dif - derivative_x1
	var coefficient3 : float = derivative_x1 + derivative_x2 - 2 * height_dif
	
	var sum0 : float = coefficient0
	var sum1 : float = coefficient1 * _local_position_x
	var sum2 : float = coefficient2 * _local_position_x * _local_position_x
	var sum3 : float = coefficient3 * _local_position_x * _local_position_x * (_local_position_x - 1)
	
	var interpolated_x : float = sum0 + sum1 + sum2 + sum3
	
	return interpolated_x

## Erzeugt das Interpolationspolynom für die senkrechte Richtung
func interpolated_polynom_y( _local_position_y : float, _heightmap_position : Vector2i ) -> float:
	var start_position : Vector2i = _heightmap_position + Vector2i(0,0)
	var end_position   : Vector2i = _heightmap_position + Vector2i(0,1)
	
	var derivative_y1 : float = get_gradient(start_position).y
	var derivative_y2 : float = get_gradient(end_position).y
	
	var height_y1 : float = get_height(start_position)
	var height_y2 : float = get_height(end_position)
	
	var height_dif : float = height_y2 - height_y1
	
	var coefficient0 : float = height_y1
	var coefficient1 : float = derivative_y1
	var coefficient2 : float = height_dif - derivative_y1
	var coefficient3 : float = derivative_y1 + derivative_y2 - 2 * height_dif
	
	var sum0 : float = coefficient0
	var sum1 : float = coefficient1 * _local_position_y
	var sum2 : float = coefficient2 * _local_position_y * _local_position_y
	var sum3 : float = coefficient3 * _local_position_y * _local_position_y * (_local_position_y - 1)
	
	var interpolated_y : float = sum0 + sum1 + sum2 + sum3
	
	return interpolated_y

## Erzeugt die Interpolierte Höhe
func get_interpolated_height( _terrain_position_x : int, _terrain_position_y : int ) -> float:
	var global_position_x : float = float(heightmap_width  * _terrain_position_x) / float(terrain_width)
	var global_position_y : float = float(heightmap_height * _terrain_position_y) / float(terrain_height)
	
	var heightmap_position : Vector2i = Vector2i(int(global_position_x),int(global_position_y))
	
	var local_position_x : float = global_position_x - heightmap_position.x
	var local_position_y : float = global_position_y - heightmap_position.y
	
	var height_x : float = interpolated_polynom_x(local_position_x,heightmap_position)
	var height_y : float = interpolated_polynom_y(local_position_y,heightmap_position)
	
	return (height_x + height_y) / 2

## Erzeugt den Terrain Vektor für einen geg. Ebenen Punkt
func get_vertex( _terrain_position_x : int, _terrain_position_z : int ) -> Vector3:
	var terrain_position_y : float = self.get_interpolated_height(
		_terrain_position_x,_terrain_position_z) * max_height
	return Vector3(_terrain_position_x,terrain_position_y,_terrain_position_z)

## Erzeugt ein Array aus in dem die Vektoren zu Dreiecken gruppiert sind
func get_vertices() -> Array[PackedVector3Array]:
	var terrain_vertices : PackedVector3Array = []
	var triangle_vertices : Array[PackedVector3Array] = []
	
	for _y : int in terrain_height: for _x : int in terrain_width: 
		terrain_vertices.append(self.get_vertex(_x,_y))
	
	for _index_y : int in terrain_height - 1:
		for _index_x : int in terrain_width - 1:
			var _index1 : int = _index_x + terrain_width * _index_y 
			var _index2 : int = _index_x + terrain_width * _index_y + 1
			var _index3 : int = _index_x + terrain_width * (_index_y + 1)
			var _index4 : int = _index_x + terrain_width * (_index_y + 1) + 1
			
			var vertex1 : Vector3 = terrain_vertices[_index1]
			var vertex2 : Vector3 = terrain_vertices[_index2]
			var vertex3 : Vector3 = terrain_vertices[_index3]
			var vertex4 : Vector3 = terrain_vertices[_index4]
			
			triangle_vertices.append(PackedVector3Array([vertex1, vertex2, vertex3]))
			triangle_vertices.append(PackedVector3Array([vertex4, vertex3, vertex2]))
	
	return triangle_vertices

## Erzeugt die Normale für ein Dreieck
func get_normal( _triangle : PackedVector3Array ) -> Vector3: 
	var side_x : Vector3 = _triangle[1] - _triangle[0]
	var side_y : Vector3 = _triangle[2] - _triangle[0]
	var normal : Vector3 = side_x.cross(side_y)
	
	return normal

#endregion

#endregion
