# Data Cloud Query Components — Admin/User Guide

This guide explains how Salesforce administrators can configure and use the Data Cloud Query Components to display Data Cloud query results on Lightning pages as tables, charts, and record detail views.

All three components are **no-code** — configuration is done entirely through Custom Metadata records and Lightning App Builder properties.

---

## Components Overview

| Component | App Builder Label | Purpose | Best For |
|-----------|-------------------|---------|----------|
| `dataCloudQueryResultList` | Data Cloud Query List | Sortable, searchable, paginated data table with optional Flow action buttons | Multi-row result sets (top accounts, case lists, asset inventories) |
| `dataCloudQueryResultChart` | Data Cloud Query Chart | Interactive charts powered by Chart.js (bar, line, pie, doughnut, polar area, radar, stacked) | Aggregated/grouped data (counts by category, revenue breakdowns, trend lines) |
| `dataCloudQueryResultRecord` | Data Cloud Query Result — Record Detail View | Section-based record detail layout with typed field rendering | Single- or multi-record views (customer 360 profile, summary metrics) |

All three components can be placed on:

- **Lightning App Pages**
- **Lightning Record Pages**
- **Lightning Home Pages**
---

## Prerequisites (One-Time Org Setup)

Before using the components, ensure the following one-time setup is complete:

### 1. Data Cloud Connectivity

Choose one of the following two options based on how Data Cloud is connected to your org:

**Option A — CDP Connection (Home Org or Companion Org)**

Use this option when Data Cloud is accessible in the org via a CDP connection (i.e. the org is connected as a Home org or Companion org).

- Ensure relevant users have the minimum required system permission: **"Allows user access Data Cloud"**.
- Grant users access to the relevant **dataspace(s)** they need to query.
- It is recommended to create a dedicated **permission set** for these Data Cloud access settings and assign it to all users who will interact with the components.
- On the `QueryDefault` custom metadata record, ensure `UseDataCloudRestApi__c` is **unchecked** (this is the default).

**Option B — REST API via Named Credentials**

Use this option when Data Cloud should be accessed via the REST API rather than a direct CDP connection.

- Set up the required **Named Credential** pointing to your Data Cloud REST endpoint, including the appropriate **External Credential** and **service user authorization** (OAuth/JWT).
- On the `QueryDefault` custom metadata record, configure:
  - `UseDataCloudRestApi__c` = **checked** (true)
  - `NamedCredential__c` = the API name of the Named Credential you created

### 2. QueryDefault Custom Metadata Record

A **`QueryDefault`** record of type `DataCloudQuerySetting__mdt` must exist with the org's default `Dataspace__c` and `WorkloadName__c` values set. This record is loaded at startup and provides:
- The default dataspace and workload name used by all queries.
- The backend selection (CDP vs REST) and Named Credential configuration (see above).

### 3. Static Resources

The following static resources must be uploaded to the org:

- `DCQR_ChartJsLib` — Chart.js library (required for the Chart component)
- `DCQR_PopperJsLib` — Popper.js library (required for popover cells in the List component)
- `DCQR_ModelFlowOverride` — CSS override for Flow modals (required for Flow action buttons)

### 4. Permission Set

Users must be assigned the **`DataCloudQueryServicePermission`** permission set, which grants access to the Apex classes and custom metadata used by the components.

---

## Step 1: Assign the Correct Page Layout

The `DataCloudQuerySetting__mdt` custom metadata type ships with two page layouts:

| Layout Name | Purpose | Fields Included |
|-------------|---------|-----------------|
| **Data Cloud Query Default Setting** | Used exclusively for the `QueryDefault` record (one-time org setup) | `Dataspace__c`, `WorkloadName__c`, `UseDataCloudRestApi__c`, `NamedCredential__c` |
| **Data Cloud Query Setting Layout** | Used for all query-specific records created by admins | `Query__c`, `Dataspace__c`, `WorkloadName__c`, `RecordFilterObject__c`, `RecordBasedFilterConfig__c` |

After completing the one-time setup of the `QueryDefault` record, you must **assign the correct page layout** so that admins see the right fields when creating new query records:

1. Go to **Setup → Custom Metadata Types → Data Cloud Query Setting**.
2. Click **Page Layout Assignment** (or **Edit Assignment**).
3. Assign the **"Data Cloud Query Setting Layout"** as the default layout for all profiles that will create query records.
4. Optionally, assign the **"Data Cloud Query Default Setting"** layout only to the System Administrator profile (or whichever profile manages the `QueryDefault` record).

