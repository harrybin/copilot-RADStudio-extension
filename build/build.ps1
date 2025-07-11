# RAD Studio Copilot Extension Build Script

param(
    [string]$Configuration = "Release",
    [string]$Platform = "Win32",
    [switch]$Clean,
    [switch]$Install,
    [switch]$Help
)

# Display help information
if ($Help) {
    Write-Host "RAD Studio Copilot Extension Build Script"
    Write-Host ""
    Write-Host "Usage: build.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Configuration <config>   Build configuration (Debug/Release) [Default: Release]"
    Write-Host "  -Platform <platform>      Target platform (Win32/Win64) [Default: Win32]"
    Write-Host "  -Clean                    Clean build outputs before building"
    Write-Host "  -Install                  Install package after successful build"
    Write-Host "  -Help                     Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build.ps1                           # Build release version"
    Write-Host "  .\build.ps1 -Configuration Debug      # Build debug version"
    Write-Host "  .\build.ps1 -Clean -Install           # Clean, build, and install"
    exit 0
}

# Set error action
$ErrorActionPreference = "Stop"

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$PackageDir = Join-Path $ProjectRoot "package"
$BuildDir = Join-Path $ProjectRoot "build"
$OutputDir = Join-Path $BuildDir "output"

# RAD Studio configuration
$RADStudioPath = ""
$MSBuildPath = ""

# Function to find RAD Studio installation
function Find-RADStudio {
    Write-Host "Locating RAD Studio installation..."
    
    # Check registry for RAD Studio installation
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Embarcadero\BDS\23.0",  # RAD Studio 12 Athens
        "HKLM:\SOFTWARE\Embarcadero\BDS\22.0",  # RAD Studio 11 Alexandria
        "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\23.0",
        "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\22.0"
    )
    
    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path $RegPath) {
            $InstallDir = Get-ItemProperty -Path $RegPath -Name "RootDir" -ErrorAction SilentlyContinue
            if ($InstallDir -and (Test-Path $InstallDir.RootDir)) {
                $script:RADStudioPath = $InstallDir.RootDir
                $script:MSBuildPath = Join-Path $RADStudioPath "bin\rsvars.bat"
                Write-Host "Found RAD Studio at: $RADStudioPath"
                return $true
            }
        }
    }
    
    # Check common installation paths
    $CommonPaths = @(
        "C:\Program Files (x86)\Embarcadero\Studio\23.0",
        "C:\Program Files (x86)\Embarcadero\Studio\22.0"
    )
    
    foreach ($Path in $CommonPaths) {
        if (Test-Path $Path) {
            $script:RADStudioPath = $Path
            $script:MSBuildPath = Join-Path $Path "bin\rsvars.bat"
            Write-Host "Found RAD Studio at: $Path"
            return $true
        }
    }
    
    Write-Error "RAD Studio installation not found. Please ensure RAD Studio 11+ is installed."
    return $false
}

# Function to clean build outputs
function Clean-BuildOutputs {
    Write-Host "Cleaning build outputs..."
    
    $CleanPaths = @(
        (Join-Path $ProjectRoot "src\*.dcu"),
        (Join-Path $ProjectRoot "src\*.dcuil"),
        (Join-Path $ProjectRoot "src\**\*.dcu"),
        (Join-Path $ProjectRoot "src\**\*.dcuil"),
        (Join-Path $PackageDir "*.dcu"),
        (Join-Path $PackageDir "*.dcuil"),
        (Join-Path $PackageDir "*.bpl"),
        (Join-Path $PackageDir "*.dcp"),
        $OutputDir
    )
    
    foreach ($Path in $CleanPaths) {
        if (Test-Path $Path) {
            Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Cleaned: $Path"
        }
    }
}

# Function to create directory structure
function Initialize-BuildEnvironment {
    Write-Host "Initializing build environment..."
    
    if (!(Test-Path $BuildDir)) {
        New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
    }
    
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    Write-Host "Build directories created."
}

# Function to build the package
function Build-Package {
    Write-Host "Building RAD Studio Copilot Extension..."
    Write-Host "Configuration: $Configuration"
    Write-Host "Platform: $Platform"
    
    # Package file path
    $PackageFile = Join-Path $PackageDir "RADStudioCopilotExtension.dpk"
    
    if (!(Test-Path $PackageFile)) {
        Write-Error "Package file not found: $PackageFile"
        return $false
    }
    
    # Set up RAD Studio environment
    $TempBat = Join-Path $BuildDir "build_temp.bat"
    
    $BuildScript = @"
@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "$PackageDir"
dcc32 -B -Q RADStudioCopilotExtension.dpk
if errorlevel 1 (
    echo Build failed
    exit /b 1
) else (
    echo Build succeeded
    exit /b 0
)
"@
    
    $BuildScript | Out-File -FilePath $TempBat -Encoding ASCII
    
    # Execute build
    Write-Host "Running build command: $TempBat"
    $BuildResult = & cmd.exe /c $TempBat
    Write-Host $BuildResult
    $BuildExitCode = $LASTEXITCODE
    
    # Clean up temporary file
    Remove-Item $TempBat -Force -ErrorAction SilentlyContinue
    
    if ($BuildExitCode -eq 0) {
        Write-Host "Build completed successfully!" -ForegroundColor Green
        
        # Copy outputs
        $BplFile = Join-Path $PackageDir "RADStudioCopilotExtension.bpl"
        $DcpFile = Join-Path $PackageDir "RADStudioCopilotExtension.dcp"
        
        if (Test-Path $BplFile) {
            Copy-Item $BplFile $OutputDir -Force
            Write-Host "Copied BPL to output directory"
        }
        
        if (Test-Path $DcpFile) {
            Copy-Item $DcpFile $OutputDir -Force
            Write-Host "Copied DCP to output directory"
        }
        
        return $true
    }
    else {
        Write-Error "Build failed with exit code: $BuildExitCode"
        return $false
    }
}

