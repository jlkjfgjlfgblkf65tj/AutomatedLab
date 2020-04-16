# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    $ProjectRoot = $PSScriptRoot
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'
}

Task Default -Depends Test

Task Init {
    $lines
    Set-Location $ProjectRoot
    "`n"
}

Task BuildDebianPackage -Depends Init {
    if (-not $IsLinux) { return }

    # Build debian package structure
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/local/share/powershell/Modules -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/assets -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/Stores -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/Labs -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/DEBIAN -Force

    # Create control file
    @"
Package: automatedlab
Version: $env:APPVEYOR_BUILD_VERSION
Maintainer: https://automatedlab.org
Description: Installs the pwsh module AutomatedLab in the global module directory
Section: utils
Architecture: amd64
Bugs: https://github.com/automatedlab/automatedlab/issues
Homepage: https://automatedlab.org
Pre-Depends: powershell
Installed-Size: $('{0:0}' -f ((Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER -Exclude .git -File -Recurse | Measure-Object Length -Sum).Sum /1mb))
"@ | Set-Content -Path ./deb/automatedlab/DEBIAN/control -Encoding UTF8

    # Copy content
    Copy-Item -Path @(
        './AutomatedLab'
        './AutomatedLab.Common/AutomatedLab.Common'
        './AutomatedLab.Recipe'
        './AutomatedLab.Ships'
        './AutomatedLabDefinition'
        './AutomtatedLabTest'
        './AutomatedLabUnattended'
        './AutomatedLabWorker'
        './HostsFile'
        './PSLog'
        './PSFileTransfer'
    ) -Destination ./deb/automatedlab/usr/local/share/powershell/Modules -Force

    Save-Module -Name Ships, PSFramework, xPSDesiredStateConfiguration, xDscDiagnostics, xWebAdministration -Path ./deb/automatedlab/usr/local/share/powershell/Modules

    Copy-Item -Path ./Assets/* -Destination ./deb/automatedlab/usr/share/AutomatedLab/assets -Force

    dpkg-deb --build ./deb/automatedlab
    Rename-Item -Path ./deb/automatedlab.deb -NewName automatedlab_$($env:APPVEYOR_BUILD_VERSION)_amd64.deb
}

Task Test -Depends Init {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Ensure recent Pester version is actually used
    Import-Module -Name Pester -MinimumVersion 4.0.0 -Force

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile"

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If ($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if ($TestResults.FailedCount -gt 0)
    {
        throw "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}
