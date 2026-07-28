import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

// Custom Labels
import msgShowingRecordCount from "@salesforce/label/c.DCQR_Showing_Record_Count";
import msgDataNotFound from "@salesforce/label/c.DCQR_Data_Not_Found";
import msgGenericErrorMessage from "@salesforce/label/c.DCQR_Generic_Error_Message";
import msgShowingTotalRows from "@salesforce/label/c.DCQR_Total_Rows";
import msgSearchPlaceholder from "@salesforce/label/c.DCQR_Search_Placeholder";
import msgSearchFieldsInfo from "@salesforce/label/c.DCQR_Search_Fields_Info";
import msgSearchSortDisabled from "@salesforce/label/c.DCQR_Search_Sort_Disabled";
import msgShowingCurrentPageLabel from "@salesforce/label/c.DCQR_Showing_Current_Page_Label";
import lblShowingPageNumber from "@salesforce/label/c.DCQR_Showing_Page_Numbers";


// Service
import {
  executeDataCloudQuery,
  getDataCloudQueryResultData,
  resolveRecordNavigation,
  formatString,
  PageRefTracker
} from "c/dataCloudQueryService";

// Colocated pure-function helpers
import {
  computeTotalPages, getPageBounds, getPageSlice,
  filterByColumns, sortData, addKeyToData, debounce,
} from "./dataUtils";

const SEARCH_DEBOUNCE_MS = 300;
const RECORD_CONTEXT_ERROR_PREFIX = '[RECORD_CONTEXT_ERROR]';

export default class DataCloudQueryResultList extends NavigationMixin(LightningElement) {
  //--------------------------------------------------------------------------
  // ---- CONFIGURATION PROPERTIES (Set by Admin in Lightning App Builder) ----
  //--------------------------------------------------------------------------
  @api title = "Data Cloud Query Results";
  @api iconName = "standard:live_data";
  @api pageSize = 20;
  @api querySettingId;
  @api titleHelpText;
  @api subtitle;
  @api recordId;

  /**
   * The JSON configuration for the lightning-datatable columns.
   * Example: [{"label":"First Name", "fieldName":"FirstName__c"}, {"label":"Last Name", "fieldName":"LastName__c"}]
   */
  @api columnConfig;

  /**
   * JSON configuration for action buttons that invoke Salesforce Flows.
   * Passed through to the c-data-cloud-query-action-bar child component.
   */
  @api actionConfig;

  /**
   * Maximum number of server-side rows for which client-side search and sort
   * are allowed. When serverTotalRows exceeds this threshold, both features
   * are disabled to avoid fetching the entire dataset to the browser.
   */
  @api maxClientProcessingRows = 5000;

  // ---------------------- LOCAL STATE PROPERTIES -----------------------

  data = [];
  columns = [];
  selectedRows = [];
  isLoading = false;
  error;
  configInfo;

  // Pagination state
  queryId;
  serverTotalRows = 0;
  currentPage = 1;

  /**
   * masterData — raw server records, accumulated across lazy-loaded pages.
   * processedData  — filtered + sorted data that feeds the table.
   */
  masterData = [];

  processedData = [];

  // Sorting state
  sortDirection = "asc";
  sortedBy;

  // Search state
  searchTerm = "";

  // Debounced search — created once, bound to instance
  _debouncedSearch = debounce(() =>  this.withAllData(this.applyFilter), SEARCH_DEBOUNCE_MS);

  _pageTracker = new PageRefTracker();

  // -------------------------- LIFECYCLE HOOKS -----------------------------

  @wire(CurrentPageReference)
  wiredPageRef(pageRef) {
    this.pageRef = pageRef;
    this._pageTracker.update(pageRef, this.recordId, () => this.refreshData());
  }

  connectedCallback() {
    this.parseActionConfig();
    this.loadInitialData();
  }

  disconnectedCallback() {
    this._debouncedSearch.cancel();
  }

