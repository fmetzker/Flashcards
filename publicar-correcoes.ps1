# Aprova as correcoes pendentes e publica o resultado, de ponta a ponta.
#
# O que ele faz, nesta ordem:
#   1. exige a arvore git limpa fora de banco/ (senao o commit levaria junto
#      trabalho seu que nada tem a ver com correcao de questao)
#   2. puxa as correcoes PENDENTES do Supabase e mostra antes->depois de cada
#      uma, campo a campo, perguntando aprovar / rejeitar / pular
#   3. grava as decisoes no servidor
#   4. chama explicar-alternativas.ps1 -DoSupabase, que confere a deriva,
#      roda o validador e so entao grava em banco/*.json
#   5. roda o validador completo de novo, ja com o banco alterado
#   6. regenera o offline.html
#   7. commita banco/ e pergunta antes de publicar
#
# ESTE SCRIPT NAO ESCREVE NO BANCO. Quem escreve continua sendo o
# explicar-alternativas.ps1 (regra 9 segue com tres scripts) — aqui e so a
# sequencia que antes era feita a mao, com os mesmos portoes no mesmo lugar.
# O validador continua sendo quem decide, e falha dele aborta tudo.
#
# NAO BUMPA VERSAO de proposito: mudanca so em banco/*.json nao precisa. O
# CACHE_BANCO tem nome estavel e o handler de fetch do sw.js reescreve o
# arquivo daquela materia a cada resposta de rede boa — ver o comentario no
# proprio sw.js. VERSAO e para mudanca de CODIGO (regra 2).
#
# Uso:
#   $env:SUPABASE_SERVICE_ROLE = "sb_secret_..."; .\publicar-correcoes.ps1
#   .\publicar-correcoes.ps1                (pede a chave interativamente)
#   .\publicar-correcoes.ps1 -DryRun        so mostra; nao decide, nao grava
#   .\publicar-correcoes.ps1 -SemPush       faz tudo menos o git push
#
# ATENCAO ao editar: .ps1 com acento precisa de UTF-8 COM BOM (regra 6). Este
# arquivo evita acento de proposito, para nao depender disso.