This ensures that when admins create new query records, they see the relevant query configuration fields and do not see the org-level connectivity fields (`UseDataCloudRestApi__c`, `NamedCredential__c`) which belong only on the `QueryDefault` record.

---

## Step 2: Create a Data Cloud Query Setting (Custom Metadata Record)

Queries are stored as **DataCloudQuerySetting__mdt** custom metadata records. Each record contains a SQL query and related configuration.

### How to Create a Record

1. Go to **Setup → Custom Metadata Types**.
2. Find **Data Cloud Query Setting** and click **Manage Records**.
3. Click **New** and fill in the following fields:

| Field | API Name | Type | Required | Description |
|-------|----------|------|----------|-------------|
| **Label** | `MasterLabel` | Text | Yes | Human-readable name (e.g. "Top Accounts By Revenue") |
| **Name** | `DeveloperName` | Text | Yes | API name referenced from the component's **Query Setting Identifier** property |
| **Query** | `Query__c` | Long Text Area (131072) | Yes | ANSI SQL query to execute against Data Cloud. Supports parameterized queries using `:paramName` syntax for record-context filtering. |
| **Dataspace** | `Dataspace__c` | Text (255) | No | Data Cloud dataspace name. Leave blank to use the default from the `QueryDefault` record. Only set if this query needs to run in a different dataspace. |
| **WorkloadName** | `WorkloadName__c` | Text (255) | No | Workload name for debugging/support. Leave blank to use the default from the `QueryDefault` record. |
| **Record Filter Object** | `RecordFilterObject__c` | Text (255) | No | API name of the Salesforce object whose record page context is required (e.g. `Account`). When set, the component validates that it is placed on a page for this object type. |
| **Record-Based Filter Config** | `RecordBasedFilterConfig__c` | Long Text Area (20000) | No | Maps SQL query parameters to record fields. Format: `paramName:fieldName:dataType` (comma-separated for multiple). See section below. |

> **Note:** The fields `UseDataCloudRestApi__c`, `NamedCredential__c`, and `UseCurrentRecord__c` are **not** used on individual query records. `UseDataCloudRestApi__c` and `NamedCredential__c` are org-level settings configured only on the `QueryDefault` record (see Prerequisites). `UseCurrentRecord__c` is deprecated and no longer used.

4. Click **Save**.

### Record-Based Filter Configuration

The `RecordBasedFilterConfig__c` field lets you pass values from the current Salesforce record into your SQL query as bind parameters.

**Format:** `paramName:fieldName:dataType`

- `paramName` — The parameter placeholder name in your SQL query (used with `:paramName` syntax)
- `fieldName` — The Salesforce field API name on the record to read the value from. Use `recordId` to pass the record's Id directly.
- `dataType` — The SQL data type (e.g. `varchar`, `integer`)

**Multiple parameters** are separated by commas:

```
accountId:recordId:varchar,contactEmail:Email:varchar
```

**Example:** To filter Data Cloud results by the current Account's Id:

- **Query__c:** `SELECT Name__c, Revenue__c FROM account_dm WHERE Id__c = :accountId`
- **RecordFilterObject__c:** `Account`
- **RecordBasedFilterConfig__c:** `accountId:recordId:varchar`

When the component loads on an Account record page, it automatically reads the Account Id and passes it as the `:accountId` parameter.

---

## Step 3: Add Components in Lightning App Builder

### General Steps

1. Navigate to **Lightning App Builder** for your target page.
2. Search for the component by its label (e.g. "Data Cloud Query List").
3. Drag it onto the page canvas.
4. Configure properties in the right-hand panel (described below).
5. **Save** and **Activate** the page.

---

## Component Configuration Reference

---

### dataCloudQueryResultList

Displays Data Cloud query results in a sortable, searchable, paginated data table. Supports custom column types (record links and popovers) and Flow-based action buttons.

#### Configuration Properties

| Property | Label in App Builder | Type | Required | Default | Description |
|----------|---------------------|------|----------|---------|-------------|
| `querySettingId` | Query Setting Identifier | String | **Yes** | — | The `DeveloperName` of the `DataCloudQuerySetting__mdt` record |
| `title` | Card Title | String | No | `Data Cloud Query Results` | Title displayed in the card header |
| `titleHelpText` | Title Help Text | String | No | — | Tooltip text shown via an info icon next to the title |
| `subtitle` | Subtitle | String | No | — | Descriptive text shown below the title |
| `iconName` | Card Icon | String | No | `standard:live_data` | SLDS icon name for the card header |
| `pageSize` | Page Size | Integer | No | `20` | Number of rows per page (min: 5, max: 100) |
| `maxClientProcessingRows` | Max record count for client side sorting and filtering | Integer | No | `5000` | When total records exceed this threshold, search and sort are disabled. (min: 1000, max: 10000) |
| `columnConfig` | Column Configuration (JSON) | String | No | — | JSON array defining datatable columns (labels, field mappings, types, custom types). See detailed format below. |
| `actionConfig` | Action Configuration (JSON) | String | No | — | JSON defining action buttons that invoke Salesforce Flows. See Action Configuration below. |

