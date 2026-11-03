# Reescreve enunciados preservando o histórico de quem já estudou.
#
#   powershell -ExecutionPolicy Bypass -File reescrever-questoes.ps1
#   powershell -ExecutionPolicy Bypass -File reescrever-questoes.ps1 -DryRun
#
# O PROBLEMA QUE ESTE SCRIPT RESOLVE
#
# O id da questão é o SHA-1 do enunciado (regra 5 do CLAUDE.md). Mudar o
# enunciado muda o id, e o progresso salvo — que é chaveado por id — deixa de
# encontrar a questão: o histórico daquele cartão zera para todo mundo.
#
# Isso torna proibitivo corrigir uma questão mal escrita, que é justamente o
# que a PADRAO-DOS-CARTOES.md manda fazer. A saída é a mesma que a Fase 0 já usou
# para migrar de índice-de-array para id: um MAPA do id velho para o novo,
# aplicado no boot do app (ver migrarReescritas em index.html).
#
# Grava banco/reescritas.json, que o app lê e usa para transportar
# E.cartoes[id_antigo] -> E.cartoes[id_novo] uma única vez por aparelho.
#
# ATENÇÃO: arquivos .ps1 com acentos precisam de UTF-8 COM BOM.

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

function Id-Questao([string]$enunciado) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($enunciado))
  $sha.Dispose()
  (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 10)
}

# ---- o que reescrever --------------------------------------------------------
# id antigo -> campos a trocar. Só 'q' muda o id; 'e', 'o', 'c', 'f' e 'eo'
# podem vir junto. 'eo' que já existir no cartão e não for mencionado aqui é
# preservado automaticamente — só é sobrescrito se a entrada do lote trouxer
# 'eo'.
#
# Este lote tira do enunciado a definição que o próprio cartão cobra
# (PADRAO-DOS-CARTOES.md §1.9.11): com ela ali, basta aplicar o que está
# escrito, sem lembrar o que o termo significa. O id antigo aponta para o novo,
# então quem já estudava o cartão segue com o histórico.

$REESCRITAS = @{
  '5b79ea650a' = @{ q = 'Qual destas palavras é um substantivo epiceno?' }
  '5e907da04e' = @{ q = 'Qual destas palavras é um substantivo deverbal?' }
  'bb11bd8a05' = @{ q = 'Assinale o substantivo deverbal:' }
  'ebc687dce5' = @{ q = 'O adjetivo ''marítimo'' é formado por qual processo?' }
  '46f6dee24e' = @{ q = 'Pela classificação de Spaulding, que processamento exige um artigo crítico?' }
  '30b6b12cfb' = @{ q = 'Um carro foi revendido por R$ 85.680,00, com prejuízo de 16% sobre o valor original. Qual foi o valor original do veículo?' }
}

# ---- o que fundir ------------------------------------------------------------
# id que sai -> id que fica. Para dois cartões que cobram o MESMO exercício,
# com os mesmos números e só o rótulo trocado (PADRAO-DOS-CARTOES.md §1.5 e
# §5.3). O cartão que sai é retirado do banco, e o par entra em
# reescritas.json: quem estudou o que saiu segue com o histórico no que
# fica (migrarReescritas, no index.html, fica com o mais recente se a conta
# respondeu os dois). O id que fica precisa existir no banco.

$FUNDIR = @{
  '987ac9721a' = '83c9849b77'   # torcedores: 23 + 23 + 15 − 6 − 5 = 50
  '9cabb3e314' = 'ba0f491a67'   # convés triangular 8-5-5, área 12 m²
  '161f7c8b41' = '7d830969dd'   # (x² − 4)/(x − 2) = x + 2
}

# ---- aplica ------------------------------------------------------------------

$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$mapa = @{}          # id_antigo -> id_novo
$alterados = 0

