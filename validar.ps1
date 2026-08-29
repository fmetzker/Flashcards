# Roda o validador do projeto.
#
# ESTE ARQUIVO NAO VALIDA NADA POR CONTA PROPRIA — ele chama o validar.py.
#
# Ate agosto/2026 havia aqui uma SEGUNDA implementacao do validador, escrita
# para "maquinas sem Python". As duas divergiram: o .py chegou a 76 checagens
# e este a 25, e o que faltava nao era detalhe — este arquivo nao conferia
# banco/requisitos.json NEM banco/topicos.json de jeito nenhum. Toda a
# engrenagem de pre-requisito e de escada de nivel (ciclo, limite de ondas
# puladas, "toda materia tem topico que abre", nivel fora de 1-9) so existia
# no .py.
#
# Isso importava de verdade porque incorporar-rascunho.ps1 e
# explicar-alternativas.ps1 gateavam AQUI: a garantia que a regra 9 do
# CLAUDE.md descreve ("rodam validar de verdade antes de gravar, falham
# fechado") estava rodando a um terco da forca. Cartao novo podia entrar no
# banco passando por checagem que o validador de verdade reprovaria.
#
# Manter duas implementacoes em sincronia e trabalho que ninguem faz duas
# vezes seguidas. Uma so, e este arquivo vira a conveniencia de chamar do
# jeito de sempre.
#
# CONSEQUENCIA ASSUMIDA: sem Python, a validacao PARA, em vez de rodar pela
# metade. E o comportamento certo — falhar fechado —, mas e uma mudanca real
# em relacao ao que este arquivo prometia antes.
#
#   powershell -ExecutionPolicy Bypass -File validar.ps1
#   powershell -ExecutionPolicy Bypass -File validar.ps1 -Rascunho rascunho.json
#   powershell -ExecutionPolicy Bypass -File validar.ps1 -Patches explicacoes.json
#
# Sai com o mesmo codigo de saida do validar.py: 1 se houver erro que impeca
# a publicacao.
#
# ATENCAO ao editar: arquivos .ps1 com acentos precisam ser gravados em UTF-8
# COM BOM, senao o PowerShell 5.1 os le como ANSI e o parser quebra. Este
# arquivo evita acento de proposito, para nao depender disso.

param(
  [string]$Rascunho,
  [string]$Patches
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$alvo = Join-Path $raiz 'validar.py'

if (-not (Test-Path $alvo)) {
  Write-Host "ERRO: validar.py nao encontrado ao lado deste script." -ForegroundColor Red
  exit 1
}

# 'py' e o launcher que vem com o instalador oficial no Windows; 'python' e
# 'python3' cobrem instalacao por Store, winget ou PATH manual.
$exe = $null
foreach ($c in @('py', 'python', 'python3')) {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if ($cmd) { $exe = $cmd.Source; break }
}

if (-not $exe) {
  Write-Host ""
  Write-Host "ERRO: Python nao encontrado — o banco NAO foi validado." -ForegroundColor Red
  Write-Host "Nada foi conferido: nao publique." -ForegroundColor Red
  Write-Host "Instale o Python (https://python.org) e rode de novo."
  exit 1
}

$argumentos = @($alvo)
if ($Rascunho) { $argumentos += @('--rascunho', $Rascunho) }
if ($Patches)  { $argumentos += @('--patches',  $Patches) }

& $exe @argumentos
exit $LASTEXITCODE
