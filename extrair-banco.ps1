# Fase 0 — extrai o array BANCO do index.html para arquivos JSON em banco/.
#
# Escrito em PowerShell porque nem toda máquina do projeto tem Python, Node ou
# Godot. Roda em Windows PowerShell 5.1 sem nada instalado.
#
# Gera:
#   banco/lp.json, banco/sus.json, banco/esp.json  — questões por área, com id
#   banco/indice-legado.json                        — ids na ordem original do
#                                                     array, para migrar o
#                                                     progresso já salvo
#
# O id é o SHA-1 do enunciado em UTF-8, truncado em 10 hexadecimais. É estável,
# independe da posição no array e pode ser recalculado em qualquer linguagem.

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$html = Join-Path $raiz 'index.html'
$dir  = Join-Path $raiz 'banco'

function Id-Questao([string]$enunciado) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($enunciado)
  $hash = $sha.ComputeHash($bytes)
  $sha.Dispose()
  ($hash | ForEach-Object { $_.ToString('x2') }) -join '' | ForEach-Object { $_.Substring(0, 10) }
}

# ---- 1. localiza as linhas do banco -----------------------------------------

$linhas = [System.IO.File]::ReadAllLines($html, [System.Text.Encoding]::UTF8)
$ini = -1; $fim = -1
for ($i = 0; $i -lt $linhas.Count; $i++) {
  if ($ini -lt 0 -and $linhas[$i] -match '^const BANCO = \[') { $ini = $i + 1; continue }
  if ($ini -ge 0 -and $linhas[$i] -match '^\];') { $fim = $i - 1; break }
}
if ($ini -lt 0 -or $fim -lt 0) { throw "array BANCO não encontrado em index.html" }

$questoes = @()
for ($i = $ini; $i -le $fim; $i++) {
  $l = $linhas[$i].Trim()
  if ($l -eq '') { continue }
  if ($l -notmatch '^\{a:"') { throw "linha $($i+1) fora do formato esperado: $($l.Substring(0,[Math]::Min(60,$l.Length)))" }

  # o formato é rigidamente regular: uma questão por linha, campos sempre na
  # mesma ordem. Basta pôr aspas nas chaves para virar JSON válido.
  $j = $l.TrimEnd(',')
  $j = $j -replace '^\{a:"',   '{"a":"'
  $j = $j -replace '",t:"',    '","t":"'
  $j = $j -replace '",q:"',    '","q":"'
  $j = $j -replace '",o:\[',   '","o":['
  $j = $j -replace '\],c:',    '],"c":'
  $j = $j -replace ',e:"',     ',"e":"'
  $j = $j -replace '",f:"',    '","f":"'

  $q = $j | ConvertFrom-Json
  $questoes += [pscustomobject]@{
    id = Id-Questao $q.q
    a  = $q.a
    t  = $q.t
    q  = $q.q
    o  = $q.o
    c  = $q.c
    e  = $q.e
    f  = $q.f
  }
}

Write-Host "questões lidas: $($questoes.Count)"

# ---- 2. confere o que foi lido ----------------------------------------------

$problemas = @()
foreach ($q in $questoes) {
  if ($q.o.Count -ne 5) { $problemas += "$($q.id): não tem 5 alternativas" }
  if ($q.c -lt 0 -or $q.c -gt 4) { $problemas += "$($q.id): índice da correta inválido" }
  foreach ($campo in 'a','t','q','e','f') {
    if ([string]::IsNullOrWhiteSpace($q.$campo)) { $problemas += "$($q.id): campo '$campo' vazio" }
  }
  if ($q.a -notin 'lp','sus','esp') { $problemas += "$($q.id): área inválida '$($q.a)'" }
}
$dup = $questoes | Group-Object id | Where-Object Count -gt 1
foreach ($d in $dup) { $problemas += "id repetido $($d.Name) em $($d.Count) questões" }

if ($problemas) {
  $problemas | ForEach-Object { Write-Host "ERRO: $_" }
  throw "$($problemas.Count) problema(s) na extração. Nada foi gravado."
}

# ---- 3. grava ----------------------------------------------------------------

if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

# uma questão por linha: mantém o arquivo legível e o diff pequeno.
function Grava-Area([string]$area) {
  $sel = $questoes | Where-Object a -eq $area
  $corpo = ($sel | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }) -join ",`n"
  $texto = "[`n$corpo`n]`n"
  [System.IO.File]::WriteAllText((Join-Path $dir "$area.json"), $texto, (New-Object System.Text.UTF8Encoding $false))
  Write-Host "  banco/$area.json — $($sel.Count) questões"
}
Grava-Area 'lp'; Grava-Area 'sus'; Grava-Area 'esp'

$legado = ($questoes | ForEach-Object { '"' + $_.id + '"' }) -join ",`n"
[System.IO.File]::WriteAllText((Join-Path $dir 'indice-legado.json'), "[`n$legado`n]`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "  banco/indice-legado.json — $($questoes.Count) ids na ordem original"
