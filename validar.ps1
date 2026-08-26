# Verifica a integridade do banco de questões e mede os vieses estatísticos.
#
# Equivalente ao validar.py, para máquinas sem Python. Roda em Windows
# PowerShell 5.1 sem nada instalado.
#
#   powershell -ExecutionPolicy Bypass -File validar.ps1
#   powershell -ExecutionPolicy Bypass -File validar.ps1 -Rascunho banco/rascunho.json
#   powershell -ExecutionPolicy Bypass -File validar.ps1 -Patches explicacoes.json
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
# -Patches é o mesmo princípio pra EDITAR em vez de acrescentar: aplica 'eo'
# (explicação por alternativa) em memória sobre cartão que já existe no banco,
# casando por id, sem gravar nada. Quem grava é o explicar-alternativas.ps1,
# só depois disto passar limpo.
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam ser gravados em UTF-8
# COM BOM, senão o PowerShell 5.1 os lê como ANSI e o parser quebra.

param(
  [string]$Rascunho,
  [string]$Patches
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

# Matérias que algum concurso referencia em blocos[].materias, MAIS as
# marcadas "avulsa": true em banco/materias.json — as duas são "alguém
# consegue estudar hoje", só que por caminhos diferentes (concurso inscrito,
# ou E.materiasAvulsas sem concurso nenhum — ver CLAUDE.md "Matéria, tópico e
# subtópico"). A UI de matéria avulsa lista TODAS as matérias do arquivo, mas
# isso sozinho não abre a porta de ESCREVER cartão novo — sem o flag, "ativa"
# viraria todo mundo e a regra 12 perderia sentido. Matéria fora das duas
# listas continua no repositório de propósito (regra 12); o que não se faz é
# ESCREVER cartão novo para ela.
$ativas = @{}
$arqConc = Join-Path $raiz 'concursos.json'
if (Test-Path $arqConc) {
  $cfgAtivas = [System.IO.File]::ReadAllText($arqConc, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  foreach ($c in $cfgAtivas.concursos) {
    foreach ($bl in $c.blocos) {
      foreach ($mid in $bl.materias) { $ativas[$mid] = $true }
    }
  }
}
foreach ($m in $materias) { if ($m.avulsa) { $ativas[$m.id] = $true } }

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
    # Cartão novo só entra em matéria que alguém pode estudar hoje. A regra é
    # sobre ESCREVER, não sobre guardar: o banco de matéria sem concurso ativo
    # nem avulsa declarada fica intacto (regra 12), mas escrever mais para ela
    # é trabalho que ninguém vê — enquanto matéria ativa tem item de edital
    # sem cartão nenhum.
    if ($q.m -and $ativas.Count -gt 0 -and -not $ativas.ContainsKey($q.m)) {
      Erro "rascunho: matéria '$($q.m)' não é referenciada por nenhum concurso de concursos.json nem marcada `"avulsa`": true em banco/materias.json — cartão novo só entra em matéria ativa (regra 12). Se o concurso vai voltar, cadastre-o primeiro; se é conteúdo avulso de propósito, marque `"avulsa`": true na matéria"
    }
    $B += $q
    $nRascunho++
  }
  Write-Host "Rascunho: $nRascunho candidato(s) avaliados junto do banco (nada foi gravado)`n"
}

