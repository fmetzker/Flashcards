# Grava 'eo' (explicação por alternativa), 'n' (nível), 'o' (alternativas,
# para corrigir viés), 's' (subtópico), 'c' (índice da correta), 'e'
# (explicação principal), 't' (tópico) e/ou 'f' (fonte) em cartão que JÁ EXISTE no banco,
# casando por id — só se o validador passar. Terceiro e último script
# autorizado a escrever em banco/*.json (regra 9 do CLAUDE.md); os outros
# dois (incorporar-rascunho.ps1, incorporar-propostas.ps1) ACRESCENTAM
# questão nova, este só ACRESCENTA/ALTERA CAMPOS de uma que já existe.
#
# A disciplina é a mesma dos outros dois:
#   1. NADA é gravado antes de `validar.ps1 -Patches` passar limpo, com o
#      patch aplicado em memória contra o banco inteiro. `validar.ps1` é só
#      o invólucro do `validar.py`, então o gate é o validador inteiro, não
#      uma cópia enfraquecida das regras.
#   2. Casa por id: id que não existe no banco é erro, não é silenciosamente
#      ignorado.
#   3. Não faz commit nem mexe em VERSAO — as duas etapas continuam manuais.
#
# Uso:
#   .\explicar-alternativas.ps1 -DryRun     mostra o que faria, não grava
#   .\explicar-alternativas.ps1             grava, se o validador passar
#   .\explicar-alternativas.ps1 -Arquivo outro.json
#
# Formato de explicacoes.json: array de {id, ...}, com um ou mais destes:
#   eo  array do mesmo tamanho de 'o' (string vazia pula a posição).
#       Ver PADRAO-DOS-CARTOES.md seção 1.4.1.
#   n   nível do cartão dentro do tópico (1 a 9).
#   o   as alternativas, para corrigir viés de comprimento reescrevendo
#       DISTRATOR. Sem 'c' no mesmo patch, a correta tem de vir idêntica e na
#       mesma posição: 'c' é índice, não texto, e trocar a ordem mudaria a
#       resposta certa sem aparecer no diff. Quem reprova isso é o
#       validar.py — mexeu na correta sem avisar, não grava. Mandando 'o',
#       mande o 'eo' junto: eo[i] explica o[i], e distrator novo com
#       explicação velha vira cartão que ensina errado.
#   s   subtópico (substitui o que o cartão já tinha; string vazia REMOVE o
#       subtópico). Não pode repetir o 't' do cartão — quem reprova é o
#       validar.py de sempre (valida_questoes), nenhuma checagem nova aqui.
#   c   índice da alternativa correta — só para quando a AUDITORIA confirma
#       que a resposta marcada está factualmente errada (não é viés de
#       comprimento, é erro de fato). Exige 'e' no mesmo patch: a explicação
#       antiga quase certamente não justifica a resposta nova, e 'c' sem 'e'
#       reescrita vira cartão que aponta pra resposta certa com explicação da
#       errada. validar.py recusa 'c' sem 'e' junto.
#   e   explicação principal (substitui a que o cartão já tinha).
#   f   fonte (substitui a que o cartão já tinha). Não pode ficar vazia — a
#       fonte é obrigatória, e o validar.py recusa patch que a esvazie.
#   t   tópico (substitui o que o cartão já tinha) — para corrigir cartão
#       classificado no tópico errado (ex.: rótulo que devia ser subtópico
#       virou tópico, ou tópico que não existe na árvore do banco). Mesma
#       checagem de sempre contra 's' != 't', nenhuma nova aqui.
#
# Rodar de novo com o mesmo id SUBSTITUI o 'eo' anterior (idempotente) — útil
# na calibração, quando a nota de uma alternativa precisa ser reescrita antes
# de fechar o lote.
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam de UTF-8 COM BOM,
# senão o PowerShell 5.1 os lê como ANSI e o parser quebra (regra 6).

