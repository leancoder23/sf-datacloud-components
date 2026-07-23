import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import {
    executeDataCloudQuery,
    PageRefTracker
} from 'c/dataCloudQueryService';

import msgDataNotFound from '@salesforce/label/c.DCQR_Data_Not_Found';
import msgGenericErrorMessage from '@salesforce/label/c.DCQR_Generic_Error_Message';

const MAX_RECORDS = 100;

const TYPE_RENDERERS = {
    date: 'date',
    datetime: 'datetime',
    text: 'text',
    longtext: 'text',
    currency: 'currency',
    number: 'number',
    integer: 'number',
    email: 'email',
    url: 'url',
    richtext: 'richtext',
    boolean: 'boolean'
};

function normalizeBoolean(value) {
    return value === true || value === 'true';
}

function resolvePath(obj, path) {
    if (!obj || !path) return null;
    return path.split('.').reduce((cur, key) => cur?.[key], obj);
}

export default class DataCloudQueryResultRecord extends LightningElement {

    @api title;
    @api subtitle;
    @api titleHelpText;
    @api iconName;
    @api hideHeader = false;
    @api querySettingId;
    @api recordConfig;
    @api recordId;

    formattedData = [];
    isLoading = false;
    error;

    _pageTracker = new PageRefTracker();

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        this.pageRef = pageRef;
        this._pageTracker.update(pageRef, this.recordId, () => this.refreshData());
    }

    connectedCallback() {
        this.loadInitialData();
    }

    // --- Getters ---

    get noDataMessage() {
        return msgDataNotFound;
    }

    get genericErrorMessage() {
        return msgGenericErrorMessage;
    }

    get hasData() {
        return this.formattedData.length > 0;
    }

    get showHeader() {
        return !normalizeBoolean(this.hideHeader);
    }

    get effectiveIconName() {
        return this.showHeader ? this.iconName : null;
    }

    // --- Data Loading ---

    @api
    async refreshData() {
        this.formattedData = [];
        this.error = null;
        await this.loadInitialData();
    }

    async loadInitialData() {
        this.isLoading = true;
        this.error = null;

        try {
            if (!this.querySettingId) {
                throw new Error(
                    'Query Setting Identifier is not configured. Please set the Query Setting Id in the component properties.'
                );
            }

            await this._pageTracker.ready;
            const effectiveRecordId = this._pageTracker.resolve(this.recordId, this.pageRef);

            const result = await executeDataCloudQuery(
                this.querySettingId,
                effectiveRecordId,
                MAX_RECORDS
            );

            this.formattedData = this.buildLayout(
                result?.records || []
            );
        } catch (e) {
            this.handleError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Layout Builder ---

    buildLayout(records) {
        const sections = this.parseConfig();
        if (!records.length || !sections.length) return [];

        return records.map((record, i) => {
            const id = record.Id || record.ssot__Id__c || `record-${i}`;
            return {
                id,
                sections: sections.map((section, si) => {
                    const sectionName = `${id}-s${si}`;
                    return {
                        key: `${id}-section-${si}`,
                        label: section.label,
                        icon: section.icon,
                        isAccordion: section.isAccordion,
                        activeSectionName: section.isCollapsed ? [] : [sectionName],
                        sectionName,
                        fields: (section.fields || []).map(field =>
                            this.buildField(field, record, sectionName, section.colSize)
                        )
                    };
                })
            };
        });
    }

    parseConfig() {
        try {
            if (!this.recordConfig) return [];

            const config = typeof this.recordConfig === 'string'
                ? JSON.parse(this.recordConfig)
                : this.recordConfig;

            return (config?.sections ?? []).map(section => {
                const columns = Number(section.columns) || 1;
                return {
                    ...section,
                    columns,
                    colSize: Math.floor(12 / columns),
                    isAccordion: Boolean(section.label),
                    isCollapsed: normalizeBoolean(section.defaultCollapsed)
                };
            });
        } catch (e) {
            this.handleError(e);
            return [];
        }
    }

    buildField(field, record, sectionName, colSize) {
        const type = (field.type || 'text').toLowerCase();
        const typeAttributes = field.typeAttributes || {};
        const labelFieldPath = typeAttributes?.label?.fieldName;

        return {
            key: `${sectionName}-${field.fieldName}`,
            label: field.label,
            fieldHelpText: field.fieldHelpText,
            hasFieldHelpText: Boolean(field.fieldHelpText),
            fieldSize: normalizeBoolean(field.spanFull) ? 12 : colSize,
            value: resolvePath(record, field.fieldName),
            labelOverride: labelFieldPath ? resolvePath(record, labelFieldPath) : null,
            typeAttributes,
            renderer: TYPE_RENDERERS[type] || 'text'
        };
    }

    // --- Error Handling ---

    handleError(error) {
        console.error(error);
        this.error =
            error?.body?.message ||
            error?.message ||
            this.genericErrorMessage;
    }
}
