# DataCloudQueryResultList — Filter & Sort Architecture Design

> **Date:** June 30, 2026
> **Author:** Architecture Review
> **Status:** Design Proposal (Revised v2)
> **Component:** `dataCloudQueryResultList` (sf-datacloud-query-components)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Architecture Decision: Client-Side vs Server-Side](#3-architecture-decision-client-side-vs-server-side)
   - 3.1 [What Server-Side Costs Per Interaction](#31-what-server-side-costs-per-interaction)
   - 3.2 [What Client-Side Costs Per Interaction](#32-what-client-side-costs-per-interaction)
   - 3.3 [Decision: Client-Side with Threshold Gate](#33-decision-client-side-with-threshold-gate)
4. [External Library Evaluation](#4-external-library-evaluation)
   - 4.1 [Performance at 5,000–10,000 Records](#41-performance-at-500010000-records)
   - 4.2 [Risks of External Libraries in LWC](#42-risks-of-external-libraries-in-lwc)
   - 4.3 [Decision: Native JavaScript](#43-decision-native-javascript)
5. [Data Architecture and Pagination](#5-data-architecture-and-pagination)
   - 5.1 [Lazy Pagination (Default)](#51-lazy-pagination-default)
   - 5.2 [Filter/Sort Mode](#52-filtersort-mode)
   - 5.3 [Threshold Gate: All or Nothing](#53-threshold-gate-all-or-nothing)
   - 5.4 [Unified Pagination Logic](#54-unified-pagination-logic)
6. [Pagination UI](#6-pagination-ui)
   - 6.1 [Next/Previous Controls](#61-nextprevious-controls)
   - 6.2 [Record Index Display](#62-record-index-display)
7. [Column-Level Sorting](#7-column-level-sorting)
   - 7.1 [Built-In lightning-datatable Sort](#71-built-in-lightning-datatable-sort)
   - 7.2 [Sort Triggers Full Fetch](#72-sort-triggers-full-fetch)
   - 7.3 [Sort Handler](#73-sort-handler)
8. [Filter Popup Design](#8-filter-popup-design)
   - 8.1 [Complete UI Layout](#81-complete-ui-layout)
   - 8.2 [Search Bar](#82-search-bar)
   - 8.3 [Filter Section](#83-filter-section)
   - 8.4 [Active Filter Indicators](#84-active-filter-indicators)
9. [Filter Types and Operators](#9-filter-types-and-operators)
   - 9.1 [Operator Matrix by Data Type](#91-operator-matrix-by-data-type)
   - 9.2 [Type-Appropriate Value Inputs](#92-type-appropriate-value-inputs)
   - 9.3 [Date Range: Relative Periods](#93-date-range-relative-periods)
10. [Condition Logic (AND/OR)](#10-condition-logic-andor)
    - 10.1 [Progressive Disclosure](#101-progressive-disclosure)
    - 10.2 [Simple Mode (Default)](#102-simple-mode-default)
    - 10.3 [Advanced Mode (Custom Logic)](#103-advanced-mode-custom-logic)
    - 10.4 [Validation](#104-validation)
    - 10.5 [Evaluation Engine](#105-evaluation-engine)
11. [Data Pipeline](#11-data-pipeline)
    - 11.1 [Filter Evaluation](#111-filter-evaluation)
    - 11.2 [Sort](#112-sort)
    - 11.3 [Unified Pipeline](#113-unified-pipeline)
12. [Refresh Behavior](#12-refresh-behavior)
    - 12.1 [Refresh Flow](#121-refresh-flow)
    - 12.2 [Over-Limit After Refresh: Deactivate, Don't Destroy](#122-over-limit-after-refresh-deactivate-dont-destroy)
    - 12.3 [Paused State UI](#123-paused-state-ui)
    - 12.4 [Refresh Handler](#124-refresh-handler)
13. [Component Architecture](#13-component-architecture)
    - 13.1 [Component Hierarchy](#131-component-hierarchy)
    - 13.2 [Parent-Child Contract](#132-parent-child-contract)
    - 13.3 [Event Payload](#133-event-payload)
    - 13.4 [Parent Handler](#134-parent-handler)
14. [Edge Cases and State Transitions](#14-edge-cases-and-state-transitions)
15. [Column Configuration Schema](#15-column-configuration-schema)
16. [Salesforce Standard Components Used](#16-salesforce-standard-components-used)
17. [Performance Considerations](#17-performance-considerations)
18. [Decision Log](#18-decision-log)

---

## 1. Executive Summary

This document defines the architecture for adding user-level filtering and sorting to the `dataCloudQueryResultList` Lightning Web Component. The solution uses **client-side filtering and sorting** with **native JavaScript** (no external libraries), combining **column-header sorting** (via `lightning-datatable` built-in `onsort`) with a **dedicated filter popup** and a **quick search bar**, built entirely from **standard Salesforce base components**.

Key design decisions:

- **Client-side processing** over server-side to avoid the latency of Data Cloud's async query pipeline on every filter interaction.
- **No external libraries** — native `Array.filter()` and `Array.sort()` are sufficient for datasets up to 10,000 records.
- **Column-header sorting** — uses `lightning-datatable` built-in `onsort` event for single-click sort. This is the universal datatable interaction pattern users expect.
- **Separate filter popup** — structured filters with type-appropriate operators, AND/OR condition logic via progressive disclosure (simple toggle by default, advanced typed expression on demand).
- **Quick search bar** — text search across filterable text columns, complementary to structured filters.
- **Lazy pagination with Next/Previous controls** — pages are fetched from the server on demand during browsing. The full dataset is only fetched when the user first sorts, searches, or applies filters.
- **Threshold gate** — sorting, filtering, and search all require complete data or are rejected. No partial processing on incomplete datasets.
- **Preserve filter configuration on refresh** — if the dataset exceeds the threshold after refresh, filters and sort are deactivated (paused) but the user's configuration is preserved for re-adjustment.

---

## 2. Problem Statement

The `dataCloudQueryResultList` component displays Data Cloud query results in a `lightning-datatable`. Currently, users cannot filter or sort the displayed data. The component fetches data via an asynchronous pipeline:

```
submitDataCloudQuery → poll getDataCloudQueryStatus (500ms intervals, up to 90s) → getDataCloudQueryData
```

This pipeline is inherently expensive. Any filtering/sorting solution must account for this latency and avoid triggering new query jobs on every user interaction.

---

## 3. Architecture Decision: Client-Side vs Server-Side

### 3.1 What Server-Side Costs Per Interaction

Every filter or sort change would trigger the full async query pipeline:

```
User clicks filter
  → submitDataCloudQuery (Apex → Data Cloud API)
  → Poll getDataCloudQueryStatus every 500ms (up to 90s timeout)
  → getDataCloudQueryData
  → Re-render
```

Minimum **1–5 seconds** per interaction with a loading spinner. Additional costs:

- Dynamic SQL injection into stored text area queries — fragile, error-prone, security risk
- Extending `DataCloudQuerySetting__mdt` metadata structure for user-filter definitions
- New Apex logic to parse, validate, and safely inject WHERE/ORDER BY clauses
- Handling combinatorial complexity of user filters + existing `RecordBasedFilterConfig__c` parameters
- Every filter change burns a Data Cloud API query job (potential rate limits, compute costs)

### 3.2 What Client-Side Costs Per Interaction

```
User clicks column header to sort
  → Array.sort() on in-memory data
  → Re-render current page

User clicks Apply in filter popup
  → Array.filter() on in-memory data
  → Re-render page 1 of results
```

**< 50ms** for 10,000 records. No spinner, no server round trip after the initial data fetch.

### 3.3 Decision: Client-Side with Threshold Gate

**Client-side filtering and sorting** is the chosen approach.

A configurable threshold (`MAX_FILTERABLE_ROWS`, default 10,000) gates the behavior. If the query returns more rows than the threshold, filter/sort functionality is rejected with an informational message. The rule is absolute: **filter/sort requires complete data or it doesn't happen.** No partial processing on incomplete datasets, as this would produce incorrect and misleading results.

---

## 4. External Library Evaluation

### 4.1 Performance at 5,000–10,000 Records

| Operation | Native JS (Array methods) | Indexed Library (mega-collection) |
|---|---|---|
| `Array.sort()` | ~46ms | ~1ms (indexed), ~6ms (non-indexed) |
| `Array.filter()` (single pass) | ~2ms | ~0.2ms |
| `Array.filter()` (20 repeated) | ~40ms | ~2.5ms |
| Text search (full scan) | ~15–30ms | ~0.5ms |

Native JS sort/filter at 10,000 records is already fast enough for discrete user actions (clicking a column header or clicking Apply). The difference between 46ms and 1ms is imperceptible for a button-click interaction.

### 4.2 Risks of External Libraries in LWC

| Concern | Impact |
|---|---|
| Must be bundled as a Static Resource | Additional build step, no npm workflow |
| Lightning Web Security (LWS) sandbox | Library runs in isolated sandbox; no direct `window` access; requires compatibility testing |
| No Salesforce support | Salesforce explicitly states: *"Salesforce doesn't provide support for third-party JavaScript libraries"* |
| Library maturity risk | Smaller libraries may have limited community support |
| Bundle size overhead | Extra static resource to manage and deploy |
| Maintenance burden | Must re-test on every Salesforce release for LWS compatibility |

### 4.3 Decision: Native JavaScript

No external library. Native `Array.filter()` and `Array.sort()` provide sufficient performance for the target dataset sizes. If profiling reveals a bottleneck in the future, an indexed library can be introduced as a targeted optimization.

---

## 5. Data Architecture and Pagination

The component does not use an explicit mode flag. Instead, the pagination source is **derived from current state** — whether filters, sort, or search are active determines which data array is used and how pages are fetched.

### 5.1 Lazy Pagination (Default)

When no filters, sort, or search are applied, pages are fetched from the server **on demand** using the existing `queryId`. Records are accumulated in `_masterRecords` as a contiguous prefix:

```
Page 1 → _masterRecords has 0 records → fetch records 0–19 from server → display
Page 2 → _masterRecords has 20 records → fetch records 20–39 → append → display
Page 3 → _masterRecords has 40 records → fetch records 40–59 → append → display
Back to Page 1 → records 0–19 already in _masterRecords → display locally (no fetch)
```

With strict Next/Previous navigation, records are always fetched sequentially. `_masterRecords` is always a contiguous prefix of the full dataset.

### 5.2 Filter/Sort Mode

When the user triggers any client-side processing (column sort, search, or filter Apply):

1. **Threshold check**: If `totalRowCount > MAX_FILTERABLE_ROWS`, reject the action with an informational message. Do not process.
2. **Full fetch**: If within the threshold, fetch all remaining records (reusing the existing `queryId`). No new Data Cloud query is submitted — only data retrieval.
3. **Process**: Apply search, filters, and sort to the complete `_masterRecords` → produce `_processedRecords`.
4. **Paginate**: Display page 1 of `_processedRecords`. All subsequent page navigation is instant (local).

### 5.3 Threshold Gate: All or Nothing

The threshold gate enforces data correctness for all client-side processing operations:

```
User triggers sort, search, or filter Apply
  │
  ├── totalRowCount ≤ MAX_FILTERABLE_ROWS?
  │     │
  │     ├── YES → fetch all remaining records → process → paginate locally
  │     │
  │     └── NO  → show message: "Dataset too large for this operation
  │                (X records). Maximum allowed: Y."
  │                → do not process → action is rejected
```

No partial results. No sorting an incomplete dataset. Either the component has everything and can process it correctly, or it rejects the action.

### 5.4 Unified Pagination Logic

A single pagination method handles both cases without a mode flag:

```javascript
async getPageRecords(pageNumber) {
    const start = (pageNumber - 1) * this.pageSize;
    const end = Math.min(start + this.pageSize, this.totalDisplayCount);
    const source = this.hasActiveProcessing
        ? this._processedRecords
        : this._masterRecords;

    // If source doesn't have enough records yet, fetch from server
    if (source.length < end && source.length < this.totalRows) {
        await this.fetchRecordsUpTo(end);
    }

    return source.slice(start, end);
}

get totalDisplayCount() {
    return this.hasActiveProcessing
        ? this._processedRecords.length
        : this.totalRows;
}

get hasActiveProcessing() {
    return this._sortedBy
        || this._searchTerm
        || (this._activeFilters && this._activeFilters.length > 0);
}
```

When any processing is active, `_processedRecords` is always the complete result (because the first sort/search/filter ensured full fetch). The `source.length < end` check never triggers a server fetch in that branch.

When nothing is active, `_masterRecords` grows lazily. The check triggers server fetches only when the user navigates beyond what's already loaded.

---

## 6. Pagination UI

### 6.1 Next/Previous Controls

The datatable always renders exactly one page of rows — consistent rendering cost regardless of position in the dataset.

```
┌──────────────────────────────────────────────────────────────────┐
│ [ ◀ First ] [ ◂ Prev ]  Page 3 of 50  [ Next ▸ ] [ Last ▶ ]   │
│                     Showing 41–60 of 1,000                      │
└──────────────────────────────────────────────────────────────────┘
```

Controls:

| Button | Behavior | Disabled When |
|---|---|---|
| **First** | Navigate to page 1 | Already on page 1 |
| **Prev** | Navigate to previous page | Already on page 1 |
| **Next** | Navigate to next page | Already on last page |
| **Last** | Navigate to last page (triggers full fetch if not all data is local) | Already on last page |

### 6.2 Record Index Display

Always show the current record range and total:

| State | Display |
|---|---|
| No filters/sort | `Showing 41–60 of 1,000` |
| Filters and/or sort active | `Showing 41–60 of 325 filtered (1,000 total)` |
| Filters paused (over limit) | `Showing 41–60 of 12,000` |

Total page count is computed from `totalDisplayCount / pageSize`. When filters are active, `totalDisplayCount` is `_processedRecords.length`.

---

## 7. Column-Level Sorting

### 7.1 Built-In lightning-datatable Sort

Sorting uses the `lightning-datatable` built-in `onsort` event — the standard, universal datatable interaction. Users click a column header, the sort arrow toggles, and the data reorders. This is a one-click interaction that matches every Salesforce list view, related list, and data table in the ecosystem.

Columns are configured as sortable via the existing `columnConfig` JSON by setting `sortable: true`:

```json
[
  { "label": "Account Name", "fieldName": "Name__c",      "sortable": true, "filterable": true },
  { "label": "Revenue",      "fieldName": "Revenue__c",   "type": "currency", "sortable": true, "filterable": true },
  { "label": "Close Date",   "fieldName": "CloseDate__c", "type": "date",     "sortable": true, "filterable": true },
  { "label": "Description",  "fieldName": "Description__c" }
]
```

The datatable renders sort arrows in the column headers automatically. Clicking a column header sorts ascending; clicking again sorts descending.

### 7.2 Sort Triggers Full Fetch

Because sorting an incomplete dataset produces incorrect results (the actual highest value may be on an unfetched page), the first column-header sort click triggers a full data fetch — subject to the threshold gate.

```
User clicks column header to sort
  │
  ├── Full dataset already loaded?
  │     │
  │     ├── YES → sort _masterRecords immediately → display page 1 of sorted results
  │     │
  │     └── NO → totalRowCount ≤ MAX_FILTERABLE_ROWS?
  │               │
  │               ├── YES → show spinner → fetch remaining records → sort → display
  │               │         (one-time cost; subsequent sort clicks are instant)
  │               │
  │               └── NO → show message: "Dataset too large for sorting (X records)."
  │                        → do not sort → column header sort is disabled
```

After the first sort loads the full dataset, all subsequent sort interactions (clicking different column headers, toggling direction) are **instant** — no network cost, just `Array.sort()` on in-memory data.

### 7.3 Sort Handler

```javascript
async handleSort(event) {
    const { fieldName, sortDirection } = event.detail;

    // Threshold check
    if (this.totalRows > this.maxFilterableRows) {
        this.showThresholdError();
        return;
    }

    this.isLoading = true;

    try {
        // Ensure full dataset is loaded
        if (!this._fullDatasetLoaded) {
            await this.fetchRemainingRecords();
            this._fullDatasetLoaded = true;
        }

        this._sortedBy = fieldName;
        this._sortDirection = sortDirection;
        this.applyAllProcessing();

    } catch (error) {
        this.handleError(error);
    } finally {
        this.isLoading = false;
    }
}
```

The sort state (`_sortedBy`, `_sortDirection`) is maintained by the parent and passed back to `lightning-datatable` via its `sorted-by` and `sorted-direction` attributes so the column header arrows reflect the current sort.

---

## 8. Filter Popup Design

The popup is dedicated to **filtering only**. Sorting is handled at column level (Section 7).

### 8.1 Complete UI Layout

Full page layout with popup collapsed:

```
┌──────────────────────────────────────────────────────────────────────┐
│  lightning-card                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Title             [🔍 Search...        ] [⊞ Filter] [↻]     │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  Active: [1. Status = Active ✕] [2. Revenue > 50K ✕]  [Clear]│  │
│  ├────────────┬──────────┬───────────┬───────────────────────────┤  │
│  │ Name    ↕  │ Status ↕ │ Revenue ↕ │ Close Date  ↕            │  │
│  │ Acme Corp  │ Active   │ $75,000   │ 2026-03-15               │  │
│  │ Beta Inc   │ Active   │ $52,000   │ 2026-06-01               │  │
│  │ ...        │ ...      │ ...       │ ...                      │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │ [◀ First] [◂ Prev]  Page 1 of 17  [Next ▸] [Last ▶]         │  │
│  │              Showing 1–20 of 325 filtered (1,000 total)       │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

Note: `↕` in column headers indicates `sortable: true` columns with built-in `lightning-datatable` sort arrows.

Full page layout with popup expanded:

```
┌──────────────────────────────────────────────────────────────────────┐
│  lightning-card                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Title             [🔍 Search...        ] [⊞ Filter] [↻]     │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  ┌─ Filters (collapsible section) ────────────────────────┐   │  │
│  │  │                                                        │   │  │
│  │  │  Match: (●) All conditions  (○) Any condition          │   │  │
│  │  │                          [ Use Custom Logic ]          │   │  │
│  │  │                                                        │   │  │
│  │  │  1. [Status  ▾] [equals       ▾] [Active ▾]      [✕]  │   │  │
│  │  │  2. [Revenue ▾] [greater than ▾] [50000   ]      [✕]  │   │  │
│  │  │  3. [Name    ▾] [contains     ▾] [Acme    ]      [✕]  │   │  │
│  │  │                                                        │   │  │
│  │  │  [+ Add Filter]                                        │   │  │
│  │  │                                                        │   │  │
│  │  ├────────────────────────────────────────────────────────┤   │  │
│  │  │                       [Clear All]  [Apply Filters]     │   │  │
│  │  └────────────────────────────────────────────────────────┘   │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  Active: [1. Status = Active ✕] [2. Revenue > 50K ✕]  [Clear]│  │
│  ├────────────┬──────────┬───────────┬───────────────────────────┤  │
│  │ Name    ↕  │ Status ↕ │ Revenue ↕ │ Close Date  ↕            │  │
│  │ ...datatable rows...                                          │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │ [◀ First] [◂ Prev]  Page 1 of 17  [Next ▸] [Last ▶]         │  │
│  │              Showing 1–20 of 325 filtered (1,000 total)       │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

**Implementation note:** Use a collapsible section (`template if:true` toggle) rather than a floating popover. Popovers in LWC within Lightning App Builder pages can have clipping issues due to container `overflow: hidden`. A collapsible section is reliable across all page types (Record Page, App Page, Home Page, URL Addressable).

### 8.2 Search Bar

A `lightning-input type="search"` in the card header provides quick text search across all text-type filterable columns. This serves a different user intent than the structured filter popup:

| Mechanism | User Intent | Interaction |
|---|---|---|
| **Search bar** | "I'm looking for something specific" — exploratory, fast | Type and see results (debounced, 300ms) |
| **Filter popup** | "I want to narrow by specific criteria" — deliberate, precise | Configure conditions and apply |

The search bar and structured filters are complementary. Every major data application (Salesforce List Views, Gmail, Jira) provides both.

**Behavior:**
- Searches across all columns where `filterable: true` and type is `text` (or no type specified)
- Debounced at 300ms to avoid excessive re-processing
- Requires full dataset to be loaded (triggers lazy fetch on first use, subject to threshold gate)
- Search term is combined with popup filters via AND logic — search narrows within the already-filtered results
- Clearing the search bar text re-applies remaining filters (if any) or returns to browse mode

### 8.3 Filter Section

Each filter row contains:

- **Row number label** (1, 2, 3...) — referenced in the logic expression (advanced mode)
- **Field selector** (`lightning-combobox`) — populated from filterable columns in `columnConfig`
- **Operator selector** (`lightning-combobox`) — dynamically adapts based on the selected field's data type
- **Value input** — type-appropriate input control (see Section 9.2)
- **Remove button** (`lightning-button-icon`) — removes the row and renumbers remaining rows

### 8.4 Active Filter Indicators

When filters are applied, display them as removable pills above the datatable:

```
Active: [1. Status = Active ✕] [2. Revenue > 50K ✕]            [Clear All]
```

Use `lightning-pill-container` for filter pills. Removing a pill removes that filter condition and re-applies the remaining conditions immediately.

---

## 9. Filter Types and Operators

### 9.1 Operator Matrix by Data Type

When the user selects a field in a filter row, the operator dropdown updates based on that field's `type` from `columnConfig`:

| Column Type | Available Operators |
|---|---|
| `text` (default) | equals, not equals, contains, starts with |
| `number`, `currency`, `percent` | equals, not equals, greater than, less than, between |
| `date`, `date-local` | equals, before, after, between, within |
| `boolean` | equals |
| `enum` (if `filterValues` provided) | equals, not equals |

Operators are auto-derived from the column type. No admin configuration required for operator lists.

### 9.2 Type-Appropriate Value Inputs

| Column Type | Value Input Component |
|---|---|
| `text` | `lightning-input type="text"` |
| `number`, `currency`, `percent` | `lightning-input type="number"` |
| `number` with `between` operator | Two `lightning-input type="number"` (min and max) |
| `date` (absolute) | `lightning-input type="date"` |
| `date` with `between` operator | Two `lightning-input type="date"` (from and to) |
| `date` with `within` operator | `lightning-combobox` with relative period options |
| `boolean` | `lightning-combobox` with True / False options |
| `enum` (has `filterValues`) | `lightning-combobox` populated from `filterValues` array |

### 9.3 Date Range: Relative Periods

When a date column's operator is set to `within`, the value input becomes a `lightning-combobox` with these relative period options:

| Label | Key | Computed Range |
|---|---|---|
| Today | `today` | Start of today → now |
| This Week | `thisWeek` | Start of current week → now |
| This Month | `thisMonth` | 1st of current month → now |
| This Quarter | `thisQuarter` | 1st of current quarter → now |
| This Year | `thisYear` | Jan 1 of current year → now |
| Last 7 Days | `last7` | 7 days ago → now |
| Last 30 Days | `last30` | 30 days ago → now |
| Last 90 Days | `last90` | 90 days ago → now |

Date boundaries are computed at evaluation time (when Apply is clicked), ensuring they are always current.

```javascript
getDateRange(rangeName) {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    switch (rangeName) {
        case 'today':
            return { min: startOfDay, max: now };
        case 'thisWeek': {
            const dayOfWeek = startOfDay.getDay();
            const weekStart = new Date(startOfDay);
            weekStart.setDate(weekStart.getDate() - dayOfWeek);
            return { min: weekStart, max: now };
        }
        case 'thisMonth':
            return { min: new Date(now.getFullYear(), now.getMonth(), 1), max: now };
        case 'thisQuarter': {
            const qMonth = Math.floor(now.getMonth() / 3) * 3;
            return { min: new Date(now.getFullYear(), qMonth, 1), max: now };
        }
        case 'thisYear':
            return { min: new Date(now.getFullYear(), 0, 1), max: now };
        case 'last7':
            return { min: new Date(now - 7 * 86400000), max: now };
        case 'last30':
            return { min: new Date(now - 30 * 86400000), max: now };
        case 'last90':
            return { min: new Date(now - 90 * 86400000), max: now };
        default:
            return { min: null, max: null };
    }
}
```

---

## 10. Condition Logic (AND/OR)

### 10.1 Progressive Disclosure

The condition logic uses a two-level progressive disclosure approach to serve both casual users and power users:

| Level | UI | Coverage |
|---|---|---|
| **Simple mode** (default) | Radio toggle: "Match **all** conditions" / "Match **any** condition" | ~90% of use cases |
| **Advanced mode** (opt-in) | Text input for custom logic expression: `1 AND (2 OR 3)` | ~10% power-user cases |

The simple toggle covers the vast majority of users without requiring knowledge of boolean syntax. A "Use Custom Logic" link reveals the text expression field for power users.

### 10.2 Simple Mode (Default)

```
FILTERS
Match: (●) All conditions  (○) Any condition
                         [ Use Custom Logic ]

1. [Status  ▾] [equals       ▾] [Active ▾]       [✕]
2. [Revenue ▾] [greater than ▾] [50000   ]       [✕]
```

- **All conditions** = all filter rows joined by AND
- **Any condition** = all filter rows joined by OR
- The radio selection auto-generates the logic string internally (e.g., `1 AND 2 AND 3` or `1 OR 2 OR 3`)

### 10.3 Advanced Mode (Custom Logic)

When the user clicks "Use Custom Logic", the radio toggle is replaced by a text input:

```
FILTERS
Logic: [ 1 AND (2 OR 3)                              ]
                               [ Use Simple Logic ]

1. [Status  ▾] [equals       ▾] [Active ▾]       [✕]
2. [Revenue ▾] [greater than ▾] [50000   ]       [✕]
3. [Name    ▾] [contains     ▾] [Acme    ]       [✕]
```

The user types a boolean expression using filter row numbers:

| User Types | Meaning |
|---|---|
| `1 AND 2 AND 3` | All conditions must match |
| `1 OR 2 OR 3` | Any condition matches |
| `1 AND (2 OR 3)` | Status is Active AND (Revenue > 50K OR Name contains Acme) |
| `(1 OR 2) AND 3` | Grouped logic with parentheses |

**Auto-population rules:**
- Switching from simple to advanced pre-fills the text with the current simple logic (e.g., `1 AND 2 AND 3`)
- Adding a new filter row auto-appends `AND <n>` to the expression
- Removing a filter row auto-renumbers remaining references
- Switching back to simple mode is only allowed if the current expression is pure AND or pure OR (otherwise greyed out with tooltip: "Custom logic cannot be expressed as simple AND/OR")

### 10.4 Validation

Before applying, the logic expression is validated (in advanced mode):

- Only allows digits, `AND`, `OR`, parentheses, and spaces
- Every referenced number must correspond to an existing filter row
- Parentheses must be balanced
- Inline error shown on the input if validation fails

```javascript
validateFilterLogic(logicString, filterCount) {
    const cleaned = logicString.trim().toUpperCase();

    if (!/^[\d\s()ANDOR]+$/.test(cleaned)) {
        return 'Only filter numbers, AND, OR, and parentheses are allowed';
    }

    let depth = 0;
    for (const ch of cleaned) {
        if (ch === '(') depth++;
        if (ch === ')') depth--;
        if (depth < 0) return 'Unbalanced parentheses';
    }
    if (depth !== 0) return 'Unbalanced parentheses';

    const refs = cleaned.match(/\d+/g) || [];
    for (const ref of refs) {
        if (parseInt(ref) < 1 || parseInt(ref) > filterCount) {
            return `Filter ${ref} does not exist`;
        }
    }

    return null;
}
```

### 10.5 Evaluation Engine

The logic string is parsed into an AST (Abstract Syntax Tree) and evaluated recursively. Note: `new Function()` is blocked by Lightning Web Security, so a recursive evaluator is required.

**Parse example:**

```
"1 AND (2 OR 3)"

→ { type: 'AND', children: [
      { type: 'filter', index: 0 },
      { type: 'OR', children: [
          { type: 'filter', index: 1 },
          { type: 'filter', index: 2 }
      ]}
  ]}
```

**Evaluator:**

```javascript
evaluateLogic(node, filterResults) {
    if (node.type === 'filter') {
        return filterResults[node.index];
    }
    if (node.type === 'AND') {
        return node.children.every(child =>
            this.evaluateLogic(child, filterResults)
        );
    }
    if (node.type === 'OR') {
        return node.children.some(child =>
            this.evaluateLogic(child, filterResults)
        );
    }
    return true;
}
```

**Evaluation flow per record:**

```
Record: { Status: 'Active', Revenue: 30000, Name: 'Acme Corp' }

Filter 1: Status equals Active    → true
Filter 2: Revenue > 50000        → false
Filter 3: Name contains Acme     → true

Logic: "1 AND (2 OR 3)"
Result: true AND (false OR true) → true AND true → true ✓ include
```

---

## 11. Data Pipeline

### 11.1 Filter Evaluation

A type-aware comparator handles all filter operators:

```javascript
evaluateFilter(record, filter) {
    const value = record[filter.field];

    switch (filter.operator) {
        case 'equals':
            return value == filter.value;
        case 'notEquals':
            return value != filter.value;
        case 'contains':
            return String(value ?? '').toLowerCase()
                       .includes(String(filter.value).toLowerCase());
        case 'startsWith':
            return String(value ?? '').toLowerCase()
                       .startsWith(String(filter.value).toLowerCase());
        case 'greaterThan':
            return value != null && Number(value) > Number(filter.value);
        case 'lessThan':
            return value != null && Number(value) < Number(filter.value);
        case 'between':
            return value != null
                && Number(value) >= Number(filter.value[0])
                && Number(value) <= Number(filter.value[1]);
        case 'before':
            return value != null && new Date(value) < new Date(filter.value);
        case 'after':
            return value != null && new Date(value) > new Date(filter.value);
        case 'within':
            const range = this.getDateRange(filter.value);
            return value != null
                && new Date(value) >= range.min
                && new Date(value) <= range.max;
        default:
            return true;
    }
}
```

### 11.2 Sort

Sort uses a type-aware comparator with null handling:

```javascript
sortData(records, fieldName, direction) {
    if (!fieldName) return records;

    const reverse = direction === 'asc' ? 1 : -1;
    const col = this.columns.find(c => c.fieldName === fieldName);
    const parse = this.parserFor(col);

    return [...records].sort((a, b) => {
        const x = parse(a[fieldName]);
        const y = parse(b[fieldName]);
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return x > y ? reverse : x < y ? -reverse : 0;
    });
}

parserFor(col) {
    switch (col && col.type) {
        case 'number': case 'currency': case 'percent':
            return v => (v == null ? null : Number(v));
        case 'date': case 'date-local':
            return v => (v == null ? null : new Date(v).getTime());
        default:
            return v => (v == null ? null : String(v).toLowerCase());
    }
}
```

### 11.3 Unified Pipeline

All processing runs through a single method in the parent component:

```javascript
applyAllProcessing() {
    let results = this._masterRecords;

    // 1. Apply text search (from search bar)
    if (this._searchTerm) {
        results = results.filter(r => this.textFilter(r));
    }

    // 2. Apply structured filters with condition logic
    if (this._activeFilters && this._activeFilters.length > 0) {
        results = results.filter(record => {
            const filterResults = this._activeFilters.map(f =>
                this.evaluateFilter(record, f)
            );
            return this.evaluateLogic(this._filterLogicTree, filterResults);
        });
    }

    // 3. Apply sort (from column header)
    if (this._sortedBy) {
        results = this.sortData(results, this._sortedBy, this._sortDirection);
    }

    // 4. Update display and reset to page 1
    this._processedRecords = results;
    this._filteredCount = results.length;
    this.currentPage = 1;
    this.data = this.addKeyToData(results.slice(0, this.pageSize));
}

textFilter(record) {
    const term = this._searchTerm.toLowerCase();
    return this._searchableFields.some(field =>
        String(record[field] ?? '').toLowerCase().includes(term)
    );
}
```

Pipeline order: **text search → structured filters → sort → paginate**. Each step operates on the output of the previous step.

---

## 12. Refresh Behavior

### 12.1 Refresh Flow

Refresh always re-executes the Data Cloud query to get fresh data. The component preserves the user's filter, sort, and search state and re-applies them if the new dataset is within the threshold.

```
User clicks Refresh
  │
  ▼
Re-execute Data Cloud query → new queryId, new totalRowCount
  │
  ├── No active filters/sort/search
  │     │
  │     ▼
  │     Fetch first page only
  │     Display page 1 in browse mode
  │
  ├── Active processing AND new totalRowCount ≤ MAX_FILTERABLE_ROWS
  │     │
  │     ▼
  │     Fetch ALL records (new query, full dataset)
  │     Re-apply existing search + filters + sort
  │     Display page 1 of processed results
  │     User sees fresh data with same view ✓
  │
  └── Active processing AND new totalRowCount > MAX_FILTERABLE_ROWS
        │
        ▼
        Fetch first page only (browse mode)
        DEACTIVATE processing on the data (do not apply)
        PRESERVE filter/sort/search configuration
        Set _filtersPaused = true
        Show informational banner
        User sees unfiltered, unsorted paginated data
```

### 12.2 Over-Limit After Refresh: Deactivate, Don't Destroy

When the dataset grows beyond the threshold between the initial load and refresh, the component separates two concerns:

- **Configuration** (what the user built — filters, sort column, search term) — **preserved**
- **Application** (whether it's active on the data) — **deactivated (paused)**

This ensures:
- Data correctness: unfiltered/unsorted pagination is always correct
- User's work is preserved: opening the popup shows their filter configuration intact, sort column is remembered, search term is retained
- Clear communication: a banner explains what happened and why
- Re-apply path: the user can adjust filters (e.g., add a stricter condition to reduce results) and click Apply again

### 12.3 Paused State UI

When processing is paused, an informational banner appears and the active filter pills change to a paused visual state:

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⓘ  Dataset has grown to 12,000 records (limit: 10,000).            │
│    Filters and sorting have been paused. Adjust your filters to     │
│    reduce the result set, then re-apply.                            │
└──────────────────────────────────────────────────────────────────────┘

Paused: [1. Status = Active] [2. Revenue > 50K]       [Re-apply] [Clear All]
```

- **Re-apply**: Attempts to fetch all data and apply processing again (will show threshold error if still over limit)
- **Clear All**: Removes all filter/sort/search configuration entirely, dismisses the banner, returns to standard browse mode

### 12.4 Refresh Handler

```javascript
async handleRefresh() {
    this.isLoading = true;

    try {
        const result = await executeDataCloudQuery(
            this.querySettingId,
            this.effectiveRecordId,
            this.pageSize
        );

        this.queryId = result.queryId;
        this.totalRows = result.totalRowCount;
        this._masterRecords = this.addKeyToData(result.records);
        this._fullDatasetLoaded = false;

        if (this.hasActiveProcessing) {
            if (this.totalRows <= this.maxFilterableRows) {
                await this.fetchRemainingRecords();
                this._fullDatasetLoaded = true;
                this.applyAllProcessing();
                this._filtersPaused = false;
            } else {
                this._filtersPaused = true;
                this._processedRecords = [];
                this.data = this._masterRecords;
                this.currentPage = 1;
            }
        } else {
            this.data = this._masterRecords;
            this.currentPage = 1;
            this._filtersPaused = false;
        }

    } catch (error) {
        this.handleError(error);
    } finally {
        this.isLoading = false;
    }
}
```

---

## 13. Component Architecture

### 13.1 Component Hierarchy

```
dataCloudQueryResultList (parent)
  │
  ├── lightning-card
  │     ├── header actions area
  │     │     ├── lightning-input type="search" (quick search bar)
  │     │     ├── lightning-button-icon (filter toggle)
  │     │     └── lightning-button-icon (refresh)
  │     │
  │     ├── informational banner (when processing paused — conditional)
  │     │
  │     ├── dataCloudQueryFilter (new child component — collapsible section)
  │     │     ├── lightning-radio-group (Match All / Match Any — simple mode)
  │     │     │   └── "Use Custom Logic" link
  │     │     ├── lightning-input (logic expression — advanced mode, conditional)
  │     │     │   └── "Use Simple Logic" link
  │     │     ├── filter rows (dynamic, one per condition)
  │     │     │     ├── row number label
  │     │     │     ├── lightning-combobox (field selector)
  │     │     │     ├── lightning-combobox (operator selector)
  │     │     │     ├── [dynamic value input based on type]
  │     │     │     └── lightning-button-icon (remove row)
  │     │     ├── lightning-button (+ Add Filter)
  │     │     └── footer: Clear All button, Apply Filters button
  │     │
  │     ├── lightning-pill-container (active / paused filter pills)
  │     │
  │     ├── lightning-datatable
  │     │     (sortable columns with built-in onsort,
  │     │      sorted-by and sorted-direction attributes,
  │     │      exactly one page of rows rendered)
  │     │
  │     └── pagination controls
  │           ├── lightning-button-icon (First, Prev, Next, Last)
  │           └── page indicator text (Page X of Y, Showing A–B of C)
```

### 13.2 Parent-Child Contract

The `dataCloudQueryFilter` child component is a self-contained, reusable filter builder. It has no awareness of the data or sorting — it only knows filterable column definitions.

```
                      ┌────────────────────────────┐
  columnConfig ──────►│  dataCloudQueryFilter      │
  (input @api)        │                            │
                      │  Emits:                    │
                      │  onfilterchange ───────────┼──► { filters, logic }
                      │  onclearfilters ───────────┼──► (no payload)
                      └────────────────────────────┘
```

The parent owns all data, sort state, search state, and processing. The child is purely a filter UI builder.

### 13.3 Event Payload

When the user clicks Apply Filters, the child dispatches:

```javascript
this.dispatchEvent(new CustomEvent('filterchange', {
    detail: {
        filters: [
            { field: 'Status__c',    operator: 'equals',      value: 'Active' },
            { field: 'Revenue__c',   operator: 'greaterThan', value: 50000 },
            { field: 'Name__c',      operator: 'contains',    value: 'Acme' }
        ],
        logic: '1 AND (2 OR 3)'
    }
}));
```

Note: no `sort` in the payload. Sort is managed independently by the parent via the `lightning-datatable` `onsort` event.

### 13.4 Parent Handler

```javascript
async handleFilterChange(event) {
    const { filters, logic } = event.detail;

    // Threshold gate: reject if dataset too large
    if (this.totalRows > this.maxFilterableRows) {
        this.showThresholdError();
        return;
    }

    this.isLoading = true;

    try {
        // Fetch remaining records if not already fetched (reuses existing queryId)
        if (!this._fullDatasetLoaded) {
            await this.fetchRemainingRecords();
            this._fullDatasetLoaded = true;
        }

        this._activeFilters = filters;
        this._filterLogicTree = this.parseLogic(logic);
        this._filtersPaused = false;
        this.applyAllProcessing();

    } catch (error) {
        this.handleError(error);
    } finally {
        this.isLoading = false;
    }
}

async fetchRemainingRecords() {
    if (this._masterRecords.length >= this.totalRows) return;

    const remaining = await getDataCloudQueryResultData(
        this.querySettingId,
        this.queryId,
        this._masterRecords.length,
        this.totalRows - this._masterRecords.length
    );

    this._masterRecords = [
        ...this._masterRecords,
        ...this.addKeyToData(remaining.records, this._masterRecords.length)
    ];
}
```

---

## 14. Edge Cases and State Transitions

| Scenario | Behavior |
|---|---|
| **User clicks Apply Filters, dataset within limit** | Fetch all → apply filters (+ existing sort if any) → show page 1 of results |
| **User clicks Apply Filters, dataset exceeds limit** | Reject with message → popup stays open → user can adjust or dismiss |
| **User clicks column header to sort, no data loaded yet** | Threshold check → fetch all → sort → show page 1 |
| **User clicks column header to sort, full data already loaded** | Sort instantly → show page 1 of sorted results |
| **User clicks column header to sort, dataset exceeds limit** | Reject with message → sort arrows disabled |
| **User types in search bar, no data loaded yet** | Threshold check → fetch all → search → show page 1 |
| **User clears search bar text** | Re-apply remaining filters/sort (if any) or return to browse mode |
| **User clicks Refresh, no active processing** | Re-execute query → show page 1 in browse mode |
| **User clicks Refresh, active processing, data within limit** | Re-execute query → fetch all → re-apply search + filters + sort → show page 1 |
| **User clicks Refresh, active processing, data now exceeds limit** | Re-execute query → show page 1 unfiltered/unsorted → pause processing → show banner → preserve configuration |
| **User clicks Re-apply after processing paused** | Re-check threshold → apply if under limit → reject with message if still over |
| **User clicks Clear All** | Remove all filter/search/sort configuration → dismiss banner → return to browse mode |
| **User removes a filter pill** | Remove that filter condition → re-apply remaining filters (+ sort + search) immediately |
| **User clicks Next/Prev with no processing active** | Check if page data is in `_masterRecords` → fetch from server if needed → display |
| **User clicks Next/Prev with processing active** | Slice from `_processedRecords` (always local, always instant) |
| **User clicks Last with lazy-loaded data (no processing)** | Triggers full fetch (subject to threshold) to calculate and display last page |
| **User opens popup, makes changes, closes without Apply** | Changes are discarded — popup state resets to match currently applied filters |
| **Query job (queryId) has expired (TTL)** | `fetchRemainingRecords` fails → catch error → re-execute full query transparently → retry fetch |
| **Sort + Filter combined** | Sort state and filter state are independent. Changing sort re-sorts the already-filtered results. Changing filters re-filters from `_masterRecords` and then re-applies current sort |

---

## 15. Column Configuration Schema

The existing `columnConfig` JSON (configured by admins in Lightning App Builder) is extended with minimal additions:

```json
[
  {
    "label": "Account Name",
    "fieldName": "Name__c",
    "sortable": true,
    "filterable": true
  },
  {
    "label": "Status",
    "fieldName": "Status__c",
    "sortable": true,
    "filterable": true,
    "filterValues": ["Active", "Inactive", "Pending"]
  },
  {
    "label": "Revenue",
    "fieldName": "Revenue__c",
    "type": "currency",
    "sortable": true,
    "filterable": true
  },
  {
    "label": "Close Date",
    "fieldName": "CloseDate__c",
    "type": "date",
    "sortable": true,
    "filterable": true
  },
  {
    "label": "Description",
    "fieldName": "Description__c"
  }
]
```

Rules:

- `sortable: true` — column header shows sort arrows; clicking triggers `onsort` event
- `filterable: true` — column appears in the filter popup field dropdown and contributes to search bar (if text type)
- `filterValues` (optional) — constrains value input to a picklist; auto-sets operators to equals/not equals
- `type` — used to auto-derive available filter operators, value input type, and sort comparator
- Columns without `sortable` or `filterable` (e.g., Description) are display-only

---

## 16. Salesforce Standard Components Used

The entire feature is built from standard Salesforce base components:

| Component | Purpose |
|---|---|
| `lightning-input type="search"` | Quick search bar in card header |
| `lightning-datatable` with `onsort` | Data display with built-in column-header sorting |
| `lightning-button-icon` | Filter toggle, refresh, remove rows, pagination (First/Prev/Next/Last) |
| `lightning-radio-group` | Simple AND/OR toggle in filter section |
| `lightning-combobox` | Field selector, operator selector, enum/date-period value selector |
| `lightning-input type="text"` | Advanced filter logic expression, text filter values |
| `lightning-input type="number"` | Number/currency filter values |
| `lightning-input type="date"` | Date filter values (absolute) |
| `lightning-button` | "Add Filter", "Apply Filters", "Clear All", "Re-apply" |
| `lightning-pill-container` | Active / paused filter summary |
| `lightning-icon` | Filter indicator, info banner icon |

No custom rendering components. No external CSS libraries. No third-party UI frameworks.

---

## 17. Performance Considerations

### DOM Performance

`lightning-datatable` renders every row to the DOM (no virtualization). Salesforce recommends a maximum of 1,000 rows for optimal performance. The Next/Previous pagination ensures the datatable always renders exactly `pageSize` rows — consistent rendering cost regardless of dataset size or position in the data.

### JavaScript Processing

| Dataset Size | Filter Time (native) | Sort Time (native) | Total Pipeline |
|---|---|---|---|
| 1,000 records | < 1ms | ~5ms | < 10ms |
| 5,000 records | ~1ms | ~25ms | < 30ms |
| 10,000 records | ~2ms | ~46ms | < 50ms |

All well within acceptable UI responsiveness thresholds (< 100ms).

### Network

- **Initial load**: Full async Data Cloud pipeline (submit → poll → fetch first page).
- **Page navigation (browse mode)**: Reuses existing `queryId` — only data transfer, no new query.
- **First sort/search/filter**: Fetches remaining records via existing `queryId` — only data transfer, no new query. One-time cost; all subsequent interactions are instant.
- **Subsequent sort/filter changes**: Zero network cost — re-processes `_masterRecords` locally.
- **Refresh**: Full async Data Cloud pipeline (new query submission).

### Threshold

| Record Count | Recommendation |
|---|---|
| ≤ 2,000 | Optimal — all operations instant |
| 2,000–5,000 | Good — sub-30ms processing |
| 5,000–10,000 | Acceptable — sub-50ms processing |
| > 10,000 | Sort/filter/search rejected, pagination-only mode |

Default `MAX_FILTERABLE_ROWS`: **10,000**. Configurable via App Builder component property.

---

## 18. Decision Log

| # | Decision | Rationale |
|---|---|---|
| 1 | Client-side over server-side | Data Cloud async pipeline (1–5s per query) makes server-side filtering unacceptable for interactive UX |
| 2 | Native JS over external library | Sub-50ms at 10,000 records; avoids LWS compatibility risk, static resource management, and dependency on low-maturity libraries |
| 3 | Column-header sorting via `lightning-datatable` `onsort` | One-click interaction matching every Salesforce list view. Universal, intuitive, zero custom UI. Sort is independent of the filter popup |
| 4 | Separate filter popup (no sort in popup) | Sorting and filtering are different interaction patterns: sort is instant/single-click, filtering is deliberate/multi-step. Combining them forces unnecessary friction on sorting |
| 5 | Search bar for quick text search | Serves exploratory intent (fast, type-ahead). Complementary to structured filters (precise, deliberate). Matches Salesforce, Gmail, Jira patterns |
| 6 | Progressive disclosure for AND/OR logic | Simple AND/OR toggle covers ~90% of use cases. Advanced typed expression (`1 AND (2 OR 3)`) available via opt-in for power users. Reduces cognitive load for casual users |
| 7 | Next/Previous pagination over Load More | Consistent DOM row count (always `pageSize`); clear position awareness (record index display); bi-directional navigation; no scroll accumulation |
| 8 | No explicit mode flag | Processing state derived from `hasActiveProcessing` (sort, search, or filters active). No mode variable to get out of sync. Behavior is a natural consequence of which array is the data source |
| 9 | Threshold gate: all or nothing | Sort/filter/search all require complete data or are rejected. No partial processing on incomplete datasets — this would produce incorrect, misleading results |
| 10 | Lazy page fetch in browse mode | Pages fetched from server on demand using existing `queryId`. Records accumulate in `_masterRecords`. Going backwards is always instant (already cached) |
| 11 | First sort/search/filter triggers full fetch | One-time cost to load remaining records via existing `queryId` (data transfer only, no new query). All subsequent sort/filter/search interactions are instant |
| 12 | Refresh preserves configuration | Filter/sort/search state is re-applied if data is within threshold. If data exceeds threshold, processing is paused (deactivated) but configuration is preserved for user to adjust and re-apply |
| 13 | Collapsible section over floating popover | Avoids `overflow: hidden` clipping issues in Lightning page containers; reliable across all page types |
| 14 | Extend existing `columnConfig` JSON | Consistent admin experience; minimal additions (`sortable`, `filterable`, `filterValues`); no new metadata objects |
