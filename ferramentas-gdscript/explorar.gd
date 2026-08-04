extends SceneTree

# Simula a estratégia do candidato que não sabe o conteúdo e "chuta na mais longa".
# Só conta as questões em que existe UMA alternativa visivelmente mais longa
# (excede a segunda em mais de LIMIAR caracteres). Nas demais a pista não existe.
#   explorar.gd <banco.json> [limiar]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var b: Array = JSON.parse_string(FileAccess.open(args[0], FileAccess.READ).get_as_text())
	var limiar := 10 if args.size() < 2 else int(args[1])

	var com_pista := 0
	var acertos := 0
	for q in b:
		var tam := []
		for j in 5:
			tam.append(String(q["o"][j]).length())
		var maior := -1
		var idx := -1
		for j in 5:
			if tam[j] > maior:
				maior = tam[j]
				idx = j
		var segundo := -1
		for j in 5:
			if j != idx:
				segundo = maxi(segundo, tam[j])
		if maior - segundo > limiar:
			com_pista += 1
			if idx == int(q["c"]):
				acertos += 1
	var n := b.size()
	print("limiar de 'visivelmente mais longa': +%d caracteres" % limiar)
	print("  questões em que a pista existe:   %d/%d (%.1f%%)" % [com_pista, n, float(com_pista) / n * 100.0])
	if com_pista > 0:
		print("  chutando na mais longa, acerta:   %d/%d (%.1f%%)   [acaso = 20%%]" % [acertos, com_pista, float(acertos) / com_pista * 100.0])
	var cobertura := float(acertos) / float(n) * 100.0
	print("  ganho sobre o banco inteiro:      %.1f%% das 852 questões entregues de graça" % cobertura)
	quit(0)
