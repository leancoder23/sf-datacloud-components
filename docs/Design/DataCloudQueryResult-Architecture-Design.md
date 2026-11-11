# DataCloudQueryResult — Record Detail View Architecture Design

> **Date:** June 30, 2026
> **Author:** Architecture Review
> **Status:** Design Proposal
> **Component:** `dataCloudQueryResult` (sf-datacloud-query-components)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Component Positioning in the Framework](#3-component-positioning-in-the-framework)
4. [Configuration Schema: `recordConfig`](#4-configuration-schema-recordconfig)
   - 4.1 [Schema Structure](#41-schema-structure)
   - 4.2 [Section Definition](#42-section-definition)
   - 4.3 [Field Definition](#43-field-definition)
   - 4.4 [Supported Field Types and Rendering Components](#44-supported-field-types-and-rendering-components)
   - 4.5 [Column-to-Cell Size Mapping](#45-column-to-cell-size-mapping)
   - 4.6 [Configuration Example](#46-configuration-example)
5. [Lightning App Builder Properties](#5-lightning-app-builder-properties)
   - 5.1 [Meta XML Target Configuration](#51-meta-xml-target-configuration)
   - 5.2 [Property Optionality Rules](#52-property-optionality-rules)
6. [Data Fetching Architecture](#6-data-fetching-architecture)
   - 6.1 [Shared Pipeline](#61-shared-pipeline)
   - 6.2 [Data Flow Sequence](#62-data-flow-sequence)
7. [Multi-Record Rendering Strategy](#7-multi-record-rendering-strategy)
   - 7.1 [Decision: Stacked Layout Over Navigation](#71-decision-stacked-layout-over-navigation)
   - 7.2 [Visual Separator Between Records](#72-visual-separator-between-records)
8. [Section Rendering: Collapsible vs Static](#8-section-rendering-collapsible-vs-static)
   - 8.1 [Decision: Section Label Drives Collapse Behavior](#81-decision-section-label-drives-collapse-behavior)
   - 8.2 [Hybrid Rendering Approach](#82-hybrid-rendering-approach)
   - 8.3 [Section Icon Behavior](#83-section-icon-behavior)
9. [Card Header Optionality](#9-card-header-optionality)
   - 9.1 [With Title: Card Layout](#91-with-title-card-layout)
   - 9.2 [Without Title: Borderless Layout](#92-without-title-borderless-layout)
10. [Template Rendering Structure](#10-template-rendering-structure)
    - 10.1 [Overall Template Hierarchy](#101-overall-template-hierarchy)
    - 10.2 [Fields Grid Structure](#102-fields-grid-structure)
    - 10.3 [Type-Conditional Rendering Block](#103-type-conditional-rendering-block)
11. [View Model Architecture](#11-view-model-architecture)
    - 11.1 [View Model Builder: `buildViewModel()`](#111-view-model-builder-buildviewmodel)
    - 11.2 [View Model Data Structure](#112-view-model-data-structure)
    - 11.3 [Key Generation Strategy](#113-key-generation-strategy)
12. [Component Class Design](#12-component-class-design)
    - 12.1 [Class Diagram](#121-class-diagram)
    - 12.2 [Lifecycle Hooks](#122-lifecycle-hooks)
13. [Error, Loading, and Empty States](#13-error-loading-and-empty-states)
14. [Consistency with Existing Components](#14-consistency-with-existing-components)
15. [Visual Rendering Examples](#15-visual-rendering-examples)
    - 15.1 [Single Record with Mixed Sections](#151-single-record-with-mixed-sections)
    - 15.2 [Multiple Records Stacked](#152-multiple-records-stacked)
    - 15.3 [No Card Header (Title Omitted)](#153-no-card-header-title-omitted)
16. [Reuse of Existing Patterns](#16-reuse-of-existing-patterns)
17. [Salesforce Standard Components Used](#17-salesforce-standard-components-used)
18. [Future Extensibility](#18-future-extensibility)
19. [Decision Log](#19-decision-log)

---

## 1. Executive Summary

This document defines the architecture for the `dataCloudQueryResult` Lightning Web Component — a **record detail view** that renders Data Cloud query results in a structured, section-based layout analogous to a Salesforce standard Record Detail page.

Key design decisions:

- **Same data-fetching pipeline** as `dataCloudQueryResultList` and `dataCloudQueryResultChart` — shared `dataCloudQueryService` module, shared `DataCloudQuerySetting__mdt` configuration, same Apex controller and provider pattern.
- **Single JSON configuration property** (`recordConfig`) — follows the established pattern of `columnConfig` (list) and `chartConfig` (chart). Defines sections, fields, types, and layout in one JSON string configured via Lightning App Builder.
- **Section-based layout with configurable collapse** — sections with a `label` render as collapsible `lightning-accordion-section`; sections without a `label` render as static, always-visible blocks. This gives admins fine-grained control over which sections can be collapsed.
- **2-column default layout with full-row override** — each section defaults to 2 columns. Individual fields can span the full row via `spanFull: true`. Section-level `columns` property allows 1, 2, or 3 column layouts.
- **Type-aware field rendering** using standard `lightning-formatted-*` base components — extends the type system already proven in `dataCloudQueryResultListPopoverCell` with additional types (`email`, `phone`, `url`, `boolean`, `percent`, `location`).
- **Multi-record stacking** — when a query returns multiple records, all records render vertically with visual separators. No navigation buttons. This is the natural rendering model for a query that typically returns a single record but may occasionally return several.
- **Optional card header** — title, icon, help text, and subtitle are all optional. When title is omitted, the component renders without a `lightning-card` wrapper, producing a borderless content block.

---

## 2. Problem Statement

The `sf-datacloud-query-components` framework provides two visualization patterns for Data Cloud query results:

1. **List** (`dataCloudQueryResultList`) — tabular view via `lightning-datatable`
2. **Chart** (`dataCloudQueryResultChart`) — visual chart via Chart.js

Both are designed for **multi-record** visualization. There is no component for **single-record detail display** — showing a record's fields in a structured, labeled, section-based layout that matches the familiar Salesforce record page experience.

Use cases:

- Display a customer's Data Cloud profile (unified identity, engagement scores, calculated insights) on a record page
- Show aggregated metrics for a specific entity retrieved via a parameterized Data Cloud SQL query
- Present Data Cloud calculated insights or segmentation results in a human-readable format
- Render any single-row query result as a detailed field-by-field breakdown

---

## 3. Component Positioning in the Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                   Data Cloud Query Components                    │
├──────────────────┬─────────────────────┬────────────────────────┤
│  ResultList      │  ResultChart        │  ResultRecord (NEW)    │
│  (Datatable)     │  (Chart.js)         │  (Record Detail)       │
│  columnConfig    │  chartConfig        │  recordConfig          │
│  JSON → columns  │  JSON → chart       │  JSON → sections/fields│
│  Multi-record    │  Multi-record agg.  │  Single/few records    │
└────────┬─────────┴──────────┬──────────┴────────────┬───────────┘
         │                    │                       │
         └────────────────────┴───────────────────────┘
                              │
                    dataCloudQueryService (shared module)
                              │
                DataCloudQueryServiceController (Apex)
                              │
                DataCloudQueryServiceProvider (Strategy/Factory)
                              │
              ┌───────────────┴───────────────┐
              │                               │
    DataCloudCdpQueryService      DataCloudRestQueryService
    (ConnectApi.CdpQuery)         (HTTP /ssot/query-sql)
```

All three components share the identical data-fetching pipeline. The differentiation is purely in the **visualization layer**: how the fetched records are rendered.

| Aspect | List | Chart | Record (NEW) |
|---|---|---|---|
| **Primary use case** | Browse many records | Visualize aggregations | View record details |
| **Typical record count** | 10s–1000s | 10s–100s | 1 (occasionally 2–5) |
| **Config property** | `columnConfig` | `chartConfig` | `recordConfig` |
| **Config describes** | Datatable columns | Chart.js chart structure | Sections and fields |
| **Rendering engine** | `lightning-datatable` | Chart.js `<canvas>` | `lightning-layout` + `lightning-formatted-*` |
| **Pagination** | Yes (Load More / Next-Prev) | No (fetches all) | No (renders all records) |

---

## 4. Configuration Schema: `recordConfig`

### 4.1 Schema Structure

The admin provides a single JSON string via Lightning App Builder. The top-level object contains a `sections` array:

```json
{
  "sections": [ ... ]
}
```

### 4.2 Section Definition

| Property | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | String | **No** | — | Section header text. When omitted, the section renders as a plain non-collapsible block — always visible, no accordion. |
| `icon` | String | No | — | SLDS icon name for the section header (e.g., `"standard:contact"`). Ignored when `label` is absent. |
| `defaultCollapsed` | Boolean | No | `false` | Initial collapsed state. Ignored when `label` is absent (section is always expanded). |
| `columns` | Integer | No | `2` | Number of columns in the section grid. Allowed values: `1`, `2`, `3`. |
| `fields` | Array | Yes | — | Ordered list of field definitions within the section. |

**Behavioral rule:** The presence or absence of `label` determines whether the section is collapsible:

| `label` provided | Rendering | Collapse/Expand |
|---|---|---|
| Yes | `lightning-accordion-section` | Enabled (with `defaultCollapsed` control) |
| No | Plain `div` container | Disabled — always visible |

### 4.3 Field Definition

| Property | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | String | Yes | — | Display label for the field. |
| `fieldName` | String | Yes | — | Data Cloud field API name from query results (e.g., `"FirstName__c"`). |
| `type` | String | No | `"text"` | Data type for rendering. Determines which `lightning-formatted-*` component is used. |
| `spanFull` | Boolean | No | `false` | When `true`, the field spans the full row width regardless of the section's column count. |
| `typeAttributes` | Object | No | `{}` | Type-specific formatting attributes passed through to the rendering component. |

### 4.4 Supported Field Types and Rendering Components

| Type | LWC Rendering Component | Applicable `typeAttributes` |
|---|---|---|
| `text` (default) | `lightning-formatted-text` | — |
| `number` | `lightning-formatted-number` `format-style="decimal"` | `minimumFractionDigits`, `maximumFractionDigits` |
| `integer` | `lightning-formatted-number` `format-style="decimal"` | `minimumIntegerDigits` |
| `currency` | `lightning-formatted-number` `format-style="currency"` | `currencyCode`, `minimumFractionDigits` |
| `percent` | `lightning-formatted-number` `format-style="percent"` | `minimumFractionDigits`, `maximumFractionDigits` |
| `date` | `lightning-formatted-date-time` | `year`, `month`, `day` |
| `datetime` | `lightning-formatted-date-time` | `year`, `month`, `day`, `hour`, `minute`, `second`, `timeZone` |
| `email` | `lightning-formatted-email` | — |
| `phone` | `lightning-formatted-phone` | — |
| `url` | `lightning-formatted-url` | `label`, `target` |
| `boolean` | `lightning-input` `type="checkbox"` (disabled/readonly) | — |
| `richtext` | `lightning-formatted-rich-text` | — |
| `location` | `lightning-formatted-location` | — |

This type system extends the one already proven in `dataCloudQueryResultListPopoverCell` (which handles `text`, `number`, `integer`, `currency`, `date`, `datetime`, `richtext`) by adding `email`, `phone`, `url`, `boolean`, `percent`, and `location`. All are native LWC base components — no custom rendering logic required.

### 4.5 Column-to-Cell Size Mapping

The `lightning-layout-item` `size` attribute is computed from the section's `columns` property and the field's `spanFull` flag:

| Section `columns` | `spanFull: false` | `spanFull: true` |
|---|---|---|
| `1` | `size = 12` (full width) | `size = 12` |
| `2` (default) | `size = 6` (half width) | `size = 12` |
| `3` | `size = 4` (third width) | `size = 12` |

Formula: `cellSize = spanFull ? 12 : Math.floor(12 / columns)`

### 4.6 Configuration Example

```json
{
  "sections": [
    {
      "label": "Customer Information",
      "icon": "standard:contact",
      "defaultCollapsed": false,
      "columns": 2,
      "fields": [
        { "label": "First Name", "fieldName": "FirstName__c", "type": "text" },
        { "label": "Last Name", "fieldName": "LastName__c", "type": "text" },
        {
          "label": "Email Address",
          "fieldName": "Email__c",
          "type": "email",
          "spanFull": true
        },
        {
          "label": "Annual Revenue",
          "fieldName": "AnnualRevenue__c",
          "type": "currency",
          "typeAttributes": { "currencyCode": "EUR", "minimumFractionDigits": 2 }
        },
        {
          "label": "Date of Birth",
          "fieldName": "BirthDate__c",
          "type": "date",
          "typeAttributes": { "year": "numeric", "month": "long", "day": "2-digit" }
        }
      ]
    },
    {
      "columns": 1,
      "fields": [
        {
          "label": "Biography",
          "fieldName": "Bio__c",
          "type": "richtext"
        }
      ]
    },
    {
      "label": "Engagement Metrics",
      "icon": "standard:metrics",
      "defaultCollapsed": true,
      "columns": 2,
      "fields": [
        { "label": "Total Orders", "fieldName": "TotalOrders__c", "type": "number" },
        {
          "label": "Last Activity",
          "fieldName": "LastActivityDate__c",
          "type": "datetime",
          "typeAttributes": {
            "year": "numeric", "month": "short", "day": "2-digit",
            "hour": "2-digit", "minute": "2-digit"
          }
        },
        { "label": "Is Active", "fieldName": "IsActive__c", "type": "boolean" },
        { "label": "Website", "fieldName": "Website__c", "type": "url",
          "typeAttributes": { "label": "Visit Website", "target": "_blank" } }
      ]
    }
  ]
}
```

In this example:
- **Section 1** ("Customer Information") — collapsible, 2-column, with an email field spanning full width
- **Section 2** (no label) — non-collapsible, 1-column, always visible, contains a rich text biography field
- **Section 3** ("Engagement Metrics") — collapsible, starts collapsed, 2-column, with boolean and URL fields

---

## 5. Lightning App Builder Properties

### 5.1 Meta XML Target Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>66.0</apiVersion>
    <description>Data Cloud Query Result — Record Detail View</description>
    <isExposed>true</isExposed>
    <masterLabel>Data Cloud Query Record</masterLabel>

    <targets>
        <target>lightning__AppPage</target>
        <target>lightning__RecordPage</target>
        <target>lightning__HomePage</target>
        <target>lightning__UrlAddressable</target>
    </targets>

    <targetConfigs>
        <targetConfig targets="lightning__AppPage, lightning__HomePage, lightning__RecordPage">
            <property name="title"
                      type="String"
                      label="Card Title"
                      description="Optional. Leave blank to render without a card header."/>

            <property name="titleHelpText"
                      type="String"
                      label="Title Help Text"
                      description="Tooltip next to title. Only rendered when title is provided."/>

            <property name="subtitle"
                      type="String"
                      label="Subtitle"
                      placeholder="Appears below the title"
                      description="Only rendered when title is provided."/>

            <property name="iconName"
                      type="String"
                      label="Card Icon"
                      description="Optional SLDS icon name. Only rendered when title is provided."/>

            <property name="querySettingId"
                      type="String"
                      label="Query Setting Identifier"
                      description="DataCloudQuerySetting__mdt developer name"/>

            <property name="recordConfig"
                      type="String"
                      label="Record Layout Configuration (JSON)"
                      description="JSON defining sections, fields, data types, and layout"
                      placeholder='{"sections":[{"label":"Details","columns":2,"fields":[{"label":"Name","fieldName":"Name__c"}]}]}'/>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

### 5.2 Property Optionality Rules

| Property | Required | Behavior When Omitted |
|---|---|---|
| `title` | No | No card header rendered. Component renders sections directly without a `lightning-card` wrapper. |
| `iconName` | No | Card renders without an icon (only relevant when `title` is provided). |
| `titleHelpText` | No | No tooltip icon next to title. |
| `subtitle` | No | No subtitle text below the title. |
| `querySettingId` | **Yes** | Error state: "Query Setting Identifier is not configured." |
| `recordConfig` | **Yes** | Error state: "Record Layout Configuration is not configured." |

---

## 6. Data Fetching Architecture

### 6.1 Shared Pipeline

The component uses the **identical** data-fetching mechanism as `dataCloudQueryResultList` and `dataCloudQueryResultChart`:

```
dataCloudQueryResult
        │
        │  import { executeDataCloudQuery } from 'c/dataCloudQueryService'
        │
        ▼
dataCloudQueryService.js (shared module)
        │
        │  Step 1: submitDataCloudQuery(querySettingId, recordId)
        │  Step 2: Poll getDataCloudQueryStatus(querySettingId, queryId) — 500ms intervals, 90s timeout
        │  Step 3: getDataCloudQueryData(querySettingId, queryId, offset, pageSize)
        │
        ▼
DataCloudQueryServiceController.cls (Apex)
        │
        │  Reads DataCloudQuerySetting__mdt (Query__c, Dataspace__c, RecordBasedFilterConfig__c, etc.)
        │  Resolves record-based SQL parameters from current record context
        │
        ▼
DataCloudQueryServiceProvider.cls (Strategy Factory)
        │
        │  IDataCloudQueryProvider.executeQuerySql(query, params, dataspace, workloadName)
        │
        ├───────────────────────────┐
        ▼                           ▼
DataCloudCdpQueryService    DataCloudRestQueryService
(ConnectApi.CdpQuery)       (HTTP /ssot/query-sql)
```

No new Apex classes, no new service methods, no new custom metadata fields. The component is purely a new **visualization layer** on top of the existing infrastructure.

### 6.2 Data Flow Sequence

```
Admin (App Builder)              LWC Component                    Service Layer
       │                              │                               │
       │── configures recordConfig ──►│                               │
       │── configures querySettingId ►│                               │
       │                              │                               │
       │                    connectedCallback()                       │
       │                    parseRecordConfig()                       │
       │                              │                               │
       │                    renderedCallback() [once]                  │
       │                    loadInitialData()                          │
       │                              │                               │
       │                              │── executeDataCloudQuery() ───►│
       │                              │   (querySettingId, recordId)   │
       │                              │                               │
       │                              │               submitDataCloudQuery()
       │                              │               poll getDataCloudQueryStatus()
       │                              │               getDataCloudQueryData()
       │                              │                               │
       │                              │◄── { queryId, records[] } ────│
       │                              │                               │
       │                    buildViewModel()                           │
       │                    for each record in records[]:              │
       │                      for each section in config.sections:    │
       │                        for each field in section.fields:     │
       │                          resolve value from record           │
       │                          compute type flags                  │
       │                          compute cell size                   │
       │                              │                               │
       │                    Template renders renderedRecords[]         │
       │                              │                               │
  End User ◄── sees record detail ────│                               │
```

---

## 7. Multi-Record Rendering Strategy

### 7.1 Decision: Stacked Layout Over Navigation

When the query returns multiple records, **all records render vertically stacked** — one below the other, each applying the same section/field configuration to its own data.

**Rationale:**

- The primary use case is a single-record query result. Multi-record is the exception, not the rule.
- Navigation buttons (Previous/Next) add state management complexity (current index, boundary checks) for a rare case.
- Stacked rendering lets the user see all records at a glance without interaction — better for comparison.
- Eliminates navigation-related state properties (`currentRecordIndex`, `handleNextRecord`, `handlePreviousRecord`).

### 7.2 Visual Separator Between Records

When `renderedRecords.length > 1`, a visual separator (horizontal rule with SLDS styling) is rendered between consecutive records. The first record has no separator above it.

```
┌──── Record 1 ─────────────────────────────────────────────┐
│  ▼ Customer Information                                    │
│    First Name: John         Last Name: Doe                 │
│    Email: john@example.com                                 │
└────────────────────────────────────────────────────────────┘

───────────────────── (slds-border_top separator) ───────────

┌──── Record 2 ─────────────────────────────────────────────┐
│  ▼ Customer Information                                    │
│    First Name: Jane         Last Name: Smith               │
│    Email: jane@smith.com                                   │
└────────────────────────────────────────────────────────────┘
```

---

## 8. Section Rendering: Collapsible vs Static

### 8.1 Decision: Section Label Drives Collapse Behavior

The presence or absence of `label` on a section definition is the sole determinant of whether the section supports collapse/expand:

| Has `label` | Rendered As | Collapsible | `defaultCollapsed` | `icon` |
|---|---|---|---|---|
| Yes | `lightning-accordion-section` | Yes | Respected | Rendered in header |
| No | Plain `<div>` container | No — always visible | Ignored | Ignored |

This eliminates the need for a separate `collapsible` boolean property. The rule is intuitive: if there's no header, there's nothing to collapse.

### 8.2 Hybrid Rendering Approach

The template does **not** wrap everything in a single `lightning-accordion`. Instead, it iterates through sections and conditionally renders each one as either an accordion section or a plain div:

```
for:each={record.sections}
  │
  ├── [if section.hasLabel]
  │     lightning-accordion (allow-multiple-sections-open)
  │       └── lightning-accordion-section (label, icon)
  │             └── [fields-grid]
  │
  └── [if !section.hasLabel]
        div.slds-section (plain container)
          └── [fields-grid]
```

This allows collapsible and non-collapsible sections to be freely interleaved in any order within a single record layout.

### 8.3 Section Icon Behavior

The `icon` property on a section is rendered **only** when `label` is also present. When rendered, it appears to the left of the section header text within the `lightning-accordion-section`.

When `label` is absent, `icon` is ignored — there is no header to display it in.

---

## 9. Card Header Optionality

### 9.1 With Title: Card Layout

When `title` is provided, the component renders inside a `lightning-card`:

```
┌──────────────────────────────────────────────────────────────┐
│ 🔵 Data Cloud Record Details  ⓘ Tooltip           [↻]      │
│   Subtitle text here                                         │
│                                                              │
│  [sections and fields rendered here]                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- `iconName` → `lightning-card` `icon-name` attribute
- `title` → card title slot (with optional `lightning-helptext` for `titleHelpText`)
- `subtitle` → displayed below the title
- Refresh button → card actions slot

### 9.2 Without Title: Borderless Layout

When `title` is omitted (empty or not configured), the component renders **without** a `lightning-card`:

```
┌ · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·┐
:                                                            :
:  [sections and fields rendered directly]                   :
:                                                            :
└ · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·┘
```

No card border, no header, no icon, no refresh button. The sections render as bare content — useful when the component is placed inside another container or when the admin wants a seamless layout.

The `iconName`, `titleHelpText`, and `subtitle` properties are ignored when `title` is absent.

---

## 10. Template Rendering Structure

### 10.1 Overall Template Hierarchy

```
[if hasTitle]
  lightning-card (icon={iconName})
    ├── [slot: title] → {title} + lightning-helptext (if titleHelpText)
    ├── [slot: actions] → lightning-button-icon (refresh)
    └── [content-body]

[else]
  div (borderless container)
    └── [content-body]


[content-body] =
  ├── [if subtitle && hasTitle]
  │     div.slds-text-body_small → {subtitle}
  │
  ├── [if isLoading]
  │     lightning-spinner (variant="brand")
  │
  ├── [if hasError]
  │     div.slds-theme_error
  │       └── lightning-accordion → lightning-accordion-section (expandable error details)
  │
  └── [if showContent]
        ├── [if hasResults]
        │     for:each={renderedRecords} as record
        │       ├── [if !record.isFirst]
        │       │     div.slds-border_top.slds-m-vertical_medium (separator)
        │       │
        │       └── for:each={record.sections} as section
        │             ├── [if section.hasLabel]
        │             │     lightning-accordion (allow-multiple-sections-open, active-section-name)
        │             │       └── lightning-accordion-section (name, label, icon)
        │             │             └── [fields-grid]
        │             │
        │             └── [if !section.hasLabel]
        │                   div.slds-section__content
        │                     └── [fields-grid]
        │
        └── [if !hasResults]
              p.slds-text-align_center → {noDataMessage}
```

### 10.2 Fields Grid Structure

Each section (whether accordion or plain div) contains the same fields grid:

```
lightning-layout (multiple-rows="true", vertical-align="stretch")
  └── for:each={section.fields} as field
        lightning-layout-item (size={field.cellSize}, padding="around-small", key={field._key})
          └── div.slds-form-element.slds-form-element_stacked.slds-form-element_readonly
                ├── span.slds-form-element__label → {field.label}
                └── div.slds-form-element__control
                      └── [type-conditional rendering]
```

This structure mirrors the pattern already used in `dataCloudQueryResultListPopoverCell` (lines 26–69 of its template).

### 10.3 Type-Conditional Rendering Block

```
[if field.isText]       → lightning-formatted-text (value={field.value})
[if field.isNumber]     → lightning-formatted-number (value, format-style="decimal", typeAttributes)
[if field.isInteger]    → lightning-formatted-number (value, format-style="decimal")
[if field.isCurrency]   → lightning-formatted-number (value, format-style="currency", currencyCode, minimumFractionDigits)
[if field.isPercent]    → lightning-formatted-number (value, format-style="percent", typeAttributes)
[if field.isDate]       → lightning-formatted-date-time (value, year, month, day)
[if field.isDateTime]   → lightning-formatted-date-time (value, year, month, day, hour, minute, second)
[if field.isEmail]      → lightning-formatted-email (value)
[if field.isPhone]      → lightning-formatted-phone (value)
[if field.isUrl]        → lightning-formatted-url (value, label, target)
[if field.isBoolean]    → lightning-input (type="checkbox", checked={field.value}, disabled)
[if field.isRichText]   → lightning-formatted-rich-text (value)
[if field.isLocation]   → lightning-formatted-location (latitude, longitude)
```

Each field has exactly one boolean flag set to `true` — the rest are `false`. This ensures only one `lightning-formatted-*` component renders per field.

---

## 11. View Model Architecture

### 11.1 View Model Builder: `buildViewModel()`

The view model builder merges the parsed configuration (`parsedConfig.sections`) with the fetched data (`queryResults`) to produce the `renderedRecords` array used by the template.

**Processing pipeline:**

```
queryResults[]                parsedConfig.sections[]
       │                              │
       └──────────────┬───────────────┘
                      │
              buildViewModel()
                      │
         for each record in queryResults:
           buildSectionsForRecord(record, recordIndex)
                      │
              for each section in parsedConfig.sections:
                ├── compute hasLabel, isCollapsed
                │
                └── for each field in section.fields:
                      ├── resolveFieldValue(record, field.fieldName)
                      ├── computeTypeFlags(field.type)
                      └── computeCellSize(section.columns, field.spanFull)
                      │
                      ▼
              renderedRecords[]
```

### 11.2 View Model Data Structure

```javascript
renderedRecords = [
  {
    _key: "record-0",
    isFirst: true,
    sections: [
      {
        _key: "record-0-section-0",
        hasLabel: true,
        label: "Customer Information",
        icon: "standard:contact",
        isCollapsed: false,
        activeSectionName: "record-0-section-0",
        fields: [
          {
            _key: "record-0-section-0-field-0",
            label: "First Name",
            value: "John",
            cellSize: 6,
            isText: true,
            isNumber: false,
            isInteger: false,
            isCurrency: false,
            isPercent: false,
            isDate: false,
            isDateTime: false,
            isEmail: false,
            isPhone: false,
            isUrl: false,
            isBoolean: false,
            isRichText: false,
            isLocation: false,
            typeAttributes: {}
          },
          ...
        ]
      },
      {
        _key: "record-0-section-1",
        hasLabel: false,
        label: null,
        icon: null,
        isCollapsed: false,
        fields: [ ... ]
      }
    ]
  },
  {
    _key: "record-1",
    isFirst: false,
    sections: [ ... ]
  }
]
```

### 11.3 Key Generation Strategy

LWC's `for:each` requires a unique `key` attribute on each iterated element. Keys are generated as composite strings to ensure uniqueness across the nested iteration:

| Level | Key Pattern | Example |
|---|---|---|
| Record | `record-{recordIndex}` | `record-0` |
| Section | `record-{recordIndex}-section-{sectionIndex}` | `record-0-section-2` |
| Field | `record-{recordIndex}-section-{sectionIndex}-field-{fieldIndex}` | `record-0-section-2-field-3` |

This guarantees uniqueness even when the same section/field configuration is applied across multiple records.

---

## 12. Component Class Design

### 12.1 Class Diagram

```
dataCloudQueryResult extends LightningElement
│
├── ─── @api Properties (Admin-Configured) ─────────────────────
│   ├── title: String                        ← optional, no default
│   ├── iconName: String                     ← optional, no default
│   ├── querySettingId: String               ← required
│   ├── recordConfig: String                 ← required (JSON)
│   ├── titleHelpText: String                ← optional
│   ├── subtitle: String                     ← optional
│   └── recordId: String                     ← auto-injected on record pages
│
├── ─── Local State Properties ──────────────────────────────────
│   ├── parsedConfig: Object                 ← parsed JSON
│   ├── queryResults: Array                  ← raw query result records
│   ├── renderedRecords: Array               ← hydrated view model
│   ├── isLoading: Boolean = false
│   ├── error: String = null
│   └── initialRender: Boolean = true
│
├── ─── Lifecycle Hooks ─────────────────────────────────────────
│   ├── connectedCallback()                  → parseRecordConfig()
│   └── renderedCallback()                   → loadInitialData() [guarded, one-time]
│
├── ─── Data Methods ────────────────────────────────────────────
│   ├── parseRecordConfig()                  → validates JSON, sets parsedConfig
│   ├── loadInitialData()                    → executeDataCloudQuery(), buildViewModel()
│   └── refreshData() [@api]                 → re-runs loadInitialData()
│
├── ─── View Model Methods ──────────────────────────────────────
│   ├── buildViewModel()                     → iterates all records × config → renderedRecords
│   ├── buildSectionsForRecord(record, idx)  → produces sections[] for one record
│   ├── resolveFieldValue(record, fieldName) → direct property lookup from record
│   ├── computeTypeFlags(type)               → returns { isText, isNumber, ... } object
│   └── computeCellSize(columns, spanFull)   → returns 4 | 6 | 12
│
├── ─── Error Handling ──────────────────────────────────────────
│   └── handleError(error)                   → sets this.error from error.body or error.message
│
└── ─── Getters ─────────────────────────────────────────────────
    ├── get hasTitle()                       → Boolean(this.title)
    ├── get hasResults()                     → renderedRecords && renderedRecords.length > 0
    ├── get hasError()                       → this.error != null
    ├── get showContent()                    → !this.isLoading && !this.hasError
    ├── get noDataMessage()                  → custom label DCQR_Data_Not_Found
    └── get genericErrorMessage()            → custom label DCQR_Generic_Error_Message
```

### 12.2 Lifecycle Hooks

**`connectedCallback()`**

Parses the `recordConfig` JSON string. This runs before rendering so the configuration is available before the first paint. If parsing fails, `error` is set and no data fetch occurs.

```
connectedCallback()
  └── parseRecordConfig()
        ├── [success] → parsedConfig = parsed JSON object
        └── [failure] → error = "Invalid record configuration JSON: {details}"
```

**`renderedCallback()`** (one-time, guarded)

Triggers data loading after the first render. Guarded by `initialRender` flag to prevent repeated fetches (same pattern as `dataCloudQueryResultList`).

```
renderedCallback()
  └── [if initialRender]
        initialRender = false
        loadInitialData()
          ├── isLoading = true
          ├── executeDataCloudQuery(querySettingId, recordId, 100)
          ├── queryResults = result.records
          ├── buildViewModel()
          ├── isLoading = false
          └── [on error] → handleError(error), isLoading = false
```

---

## 13. Error, Loading, and Empty States

The component follows the identical state display pattern used by `dataCloudQueryResultList` and `dataCloudQueryResultChart`:

| State | Rendering |
|---|---|
| **Loading** | `lightning-spinner` (variant="brand") in the content area |
| **Error** | `slds-theme_error` container with `lightning-accordion` → `lightning-accordion-section` showing generic error message as label and detailed error as expandable content |
| **No Data** | Centered text: `{noDataMessage}` (custom label `DCQR_Data_Not_Found`) |
| **No Config** | Error state with specific message about missing configuration |
| **Success** | Rendered sections and fields |

Error messages:

| Condition | Message |
|---|---|
| `querySettingId` not configured | "Query Setting Identifier is not configured. Please set the Query Setting Id in the component properties." |
| `recordConfig` not configured | "Record Layout Configuration is not configured. Please set the Record Config in the component properties." |
| Invalid `recordConfig` JSON | "Invalid record configuration JSON: {parse error details}" |
| Apex/service error | Extracted from `error.body.message` (Apex) or `error.message` (JS) |

---

## 14. Consistency with Existing Components

| Aspect | List Component | Chart Component | Record Component (NEW) |
|---|---|---|---|
| **Config property** | `columnConfig` (JSON) | `chartConfig` (JSON) | `recordConfig` (JSON) |
| **Config describes** | Datatable columns | Chart.js structure + data map | Sections → fields |
| **Data fetch** | `executeDataCloudQuery()` | `executeDataCloudQuery()` | `executeDataCloudQuery()` |
| **Query setting** | `querySettingId` | `querySettingId` | `querySettingId` |
| **Card structure** | `lightning-card` (always) | `lightning-card` (always) | `lightning-card` (optional, driven by `title`) |
| **Title** | Required, default provided | Required, default provided | **Optional, no default** |
| **Icon** | Required, default provided | N/A (no icon) | **Optional, no default** |
| **Error pattern** | Error accordion + `genericErrorMessage` | Same | Same |
| **Loading** | `lightning-spinner` | Same | Same |
| **No-data** | `noDataMessage` label | Same | Same |
| **Custom labels** | `DCQR_Data_Not_Found`, `DCQR_Generic_Error_Message`, `DCQR_Load_More`, `DCQR_Showing_Record_Count` | Reuses same | Reuses `DCQR_Data_Not_Found`, `DCQR_Generic_Error_Message` |
| **Parse timing** | `renderedCallback` (once) | `connectedCallback` (parse) + fetch | `connectedCallback` (parse) + `renderedCallback` (fetch) |
| **Refresh** | `@api refreshData()` | `@api refreshData()` | `@api refreshData()` |
| **Record page support** | `recordId` auto-injected | `recordId` auto-injected | `recordId` auto-injected |
| **Page targets** | App, Record, Home, URL-addressable | Same | Same |

---

## 15. Visual Rendering Examples

### 15.1 Single Record with Mixed Sections

```
┌──────────────────────────────────────────────────────────────┐
│ 🔵 Data Cloud Customer Profile  ⓘ Unified profile    [↻]   │
│   Data sourced from Data Cloud unified individual            │
│                                                              │
│ ▼ Customer Information                                       │
│ ┌───────────────────────────┬────────────────────────────┐   │
│ │ First Name                │ Last Name                  │   │
│ │ John                      │ Doe                        │   │
│ ├───────────────────────────┴────────────────────────────┤   │
│ │ Email Address                              (spanFull)  │   │
│ │ john@example.com  ← (clickable email link)             │   │
│ ├───────────────────────────┬────────────────────────────┤   │
│ │ Annual Revenue            │ Date of Birth              │   │
│ │ €150,000.00               │ January 15, 1985           │   │
│ └───────────────────────────┴────────────────────────────┘   │
│                                                              │
│ ── (no label section — always visible, no collapse) ──────── │
│ ┌────────────────────────────────────────────────────────┐   │
│ │ Biography                                  (1-column)  │   │
│ │ Senior Software Engineer with 15 years of experience   │   │
│ │ in enterprise systems...   ← (rich text rendered)      │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                              │
│ ► Engagement Metrics  (collapsed by default, click to open)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 15.2 Multiple Records Stacked

```
┌──────────────────────────────────────────────────────────────┐
│ 🔵 Related Contacts                                   [↻]   │
│                                                              │
│  ▼ Contact Details                                           │
│  ┌──────────────────────────┬─────────────────────────────┐  │
│  │ Name                     │ Email                       │  │
│  │ John Doe                 │ john@example.com            │  │
│  ├──────────────────────────┼─────────────────────────────┤  │
│  │ Phone                    │ Role                        │  │
│  │ +1 (555) 123-4567        │ Primary Contact             │  │
│  └──────────────────────────┴─────────────────────────────┘  │
│                                                              │
│  ─────────────────── (visual separator) ──────────────────── │
│                                                              │
│  ▼ Contact Details                                           │
│  ┌──────────────────────────┬─────────────────────────────┐  │
│  │ Name                     │ Email                       │  │
│  │ Jane Smith               │ jane@company.com            │  │
│  ├──────────────────────────┼─────────────────────────────┤  │
│  │ Phone                    │ Role                        │  │
│  │ +1 (555) 987-6543        │ Technical Lead              │  │
│  └──────────────────────────┴─────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 15.3 No Card Header (Title Omitted)

```
  ▼ Customer Information
  ┌──────────────────────────┬─────────────────────────────┐
  │ First Name               │ Last Name                   │
  │ John                     │ Doe                         │
  └──────────────────────────┴─────────────────────────────┘

  ── (plain section — no label, no collapse) ──────────────
  ┌────────────────────────────────────────────────────────┐
  │ Email Address                                          │
  │ john@example.com                                       │
  └────────────────────────────────────────────────────────┘
```

No border, no card header, no icon. Sections render directly, allowing seamless embedding within other page layouts.

---

## 16. Reuse of Existing Patterns

### Type-Rendering Pattern from `dataCloudQueryResultListPopoverCell`

The popover cell component already solves the "render a field value based on its data type" problem. The record detail component reuses the **exact same pattern**:

- Boolean type-discriminator flags (`isText`, `isNumber`, `isCurrency`, etc.) on each field item
- Conditional `if:true` blocks selecting the appropriate `lightning-formatted-*` component
- `typeAttributes` passthrough for formatting customization
- `cellSize` computed from layout and `spanFull` flag

The popover cell handles 6 types (`text`, `number`, `integer`, `currency`, `date`, `datetime`, `richtext`). The record detail component extends this to 13 types by adding `email`, `phone`, `url`, `boolean`, `percent`, `location`.

### Shared Data Fetching via `dataCloudQueryService`

Identical import and usage:

```javascript
import { executeDataCloudQuery } from 'c/dataCloudQueryService';

const result = await executeDataCloudQuery(this.querySettingId, this.recordId, 100);
this.queryResults = result.records || [];
```

Same function, same parameters, same return shape.

### Error Display Pattern

Identical to both existing components — `slds-theme_error` div with `lightning-accordion` for expandable error details.

### Custom Label Reuse

Reuses existing labels `DCQR_Data_Not_Found` and `DCQR_Generic_Error_Message` — no new custom labels required.

---

## 17. Salesforce Standard Components Used

The component is built entirely from standard Salesforce base components:

| Component | Purpose |
|---|---|
| `lightning-card` | Card container with header, icon, and actions (when title provided) |
| `lightning-accordion` | Collapsible section container |
| `lightning-accordion-section` | Individual collapsible section with label and icon |
| `lightning-layout` | Responsive multi-column grid container |
| `lightning-layout-item` | Grid cell with configurable size (4, 6, or 12 out of 12) |
| `lightning-spinner` | Loading state indicator |
| `lightning-helptext` | Tooltip next to title |
| `lightning-button-icon` | Refresh button |
| `lightning-formatted-text` | Text field rendering |
| `lightning-formatted-number` | Number, currency, and percent field rendering |
| `lightning-formatted-date-time` | Date and datetime field rendering |
| `lightning-formatted-email` | Clickable email link rendering |
| `lightning-formatted-phone` | Phone number rendering |
| `lightning-formatted-url` | Clickable URL rendering |
| `lightning-formatted-rich-text` | Rich text / HTML rendering |
| `lightning-formatted-location` | Geolocation rendering |
| `lightning-input` (checkbox, disabled) | Boolean field rendering |

No external libraries. No static resources. No custom CSS frameworks.

---

## 18. Future Extensibility

### 18a. Extract Shared Field Renderer Component

If the type-rendering conditional block grows beyond the current 13 types, extract a `dataCloudQueryResultField` child component that accepts `{value, type, typeAttributes}` and renders the appropriate `lightning-formatted-*` output. This would be reusable by:
- `dataCloudQueryResult` (record detail view)
- `dataCloudQueryResultListPopoverCell` (popover in list view)
- Any future component that needs type-aware field rendering

### 18b. Conditional Field Visibility

Add an optional `visibleWhen` property to field definitions as a **structured declarative condition** — not an expression string, since `eval()` and `new Function()` are blocked by Lightning Web Security.

Conditions would be structured JSON with a fixed set of operators (`isNotNull`, `isNull`, `equals`, `notEquals`, `in`, `notIn`) evaluated via a hardcoded `switch` — no dynamic code generation, no injection surface:

```json
{ "label": "Fax", "fieldName": "Fax__c", "type": "phone",
  "visibleWhen": { "source": "data", "fieldName": "Fax__c", "operator": "isNotNull" } }
```

Two condition sources are envisioned:
- **`"source": "data"`** — evaluates against the current record's field values (client-side, no Apex call).
- **`"source": "permission"`** — evaluates against the current user's custom permissions via a new cacheable Apex method using `FeatureManagement.checkPermission()`. Permission names would be extracted from the config at parse time and fetched in a single round-trip.

Compound conditions (`AND`/`OR`) would use a recursive evaluator over nested condition arrays — same pattern as the filter logic evaluator in the FilterSort architecture.

### 18c. Field Groups / Compound Fields

Support grouping multiple fields into a single visual cell (e.g., City + State + Zip on one line), similar to Salesforce compound address fields. Would require a `group` wrapper in the field definition schema.

---

## 19. Decision Log

| # | Decision | Rationale |
|---|---|---|
| 1 | Shared data-fetching pipeline | Reuses proven `dataCloudQueryService` module, `DataCloudQueryServiceController`, and provider pattern. No new Apex code required for data layer. |
| 2 | Single `recordConfig` JSON property | Follows established pattern of `columnConfig` (list) and `chartConfig` (chart). Hierarchical sections → fields structure cannot be expressed as flat App Builder properties. |
| 3 | Section label drives collapse behavior | Eliminates need for a separate `collapsible` property. Intuitive rule: no header means nothing to collapse. Reduces configuration surface. |
| 4 | Optional card header (title-driven) | Provides flexibility for embedding in other containers or standalone use. When title is absent, component produces a borderless content block. |
| 5 | Multi-record stacking over navigation | Primary use case is single-record display. Navigation adds state management complexity for a rare case. Stacking lets users see all records at a glance. |
| 6 | Type system extending popover cell | Proven pattern for type-conditional rendering. Adds `email`, `phone`, `url`, `boolean`, `percent`, `location` to cover standard record page field types. All native LWC base components. |
| 7 | Standard `lightning-formatted-*` components | No custom rendering needed. Native accessibility, localization, and SLDS styling. Zero maintenance burden on type rendering. |
| 8 | SLDS form element stacked layout | Matches Salesforce standard record page visual language. `slds-form-element_stacked` + `slds-form-element_readonly` produces label-above-value layout matching user expectations. |
| 9 | `lightning-layout` for column grid | Built-in responsive grid with 12-column system. `size` attribute directly maps to column count (12/6/4 for 1/2/3 columns). `spanFull` overrides to 12 regardless. |
| 10 | Composite key generation | `record-{i}-section-{j}-field-{k}` ensures uniqueness across nested iterations. Required by LWC `for:each` directive. |
| 11 | Parse config in `connectedCallback`, fetch in `renderedCallback` | Config parsing has no DOM dependency — safe in `connectedCallback`. Data fetch uses `renderedCallback` with one-time guard — consistent with list and chart components. |
| 12 | Reuse existing custom labels | `DCQR_Data_Not_Found` and `DCQR_Generic_Error_Message` already exist and are appropriate. No new labels required. |
| 13 | No pagination | Record detail view typically shows 1–5 records. No need for Load More or Next/Prev. All returned records are rendered. `pageSize` passed to `executeDataCloudQuery` is set to a reasonable max (100). |
