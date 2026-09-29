# CEA Lab 05 - LinkedIn Post Series

**Posting notes:**
- Space these 2-3 days apart, in order: Loom, GitHub, Learned, Different.
- LinkedIn does not accept SVG. Use the PNG copies in `assets/thumbnails/png/` and `assets/thumbnails/generic/png/`.
- Suggested second image for Posts 3 and 4: a real screenshot from `assets/screenshots/` (see notes under each post).
- Loom link is a placeholder below until the walkthrough is recorded.

---

## Post 1 - Loom Video

**Thumbnail:** `assets/thumbnails/png/post1-loom.png` (or generic alternate `assets/thumbnails/generic/png/g1-watch.png`)

A resource group with zero guardrails is one bad click away from a five figure Azure bill.

That is the problem Lab 05 of my Cloud Engineering Accelerator track solves. I built three governance controls into one resource group: a Reader-only role for a simulated junior developer, an Azure Policy that blocks expensive VM sizes for every account including my own Owner login, and a cost budget with both an actual and a forecasted alert.

The part that made it real: the policy had to hold even when I tried to bypass it myself. Governance you can turn off by elevating your own permissions is not governance. I proved it by trying to deploy a Standard_D2s_v3 VM as the Owner account and watching the same Deny effect block it that blocked the junior dev.

I recorded the full build, including the parts that did not go right the first time.

Watch the walkthrough here: [LOOM_URL]

If you are building toward cloud security or DevOps roles, this is the kind of hands on control that shows up in real interviews.

#Azure #CloudSecurity #AzurePolicy #RBAC #CostManagement #DevOps #CloudEngineering #NIST #CareerChange #Veterans

---

## Post 2 - GitHub Repo

**Thumbnail:** `assets/thumbnails/png/post2-github.png` (or generic alternate `assets/thumbnails/generic/png/g2-github.png`)

Repo is live for Lab 05 of my Cloud Engineering Accelerator series: Implementing Governance and Security Hardening in Azure.

What's inside:
- Full step-by-step SOP, portal clicks and Azure CLI commands side by side
- An Entra ID user provisioned with Reader-only access, scoped to a single resource group
- An Azure Policy with a Deny effect restricting VM sizes to the approved SKU list, enforced against every account in the resource group
- A Cost Management budget with an actual alert at 80 percent and a forecasted alert at 100 percent
- Nine build screenshots, including the two errors I actually hit and had to troubleshoot live
- Every control mapped to a NIST Cybersecurity Framework function

Total cost to build this: close to zero. The lab only stands up a resource group, a policy assignment, and a budget. Time investment: about an hour.

If you are studying for AZ-500 or just want to see governance controls that actually get enforced instead of just documented, the SOP walks through the whole build including the troubleshooting.

Repo: https://github.com/Gguerra4networks/Lab-05-Implementing-Governance-and-Security-Hardening

Star it if it's useful. More labs coming in this series.

#Azure #AzurePolicy #RBAC #CloudSecurity #GitHub #AZ500 #CloudEngineering #InfrastructureAsCode #CareerChange #Veterans

---

## Post 3 - One Thing I Learned

**Thumbnail:** `assets/thumbnails/png/post3-learned.png` (or generic alternate `assets/thumbnails/generic/png/g3-learned.png`)
**Suggested second image:** `assets/screenshots/05-vm-policy-blocked-d2sv3.png`

Not every red error in Azure means your policy failed.

While testing my VM-size Deny policy, I tried deploying a Standard_B1s VM through the portal and the size showed up grayed out as "Size not available." My first assumption was the policy itself, or a Generation 1 versus Generation 2 image mismatch. I spent real time chasing both.

The actual answer came from the CLI. Running the deployment with `az vm create` returned a `SkuNotAvailable` error, not `RequestDisallowedByPolicy`. Those are two completely different failure modes in Azure. `RequestDisallowedByPolicy` means your governance control did its job and blocked the request. `SkuNotAvailable` means the region simply does not have capacity for that VM size right now, which has nothing to do with policy at all.

Once I saw the actual error code instead of trusting the portal's grayed-out UI, the whole troubleshooting path got a lot shorter.

Lesson: when Azure blocks something, read the actual error code before you start debugging your policy. The portal UI does not always tell you which layer failed.

Have you ever chased a policy bug that turned out to be a capacity issue?

#Azure #AzurePolicy #Troubleshooting #CloudSecurity #AzureCLI #DevOps #CloudEngineering #LessonsLearned #CareerChange #Veterans

---

## Post 4 - What I'd Do Differently

**Thumbnail:** `assets/thumbnails/png/post4-different.png` (or generic alternate `assets/thumbnails/generic/png/g4-different.png`)
**Suggested second image:** `assets/screenshots/06-budget-auth-error-wrong-account.png`

I locked myself out of my own budget and didn't realize it for ten minutes.

Setting up the Cost Management budget, I kept hitting: "Cannot create budget - The client does not have authorization to perform action." My Owner account has full rights on the subscription, so I started checking role assignments, assuming something was actually broken.

The real problem: the portal was still signed in as the Reader-only junior developer test account from an earlier phase. Reader cannot write a budget. My Owner account was never in the picture.

**Before:** troubleshooting permissions on the wrong identity.
**Fix:** click the account avatar top-right, confirm the signed-in email before anything else.
**Verify:** `az account show --query user.name -o tsv` matches your admin UPN.

Next time: check the signed-in identity first, every time an authorization error shows up, before assuming a role assignment is missing.

What's the dumbest "permissions bug" you've chased that turned out to be the wrong account?

#Azure #CostManagement #CloudSecurity #AzureCLI #RBAC #DevOps #Troubleshooting #CloudEngineering #CareerChange #Veterans
