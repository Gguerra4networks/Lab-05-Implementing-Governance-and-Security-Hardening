# CEA Lab 05: Implementing Governance and Security Hardening
## A step by step Azure lab, written so a 13 year old can follow along

This lab builds three governance controls in Azure: a role that limits what a person can touch, a rule that applies to everyone including the person who made the rule, and a spending alert that catches a runaway bill before it happens. Each control maps to a function in the NIST Cybersecurity Framework. No deviations from the course guide were reported for this build. The resource group name below uses `giovanni` as the `[yourname]` placeholder, swap in your own name if you run this yourself.

**What this actually means:**
- Think of the whole lab like setting up rules for one classroom inside a big school. The school is your Azure subscription. The classroom is the resource group you are about to create.
- Every control in this lab gets one analogy, reused the whole way through: a hall monitor badge for the access role, a rule posted on the classroom wall for the policy, and a weekly allowance with a check-in text for the budget.
- NIST is just a safety plan, the same way a school has one. Identify is the roster of who is in the building. Protect is the locked doors and badges. Detect is the smoke alarm. Respond is the fire drill. Recover is everyone filing back to class once the all clear sounds.

---

## Before You Open VS Code

You will work mostly in the Azure portal for this lab, with the CLI available as a second path for Phases 1, 2, and 4. Have an incognito or private browser window ready before Phase 3, you will use it to log in as the simulated Junior Developer without logging out of your Admin account.

**Open the built-in terminal in VS Code:** top menu **Terminal**, then **New Terminal**, or press **Ctrl+`** (the backtick key, usually just above Tab). Every command in this lab runs in that terminal.

**NOTE:** This SOP uses angle bracket placeholders like `<yourtenant>` and `<sub-id>` in a few CLI commands. Those are not literal text, swap in your real value before you run the command.
- Tenant domain: Azure Portal, **Microsoft Entra ID**, **Overview**, "Primary domain" (or from the CLI: `az ad signed-in-user show --query userPrincipalName -o tsv`, then take the part after the `@`).
- Subscription ID: `az account show --query id -o tsv`, or Portal, **Subscriptions**.

**What this actually means:**
- A placeholder like `<yourtenant>` is a stand-in, the same way a form says "Name: ______" and expects you to write your actual name on the line instead of leaving the underscores there.

**FIX:** On Windows, `az` runs through a `.cmd` wrapper, so `cmd.exe` reads `<` and `>` as file redirection symbols even inside quotes, before the command ever reaches Azure. A left-in `<yourtenant>` placeholder does not just fail to resolve, it breaks the whole command with `The system cannot find the file specified.` That error means a placeholder was not swapped out, not that the command itself is wrong.

---

## Step 0: Sign In and Save Your Variables

**What this does:** gets you logged into Azure from the terminal, and loads a set of shortcut names so you never have to retype the resource group name or the junior dev's username by hand.

`cd` into the folder where you cloned this repo before doing anything else.

```powershell
cd "<path to your cloned repo folder>"
```

Sign in with the device code flow instead of the interactive browser popup:

```powershell
az login --use-device-code
```

Open the URL it prints (microsoft.com/devicelogin) in any browser, enter the code, and complete sign in with your admin account. Then confirm you landed in the right tenant and subscription:

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

**What this actually means:**
- `set-vars.ps1` is like a class roster you fill out once at the start of the school year instead of writing every student's full name on every single form afterward. Every command below that needs the resource group name, the junior dev's username, or the policy name just points at the roster instead of spelling it out again.

**NOTE:** This prints each variable back to you so you can confirm it loaded. Every command below that references a resource group, user name, or policy name uses these variables instead of typed out strings, so a typo only needs to be fixed in one place.

**FIX:** If PowerShell blocks this with "is not digitally signed," that is the execution policy, not a broken script. Run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` in that same terminal, then re-run the `set-vars.ps1` line. If it still blocks, run `Unblock-File -Path .\set-vars.ps1` first.

---

## Phase 1: Create the Lab Resource Group

