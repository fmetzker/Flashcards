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
# Este lote conserta o bug do "texto ausente": cartões de Português (a maioria
# de provas reais do CAAQ-ELT/CAAQ-MFL, transcritas de PROVAS ANTIGAS/) que
# diziam "no texto..." ou "de acordo com o texto..." sem que o texto estivesse
# em lugar nenhum do cartão — inrespondível para quem não tinha a prova
# original na mão. As alternativas, a correta (`c`) e a explicação (`e`) já
# estavam certas (conferidas contra o PDF real da prova, em PROVAS ANTIGAS/);
# só faltava o enunciado trazer o texto consigo. Os textos abaixo são versões
# adaptadas (não cópia literal) dos originais jornalísticos — PADRAO-DOS-
# CARTOES.md §1.6 pede exatamente isso: reduzir/reescrever, nunca copiar um
# texto inteiro para o cartão. A lenda do girassol é exceção: autoria popular,
# tradição oral, sem direito autoral — reproduzida na íntegra.

$textoCaaqElt = 'Leia o trecho a seguir (adaptado de um comunicado sobre inscrições para o CAAQ-ELT): “1º§ — Entre hoje e o dia 14 de janeiro, a Marinha do Brasil, pela Diretoria de Portos e Costas (DPC), recebe inscrições para o processo seletivo público destinado a trabalhadores interessados em cursos de adaptação para aquaviários, como o módulo específico para marítimos da seção de máquinas, o CAAQ-ELT, que terá 30 vagas disponíveis. 2º§ — Com início previsto para 5 de maio, o curso será realizado no Centro de Instrução Almirante Graça Aranha (CIAGA). Podem participar do processo seletivo brasileiros, natos ou naturalizados, de ambos os sexos, com idade mínima de 18 anos. 3º§ — Além disso, é preciso ter formação técnica de nível médio reconhecida pelo Ministério da Educação, estar em dia com as obrigações da Justiça Eleitoral e do Serviço Militar em caso de candidatos do sexo masculino, entre outras exigências. 4º§ — A taxa de inscrição custa R$ 8,00. Saiba mais no edital publicado pela Autoridade Marítima.”'

$textoAmamentacao = 'Leia o trecho, adaptado de uma reportagem sobre um relatório da OMS e do Unicef sobre amamentação: “O relatório alerta que a desinformação, o isolamento da pandemia e o marketing abusivo têm incentivado a substituição do leite materno. Segundo a professora Flávia Gomes-Sponholz, da USP, "no peito o bebê tem tudo que ele precisa, não somente o alimento, mas também o aconchego, o calor e o olhar da mãe". A amamentação deve ser uma escolha da mulher, não uma prática imposta — os substitutos devem ser usados só quando a mãe não pode amamentar: "é uma decisão que, embora difícil de ser tomada, é muito fácil o acesso aos produtos que substituem o leite." A OMS destaca que bebês que não são amamentados têm até 14 vezes mais chances de morrer. A recomendação é peito exclusivo até os seis meses e, depois, complementado com outros alimentos até os dois anos ou mais.”'

