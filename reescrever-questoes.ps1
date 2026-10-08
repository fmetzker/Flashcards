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
# Este lote aplica o PADRAO-DOS-CARTOES.md §1.9.5 a Comandos Elétricos:
# enunciados que diziam "a apostila" ou "o Franchi" passam a perguntar pelo
# fato ou pela prática, e o caso ilustrativo vira a própria situação ("Num
# torno...", "Numa siderúrgica..."). A fonte continua no 'f'. Vêm junto as
# notas por alternativa genéricas ou repetidas (§1.9.3).

$REESCRITAS = @{
  '5d5e3b9826' = @{
    q = 'Na partida direta, o que identificam S0 e S1?'
    e = 'A letra S identifica os dispositivos de comando manual. S0 é o botão desliga (vermelho, NF 11-12) e S1 o botão liga (verde, NA 13-14).'
  }
  '1d047558d5' = @{
    q = 'Nos diagramas de comando, que dispositivos são identificados pela letra Q (Q11, Q12)?'
    eo = @('Correta: Q = disjuntor.', 'Errada: contatores são K.', 'Errada: botões são S.', 'Errada: a lâmpada é E1 (em outra convenção, H).', 'Errada: fusíveis são F.')
  }
  'd4ec7cd020' = @{
    q = 'Se a corrente nominal do fusível deve ser pelo menos 20% maior que a do motor, qual é o mínimo para um motor de 20 A?'
  }
  'e52187c070' = @{
    q = 'Com qual valor se ajusta a corrente do relé térmico?'
  }
  'e91e96b4f0' = @{
    q = 'Em que tipo de máquina se aceita o relé térmico em rearme automático?'
  }
  'fff794fd7a' = @{
    q = 'Como se liga um disjuntor-motor tripolar a um motor monofásico?'
    eo = @('Correta: todos os polos no caminho da corrente.', 'Errada: com um polo só, a proteção térmica fica desequilibrada.', 'Errada: em paralelo, cada polo sentiria só parte da corrente.', 'Errada: o disjuntor-motor tripolar tem ligação própria para monofásico e para bifásico.', 'Errada: nenhum polo vai ao terra.')
  }
  '0b3461e5f4' = @{
    q = 'Em que situação se recomenda partir um motor só com disjuntor-motor, sem contator?'
  }
  'f5636b967c' = @{
    q = 'Qual é a diferença entre um seccionador e um interruptor?'
  }
  'd2d7d47666' = @{
    q = 'Um contator vibra e faz ruído durante o funcionamento. Qual é uma causa típica?'
  }
  '55583a8b7f' = @{
    q = 'Numa bomba, uma chave-boia substituiu o botão de ligar. Como ela comanda a bobina do contator?'
  }
  '7749dfce4b' = @{
    q = 'Para que tipo de máquina se indica a partida direta?'
  }
  'f6ca72689b' = @{
    q = 'A partir de que potência a NBR 5410 recomenda consultar a concessionária antes de partir um motor direto na rede pública de baixa tensão?'
  }
  '907d28ea1a' = @{
    q = 'Como se testa se um relé térmico está "cansado"?'
  }
  '0cfb3a1e94' = @{
    q = 'Como se testa se um relé térmico está "viciado"?'
  }
  '53941a0db0' = @{
    q = 'Na partida direta, ao pressionar S1 o disjuntor do comando desarma na hora. Que falha causa esse sintoma?'
  }
  'fd5bf26fa6' = @{
    q = 'Na partida direta, a lâmpada E1 não apaga nunca, nem com o motor desligado. Que falha causa isso?'
  }
  'd29e0b2d84' = @{
    q = 'Um contator trepida (vibra) no conjunto magnético durante o funcionamento. Quais são as consequências?'
  }
  '04641ff197' = @{
    q = 'Em que condição se pode medir resistência com ohmímetro ou megômetro num painel?'
  }
  '4a948ba563' = @{
    q = 'Como é formado o sistema de partida direta com reversão?'
  }
  'f0ec5eae60' = @{
    q = 'Na reversão da figura, o disjuntor-motor Q1 atua por sobrecarga. O que acontece no comando?'
  }
  'aafdb2dde8' = @{
    q = 'Quais são os tipos de intertravamento usados em comandos de reversão?'
    eo = @('Correta: os três tipos.', 'Errada: temporizador e fim de curso não impedem os dois contatores de fecharem juntos.', 'Errada: são proteções, não intertravamentos.', 'Errada: são sensores.', 'Errada: há também os elétricos.')
  }
  '343d313886' = @{
    q = 'No comando em 24 VCC, as bobinas, lâmpadas e sensores vão sendo ligados e logo em seguida começam a desligar. Que falha da fonte causa isso?'
  }
  'ebfa5a929d' = @{
    q = 'Numa retificadora, o sensor S10 foi trocado e queimou de novo, abrindo o fusível F2. A bobina de K10 mediu quase 0 Ω. O que o eletricista verificou antes de trocar a bobina?'
  }
  '058ddfb2c1' = @{
    q = 'Que desvantagem a partida estrela-triângulo tem no instante da comutação?'
  }
  '207926675b' = @{
    q = 'Quais são vantagens da chave estrela-triângulo?'
  }
  '67ca8de1bb' = @{
    q = 'Como se verifica se o condutor terra está interrompido numa alimentação trifásica?'
  }
  '0cdbc6fafc' = @{
    q = 'Um eletricista simplificou o comando de uma estrela-triângulo com um temporizador comum. Dias depois, K2 e K3 colaram e os fusíveis queimaram. Qual era a causa?'
    e = 'O temporizador próprio para Y-Δ tem um retardo (entre 30 e 100 ms, tipicamente cerca de 50 ms) para K2 abrir e extinguir o arco antes de K3 fechar. Sem ele, os dois se sobrepunham: curto, contatos colados e fusíveis queimados. Outra solução é o intertravamento mecânico.'
  }
  'e50a0cf6ba' = @{
    q = 'Qual é a sequência de funcionamento da chave compensadora?'
  }
  '05b7fe99f6' = @{
    q = 'Com um tap de relação a = 0,5 na chave compensadora, a quanto fica reduzido o conjugado de partida?'
  }
  '2bdd6fe564' = @{
    q = 'Um vigilante tentou partir várias vezes um compressor com chave compensadora, que não ganhava velocidade, até sentir cheiro de queimado. O que se danificou, e por quê?'
    eo = @('Correta: partidas seguidas aquecem o autotransformador.', 'Errada: rearmar o relé não o danifica; quem esquentou foi o autotransformador.', 'Errada: os contatores não foram o dano; o autotransformador precisou ser rebobinado.', 'Errada: não houve falta de fase.', 'Errada: a causa foi a carga — as válvulas de alívio estavam fechadas.')
  }
  'f64ca31a73' = @{
    q = 'Qual é a menor resistência típica de um sensor PTC em bom estado, e o que indica um valor próximo de zero?'
  }
  'fdb2b62489' = @{
    q = 'Num torno, o motor Dahlander roncava e não girava só na velocidade alta. O que foi medido e encontrado?'
  }
  'b83ce7bf2c' = @{
    q = 'Qual é o sintoma característico de falta de fase num motor Dahlander?'
  }
  'ebf8474c58' = @{
    q = 'Como se testa se o contato de uma chave comutadora de velocidades está danificado?'
    eo = @('Correta: continuidade posição a posição.', 'Errada: corrente em vazio testa o motor, não a chave.', 'Errada: medir com o motor ligado é outro teste e é perigoso.', 'Errada: megômetro testa isolação.', 'Errada: bússola não diz nada sobre o contato da chave.')
  }
  'd85e45c3c4' = @{
    q = 'Qual é a corrente de partida típica, a plena carga, de um motor com aceleração rotórica?'
  }
  '2a128b5fcb' = @{
    q = 'Em que equipamento é típico o uso do motor de anéis com aceleração rotórica?'
  }
  'a763de32fe' = @{
    q = 'Na partida rotórica automática, como a velocidade aumenta de um estágio para o outro?'
  }
  'a37fd1eb0b' = @{
    q = 'Uma ponte rolante com motor de anéis se movia só devagar. Medindo entre os terminais L e M do rotor, a resistência estava alta. O que foi encontrado?'
  }
  'd461c1c326' = @{
    q = 'Por que um motor de anéis parado não está necessariamente desenergizado?'
    eo = @('Correta: rotor aberto, estator energizado.', 'Errada: escovas não guardam carga.', 'Errada: resistores não acumulam carga.', 'Errada: sem movimento o rotor não gera tensão.', 'Errada: a ponte é alimentada pela rede; o perigo é o estator energizado.')
  }
  'bc08faa4da' = @{
    q = 'Antes de subir numa ponte rolante para manutenção, o que se deve fazer?'
  }
  '8bba56e42f' = @{
    q = 'Em que aplicação o sensor óptico de barreira é usado como proteção do operador?'
  }
  '6869ef4abe' = @{
    q = 'Numa siderúrgica, um sensor indutivo falhava porque o batente tinha folga mecânica. Qual foi a solução?'
    eo = @('Correta: óptico a distância maior.', 'Errada: o capacitivo também tem distância pequena.', 'Errada: a tensão não muda a distância sensora.', 'Errada: mascarar a falha não resolve.', 'Errada: o reed switch também exige o atuador perto; a folga continuaria atrapalhando.')
  }
  '688ffd8d57' = @{
    q = 'Por que se recomendam motores com isolação reforçada quando alimentados por inversor?'
    eo = @('Correta: picos de chaveamento.', 'Errada: o inversor não eleva a tensão da rede.', 'Errada: girar acima da nominal afeta o conjugado, não a isolação.', 'Errada: o inversor tem proteções.', 'Errada: a partida é suave.')
  }
  'feff088d0f' = @{
    q = 'Que vantagem tem a placa de montagem com acabamento metalizado (galvanizada ou zincada)?'
  }
  '3c06c0e08f' = @{
    q = 'Num painel, um temporizador de retardo na desenergização foi instalado no lugar de um de retardo na energização, e a máquina quebrou a trava no teste. Quais foram as duas falhas?'
    eo = @('Correta: tipo errado + sem teste.', 'Errada: o motor e a trava funcionavam; o problema foi a ordem de acionamento.', 'Errada: a fiação estava certa; o temporizador é que era do tipo errado.', 'Errada: aterramento e disjuntor não explicam motor e trava acionando juntos.', 'Errada: a tensão estava certa; o temporizador não esperou o tempo.')
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