  // =======================================================================
  //  DERIVED STATE GETTERS
  // =======================================================================

  /**
   * Once all server data is loaded, processedData.length is the
   * accurate count (filtered or not). During lazy-loading phase,
   * fall back to serverTotalRows so pagination shows all pages.
   */
  get totalRows() {
    return this.masterData.length >= this.serverTotalRows
      ? this.processedData.length
      : this.serverTotalRows;
  }

  // =======================================================================
  //  LABEL GETTERS
  // =======================================================================

  get noDataMessage() {
    return msgDataNotFound;
  }

  get genericErrorMessage() {
    return msgGenericErrorMessage;
  }

  get footerRecordInfo() {
    const { startRecord, endRecord } = getPageBounds(
      this.currentPage,
      this.pageSize,
      this.totalRows,
    );
    let info = formatString(
      msgShowingRecordCount,
      startRecord,
      endRecord,
      this.totalRows,
    );
    if (this.totalRows < this.serverTotalRows) {
      info += ` | ${formatString(msgShowingTotalRows, this.serverTotalRows)}`;
    }
    return info;
  }

  get searchPlaceholderText() {
    return msgSearchPlaceholder;
  }

  // =======================================================================
  //  CONDITIONAL / DISPLAY GETTERS
  // =======================================================================

  get hasNoActionConfig() {
    return !this.parsedActionConfig;
  }

  parseActionConfig() {
    if (!this.actionConfig) {
      this.parsedActionConfig = null;
      return;
    }
    try {
      this.parsedActionConfig = typeof this.actionConfig === 'string'
        ? JSON.parse(this.actionConfig)
        : this.actionConfig;
    } catch (e) {
      console.error('Invalid action config JSON:', e);
      this.parsedActionConfig = null;
    }
  }

  get hasConfigInfo() {
    return Boolean(this.configInfo);
  }

  get hasNoData() {
    return !this.isLoading && !this.error && !this.configInfo && !this.hasActualData;
  }

  get hasActualData() {
    return this.serverTotalRows > 0;
  }

  get showPagination() {
    return this.totalRows > this.pageSize;
  }

  get isSearchSortDisabled() {
    return this.serverTotalRows > this.maxClientProcessingRows;
  }

  get isSearchDisabled() {
    return this.isSearchSortDisabled;
  }

  get showSearch() {
    return this.columns.some((col) => col.filterable) && this.serverTotalRows > 1;
  }

  get searchHelpText() {
    if (this.isSearchSortDisabled) {
      return formatString(msgSearchSortDisabled, this.maxClientProcessingRows);
    }
    const filterableLabels = this.columns
      .filter((col) => col.filterable)
      .map((col) => col.label)
      .join(", ");
    return formatString(msgSearchFieldsInfo, filterableLabels);
  }

  // =======================================================================
  //  PAGINATION GETTERS
  // =======================================================================

  get totalPages() {
    return computeTotalPages(this.totalRows, this.pageSize);
  }

  get disablePrevious() {
    return this.currentPage <= 1;
  }

  get disableNext() {
    return this.currentPage >= this.totalPages;
  }

  get pageDropdownLabel() {
    return formatString(msgShowingCurrentPageLabel,this.currentPage,this.totalPages);
  }

  get pageOptions() {
    const options = [];
    for (let i = 1; i <= this.totalPages; i++) {
      options.push({
        label: formatString(lblShowingPageNumber,i),
        value: String(i),
        checked: i === this.currentPage,
      });
    }
    return options;
  }

  // =======================================================================
  //  PAGINATION HANDLERS
  // =======================================================================

  handlePreviousPage() {
    if (this.currentPage > 1) {
      this.navigateToPage(this.currentPage - 1);
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.navigateToPage(this.currentPage + 1);
    }
  }

  handlePageJump(event) {
    const pageNumber = Number(event.detail.value);
    if (pageNumber && pageNumber !== this.currentPage) {
      this.navigateToPage(pageNumber);
    }
  }