# antes de tirar qualquer cartão, confere que o par da fusão existe: um
# destino ausente deixaria o histórico apontando para lugar nenhum
$todos = @{}
foreach ($m in $materias) {
  $arq = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $arq)) { continue }
  foreach ($l in [System.IO.File]::ReadAllLines($arq, [System.Text.Encoding]::UTF8)) {
    $l = $l.Trim().TrimEnd(',')
    if ($l.StartsWith('{')) { $todos[($l | ConvertFrom-Json).id] = $true }
  }
}
foreach ($k in $FUNDIR.Keys) {
  $alvo = $FUNDIR[$k]
  if (-not $todos.ContainsKey($alvo)) { throw "Fusão $k -> $alvo`: o cartão que fica não existe no banco." }
  if ($FUNDIR.ContainsKey($alvo)) { throw "Fusão $k -> $alvo`: o cartão que fica também está marcado para sair." }
}

foreach ($m in $materias) {
  $arq = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $arq)) { continue }
  $linhas = [System.IO.File]::ReadAllLines($arq, [System.Text.Encoding]::UTF8)
  $mudouArquivo = $false
  $sair = @{}          # posições dos cartões fundidos, que saem do arquivo

  for ($i = 0; $i -lt $linhas.Count; $i++) {
    $l = $linhas[$i].Trim().TrimEnd(',')
    if (-not $l.StartsWith('{')) { continue }
    $q = $l | ConvertFrom-Json
    if ($FUNDIR.ContainsKey($q.id)) {
      $mapa[$q.id] = $FUNDIR[$q.id]
      $sair[$i] = $true
      $mudouArquivo = $true
      $alterados++
      Write-Host "  [$($q.id) => $($FUNDIR[$q.id])] $($m.id)/$($q.t) (fundido, sai do banco)"
      continue
    }
    if (-not $REESCRITAS.ContainsKey($q.id)) { continue }

    $novo = $REESCRITAS[$q.id]
    $idAntigo = $q.id

    if ($novo.ContainsKey('q')) { $q.q = $novo.q }
    if ($novo.ContainsKey('e')) { $q.e = $novo.e }
    if ($novo.ContainsKey('o')) { $q.o = $novo.o }
    if ($novo.ContainsKey('c')) { $q.c = $novo.c }
    if ($novo.ContainsKey('f')) { $q.f = $novo.f }
    if ($novo.ContainsKey('eo')) { $q | Add-Member -NotePropertyName eo -NotePropertyValue $novo.eo -Force }

    $idNovo = Id-Questao $q.q
    $q.id = $idNovo
    if ($idAntigo -ne $idNovo) { $mapa[$idAntigo] = $idNovo }

    # regrava na MESMA ordem de campos do banco (ESTRUTURA.md §1), para o
    # diff ficar mínimo
    $obj = [ordered]@{ id = $q.id; m = $q.m; t = $q.t }
    if ($q.PSObject.Properties.Name -contains 's' -and $q.s) { $obj.s = $q.s }
    # sem isto, reescrever um cartão já classificado (campanha da escada de
    # nível, CLAUDE.md "Ordem de aprendizado") apagava o `n` em silêncio —
    # mesmo bug que 'eo' já tinha tido, um campo abaixo
    if ($q.PSObject.Properties.Name -contains 'n' -and $q.n) { $obj.n = [int]$q.n }
    $obj.q = $q.q
    # idem para a figura do enunciado (§1.8 do PADRAO-DOS-CARTOES.md)
    if ($q.PSObject.Properties.Name -contains 'img' -and $q.img) { $obj.img = $q.img; $obj.alt = $q.alt }
    $obj.o = @($q.o); $obj.c = [int]$q.c; $obj.e = $q.e; $obj.f = $q.f
    # sem isto, reescrever um cartão que já tinha 'eo' apagava a explicação
    # por alternativa em silêncio — o rebuild listava só os campos de sempre
    if ($q.PSObject.Properties.Name -contains 'eo' -and $q.eo) { $obj.eo = @($q.eo) }

    $virgula = if ($linhas[$i].TrimEnd().EndsWith(',')) { ',' } else { '' }
    $linhas[$i] = ($obj | ConvertTo-Json -Compress -Depth 5) + $virgula
    $mudouArquivo = $true
    $alterados++
    Write-Host "  [$idAntigo -> $idNovo] $($m.id)/$($q.t)"
  }

  if ($mudouArquivo -and -not $DryRun) {
    # cartão fundido sai; a última linha de cartão não leva vírgula, porque o
    # array JSON fecha logo depois dela
    # pela posição, não por $null: num vetor de texto, $null vira '' e a
    # linha ficaria em branco no arquivo em vez de sair
    $linhas = @(for ($k = 0; $k -lt $linhas.Count; $k++) { if (-not $sair.ContainsKey($k)) { $linhas[$k] } })
    $ultimo = -1
    for ($k = 0; $k -lt $linhas.Count; $k++) { if ($linhas[$k].Trim().StartsWith('{')) { $ultimo = $k } }
    for ($k = 0; $k -lt $linhas.Count; $k++) {
      if (-not $linhas[$k].Trim().StartsWith('{')) { continue }
      $s = $linhas[$k].TrimEnd().TrimEnd(',')
      $linhas[$k] = if ($k -eq $ultimo) { $s } else { $s + ',' }
    }
    [System.IO.File]::WriteAllText($arq, ($linhas -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
}

Write-Host ""
if ($alterados -eq 0) {
  Write-Host "Nenhuma questão do lote encontrada no banco (já reescritas?)."
  return
}

if ($DryRun) {
  Write-Host "DryRun: $alterados questão(ões) seriam reescritas. Nada foi gravado."
  return
}

# ---- acumula o mapa ----------------------------------------------------------
# Nunca sobrescreve: o mapa é histórico. Um aparelho que ficou meses sem abrir
# precisa achar o caminho do id que ele tem até o id atual, mesmo que a questão
# tenha sido reescrita duas vezes.

$arqMapa = Join-Path $dir 'reescritas.json'
$anterior = @{}
if (Test-Path $arqMapa) {
  $j = [System.IO.File]::ReadAllText($arqMapa, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  foreach ($p in $j.PSObject.Properties) { $anterior[$p.Name] = $p.Value }
}
foreach ($k in $mapa.Keys) { $anterior[$k] = $mapa[$k] }

$corpo = ($anterior.Keys | Sort-Object | ForEach-Object {
  '  "' + $_ + '": "' + $anterior[$_] + '"'
}) -join ",`n"
[System.IO.File]::WriteAllText($arqMapa, "{`n$corpo`n}`n", (New-Object System.Text.UTF8Encoding $false))

# ---- acerta o índice legado --------------------------------------------------
# indice-legado.json mapeia a POSIÇÃO no array antigo (pré-Fase 0) para o id.
# Se um id foi reescrito e o índice continuasse apontando para o antigo, quem
# ainda tem progresso naquele formato perderia justamente essas questões na
# migração — o oposto do que este script existe para evitar.

$arqLegado = Join-Path $dir 'indice-legado.json'
if (Test-Path $arqLegado) {
  $legado = [System.IO.File]::ReadAllText($arqLegado, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $trocados = 0
  $novoLegado = $legado | ForEach-Object {
    if ($mapa.ContainsKey($_)) { $trocados++; $mapa[$_] } else { $_ }
  }
  if ($trocados -gt 0) {
    $txt = ($novoLegado | ForEach-Object { '"' + $_ + '"' }) -join ",`n"
    [System.IO.File]::WriteAllText($arqLegado, "[`n$txt`n]`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "indice-legado.json: $trocados id(s) atualizado(s) para o novo enunciado."
  }
}

Write-Host "$alterados questão(ões) reescrita(s)."
Write-Host "banco/reescritas.json com $($anterior.Count) mapeamento(s) no total."
Write-Host ""
Write-Host "Falta: rodar validar.ps1 e dar commit."
