/**
 * Created by mitulpatel on 10/30/18.
 */
({
    initialize: function(component, event, helper ) {

        $A.get("e.siteforce:registerQueryEventMap").setParams({"qsToEvent" : helper.qsToEventMap}).fire();
        $A.get("e.siteforce:registerQueryEventMap").setParams({"qsToEvent" : helper.qsToEventMap2}).fire();
        component.set('v.extraFields', helper.getExtraFields(component, event, helper));
        //component.set('v.disableSubmitButton', true);
        var accessid  =helper.getUrlParameter('accessid');
        component.set('v.UrlAccessId',accessid);
        //alert(accessid);
        if(accessid !=null)
        {
               var action = component.get("c.validateAccess");

                debugger;
                action.setParams({
                      accessId : accessid
                                  });
                  action.setCallback(this, function(response){

                    var state = response.getState();
                   // alert(state);
                    if (state === "SUCCESS")
                    {
                          var returnValue = response.getReturnValue();
                          console.log(returnValue);
                         // alert(returnValue.Name);
                          //alert(returnValue.Email_Address__c);
                          if(returnValue.Email_Address__c !=null)
                            component.set('v.workEmail', returnValue.Email_Address__c);
                    }
                });

                $A.enqueueAction(action);
        }
        helper.getTimeZoneList(component,event,helper);
        var date = new Date();
        var dateYear = date.getFullYear()-18;
        var birthYear =[];
        var birthMonth =[];
        for(var year=0; year <105 ; year++)
        {
            var yr = dateYear-year;
            if(yr =="1899")
                  break;
            else
            birthYear.push(yr);

        }
        birthMonth.push({key: "0", value: "January"});
        birthMonth.push({key: "01", value: "February"});
        birthMonth.push({key: "02", value: "March"});
        birthMonth.push({key: "03", value: "April"});
        birthMonth.push({key: "04", value: "May"});
        birthMonth.push({key: "05", value: "June"});
        birthMonth.push({key: "06", value: "July"});
        birthMonth.push({key: "07", value: "August"});
        birthMonth.push({key: "08", value: "September"});
        birthMonth.push({key: "09", value: "October"});
        birthMonth.push({key: "10", value: "November"});
        birthMonth.push({key: "11", value: "December"});

        component.set("v.birthMonth",birthMonth);
        component.set("v.birthYear",birthYear);
        helper.killSession(component);
    },


    handleSelfRegister: function (component, event, helper) {
        helper.handleSelfRegister(component, event, helper);
    },

    setStartUrl: function (component, event, helper) {
        let startUrl = event.getParam('startURL');
        if(startUrl) {
            component.set("v.startUrl", startUrl);
        }
    },

    setExpId: function (component, event, helper) {
        let expId = event.getParam('expid');
        if (expId) {
            component.set("v.expid", expId);
        }
        helper.setBrandingCookie(component, event, helper);
    },

    onKeyUp: function(component, event, helper){
        //checks for "enter" key
        if (event.getParam('keyCode')===13) {
            helper.handleSelfRegister(component, event, helper);
        }
    },


    callCheckboxMethod : function(component, event, helper) {
            let capturedCheckboxName = event.getSource().get("v.value");
            let selectedCheckBoxes =  component.get("v.selectedRoles");

            if(selectedCheckBoxes.indexOf(capturedCheckboxName) > -1){
                selectedCheckBoxes.splice(selectedCheckBoxes.indexOf(capturedCheckboxName), 1);
            }
            else{
                selectedCheckBoxes.push(capturedCheckboxName);
            }

            component.set("v.selectedRoles", selectedCheckBoxes);
            console.log(">>> selectedRoles: " + selectedCheckBoxes);
            helper.DisableButton(component,event,helper);

    },
    checkDisableButton: function(component, event, helper){

        //alert(component.find("termsCond").get("v.checked"));
        var termsCondCmp = component.find("termsCond");
         if(component.find("termsCond").get("v.checked") == false)
         {
                   termsCondCmp.setCustomValidity("Please check the terms and conditions.");

         }
         else
        {
            termsCondCmp.setCustomValidity("");
            helper.DisableButton(component,event,helper);
        }
        termsCondCmp.reportValidity();
    },
    checkNameValidation: function(component, event, helper){

            debugger;
            var inputCmp = component.find("firstname");
            var value = inputCmp.get("v.value");
            inputCmp.setCustomValidity("");
            var firstname = component.find("firstname").get("v.value");
            //var letters = /^[a-zA-Z-,]+(\s{0,1}[a-zA-Z-, ])*$/;
            //var letters = "^(?:[A-Za-z]+)(?:[A-Za-z0-9 _]*)$";
             var letters = new RegExp('^[a-zA-Z0-9-_\',. ]*$') ;
            if ((! firstname.match(letters)) || (firstname.trim() === '')  )
             {
                  //component.set("v.showError",true);
                  //component.set("v.errorMessage","Please enter a valid first name");
                  //component.set('v.disableSubmitButton', true);
                  inputCmp.setCustomValidity("Please enter a valid first name.");
             }
            else
            {
                //component.set("v.showError",false);
                //component.set("v.errorMessage",null);
                inputCmp.setCustomValidity("");
                helper.DisableButton(component,event,helper);

            }
            inputCmp.reportValidity();
     },
     checkNameValidation1: function(component, event, helper){

             debugger;
             var inputCmp = component.find("lastname");
             var value = inputCmp.get("v.value");
             inputCmp.setCustomValidity("");
             var lastname = component.find("lastname").get("v.value");
             //var letters = "^(?:[A-Za-z]+)(?:[A-Za-z0-9 _]*)$";
              var letters = new RegExp('^[a-zA-Z0-9-_\',. ]*$') ;

              //add field length validation
             if ((! lastname.match(letters)) || (lastname.trim() === '')  )
              {
                   //component.set("v.showError",true);
                   //component.set("v.errorMessage","Please enter a valid last name");
                   //component.set('v.disableSubmitButton', true);
                   inputCmp.setCustomValidity("Please enter a valid last name.");
              }
             else
             {
                 //component.set("v.showError",false);
                 //component.set("v.errorMessage",null);
                 inputCmp.setCustomValidity("");
                 helper.DisableButton(component,event,helper);
             }
             inputCmp.reportValidity();
     },
     checkNicknameValidation: function(component, event, helper){

                  debugger;
                  var inputCmp = component.find("nickname");
                  var value = inputCmp.get("v.value");
                  inputCmp.setCustomValidity("");
                  var nickname = component.find("nickname").get("v.value");
                  //var letters = "^(?:[A-Za-z]+)(?:[A-Za-z0-9 _]*)$";
                   //var letters = new RegExp('^[a-zA-Z0-9-_\',. ]*$') ;
                  if ((nickname.trim() == '') || (nickname.length) == 0 || (nickname.length > 40))
                   {
                        inputCmp.setCustomValidity("Please enter a valid nickname up to 40 characters.");
                   }
                  else
                  {
                      //component.set("v.showError",false);
                      //component.set("v.errorMessage",null);
                      inputCmp.setCustomValidity("");
                      helper.DisableButton(component,event,helper);
                  }
                  inputCmp.reportValidity();
          },
    checkPinValidation: function(component, event, helper){

             debugger;
             var inputCmp = component.find("pin");
             var value = inputCmp.get("v.value");
             var pin = component.find("pin").get("v.value");
             var letters = "^[0-9]+$";
             if ((! pin.match(letters)) || (pin.trim() === '') || ((pin.length < 4)) )
              {
                   //component.set("v.showError",true);
                   //component.set("v.errorMessage","Please enter a valid PIN");
                   inputCmp.setCustomValidity("Please enter a valid PIN.");
                   //component.set('v.disableSubmitButton', true);
              }
             else
             {
                 //component.set("v.showError",false);
                 //component.set("v.errorMessage",null);
                 inputCmp.setCustomValidity("");
                 helper.DisableButton(component,event,helper);
             }
             inputCmp.reportValidity();
     },

    checkDateValidation: function(component, event, helper){

        debugger;
        var birthMonth = component.find("birthMonth").get("v.value");
        var bMonth = parseInt(birthMonth) + 1;
        var birthDay = component.find("birthDay").get("v.value");
        var birthYear = component.find("birthYear").get("v.value");
        var selectedbirthDay = bMonth+' '+birthDay+','+ ' '+birthYear;
        var birthDayNumber = isNaN(birthDay);
        //alert(birthDayNumber);

        if(birthDayNumber)
        {
            //component.set('v.disableSubmitButton', true);
            component.set('v.DOBShowError',true);
            component.set('v.DOBErrorMessage',"Invalid birth date");
        }
        else
        {
        let action = component.get("c.dateValidation");

                action.setParams({
                    year: birthYear,
                    month: bMonth,
                    day: birthDay
                });
                action.setCallback(this, function(response) {
                        var objReturn = response.getReturnValue();
                        var state = response.getState();


                        if(objReturn.startsWith('Valid'))
                        {
                           //  alert(objReturn.split(";")[1]);
                             component.set('v.DOBShowError',false);
                             component.set('v.DOBErrorMessage',"");
                             var dm = new Date(Date.parse(selectedbirthDay));
                             component.set("v.birthDateValid",true);
                             component.set("v.birthday",returnValue.split(";")[2]);
                             helper.DisableButton(component,event,helper);



                        }
                        else
                        {
                            // component.set('v.disableSubmitButton', true);
                             component.set('v.DOBShowError',true);
                             component.set('v.DOBErrorMessage',objReturn);
                             component.set("v.birthDateValid",false);


                        }
                });
                    
                         // enqueue the Action
                         $A.enqueueAction(action);



        }
    },
    checkEmailChange: function(component, event, helper){
         var emailCmp = component.find("workEmail");
         emailCmp.setCustomValidity("");
         if(email == undefined || email =='')
         {
            emailCmp.setCustomValidity("Please enter your work email.");


         }
         else
         {
            emailCmp.setCustomValidity("");
            helper.DisableButton(component,event,helper);

         }
         emailCmp.reportValidity();


    },
    checkPhoneChange : function(component, event, helper){

        var phoneCmp = component.find("phone");
        var phone = component.find("phone").get("v.value");

        phoneCmp.setCustomValidity("");
        if(phone == undefined || phone =='' )
        {
            phoneCmp.setCustomValidity("Please enter your phone number.");

        }
        else
        {
            phoneCmp.setCustomValidity("");
            helper.DisableButton(component,event,helper);

        }
        phoneCmp.reportValidity();

    },
    checkAcessCode: function(component, event, helper){
        debugger;

        if(component.find("checkboxAccessCode").get("v.checked") == true)
        {
            component.set("v.haveAcessCode",true);
        }
        else
        {
            component.set("v.haveAcessCode",false);
            component.set("v.validateCount",0);
             component.set("v.disableshowAccess" ,false);
             component.set("v.selectedAccount",null);
             component.set("v.accessCode" , null);


        }
        helper.DisableButton(component,event,helper);


    },

    validateAccessCode: function (component, event, helper) {

                debugger;

                var inputCmp = component.find("accessToken");
                component.set("v.validateerrorMessage", null);
                component.set("v.validateshowError", false);
                helper.spinnerShow(component);
                var action = component.get("c.validateAcessCode");

                var selectedAccountId = component.get("v.selectedAccount.Id");
                debugger;
                action.setParams({
                       accessCode: component.get("v.accessCode"),
                       accountId : selectedAccountId
                                  });
                  action.setCallback(this, function(response){

                    var state = response.getState();

                    if (state === "SUCCESS")
                    {


                        var returnValue = response.getReturnValue();

                        if(returnValue.startsWith('valid'))
                        {

                            component.set("v.disableshowAccess",true);
                            helper.DisableButton(component,event,helper);
                            //inputCmp.setCustomValidity("");
                             component.set("v.validateSuccessMessage", "This code is a valid access code.");
                             component.set("v.validateshowSuccess", true);

                             component.set("v.accessCodeId",returnValue.split(";")[1]);
                             component.set("v.accessCodeUsage",returnValue.split(";")[2]);
                              component.set("v.trustedAgentType",returnValue.split(";")[3]);
                             component.set("v.validateResponse", "valid");

                        }
                        else if (returnValue.startsWith('more'))
                        {
                             var count = component.get("v.validateCount") + 1;
                             component.set("v.validateCount" ,count);

                             component.set("v.validateResponse", "more");

                             component.set("v.accessCodeId",returnValue.split(";")[1]);

                            // if(count >=3)
                            // {
                                // helper.spinnerHide(component);
                                 component.set("v.disableshowAccess",true);
                                 helper.DisableButton(component,event,helper);

                            // }
                           // inputCmp.setCustomValidity("This code has been used more than ten times. If you feel this level of access is correct, please submit the Access Request and it will be submitted for review by your District’s trusted agents.");
                            component.set("v.validateerrorMessage", "This code has been used more than ten times. If you feel this level of access is correct, please submit the Access Request and it will be submitted for review by your District’s trusted agents.");
                            component.set("v.validateshowError", true);
                             //helper.spinnerHide(component);

                        }
                        else if(returnValue =='Invalid')
                        {
                             var count = component.get("v.validateCount") + 1;
                             component.set("v.validateCount" ,count);
                              component.set("v.validateResponse", "Invalid");

                             if(count >=3)
                             {
                                helper.spinnerHide(component);
                                component.set("v.disableshowAccess",true);

                               // alert(count);
                                component.set("v.validateerrorMessage", "This code is either incorrect or not valid. Please double-check your entry. If it's correct, submit the form and it will be manually reviewed by ACT.");
                                component.set("v.validateshowError", true);
                                helper.DisableButton(component,event,helper);
                                //inputCmp.setCustomValidity("This code is either incorrect or not valid. Please double-check your entry. If it's correct, submit the form and it will be manually reviewed by ACT.");


                             }
                             else
                             {

                                  //inputCmp.setCustomValidity("This code is either incorrect or not valid. Please double-check your entry.");

                                 component.set("v.validateerrorMessage", "This code is either incorrect or not valid. Please double-check your entry.");
                                 component.set("v.validateshowError", true);

                             }
                        }
                        helper.spinnerHide(component);

                    }
                    else
                   {
                       helper.spinnerHide(component);
                       var strError = response.getError()[0].message;
                       component.set("v.showError", true);

                   }
                    //inputCmp.reportValidity();
                  });

                    $A.enqueueAction(action);


    },
    handleURLRedirect:function(component, event, helper ) {

                window.open('https://www.act.org/the-act/signin','_top')


    },
    handleTermsAndConditions:function(component, event, helper) {
                        window.open('../terms-and-conditions')
    },

    handleActOrgTermsAndConditions:function(component, event, helper) {
                        window.open('https://www.act.org/content/act/en/terms-of-use.html')


    },
    handlePrivacyPolicy:function(component, event, helper) {
                window.open('https://www.act.org/content/act/en/privacy-policy.html')
    }
})
