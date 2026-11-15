"""Create a metric, editable Blender cabin and export Godot modules as GLB."""
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
project = Path(args[0])
prototype = "prototype" in args[1:]
reexport = "reexport" in args[1:]
out = project / "assets/models/cabin"
out.mkdir(parents=True, exist_ok=True)
(out.parent / 'landing').mkdir(parents=True, exist_ok=True)
if not reexport:
    bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
if not reexport:
    scene.name = 'Peças editáveis'
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
collections = {}
palette = {}

for name, color, roughness, metal, emission in [
    ("Ivory","BCBAA9",.77,0,0), ("Liner","949E98",.82,0,0),
    ("Putty","9D937B",.86,0,0), ("Slate","485C62",.82,0,0),
    ("Ink","202B2B",.79,0,0), ("Edge","667874",.62,.20,0),
    ("Metal","C2C5B7",.49,.38,0), ("Bolt","737C74",.54,.26,0),
    ("Trim","D1A962",.59,.12,0), ("Black","12201E",.61,0,0),
    ("Olive","727F73",.91,0,0), ("Binding","9BA78E",.92,0,0),
    ("Webbing","B3A589",.94,0,0), ("Red","B6563F",.76,0,0),
    ("Paper","E8DBB9",.88,0,0), ("Green","A4E9A6",.55,0,.62),
    ("Amber","FFC473",.53,0,.38), ("Lamp","F9DFB1",.59,0,.52),
    ("FlagRed","A83243",.94,0,0), ("FlagWhite","ECE6D9",.9,0,0),
    ("FlagBlue","274361",.92,0,0),
]:
    if reexport:
        break
    rgb = [channel / 255 for channel in bytes.fromhex(color)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear,1)
    mat.use_nodes=True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value=mat.diffuse_color
    node.inputs["Metallic"].default_value=metal
    node.inputs["Roughness"].default_value=roughness
    node.inputs["Emission Color"].default_value=mat.diffuse_color
    node.inputs["Emission Strength"].default_value=emission
    palette[name]=mat


def group(name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    collections[name] = col
    return col


def mesh(col,name,vertices,polygons,material,bevel=0):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],polygons)
    data.update()
    obj=bpy.data.objects.new(name,data)
    col.objects.link(obj)
    data.materials.append(palette[material])
    if bevel:
        edge=obj.modifiers.new("Chanfro","BEVEL")
        edge.width=bevel
        edge.segments=2
    return obj


