#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cargador y validador de test cases JSON

.DESCRIPTION
    Utilitario para cargar, validar y analizar test cases JSON.
    Proporciona funciones helper para el generador de scripts curl.

.EXAMPLE
    .\test-case-loader.ps1 -Validate -Source "..\..\cases"
#>

param(
    [string]$Source = "..\..\cases",
    [switch]$Validate,
    [switch]$List,
    [switch]$Summary
)

# Funciones de utilidad
function Get-AllTestCases {
    param([string]$SourcePath)
    
    $testCases = @()
    $jsonFiles = Get-ChildItem -Path $SourcePath -Recurse -Filter "*.json" | Where-Object { $_.Name -ne "test_suite_index.json" }
    
    foreach ($file in $jsonFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $relativePath = $file.FullName.Replace((Resolve-Path $SourcePath).Path, "").TrimStart('\')
            $category = $relativePath.Split('\')[0]
            
            $testCases += @{
                File = $file.Name
                Path = $file.FullName
                Category = $category
                Content = $content
                Valid = $true
                Errors = @()
            }
        } catch {
            $testCases += @{
                File = $file.Name
                Path = $file.FullName
                Category = "unknown"
                Content = $null
                Valid = $false
                Errors = @($_.Exception.Message)
            }
        }
    }
    
    return $testCases
}

function Test-TestCaseStructure {
    param($TestCase)
    
    $errors = @()
    $content = $TestCase.Content
    
    if (-not $content) {
        return @("Contenido JSON inválido")
    }
    
    # Validar campos requeridos
    $requiredFields = @('test_case', 'description', 'category')
    foreach ($field in $requiredFields) {
        if (-not $content.$field) {
            $errors += "Campo requerido faltante: $field"
        }
    }
    
    # Validar estructura de test_data
    if ($content.test_data -and $content.test_data.input -and -not $content.test_data.input.query) {
        $errors += "Campo test_data.input.query es requerido"
    }
    
    # Validar validation_criteria
    if (-not $content.validation_criteria) {
        $errors += "Campo validation_criteria es requerido"
    }
    
    return $errors
}

function Show-TestCaseSummary {
    param($TestCases)
    
    Write-Host "📊 RESUMEN DE TEST CASES" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Gray
    
    $total = $TestCases.Count
    $valid = ($TestCases | Where-Object { $_.Valid }).Count
    $invalid = $total - $valid
    
    Write-Host "📁 Total de archivos: $total" -ForegroundColor Cyan
    Write-Host "✅ Válidos: $valid" -ForegroundColor Green
    Write-Host "❌ Inválidos: $invalid" -ForegroundColor Red
    
    # Agrupar por categoría
    $byCategory = $TestCases | Group-Object Category
    Write-Host "`n📂 Por categoría:" -ForegroundColor Cyan
    foreach ($group in $byCategory) {
        $validInCategory = ($group.Group | Where-Object { $_.Valid }).Count
        Write-Host "   $($group.Name): $validInCategory/$($group.Count)" -ForegroundColor Gray
    }
    
    # Mostrar test cases válidos
    Write-Host "`n✅ Test cases válidos:" -ForegroundColor Green
    $validCases = $TestCases | Where-Object { $_.Valid }
    foreach ($case in $validCases) {
        $testName = $case.Content.test_case
        $description = $case.Content.description
        Write-Host "   • $testName - $($case.Category)" -ForegroundColor Gray
        Write-Host "     $description" -ForegroundColor DarkGray
    }
    
    # Mostrar errores si hay
    if ($invalid -gt 0) {
        Write-Host "`n❌ Test cases con errores:" -ForegroundColor Red
        $invalidCases = $TestCases | Where-Object { -not $_.Valid }
        foreach ($case in $invalidCases) {
            Write-Host "   • $($case.File)" -ForegroundColor Red
            foreach ($error in $case.Errors) {
                Write-Host "     - $error" -ForegroundColor DarkRed
            }
        }
    }
}

function Show-TestCasesList {
    param($TestCases)
    
    Write-Host "📋 LISTA DE TEST CASES" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Gray
    
    $validCases = $TestCases | Where-Object { $_.Valid } | Sort-Object Category, { $_.Content.test_case }
    
    foreach ($case in $validCases) {
        $content = $case.Content
        Write-Host "`n🧪 $($content.test_case)" -ForegroundColor Cyan
        Write-Host "   📂 Categoría: $($case.Category)" -ForegroundColor Gray
        Write-Host "   📝 Descripción: $($content.description)" -ForegroundColor Gray
        
        if ($content.test_data -and $content.test_data.input) {
            Write-Host "   🔍 Query: $($content.test_data.input.query)" -ForegroundColor Yellow
        }
        
        if ($content.validation_criteria) {
            $criteria = $content.validation_criteria
            if ($criteria.response_content) {
                if ($criteria.response_content.should_contain) {
                    $shouldContain = $criteria.response_content.should_contain -join ", "
                    Write-Host "   ✅ Debe contener: $shouldContain" -ForegroundColor Green
                }
                if ($criteria.response_content.should_not_contain) {
                    $shouldNotContain = $criteria.response_content.should_not_contain -join ", "
                    Write-Host "   ❌ No debe contener: $shouldNotContain" -ForegroundColor Red
                }
            }
        }
        
        Write-Host "   📁 Archivo: $($case.File)" -ForegroundColor DarkGray
    }
}

# Ejecutar según parámetros
if (-not (Test-Path $Source)) {
    Write-Host "❌ Directorio fuente no existe: $Source" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Cargando test cases desde: $Source" -ForegroundColor Blue
$testCases = Get-AllTestCases -SourcePath $Source

if ($Validate) {
    Write-Host "`n🔍 Validando estructura de test cases..." -ForegroundColor Blue
    
    foreach ($testCase in $testCases) {
        if ($testCase.Valid) {
            $validationErrors = Test-TestCaseStructure -TestCase $testCase
            if ($validationErrors.Count -gt 0) {
                $testCase.Valid = $false
                $testCase.Errors += $validationErrors
            }
        }
    }
}

if ($List) {
    Show-TestCasesList -TestCases $testCases
}

if ($Summary -or (-not $List -and -not $Validate)) {
    Show-TestCaseSummary -TestCases $testCases
}

# Exportar funciones para uso en otros scripts
$script:LoadedTestCases = $testCases

# Función exportable para otros scripts
function Get-LoadedTestCases {
    return $script:LoadedTestCases
}

if ($Validate) {
    $invalidCount = ($testCases | Where-Object { -not $_.Valid }).Count
    if ($invalidCount -gt 0) {
        Write-Host "`n⚠️  Se encontraron $invalidCount test cases inválidos" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "`n✅ Todos los test cases son válidos" -ForegroundColor Green
    }
}

Write-Host "`n✅ Carga de test cases completada" -ForegroundColor Green