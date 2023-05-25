import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getRecords from '@salesforce/apex/BigObjectRelatedListController.getRecords';
import getColumns from '@salesforce/apex/BigObjectRelatedListController.getColumns';
import getSObjectPluralLabel from '@salesforce/apex/BigObjectRelatedListController.getSObjectPluralLabel';
import isSObjectAccessible from '@salesforce/apex/BigObjectRelatedListController.isSObjectAccessible';
import viewMore from '@salesforce/label/c.View_More';
import allRecordsDisplayedTitle from '@salesforce/label/c.All_Records_Are_Displayed_Title';
import allRecordsDisplayedMessage from '@salesforce/label/c.All_Records_Are_Displayed_Message';

const TABLE_SLICE_SIZE = 5;
const TILES_SLICE_SIZE = 4;
const TABLE_MODE = "Table";
const TILES_MODE = "Tiles";

const TRIGGER_SMALL_SCREENS = '(max-width: 455px)';
const TRIGGER_MEDIUM_SCREENS = '(min-width: 456px) and (max-width: 769px)';
const TRIGGER_LARGE_SCREENS = '(min-width: 770px)';

const RELATED_LIST_HEADER_CLASSES = "slds-media slds-media--center slds-has-flexi-truncate ";
const RELATED_LIST_HEADER_RESPONSIVE = "responsive-header";
const RELATED_LIST_HEADER_TITLE_CLASSES = "slds-media__body slds-truncate ";
const RELATED_LIST_HEADER_TITLE_RESPONSIVE = 'responsive-header-title';
const RELATED_LIST_HEADER_ACTIONS_CONTAINER_CLASSES = "slds-no-flex ";
const RELATED_LIST_HEADER_ACTIONS_CONTAINER_RESPONSIVE = 'responsive-header-actions-container';
const RELATED_LIST_HEADER_ACTIONS_CLASSES = "branding-actions slds-button-group slds-m-left--xx-small small oneActionsRibbon forceActionsContainer ";
const RELATED_LIST_HEADER_ACTIONS_RESPONSIVE = 'responsive-header-actions';

export default class BigObjectRelatedList extends LightningElement {

    _isLoading = true;

    @api recordId;
    @api iconName;
    @api iconBackgroundColor;
    @api apiName;
    @api retrievedFields;
    @api numberOfRecords;
    @api displayModeLarge;
    @api displayModeMedium;
    @api displayModeSmall;

    @track fields;
    @track records;
    @track displayedRecords;

    pluralLabel;
    isAccessible;
    maxRecords;
    labels = {
        viewMore: viewMore,
        allRecordsDisplayedTitle: allRecordsDisplayedTitle,
        allRecordsDisplayedMessage: allRecordsDisplayedMessage,
    }

    connectedCallback() {
        // Select the first value, if exists, for the maximum number of records to load options picklist.
        this.maxRecords = this.numberOfRecords ? (this.numberOfRecords.split(',').length ? this.numberOfRecords.split(',')[0] : '') : '';
        
        // Init fields metadata and records.
        this.initData();
    }

    renderedCallback() {
        this.setDynamicStyles();
    }

    async initData() {
        this._isLoading = true;
            const hasAccess = await this.loadAccess();
            if(hasAccess) {
                const fields = await this.loadColumns();
                await this.loadRecords(fields);
            }
        this._isLoading = false;
    }

    // Checks the access for the big object based on the current user.
    loadAccess() {
        const trimmedObjectApiName = this.removeWhitespaces(this.apiName);

        return isSObjectAccessible({ apiName: trimmedObjectApiName })
            .then(data => {
                this.isAccessible = data;
                return this.isAccessible;
            })
            .catch(error => {
                console.error('Unexpected error when checking the big object access: ', error);
            })
    }

    // Load the columns to display.
    loadColumns() {
        const trimmedObjectApiName = this.removeWhitespaces(this.apiName);
        const trimmedRetrievedFields = this.removeWhitespaces(this.retrievedFields);
        return getColumns({ bigObjectApiName: trimmedObjectApiName, fieldsApiNames: trimmedRetrievedFields })
            .then(data => {
                return data;
            })
            .catch(error => {
                console.error('Unexpected error when loading metadata: ', error);
            })
    }

