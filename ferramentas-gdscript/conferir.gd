extends SceneTree

# Confere que a alternativa CORRETA continua idêntica à do banco original,
# em todas as questões — a regra é reescrever distratores, nunca a resposta certa.
#   conferir.gd <banco_original.json> <banco_final.json>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var a: Array = JSON.parse_string(FileAccess.open(args[0], FileAccess.READ).get_as_text())
	var b: Array = JSON.parse_string(FileAccess.open(args[1], FileAccess.READ).get_as_text())

	if a.size() != b.size():
		print("ERRO: tamanhos diferentes: %d vs %d" % [a.size(), b.size()])
		quit(1)
		return

	var alteradas := 0
	var corretas_mudadas: Array[String] = []
	var enunciados_mudados := 0
	var fontes_mudadas := 0
	var explic_mudadas := 0
	var distratores_reescritos := 0

	for i in a.size():
		var qa: Dictionary = a[i]
		var qb: Dictionary = b[i]
		var certa_a := String(qa["o"][int(qa["c"])])
		var certa_b := String(qb["o"][int(qb["c"])])
		if certa_a != certa_b:
			corretas_mudadas.append("[%d]\n    antes: %s\n    depois: %s" % [i, certa_a, certa_b])
		if String(qa["q"]) != String(qb["q"]):
			enunciados_mudados += 1
		if String(qa["f"]) != String(qb["f"]):
			fontes_mudadas += 1
		if String(qa["e"]) != String(qb["e"]):
			explic_mudadas += 1
		# distratores
		var da := []
		var db := []
		for j in 5:
			if j != int(qa["c"]):
				da.append(qa["o"][j])
			if j != int(qb["c"]):
				db.append(qb["o"][j])
		da.sort()
		db.sort()
		if da != db:
			alteradas += 1
			distratores_reescritos += 1

	print("questões no banco:                    %d" % a.size())
	print("questões com distratores reescritos:  %d" % distratores_reescritos)
	print("enunciados alterados:                 %d   (esperado 0)" % enunciados_mudados)
	print("explicações alteradas:                %d   (esperado 0)" % explic_mudadas)
	print("fontes alteradas:                     %d   (esperado 0)" % fontes_mudadas)
	print("RESPOSTAS CORRETAS alteradas:         %d   (esperado 0)" % corretas_mudadas.size())
	for c in corretas_mudadas.slice(0, 15):
		print("  ", c)
	quit(1 if corretas_mudadas.size() > 0 or enunciados_mudados > 0 or fontes_mudadas > 0 else 0)
