import { createElement } from '@lwc/engine-dom';
import DataCloudQueryActionBar from 'c/dataCloudQueryActionBar';

jest.mock(
    '@salesforce/label/c.DCQR_Generic_Error_Message',
    () => ({ default: 'Generic error' }),
    { virtual: true }
);
jest.mock(
    '@salesforce/label/c.DCQR_Single_Row_Selection',
    () => ({ default: 'Select exactly one record.' }),
    { virtual: true }
);
jest.mock(
    '@salesforce/label/c.DCQR_Multi_Row_Selection',
    () => ({ default: 'Select one or more records.' }),
    { virtual: true }
);
jest.mock(
    '@salesforce/label/c.DCQR_Generic_Row_Selection_Info',
    () => ({ default: 'Selection info' }),
    { virtual: true }
);
jest.mock('c/dataCloudQueryFlowModal', () => ({ default: { open: jest.fn() } }), { virtual: true });

const flushPromises = () => new Promise(process.nextTick);

function createComponent(props = {}) {
    const element = createElement('c-data-cloud-query-action-bar', {
        is: DataCloudQueryActionBar
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe('c-data-cloud-query-action-bar', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    describe('singleRecordMode', () => {
        it('filters out multiple-selection actions when singleRecordMode is true', async () => {
            const config = {
                singleRecordMode: true,
                showRefresh: true,
                actions: [
                    { label: 'Single Action', flowApiName: 'Flow_Single', selectionMode: 'single', inputMappings: [] },
                    { label: 'Multi Action', flowApiName: 'Flow_Multi', selectionMode: 'multiple', inputMappings: [] },
                    { label: 'No Select Action', flowApiName: 'Flow_None', selectionMode: 'none', inputMappings: [] }
                ]
            };

            const element = createComponent({
                actionConfig: config,
                selectedRecords: [{ Id: '001' }]
            });
            await flushPromises();

            const buttons = element.shadowRoot.querySelectorAll('lightning-button');
            const labels = Array.from(buttons).map(b => b.label);

            expect(labels).toContain('Single Action');
            expect(labels).toContain('No Select Action');
            expect(labels).not.toContain('Multi Action');
        });

        it('keeps all actions when singleRecordMode is false', async () => {
            const config = {
                singleRecordMode: false,
                actions: [
                    { label: 'Single Action', flowApiName: 'Flow_Single', selectionMode: 'single', inputMappings: [] },
                    { label: 'Multi Action', flowApiName: 'Flow_Multi', selectionMode: 'multiple', inputMappings: [] }
                ]
            };

            const element = createComponent({
                actionConfig: config,
                selectedRecords: [{ Id: '001' }]
            });
            await flushPromises();

            const buttons = element.shadowRoot.querySelectorAll('lightning-button');
            const labels = Array.from(buttons).map(b => b.label);

            expect(labels).toContain('Single Action');
            expect(labels).toContain('Multi Action');
        });

        it('hides helptext when singleRecordMode is true', async () => {
            const config = {
                singleRecordMode: true,
                showRefresh: true,
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const helptext = element.shadowRoot.querySelector('lightning-helptext');
            expect(helptext).toBeNull();
        });

        it('shows helptext when singleRecordMode is false', async () => {
            const config = {
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const helptext = element.shadowRoot.querySelector('lightning-helptext');
            expect(helptext).not.toBeNull();
        });
    });

    describe('showRefresh', () => {
        it('hides refresh button when singleRecordMode is true and showRefresh is not set', async () => {
            const config = {
                singleRecordMode: true,
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon[icon-name="utility:refresh"]');
            expect(refreshBtn).toBeNull();
        });

        it('shows refresh button when singleRecordMode is true but showRefresh is explicitly true', async () => {
            const config = {
                singleRecordMode: true,
                showRefresh: true,
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon[icon-name="utility:refresh"]');
            expect(refreshBtn).not.toBeNull();
        });

        it('hides refresh button when showRefresh is explicitly false even without singleRecordMode', async () => {
            const config = {
                showRefresh: false,
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon[icon-name="utility:refresh"]');
            expect(refreshBtn).toBeNull();
        });

        it('shows refresh button by default when neither flag is set', async () => {
            const config = {
                actions: [
                    { label: 'Action', flowApiName: 'Flow_1', selectionMode: 'single', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [] });
            await flushPromises();

            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon[icon-name="utility:refresh"]');
            expect(refreshBtn).not.toBeNull();
        });
    });

    describe('backward compatibility', () => {
        it('renders all actions and refresh when no new flags are present', async () => {
            const config = {
                actions: [
                    { label: 'Action A', flowApiName: 'Flow_A', selectionMode: 'single', inputMappings: [] },
                    { label: 'Action B', flowApiName: 'Flow_B', selectionMode: 'multiple', inputMappings: [] }
                ]
            };

            const element = createComponent({ actionConfig: config, selectedRecords: [{ Id: '001' }] });
            await flushPromises();

            const buttons = element.shadowRoot.querySelectorAll('lightning-button');
            expect(buttons.length).toBe(2);

            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon[icon-name="utility:refresh"]');
            expect(refreshBtn).not.toBeNull();

            const helptext = element.shadowRoot.querySelector('lightning-helptext');
            expect(helptext).not.toBeNull();
        });
    });
});
