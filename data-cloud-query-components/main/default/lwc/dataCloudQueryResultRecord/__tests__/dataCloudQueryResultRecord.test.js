import { createElement } from '@lwc/engine-dom';
import DataCloudQueryResultRecord from 'c/dataCloudQueryResultRecord';
import { executeDataCloudQuery } from 'c/dataCloudQueryService';

jest.mock('c/dataCloudQueryService', () => ({
    executeDataCloudQuery: jest.fn(),
    PageRefTracker: jest.fn().mockImplementation(() => ({
        ready: Promise.resolve(),
        update: jest.fn(),
        resolve: jest.fn((recordId) => recordId)
    }))
}));

jest.mock('lightning/navigation', () => ({
    CurrentPageReference: jest.fn()
}));

jest.mock(
    '@salesforce/label/c.DCQR_Data_Not_Found',
    () => ({ default: 'No data found' }),
    { virtual: true }
);
jest.mock(
    '@salesforce/label/c.DCQR_Generic_Error_Message',
    () => ({ default: 'Generic error' }),
    { virtual: true }
);

const flushPromises = () => new Promise(process.nextTick);

const MOCK_RECORDS = [
    { Id: '001ABC', FirstName__c: 'John', Email__c: 'john@test.com' },
    { Id: '002DEF', FirstName__c: 'Jane', Email__c: 'jane@test.com' }
];

const RECORD_CONFIG = JSON.stringify({
    sections: [{
        label: 'Details',
        columns: 2,
        fields: [
            { label: 'First Name', fieldName: 'FirstName__c', type: 'text' },
            { label: 'Email', fieldName: 'Email__c', type: 'email' }
        ]
    }]
});

const ACTION_CONFIG = JSON.stringify({
    singleRecordMode: true,
    actions: [
        { label: 'Create Case', flowApiName: 'Create_Case_Flow', selectionMode: 'single', inputMappings: [] }
    ]
});

function createComponent(props = {}) {
    const element = createElement('c-data-cloud-query-result-record', {
        is: DataCloudQueryResultRecord
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe('c-data-cloud-query-result-record', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    describe('refresh button in card header', () => {
        it('renders a standalone refresh button in the card header', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG
            });
            await flushPromises();

            const actionsSlot = element.shadowRoot.querySelector('div[slot="actions"]');
            expect(actionsSlot).not.toBeNull();

            const refreshBtn = actionsSlot.querySelector('lightning-button-icon');
            expect(refreshBtn).not.toBeNull();
            expect(refreshBtn.iconName).toBe('utility:refresh');
        });
    });

    describe('actionConfig integration', () => {
        it('renders action bar per record when actionConfig is provided', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG,
                actionConfig: ACTION_CONFIG
            });
            await flushPromises();

            const actionBars = element.shadowRoot.querySelectorAll('c-data-cloud-query-action-bar');
            expect(actionBars.length).toBe(MOCK_RECORDS.length);
        });

        it('does not render action bar when actionConfig is not provided', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG
            });
            await flushPromises();

            const actionBars = element.shadowRoot.querySelectorAll('c-data-cloud-query-action-bar');
            expect(actionBars.length).toBe(0);
        });

        it('passes the correct actionConfig to each action bar', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: [MOCK_RECORDS[0]] });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG,
                actionConfig: ACTION_CONFIG
            });
            await flushPromises();

            const actionBar = element.shadowRoot.querySelector('c-data-cloud-query-action-bar');
            expect(actionBar.actionConfig).toBe(ACTION_CONFIG);
        });

        it('passes selectedArray with the raw record to each action bar', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: [MOCK_RECORDS[0]] });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG,
                actionConfig: ACTION_CONFIG
            });
            await flushPromises();

            const actionBar = element.shadowRoot.querySelector('c-data-cloud-query-action-bar');
            expect(actionBar.selectedRecords).toEqual([MOCK_RECORDS[0]]);
        });
    });

    describe('buildLayout selectedArray', () => {
        it('includes selectedArray wrapping the raw record in each layout entry', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG,
                actionConfig: ACTION_CONFIG
            });
            await flushPromises();

            const actionBars = element.shadowRoot.querySelectorAll('c-data-cloud-query-action-bar');
            expect(actionBars[0].selectedRecords).toEqual([MOCK_RECORDS[0]]);
            expect(actionBars[1].selectedRecords).toEqual([MOCK_RECORDS[1]]);
        });
    });

    describe('hasActionConfig getter', () => {
        it('returns true when actionConfig is set', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG,
                actionConfig: ACTION_CONFIG
            });
            await flushPromises();

            const actionBars = element.shadowRoot.querySelectorAll('c-data-cloud-query-action-bar');
            expect(actionBars.length).toBeGreaterThan(0);
        });

        it('returns false when actionConfig is not set', async () => {
            executeDataCloudQuery.mockResolvedValue({ records: MOCK_RECORDS });

            const element = createComponent({
                querySettingId: 'TestSetting',
                recordConfig: RECORD_CONFIG
            });
            await flushPromises();

            const actionBars = element.shadowRoot.querySelectorAll('c-data-cloud-query-action-bar');
            expect(actionBars.length).toBe(0);
        });
    });
});
