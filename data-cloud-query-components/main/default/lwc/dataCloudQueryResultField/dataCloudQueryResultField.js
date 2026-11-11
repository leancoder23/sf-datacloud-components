import { LightningElement, api } from 'lwc';

export default class DataCloudQueryResultField extends LightningElement {
    @api field;

    get renderer() {
        return this.field?.renderer;
    }

    get formattedValue() {
        return this.field?.value;
    }

    get typeAttributes() {
        return this.field?.typeAttributes || {};
    }

    get fieldLabel() {
        return this.field?.label || '';
    }

    get fieldHelpText() {
        return this.field?.fieldHelpText || '';
    }

    get hasFieldHelpText() {
        return !!this.field?.hasFieldHelpText;
    }

    get displayLabel() {
        return this.field?.labelOverride || this.field?.label || '';
    }

    get urlLabel() {
        return this.field?.labelOverride || this.formattedValue;
    }

    get isCheckboxChecked() {
        return Boolean(this.formattedValue);
    }

    get isDate() {
        return this.renderer === 'date';
    }

    get isDateTime() {
        return this.renderer === 'datetime';
    }

    get isText() {
        return this.renderer === 'text';
    }

    get isCurrency() {
        return this.renderer === 'currency';
    }

    get isNumber() {
        return this.renderer === 'number';
    }

    get isEmail() {
        return this.renderer === 'email';
    }

    get isUrl() {
        return this.renderer === 'url';
    }

    get isRichText() {
        return this.renderer === 'richtext';
    }

    get isBoolean() {
        return this.renderer === 'boolean';
    }
}