**What this does:** builds the one classroom that everything else in this lab happens inside of, so nothing else in your subscription (your school) gets touched.

The resource group is the container for everything in this lab, every role, policy, and budget below is scoped to it so nothing else in your subscription is affected.

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

## Phase 2: RBAC, Create a User and Restrict Their Access

### Step 1: Create the user in Microsoft Entra ID

**What this does:** adds one new person to the school roster before deciding what that person is allowed to do.

**What this actually means:**
- This is the NIST **Identify** function: the roster. A school cannot hand out hall passes to someone who is not on the roster in the first place. You have to know who a person is before you can grant or restrict anything.

**Portal path:**
1. Search for **Microsoft Entra ID**, **Users**, **+ New user**, **Create new user**.
2. User principal name: `junior-dev-giovanni` (Azure appends your tenant domain automatically).
3. Display name: `Junior Developer`.
4. Uncheck **Auto-generate password**. Set a password you will remember for Phase 3.
5. Click **Review + create**, then **Create**.

**SECURITY:** Collect the password interactively rather than typing it into a script or committing it anywhere.

**NOTE:** Replace `<yourtenant>` below with your real tenant domain (see the placeholder note under "Before You Open VS Code") before running this. Every other `<yourtenant>` in this SOP needs the same swap.

Click the repo folder in the Explorer sidebar if you need to open `set-vars.ps1` again to check a value, then run:

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

### Step 2: Assign the Reader role scoped to your resource group

**What this does:** hands the new user a badge that lets them look around the classroom, but not touch, move, or take anything.

**What this actually means:**
- Azure denies by default, the same way a brand new student has zero hall passes on day one until a teacher actually hands one out. Creating the user in Step 1 grants zero access on its own. Nothing happens until you explicitly assign a role.
- Reader is a look-but-do-not-touch badge. It lets the junior developer see what exists in the classroom, but not create, change, or delete anything in it.

**Portal path:**
1. Navigate to `rg-lab05-gov-giovanni`, **Access control (IAM)**, **+ Add**, **Add role assignment**.
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

## Phase 3: Verify Access, the "Permission Denied" Test

**What this does:** actually tries to break the rule you just set, on purpose, to prove the badge really works instead of just trusting that it does.

**FIX:** This phase proves the Reader role actually works. A governance control nobody has tested is a control you cannot trust.

1. Open a new **Incognito/Private** browser window.
2. Go to portal.azure.com and log in as `junior-dev-giovanni@<yourtenant>.onmicrosoft.com` with the password from Phase 2.
3. Complete any MFA or welcome screen prompts.

**What this actually means:**
- MFA (multi-factor authentication) means proving who you are two different ways, not just one. It is the difference between a locker that opens with a key versus a locker that needs the key and a fingerprint. Even a stolen password is not enough on its own.

4. Navigate to **Resource Groups**, you should only see `rg-lab05-gov-giovanni`.
5. Click into it, then **+ Create**, search **Storage Account**, **Create**.
6. Fill in any name, click **Review + create**.

**Expected result:** a red validation banner reading something like `AuthorizationFailed` or "You do not have permission to perform this action." This is the Reader role working as designed, the NIST **Protect** function in practice, the locked door actually staying locked when someone without a key tries it.

7. Close the incognito window and return to your Admin session.

---

## Phase 4: Azure Policy, Prevent Expensive Configurations

**What this does:** posts a rule on the classroom wall that applies to every single person in the room, including the teacher who wrote the rule.

**SECURITY:** This policy applies to every account in scope, including the Owner account that created it. That is intentional, governance cannot be bypassed by elevating your own permissions.

**What this actually means:**
- Reader from Phase 2 is a badge given to one specific person. Azure Policy is different: it is a rule taped to the classroom door that applies to anyone who walks in, teacher included. A substitute teacher does not get to ignore the "no phones during a test" sign just because they are the one in charge that day, and neither does your Owner account here.

### Step 1: Create the policy assignment

