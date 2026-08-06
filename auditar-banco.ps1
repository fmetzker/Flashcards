# Mede o banco contra o padrão de METODOLOGIA.md.
#
# Equivalente ao auditar-banco.py, para máquinas sem Python (a mesma razão
# pela qual validar.ps1 existe ao lado de validar.py).
#
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1 -Listar
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1 -Csv saida.csv
#
# Diferente do validar.ps1, este script NÃO reprova nada e sempre sai com 0:
# ele mede qualidade, que é gradiente, não regra. A saída serve para decidir o
# que reescrever primeiro — não para barrar publicação.
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam ser gravados em UTF-8
# COM BOM, senão o PowerShell 5.1 os lê como ANSI e o parser quebra.

param(
  [switch]$Listar,
  [string]$Csv
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'

# ---- carrega -----------------------------------------------------------------

$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$nomes = @{}
foreach ($m in $materias) { $nomes[$m.id] = $m.nome }

$B = @()
foreach ($m in $materias) {
  $arq = Join-Path $dir "$($m.id).json"
  if (Test-Path $arq) {
    $B += [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  }
}

# ---- verificações ------------------------------------------------------------
# Cada uma devolve o motivo (string) ou $null se a questão passa.

# 1.1 — recordação ativa: o enunciado precisa ser respondível sozinho.
# Enunciado que só diz "assinale a correta sobre X" transfere a pergunta
# inteira para as alternativas, e aí o que se mede é reconhecimento.
function Test-SemPergunta($q) {
  $e = $q.q.Trim()
  $vagos = @(
    'assinale a (alternativa )?(correta|incorreta|verdadeira|falsa)\s*[.:]?$',
    '^sobre .{0,60},? (assinale|marque|indique)',
    '(é|está) correto afirmar( que)?\s*[.:]?$',
    '^(considere|analise) as (afirmativas|assertivas|proposições)'
  )
  foreach ($p in $vagos) {
    if ($e -match "(?i)$p") { return 'enunciado não é pergunta respondível sem as alternativas' }
  }
  return $null
}

# 2 — "todas as anteriores" e combinatórias tipo "apenas I e III"
function Test-AlternativaLixo($q) {
  $ruins = @()
  foreach ($a in $q.o) {
    $al = $a.Trim()
    if ($al -match '(?i)(todas|nenhuma) (as|das) (anteriores|alternativas|afirmativas)') { $ruins += $a }
    elseif ($al -match '(?i)^(apenas|somente)\s+([ivx]+|\d)(\s*(,|e)\s*([ivx]+|\d))*\.?$') { $ruins += $a }
  }
  if ($ruins.Count -gt 0) {
    return 'alternativa de formato proibido: ' + (($ruins | Select-Object -First 2) -join ' | ')
  }
  return $null
}

# 1.2 — um fato por cartão. Comprimento não prova que há vários fatos, mas é o
# melhor indício automático. Limiar alto de propósito: só os casos gritantes.
function Test-EnunciadoLongo($q) {
  $n = $q.q.Length
  if ($n -gt 400) { return "enunciado com $n caracteres (provável mais de um fato)" }
  return $null
}

# 2 — "assinale a INCORRETA". Não é erro, é custo: só vale quando a própria
# banca cobra assim. Listado para revisão, não como defeito.
function Test-Negativa($q) {
  if ($q.q -match '(?i)\b(incorret|excet|não\s+(é|são|deve|corresponde|faz)|falsa)\w*\b') {
    return 'enunciado por negativa'
  }
  return $null
}

# 1.4 — a explicação precisa dizer POR QUE.
#
# O limiar de comprimento sozinho gera falso positivo: "15 x 60 = 900 mg" e
# "'A fim de' introduz finalidade" são curtas E completas — em cálculo e em
# definição direta, a explicação curta é a explicação inteira. Por isso o
# comprimento só acusa quando a explicação também NÃO tem sinal de raciocínio
# (conta, ou conectivo de causa).
function Test-ExplicacaoFraca($q) {
  $e = $q.e.Trim()
  if ($e -match '(?i)^(a )?(alternativa|opção|letra)\s+[a-e]\b') { return 'explicação só aponta a letra, não explica' }
  $temRaciocinio = $e -match '\d\s*[x*×÷/+=-]\s*\d' -or
                   $e -match '(?i)\b(porque|pois|já que|logo|portanto|ou seja|isto é|significa|indica|introduz|caracteriza|define)\b'
  if ($e.Length -lt 40 -and -not $temRaciocinio) {
    return "explicação com $($e.Length) caracteres e sem raciocínio explícito"
  }
  return $null
}

# 1.3 — distrator plausível. Distrator drasticamente mais curto que a correta
# costuma ser preenchimento ("Nunca", "Apenas X"), que ninguém marcaria por
# engano de verdade.
function Test-DistratorCurto($q) {
  $correta = $q.o[$q.c].Length
  $curtos = @()
  for ($i = 0; $i -lt $q.o.Count; $i++) {
    if ($i -eq $q.c) { continue }
    if (($q.o[$i].Length * 3) -lt $correta -and $q.o[$i].Length -lt 25) { $curtos += $q.o[$i] }
  }
  if ($curtos.Count -gt 0) {
    return 'distrator curto demais para ser plausível: ' + (($curtos | Select-Object -First 2) -join ' | ')
  }
  return $null
}

$VERIFICACOES = @(
  @{ chave='sem-pergunta';     fn=${function:Test-SemPergunta};     grav='ALTO'  },
  @{ chave='alternativa-lixo'; fn=${function:Test-AlternativaLixo}; grav='ALTO'  },
  @{ chave='explicacao-fraca'; fn=${function:Test-ExplicacaoFraca}; grav='ALTO'  },
  @{ chave='distrator-curto';  fn=${function:Test-DistratorCurto};  grav='MÉDIO' },
  @{ chave='enunciado-longo';  fn=${function:Test-EnunciadoLongo};  grav='MÉDIO' },
  @{ chave='negativa';         fn=${function:Test-Negativa};        grav='BAIXO' }
)

# ---- roda --------------------------------------------------------------------

$achados = New-Object System.Collections.ArrayList
foreach ($q in $B) {
  foreach ($v in $VERIFICACOES) {
    $motivo = & $v.fn $q
    if ($motivo) {
      [void]$achados.Add([pscustomobject]@{
        id = $q.id; materia = $q.m; topico = $q.t
        verificacao = $v.chave; gravidade = $v.grav; motivo = $motivo
      })
    }
  }
}

# ---- relatório ---------------------------------------------------------------

Write-Host "Banco: $($B.Count) questões`n"
Write-Host ("=" * 66)
Write-Host "ADERÊNCIA AO PADRÃO (METODOLOGIA.md)"
Write-Host ("=" * 66)

foreach ($v in $VERIFICACOES) {
  $n = @($achados | Where-Object verificacao -eq $v.chave).Count
  $pct = if ($B.Count) { $n / $B.Count * 100 } else { 0 }
  Write-Host ("  [{0,-5}] {1,-18} {2,4} questões ({3:N1}%)" -f $v.grav, $v.chave, $n, $pct)
}

$afetadas = @($achados | Select-Object -ExpandProperty id -Unique).Count
$limpas = $B.Count - $afetadas
Write-Host ""
Write-Host ("  questões com ao menos um apontamento: {0} de {1} ({2:N1}%)" -f $afetadas, $B.Count, ($afetadas/$B.Count*100))
Write-Host ("  questões sem nenhum apontamento:      {0} ({1:N1}%)" -f $limpas, ($limpas/$B.Count*100))

Write-Host "`n  por matéria (só gravidade ALTA):"
foreach ($m in $materias) {
  $total = @($B | Where-Object m -eq $m.id).Count
  if (-not $total) { continue }
  $n = @($achados | Where-Object { $_.materia -eq $m.id -and $_.gravidade -eq 'ALTO' }).Count
  Write-Host ("    {0,-42} {1,4} de {2}" -f $m.nome, $n, $total)
}

Write-Host "`n$("=" * 66)"
Write-Host "COBERTURA — os 12 tópicos com menos cartões"
Write-Host ("=" * 66)
$B | Group-Object { $_.m + '|' + $_.t } | Sort-Object Count |
  Select-Object -First 12 | ForEach-Object {
    $partes = $_.Name -split '\|'
    $nomeM = $nomes[$partes[0]]
    if ($nomeM.Length -gt 28) { $nomeM = $nomeM.Substring(0,28) }
    Write-Host ("  {0,4}  {1,-28}  {2}" -f $_.Count, $nomeM, $partes[1])
  }

if ($Listar) {
  Write-Host "`n$("=" * 66)"
  Write-Host "APONTAMENTOS (gravidade ALTA)"
  Write-Host ("=" * 66)
  $achados | Where-Object gravidade -eq 'ALTO' | Sort-Object materia, topico | ForEach-Object {
    $m = $_.motivo
    if ($m.Length -gt 110) { $m = $m.Substring(0,110) }
    Write-Host "  [$($_.id)] $($_.materia)/$($_.topico)"
    Write-Host "        $($_.verificacao): $m"
  }
}

if ($Csv) {
  $achados | Export-Csv -Path $Csv -NoTypeInformation -Encoding UTF8
  Write-Host "`nCSV gravado em $Csv ($($achados.Count) linhas)"
}

Write-Host "`nEste script mede, não reprova. Ver METODOLOGIA.md para o padrão."
