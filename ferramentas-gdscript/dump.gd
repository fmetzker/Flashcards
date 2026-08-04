extends SceneTree

# Escreve as questões enviesadas em lotes de texto legível, para reescrita manual.
#   dump.gd <banco.json> <dir_saida> <folga_minima> <tamanho_do_lote>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var banco: Array = JSON.parse_string(FileAccess.open(args[0], FileAccess.READ).get_as_text())
	var dir: String = args[1]
	var folga_min := int(args[2])
	var lote := int(args[3])

	var alvos: Array = []
	for i in banco.size():
		var q: Dictionary = banco[i]
		var c := int(q["c"])
		var maior := 0
		for j in q["o"].size():
			if j != c:
				maior = maxi(maior, String(q["o"][j]).length())
		var folga := String(q["o"][c]).length() - maior
		if folga > folga_min:
			alvos.append({"i": i, "folga": folga, "q": q})

	DirAccess.make_dir_recursive_absolute(dir)
	var n_lotes := int(ceil(float(alvos.size()) / float(lote)))
	for l in n_lotes:
		var texto := ""
		for k in range(l * lote, mini((l + 1) * lote, alvos.size())):
			var a: Dictionary = alvos[k]
			var q: Dictionary = a["q"]
			var c := int(q["c"])
			texto += "### %d  [%s / %s]  folga=%d\n" % [a["i"], q["a"], q["t"], a["folga"]]
			texto += "P: %s\n" % q["q"]
			for j in q["o"].size():
				var marca := "*" if j == c else " "
				texto += "%s (%d) %s\n" % [marca, String(q["o"][j]).length(), q["o"][j]]
			texto += "F: %s\n\n" % q["f"]
		var f := FileAccess.open("%s/lote%02d.txt" % [dir, l + 1], FileAccess.WRITE)
		f.store_string(texto)
		f.close()
	print("%d questões em %d lotes" % [alvos.size(), n_lotes])
	quit(0)
