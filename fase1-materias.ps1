# Fase 1 — reagrupa os tópicos em matérias reais e reparte o banco.
#
# Até aqui o banco era dividido em lp / sus / esp. "esp" não é matéria: é "o
# resto da prova do cargo Enfermeiro", justamente a parte que muda de concurso
# para concurso. Não dá para compartilhar "Conhecimentos Específicos" — dá para
# compartilhar "Imunização", "Saúde da Mulher", "Urgência e Emergência".
#
# O campo `a` (área) sai e entra `m` (matéria). O id da questão NÃO muda: ele
# deriva do enunciado, então nenhum progresso é perdido.
#
# Lê:    banco/lp.json, banco/sus.json, banco/esp.json
# Grava: banco/materias.json e um banco/<materia>.json por matéria
# Apaga: os três arquivos de área
#
# ATENÇÃO ao editar: .ps1 com acento precisa ser gravado em UTF-8 COM BOM.

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

# Cada matéria é uma unidade que reaparece em editais diferentes — é o que
# permite duas pessoas em concursos distintos estudarem o mesmo acervo.
# A ordem aqui é a ordem em que as matérias aparecem no app.
$MATERIAS = [ordered]@{
  'portugues'      = @{ nome = 'Língua Portuguesa' }
  'sus-legislacao' = @{ nome = 'Legislação do SUS' }
  'sus-politicas'  = @{ nome = 'Políticas Nacionais de Saúde' }
  'urgencia'       = @{ nome = 'Urgência, Emergência e Terapia Intensiva' }
  'transmissiveis' = @{ nome = 'Doenças Transmissíveis' }
  'imunizacao'     = @{ nome = 'Imunização' }
  'fundamentos'    = @{ nome = 'Fundamentos e Procedimentos de Enfermagem' }
  'mulher'         = @{ nome = 'Saúde da Mulher' }
  'adulto-idoso'   = @{ nome = 'Saúde do Adulto e do Idoso' }
  'crianca'        = @{ nome = 'Saúde da Criança e do Adolescente' }
  'infeccao'       = @{ nome = 'Controle de Infecção e Segurança do Paciente' }
  'vigilancia'     = @{ nome = 'Vigilância em Saúde' }
  'medicamentos'   = @{ nome = 'Farmacologia e Medicamentos' }
  'cirurgica'      = @{ nome = 'Centro Cirúrgico e CME' }
  'mental'         = @{ nome = 'Saúde Mental' }
  'etica'          = @{ nome = 'Ética e Exercício Profissional' }
  'anatomia'       = @{ nome = 'Anatomia e Fisiologia' }
  'sae'            = @{ nome = 'Processo de Enfermagem e Registros' }
  'trabalhador'    = @{ nome = 'Saúde do Trabalhador' }
  'domiciliar'     = @{ nome = 'Atenção Domiciliar' }
}

# tópico -> matéria. Todo tópico do banco precisa estar aqui; o script falha se
# aparecer um tópico não mapeado, o que é o que se quer quando o banco crescer.
$DE_TOPICO = @{
  # Português: um único bloco de edital, não vale fatiar
  'Figuras de linguagem'='portugues'; 'Classes de palavras'='portugues'
  'Coesão'='portugues'; 'Semântica'='portugues'; 'Pontuação'='portugues'
  'Ortografia'='portugues'; 'Concordância'='portugues'
  'Interpretação de textos'='portugues'; 'Subordinação'='portugues'
  'Regência'='portugues'; 'Acentuação'='portugues'; 'Crase'='portugues'
  'Gêneros textuais'='portugues'; 'Colocação pronominal'='portugues'
  'Reescrita'='portugues'; 'Tipologia textual'='portugues'
  'Coordenação e subordinação'='portugues'; 'Pronomes'='portugues'
  'Sintaxe'='portugues'; 'Coordenação'='portugues'; 'Ambiguidade'='portugues'
  'Coerência'='portugues'; 'Intertextualidade'='portugues'

  # a lei e a estrutura do SUS
  'Lei 8.080/90'='sus-legislacao'; 'Lei 8.142/90'='sus-legislacao'
  'Constituição Federal'='sus-legislacao'; 'Organização do SUS'='sus-legislacao'
  'Controle social'='sus-legislacao'

  # as políticas, que muitos editais listam em bloco separado
  'PNAB'='sus-politicas'; 'PNH'='sus-politicas'; 'PNAU'='sus-politicas'
  'Rede Alyne'='sus-politicas'; 'Transferência inter-hospitalar'='sus-politicas'

  'Urgência e emergência'='urgencia'; 'UTI'='urgencia'

  'Tuberculose'='transmissiveis'; 'Hanseníase'='transmissiveis'
  'IST'='transmissiveis'; 'Sífilis'='transmissiveis'
  'Hepatites virais'='transmissiveis'; 'Arboviroses'='transmissiveis'
  'Meningite'='transmissiveis'; 'Influenza'='transmissiveis'
  'Tétano'='transmissiveis'; 'Sarampo'='transmissiveis'
  'Raiva'='transmissiveis'; 'Covid-19'='transmissiveis'
  'Varicela'='transmissiveis'; 'Toxoplasmose'='transmissiveis'
  'Rubéola'='transmissiveis'; 'Poliomielite'='transmissiveis'
  'Malária'='transmissiveis'; 'Leptospirose'='transmissiveis'
  'Leishmaniose'='transmissiveis'; 'Febre maculosa'='transmissiveis'
  'Doença de Chagas'='transmissiveis'; 'Esquistossomose'='transmissiveis'
  'Escabiose'='transmissiveis'; 'Difteria'='transmissiveis'
  'Coqueluche'='transmissiveis'

  'Imunização'='imunizacao'

  'Procedimentos'='fundamentos'; 'Feridas'='fundamentos'; 'Estomias'='fundamentos'

  'Saúde da mulher'='mulher'

  'DANT'='adulto-idoso'; 'Saúde do idoso'='adulto-idoso'
  'Saúde do homem'='adulto-idoso'; 'Reabilitação'='adulto-idoso'

  'Saúde da criança'='crianca'; 'Saúde do adolescente'='crianca'

  'Controle de infecção'='infeccao'; 'Segurança do paciente'='infeccao'

  'Vigilância epidemiológica'='vigilancia'; 'Vigilância sanitária'='vigilancia'
  'Vigilância ambiental'='vigilancia'

  'Medicamentos'='medicamentos'
  'Centro cirúrgico e CME'='cirurgica'
  'Saúde mental'='mental'
  'Ética profissional'='etica'
  'Anatomia e fisiologia'='anatomia'
  'Processo de enfermagem'='sae'; 'Registros de enfermagem'='sae'
  'Saúde do trabalhador'='trabalhador'
  'Atenção domiciliar'='domiciliar'
}

