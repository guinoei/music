param([int]$Port = 8080)
$ErrorActionPreference = 'Stop'
$siteRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.json'='application/json'; '.svg'='image/svg+xml'; '.png'='image/png'; '.ico'='image/x-icon' }
$listener.Start()
Write-Output "Signal lab: http://localhost:$Port (Ctrl+C to stop)"
try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $client.ReceiveTimeout = 2000
      $stream = $client.GetStream()
      $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
      $request = $reader.ReadLine()
      if (!$request) { continue }
      while ($reader.ReadLine()) {}
      $parts = $request.Split(' ')
      $relative = [Uri]::UnescapeDataString(($parts[1] -split '\?')[0]).TrimStart('/')
      if (!$relative) { $relative = 'index.html' }
      $path = [IO.Path]::GetFullPath((Join-Path $siteRoot $relative))
      $extension = [IO.Path]::GetExtension($path)
      $status = '200 OK'
      $mime = $types[$extension]
      if ($parts[0] -notin @('GET','HEAD') -or !$path.StartsWith($siteRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or !$mime -or !(Test-Path -LiteralPath $path -PathType Leaf)) {
        $status = '404 Not Found'; $mime = 'text/plain'; $body = [Text.Encoding]::UTF8.GetBytes('Not found')
      } else { $body = [IO.File]::ReadAllBytes($path) }
      $headers = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $mime`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nReferrer-Policy: strict-origin-when-cross-origin`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n")
      $stream.Write($headers,0,$headers.Length)
      if ($parts[0] -ne 'HEAD') { $stream.Write($body,0,$body.Length) }
    } catch { Write-Verbose $_ } finally { $client.Dispose() }
  }
} finally { $listener.Stop() }