#### Column Configuration JSON

The `columnConfig` defines the `lightning-datatable` columns. Each column object supports standard Lightning datatable properties plus custom types.

**Standard column properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `label` | String | Yes | Column header text |
| `fieldName` | String | Yes | Field name in the query results to display |
| `type` | String | No | Column type: `text`, `number`, `currency`, `date`, `boolean`, `url`, `customRecordLink`, `customPopoverCell` |
| `sortable` | Boolean | No | Whether column supports sorting. Automatically disabled when dataset exceeds `maxClientProcessingRows`. |
| `filterable` | Boolean | No | Whether the column is included in search filtering |
| `sortFilterField` | String | No | Alternative field name to use for sort/filter operations (when the display field differs from the sortable data) |
| `initialWidth` | Number | No | Column width in pixels |

**Simple column configuration example:**

```json
[
  {"label": "Account Name", "fieldName": "account_name__c", "type": "text", "sortable": true, "filterable": true},
  {"label": "Industry", "fieldName": "industry__c", "type": "text", "filterable": true},
  {"label": "Annual Revenue", "fieldName": "annual_revenue__c", "type": "currency", "sortable": true},
  {"label": "Employees", "fieldName": "employee_count__c", "type": "number", "sortable": true}
]
```

#### Custom Column Type: customRecordLink

Renders a clickable link that navigates to a Salesforce record. Supports local Salesforce records, Data Cloud (Data360) records resolved via `ssot__Id__c`, and custom Lightning pages.

**typeAttributes:**

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `label` | `{"fieldName": "..."}` | Yes | The field to use as the link display text |
| `objectName` | String | Conditional | API name of the target Data 360 object (e.g. `ssot__Opportunity__dlm`). Used to resolve Data Cloud record IDs via `ssot__Id__c` on the corresponding Data 360 object. **Only applicable when the org is connected to a Data 360 instance as a home or companion org** and you want to navigate to the standard record page for that remote object. Either `objectName` or `pageApiName` is required. |
| `pageApiName` | String | Conditional | API name of a custom Lightning page (tab) to navigate to. The record ID is passed as the `c__recordId` state parameter. Either `objectName` or `pageApiName` is required. **When both are provided, `pageApiName` takes priority** over `objectName` for non-local records. |

> **Note:** At least one of `objectName` or `pageApiName` must be provided. If only a valid Salesforce ID is expected in the link column, both can be omitted — the component will resolve local Salesforce records automatically. However, for Data Cloud IDs that are not native Salesforce IDs, you must configure one of these attributes for navigation to work.

**Example 1 — Data 360 object navigation** (org connected to Data 360):

```json
[
  {
    "label": "Opportunity",
    "type": "customRecordLink",
    "fieldName": "dcOpportunityId",
    "typeAttributes": {
      "label": {"fieldName": "opportunityName"},
      "objectName": "ssot__Opportunity__dlm"
    },
    "initialWidth": 320
  }
]
```

**Example 2 — Custom page navigation** (no Data 360 connection, or custom UI preferred):

```json
[
  {
    "label": "Opportunity",
    "type": "customRecordLink",
    "fieldName": "dcOpportunityId",
    "typeAttributes": {
      "label": {"fieldName": "opportunityName"},
      "pageApiName": "Data_Cloud_Opportunity_Detail"
    },
    "initialWidth": 320
  }
]
```

**Example 3 — Both configured** (`pageApiName` takes priority for non-local records):

```json
[
  {
    "label": "Opportunity",
    "type": "customRecordLink",
    "fieldName": "dcOpportunityId",
    "typeAttributes": {
      "label": {"fieldName": "opportunityName"},
      "objectName": "ssot__Opportunity__dlm",
      "pageApiName": "Data_Cloud_Opportunity_Detail"
    },
    "initialWidth": 320
  }
]
```

