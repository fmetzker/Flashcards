# Fase 1b — subdivide em tópicos as matérias que ficaram com um tópico só.
#
# Depois da Fase 1, 10 das 20 matérias tinham um único tópico, com o mesmo nome
# da matéria: "Imunização > Imunização", 66 questões. A árvore existia mas não
# dividia nada. Este script reclassifica o campo `t` usando a fonte e o
# enunciado — que já carregam o assunto — em tópicos de verdade.
#
# O `t` NÃO faz parte do id (que é o SHA-1 do enunciado), então reclassificar
# não custa nenhum progresso salvo.
#
# Sem argumento faz apenas a simulação e imprime o resultado com amostras.
# Com -Aplicar grava os arquivos.
#
#   powershell -ExecutionPolicy Bypass -File fase1b-topicos.ps1
#   powershell -ExecutionPolicy Bypass -File fase1b-topicos.ps1 -Aplicar
#
# ATENÇÃO ao editar: .ps1 com acento precisa ser gravado em UTF-8 COM BOM.

param([switch]$Aplicar)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $PSScriptRoot 'banco'

# Regras por matéria, na ordem: a primeira que casar vence. A última entrada de
# cada lista tem padrão vazio e funciona como destino do que não casou com nada.
$REGRAS = [ordered]@{
  'urgencia' = @(
    @('Parada cardiorrespiratória e RCP', 'RCP|parada cardiorrespirat|reanima|desfibril|AHA|Suporte Básico|Suporte Avançado|compress(ão|ões) torácic|cadeia de sobreviv|DEA'),
    @('Trauma e atendimento pré-hospitalar','trauma|ATLS|pré-hospitalar|imobiliza|colar cervical|prancha|fratura|politrauma|acidente de trânsito'),
    @('Intoxicações e emergências ambientais','intoxica|envenenamento|carvão ativado|ofídic|peçonhent|picada|escorpi|afogamento|hipotermia|insolação|queimadur|emergências ambientais'),
    @('Emergências cardiovasculares',      'cardiovascular|infarto|IAM|síndrome coronarian|angina|arritmi|fibrila|edema agudo de pulmão|crise hipertensiv|dor torácic|eletrocardiograma|choque cardiogênico'),
    @('Emergências neurológicas',          'AVC|acidente vascular|convuls|epilé|Glasgow|TCE|traumatismo cranio|neurológic'),
    @('Emergências respiratórias e via aérea','ventilação mecânica|via aérea|vias aéreas|intuba|oxigenoterapia|insuficiência respiratóri|asma|broncoespasmo|engasg|obstrução das vias|traqueostom|saturaç'),
    @('Choque, sepse e anafilaxia',        'choque|sepse|séptic|hipovolêm|anafila|anafilátic'),
    @('Cuidados ao paciente crítico',      'paciente crítico|terapia intensiva|UTI|monitoriz|sedaç|hemodinâmic|cateter|pressão arterial invasiv|drogas vasoativ|balanço hídric|delirium'),
    @('Acolhimento e classificação de risco','classificação de risco|acolhimento|Manchester|triagem|regulaç|SAMU|rede de atenção às urgênci|PNAU|transferência'),
    @('Emergências clínicas',              '')
  )
  'imunizacao' = @(
    @('Rede de frio',                      'rede de frio|conservaç|temperatura|termômetr|caixa térmic|refrigerad|bobina'),
    @('Eventos adversos pós-vacinação',    'evento adverso|EAPV|ESAVI|evento supostamente atribuível|reação.*vacin'),
    @('Profilaxia da raiva',               'raiva|antirrábic'),
    @('Imunobiológicos especiais e CRIE',  'CRIE|imunobiológico especial|imunoglobulin'),
    @('Calendário vacinal',                'calendário|pentavalente|tríplice viral|tetraviral|dupla adulto|esquema básic|esquema vacinal|primeira dose|dose de reforço|reforço da vacina|intervalo mínimo'),
    @('Técnica e vias de administração',   'via de administraç|via intramuscular|via subcutân|via intradérmic|administrada por via|agulha|seringa|técnica de aplicaç|deltoide|vasto lateral'),
    @('Situações especiais e contraindicações','contraindicaç|gestante|imunossuprim|indígena|viajante|prematur|HIV|grupos prioritári|bloqueio'),
    @('Normas e procedimentos de vacinação','')
  )
  'mulher' = @(
    @('Emergências obstétricas',           'eclâmpsia|hemorragia pós-parto|emergência.*obstétric|descolamento prematuro|placenta prévia|distócia|abortamento|sangramento vaginal|gravidez ectópica|sulfato de magnésio'),
    @('Pré-natal',                         'pré-natal|prenatal|gestação de alto risco|idade gestacional|altura uterina|caderneta da gestante|Naegele'),
    @('Parto e nascimento',                'parto|partograma|nascimento|dilataç|episiotomia|cesária|cesarian|11\.108'),
    @('Puerpério',                         'puerpéri|pós-parto|lóquio|involuç'),
    @('Aleitamento materno',               'aleitamento|amamenta|ordenha|pega correta|mastite|leite materno'),
    @('Planejamento reprodutivo',          'planejamento reprodutiv|contracep|anticoncep|LARC|DIU|laqueadura|vasectomia'),
    @('Rastreamento de câncer',            'citopatológic|colo do útero|câncer de mama|mamografi|rastreamento|Papanicolau|autoexame'),
    @('Climatério e violência',            'climatéri|menopaus|violência'),
    @('Saúde da mulher — atenção básica',  '')
  )
  'crianca' = @(
    @('Triagem neonatal',                  'teste do pezinho|orelhinha|olhinho|coraçãozinho|linguinha|triagem neonatal|reflexo vermelho'),
    @('Recém-nascido',                     'recém-nascid|neonat|Apgar|coto umbilical|morte súbita|icterícia|clampeamento'),
    @('Violência e proteção da criança',   'violência|maus-tratos|Conselho Tutelar|negligênci|abuso'),
    @('Crescimento e desenvolvimento',     'crescimento|desenvolvimento|percentil|curva|caderneta|puericultura|marcos'),
    @('Alimentação e nutrição infantil',   'alimenta|nutriç|desnutriç|obesidade infantil|vitamina A|aleitamento|leite materno|ordenha|mel|ferro'),
    @('Doenças comuns da infância',        'diarrei|desidrataç|otite|dermatite|monilíase|refluxo|AIDPI|sinais gerais de perigo|bronquiolite|pneumonia|sibil|verminose|escabiose'),
    @('Saúde do adolescente',              'adolescên|ao adolescente|do adolescente|puberdade'),
    @('Saúde da criança — atenção básica', '')
  )
  'fundamentos' = @(
    @('Estomias',                          'estomi|colostomi|ileostomi|bolsa coletora|peristoma'),
    @('Avaliação e classificação de feridas','classificaç.*ferida|cicatrizaç|estágio|lesão por pressão|úlcera|Braden|tecido de granulaç|necros'),
    @('Curativos e coberturas',            'curativ|cobertura|desbridamento|alginato|hidrocoloide|papaína|carvão ativado|exsudat'),
    @('Sondagens e cateterismo',           'sonda|cateter|gastrostomi|vesical|nasoenteral|nasogástric'),
    @('Punção venosa e terapia intravenosa','punção venos|acesso venos|flebite|infiltraç|terapia intravenos|scalp|extravasamento'),
    @('Coleta de exames',                  'hemocultur|coleta|amostra|urina tipo|glicemia capilar|hemoglicotest|swab'),
    @('Oxigenoterapia e aspiração',        'oxigenoterapia|aspiraç|nebuliza|cânula|máscara de'),
    @('Sinais vitais e avaliação',         'sinais vitais|temperatura axilar|pulso|pressão arterial|frequência respiratóri|saturaç|escala de dor|antropometr'),
    @('Higiene, conforto e mobilidade',    'higiene|banho|posicionamento|mobiliz|transferência do paciente|decúbit'),
    @('Procedimentos de enfermagem',       '')
  )
  'infeccao' = @(
    @('Limpeza, desinfecção e resíduos',   'resíduo|grupo E|RDC 222|limpeza terminal|limpeza concorrente|desinfecção de superfície|saneante|Spaulding|artigo crític|semicrític|rastreabilidade|artigos processad'),
    @('Acidente com material biológico',   'material biológic|perfurocortant|acidente ocupacional|profilaxia pós-exposiç'),
    @('Precauções e isolamento',           'precauç|isolamento|aerossó|gotícul|máscara N95|quarto privativ'),
    @('EPI',                               'EPI|equipamento de proteção|luva|avental|óculos de proteç|paramenta'),
    @('Higienização das mãos',             'higieniza.*mãos|lavagem das mãos|álcool.*70|fricção antissépt|cinco momentos'),
    @('IRAS e vigilância de infecção',     'IRAS|infecção relacionada|CCIH|SCIH|infecção hospitalar|bundle|notificaç.*infecç|surto|sítio cirúrgic|antibioticoprofilaxia'),
    @('Identificação e cirurgia segura',   'identificação do paciente|pulseira|marcação do sítio|cirurgia segura|checklist|lista de verificaç'),
    @('Prevenção de quedas e lesões',      'Morse|risco de queda|prevenção de queda|lesão por pressão|contenç'),
    @('Metas de segurança do paciente',    'SBAR|meta internacional|near miss|never event|notificação de incidente|cultura de segurança|NSP|PNSP|protocolos básicos|dupla checagem|evento adverso'),
    @('Controle de infecção',              '')
  )
  'medicamentos' = @(
    @('Cálculo de dose e gotejamento',     'cálculo|gotejamento|gotas|infusão|diluiç|concentraç|regra de três|mL/h'),
    @('Medicamentos controlados',          '344/1998|psicotrópic|controle especial|entorpecent'),
    @('Segurança na administração',        'segurança|certos|erro de medicaç|dupla checagem|prescriç|abreviatur|nomes ou embalagens'),
    @('Vias de administração',             'via |parenteral|intramuscular|endovenos|intravenos|subcutân|sublingual|sonda|insulin'),
    @('Farmacologia aplicada',             '')
  )
  'adulto-idoso' = @(
    @('Violência e proteção da pessoa idosa','maus-tratos|violência|negligênci|Estatuto da Pessoa Idosa'),
    @('Avaliação funcional e fragilidade', 'capacidade funcional|fragilidade|AVD|atividades de vida diária|polifarmác|ILPI|Timed Up|Katz|Lawton|síndrome.*geriátric|gigantes da geriatria'),
    @('Saúde do idoso',                    'idos|geriátric|delirium|demênci|envelhec|Caderneta de Saúde da Pessoa Idosa'),
    @('Saúde do homem',                    'homem|próstata|PSA|masculin|vasectomia'),
    @('Reabilitação',                      'reabilitaç|deficiênci|órtese|prótese'),
    @('Diabetes mellitus',                 'diabet|glicemi|insulin|hipoglicem|pé diabétic|hemoglobina glicad'),
    @('Hipertensão arterial',              'hipertens|pressão arterial|HAS|anti-hipertensiv'),
    @('Obesidade e fatores de risco',      'obesidade|sobrepeso|IMC|tabagis|sedentar|alimentação saudável|circunferência abdominal'),
    @('Câncer e cuidados paliativos',      'câncer|neoplasi|paliativ|quimioterapi|oncológ'),
    @('Doenças crônicas — atenção básica', '')
  )
  'cirurgica' = @(
    @('CME e processamento de materiais',  'CME|esteriliz|autoclave|desinfecç|processamento|termodesinfecç|indicador biológic|Bowie-Dick|embalagem|artigo crític'),
    @('Período perioperatório',            'pré-operatóri|pós-operatóri|perioperatóri|SRPA|recuperação anestésic|jejum|tricotomi|consentimento'),
    @('Centro cirúrgico',                  '')
  )
  'mental' = @(
    @('RAPS e reforma psiquiátrica',       'RAPS|3\.088|CAPS|reforma psiquiátric|10\.216|residência terapêutic|matriciamento|De Volta para Casa|desinstitucionaliz|leito.*psiquiátric'),
    @('Álcool e outras drogas',            'álcool|drogas|redução de danos|abstinênci|dependência químic|tabaco'),
    @('Prevenção do suicídio',             'suicíd|automutila|autoextermín'),
    @('Psicofarmacologia',                 'farmacolog|antipsicót|lítio|benzodiazep|antidepress|neurolépt|haloperidol'),
    @('Transtornos e cuidado em crise',    '')
  )
  'etica' = @(
    @('Código de Ética',                   'Código de Ética|564/2017|sigilo|infraç|penalidade'),
    @('Exercício profissional',            '7\.498|5\.905|COREN|COFEN|exercício profissional|responsabilidade técnic|privativ|estágio|supervis'),
    @('Educação permanente',               'educação permanente|educação continuada|capacitaç'),
    @('Responsabilidade e consentimento',  '')
  )
  'anatomia' = @(
    @('Sistema cardiovascular e respiratório','coraç|cardíac|sangu|artéri|veia|venos|circulat|hemácia|átrio|ventrícul|pulm|respiratóri|alvéol|brônqui|hematose'),
    @('Sistemas digestório, urinário e endócrino','digest|estômag|intestin|fígad|pâncreas|bile|rim|renal|urin|bexiga|néfron|hipófise|tireoid|hormôni|adrenal'),
    @('Anatomia e fisiologia geral',       '')
  )
}

