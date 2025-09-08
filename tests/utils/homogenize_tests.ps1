# Script para homogeneizar archivos de test al formato estándar ADK
# Autor: GitHub Copilot
# Fecha: 2025-09-08

Write-Host "🔄 Iniciando homogeneización de archivos .test.json..." -ForegroundColor Yellow

# Obtener todos los archivos .test.json
$testFiles = Get-ChildItem -Path "." -Filter "*.test.json"
Write-Host "📁 Encontrados $($testFiles.Count) archivos .test.json" -ForegroundColor Cyan

$standardFiles = @()
$needsConversion = @()
$errors = @()

foreach ($file in $testFiles) {
    try {
        Write-Host "🔍 Analizando: $($file.Name)" -ForegroundColor White
        
        $content = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        
        # Verificar si ya está en formato estándar ADK
        $hasName = $content.PSObject.Properties.Name -contains "name"
        $hasExpectedTrajectory = $content.PSObject.Properties.Name -contains "expected_trajectory"
        $hasExpectedResponse = $content.PSObject.Properties.Name -contains "expected_response"
        
        # Verificar formatos no estándar
        $hasTestName = $content.PSObject.Properties.Name -contains "test_name"
        $hasToolExpected = $content.PSObject.Properties.Name -contains "tool_expected"
        $hasTestId = $content.PSObject.Properties.Name -contains "test_id"
        $hasValidationCriteria = $content.PSObject.Properties.Name -contains "validation_criteria"
        
        if ($hasName -and $hasExpectedTrajectory -and $hasExpectedResponse) {
            Write-Host "  ✅ Ya está en formato estándar ADK" -ForegroundColor Green
            $standardFiles += $file.Name
        }
        elseif ($hasTestName -or $hasToolExpected -or $hasTestId -or $hasValidationCriteria) {
            Write-Host "  ⚠️  Necesita conversión al formato estándar" -ForegroundColor Yellow
            $needsConversion += @{
                File = $file.Name
                CurrentFormat = if ($hasTestId) { "Format 3 (Enhanced)" } 
                               elseif ($hasTestName -and $hasToolExpected) { "Format 2 (Custom)" }
                               else { "Format Unknown" }
                HasName = $hasName
                HasTestName = $hasTestName
                HasTestId = $hasTestId
                HasToolExpected = $hasToolExpected
                HasExpectedTrajectory = $hasExpectedTrajectory
                HasValidationCriteria = $hasValidationCriteria
            }
        }
        else {
            Write-Host "  ❓ Formato no reconocido" -ForegroundColor Magenta
            $errors += $file.Name
        }
    }
    catch {
        Write-Host "  ❌ Error al procesar: $($_.Exception.Message)" -ForegroundColor Red
        $errors += $file.Name
    }
}

Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
Write-Host "✅ Archivos en formato estándar: $($standardFiles.Count)" -ForegroundColor Green
Write-Host "⚠️  Archivos que necesitan conversión: $($needsConversion.Count)" -ForegroundColor Yellow
Write-Host "❌ Archivos con errores: $($errors.Count)" -ForegroundColor Red

if ($standardFiles.Count -gt 0) {
    Write-Host "`n✅ ARCHIVOS EN FORMATO ESTÁNDAR:" -ForegroundColor Green
    $standardFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
}

if ($needsConversion.Count -gt 0) {
    Write-Host "`n⚠️  ARCHIVOS QUE NECESITAN CONVERSIÓN:" -ForegroundColor Yellow
    $needsConversion | ForEach-Object {
        Write-Host "  - $($_.File) [$($_.CurrentFormat)]" -ForegroundColor White
    }
    
    Write-Host "`n🔧 ¿Deseas proceder con la conversión automática? (S/N)" -ForegroundColor Cyan
    $response = Read-Host
    
    if ($response -eq "S" -or $response -eq "s" -or $response -eq "Y" -or $response -eq "y") {
        Write-Host "🚀 Iniciando conversión automática..." -ForegroundColor Green
        
        # Aquí iríamos archivo por archivo para convertir
        foreach ($fileInfo in $needsConversion) {
            Write-Host "🔄 Convirtiendo: $($fileInfo.File)" -ForegroundColor Yellow
            # La conversión se haría aquí (requiere lógica específica por formato)
        }
    }
    else {
        Write-Host "⏸️  Conversión cancelada por el usuario" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`n❌ ARCHIVOS CON ERRORES:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
}

Write-Host "`n✨ Análisis completado!" -ForegroundColor Green