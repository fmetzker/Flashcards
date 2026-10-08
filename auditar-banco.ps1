# Mede o banco contra o padrao de PADRAO-DOS-CARTOES.md.
#
# ESTE ARQUIVO NAO MEDE NADA POR CONTA PROPRIA — ele chama o auditar-banco.py,
# pela mesma razao que o validar.ps1 chama o validar.py: duas implementacoes
# das mesmas checagens divergem, e a que fica para tras passa a medir menos
# sem avisar. Sem Python, este script para em vez de medir pela metade.
#
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1 -Listar
#   powershell -ExecutionPolicy Bypass -File auditar-banco.ps1 -Csv saida.csv
#
# Como o .py, NAO reprova nada: mede qualidade, que e gradiente, nao regra.
#
# ATENCAO ao editar: .ps1 com acento precisa de UTF-8 COM BOM. Este arquivo
# evita acento de proposito, para nao depender disso.

param(
  [switch]$Listar,
  [string]$Csv
)

$ErrorActionPreference = 'Stop'
$alvo = Join-Path $PSScriptRoot 'auditar-banco.py'

$exe = $null
foreach ($c in @('py', 'python', 'python3')) {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if ($cmd) { $exe = $cmd.Source; break }
}
if (-not $exe) {
  Write-Host "ERRO: Python nao encontrado — o banco NAO foi auditado." -ForegroundColor Red
  exit 1
}

$argumentos = @($alvo)
if ($Listar) { $argumentos += '--listar' }
if ($Csv)    { $argumentos += @('--csv', $Csv) }

& $exe @argumentos