    // Load the records to display & perform parsing the particular cases (if the field is an URL or a REFERENCE).
    loadRecords(fields) {
        const trimmedObjectApiName = this.removeWhitespaces(this.apiName);
        const trimmedRetrievedFields = this.removeWhitespaces(this.retrievedFields);
        return getRecords({ bigObjectApiName: trimmedObjectApiName, fieldsApiNames: trimmedRetrievedFields, parentRecordId: this.recordId, numberOfRecords: this.maxRecords })
            .then(data => {
                if (this.isDisplayModeTable) {
                    this.records = this.parseRecordsForDatatable(data, fields);
                    this.fields = this.parseFields(fields);
                    this.displayedRecords = this.records.slice(0, this.tableSliceSize);
                }
                if (this.isDisplayModeTiles) {
                    this.records = this.parseRecordsForTiles(data, fields);
                    this.fields = this.parseFields(fields);
                    this.displayedRecords = this.records.slice(0, this.tilesSliceSize);
                }
            })
            .catch(error => {
                console.error('Unexpected error when loading records: ', error);
            })
    }

    // Wire the big object plural label according to the current user language.
    @wire(getSObjectPluralLabel, ({ apiName: '$apiName' }))
    wiredpluralLabel({ error, data }) {
        if (data) {
            this.pluralLabel = data;
        }
        else if (error) {
            console.error('Unexpected error when loading the big object plural label: ', error);
        }
    }

    // Handler for the View more actions. If no more records can be displayed, a warning message is displayed through a Toast.
    handleViewMore() {
        if (this.displayedRecords.length != this.records.length) {
            if (this.isDisplayModeTable) {
                this.displayedRecords = this.records.slice(0, this.displayedRecords.length + this.tableSliceSize);
            }
            if (this.isDisplayModeTiles) {
                this.displayedRecords = this.records.slice(0, this.displayedRecords.length + this.tilesSliceSize);
            }
        }
        else {
            const event = new ShowToastEvent({
                title: this.labels.allRecordsDisplayedTitle,
                message: this.labels.allRecordsDisplayedMessage,
                variant: 'warning'
            });
            this.dispatchEvent(event);
        }
    }

    // Handler for the max records number change through the picklist.
    async handleMaxRecordsChange(event) {
        this._isLoading = true;
            this.maxRecords = event.detail.value;
            const fields = await this.loadColumns();
            await this.loadRecords(fields);
        this._isLoading = false;
    }

    // Set the dynamic styles for the related list.
    setDynamicStyles() {
        // Set the related list's icon background according to the specified property.
        if (this.isValidColor(this.iconBackgroundColor)) {
            const icon = this.template.querySelector(".forceEntityIcon");
            if (icon)
                icon.style.backgroundColor = this.iconBackgroundColor ? this.iconBackgroundColor : "transparent";
        }
    }

