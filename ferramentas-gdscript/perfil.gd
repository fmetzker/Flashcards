extends SceneTree

# Quantos distratores são MAIS LONGOS que a resposta certa, por questão.
# Se a maioria das questões tivesse exatamente um, isso seria um novo padrão
# explorável; o desejável é uma distribuição espalhada.
#   perfil.gd <banco.json>

func _init() -> void:
	var b: Array = JSON.parse_string(FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ).get_as_text())
	var hist := [0, 0, 0, 0, 0]
	var posicao := [0, 0, 0, 0, 0]
	for q in b:
		var c := int(q["c"])
		var n_certa := String(q["o"][c]).length()
		var maiores := 0
		for j in 5:
			if j != c and String(q["o"][j]).length() > n_certa:
				maiores += 1
		hist[maiores] += 1
		posicao[maiores] += 0
	print("distratores mais longos que a resposta certa:")
	for k in 5:
		var rotulo := "%d distrator(es) maior(es)" % k
		print("  %-28s %4d questões (%.1f%%)" % [rotulo, hist[k], float(hist[k]) / float(b.size()) * 100.0])
	quit(0)
