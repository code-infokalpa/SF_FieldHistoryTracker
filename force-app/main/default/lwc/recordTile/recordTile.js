import { LightningElement, api } from 'lwc';

export default class RecordTile extends LightningElement {

    @api record;
    @api key;

}