    // Check if a color is a valid color in HEX.
    isValidColor(color) {
        return (/^#([0-9A-F]{3}){1,2}$/i.test(color));
    }

    // Removes all whitespaces from a string and returns it.
    removeWhitespaces(string) {
        return string ? string.replace(/\s+/g, '') : string;
    }

    // Parse records the the datatable and handle particular cases (record contains url or reference fields)
    parseRecordsForDatatable(data, fields) {
        const parsedData = [];
        data.forEach(record => {
            const clonedRecord = Object.assign({}, record);
            // For each record field, checks if it's a reference, then convert its value to an URL.
            const referenceFields = Object.keys(clonedRecord).filter(field => {
                return fields.find(fieldProps => fieldProps.fieldName == field && fieldProps.type == 'reference');
            })
            referenceFields.forEach(field => { 
                clonedRecord[field] = '/' + clonedRecord[field];
            })

            // For each relationship field (Example: "Contact__r"), create a new property inside the record itself 
            // that contains the name directly (Example: "Contact__r.Name"). This is a workaround because we cannot
            // access the relationship name directly in the LWC datatable.
            const referenceNameFields = Object.keys(clonedRecord).filter(field => {
                return clonedRecord[field].hasOwnProperty('Name') && clonedRecord[field].hasOwnProperty('Id');
            })
            referenceNameFields.forEach(field => { 
                clonedRecord[field + '.Name'] = clonedRecord[field].Name;
            })

            parsedData.push(clonedRecord);
        })
        return parsedData;
    }

    // Parses records the the datatable and handle particular cases (record contains reference fields).
    parseRecordsForTiles(data, fields) {
        const parsedData = [];
        data.forEach((item) => {
            const fieldsData = Array();
            for (let [key, value] of Object.entries(item)) {
                const foundField = fields.find(field => field.fieldName == key);
                if (foundField) {
                    const fieldData = {
                        fieldName: foundField.label,
                        fieldType: foundField.type,
                        fieldValue: value
                    }
                    if(foundField.type == 'reference') {
                        fieldData.fieldDisplayedValue = item[foundField.typeAttributes.label.fieldName.split('.')[0]].Name;
                    }
                    fieldsData.push(fieldData);
                }
            }
            parsedData.push({
                id: item.Id,
                fieldsData: fieldsData
            });
        })
        return parsedData;
    }

    // Parses fields and handle particular cases (field type is a reference).
    parseFields(fields) {
        const formattedFields = [];
        fields.forEach(field => {
            const clonedField = Object.assign({}, field);
            if(clonedField.type == 'reference') {
                clonedField.type = 'url';
            }
            formattedFields.push(clonedField);
        })
        return formattedFields;
    }


    // Getter for the maximum number of records to load options.
    get maxRecordsOptions() {
        let options = [];
        if(this.numberOfRecords) {
            this.numberOfRecords.split(',').forEach((element) => {
                const trimmedElement = this.removeWhitespaces(element);
                if (Number.isInteger(parseInt(trimmedElement)))
                    options.push({ label: trimmedElement + ' records', value: trimmedElement })
            });
        }
        return options;
    }

    // Checks if the current display mode is Table based on the screen size.
    get isDisplayModeTable() {
        if(this.isSmallScreens) {
            return this.displayModeSmall == TABLE_MODE;
        }
        if(this.isMediumScreens) {
            return this.displayModeMedium == TABLE_MODE;
        }
        if(this.isLargeScreens) {
            return this.displayModeLarge == TABLE_MODE;
        }
    }

    // Checks if the current display mode is Tiles based on the screen size.
    get isDisplayModeTiles() {
        if(this.isSmallScreens) {
            return this.displayModeSmall == TILES_MODE;
        }
        if(this.isMediumScreens) {
            return this.displayModeMedium == TILES_MODE;
        }
        if(this.isLargeScreens) {
            return this.displayModeLarge == TILES_MODE;
        }
    }

    // Getter for the number of records loaded.
    get recordsSize() {
        return this.records ? this.records.length : 0;
    }

    // Getter for the slice size for the table display mode.
    get tableSliceSize() {
        return TABLE_SLICE_SIZE;
    }

    // Getter for the slice size for tiles displayed mode, based on the current screen size.
    get tilesSliceSize() {
        return this.isSmallScreens ? 2 : TILES_SLICE_SIZE;
    }

    // Getter for the number of records not displayed yet and that can be loaded by clicking on 'View more'.
    get moreRecordsLength() {
        let result = '0';
        if(this.records) {
            result = this.records.length - this.displayedRecords.length;
        }
        return result;
    }

    // Checks if the current screen is small.
    get isSmallScreens() {
        return window.matchMedia(TRIGGER_SMALL_SCREENS).matches;
    }

    // Checks if the current screen is medium.
    get isMediumScreens() {
        return window.matchMedia(TRIGGER_MEDIUM_SCREENS).matches;
    }

    // Checks if the current screen is large.
    get isLargeScreens() {
        return window.matchMedia(TRIGGER_LARGE_SCREENS).matches;
    }

    // Getters for CSS styles & classes according to the current screen size.
    get headerStyle() {
        return RELATED_LIST_HEADER_CLASSES + (this.isSmallScreens ? RELATED_LIST_HEADER_RESPONSIVE : '');
    }

    get headerTitleStyle() {
        return RELATED_LIST_HEADER_TITLE_CLASSES + (this.isSmallScreens ? RELATED_LIST_HEADER_TITLE_RESPONSIVE : '');
    }

    get headerActionsContainerStyle() {
        return RELATED_LIST_HEADER_ACTIONS_CONTAINER_CLASSES + (this.isSmallScreens ? RELATED_LIST_HEADER_ACTIONS_CONTAINER_RESPONSIVE : '');
    }

    get headerActionsStyle() {
        return RELATED_LIST_HEADER_ACTIONS_CLASSES + (this.isSmallScreens ? RELATED_LIST_HEADER_ACTIONS_RESPONSIVE : '');
    }
}