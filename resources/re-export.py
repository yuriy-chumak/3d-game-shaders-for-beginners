import bpy
import os
import glob

import sys
argv = sys.argv
argv = argv[argv.index("--") + 1:] # get all args after "--"

# Clear scene
context = bpy.context
scene = context.scene

# Cleanup
for c in bpy.data.objects:
	bpy.data.objects.remove(c)
for collection in bpy.data.collections:
	bpy.data.collections.remove(collection)

# Model directory/files
model_dir = argv[0] + "/OBJ"
model_files = glob.glob(model_dir + "/*.obj")

# Reprocess obj files
for f in model_files:
	name = os.path.basename(os.path.splitext(f)[0]).rsplit(".", 1)[0]
	print(name)
	bpy.ops.import_scene.obj(filepath=f
		,axis_forward='-Z', axis_up='Y')

	patch = "patches/" + name + ".py"
	if os.path.exists(patch):
		exec(compile(open(patch).read(), "", 'exec'))

	bpy.ops.export_scene.obj(filepath=f
		,use_triangles=True
		,use_vertex_groups=False
		,use_blen_objects=True
		,axis_forward='Y', axis_up='Z')
	for item in bpy.data.objects:
		bpy.data.objects.remove(item)
