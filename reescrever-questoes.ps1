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
# Este lote traz para o enunciado o trecho de que a resposta depende, em
# cartões de Português tirados de prova com texto: "Qual destes termos é
# advérbio?" sem a frase, "o núcleo do sujeito no primeiro parágrafo" sem o
# parágrafo. Fora do app, o texto da prova não existe — o cartão precisa se
# sustentar sozinho (PADRAO-DOS-CARTOES.md §1.1 e §1.6).

$REESCRITAS = @{
  'f57be1ef63' = @{
    q = 'No subtítulo de notícia ''Inscrições em seleções custam apenas R$ 8'', qual palavra deve ser classificada morfologicamente como advérbio?'
    o = @('inscrições.', 'apenas.', 'seleções.', 'custam.', 'em.')
    c = 1
    e = '''Apenas'' equivale a ''somente'': modifica ''R$ 8'', restringindo o valor — por isso a banca o classifica como advérbio (a NGB o chama também de palavra denotativa de exclusão). Na mesma frase, ''inscrições'' e ''seleções'' são substantivos, ''custam'' é verbo e ''em'' é preposição.'
    eo = @('Errada: ''inscrições'' é substantivo, núcleo do sujeito.', 'Correta: ''apenas'' (= somente) modifica o valor ''R$ 8'', restringindo-o.', 'Errada: ''seleções'' é substantivo, ligado a ''inscrições'' pela preposição ''em''.', 'Errada: ''custam'' é verbo (custar, presente do indicativo).', 'Errada: ''em'' é preposição: liga ''inscrições'' a ''seleções''.')
  }
  '1715aaccdc' = @{
    q = 'Um comunicado sobre um processo seletivo, com curso de formação previsto para maio, termina assim: ''A taxa de inscrição custa R$ 8,00. Saiba mais no edital.'' Qual destes termos do comunicado NÃO é substantivo?'
    e = '''Custa'' é o verbo custar (3ª pessoa do singular do presente do indicativo), núcleo do predicado de ''A taxa de inscrição custa R$ 8,00''. Processo, maio, formação e edital nomeiam coisas: são substantivos.'
  }
  '37cd63777b' = @{
    q = 'Em ''Entre hoje e o dia 14 de janeiro, a Marinha do Brasil, por meio da Diretoria de Portos e Costas (DPC), vai receber inscrições'', qual é o núcleo do sujeito com o qual concorda a locução verbal ''vai receber''?'
  }
  '826e9e1aa7' = @{
    q = 'Numa notícia: ''O risco de um apagão na navegação marítima brasileira será discutido'', com base num diagnóstico que ''previu que a marinha mercante, em breve, sofrerá com a falta de pessoal qualificado''. A que se refere o termo ''apagão''?'
  }
  '69010375cf' = @{
    q = 'Um texto intitulado ''Comissões debatem risco de apagão na Marinha Mercante'' relata uma audiência marcada na Câmara, com data, nomes dos convidados e falas entre aspas, e indica o site de onde foi tirado. Pela forma e pelo conteúdo, ele pertence ao gênero:'
  }
  '876c54e41d' = @{
    q = 'No texto ''Registro de encantamento e atestado de importância'' (Stela Maris Rezende), que celebra o prazer de entrar em livrarias e ler, qual fragmento evidencia ironia?'
  }
  '670de76010' = @{
    q = 'Num vídeo pelos 217 anos do Corpo de Fuzileiros Navais, sobre a prontidão desses militares ''na paz ou na guerra'', o narrador diz: ''Quando a natureza desafia o homem, eles estão lá. Em qualquer lugar, a qualquer hora''. Qual é o sentido da frase?'
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
    $obj.q = $q.q
    # idem para a figura do enunciado (§1.8 do PADRAO-DOS-CARTOES.md)
    if ($q.PSObject.Properties.Name -contains 'img' -and $q.img) { $obj.img = $q.img; $obj.alt = $q.alt }
    $obj.o = @($q.o); $obj.c = [int]$q.c; $obj.e = $q.e; $obj.f = $q.f
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
