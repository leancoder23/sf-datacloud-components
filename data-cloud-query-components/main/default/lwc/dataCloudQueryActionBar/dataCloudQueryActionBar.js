import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import DataCloudQueryFlowModal from "c/dataCloudQueryFlowModal";

import msgGenericErrorMessage from "@salesforce/label/c.DCQR_Generic_Error_Message";
import singleRowSelectionMessage from "@salesforce/label/c.DCQR_Single_Row_Selection";
import multiRowSelectionMessage from "@salesforce/label/c.DCQR_Multi_Row_Selection";
import actionbarInfoMessage from "@salesforce/label/c.DCQR_Generic_Row_Selection_Info";

const DEFAULT_VISIBLE_BUTTON_COUNT = 3;
const DEFAULT_MODAL_SIZE='medium';

const MSG_SINGLE_ROW_SELECTION="This action requires exactly one selected record.";
const MSG_MULTI_ROW_SELECTION="Select one or more records before proceeding.";
const ERR_GENERIC_MESSAGE = "Oops! Something went wrong. Please contact administrator";
const MSG_ACTION_BAR_INFO=`Select one or more records from the table to activate these buttons. 
Note: that some actions require exactly one selected record, while others support multiple records`;

export default class DataCloudQueryActionBar extends LightningElement {
  @api selectedRecords = [];
  @api actionConfig;
  @api recordId;


  @track _actions = [];
  @track _visibleButtonCount = DEFAULT_VISIBLE_BUTTON_COUNT;
  @track isRefreshVisible=true;

  connectedCallback() {
    this.parseActions();
  }

  // --------------------------- GETTERS -------------------------------

  get actionbarInfo(){
    return actionbarInfoMessage||MSG_ACTION_BAR_INFO;
  }
  get genericErrorMessage(){
    return msgGenericErrorMessage||ERR_GENERIC_MESSAGE;
  }

  get singleSelectionMessage(){
    return singleRowSelectionMessage||MSG_SINGLE_ROW_SELECTION;
  }

  get multiRowSelectionMessage(){
    return multiRowSelectionMessage||MSG_MULTI_ROW_SELECTION;
  }

  //Dynamically inject disabled and tooltip state into actions
  get processedActions() {
    if (!this.hasActions) return [];
    const selectedCount = this.selectedRecords ? this.selectedRecords.length : 0;

    return this._actions.map((action) => {
      let isDisabled = false;
      let tooltipText = action.label;

      // Default to "multiple" if no mode is provided, to ensure backward compatibility
      const mode = action.selectionMode || "multiple";

      if (mode === "single") {
        isDisabled = selectedCount !== 1;
        tooltipText = isDisabled
            ? this.singleSelectionMessage
            : action.label;
      } else if (mode === "multiple") {
        isDisabled = selectedCount === 0;
        tooltipText = isDisabled
            ? this.multiRowSelectionMessage
            : action.label;
      }
      // If mode === "none", isDisabled remains false

      return {
        ...action,
        disabled: isDisabled,
        tooltip: tooltipText,
      };
    });
  }

  get hasActions() {
    return this._actions && this._actions.length > 0;
  }

  get visibleActions() {
    if (!this.hasActions) return [];
    return this.processedActions.slice(0, this._visibleButtonCount);
  }

  get overflowActions() {
    if (!this.hasActions) return [];
    return this.processedActions.slice(this._visibleButtonCount);
  }

  get hasOverflowActions() {
    return this.overflowActions.length > 0;
  }

  // --------------------------- CONFIG PARSING ----------------------------

  parseActions() {
    if (!this.actionConfig) {
      this._actions = [];
      return;
    }
    try {
      const config =
        typeof this.actionConfig === "string"
          ? JSON.parse(this.actionConfig)
          : this.actionConfig;
      this._actions = config.actions || [];
      if (config.visibleButtonCount !== undefined) {
        this._visibleButtonCount =
          parseInt(config.visibleButtonCount, 10) || DEFAULT_VISIBLE_BUTTON_COUNT;
      }

    } catch (e) {
      console.error("Invalid action config JSON:", e);
      this._actions = [];
    }
  }

  // --------------------------- ACTION HANDLERS ---------------------------

  handleActionClick(event) {
    const flowApiName = event.target.dataset.flowName;
    this.executeAction(flowApiName);
  }

