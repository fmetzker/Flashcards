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
# Este lote aplica o PADRAO-DOS-CARTOES.md §1.9.5 a Manutenção Elétrica:
# enunciados que diziam "a apostila" passam a perguntar pelo fato ou pela
# prática, e a fonte continua no 'f'. Vêm junto as notas por alternativa que não
# diziam o que a alternativa é ("não é o argumento", "não confere"), §1.9.3.

$REESCRITAS = @{
  '97e5e73900' = @{
    q = 'Por que não se deve improvisar durante a manutenção, mesmo quando o improviso resolve na hora?'
    eo = @('Correta: risco futuro.', 'Errada: o problema não é o tempo — o improviso às vezes é até mais rápido na hora.', 'Errada: fazer certo é que economiza material; o risco do improviso é o acidente e a nova falha.', 'Errada: não é questão de burocracia; o risco é técnico.', 'Errada: o motivo é segurança e nova falha, não a garantia.')
  }
  '94db489656' = @{
    q = 'Que atitude ambiental se espera do mantenedor com fitas, pilhas, lâmpadas e cabos usados?'
    eo = @('Correta: uso racional e descarte legal.', 'Errada: pilha e lâmpada no lixo comum contaminam o ambiente; o descarte segue a lei.', 'Errada: guardar resíduo no painel acumula sujeira e risco, e não é descarte.', 'Errada: é poluente e perigoso.', 'Errada: o resíduo é responsabilidade de quem fez o serviço, não do operador.')
  }
  'f6547cd9a1' = @{
    q = 'Por que, num cabo longo, se usa a escala de resistência do multímetro em vez da de continuidade?'
    eo = @('Correta: limite do bipe.', 'Errada: a continuidade é um ohmímetro com bipe; não tem relação com CA.', 'Errada: isolação é com megômetro.', 'Errada: as duas escalas usam a bateria do mesmo jeito.', 'Errada: a medição é com o circuito desenergizado; o problema é o limite do bipe.')
    e = 'O bipe de continuidade só atua com resistência baixíssima; um cabo comprido tem alguns ohms e o bipe não tocaria mesmo estando inteiro. Num exemplo de cabo longo, cada par deu 2,1 Ω.'
  }
  '78e37be4d1' = @{
    q = 'Pela regra prática para máquinas rotativas, qual é a resistência de isolação mínima, a 40 °C, de um motor de 440 V?'
    eo = @('Correta: 0,44 + 1.', 'Errada: esqueceu o +1.', 'Errada: 4,4 seria ler 440 V como 4,4 kV; 440 V = 0,44 kV.', 'Errada: 440 é a tensão em volts, não a isolação; a regra usa kV + 1.', 'Errada: 44 não sai da regra kV + 1, que dá 0,44 + 1.')
  }
  'bb5056f070' = @{
    q = 'Por quanto tempo se mantém a tensão de ensaio do megômetro na medição de isolação de um motor?'
    eo = @('Correta: 1 minuto.', 'Errada: curto demais.', 'Errada: a leitura de rotina é feita com um minuto de ensaio.', 'Errada: o motor está desligado.', 'Errada: uma hora não é ensaio de rotina; a leitura sai com um minuto.')
  }
  '3261101990' = @{
    q = 'Qual é a menor resistência de isolação aceitável, na prática, para motores de baixa potência e baixa tensão?'
    eo = @('Correta: ≈ 2 MΩ.', 'Errada: kΩ indica isolação danificada.', 'Errada: muito baixo.', 'Errada: é quase curto.', 'Errada: gigaohms é isolação excelente, não o mínimo aceitável.')
  }
  '335671d614' = @{
    q = 'Um motor apresentou isolação baixa por causa de umidade. O que às vezes a recupera?'
    eo = @('Correta: estufa.', 'Errada: não recupera a isolação.', 'Errada: o relé térmico protege de sobrecarga; não mexe na isolação do motor.', 'Errada: ligar com isolação baixa arrisca curto e choque; primeiro se seca o motor.', 'Errada: inverter duas fases muda o sentido de giro, não a isolação.')
  }
  '897948d19a' = @{
    q = 'Ao substituir um TC ligado a um amperímetro, que TC se deve usar?'
    eo = @('Correta: casado.', 'Errada: pode perder exatidão.', 'Errada: erraria a escala.', 'Errada: sem secundário não há corrente para o instrumento.', 'Errada: sem TC, a corrente alta do circuito passaria pelo amperímetro pequeno.')
  }
  '19d56a6fba' = @{
    q = 'Antes de começar uma manutenção corretiva, que dados se devem coletar?'
  }
  'b656f510a1' = @{
    q = 'Depois de levantar as hipóteses da falha, por qual verificação se começa?'
    eo = @('Correta: visual.', 'Errada: é o último recurso.', 'Errada: vem depois.', 'Errada: nem sempre é preciso.', 'Errada: chamar o fabricante antes de olhar é o erro clássico — muitas falhas se veem a olho.')
  }
  '6542e0ab8e' = @{
    q = 'Ao investigar uma falha, como se comprova a hipótese de "motor queimado"?'
  }
  '8034155407' = @{
    q = 'Ao investigar uma falha, como se comprova a hipótese de "cabo que alimenta o motor rompido"?'
  }
  '777bb63bd2' = @{
    q = 'Um motor, ao ser ligado, queima os fusíveis imediatamente. Que falha do motor causa isso?'
    eo = @('Correta: curto entre bobinas.', 'Errada: faz roncar.', 'Errada: rolamento gasto dá ruído e aquecimento, não curto.', 'Errada: desliga, mas não queima fusível.', 'Errada: ventilador quebrado aquece o motor aos poucos; não queima fusível na hora.')
  }
  '4939ded637' = @{
    q = 'Ao energizar, um motor ronca e não desenvolve torque. Que falha dos enrolamentos causa isso?'
  }
  '85990cabf0' = @{
    q = 'Como se testa se uma bobina do motor está aberta?'
    eo = @('Correta: ohmímetro início-fim.', 'Errada: isso testa isolação.', 'Errada: o alicate mostra corrente, mas não diz qual bobina está aberta.', 'Errada: o termovisor vê aquecimento, não interrupção da bobina.', 'Errada: não localiza e é arriscado.')
  }
  '7c26581603' = @{
    q = 'No gráfico de tendência da figura, a corrente do motor M1 salta de 12 A para 18 A no horário em que a mesa parou. O que isso indica?'
    eo = @('Correta: travamento com sobrecarga.', 'Errada: não é o que o gráfico mostra.', 'Errada: em vazio a corrente cai.', 'Errada: trocar o TC não muda a corrente do motor, só a leitura.', 'Errada: a parametrização errada explica a demora da proteção, não o salto de corrente.')
  }
  '6f44fa87ae' = @{
    q = 'No caso do motor M1, por que a proteção do inversor demorou a desligar o motor que acabou queimando?'
  }
  '60771f0720' = @{
    q = 'Qual é a ordem de validação de uma manutenção corretiva?'
    eo = @('Correta: medir → testar → registrar → encerrar.', 'Errada: a OS só fecha depois de medir, testar e registrar.', 'Errada: registra-se o resultado, então medir e testar vêm antes do registro.', 'Errada: medir vem antes de testar, e a OS fecha por último.', 'Errada: sem medir e testar, não há como validar o reparo.')
  }
  '3e0036d18a' = @{
    q = 'No caso do robô metalúrgico que não funcionava, qual era a causa do defeito?'
    eo = @('Correta: curto no sinalizador.', 'Errada: as mensagens de falha de rede eram sintoma — a equipe perdeu dois dias nelas.', 'Errada: o controlador reiniciava porque a tensão caía, mas estava bom.', 'Errada: não era mecânico.', 'Errada: não era software.')
  }
  '5b89b4f38a' = @{
    q = 'Por que a manutenção preditiva costuma ficar só nos equipamentos mais críticos?'
  }
  '30f017aedb' = @{
    q = 'Que referência se usa para avaliar o resultado de uma inspeção instrumental?'
    eo = @('Correta: fabricante ou histórico.', 'Errada: não é parâmetro técnico.', 'Errada: é parte do histórico, não sempre.', 'Errada: sem referência não se avalia.', 'Errada: outra fábrica tem equipamento e condição diferentes; compara-se com equipamento semelhante do próprio setor.')
  }
  '6c6cf71f3b' = @{
    q = 'Num plano de manutenção preventiva, que serviço periódico se faz no inversor de frequência e no controlador programável?'
    eo = @('Correta: backup.', 'Errada: trocar motor todo ano não é preventiva, é desperdício.', 'Errada: isolação é medição de motor, e não diária.', 'Errada: rebobinar é reparo de motor queimado, não preventiva.', 'Errada: pintura não protege o que se perde numa pane: os parâmetros e o programa.')
  }
  'd23bac9166' = @{
    q = 'Antes de inspeção ou teste com o equipamento em funcionamento, o que se deve fazer?'
    eo = @('Correta: comunicar.', 'Errada: o teste é com ele ligado.', 'Errada: nunca.', 'Errada: mexer nas proteções aumenta o risco, não o reduz.', 'Errada: o teste pode parar ou acionar a máquina de surpresa.')
  }
  '0817961da3' = @{
    q = 'O que é preciso para implantar manutenção preditiva?'
  }
  '69361b5a7c' = @{
    q = 'No plano de preditiva do motor M1, que grandezas são medidas mensalmente?'
    eo = @('Correta: as quatro.', 'Errada: o plano do M1 mede grandezas elétricas, não temperatura.', 'Errada: rotação não está entre as grandezas medidas no plano do M1.', 'Errada: ruído é inspeção auditiva, não medição do plano.', 'Errada: preditiva é medição.')
  }
  '2b6bb736c3' = @{
    q = 'Que resistência teria uma isolação perfeita?'
  }
  '3537562869' = @{
    q = 'Por que se levam em conta as medições anteriores ao avaliar a isolação de um equipamento?'
  }
  '493acea6f7' = @{
    q = 'Na correção da resistência de isolação para 40 °C, como o coeficiente kt varia com a temperatura do enrolamento?'
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