**Portal path:**
1. Search **Policy**, **Assignments** (under Authoring), **Assign policy**.
2. Scope: select your subscription, then `rg-lab05-gov-giovanni` as the resource group.
3. Policy definition: search "Allowed virtual machine size SKUs", select, **Add**.
4. Assignment name: `Restrict-VM-Sizes`. Click **Next**.
5. Parameters tab: uncheck "Only show parameters that need input or review." Allowed Size SKUs: select `Standard_B1s` and `Standard_B1ms`.
6. **Review + create**, then **Create**.

**NOTE:** Policy propagation typically takes 10 to 30 minutes. If Phase 5's test does not block immediately, wait 15 minutes and retry, this is expected, not a failure.

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

## Phase 5: Test the Policy

**What this does:** tries to break the wall rule on purpose, the same way Phase 3 tried to break the badge rule, to prove the rule actually stops something instead of just existing on paper.

**FIX:** Deliberately try to violate the policy to prove it actually blocks non-compliant deployments.

1. Navigate to `rg-lab05-gov-giovanni`, **+ Create**, **Virtual Machine**.
2. Fill in any VM name, select Ubuntu Server as the image.
3. Size: **See all sizes**, select `Standard_D2s_v3` (not on the allowed list).
4. **Review + create**.

**Expected result:** a red "Validation failed" banner. Expanding it shows "Policy check failed" and `Restrict-VM-Sizes` as the reason.

5. Repeat with `Standard_B1s` instead. This time validation should pass, you do not need to complete the deployment, just confirm it clears validation.

**Verify:** both directions confirmed, `Standard_D2s_v3` blocked, `Standard_B1s` allowed.

**What this actually means:**
- Testing both directions matters. A rule that blocks everything, even things it should allow, is just as broken as a rule that blocks nothing. `Standard_D2s_v3` getting blocked and `Standard_B1s` getting through are both required proof, not just one or the other.

---

## Phase 6: Cost Management, Set Up a Budget and Alerts

**What this does:** sets up a text message system that warns you before a bill gets out of control, instead of finding out about it only after the invoice arrives.

**NOTE:** A budget does not stop spending, delete resources, or turn anything off. It is a monitoring and alerting tool, the earliest possible warning that something needs your attention.

**What this actually means:**
- Think of it like a weekly allowance with a check-in text. Your parents do not physically stop you from spending once you hit a number, but they do get a heads up text once you have spent 80 percent of it (that is the Actual alert), and a second kind of heads up if, based on how fast you have been spending so far, you are on pace to blow through the whole thing before the week is even over (that is the Forecasted alert). One tells you what already happened, the other tells you where you are headed.

### Step 1: Create the budget

**Portal path (this phase is portal only in this lab):**
1. Navigate to `rg-lab05-gov-giovanni`, **Budgets** (under Cost Management; search "Budgets" in the left menu if not visible), **+ Add**.
2. Name: `Monthly-Lab-Budget`. Reset period: **Billing month**. Expiration: one year from today. Budget amount: **$50**.
3. Click **Next**.

### Step 2: Configure alert thresholds

1. Alert condition 1: type **Actual**, **80%** of budget (fires once $40 is spent).
2. **+ Add alert condition**: type **Forecasted**, **100%** of budget (fires when projected spend will exceed $50 by month end).

**NOTE:** Actual gives you ground truth after money is spent. Forecasted gives you advance warning based on trend. In practice you want both.

### Step 3: Set up email notification

1. Alert recipients: your personal email address. Language: English. Click **Create**.

**NOTE:** Action Groups can extend this to SMS, a webhook, or an Azure Function for automated response, out of scope here, using email only.

**Verify:**
Navigate to `rg-lab05-gov-giovanni`, **Budgets**, `Monthly-Lab-Budget` and confirm both the 80% Actual and 100% Forecasted thresholds are listed with your email as the recipient.

---

## Troubleshooting

Real issues hit during this build, not hypothetical ones.

