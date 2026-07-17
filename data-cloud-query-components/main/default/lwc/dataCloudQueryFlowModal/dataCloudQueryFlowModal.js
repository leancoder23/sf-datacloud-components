import { api } from "lwc";
import LightningModal from "lightning/modal";
import { loadStyle } from 'lightning/platformResourceLoader';
import modalFlowOverride from '@salesforce/resourceUrl/DCQR_ModelFlowOverride';


export default class DataCloudQueryFlowModal extends LightningModal {
  @api flowApiName;
  @api flowInputVariables = [];
  @api label = "Action";

  handleFlowStatusChange(event) {
    const { status } = event.detail;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.close("completed");
    } else if (status === "ERROR") {
      console.error("The flow failed due to an unhandled exception.",event.detail);
      this.close("error");
    }
  }

  handleClose() {
    this.close("cancelled");
  }

  connectedCallback() {

    // Inject the CSS to fix the flow footer and body
    loadStyle(this, modalFlowOverride)
        .then(() => {
          console.log('Flow internal styling overridden successfully.');
        })
        .catch(error => {
          console.error('Error loading flow CSS', error);
        });
  }
}
