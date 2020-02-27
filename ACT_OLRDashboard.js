/**
 * Created by craighoneyfield on 12/5/18.
 */
({
     doInit : function(component, event, helper) {
        helper.getApprovalData(component,event,helper);

        var action2 = component.get("c.getDashboardPermissions");
        action2.setBackground();
        action2.setCallback(this, function(response) {
            var objReturn = response.getReturnValue();
            var state = response.getState();

            if (state ==="SUCCESS") {
                if (objReturn) {
                    component.set("v.showEdFiAdmin", objReturn['EdFi Admin']);
                    component.set("v.showeMetrics", objReturn['eMetrics SSO']);
                    component.set("v.showInviteUsers", objReturn['Invite Users']);
                    component.set("v.showManageUsers", objReturn['Manage Users']);
                    component.set("v.showPANext", objReturn['PANext']);
                    //component.set("v.showRequestAccess", objReturn['Request Access']);
                    component.set("v.showManageMyAccess", objReturn['My Access']);
                    //Toggle Test Accomodations section.
                    component.set("v.showTestAccomodations", objReturn['TAA Role']);

                    console.debug('EdFi Admin:' + objReturn['EdFi Admin'] + ' eMetrics SSO:' + objReturn['eMetrics SSO'] + ' Invite Users: ' + objReturn['Invite Users']);
                    console.debug('Manage Users: ' + objReturn['Manage Users'] + ' PANext: ' + objReturn['PANext'] + ' Request Access: ' + objReturn['Request Access']);
                }
            }
            else {
                var strError = response.getError()[0].message;

                resultsToast.setParams({
                    title: "Error checking permission sets",
                    mode: "sticky",
                    type: "error",
                    message: strError
                });

               resultsToast.fire();
            }
        });

        // Launch the server side calls
        $A.enqueueAction(action2);
     },

    navAddUsers: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/manage-users?view=addaccess');
    },

    navConfigureEdFi : function(component, event, helper) {
        // Show spinner
        helper.spinnerShow(component);

        // First create the OIDC attributes
        helper.doCallout(component, helper, "c.generateEdFiOIDC", null).then(function(response) {
            // Get component values (come from designer)
            var strCSPhone = component.get('v.ACTCustomerServicePhone');
            var strEdFiURL = component.get('v.EdFiURL');

            // Then redirect based on the response
            if (response.AllowSSO == true) {
                helper.gotoURLPopup(component, helper, strEdFiURL, 'EdFiWindow');
            }
            else {
                helper.showMessage('Warning', response.ValidationResults);
            }
        }).catch(function(errors) {
            helper.showErrors(errors);
        }).finally(function() {
            // Hide spinner
            helper.spinnerHide(component);
        });
    },

    navConfigureTAA : function(component, event, helper) {
        //Show spinner
        helper.spinnerShow(component);

        // First create the OIDC attributes
        helper.doCallout(component, helper, "c.generateTAAOIDC", null).then(function(response) {
            // Get component values (come from designer)
            var strTestAccomodationsURL = component.get('v.testAccomodationsURL');

            // Then redirect based on the response
            if (response.AllowSSO == true) {
                helper.gotoURLPopup(component, helper, strTestAccomodationsURL, 'TAAWindow');
            }
            else {
                helper.showMessage('Warning', response.ValidationResults);
            }
        }).catch(function(errors) {
            helper.showErrors(errors);
        }).finally(function() {
            // Hide spinner
            helper.spinnerHide(component);
        });
    },

    navDisplayHierarchy: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/hierarchy-approval');
    },

    navManageAccess: function(component,event,helper) {
        helper.gotoUrl(component, helper, '/manage-users');
    },

    navMyAccess: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/my-access');
    },

    navRequestAccess: function(component, event, helper) {
        helper.gotoUrl(component, helper, '/request-access');
    },

    navViewScores: function(component, event, helper) {
        // Show spinner
        helper.spinnerShow(component);

        // Create the parameters
        var objParameters = {
            eMetricsContactId: null,
            programTypeSelected: null
        };

        // First create the SAML
        helper.doCallout(component, helper, "c.generateeMetricsSAML", objParameters).then(function(response) {
            // Log the response
            helper.showConsole(component, 'generateeMetricsSAML response = ' + JSON.stringify(response));

            // Set the response
            component.set('v.gordonResults', response);
            component.set('v.showProgramTypeModal', response.ProgramTypeSelectionRequired);

            // Get component values (come from designer)
            var strCSPhone = component.get('v.ACTCustomerServicePhone');
            var streMetricsURL = component.get('v.eMetricsURL');

            helper.showConsole(component, 'strCSPhone = ' + strCSPhone);
            helper.showConsole(component, 'streMetricsURL = ' + streMetricsURL);

            // If a modal isn't shown, loop through to determine the message to show
            if (!response.ProgramTypeSelectionRequired) {
                var responseValue = '';
                var responseMap = JSON.parse(response.ValidationResults);

                for (var key in responseMap){
                    var keyValue = key;

                    if(keyValue.includes('Disputed Record')){
                        responseValue = 'Disputed';
                        break;
                    }
                    else if(key == 'Approval Required'){
                        responseValue = 'Approval Required';
                    }
                    else if(key == 'Disputed and Approval Required'){
                        responseValue = 'Disputed and Approval Required';
                    }
                    else if(key == 'Success'){
                        responseValue = 'Success';
                    }
                    else if(key == 'NoAccess'){
                        responseValue = 'NoAccess';
                    }
                }

                // Then redirect based on the response
                switch (responseValue) {
                    case 'Disputed':
                           var message = '';
                           var academicYear = '';
                           for (var key in responseMap){
                               if(!$A.util.isUndefinedOrNull(responseMap[key])){
                                   academicYear = responseMap[key];
                               }
                               message = message+'  '+'The hierarchy for '+ key.replace('Disputed Record','') +' '+ academicYear+' '+'is currently disputed. Access to Online Reporting for this hierarchy is currently suspended.';
                              }
                           helper.showMessage('Warning',message, true);

                        break;
                    case 'Success':
                        helper.gotoURLPopup(component, helper, streMetricsURL, 'eMetricsWindow');
                        break;
                    case 'Approval Required':
                        helper.showMessage('Warning', 'We apologize, hierarchy approval required. For questions, please call ACT at 1-319-337-1365 ', true);
                        break;
                    case 'Disputed and Approval Required':
                        helper.showMessage('Warning', 'We apologize, hierarchy is under dispute and approval required. For questions, please call ACT at 1-319-337-1365 ', true);
                        break;
                    case 'NoAccess':
                        helper.showMessage('Warning', 'We apologize, there are no accounts currently available for this feature. For questions, please call ACT at 1-319-337-1365', true);
                        break;
                    default:
                        helper.showMessage('Error', 'An unexpected error occurred.  Please try again, or contact support.  Response = ' + response, false);
                        break;
                }
            }
        }).catch(function(errors) {
            helper.showMessage('Error', errors[0].message, true);
        }).finally(function() {
            // Hide spinner
            helper.spinnerHide(component);
        });
    },

    PANext: function(component, event, helper) {
        $A.get("e.force:navigateToURL").setParams({
            "url": "https://testadmin.act.org/"
        }).fire();
    },
})
