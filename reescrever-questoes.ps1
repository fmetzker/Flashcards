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
# Este lote aplica o limite de 300 caracteres no enunciado (PADRAO-DOS-
# CARTOES.md §1.7): 22 cartões de Português passavam disso, com enunciados de
# até 1.307 caracteres — texto que a pessoa releria inteiro a cada revisão
# espaçada.
#
# A maioria deles ficou longa pelo LOTE ANTERIOR, que consertou o bug oposto
# (cartão que dizia "de acordo com o texto" sem o texto estar no cartão)
# colando a passagem inteira da prova. A correção de lá estava certa; o
# tamanho é que passou do ponto. Então este lote NÃO volta atrás: ele separa
# dois casos que aquele lote tratou igual.
#
#   1. Texto DECORATIVO (6 cartões) — a pergunta é de classe de palavra ou de
#      morfema, respondível sem trecho nenhum: "Qual destes termos NÃO é
#      substantivo?" não precisa de um comunicado de 900 caracteres atrás.
#      O texto sai inteiro, e as alternativas perdem os marcadores "(1º§)",
#      que só faziam sentido com ele.
#   2. Texto NECESSÁRIO (16 cartões) — correferência, uso das aspas,
#      interpretação: sem trecho a questão volta a ser inrespondível. Aqui o
#      texto fica, reduzido a uma ou duas frases que sozinhas sustentam a
#      pergunta, preservando cada termo que os distratores e o `eo` citam.
#
# Fora deste lote, por não serem problema de tamanho: 8ffa1e3d3a, 2727068f49,
# b9ae6e00ea e 62bfda28ba — "julgue os itens I a VI", 4 a 6 fatos num cartão
# só (viola §1.2), e dois deles ainda citam um texto ausente.