  handleOverflowActionSelect(event) {
    const flowApiName = event.detail.value;
    this.executeAction(flowApiName);
  }

  handleRefreshClick() {
    this.dispatchEvent(new CustomEvent("refresh"));
  }

  async executeAction(flowApiName) {
    const action = this._actions.find((a) => a.flowApiName === flowApiName);

    if (!action) {
      console.log(`No action configuration found for the flow: ${flowApiName}`)
      return;
    }

    const records = this.selectedRecords || [];

    const validation = this.validateSelection(records, action);

    if (!validation.valid) {
      this.dispatchEvent(
        new ShowToastEvent({
          message: validation.message,
          variant: "warning",
        })
      );
      return;
    }
    try {
      const inputVariables = this.buildFlowInputVariables(records, action);

      const result = await DataCloudQueryFlowModal.open({
        label: action.label,
        flowApiName: action.flowApiName,
        flowInputVariables: inputVariables,
        size: action.size||DEFAULT_MODAL_SIZE,
      });
      if (result === "completed" && action.refreshOnComplete) {
        this.dispatchEvent(new CustomEvent("refresh"));
      }
      if(result==="error"){
        throw new Error("Unhandled exception occurred while opening the screen flow")
      }
    } catch (err) {
      console.error("Error launching flow action:", err);
      this.dispatchEvent(
        new ShowToastEvent({
          message: this.genericErrorMessage,
          variant: "error",
          mode:'sticky'
        })
      );
    }
  }

  // ----------------------- SELECTION & FLOW VARIABLE UTILS ----------------

  validateSelection(selectedRecords, action) {
    if (!selectedRecords || selectedRecords.length === 0) {
      return {
        valid: false,
        message: this.multiRowSelectionMessage,
      };
    }
    if (action.selectionMode === "single" && selectedRecords.length > 1) {
      return {
        valid: false,
        message: this.singleSelectionMessage,
      };
    }
    return { valid: true };
  }


  buildFlowInputVariables(selectedRecords, action) {
    const isSingle = action.selectionMode === "single";
    const hasAllMapping = action.inputMappings.some(
      (m) => m.fieldName === "__ALL__",
    );
    let variables = [];

    if (isSingle) {
      const record = this.sanitizeRecord(selectedRecords[0]);
      variables = action.inputMappings.map((mapping) => {
        const type = mapping.type || "String";
        let value;

        if (mapping.fieldName === "__ALL__") {
          value = JSON.stringify(record);
        } else {
          value = this.convertValue(record[mapping.fieldName], type);
        }

        return { name: mapping.flowVariable, type, value };
      });
    } else {
      const projectedRecords = selectedRecords.map((record) => {
        const cleanRecord = this.sanitizeRecord(record);
        if (hasAllMapping) {
          return cleanRecord;
        }
        const obj = {};
        action.inputMappings.forEach((mapping) => {
          obj[mapping.key] = cleanRecord[mapping.fieldName];
        });
        return obj;
      });

      variables = [
        {
          name: action.targetFlowVariable,
          type: "String",
          value: JSON.stringify(projectedRecords),
        },
      ];
    }

    if (action.recordIdFlowVariable && this.recordId) {
      variables.push({
        name: action.recordIdFlowVariable,
        type: "String",
        value: this.recordId,
      });
    }

    return variables.filter((v) => v.value !== null && v.value !== undefined);
  }


  sanitizeRecord(record) {
    const { _key, _row, ...cleanRecord } = record;
    return cleanRecord;
  }

  /**
   * Convert a value to a specific given type
   * @param rawValue value to be converted
   * @param type data type to convert to (Number, Currency,Boolean,Date, DateTime,String)
   * @returns {string|number|*|boolean|null} converted value
   */
  convertValue(rawValue, type) {
    if (rawValue === null || rawValue === undefined) {
      return null;
    }

    switch (type) {
      case "Number":
      case "Currency":
        return Number(rawValue);

      case "Boolean":
        if (typeof rawValue === "boolean") return rawValue;
        if (typeof rawValue === "string")
          return rawValue.toLowerCase() === "true";
        return Boolean(rawValue);

      case "Date":
        return rawValue instanceof Date
          ? rawValue.toISOString().split("T")[0]
          : String(rawValue);

      case "DateTime":
        return rawValue instanceof Date
          ? rawValue.toISOString()
          : String(rawValue);

      case "String":
      default:
        return String(rawValue);
    }
  }
}
