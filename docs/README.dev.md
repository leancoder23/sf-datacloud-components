# Data Cloud Query Components — Developer Guide

This repository contains Apex services and Lightning Web Components (LWC) that fetch and visualize Salesforce Data Cloud query results. It supports two pluggable backends:

- **Data Cloud CDP** — Native platform APIs via `ConnectApi.CdpQuery` (requires companion org connection)
- **Data Cloud REST API** — Via Named Credential (no companion org required)

---

## Repository Structure

The project is organized into three SFDX packages:

```
sf-datacloud-query-components/
├── data-cloud-query-components/          # Main package (dcQueryComponents)
│   └── main/default/
│       ├── classes/
│       │   ├── DataCloudQueryServiceController.cls     # AuraEnabled controller
│       │   ├── DataCloudQueryServiceControllerTest.cls
│       │   ├── DataCloudQueryServiceProvider.cls        # Strategy/factory for backend selection
│       │   └── DataCloudQueryServiceProviderTest.cls
│       ├── labels/
│       │   └── CustomLabels.labels-meta.xml             # 11 translatable UI labels
│       ├── lwc/
│       │   ├── dataCloudQueryResultList/                # List/table component
│       │   │   ├── dataCloudQueryResultList.html
│       │   │   ├── dataCloudQueryResultList.js
│       │   │   ├── dataCloudQueryResultList.js-meta.xml
│       │   │   ├── dataCloudQueryResultList.css
│       │   │   ├── dataUtils.js                         # Pure utility functions
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryResultChart/               # Chart component
│       │   │   ├── dataCloudQueryResultChart.html
│       │   │   ├── dataCloudQueryResultChart.js
│       │   │   ├── dataCloudQueryResultChart.js-meta.xml
│       │   │   ├── chartUtility.js                      # Chart.js function registry
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryResultRecord/              # Record detail component
│       │   │   ├── dataCloudQueryResultRecord.html
│       │   │   ├── dataCloudQueryResultRecord.js
│       │   │   ├── dataCloudQueryResultRecord.js-meta.xml
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryService/                   # Shared service module
│       │   │   └── dataCloudQueryService.js
│       │   ├── dataCloudQueryResultField/               # Field renderer child component
│       │   │   ├── dataCloudQueryResultField.html
│       │   │   ├── dataCloudQueryResultField.js
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryActionBar/                 # Action bar child component
│       │   │   ├── dataCloudQueryActionBar.html
│       │   │   ├── dataCloudQueryActionBar.js
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryFlowModal/                 # Flow modal (LightningModal)
│       │   │   └── dataCloudQueryFlowModal.js
│       │   ├── dataCloudQueryResultListCustomDataTypesProvider/  # Custom datatable types
│       │   │   ├── dataCloudQueryResultListCustomDataTypesProvider.js
│       │   │   ├── customUrl.html
│       │   │   ├── customPopoverCell.html
│       │   │   └── __tests__/
│       │   ├── dataCloudQueryResultListPopoverCell/      # Popover cell child component
│       │   │   ├── dataCloudQueryResultListPopoverCell.html
│       │   │   ├── dataCloudQueryResultListPopoverCell.js
│       │   │   └── dataCloudQueryResultListPopoverCell.css
│       │   └── dataCloudCustomUrl/                       # Custom URL provider
│       │       └── dataCloudCustomUrl.js
│       └── objects/
│           └── DataCloudQuerySetting__mdt/               # Custom metadata type definition
│               ├── DataCloudQuerySetting__mdt.object-meta.xml
│               └── fields/ (8 fields)
│
├── data-cloud-query-service-cdp/         # CDP backend package (dcQueryServiceCdp)
│   └── main/default/classes/
│       ├── DataCloudCdpQueryService.cls
│       └── DataCloudCdpQueryServiceTest.cls
│
├── data-cloud-query-service-restapi/     # REST backend package (dcQueryServiceRestApi)
│   └── main/default/classes/
│       ├── DataCloudRestQueryService.cls
│       └── DataCloudRestQueryServiceTest.cls
│
├── config/
│   └── project-scratch-def.json
├── sfdx-project.json
├── jest.config.js
└── package.json
```

### Package Dependencies

```
dcQueryComponents (main)
    ↑                ↑
    │                │
dcQueryServiceCdp   dcQueryServiceRestApi
```

Both backend packages depend on the main `dcQueryComponents` package. Only one backend package needs to be deployed, based on your org's setup.

