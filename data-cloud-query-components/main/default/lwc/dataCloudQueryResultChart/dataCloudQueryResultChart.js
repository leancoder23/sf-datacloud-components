import { LightningElement, api, wire } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import { CurrentPageReference } from "lightning/navigation";

import chartjs from "@salesforce/resourceUrl/DCQR_ChartJsLib";

// Import custom labels
import msgGenericErrorMessage from "@salesforce/label/c.DCQR_Generic_Error_Message";
import msgDataNotFound from "@salesforce/label/c.DCQR_Data_Not_Found";

// Import service component methods
import { executeDataCloudQuery, PageRefTracker } from "c/dataCloudQueryService";

import { chartFunctionRegistry, hydrateChartConfig } from "./chartUtility.js";


const DATA_SET_MAX_SIZE = 800;
const RECORD_CONTEXT_ERROR_PREFIX = '[RECORD_CONTEXT_ERROR]';

export default class DataCloudQueryResultChart extends LightningElement {
  // --- Public Properties (from App Builder) ---
  @api querySettingId;
  @api chartTitle;
  @api chartConfig;
  @api recordId;

  @api height;
  @api width;

  @api chartHelpText;
  @api chartSubtitle;

  // --- Private State ---
  isLoading;
  error;
  configInfo;
  chart;

  _chartData;
  _chartJsOptions;
  _finalChartConfig;
  _chartJsLoaded = false;

  _pageTracker = new PageRefTracker();

  // --- Lifecycle Hooks ---

  @wire(CurrentPageReference)
  wiredPageRef(pageRef) {
    this._pageRef = pageRef;
    this._pageTracker.update(pageRef, this.recordId, () => this.handleRefresh());
  }

  connectedCallback() {
   // this.setupTestQuery(); //TODO: remove this before production deployment
    this.loadChartScriptAndChartData();
  }

  renderedCallback() {
    if (this._chartJsLoaded && this._finalChartConfig && !this.chart) {
      this.renderChart(this._finalChartConfig);
    }
  }

