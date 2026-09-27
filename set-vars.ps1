# Lab 05 - Implementing Governance and Security Hardening
# Run this first in every new PowerShell session before touching the portal or CLI.
# Never commit this file with real secrets in it. Passwords are collected interactively, not stored here.

$env:LAB_RESOURCE_GROUP   = "rg-lab05-gov-giovanni"
$env:LAB_REGION           = "eastus"
$env:LAB_JUNIOR_UPN_NAME  = "junior-dev-giovanni"
$env:LAB_JUNIOR_DISPLAY   = "Junior Developer"
$env:LAB_POLICY_NAME      = "Restrict-VM-Sizes"
$env:LAB_ALLOWED_SKUS     = "Standard_B1s,Standard_B1ms"
$env:LAB_BUDGET_NAME      = "Monthly-Lab-Budget"
$env:LAB_BUDGET_AMOUNT    = "50"

Write-Host "Lab 05 variables loaded:" -ForegroundColor Cyan
Write-Host "  Resource Group : $env:LAB_RESOURCE_GROUP"
Write-Host "  Region         : $env:LAB_REGION"
Write-Host "  Junior Dev UPN : $env:LAB_JUNIOR_UPN_NAME"
Write-Host "  Policy Name    : $env:LAB_POLICY_NAME"
Write-Host "  Allowed SKUs   : $env:LAB_ALLOWED_SKUS"
Write-Host "  Budget Name    : $env:LAB_BUDGET_NAME"
Write-Host "  Budget Amount  : `$$env:LAB_BUDGET_AMOUNT"
Write-Host "Ready. Passwords are collected interactively - none are stored here." -ForegroundColor Green
