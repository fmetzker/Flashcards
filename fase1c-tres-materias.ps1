# Fase 1c — as matérias passam a ser as três do edital.
#
# A Fase 1 tratou "Imunização", "Saúde da Mulher" etc. como matérias. Pela
# leitura do edital, matéria é o bloco da prova: Português, Legislação do SUS e
# Conhecimentos Específicos de Enfermagem. O que era matéria vira TÓPICO, e o
# que era tópico vira SUBTÓPICO.
#
#   m = matéria  (3)
#   t = tópico   (50)
#   s = subtópico (114, só onde há subdivisão — Português e SUS não têm)
#
# O id continua sendo o SHA-1 do enunciado: nada de progresso se perde.
#
# Lê:    os 20 arquivos de matéria da Fase 1
# Grava: banco/portugues.json, banco/sus.json, banco/enfermagem.json
#        e o novo banco/materias.json
#
# ATENÇÃO ao editar: .ps1 com acento precisa ser gravado em UTF-8 COM BOM.

$ErrorActionPreference = 'Stop'
$dir = Join-Path $PSScriptRoot 'banco'

$MATERIAS = [ordered]@{
  'portugues'  = 'Língua Portuguesa'
  'sus'        = 'Legislação do SUS'
  'enfermagem' = 'Conhecimentos Específicos de Enfermagem'
}

# antiga matéria -> nova matéria + nome do tópico.
# Onde o tópico é $null, o `t` atual é mantido e não há subtópico: é o caso de
# Português e do SUS, que já estavam no nível certo.
$DE = [ordered]@{
  'portugues'      = @('portugues',  $null)
  'sus-legislacao' = @('sus',        $null)
  'sus-politicas'  = @('sus',        $null)
  'urgencia'       = @('enfermagem', 'Urgência, Emergência e Terapia Intensiva')
  'transmissiveis' = @('enfermagem', 'Doenças Transmissíveis')
  'imunizacao'     = @('enfermagem', 'Imunização')
  'fundamentos'    = @('enfermagem', 'Fundamentos e Procedimentos de Enfermagem')
  'mulher'         = @('enfermagem', 'Saúde da Mulher')
  'adulto-idoso'   = @('enfermagem', 'Saúde do Adulto e do Idoso')
  'crianca'        = @('enfermagem', 'Saúde da Criança e do Adolescente')
  'infeccao'       = @('enfermagem', 'Controle de Infecção e Segurança do Paciente')
  'vigilancia'     = @('enfermagem', 'Vigilância em Saúde')
  'medicamentos'   = @('enfermagem', 'Farmacologia e Medicamentos')
  'cirurgica'      = @('enfermagem', 'Centro Cirúrgico e CME')
  'mental'         = @('enfermagem', 'Saúde Mental')
  'etica'          = @('enfermagem', 'Ética e Exercício Profissional')
  'anatomia'       = @('enfermagem', 'Anatomia e Fisiologia')
  'sae'            = @('enfermagem', 'Processo de Enfermagem e Registros')
  'trabalhador'    = @('enfermagem', 'Saúde do Trabalhador')
  'domiciliar'     = @('enfermagem', 'Atenção Domiciliar')
}

# ---- carrega e converte ------------------------------------------------------

$saida = [ordered]@{}
foreach ($k in $MATERIAS.Keys) { $saida[$k] = New-Object System.Collections.ArrayList }
$lidas = 0

foreach ($antiga in $DE.Keys) {
  $arq = Join-Path $dir "$antiga.json"
  if (-not (Test-Path $arq)) { throw "banco/$antiga.json não encontrado — a Fase 1c já foi aplicada?" }
  $qs = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $lidas += $qs.Count

  $novaMateria = $DE[$antiga][0]
  $novoTopico  = $DE[$antiga][1]

  # uma antiga matéria com um único tópico não ganha subtópico: o segundo nível
  # seria uma cópia do primeiro
  # o @() é obrigatório: sem ele, um único grupo devolve o tamanho do grupo
  # em vez de 1, e a matéria ganha um subtópico que é cópia do tópico
  $distintos = @($qs | Group-Object t).Count
  $temSub = $novoTopico -and $distintos -gt 1

  foreach ($q in $qs) {
    $obj = [ordered]@{ id = $q.id; m = $novaMateria }
    if ($novoTopico) { $obj['t'] = $novoTopico } else { $obj['t'] = $q.t }
    if ($temSub)     { $obj['s'] = $q.t }
    $obj['q'] = $q.q; $obj['o'] = $q.o; $obj['c'] = $q.c; $obj['e'] = $q.e; $obj['f'] = $q.f
    [void]$saida[$novaMateria].Add([pscustomobject]$obj)
  }
}

# ---- confere -----------------------------------------------------------------

$total = ($saida.Keys | ForEach-Object { $saida[$_].Count } | Measure-Object -Sum).Sum
if ($total -ne $lidas) { throw "soma final ($total) difere do lido ($lidas)" }

# ---- grava -------------------------------------------------------------------

$lista = @()
foreach ($k in $MATERIAS.Keys) {
  $sel = $saida[$k]
  $corpo = ($sel | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }) -join ",`n"
  [System.IO.File]::WriteAllText((Join-Path $dir "$k.json"), "[`n$corpo`n]`n", (New-Object System.Text.UTF8Encoding $false))

  $tops = $sel | Group-Object t | Sort-Object Count -Descending
  $nsub = ($sel | Where-Object { $_.s } | Group-Object s).Count
  Write-Host ("`n{0}  —  {1} questões · {2} tópicos · {3} subtópicos" -f $MATERIAS[$k], $sel.Count, @($tops).Count, $nsub)
  foreach ($t in $tops) {
    $subs = ($t.Group | Where-Object { $_.s } | Group-Object s)
    $marca = if (@($subs).Count -gt 0) { "$(@($subs).Count) sub" } else { "" }
    Write-Host ("  {0,4}  {1}  {2}" -f $t.Count, $t.Name, $marca)
  }
  $lista += [pscustomobject]@{ id = $k; nome = $MATERIAS[$k] }
}

$corpoM = ($lista | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 3 }) -join ",`n"
[System.IO.File]::WriteAllText((Join-Path $dir 'materias.json'), "[`n$corpoM`n]`n", (New-Object System.Text.UTF8Encoding $false))

foreach ($antiga in $DE.Keys) {
  if ($MATERIAS.Contains($antiga)) { continue }   # portugues e sus foram sobrescritos
  Remove-Item (Join-Path $dir "$antiga.json") -Force
}

Write-Host "`ntotal conferido: $total questões em 3 matérias"
