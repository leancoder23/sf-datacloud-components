/**
 * Created by dsingh on 13.10.25.
 */

import { LightningElement,api } from 'lwc';
import customUrl from "./customUrl.html";

export default class DataCloudCustomUrlProvider extends LightningElement {

    @api
      getDataTypes() {
        return {
          customDataCloudUrl: {
            template: customUrl,
            standardCellLayout: true,
            typeAttributes: ["label","objectName"],
          },
          // Other custom types here
        }

}

  handleClick(event){
            let {record,object} = event.currentTarget.dataset;
             const clickEvent = new CustomEvent("datacloudrecordclick", {
                    composed: true,
                    bubbles: true,
                    cancelable: true,
                    detail: {
                      recordId: record,
                      objectApi: object
                    },
                });
                console.log('click from provider', clickEvent.detail);
                this.dispatchEvent(clickEvent);
        }

}