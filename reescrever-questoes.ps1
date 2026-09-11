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
# Este lote leva o limite de 300 caracteres (PADRAO-DOS-CARTOES.md §1.7) para
# MATEMÁTICA, a única matéria que ainda tinha enunciado acima disso: 51 de
# 942, de 301 a 508 caracteres. Só o enunciado muda — alternativas, correta,
# explicação e `eo` ficam como estavam, então nem o viés de comprimento nem
# a explicação por alternativa se mexem.
#
# O que foi cortado, e por que não é conteúdo:
#   - CENÁRIO. "Em um navio da Marinha Mercante, o convés superior, que é a
#     área de circulação, tem o formato de um retângulo, com 80 metros de
#     comprimento e 30 metros de largura" vira "Um convés retangular mede
#     80 m por 30 m". A conta é a mesma; o que sai é a ambientação naval.
#   - A PERGUNTA REPETIDA NO FIM. "Com base nas informações acima, a
#     quantidade de tinta necessária, em litros, para pintar a área
#     correspondente a 30% do convés superior será" vira "Quantos litros de
#     tinta são necessários?".
#   - NOTAÇÃO, não dado: "quadrada, lado 11 cm, R$0,45/cm²" vira "11×11 cm,
#     R$ 0,45/cm²"; cinco opções assim economizam 80 caracteres sem perder
#     um número.
#
# Nenhum número, etapa ou condição saiu. O gerador conferiu cada enunciado
# número a número contra o original, e as 14 diferenças que restaram foram
# revisadas uma a uma: são número por extenso virando dígito ("12
# marinheiros" <-> "Doze marinheiros"), formato de moeda ("R$50,00" ->
# "R$ 50"), e dado que a resposta não usa (o ano "2024", o comprimento da
# pista numa questão de MMC, os 42 km do maratonista grego numa questão que
# só compara 60 cm com 420 km).
#
# Três enunciados ganharam texto em vez de perder, porque encurtar tinha
# deixado implícita uma condição de que a resposta depende:
#   - 0225a815c8: "desligado NO INSTANTE t = 0" — sem a âncora, "tempo
#     mínimo de espera" não tem de quando contar.
#   - a558269d85: "PARTE NA MARÉ ENCHENTE E O RESTANTE NA VAZANTE" — sem
#     isso o trajeto não tem as duas fases que o sistema de equações usa.
#   - 36c8fe4949: "E, EM CASO AFIRMATIVO, POR QUAL MARGEM" — as cinco
#     alternativas dão a margem, então o enunciado tem de pedi-la.

