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
# Este lote quebra os quatro cartões "julgue os itens I a VI" de Português —
# 4 a 6 fatos num cartão só, o que o §1.2 proíbe: errar não diz QUAL dos
# seis a pessoa não sabia, e o Leitner devolve os seis para a caixa 1. Dois
# deles ainda citavam "o texto" sem que texto nenhum estivesse no cartão.
#
# Cada original é reescrito aqui como o PRIMEIRO fato da família (preserva o
# progresso de quem já estudou, regra 5); os demais fatos entram como cartões
# novos por rascunho.json + incorporar-rascunho.ps1. O `t` de cada um é o que
# já era: este script não troca matéria nem tópico.
#
# Cinco itens dos originais foram DESCARTADOS em vez de virarem cartão, por
# não serem defensáveis com a fonte em mãos:
#   - 8ffa1e3d3a IV ("fabricação/manutenção/construção/participação são
#     substantivos abstratos") — a própria explicação do cartão dizia que a
#     classificação era "imprecisa"; cartão não se escreve sobre dúvida.
#   - 8ffa1e3d3a V ("interesse" por derivação regressiva) — a etimologia é
#     disputada, e a fonte não resolve a disputa.
#   - 2727068f49 V ("cinco das palavras citadas são substantivos") — contar
#     palavras não é fato de língua, é aritmética sobre o enunciado.
#   - b9ae6e00ea B ("uma vez que" com valor de tempo) — com o verbo no
#     subjuntivo ("entre em vigor"), a leitura temporal/condicional é a
#     natural; afirmar que só a causal vale seria ensinar errado.
#   - b9ae6e00ea C ("caso" como conjunção condicional em "Caso pertinente")
#     — ali "caso" lê-se como substantivo ("caso pertinente"), e o cartão
#     dependeria de um texto que não foi localizado.

$REESCRITAS = @{
  '62bfda28ba' = @{
    q = 'Em “E toda vez que o Sol se punha ela chorava lágrimas de chuva”, a pontuação está incompleta. O que falta?'
    o = @(
      'Vírgula depois de “punha”, isolando a oração adverbial deslocada.'
      'Vírgula depois de “E”, isolando o conectivo no início do período.'
      'Vírgula depois de “chorava”, separando o verbo do seu complemento.'
      'Ponto e vírgula depois de “punha”, por serem orações coordenadas.'
      'Nada falta: oração adverbial antes da principal dispensa vírgula.'
    )
    c = 0
    e = 'A oração adverbial temporal “toda vez que o Sol se punha” vem antes da principal e, deslocada, precisa ser isolada por vírgula: “…o Sol se punha, ela chorava…”.'
    eo = @(
      'Correta: oração adverbial deslocada para antes da principal pede vírgula.'
      'Errada: o “E” inicial é conectivo aditivo e não se isola por vírgula.'
      'Errada: nunca se separa o verbo do seu complemento por vírgula.'
      'Errada: não são coordenadas — a primeira é subordinada adverbial da segunda.'
      'Errada: é justamente o contrário — deslocada para antes da principal, ela exige a vírgula.'
    )
  }
  'b9ae6e00ea' = @{
    q = 'Em “Uma vez que a Convenção entre em vigor, os desafios surgirão”, o trecho iniciado por “Uma vez que” é uma oração subordinada:'
    o = @(
      'Adverbial.'
      'Substantiva subjetiva.'
      'Substantiva objetiva direta.'
      'Adjetiva restritiva.'
      'Adjetiva explicativa.'
    )
    c = 0
    e = '“Uma vez que…” é introduzida por locução conjuntiva e modifica a oração principal inteira, indicando a circunstância em que os desafios surgirão — oração subordinada adverbial.'
    eo = @(
      'Correta: introduzida por locução conjuntiva, modifica a oração principal como um adjunto adverbial.'
      'Errada: não exerce função de sujeito de nenhum verbo da principal.'
      'Errada: não completa verbo algum — “surgirão” não é transitivo aqui.'
      'Errada: oração adjetiva se liga a um substantivo antecedente, por pronome relativo.'
      'Errada: além de não ser adjetiva, não há antecedente nem vírgula isolando termo explicativo.'
    )
  }
  '2727068f49' = @{
    q = 'Em “A pesquisa confirma o risco de paralisações futuras na navegação marítima por falta de tripulação”, qual é o núcleo do sujeito de “confirma”?'
    o = @(
      'pesquisa'
      'risco'
      'paralisações'
      'navegação'
      'tripulação'
    )
    c = 0
    e = 'Quem confirma? “A pesquisa”. O núcleo desse sujeito é o substantivo “pesquisa”; os demais termos estão dentro do objeto ou de adjuntos.'
    eo = @(
      'Correta: “a pesquisa” é o sujeito de “confirma”, e seu núcleo é “pesquisa”.'
      'Errada: “risco” é o núcleo do objeto direto, não do sujeito.'
      'Errada: “paralisações” está dentro do adjunto adnominal de “risco”.'
      'Errada: “navegação” está no adjunto adverbial de lugar.'
      'Errada: “tripulação” está no adjunto adverbial de causa introduzido por “por”.'
    )
  }
  '8ffa1e3d3a' = @{
    q = 'Um texto em prosa informa que a Marinha Mercante abriu vagas em cursos de adaptação, trazendo número de vagas, requisitos e valor da taxa. Esse texto pertence a que gênero?'
    o = @(
      'Notícia.'
      'Crônica.'
      'Editorial.'
      'Resenha crítica.'
      'Conto.'
    )
    c = 0
    e = 'Relatar um fato recente de interesse público, com dados objetivos e sem opinião do autor, é o que define a notícia.'
    eo = @(
      'Correta: relato objetivo de fato recente e de interesse público — notícia.'
      'Errada: a crônica parte do cotidiano para um texto literário e subjetivo.'
      'Errada: o editorial defende a opinião do veículo, e aqui não há opinião.'
      'Errada: a resenha avalia uma obra; não há obra avaliada.'
      'Errada: o conto é ficcional e narra história inventada.'
    )
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
    $obj.q = $q.q; $obj.o = @($q.o); $obj.c = [int]$q.c; $obj.e = $q.e; $obj.f = $q.f
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
