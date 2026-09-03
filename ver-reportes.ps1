# Le os reportes PENDENTES do Supabase ("Reportar problema nesta questao") e
# mostra cada um por completo — questao, alternativas e motivo — cruzando com
# o banco local. So LEITURA: nao grava nada em lugar nenhum, nem no Supabase
# nem em banco/*.json. Por isso nao entra na contagem da regra 9 do
# CLAUDE.md (que e sobre GRAVACAO) — e por isso tambem nao pede -DryRun.
#
# Pede a chave SECRETA (sb_secret_...), que ignora toda a RLS — e o que
# permite ler reporte de qualquer autor de uma vez so, do jeito que
# incorporar-propostas.ps1/explicar-alternativas.ps1 -DoSupabase ja fazem.
# Nunca cole essa chave num arquivo do repo; passe por variavel de ambiente
# ou cole na hora, sem eco no terminal.
#
# Depois de ler, a correcao em si continua pelo caminho de sempre:
# explicar-alternativas.ps1 (questao que ja existe) ou reescrever-questoes.ps1
# (enunciado errado, regra 5) — este script aqui so mostra o que esta pendente.
#
# Uso:
#   $env:SUPABASE_SERVICE_ROLE = "sb_secret_..."; .\ver-reportes.ps1
#   .\ver-reportes.ps1                (pede a chave interativamente)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

# ---- 1. configuracao ---------------------------------------------------------

$supaJson = Join-Path $raiz 'supabase.json'
if (-not (Test-Path $supaJson)) { throw "supabase.json ausente" }
$supa = Get-Content $supaJson -Raw | ConvertFrom-Json
if (-not $supa.url -or $supa.url -like '*SEU-PROJETO*') {
  throw "supabase.json ainda nao tem a URL de verdade — preencha antes de rodar"
}

$chave = $env:SUPABASE_SERVICE_ROLE
if (-not $chave) {
  $segura = Read-Host "Cole a chave SECRETA do Supabase (sb_secret_...)" -AsSecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
  $chave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ($chave -notlike 'sb_secret_*') {
  throw "isso nao parece uma chave secreta (sb_secret_...) — confira se nao colou a publica por engano"
}

$headers = @{ apikey = $chave; Authorization = "Bearer $chave" }

# ---- 2. indice local: questao_id -> {materia, questao} ----------------------

$materias = Get-Content (Join-Path $dir 'materias.json') -Raw | ConvertFrom-Json
$porId = @{}
foreach ($m in $materias) {
  $caminho = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $caminho)) { continue }
  $qs = Get-Content $caminho -Raw | ConvertFrom-Json
  foreach ($q in $qs) { $porId[$q.id] = [pscustomobject]@{ materia = $m.id; q = $q } }
}

# ---- 3. puxa os reportes pendentes, com quem reportou --------------------

$url = $supa.url.TrimEnd('/') + '/rest/v1/reportes?status=eq.pendente&order=criado_em.asc&select=id,questao_id,motivo,criado_em,autor_id'
$reportes = @(Invoke-RestMethod -Uri $url -Headers $headers -Method Get)

if ($reportes.Count -eq 0) {
  Write-Host "Nada pendente — nenhum reporte aberto no momento."
  exit 0
}

Write-Host "$($reportes.Count) reporte(s) pendente(s):`n"

$letras = @('A','B','C','D','E')
$i = 0
foreach ($rp in $reportes) {
  $i++
  Write-Host "===================================================================="
  Write-Host "[$i/$($reportes.Count)] reporte $($rp.id)  ·  criado $($rp.criado_em)"
  Write-Host "motivo do reporte: $($rp.motivo)"
  Write-Host ""

  $achado = $porId[$rp.questao_id]
  if (-not $achado) {
    Write-Host "questao $($rp.questao_id) NAO esta em banco/*.json local (id orfao, ou matéria não sincronizada)."
    Write-Host ""
    continue
  }
  $q = $achado.q
  Write-Host "id: $($q.id)   materia: $($achado.materia)   topico: $($q.t)$(if ($q.s) { " · subtopico: $($q.s)" })"
  Write-Host "fonte: $($q.f)"
  Write-Host ""
  Write-Host "enunciado: $($q.q)"
  for ($k = 0; $k -lt $q.o.Count; $k++) {
    $marca = if ($k -eq $q.c) { " <- correta" } else { "" }
    Write-Host "  $($letras[$k])) $($q.o[$k])$marca"
  }
  Write-Host ""
  Write-Host "explicacao: $($q.e)"
  Write-Host ""
}

Write-Host "===================================================================="
Write-Host "Fim. Para corrigir, use explicar-alternativas.ps1 (campo errado) ou"
Write-Host "reescrever-questoes.ps1 (enunciado errado, regra 5) — este script so leu."
