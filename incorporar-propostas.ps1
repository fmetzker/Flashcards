# Fase 4c — puxa propostas aprovadas do Supabase e grava como questão de
# verdade em banco/<matéria>.json.
#
# Rode só localmente, nunca a partir do app. Pede a chave SECRETA
# (sb_secret_...), que ignora toda a RLS — é isso que permite ler propostas de
# qualquer autor de uma vez só. Nunca cole essa chave num arquivo do repo;
# passe por variável de ambiente ou cole na hora, sem eco no terminal.
#
# O que este script NÃO faz, de propósito: commit, e não roda validar.py. As
# duas etapas continuam manuais — a mesma disciplina de sempre antes de
# publicar uma questão nova, aprovada por revisor ou não.
#
# Uso:
#   $env:SUPABASE_SERVICE_ROLE = "sb_secret_..."; .\incorporar-propostas.ps1
#   .\incorporar-propostas.ps1              (pede a chave interativamente)
#   .\incorporar-propostas.ps1 -DryRun      (mostra o que faria, não grava nada)

param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

function Id-Questao([string]$enunciado) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($enunciado)
  $hash = $sha.ComputeHash($bytes)
  $sha.Dispose()
  (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 10)
}

# ---- 1. configuração ---------------------------------------------------------

$supaJson = Join-Path $raiz 'supabase.json'
if (-not (Test-Path $supaJson)) { throw "supabase.json ausente" }
$supa = Get-Content $supaJson -Raw | ConvertFrom-Json
if (-not $supa.url -or $supa.url -like '*SEU-PROJETO*') {
  throw "supabase.json ainda não tem a URL de verdade — preencha antes de rodar"
}

$chave = $env:SUPABASE_SERVICE_ROLE
if (-not $chave) {
  $segura = Read-Host "Cole a chave SECRETA do Supabase (sb_secret_...)" -AsSecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
  $chave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ($chave -notlike 'sb_secret_*') {
  throw "isso não parece uma chave secreta (sb_secret_...) — confira se não colou a pública por engano"
}

$headers = @{ apikey = $chave; Authorization = "Bearer $chave" }

# ---- 2. matérias válidas e ids já existentes no banco ------------------------

$materias = Get-Content (Join-Path $dir 'materias.json') -Raw | ConvertFrom-Json
$idsExistentes = @{}   # materiaId -> HashSet de ids já no arquivo
foreach ($m in $materias) {
  $caminho = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $caminho)) { throw "banco/$($m.id).json ausente" }
  $qs = Get-Content $caminho -Raw | ConvertFrom-Json
  $set = New-Object System.Collections.Generic.HashSet[string]
  foreach ($q in $qs) { [void]$set.Add($q.id) }
  $idsExistentes[$m.id] = $set
}

# ---- 3. puxa as propostas aprovadas e ainda não incorporadas -----------------

$url = $supa.url.TrimEnd('/') + '/rest/v1/propostas?status=eq.aprovada&incorporada_em=is.null&select=*'
$propostas = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

if (-not $propostas -or $propostas.Count -eq 0) {
  Write-Host "Nenhuma proposta aprovada pendente de incorporação."
  return
}
Write-Host "$($propostas.Count) proposta(s) aprovada(s) para incorporar."
if ($DryRun) { Write-Host "(-DryRun: nada será gravado nem marcado)" }

# ---- 4. incorpora, uma de cada vez -------------------------------------------

$novasPorMateria = @{}   # materiaId -> lista de linhas JSON compactas a inserir
$incorporadas = @(); $puladas = @()

