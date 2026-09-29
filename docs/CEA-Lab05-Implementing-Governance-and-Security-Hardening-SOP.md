# CEA Lab 05 - Implementing Governance and Security Hardening
## Full Step-by-Step SOP

This SOP walks through building three governance controls in Azure: RBAC, Azure Policy, and a cost budget, and mapping each to the NIST Cybersecurity Framework. Every phase ends with a verification step. No deviations from the course guide were reported for this build; the resource group name below uses `giovanni` as the `[yourname]` placeholder - swap in your own name if you follow this SOP for your own run.

---

## Before You Open VS Code

You will work mostly in the Azure portal for this lab, with the CLI available as a second path for Phases 1, 2, and 4. Have an incognito or private browser window ready before Phase 3 - you will use it to log in as the simulated Junior Developer without logging out of your Admin account.

**NOTE:** This SOP uses angle-bracket placeholders like `<yourtenant>` and `<sub-id>` in a few CLI commands. Those are not literal text - swap in your real value before you run the command.
- Tenant domain: Azure Portal > **Microsoft Entra ID** > **Overview** > "Primary domain" (or from the CLI: `az ad signed-in-user show --query userPrincipalName -o tsv`, then take the part after the `@`).
- Subscription ID: `az account show --query id -o tsv`, or Portal > **Subscriptions**.

**FIX:** On Windows, `az` runs through a `.cmd` wrapper, so `cmd.exe` reads `<` and `>` as file-redirection symbols even inside quotes, before the command ever reaches Azure. A left-in `<yourtenant>` placeholder does not just fail to resolve - it breaks the whole command with `The system cannot find the file specified.` That error means a placeholder was not swapped out, not that the command itself is wrong.

---

## Step 0 - Sign In and Save Your Variables

**PATH:** Open a PowerShell terminal (or the VS Code integrated terminal) and `cd` into the folder where you cloned this repo before doing anything else.

```powershell
cd "<path to your cloned repo folder>"
```

Sign in with the device code flow instead of the interactive browser popup:

```powershell
az login --use-device-code
```

Open the URL it prints (microsoft.com/devicelogin) in any browser, enter the code, and complete sign-in with your admin account. Then confirm you landed in the right tenant and subscription:

```powershell
az account show --output table
```

If it shows the wrong subscription, pin the right one:

```powershell
az account set --subscription "<name-or-id>"
```

Now load the lab variables:

```powershell
. .\set-vars.ps1
```

**NOTE:** This prints each variable back to you so you can confirm it loaded. Every command below that references a resource group, user name, or policy name uses these variables instead of typed-out strings, so a typo only needs to be fixed in one place.

**FIX:** If PowerShell blocks this with "is not digitally signed," that is the execution policy, not a broken script. Run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` in that same terminal, then re-run the `set-vars.ps1` line. If it still blocks, run `Unblock-File -Path .\set-vars.ps1` first.

---

## Phase 1 - Create the Lab Resource Group

The resource group is the container for everything in this lab - every RBAC assignment, policy, and budget below is scoped to it so nothing else in your subscription is affected.

**Portal path:**
1. Log in to portal.azure.com with your main Admin account.
2. Search for **Resource Groups** and click **+ Create**.
3. Name: `rg-lab05-gov-giovanni`. Region: **East US**.
4. Click **Review + create**, then **Create**.

**CLI path:**
```powershell
az group create --name $env:LAB_RESOURCE_GROUP --location $env:LAB_REGION
```

**Verify:**
```powershell
az group show --name $env:LAB_RESOURCE_GROUP --output table
```
Expected: the resource group listed with `ProvisioningState: Succeeded`.

---

## Phase 2 - RBAC: Create a User and Restrict Their Access

### Step 1 - Create the user in Microsoft Entra ID

**NOTE:** This is the NIST **Identify** function - you have to know who a person is before you can grant or restrict what they can do.

**Portal path:**
1. Search for **Microsoft Entra ID** > **Users** > **+ New user** > **Create new user**.
2. User principal name: `junior-dev-giovanni` (Azure appends your tenant domain automatically).
3. Display name: `Junior Developer`.
4. Uncheck **Auto-generate password**. Set a password you will remember for Phase 3.
5. Click **Review + create**, then **Create**.

**SECURITY:** Collect the password interactively rather than typing it into a script or committing it anywhere.

**NOTE:** Replace `<yourtenant>` below with your real tenant domain (see the placeholder note under "Before You Open VS Code") before running this. Every other `<yourtenant>` in this SOP needs the same swap.

```powershell
$pw = Read-Host -AsSecureString "Set a password for the junior dev account"
az ad user create --display-name $env:LAB_JUNIOR_DISPLAY `
  --user-principal-name "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com" `
  --password $pw --output none