# ---- patches (eo, n, o e/ou s em cartão existente) ----------------------------
# Mesma ideia do rascunho, mas para EDITAR em vez de acrescentar: aplica os
# campos que não entram no id ('eo', explicação por alternativa, 'n', nível do
# cartão dentro do tópico, 'o', as alternativas, e 's', subtópico) em memória
# sobre a questão já carregada em $B, casando por id, antes de qualquer
# checagem abaixo rodar. Quem grava é o explicar-alternativas.ps1.
#
# Campo AUSENTE no patch não pode ser aplicado: aplicar 'eo' vazio sobre um
# cartão que só quer receber 'n' apagaria a explicação por alternativa e ainda
# reprovaria na checagem de tamanho de 'eo'. Espelha carrega_patches do
# validar.py — as duas implementações precisam concordar, senão o script grava
# com base numa validação diferente da que o validar.py fez.
#
# 'o' carrega o risco que 'eo' e 'n' não têm: 'c' é o ÍNDICE da correta, não o
# texto. Patch que reordene as alternativas trocaria a resposta certa sem
# aparecer no diff. Por isso a correta tem de vir idêntica e na mesma posição —
# a mesma regra do validar.py, e ela é o que restringe o patch de 'o' a fazer
# só o que a seção de viés do CLAUDE.md manda: mexer em DISTRATOR.
$nPatches = 0
if ($Patches) {
  $arqP = if ([System.IO.Path]::IsPathRooted($Patches)) { $Patches } else { Join-Path $raiz $Patches }
  if (-not (Test-Path $arqP)) { Write-Host "ERRO: patches não encontrado: $arqP"; exit 1 }
  $porId = @{}
  foreach ($q in $B) { $porId[$q.id] = $q }
  $pats = [System.IO.File]::ReadAllText($arqP, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($null -eq $pats) { $pats = @() }
  foreach ($p in @($pats)) {
    if (-not $porId.ContainsKey($p.id)) { Erro "patches: id '$($p.id)' não existe no banco"; continue }
    $campos = $p.PSObject.Properties.Name
    if ($campos -notcontains 'eo' -and $campos -notcontains 'n' -and $campos -notcontains 'o' -and $campos -notcontains 's' `
        -and $campos -notcontains 'c' -and $campos -notcontains 'e' -and $campos -notcontains 't') {
      Erro "patches: id '$($p.id)' não traz 'eo', 'n', 'o', 's', 'c', 'e' nem 't' — nada a aplicar"; continue
    }
    $falhou = $false
    if ($campos -contains 'o') {
      $atual = @($porId[$p.id].o); $novo = @($p.o)
      if ($novo.Count -ne $atual.Count) {
        Erro "patches: id '$($p.id)': 'o' precisa ter as mesmas $($atual.Count) alternativas (veio $($novo.Count))"; $falhou = $true
      } elseif ($campos -notcontains 'c') {
        $ci = [int]$porId[$p.id].c
        if ($novo[$ci] -ne $atual[$ci]) {
          Erro "patches: id '$($p.id)': a alternativa correta (índice $ci) mudou de texto ou de posição — patch de 'o' sem 'c' só pode reescrever distrator, nunca a correta"; $falhou = $true
        }
      }
      if (-not $falhou) { $porId[$p.id] | Add-Member -NotePropertyName o -NotePropertyValue $novo -Force }
    }
    if ($falhou) { continue }
    if ($campos -contains 'c') {
      $oFinal = @($porId[$p.id].o)
      $novoC = $p.c
      if ($novoC -isnot [int] -or $novoC -lt 0 -or $novoC -ge $oFinal.Count) {
        Erro "patches: id '$($p.id)': 'c' precisa ser um índice inteiro entre 0 e $($oFinal.Count - 1)"; continue
      }
      if ($campos -notcontains 'e') {
        Erro "patches: id '$($p.id)': patch de 'c' precisa vir junto com 'e' — a explicação antiga não justifica a resposta nova"; continue
      }
      $porId[$p.id] | Add-Member -NotePropertyName c -NotePropertyValue ([int]$novoC) -Force
    }
    if ($campos -contains 'e') {
      $porId[$p.id] | Add-Member -NotePropertyName e -NotePropertyValue ([string]$p.e) -Force
    }
    if ($campos -contains 't') {
      if (-not $p.t -or -not ([string]$p.t).Trim()) {
        Erro "patches: id '$($p.id)': 't' não pode ser vazio"; continue
      }
      $porId[$p.id] | Add-Member -NotePropertyName t -NotePropertyValue ([string]$p.t) -Force
    }
    if ($campos -contains 'eo') {
      $porId[$p.id] | Add-Member -NotePropertyName eo -NotePropertyValue @($p.eo) -Force
    }
    if ($campos -contains 'n') {
      $porId[$p.id] | Add-Member -NotePropertyName n -NotePropertyValue ([int]$p.n) -Force
    }
    if ($campos -contains 's') {
      $porId[$p.id] | Add-Member -NotePropertyName s -NotePropertyValue ([string]$p.s) -Force
    }
    $nPatches++
  }
  Write-Host "Patches: $nPatches de $(@($pats).Count) aplicado(s) em memória (nada foi gravado)`n"
}

# arquivo de matéria que não está no materias.json passaria despercebido.
# 'requisitos' entra na lista de arquivos de sistema como 'topicos': o conteúdo
# dele é conferido pelo validar.py (valida_requisitos), o validador mais completo;
# aqui basta não acusá-lo de matéria órfã, senão o incorporar-rascunho.ps1
# passaria a falhar sem ter nada a ver com o cartão sendo gravado.
foreach ($f in Get-ChildItem $dir -Filter '*.json') {
  $nome = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  if ($nome -in 'materias','indice-legado','reescritas','topicos','requisitos') { continue }
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

  # 'eo' é opcional (explicação por alternativa, ver PADRAO-DOS-CARTOES.md
  # seção 1.4.1) — quando existe, precisa cobrir toda alternativa em posição
  # (vazio = "sem nota pra esta", não elemento faltando)
  if ($null -ne $q.eo) {
    if ($q.eo.Count -ne $q.o.Count) {
      Erro "[$rot] 'eo' precisa ter o mesmo tamanho de 'o' — uma posição por alternativa (string vazia pula, mas a posição tem que existir)"
    } elseif (-not ($q.eo | Where-Object { $_ -and $_.Trim() -ne '' })) {
      Erro "[$rot] 'eo' está presente mas vazio em todas as alternativas — tire o campo se nenhuma vai ser preenchida"
    }
  }

  # o id precisa continuar derivando do enunciado, senão o progresso salvo
  # deixa de encontrar a questão
  $esperado = Id-Questao $q.q
  if ($q.id -ne $esperado) { Erro "[$rot] id não corresponde ao enunciado (esperado $esperado)" }

  if ($vistos.ContainsKey($q.q)) { Erro "[$rot] enunciado duplicado" }
  $vistos[$q.q] = $true
  if ($ids.ContainsKey($q.id))   { Erro "[$rot] id duplicado" }
  $ids[$q.id] = $true

  $texto = $q.q + ($q.o -join ' ') + $q.e + (($q.eo | Where-Object { $_ }) -join ' ')
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
      # Escopo de tópicos do bloco (opcional): restringe quais tópicos da
      # matéria caem NESTE concurso. Tópico escrito errado aqui não daria erro
      # visível — só sumiria silenciosamente da sessão de estudo, que é pior.
      if ($bl.topicos) {
        $doBloco = @($B | Where-Object { $bl.materias -contains $_.m })
        $existentes = @($doBloco | Select-Object -ExpandProperty t -Unique)
        foreach ($t in $bl.topicos) {
          if ($existentes -notcontains $t) {
            Erro "concurso [$rot], bloco '$($bl.id)': tópico '$t' não existe no banco das matérias deste bloco"
          }
        }
        if (@($bl.topicos | Select-Object -Unique).Count -ne @($bl.topicos).Count) {
          Erro "concurso [$rot], bloco '$($bl.id)': tópico repetido na lista de escopo"
        }
        $dispEscopo = @($doBloco | Where-Object { $bl.topicos -contains $_.t }).Count
        if ($dispEscopo -lt $bl.questoes) {
          Aviso "concurso [$rot], bloco '$($bl.nome)': dentro do escopo declarado há $dispEscopo questões para $($bl.questoes) da prova"
        }
        $disp = $dispEscopo
      }
      if ($disp -lt $bl.questoes) {
        Aviso "concurso [$rot], bloco '$($bl.nome)': o banco tem $disp questões para $($bl.questoes) da prova"
      }
    }
    $total = ($c.blocos | Measure-Object -Property questoes -Sum).Sum
    if ($c.aprovacao.minimoTotal -gt $total) {
      Erro "concurso [$rot]: mínimo para aprovação ($($c.aprovacao.minimoTotal)) é maior que o total da prova ($total)"
    }
  }
  # Uma linha só para o banco inteiro, em vez de uma por concurso repetindo tudo
  # que não cai naquela prova — o que interessa é quem não cai em prova NENHUMA
  # e não é avulsa declarada: é a matéria em que não se escreve cartão novo
  # (regra 12).
  $inativas = @($idsMateria.Keys | Where-Object { -not $ativas.ContainsKey($_) })
  if ($inativas.Count -gt 0) {
    $detalhe = ($inativas | ForEach-Object {
      $mid = $_
      "$mid ($(@($B | Where-Object { $_.m -eq $mid }).Count) cartões)"
    }) -join ', '
    Aviso "$($inativas.Count) matéria(s) sem concurso ativo nem avulsa declarada, mantidas pela regra 12 — não escrever cartão novo para elas: $detalhe"
  }
}

# ---- redundância (princípio 1.5 do PADRAO-DOS-CARTOES) -----------------------
# Dois cartões que cobram o MESMO FATO competem entre si: a pessoa decora a
# diferença superficial e o Leitner gasta duas revisões para fixar uma
# informação. O difícil é detectar isso sem afogar em falso positivo.
#
# Medido no banco de 946 questões antes de escolher os limiares:
#   - "mesma resposta correta" sozinho: 10 pares, TODOS legítimos (sen 30° e
#     cos 60° valem 1/2; atropina é antídoto de organofosforado E droga da
#     bradicardia). Sozinho, é 100% ruído — não serve de regra.
#   - "enunciado parecido" sozinho: fórmula repetida de enunciado é boa prática
#     ("regência do verbo assistir/visar/aspirar"), não defeito.
# O que sobra é a COMBINAÇÃO, que hoje não acontece nenhuma vez. Por isso é
# aviso e não erro: quando dispara, merece olhar humano; nunca deve incomodar.
$VAZIAS = @{}
foreach ($p in @('a','o','as','os','um','uma','de','do','da','dos','das','em','no','na','nos','nas',
                 'e','ou','que','com','para','por','ao','aos','se','sua','seu','suas','seus','qual',
                 'é','ser','não','sobre','entre','como','mais','menos','pelo','pela','pelos','pelas')) { $VAZIAS[$p] = $true }

function Tokens-De([string]$t) {
  # Número NUNCA é descartado por tamanho, mesmo com 1 ou 2 dígitos: em
  # questão de aritmética (tabuada, cálculo) é o número que distingue um
  # fato do outro -- "3 × 4" e "3 × 8" só diferem no número. Cortá-los pela
  # mesma regra de tamanho das palavras (>2 caracteres) fazia toda questão
  # de Tabuada colapsar no mesmo token só ("quanto"), tratando 56 fatos
  # aritméticos diferentes como se fossem a mesma pergunta repetida —
  # descoberto ao rodar contra o banco depois da Tabuada entrar (1553
  # avisos numa leva de 5 candidatos sem nenhuma relação com ela).
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($p in (($t.ToLower() -replace '[^\p{L}\p{Nd}\s]', ' ') -split '\s+')) {
    if ($p.Length -eq 0) { continue }
    $ehNumero = $p -match '^\d+$'
    if ($ehNumero -or ($p.Length -gt 2 -and -not $VAZIAS.ContainsKey($p))) { [void]$set.Add($p) }
  }
  $set
}
# caixa, pontuação e espaço não distinguem um fato de outro
function Norm-Resp([string]$t) { (($t.ToLower() -replace '[^\p{L}\p{Nd}\s]', '') -replace '\s+', ' ').Trim() }

$meta = @{}
foreach ($q in $B) { $meta[$q.id] = @{ tok = (Tokens-De $q.q); cor = (Norm-Resp $q.o[$q.c]) } }

foreach ($g in ($B | Group-Object { "$($_.m)|$($_.t)" })) {
  $it = @($g.Group)
  for ($i = 0; $i -lt $it.Count; $i++) {
    for ($j = $i + 1; $j -lt $it.Count; $j++) {
      $ta = $meta[$it[$i].id].tok; $tb = $meta[$it[$j].id].tok
      if ($ta.Count -eq 0 -or $tb.Count -eq 0) { continue }
      $inter = 0
      foreach ($x in $ta) { if ($tb.Contains($x)) { $inter++ } }
      $uniao = $ta.Count + $tb.Count - $inter
      if ($uniao -eq 0) { continue }
      $sim = [double]$inter / $uniao
      $mesmaResp = $meta[$it[$i].id].cor -eq $meta[$it[$j].id].cor

      if ($sim -ge 0.85 -and $mesmaResp) {
        Aviso ("redundância provável [$($it[$i].id)] e [$($it[$j].id)]: enunciados {0:N0}% parecidos E mesma resposta certa. Testam o mesmo fato? Ver princípio 1.5" -f ($sim * 100))
      } elseif ($sim -ge 0.90) {
        Aviso ("[$($it[$i].id)] e [$($it[$j].id)]: enunciados {0:N0}% parecidos (respostas diferentes). Confirme que o fato cobrado é outro" -f ($sim * 100))
      }
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

# ...e a MESMA conta por matéria, que é onde ela significa alguma coisa. O
# número do banco inteiro é média de coisas opostas e engana: já esteve em 18%
# — dentro do acaso — com TODA matéria ativa em 0% e as duas inativas em 59%.
# Zero por cento não é neutro, é a pista invertida ("a mais longa nunca é a
# certa"). Espelha mede_vies do validar.py; as duas precisam concordar.
$pistaM = @{}; $acertoM = @{}
foreach ($q in $B) {
  $tam = @($q.o | ForEach-Object { $_.Length })
  $ord = @($tam | Sort-Object -Descending)
  if ($ord[0] - $ord[1] -gt 10) {
    $pistaM[$q.m] = 1 + $(if ($pistaM.ContainsKey($q.m)) { $pistaM[$q.m] } else { 0 })
    if ([array]::IndexOf($tam, $ord[0]) -eq $q.c) {
      $acertoM[$q.m] = 1 + $(if ($acertoM.ContainsKey($q.m)) { $acertoM[$q.m] } else { 0 })
    }
  }
}
Write-Host "  por matéria (só as com 20+ questões de pista):"
foreach ($mid in ($pistaM.Keys | Sort-Object)) {
  $p = $pistaM[$mid]
  if ($p -lt 20) { continue }
  $a = if ($acertoM.ContainsKey($mid)) { $acertoM[$mid] } else { 0 }
  $r = $a / $p * 100
  $flag = if ($r -ge 5 -and $r -le 40) { '' } else { '  <-- fora da faixa' }
  Write-Host ("    {0,-22} {1,3}/{2,-4} {3,5:N1}%{4}" -f $mid, $a, $p, $r, $flag)
  if (-not $ativas.ContainsKey($mid)) { continue }
  if ($r -gt 40) {
    Erro ("{0}: a alternativa mais longa é a correta em {1:N1}% das {2} questões com pista (acaso = 20%)" -f $mid, $r, $p)
  } elseif ($r -lt 5) {
    Aviso ("{0}: a mais longa quase nunca é a correta ({1} de {2}) — pista invertida, dá pra eliminar uma alternativa de graça. Corrigir enxugando o distrator que se destaca, não alongando a correta" -f $mid, $a, $p)
  }
}

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