$REESCRITAS = @{
  '4683677563' = @{
    q = 'Leia o trecho, adaptado de uma notícia sobre vagas na Marinha Mercante: “A Marinha Mercante tem vagas nos Cursos de Adaptação para Aquaviários do 1º Grupo-Marítimos. São 30 oportunidades para condutores de máquinas e 30 chances para eletricistas, para os cursos técnicos listados a seguir, entre eles o de eletromecânica e o de mecatrônica — todos requerem o ensino médio técnico. Os interessados pagam uma taxa a partir de guia emitida no site da Marinha, confirmando o interesse no CIAGA.” Assinale a opção em que todos os termos abaixo, retirados do trecho, são formados pela inclusão de um elemento mórfico (morfema) na mesma posição:'
  }
  '97d372f5f5' = @{
    q = 'Leia o trecho a seguir, adaptado de uma notícia sobre vagas na Marinha Mercante, com a paragrafação preservada — subtítulo/lide: “Inscrições em seleções custam apenas R$ 8”; 1º§: “A Marinha Mercante tem vagas abertas nos Cursos de Adaptação para Aquaviários. São 30 oportunidades para condutores de máquinas e 30 chances para eletricistas.”; 3º§: “Os selecionados farão curso de formação; precisam ter idade mínima de 18 anos até o início da formação. Se aprovado, o aluno será declarado condutor de máquinas e eletricista.” Qual desses termos do trecho deve ser classificado morfologicamente como advérbio?'
  }
  '0da7dcfb1f' = @{
    q = $textoCaaqElt + ' Marque a opção em que todas as palavras, encontradas no trecho, são formadas pela inclusão de um elemento mórfico (morfema) na mesma posição:'
  }
  'f419c2270e' = @{
    q = $textoCaaqElt + ' Qual desses termos do trecho NÃO é substantivo?'
  }
  'd4d12f7b23' = @{
    q = $textoCaaqElt + ' Qual desses termos do trecho é um substantivo abstrato, que dá nome a uma ação ou processo?'
  }
  'c9b888624a' = @{
    q = $textoCaaqElt + ' A leitura atenta do primeiro parágrafo do trecho permite interpretar que:'
  }
  'c2c2f74d94' = @{
    q = $textoCaaqElt + ' A leitura atenta do trecho permite compreender que há uma mudança de perspectiva em determinado ponto, no sentido de que o texto deixa de ser meramente informativo e passa a assumir uma característica mais instrutiva/injuntiva/sugestiva. Isso ocorre:'
  }
  '1e5a949b67' = @{
    q = $textoCaaqElt + ' No trecho, há duas expressões diretamente relacionadas, correferentes, equivalentes:'
  }
  '059e24e886' = @{
    q = $textoAmamentacao + ' De acordo com o trecho acima, podemos afirmar que:'
  }
  '5f993f2886' = @{
    q = $textoAmamentacao + ' Observando a utilização das aspas no trecho acima (que reproduz falas da professora Flávia Gomes-Sponholz), podemos afirmar que elas:'
  }
  '4f2076294b' = @{
    q = 'Leia o trecho, adaptado de uma notícia da Marinha sobre a campanha “Na Paz ou Na Guerra”, em homenagem aos 217 anos do Corpo de Fuzileiros Navais: “Em poucos segundos, o público pode notar, no vídeo institucional da campanha, que a seriedade de um combatente não se separa da emoção do servir. O vídeo mostra momentos de combate, treinamentos e formações, mostrando que, há 217 anos, o Brasil conta com os Fuzileiros Navais prontos para responder de imediato, em qualquer lugar e a qualquer hora.” De acordo com o trecho, o que o vídeo institucional da campanha transmite ao público?'
  }
  'fc118517b9' = @{
    q = 'Leia o trecho, adaptado de uma notícia da Marinha sobre a Soldado Fuzileiro Naval Fabiana Damasceno, primeira mulher qualificada em Operações no Cerrado: “Os momentos mais desafiadores para mim, sem dúvidas, foram as etapas que envolviam água. Antes de começar o curso, eu não conseguia fazer nem cinco minutos de permanência com o fuzil a tiracolo. Então, durante esse período, percebi que, com muito esforço, dedicação e vibração, nós podemos superar todos os nossos limites, avalia a Soldado.” Segundo o trecho, como ela descreveu sua experiência com a água durante o estágio?'
  }
  'b5b64d4a35' = @{
    q = 'Leia a lenda a seguir (autoria popular, tradição oral): “A LENDA DO GIRASSOL — Dizem que existia no céu uma estrelinha tão apaixonada pelo Sol que era a primeira a aparecer de tardinha, antes que ele se escondesse. E toda vez que o Sol se punha ela chorava lágrimas de chuva. A Lua falava com a estrelinha que assim não podia ser. Que a estrela nasceu para brilhar à noite e que não tinha sentido esse amor. Mas a estrelinha amava cada raio de sol como se fosse a única luz de sua vida. Esquecia até sua própria luzinha. Um dia ela foi falar com o Rei dos Ventos para pedir a sua ajuda, pois queria ficar olhando o Sol, sentindo o seu calor eternamente. O Rei dos Ventos disse que seu sonho era impossível, a não ser que ela abandonasse o céu e fosse morar na Terra, deixando de ser estrela. A estrelinha não pensou duas vezes: virou uma estrela cadente e caiu na Terra em forma de semente. O Rei dos Ventos plantou esta sementinha com muito carinho e regou com as mais lindas chuvas. A sementinha virou planta. As suas pétalas foram se abrindo, girando devagarinho, seguindo o giro do Sol no céu. É por isso que os girassóis até hoje explodem seu amor em lindas pétalas amarelas.” Na lenda do girassol, a transformação da estrelinha em girassol pode ser interpretada, no contexto do texto, como símbolo de:'
  }
  '318e2b6619' = @{
    # fonte original ("Anexo I") não foi localizada em PROVAS ANTIGAS/ — troca
    # de texto autorizada pelo usuário (mesma situação gramatical: núcleo
    # substantivo entre quatro adjetivos). A frase nova reaproveita os pares
    # exatos já citados na explicação existente ("atividades congêneres/
    # pertinentes", "respaldo institucional", "conhecimentos inerentes/afins").
    # v2: "termos destacados" citava formatação que o app não tem — corrigido.
    q = 'Leia a frase: “O projeto obteve respaldo institucional para desenvolver atividades congêneres e pertinentes à sua área de atuação, com base em conhecimentos inerentes e afins à formação da equipe.” Marque a única das opções abaixo que representa, na frase, um núcleo substantivo (as demais são adjetivos):'
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

    # regrava na MESMA ordem de campos do banco, para o diff ficar mínimo
    $obj = [ordered]@{ id = $q.id; m = $q.m; t = $q.t }
    if ($q.PSObject.Properties.Name -contains 's' -and $q.s) { $obj.s = $q.s }
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
