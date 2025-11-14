# Data Cloud Query Components — Developer Guide

This repository contains Apex services and Lightning Web Components (LWC) that fetch and visualize Salesforce Data Cloud query results. It supports two pluggable backends:

- Data Cloud REST API (via Named Credential)
- Data Cloud CDP (native platform APIs)

This guide covers architecture, packages, installation, configuration, development, testing, and deployment.

## Repository Structure

- data-cloud-query-components/

  - main/default/classes/
    - DataCloudQueryServiceController.cls — AuraEnabled controller for LWC
    - DataCloudQueryServiceProvider.cls — Strategy/factory that selects concrete query service (REST or CDP)
  - main/default/lwc/
    - dataCloudQueryService/ — shared client helpers
    - dataCloudQueryResultList/ — list/table renderer for query results
    - dataCloudQueryResultChart/ — chart renderer (Chart.js static resource)
    - dataCloudCustomUrl/ and dataCloudCustomUrlProvider/ — components to provide/override Data Cloud API base URL when needed
  - main/default/objects/DataCloudQuerySetting\_\_mdt — Custom Metadata Type used to store query/config
  - main/default/staticresources/chartJsLib.\* — Chart.js bundled as static resource
  - main/default/permissionsets/DataCloudQueryServicePermission.permissionset-meta.xml — grants required access
  - main/default/labels/ — Custom Labels for UI texts
  - main/default/layouts/ — Layouts for the custom metadata UI

- data-cloud-query-service-restapi/

  - main/default/classes/
    - DataCloudRestQueryService.cls — Concrete service to call Data Cloud REST API

- data-cloud-query-service-cdp/

  - main/default/classes/
    - DataCloudCdpQueryService.cls — Concrete service to use native CDP platform APIs

- config/

  - project-scratch-def.json — Scratch org definition

- sfdx-project.json — SFDX project descriptor

## Technical Design (Short)

- Frontend: LWCs render results in list and chart formats. The chart component uses a Chart.js static resource. LWCs call Apex controller methods to fetch results.
- Backend: The `DataCloudQueryServiceProvider` selects a concrete implementation based on custom metadata/property (REST vs CDP). Both implementations expose a consistent interface for executing a configured query with optional record-context filters.
- Configuration: `DataCloudQuerySetting__mdt` stores:
  - WorkloadName\_\_c — Data Cloud workload or dataset scope
  - Query\_\_c — the query to run (e.g., SQL or segment query)
  - Dataspace\_\_c — Data Cloud dataspace when applicable
  - UseDataCloudRestApi\_\_c — toggles REST vs CDP provider
  - NamedCredential\_\_c — REST Named Credential reference
  - Record filter fields — RecordFilterObject**c, RecordBasedFilterConfig**c, UseCurrentRecord\_\_c
- Security: Use with sharing in Apex; user-mode DML/queries where applicable; permission set provides field/object access for runtime users.

## Prerequisites

- Salesforce CLI (sf) installed and authenticated
- Appropriate Dev Hub / scratch org access or a sandbox
- Data Cloud provisioned in the target org if using REST/CDP
- Named Credential configured for Data Cloud REST API (for REST mode)
- Users assigned the provided permission set

## Installation

You can deploy the full repository packages to a scratch org or sandbox.

1. Create/Push to a Scratch Org (example)

- Create org:
  - sf org create scratch -f config/project-scratch-def.json -a data-cloud-query -s
- Push source:
  - sf project deploy start -o data-cloud-query
- Assign permission set:
  - sf org assign permset -n DataCloudQueryServicePermission -o data-cloud-query

2. Deploy to a Sandbox

- Ensure your default org is set (or pass -o):
  - sf project deploy start
- Assign permission set:
  - sf org assign permset -n DataCloudQueryServicePermission

3. Load Sample Custom Metadata (Optional)

- Open Setup > Custom Metadata Types > Data Cloud Query Setting > Manage Records and create records as described below.

Note: This repo uses multiple source directories. The `sf project deploy start` command will deploy all package directories defined in sfdx-project.json.

## Configuration

1. Named Credential (REST Mode)

- Create a Named Credential with access to your Data Cloud REST endpoint
- Store the Named Credential API name in `DataCloudQuerySetting__mdt.NamedCredential__c`
- Ensure proper scopes and auth (OAuth/JWT) are configured

2. Data Cloud Query Setting (Custom Metadata)

- Navigate: Setup > Custom Metadata Types > Data Cloud Query Setting > Manage Records
- Create a record with:
  - Query Name & label of your choice
  - WorkloadName\_\_c (if required)
  - Dataspace\_\_c (if required)
  - Query\_\_c (your SQL/segment query)
  - UseDataCloudRestApi\_\_c (true for REST, false for CDP)
  - NamedCredential**c (required if UseDataCloudRestApi**c = true)
  - RecordFilterObject\_\_c (API name, e.g., Account)
  - RecordBasedFilterConfig\_\_c (JSON describing how to map current record fields to query parameters)
  - UseCurrentRecord\_\_c (true to enable context filtering from the page)

3. Permission Set

- Assign `DataCloudQueryServicePermission` to users who will run the components
- This grants access to the custom metadata, Apex classes, and necessary fields

## Development

- Apex patterns:
  - with sharing
  - Invocable/AuraEnabled endpoints for LWC
  - Strategy/Factory via `DataCloudQueryServiceProvider` to switch providers
  - No SOQL/DML in loops, bulkify where relevant, handle exceptions, and return early
- LWC patterns:
  - SLDS classes, loading/error states
  - `dataCloudQueryResultList` and `dataCloudQueryResultChart` are single-responsibility renderers
  - `dataCloudQueryService` encapsulates client logic to call Apex
  - `dataCloudCustomUrl*` supports dynamic REST base URL injection where needed
- Static resources:
  - `chartJsLib` is packaged for offline-safe chart rendering
- Labels and Layouts:
  - Labels in `labels/` for translatable UI text
  - Layouts defined for the custom metadata records

Recommended Commands:

- Run tests:
  - sf apex run test -o <org-alias> --code-coverage --result-format human
- Open org:
  - sf org open -o <org-alias>

## Testing

- Unit tests exist for:
  - DataCloudQueryServiceController
  - DataCloudQueryServiceProvider
  - DataCloudRestQueryService
  - DataCloudCdpQueryService
- Use `Test.startTest()`/`Test.stopTest()` and avoid SeeAllData=true
- Provide minimal test data using @TestSetup
- For callouts (REST mode), implement HttpCalloutMock as needed

## Deployment

- Use `sf project deploy start -o <org>` to deploy to target org
- Post-deploy checks:
  - Named Credential exists (REST mode)
  - Custom metadata records created
  - Permission set assigned
  - LWC components available in Lightning App Builder

## Troubleshooting

- LWC not rendering data:
  - Verify `DataCloudQuerySetting__mdt` exists and matches the component property
  - Check user has the permission set and object/field access
  - Confirm Named Credential and auth scopes (REST)
- Chart not visible:
  - Ensure `chartJsLib` static resource is deployed
- REST callouts failing:
  - Check Remote Site Settings (if not using Named Credential) and Named Credential auth

## Notes

- No hardcoded IDs/URLs: use Named Credentials and custom metadata
- Respect FLS and sharing via with sharing and user-mode access patterns
- Keep queries selective and secured; prefer WITH SECURITY_ENFORCED when applicable
