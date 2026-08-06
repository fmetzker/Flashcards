# Verifica a integridade do banco de questões e mede os vieses estatísticos.
#
# Equivalente ao validar.py, para máquinas sem Python. Roda em Windows
# PowerShell 5.1 sem nada instalado.
#
#   powershell -ExecutionPolicy Bypass -File validar.ps1
#   powershell -ExecutionPolicy Bypass -File validar.ps1 -Rascunho banco/rascunho.json
#
# Sai com código 1 se encontrar erro que impeça a publicação.
#
# -Rascunho avalia cartões candidatos COMO SE já estivessem no banco, sem
# gravar nada. Existe porque a ordem antiga era escrever no banco e só então
# descobrir o que o validador reprova — e desfazer isso à mão já corrompeu o
# banco uma vez. Com o rascunho, toda regra daqui (viés, formatação, id
# duplicado, fonte, matéria) roda ANTES de a questão existir, e são as regras
# de verdade, não uma cópia enfraquecida delas num script de uma vez só.
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam ser gravados em UTF-8
# COM BOM, senão o PowerShell 5.1 os lê como ANSI e o parser quebra.

param(
  [string]$Rascunho
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

$erros = New-Object System.Collections.ArrayList
$avisos = New-Object System.Collections.ArrayList
function Erro($m)  { [void]$erros.Add($m) }
function Aviso($m) { [void]$avisos.Add($m) }

function Id-Questao([string]$enunciado) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($enunciado))
  $sha.Dispose()
  (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 10)
}

# ---- carrega -----------------------------------------------------------------