param(
  [switch]$DryRun,
  [switch]$SemPush
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot

function Titulo($t) {
  Write-Host ""
  Write-Host "== $t" -ForegroundColor Cyan
}

# ---- 1. arvore limpa fora de banco/ ------------------------------------------
# Sem isso, o commit do fim varreria junto qualquer coisa que voce estivesse
# editando — e uma correcao de questao viraria um commit que mexe em index.html.
Titulo "Conferindo a arvore de trabalho"
$sujo = @(git -C $raiz status --porcelain | Where-Object { $_ -and ($_ -notmatch '^\s*.\s+banco/') })
if ($sujo.Count -gt 0) {
  Write-Host "A arvore tem mudancas fora de banco/:" -ForegroundColor Red
  $sujo | ForEach-Object { Write-Host "   $_" }
  Write-Host ""
  Write-Host "Commite ou guarde essas mudancas antes: o commit deste script deve conter"
  Write-Host "apenas o banco, senao a correcao de questao some no meio de outra coisa."
  exit 1
}
Write-Host "OK - nada pendente fora de banco/."

# ---- 2. chave e conexao ------------------------------------------------------
$supaJson = Join-Path $raiz 'supabase.json'
if (-not (Test-Path $supaJson)) { throw "supabase.json nao encontrado" }
$supa = Get-Content $supaJson -Raw | ConvertFrom-Json
if (-not $supa.url -or $supa.url -like '*SEU-PROJETO*') {
  throw "supabase.json ainda nao tem a URL de verdade"
}

$chave = $env:SUPABASE_SERVICE_ROLE
if (-not $chave) {
  $segura = Read-Host "Cole a chave SECRETA do Supabase (sb_secret_...)" -AsSecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
  $chave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ($chave -notlike 'sb_secret_*') {
  throw "isso nao parece a chave secreta (sb_secret_...) — confira se nao colou a publica"
}
$headers = @{ apikey = $chave; Authorization = "Bearer $chave" }
$base = $supa.url.TrimEnd('/') + '/rest/v1'

# ---- 3. revisar as pendentes -------------------------------------------------
Titulo "Correcoes pendentes"
$pendentes = @(Invoke-RestMethod -Method Get -Headers $headers `
  -Uri "$base/correcoes?status=eq.pendente&order=criado_em.asc&select=*")

if ($pendentes.Count -eq 0) {
  Write-Host "Nenhuma correcao pendente."
  Write-Host "(Se ha correcoes ja APROVADAS esperando, rode:"
  Write-Host "   .\explicar-alternativas.ps1 -DoSupabase)"
  exit 0
}
Write-Host "$($pendentes.Count) pendente(s).`n"

# indice do banco, so pra mostrar o enunciado junto do diff
$porIdBanco = @{}
foreach ($m in (Get-Content (Join-Path $raiz 'banco/materias.json') -Raw | ConvertFrom-Json)) {
  $arqM = Join-Path $raiz "banco/$($m.id).json"
  if (-not (Test-Path $arqM)) { continue }
  foreach ($q in (Get-Content $arqM -Raw | ConvertFrom-Json)) { $porIdBanco[$q.id] = $q }
}

$ROTULO = @{ o='Alternativas'; c='Qual e a correta'; e='Explicacao'; eo='Notas por alternativa';
             t='Topico'; s='Subtopico'; n='Nivel'; f='Fonte' }

$aprovar = @(); $rejeitar = @()
foreach ($cor in $pendentes) {
  $q = $porIdBanco[$cor.questao_id]
  Write-Host ("-" * 70)
  if ($q) { Write-Host "$($q.m) / $($q.t)" -ForegroundColor DarkGray; Write-Host $q.q }
  else    { Write-Host "id $($cor.questao_id) — nao existe no banco atual" -ForegroundColor Yellow }
  Write-Host ""

  foreach ($campo in $cor.patch.PSObject.Properties.Name) {
    if ($campo -eq 'id') { continue }
    $rot = if ($ROTULO.ContainsKey($campo)) { $ROTULO[$campo] } else { $campo }
    Write-Host "  $rot" -ForegroundColor DarkGray
    $antes  = $cor.antes.$campo  | ConvertTo-Json -Compress -Depth 5
    $depois = $cor.patch.$campo  | ConvertTo-Json -Compress -Depth 5
    Write-Host "    - $antes"
    Write-Host "    + $depois" -ForegroundColor Green
  }
  Write-Host ""

  if ($DryRun) { Write-Host "  (-DryRun: nada decidido)" -ForegroundColor DarkGray; continue }

  $r = ''
  while ($r -notin @('a','r','p')) {
    $r = (Read-Host "  [a]provar / [r]ejeitar / [p]ular").ToLower()
  }
  if ($r -eq 'a') { $aprovar  += $cor.id; Write-Host "  -> aprovada" -ForegroundColor Green }
  if ($r -eq 'r') { $rejeitar += $cor.id; Write-Host "  -> rejeitada" -ForegroundColor Yellow }
  if ($r -eq 'p') { Write-Host "  -> pulada (segue pendente)" -ForegroundColor DarkGray }
}

if ($DryRun) {
  Write-Host "`n-DryRun: nada foi decidido nem gravado."
  exit 0
}

if ($aprovar.Count -eq 0) {
  Write-Host "`nNenhuma correcao aprovada."
  if ($rejeitar.Count -gt 0) { Write-Host "Registrando as $($rejeitar.Count) rejeicao(oes)..." }
  foreach ($id in $rejeitar) {
    Invoke-RestMethod -Method Patch -Uri "$base/correcoes?id=eq.$id" `
      -Headers ($headers + @{ 'Content-Type'='application/json'; Prefer='return=minimal' }) `
      -Body (@{ status = 'rejeitada' } | ConvertTo-Json -Compress) | Out-Null
  }
  exit 0
}

# ---- 4. grava as decisoes ----------------------------------------------------
Titulo "Registrando as decisoes"
foreach ($id in $aprovar) {
  Invoke-RestMethod -Method Patch -Uri "$base/correcoes?id=eq.$id" `
    -Headers ($headers + @{ 'Content-Type'='application/json'; Prefer='return=minimal' }) `
    -Body (@{ status = 'aprovada' } | ConvertTo-Json -Compress) | Out-Null
}
foreach ($id in $rejeitar) {
  Invoke-RestMethod -Method Patch -Uri "$base/correcoes?id=eq.$id" `
    -Headers ($headers + @{ 'Content-Type'='application/json'; Prefer='return=minimal' }) `
    -Body (@{ status = 'rejeitada' } | ConvertTo-Json -Compress) | Out-Null
}
Write-Host "$($aprovar.Count) aprovada(s), $($rejeitar.Count) rejeitada(s)."

# ---- 5. incorpora (o unico que escreve no banco) -----------------------------
Titulo "Incorporando ao banco"
$env:SUPABASE_SERVICE_ROLE = $chave    # repassa, pra nao pedir a chave de novo
& powershell -ExecutionPolicy Bypass -File (Join-Path $raiz 'explicar-alternativas.ps1') -DoSupabase
if ($LASTEXITCODE -ne 0) {
  Write-Host "`nA incorporacao falhou. NADA foi commitado." -ForegroundColor Red
  Write-Host "As correcoes aprovadas seguem no servidor, sem incorporar."
  exit 1
}

# ---- 6. validador completo, ja com o banco alterado --------------------------
Titulo "Validando o banco"
& powershell -ExecutionPolicy Bypass -File (Join-Path $raiz 'validar.ps1')
if ($LASTEXITCODE -ne 0) {
  Write-Host "`nO validador reprovou DEPOIS da gravacao." -ForegroundColor Red
  Write-Host "Nada foi commitado. Confira o banco com: git diff banco/"
  exit 1
}

# ---- 7. offline.html -------------------------------------------------------
Titulo "Regerando o offline.html"
& powershell -ExecutionPolicy Bypass -File (Join-Path $raiz 'gerar-offline.ps1')

# ---- 8. commit ---------------------------------------------------------------
Titulo "Commit"
$mudou = @(git -C $raiz status --porcelain -- banco/)
if ($mudou.Count -eq 0) {
  Write-Host "Nada mudou em banco/ — nada a commitar."
  exit 0
}
$mudou | ForEach-Object { Write-Host "   $_" }

$quantos = $aprovar.Count
$plural = if ($quantos -eq 1) { 'correcao aplicada' } else { 'correcoes aplicadas' }
$msg = @"
$quantos $plural pela caixa de entrada do app

Aprovadas no editor e incorporadas por explicar-alternativas.ps1 -DoSupabase:
o `antes` de cada uma foi conferido contra o banco atual, e o validador passou
antes e depois da gravacao.

Sem bump de VERSAO: mudanca so em banco/*.json nao precisa — CACHE_BANCO tem
nome estavel e o handler de fetch do sw.js rebaixa o arquivo da materia
sozinho.
"@

git -C $raiz add banco/
git -C $raiz commit -m $msg
if ($LASTEXITCODE -ne 0) { throw "git commit falhou" }

# ---- 9. push -----------------------------------------------------------------
if ($SemPush) {
  Write-Host "`n-SemPush: commitado, nao publicado. Rode 'git push' quando quiser."
  exit 0
}
$ok = Read-Host "`nPublicar agora (git push)? [s/N]"
if ($ok.ToLower() -eq 's') {
  git -C $raiz push
  if ($LASTEXITCODE -ne 0) { throw "git push falhou" }
  Write-Host "`nPublicado." -ForegroundColor Green
} else {
  Write-Host "`nCommitado, nao publicado. Rode 'git push' quando quiser."
}
