import { LightningElement, api } from "lwc";
import customUrl from "./customUrl.html";
import popoverCell from "./customPopoverCell.html";

export default class DataCloudQueryResultListCustomDataTypesProvider extends LightningElement {


  @api
  getDataTypes() {
    return {
      customRecordLink: {
        template: customUrl,
        standardCellLayout: true,
        typeAttributes: ["label", "objectName","pageApiName"],
      },
      customPopoverCell: {
        template: popoverCell,
        standardCellLayout: true,
        typeAttributes: ["popoverTitle", "popoverIcon","popoverWidth","popoverHeight","rowData","itemInfo"],
      },
      // Other custom types here
    };
  }

}
