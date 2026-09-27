# CEA Lab 05 - LinkedIn Post Series

**Posting notes:**
- Space these 2-3 days apart, in order: Loom, GitHub, Learned, Different.
- LinkedIn does not accept SVG. Use the PNG copies linked under each post.
- Consider adding a real screenshot as a second image on Posts 3 and 4 (the policy validation error and the budget alert screen are strong choices).
- Each post below lists its detailed thumbnail and its generic scroll-stopping alternate. Try swapping between them if engagement is flat.

---

## Post 1 - Loom Video

**Thumbnail:** `assets/thumbnails/png/post1-loom.png`
**Generic alternate:** `assets/thumbnails/generic/png/g1-watch.png`

I gave a junior developer full access to my Azure environment, then spent the rest of the lab making sure they couldn't actually do anything with it.

That is not a contradiction. It is governance.

For Lab 05 of the Cloud Engineering Accelerator, I built three controls in one resource group: a Reader role that lets a simulated junior dev see everything but touch nothing, an Azure Policy that blocks expensive VM sizes for every account including the Owner, and a cost budget with two different types of alerts.

Then I tested every single one. I logged in as the junior dev in an incognito window and tried to create a storage account. Denied. I tried to deploy an oversized VM. Blocked before it ever got created. I confirmed the budget would flag spend at 80% actual and again if it was forecasted to blow past the limit.

Untested governance is just a policy document nobody follows. This lab is the difference between writing the rule and proving the rule holds.

The walkthrough covers all three controls end to end, including the two failure tests that actually prove they work.

Watch the full breakdown here: [LOOM_URL]

#Azure #CloudSecurity #CloudGovernance #RBAC #AzurePolicy #NIST #CloudEngineering #CareerChange #VeteranInTech #LearnInPublic

---

## Post 2 - GitHub Repo

**Thumbnail:** `assets/thumbnails/png/post2-github.png`
**Generic alternate:** `assets/thumbnails/generic/png/g2-github.png`

The Lab 05 repo is live: a full governance build you can clone and run in your own Azure subscription.

Inside:

- A Reader role assignment scoped to one resource group, proven with a real AuthorizationFailed test
- An Azure Policy with a Deny effect that blocks non-approved VM sizes for every account, including Owner
- A cost budget with an Actual alert (fires after spend happens) and a Forecasted alert (fires on projected trend)
- The full SOP with portal clicks and CLI commands for every phase
- A troubleshooting table built from real issues in this build, not hypothetical ones

Cost to run it: close to zero if you stop before completing a VM deployment. Time: 60 to 75 minutes.

Every phase ends with a verification command, because a control you have not tested is a control you cannot trust in an interview or in production.

Part of my ongoing Cloud Engineering Accelerator portfolio as I move from 30 years in RF and telecom field engineering into cloud security.

Repo link: [REPO_URL]

If this helps your own Azure governance learning, a star helps other people find it.

#Azure #CloudGovernance #AzurePolicy #RBAC #GitHub #CloudSecurity #NIST #InfrastructureAsCode #CareerChange #OpenSource

---

## Post 3 - One Thing I Learned

**Thumbnail:** `assets/thumbnails/png/post3-learned.png`
**Generic alternate:** `assets/thumbnails/generic/png/g3-learned.png`

The exact error was: "Validation failed - Policy check failed: Restrict-VM-Sizes." I hit it from my own Owner account.

That surprised me. I have full Owner rights on this subscription. I can create, modify, and delete anything. I assumed that meant I could override any rule I had set for other people.

I was wrong, and that is the entire point of Azure Policy.

RBAC controls who can act. With Owner rights you can do almost anything, and grant yourself more access if you want. Azure Policy is different. A Deny effect applies to every account in scope, no exceptions, including the one that created the policy. There is no elevated-permissions escape hatch.

If governance could be bypassed by whoever has the most access, it would not be governance, it would be a suggestion. Policy exists as a separate system from RBAC so some rules hold regardless of who is asking.

The sentence that shows you actually understand the tool: RBAC is about identity, Policy is about configuration, and a mature governance model uses both together.

Has anyone else been caught off guard by a Deny policy blocking their own admin account? What was the fix?

#Azure #AzurePolicy #CloudGovernance #RBAC #CloudSecurity #NIST #LeastPrivilege #CloudEngineering #TechLearning #CareerChange

---

## Post 4 - What I'd Do Differently

**Thumbnail:** `assets/thumbnails/png/post4-different.png`
**Generic alternate:** `assets/thumbnails/generic/png/g4-different.png`

Next time I assign an Azure Policy, I am checking that it actually propagated before running the test that depends on it.

Policy assignments do not take effect instantly. The guide calls out a 10 to 30 minute propagation window, and it is easy to read that and test anyway because the assignment blade says "succeeded." Succeeded means the assignment was created, not that every evaluation point has picked it up yet.

The fix, a 10 second check before the deployment test:

```
az policy assignment list --query "[?name=='Restrict-VM-Sizes']" --output table
```

If it is listed at the right scope, wait out the remaining window, then test. A deployment that passes when it should have been blocked is usually a timing issue, not a bad policy definition.

Verify command once propagation is done:

```
az vm create --resource-group rg-lab05-gov-giovanni --size Standard_D2s_v3 ...
```

Expected: a validation failure naming the policy. Get that instead of an unexpected success and the control is working exactly as designed.

What is your go-to move when an Azure control seems to be silently not working: wait it out, or start debugging the config?

#Azure #AzurePolicy #CloudGovernance #DevOps #CloudSecurity #Troubleshooting #NIST #CloudEngineering #LessonsLearned #CareerChange