  // =======================================================================
  //  SEARCH HANDLER
  // =======================================================================

  handleSearchInput(event) {
    if (this.isSearchSortDisabled) return;
    this.searchTerm = event.target.value;
    this._debouncedSearch();
  }

  // =======================================================================
  //  DATA METHODS
  // =======================================================================

  @api
  async refreshData() {
    this.resetState();
    await this.loadInitialData();
  }

  async handleRecordNavigation(event) {
    const { recordId, objectName, pageApiName } = event.detail;
    try {
      this.isLoading = true;

      const navInfo = await resolveRecordNavigation(recordId, objectName);
      let pageRef;

      if (navInfo.navigationType === "LOCAL_RECORD") {
        pageRef = {
          type: "standard__recordPage",
          attributes: {
            recordId: navInfo.resolvedRecordId,
            objectApiName: navInfo.objectApiName,
            actionName: "view",
          },
        };
      } else if (pageApiName) {
        pageRef = {
          type: "standard__navItemPage",
          attributes: { apiName: pageApiName },
          state: { c__recordId: recordId },
        };
      } else if (navInfo.navigationType === "DATA360_RECORD") {
        pageRef = {
          type: "standard__recordPage",
          attributes: {
            recordId: navInfo.resolvedRecordId,
            objectApiName: navInfo.objectApiName,
            actionName: "view",
          },
        };
      }

      if (!pageRef) {
        throw new Error(
          `No navigation target could be resolved for recordId: ${recordId}. Configure a pageApiName or ensure the record is accessible.`,
        );
      }

      const url = await this[NavigationMixin.GenerateUrl](pageRef);

      if (!url) {
        throw new Error(
          `Unable to generate URL for recordId: ${recordId}. The record may not be accessible or the page reference is invalid.`,
        );
      }
      window.open(url, "_blank");
    } catch (error) {
      console.error(`Record Navigation Error -  recordId: ${recordId}, data360Object: ${objectName}, pageApiName:${pageApiName}`, error);
      this.showErrorToast(this.genericErrorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  async loadInitialData() {
    try {
      this.isLoading = true;
      this.configInfo = null;

      if (!this.querySettingId) {
        throw new Error(
          "Query Setting Identifier is not configured. Please set the Query Setting Id in the component properties.",
        );
      }

      await this._pageTracker.ready;
      const effectiveRecordId = this._pageTracker.resolve(this.recordId, this.pageRef);

      const result = await executeDataCloudQuery(
        this.querySettingId,
        effectiveRecordId,
        this.pageSize,
      );

      this.masterData = addKeyToData(result.records);
      this.processedData = this.masterData;
      this.queryId = result.queryId;
      this.serverTotalRows = result.totalRowCount;
      this.parseColumnConfig();
      this.currentPage = 1;
      this.data = getPageSlice(this.processedData, 1, this.pageSize);
    } catch (error) {
      this.handleError(error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Navigate to the requested page, fetching from server if data is not cached.
   */
  async navigateToPage(pageNumber) {
    if (pageNumber === this.currentPage) return;

    try {
      const requiredRecords = Math.min(
        pageNumber * this.pageSize,
        this.serverTotalRows,
      );

      if (this.masterData.length < requiredRecords) {
        this.isLoading = true;
        await this.fetchDataUpTo(requiredRecords);
      }

      this.data = getPageSlice(this.processedData, pageNumber, this.pageSize);
      this.currentPage = pageNumber;
    } catch (error) {
      this.handleError(error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Fetch data from server starting at the current masterData length
   * up to the required count, filling any gaps sequentially.
   */
  async fetchDataUpTo(requiredCount) {
    const offset = this.masterData.length;
    const limit = requiredCount - offset;
    if (limit <= 0) return;

    const result = await getDataCloudQueryResultData(
      this.querySettingId,
      this.queryId,
      offset,
      limit,
    );

    if (result.records.length > 0) {
      const newData = addKeyToData(result.records, this.masterData.length);
      this.masterData = [...this.masterData, ...newData];
      this.processedData = this.masterData;
    }
  }

  handleSort(event) {
    if (this.isSearchSortDisabled) return;
    const { fieldName: sortedBy, sortDirection } = event.detail;
    this.sortedBy = sortedBy;
    this.sortDirection = sortDirection;
    this.withAllData(this.applySort);
  }

  /**
   * Calls a given function after loading all data from server (e.g. applySort, applyFilter)
   * @param fn function to be called
   * @returns {Promise<void>}
   */

  /* @type {Promise} */
  _allDataPromise = null;
  async withAllData(fn){
    this.isLoading = true;
    try {
      if (this.masterData.length < this.serverTotalRows) {
        if (!this._allDataPromise) {
          this._allDataPromise = this.fetchDataUpTo(this.serverTotalRows);
        }
        await this._allDataPromise;
      }
      fn.call(this);
    } catch (error) {
      this.handleError(error);
    } finally {
      this._allDataPromise = null;
      this.isLoading = false;
    }
  }

  // =======================================================================
  //  VIEW PIPELINE
  // =======================================================================

  /**
   * Filters masterData by the current searchTerm and updates processedData,
   * then calls applySort() to maintain sort order on the filtered result.
   */
  applyFilter() {
    //filter only when user types more than 2 character
    if (this.searchTerm && this.searchTerm.trim()!=="" && this.searchTerm.length>2) {
      const searchKey = this.searchTerm.toLowerCase();
      const filterableColumns = this.columns.filter(
        (col) => col.filterable === true,
      );
      this.processedData = filterByColumns(this.masterData, searchKey, filterableColumns);
    } else {
      this.processedData = this.masterData;
    }
    this.applySort();
  }

  /**
   * Sorts processedData in place using the current sortedBy / sortDirection.
   * Resets to page 1 and slices the first page for display.
   */
  applySort() {
    if (this.sortedBy) {
      const columnConfig = this.columns.find(
        (col) => col.fieldName === this.sortedBy,
      );
      this.processedData = sortData(
        this.processedData, this.sortedBy, this.sortDirection, columnConfig,
      );
    }
    this.currentPage = 1;
    this.data = getPageSlice(this.processedData, 1, this.pageSize);
  }

  // =======================================================================
  //  UTILITY METHODS
  // =======================================================================

  parseColumnConfig() {
    try {
      if (this.columnConfig) {
        const columns = JSON.parse(this.columnConfig);

        const disableSorting = this.isSearchSortDisabled;
        columns.forEach((col) => {
          if (col.type === "customPopoverCell") {
            if (!col.typeAttributes) {
              throw new Error(
                "typeAttributes are required for customPopoverCell type",
              );
            }
            col.typeAttributes.rowData = { fieldName: "_row" };
          }
          if (disableSorting) {
            delete col.sortable;
          }
        });

        this.columns = columns;
      }
    } catch (e) {
      this.columns = [];
      throw new Error(
          `Error parsing column configuration JSON. Please check the format. Details: ${e.message}`,
      )
    }
  }

  showErrorToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        message: message,
        variant: "error",
        mode: "sticky",
      }),
    );
  }

  handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows;
  }

  resetState() {
    this.data = [];
    this.masterData = [];
    this.processedData = [];
    this.isLoading = false;
    this.error = null;
    this.configInfo = null;
    this.serverTotalRows = 0;
    this.currentPage = 1;
    this.sortedBy = null;
    this.sortDirection = "asc";
    this.searchTerm = "";
  }

  handleError(error) {
    console.error("Data Cloud Query Result List Error:", error);
    const message = error?.body?.message || error?.message || this.genericErrorMessage;
    if (message.startsWith(RECORD_CONTEXT_ERROR_PREFIX)) {
      this.configInfo = message.substring(RECORD_CONTEXT_ERROR_PREFIX.length).trim();
      return;
    }
    this.error = message;
  }
}