**Navigation resolution order:**
1. **Local Salesforce record** — If the `fieldName` value is a valid Salesforce ID and the user can access it, navigates directly to the standard record page.
2. **Custom Lightning page** (`pageApiName`) — If `pageApiName` is configured, navigates to that page with the record ID passed as `c__recordId`. **This takes priority over Data 360 resolution when both are configured.**
3. **Data 360 record** (`objectName`) — If `objectName` is set, the org is connected to a Data 360 instance, and the object exists in the schema, the component looks up the record via `ssot__Id__c` and navigates to its standard record page.
4. If none succeed → shows an error toast.

#### Custom Column Type: customPopoverCell

Renders a cell value as a clickable link; clicking the cell opens a popover with additional fields from the same row.

**Required typeAttributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `popoverTitle` | String | Title text at the top of the popover |
| `itemInfo` | Array | Array of field definitions to display in the popover (see below) |

**Optional typeAttributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `popoverIcon` | String | `utility:info` | SLDS icon name for the popover header |
| `popoverWidth` | Number | — | Width of the popover in pixels |
| `popoverHeight` | Number | — | Height of the popover content in pixels |

**itemInfo field object:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `label` | String | Yes | Display label for the field |
| `fieldName` | String | Yes | Field name from the row data to display |
| `type` | String | No | Rendering type: `richtext`, `number`, `integer`, `currency`, `date`, `datetime`. Defaults to plain text. |
| `cellSpanFull` | Boolean | No | When `true`, the field takes the full width of the popover instead of half |
| `typeAttributes` | Object | No | Additional formatting attributes passed to the formatter |

**Example:**

```json
[
  {
    "label": "Owner",
    "type": "customPopoverCell",
    "fieldName": "ownerName",
    "initialWidth": 220,
    "typeAttributes": {
      "popoverTitle": "Opportunity Owner",
      "popoverIcon": "standard:user",
      "popoverWidth": 520,
      "popoverHeight": 180,
      "itemInfo": [
        {"label": "Name", "fieldName": "ownerName"},
        {"label": "Email", "fieldName": "ownerEmail", "type": "richtext"},
        {"label": "Revenue", "fieldName": "ownerRevenue", "type": "currency"}
      ]
    }
  }
]
```

#### Action Configuration JSON

The `actionConfig` defines buttons in the card header that invoke Salesforce Screen Flows. Each action passes selected row data as input variables to the Flow.

**Top-level structure:**

```json
{
  "actions": [...],
  "visibleButtonCount": 3
}
```

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `actions` | Array | No | `[]` | Array of action definitions |
| `visibleButtonCount` | Integer | No | `3` | Number of action buttons visible before overflow into a "more" menu |
| `showRefresh` | Boolean | No | `true` | Whether to show the refresh button. The refresh button is **visible by default** — set to `false` to hide it. |

**Action object properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `label` | String | Yes | Button label text |
| `flowApiName` | String | Yes | API name of the Salesforce Screen Flow to invoke |
| `icon` | String | No | SLDS icon name for the button (e.g. `utility:add`, `utility:edit`) |
| `variant` | String | No | Lightning button variant (e.g. `brand`, `destructive`, `neutral`) |
| `selectionMode` | String | No | `single` (exactly one row), `multiple` (one or more rows), or `none` (no selection required). Default: `multiple`. |
| `inputMappings` | Array | Yes | Maps row field values to Flow input variables |
| `targetFlowVariable` | String | For multi | Name of the Flow variable that receives the JSON array (used in `multiple` mode) |
| `recordIdFlowVariable` | String | No | Name of a Flow variable to receive the current page's record ID |
| `refreshOnComplete` | Boolean | No | When `true`, refreshes the table data after the Flow completes |
| `size` | String | No | Modal size: `small`, `medium`, `large`. Default: `medium`. |

**inputMappings object (single mode):**

| Property | Type | Description |
|----------|------|-------------|
| `flowVariable` | String | Name of the Flow input variable |
| `fieldName` | String | Field name from the selected row. Use `__ALL__` to pass the entire row as a JSON string. |
| `type` | String | Data type conversion: `String`, `Number`, `Currency`, `Boolean`, `Date`, `DateTime` |

**inputMappings object (multiple mode):**

| Property | Type | Description |
|----------|------|-------------|
| `key` | String | Key name in the projected object for each row |
| `fieldName` | String | Field name from each selected row. Use `__ALL__` to pass entire rows. |

**Example (single selection action):**

```json
{
  "actions": [
    {
      "label": "Create Case",
      "flowApiName": "Create_Case_From_DC",
      "selectionMode": "single",
      "refreshOnComplete": true,
      "inputMappings": [
        {"flowVariable": "customerEmail", "fieldName": "Email__c", "type": "String"},
        {"flowVariable": "accountName", "fieldName": "Account_Name__c", "type": "String"}
      ]
    }
  ]
}
```