$arqMaterias = Join-Path $dir 'materias.json'
if (-not (Test-Path $arqMaterias)) {
  Write-Host "ERRO: banco/materias.json ausente"
  Write-Host "`nNão publicar."
  exit 1
}
$materias = [System.IO.File]::ReadAllText($arqMaterias, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$idsMateria = @{}
foreach ($m in $materias) { $idsMateria[$m.id] = $m.nome }

$B = @()
foreach ($m in $materias) {
  $arq = Join-Path $dir "$($m.id).json"
  if (-not (Test-Path $arq)) { Erro "arquivo ausente: banco/$($m.id).json"; continue }
  $qs = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  foreach ($q in $qs) {
    if ($q.m -ne $m.id) { Erro "[$($q.id)] está em banco/$($m.id).json mas diz pertencer a '$($q.m)'" }
  }
  $B += $qs
}
if ($erros.Count -gt 0 -or $B.Count -eq 0) {
  $erros | ForEach-Object { Write-Host "ERRO: $_" }
  Write-Host "`nNão publicar."
  exit 1
}

# ---- rascunho ----------------------------------------------------------------
# Candidatos entram no MESMO $B que o banco real, para que todas as checagens
# abaixo os alcancem sem precisar existir em duplicata. O id é calculado aqui
# porque o rascunho não traz id — é justamente o que se quer conferir: se o
# SHA-1 do enunciado colide com questão que já existe, a checagem de id
# duplicado acusa antes de a questão ser gravada.
$nRascunho = 0
if ($Rascunho) {
  $arqR = if ([System.IO.Path]::IsPathRooted($Rascunho)) { $Rascunho } else { Join-Path $raiz $Rascunho }
  if (-not (Test-Path $arqR)) { Write-Host "ERRO: rascunho não encontrado: $arqR"; exit 1 }
  $cands = [System.IO.File]::ReadAllText($arqR, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($null -eq $cands) { $cands = @() }
  foreach ($q in @($cands)) {
    if ($q.PSObject.Properties.Name -contains 'id' -and $q.id) {
      Erro "rascunho: questão não deve trazer 'id' — ele é calculado do enunciado ao incorporar"
    } else {
      $q | Add-Member -NotePropertyName id -NotePropertyValue (Id-Questao $q.q) -Force
    }
    $B += $q
    $nRascunho++
  }
  Write-Host "Rascunho: $nRascunho candidato(s) avaliados junto do banco (nada foi gravado)`n"
}

# arquivo de matéria que não está no materias.json passaria despercebido
foreach ($f in Get-ChildItem $dir -Filter '*.json') {
  $nome = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  if ($nome -in 'materias','indice-legado','reescritas','topicos') { continue }
  if (-not $idsMateria.ContainsKey($nome)) { Erro "banco/$($f.Name) não corresponde a nenhuma matéria de materias.json" }
}

# ---- questões ----------------------------------------------------------------

$vistos = @{}
$ids = @{}
foreach ($q in $B) {
  $rot = if ($q.id) { $q.id } else { '(sem id)' }
  foreach ($campo in 'id','m','t','q','o','c','e','f') {
    if ($null -eq $q.$campo) { Erro "[$rot] campo '$campo' ausente" }
  }
  if (-not $idsMateria.ContainsKey($q.m)) { Erro "[$rot] matéria inexistente: $($q.m)" }
  # o subtópico é opcional, mas quando existe não pode repetir o nome do tópico
  if ($q.s -and $q.s -eq $q.t) { Erro "[$rot] subtópico é cópia do tópico: '$($q.t)'" }
  if ($q.o.Count -ne 5)                  { Erro "[$rot] não tem exatamente 5 alternativas" }
  if ($q.c -isnot [int] -or $q.c -lt 0 -or $q.c -gt 4) { Erro "[$rot] índice da correta inválido: $($q.c)" }
  if (($q.o | Select-Object -Unique).Count -ne $q.o.Count) { Erro "[$rot] alternativas repetidas dentro da questão" }
  if ([string]::IsNullOrWhiteSpace($q.f)) { Erro "[$rot] sem fonte" }

  # o id precisa continuar derivando do enunciado, senão o progresso salvo
  # deixa de encontrar a questão
  $esperado = Id-Questao $q.q
  if ($q.id -ne $esperado) { Erro "[$rot] id não corresponde ao enunciado (esperado $esperado)" }

  if ($vistos.ContainsKey($q.q)) { Erro "[$rot] enunciado duplicado" }
  $vistos[$q.q] = $true
  if ($ids.ContainsKey($q.id))   { Erro "[$rot] id duplicado" }
  $ids[$q.id] = $true

  $texto = $q.q + ($q.o -join ' ') + $q.e
  if ($texto -match '(?i)destacad|grifad|sublinhad|em negrito') {
    Erro "[$rot] refere-se a formatação que não existe no texto puro"
  }
}

# ---- mapa de migração --------------------------------------------------------

$arqLegado = Join-Path $dir 'indice-legado.json'
if (-not (Test-Path $arqLegado)) {
  Erro "banco/indice-legado.json ausente — o progresso salvo por índice não seria migrado"
} else {
  $legado = [System.IO.File]::ReadAllText($arqLegado, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $orfaos = @($legado | Where-Object { -not $ids.ContainsKey($_) })
  if ($orfaos.Count -gt 0) {
    Erro "indice-legado.json aponta para $($orfaos.Count) id(s) que não existem mais no banco"
  }
  if ($legado.Count -ne $B.Count) {
    Aviso "indice-legado.json tem $($legado.Count) ids e o banco tem $($B.Count) questões (esperado se o banco cresceu depois da Fase 0)"
  }
}

# ---- vieses ------------------------------------------------------------------

# ---- concursos ---------------------------------------------------------------

$arqConcursos = Join-Path $raiz 'concursos.json'
if (-not (Test-Path $arqConcursos)) {
  Erro "concursos.json ausente — o app não tem como saber data, composição nem regra de aprovação"
} else {
  $cfg = [System.IO.File]::ReadAllText($arqConcursos, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  if (-not $cfg.concursos -or $cfg.concursos.Count -eq 0) { Erro "concursos.json não tem nenhum concurso" }
  foreach ($c in $cfg.concursos) {
    $rot = if ($c.id) { $c.id } else { '(sem id)' }
    foreach ($campo in 'id','cargo','data','blocos','aprovacao') {
      if ($null -eq $c.$campo) { Erro "concurso [$rot]: campo '$campo' ausente" }
    }
    if ($c.data -notmatch '^\d{4}-\d{2}-\d{2}$') { Erro "concurso [$rot]: data '$($c.data)' fora do formato AAAA-MM-DD" }
    $usadas = @{}
    foreach ($bl in $c.blocos) {
      if ($null -eq $bl.id -or $null -eq $bl.nome -or $null -eq $bl.questoes) {
        Erro "concurso [$rot]: bloco incompleto (precisa de id, nome e questoes)"
        continue
      }
      $disp = 0
      foreach ($mid in $bl.materias) {
        if (-not $idsMateria.ContainsKey($mid)) { Erro "concurso [$rot], bloco '$($bl.id)': matéria inexistente '$mid'"; continue }
        if ($usadas.ContainsKey($mid)) { Erro "concurso [$rot]: matéria '$mid' aparece em mais de um bloco" }
        $usadas[$mid] = $true
        $disp += @($B | Where-Object m -eq $mid).Count
      }
      if ($disp -lt $bl.questoes) {
        Aviso "concurso [$rot], bloco '$($bl.nome)': o banco tem $disp questões para $($bl.questoes) da prova"
      }
    }
    $total = ($c.blocos | Measure-Object -Property questoes -Sum).Sum
    if ($c.aprovacao.minimoTotal -gt $total) {
      Erro "concurso [$rot]: mínimo para aprovação ($($c.aprovacao.minimoTotal)) é maior que o total da prova ($total)"
    }
    $orfas = @($idsMateria.Keys | Where-Object { -not $usadas.ContainsKey($_) })
    if ($orfas.Count -gt 0) {
      Aviso "concurso [$rot]: $($orfas.Count) matéria(s) do banco não entram nesta prova ($($orfas -join ', '))"
    }
  }
}

# ---- resumo ------------------------------------------------------------------

Write-Host "`nBanco: $($B.Count) questões em $(@($materias).Count) matérias"
foreach ($m in $materias) {
  $qs = @($B | Where-Object m -eq $m.id)
  $tops = @($qs | Group-Object t)
  $subs = @($qs | Where-Object { $_.s } | Group-Object s)
  Write-Host ("  {0,4}q  {1,3} tópicos  {2,3} subtópicos   {3}" -f $qs.Count, $tops.Count, $subs.Count, $m.nome)
  foreach ($t in ($tops | Sort-Object Count -Descending)) {
    $ns = @($t.Group | Where-Object { $_.s } | Group-Object s).Count
    Write-Host ("        {0,4}  {1}{2}" -f $t.Count, $t.Name, $(if ($ns) { "  ($ns subtópicos)" } else { "" }))
  }
}
Write-Host "`nVieses:"

$difs = foreach ($q in $B) {
  $tam = @($q.o | ForEach-Object { $_.Length })
  $outros = @(for ($j = 0; $j -lt $tam.Count; $j++) { if ($j -ne $q.c) { $tam[$j] } })
  $tam[$q.c] - ($outros | Measure-Object -Maximum).Maximum
}
$n = $B.Count
$maisLonga = @($difs | Where-Object { $_ -gt 0 }).Count
$acima20   = @($difs | Where-Object { $_ -gt 20 }).Count
$acima40   = @($difs | Where-Object { $_ -gt 40 }).Count

Write-Host ("  correta é a mais longa:        {0}/{1} ({2:N1}%)   [ideal ~20%]" -f $maisLonga, $n, ($maisLonga / $n * 100))
Write-Host "  excede a 2ª maior em >20 char: $acima20"
Write-Host "  excede em >40 char:            $acima40"

# Linha de base do 3º passe: zero questão acima de 20 chars de folga.
if ($acima40 -gt 0) { Erro "viés de comprimento regrediu: há questão excedendo a 2ª maior em +40 chars (linha de base: 0)" }
if ($acima20 -gt 0) { Erro "viés de comprimento regrediu: há questão excedendo a 2ª maior em +20 chars (linha de base: 0)" }
if ($maisLonga -gt 240) { Aviso "'correta é a mais longa' subiu para $maisLonga (linha de base: 228, todas com folga <= 10 chars)" }

# A pista só é explorável quando existe UMA alternativa visivelmente mais longa.
$comPista = 0; $acertos = 0
foreach ($q in $B) {
  $tam = @($q.o | ForEach-Object { $_.Length })
  $ord = @($tam | Sort-Object -Descending)
  if ($ord[0] - $ord[1] -gt 10) {
    $comPista++
    if ([array]::IndexOf($tam, $ord[0]) -eq $q.c) { $acertos++ }
  }
}
$taxa = if ($comPista) { $acertos / $comPista * 100 } else { 0.0 }
Write-Host ("  pista 'mais longa' existe em:  {0} questões; acerta {1:N1}%   [acaso 20%]" -f $comPista, $taxa)
if ($taxa -gt 40) { Erro ("chutar na alternativa mais longa acerta {0:N1}% das vezes (acaso = 20%)" -f $taxa) }

# ---- app ---------------------------------------------------------------------

$fonte = [System.IO.File]::ReadAllText((Join-Path $raiz 'index.html'), [System.Text.Encoding]::UTF8)
if ($fonte -notmatch 'embaralhaOrdem') {
  Erro "função embaralhaOrdem ausente — o viés de posição da correta volta a valer"
}
if ($fonte -match 'const BANCO = \[') {
  Erro "index.html ainda tem o array BANCO embutido — o banco agora vive em banco/*.json"
}

$sw = [System.IO.File]::ReadAllText((Join-Path $raiz 'sw.js'), [System.Text.Encoding]::UTF8)
if ($sw -match 'const VERSAO = "([^"]+)"') {
  Write-Host "  versão do service worker:      $($Matches[1])"
  Aviso "confirme que a VERSAO ($($Matches[1])) mudou desde a última publicação"
  # os arquivos de matéria entram no cache a partir do materias.json, então
  # basta conferir os fixos
  foreach ($a in 'concursos.json','supabase.json','banco/materias.json','banco/indice-legado.json') {
    if ($sw -notmatch [regex]::Escape($a)) { Erro "sw.js não guarda $a no cache" }
  }
} else {
  Erro "VERSAO não encontrada em sw.js"
}

# ---- configuração do Supabase -------------------------------------------------
$arqSupa = Join-Path $raiz 'supabase.json'
if (-not (Test-Path $arqSupa)) {
  Erro "supabase.json ausente — a Fase 3b lê a URL e a chave anon dali"
} else {
  try {
    $supa = [System.IO.File]::ReadAllText($arqSupa, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $supa.url -or -not $supa.anonKey) { Erro "supabase.json precisa dos campos 'url' e 'anonKey'" }
    elseif ($supa.url -match 'SEU-PROJETO') { Erro "supabase.json ainda tem a URL de exemplo — como o login é obrigatório, publicar assim tranca todo mundo pra fora do app" }
  } catch { Erro "supabase.json não é JSON válido" }
}

Aviso "a sintaxe do JS do index.html não é conferida aqui (exige Node); use validar.py numa máquina com Node instalado"

# ---- chave secreta do Supabase -----------------------------------------------
# A chave pública (anon / sb_publishable_...) pode ficar no repositório; a
# secreta (service_role / sb_secret_...) ignora toda a RLS e daria acesso ao
# progresso de todo mundo. Dois formatos de chave circulam por aí:
#   - antigo: as duas são JWT (começam com "eyJ") e só dá para distinguir
#     decodificando o miolo, onde vem "role":"service_role" ou "role":"anon";
#   - novo (2024+): prefixo já denuncia — "sb_secret_..." vs "sb_publishable_...".
# Este guarda-corpo existe porque o erro é fácil de cometer (as duas ficam
# lado a lado no painel) e silencioso — já aconteceu de colar a errada aqui
# no chat achando que era a pública.
function Papel-DoJwt([string]$jwt) {
  $partes = $jwt.Split('.')
  if ($partes.Count -lt 2) { return '' }
  $p = $partes[1].Replace('-', '+').Replace('_', '/')
  switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
  try { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) } catch { '' }
}

$aVarrer = Get-ChildItem $raiz -Recurse -File -Include '*.html','*.js','*.json','*.ps1','*.py','*.sql','*.md' |
           Where-Object { $_.FullName -notlike "*\banco\*" -and $_.Name -ne 'offline.html' }
foreach ($f in $aVarrer) {
  $texto = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)

  # formato novo: o prefixo já diz o que é
  foreach ($m in [regex]::Matches($texto, 'sb_secret_[A-Za-z0-9_-]{10,}')) {
    Erro "chave secreta do Supabase (sb_secret_...) encontrada em $($f.Name) — ela ignora a RLS; use a sb_publishable_ e regenere esta no painel"
  }

  # formato antigo: JWT, precisa decodificar pra saber o papel
  foreach ($m in [regex]::Matches($texto, 'eyJ[A-Za-z0-9_-]{5,}\.eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}')) {
    if ((Papel-DoJwt $m.Value) -match 'service_role') {
      Erro "chave service_role do Supabase encontrada em $($f.Name) — ela ignora a RLS; use a chave anon e revogue esta no painel"
    }
  }
}

# offline.html é gerado a partir do index.html e do banco: se ficar para trás,
# o arquivo que se leva no pendrive não é o app que está no disco
$arqOffline = Join-Path $raiz 'offline.html'
if (Test-Path $arqOffline) {
  $geradoEm = (Get-Item $arqOffline).LastWriteTimeUtc
  $fontes = @((Join-Path $raiz 'index.html'), (Join-Path $raiz 'concursos.json')) +
            (Get-ChildItem $dir -Filter '*.json' | ForEach-Object { $_.FullName })
  $novas = @($fontes | Where-Object { (Get-Item $_).LastWriteTimeUtc -gt $geradoEm } |
             ForEach-Object { Split-Path $_ -Leaf })
  if ($novas.Count -gt 0) {
    Aviso "offline.html está desatualizado ($($novas.Count) arquivo(s) mudaram depois: $($novas -join ', ')). Rode gerar-offline.ps1"
  }
}

# ---- saída -------------------------------------------------------------------

Write-Host ""
$avisos | ForEach-Object { Write-Host "aviso: $_" }
if ($erros.Count -gt 0) {
  $erros | Select-Object -First 40 | ForEach-Object { Write-Host "ERRO: $_" }
  if ($erros.Count -gt 40) { Write-Host "... e mais $($erros.Count - 40) erros" }
  Write-Host "`n$($erros.Count) erro(s). Não publicar."
  exit 1
}
Write-Host "Sem erros. Pode publicar."
