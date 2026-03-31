param(
  [string]$BaseUrl = "http://localhost:3000",
  [string]$TenantCode = "ulv-demo"
)

$ErrorActionPreference = "Stop"

function Write-Section($text) {
  Write-Host ""
  Write-Host "=== $text ===" -ForegroundColor Cyan
}

function Invoke-JsonRequest {
  param(
    [string]$Method,
    [string]$Url,
    [hashtable]$Headers = @{},
    $Body = $null
  )

  try {
    $hasHeaders = $Headers -and $Headers.Count -gt 0
    if ($null -ne $Body) {
      $json = ($Body | ConvertTo-Json -Depth 10)
      if ($hasHeaders) {
        return Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Url -Headers $Headers -Body $json -ContentType "application/json"
      }
      return Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Url -Body $json -ContentType "application/json"
    }
    if ($hasHeaders) {
      return Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Url -Headers $Headers
    }
    return Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Url
  } catch {
    if ($_.Exception.Response) {
      return $_.Exception.Response
    }
    throw
  }
}

function Assert-Status {
  param(
    [string]$CaseName,
    [int]$Expected,
    $Response
  )
  $actual = [int]$Response.StatusCode
  if ($actual -ne $Expected) {
    Write-Host "[FAIL] $CaseName -> esperado $Expected, actual $actual" -ForegroundColor Red
    try {
      $sr = New-Object System.IO.StreamReader($Response.GetResponseStream())
      $sr.BaseStream.Position = 0
      $sr.DiscardBufferedData()
      $content = $sr.ReadToEnd()
      if ($content) { Write-Host "Body: $content" -ForegroundColor DarkYellow }
    } catch {}
    return $false
  }
  Write-Host "[OK]   $CaseName -> $actual" -ForegroundColor Green
  return $true
}

function Login-Token {
  param(
    [string]$Email,
    [string]$Password
  )
  $resp = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/auth/login" -Body @{
    tenantCode = $TenantCode
    email = $Email
    password = $Password
  }
  if ([int]$resp.StatusCode -ne 200) {
    throw "Login falló para $Email (status $($resp.StatusCode))"
  }
  $json = $resp.Content | ConvertFrom-Json
  return [string]$json.accessToken
}

Write-Section "Health check"
$health = Invoke-JsonRequest -Method "GET" -Url "$BaseUrl/health"
if ([int]$health.StatusCode -ne 200) {
  throw "Backend no disponible en $BaseUrl"
}
Write-Host $health.Content

Write-Section "Carga de variables requeridas"

# Credenciales
$fieldEmail = $env:E2E_FIELD_EMAIL
$fieldPass = $env:E2E_FIELD_PASS
$pastorEmail = $env:E2E_PASTOR_EMAIL
$pastorPass = $env:E2E_PASTOR_PASS
$directorEmail = $env:E2E_DIRECTOR_EMAIL
$directorPass = $env:E2E_DIRECTOR_PASS
$memberEmail = $env:E2E_MEMBER_EMAIL

# Scope IDs
$churchId = $env:E2E_CHURCH_ID
$smallGroupId = $env:E2E_SMALL_GROUP_ID
$memberUserId = $env:E2E_MEMBER_USER_ID

$required = @(
  "E2E_FIELD_EMAIL","E2E_FIELD_PASS",
  "E2E_PASTOR_EMAIL","E2E_PASTOR_PASS",
  "E2E_DIRECTOR_EMAIL","E2E_DIRECTOR_PASS",
  "E2E_MEMBER_EMAIL","E2E_MEMBER_PASS",
  "E2E_CHURCH_ID","E2E_SMALL_GROUP_ID","E2E_MEMBER_USER_ID"
)

$missing = @()
foreach ($k in $required) {
  $v = (Get-Item -Path "Env:$k" -ErrorAction SilentlyContinue).Value
  if ([string]::IsNullOrWhiteSpace($v)) { $missing += $k }
}
if ($missing.Count -gt 0) {
  throw "Faltan variables de entorno: $($missing -join ', ')"
}

Write-Section "Login de actores"
$fieldToken = Login-Token -Email $fieldEmail -Password $fieldPass
$pastorToken = Login-Token -Email $pastorEmail -Password $pastorPass
$directorToken = Login-Token -Email $directorEmail -Password $directorPass

$okCount = 0
$failCount = 0

function Register-Result($ok) {
  if ($ok) { $script:okCount++ } else { $script:failCount++ }
}