---

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                          Lightning App Builder                                │
│  ┌────────────────────┐ ┌───────────────────┐ ┌───────────────────────────┐   │
│  │ ResultList (LWC)   │ │ ResultChart (LWC) │ │ ResultRecord (LWC)       │   │
│  │  └─ ActionBar      │ │                   │ │  └─ ActionBar            │   │
│  │  └─ CustomTypes    │ │                   │ │  └─ ResultField (×N)     │   │
│  │  └─ PopoverCell    │ │                   │ │                           │   │
│  └────────┬───────────┘ └─────────┬─────────┘ └────────────┬──────────────┘   │
│           │                       │                         │                  │
│           └───────────────────────┼─────────────────────────┘                  │
│                                   │                                            │
│                    c/dataCloudQueryService (shared)                             │
│                    ├─ executeDataCloudQuery()                                   │
│                    ├─ getDataCloudQueryResultData()                             │
│                    ├─ resolveRecordNavigation()                                 │
│                    └─ PageRefTracker                                            │
└───────────────────────────────────┼────────────────────────────────────────────┘
                                    │ imperative Apex calls
                    ┌───────────────▼────────────────┐
                    │ DataCloudQueryServiceController │
                    │ ├─ submitDataCloudQuery()       │
                    │ ├─ getDataCloudQueryStatus()    │
                    │ ├─ getDataCloudQueryData()      │
                    │ ├─ getRecordData()              │
                    │ └─ resolveRecordNavigation()    │
                    └───────────────┬────────────────┘
                                    │
                    ┌───────────────▼────────────────┐
                    │ DataCloudQueryServiceProvider   │
                    │ (Strategy/Factory)              │
                    │ ├─ getInstance()                │
                    │ └─ IDataCloudQueryProvider      │
                    └──────┬────────────────┬────────┘
                           │                │
              ┌────────────▼───┐   ┌────────▼──────────┐
              │ CdpQueryService│   │ RestQueryService   │
              │ (ConnectApi)   │   │ (Named Credential) │
              └────────────────┘   └───────────────────┘
