# Grava os cartões de rascunho.json como questão de verdade em banco/<matéria>.json.
#
# Junto com incorporar-propostas.ps1, é um dos DOIS únicos caminhos que gravam
# no banco (regra 9 do CLAUDE.md). Existe porque a alternativa — um script
# descartável por lote — reimplementava SHA-1, append e uma cópia enfraquecida
# das checagens, e já corrompeu o banco por encoding e deixou passar regra que
# o validador reprova.
#
# A disciplina que este script impõe:
#   1. NADA é gravado antes de `validar.ps1 -Rascunho` passar limpo. O script
#      roda o validador de verdade; não há cópia das regras aqui.
#   2. O id sai do SHA-1 do enunciado, calculado na hora (regra 5).
#   3. Não faz commit nem mexe em VERSAO — as duas etapas continuam manuais,
#      a mesma disciplina de incorporar-propostas.ps1.
#
# Uso:
#   .\incorporar-rascunho.ps1 -DryRun     mostra o que faria, não grava
#   .\incorporar-rascunho.ps1             grava, se o validador passar
#   .\incorporar-rascunho.ps1 -Arquivo outro.json
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam de UTF-8 COM BOM,
# senão o PowerShell 5.1 os lê como ANSI e o parser quebra (regra 6).

param(
  [switch]$DryRun,
  [string]$Arquivo = 'rascunho.json'
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

function Id-Questao([string]$enunciado) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($enunciado))
  $sha.Dispose()
  (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 10)
}

$arqR = if ([System.IO.Path]::IsPathRooted($Arquivo)) { $Arquivo } else { Join-Path $raiz $Arquivo }
if (-not (Test-Path $arqR)) { throw "rascunho não encontrado: $arqR" }

# ConvertFrom-Json do PowerShell 5.1 NÃO enumera array na pipeline: devolve o
# array inteiro como um item só. Envolver em @() aqui criaria um array dentro
# de outro, e o agrupamento por matéria passaria a ver 'System.Object[]' como
# nome de matéria. Por isso a atribuição é direta, e o @() só entra quando o
# JSON tem um objeto solto em vez de lista.
$raw = [System.IO.File]::ReadAllText($arqR, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
# @(...) por fora do if inteiro: um rascunho com EXATAMENTE um candidato faz
# o próprio if/elseif/else desembrulhar o array pra um objeto solto (efeito
# de pipeline do PowerShell 5.1, não da checagem `-is [Array]` em si), e
# $cands.Count vira $null em vez de 1. Sem o @() de fora, isso não quebra o
# foreach abaixo (que itera um objeto solto do mesmo jeito), mas quebraria
# qualquer checagem futura que dependa de .Count.
$cands = @( if ($null -eq $raw) { @() } elseif ($raw -is [Array]) { $raw } else { @($raw) } )
if ($cands.Count -eq 0) {
  Write-Host "rascunho vazio — nada a incorporar."
  exit 0
}

# ---- 1. o validador de verdade decide -----------------------------------------
Write-Host "Rodando validar.ps1 -Rascunho $Arquivo ...`n"
$saida = & powershell -ExecutionPolicy Bypass -File (Join-Path $raiz 'validar.ps1') -Rascunho $Arquivo 2>&1
$codigo = $LASTEXITCODE
$saida | ForEach-Object { Write-Host $_ }

if ($codigo -ne 0) {
  Write-Host "`nNADA foi gravado: o validador reprovou os candidatos acima."
  Write-Host "Corrija rascunho.json e rode de novo."
  exit 1
}

# ---- 2. agrupa por matéria ----------------------------------------------------
$porMateria = @{}
foreach ($q in $cands) {
  if (-not $q.m) { throw "questão sem matéria: $($q.q)" }
  if (-not $porMateria.ContainsKey($q.m)) { $porMateria[$q.m] = @() }
  $porMateria[$q.m] += $q
}

Write-Host "`n--- a incorporar ---"
foreach ($m in $porMateria.Keys) {
  Write-Host ("  {0,-22} {1} cartão(ões)" -f $m, $porMateria[$m].Count)
  foreach ($q in $porMateria[$m]) {
    Write-Host ("     [{0}] {1}" -f (Id-Questao $q.q), $q.t)
  }
}

if ($DryRun) {
  Write-Host "`n-DryRun: nada gravado."
  exit 0
}

# ---- 3. grava ------------------------------------------------------------------
foreach ($m in $porMateria.Keys) {
  $destino = Join-Path $dir "$m.json"
  if (-not (Test-Path $destino)) { throw "banco/$m.json não existe" }

  $linhas = foreach ($q in $porMateria[$m]) {
    $obj = [ordered]@{ id = Id-Questao $q.q; m = $q.m; t = $q.t }
    if ($q.s) { $obj.s = $q.s }
    $obj.q = $q.q; $obj.o = $q.o; $obj.c = $q.c; $obj.e = $q.e; $obj.f = $q.f
    if ($q.PSObject.Properties.Name -contains 'eo' -and $q.eo) { $obj.eo = @($q.eo) }
    $obj | ConvertTo-Json -Compress -Depth 5
  }

  $arq = [System.IO.File]::ReadAllLines($destino, [System.Text.Encoding]::UTF8)
  $fecho = -1
  for ($i = $arq.Count - 1; $i -ge 0; $i--) { if ($arq[$i].Trim() -eq ']') { $fecho = $i; break } }
  if ($fecho -lt 0) { throw "banco/$m.json não termina com ']' — formato inesperado" }

  $resultado = @()
  if ($fecho -eq 1) {
    # arquivo vazio ("[\n]"): as novas questões são as primeiras
    $resultado += $arq[0]
    $resultado += (@($linhas[0..($linhas.Count - 1)]) -join ",`n")
  } else {
    $ultimo = $fecho - 1
    if ($arq[$ultimo].TrimEnd() -notmatch ',$') { $arq[$ultimo] = $arq[$ultimo].TrimEnd() + ',' }
    $resultado += $arq[0..$ultimo]
    $resultado += (@($linhas) -join ",`n")
  }
  $resultado += $arq[$fecho..($arq.Count - 1)]

  [System.IO.File]::WriteAllText($destino, ($resultado -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
  Write-Host "GRAVADO banco/$m.json (+$($porMateria[$m].Count))"
}

# esvazia o rascunho: o que foi incorporado não pode ser incorporado de novo
[System.IO.File]::WriteAllText($arqR, "[`n]`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "`nrascunho esvaziado."
Write-Host "Falta, à mão: validar.ps1, gerar-offline.ps1, VERSAO no sw.js, commit."