# ---- carrega -----------------------------------------------------------------

$B = @()
foreach ($a in 'lp','sus','esp') {
  $arq = Join-Path $dir "$a.json"
  if (-not (Test-Path $arq)) { throw "banco/$a.json não encontrado — a Fase 1 já foi aplicada?" }
  $B += [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}
Write-Host "questões lidas: $($B.Count)"

# ---- confere o mapeamento antes de gravar qualquer coisa ---------------------

$naoMapeados = @($B | Where-Object { -not $DE_TOPICO.ContainsKey($_.t) } | ForEach-Object { $_.t } | Sort-Object -Unique)
if ($naoMapeados) {
  $naoMapeados | ForEach-Object { Write-Host "ERRO: tópico sem matéria: '$_'" }
  throw "$($naoMapeados.Count) tópico(s) sem matéria. Nada foi gravado."
}
$destinosInvalidos = @($DE_TOPICO.Values | Sort-Object -Unique | Where-Object { -not $MATERIAS.Contains($_) })
if ($destinosInvalidos) { throw "matéria inexistente no mapa: $($destinosInvalidos -join ', ')" }

# ---- grava -------------------------------------------------------------------

$saida = [ordered]@{}
foreach ($k in $MATERIAS.Keys) { $saida[$k] = New-Object System.Collections.ArrayList }

foreach ($q in $B) {
  $m = $DE_TOPICO[$q.t]
  # `a` sai, `m` entra; o id continua o mesmo porque deriva do enunciado
  [void]$saida[$m].Add([pscustomobject]@{
    id = $q.id; m = $m; t = $q.t; q = $q.q; o = $q.o; c = $q.c; e = $q.e; f = $q.f
  })
}

$total = 0
$lista = @()
foreach ($k in $MATERIAS.Keys) {
  $sel = $saida[$k]
  if ($sel.Count -eq 0) { throw "matéria '$k' ficou sem nenhuma questão" }
  $corpo = ($sel | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }) -join ",`n"
  [System.IO.File]::WriteAllText((Join-Path $dir "$k.json"), "[`n$corpo`n]`n", (New-Object System.Text.UTF8Encoding $false))
  Write-Host ("  banco/{0,-16} {1,4} questões  {2}" -f "$k.json", $sel.Count, $MATERIAS[$k].nome)
  $total += $sel.Count
  $lista += [pscustomobject]@{ id = $k; nome = $MATERIAS[$k].nome }
}
if ($total -ne $B.Count) { throw "soma das matérias ($total) difere do banco ($($B.Count))" }

$corpoM = ($lista | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 3 }) -join ",`n"
[System.IO.File]::WriteAllText((Join-Path $dir 'materias.json'), "[`n$corpoM`n]`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "  banco/materias.json — $($lista.Count) matérias"

foreach ($a in 'lp','sus','esp') { Remove-Item (Join-Path $dir "$a.json") -Force }
Write-Host "  removidos banco/lp.json, banco/sus.json, banco/esp.json"
Write-Host "`ntotal conferido: $total questões"