# ---- carrega -----------------------------------------------------------------

$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$mudancas = 0

foreach ($m in $materias) {
  if (-not $REGRAS.Contains($m.id)) { continue }
  $arq = Join-Path $dir "$($m.id).json"
  $qs = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  # nome diferente de $REGRAS de propósito: nomes de variável no PowerShell não
  # diferenciam maiúsculas, e "$regras = $REGRAS[...]" apagaria o dicionário
  $daMateria = $REGRAS[$m.id]

  foreach ($q in $qs) {
    $palheiro = "$($q.f) $($q.q) $($q.e)"
    $novo = $null
    foreach ($r in $daMateria) {
      if ($r[1] -eq '') { $novo = $r[0]; break }
      if ($palheiro -imatch $r[1]) { $novo = $r[0]; break }
    }
    if ($q.t -ne $novo) { $mudancas++ }
    $q | Add-Member -NotePropertyName tNovo -NotePropertyValue $novo -Force
  }

  Write-Host "`n=== $($m.nome) — $($qs.Count) questões"
  $qs | Group-Object tNovo | Sort-Object Count -Descending | ForEach-Object {
    Write-Host ("  {0,4}  {1}" -f $_.Count, $_.Name)
    # nada de Select-Object -First aqui: dentro de um ForEach-Object ele
    # interrompe também o laço externo
    if (-not $Aplicar) {
      $amostra = @($_.Group)
      for ($i = 0; $i -lt [Math]::Min(2, $amostra.Count); $i++) {
        $t = $amostra[$i].q -replace '\s+', ' '
        Write-Host ("          · " + $t.Substring(0, [Math]::Min(88, $t.Length)))
      }
    }
  }

  if ($Aplicar) {
    $novos = $qs | ForEach-Object {
      [pscustomobject]@{ id=$_.id; m=$_.m; t=$_.tNovo; q=$_.q; o=$_.o; c=$_.c; e=$_.e; f=$_.f }
    }
    $corpo = ($novos | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }) -join ",`n"
    [System.IO.File]::WriteAllText($arq, "[`n$corpo`n]`n", (New-Object System.Text.UTF8Encoding $false))
  }
}

Write-Host "`n$mudancas questões mudariam de tópico."
if (-not $Aplicar) { Write-Host "Simulação — nada foi gravado. Use -Aplicar para valer." }
