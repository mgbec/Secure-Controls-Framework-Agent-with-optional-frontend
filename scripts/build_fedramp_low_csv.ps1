# Builds docs/fedramp-low-aws-implementation.csv from the SCF 2026.2 catalog.
# Authoritative columns (SCF ID, name, domain, NIST 800-53 mapping, ERL ref,
# cadence) come straight from the catalog. AWS guidance + example evidence are
# applied per SCF domain (domain-level patterns), consistent with the GovRAMP file.

$ErrorActionPreference = 'Stop'
$catalog = Join-Path $PSScriptRoot '..\..\JSON\scf-full-2026.2.json'
if (-not (Test-Path $catalog)) {
  # fall back to the SCF-2026-2 source tree location
  $catalog = 'c:\Users\maryb\Desktop\compliance scf\SCF-2026-2\SCF-2026-2\JSON\scf-full-2026.2.json'
}
$json = Get-Content $catalog -Raw | ConvertFrom-Json

# ERL id -> artifact name
$erlMap = @{}
foreach ($e in $json.evidence_request_list) { if ($e.erl_id) { $erlMap[$e.erl_id] = $e.artifact } }

# Per-domain AWS implementation guidance + example evidence.
$domainGuidance = @{
  'Security, Compliance & Resilience Governance' = @{ aws='Codify the security program in AWS using Organizations SCPs, Control Tower guardrails, and a documented control ownership model; track posture in Security Hub.'; ev='Program charter/policy; Control Tower guardrail report; Security Hub security score; control ownership matrix.' }
  'Asset Management' = @{ aws='Maintain an automated inventory with AWS Config, Systems Manager Inventory, and mandatory tagging enforced by Organizations tag policies.'; ev='AWS Config resource inventory; SSM Inventory report; tag policy compliance report.' }
  'Business Continuity & Disaster Recovery' = @{ aws='Design multi-AZ/multi-Region, centralize backups with AWS Backup (cross-Region/account copy + Vault Lock), and validate RTO/RPO with Resilience Hub.'; ev='AWS Backup plans and job history; Resilience Hub assessment; DR test results; restore test record.' }
  'Capacity & Performance Planning' = @{ aws='Use CloudWatch metrics/alarms, Auto Scaling, and Trusted Advisor to plan and enforce capacity; forecast with Cost/Usage and CloudWatch.'; ev='CloudWatch dashboards/alarms; Auto Scaling policies; capacity plan; Trusted Advisor checks.' }
  'Change Management' = @{ aws='Drive changes through IaC (CloudFormation/Terraform) with pipeline approvals, protected branches, and least-privilege deploy roles; log via CloudTrail.'; ev='Change tickets; pipeline approval config; CloudTrail change logs; branch protection settings.' }
  'Cloud Security' = @{ aws='Apply the AWS shared-responsibility model; enforce baseline guardrails with Control Tower, SCPs, and Config conformance packs.'; ev='Control Tower/landing-zone config; SCP set; Config conformance pack results.' }
  'Compliance' = @{ aws='Use AWS Audit Manager (FedRAMP framework), Config conformance packs, and Artifact for AWS compliance reports.'; ev='Audit Manager assessment report; Config conformance pack results; AWS Artifact reports.' }
  'Configuration Management' = @{ aws='Define hardened baselines (CIS via SSM) and golden AMIs; enforce with SSM State Manager + AWS Config drift detection.'; ev='Golden AMI pipeline; State Manager associations; Config baseline compliance; CIS scan.' }
  'Continuous Monitoring' = @{ aws='Aggregate findings in Security Hub; use GuardDuty, Config, CloudWatch, VPC Flow Logs, and an org CloudTrail into a central logging account (optionally Security Lake).'; ev='Security Hub dashboard; GuardDuty findings; org CloudTrail config; centralized log bucket; monitoring reports.' }
  'Cryptographic Protections' = @{ aws='Encrypt at rest with KMS/CloudHSM (FIPS 140-validated) and in transit with TLS; enforce via SCPs and Config rules; use FIPS endpoints.'; ev='KMS key inventory/policies; Config encryption-rule results; TLS/HTTPS listener config; FIPS endpoint usage.' }
  'Data Classification & Handling' = @{ aws='Classify and discover sensitive data with Amazon Macie; tag by sensitivity; enforce handling with S3 policies, Lake Formation, and KMS.'; ev='Macie classification findings; data classification policy; S3 bucket policies; tagging report.' }
  'Data Privacy' = @{ aws='Support privacy obligations with Macie (PII discovery), data-residency via Region selection, retention via S3 lifecycle, and access logging.'; ev='Macie PII findings; data-residency/Region config; retention lifecycle policy; privacy policy document.' }
  'Endpoint Security' = @{ aws='Harden endpoints with golden AMIs and SSM; deploy anti-malware/EDR (GuardDuty Malware Protection, partner agents) and FIM; encrypt volumes.'; ev='SSM-managed inventory; EDR/anti-malware coverage; GuardDuty Malware findings; FIM alerts; volume encryption report.' }
  'Human Resources Security' = @{ aws='Integrate HR/IdP via SCIM for joiner-mover-leaver; enforce onboarding/offboarding to IAM Identity Center; track training.'; ev='SCIM provisioning logs; onboarding/offboarding tickets; background-check policy; training records.' }
  'Identification & Authentication' = @{ aws='Centralize identity with IAM Identity Center/federated IdP; require MFA (FIDO2 for privileged); enforce least privilege with IAM Access Analyzer and SCPs; audit via CloudTrail.'; ev='IAM Identity Center config; MFA enforcement + credential report; Access Analyzer findings; quarterly access reviews; CloudTrail logs.' }
  'Information Assurance' = @{ aws='Assess controls with AWS Audit Manager (FedRAMP), run SA-11 testing in CI/CD, and maintain an assessment/authorization package.'; ev='Audit Manager assessment; security test results; SSP/control assessment records.' }
  'Incident Response' = @{ aws='Operate IR with Security Hub + GuardDuty + Detective; automate triage/containment via EventBridge, Lambda, and SSM Automation; define playbooks.'; ev='IR plan and playbooks; Security Hub incident records; automation runbooks; tabletop/game-day results.' }
  'Maintenance' = @{ aws='Perform maintenance via SSM (Patch Manager, Automation, Session Manager); restrict and log maintenance tools and remote maintenance.'; ev='SSM patch/automation config; Session Manager logs; approved maintenance-tool list; CloudTrail maintenance actions.' }
  'Mobile Device Management' = @{ aws='Govern mobile/BYOD access through the IdP and conditional access; restrict access to AWS consoles/apps from unmanaged devices.'; ev='MDM/conditional-access policy; device compliance report; access restriction evidence.' }
  'Network Security' = @{ aws='Segment with VPCs/subnets, security groups (default-deny), NACLs, AWS Network Firewall, Route 53 DNS Firewall, and WAF; broker remote access via SSM/Client VPN.'; ev='VPC/segmentation diagram; Network Firewall + WAF rules; security group review; Flow Logs; Session Manager/Client VPN config.' }
  'Physical & Environmental Security' = @{ aws='Inherit physical controls from AWS data centers via the shared-responsibility model; evidence through AWS Artifact (SOC 2 / FedRAMP) and the CRM.'; ev='AWS Artifact SOC 2 / FedRAMP package; customer responsibility matrix (CRM) noting inherited physical controls.' }
  'Project & Resource Management' = @{ aws='Integrate security into project/SDLC governance; track security requirements and resourcing in the delivery process.'; ev='Project security requirements; SDLC gate records; resourcing/plan documentation.' }
  'Risk Management' = @{ aws='Run risk assessments feeding a POA&M; use Security Hub + Audit Manager findings and Inspector risk scores as inputs.'; ev='Risk assessment report; POA&M; Security Hub/Audit Manager findings; Inspector risk scores.' }
  'Secure Engineering & Architecture' = @{ aws='Apply defense-in-depth and least-functionality; partition planes across accounts/VPCs; follow AWS Well-Architected (Security Pillar).'; ev='Architecture diagrams; Well-Architected review; account/VPC partitioning; threat model.' }
  'Security Awareness & Training' = @{ aws='Deliver role-based security training and track completion; include AWS-specific secure-use guidance.'; ev='Training curriculum; completion records; role-based training matrix.' }
  'Security Operations' = @{ aws='Run SecOps from Security Hub as the single pane; integrate GuardDuty/Detective/Inspector; define runbooks and on-call.'; ev='SecOps runbooks; Security Hub operations records; on-call/escalation documentation.' }
  'Technology Development & Acquisition' = @{ aws='Embed security in CI/CD: SAST/DAST/dependency and container scans (CodeGuru, Inspector for ECR, partner tools); gate on findings; secure the supply chain.'; ev='Pipeline security-test stages; SAST/DAST/SCA reports; ECR scan results; build-gate evidence.' }
  'Third-Party Management' = @{ aws='Assess vendors and manage supply-chain risk; for AWS, use Artifact for provider assurance and track third-party access via IAM roles with external IDs.'; ev='Vendor risk assessments; AWS Artifact reports; third-party IAM role/external-ID config; contract security clauses.' }
  'Threat Management' = @{ aws='Operationalize threat intel and detection with GuardDuty (threat lists), Security Hub, and Detective; tune detections.'; ev='GuardDuty threat-intel/finding config; Detective investigations; threat detection tuning records.' }
  'Vulnerability & Patch Management' = @{ aws='Scan continuously with Amazon Inspector (EC2/ECR/Lambda); remediate via SSM Patch Manager with severity-based SLAs; track status in Security Hub.'; ev='Inspector scan results and coverage; Patch Manager baselines + compliance; remediation SLA; Security Hub vuln findings.' }
}