foreach ($p in $propostas) {
  $id = Id-Questao $p.enunciado

  if ($idsExistentes.ContainsKey($p.materia) -and $idsExistentes[$p.materia].Contains($id)) {
    Write-Host "  pulando [$id] (materia $($p.materia)): já existe no banco (duplicata ou já incorporada antes)"
    $puladas += $p
    continue
  }
  if (-not $idsExistentes.ContainsKey($p.materia)) {
    Write-Host "  ERRO [$($p.id)]: matéria '$($p.materia)' não existe em materias.json — pulando"
    $puladas += $p
    continue
  }
  if ($p.subtopico -and $p.subtopico -eq $p.topico) {
    Write-Host "  ERRO [$($p.id)]: subtópico igual ao tópico ('$($p.topico)') — corrija a proposta e rode de novo"
    $puladas += $p
    continue
  }

  $obj = [ordered]@{
    id = $id
    m  = $p.materia
    t  = $p.topico
  }
  if ($p.subtopico) { $obj.s = $p.subtopico }
  $obj.q = $p.enunciado
  $obj.o = @($p.alternativas)
  $obj.c = [int]$p.correta
  $obj.e = $p.explicacao
  $obj.f = $p.fonte

  $linha = $obj | ConvertTo-Json -Compress -Depth 5

  if (-not $novasPorMateria.ContainsKey($p.materia)) { $novasPorMateria[$p.materia] = @() }
  $novasPorMateria[$p.materia] += $linha
  [void]$idsExistentes[$p.materia].Add($id)   # evita duplicata se duas propostas aprovadas tiverem o mesmo enunciado
  $incorporadas += @{ proposta = $p; id = $id }
  Write-Host "  [$id] $($p.materia) / $($p.topico) — $($p.enunciado.Substring(0,[Math]::Min(60,$p.enunciado.Length)))..."
}

if ($DryRun) {
  Write-Host "`nDryRun: $($incorporadas.Count) seria(m) incorporada(s), $($puladas.Count) pulada(s). Nada foi gravado."
  return
}

# ---- 5. grava nos arquivos de matéria, uma matéria por vez -------------------

foreach ($materiaId in $novasPorMateria.Keys) {
  $caminho = Join-Path $dir "$materiaId.json"
  $linhas = [System.IO.File]::ReadAllLines($caminho, [System.Text.Encoding]::UTF8)

  $fechoIdx = -1
  for ($i = $linhas.Count - 1; $i -ge 0; $i--) {
    if ($linhas[$i].Trim() -eq ']') { $fechoIdx = $i; break }
  }
  if ($fechoIdx -lt 1) { throw "banco/$materiaId.json não tem o formato esperado (linha ']' não encontrada)" }

  $ultimoConteudoIdx = $fechoIdx - 1
  if ($linhas[$ultimoConteudoIdx].TrimEnd() -notmatch ',$') {
    $linhas[$ultimoConteudoIdx] = $linhas[$ultimoConteudoIdx].TrimEnd() + ','
  }

  $novasLinhas = $novasPorMateria[$materiaId]
  $comVirgula = $novasLinhas[0..($novasLinhas.Count - 2)] | ForEach-Object { $_ + ',' }
  $todasNovas = @($comVirgula) + @($novasLinhas[-1])

  $resultado = @()
  $resultado += $linhas[0..$ultimoConteudoIdx]
  $resultado += $todasNovas
  $resultado += $linhas[$fechoIdx..($linhas.Count - 1)]

  [System.IO.File]::WriteAllText($caminho, ($resultado -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
  Write-Host "banco/$materiaId.json — $($novasLinhas.Count) questão(ões) adicionada(s)"
}

# ---- 6. marca como incorporada no Supabase ------------------------------------

foreach ($item in $incorporadas) {
  $p = $item.proposta
  $urlPatch = $supa.url.TrimEnd('/') + "/rest/v1/propostas?id=eq.$($p.id)"
  $corpo = @{ incorporada_em = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json -Compress
  Invoke-RestMethod -Uri $urlPatch -Headers $headers -Method Patch -Body $corpo -ContentType 'application/json' | Out-Null
}

Write-Host "`n$($incorporadas.Count) questão(ões) incorporada(s), $($puladas.Count) pulada(s)."
Write-Host "Falta: rodar validar.py (ou validar.ps1) e dar commit."