Remove-Variable pw
```

**Verify:**
```powershell
az ad user show --id "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com" --output table
```

### Step 2 - Assign the Reader role scoped to your resource group

**NOTE:** Azure denies by default. Creating the user grants zero access until a role is explicitly assigned.

**Portal path:**
1. Navigate to `rg-lab05-gov-giovanni` > **Access control (IAM)** > **+ Add** > **Add role assignment**.
2. Role tab: search for and select **Reader**. Click **Next**.
3. Members tab: **+ Select members**, search for **Junior Developer**, select, **Select**.
4. **Review + assign**, then **Review + assign** again.

**CLI path:**
```powershell
az role assignment create `
  --assignee "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com" `
  --role "Reader" `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$($env:LAB_RESOURCE_GROUP)"
```

**Verify:**
```powershell
az role assignment list --resource-group $env:LAB_RESOURCE_GROUP --output table
```
Expected: Junior Developer listed with the Reader role, scoped to `rg-lab05-gov-giovanni` only.

---

## Phase 3 - Verify Access: The "Permission Denied" Test

**FIX:** This phase proves the Reader role actually works. Untested governance controls are controls you cannot trust.

1. Open a new **Incognito/Private** browser window.
2. Go to portal.azure.com and log in as `junior-dev-giovanni@<yourtenant>.onmicrosoft.com` with the password from Phase 2.
3. Complete any MFA or welcome-screen prompts.
4. Navigate to **Resource Groups** - you should only see `rg-lab05-gov-giovanni`.
5. Click into it, then **+ Create** > search **Storage Account** > **Create**.
6. Fill in any name, click **Review + create**.

**Expected result:** a red validation banner reading something like `AuthorizationFailed` or "You do not have permission to perform this action." This is the Reader role working as designed - it is the NIST **Protect** function in practice.

7. Close the incognito window and return to your Admin session.

---

## Phase 4 - Azure Policy: Prevent Expensive Configurations

**SECURITY:** This policy applies to every account in scope, including the Owner account that created it. That is intentional - governance cannot be bypassed by elevating your own permissions.

### Step 1 - Create the policy assignment

**Portal path:**
1. Search **Policy** > **Assignments** (under Authoring) > **Assign policy**.
2. Scope: select your subscription, then `rg-lab05-gov-giovanni` as the resource group.
3. Policy definition: search "Allowed virtual machine size SKUs", select, **Add**.
4. Assignment name: `Restrict-VM-Sizes`. Click **Next**.
5. Parameters tab: uncheck "Only show parameters that need input or review." Allowed Size SKUs: select `Standard_B1s` and `Standard_B1ms`.
6. **Review + create**, then **Create**.

**NOTE:** Policy propagation typically takes 10-30 minutes. If Phase 5's test does not block immediately, wait 15 minutes and retry - this is expected, not a failure.

**CLI path:**
```powershell
az policy assignment create --name $env:LAB_POLICY_NAME `
  --scope "/subscriptions/<sub-id>/resourceGroups/$($env:LAB_RESOURCE_GROUP)" `
  --policy "cccc23c7-8427-4f53-ad12-b6a63eb452b3" `
  --params "{\"listOfAllowedSKUs\":{\"value\":[\"Standard_B1s\",\"Standard_B1ms\"]}}"
