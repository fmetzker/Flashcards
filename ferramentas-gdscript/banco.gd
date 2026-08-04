extends SceneTree

# Utilitário de linha de comando para o banco de questões do app de concurso.
# Substitui validar.py/equilibra2.py nesta máquina (sem Python e sem Node).
#
#   banco.gd extrair <index.html> <saida.json>
#   banco.gd medir   <index.html>
#   banco.gd aplicar <index.html> <patch.json>   # {"<indice>": {"o":[...], "c":n}, ...}
#   banco.gd validar <index.html> <sw.js>

const CAMPOS := ["a", "t", "q", "o", "c", "e", "f"]
const AREAS := ["lp", "sus", "esp"]

var erros: Array[String] = []
var avisos: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("uso: banco.gd <extrair|medir|aplicar|validar> ...")
		quit(2)
		return
	match args[0]:
		"extrair":
			cmd_extrair(args[1], args[2])
		"medir":
			cmd_medir(args[1])
		"aplicar":
			cmd_aplicar(args[1], args[2])
		"folgas":
			cmd_folgas(args[1], args[2])
		"validar":
			cmd_validar(args[1], args[2])
		_:
			push_error("comando desconhecido: " + args[0])
			quit(2)
			return
	quit(1 if erros.size() > 0 else 0)


# --- leitura -----------------------------------------------------------------

func le_texto(caminho: String) -> String:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		push_error("não abriu: " + caminho)
		quit(2)
		return ""
	return f.get_as_text()


## Devolve [linhas_do_banco, indice_da_linha_de_abertura, todas_as_linhas].
func fatia_banco(fonte: String) -> Array:
	var linhas := fonte.split("\n")
	var ini := -1
	var fim := -1
	for i in linhas.size():
		if ini == -1 and linhas[i].begins_with("const BANCO = ["):
			ini = i
		elif ini != -1 and linhas[i].begins_with("];"):
			fim = i
			break
	if ini == -1 or fim == -1:
		erros.append("array BANCO não encontrado em index.html")
		return [[], -1, linhas]
	var corpo: Array[String] = []
	for i in range(ini + 1, fim):
		var l := linhas[i].strip_edges()
		if l.is_empty():
			continue
		corpo.append(l.trim_suffix(","))
	return [corpo, ini, linhas]


## Converte o literal de objeto JS (chaves sem aspas) em JSON e parseia.
## Faz a varredura respeitando strings, para não tocar em ":" dentro de texto.
func parse_questao(linha: String) -> Dictionary:
	var saida := ""
	var dentro_string := false
	var escapado := false
	var i := 0
	while i < linha.length():
		var c := linha[i]
		if dentro_string:
			saida += c
			if escapado:
				escapado = false
			elif c == "\\":
				escapado = true
			elif c == "\"":
				dentro_string = false
			i += 1
			continue
		if c == "\"":
			dentro_string = true
			saida += c
			i += 1
			continue
		# chave sem aspas: letra logo após "{" ou "," e seguida de ":"
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_":
			var j := i
			while j < linha.length():
				var d := linha[j]
				var alfa := (d >= "a" and d <= "z") or (d >= "A" and d <= "Z") or d == "_" or (d >= "0" and d <= "9")
				if not alfa:
					break
				j += 1
			if j < linha.length() and linha[j] == ":":
				saida += "\"" + linha.substr(i, j - i) + "\""
				i = j
				continue
		saida += c
		i += 1
	var q = JSON.parse_string(saida)
	if q == null or typeof(q) != TYPE_DICTIONARY:
		erros.append("linha não parseável: " + linha.substr(0, 120))
		return {}
	return q


func carrega_banco(caminho: String) -> Array:
	var fonte := le_texto(caminho)
	var fatia := fatia_banco(fonte)
	var banco: Array = []
	for l in fatia[0]:
		var q := parse_questao(l)
		if not q.is_empty():
			banco.append(q)
	return banco


# --- escrita -----------------------------------------------------------------