**Example (multiple selection action):**

```json
{
  "actions": [
    {
      "label": "Bulk Update",
      "flowApiName": "Bulk_Update_Flow",
      "selectionMode": "multiple",
      "targetFlowVariable": "selectedRecordsJson",
      "inputMappings": [
        {"key": "id", "fieldName": "Id__c"},
        {"key": "name", "fieldName": "Name__c"}
      ]
    }
  ]
}
```

#### Features

- **Search**: Case-insensitive search across columns marked with `filterable: true`. Activates after 3+ characters. Debounced at 300ms. Shows a help tooltip listing which columns are searchable.
- **Sorting**: Click any sortable column header. Supports type-aware sorting (text, number, date). Sort and search require loading all server data first.
- **Pagination**: Previous/Next navigation with a page-jump dropdown. Footer shows "Showing X-Y of Z records". When total rows differ from filtered results, shows total server row count as well.
- **Large dataset protection**: When server rows exceed `maxClientProcessingRows`, client-side search and sort are disabled with an explanatory tooltip.
- **Lazy loading**: Only the first page of data is fetched initially. Additional pages are fetched on demand. For search/sort, all data is loaded at once.
- **Row selection**: When action buttons are configured, checkboxes appear for row selection.
- **Record navigation**: `customRecordLink` columns open records in a new tab.
- **Refresh**: Automatic refresh when the record context changes on a record page.

---

### dataCloudQueryResultChart

Renders Data Cloud query results as an interactive chart using Chart.js. Supports standard Chart.js chart types (bar, pie, line, doughnut, etc.), stacked charts, and multiple datasets.

#### Configuration Properties

| Property | Label in App Builder | Type | Required | Default | Description |
|----------|---------------------|------|----------|---------|-------------|
| `querySettingId` | Query Setting Identifier | String | **Yes** | — | The `DeveloperName` of the `DataCloudQuerySetting__mdt` record |
| `chartTitle` | Chart Title | String | No | `Data Cloud Query Chart` | Title displayed in the card header |
| `chartHelpText` | Title Help Text | String | No | — | Tooltip text shown via an info icon next to the title |
| `chartSubtitle` | Chart Subtitle | String | No | — | Descriptive text shown below the title |
| `width` | Container Width | Integer | No | `80` | Width of the chart container in **viewport width** units (vw) |
| `height` | Container Height | Integer | No | `40` | Height of the chart container in **viewport height** units (vh) |
| `chartConfig` | Chart.js Config (JSON) | String | **Yes** | See below | A full Chart.js configuration JSON with data field mapping extensions. See detailed format below. |

#### Chart Configuration JSON — Standard Format

The `chartConfig` is a standard Chart.js configuration object with two extensions:

1. **`data.labelsField`** — Maps a query result field name to the chart labels (replaces `data.labels` array)
2. **`dataset.dataField`** — Maps a query result field name to dataset values (replaces `dataset.data` array)

These extensions are resolved at runtime: the component reads data from the query results and populates the standard Chart.js `labels` and `data` arrays automatically.

**Basic example (bar chart):**

```json
{
  "type": "bar",
  "data": {
    "labelsField": "manufacturer__c",
    "datasets": [
      {
        "label": "Asset Count",
        "dataField": "asset_count",
        "backgroundColor": "rgba(54, 162, 235, 0.7)"
      }
    ]
  },
  "options": {
    "responsive": true,
    "plugins": {
      "legend": {"position": "top"}
    }
  }
}
```

**Pie chart example:**

```json
{
  "type": "pie",
  "data": {
    "labelsField": "status__c",
    "datasets": [
      {
        "label": "Cases",
        "dataField": "case_count"
      }
    ]
  },
  "options": {
    "responsive": true,
    "plugins": {
      "legend": {"position": "right"}
    }
  }
}
```

When no `backgroundColor` is specified on a dataset, the component assigns colors from a built-in 6-color palette automatically.

#### Chart Configuration — Legacy Format (dataMap)

For backward compatibility, the component also supports a legacy `dataMap` format:

```json
{
  "type": "bar",
  "dataMap": {
    "labelField": "field_name_for_labels",
    "dataFields": ["value_field_1", "value_field_2"],
    "dataFieldLabels": {
      "value_field_1": "Label One",
      "value_field_2": "Label Two"
    },
    "backgroundColor": "rgba(54, 162, 235, 0.5)",
    "borderColor": "rgba(54, 162, 235, 1)"
  },
  "options": {
    "responsive": true,
    "plugins": {"legend": {"position": "top"}}
  }
}
```