$genericAws = 'Implement using the applicable AWS services for this control domain, enforced through Organizations SCPs, AWS Config rules, and IAM least privilege; monitor in Security Hub.'
$genericEv  = 'Policy/procedure document; AWS Config rule results; CloudTrail logs; Security Hub evidence.'

$low = $json.controls | Where-Object { $_.mappings.'US FedRAMP R5 (low)' -and "$($_.mappings.'US FedRAMP R5 (low)')".Trim() -ne '' }

$rows = foreach ($c in ($low | Sort-Object scf_domain, scf_id)) {
  # ERL reference enriched with artifact names
  $refs = @()
  if ($c.erl_reference -and "$($c.erl_reference)".Trim() -ne '') {
    foreach ($id in ($c.erl_reference -split "`r?`n")) {
      $id = $id.Trim(); if ($id -eq '') { continue }
      $art = $erlMap[$id]
      if ($art) { $refs += "$id ($art)" } else { $refs += $id }
    }
  }
  $g = $domainGuidance[$c.scf_domain]
  $aws = if ($g) { $g.aws } else { $genericAws }
  $ev  = if ($g) { $g.ev }  else { $genericEv }

  [PSCustomObject]@{
    'SCF ID'                      = $c.scf_id
    'SCF Control Name'            = $c.scf_control_name
    'Domain'                      = $c.scf_domain
    'NIST 800-53 Mapping'         = (($c.mappings.'US FedRAMP R5 (low)') -replace "`r?`n", ', ')
    'SCF ERL Reference'           = ($refs -join '; ')
    'Conformity Cadence'          = $c.conformity_cadence
    'AWS Implementation Guidance' = $aws
    'Example Evidence'            = $ev
  }
}

$outPath = Join-Path $PSScriptRoot '..\docs\fedramp-low-aws-implementation.csv'
$rows | Export-Csv $outPath -NoTypeInformation -Encoding UTF8
Write-Output "wrote $($rows.Count) rows to $outPath"