```

### Asynchronous Query Execution Flow

Unlike simple cacheable wire calls, the components use an asynchronous query pattern:

1. **Submit** → `submitDataCloudQuery()` sends the SQL to Data Cloud and returns a `queryId`
2. **Poll** → If not immediately complete, `getDataCloudQueryStatus()` polls every 500ms (up to 90s timeout)
3. **Fetch** → `getDataCloudQueryData()` retrieves paginated results using `queryId`, `rowStart`, `rowCount`

This pattern supports large datasets, server-side pagination, and long-running queries.

---

## Apex Layer

### DataCloudQueryServiceController

**File:** `data-cloud-query-components/main/default/classes/DataCloudQueryServiceController.cls`

| Method | Annotations | Parameters | Return Type | Description |
|--------|-------------|------------|-------------|-------------|
| `submitDataCloudQuery` | `@AuraEnabled` | `String querySettingId, Id recordId` | `QueryResult` | Reads the query from custom metadata, resolves record-based parameters, executes via the selected backend. |
| `getDataCloudQueryStatus` | `@AuraEnabled` | `String querySettingId, String queryId` | `QueryResult` | Checks whether an asynchronous query has completed. Returns `isCompleted` flag and `rowCount`. |
| `getDataCloudQueryData` | `@AuraEnabled` | `String querySettingId, String queryId, Integer rowStart, Integer rowCount` | `QueryResult` | Fetches a page of results for a completed query. |
| `getRecordData` | `@AuraEnabled(Cacheable=true)` | `Id recordId, List<String> fields` | `SObject` | Retrieves field values from a Salesforce record (used for record-based query parameter resolution). Enforces FLS checks. |
| `resolveRecordNavigation` | `@AuraEnabled(Cacheable=true)` | `String recordId, String data360ObjectName` | `RecordNavigationInfo` | Resolves navigation strategy for a record ID: local SF record → Data360 record via `ssot__Id__c` → custom page fallback. |

**Inner classes:**

- `SoqlQueryAdapter` — Wraps SOQL operations for testability (virtual methods, mockable).
- `RecordFieldParam` — Represents a record-based filter parameter with `name`, `type`, `fieldName`.
- `RecordNavigationInfo` — Navigation resolution result with `navigationType`, `resolvedRecordId`, `objectApiName`.

**Navigation types:** `LOCAL_RECORD`, `DATA360_RECORD`, `CUSTOM_PAGE`.

**Record-based filter parsing:** The `RecordBasedFilterConfig__c` field is parsed as comma-separated entries of format `paramName:fieldName:dataType`. Each entry becomes a `SqlParameterItem` passed to the query backend.

### DataCloudQueryServiceProvider

**File:** `data-cloud-query-components/main/default/classes/DataCloudQueryServiceProvider.cls`

Strategy/factory class that selects the appropriate query backend at runtime.

**Selection logic (in `getInstance()`):**
1. Reads the `QueryDefault` custom metadata record
2. Validates `Dataspace__c` and `WorkloadName__c` are set
3. If `UseDataCloudRestApi__c` is `false` AND `DataCloudCdpQueryService` class exists → instantiates CDP service
4. If `DataCloudRestQueryService` class exists → instantiates REST service (requires `NamedCredential__c`)

**Key types:**

- `IDataCloudQueryProvider` — Interface with `initializeWith()`, `executeQuerySql()`, `getQueryStatus()`, `getQueryResult()`
- `QueryResult` — `queryId`, `isCompleted`, `rowCount`, `records` (List<Map<String,Object>>)
- `SqlParameterItem` — `name`, `type`, `value` (bind parameters for parameterized queries)
- `DataCloudQueryServiceException` — Custom exception type

### Backend Implementations

**DataCloudCdpQueryService** (`data-cloud-query-service-cdp/`):
- Uses `ConnectApi.CdpQuery` APIs
- Requires companion org connection
- No Named Credential needed

**DataCloudRestQueryService** (`data-cloud-query-service-restapi/`):
- Uses REST callouts via Named Credential
- No companion org connection needed
- Requires Named Credential setup

Both implement `IDataCloudQueryProvider` and are loaded dynamically via `Type.forName()`.

---

## Custom Metadata Type: DataCloudQuerySetting__mdt

**Object:** `data-cloud-query-components/main/default/objects/DataCloudQuerySetting__mdt/`

| Field | API Name | Type | Length | Description |
|-------|----------|------|--------|-------------|
| Query | `Query__c` | LongTextArea | 131072 | SQL query with optional `:paramName` bind variables |
| Dataspace | `Dataspace__c` | Text | 255 | Data Cloud dataspace name |
| WorkloadName | `WorkloadName__c` | Text | 255 | Workload name for debugging/support |
| Record-Based Filter Config | `RecordBasedFilterConfig__c` | LongTextArea | 20000 | `paramName:fieldName:type` mapping (comma-separated) |
| Record Filter Object | `RecordFilterObject__c` | Text | 255 | Salesforce object API name for page-context validation |
| Use Data Cloud Rest Api | `UseDataCloudRestApi__c` | Checkbox | — | Toggle REST vs CDP backend on `QueryDefault` record (default: false) |
| Named Credential | `NamedCredential__c` | Text | 255 | Named Credential API name on `QueryDefault` record (required for REST) |

> **Deprecated field:** `UseCurrentRecord__c` exists on the object definition but is no longer used by any component or Apex code. It should be removed in a future cleanup.

**Required record:** A record with `DeveloperName` = `QueryDefault` must exist, providing the org-wide default `Dataspace__c`, `WorkloadName__c`, and the backend selection (`UseDataCloudRestApi__c` / `NamedCredential__c`).

---

## LWC Component Architecture

### Shared Service: c/dataCloudQueryService

**File:** `data-cloud-query-components/main/default/lwc/dataCloudQueryService/dataCloudQueryService.js`

Shared module imported by all three main components. Encapsulates all Apex interactions.

| Export | Type | Description |
|--------|------|-------------|
| `executeDataCloudQuery(querySettingId, recordId, pageSize)` | async function | Full query lifecycle: submit → poll → fetch first page. Returns `{ queryId, totalRowCount, records }`. |
| `getDataCloudQueryResultData(querySettingId, queryId, rowOffset, rowCount)` | async function | Fetches additional pages for lazy loading. Returns `{ records }`. |
| `resolveRecordNavigation(recordId, data360ObjectName)` | async function | Resolves navigation strategy for a record ID. |
| `formatString(format, ...values)` | function | String formatter using `{0}`, `{1}` placeholders. |
| `resolveRecordId(apiRecordId, pageReference)` | function | Resolves record ID from either the `@api recordId` or the `c__recordId` URL query parameter. |
| `PageRefTracker` | class | Tracks page reference changes and triggers data reload when the record context changes. |

**Polling configuration:**
- `MAX_WAIT_FOR_FINISH_STATUS`: 90000ms (90 seconds timeout)
- `WAIT_LOOP_DELAY`: 500ms between status checks
- `DEFAULT_PAGE_SIZE`: 20

### dataCloudQueryResultList

**Key internal modules:**

- `dataUtils.js` — Pure utility functions for pagination, search, sort, and data keying
- Uses `NavigationMixin` for record navigation
- Custom datatable types via `c-data-cloud-query-result-list-custom-data-types-provider`
- Popover cells via `c-data-cloud-query-result-list-popover-cell` (uses Popper.js)
- Action bar via `c-data-cloud-query-action-bar`

**Data pipeline:**

```
masterData (raw server records, accumulated)
    │
    ├─ applyFilter() → processedData (filtered by searchTerm)
    │
    └─ applySort() → processedData (sorted)
         │
         └─ getPageSlice() → data (current page for display)
