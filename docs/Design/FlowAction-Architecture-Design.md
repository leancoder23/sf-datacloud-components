# Flow Action Buttons — Architecture Design

> **Date:** July 10, 2026
> **Author:** Architecture Review
> **Status:** Design Proposal
> **Components:** `dataCloudQueryResultList`, `dataCloudQueryResult` (sf-datacloud-query-components)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Design Principles](#3-design-principles)
4. [Configuration Schema: `actionConfig`](#4-configuration-schema-actionconfig)
   - 4.1 [Top-Level Structure](#41-top-level-structure)
   - 4.2 [Action Definition](#42-action-definition)
   - 4.3 [Selection Mode](#43-selection-mode)
   - 4.4 [Input Mappings — Single Mode](#44-input-mappings--single-mode)
   - 4.5 [Input Mappings — Multi Mode](#45-input-mappings--multi-mode)
   - 4.6 [The `__ALL__` Keyword](#46-the-__all__-keyword)
   - 4.7 [Supported Flow Variable Types](#47-supported-flow-variable-types)
   - 4.8 [Configuration Examples](#48-configuration-examples)
5. [Component Architecture](#5-component-architecture)
   - 5.1 [System Diagram](#51-system-diagram)
   - 5.2 [Shared Action Service Module](#52-shared-action-service-module)
   - 5.3 [Flow Modal Component](#53-flow-modal-component)
6. [Data Flow Sequence](#6-data-flow-sequence)
7. [Validation Logic](#7-validation-logic)
8. [Type Coercion](#8-type-coercion)
9. [Record Sanitization](#9-record-sanitization)
10. [Lightning App Builder Properties](#10-lightning-app-builder-properties)
11. [Component-Specific Behavior](#11-component-specific-behavior)
    - 11.1 [Result List Component](#111-result-list-component)
    - 11.2 [Result Detail Component](#112-result-detail-component)
12. [Template Rendering](#12-template-rendering)
13. [Flow-Side Consumption](#13-flow-side-consumption)
14. [Files to Create / Modify](#14-files-to-create--modify)
15. [Decision Log](#15-decision-log)
16. [Future Extensibility](#16-future-extensibility)

---

## 1. Executive Summary

This document defines the architecture for adding **configurable action buttons** to the Data Cloud Query Result components (`dataCloudQueryResultList` and `dataCloudQueryResult`). These action buttons invoke Salesforce Screen Flows, passing selected record data as typed input variables based on admin-configured field mappings.

Key design decisions:

- **Header-level actions only** — all action buttons render in the card header area. No row-level inline actions. This avoids duplicating rendering logic across components.
- **Per-action `selectionMode`** — each action declares whether it operates on a single row or multiple rows. Validation enforces the rule at click time.
- **Typed flow variables** — input mappings declare the target flow variable's data type (`String`, `Number`, `Boolean`, `Date`, `DateTime`, `Currency`). Values are coerced before passing to `lightning-flow`.
- **Single mode: one variable per mapping** — each mapping produces a separate typed flow input variable.
- **Multi mode: one JSON payload** — all mapped fields from all selected records are projected into a JSON array string, sent to a single `targetFlowVariable`.
- **`__ALL__` keyword** — shorthand to pass the entire record (single) or all selected records (multi) without enumerating fields.
- **Shared service module** — config parsing, validation, and variable building live in a single `dataCloudQueryActionService` module, consumed by both components with zero logic duplication.
- **LightningModal-based flow execution** — flows run in a modal overlay, keeping the user on the same page with automatic data refresh on completion.

---

## 2. Problem Statement

The Data Cloud Query components display query results in list and detail formats. Currently, these components are **read-only** — users can view data but cannot take action on it.

Common use cases require the ability to:

- Create a Case from a Data Cloud customer record
- Sync selected Data Cloud records to CRM objects
- Enroll multiple contacts into a campaign
- Trigger an approval process based on engagement scores
- Launch any admin-configured business process with Data Cloud context

Salesforce Flows are the standard mechanism for orchestrating business processes. The components need a declarative way to connect displayed data to Flows without custom development per use case.

---

## 3. Design Principles

| Principle | Rationale |
|---|---|
| **No logic duplication** | Shared service module handles all action logic. Components only manage selection state and UI rendering. |
| **Header-only placement** | Eliminates divergent rendering patterns between datatable row actions (list) and per-record buttons (detail). Consistent, predictable UX. |
| **Per-action selection mode** | One component can host both single-record and multi-record actions without conflict. |
| **Declarative configuration** | Admins configure everything via JSON in Lightning App Builder. No code changes for new flows. |
| **Type safety** | Flow variables receive correctly-typed values. No unnecessary type conversion inside the flow. |
| **Inline execution** | Modal keeps user context. No page navigation. Auto-refresh on completion. |

---

## 4. Configuration Schema: `actionConfig`

### 4.1 Top-Level Structure

The admin provides a single JSON string via Lightning App Builder:

```json
{
  "actions": [ ... ]
}
```

### 4.2 Action Definition

| Property | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | String | Yes | — | Button label text |
| `flowApiName` | String | Yes | — | API name of the Screen Flow to invoke |
| `icon` | String | No | — | SLDS icon for the button (e.g., `"utility:case"`) |
| `variant` | String | No | `"neutral"` | Button variant: `brand`, `neutral`, `destructive`, `success` |
| `selectionMode` | String | Yes | — | `"single"` or `"multi"` — determines validation and data passing behavior |
| `targetFlowVariable` | String | Conditional | — | **Required for `multi` mode only.** Flow variable name that receives the JSON array payload |
| `inputMappings` | Array | Yes | — | Field-to-flow-variable mappings |
| `refreshOnComplete` | Boolean | No | `true` | Whether to refresh component data after flow completes |

### 4.3 Selection Mode

`selectionMode` is declared per action, enabling mixed behaviors on the same component:

| `selectionMode` | Validation Rule | Data Passing Strategy |
|---|---|---|
| `"single"` | Exactly 1 record selected. Error if 0 or >1. | One flow variable per mapping (typed scalar values) |
| `"multi"` | At least 1 record selected. Error if 0. | Single `targetFlowVariable` receives JSON array of projected objects |

### 4.4 Input Mappings — Single Mode

Each mapping produces a separate, typed flow input variable:

| Property | Required | Default | Description |
|---|---|---|---|
| `flowVariable` | Yes | — | Target flow input variable name |
| `fieldName` | Yes | — | Source field from the Data Cloud record. Use `"__ALL__"` for full record. |
| `type` | No | `"String"` | Flow variable data type: `String`, `Number`, `Currency`, `Boolean`, `Date`, `DateTime` |

**Example:**

```json
"inputMappings": [
    { "flowVariable": "customerEmail", "fieldName": "Email__c", "type": "String" },
    { "flowVariable": "totalOrders", "fieldName": "TotalOrders__c", "type": "Number" },
    { "flowVariable": "isActive", "fieldName": "IsActive__c", "type": "Boolean" }
]
```

**Flow receives:**

```javascript
[
    { name: "customerEmail", type: "String",  value: "john@example.com" },
    { name: "totalOrders",   type: "Number",  value: 42 },
    { name: "isActive",      type: "Boolean", value: true }
]
```

### 4.5 Input Mappings — Multi Mode

Mappings define the shape of each projected object in the JSON array. All objects are serialized and sent to `targetFlowVariable`:

| Property | Required | Default | Description |
|---|---|---|---|
| `key` | Yes* | — | Property name in the projected JSON object. *Not required when using `__ALL__`. |
| `fieldName` | Yes | — | Source field from each record. Use `"__ALL__"` for full records. |

**Example:**

```json
"targetFlowVariable": "recordsPayload",
"inputMappings": [
    { "key": "email", "fieldName": "Email__c" },
    { "key": "id", "fieldName": "IndividualId__c" },
    { "key": "name", "fieldName": "FullName__c" }
]
```

**Flow receives (3 rows selected):**

```javascript
[{
    name: "recordsPayload",
    type: "String",
    value: '[{"email":"john@ex.com","id":"ID-123","name":"John Doe"},{"email":"jane@co.com","id":"ID-456","name":"Jane Smith"},{"email":"bob@io.com","id":"ID-789","name":"Bob Lee"}]'
}]
```

Only the mapped fields are included. Unmapped fields (`Score__c`, `Region__c`, etc.) are excluded.

### 4.6 The `__ALL__` Keyword

A special `fieldName` value that passes the entire record without enumerating individual fields:

| `selectionMode` | `__ALL__` Behavior | Flow Receives |
|---|---|---|
| `"single"` | Full record serialized as JSON string | Single flow variable with complete record JSON |
| `"multi"` | All selected records serialized as JSON array | `targetFlowVariable` with JSON array of complete records |

**Single with `__ALL__`:**

```json
"inputMappings": [
    { "flowVariable": "recordData", "fieldName": "__ALL__", "type": "String" }
]
```

Flow receives: `recordData = '{"IndividualId__c":"ID-123","Email__c":"john@ex.com","FullName__c":"John Doe"}'`

**Multi with `__ALL__`:**

```json
"targetFlowVariable": "allRecords",
"inputMappings": [
    { "fieldName": "__ALL__" }
]
```

Flow receives: `allRecords = '[{...full record 1...},{...full record 2...}]'`

**Precedence rule:** When `__ALL__` is present in a multi-mode action alongside specific `key`/`fieldName` mappings, `__ALL__` takes precedence — the full record is passed. This keeps behavior predictable.

### 4.7 Supported Flow Variable Types

| Type Value | JS Coercion | Example Output |
|---|---|---|
| `"String"` (default) | `String(value)` | `"john@example.com"` |
| `"Number"` | `Number(value)` | `42`, `3.14` |
| `"Currency"` | `Number(value)` | `150000.00` |
| `"Boolean"` | Boolean coercion | `true` / `false` |
| `"Date"` | ISO date string | `"2026-07-10"` |
| `"DateTime"` | ISO datetime string | `"2026-07-10T18:30:00.000Z"` |

Types are only applicable to single-mode mappings. Multi-mode always produces a `String` (JSON payload).

### 4.8 Configuration Examples

**Example 1 — Single action, typed fields:**

```json
{
  "actions": [
    {
      "label": "Create Case",
      "flowApiName": "Create_Case_From_DataCloud",
      "icon": "utility:case",
      "variant": "brand",
      "selectionMode": "single",
      "inputMappings": [
        { "flowVariable": "customerEmail", "fieldName": "Email__c", "type": "String" },
        { "flowVariable": "customerId", "fieldName": "IndividualId__c", "type": "String" },
        { "flowVariable": "engagementScore", "fieldName": "Score__c", "type": "Number" },
        { "flowVariable": "isHighValue", "fieldName": "HighValue__c", "type": "Boolean" },
        { "flowVariable": "lastPurchase", "fieldName": "LastPurchaseDate__c", "type": "Date" }
      ]
    }
  ]
}
```

**Example 2 — Multi action, projected fields:**

```json
{
  "actions": [
    {
      "label": "Bulk Enroll",
      "flowApiName": "Bulk_Enroll_Campaign",
      "icon": "utility:groups",
      "variant": "neutral",
      "selectionMode": "multi",
      "targetFlowVariable": "enrollmentData",
      "inputMappings": [
        { "key": "contactId", "fieldName": "IndividualId__c" },
        { "key": "email", "fieldName": "Email__c" },
        { "key": "score", "fieldName": "EngagementScore__c" }
      ]
    }
  ]
}
```

**Example 3 — Mixed actions on the same component:**

```json
{
  "actions": [
    {
      "label": "View Profile",
      "flowApiName": "Show_Customer_Profile",
      "icon": "utility:user",
      "variant": "brand",
      "selectionMode": "single",
      "inputMappings": [
        { "flowVariable": "recordJson", "fieldName": "__ALL__", "type": "String" }
      ]
    },
    {
      "label": "Sync to CRM",
      "flowApiName": "Sync_DC_Records_To_CRM",
      "icon": "utility:sync",
      "variant": "neutral",
      "selectionMode": "multi",
      "targetFlowVariable": "recordsPayload",
      "inputMappings": [
        { "fieldName": "__ALL__" }
      ]
    }
  ]
}
```

---

## 5. Component Architecture

### 5.1 System Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│   dataCloudQueryResultList            dataCloudQueryResult            │
│                                                                        │
│   @api actionConfig (JSON)            @api actionConfig (JSON)        │
│                                                                        │
│   ┌── Header ─────────────────────────────────────────────────┐       │
│   │  [Action 1] [Action 2] ... [Refresh]                       │       │
│   └────────────────────────────────────────────────────────────┘       │
│                                                                        │
│   handleActionClick(event)            handleActionClick(event)        │
│        │                                    │                          │
│        │  getSelectedRecords()              │  getSelectedRecords()    │
│        │  (datatable.getSelectedRows)       │  (queryResults slice)    │
│        │                                    │                          │
│        └──────────────────┬─────────────────┘                          │
│                           ▼                                            │
│             dataCloudQueryService (existing shared module)             │
│               ├── [existing] executeDataCloudQuery(...)                │
│               ├── [existing] getDataCloudQueryResultData(...)          │
│               ├── [existing] getDataCloudRecordLocalId(...)            │
│               ├── [existing] formatString(...)                         │
│               ├── [existing] resolveRecordId(...)                      │
│               ├── [NEW] parseActionConfig(jsonString) → actions[]      │
│               ├── [NEW] validateSelection(records, action) → {v, msg} │
│               ├── [NEW] buildFlowInputVariables(records, action) → [] │
│               ├── [NEW] coerceValue(rawValue, type) → typed value     │
│               └── [NEW] sanitizeRecord(record) → clean record         │
│                           │                                            │
│                           ▼                                            │
│             dataCloudQueryFlowModal (LightningModal)                  │
│               ├── @api flowApiName                                     │
│               ├── @api flowInputVariables                              │
│               ├── <lightning-flow> embedded                            │
│               └── onstatuschange → close + return result              │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### 5.2 Shared Service Module (Extended `dataCloudQueryService`)

The existing `dataCloudQueryService.js` module already serves as the shared utility layer for all Data Cloud Query components. Action-related functions are added directly to this module, following the established pattern:

```javascript
// Existing exports (unchanged):
export { executeDataCloudQuery, getDataCloudQueryResultData, getDataCloudRecordLocalId, formatString, delay, resolveRecordId };

// New action-related exports:
export { parseActionConfig, validateSelection, buildFlowInputVariables, coerceValue, sanitizeRecord };
```

**New functions added to `dataCloudQueryService.js`:**

```javascript
/**
 * Parses the actionConfig JSON string into an array of action objects.
 */
function parseActionConfig(actionConfigJson) { ... }

/**
 * Validates whether the current selection satisfies the action's selectionMode.
 */
function validateSelection(selectedRecords, action) { ... }

/**
 * Builds the flow input variables array based on selection mode and mappings.
 * - Single mode: one typed variable per mapping
 * - Multi mode: one JSON string variable containing projected records
 */
function buildFlowInputVariables(selectedRecords, action) { ... }

/**
 * Coerces a raw value to the target flow variable type.
 */
function coerceValue(rawValue, type) { ... }

/**
 * Removes internal framework properties (_key, _row) from a record.
 */
function sanitizeRecord(record) { ... }
```

This avoids creating a new service component. Both `dataCloudQueryResultList` and `dataCloudQueryResult` already import from `c/dataCloudQueryService` — they simply add the new functions to their import statement.

### 5.3 Flow Modal Component

`dataCloudQueryFlowModal` — a `LightningModal` subclass that embeds `lightning-flow`:

```
dataCloudQueryFlowModal
├── @api flowApiName         → passed to <lightning-flow flow-api-name>
├── @api flowInputVariables  → passed to <lightning-flow flow-input-variables>
├── @api label               → modal header title
│
├── Template:
│   ├── lightning-modal-header (label)
│   ├── lightning-modal-body
│   │   └── lightning-flow (flow-api-name, flow-input-variables, onstatuschange)
│   └── lightning-modal-footer (close button)
│
└── handleFlowStatusChange(event):
      if FINISHED / FINISHED_SCREEN → this.close('completed')
      if ERROR → show toast, keep modal open
```

---

## 6. Data Flow Sequence

```
User clicks [Create Case] button in card header
        │
        ▼
Component: handleActionClick(event)
  ├── Identify action by event.target.dataset.flowName
  ├── Call getSelectedRecords() [component-specific]
  │
  ▼
Service: validateSelection(selectedRecords, action)
  ├── [FAIL: 0 records] → Toast: "Please select at least one record..."
  ├── [FAIL: >1 record for single mode] → Toast: "...requires exactly one record..."
  └── [PASS] → continue
        │
        ▼
Service: buildFlowInputVariables(selectedRecords, action)
  ├── [single] → iterate inputMappings, coerce values, return [{name, type, value}, ...]
  └── [multi]  → project mapped fields from all records, serialize, return [{name, type:"String", value:JSON}]
        │
        ▼
DataCloudQueryFlowModal.open({
    label: action.label,
    flowApiName: action.flowApiName,
    flowInputVariables: inputVariables,
    size: 'medium'
})
        │
        ▼
Modal renders <lightning-flow>
  ├── Flow executes with pre-populated input variables
  ├── User interacts with flow screens
  └── Flow finishes (FINISHED status)
        │
        ▼
handleFlowStatusChange → modal.close('completed')
        │
        ▼
Component receives result
  └── if (result === 'completed' && action.refreshOnComplete !== false)
        → this.refreshData()
```

---

## 7. Validation Logic

```javascript
function validateSelection(selectedRecords, action) {
    if (!selectedRecords || selectedRecords.length === 0) {
        return {
            valid: false,
            message: `Please select at least one record to perform "${action.label}".`
        };
    }
    if (action.selectionMode === 'single' && selectedRecords.length > 1) {
        return {
            valid: false,
            message: `"${action.label}" requires exactly one record. Please select only one row.`
        };
    }
    return { valid: true };
}
```

Validation runs per-action at click time. The same component can have actions with different `selectionMode` values — each is validated independently.

---

## 8. Type Coercion

```javascript
function coerceValue(rawValue, type) {
    if (rawValue === null || rawValue === undefined) {
        return null;
    }

    switch (type) {
        case 'Number':
        case 'Currency':
            return Number(rawValue);

        case 'Boolean':
            if (typeof rawValue === 'boolean') return rawValue;
            if (typeof rawValue === 'string') return rawValue.toLowerCase() === 'true';
            return Boolean(rawValue);

        case 'Date':
            return rawValue instanceof Date
                ? rawValue.toISOString().split('T')[0]
                : String(rawValue);

        case 'DateTime':
            return rawValue instanceof Date
                ? rawValue.toISOString()
                : String(rawValue);

        case 'String':
        default:
            return String(rawValue);
    }
}
```

Type coercion applies only to single-mode mappings. Multi-mode serializes everything to JSON (String).

---

## 9. Record Sanitization

Before passing record data to `buildFlowInputVariables`, internal framework properties added by the component are stripped:

```javascript
function sanitizeRecord(record) {
    const { _key, _row, ...cleanRecord } = record;
    return cleanRecord;
}
```

This ensures that `__ALL__` payloads contain only actual Data Cloud field data, not LWC rendering artifacts.

---

## 10. Lightning App Builder Properties

### Meta XML Addition (Both Components)

```xml
<property name="actionConfig"
          type="String"
          label="Action Configuration (JSON)"
          description="JSON defining action buttons that invoke Salesforce Flows. Each action specifies a flow API name, selection mode (single/multi), and field-to-flow-variable mappings."
          placeholder='{"actions":[{"label":"Create Case","flowApiName":"My_Flow","selectionMode":"single","inputMappings":[{"flowVariable":"email","fieldName":"Email__c","type":"String"}]}]}'/>
```

### Property Summary

| Property | Component(s) | Required | Description |
|---|---|---|---|
| `actionConfig` | List + Detail | No | JSON string defining action buttons. When omitted, no actions are rendered. |

When `actionConfig` is provided and contains at least one action:
- **List component:** Enables the checkbox column on the datatable for row selection
- **Detail component:** No UI change (record context is implicit)

---

## 11. Component-Specific Behavior

### 11.1 Result List Component

| Aspect | Behavior |
|---|---|
| **Checkbox column** | Enabled automatically when `actions[]` has at least one entry |
| **Selection** | User selects rows via checkboxes before clicking an action button |
| **`getSelectedRecords()`** | Returns `this.template.querySelector('lightning-datatable').getSelectedRows()` |
| **Button placement** | Card header `slot="actions"`, before the refresh button |

### 11.2 Result Detail Component

| Aspect | Behavior |
|---|---|
| **Selection UI** | None — no checkboxes or row selection |
| **`getSelectedRecords()`** | `selectionMode: "single"` → `[this.queryResults[0]]`; `selectionMode: "multi"` → `this.queryResults` (all rendered records) |
| **Button placement** | Card header actions area (when title is present) or top of content area (when borderless) |

---

## 12. Template Rendering

### Action Buttons in Card Header (Both Components)

```html
<div slot="actions">
    <template for:each={actions} for:item="action">
        <lightning-button
            key={action.flowApiName}
            label={action.label}
            icon-name={action.icon}
            variant={action.variant}
            data-flow-name={action.flowApiName}
            onclick={handleActionClick}
            class="slds-m-left_x-small">
        </lightning-button>
    </template>
    <lightning-button-icon
        icon-name="utility:refresh"
        alternative-text="Refresh"
        onclick={refreshData}>
    </lightning-button-icon>
</div>
```

### Datatable with Checkbox Column (List Component)

```html
<lightning-datatable
    key-field="_key"
    data={data}
    columns={columns}
    show-checkbox-column={hasActions}
    hide-checkbox-column={noActions}>
</lightning-datatable>
```

Where `hasActions` is a getter: `return this.actions && this.actions.length > 0;`

---

## 13. Flow-Side Consumption

### Single Mode

Flow receives individual typed variables — no parsing needed. Variables can be used directly in assignments, decisions, screens, and record operations.

### Multi Mode

Flow receives a single `Text` variable containing a JSON array string. A lightweight Invocable Apex action deserializes it:

```java
public class ParseJsonRecordsAction {

    @InvocableMethod(label='Parse JSON Records' description='Deserializes a JSON array string into a list of key-value maps')
    public static List<Result> parseRecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            res.records = (List<Map<String, Object>>)
                JSON.deserializeUntyped(req.jsonPayload);
            results.add(res);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(required=true)
        public String jsonPayload;
    }

    public class Result {
        @InvocableVariable
        public List<Map<String, Object>> records;
    }
}
```

The Flow then uses a Loop element to iterate over the parsed collection.

---

## 14. Files to Create / Modify

| File | Action | Purpose |
|---|---|---|
| `lwc/dataCloudQueryService/dataCloudQueryService.js` | **MODIFY** | Add action functions: `parseActionConfig`, `validateSelection`, `buildFlowInputVariables`, `coerceValue`, `sanitizeRecord` |
| `lwc/dataCloudQueryFlowModal/dataCloudQueryFlowModal.js` | **CREATE** | LightningModal wrapping `lightning-flow` |
| `lwc/dataCloudQueryFlowModal/dataCloudQueryFlowModal.html` | **CREATE** | Modal template with flow embed |
| `lwc/dataCloudQueryFlowModal/dataCloudQueryFlowModal.js-meta.xml` | **CREATE** | Modal component metadata |
| `lwc/dataCloudQueryResultList/dataCloudQueryResultList.js` | **MODIFY** | Add `actionConfig` property, parse actions, handle click, manage checkbox column |
| `lwc/dataCloudQueryResultList/dataCloudQueryResultList.html` | **MODIFY** | Add action buttons in header slot |
| `lwc/dataCloudQueryResultList/dataCloudQueryResultList.js-meta.xml` | **MODIFY** | Add `actionConfig` property definition |
| `lwc/dataCloudQueryResult/dataCloudQueryResult.js` | **MODIFY** | Add `actionConfig` property, parse actions, handle click |
| `lwc/dataCloudQueryResult/dataCloudQueryResult.html` | **MODIFY** | Add action buttons in header slot |
| `lwc/dataCloudQueryResult/dataCloudQueryResult.js-meta.xml` | **MODIFY** | Add `actionConfig` property definition |

---

## 15. Decision Log

| # | Decision | Rationale |
|---|---|---|
| 1 | Header-level actions only (no row-level) | Eliminates divergent rendering logic between datatable row actions and per-record buttons. Consistent UX across both components. |
| 2 | `selectionMode` per action (not per component) | One component can host both single-record and multi-record actions. Each action declares and validates its own requirement independently. |
| 3 | Single mode: one flow variable per mapping | Clean, typed scalar values. Flow receives ready-to-use variables without parsing. |
| 4 | Multi mode: single JSON payload | `lightning-flow` cannot pass complex object collections. JSON string is the universal container. Single `targetFlowVariable` keeps the flow interface simple. |
| 5 | `__ALL__` keyword for full record pass-through | Zero-config option for admins who want to pass everything. Avoids enumerating every field. |
| 6 | Typed flow variables with coercion | Eliminates unnecessary type conversion inside flows. `Number`, `Boolean`, `Date` etc. are passed natively. |
| 7 | LightningModal for flow execution | Keeps user on the same page. No navigation. Supports auto-refresh on completion. Better UX than URL navigation. |
| 8 | Action functions added to existing `dataCloudQueryService` | Avoids creating a new component. Both consumer components already import from this module. Follows the established pattern of a single shared service for all query-related utilities. |
| 9 | Checkbox column enabled automatically | When actions are configured, the list component shows checkboxes. No separate property needed. |
| 10 | `refreshOnComplete` defaults to `true` | Most actions modify data. Auto-refresh ensures the UI stays current. Admin can opt out per action. |
| 11 | Validation at click time (not render time) | Buttons are always visible. Selection errors are reported as toast messages when the user clicks. This is simpler and more predictable than conditional button visibility. |
| 12 | Record sanitization before data transfer | Strips `_key` and `_row` framework properties. Ensures flow receives only actual Data Cloud field data. |
| 13 | Multi-mode `__ALL__` takes precedence over field mappings | When both are specified, `__ALL__` wins. Avoids ambiguous merge behavior. Keeps serialization predictable. |

---

## 16. Future Extensibility

### 16a. Conditional Action Visibility

Add an optional `visibleWhen` condition per action to show/hide buttons based on data state or user permissions:

```json
{
  "label": "Escalate",
  "visibleWhen": { "fieldName": "Priority__c", "operator": "equals", "value": "High" }
}
```

### 16b. Confirmation Dialog

Add an optional `confirmMessage` property that shows a confirmation prompt before launching the flow:

```json
{
  "label": "Delete Records",
  "confirmMessage": "Are you sure you want to delete the selected records?",
  "variant": "destructive"
}
```

### 16c. Non-Flow Action Types

Extend the schema to support other action types beyond flows:

```json
{ "type": "flow", "flowApiName": "..." }
{ "type": "navigate", "url": "/lightning/o/Case/new?..." }
{ "type": "apex", "apexClass": "MyInvocableAction", "apexMethod": "execute" }
```

### 16d. Flow Output Capture

Read output variables from the completed flow and display a success summary or update specific UI elements without a full refresh.

### 16e. Bulk Selection Limit

Add an optional `maxSelection` property to cap how many rows can be selected for a multi action:

```json
{
  "selectionMode": "multi",
  "maxSelection": 50,
  "targetFlowVariable": "payload"
}
```
