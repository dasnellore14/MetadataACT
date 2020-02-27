/**
 * Created by adamsm on 5/2/2019.
 */
({
    accessRecordsChangeSort: function(component, event, helper) {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');

        component.set("v.accessRecordsSortedBy", fieldName);
        component.set("v.accessRecordsSortedDirection", sortDirection);

        helper.showConsole(component, 'Sort = ' + fieldName + ', ' + sortDirection);
        helper.sortData(component, fieldName, sortDirection);
    },

    accessRecordsLoadMore: function(component, event, helper) {
        // Get component values
        var maxRecords = Number(component.get("v.accessRecordsMax"));
        var lastLoad = component.get("v.accessRecordsLastLoadTime");
        var loading = component.get("v.accessRecordsLoading");

        // Check the last load time
        var timePast = new Date() - lastLoad;

        if (loading == 'true' || Number(timePast) < 1000) {
            return;
        }

        // Adjust the max records
        maxRecords = Number(maxRecords) + Number(component.get("v.accessRecordsIncrement"));
        component.set("v.accessRecordsMax", maxRecords);

        // Load the records
        helper.loadAccessRecords(component, helper);
    },

    accessRecordsSelectRows: function(component, event, helper) {
        component.set("v.accessRecordsSelectedRows", event.getParam('selectedRows'));
    },

    cancelAddAccess: function(component, event, helper) {
        helper.resetAddAccess(component, helper);
    },

    checkAddAccessAccount: function(component, event, helper) {
        var selectedAccount = component.get("v.selectedAddAccessAccount");

        if (selectedAccount && selectedAccount.Name) {
            helper.loadACRRecords(component, helper);
        }
        else {
            helper.resetAddAccess(component, helper);
        }
    },

    checkEmail: function(component, event, helper) {
        helper.checkAddUsersButton(component, helper);
    },

    checkStep3: function(component, event, helper) {
        helper.checkStep3(component, helper);
    },

    doInit: function(component, event, helper) {
        // Initialize the page
        helper.doInit(component, helper);

        // Set up the invited users columns
        var objColumns = [
            {
                fieldName: 'ContactLink',
                initialWidth: 300,
                label: 'Name',
                sortable: true,
                type: 'url',
                typeAttributes:
                {
                    label: {fieldName: 'ContactName'},
                    target: '_blank'
                }
            },
            {
                fieldName: 'Title',
                initialWidth: 200,
                label: 'Title',
                sortable: true,
                type: 'text'
            },
            {
                fieldName: 'Phone',
                initialWidth: 125,
                label: 'Phone',
                sortable: true,
                type: 'text'
            },
            {
                fieldName: 'EmailAddress',
                initialWidth: 200,
                label: 'Email',
                sortable: true,
                type: 'Email'
            }
        ];

        // Set up the one column invited users
        var objColumnsSmall = [
            {
                fieldName: 'ContactLink',
                initialWidth: 300,
                label: 'Name',
                sortable: true,
                type: 'url',
                typeAttributes:
                {
                    label: {fieldName: 'ContactName'},
                    target: '_blank'
                }
            }
        ];

        component.set("v.inviteUsersColumns", objColumns);
        component.set("v.inviteUsersColumnsSmall", objColumnsSmall);
    },

    gotoDashboard: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/');
    },

    handleRequestButton: function(component, event, helper) {
        // Get/set the request button action
        var selectedButtonLabel = event.getSource().get("v.label");
        component.set("v.requestButtonAction", selectedButtonLabel);

        // Set the variants
        component.set("v.buttonApproveVariant", selectedButtonLabel == 'Approve' ? 'brand' : 'neutral');
        component.set("v.buttonCancelVariant", selectedButtonLabel == 'Cancel' ? 'brand' : 'neutral');
        component.set("v.buttonExtendVariant", selectedButtonLabel == 'Extend' ? 'brand' : 'neutral');
        component.set("v.buttonRejectVariant", selectedButtonLabel == 'Reject' ? 'brand' : 'neutral');

        // Enable the update button if there are records in the list, and the select action is chosen
        if (component.get("v.accessRecordsSize") != 0) {
            component.set("v.buttonUpdateDisabled", false);
        }
        if(selectedButtonLabel == 'Approve'){
            component.set("v.onlineReportingbuttonsDisabled",false);
            component.set("v.buttonScrResOnlyVariant", 'neutral');
            component.set("v.buttonViewConDelVariant", 'brand');
            component.set("v.onlineReportingButtonAction",'View Contract Deliverables');
        }else if(selectedButtonLabel == 'Reject'){
            component.set("v.buttonScrResOnlyVariant", 'neutral');
            component.set("v.buttonViewConDelVariant", 'neutral');
            component.set("v.onlineReportingButtonAction",'');
            component.set("v.onlineReportingbuttonsDisabled", true);
        }
    },
    handleOnlineReportingButton: function(component, event, helper){
        var selectedButtonLabel = event.getSource().get("v.label");
        var selectedButtonVariant = event.getSource().get("v.variant");
        if(selectedButtonLabel=='Contract Reports & Score Results'){
            component.set("v.buttonScrResOnlyVariant", 'neutral');
            if(selectedButtonVariant == 'brand'){
                component.set("v.buttonViewConDelVariant", 'neutral');
                component.set("v.onlineReportingButtonAction",'');
            }else{
                component.set("v.buttonViewConDelVariant", 'brand');
                component.set("v.onlineReportingButtonAction",'View Contract Deliverables');
            }
        }else if(selectedButtonLabel=='Score Results Only'){
            component.set("v.buttonViewConDelVariant", 'neutral');
            if(selectedButtonVariant == 'brand'){
                component.set("v.buttonScrResOnlyVariant", 'neutral');
                component.set("v.onlineReportingButtonAction",'');
              }else{
                 component.set("v.buttonScrResOnlyVariant", 'brand');
                 component.set("v.onlineReportingButtonAction",'Score Results Only');
            }
        }
    },

    hideSelectedView: function(component, event, helper) {
        component.find("isSelectView").getElement().blur();
        component.find("selectList").getElement().focus();
    },

    inviteUsersSelectRows: function(component, event, helper) {
        helper.checkAddUsersButton(component, helper);
    },

    pickOLR: function(component, event, helper) {
        var strClicked;
        var strEventClicked = event.target.id;
        var strNotClicked;

        console.log('strEventClicked = ' + strEventClicked);

        switch (strEventClicked) {
            case 'checkedSVBig':
            case 'checkedSVSmall':
                strClicked = 'checkedSV';
                strNotClicked = 'checkedDV';

                break;
            case 'checkedDVBig':
            case 'checkedDVSmall':
                strClicked = 'checkedDV';
                strNotClicked = 'checkedSV';

                break;
        }

        console.log('strClicked = ' + strClicked);
        console.log('strNotClicked = ' + strNotClicked);

        // Set the value of check for the 2 options
        component.set("v." + strClicked, 'checked');
        component.set("v." + strNotClicked, null);

        // Set make trusted agent to false, since you can only be one type
        component.set("v.makeTrustedAgent", null);
        component.set("v.onlineReportingbuttonsDisabled",false);
        component.set("v.buttonScrResOnlyVariant", 'neutral');
        component.set("v.buttonViewConDelVariant", 'brand');
        component.set("v.onlineReportingButtonAction",'View Contract Deliverables');

        helper.checkStep3(component, helper);
    },

    processAddUsersClick: function(component, event, helper) {
        // Check the email addresses
        var regExpEmailformat  = /^(([^<>()\[\]\\.,;:\s@“]+(\.[^<>()\[\]\\.,;:\s@“]+)*)|(“.+“))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        var strUserEmails = component.get("v.userEmails");

        if (strUserEmails) {
            var aryEmails = strUserEmails.split(',');

            for (var intX = 0; intX < aryEmails.length; intX++) {
                var strEmail = aryEmails[intX].trim();

                if (strEmail != '' && !strEmail.match(regExpEmailformat)) {
                    // Flag the email field
                    var emailField = component.find("userEmails");
                    $A.util.addClass(emailField, 'slds-has-error');

                    // Show a toast error
                    var resultsToast = $A.get("e.force:showToast");

                    resultsToast.setParams({
                        duration: "1500",
                        title: "Email format Error",
                        mode: "dismissible",
                        type: "error",
                        message: "The following email address is not valid '" + strEmail + "' "
                    });

                    resultsToast.fire();

                    return;
                }
            }
        }

        helper.processAddUsersClick(component, helper);
    },

    selectView: function(component, event, helper) {
        // Load relevant values
        var currentView = component.get('v.selectedView');

        // Get the new view
        var source = event.getSource();
        var label = source.get("v.label");
        var newView = label.trim();

        // See if the selected view is already the current view
        if (newView == currentView) {
            return;
        }

        // Remove the Add Access Section
        component.set("v.selectedAddAccessAccount", null);
        component.set("v.addAccess1", false);
        component.set("v.addAccess3", false);

        //Remove the Revoke Access Section
         component.set("v.selectedRevokeAccessAccount", null);
         component.set("v.revokeAccess", false);

        // Load the new view
        helper.selectView(component, helper, newView);
    },

    trustedAgentClick: function(component, event, helper) {
        // If they are a trusted agent, turn off detail/summary viewer, since you can only be one type
        if (component.get("v.makeTrustedAgent")) {
            component.set("v.checkedDV", null);
            component.set("v.checkedSV", null);
            component.set("v.buttonScrResOnlyVariant", 'neutral');
            component.set("v.buttonViewConDelVariant", 'neutral');
            component.set("v.onlineReportingbuttonsDisabled", true);
            component.set("v.onlineReportingButtonAction", null);
        }

        helper.checkStep3(component, helper);
    },

    stateTrustedAgentClick: function(component, event, helper) {
        // If they are a trusted agent, turn off detail/summary viewer, since you can only be one type
        if (component.get("v.makeStateTrustedAgent")) {
            component.set("v.checkedDV", null);
            component.set("v.checkedSV", null);
            component.set("v.buttonScrResOnlyVariant", 'neutral');
            component.set("v.buttonViewConDelVariant", 'neutral');
            component.set("v.onlineReportingbuttonsDisabled", true);
            component.set("v.onlineReportingButtonAction", null);
        }

        helper.checkStep3(component, helper);
    },

    updateAccess: function(component, event, helper) {
        helper.updateAccess(component, helper);
    },
    revokeAccess: function(component, event, helper) {
        helper.revokeAccessHelper(component, event,helper);
    },

    performRevokeAccessRequest: function(component, event, helper) {
        helper.processRevokeAccessRequestHelper(component, event,helper);
    },
})