  setupTestQuery() {
    const urlParams = new URLSearchParams(window.location.search);
    if (
      !window.location.pathname.includes("c__dataCloudQueryResultChart") ||
      !urlParams.get("c__test")
    )
      return;

    this.chartTitle = "Test Chart";
    this.querySettingId = "ChartComponentTestQuery";
    this.recordId = "0019V00001SCUL8QAP";
    this.cardHelpText="Test charts...  ";
    this.cardSubtitle="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam nec nisl aliquet, elementum lectus sit amet, suscipit tellus. Curabitur in lacinia augue. Cras at felis a sem euismod blandit. Quisque at odio metus. Proin accumsan euismod hendrerit.";

    // 3. UPDATED CONFIGURATION: Functions replaced by @@FUNC: markers
    this.chartConfig = JSON.stringify({
      type: "bar",
      data: {
        labelsField: "stage",
        datasets: [
          // --- FY -2 ---
          {
            label: "S4S",
            dataField: "fyMinus2_s4sSum",
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            stack: "FY_Minus_2",
            stackLabel: "FY -2", // <-- The generic function will read this!
          },
          {
            label: "PLM",
            dataField: "fyMinus2_plmSum",
            backgroundColor: "rgba(75, 192, 192, 0.5)",
            stack: "FY_Minus_2",
            stackLabel: "FY -2",
          },
          {
            label: "ADV",
            dataField: "fyMinus2_advSum",
            backgroundColor: "rgba(153, 102, 255, 0.5)",
            stack: "FY_Minus_2",
            stackLabel: "FY -2",
          },
          // --- FY -1 ---
          {
            label: "S4S",
            dataField: "fyMinus1_s4sSum",
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            stack: "FY_Minus_1",
            stackLabel: "FY -1", // <-- The generic function will read this!
          },
          {
            label: "PLM",
            dataField: "fyMinus1_plmSum",
            backgroundColor: "rgba(75, 192, 192, 0.5)",
            stack: "FY_Minus_1",
            stackLabel: "FY -1",
          },
          {
            label: "ADV",
            dataField: "fyMinus1_advSum",
            backgroundColor: "rgba(153, 102, 255, 0.5)",
            stack: "FY_Minus_1",
            stackLabel: "FY -1",
          },
          // --- CURRENT FY ---
          {
            label: "S4S",
            dataField: "fyCurrent_s4sSum",
            backgroundColor: "rgba(54, 162, 235, 0.5)",
            stack: "FY_Current",
            stackLabel: "This FY", // <-- The generic function will read this!
          },
          {
            label: "PLM",
            dataField: "fyCurrent_plmSum",
            backgroundColor: "rgba(75, 192, 192, 0.5)",
            stack: "FY_Current",
            stackLabel: "This FY",
          },
          {
            label: "ADV",
            dataField: "fyCurrent_advSum",
            backgroundColor: "rgba(153, 102, 255, 0.5)",
            stack: "FY_Current",
            stackLabel: "This FY",
          },
        ],
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: "top",
            labels: { filter: "@@FUNC:groupedLegendFilter" },
            onClick: "@@FUNC:groupedLegendClick",
          },

          // NEW: Pass styling options to your generic plugin dynamically!
          stackLabelsPlugin: {
            font: "11px Arial",
            color: "#666",
            paddingTop: 8,
          },
        },
        scales: {
          x: {
            stacked: true,
            title: { display: false, text: "Opportunity Stage" },
            ticks: { padding: 30 }, // Push main labels down to make room
          },
          y: { stacked: true, title: { display: true, text: "Value (EUR)" } },
        },
      },
      plugins: [
        {
          id: "stackLabelsPlugin",
          afterDatasetsDraw: "@@FUNC:drawStackLabels",
        },
      ],
    });

    //console.log('DS config',this.chartConfig)
  }

  // --- Main Data & Rendering Logic ---
  async loadChartScriptAndChartData() {
    try {
      this.isLoading = true;
      await loadScript(this, chartjs);
      if (!window.Chart) {
        throw new Error("Chart js could not be loaded successfully!");
      }
      this._chartJsLoaded = true;

      await this.loadChartData();
    } catch (error) {
      console.log("initial loading error", error);
      this.handleError(error, "Error loading initial data");
    } finally {
      this.isLoading = false;
    }
  }

  async loadChartData() {
    if (!this._chartJsLoaded) {
      console.warn("Chart script not loaded yet. Aborting data fetch.");
      return;
    }
    this.error = null;
    this.configInfo = null;
    this.clearChartState();

    // Step 1: Validate and parse config template
    const configTemplate = this.parseAndValidateConfig();

    // Step 2: Fetch data
    const records = await this.fetchChartData();

    // Step 3: Transform and merge data into the standard Chart.js structure
    if (records && records.length > 0) {
      this._finalChartConfig = this.transformDataForChart(
        records,
        configTemplate,
      );
    }
  }

  parseAndValidateConfig() {
    if (!this.querySettingId || !this.chartConfig) {
      throw new Error("Query Setting Id and Chart Configuration are required.");
    }

    let config;
    try {
      config = JSON.parse(this.chartConfig);
    } catch (parseError) {
      console.error("Chart Config JSON parse error:", parseError);
      throw new Error(
        `Invalid Chart Configuration JSON: ${parseError.message}`,
      );
    }

    // --- BACKWARD COMPATIBILITY BLOCK ---
    if (config.dataMap) {
      const { dataMap, ...restOfConfig } = config;
      if (!restOfConfig.data) restOfConfig.data = {};
      if (dataMap.labelField)
        restOfConfig.data.labelsField = dataMap.labelField;

      if (dataMap.dataFields && Array.isArray(dataMap.dataFields)) {
        const dataFieldLabels = dataMap.dataFieldLabels || {};
        const bgColors = [
          "rgba(54, 162, 235, 0.5)",
          "rgba(255, 99, 132, 0.5)",
          "rgba(255, 206, 86, 0.5)",
          "rgba(75, 192, 192, 0.5)",
          "rgba(153, 102, 255, 0.5)",
          "rgba(255, 159, 64, 0.5)",
        ];
        const borderColors = [
          "rgba(54, 162, 235, 1)",
          "rgba(255, 99, 132, 1)",
          "rgba(255, 206, 86, 1)",
          "rgba(75, 192, 192, 1)",
          "rgba(153, 102, 255, 1)",
          "rgba(255, 159, 64, 1)",
        ];

        restOfConfig.data.datasets = dataMap.dataFields.map((field, index) => {
          return {
            label: dataFieldLabels[field] || field,
            dataField: field,
            backgroundColor:
              dataMap.backgroundColor || bgColors[index % bgColors.length],
            borderColor:
              dataMap.borderColor || borderColors[index % borderColors.length],
            borderWidth: 1,
          };
        });
      }
      config = restOfConfig;
    }
    // --- END BACKWARD COMPATIBILITY ---

    if (
      !config.data ||
      !config.data.datasets ||
      !Array.isArray(config.data.datasets)
    ) {
      throw new Error(
        "Chart Config JSON must include a standard 'data.datasets' array or a valid legacy 'dataMap'.",
      );
    }

    return config;
  }

  async fetchChartData() {
    try {
      await this._pageTracker.ready;
      const effectiveRecordId = this._pageTracker.resolve(this.recordId, this._pageRef);

      const initialResult = await executeDataCloudQuery(
        this.querySettingId,
        effectiveRecordId,
        DATA_SET_MAX_SIZE,
      );
      const { totalRowCount, records } = initialResult;

      if (totalRowCount === 0) return [];

      if (totalRowCount > DATA_SET_MAX_SIZE) {
        throw new Error(
          "Returned data set size is greater than maximum allowed data set size for this component, please contact administrator to adjust the query",
        );
      }
      return records;
    } catch (fetchError) {
      throw new Error(
        `Error in fetching chart data: ${fetchError.body?.message || fetchError.message}`,
      );
    }
  }

  async handleRefresh() {
    try {
      this.isLoading = true;
      await this.loadChartData();
    } catch (error) {
      this.handleError(error, "Error refreshing chart data");
    } finally {
      this.isLoading = false;
    }
  }

  // --- Data Transformation---
  transformDataForChart(records, configTemplate) {
    let finalConfig = JSON.parse(JSON.stringify(configTemplate));

    if (finalConfig.data.labelsField) {
      finalConfig.data.labels = records.map(
        (record) => record[finalConfig.data.labelsField],
      );
      delete finalConfig.data.labelsField;
    }

    const defaultColors = [
      "rgba(54, 162, 235, 0.7)",
      "rgba(255, 99, 132, 0.7)",
      "rgba(255, 206, 86, 0.7)",
      "rgba(75, 192, 192, 0.7)",
      "rgba(153, 102, 255, 0.7)",
      "rgba(255, 159, 64, 0.7)",
    ];

    finalConfig.data.datasets.forEach((dataset, index) => {
      if (dataset.dataField) {
        dataset.data = records.map((record) => record[dataset.dataField]);
        delete dataset.dataField;
      }
      if (!dataset.backgroundColor) {
        dataset.backgroundColor = defaultColors[index % defaultColors.length];
      }
    });

    // ==========================================
    // 4. HYDRATE THE CONFIG
    // Just before returning, we hydrate all function string markers!
    // ==========================================
    finalConfig = hydrateChartConfig(finalConfig, chartFunctionRegistry);

    return finalConfig;
  }

  // --- Chart Rendering---
  renderChart(chartJsConfig) {
    const canvas = this.template.querySelector("canvas.chart");
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (this.chart) {
      this.chart.destroy();
    }

    this.chart = new window.Chart(ctx, chartJsConfig);
  }

  // --- Helper Methods ---
  clearChartState() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
    this._finalChartConfig = null;
  }

  handleError(error, contextMessage = null) {
    const errorMessage = error?.body?.message || error?.message;
    if (errorMessage?.includes(RECORD_CONTEXT_ERROR_PREFIX)) {
      const idx = errorMessage.indexOf(RECORD_CONTEXT_ERROR_PREFIX);
      this.configInfo = errorMessage.substring(idx + RECORD_CONTEXT_ERROR_PREFIX.length).trim();
      this.clearChartState();
      this.isLoading = false;
      return;
    }
    console.error(contextMessage || "An error occurred:", errorMessage, error);
    this.error = (contextMessage ? `${contextMessage}: ` : "") + errorMessage;
    this.clearChartState();
    this.isLoading = false;
  }

  // --- Getters ---
  get hasConfigInfo() {
    return Boolean(this.configInfo);
  }
  get noDataMessage() {
    return msgDataNotFound;
  }
  get genericErrorMessage() {
    return msgGenericErrorMessage;
  }
  get showNoDataMessage() {
    return !this.isLoading && !this._finalChartConfig;
  }
  get chartContainerStyle() {
    const height = this.height
      ? String(this.height).replace(/[^0-9]/g, "")
      : "40";
    const width = this.width ? String(this.width).replace(/[^0-9]/g, "") : "80";
    return `position: relative; height:${height}vh; width:${width}vw`;
  }
}