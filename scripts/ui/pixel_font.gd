extends RefCounted
## Fonte de pixels 5×7 do menu, montada em tempo de execução a partir da tabela abaixo.
## Só tem maiúsculas: as minúsculas usam o mesmo desenho. Peça tamanhos múltiplos de SIZE
## (use px()) para os pixels ficarem inteiros.
##
## Cada letra tem 7 linhas separadas por espaço ("#" = pixel aceso). Uma 8ª e uma 9ª linha
## descem abaixo da base. Os acentos ocupam as duas linhas acima da letra.

const SIZE := 11        ## altura da célula: 2 de acento + 7 de letra + 2 abaixo da base
const ASCENT := 9
const ATLAS_COLUMNS := 16
const CELL := Vector2i(6, 12)

const GLYPHS := {
	"A": ".###. #...# #...# ##### #...# #...# #...#",
	"B": "####. #...# #...# ####. #...# #...# ####.",
	"C": ".###. #...# #.... #.... #.... #...# .###.",
	"D": "####. #...# #...# #...# #...# #...# ####.",
	"E": "##### #.... #.... ####. #.... #.... #####",
	"F": "##### #.... #.... ####. #.... #.... #....",
	"G": ".###. #...# #.... #.### #...# #...# .###.",
	"H": "#...# #...# #...# ##### #...# #...# #...#",
	"I": "### .#. .#. .#. .#. .#. ###",
	"J": "..### ...#. ...#. ...#. ...#. #..#. .##..",
	"K": "#...# #..#. #.#.. ##... #.#.. #..#. #...#",
	"L": "#.... #.... #.... #.... #.... #.... #####",
	"M": "#...# ##.## #.#.# #.#.# #...# #...# #...#",
	"N": "#...# #...# ##..# #.#.# #..## #...# #...#",
	"O": ".###. #...# #...# #...# #...# #...# .###.",
	"P": "####. #...# #...# ####. #.... #.... #....",
	"Q": ".###. #...# #...# #...# #.#.# #..#. .##.#",
	"R": "####. #...# #...# ####. #.#.. #..#. #...#",
	"S": ".#### #.... #.... .###. ....# ....# ####.",
	"T": "##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
	"U": "#...# #...# #...# #...# #...# #...# .###.",
	"V": "#...# #...# #...# #...# #...# .#.#. ..#..",
	"W": "#...# #...# #...# #.#.# #.#.# ##.## #...#",
	"X": "#...# #...# .#.#. ..#.. .#.#. #...# #...#",
	"Y": "#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..",
	"Z": "##### ....# ...#. ..#.. .#... #.... #####",
	"0": ".###. #...# #..## #.#.# ##..# #...# .###.",
	"1": "..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.",
	"2": ".###. #...# ....# ...#. ..#.. .#... #####",
	"3": "####. ....# ....# .###. ....# ....# ####.",
	"4": "...#. ..##. .#.#. #..#. ##### ...#. ...#.",
	"5": "##### #.... ####. ....# ....# #...# .###.",
	"6": ".###. #.... #.... ####. #...# #...# .###.",
	"7": "##### ....# ...#. ..#.. ..#.. ..#.. ..#..",
	"8": ".###. #...# #...# .###. #...# #...# .###.",
	"9": ".###. #...# #...# .#### ....# ....# .###.",
	".": ". . . . . . #",
	",": ".. .. .. .. .. .. .# #.",
	":": ". . # . . # .",
	";": ".. .. .# .. .. .. .# #.",
	"!": "# # # # # . #",
	"?": ".###. #...# ....# ...#. ..#.. ..... ..#..",
	"-": "... ... ... ### ... ... ...",
	"—": "..... ..... ..... ##### ..... ..... .....",
	"_": "..... ..... ..... ..... ..... ..... #####",
	"+": "..... ..#.. ..#.. ##### ..#.. ..#.. .....",
	"=": "..... ..... ##### ..... ##### ..... .....",
	"/": "....# ....# ...#. ..#.. .#... #.... #....",
	"(": ".# #. #. #. #. #. .#",
	")": "#. .# .# .# .# .# #.",
	"%": "##..# ##.#. ...#. ..#.. .#... .#.## #..##",
	"$": "..#.. .#### #.#.. .###. ..#.# ####. ..#..",
	"&": ".##.. #..#. #.#.. .#... #.#.# #..#. .##.#",
	"'": "# # . . . . .",
	"\"": "#.# #.# ... ... ... ... ...",
	"°": ".#. #.# .#. ... ... ... ...",
	"·": ".. .. .. ## ## .. ..",
	"•": "... ... ### ### ### ... ...",
	"<": "...# ..#. .#.. #... .#.. ..#. ...#",
	">": "#... .#.. ..#. ...# ..#. .#.. #...",
	"◀": "...# ..## .### #### .### ..## ...#",
	"▶": "#... ##.. ###. #### ###. ##.. #...",
}

