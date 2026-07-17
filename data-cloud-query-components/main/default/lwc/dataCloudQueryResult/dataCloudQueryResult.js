import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import custom labels
import msgDataNotFound from '@salesforce/label/c.DCQR_Data_Not_Found';
import msgGenericErrorMessage from '@salesforce/label/c.DCQR_Generic_Error_Message';

// Import DataCloudQueryService methods
import { executeDataCloudQuery } from 'c/dataCloudQueryService';

const MSG_DATA_NOT_FOUND = 'No Data found!';
const ERR_GENERIC_MESSAGE = 'Oops! Something went wrong. Please contact administrator';

export default class DataCloudQueryResult extends LightningElement {
    //--------------------------------------------------------------------------
    // ---- CONFIGURATION PROPERTIES (Set by Admin in Lightning App Builder) ----
    //--------------------------------------------------------------------------
    @api title = 'Data Cloud Query Results';
    @api iconName = 'standard:live_data';
    @api querySettingId;
    @api titleHelpText;
    @api subtitle;
    @api layoutColumns = '1'; // Default to 1 column layout
    @api fieldConfig; // JSON config string for field configuration


    // ---------------------- LOCAL STATE PROPERTIES -----------------------
    @api recordId; // Automatically populated if on a record page.

    queryResults = [];
    error;
    isLoading = false;
    parsedConfig = [];
    initialRender = true;

    // -------------------------- LIFECYCLE HOOKS -----------------------------

    connectedCallback() {
        this.parseFieldConfig();
    }

    renderedCallback() {
        if (!this.initialRender) return;
        this.initialRender = false;
        this.loadInitialData();
    }

    // --------------------------- GETTERS -------------------------------

    get noDataMessage() {
        return msgDataNotFound || MSG_DATA_NOT_FOUND;
    }

    get genericErrorMessage() {
        return msgGenericErrorMessage || ERR_GENERIC_MESSAGE;
    }

    get hasResults() {
        return this.queryResults && this.queryResults.length > 0;
    }

    get hasError() {
        return this.error != null;
    }

    get showContent() {
        return !this.isLoading && !this.hasError;
    }

    get layoutItemSize() {
        const columns = parseInt(this.layoutColumns, 10) || 1;
        switch(columns) {
            case 2:
                return '6'; // 6/12 = 50% width for 2 columns
            case 3:
                return '4'; // 4/12 = 33.33% width for 3 columns
            default:
                return '12'; // 12/12 = 100% width for 1 column
        }
    }


    // --------------------------- DATA METHODS -------------------------------

    parseFieldConfig() {
        try {
            if (this.fieldConfig) {
                this.parsedConfig = typeof this.fieldConfig === 'string'
                    ? JSON.parse(this.fieldConfig)
                    : this.fieldConfig;
            }
        } catch (e) {
            this.error = 'Invalid field configuration JSON: ' + e.message;
            console.error('Error parsing field config:', e);
        }
    }

    async loadInitialData() {
        try {
            this.isLoading = true;
            this.error = null;

            if (!this.querySettingId) {
                throw new Error(
                    'Query Setting Identifier is not configured. Please set the Query Setting Id in the component properties.'
                );
            }

            const result = await executeDataCloudQuery(
                this.querySettingId,
                this.recordId,
                100 // Max records for display
            );

            this.queryResults = result.records || [];

        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async refreshData() {
        await this.loadInitialData();
    }



}
