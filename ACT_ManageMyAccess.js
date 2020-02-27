/**
 * Created by Rama on 2019-06-13.
 */
({
    doInit: function(component, event, helper) {
        // Initialize the page
        helper.doInit(component, helper);
    },

    gotoDashboard: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/');
    },

    selectView: function(component, event, helper) {

        component.set('v.boolShowMyAccess',false);
        component.set('v.trustedAgentType','');
        component.set('v.accessCode','');
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

        // Load the new view
        helper.selectView(component, helper, newView);
    },
    processMyAccess : function(component, event, helper) {
        helper.processMyAccessHelper(component, helper);
    },
    validateAccessCode : function(component, event, helper) {
        helper.validateAccessCodeHelper(component, helper);
    },

    actionMouseOver : function(component, event, helper) {
        document.getElementById("help").style.display = "";
    },

 	actionMouseOut : function(component, event, helper) {
        document.getElementById("help").style.display = "none";
    },
    clearInputsAfterValidate : function(component, event, helper) {

        component.set('v.trustedAgentType','');
        component.set('v.accessCode','');
        component.set('v.selectedAccountRecord',{});
        component.set("v.boolDisableCodeSection",false);
        component.set("v.validateCount",0);
    },
    showSucessMessage : function(component, event, helper) {
        var resultsToast = $A.get("e.force:showToast");
        resultsToast.setParams({
            title: "Valid access code:",
            message: "This code is a valid access code",
            mode: "dismissible",
            type: "success"
        });
        // Fire error toaster message
        resultsToast.fire();
    },
    clearInputs : function(component, event, helper) {
        component.set("v.trustedAgentType",'');
        component.set("v.disableshowAccess",false);
        //component.set("v.validateCount",0);
    },
    applyValidAccessToProfile : function(component, event, helper) {
        helper.applyValidAccessToProfileHelper(component, event, helper);
    },
    enableDisableMyAccessBtn : function(component, event, helper) {
        helper.enableDisableMyAccessBtnHelper(component, event, helper);
    },
    enableDisableUseAccessBtn : function(component, event, helper) {
        helper.enableDisableUseAccessBtnHelper(component, event, helper);
    },
    processRequestForMoreAccess : function(component, event, helper) {
        helper.processRequestForMoreAccessHelper(component, helper);
    },
    applyRequestedAccess : function(component, event, helper) {
        helper.applyRequestedAccessHelper(component, helper);
    },
    toggleMoreAccessBtn : function(component, event, helper) {
        helper.toggleMoreAccessBtnHelper(component, helper,event);
    },
    pickOLR: function(component, event, helper) {
        var strClicked;
        var strEventClicked = event.target.id;
        var strNotClicked;

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

        // Set the value of check for the 2 options
        component.set("v." + strClicked, 'checked');
        component.set("v." + strNotClicked, null);

        // Set make trusted agent to false, since you can only be one type
        component.set("v.makeTrustedAgent", null);

        //Logic to toggle submit button.
        const strEmetricRole = component.get("v.strEmetricRole");
        const checkedSV = component.get("v.checkedSV");
        const checkedDV = component.get("v.checkedDV");
        const strAccessLevels = component.get('v.strAccessLevels');
        const objAccessLevels = JSON.parse(strAccessLevels);

        let objModifiedAccessLevels = {
            boolIsTrustedAgent : ! component.get('v.makeTrustedAgent') || $A.util.isUndefinedOrNull(component.get('v.makeTrustedAgent')) ? false : true,
            boolShowEdFIReport : ! component.get('v.makeEdFi') || $A.util.isUndefinedOrNull(component.get('v.makeEdFi')) ? false : true,
            boolShowTAARole : ! component.get('v.makeTAA') || $A.util.isUndefinedOrNull(component.get('v.makeTAA')) ? false : true
        }

        if(component.get('v.checkedSV') == 'checked'){
            objModifiedAccessLevels.boolShowOnlineReport = 'checkedSV';
        } else if (component.get('v.checkedDV') == 'checked'){
            objModifiedAccessLevels.boolShowOnlineReport = 'checkedDV';
        } else {
            objModifiedAccessLevels.boolShowOnlineReport = 'none';
        }

        if(objModifiedAccessLevels.boolIsTrustedAgent != objAccessLevels.boolIsTrustedAgent ||
           objModifiedAccessLevels.boolShowEdFIReport != objAccessLevels.boolShowEdFIReport ||
           objModifiedAccessLevels.boolShowTAARole != objAccessLevels.boolShowTAARole ||
           objModifiedAccessLevels.boolShowOnlineReport != objAccessLevels.boolShowOnlineReport){
            component.set('v.boolDisableReqMoreBtn',false);
        }else {
            component.set('v.boolDisableReqMoreBtn',true);
        }
    },

})
