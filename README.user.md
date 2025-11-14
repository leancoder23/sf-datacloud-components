# Data Cloud Query Components — Admin/User Guide

This guide explains how Salesforce admins can configure and use the Data Cloud Query Components to display Data Cloud query results in Lightning pages as lists and charts.

These components support two backends:

- Data Cloud REST API (via Named Credential)
- Data Cloud CDP (native platform APIs)

No code is required; configuration is done via Custom Metadata and standard Setup.

## What You Can Do

- Show query results from Data Cloud on Lightning pages.
- Display results as a list/table or as a chart.
- Optionally filter results by the current record (e.g., show results related to the Account being viewed).
- Switch between REST and CDP backends using configuration, no deployments needed.

## Prerequisites (One-Time Org Setup)

- Data Cloud is provisioned and accessible in your org.
- A Named Credential exists for the Data Cloud REST endpoint (only if you will use REST mode).
- Users who will view the components have been assigned the permission set:
  - DataCloudQueryServicePermission

Work with your developer/admin to ensure these are set. See Developer Guide for technical details.

## Step 1: Create a Data Cloud Query Setting (Custom Metadata)

1. Go to Setup > Custom Metadata Types.
2. Find “Data Cloud Query Setting” and click “Manage Records.”
3. Click “New” and fill in:

   - Label / Name: Friendly name for your setting (e.g., “Default Opportunity Insights”).
   - WorkloadName\_\_c: If required by your Data Cloud setup.
   - Dataspace\_\_c: If required by your Data Cloud setup.
   - Query\_\_c: The query to run (for example: a SQL or segment query your team provides).
   - UseDataCloudRestApi\_\_c:
     - True = Use REST backend (requires Named Credential).
     - False = Use CDP backend.
   - NamedCredential\_\_c: The API name of the Named Credential (required if using REST).
   - RecordFilterObject\_\_c: API name of an object to support record-context filters (e.g., Account).
   - RecordBasedFilterConfig\_\_c: JSON mapping that tells the system how to filter based on the current record. Your developer can provide this. Example (illustrative only):
     {
     "paramName": "accountId",
     "sourceField": "Id"
     }
   - UseCurrentRecord\_\_c: True to filter results based on the current Lightning record page.

4. Save.

Tip: You can create multiple settings for different queries and scenarios (e.g., a list in one app page and a chart on another).

## Step 2: Add Components in Lightning App Builder

There are two main visual components:

- dataCloudQueryResultList (List/Table)
- dataCloudQueryResultChart (Chart)

To add them:

1. Go to Lightning App Builder for the page where you want to show results (e.g., Account Record Page or a Home page).
2. Drag the component onto the page.
3. In the component properties (right panel), configure:
   - Query Setting: Enter/select the API Name of the Data Cloud Query Setting you created.
   - Other properties per component (if any are exposed):
     - For lists: columns/format options as available.
     - For charts: chart type, labels, value fields if configurable.
4. Save and Activate the page.

If you need to target a specific REST base URL or special routing, consult your developer about the “Custom URL Provider” components included in the solution.

## Step 3: Assign Permissions

Ensure users who need to see the components have the permission set:

- DataCloudQueryServicePermission

Go to:

- Setup > Permission Sets > DataCloudQueryServicePermission > Manage Assignments.

## How Record-Based Filtering Works (Optional)

If UseCurrentRecord**c is set to true in your Data Cloud Query Setting and RecordFilterObject**c matches the page’s object, the component can take fields from the current record (as defined in RecordBasedFilterConfig\_\_c) to filter the query results. This lets you show data that is relevant to the current record context.

Example:

- On an Account page, show query results only for that Account by mapping the Account Id to a query parameter.

Your developer can provide the exact JSON structure supported by the query service.

## Common Tasks

- Change backend from REST to CDP: Edit the Data Cloud Query Setting and toggle UseDataCloudRestApi**c to false (and remove NamedCredential**c if not needed).
- Point to a different Named Credential (REST): Update NamedCredential\_\_c with the API name of the new credential.
- Modify the query: Update Query\_\_c in the custom metadata record and save.
- Duplicate a configuration: Create another Data Cloud Query Setting record and reference it from another component instance on any page.

## Troubleshooting

- Component shows no data:

  - Confirm the correct Query Setting API name is set in the component properties.
  - Ensure the user has the DataCloudQueryServicePermission permission set.
  - Check that the Query\_\_c text is valid for your Data Cloud environment.
  - If REST mode is enabled, verify that the Named Credential exists and is authorized.

- Errors on record pages:

  - If UseCurrentRecord**c is true, ensure RecordFilterObject**c matches the page’s object API name.
  - Validate the JSON in RecordBasedFilterConfig\_\_c is correct and refers to fields that exist.

- Chart not visible:
  - Confirm the chart component is used and that any required static resources or chart-type properties are available in your org (these are typically packaged with the solution).

## FAQs

- Can I use multiple components on the same page?

  - Yes. Create multiple Data Cloud Query Setting records and reference them from different component instances.

- Can I restrict who sees the component?

  - Use field/object permissions and the provided permission set. You can also use standard Lightning page visibility rules for components.

- Do I need to deploy code to change queries?
  - No. Queries and behavior are controlled via Custom Metadata records.

## Summary

- Create a Data Cloud Query Setting record with the required fields.
- Drag and configure the List and/or Chart components in Lightning App Builder.
- Assign the permission set to users.
- Optional: Use record-based filtering for context-aware results.

Your solution is now ready for admins to configure and end users to consume on Lightning pages.
