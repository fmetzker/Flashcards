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
# Este lote aplica o PADRAO-DOS-CARTOES.md §1.9.5 a Máquinas Elétricas:
# enunciados que diziam "o Franchi" ou "a apostila" passam a perguntar pelo
# fato, e a fonte continua no 'f'. Vêm junto as notas por alternativa
# genéricas ou repetidas (§1.9.3).

$REESCRITAS = @{
  '2f3e643ac7' = @{
    q = 'No teste de polaridade, com as bobinas 1 e 2 em série recebendo 220 V e uma lâmpada na bobina 3, a lâmpada acendeu. O que isso indica?'
  }
  '7a0345e55c' = @{
    q = 'Por que, em algumas máquinas, se desacopla o motor antes de testar o sentido de giro?'
    eo = @('Correta: o risco é danificar o equipamento.', 'Errada: o motor parte com carga normalmente.', 'Errada: não é medição de rotação.', 'Errada: o relé térmico não sofre com o sentido de giro.', 'Errada: a razão é a segurança do equipamento.')
  }
  '76169d574c' = @{
    q = 'Pela regra prática, o que acontece com a vida útil do isolamento a cada 10 °C acima do limite da classe?'
    eo = @('Correta: metade a cada 10 °C.', 'Errada: a perda é bem maior que 10%.', 'Errada: a degradação é gradual e começa antes da queima.', 'Errada: o calor degrada, não reforça.', 'Errada: a degradação é gradual; a vida útil não zera de uma vez.')
  }
  'd90c9a7dc8' = @{
    q = 'Em que situação se desaconselha o uso de motofreio?'
    eo = @('Correta: contaminação do freio.', 'Errada: ponte rolante e elevador são aplicações típicas do motofreio.', 'Errada: parada precisa é justamente o que o motofreio oferece.', 'Errada: correia transportadora é outra aplicação típica.', 'Errada: a potência não é o critério citado.')
  }
  '017ea5edf7' = @{
    q = 'Qual é o fator de potência mínimo exigido pela ANEEL?'
  }
  'dfa4b29133' = @{
    q = 'Qual é a localização de capacitores mais eficaz tecnicamente?'
  }
  '4b24d76a42' = @{
    q = 'Em que tipo de motor se desaconselha instalar capacitor de correção individual?'
    eo = @('Correta: reversão.', 'Errada: bomba em regime contínuo, sem reversão, é caso adequado.', 'Errada: ventilador sem reversão nem partidas frequentes é caso adequado.', 'Errada: o problema seria o motor de MAIS de uma velocidade.', 'Errada: o problema é o excesso de partidas, não poucas.')
  }
  '4e96d00ee7' = @{
    q = 'Quantos watts vale 1 cv?'
    eo = @('Correta: 736.', 'Errada: 746 é o hp.', 'Errada: é o kW.', 'Errada: 860 é o fator de kW para kcal/h, outra conversão.', 'Errada: 550 é o hp em ft·lbf/s, não em watts.')
  }
  'a7a3a6761a' = @{
    q = 'Num caso real, a chave 110/220 V de um transformador foi ligada invertida e a saída deu o dobro. Como o ohmímetro teria mostrado o erro antes?'
    eo = @('Correta: leitura invertida.', 'Errada: as posições dão valores diferentes.', 'Errada: infinito seria bobina aberta.', 'Errada: zero seria curto.', 'Errada: as duas posições dão resistências diferentes, e a inversão aparece.')
  }
}

# ---- aplica ------------------------------------------------------------------

$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$mapa = @{}          # id_antigo -> id_novo
$alterados = 0

foreach ($m in $materias) {
  $arq = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $arq)) { continue }
  $linhas = [System.IO.File]::ReadAllLines($arq, [System.Text.Encoding]::UTF8)
  $mudouArquivo = $false

  for ($i = 0; $i -lt $linhas.Count; $i++) {
    $l = $linhas[$i].Trim().TrimEnd(',')
    if (-not $l.StartsWith('{')) { continue }
    $q = $l | ConvertFrom-Json
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
