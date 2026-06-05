# Zero Trust Assessment To Zero Trust Workshop

Carry your **Zero Trust Assessment** findings directly into the **Zero Trust Workshop** in seconds.

## What is this tool?

**Zero Trust Assessment To Zero Trust Workshop** is a PowerShell script (`Convert-ZTAssessmentToZTWorkshop.ps1`) that turns your [Zero Trust Assessment](https://github.com/microsoft/zerotrustassessment) HTML report into a JSON file you can import into the [Zero Trust Workshop](https://zerotrust.microsoft.com/).

Instead of re-typing assessment results into the Workshop one task at a time, the script:

- Reads the HTML report you exported from the assessment
- Maps each assessment test to the matching Workshop task (Identity, Devices, Data, Network)
- Produces a Workshop-ready JSON file with each task pre-filled with the assessment's findings as notes

The result: your assessment work shows up inside the Workshop tasks, ready for your Zero Trust adoption planning.

## Quick links

- [aka.ms/zta2ztws](https://aka.ms/zta2ztws) → **Access this page directly**
- [aka.ms/zta2ztws/issues](https://aka.ms/zta2ztws/issues) → **Report a bug or open an issue**
- [aka.ms/zta2ztws/feedback](https://aka.ms/zta2ztws/feedback) → **Share your feedback — tell us what you like and how we can improve**

## Prerequisites

- **PowerShell 5.1 or later** (Windows PowerShell or PowerShell 7+)
- A **Zero Trust Assessment HTML report** — generated from the [Zero Trust Assessment module](https://github.com/microsoft/zerotrustassessment)
- The files from this repository (the script and `test-mapping.json`)

## Usage

### Basic usage

```powershell
.\Convert-ZTAssessmentToZTWorkshop.ps1 -HtmlFilePath ".\ZeroTrustAssessmentReport.html"
```

This produces a timestamped JSON file in the current folder, for example:

```
ZTA-to-Workshop-2026-06-05_152200.json
```

### Specify an output file

```powershell
.\Convert-ZTAssessmentToZTWorkshop.ps1 `
    -HtmlFilePath "C:\Reports\ZeroTrustAssessmentReport.html" `
    -OutputFilePath ".\my-workshop-import.json"
```

### Use a custom mapping file

```powershell
.\Convert-ZTAssessmentToZTWorkshop.ps1 `
    -HtmlFilePath ".\ZeroTrustAssessmentReport.html" `
    -MappingFilePath ".\test-mapping.json"
```

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-HtmlFilePath` | Yes | — | Path to the Zero Trust Assessment HTML report. |
| `-OutputFilePath` | No | `./ZTA-to-Workshop-{timestamp}.json` | Where to save the generated JSON. |
| `-MappingFilePath` | No | `./test-mapping.json` | Path to the test-to-task mapping file (included). |

## Import into the Zero Trust Workshop

1. Open the [Zero Trust Workshop](https://zerotrust.microsoft.com/).
2. Use the Workshop's import feature to load the JSON file produced by the script.
3. Your assessment findings now appear on the corresponding Workshop tasks as notes — ready for planning and tracking.

## What gets mapped?

The script ships with a curated mapping that covers the four active Workshop pillars:

| Pillar | Workshop tasks covered | Assessment tests mapped |
|---|---|---|
| Identity | 40 | 100 |
| Devices | 25 | 30 |
| Data | 14 | 34 |
| Network | 41 | 69 |

Tests without a mapping entry are skipped and will not appear in the output.

Expand a pillar below to see which Workshop tasks are covered and which assessment tests feed into each one.

<details>
<summary><strong>Identity — 40 Workshop tasks, 100 assessment tests</strong></summary>

**Design Conditional Access Posture**

- Token protection policies are configured
- User sign-in activity uses token protection
- Secure the MFA registration (My Security Info) page

**Discover and triage modern apps**

- Service principals use safe redirect URIs
- Inactive applications don't have highly privileged Microsoft Graph API permissions
- Inactive applications don't have highly privileged built-in roles
- Applications don't have certificates with expiration longer than 180 days
- Enforce standards for app secrets and certificates
- Enterprise applications with high privilege Microsoft Graph API permissions have owners
- Guests do not own apps in the tenant
- App registrations use safe redirect URIs
- App registrations must not have dangling or abandoned domain redirect URIs

**Discover and triage legacy apps**

- No usage of ADAL in the tenant

**Rollout Conditional Access with device state and app management controls**

- All sign-in activity comes from managed devices

**Rollout Conditional Access with risk controls**

- Restrict high risk sign-ins
- Restrict access to high risk users
- All risky workload identity sign-ins are triaged
- All risky workload identities are triaged
- Service principals don't have certificates or credentials associated with them

**Rollout Conditional Access for Guest Accounts**

- Guests don't have long lived sign-in sessions

**Rollout Authenticator App**

- Microsoft Authenticator app shows sign-in context
- Microsoft Authenticator app report suspicious activity setting is enabled

**Migrate on-prem MFA systems**

- Migrate from legacy MFA and SSPR policies

**Migrate self-service password reset**

- Block administrators from using SSPR

**Develop credential (incl. Passwordless) strategy**

- Users have strong authentication methods configured
- SMS and Voice Call authentication methods are disabled
- Password expiration is disabled
- Temporary access pass is enabled
- Restrict Temporary Access Pass to Single Use

**Deploy Password Protection**

- Password protection for on-premises is enabled
- Add organizational terms to the banned password list
- Smart lockout duration is set to a minimum of 60
- Smart lockout threshold set to 10 or less

**Migrate to Password Hash Sync auth**

- Use cloud authentication

**Rollout FIDO2**

- Security key authentication method enabled
- Passkey authentication method enabled
- Security key attestation is enforced

**Drive passwordless usage**

- All user sign in activity uses phishing-resistant authentication methods
- Reduce the user-visible password surface area

**Define policy & use least privileged roles**

- Global Administrators don't have standing access to Azure subscriptions
- Maximum number of Global Administrators doesn't exceed five users
- High Global Administrator to privileged user ratio
- Restrict non-administrator users from recovering the BitLocker keys for their owned devices
- Manage the local administrators on Microsoft Entra joined devices

**Use cloud-only privileged accounts**

- Privileged accounts are cloud native identities

**Rollout Privileged Identity Management for Tier-Zero roles**

- All Microsoft Entra privileged role assignments are managed with PIM
- Global Administrator role activation triggers an approval workflow

**Discover & remediate existing overprivileged Workload Identities**

- Workload Identities are not assigned privileged roles

**Lock down Microsoft Entra tenant config**

- User consent settings are restricted
- App instance property lock is configured for all multitenant applications
- Permissions to create new tenants are limited to the Tenant Creator role
- Creating new applications and service principals is restricted to privileged users
- Admin consent workflow is enabled
- Resource-specific consent is restricted
- Limit the maximum number of devices per user to 10
- Block legacy Azure AD PowerShell module
- All Microsoft Entra recommendations are addressed
- Enable protected actions to secure Conditional Access policy creation and changes
- High priority Microsoft Entra recommendations are addressed

**Rollout Privileged Identity Management for remaining roles**

- All privileged role assignments are activated just in time and not permanently active

**Rollout strong auth credentials for Workload Identities**

- Applications don't have client secrets configured
- Microsoft services applications don't have credentials configured
- Application certificates must be rotated on a regular basis

**Rollout Conditional Access for Workload Identities**

- Conditional Access policies for workload identities based on known networks are configured
- Workload Identities are configured with risk-based policies

**Enforce authentication with strong creds for all privileged accounts**

- Privileged users sign in with phishing-resistant methods
- Privileged accounts have phishing-resistant methods registered
- Privileged Microsoft Entra built-in roles are targeted with Conditional Access policies to enforce phishing-resistant methods
- Privileged users have short-lived sign-in sessions

**Deploy Cloud Privileged Access Workstations**

- Conditional Access policies for Privileged Access Workstations are configured

**Integrate all Microsoft Entra logs 
into Security Information and Event Management**

- Diagnostic settings are configured for all Microsoft Entra logs

**Remediate risk signals from Microsoft Entra ID Protection & Microsoft Defender for Identity**

- All high-risk users are triaged
- All high-risk sign-ins are triaged

**Implement monitoring for Entra Connect Sync**

- Entra Connect Sync is configured with Service Principal Credentials

**Discover & remediate existing overprivileged accounts**

- Guests are not assigned high privileged directory roles

**Implement Monitoring of Role-Based Access Assignments**

- Privileged role activations have monitoring and alerting configured
- Activation alert for Global Administrator role assignment
- Activation alert for all privileged role assignments

**Inventory applications and resources, attributes needed from users, and owners**

- Enterprise applications have owners

**Determine sequence of application onboarding and Microsoft Entra Integration**

- Enterprise applications must require explicit assignment or scoped provisioning

**Roll out app automated provisioning**

- Applications are configured for automatic user provisioning

**Define patterns of initial access for guests**

- Guests can't invite other guests
- Guest self-service sign-up via user flow is disabled

**Assign sponsors to existing guests**

- All guests have a sponsor

**Roll out onboarding access packages for guests**

- All entitlement management policies have an expiration date
- All entitlement management policies that apply to External users require approval
- All entitlement management packages that apply to guests have expirations or access reviews configured in their assignment policies

**Roll out guest cleanup processes**

- Inactive guest identities are disabled or removed from the tenant

**Define requirements to onboard new partner organizations**

- Outbound cross-tenant access settings are configured
- Guests have restricted access to directory objects
- Tenant restrictions v2 policy is configured
- Guest access is limited to approved tenants
- All entitlement management assignment policies that apply to external users require connected organizations

**Rollout Conditional Access with Authentication Strength controls**

- Authentication transfer is blocked
- Require multifactor authentication for device join and device registration using user action

**Roll out Conditional Access for network and legacy app access**

- Block legacy authentication policy is configured
- Restrict device code flow
- Named locations are configured

**Plan and implement emergency access (breakglass) accounts**

- Emergency access accounts are configured appropriately

</details>

<details>
<summary><strong>Devices — 25 Workshop tasks, 30 assessment tests</strong></summary>

**Compliance policy**

- Compliance policies protect iOS/iPadOS devices
- Compliance policies protect fully managed and corporate-owned Android devices
- Compliance policies protect personally owned Android devices

**Conditional access policy**

- Conditional Access policies block access from noncompliant devices

**Mobile Threat Defense**

- Defender for Endpoint automatic enrollment is enforced to reduce risk from unmanaged Android threats

**Wi-Fi**

- Secure Wi-Fi profiles protect iOS devices from unauthorized network access
- Secure Wi-Fi profiles protect Android devices from unauthorized network access

**Windows Hello for Business**

- Authentication on Windows uses Windows Hello for Business

**Send org data to other apps**

- Data on iOS/iPadOS is protected by app protection policies
- Data on Android is protected by app protection policies

**Compliance Policies**

- Compliance policies protect Windows devices

**Windows Update**

- Windows Update policies are enforced to reduce risk from unpatched vulnerabilities

**MAM Conditional Access**

- Conditional Access policies block access from unmanaged apps

**Enrollment Restriction & Notifications**

- Device enrollment notifications are enforced to ensure user awareness and secure onboarding

**FileVault**

- FileVault encryption protects data on macOS devices

**Compliance policy**

- Compliance policies protect macOS devices

**Attack surface reduction**

- Attack Surface Reduction rules are applied to Windows devices to prevent exploitation of vulnerable system components

**Enable Windows Firewall**

- Windows Firewall policies protect against unauthorized network access

**Bitlocker + Key Escrow**

- Data on Windows is protected by BitLocker encryption

**LAPS**

- Local administrator credentials on Windows are protected by Windows LAPS
- A macOS Cloud LAPS Policy is Created and Assigned

**Local Users and Groups**

- Local account usage on Windows is restricted to reduce unauthorized access

**Compliance: Require Firewall**

- macOS Firewall policies protect against unauthorized network access

**Defender for macOS**

- Defender Antivirus policies protect macOS devices from malware

**Platform SSO**

- Platform SSO is configured to strengthen authentication on macOS devices

**Managed macOS Updates**

- Update policies for macOS are enforced to reduce risk from unpatched vulnerabilities

**Company Portal Deployment**

- Company Portal branding and support settings enhance user experience and trust

**Scope Tags**

- Scope tag configuration is enforced to support delegated administration and least-privilege access

**Endpoint Analytics**

- Endpoint Analytics is enabled to help identify risks on Windows devices

**Security Baselines**

- Security baselines are applied to Windows devices to strengthen security posture

</details>

<details>
<summary><strong>Data — 14 Workshop tasks, 34 assessment tests</strong></summary>

**Sensitive data discovery**

- On-Demand scans configured for sensitive information discovery
- Custom Sensitive Information Types (SITs) Configured
- Exact Data Match (EDM) Configurations

**Document/Identify all approved cross-boundary data sharing scenarios**

- Cross-Tenant Access Policy (XTAP) RMS Inbound/Outbound Settings

**Define a data classification taxonomy for the organization based on data sensitivity**

- Total Sensitivity Labels Configured
- Global Scope Label Count

**Identify Automatic Classification cases**

- Named Entity SITs usage in Auto-Labeling and DLP policies

**Manually classify sensitive assets**

- Published Label Policies
- Sensitivity Labels Enabled in SharePoint Online
- PDF Labeling Support in SharePoint Online
- Container labels are configured for Teams, Groups, and Sites
- Mandatory labeling enabled for sensitivity labels
- Downgrade Justification Required for Sensitivity Labels

**Set Data Loss Prevention policies**

- DLP Policies Enabled
- Adaptive Protection in DLP Policies

**Monitor sharing by employees**

- Copilot Communication Compliance Monitoring Configured

**Automatically label sensitive assets**

- SPO Default Document Library Label (Tenant-Wide)
- Email label inheritance from attachments configured
- Default label configured for sensitivity labels
- Auto-Labeling Policies Configured (All Workloads)
- Auto-labeling enforcement mode enabled
- Auto-Labeling Policies Enabled for SharePoint and OneDrive
- Mail flow rules with rights protection

**Identify sensitive data using Trainable Classifiers**

- Trainable Classifiers Usage in Policies

**Set Insider Risk Management policies**

- Insider Risk Management Policies Enabled for Risky AI Usage

**Privileged Access Management for DLP/MIP/IRM Admins**

- Super User Membership Configuration

**Protect Critical Assets**

- Information Rights Management (IRM) Enabled in SharePoint Online
- Co-Authoring Enabled for Encrypted Documents
- Encryption-Enabled Labels
- Azure RMS Licensing Enabled
- Internal RMS Licensing Enabled
- Office 365 Message Encryption (OME) - SimplifiedClientAccessEnabled

**Evaluate and implement special cryptographic needs (BYOK, DKE)**

- Double Key Encryption (DKE) Labels

**Monitor Audit Logs for Data Access**

- Purview audit logging enabled

</details>

<details>
<summary><strong>Network — 41 Workshop tasks, 69 assessment tests</strong></summary>

**Enable Quick Access and Deploy Connectors**

- Quick Access has assigned users or groups
- Quick Access is enabled and bound to a connector

**Migrate key remote apps to Quick Access & enable private DNS**

- Is port 53 published or private DNS configured for Private Access applications
- Private DNS is configured for internal name resolution

**Secure remote app access with modern security controls (MFA/Device Trust)**

- Conditional Access policies enforce strong authentication for private apps
- Quick Access is bound to a Conditional Access policy

**Bring all legacy apps under full governance lifecycle**

- All Private Access applications have assigned users or groups

**Complete migration of apps to Private Access/App Proxy**

- Test 25401

**Roll out GSA client to all managed devices**

- Global Secure Access (GSA) client is deployed on all managed endpoints
- Global Secure Access licenses are available in the tenant and assigned to users

**Rollout App Segments for Macro Segmentation**

- Private Access application segments enforce least-privilege access

**Secure sensitive legacy App Access with PIM**

- Application admin rights are constrained to specific Private Access apps

**Implement B2B Guest Access for private apps**

- External collaboration is governed by explicit Cross-Tenant Access Policies

**Implement DC Agent for GSA**

- DC Agent is deployed and enforcing strong authentication policies
- Domain controller RDP access is protected by phishing-resistant authentication through Global Secure Access

**Implement intelligent local Access**

- Intelligent Local Access is enabled and configured

**Review GSA Audit Logs**

- GSA Deployment logs are populated and reviewed

**Export Traffic and Audit logs to external SIEM solution**

- Network access logs are retained for security analysis and compliance requirements

**Leverage GSA Sentinel integration**

- Network access activity is visible to security operations for threat detection and response

**Monitor and scale out**

- At least two Private Access connectors are active and healthy per connector group
- Private Access Connectors are running the latest version
- Private network connectors are active and healthy to maintain Zero Trust access to internal resources

**Define your SaaS app and Internet Access protection policy**

- Traffic forwarding profiles are scoped to appropriate users and groups for controlled deployment

**Onboard M365 traffic to SSE**

- Microsoft 365 traffic is actively flowing through Global Secure Access

**Update CA policies to leverage Compliant Network controls**

- Compliant network controls are used in conditional access policies

**Onboard Internet Access Secure Web Gateway capabilities**

- Internet access forwarding profile is enabled
- Network traffic is routed through Global Secure Access for security policy enforcement

**Enable and configure URL Filtering capabilities**

- Global Secure Access Web content filtering controls internet access based on website categories
- Global Secure Access web content filtering is enabled and configured
- Internet traffic is protected by web content filtering policies in Global Secure Access
- Web content filtering blocks high-risk categories

**Rollout advanced filtering and Inspection**

- Test 27014

**Implement Universal Tenant Restrictions to protect Auth and Data Plan for M365**

- Users accessing external applications from corporate devices are blocked unless explicitly authorized by tenant restrictions policies

**Enable GSA Signaling for Conditional Access**

- Global Secure Access signaling for Conditional Access is enabled
- Internet Access security policies are enforced through Conditional Access for user-aware protection
- Network access is validated in real-time through Universal Continuous Access Evaluation

**Enable and Configure TLS inspection**

- TLS inspection bypass rules are regularly reviewed
- TLS inspection certificates have sufficient validity period to prevent service disruption
- TLS inspection custom bypass rules don't duplicate system bypass destinations
- TLS inspection failure rate is below 1%
- TLS inspection is enabled and correctly configured for outbound traffic in Global Secure Access

**Enable and configure Network DLP capabilities**

- Sensitive data exfiltration through file transfers is prevented by network content filtering policies

**Implement Threat Intelligence filtering**

- Test 25412

**Implement Cloud Firewall capabilities**

- Branch office internet traffic is protected by Cloud Firewall policies through Global Secure Access

**Protect enterprise generative AI applications with Prompt Shield**

- Enterprise generative AI applications are protected from prompt injection attacks through AI Gateway

**Create an Azure DDoS Protection Plan for VNETs / Enable Azure DDoS Protection for Public IPs**

- DDoS Protection is enabled for all Public IP Addresses in VNETs

**Deploy Azure Firewall and route all outbound and inbound traffic through it.**

- Outbound traffic from VNET integrated workloads is routed through Azure Firewall

**Enable Threat Intelligence based filtering in Azure Firewall Policy**

- Threat intelligence is Enabled in Deny Mode on Azure Firewall

**Enable IDPS to inspect all inbound and outbound traffic on Azure Firewall**

- IDPS Inspection is Enabled in Deny Mode on Azure Firewall

**Enable and configure TLS inspection on Azure Firewall policy to Inspect all outbound TLS traffic to allow/deny with IDPS and Application rules**

- Inspection of Outbound TLS Traffic is Enabled on Azure Firewall

**Azure WAF on Azure Front Door to protect global applications**

- Azure Front Door WAF is Enabled in Prevention Mode
- Request Body Inspection is enabled in Azure Front Door WAF

**Azure WAF on Azure Application Gateway to protect regional and internal applications**

- Application Gateway WAF is Enabled in Prevention mode
- Request Body Inspection is enabled in Application Gateway WAF

**Use the latest Default Ruleset and Bot Manager Ruleset**

- Bot protection rule set is enabled and assigned in Azure Front Door WAF
- Bot protection ruleset is enabled and assigned in Application Gateway WAF
- Default rule set is assigned in Azure Front Door WAF
- Default Ruleset is enabled in Application Gateway WAF

**Enable and configure Custom Rules for Rate Limit, JS Challenge and CAPTCHA**

- CAPTCHA challenge is enabled in Azure Front Door WAF
- JavaScript Challenge is Enabled in Application Gateway WAF
- JavaScript Challenge is Enabled in Azure Front Door WAF
- Rate Limiting is Enabled in Application Gateway WAF
- Rate Limiting is Enabled in Azure Front Door WAF

**Configure DDoS Alerting, Logging and Metrics**

- Diagnostic logging is enabled for DDoS-protected public IPs
- Metrics are enabled for DDoS-protected public IPs

**Configure diagnostic logging and metrics for the Azure Firewall Network and Application Rules, Threat Intelligence and IDPS**

- Diagnostic logging is enabled in Azure Firewall

**Configure diagnostic logging and metrics for WAF on Azure Front Door and Azure Application Gateway**

- Diagnostic logging is enabled in Application Gateway WAF
- Diagnostic logging is enabled in Azure Front Door WAF

**Enable and use the latest HTTP DDoS Ruleset**

- HTTP DDoS Protection Ruleset is Enabled in Application Gateway WAF

</details>



## Troubleshooting

**"HTML file not found"**
Check the path to your assessment report. Use an absolute path if you're unsure, e.g. `"C:\Reports\ZeroTrustAssessmentReport.html"`.

**"Failed to extract 'Tests' array from the HTML file"**
The HTML file isn't a valid Zero Trust Assessment report. Re-export it from the assessment module and try again.

**Execution policy errors**
If PowerShell blocks the script, unblock it once and run again:

```powershell
Unblock-File .\Convert-ZTAssessmentToZTWorkshop.ps1
```

Or run with a relaxed policy for the current session only:

```powershell
powershell -ExecutionPolicy Bypass -File .\Convert-ZTAssessmentToZTWorkshop.ps1 -HtmlFilePath ".\ZeroTrustAssessmentReport.html"
```

## Related links

- [Zero Trust Workshop](https://zerotrust.microsoft.com/)
- [Zero Trust Assessment](https://github.com/microsoft/zerotrustassessment)
- [Microsoft Zero Trust guidance](https://www.microsoft.com/security/business/zero-trust)