The legacy format is automatically converted to the standard format at runtime. New configurations should use the standard `data.datasets` format.

#### Chart Configuration — Advanced: Stacked Charts with Multiple Datasets

For stacked bar charts with multiple datasets:

```json
{
  "type": "bar",
  "data": {
    "labelsField": "stage",
    "datasets": [
      {
        "label": "Product A",
        "dataField": "productA_sum",
        "backgroundColor": "rgba(54, 162, 235, 0.5)",
        "stack": "Group_1",
        "stackLabel": "2024"
      },
      {
        "label": "Product B",
        "dataField": "productB_sum",
        "backgroundColor": "rgba(75, 192, 192, 0.5)",
        "stack": "Group_1",
        "stackLabel": "2024"
      },
      {
        "label": "Product A",
        "dataField": "productA_current",
        "backgroundColor": "rgba(54, 162, 235, 0.5)",
        "stack": "Group_2",
        "stackLabel": "2025"
      },
      {
        "label": "Product B",
        "dataField": "productB_current",
        "backgroundColor": "rgba(75, 192, 192, 0.5)",
        "stack": "Group_2",
        "stackLabel": "2025"
      }
    ]
  },
  "options": {
    "responsive": true,
    "plugins": {
      "legend": {
        "position": "top",
        "labels": {"filter": "@@FUNC:groupedLegendFilter"},
        "onClick": "@@FUNC:groupedLegendClick"
      },
      "stackLabelsPlugin": {
        "font": "11px Arial",
        "color": "#666",
        "paddingTop": 8
      }
    },
    "scales": {
      "x": {"stacked": true},
      "y": {"stacked": true, "title": {"display": true, "text": "Value"}}
    }
  },
  "plugins": [
    {
      "id": "stackLabelsPlugin",
      "afterDatasetsDraw": "@@FUNC:drawStackLabels"
    }
  ]
}
```

**Custom dataset properties:**

| Property | Description |
|----------|-------------|
| `stack` | Stack group identifier (datasets with the same `stack` value are stacked together) |
| `stackLabel` | Human-readable label displayed below the stacked group on the x-axis |

#### Built-in Dynamic Function References

Due to LWC Locker Service restrictions, custom JavaScript plugins and arbitrary dynamic functions cannot be injected at runtime. The component provides a **fixed set of pre-built functions** that can be referenced from the JSON configuration using the `@@FUNC:functionName` marker syntax. At render time, these markers are replaced with the corresponding JavaScript functions from an internal registry.

> **Important:** Only the functions listed below are available. Custom plugins or functions beyond this set require a code change to the `chartFunctionRegistry` in `chartUtility.js` (see Developer Guide).

**Available functions:**

| Marker | Purpose |
|--------|---------|
| `@@FUNC:groupedLegendFilter` | Deduplicates legend entries for datasets that share the same label (useful for stacked charts where the same series appears in multiple stack groups) |
| `@@FUNC:groupedLegendClick` | Toggles visibility of **all** datasets sharing the clicked legend label (companion to `groupedLegendFilter`) |
| `@@FUNC:drawStackLabels` | Renders custom text labels below stacked bar groups using the `stackLabel` dataset property. Accepts configuration via `options.plugins.stackLabelsPlugin` with optional `font`, `color`, and `paddingTop` settings. |

**Usage:** Place the marker string wherever Chart.js expects a function value:

```json
"labels": {"filter": "@@FUNC:groupedLegendFilter"}
```

The `drawStackLabels` function is used as a Chart.js plugin hook. To use it, add a plugin entry in the top-level `plugins` array and optionally configure its appearance via `options.plugins.stackLabelsPlugin`:

```json
{
  "options": {
    "plugins": {
      "stackLabelsPlugin": {
        "font": "11px Arial",
        "color": "#666",
        "paddingTop": 8
      }
    }
  },
  "plugins": [
    {
      "id": "stackLabelsPlugin",
      "afterDatasetsDraw": "@@FUNC:drawStackLabels"
    }
  ]
}
```

#### Data Limits

The chart component enforces a maximum of **800 records** from the query. If the query returns more, an error is displayed asking the administrator to narrow the query.

#### Features

- **Refresh button**: A refresh icon button in the card header reloads the chart data.
- **Record context**: Supports record-page context filtering (same as the list component).
- **Auto-refresh**: Automatically refreshes when the record context changes.
- **Responsive sizing**: Chart scales responsively within its viewport-based container.

---

