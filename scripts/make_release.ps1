# make_release.ps1 will create a build package ready for publishing.
Set-StrictMode -Version 2.0
$ErrorActionPreference="Stop"

$Root=Join-Path $PSScriptRoot ".."
$PublishDir=New-Item -ItemType Directory -Path "$env:TEMP\$([System.IO.Path]::GetRandomFileName())"
$GitHash=$(git rev-parse HEAD)
$PublishFile="$(Split-Path -Parent -Path $PublishDir)\$GitHash.zip"
$Version = $(git describe --tags 2>$null)
$Branch = $(if (Test-Path env:APPVEYOR_REPO_BRANCH) { $env:APPVEYOR_REPO_BRANCH } else { $(git rev-parse --abbrev-ref HEAD) })
$PublishTargets = @($GitHash, $Version, $Branch)

function RunGoBuild($goPackage) {
    $binRoot = New-Item -ItemType Directory -Force -Path "$PublishDir\bin"
    $outputName = Split-Path -Leaf $(go list -f "{{.Target}}" $goPackage)
    go build -ldflags "-X main.version=$Version" -o "$binRoot\$outputName" $goPackage
}

function CopyPackage($pathToModule, $moduleName) {
    $moduleRoot = New-Item -ItemType Directory -Force -Path "$PublishDir\node_modules\$moduleName"
    Copy-Item -Recurse $pathToModule\* $moduleRoot
    if (Test-Path (Join-Path $moduleRoot "node_modules")) { 
        Remove-Item -Recurse -Force "$moduleRoot\node_modules"
    }
}

RunGoBuild "github.com/pulumi/pulumi"
CopyPackage "$Root\sdk\nodejs\bin" "pulumi"

Copy-Item "$Root\dist\sdk\nodejs\pulumi-langhost-nodejs.cmd" "$PublishDir\bin"
New-Item -ItemType Directory -Force -Path "$PublishDir\bin\node" | Out-Null
Copy-Item "$Root\sdk\nodejs\custom_node\node.exe" "$PublishDir\bin\node"


Remove-Item "$PublishDir\node_modules\pulumi\pulumi-langhost-nodejs"
Remove-Item "$PublishDir\node_modules\pulumi\pulumi-langhost-nodejs.cmd"
Remove-Item "$PublishDir\node_modules\pulumi\pulumi-provider-pulumi-nodejs"
Remove-Item "$PublishDir\node_modules\pulumi\pulumi-provider-pulumi-nodejs.cmd"

# By default, if the archive already exists, 7zip will just add files to it, so blow away the existing
# archive if it exists.
if (Test-Path $PublishFile) {
    Remove-Item -Force $PublishFile
}

7z a "$PublishFile" "$PublishDir\." | Out-Null

Remove-Item -Recurse -Force $PublishDir

New-Object PSObject -Property @{ArchivePath=$PublishFile;Targets=$PublishTargets}