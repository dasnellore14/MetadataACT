/**
 * Created by adamsm on 7/15/2019.
 */

({
    doInit: function(component, event, helper) {
        // Get the data
        var objColumns = component.get('v.columns');
        var objData = component.get('v.data');
        var objKeyField = component.get('v.keyField');

        // Determine the column size
        component.set('v.columnsSize', objColumns.length);

        // Make a flat object
        var objFlatData = new Object();

        // Get the total records
        objFlatData.Records = [];
        objFlatData.TotalRecords = objData.length;

        // Populate the data
        for (var intX = 0; intX < objFlatData.TotalRecords; intX++) {
            var objThisRecord = new Object();

            objThisRecord.Fields = [];
            objThisRecord.RecordNumber = intX;
            objThisRecord.Selected = false;

            // Get the Key Field Value
            objThisRecord.KeyFieldValue = objData[intX][objKeyField];

            // Get the fields
            for (var intY = 0; intY < objColumns.length; intY++) {
                var objField = new Object();

                objField.CustomType = false;
                objField.FieldName = objColumns[intY].fieldName;
                objField.FieldLabel = objColumns[intY].label;
                objField.FieldType = objColumns[intY].type;
                objField.FieldValue = objData[intX][objColumns[intY].fieldName];

                switch (objField.FieldType) {
                    case 'url':
                        objField.CustomType = true;
                        objField.LinkLabel = objData[intX][objColumns[intY].typeAttributes.label.fieldName];
                        objField.LinkTarget = objColumns[intY].typeAttributes.target;

                        break;
                   }

                   objThisRecord.Fields.push(objField);
            }

            // Push the record
            objFlatData.Records.push(objThisRecord);
        }

        // Set the flat object
        component.set('v.flatData', objFlatData);
    },

    DTChangeSort : function(component, event, helper) {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        component.set("v.sortedBy", fieldName);
        component.set("v.sortedDirection", sortDirection);

        helper.sortData(component, fieldName, sortDirection, helper);
    },

    DTRecordSelectedClick : function(component, event, helper) {
        // Get the selected rows from the event
        var objDTSelectedRows = event.getParam('selectedRows');

        // Set the selected rows
        component.set('v.selectedRows', objDTSelectedRows);

        console.log('DTRecordSelectedClick = ' + objDTSelectedRows);

        // Call the parent
        $A.enqueueAction(component.get('v.onrowselection'));
    },

    tileRecordSelectedClick : function(component, event, handler) {
        // See what is selected
        var objData = component.get('v.data');
        var objFlatData = component.get('v.flatData');
        var objSelectedRows = [];

        for (var intX = 0; intX < objFlatData.TotalRecords; intX++) {
            if (objFlatData.Records[intX].Selected) {
                objSelectedRows.push(objData[intX]);
            }
        }

        component.set('v.selectedRows', objSelectedRows);

        // Call the parent
        $A.enqueueAction(component.get('v.onrowselection'));
    },
});