func serializa_questao(q: Dictionary) -> String:
	var partes: Array[String] = []
	for campo in CAMPOS:
		var v = q[campo]
		if campo == "o":
			var itens: Array[String] = []
			for x in v:
				itens.append(JSON.stringify(x))
			partes.append("o:[" + ",".join(itens) + "]")
		elif campo == "c":
			partes.append("c:" + str(int(v)))
		else:
			partes.append(campo + ":" + JSON.stringify(v))
	return "{" + ",".join(partes) + "}"


func regrava_banco(caminho: String, banco: Array) -> void:
	var fonte := le_texto(caminho)
	var fatia := fatia_banco(fonte)
	if fatia[1] == -1:
		return
	var linhas: PackedStringArray = fatia[2]
	var ini: int = fatia[1]
	var fim := ini
	while fim < linhas.size() and not linhas[fim].begins_with("];"):
		fim += 1
	var corpo: Array[String] = []
	for q in banco:
		corpo.append(serializa_questao(q))
	var novo: Array[String] = []
	for i in ini:
		novo.append(linhas[i])
	novo.append("const BANCO = [")
	novo.append(",\n".join(corpo))
	for i in range(fim, linhas.size()):
		novo.append(linhas[i])
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string("\n".join(novo))
	f.close()


# --- métricas ----------------------------------------------------------------

## Quanto a alternativa correta excede, em caracteres, a maior das demais.
func folga(q: Dictionary) -> int:
	var opcoes: Array = q["o"]
	var c := int(q["c"])
	var maior := 0
	for j in opcoes.size():
		if j != c:
			maior = maxi(maior, String(opcoes[j]).length())
	return String(opcoes[c]).length() - maior


func relatorio(banco: Array) -> void:
	var n := banco.size()
	var mais_longa := 0
	var acima20 := 0
	var acima40 := 0
	for q in banco:
		var d := folga(q)
		if d > 0:
			mais_longa += 1
		if d > 20:
			acima20 += 1
		if d > 40:
			acima40 += 1
	var por_area := {"lp": 0, "sus": 0, "esp": 0}
	for q in banco:
		if por_area.has(q["a"]):
			por_area[q["a"]] += 1
	print("Banco: %d questões  (lp %d · sus %d · esp %d)" % [n, por_area["lp"], por_area["sus"], por_area["esp"]])
	print("Vieses:")
	print("  correta é a mais longa:        %d/%d (%.1f%%)   [ideal ~20%%]" % [mais_longa, n, float(mais_longa) / float(n) * 100.0])
	print("  excede a 2ª maior em >20 char: %d" % acima20)
	print("  excede em >40 char:            %d" % acima40)


# --- comandos ----------------------------------------------------------------

func cmd_extrair(entrada: String, saida: String) -> void:
	var banco := carrega_banco(entrada)
	var f := FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify(banco, "", false))
	f.close()
	print("extraídas %d questões para %s" % [banco.size(), saida])


func cmd_medir(entrada: String) -> void:
	var banco := carrega_banco(entrada)
	relatorio(banco)
	var linhas: Array[String] = []
	for i in banco.size():
		var d := folga(banco[i])
		if d > 20:
			linhas.append("%d\t%d\t%s\t%s" % [i, d, banco[i]["a"], banco[i]["t"]])
	print("\nquestões com folga > 20 (índice, folga, área, tópico): %d" % linhas.size())
	for l in linhas:
		print(l)


func cmd_aplicar(entrada: String, patch_json: String) -> void:
	var banco := carrega_banco(entrada)
	var patch = JSON.parse_string(le_texto(patch_json))
	if patch == null:
		erros.append("patch inválido: " + patch_json)
		return
	var aplicados := 0
	for chave in patch.keys():
		var i := int(chave)
		if i < 0 or i >= banco.size():
			erros.append("índice fora do banco: %d" % i)
			continue
		var novo: Dictionary = patch[chave]
		if novo.has("o"):
			if novo["o"].size() != 5:
				erros.append("[%d] patch não tem 5 alternativas" % i)
				continue
			var limpas: Array = []
			for x in novo["o"]:
				limpas.append(String(x).strip_edges())
			banco[i]["o"] = limpas
		if novo.has("c"):
			banco[i]["c"] = int(novo["c"])
		if novo.has("q"):
			banco[i]["q"] = novo["q"]
		if novo.has("e"):
			banco[i]["e"] = novo["e"]
		aplicados += 1
	if erros.size() > 0:
		return
	regrava_banco(entrada, banco)
	print("patch aplicado a %d questões" % aplicados)
	relatorio(carrega_banco(entrada))