### dataCloudQueryResultRecord

Displays Data Cloud query results as a section-based record detail layout. Each record from the results is rendered with its own set of sections, fields, and optional action buttons. Supports rich field type rendering including dates, currency, emails, URLs, rich text, and booleans.

#### Configuration Properties

| Property | Label in App Builder | Type | Required | Default | Description |
|----------|---------------------|------|----------|---------|-------------|
| `querySettingId` | Query Setting Identifier | String | **Yes** | — | The `DeveloperName` of the `DataCloudQuerySetting__mdt` record |
| `title` | Title | String | No | — | Title displayed in the card header |
| `subtitle` | Subtitle | String | No | — | Descriptive text shown below the title |
| `titleHelpText` | Title Help Text | String | No | — | Tooltip text shown via an info icon next to the title |
| `iconName` | Icon | String | No | — | SLDS icon name for the card header (only rendered when the header is visible) |
| `hideHeader` | Hide Header | Boolean | No | `false` | When checked, hides the entire card header (title, icon, subtitle, help text) |
| `recordConfig` | Record Layout Configuration (JSON) | String | **Yes** | — | JSON defining sections, fields, data types, and layout. See detailed format below. |
| `actionConfig` | Action Configuration (JSON) | String | No | — | JSON defining action buttons that invoke Salesforce Flows. Actions are automatically scoped to single-record mode. Same structure as the list component's action config, but only `single` and `none` selection modes are supported. |

#### Record Configuration JSON

The `recordConfig` defines the layout structure using sections, each containing fields with typed rendering.

**Top-level structure:**

