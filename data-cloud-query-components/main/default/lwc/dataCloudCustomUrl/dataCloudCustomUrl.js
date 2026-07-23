/**
 * Created by dsingh on 13.10.25.
 */

import { LightningElement,api } from 'lwc';

export default class DataCloudCustomUrl extends LightningElement {
    @api label;
    @api recordId;
    @api pageApiName;
    @api objectName;

     handleClick() {
            // Dispatch custom event to parent datatable
            const event = new CustomEvent('navigatetodatacloudrecord', {
                detail: {
                    recordId: this.recordId,
                    objectName: this.objectName,
                    pageApiName:this.pageApiName
                },
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(event);
        }

}