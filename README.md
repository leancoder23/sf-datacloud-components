# Data Cloud Query Components

Salesforce Lightning Web Components for querying and visualizing Data Cloud results. Execute ANSI SQL queries against Data Cloud and display results as interactive tables, charts, or record detail views — all configurable through Custom Metadata and Lightning App Builder with no code required.

Supports two pluggable backends:

- **Data Cloud CDP** — Native platform APIs (requires companion org connection)
- **Data Cloud REST API** — Via Named Credential (no companion org required)

## Components

| Component | Description |
|-----------|-------------|
| **dataCloudQueryResultList** | Sortable, searchable, paginated data table with custom column types (record links, popovers), Flow action buttons, CSV-style filtering, and lazy-loaded pagination |
| **dataCloudQueryResultChart** | Interactive charts (bar, line, pie, doughnut, polar area, radar, stacked) powered by Chart.js with full Chart.js configuration support |
| **dataCloudQueryResultRecord** | Section-based record detail view with typed field rendering (date, currency, email, URL, rich text, boolean), collapsible accordions, and per-record Flow actions |

## Quick Start

1. Deploy the source to your org:

```bash
sf project deploy start -o <org-alias>
sf org assign permset -n DataCloudQueryServicePermission -o <org-alias>
```

2. Upload required static resources (`DCQR_ChartJsLib`, `DCQR_PopperJsLib`, `DCQR_ModelFlowOverride`).

3. Create a `QueryDefault` record in `DataCloudQuerySetting__mdt` with your org's default Dataspace and WorkloadName.

4. Create query-specific `DataCloudQuerySetting__mdt` records with your SQL queries.

5. Add the components to any Lightning page via App Builder and configure the `querySettingId` property.

## Documentation

- **[Admin/User Guide](docs/README.user.md)** — Configuration reference, property descriptions, JSON configuration examples, and troubleshooting for system administrators.
- **[Developer Guide](docs/README.dev.md)** — Architecture, Apex service reference, LWC technical details, installation, testing, and deployment.
