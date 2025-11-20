import { LightningElement, api } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import chartjs from "@salesforce/resourceUrl/DCQR_ChartJsLib";

// Import custom labels
import msgGenericErrorMessage from "@salesforce/label/c.DCQR_Generic_Error_Message";
import msgDataNotFound from "@salesforce/label/c.DCQR_Data_Not_Found";

// Import service component methods
import {executeDataCloudQuery} from "c/dataCloudQueryService";

const DATA_SET_MAX_SIZE=800;

// Fallback messages for labels
const MSG_DATA_NOT_FOUND='No Data found!';
const ERR_GENERIC_MESSAGE='Oops! Something went wrong. Please contact administrator';

export default class DataCloudQueryResultChart extends LightningElement {
  // --- Public Properties (from App Builder) ---
  @api querySettingId;
  @api chartTitle;
  @api chartConfig;
  @api recordId; // Automatically populated on a record page

  @api height;
  @api width;

  // --- Private State ---
    isLoading;
    error;
    chart;

    _chartData;
    _chartJsOptions;
    _chartJsLoaded = false;

  // --- Lifecycle Hooks ---

   connectedCallback() {
      // Load the script once, then fetch data
      this.setupTestQuery(); //TODO: remove this before production deployment
      this.loadChartScriptAndChartData();
    }

      renderedCallback() {

        if (this._chartJsLoaded && this._chartData && !this.chart) {
          this.renderChart(this._chartData, this._chartJsOptions);
        }
      }

   setupTestQuery(){

       const urlParams = new URLSearchParams(window.location.search);
           if (
             !window.location.pathname.includes("c__dataCloudQueryResultChart") ||
             !urlParams.get("c__test")
           ) return; //do not process if not accessed via url as test

            this.chartTitle='Test Chart';

             this.querySettingId='ChartComponentTestQuery';
             this.recordId='0019V00000q2bIXQAY';

             this.chartConfig=`{"type":"bar",
                             "dataMap":{
                             "labelField":"stage",
                             "dataFields":["s4sCount","plmCount"]
                             },
                             "options":{"responsive":true,
                             "plugins":{"legend":{"position":"top"}}}}`;
        }

// --- Main Data & Rendering Logic ---
    async loadChartScriptAndChartData(){

      try{
          this.isLoading=true;
        await loadScript(this, chartjs);
          if(!window.Chart){
              throw new Error('Chart js could not be loaded successfully!')
      }
        this._chartJsLoaded = true;

      await this.loadChartData();

      }catch(error){
          console.log('initial loading error',error);
        this.handleError(error, "Error loading charting library");
      }finally{
          this.isLoading=false;
      }

    }

    /**
     * This method orchestrates the validation, fetching,
     * and transformation of data.
     */
    async loadChartData() {
      // Prevent rendering attempts until script is loaded
      if (!this._chartJsLoaded) {
        console.warn("Chart script not loaded yet. Aborting data fetch.");
        return;
      }
      this.error = null; // Clear previous errors on fetch
      this.clearChartState(); // Clear old chart/data before fetching new

      // Step 1: Validate and parse config
      const { dataMap, chartJsOptions } = this.parseAndValidateConfig();

      // Step 2: Fetch data
      const records = await this.fetchChartData();

      // Step 3: Transform and store data for renderedCallback
      if (records.length>0) {
          this._chartData = this.transformDataForChart(records, dataMap);
          this._chartJsOptions = chartJsOptions;
          // The component will now re-render, and renderedCallback will
          // pick up the data and draw the chart.
      }

    }

    /**
     * Validate the chartConfig property. Throws error If config is invalid
     * @returns {Object} { dataMap, chartJsOptions }
     */
    parseAndValidateConfig() {
      if (!this.querySettingId || !this.chartConfig) {
        throw new Error("Query Setting Id and Chart Configuration are required.");
      }

      let config;
      try {
        config = JSON.parse(this.chartConfig);
      } catch (parseError) {
        console.error("Chart Config JSON parse error:", parseError);
        throw new Error(`Invalid Chart Configuration JSON: ${parseError.message}`);
      }

      const { dataMap, ...chartJsOptions } = config;

      if (!dataMap || !dataMap.labelField || !dataMap.dataFields) {
        throw new Error(
          "Chart Config JSON must include a 'dataMap' object with 'labelField' and 'dataFields' properties."
        );
      }

      return { dataMap, chartJsOptions };
    }