$REESCRITAS = @{
  '9e86b152f6' = @{
    q = 'Um convés retangular mede 80 m por 30 m. Será pintada 30% da área, e 1 litro de tinta cobre 3 m². Quantos litros de tinta são necessários?'
  }
  'eb048f2895' = @{
    q = 'Dos 52 equipamentos de um navio, 20 têm defeito no áudio e 12 têm defeito no áudio e no vídeo. O número com defeito apenas no vídeo é 3 vezes o número sem defeito algum. Quantos NÃO apresentam defeito no vídeo?'
  }
  'a8d02917d9' = @{
    q = 'Pela fórmula de Young, a dose infantil é [idade / (idade + 12)] × dose do adulto. Uma criança de idade desconhecida recebeu corretamente 14 mg do remédio Y, de dose adulta 42 mg. Que dose do remédio X, de dose adulta 60 mg, ela deve receber, em mg?'
  }
  '2ae9dee69a' = @{
    q = 'Uma pista reta de 60 cm desenhada na lousa representa os 420 km corridos por um ultramaratonista. Qual é a escala desse desenho?'
  }
  'a558269d85' = @{
    q = 'Um barco percorre 40 km entre 8h e 14h, parte na maré enchente e o restante na vazante. Sua velocidade em água parada é 8 km/h, e a corrente de 2 km/h soma na enchente e subtrai na vazante. A diferença entre o tempo navegado na enchente e o navegado na vazante, em horas, é:'
  }
  '6a90f5bf03' = @{
    q = 'Os lados de uma placa triangular são números inteiros consecutivos, em dm. O perímetro em cm excede o dobro do menor lado, também em cm, em 160. Aplica-se selante de 0,5 kg por metro de perímetro. Qual a massa total necessária, em gramas?'
  }
  '36c8fe4949' = @{
    q = 'Três sensores de um motor marcam 185 °F, 333,15 K e 95 °C. O limite de segurança é ultrapassado quando a média dessas temperaturas, em Celsius, passa de 75,5 °C. Qual é a média em Celsius, o limite foi ultrapassado e, em caso afirmativo, por qual margem?'
  }
  'b7cf87d9a4' = @{
    q = 'Numa avaliação de nota máxima 7, Alexandre tirou 5,6; em outra, de nota máxima 3, tirou 2,4. Se as duas valessem 10, quais seriam suas notas, na mesma ordem, mantida a proporção de acerto?'
  }
  '17d76f003c' = @{
    q = 'Das 60 crianças, 40 gostam de futebol, 30 de basquete e 20 de vôlei. Entre as de futebol, 10 não gostam de nenhum outro esporte, 3 gostam dos três e 14 gostam também de basquete mas não de vôlei. Só 1 gosta de basquete e vôlei sem gostar de futebol. Quantas não gostam de nenhum?'
  }
  '8363f06f81' = @{
    q = 'Um cabo de aço liga o topo de um prédio de 25 m ao topo de outro de 10 m, separados por 20 m na horizontal. Qual o comprimento mínimo do cabo?'
  }
  '72e490d411' = @{
    q = 'Alex tem R$ 36,00 em moedas de 5, 10, 25 e 50 centavos. Aumentando em 30% a quantidade das de 10, 25 e 50, passa a ter R$ 46,65. Aumentando em 50% a das de 5, 10 e 25, passa a ter R$ 44,00. Quantas moedas de 50 centavos ele passou a ter?'
  }
  '20dfd007e9' = @{
    q = 'Um compartimento é formado por um retângulo de 2 m por 3 m, outro retângulo de 2 m por 2 m e um triângulo de base 1 m e altura 2 m. Qual é a área total?'
  }
  'f809bf6d3f' = @{
    q = 'Galões de óleo de R$ 5, R$ 10, R$ 25 e R$ 50 somam R$ 3.600,00 em estoque. Aumentando em 30% a quantidade dos de R$ 10, R$ 25 e R$ 50, o total vai a R$ 4.665,00. Aumentando em 50% a dos de R$ 5, R$ 10 e R$ 25, vai a R$ 4.400,00. Quantos galões de R$ 50 havia no início?'
  }
  'ae3b877a78' = @{
    q = 'Três cabos de 180, 240 e 300 m são cortados em pedaços iguais, do maior tamanho possível e sem sobras. Depois, 25% dos pedaços são descartados por avaria, e 1/3 dos restantes é enviado a uma corveta. Quantos pedaços foram enviados?'
  }
  '1176d448ef' = @{
    q = 'Uma camisa custa R$ 30,00 para produzir, e o preço de venda é o custo mais 60%. Na promoção dá-se 20% de desconto sobre esse preço, e a plataforma cobra 10% do valor pago pelo cliente. Qual o lucro líquido por camisa?'
  }
  '935647b8fc' = @{
    q = 'Um lote de 5,75 toneladas de fertilizante será posto em recipientes de 450 kg, preenchidos até no máximo 4/5 da capacidade. Quantos recipientes ficam totalmente preenchidos e quantos quilos sobram?'
  }
  'bee2c20d9a' = @{
    q = 'Alguém comprou 200 ações a R$ 50,00 cada. Depois de um ano a ação subiu 40%; ele vendeu metade por um preço 20% abaixo do valor atual e o restante pelo valor atual. Qual foi o lucro total, em reais?'
  }
  'e31d27cec2' = @{
    q = 'Um guindaste opera 43 horas e 45 minutos por semana, divididas igualmente em 6 dias. O motor consome 0,005 grama de aditivo por segundo de operação. Qual a massa de aditivo, em kg, consumida em um dia?'
  }
  'bde9a865d2' = @{
    q = 'Entre N oficiais, 42 têm certificação em Automação, 38 em Motores Diesel, 30 em Refrigeração, 12 em Automação e Refrigeração, e 15 em Diesel e Refrigeração. Ninguém tem Automação e Diesel juntas, e todos têm ao menos uma. Quanto vale N?'
  }
  '5c9f72bb41' = @{
    q = 'Vinte marinheiros treinaram Navegação, 15 treinaram Segurança e 10 treinaram Manutenção. Desses, 5 fizeram Navegação e Segurança, 4 fizeram Segurança e Manutenção, 3 fizeram Navegação e Manutenção, e 2 fizeram os três. Quantos fizeram pelo menos um treinamento?'
  }
  '4ea016b6a8' = @{
    q = 'Numa pista circular, um carrinho completa uma volta a cada 90 segundos e outro a cada 75 segundos. Partindo juntos do mesmo ponto, quantas voltas terá dado o mais rápido quando os dois se reencontrarem na partida?'
  }
  '76a398934c' = @{
    q = 'Uma empresa tem X funcionários: um gerente, que recebe R$ 900,00 por semana, e diaristas, que trabalham 3 dias por semana e recebem R$ 70,00 por dia. O gasto semanal Y com todos eles é dado por:'
  }
  '2f8a2176a9' = @{
    q = 'Um aluno copiou errado o termo constante de uma equação do 2º grau e achou as raízes −3 e −2, acertando o coeficiente do 1º grau. Outro errou esse coeficiente e achou as raízes 1 e 4, acertando o termo constante. Qual a diferença positiva entre as raízes da equação correta?'
  }
  'ce042b8b2a' = @{
    q = 'Numa escola, 180 alunos leem pelo menos um livro: 50 leem somente A, 30 somente B, 40 somente C, 25 leem A e C, 40 leem A e B, e 25 leem B e C. Quantos leem A, B e C?'
  }
  '796ef7e7ff' = @{
    q = 'Em 60 extintores, 36 têm irregularidade no lacre e 10 têm irregularidade no lacre e no manômetro. O número com irregularidade apenas no manômetro é igual ao número sem irregularidade alguma. Quantos não têm defeito no lacre?'
  }
  'de72c221a8' = @{
    q = 'Um técnico cumpre 36 horas semanais em 6 dias iguais, com dois intervalos diários de 12 minutos que não contam como trabalho. Quantos segundos de trabalho efetivo ele cumpre por dia?'
  }
  '115c360e1b' = @{
    q = 'Sejam u, v, w vetores não nulos de ℝ³. I) Se u·v=0 e v·w=0, então u e w são necessariamente ortogonais. II) Se u×v=0, todo vetor ortogonal a u também é ortogonal a v. III) Se o produto misto [u,v,w]=0, então u, v e w são linearmente dependentes. Assinale a alternativa correta:'
  }
  'cd3400bfd8' = @{
    q = 'Entre 800 famílias, 30% produzem apenas o suficiente para o próprio consumo, 22% produzem o suficiente e vendem o excedente, 33% não produzem nem o bastante para a família, e o restante nada produz. Quantas produzem, no mínimo, o suficiente para o consumo?'
  }
  'f86e7abd39' = @{
    q = 'Inquéritos sobre acidentes de navegação em 2023, por Distrito Naval: 1DN=22, 2DN=8, 3DN=6, 4DN=10, 5DN=5, 6DN=1, 7DN=1, 8DN=7, 9DN=12. Que porcentagem do total ocorreu no 4DN?'
  }
  '7d05f58fe3' = @{
    q = 'Um painel solar retangular gera 5 MWh por metro quadrado. Ele tem 3 m de largura e 6 m de comprimento, que é fixo. Para gerar no mínimo 150 MWh, qual o aumento mínimo de largura, em metros?'
  }
  '0225a815c8' = @{
    q = 'A temperatura de um forno desligado no instante t = 0 segue T(t) = −t²/4 + 400, com T em °C e t em minutos. Por segurança, a porta só pode ser aberta a 39 °C. Qual o tempo mínimo de espera, em minutos?'
  }
  '23fde60c91' = @{
    q = 'A eficiência A/E (cestas certas por erradas) classifica o jogador: EXCELENTE se A/E≥7; MUITO BOM se 5,5≤A/E<7; BOM se 3,7<A/E<5,5; REGULAR se 2,5≤A/E≤3,7; RUIM se A/E<2,5. Com 230 cestas certas e 67 erradas, a classificação é:'
  }
  '964f939f7f' = @{
    q = 'Na moeda "flor", que vale 1 real, os preços saem com desconto: um item de R$ 0,20 custa 0,15 flor, e outro de R$ 2,00 custa 1,50 flor. Qual o desconto de quem compra 5 unidades do primeiro e 3 do segundo pagando em flor?'
  }
  '2f18e5b690' = @{
    q = 'Foram distribuídos 144 cadernos, 192 lápis e 216 borrachas entre o maior número possível de famílias, todas recebendo a mesma quantidade de cada material, sem sobra. Quantos cadernos cada família recebeu?'
  }
  '2de99f40b6' = @{
    q = 'O mesmo celular custa R$ 800,00 com 15% de desconto na loja A, R$ 750,00 com 8% de desconto na loja B e R$ 850,00 com 20% de desconto na loja C. Em qual loja é mais vantajoso comprar?'
  }
  '5a3b3f8384' = @{
    q = 'Numa turma, 23 alunos torcem pelo Grêmio, 23 pelo Corinthians e 15 pelo Internacional; 6 torcem por Grêmio e Internacional, 5 por Internacional e Corinthians, e nenhum torce por Grêmio e Corinthians ao mesmo tempo. Quantos alunos há na turma?'
  }
  'db88237b4c' = @{
    q = 'Sessenta empregados fizeram pelo menos um de dois cursos. Dos que fizeram Cuidados Médicos, 75% também fizeram Segurança; dos que fizeram Segurança, 60% também fizeram Cuidados Médicos. Quantos fizeram os dois cursos?'
  }
  'b3e8597f4f' = @{
    q = 'O Terminal A carrega um navio a cada 40 minutos, e o Terminal B, a cada 50 minutos. Começando juntos, quantos navios o Terminal B terá carregado quando os dois voltarem a iniciar um carregamento ao mesmo tempo?'
  }
  '55aa2a91f0' = @{
    q = 'Produção diária de lixo, em kg. Rebocador 1 — 2ª:2, 3ª:5, 4ª:9, 5ª:6, 6ª:3, sáb:7, dom:10. Rebocador 2 — 2ª:1, 3ª:1, 4ª:3, 5ª:1, 6ª:2, sáb:3, dom:10. Em que dia da semana as duas produções foram iguais?'
  }
  'db890c498f' = @{
    q = 'Com 240 m de cerca, cerca-se um campo retangular à margem de um rio reto, sem cercar o lado do rio: dois lados de medida x, perpendiculares ao rio, e um lado y, paralelo a ele. Se a área é 7.000 m², quais são x e y?'
  }
  '295d55bba9' = @{
    q = 'Numa escola, 200 estudantes leram pelo menos um livro: 60 leram somente X, 35 somente Y, 45 somente Z, 30 leram X e Z, 50 leram X e Y, e 30 leram Y e Z. Quantos leram X, Y e Z?'
  }
  'a44bc541cb' = @{
    q = 'Ontem, 4 caixas de leite e 6 pães custaram R$ 12,00. Hoje, com o leite em promoção e o pão pelo mesmo preço, 8 caixas e 12 pães custaram R$ 20,00. De quanto foi o desconto em cada caixa de leite?'
  }
  '7beef5381f' = @{
    q = 'A temperatura do ar no equador é 30 °C e diminui 2,5% a cada 100 milhas náuticas em direção aos polos. Qual a temperatura aproximada a 200 milhas náuticas do equador?'
  }
  '6114895765' = @{
    q = 'Numa pesquisa, 3/8 das 240 mulheres entrevistadas usaram transporte público na última semana. Esse número é 30% do número de homens entrevistados que fizeram o mesmo. Quantos homens usaram transporte público?'
  }
  'f47b8e1e93' = @{
    q = 'Um reservatório de 40 cm por 25 cm por 20 cm, já com água, recebe 500 cubos metálicos idênticos totalmente submersos. O volume não ocupado pelos cubos passa a ser 16 dm³. Qual o volume de cada cubo, em cm³?'
  }
  'f9c0cc629a' = @{
    q = 'Numa pista circular, três corredores completam uma volta em 80, 96 e 120 segundos. Partindo juntos, após quantos segundos estarão novamente alinhados na linha de partida?'
  }
  '02d622733d' = @{
    q = 'O cabo de uma âncora, totalmente esticado, tem 60 m e vai do navio até o fundo, a 48 m de profundidade, formando um triângulo retângulo. Qual a distância horizontal entre o navio e a âncora?'
  }
  '9ee7358d72' = @{
    q = 'Um produto vendido a R$ 26,00 dá ao vendedor 30% de lucro sobre o custo. Ele quer manter no mínimo 15% de lucro sobre o custo. Qual o maior desconto inteiro, em porcentagem sobre os R$ 26,00, que ele pode dar?'
  }
  '1e1c626eaa' = @{
    q = 'Uma confeitaria quer uma caixa com base de no mínimo 120 cm², ao menor custo. Opções: I) 11×11 cm, R$ 0,45/cm²; II) 13×8 cm, R$ 0,40/cm²; III) 12×10 cm, R$ 0,38/cm²; IV) 10,5×10,5 cm, R$ 0,42/cm²; V) 16×7,5 cm, R$ 0,39/cm². Qual escolher?'
  }
  '1d080a4fc8' = @{
    q = 'Doze marinheiros reparam uma seção do navio em 15 dias, trabalhando 7 horas por dia. Para fazer o mesmo trabalho em 10 dias, mantida a jornada diária, quantos marinheiros são necessários?'
  }
  'ed6bcac26a' = @{
    q = 'Todos os 67 alunos de uma turma participam de Música, de Xadrez ou dos dois. 52 participam de Música. O número dos que participam dos DOIS é igual ao dos que participam APENAS de Xadrez. Quantos participam SOMENTE de Música?'
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
