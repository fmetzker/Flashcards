# Servidor estático para testar o app localmente.
#
# Desde a Fase 0 o banco vive em banco/*.json e é lido por fetch, então abrir
# o index.html direto do disco (file://) não funciona mais: o navegador bloqueia
# a leitura. Este script serve a pasta por http, sem instalar nada.
#
#   powershell -ExecutionPolicy Bypass -File servidor.ps1
#   depois abra http://localhost:8080
#
# Ctrl+C para parar.
#
# ATENÇÃO ao editar: arquivos .ps1 com acentos precisam ser gravados em UTF-8
# COM BOM, senão o PowerShell 5.1 os lê como ANSI e o parser quebra.

param([int]$Porta = 8080)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot

$tipos = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.png'  = 'image/png'
  '.svg'  = 'image/svg+xml'
}

$ouvinte = New-Object System.Net.HttpListener
$ouvinte.Prefixes.Add("http://localhost:$Porta/")
$ouvinte.Start()
Write-Host "servindo $raiz em http://localhost:$Porta  (Ctrl+C para parar)"

try {
  while ($ouvinte.IsListening) {
    $ctx = $ouvinte.GetContext()
    # uma requisição com problema não pode derrubar o servidor
    try {
      $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      if ($rel -eq '') { $rel = 'index.html' }

      $caminho = Join-Path $raiz $rel
      # não deixa sair da pasta do projeto
      $completo = [System.IO.Path]::GetFullPath($caminho)
      $dentro = $completo.StartsWith([System.IO.Path]::GetFullPath($raiz), [StringComparison]::OrdinalIgnoreCase)

      if ($dentro -and (Test-Path $completo -PathType Leaf)) {
        $ext = [System.IO.Path]::GetExtension($completo).ToLower()
        $ctx.Response.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { 'application/octet-stream' }
        $ctx.Response.Headers['Cache-Control'] = 'no-store'
        $bytes = [System.IO.File]::ReadAllBytes($completo)
        # Close(bytes, true) cuida do Content-Length e do fechamento do fluxo
        $ctx.Response.Close($bytes, $true)
        Write-Host "200 $rel"
      } else {
        $ctx.Response.StatusCode = 404
        $ctx.Response.Close()
        Write-Host "404 $rel"
      }
    } catch {
      Write-Host "erro ao responder: $($_.Exception.Message)"
      try { $ctx.Response.Abort() } catch {}
    }
  }
} finally {
  $ouvinte.Stop()
  $ouvinte.Close()
}