Write-Section "Caso A1: FIELD director crea PASTOR (espera 201)"
$a1 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/field-admin/pastors" -Headers @{
  Authorization = "Bearer $fieldToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "pastor_nuevo_be2@demo.local"
  password = "Temp12345!"
  firstName = "Pastor"
  lastName = "Nuevo"
  displayName = "Pastor Nuevo"
}
Register-Result (Assert-Status -CaseName "A1 field -> pastor create" -Expected 201 -Response $a1)

Write-Section "Caso A2: Repetir create PASTOR duplicado (espera 409)"
$a2 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/field-admin/pastors" -Headers @{
  Authorization = "Bearer $fieldToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "pastor_nuevo_be2@demo.local"
  password = "Temp12345!"
  firstName = "Pastor"
  lastName = "Nuevo"
  displayName = "Pastor Nuevo"
}
Register-Result (Assert-Status -CaseName "A2 field -> pastor duplicate" -Expected 409 -Response $a2)

Write-Section "Caso A3: PASTOR intenta crear PASTOR via field-admin (espera 403)"
$a3 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/field-admin/pastors" -Headers @{
  Authorization = "Bearer $pastorToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "forbidden_pastor_be2@demo.local"
  password = "Temp12345!"
  firstName = "No"
  lastName = "Permitido"
  displayName = "No Permitido"
}
Register-Result (Assert-Status -CaseName "A3 pastor forbidden in field-admin" -Expected 403 -Response $a3)

Write-Section "Caso B1: PASTOR crea Director ES iglesia (espera 201)"
$b1 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/sabbath-directors" -Headers @{
  Authorization = "Bearer $pastorToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "director_nuevo_be2@demo.local"
  password = "Temp12345!"
  firstName = "Director"
  lastName = "Nuevo"
  displayName = "Director Nuevo"
}
Register-Result (Assert-Status -CaseName "B1 pastor -> sabbath director create" -Expected 201 -Response $b1)

Write-Section "Caso B2: Repetir create Director ES (espera 409)"
$b2 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/sabbath-directors" -Headers @{
  Authorization = "Bearer $pastorToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "director_nuevo_be2@demo.local"
  password = "Temp12345!"
  firstName = "Director"
  lastName = "Nuevo"
  displayName = "Director Nuevo"
}
Register-Result (Assert-Status -CaseName "B2 pastor -> sabbath director duplicate" -Expected 409 -Response $b2)

Write-Section "Caso B3: FIELD director intenta crear Director ES iglesia (espera 403)"
$b3 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/sabbath-directors" -Headers @{
  Authorization = "Bearer $fieldToken"
} -Body @{
  churchOrgUnitId = $churchId
  email = "forbidden_director_be2@demo.local"
  password = "Temp12345!"
  firstName = "No"
  lastName = "Permitido"
  displayName = "No Permitido"
}
Register-Result (Assert-Status -CaseName "B3 field forbidden in church-admin director" -Expected 403 -Response $b3)

Write-Section "Caso C1: Director ES asigna líder GP (espera 201)"
$c1 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/small-group-leaders" -Headers @{
  Authorization = "Bearer $directorToken"
} -Body @{
  userId = $memberUserId
  smallGroupOrgUnitId = $smallGroupId
}
Register-Result (Assert-Status -CaseName "C1 director -> small group leader assign" -Expected 201 -Response $c1)

Write-Section "Caso C2: Repetir asignación líder GP (espera 409)"
$c2 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/small-group-leaders" -Headers @{
  Authorization = "Bearer $directorToken"
} -Body @{
  userId = $memberUserId
  smallGroupOrgUnitId = $smallGroupId
}
Register-Result (Assert-Status -CaseName "C2 director -> small group leader duplicate" -Expected 409 -Response $c2)

Write-Section "Caso C3: Miembro intenta asignar líder GP (espera 403)"
$memberToken = Login-Token -Email $memberEmail -Password $env:E2E_MEMBER_PASS
$c3 = Invoke-JsonRequest -Method "POST" -Url "$BaseUrl/api/v1/church-admin/small-group-leaders" -Headers @{
  Authorization = "Bearer $memberToken"
} -Body @{
  userId = $memberUserId
  smallGroupOrgUnitId = $smallGroupId
}
Register-Result (Assert-Status -CaseName "C3 member forbidden in leader assign" -Expected 403 -Response $c3)

Write-Section "Resumen"
Write-Host "OK:   $okCount" -ForegroundColor Green
Write-Host "FAIL: $failCount" -ForegroundColor Red

if ($failCount -gt 0) {
  exit 1
}
exit 0
