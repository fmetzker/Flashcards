# Gera offline.html: o app inteiro num arquivo só.
#
# Desde a Fase 0 o banco vive em banco/*.json e é lido por fetch, o que exige um
# servidor — abrir o index.html com duplo clique não funciona, porque o
# navegador bloqueia fetch em file://. Este script embute os dados no HTML, em
# window.DADOS, de onde a função pega() do app os lê sem requisição nenhuma.
#
#   powershell -ExecutionPolicy Bypass -File gerar-offline.ps1
#
# O resultado é um arquivo único, sem servidor e sem rede: dá para abrir com
# duplo clique, mandar por e-mail ou levar num pendrive. É um artefato gerado —
# não editar à mão; mexa no index.html e rode isto de novo.
#
# ATENÇÃO ao editar: .ps1 com acento precisa ser gravado em UTF-8 COM BOM.

param([string]$Saida = 'offline.html')

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$dir  = Join-Path $raiz 'banco'
$html = Join-Path $raiz 'index.html'

# ---- reúne os dados na mesma chave que o app usa em pega() -------------------

# supabase.json entra aqui por consistência (tudo que pega() pode ler fica
# embutido), mas a seção Conta se declara indisponível nesta versão antes de
# sequer olhar para ele — não há rede em file:// para autenticar.
$arquivos = @('concursos.json', 'banco/materias.json', 'banco/indice-legado.json', 'supabase.json',
                'banco/reescritas.json', 'banco/topicos.json', 'banco/requisitos.json')
$materias = [System.IO.File]::ReadAllText((Join-Path $dir 'materias.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
foreach ($m in $materias) { $arquivos += "banco/$($m.id).json" }

$partes = @()
foreach ($a in $arquivos) {
  $caminho = Join-Path $raiz ($a -replace '/', '\')
  if (-not (Test-Path $caminho)) { throw "arquivo ausente: $a" }
  # o JSON entra cru: já é JavaScript válido, e assim não há reserialização
  # nem risco de alterar acentuação ou ordem
  $conteudo = [System.IO.File]::ReadAllText($caminho, [System.Text.Encoding]::UTF8).Trim()
  $partes += '"' + $a + '":' + $conteudo
}
$dados = "window.DADOS={`n" + ($partes -join ",`n") + "`n};"

# ---- figuras dos enunciados (campo img, PADRAO-DOS-CARTOES.md §1.8) ----------
# Um arquivo único não pode apontar para banco/img/: cada figura entra como
# data URI em window.IMAGENS, de onde srcFigura() a lê. A lista sai dos
# próprios cartões — imagem sem cartão não entra, cartão sem imagem não quebra.
$mime = @{ '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.webp' = 'image/webp' }
$figuras = [ordered]@{}
foreach ($m in $materias) {
  $qs = [System.IO.File]::ReadAllText((Join-Path $dir "$($m.id).json"), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  foreach ($q in $qs) {
    if (-not $q.img -or $figuras.Contains($q.img)) { continue }
    $arq = Join-Path $dir ($q.img -replace '/', '\')
    if (-not (Test-Path $arq)) { throw "figura ausente: banco/$($q.img) (cartão $($q.id))" }
    $ext = [System.IO.Path]::GetExtension($arq).ToLower()
    if (-not $mime.ContainsKey($ext)) { throw "formato de figura não aceito: $($q.img)" }
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($arq))
    $figuras[$q.img] = "data:$($mime[$ext]);base64,$b64"
  }
}
$partesImg = foreach ($k in $figuras.Keys) { '"' + $k + '":"' + $figuras[$k] + '"' }
$dados += "`nwindow.IMAGENS={" + (@($partesImg) -join ",`n") + "};"

# ---- injeta no HTML ----------------------------------------------------------

$fonte = [System.IO.File]::ReadAllText($html, [System.Text.Encoding]::UTF8)

# O motor vive em motor.js, carregado por <script src> no app publicado. Num
# arquivo unico isso nao funciona (seria um segundo arquivo, que e justamente
# o que o offline.html existe para evitar), entao a tag e trocada pelo
# conteudo. Tem que vir ANTES do bloco inline, igual no index.html: o motor so
# define funcoes, e o inline declara os globais e dispara o boot.
$motorArq = Join-Path $raiz 'motor.js'
if (-not (Test-Path $motorArq)) { throw "motor.js nao encontrado" }
$motor = [System.IO.File]::ReadAllText($motorArq, [System.Text.Encoding]::UTF8)
$tagMotor = '<script src="motor.js"></script>'
if ($fonte -notlike "*$tagMotor*") { throw "tag do motor.js nao encontrada no index.html" }
$fonte = $fonte.Replace($tagMotor, "<script>`n$motor`n</script>")

# `</script>` dentro de uma string quebraria a tag; nenhum dado do banco tem
# isso hoje, mas a conferência é barata e a falha seria silenciosa
if ($dados -match '(?i)</script') { throw "os dados contêm '</script' e quebrariam o HTML" }

$marca = '<script>'
$i = $fonte.IndexOf($marca)
if ($i -lt 0) { throw "bloco <script> não encontrado no index.html" }

$aviso = @"
<!-- ARQUIVO GERADO por gerar-offline.ps1 — não editar à mão.
     Mexa no index.html e nos arquivos de banco/, depois rode o script de novo. -->
"@

$novo = $fonte.Substring(0, $i) +
        "$aviso`n<script>`n$dados`n</script>`n" +
        $fonte.Substring($i)

# o service worker não faz sentido num arquivo solto e tentaria buscar sw.js
$novo = $novo -replace '<link rel="manifest" href="manifest.json">', ''

$destino = Join-Path $raiz $Saida
[System.IO.File]::WriteAllText($destino, $novo, (New-Object System.Text.UTF8Encoding $false))

$kb = [math]::Round((Get-Item $destino).Length / 1KB)
Write-Host "gerado $Saida — $kb KB, $($arquivos.Count) arquivos embutidos"
Write-Host "abra com duplo clique; não precisa de servidor nem de internet"
