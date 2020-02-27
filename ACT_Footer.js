/**
 * Created by adamsm on 1/14/2019.
 */
({
    doInit: function (component, event, helper) {
        helper.doInit(component, event, helper);
    },

    handleCheatingClick : function(component, event, helper) {
        helper.gotoUrl('https://www.act.org/content/act/en/report-cheating.html');
    },

    handleDashboardClick : function(component, event, helper) {
        helper.gotoUrl('/');
    },

    handleEmailUsClick : function(component, event, helper) {
        helper.gotoUrl('/contactsupport');
    },

    handleEthicsClick : function(component, event, helper) {
        helper.gotoUrl('https://www.act.org/content/act/en/ethics.html');
    },

    handleKnowledgeClick : function(component, event, helper) {
        helper.gotoUrl('/topiccatalog');
    },

    handleLogoClick : function(component, event, helper) {
        helper.gotoUrl('https://www.act.org/content/act/en.html');
    },

    handleMyAccountClick : function(component, event, helper) {
        helper.gotoUrl('/s/profile/' + component.get('v.userId'));
    },

    handlePrivacyClick : function(component, event, helper) {
        helper.gotoUrl('https://www.act.org/content/act/en/privacy-policy.html');
    },

    handleTermsClick : function(component, event, helper) {
        var urlString = window.location.href;
        var baseURL = urlString.substring(0, urlString.lastIndexOf("/s"));
        window.open(baseURL + '/s/terms-and-conditions','_blank');

    },
})