const ACCENTS := {
	"acute": "...#. ..#..",
	"grave": ".#... ..#..",
	"circumflex": "..#.. .#.#.",
	"tilde": ".#..# #.##.",
}

## Letra acentuada: [letra base, acento]. A cedilha é desenhada abaixo da base.
const ACCENTED := {
	"Á": ["A", "acute"], "À": ["A", "grave"], "Â": ["A", "circumflex"], "Ã": ["A", "tilde"],
	"É": ["E", "acute"], "Ê": ["E", "circumflex"], "Í": ["I", "acute"],
	"Ó": ["O", "acute"], "Ô": ["O", "circumflex"], "Õ": ["O", "tilde"], "Ú": ["U", "acute"],
}
const CEDILLA := "..#.. .##.."

static var _font: FontFile


## Tamanho de fonte que amplia cada pixel `zoom` vezes.
static func px(zoom: int) -> int:
	return SIZE * zoom


static func get_font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font


static func _build() -> FontFile:
	var shapes := {}  # caractere → linhas da célula, de cima para baixo
	for key in GLYPHS:
		shapes[key] = ["", ""] + Array(GLYPHS[key].split(" "))
	for key in ACCENTED:
		var rows: Array = shapes[ACCENTED[key][0]].duplicate()
		var accent: PackedStringArray = ACCENTS[ACCENTED[key][1]].split(" ")
		var width: int = rows[2].length()
		for i in 2:
			rows[i] = accent[i].substr(int((5 - width) * 0.5), width)
		shapes[key] = rows
	shapes["Ç"] = shapes["C"] + Array(CEDILLA.split(" "))

	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.generate_mipmaps = false
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.fixed_size = SIZE
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var cache := Vector2i(SIZE, 0)
	font.set_cache_ascent(0, SIZE, ASCENT)
	font.set_cache_descent(0, SIZE, SIZE - ASCENT)
	var image := Image.create(ATLAS_COLUMNS * CELL.x, ceili(float(shapes.size()) / ATLAS_COLUMNS) * CELL.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var index := 0
	for key in shapes:
		var rows: Array = shapes[key]
		var origin := Vector2i(index % ATLAS_COLUMNS, floori(float(index) / ATLAS_COLUMNS)) * CELL
		var width := 0
		for y in rows.size():
			var row: String = rows[y]
			width = maxi(width, row.length())
			for x in row.length():
				if row[x] == "#":
					image.set_pixel(origin.x + x, origin.y + y, Color.WHITE)
		var codes := [key.unicode_at(0)]
		var lower: String = key.to_lower()
		if lower != key:
			codes.append(lower.unicode_at(0))
		for code in codes:
			font.set_glyph_advance(0, SIZE, code, Vector2(width + 1, 0))
			font.set_glyph_offset(0, cache, code, Vector2(0, -ASCENT))
			font.set_glyph_size(0, cache, code, Vector2(width, SIZE))
			font.set_glyph_uv_rect(0, cache, code, Rect2(origin.x, origin.y, width, SIZE))
			font.set_glyph_texture_idx(0, cache, code, 0)
		index += 1
	var space := " ".unicode_at(0)
	font.set_glyph_advance(0, SIZE, space, Vector2(4, 0))
	font.set_glyph_size(0, cache, space, Vector2.ZERO)
	font.set_glyph_uv_rect(0, cache, space, Rect2())
	font.set_glyph_texture_idx(0, cache, space, 0)
	font.set_texture_image(0, cache, 0, image)
	# Caracteres fora da tabela caem na fonte do sistema.
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "monospace"])
	font.fallbacks = [fallback]
	return font
