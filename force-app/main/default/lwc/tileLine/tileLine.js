import { LightningElement, api } from 'lwc';
import goToUrl from '@salesforce/label/c.Go_to_URL';

export default class TileLine extends LightningElement {

    @api fieldData;

    isDateTime
    isEmail
    isNumber
    isCurrency
    isPercent
    isPhone
    isText
    isUrl
    isId

    labels = {
        goToUrl: goToUrl
    }
    
    connectedCallback() {
        this.isDateTime  = this.fieldData.fieldType == 'date';
        this.isEmail     = this.fieldData.fieldType == 'email';
        this.isNumber    = this.fieldData.fieldType == 'number';
        this.isCurrency  = this.fieldData.fieldType == 'currency';
        this.isPercent   = this.fieldData.fieldType == 'percent';
        this.isPhone     = this.fieldData.fieldType == 'phone';
        this.isText      = this.fieldData.fieldType == 'text';
        this.isUrl       = this.fieldData.fieldType == 'url';
        this.isReference        = this.fieldData.fieldType == 'reference';
    }

    get data() {
        const data = Object.assign({}, this.fieldData);
        if(this.isReference) {
            data.fieldValue = '/' + data.fieldValue;
        }
        return data;
    }


}