```

**Lazy loading:** `fetchDataUpTo(requiredCount)` fetches additional pages from the server as the user navigates. For search/sort operations, `withAllData(fn)` ensures all server data is loaded before applying client-side operations.

**Search behavior:** Activates after 3+ characters. Searches only columns marked `filterable: true` using the `sortFilterField` (or `fieldName` as fallback). Debounced at 300ms.

### dataCloudQueryResultChart

**Key internal modules:**

- `chartUtility.js` — Contains `chartFunctionRegistry` (a fixed set of pre-built functions) and `hydrateChartConfig()` for replacing `@@FUNC:` markers with real JavaScript functions from the registry

**Limitation — LWC Locker Service:** Custom Chart.js plugins and arbitrary dynamic functions cannot be injected at runtime through JSON configuration. Only functions pre-registered in `chartFunctionRegistry` (in `chartUtility.js`) can be referenced via `@@FUNC:` markers. To add new dynamic functions, a developer must add them to `chartFunctionRegistry` and redeploy. Currently registered functions: `groupedLegendFilter`, `groupedLegendClick`, `drawStackLabels`.

**Chart rendering pipeline:**

1. Load Chart.js from static resource (`DCQR_ChartJsLib`)
2. Fetch data via `executeDataCloudQuery()`
3. `parseAndValidateConfig()` — Parse JSON, handle legacy `dataMap` backward compatibility
4. `transformDataForChart()` — Map query field names to Chart.js data arrays
5. `hydrateChartConfig()` — Replace `@@FUNC:` string markers with actual functions from `chartFunctionRegistry`
6. `renderChart()` — Create Chart.js instance on canvas

**Data limit:** 800 records max (`DATA_SET_MAX_SIZE`).

### dataCloudQueryResultRecord

**Key child components:**

- `c-data-cloud-query-result-field` — Renders individual field values with type-aware formatting
- `c-data-cloud-query-action-bar` — Per-record Flow action buttons

**Field type rendering:** Uses `TYPE_RENDERERS` map to normalize type names to renderer identifiers, then the `dataCloudQueryResultField` template switches between `lightning-formatted-*` base components.

**Layout:** Uses `lightning-layout` with SLDS 12-column grid. Field size = `Math.floor(12 / columns)`. Fields with `spanFull: true` get size 12.

**Multi-record support:** The component renders ALL records from the query results (up to 100), each as a separate card section with its own action bar.

### dataCloudQueryActionBar

**Flow execution:** Opens Salesforce Screen Flows in a `LightningModal` (`c-data-cloud-query-flow-modal`).

**Selection modes:**
- `single` — Exactly one row must be selected; individual field mappings via `inputMappings`
- `multiple` — One or more rows; rows are projected/serialized as JSON into a single Flow variable
- `none` — No selection required

**Special mapping:** `fieldName: "__ALL__"` passes the entire record as a JSON string.

---

## Custom Labels

All UI text is translatable via custom labels with the `DCQR_` prefix:

| Label API Name | Default Value |
|----------------|---------------|
| `DCQR_Data_Not_Found` | No Data found! |
| `DCQR_Generic_Error_Message` | Oops! Something went wrong. Please contact administrator |
| `DCQR_Showing_Record_Count` | Showing {0}-{1} of {2} records |
| `DCQR_Total_Rows` | Total rows: {0} |
| `DCQR_Search_Placeholder` | Search this list... |
| `DCQR_Search_Fields_Info` | Searching across: {0} |
| `DCQR_Search_Sort_Disabled` | Note: Search and sorting are disabled for datasets exceeding {0} records... |
| `DCQR_Showing_Current_Page_Label` | Page {0} of {1} |
| `DCQR_Showing_Page_Numbers` | Page {0} |
| `DCQR_Single_Row_Selection` | This action requires exactly one selected record. |
| `DCQR_Multi_Row_Selection` | Select one or more records before proceeding. |
| `DCQR_Generic_Row_Selection_Info` | Select one or more records from the table to activate these buttons... |

---

## Static Resources

| Resource Name | Library | Used By |
|---------------|---------|---------|
| `DCQR_ChartJsLib` | Chart.js | `dataCloudQueryResultChart` |
| `DCQR_PopperJsLib` | Popper.js | `dataCloudQueryResultListPopoverCell` |
| `DCQR_ModelFlowOverride` | CSS | `dataCloudQueryFlowModal` |

---

## Prerequisites

- **Salesforce CLI** (`sf`) installed and authenticated
- **Dev Hub** or sandbox access
- **Data Cloud** provisioned and accessible in the target org:
  - **CDP connection** (Home org or Companion org): Users need the "Allows user access Data Cloud" system permission and relevant dataspace access
  - **REST API**: Named Credential and External Credential with service user authorization must be configured
- **Node.js** and npm for running Jest tests

---

## Installation

### Deploy to Scratch Org

```bash
sf org create scratch -f config/project-scratch-def.json -a dc-query-components -s
sf project deploy start -o dc-query-components
sf org assign permset -n DataCloudQueryServicePermission -o dc-query-components
```

### Deploy to Sandbox

```bash
sf project deploy start -o <sandbox-alias>
sf org assign permset -n DataCloudQueryServicePermission -o <sandbox-alias>
```

### Post-Deployment

1. Upload required static resources (`DCQR_ChartJsLib`, `DCQR_PopperJsLib`, `DCQR_ModelFlowOverride`)
2. Create the `QueryDefault` custom metadata record with org-wide `Dataspace__c` and `WorkloadName__c`
3. Create query-specific custom metadata records as needed

> **Note:** The `sfdx-project.json` defines three package directories. `sf project deploy start` deploys all of them. If you only need one backend, deploy selectively.

---

## Development Conventions

### Apex

- `with sharing` enforcement on all controllers
- `@AuraEnabled` for LWC-callable methods; `(Cacheable=true)` only for idempotent reads
- `AuraHandledException` / `DataCloudQueryServiceException` for user-facing errors
- FLS checks via `DescribeFieldResult.isAccessible()` in `getRecordData()`
- `SoqlQueryAdapter` virtual class pattern for test mockability
- Strategy/Factory pattern via `DataCloudQueryServiceProvider` for backend selection

### LWC

- SLDS classes for all styling
- Custom labels for all user-facing text (translatable)
- Imperative Apex calls (not `@wire`) for the async query lifecycle
- `PageRefTracker` pattern for record context tracking across all three components
- `debounce()` for search input handling
- Pure utility functions extracted to colocated modules (`dataUtils.js`, `chartUtility.js`)

### Error Handling Pattern

All three components share a consistent error handling pattern:

1. Errors starting with `[RECORD_CONTEXT_ERROR]` are treated as informational messages (not errors) — displayed as a config info banner
2. All other errors are displayed in a collapsible SLDS accordion section

---

## Testing

### Apex Tests

```bash
sf apex run test -o <org-alias> --code-coverage --result-format human
```

Test classes:
- `DataCloudQueryServiceControllerTest`
- `DataCloudQueryServiceProviderTest`
- `DataCloudCdpQueryServiceTest`
- `DataCloudRestQueryServiceTest`

### LWC Jest Tests

```bash
npm install
npm test
```

Test files exist for all main and child components under `__tests__/` directories.

---

## Deployment Checklist

- [ ] All source files deployed (`sf project deploy start`)
- [ ] Static resources uploaded (`DCQR_ChartJsLib`, `DCQR_PopperJsLib`, `DCQR_ModelFlowOverride`)
- [ ] `QueryDefault` custom metadata record created with Dataspace, WorkloadName, and backend selection
- [ ] Data Cloud access configured (CDP: user permissions + dataspace access; REST: Named Credential + External Credential)
- [ ] Query-specific custom metadata records created
- [ ] `DataCloudQueryServicePermission` permission set assigned to users
- [ ] Components visible in Lightning App Builder
- [ ] Data Cloud connectivity verified (queries return data)

---

## Troubleshooting

### "QueryDefault setting expected and it does not exist"
Create a `DataCloudQuerySetting__mdt` record with `DeveloperName` = `QueryDefault` and set `Dataspace__c` and `WorkloadName__c`.

### "Dataspace and workload name cannot be empty for QueryDefault setting"
Edit the `QueryDefault` custom metadata record and ensure both fields have values.

### Chart.js not loading
Verify the static resource is named exactly `DCQR_ChartJsLib` (case-sensitive).

### "Fetching query status is timeout"
The query did not complete within 90 seconds. This may indicate a complex query or Data Cloud performance issues. Simplify the query or increase the timeout in `dataCloudQueryService.js`.

### Component not appearing in App Builder
- Verify `isExposed` is `true` in the `.js-meta.xml` file
- Confirm the `apiVersion` (65.0) is compatible with the target org
- Check deployment was successful
