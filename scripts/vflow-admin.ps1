param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodeScript = Join-Path $scriptDir 'vflow-admin.js'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error "Error: node is required for vflow-admin.ps1"
  exit 1
}

& node $nodeScript @Args
