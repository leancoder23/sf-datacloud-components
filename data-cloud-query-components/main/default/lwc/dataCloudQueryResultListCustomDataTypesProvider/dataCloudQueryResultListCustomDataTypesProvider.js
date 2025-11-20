import { LightningElement, api } from "lwc";
import customUrl from "./customUrl.html";
import popoverCell from "./customPopoverCell.html";

export default class DataCloudQueryResultListCustomDataTypesProvider extends LightningElement {


  @api
  getDataTypes() {
    return {
      customDataCloudUrl: {
        template: customUrl,
        standardCellLayout: true,
        typeAttributes: ["label", "objectName"],
      },
      customPopoverCell: {
        template: popoverCell,
        standardCellLayout: true,
        typeAttributes: ["popoverTitle", "popoverIcon","popoverWidth","popoverHeight","rowData","itemInfo"],
      },
      // Other custom types here
    };
  }

  /*
  handleClick(event) {
    let { record, object } = event.currentTarget.dataset;
    const clickEvent = new CustomEvent("datacloudrecordclick", {
      composed: true,
      bubbles: true,
      cancelable: true,
      detail: {
        recordId: record,
        objectApi: object,
      },
    });
    console.log("click from provider", clickEvent.detail);
    this.dispatchEvent(clickEvent);
  }*/
}