    /**
    * fetch data from the service and check row counts. Throws error If data set is too large or query fails.
     * @returns {Array} The records array.
     */
    async fetchChartData() {
      try{
      const initialResult = await executeDataCloudQuery(
        this.querySettingId,
        this.recordId,
        DATA_SET_MAX_SIZE
      );
         const { totalRowCount, records } = initialResult;

            if (totalRowCount === 0) {
              return []; // No data to chart
            }

            if (totalRowCount > DATA_SET_MAX_SIZE) {
              throw new Error(
                "Returned data set size is greater than maximum allowed data set size for this component, please contact administrator to adjust the query"
              );
            }

            return records;
      }catch(fetchError){
       throw new Error(`Error in fetching chart data: ${fetchError.body?.message || fetchError.message}`);
      }

    }

    // --- Event Handlers ---

    /**
     * Handles the click on the refresh button.
     */
    async handleRefresh() {
      // Re-fetch data. `loadChartData` now handles clearing state.
      try{
           this.isLoading=true;
          await this.loadChartData();
      }catch(error){
         this.handleError(error, "Error refreshing chart data");
      }finally{
          this.isLoading=false;
      }

    }


    // --- Data Transformation---
    transformDataForChart(records, dataMap) {
      const labels = records.map((record) => record[dataMap.labelField]);
      const dataFieldLabels = dataMap.dataFieldLabels;
      const backgroundColors = [
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

      const userBgColor = dataMap.backgroundColor;
      const userBorderColor = dataMap.borderColor;

      const datasets = dataMap.dataFields.map((field, index) => {
        return {
          label: (dataFieldLabels ? dataFieldLabels[field] : null) || field,
          data: records.map((record) => record[field]),
          backgroundColor:
            userBgColor || backgroundColors[index % backgroundColors.length],
          borderColor:
            userBorderColor || borderColors[index % borderColors.length],
          borderWidth: 1,
        };
      });

      return { labels, datasets };
    }

    // --- Chart Rendering---
    renderChart(data, options) {
      const canvas = this.template.querySelector("canvas.chart");
      if (!canvas) return; // Guard clause in case DOM isn't ready

      const ctx = canvas.getContext("2d");

      // Destroy existing chart if one exists. This is crucial for re-renders.
      if (this.chart) {
        this.chart.destroy();
      }

      this.chart = new window.Chart(ctx, {
        type: options.type || "bar",
        data: data,
        options: options.options || { responsive: true },
      });
    }

    // --- Helper Methods ---

    /**
     * New: Clears all chart-related state and destroys the chart instance.
     */
    clearChartState() {
      if (this.chart) {
        this.chart.destroy();
        this.chart = null;
      }
      this._chartData = null;
      this._chartJsOptions = null;
    }

    /**
     * New: Centralized error handler.
     * @param {Error} error - The error object.
     * @param {string} [contextMessage] - A user-friendly message for context.
     */
    handleError(error, contextMessage = null) {
      const errorMessage = error.body ? error.body.message : error.message;
      console.error(
        contextMessage || "An error occurred:",
        errorMessage,
        error
      );

      this.error = (contextMessage ? `${contextMessage}: ` : "") + errorMessage;

      // Clear any stale data/chart
      this.clearChartState();
      this.isLoading = false; // Ensure loading spinner stops on error
    }

    // --- Getters ---

    get noDataMessage() {
      return msgDataNotFound || MSG_DATA_NOT_FOUND;
    }

    get genericErrorMessage() {
      return msgGenericErrorMessage || ERR_GENERIC_MESSAGE;
    }

    /**
     * Show no data message when no chart data to show
     */
    get showNoDataMessage() {
      return !this.isLoading && !this._chartData;
    }

    get chartContainerStyle() {
      // Use || for defaults, ensure vh/vw units are present
      const height = this.height ? String(this.height).replace(/[^0-9]/g, '') : "40";
      const width = this.width ? String(this.width).replace(/[^0-9]/g, '') : "80";
      return `position: relative; height:${height}vh; width:${width}vw`;
    }
}
