import { LightningElement, api, track,wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin,CurrentPageReference } from "lightning/navigation";
import {
  executeDataCloudQuery,
  getDataCloudQueryResultData,
  getDataCloudRecordLocalId,
  formatString,
  resolveRecordId
} from "c/dataCloudQueryService";


//CUSTOM LABELS
import msgShowingRecordCount from "@salesforce/label/c.DCQR_Showing_Record_Count";
import msgDataNotFound from "@salesforce/label/c.DCQR_Data_Not_Found";
import lblLoadMore from "@salesforce/label/c.DCQR_Load_More";
import msgGenericErrorMessage from "@salesforce/label/c.DCQR_Generic_Error_Message";


const MSG_SHOWING_RECORD_COUNT = "Showing {0} of records {1}.";
const MSG_DATA_NOT_FOUND = "No Data found!";
const LABEL_LOAD_MORE = "Load More";
const ERR_GENERIC_MESSAGE =
  "Oops! Something went wrong. Please contact administrator";

export default class DataCloudQueryResultList extends NavigationMixin(
  LightningElement
) {
  //--------------------------------------------------------------------------
  // ---- CONFIGURATION PROPERTIES (Set by Admin in Lightning App Builder) ----
  //--------------------------------------------------------------------------
  @api title = "Data Cloud Query Results";
  @api iconName = "standard:live_data";
  @api pageSize = 20;

  @api querySettingId;

  @api titleHelpText;
  @api subtitle;

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


  // ---------------------- LOCAL STATE PROPERTIES -----------------------

  @api recordId; // Automatically populated if on a record page.

  @track data = [];
  @track columns = [];
  @track selectedRows = [];
  isLoading = false;

  error;
  initialRender = true;
  queryService;

  // --- For Pagination ---
  queryId;
  totalRows = 0;
  rowsLoaded = 0;
  hasMoreData = true;

  @wire(CurrentPageReference) _pageRef;

  // -------------------------- LIFECYCLE HOOKS -----------------------------

  renderedCallback() {
    if (!this.initialRender) return;
    this.initialRender = false;

    this.parseColumnConfig();
    this.loadInitialData();
  }

  // --------------------------- GETTERS -------------------------------

  get showViewMoreButton() {
    return !this.isLoading && this.hasMoreData;
  }

  get noDataMessage() {
    return msgDataNotFound || MSG_DATA_NOT_FOUND;
  }

  get loadMoreButtonLabel() {
    return lblLoadMore || LABEL_LOAD_MORE;
  }

  get genericErrorMessage() {
    return msgGenericErrorMessage || ERR_GENERIC_MESSAGE;
  }

  get showRecordCount() {
    return formatString(
      msgShowingRecordCount || MSG_SHOWING_RECORD_COUNT,
      this.rowsLoaded,
      this.totalRows
    );
  }

  get hasNoActionConfig() {
    return !this.actionConfig;
  }

  // --------------------------- DATA METHODS -------------------------------

  @api
  async refreshData() {
    this.resetState();
    await this.loadInitialData();
  }

  async handleDataCloudRecordClick(event) {
    const { recordId, objectName } = event.detail;
    try {
      this.isLoading = true;

      const localRecordId = await getDataCloudRecordLocalId(
        recordId,
        objectName
      );

      const pageRef = {
        type: "standard__recordPage",
        attributes: {
          recordId: localRecordId,
          actionName: "view",
          objectApiName: objectName,
        },
      };

      const url = await this[NavigationMixin.GenerateUrl](pageRef);
      console.log("url", url);

      window.open(url, "__blank");
    } catch (error) {
      console.log("Record Link Error", error, error.message);
      this.showErrorToast(this.genericErrorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  async loadInitialData() {
    try {
      this.isLoading = true;

      if (!this.querySettingId) {
        console.log("throwing error");
        throw new Error(
          "Query Setting Identifier is not configured. Please set the Query Setting Id in the component properties."
        );
      }

      const effectiveRecordId = resolveRecordId(this.recordId, this._pageRef);

      const result = await executeDataCloudQuery(
        this.querySettingId,
        effectiveRecordId,
        this.pageSize
      );

      this.data = this.addKeyToData(result.records);
      this.queryId = result.queryId;
      this.totalRows = result.totalRowCount;
      this.rowsLoaded = result.records.length;
      this.hasMoreData = this.rowsLoaded < this.totalRows;
    } catch (error) {
      this.handleError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async handleViewMore(event) {
    if (!this.hasMoreData) return;

    this.isLoading = true;
    try {
      const result = await getDataCloudQueryResultData(
        this.querySettingId,
        this.queryId,
        this.rowsLoaded,
        this.pageSize
      );

      if (result.records.length > 0) {
        const newData = this.addKeyToData(result.records, this.rowsLoaded);
        this.data = [...this.data, ...newData];
        this.rowsLoaded += result.records.length;
        this.hasMoreData = this.rowsLoaded < this.totalRows;
      } else {
        this.hasMoreData = false;
      }
    } catch (error) {
      this.handleError(error);
    } finally {
      this.isLoading = false;
    }
  }

  // -------------------------- ROW SELECTION ------------------------------

  handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows;
  }

  // -------------------------- HELPER METHODS ------------------------------

  parseColumnConfig() {
    try {
      if (this.columnConfig) {
        const columns = JSON.parse(this.columnConfig);

        columns.forEach((col) => {
          if (col.type == "customPopoverCell") {
            if (!col.typeAttributes) {
              throw new Error(
                "typeAttributes are required for customPopoverCell type"
              );
            }
            col.typeAttributes.rowData = { fieldName: "_row" };
          }
        });

        this.columns = columns;
      }
    } catch (e) {
      this.columns = [];
      throw new Error(
        `Error parsing column configuration JSON. Please check the format. Details: ${e.message}`
      );
    }
  }

  addKeyToData(records, startIndex = 0) {
    return records.map((record, index) => ({
      ...record,
      _key: `row-${startIndex + index}`,
      _row: record,
    }));
  }

  showErrorToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message: message,
        variant: "error",
        mode: "sticky",
      })
    );
  }

  resetState() {
    this.data = [];
    this.selectedRows = [];
    this.isLoading = false;
    this.error = null;
    this.totalRows = 0;
    this.rowsLoaded = 0;
  }

  handleError(error) {
    console.log("handling error");
    console.error("Data Cloud Query Result List Error:", error);

    this.error = error.body ? error.body.message : error.message;
  }
}