```

**Verify:**
```powershell
az policy assignment list --output table
```
Expected: `Restrict-VM-Sizes` listed, scoped to `rg-lab05-gov-giovanni`.

---

## Phase 5 - Test the Policy

**FIX:** Deliberately try to violate the policy to prove it actually blocks non-compliant deployments.

1. Navigate to `rg-lab05-gov-giovanni` > **+ Create** > **Virtual Machine**.
2. Fill in any VM name, select Ubuntu Server as the image.
3. Size: **See all sizes**, select `Standard_D2s_v3` (not on the allowed list).
4. **Review + create**.

**Expected result:** a red "Validation failed" banner. Expanding it shows "Policy check failed" and `Restrict-VM-Sizes` as the reason.

5. Repeat with `Standard_B1s` instead. This time validation should pass - you do not need to complete the deployment, just confirm it clears validation.

**Verify:** both directions confirmed - `Standard_D2s_v3` blocked, `Standard_B1s` allowed.

---

## Phase 6 - Cost Management: Set Up a Budget and Alerts

**NOTE:** A budget does not stop spending, delete resources, or turn anything off. It is a monitoring and alerting tool - the earliest possible warning that something needs your attention.

### Step 1 - Create the budget

**Portal path (this phase is portal-only in this lab):**
1. Navigate to `rg-lab05-gov-giovanni` > **Budgets** (under Cost Management; search "Budgets" in the left menu if not visible) > **+ Add**.
2. Name: `Monthly-Lab-Budget`. Reset period: **Billing month**. Expiration: one year from today. Budget amount: **$50**.
3. Click **Next**.

### Step 2 - Configure alert thresholds

1. Alert condition 1: type **Actual**, **80%** of budget (fires once $40 is spent).
2. **+ Add alert condition**: type **Forecasted**, **100%** of budget (fires when projected spend will exceed $50 by month end).

**NOTE:** Actual gives you ground truth after money is spent. Forecasted gives you advance warning based on trend. In practice you want both.

### Step 3 - Set up email notification

1. Alert recipients: your personal email address. Language: English. Click **Create**.

**NOTE:** Action Groups can extend this to SMS, a webhook, or an Azure Function for automated response - out of scope here, using email only.

**Verify:**
Navigate to `rg-lab05-gov-giovanni` > **Budgets** > `Monthly-Lab-Budget` and confirm both the 80% Actual and 100% Forecasted thresholds are listed with your email as the recipient.

---

## Troubleshooting

| Issue | Root cause | Resolution |
|---|---|---|
| `set-vars.ps1` will not run: "is not digitally signed" | PowerShell execution policy blocks unsigned scripts by default | Run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` in the same terminal, then re-run the dot-source. If it persists, run `Unblock-File -Path .\set-vars.ps1` first. |
| Junior Developer can still create resources | Role assigned at the subscription level instead of the resource group | Check `rg-lab05-gov-giovanni` > Access control (IAM) > Role assignments. Re-add the Reader assignment at the resource group level if missing there. |
| Policy is not blocking the VM (validation passes for D2s_v3) | Policy assignment has not finished propagating (10-30 minutes) | Wait 15 minutes and retry. If still not blocking after 30 minutes, confirm `Restrict-VM-Sizes` is listed in Policy > Assignments scoped to the resource group. |
| Cannot find Budgets in the resource group's left menu | Cost Management is not visible on the left panel for all subscription types | Go to Cost Management + Billing in the main search bar and navigate to Budgets from there. |
| Incognito login prompts an authenticator app setup | Microsoft Entra ID requires MFA on first login | Complete MFA setup with your phone - this is the NIST Protect function in action, not an error. |
| Policy definition "Allowed virtual machine size SKUs" not found | Search term slightly off | Search "virtual machine size" without quotes and select the definition mentioning allowed sizes/SKUs. |
| Portal shows `Standard_B1s` grayed out as "Size not available" when picking a VM size | Regional capacity restriction on that SKU, not a policy block or a Generation 1/2 mismatch | Confirm the SKU actually exists with `az vm list-skus --location eastus --size Standard_B1s --output table`, then try the deployment through the CLI. A `SkuNotAvailable` error there confirms capacity, not policy, is the blocker - `RequestDisallowedByPolicy` is the error you'd see if the policy itself denied it. Either error is fine proof for this lab: it means validation passed and the deployment failed at a later, unrelated stage. Try `Standard_B1ms` or a different region if you want an actual successful deployment. |
| Budget creation fails: "Cannot create budget - The client does not have authorization to perform action" even though your account is Owner | Signed into the Azure portal as the Junior Developer test account (Reader-only), not your Admin account - easy to miss in an incognito window left open from Phase 3 | Click your account avatar in the top-right corner of the portal and check the signed-in email before troubleshooting permissions. If it shows the junior dev UPN, sign out completely, close the window, and sign back in with your Admin account before retrying Create budget. |

---

## Clean Up

**NOTE:** This is the NIST **Recover** function - restoring the environment to a known clean state.

```powershell
az group delete --name $env:LAB_RESOURCE_GROUP --yes --no-wait
az ad user delete --id "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com"
```

**Verify:**
```powershell
az group exists --name $env:LAB_RESOURCE_GROUP
az ad user show --id "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com"
```
Expected: `False` for the group check, and a "not found" error for the user check. Both confirm clean-up succeeded.

---

## What You Built

| Component | What it does | NIST function |
|---|---|---|
| Entra ID user (Junior Developer) | Establishes an identity before granting any access | Identify |
| Reader role, scoped to resource group | Limits the junior developer to view-only access | Protect |
| Azure Policy - Restrict-VM-Sizes (Deny) | Blocks expensive VM sizes for everyone, including Owner | Protect |
| Monthly-Lab-Budget with Actual + Forecasted alerts | Flags abnormal or drifting cloud spend before it becomes a surprise bill | Detect |
| Investigating a fired budget alert | The first step of an incident response workflow | Respond |
| Resource group and user deletion | Returns the environment to a known clean state | Recover |
