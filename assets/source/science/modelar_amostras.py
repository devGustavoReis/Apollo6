
import bpy, math, sys
from pathlib import Path
root=Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
 return m
metal=mat('Aluminio escovado',(.43,.46,.47)); lining=mat('Espuma de retencao',(.08,.12,.13))
gold=mat('Fechos',(.45,.33,.14)); rock=mat('Basalto',(.25,.25,.23))
def box(name,size,loc,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 bevel=o.modifiers.new('Bordas','BEVEL');bevel.width=.004;bevel.segments=1
 return o
box('Base',(.52,.34,.04),(0,0,.02),metal)
box('Espuma',(.49,.31,.03),(0,0,.055),lining)
for x in [-.25,.25]:box('Parede',(.02,.34,.12),(x,0,.08),metal)
for y in [-.16,.16]:box('Parede',(.52,.02,.12),(0,y,.08),metal)
lid=box('Tampa aberta',(.52,.025,.32),(0,.17,.25),metal);lid.rotation_euler.x=math.radians(-15)
box('Interior tampa',(.47,.015,.27),(0,.15,.25),lining)
for x in [-.17,.17]:box('Fecho',(.045,.02,.035),(x,-.18,.07),gold)
box('Alca',(.17,.025,.025),(0,-.22,.08),lining)
for x in [-.08,.08]:box('Suporte alca',(.02,.05,.025),(x,-.19,.08),metal)
box('Cabo martelo',(.035,.23,.035),(-.12,0,.1),lining)
box('Cabeca martelo',(.12,.045,.04),(-.12,.09,.1),metal)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.075,location=(.12,.02,.12))
o=bpy.context.object;o.name='Amostra lunar';o.scale=(1,.8,.65);o.data.materials.append(rock)
box('Divisoria',(.018,.29,.07),(0,0,.08),lining)
for y in [-.07,.09]:box('Retencao da amostra',(.19,.012,.012),(.12,y,.145),gold)
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/source/science/amostras.blend'))
dest=root/'assets/models/equipment/sample_case.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_apply=True)
