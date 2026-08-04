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
$arquivos = @('concursos.json', 'banco/materias.json', 'banco/indice-legado.json', 'supabase.json')
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

# ---- injeta no HTML ----------------------------------------------------------

$fonte = [System.IO.File]::ReadAllText($html, [System.Text.Encoding]::UTF8)

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