def box(col,name,at,dims,material,bevel=0,axes=None):
    u,v,w=map(Vector,axes or ((1,0,0),(0,1,0),(0,0,1)))
    x,y,z=(d/2 for d in dims)
    p=Vector(at)
    verts=[p+sx*x*u+sy*y*v+sz*z*w for sx,sy,sz in
           [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return mesh(col,name,verts,faces,material,bevel)


def rod(col,name,a,b,radius,mat,sides=10):
    a,b=Vector(a),Vector(b)
    w=(b-a).normalized()
    u=w.cross((0,0,1) if abs(w.z)<.9 else (1,0,0)).normalized()
    v=w.cross(u)
    perimeter=[radius*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)]
    faces=[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return mesh(col,name,[p+d for p in (a,b) for d in perimeter],faces,mat)


FRONT_RIGHT=Vector((-1,0,0))
UP=Vector((0,0,1))


# Compact geometric lettering with the same low-resolution vocabulary as the HUD.
GLYPHS = {
    "A":"0e11111f111111","B":"1e11111e11111e","C":"0e11101010110e","D":"1e11111111111e",
    "E":"1f10101e10101f","F":"1f10101e101010","G":"0e11101711110f","H":"1111111f111111",
    "I":"0e04040404040e","J":"0702020212120c","K":"11121418141211","L":"1010101010101f",
    "M":"111b1515111111","N":"11191513111111","O":"0e11111111110e","P":"1e11111e101010",
    "Q":"0e11111115120d","R":"1e11111e141211","S":"0f10100e01011e","T":"1f040404040404",
    "U":"1111111111110e","V":"11111111110a04","W":"11111115151b11","X":"11110a040a1111",
    "Y":"11110a04040404","Z":"1f01020408101f","0":"0e11131519110e","1":"040c040404040e",
    "2":"0e11010204081f","3":"1e01010601011e","4":"02060a121f0202","5":"1f10101e01011e",
    "6":"0608101e11110e","7":"1f010204080808","8":"0e11110e11110e","9":"0e11110f01020c",
    "-":"0000001f000000","/":"01010204081010"," ":"00000000000000",
}


def inscription(col,label,at,size,mat="Paper",right=FRONT_RIGHT,up=UP,center=False):
    px=size/7
    origin=Vector(at)
    if center:
        origin-=right*((len(label)*6-1)*px*.5)
    verts, faces = [], []
    for i,char in enumerate(label.upper()):
        rows=bytes.fromhex(GLYPHS[char])
        for row,mask in enumerate(rows):
            x=0
            while x<5:
                if not mask & (16>>x):
                    x+=1
                    continue
                start=x
                while x<5 and mask & (16>>x):
                    x+=1
                l,r=(i*6+start)*px,(i*6+x)*px
                b,t=(6-row)*px,(7-row)*px
                idx=len(verts)
                verts.extend(origin+right*u+up*v for u,v in ((l,b),(r,b),(r,t),(l,t)))
                faces.append((idx,idx+1,idx+2,idx+3))
    return mesh(col,label,verts,faces,mat)


def face(col,name,x,z,w,h,mat,y,depth=.008,bevel=.003):
    box(col,name,(x,y,z),(w,depth,h),mat,bevel)


def bolt(col,x,z,y,r=.004):
    rod(col,"Fixação",(x,y-.003,z),(x,y,z),r,"Bolt",8)
    face(col,"Fenda",x,z,r*1.2,.001,"Ink",y+.001,.001,0)


def lamp(col,x,z,y,mat):
    face(col,"Aro do indicador",x,z,.02,.015,"Black",y)
    face(col,"Lente",x,z,.012,.008,mat,y+.005,.003)


def knob(col,x,z,y,r):
    rod(col,"Aro",(x,y-.004,z),(x,y+.009,z),r*1.18,"Metal",16)
    rod(col,"Seletor",(x,y+.008,z),(x,y+.024,z),r,"Slate",16)
    face(col,"Posição",x,z+r*.32,.004,r,"Paper",y+.025,.001,0)


def gauge(col,x,z,y,r,angle):
    rod(col,"Aro do instrumento",(x,y-.005,z),(x,y+.008,z),r,"Edge",20)
    rod(col,"Fundo do instrumento",(x,y+.007,z),(x,y+.009,z),r*.86,"Black",20)
    for i in range(9):
        t=math.radians(-135+i*33.75)
        u,v=math.sin(t),math.cos(t)
        rod(col,"Graduação",(x+r*.65*u,y+.011,z+r*.65*v),(x+r*.78*u,y+.011,z+r*.78*v),.0015,"Paper",5)
    rod(col,"Agulha",(x,y+.012,z),(x+r*.63*math.sin(angle),y+.012,z+r*.63*math.cos(angle)),.002,"Amber",6)


def display(col,x,z,w,h,y,lines):
    face(col,"Moldura chanfrada",x,z,w,h,"Edge",y,.018,.006)
    face(col,"Máscara",x,z,w-.010,h-.009,"Black",y+.009,.004)
    for idx,(text,mat) in enumerate(lines):
        inscription(col,text,(x,y+.012,z+h*.19-idx*h/(len(lines)+2)),min(h*.79/(len(lines)+2),w/(max(1,len(text))*.89)),mat,center=True)


def keys(col,x,z,y,labels,dx,dz):
    for row,values in enumerate(labels):
        for column,value in enumerate(values):
            px,pz=x-column*dx,z-row*dz
            kind="Trim" if value in ("ENT","CLR") else "Edge"
            face(col,"Tecla "+value,px,pz,dx*.80,dz*.77,kind,y,.012,.004)
            inscription(col,value,(px,y+.007,pz-dz*.175),min(.014,dz*.48),
                        "Ink" if kind=="Trim" else "Paper",center=True)


def unit(name,title,w,h,d):
    col=group(name)
    face(col,"Caixa principal",0,h*.5,w-.015,h-.012,"Slate",0,d-.019,.012)
    face(col,"Guarnição",0,h*.5,w-.024,h-.021,"Metal",d*.5-.016,.010,.007)
    face(col,"Espelho do painel",0,h*.5,w-.042,h-.037,"Ink",d*.5-.010,.009,.004)
    face(col,"Faixa de identificação",0,h-.055,w-.088,.042,"Slate",d*.5-.003,.003)
    inscription(col,title,(0,d*.5,h-.068),.030,center=True)
    for x in (-w/2+.025,w/2-.025):
        for z in (.026,h-.026):
            bolt(col,x,z,d*.5-.002)
    return col


def console():
    col=group("main_console")
    box(col,"Gabinete inferior",(0,-.13,-.325),(2.27,.22,.643),"Slate",.026)
    for x in (-.76,0,.76):
        box(col,"Tampa de baia",(x,-.014,-.29),(.71,.013,.46),"Liner",.009)
        box(col,"Faixa de numeração",(x,-.004,-.224),(.43,.006,.026),"Slate",.004)
        rod(col,"Puxador",(x-.067,-.004,-.337),(x+.067,-.004,-.337),.009,"Metal")
    box(col,"Estrutura de comando",(0,-.015,.214),(2.385,.45,.424),"Slate",.026)
    box(col,"Quebra-luz",(0,.05,.425),(2.36,.31,.033),"Ink",.009)
    for x,label in [(.791,"FLIGHT CONTROL"),(0,"COMMAND CONSOLE"),(-.791,"SYSTEM STATUS")]:
        face(col,"Cassete",x,.217,.744,.356,"Edge",.217,.027,.014)
        face(col,"Máscara",x,.216,.707,.322,"Ink",.231,.012,.008)
        face(col,"Faixa gravada",x,.369,.665,.038,"Slate",.238)
        inscription(col,label,(x,.243,.354),.032,center=True)
        bolt(col,x-.332,.075,.241,.005)
        bolt(col,x+.332,.075,.241,.005)
    for i,x in enumerate((.57,.79,1.01)):
        gauge(col,x,.236,.239,.075,.21+i*.34)
    display(col,0,.25,.50,.133,.239,[("APOLLO 6","Green"),("COMMAND MODULE","Paper")])
    keys(col,.164,.138,.24,[["MODE","SEL","TEST","CLR"]],.109,.040)
    for x,title in [(-.55,"GUID"),(-.71,"COMM"),(-.865,"PWR"),(-1.02,"ECS")]:
        lamp(col,x,.276,.241,"Green")
        inscription(col,title,(x,.245,.23),.026,center=True)
        knob(col,x,.147,.24,.024)
    for x in (-1.09,-.95,-.81,-.67,-.53,.56,.70,.84,.98,1.12):
        face(col,"Base da chave",x,.079,.040,.031,"Slate",.24)
        rod(col,"Alavanca",(x,.244,.073),(x,.263,.090),.005,"Metal",8)
    return col


def nav():
    col=unit("nav_panel","NAVIGATION",.55,.32,.15)
    display(col,.101,.175,.235,.143,.078,[("VERB     NOUN","Paper"),("--        --","Green"),("GUIDANCE","Green")])
    keys(col,-.020,.217,.079,[["7","8","9"],["4","5","6"],["1","2","3"],["CLR","0","ENT"]],.059,.042)
    for x,mat in ((.196,"Green"),(.156,"Amber"),(.116,"Green")):
        lamp(col,x,.066,.078,mat)
    inscription(col,"DSKY",(.215,.083,.026),.021)
    return col


def radio():
    col=unit("radio_panel","RADIO",.55,.32,.15)
    display(col,.102,.194,.22,.101,.078,[("S-BAND / VHF","Paper"),("COMMS","Amber")])
    for i in range(9):
        face(col,"Fenda da grade",.196-i*.022,.107,.011,.051,"Slate",.080,.003,.001)
    knob(col,-.078,.141,.078,.046)
    knob(col,-.187,.140,.078,.030)
    for x,title,mat in ((.188,"RX","Green"),(.108,"TX","Amber")):
        lamp(col,x,.054,.078,mat)
        inscription(col,title,(x-.019,.084,.048),.018)
    for x,title in ((-.078,"GAIN"),(-.187,"BAND")):
        inscription(col,title,(x,.079,.062),.021,center=True)
    return col


def side_panel(name,life):
    col=unit(name,"LIFE SUPPORT" if life else "POWER",.55,.65,.38)
    y=.188
    for x,title in [( .113,"PRESS" if life else "MAIN"),(-.106,"FLOW" if life else "AUX")]:
        gauge(col,x,.445,y,.074,.52 if x>0 else -.64)
        inscription(col,title,(x,y+.009,.340),.026,center=True)
    if life:
        knob(col,.086,.233,y,.050)
        knob(col,-.094,.233,y,.042)
        face(col,"Proteção da válvula",.086,.132,.12,.029,"Trim",y+.017)
        inscription(col,"LiOH",(-.094,y+.009,.127),.024,center=True)
    else:
        for i in range(6):
            for z in (.247,.181):
                x=.176-i*.070
                face(col,"Disjuntor",x,z,.048,.047,"Edge",y)
                rod(col,"Alavanca do circuito",(x,y,z),(x,y+.025,z+.013),.006,"Paper")
    for i in range(4):
        lamp(col,.164-i*.067,.086,y,"Amber" if i==3 else "Green")
    return col


def seat():
    col=group("crew_seat")
    for x in (-.226,.226):
        box(col,"Trilho",(x,0,.034),(.077,.82,.060),"Edge",.014)
        for y in (-.336,.336):
            rod(col,"Montante",(x,y,.052),(x,y*.91,.421),.022,"Metal",12)
        rod(col,"Diagonal",(x,.30,.07),(x,-.30,.416),.015,"Bolt")
        rod(col,"Longarina",(x,-.34,.414),(x,.37,.414),.030,"Edge",12)
        rod(col,"Tubo traseiro",(x,-.29,.408),(x,-.434,.943),.028,"Metal",12)
        box(col,"Apoio lateral",(x,.064,.523),(.086,.46,.102),"Olive",.035)
    box(col,"Concha inferior",(0,.012,.416),(.484,.70,.063),"Slate",.019)
    box(col,"Estofamento inferior",(0,.037,.478),(.413,.61,.117),"Olive",.039)
    for x in (-.171,.171):
        box(col,"Vivo da almofada",(x,.039,.530),(.012,.526,.009),"Binding",.004)
    lean=math.radians(14)
    axes=((1,0,0),(0,math.cos(lean),math.sin(lean)),(0,-math.sin(lean),math.cos(lean)))
    box(col,"Concha traseira",(0,-.351,.675),(.486,.102,.548),"Slate",.030,axes)
    box(col,"Almofada dorsal",(0,-.288,.684),(.406,.115,.467),"Olive",.040,axes)
    box(col,"Apoio de cabeça",(0,-.352,.937),(.285,.114,.143),"Olive",.037,axes)
    for x in (-.12,.12):
        box(col,"Cinto",(x,-.225,.698),(.046,.014,.343),"Webbing",.004,axes)
        box(col,"Ancoragem do cinto",(x,-.277,.888),(.066,.036,.053),"Trim",.005,axes)
    box(col,"Fivela",(0,-.135,.546),(.089,.061,.018),"Metal",.006)
    box(col,"Destrave",(0,-.137,.558),(.031,.029,.009),"Red",.004)
    return col


def godot_vec(point):
    x,y,z = point
    return Vector((x,-z,y))


def floats(value):
    return [float(n) for n in value.split(",")]


def cabin_parts():
    source = (project / "scenes/spacecraft_interior.tscn").read_text(encoding="utf-8")
    blocks = re.split(r"(?m)(?=^\[(?:node|sub_resource|ext_resource) )", source)
    sizes = {}
    walls = []
    slots = {}
    for block in blocks:
        if block.startswith('[sub_resource type="BoxMesh"'):
            identifier = re.search(r'id="([^"]+)"',block)[1]
            dims = re.search(r'size = Vector3\(([^)]+)\)',block)
            if dims:
                sizes[identifier] = floats(dims[1])
        if block.startswith('[node '):
            match = re.search(r'transform = Transform3D\(([^)]+)\)',block)
            if not match:
                continue
            values = floats(match[1])
            axes = [godot_vec(values[i:i+3]) for i in (0,3,6)]
            name = re.search(r'name="([^"]+)"',block)[1]
            p = godot_vec(values[9:12])
            if 'parent="CabinStructure/Walls"' in block:
                identifier = re.search(r'mesh = SubResource\("([^"]+)"\)',block)[1]
                walls.append((name,p,axes,sizes[identifier]))
            if 'parent="EquipmentSlots"' in block:
                slots[name] = (p, axes)
    return walls, slots


def badge(col, p, u, v, width, country):
    u, v = Vector(u), Vector(v)
    n = u.cross(v)
    p = Vector(p)
    h=width/1.9
    box(col,"Placa de identificação",p,(width+.028,h+.026,.014),"Ink",.005,(u,v,n))
    if not country:
        box(col,"Plaqueta da missão",p+n*.008,(width,h,.003),"Slate",.001,(u,v,n))
        inscription(col,"APOLLO 6",p+n*.011-v*h*.15,width*.135,"Paper",u,v,True)
        return
    for stripe in range(13):
        box(col,"Listra",p+n*.009+v*(h*.5-(stripe+.5)*h/13),
            (width,h/13,.003),"FlagRed" if stripe%2==0 else "FlagWhite",0,(u,v,n))
    union_w, union_h = width*.40,h*7/13
    origin=p-u*(width*.5-union_w*.5)+v*(h*.5-union_h*.5)+n*.011
    box(col,"Campo azul",origin,(union_w,union_h,.003),"FlagBlue",0,(u,v,n))
    for j in range(9):
        count=6 if j%2==0 else 5
        for i in range(count):
            c=origin+u*((i-(count-1)*.5)*union_w/6)+v*((4-j)*union_h/9)+n*.002
            pts=[c]
            for k in range(10):
                a=math.tau*k/10
                rad=h*.031*(1 if k%2==0 else .40)
                pts.append(c + rad*(-math.sin(a)*u+math.cos(a)*v))
            mesh(col,"Estrela",pts,[(0,k+1,(k+1)%10+1) for k in range(10)],"FlagWhite")


def wall_details(wall_parts):
    col=group("cabin_wall_panels")
    for name,p,(u,v,n),(w,h,d) in wall_parts:
        if w < .16 or h < .17:
            continue
        inner=p+n*(d*.5)
        count=max(1,math.ceil(w/.75))
        width=w/count
        for i in range(count):
            q=inner+u*((i+.5)*width-w*.5)
            pw=width-.026
            ph=h-.045
            box(col,"Chapa "+name,q+n*.014,(pw,ph,.026),
                ("Putty" if i%2 and h>.7 else "Ivory") if h>.6 else "Liner",.010,(u,v,n))
            if ph > .58:
                box(col,"Tampa embutida",q+n*.030+v*ph*.12,(pw-.074,ph*.66,.012),
                    "Liner",.010,(u,v,n))
                box(col,"Placa estreita",q+n*.039+v*ph*.355,(pw-.105,.061,.009),
                    "Slate",.005,(u,v,n))
                for side in (-1,1):
                    for top in (-1,1):
                        c=q+u*side*(pw*.5-.025)+v*top*(ph*.5-.030)
                        rod(col,"Fixação de parede",c+n*.027,c+n*.035,.008,"Bolt",7)
    return col


def deck():
    col=group("cabin_deck_panels")
    for x in (-1.12,0,1.12):
        for y in (-1.03,-.32,.39,1.03):
            box(col,"Módulo do piso",(x,y,.002), (1.088,.608,.009),
                "Slate" if x == 0 else "Edge",.004)
            for side in (-1,1):
                box(col,"Arremate do piso",(x+side*.48,y,.008),(.016,.568,.003),"Bolt",.001)
    for x in (-.568,.568):
        for y in (-.34,.39,1.04):
            box(col,"Referência do corredor",(x,y,.008),(.025,.19,.003),"Trim",.001)
    return col


def roof():
    col=group("cabin_roof_trim")
    perimeter=[(-1.35,1.9),(1.35,1.9),(2,1.25),(2,-1.25),
               (1.35,-1.9),(-1.35,-1.9),(-2,-1.25),(-2,1.25)]
    for i,a in enumerate(perimeter):
        b=perimeter[(i+1)%len(perimeter)]
        base_a=Vector((*a,1.65))
        base_b=Vector((*b,1.65))
        tip_a=Vector((a[0]*.78,a[1]*.78,2.60))
        tip_b=Vector((b[0]*.78,b[1]*.78,2.60))
        u=(base_b-base_a).normalized()
        v=((tip_a+tip_b)-(base_a+base_b)).normalized()
        n=u.cross(v)
        mid=(base_a+base_b+tip_a+tip_b)*.25+n*.023
        w=(base_b-base_a).length*.72
        box(col,"Painel do teto",mid,(w,.47,.031),"Liner" if i%2 else "Ivory",.013,(u,v,n))
        if i%2==0:
            box(col,"Canal da luminária",mid+n*.027,(w*.62,.073,.035),"Edge",.007,(u,v,n))
            box(col,"Difusor da luminária",mid+n*.047,(w*.56,.038,.013),"Lamp",.005,(u,v,n))
        else:
            box(col,"Travessa do teto",mid+n*.025,(w*.46,.052,.024),"Slate",.006,(u,v,n))
    for x in (-.97,.97):
        box(col,"Base da estação",(x,1.615,1.825),(.29,.177,.20),"Slate",.012)
        for dx in (-.095,.095):
            rod(col,"Apoio da estação",(x+dx,1.533,1.743),(x+dx,1.772,1.762),.015,"Metal")
    return col


def hatch():
    col=group("cabin_hatch_trim")
    y=-.60
    for x in (-.504,.504):
        box(col,"Flange longitudinal",(x,y,2.579),(.124,1.18,.040),"Slate",.008)
        box(col,"Faixa longitudinal",(x,y,2.555),(.045,.98,.008),"Trim",.003)
        for offset in (-.43,-.23,0,.23,.43):
            rod(col,"Fixação da escotilha",(x,y+offset,2.557),(x,y+offset,2.545),.013,"Bolt")
    for y2 in (y-.555,y+.555):
        box(col,"Flange transversal",(0,y2,2.579),(.89,.13,.040),"Slate",.008)
        for x in (-.36,-.22,.22,.36):
            face=box(col,"Marca de acesso",(x,y2,2.556),(.067,.049,.007),"Trim",.002)

    return col


def markings():
    col=group("cabin_markings")
    badge(col,(.70,1.49,.56),Vector((1,0,0)),UP,.244,True)
    badge(col,(-.73,1.49,.56),Vector((1,0,0)),UP,.26,False)
    badge(col,(.76,-1.775,1.35),FRONT_RIGHT,UP,.34,True)
    badge(col,(-.76,-1.775,1.35),FRONT_RIGHT,UP,.32,False)
    for suffix, x in [("01",-.85),("02",0),("03",.85)]:
        inscription(col,suffix,(x,-1.780,.21),.085,"Edge",FRONT_RIGHT,UP,True)
    return col


def lunar_flag():
    col=group("lunar_flag")
    width=.72
    height=width/1.9
    upper=.98

    def fabric(u,v,offset=0):
        return (.011+width*u,
                -u*.060*math.sin(u*9+v*2.5)-offset,
                upper-height*v-u*u*v*.063)

    def cloth(x0,x1,y0,y1,mat,n,m,offset=0):
        points=[fabric(x0+(x1-x0)*i/n,y0+(y1-y0)*j/m,offset)
                for j in range(m+1) for i in range(n+1)]
        faces=[(j*(n+1)+i,j*(n+1)+i+n+1,j*(n+1)+i+n+2,j*(n+1)+i+1)
               for j in range(m) for i in range(n)]
        mesh(col,"Tecido com dobras fixas",points,faces,mat)

    for stripe in range(13):
        start=.4 if stripe<7 else 0
        cloth(start,1,stripe/13,(stripe+1)/13,"FlagRed" if stripe%2==0 else "FlagWhite",24,2)
    cloth(0,.4,0,7/13,"FlagBlue",16,12)
    for row in range(9):
        count=6 if row%2==0 else 5
        for i in range(count):
            u=.20+(i-(count-1)/2)*.4/6
            v=(row+.5)*(7/13)/9
            for offset in (-.0015,.0015):
                vertices=[fabric(u,v,offset)]
                for k in range(10):
                    a=math.tau*k/10
                    rad=.031*(1 if k%2==0 else .4)
                    vertices.append(fabric(u+rad*height/width*math.sin(a),v-rad*math.cos(a),offset))
                mesh(col,"Estrela",vertices,[(0,k+1,(k+1)%10+1) for k in range(10)],"FlagWhite")
    for mat in ("FlagRed","FlagWhite","FlagBlue"):
        palette[mat].use_backface_culling=False
    rod(col,"Mastro",(0,0,0),(0,0,1),.010,"Metal")
    rod(col,"Travessa",(0,0,.988),(.741,0,.988),.007,"Metal")
    return col


def export(col):
    deps=bpy.context.evaluated_depsgraph_get()
    verts, faces, mats, indices = [], [], [], []
    for obj in col.objects:
        evaluated=obj.evaluated_get(deps)
        data=evaluated.to_mesh()
        if not data or not data.polygons:
            continue
        material_slot=data.materials[0]
        if material_slot not in mats:
            mats.append(material_slot)
        idx=mats.index(material_slot)
        offset=len(verts)
        verts.extend(obj.matrix_world @ v.co for v in data.vertices)
        faces.extend(tuple(offset+k for k in poly.vertices) for poly in data.polygons)
        indices.extend([idx]*len(data.polygons))
        evaluated.to_mesh_clear()
    data=bpy.data.meshes.new(col.name)
    data.from_pydata(verts,[],faces)
    data.update()
    model=bpy.data.objects.new(col.name,data)
    scene.collection.objects.link(model)
    for mat in mats:
        data.materials.append(mat)
    uv_layer=data.uv_layers.new(name="UVMap")
    for polygon,idx in zip(data.polygons,indices):
        polygon.material_index=idx
        axes=sorted(range(3),key=lambda i: abs(polygon.normal[i]))[:2]
        for loop_index in polygon.loop_indices:
            point=data.vertices[data.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv=(point[axes[0]],point[axes[1]])
    bpy.ops.object.select_all(action="DESELECT")
    model.select_set(True)
    bpy.context.view_layer.objects.active=model
    result=bpy.ops.export_scene.gltf(
        filepath=str((out.parent/"landing" if col.name=="lunar_flag" else out)/(col.name+".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_animations=False,
        export_attributes=False)
    assert result=={"FINISHED"}, result
    bpy.data.objects.remove(model,do_unlink=True)
    bpy.data.meshes.remove(data)


def review_scene(slots):
    review=bpy.data.scenes.new("Cabine montada")
    review.world=bpy.data.worlds.new("Estúdio")
    review.world.use_nodes=True
    review.world.node_tree.nodes.get("Background").inputs["Color"].default_value=(.19,.21,.23,1)
    review.world.node_tree.nodes.get("Background").inputs["Strength"].default_value=.36
    review.render.resolution_x,review.render.resolution_y=1280,720
    review.render.resolution_percentage=100
    mapping={"main_console":["MainConsole"],"nav_panel":["NavigationPanel"],
             "radio_panel":["RadioPanel"],"power_panel":["PowerPanel"],"life_support":["LifeSupport"],
             "crew_seat":["SeatLeft","SeatCenter","SeatRight"]}
    for key,col in collections.items():
        if key == 'lunar_flag':
            continue
        for slot in mapping.get(key,[None]):
            inst=bpy.data.objects.new(slot or key,None)
            inst.instance_type="COLLECTION"
            inst.instance_collection=col
            if slot in slots:
                p,(x,y,z)=slots[slot]
                inst.matrix_world=Matrix((x,-z,y)).transposed().to_4x4()
                inst.location=p
            review.collection.objects.link(inst)
    for at,target,watts,size in [((0,-1.04,2.12),(0,1,.8),105,1.8),
                                  ((.7,.3,2.2),(0,0,.7),52,1.15),((-.6,1.1,1.7),(0,-1,1),34,1.8)]:
        lamp=bpy.data.lights.new("Luz de revisão","AREA")
        lamp.energy=watts
        lamp.size=size
        ob=bpy.data.objects.new(lamp.name,lamp)
        review.collection.objects.link(ob)
        ob.location=at
        ob.rotation_euler=(Vector(target)-ob.location).to_track_quat("-Z","Y").to_euler()
    camera=bpy.data.objects.new("Corredor",bpy.data.cameras.new("Corredor"))
    camera.location=(.12,-1.64,1.54)
    camera.rotation_euler=(Vector((0,1.37,1.16))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.lens=28
    camera.data.clip_start=.04
    review.collection.objects.link(camera)
    review.camera=camera
    return review


if reexport:
    work = bpy.data.scenes["Peças editáveis"]
    bpy.context.window.scene = work
    scene = work
    names = (
        "main_console", "nav_panel", "radio_panel", "power_panel", "life_support",
        "crew_seat", "cabin_wall_panels", "cabin_deck_panels", "cabin_roof_trim",
        "cabin_hatch_trim", "cabin_markings", "lunar_flag",
    )
    for name in names:
        export(bpy.data.collections[name])
else:

    wall_parts, slots=cabin_parts()
    nav()
    seat()
    wall_details(wall_parts)
    if not prototype:
        console()
        radio()
        side_panel("power_panel",False)
        side_panel("life_support",True)
        deck()
        roof()
        hatch()
        markings()
        lunar_flag()

    for collection in collections.values():
        export(collection)

    review=review_scene(slots)
    bpy.context.window.scene=review
    if not prototype:
        source_folder=project/"assets/source/cabin"
        source_folder.mkdir(parents=True,exist_ok=True)
        (source_folder/".gdignore").write_text("",encoding="utf-8")
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(source_folder/"apollo6_cabine.blend"),compress=True)