## Confere a folga das questões citadas num patch, para revisar lote a lote.
func cmd_folgas(entrada: String, patch_json: String) -> void:
	var banco := carrega_banco(entrada)
	var patch = JSON.parse_string(le_texto(patch_json))
	var positivas := 0
	var restantes: Array[String] = []
	for chave in patch.keys():
		var i := int(chave)
		var d := folga(banco[i])
		if d > 0:
			positivas += 1
		if d > 10:
			restantes.append("  [%d] folga ainda %d" % [i, d])
	print("lote: %d questões · correta ainda é a mais longa em %d · acima de 10: %d" % [patch.size(), positivas, restantes.size()])
	for r in restantes:
		print(r)


func cmd_validar(entrada: String, sw: String) -> void:
	var banco := carrega_banco(entrada)
	if banco.is_empty():
		return
	var vistos := {}
	var re_fmt := RegEx.create_from_string("(?i)destacad|grifad|sublinhad|em negrito")
	for i in banco.size():
		var q: Dictionary = banco[i]
		for campo in CAMPOS:
			if not q.has(campo):
				erros.append("[%d] campo '%s' ausente" % [i, campo])
		if not AREAS.has(q.get("a", "")):
			erros.append("[%d] área inválida: %s" % [i, str(q.get("a"))])
		var opcoes: Array = q.get("o", [])
		if opcoes.size() != 5:
			erros.append("[%d] não tem exatamente 5 alternativas" % i)
		var c = q.get("c", -1)
		if typeof(c) != TYPE_FLOAT and typeof(c) != TYPE_INT:
			erros.append("[%d] índice da correta inválido: %s" % [i, str(c)])
		elif int(c) < 0 or int(c) > 4:
			erros.append("[%d] índice da correta inválido: %s" % [i, str(c)])
		var unicas := {}
		for x in opcoes:
			unicas[x] = true
		if unicas.size() != opcoes.size():
			erros.append("[%d] alternativas repetidas dentro da questão" % i)
		if String(q.get("f", "")).is_empty():
			erros.append("[%d] sem fonte" % i)
		var enunciado := String(q.get("q", ""))
		if vistos.has(enunciado):
			erros.append("[%d] enunciado duplicado" % i)
		vistos[enunciado] = true
		var texto := enunciado + " ".join(PackedStringArray(opcoes)) + String(q.get("e", ""))
		if re_fmt.search(texto) != null:
			erros.append("[%d] refere-se a formatação que não existe no texto puro" % i)

	var fonte := le_texto(entrada)
	if not fonte.contains("embaralhaOrdem"):
		erros.append("função embaralhaOrdem ausente — o viés de posição da correta volta a valer")
	if not fonte.contains("vr-enf-2026"):
		erros.append("chave de localStorage vr-enf-2026 ausente")
	if not fonte.contains("Chutei"):
		erros.append("botão \"Chutei\" ausente")
	if fonte.contains("http://") or fonte.contains("https://cdn") or fonte.contains("<script src"):
		avisos.append("possível referência externa em index.html — conferir se não é CDN")

	print("")
	relatorio(banco)

	var texto_sw := le_texto(sw)
	var m := RegEx.create_from_string("const VERSAO = \"([^\"]+)\"").search(texto_sw)
	if m == null:
		erros.append("VERSAO não encontrada em sw.js")
	else:
		print("  versão do service worker:      %s" % m.get_string(1))
		avisos.append("confirme que a VERSAO (%s) mudou desde a última publicação" % m.get_string(1))

	print("")
	for a in avisos:
		print("aviso: ", a)
	if erros.size() > 0:
		for e in erros.slice(0, 40):
			print("ERRO: ", e)
		if erros.size() > 40:
			print("... e mais %d erros" % (erros.size() - 40))
		print("\n%d erro(s). Não publicar." % erros.size())
	else:
		print("Sem erros. Pode publicar.")