param(
  [switch]$DryRun,
  [string]$Arquivo = 'explicacoes.json'
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

$arqP = if ([System.IO.Path]::IsPathRooted($Arquivo)) { $Arquivo } else { Join-Path $raiz $Arquivo }
if (-not (Test-Path $arqP)) { throw "patches não encontrado: $arqP" }

$raw = [System.IO.File]::ReadAllText($arqP, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
# @(...) por fora do if inteiro: com EXATAMENTE um patch, o próprio
# if/elseif/else desembrulha o array pra um objeto solto (pipeline do
# PowerShell 5.1), e $patches.Count usado abaixo viraria $null — ver
# incorporar-rascunho.ps1 pro mesmo caso.
$patches = @( if ($null -eq $raw) { @() } elseif ($raw -is [Array]) { $raw } else { @($raw) } )
if ($patches.Count -eq 0) {
  Write-Host "explicacoes.json vazio — nada a incorporar."
  exit 0
}

# ids repetidos no próprio arquivo são erro de digitação do lote, não do
# banco — pegar aqui evita um patch pisar no outro em silêncio
$vistos = @{}
foreach ($p in $patches) {
  if ($vistos.ContainsKey($p.id)) { throw "id '$($p.id)' aparece duas vezes em $Arquivo" }
  $vistos[$p.id] = $true
}

# ---- 1. o validador de verdade decide -----------------------------------------
Write-Host "Rodando validar.ps1 -Patches $Arquivo ...`n"
$saida = & powershell -ExecutionPolicy Bypass -File (Join-Path $raiz 'validar.ps1') -Patches $Arquivo 2>&1
$codigo = $LASTEXITCODE
$saida | ForEach-Object { Write-Host $_ }

if ($codigo -ne 0) {
  Write-Host "`nNADA foi gravado: o validador reprovou os patches acima."
  Write-Host "Corrija $Arquivo e rode de novo."
  exit 1
}

if ($DryRun) {
  Write-Host "`n-DryRun: $($patches.Count) cartão(ões) seria(m) alterado(s). Nada gravado."
  exit 0
}

# ---- 2. acha em qual banco/<matéria>.json cada id mora ------------------------
$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
# Um patch traz 'eo', 'n', 'o', 's', 'c', 'e', 't', 'f', ou uma combinação. Guardo
# em mapas separados porque campo ausente no patch NÃO pode apagar o que o
# cartão já tem — quem só define 'n' não deve perder o 'eo' escrito antes, e
# vice-versa.
#
# 'o' (as alternativas) entra por aqui para corrigir viés de comprimento:
# reescrever distrator curto demais, que denuncia a correta por ser a única
# frase longa. 'c' entra para corrigir resposta marcada errada de fato (não
# viés). Quem garante que o patch de 'o' sem 'c' não troca a correta de
# lugar, e que todo patch de 'c' vem com 'e' nova junto, é o validar.py, que
# roda logo acima — este script não reimplementa essa checagem (regra 9).
$eoPorId = @{}; $nPorId = @{}; $oPorId = @{}; $sPorId = @{}; $cPorId = @{}; $ePorId = @{}; $tPorId = @{}; $fPorId = @{}; $alvos = @{}
foreach ($p in $patches) {
  $campos = $p.PSObject.Properties.Name
  if ($campos -contains 'eo') { $eoPorId[$p.id] = @($p.eo) }
  if ($campos -contains 'n')  { $nPorId[$p.id]  = [int]$p.n }
  if ($campos -contains 'o')  { $oPorId[$p.id]  = @($p.o) }
  if ($campos -contains 's')  { $sPorId[$p.id]  = [string]$p.s }
  if ($campos -contains 'c')  { $cPorId[$p.id]  = [int]$p.c }
  if ($campos -contains 'e')  { $ePorId[$p.id]  = [string]$p.e }
  if ($campos -contains 't')  { $tPorId[$p.id]  = [string]$p.t }
  if ($campos -contains 'f')  { $fPorId[$p.id]  = [string]$p.f }
  $alvos[$p.id] = $true
}

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
    if (-not $alvos.ContainsKey($q.id)) { continue }

    # regrava na MESMA ordem de campos do banco, com 'n' e 'eo' por último — é
    # o mesmo padrão de reescrever-questoes.ps1, pelo mesmo motivo: garante
    # formatação previsível em vez de depender da ordem que ConvertFrom-Json
    # devolveu as propriedades
    $campoQ = $q.PSObject.Properties.Name
    $tFinal = if ($tPorId.ContainsKey($q.id)) { $tPorId[$q.id] } else { $q.t }
    $obj = [ordered]@{ id = $q.id; m = $q.m; t = $tFinal }
    if ($sPorId.ContainsKey($q.id)) {
      if ($sPorId[$q.id]) { $obj.s = $sPorId[$q.id] }   # string vazia = remove
    } elseif ($campoQ -contains 's' -and $q.s) { $obj.s = $q.s }
    $obj.q = $q.q
    if ($oPorId.ContainsKey($q.id)) { $obj.o = $oPorId[$q.id] } else { $obj.o = @($q.o) }
    $obj.c = if ($cPorId.ContainsKey($q.id)) { $cPorId[$q.id] } else { [int]$q.c }
    $obj.e = if ($ePorId.ContainsKey($q.id)) { $ePorId[$q.id] } else { $q.e }
    $obj.f = if ($fPorId.ContainsKey($q.id)) { $fPorId[$q.id] } else { $q.f }
    # o que o patch não trouxe é preservado do cartão original
    if ($nPorId.ContainsKey($q.id))      { $obj.n = $nPorId[$q.id] }
    elseif ($campoQ -contains 'n')       { $obj.n = [int]$q.n }
    if ($eoPorId.ContainsKey($q.id))     { $obj.eo = $eoPorId[$q.id] }
    elseif ($campoQ -contains 'eo')      { $obj.eo = @($q.eo) }

    $virgula = if ($linhas[$i].TrimEnd().EndsWith(',')) { ',' } else { '' }
    $linhas[$i] = ($obj | ConvertTo-Json -Compress -Depth 5) + $virgula
    $mudouArquivo = $true
    $alterados++
    $vistos.Remove($q.id)
    Write-Host "  [$($q.id)] $($m.id)/$($q.t)"
  }

  if ($mudouArquivo) {
    [System.IO.File]::WriteAllText($arq, ($linhas -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
}

# não deveria sobrar nenhum — o validador já confere id contra o banco, mas
# confere de novo aqui porque é o passo que decide gravar ou não
if ($vistos.Count -gt 0) {
  throw "id(s) aprovados no validador mas não encontrados na hora de gravar: $($vistos.Keys -join ', ')"
}

Write-Host "`n$alterados cartão(ões) alterado(s)."

# esvazia o arquivo de trabalho: o que foi incorporado não pode ser incorporado de novo
[System.IO.File]::WriteAllText($arqP, "[`n]`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "$Arquivo esvaziado."
Write-Host "Falta, à mão: validar.ps1, gerar-offline.ps1, VERSAO no sw.js, commit."