$REESCRITAS = @{
  'b336e58002' = @{
    q = 'Marque a opção em que todas as palavras são formadas pela inclusão de um elemento mórfico (morfema) na mesma posição:'
  }
  'c5c801015c' = @{
    q = 'Qual destes termos é um substantivo abstrato, que dá nome a uma ação ou processo?'
    o = @(
      'edital.'
      'nível.'
      'adaptação.'
      'máquinas.'
      'trabalhadores.'
    )
  }
  '0dca7c8473' = @{
    q = 'Qual destes termos NÃO é substantivo?'
    o = @(
      'processo.'
      'maio.'
      'formação.'
      'custa.'
      'edital.'
    )
  }
  '5085f4c907' = @{
    q = 'Assinale a opção em que todos os termos são formados pela inclusão de um elemento mórfico (morfema) na mesma posição:'
  }
  '7062598e2b' = @{
    q = 'Qual destes termos deve ser classificado morfologicamente como advérbio?'
    o = @(
      'início.'
      'apenas.'
      'seleções.'
      'oportunidades.'
      'eletricista.'
    )
  }
  'ba697ac65b' = @{
    q = 'Em qual destes trechos o verbo NÃO é verbo de ligação?'
  }
  'd265277903' = @{
    q = 'Na lenda do girassol, uma estrelinha apaixonada pelo Sol aceita deixar o céu e virar semente na Terra para poder segui-lo para sempre. Essa transformação pode ser interpretada como símbolo de:'
  }
  '9579c48d83' = @{
    q = 'Um comunicado tem quatro parágrafos: 1º, o prazo de inscrição; 2º, a data e o local do curso; 3º, as exigências de formação; 4º, o valor da taxa, terminando com “Saiba mais no edital”. O texto deixa de ser apenas informativo e passa a instruir o leitor:'
  }
  '34717880cc' = @{
    q = 'Leia: “A Marinha recebe inscrições para o processo seletivo do módulo para marítimos da seção de máquinas, o CAAQ-ELT, que terá 30 vagas. O curso começa em 5 de maio, no CIAGA.” Que duas expressões do trecho são correferentes, isto é, apontam para a mesma coisa?'
  }
  '91f509c668' = @{
    q = 'Leia: “A Marinha do Brasil recebe inscrições para cursos de adaptação para aquaviários, como o módulo específico para marítimos da seção de máquinas, o CAAQ-ELT.” Do trecho, interpreta-se que:'
  }
  '2f8120a0c3' = @{
    q = 'Leia: “Segundo a professora Flávia Gomes-Sponholz, da USP, "no peito o bebê tem tudo que ele precisa, não somente o alimento, mas também o aconchego e o calor da mãe".” Sobre o emprego das aspas nesse trecho, podemos afirmar que elas:'
    e = 'As aspas reproduzem literalmente a fala da entrevistada (“no peito o bebê tem tudo que ele precisa…”) — marca própria do discurso direto, que transcreve a fala tal como foi dita.'
  }
  '4203c47831' = @{
    q = 'Leia: “A pandemia e o marketing abusivo incentivaram a substituição do leite materno, e é muito fácil o acesso aos substitutos. Amamentar é escolha da mulher, não imposição. Bebês não amamentados têm até 14 vezes mais chances de morrer. Recomenda-se peito exclusivo até os 6 meses.” Segundo o trecho:'
    e = 'O texto afirma diretamente que bebês não amamentados têm até 14 vezes mais chances de morrer. As demais alternativas invertem o que o texto diz: a pandemia PREJUDICOU a amamentação; o peito exclusivo vai até os SEIS MESES, não dois; amamentar deve ser ESCOLHA, não obrigação; e o acesso aos substitutos é FÁCIL, não difícil.'
  }
  '9dcb8682c3' = @{
    q = 'Leia: “No vídeo institucional da campanha, o público nota que a seriedade de um combatente não se separa da emoção do servir.” De acordo com o trecho, o que o vídeo transmite ao público?'
  }
  '3d30bb09e2' = @{
    q = 'Leia o relato da primeira mulher qualificada em Operações no Cerrado: “Os momentos mais desafiadores foram as etapas que envolviam água. Antes do curso, eu não conseguia ficar nem cinco minutos com o fuzil a tiracolo.” Segundo o trecho, como foi a experiência dela com a água?'
  }
  '527a84e5e2' = @{
    q = 'Numa tirinha: 1º quadrinho — “Aonde você vai?” / “À praia! Vou ver a Crase.”; 2º — “Ao campo eu não vou!”; 3º — “A crase me quer à meia-noite, em frente à orla, para um bife à parmegiana.”; 4º — “Às vezes as crases são exigentes!”. Sobre o acento grave nesses quadrinhos, é correto afirmar que ele:'
  }
  '40dd28d479' = @{
    q = 'Analise os fragmentos: I) “estava à espera de ordem para pousar”; II) “meu lugar junto à janela”; III) “o ressentimento com que reagia às suas palavras”. Assinale a opção correta quanto ao emprego do acento grave indicativo de crase:'
  }
  '2e61e1e751' = @{
    q = 'Em “Ele integra a Frente Parlamentar, grupo que já fez um diagnóstico do setor e previu que a marinha mercante sofrerá com a falta de pessoal qualificado”, as orações “que já fez um diagnóstico do setor” e “que a marinha mercante sofrerá…” têm função sintática, respectivamente, de:'
  }
  '49cb059b04' = @{
    q = 'Assinale a reescrita de “Segundo a Itaipu Binacional, o barco é resultado da experiência de mais de 10 anos de produção de hidrogênio verde do Itaipu Parquetec, um centro de pesquisa em tecnologias sustentáveis, em Foz do Iguaçu, no Paraná” que respeita a pontuação e não altera o sentido:'
  }
  'e0e97f8c82' = @{
    q = 'Em “Os submarinos nucleares são uma vantagem naval. Eles vão mais fundo e navegam mais rápido. Essas qualidades se mostraram óbvias em 1939, quando Ross Gunn idealizou a primeira embarcação do tipo”, há verbos no:'
  }
  '6efa448982' = @{
    q = 'Em “A Marinha do Brasil, por meio da Diretoria de Portos e Costas, vai receber inscrições”, o sujeito está separado do verbo por vírgula, o que em geral contraria a norma-padrão. Aqui o emprego está correto porque:'
  }
  'e0c5c4f986' = @{
    q = '“Íntegra” (substantivo) perde o acento e vira “integra” (verbo): muda de classe gramatical. Em qual destas palavras a retirada do acento NÃO muda a classe gramatical?'
  }
  'de58e0f4fe' = @{
    q = 'Leia: “O projeto obteve respaldo institucional para desenvolver atividades congêneres e pertinentes à sua área, com base em conhecimentos inerentes e afins à formação da equipe.” Qual destas palavras é, na frase, um substantivo (as demais são adjetivos)?'
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