| Issue | Root cause | Resolution |
|---|---|---|
| `set-vars.ps1` will not run: "is not digitally signed" | PowerShell execution policy blocks unsigned scripts by default | Run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` in the same terminal, then re-run the dot-source. If it persists, run `Unblock-File -Path .\set-vars.ps1` first. |
| Junior Developer can still create resources | Role assigned at the subscription level instead of the resource group | Check `rg-lab05-gov-giovanni`, Access control (IAM), Role assignments. Re-add the Reader assignment at the resource group level if missing there. |
| Policy is not blocking the VM (validation passes for D2s_v3) | Policy assignment has not finished propagating (10-30 minutes) | Wait 15 minutes and retry. If still not blocking after 30 minutes, confirm `Restrict-VM-Sizes` is listed in Policy > Assignments scoped to the resource group. |
| Cannot find Budgets in the resource group's left menu | Cost Management is not visible on the left panel for all subscription types | Go to Cost Management + Billing in the main search bar and navigate to Budgets from there. |
| Incognito login prompts an authenticator app setup | Microsoft Entra ID requires MFA on first login | Complete MFA setup with your phone, this is the NIST Protect function in action, not an error. |
| Policy definition "Allowed virtual machine size SKUs" not found | Search term slightly off | Search "virtual machine size" without quotes and select the definition mentioning allowed sizes/SKUs. |
| Portal shows `Standard_B1s` grayed out as "Size not available" when picking a VM size | Regional capacity restriction on that SKU, not a policy block or a Generation 1/2 mismatch | Confirm the SKU actually exists with `az vm list-skus --location eastus --size Standard_B1s --output table`, then try the deployment through the CLI. A `SkuNotAvailable` error there confirms capacity, not policy, is the blocker, `RequestDisallowedByPolicy` is the error you would see if the policy itself denied it. Either error is fine proof for this lab: it means validation passed and the deployment failed at a later, unrelated stage. Try `Standard_B1ms` or a different region if you want an actual successful deployment. |
| Budget creation fails: "Cannot create budget, the client does not have authorization to perform action" even though your account is Owner | Signed into the Azure portal as the Junior Developer test account (Reader only), not your Admin account, easy to miss in an incognito window left open from Phase 3 | Click your account avatar in the top right corner of the portal and check the signed-in email before troubleshooting permissions. If it shows the junior dev UPN, sign out completely, close the window, and sign back in with your Admin account before retrying Create budget. |

---

## Clean Up

**What this does:** tears the classroom back down so nothing keeps costing money or sitting around after the lab is finished.

**NOTE:** This is the NIST **Recover** function, restoring the environment to a known clean state, the all clear after a fire drill.

```powershell
az group delete --name $env:LAB_RESOURCE_GROUP --yes --no-wait
az ad user delete --id "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com"
```

**Verify:**
```powershell
az group exists --name $env:LAB_RESOURCE_GROUP
az ad user show --id "$($env:LAB_JUNIOR_UPN_NAME)@<yourtenant>.onmicrosoft.com"
```
Expected: `False` for the group check, and a "not found" error for the user check. Both confirm clean up succeeded.

---

## What You Built

| Component | What it does | NIST function |
|---|---|---|
| Entra ID user (Junior Developer) | Establishes an identity before granting any access | Identify |
| Reader role, scoped to resource group | Limits the junior developer to view-only access | Protect |
| Azure Policy, Restrict-VM-Sizes (Deny) | Blocks expensive VM sizes for everyone, including Owner | Protect |
| Monthly-Lab-Budget with Actual + Forecasted alerts | Flags abnormal or drifting cloud spend before it becomes a surprise bill | Detect |
| Investigating a fired budget alert | The first step of an incident response workflow | Respond |
| Resource group and user deletion | Returns the environment to a known clean state | Recover |

---

## Glossary

- **RBAC (Role-Based Access Control):** the system that decides what a person is allowed to do based on the role they are assigned, not who they personally are. Reader, Contributor, and Owner are all roles.
- **Reader role:** a built-in RBAC role that lets someone view resources but not create, change, or delete them. The look-but-do-not-touch badge in this lab.
- **Scope:** how far a permission or rule reaches. A role can be scoped to a single resource group (this lab), a whole subscription, or higher. Narrower scope means a smaller blast radius if something goes wrong.
- **Azure Policy:** a rule engine that evaluates resources against conditions you define and can block, audit, or modify them. Unlike RBAC, a policy's Deny effect applies to every account in its scope, including Owner.
- **Deny effect:** the specific policy behavior that blocks a non-compliant action at validation time, before the resource is ever created.
- **SKU (Stock Keeping Unit):** the specific size or tier of a resource, in this lab a VM size like `Standard_B1s` or `Standard_D2s_v3`.
- **Microsoft Entra ID:** Azure's identity service, formerly Azure Active Directory. It is where users, groups, and sign-in policies live.
- **MFA (Multi-Factor Authentication):** requiring two different proofs of identity, typically a password plus a phone app or code, instead of a password alone.
- **Budget (Cost Management):** a spending threshold with alerts attached. It does not stop spending on its own, it notifies.
- **Actual vs Forecasted alert:** Actual fires based on money already spent. Forecasted fires based on projected spend by the end of the billing period, using the current trend.
- **NIST Cybersecurity Framework:** a five-function model (Identify, Protect, Detect, Respond, Recover) used to organize and talk about security controls in a structured, checkable way.

---

## Key Concepts Worth Knowing for Interviews

- **RBAC and Azure Policy solve different problems.** RBAC answers "who can do this." Policy answers "is this configuration allowed at all, no matter who is asking." Being able to explain that distinction cleanly, with the fact that Policy's Deny effect applies even to Owner accounts, is a strong signal in an interview.
- **Least privilege in practice, not just as a buzzword.** This lab is a concrete example: the junior developer got exactly Reader, scoped to exactly one resource group, nothing broader. Being able to describe a real instance of scoping a role down, rather than just defining the term, is what interviewers are actually listening for.
- **Untested controls are not proven controls.** Phases 3 and 5 exist specifically to try to break what was just built. Mentioning that you deliberately test your own access controls, not just configure them, is a meaningful thing to bring up when asked about your approach to security work.
- **Knowing the difference between a capacity error and a policy error.** `SkuNotAvailable` and `RequestDisallowedByPolicy` look similar on the surface but mean completely different things. Being able to read an actual Azure error code instead of guessing from the UI is a practical skill that separates hands-on experience from textbook knowledge.
- **Mapping technical controls to a framework like NIST.** Employers in regulated or public-sector environments (a relevant point given a background in public-safety networks and defense-adjacent work) often care as much about whether a control maps cleanly to a framework as whether it works at all. This lab's "What You Built" table is a small example of that mapping done explicitly.

---

## How This Would Change for a Real Production Environment

- **Least privilege at a larger scale.** This lab assigns Reader to one test user for demonstration. A real environment would use Entra ID groups instead of individual user assignments, so access is managed by adding or removing someone from a group rather than editing role assignments one person at a time.
- **Policy as code, not a one-off portal click.** A production environment would define this policy assignment in Terraform or Bicep, version controlled and deployed through a pipeline, rather than created once by hand in the portal. That also makes the policy auditable and reproducible across multiple subscriptions or environments.
- **More than one budget, at more than one scope.** A real subscription would have a budget at the subscription level in addition to individual resource-group budgets like this one, plus Action Groups wired to something more actionable than email alone, a Teams or Slack webhook, or an automated runbook that reacts to a fired alert.
- **Conditional Access instead of MFA alone.** Production environments typically layer Conditional Access policies on top of MFA, requiring a compliant device, blocking sign-in from unexpected locations, or requiring re-authentication for sensitive actions, rather than relying on MFA as the only identity control.
- **Alerting tied to an actual on-call process.** In this lab, a fired budget alert just sends an email. In production, that alert would typically feed into a ticketing or incident system so the Respond function is a documented process, not a one-off inbox check.