```json
{
  "showRefresh": true,
  "sections": [...]
}
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `showRefresh` | Boolean | `false` | When `true`, shows a refresh button in the card header |
| `sections` | Array | `[]` | Array of section definitions |

**Section object:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `label` | String | No | — | Section header label. When provided, the section renders as a collapsible accordion. When omitted, fields render in a flat layout. |
| `icon` | String | No | — | SLDS icon name for the accordion section header |
| `columns` | Integer | No | `1` | Number of field columns within the section (1-12). Field size is calculated as `12 / columns` using the SLDS 12-column grid. |
| `defaultCollapsed` | Boolean | No | `false` | When `true`, the accordion section starts in a collapsed state |
| `fields` | Array | Yes | — | Array of field definitions |

**Field object:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `label` | String | Yes | — | Display label shown above the field value |
| `fieldName` | String | Yes | — | Field name (or dot-notation path) in the query results to display. Supports nested paths like `address.city`. |
| `type` | String | No | `text` | Rendering type — see supported types below |
| `fieldHelpText` | String | No | — | Tooltip text shown via an info icon next to the field label |
| `spanFull` | Boolean | No | `false` | When `true`, the field spans the full width regardless of the section's column setting |
| `typeAttributes` | Object | No | `{}` | Additional formatting attributes for the field renderer (varies by type) |

**Supported field types and their typeAttributes:**

| Type | Renderer | Available typeAttributes |
|------|----------|------------------------|
| `text` | `lightning-formatted-text` | — |
| `longtext` | `lightning-formatted-text` | — |
| `date` | `lightning-formatted-date-time` | `year`, `month`, `day`, `timeZone` |
| `datetime` | `lightning-formatted-date-time` | `year`, `month`, `day`, `hour`, `minute`, `second`, `hour12`, `weekday`, `timeZone` |
| `currency` | `lightning-formatted-number` (currency style) | `currencyCode`, `currencyDisplayAs`, `minimumFractionDigits` |
| `number` | `lightning-formatted-number` | `minimumFractionDigits` |
| `integer` | `lightning-formatted-number` | `minimumFractionDigits` |
| `email` | `lightning-formatted-email` | — |
| `url` | `lightning-formatted-url` | `target` (e.g. `_blank`) |
| `richtext` | `lightning-formatted-rich-text` | — |
| `boolean` | `lightning-input` (checkbox, disabled) | — |

**URL fields with dynamic labels:** Use `typeAttributes.label.fieldName` to render the link text from another field in the record:

```json
{
  "label": "Website",
  "fieldName": "website_url__c",
  "type": "url",
  "typeAttributes": {
    "target": "_blank",
    "label": {"fieldName": "company_name__c"}
  }
}
```

#### Complete Example

**Query record:** A query returning customer profile data from Data Cloud.

**App Builder configuration:**

| Property | Value |
|----------|-------|
| Query Setting Identifier | `Customer360_Profile` |
| Title | `Customer 360` |
| Icon | `standard:contact` |
| Subtitle | `Unified customer profile from Data Cloud` |

**Record Configuration:**

```json
{
  "showRefresh": true,
  "sections": [
    {
      "columns": 3,
      "fields": [
        {"label": "Customer Name", "fieldName": "customer_name__c"},
        {"label": "Email", "fieldName": "email__c", "type": "email"},
        {"label": "Phone", "fieldName": "phone__c"}
      ]
    },
    {
      "label": "Financial Summary",
      "icon": "standard:currency",
      "columns": 2,
      "fields": [
        {"label": "Lifetime Value", "fieldName": "lifetime_value__c", "type": "currency", "typeAttributes": {"currencyCode": "EUR"}},
        {"label": "Total Purchases", "fieldName": "total_purchases__c", "type": "number"},
        {"label": "Last Purchase", "fieldName": "last_purchase_date__c", "type": "date"},
        {"label": "Segment", "fieldName": "segment__c"}
      ]
    },
    {
      "label": "Additional Details",
      "defaultCollapsed": true,
      "columns": 2,
      "fields": [
        {"label": "Account", "fieldName": "account_name__c"},
        {"label": "Last Interaction", "fieldName": "last_interaction_date__c", "type": "datetime", "typeAttributes": {"year": "numeric", "month": "short", "day": "2-digit", "hour": "2-digit", "minute": "2-digit"}},
        {"label": "Notes", "fieldName": "notes__c", "type": "richtext", "spanFull": true}
      ]
    }
  ]
}
```

#### Features

- **Multi-record display**: Unlike a typical record detail, this component renders **all** records returned by the query (up to 100), each with its own set of sections.
- **Collapsible sections**: Sections with a `label` render as accordions; sections without a label render as flat field grids.
- **Rich type rendering**: Each field type uses the appropriate `lightning-formatted-*` base component for proper localization and formatting.
- **Per-record actions**: When `actionConfig` is provided, each record gets its own action bar with Flow buttons scoped to that single record.
- **Record context**: Supports record-page context filtering (same as the list and chart components).
- **Refresh**: Refresh button (when `showRefresh: true`), and automatic refresh on record context change.

---

## Step 4: Assign Permissions

Ensure users who need to see the components have the permission set:

- **DataCloudQueryServicePermission**

Go to: **Setup → Permission Sets → DataCloudQueryServicePermission → Manage Assignments**.

---

## Troubleshooting

### Component shows "No Data found!"

1. Confirm the correct **Query Setting Identifier** is entered (the DeveloperName, not the label).
2. Verify the SQL query in the custom metadata record is valid for your Data Cloud environment.
3. If the query uses record-based filters, ensure the component is placed on the correct record page type matching `RecordFilterObject__c`.

### Component shows a config info message instead of data

- The message "Query requires current record id which is empty..." appears when `RecordBasedFilterConfig__c` is configured but no record ID is available. Ensure the component is placed on a record page that provides a record context.

### Component shows "Oops! Something went wrong"

- Click the error accordion to expand and see the detailed error message.
- Common causes: invalid SQL syntax, Data Cloud connectivity issues, missing permissions.

### Chart shows "Returned data set size is greater than maximum allowed..."

- The chart component limits data to 800 records. Adjust your SQL query to return fewer rows (use `LIMIT`, aggregation, or more specific filters).

### Search and sort are disabled on the list

- When the total row count exceeds the `maxClientProcessingRows` threshold (default: 5000), client-side search and sorting are automatically disabled. A tooltip explains this to users. Increase the threshold (up to 10000) or narrow the query.

### Flow action button is disabled

- **Single selection mode**: Exactly one row must be selected.
- **Multiple selection mode**: At least one row must be selected.
- A tooltip on the disabled button explains the requirement.

---

## FAQs

**Can I use multiple components on the same page?**
Yes. Each component instance has its own `querySettingId`, so you can point different instances to different queries.

**Can I show the same data as both a list and a chart?**
Yes. Create two components pointing to the same `DataCloudQuerySetting__mdt` record.

**Do I need to deploy code to change queries?**
No. Queries are stored in custom metadata records editable in Setup without any code deployment.

**Can I filter data by the current record?**
Yes. Configure `RecordBasedFilterConfig__c` and `RecordFilterObject__c` on the query setting, and use `:paramName` placeholders in the SQL query.

**What happens if my JSON configuration is malformed?**
The component displays an error message with details about the parsing failure.

**Can I invoke Salesforce Flows from the components?**
Yes. Both the list and record components support Flow action buttons via the `actionConfig` property. Flows open in a modal dialog.
