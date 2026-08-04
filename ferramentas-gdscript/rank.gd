extends SceneTree

# O viés só é explorável se a diferença de comprimento for PERCEPTÍVEL.
# Mede: (a) a que distância a certa fica da alternativa mais longa;
#       (b) a amplitude entre a maior e a menor alternativa de cada questão.
#   rank.gd <banco.json>

func _init() -> void:
	var b: Array = JSON.parse_string(FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ).get_as_text())
	var atras_ate10 := 0      # certa não é a maior, mas fica a <=10 chars da maior
	var atras_11a20 := 0
	var atras_mais20 := 0
	var e_a_maior := 0
	var amplitude_ate20 := 0
	var amplitude_21a40 := 0
	var amplitude_mais40 := 0
	for q in b:
		var c := int(q["c"])
		var n := String(q["o"][c]).length()
		var maior := 0
		var menor := 9999
		for j in 5:
			var t := String(q["o"][j]).length()
			maior = maxi(maior, t)
			menor = mini(menor, t)
		var atraso := maior - n
		if atraso <= 0:
			e_a_maior += 1
		elif atraso <= 10:
			atras_ate10 += 1
		elif atraso <= 20:
			atras_11a20 += 1
		else:
			atras_mais20 += 1
		var amp := maior - menor
		if amp <= 20:
			amplitude_ate20 += 1
		elif amp <= 40:
			amplitude_21a40 += 1
		else:
			amplitude_mais40 += 1
	var n_tot := b.size()
	print("distância da certa até a alternativa mais longa da questão:")
	print("  a certa É a mais longa:        %4d (%.1f%%)" % [e_a_maior, float(e_a_maior) / n_tot * 100.0])
	print("  fica ate 10 chars atras:       %4d (%.1f%%)   <- diferenca imperceptivel" % [atras_ate10, float(atras_ate10) / n_tot * 100.0])
	print("  fica 11 a 20 chars atras:      %4d (%.1f%%)" % [atras_11a20, float(atras_11a20) / n_tot * 100.0])
	print("  fica mais de 20 chars atras:   %4d (%.1f%%)" % [atras_mais20, float(atras_mais20) / n_tot * 100.0])
	print("")
	print("amplitude (maior - menor alternativa) por questão:")
	print("  ate 20 chars:                  %4d (%.1f%%)" % [amplitude_ate20, float(amplitude_ate20) / n_tot * 100.0])
	print("  21 a 40 chars:                 %4d (%.1f%%)" % [amplitude_21a40, float(amplitude_21a40) / n_tot * 100.0])
	print("  mais de 40 chars:              %4d (%.1f%%)" % [amplitude_mais40, float(amplitude_mais40) / n_tot * 100.0])
	quit(0)