# Function to install the package
function Install-Package {
    Write-Host "Installing package..."
    
    $BplFile = Join-Path $OutputDir "RADStudioCopilotExtension.bpl"
    
    if (!(Test-Path $BplFile)) {
        Write-Error "Package file not found for installation: $BplFile"
        return $false
    }
    
    # Get RAD Studio packages directory
    $PackagesDir = Join-Path $RADStudioPath "bin"
    
    # Copy package to RAD Studio directory
    Copy-Item $BplFile $PackagesDir -Force
    Write-Host "Package copied to RAD Studio packages directory"
    
    # TODO: Add registry entries for package registration
    # This would typically be done through the IDE's Component > Install Packages menu
    
    Write-Host "Package installation completed!" -ForegroundColor Green
    Write-Host "Please restart RAD Studio and install the package via Component > Install Packages"
    
    return $true
}

# Function to validate Node.js environment
function Test-NodeJSEnvironment {
    Write-Host "Checking Node.js environment..."
    
    try {
        $NodeVersion = & node --version 2>$null
        if ($NodeVersion) {
            Write-Host "Node.js version: $NodeVersion"
            
            # Check for minimum version (16.0)
            $VersionNumber = $NodeVersion -replace "v", ""
            $MajorVersion = [int]($VersionNumber -split "\.")[0]
            
            if ($MajorVersion -ge 16) {
                Write-Host "Node.js version meets minimum requirements" -ForegroundColor Green
                return $true
            }
            else {
                Write-Warning "Node.js version $NodeVersion is below minimum required version 16.0"
                return $false
            }
        }
    }
    catch {
        Write-Warning "Node.js not found or not accessible from PATH"
        Write-Host "Please install Node.js 16.0 or later from https://nodejs.org"
        return $false
    }
}

# Function to setup Node.js dependencies
function Setup-NodeJSDependencies {
    Write-Host "Setting up Node.js dependencies..."
    
    $BridgeDir = Join-Path $ProjectRoot "src\copilot-bridge"
    $PackageJsonPath = Join-Path $BridgeDir "package.json"
    
    # Create package.json if it doesn't exist
    if (!(Test-Path $PackageJsonPath)) {
        Write-Host "Creating Node.js package.json..."
        
        $PackageJson = @{
            name         = "radstudio-copilot-bridge"
            version      = "1.0.0"
            description  = "Bridge between RAD Studio and VS Code Copilot Chat"
            main         = "bridge.js"
            dependencies = @{
                # Add Node.js dependencies here when implemented
            }
        } | ConvertTo-Json -Depth 3
        
        $PackageJson | Out-File -FilePath $PackageJsonPath -Encoding UTF8
    }
    
    # Install dependencies (when package.json has dependencies)
    if (Test-Path $PackageJsonPath) {
        Push-Location $BridgeDir
        try {
            # npm install (when dependencies are added)
            Write-Host "Node.js dependencies setup completed"
        }
        finally {
            Pop-Location
        }
    }
}

# Main build script execution
function Main {
    Write-Host "RAD Studio Copilot Extension Build Script" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # Find RAD Studio
    if (!(Find-RADStudio)) {
        exit 1
    }
    
    # Initialize build environment
    Initialize-BuildEnvironment
    
    # Test Node.js environment
    Test-NodeJSEnvironment
    
    # Setup Node.js dependencies
    Setup-NodeJSDependencies
    
    # Clean if requested
    if ($Clean) {
        Clean-BuildOutputs
    }
    
    # Build package
    if (!(Build-Package)) {
        exit 1
    }
    
    # Install if requested
    if ($Install) {
        if (!(Install-Package)) {
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Output directory: $OutputDir"
    
    if ($Install) {
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "1. Restart RAD Studio"
        Write-Host "2. Go to Component > Install Packages"
        Write-Host "3. Add the package: RADStudioCopilotExtension.bpl"
        Write-Host "4. Configure GitHub Copilot authentication"
    }
}

# Execute main function
Main
