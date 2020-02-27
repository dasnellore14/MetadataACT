/**
 * Created by adamsm on 2/7/2019.
 */

public inherited sharing class ACT_GEN_HierarchyFunctions {
    // This function takes a of accounts and recalculates the ACRs for those accounts, based on their status
    // Since the order of incoming changes can include parents/children keep a map of accounts to deactivate all ACRs for
    //   to prevent duplicates or duplicate DML
    // New ACRs will be a map of user to org, with details, then are additive (sub-districts may have more access than
    //   at a district, for example)
    // If an organization is disabled for multiple reasons in the same batch, the last reason will "win"
    // Process all new ACRs, after processing deactivated ACRs

    public static void AccountsAccessRecalculate(List<Account> Accounts, Map<Id, Account> OldAccounts) {
        try {
            // Initialize variables
            list<ACRMVP> lstUpsertACRs = new list<ACRMVP>();
            map<id, Account> mapAccounts = new map<id, Account>();
            map<id, list<Account>> mapChildren = new map<id, list<Account>>();
            map<id, string> mapInactiveAccounts = new map<id, string>();
            set<Id> setNewAccounts = new Set<Id>();
            set<id> setDeactivatedAccounts = new set<id>();
            set<id> setParentAccounts = new set<id>();
            set<id> setReactivatedAccounts = new set<id>();
            set<Id> setReparentedAccounts = new Set<Id>();
            set<id> setWorkingAccounts = new set<id>();

            // Log for debugging
            System.debug('AccountsAccessRecalculate Start...');

            // Look for accounts that have relevant changes, and put them into sets
            for (Account thisA : Accounts) {
                // Filter out the DOE and Tyler
                if (thisA.Name != 'ACT INCORPORATED TYLER BUILDING' && thisA.Name != 'US DEPARTMENT OF EDUCATION') {
                    // See what type of organization this is
                    boolean blnSchoolOrSubdistrict = thisA.eMetric_Org_Type__c == 'B' || (String.isEmpty(thisA.eMetric_Org_Type__c));
                    string strAction = 'None';

                    // Get the old account
                    Account oldAccount = OldAccounts.get(thisA.Id);

                    // Find new school/sub-district accounts, that have parents
                    if (oldAccount == null && thisA.ParentId != null && blnSchoolOrSubdistrict) {
                        setNewAccounts.add(thisA.Id);
                        setParentAccounts.add(thisA.ParentId);
                        strAction = 'New Account';
                    }

                    // Find re-parented school/sub-district accounts (includes moving to/from no parent)
                    if (oldAccount != null && oldAccount.ParentId != thisA.ParentId && blnSchoolOrSubdistrict) {
                        setReparentedAccounts.add(thisA.Id);

                        if (thisA.ParentId != null) {
                            setParentAccounts.add(thisA.ParentId);
                        }

                        strAction = 'Re-parented Account';
                    }

                    // Find deactivated accounts, that aren't states
                    if (oldAccount != null && oldAccount.Active__c == true && thisA.Active__c == false && thisA.eMetric_Org_Type__c != 'S') {
                        setDeactivatedAccounts.add(thisA.Id);
                        strAction = 'Deactivated Account';
                    }

                    // Find reactivated school/sub-district accounts with a parent
                    if (oldAccount != null && oldAccount.Active__c == false && thisA.Active__c == true && thisA.ParentId != null && blnSchoolOrSubdistrict) {
                        setReactivatedAccounts.add(thisA.Id);
                        setParentAccounts.add(thisA.ParentId);
                        strAction = 'Reactivated Account';
                    }

                    // Debug the action taken
                    System.debug('Account = ' + thisA.Name + ', Id = ' + thisA.Id + ', Action = ' + strAction);
                }
            }

            // Get the necessary data for all the relevant accounts, and map them
            setWorkingAccounts.clear();

            setWorkingAccounts.addAll(setDeactivatedAccounts);
            setWorkingAccounts.addAll(setNewAccounts);
            setWorkingAccounts.addAll(setParentAccounts);
            setWorkingAccounts.addAll(setReactivatedAccounts);
            setWorkingAccounts.addAll(setReparentedAccounts);

            List<Account> lstRelevantAccounts =
            [
                    SELECT
                            Id,
                            Name,
                            Active__c,
                            eMetric_Org_Type__c,
                            MDM_ID__c,
                            ParentId,
                            Parent.Active__c,
                            Parent.eMetric_Org_Type__c,
                            Parent.Name
                    FROM
                            Account
                    WHERE
                            Id in: setWorkingAccounts
            ];

            for (Account thisA: lstRelevantAccounts) {
                mapAccounts.put(thisA.Id, thisA);
            }

            // Get the current user
            User thisU = [SELECT Id, ContactId FROM User WHERE Id =: UserInfo.getUserId()];

            // Get all the children for appropriate accounts, including inactive children
            setWorkingAccounts.clear();

            setWorkingAccounts.addAll(setDeactivatedAccounts);
            setWorkingAccounts.addAll(setReparentedAccounts);

            mapChildren = getAccountIdToChildrenMap(setWorkingAccounts, true, true);

            // ======================
            // Now start looking for changes
            // ======================

            // Look for children where the parents have changed, and should result in ACR deactivation for the old account and their children
            for (Id thisAId : setReparentedAccounts) {
                list<Account> lstAChildren = mapChildren.get(thisAId);

                for (Account thisA : lstAChildren) {
                    mapInactiveAccounts.put(thisA.Id, 'Parent Change');
                }
            }

            // Loop through deactivated accounts, and flag those accounts and their children to have the ACRs deactivated
            for (Id thisAId : setDeactivatedAccounts) {
                // Deactivate the ACRs of the account and its children because of an org inactivation
                list<Account> lstATemp = mapChildren.get(thisAId);

                for (Account thisAT : lstATemp) {
                    mapInactiveAccounts.put(thisAT.Id, 'Org Inactivation');
                }
            }

            // Get the ACRs for the accounts with changes, as well as relevant parents
            setWorkingAccounts.clear();

            setWorkingAccounts.addAll(mapInactiveAccounts.keySet());

            for (Id thisAId : setParentAccounts) {
                Account thisParent = mapAccounts.get(thisAId);

                // Only add parents that are districts or sub-districts
                if (thisParent.eMetric_Org_Type__c == 'D' || (String.isEmpty(thisParent.eMetric_Org_Type__c) && thisParent.Parent.eMetric_Org_Type__c == 'D')) {
                    setWorkingAccounts.add(thisParent.Id);
                }
            }

            // Get all ACRs for relevant accounts, for all roles
            // Note you must pass ActiveOnly = false to get the ACRs for the recently deactivated accounts
            map<id, list<AccountContactRelation>> mapACRs = getAccountIdToUserMap(setWorkingAccounts, false, null);

            // Process deactivations completely first, before processing additions
            // This is important for reparented accounts
            list<ACRMVP> lstDeactivations = new list<ACRMVP>();

            for (id thisAId : mapInactiveAccounts.keySet()) {
                list<AccountContactRelation> thisLstACR = mapACRs.get(thisAId);

                if (thisLstACR != null) {
                    for (AccountContactRelation thisACR : thisLstACR) {
                        // Only deactivate currently active ACRs
                        if (thisACR.IsActive) {
                            ACRMVP thisACRMVP = new ACRMVP();

                            thisACRMVP.Active = false;
                            thisACRMVP.AccountId = thisAId;
                            thisACRMVP.AuditChangeType = 'Trigger';
                            thisACRMVP.AuditChangeTypeId = null;
                            thisACRMVP.AuditContactId = thisU.ContactId;
                            thisACRMVP.AuditReason = mapInactiveAccounts.get(thisAId);
                            thisACRMVP.ContactId = thisACR.ContactId;
                            thisACRMVP.Status = 'Inactive';

                            lstDeactivations.add(thisACRMVP);
                        }
                    }
                }
            }

            if (lstDeactivations.size() > 0) {
                setACRAccess(lstDeactivations);
            }

            // For the new accounts with district/sub-district parents, create new ACR records for them matching their parent.
            for (Id thisAId : setNewAccounts) {
                Account thisA = mapAccounts.get(thisAId);

                // Add the parent's acrs (note, no acrs will be present in mapACRs if the parent is not a district/sub-district)
                lstUpsertACRs.addAll(assignParentACRsToChildren(mapACRs, thisAId, thisA.ParentId, thisU.ContactId, 'New Account', true));
            }

            // For the accounts with new district/sub-district parents, create new ACR records for them matching their parent.
            for (Id thisAId : setReparentedAccounts) {
                Account thisA = mapAccounts.get(thisAId);

                // Add the parent's acrs (note, no acrs will be present in mapACRs if the parent is not a district/sub-district)
                if (thisA.ParentId != null) {
                    lstUpsertACRs.addAll(assignParentACRsToChildren(mapACRs, thisAId, thisA.ParentId, thisU.ContactId, 'Parent Change', true));
                }
            }

            // Process reactivated accounts, based on their parents
            for (Id thisAId : setReactivatedAccounts) {
                Account thisA = mapAccounts.get(thisAId);

                // Add the parent's acrs (note, no acrs will be present in mapACRs if the parent is not a district/sub-district)
                if (thisA.ParentId != null) {
                    lstUpsertACRs.addAll(assignParentACRsToChildren(mapACRs, thisAId, thisA.ParentId, thisU.ContactId, 'Reactivation', false));
                }
            }

            // Process all the ACRs
            if (lstUpsertACRs.size() > 0) {
                setACRAccess(lstUpsertACRs);
            }
        }
        catch (Exception ex) {
            // Flag the error
            system.debug('Exception occurred in AccountsAccessRecalculate >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'AccountsAccessRecalculate', ex.getMessage(), '', '', '');
        }
    }

    // Adds the 'IDP Registration' ACR to users, if needed.  Then deactivates all other ACRs
    @Future
    public static void deactivateUsers(set<Id> ContactIds) {
        try {
            // Log the function
            system.debug('deactivateUsers, ContactIds = ' + string.valueOf(ContactIds));

            // Get the id for the IDP Registration account
            list<NetworkSelfRegistration> lstIDP = [
                    SELECT
                            AccountId
                    FROM
                            NetworkSelfRegistration
                    WHERE
                            NetworkId In (SELECT Id FROM Network WHERE Name = 'ACT Success')
            ];

            id IdIDPId = lstIDP.size() > 0 ? lstIDP[0].AccountId : null;

            system.debug('IDP Account = ' + IdIDPId);

            // Get all ACRs for the affected users
            Set<Id> setHasIDP = new Set<Id>();

            list<AccountContactRelation> lstIDPACR =
            [
                    SELECT
                            AccountId,
                            ContactId
                    FROM
                            AccountContactRelation
                    WHERE
                            ContactId in: ContactIds
            ];

            // Deactivate all ACRs, except for the IDP
            for (AccountContactRelation thisACR : lstIDPACR) {
                if (thisACR.AccountId != IdIDPId) {
                    thisACR.IsActive = false;
                    thisACR.Status__c = 'Inactive';
                }
            }

            // Update the changes
            if (lstIDPACR.size() > 0) {
                update lstIDPACR;
            }

            // Log the changes to the audit log
            // TODO:Do this in Omniscient
        }
        catch (Exception ex) {
            system.debug('Exception occurred in deacivateUsers >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'deacivateUsers', ex.getMessage(), '', '', '');
            throw ex;
        }
    }

    // Returns a map of account ids to a map of contact ids to AccountContactRelation records for those accounts
    // ActiveOnly will filter the results to only active relationships
    // LimitToRole will filter the results to only the passed roll, if not null
    // This function does not consider districts/parents
    public static map<id, map<id, AccountContactRelation>> getAccountIdToACRMap (set<id> AccountIds, boolean ActiveOnly, string LimitToRole) {
        try {
            // Create a map to return
            map<id, map<id, AccountContactRelation>> mapReturn = new map<id, map<id, AccountContactRelation>>();

            // Get the account to ACR list map
            map<Id, List<AccountContactRelation>> mapACR = getAccountIdToUserMap(AccountIds, ActiveOnly, LimitToRole);

            // Convert each list to a map
            for (Id thisAId : mapACR.keySet()) {
                List<AccountContactRelation> lstAACR = mapACR.get(thisAId);
                map<Id, AccountContactRelation> mapAACR = new map<Id, AccountContactRelation>();

                for (AccountContactRelation thisACR : lstAACR) {
                    mapAACR.put(thisACR.ContactId, thisACR);
                }

                mapReturn.put(thisAId, mapAACR);
            }

            return mapReturn;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToACRMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of accounts to a map of those needing hierarchy approval, by academic year
    // LimitToApprovalNeeded will filter the results to only those needing approval
    public static map<id, map<integer, boolean>> getAccountIdToApprovalNeededMap (set<id> AccountIds, Boolean LimitToApprovalNeeded) {
        try {
            // Create a map to return
            map<id, map<integer, boolean>> mapAccountToApproval = new map<id, map<integer, boolean>>();

            // Get the map of the accounts to their Hierarchy Approval records
            map<id, map<integer, Hierarchy_Approval__c>> mapAccountToHA = getAccountIdToHierarchyApprovalMap(AccountIds);

            // Return a map of the accounts, and if they need approval or not
            for (id thisAccount : AccountIds) {
                map<integer, Hierarchy_Approval__c> thisHAMap = mapAccountToHA.get(thisAccount);
                map<integer, boolean> mapHATemp = new map<integer, boolean>();

                for (integer thisAY : ACT_CommunityConstants.HA_AcademicYearAPIName.keySet()) {
                    Hierarchy_Approval__c thisHA;

                    if (thisHAMap != null) {
                        thisHA = thisHAMap.get(thisAY);
                    }

                    boolean blnApprovalNeeded = thisHA == null ? false : thisHA.Status__c == 'Approval Required';

                    if (!LimitToApprovalNeeded || blnApprovalNeeded) {
                        mapHATemp.put(thisAY, blnApprovalNeeded);
                    }
                }

                if (mapHATemp.size() > 0)
                {
                    mapAccountToApproval.put(thisAccount, mapHATemp);
                }
            }

            return mapAccountToApproval;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToApprovalNeededMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of accounts to whether they are considered approved or not
    // Note that approvals are required for the current year, and optional for future years
    public static map<id, boolean> getAccountIdToApprovedMap (set<id> AccountIds) {
        try {
            // Create a map to return
            map<id, boolean> mapAccountToApproval = new map<id, boolean>();

            // Get the map of the accounts to their Hierarchy Approval records
            map<id, map<integer, Hierarchy_Approval__c>> mapAccountToHA = getAccountIdToHierarchyApprovalMap(AccountIds);

            // Return a map of the accounts, and if they are approved or not
            for (id thisAccount : AccountIds) {
                map<integer, Hierarchy_Approval__c> thisHAMap = mapAccountToHA.get(thisAccount);

                for (integer thisAY : ACT_CommunityConstants.HA_AcademicYearAPIName.keySet()) {
                    boolean blnApproved = true;
                    Hierarchy_Approval__c thisHA;

                    if (thisHAMap != null) {
                        thisHA = thisHAMap.get(thisAY);
                    }

                    // Check for the current year
                    if (thisAY == 0 && thisHA == null) {
                        blnApproved = false;
                    }
                    else if (thisHA != null && thisHA.Status__c != 'Approved') {
                        blnApproved = false;
                    }

                    mapAccountToApproval.put(thisAccount, blnApproved);
                }
            }

            return mapAccountToApproval;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToApprovedMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of accounts to a list of all their children accounts
    // IncludePassedAccounts = True will include the accounts passed in the AccountIds along with the children.
    // IncludePassedAccounts = False will only include the children, and not the passed in accounts.
    // This function also does not consider the type of account (state, district, etc.), it just gets all the children in one map
    // If IncludeInactiveAccounts = false, it will not return in the list any accounts that are inactive, or their children
    public static map<id, list<Account>> getAccountIdToChildrenMap (set<id> AccountIds, boolean IncludePassedAccounts, boolean IncludeInactiveAccounts) {
        try {
            // Log the function
            system.debug('getAccountIdToChildrenMap, accounts = ' + string.valueOf(AccountIds));

            // Abort if there are no accounts passed in
            if (AccountIds == null || (AccountIds.size() == 1 && AccountIds.contains(null))) {
                return null;
            }

            // Create a map to keep track of children ids
            map<id, set<id>> mapAccountIdToChildrenSet = new map<id, set<id>>();

            // Create a map to return the children as accounts
            map<id, list<Account>> mapAccountIdToChildren = new map<id, list<Account>>();

            for (id thisId : AccountIds) {
                mapAccountIdToChildrenSet.put(thisId, new set<id>());
                mapAccountIdToChildren.put(thisId, new list<Account>());
            }

            // Variables to manage the tree search
            set<id> setCurrentParents = new set<id>{};
            Integer intLevel = 0;

            // Start with the passed in set of accounts
            setCurrentParents.addAll(AccountIds);

            // Loop though and find all the children
            while (setCurrentParents.size() > 0 && intLevel < 25) {
                List<Account> lstChildren =
                [
                        SELECT
                                Id,
                                Name,
                                Active__c,
                                BillingCity,
                                BillingPostalCode,
                                BillingState,
                                BillingStreet,
                                eMetric_Org_Type__c,
                                Industry,
                                MDM_ID__c,
                                ParentId,
                                Type,
                                Parent.eMetric_Org_Type__c,
                                Parent.Name,
                                Historical_MDM_ID__c
                        FROM
                                Account
                        WHERE
                                ParentId in: setCurrentParents
                ];

                system.debug('Level ' + intLevel + ' Accounts = ' + lstChildren.size());

                // Clear out the parents
                setCurrentParents.clear();

                // Loop through the children
                for (Account thisAccount : lstChildren) {
                    // Only include active accounts, if IncludeInactiveAccounts is false
                    if (IncludeInactiveAccounts || thisAccount.Active__c) {
                        // Add each account as a new parent
                        setCurrentParents.add(thisAccount.id);

                        // Add the children to the maps
                        if (intLevel == 0) {
                            // For the first level, just add the children to the maps
                            set<id> setChild = mapAccountIdToChildrenSet.get(thisAccount.ParentId);
                            list<Account> lstChild = mapAccountIdToChildren.get(thisAccount.ParentId);

                            setChild.add(thisAccount.id);
                            lstChild.add(thisAccount);

                            mapAccountIdToChildrenSet.put(thisAccount.ParentId, setChild);
                            mapAccountIdToChildren.put(thisAccount.ParentId, lstChild);
                        }
                        else {
                            // For the subsequent levels, find the parent(s), then add the children to those maps
                            for (id AccountId : AccountIds) {
                                set<id> setChildren = mapAccountIdToChildrenSet.get(AccountId);

                                if (setChildren.contains(thisAccount.ParentId)) {
                                    set<id> setChild = mapAccountIdToChildrenSet.get(AccountId);
                                    list<Account> lstChild = mapAccountIdToChildren.get(AccountId);

                                    setChild.add(thisAccount.id);
                                    lstChild.add(thisAccount);

                                    mapAccountIdToChildrenSet.put(AccountId, setChild);
                                    mapAccountIdToChildren.put(AccountId, lstChild);
                                }
                            }
                        }
                    }
                }

                // Increment the level
                intLevel++;
            }

            // If IncludePassedAccounts is true, add the original accounts to the maps
            if (IncludePassedAccounts) {
                List<Account> lstParents =
                [
                        SELECT
                                Id,
                                Name,
                                Active__c,
                                BillingCity,
                                BillingPostalCode,
                                BillingState,
                                BillingStreet,
                                eMetric_Org_Type__c,
                                Industry,
                                MDM_ID__c,
                                ParentId,
                                Type,
                                Parent.eMetric_Org_Type__c,
                                Parent.Name,
                                Historical_MDM_ID__c
                        FROM
                                Account
                        WHERE
                                Id in: AccountIds
                ];

                for (Account thisAccount : lstParents) {
                    // Note, only include active accounts, if IncludeInactiveAccounts is false
                    if (IncludeInactiveAccounts || thisAccount.Active__c) {
                        list<Account> lstThis = mapAccountIdToChildren.get(thisAccount.Id);
                        lstThis.add(thisAccount);
                        mapAccountIdToChildren.put(thisAccount.Id, lstThis);
                    }
                }
            }

            return mapAccountIdToChildren;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToChildrenMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of accounts to their suitable parent item IDs
    // Parent Types are eMetricOrgTypes to look for (D=District, S=State, Null=Subdistrict)
    //      Subdistricts must also be a child of an account with an eMetricOrgType of 'D'
    // If a suitable parent for an account is not found, those accounts will map to themselves
    public static map<id, id> getAccountIdToParentIdMap (set<id> AccountIds, set<string> ParentTypes) {
        try {
            // Declare Variables
            map<id, id> mapAccountToViableParent = new map<id, id>();
            map<id, id> mapAccountToCurrentParent = new map<id, id>();
            set<id> setLookForParents = new set<id>();

            // Add the original set of accounts to the set used to look for parents
            setLookForParents.addAll(AccountIds);

            // Originally set all accounts to be their own parent
            for (id thisA : AccountIds) {
                mapAccountToViableParent.put(thisA, thisA);
                mapAccountToCurrentParent.put(thisA, thisA);
            }

            // Keep going up the tree until a district is found, or there is no more parent
            while (setLookForParents.size() > 0) {
                // Get the list of accounts in setLookForParents
                list<Account> lstAccounts =
                [
                        SELECT
                                Id,
                                Active__c,
                                eMetric_Org_Type__c,
                                ParentId,
                                Parent.eMetric_Org_Type__c
                        FROM
                                Account
                        WHERE
                                Id In: setLookForParents
                ];

                // Clear out the set, and add back accounts that still have not found a district, or the top of the tree
                setLookForParents.clear();

                for (Account thisA : lstAccounts) {
                    // Look if the current org is a viable parent
                    // Note that subdistricts must have a null eMetricsOrgType and have a district parent
                    if (ParentTypes.contains(thisA.eMetric_Org_Type__c) && (thisA.eMetric_Org_Type__c != null || (thisA.ParentId != null && thisA.Parent.eMetric_Org_Type__c == 'D'))) {
                        // If a suitable parent is found, flag it as the parent for any accounts that consider that
                        // account it's parent
                        for (id thisChild : AccountIds) {
                            if (mapAccountToCurrentParent.get(thisChild) == thisA.id) {
                                mapAccountToViableParent.put(thisChild, thisA.id);
                            }
                        }
                    }
                    else {
                        // If the parent wasn't suitable, check if there is another parent above this parent, and add that
                        // parent to the set to look for on the next pass.
                        if (thisA.ParentId != null)
                        {
                            // Add the parent to the next round
                            setLookForParents.add(thisA.ParentId);

                            // Set the current parent for the children
                            for (id thisChild : AccountIds) {
                                if (mapAccountToCurrentParent.get(thisChild) == thisA.id) {
                                    mapAccountToCurrentParent.put(thisChild, thisA.ParentId);
                                }
                            }
                        }
                    }
                }
            }

            return mapAccountToViableParent;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToParentMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Return a map of accounts to a map of their associated hierarchy approval records, by academic year (as an integer, 0 for current, negative number for years back)
    // The function first looks for a district of the account, if one exists
    public static map<id, map<integer, Hierarchy_Approval__c>> getAccountIdToHierarchyApprovalMap (set<id> AccountIds) {
        try {
            // Declare Variables
            map<id, map<integer, Hierarchy_Approval__c>> mapAccountToHA = new map<id, map<integer, Hierarchy_Approval__c>>();

            // Get the account/parent map
            map<id, id> mapAccountToDistrict = getAccountIdToParentIdMap(AccountIds, new Set<String>{'D'});

            // Now that the parent accounts are found, get the hierarchy approval records
            list<Hierarchy_Approval__c> lstHA =
            [
                    SELECT
                            Id,
                            Academic_Year__c,
                            District_Account__c,
                            District_Account__r.Aggregated_Hierarchy_Submitted__c,
                            District_Account__r.Current_Year_Hierarchy__c,
                            District_Account__r.MDM_ID__c,
                            District_Account__r.Name,
                            District_Account__r.One_Year_Previous_Hierarchy__c,
                            District_Account__r.Two_Years_Previous_Hierarchy__c,
                            Initial_Approval_Date__c,
                            Previous_Status__c,
                            Status__c,
                            Verification_Case__c
                    FROM
                            Hierarchy_Approval__c
                    WHERE
                            District_Account__c in : mapAccountToDistrict.values()
                    ORDER BY
                            CreatedDate ASC
            ];

            // Load the hierarchy approvals into a map by account
            // Note that records will be map with their associated academic years
            map<id, map<integer, Hierarchy_Approval__c>> mapDistrictHAs = new map<id, map<integer, Hierarchy_Approval__c>>();

            for (Hierarchy_Approval__c thisHA : lstHA)
            {
                // Set up the academic year map for the district
                map<integer, Hierarchy_Approval__c> mapAcademicYears = mapDistrictHAs.get(thisHA.District_Account__c);

                if (mapAcademicYears == null) {
                    mapAcademicYears = new map<integer, Hierarchy_Approval__c>();
                }

                for (integer thisAY : ACT_CommunityConstants.HA_AcademicYearAPIName.keySet()) {
                    if (thisHA.Id == thisHA.getSobject('District_Account__r').get(ACT_CommunityConstants.HA_AcademicYearAPIName.get(thisAY))) {
                        mapAcademicYears.put(thisAY, thisHA);
                    }
                }

                mapDistrictHAs.put(thisHA.District_Account__c, mapAcademicYears);
            }

            // Map the original accounts to the hierarchy records
            for (id thisId : mapAccountToDistrict.keySet())
            {
                mapAccountToHA.put(thisId, mapDistrictHAs.get(mapAccountToDistrict.get(thisId)));
            }

            // Return the map
            return mapAccountToHA;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToHierarchyApprovalMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of account ids to a list of AccountContactRelation records for those accounts
    // ActiveOnly will filter the results to only active relationships
    // LimitToRole will filter the results to only the passed roll, if not null
    // This function does not consider districts/parents
    public static map<id, list<AccountContactRelation>> getAccountIdToUserMap (set<id> AccountIds, boolean ActiveOnly, string LimitToRole) {
        try {
            // Create a map to return
            map<id, list<AccountContactRelation>> mapAccountToUser = new map<id, list<AccountContactRelation>>();

            // Get the appropriate account contact relation records for the accounts
            List<AccountContactRelation> listACR =
            [
                    SELECT
                            AccountId,
                            ContactId,
                            Ed_Fi_Role__c,
                            eMetrics_Role__c,
                            IsActive,
                            Status__c,
                            Success_Community_Role__c,
                            TAA_Role__c,
                            Account.Active__c,
                            Contact.Email,
                            Contact.User__c
                    FROM
                            AccountContactRelation
                    WHERE
                            AccountId in: AccountIds
                    ORDER BY
                            CreatedDate
            ];

            system.debug('getAccountIdToUserMap listACR size = ' + string.valueOf(listACR.size()));

            for (AccountContactRelation thisACR: listACR) {
                if ((!ActiveOnly || (thisACR.IsActive && thisACR.Account.Active__c)) && (LimitToRole == null || thisACR.Success_Community_Role__c == LimitToRole)) {
                    list<AccountContactRelation> lstTemp = mapAccountToUser.get(thisACR.AccountId);

                    if (lstTemp == null)
                    {
                        lstTemp = new list<AccountContactRelation>();
                    }

                    lstTemp.add(thisACR);

                    mapAccountToUser.put(thisACR.AccountId, lstTemp);
                }
            }

            return mapAccountToUser;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToUserMap >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a map of account ids to that user's role for a user
    // ActiveOnly will filter the results to only active relationships
    // LimitToRole will filter the results to only the passed roll, if not null
    // Note this function does not take parents/districts into account
    public static map<id, string> getAccountIdToRoleMapForUser (id UserId, boolean ActiveOnly, string LimitToRole) {
        try {
            // Create a map to return
            map<id, string> mapAccountToRole = new map<id, string>();

            List<AccountContactRelation> listACR =
            [
                    SELECT
                            AccountId,
                            IsActive,
                            Success_Community_Role__c
                    FROM
                            AccountContactRelation
                    WHERE
                            Contact.user__c =: UserId
                    ORDER BY
                            CreatedDate
            ];

            for (AccountContactRelation thisACR: listACR) {
                if ((!ActiveOnly || thisACR.IsActive) && (LimitToRole == null || thisACR.Success_Community_Role__c == LimitToRole)) {
                    mapAccountToRole.put(thisACR.AccountId, thisACR.Success_Community_Role__c);
                }
            }

            return mapAccountToRole;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getAccountIdToRoleMapForUser >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // This function looks to see if there are any hierarchies the passed in user needs to approve
    // Used in various redirect scenarios after login or data change
    // Note this only looks for hierarchies where the user is a trusted agent for the account needing approval
    public static boolean getHierarchyApprovalNeededForUser(string UserId) {
        try {
            // Get the active accounts for this user, where they are a trusted agent, note it does not consider parents/districts
            map<id, string> mapAccountToRole = getAccountIdToRoleMapForUser(UserId, true, 'Trusted Agent');

            // Of the accounts they have access to, find the ones with hierarchy approval records needing approval, this does consider parents/districts
            map<id, map<integer, boolean>> mapAccountToApprovalNeeded = getAccountIdToApprovalNeededMap(mapAccountToRole.keySet(), true);

            // Default to no redirect
            Boolean blnHierarchyRedirect = false;

            // Redirect if there is at least one account that needs to be approved, that they are actually a trusted agent of (don't climb the tree)
            // Do this by looping through the accounts needing approval, and seeing if they are a trusted agent for that account
            for (id AccountId : mapAccountToApprovalNeeded.keySet()) {
                if (mapAccountToRole.keySet().contains(AccountId)) {
                    blnHierarchyRedirect = true;
                }
            }

            return blnHierarchyRedirect;
        }
        catch(Exception ex) {
            // Flag the error
            system.debug('Exception occurred in getHierarchyApprovalNeededForUser >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());

            AuraHandledException AHE = new AuraHandledException(ex.getMessage());
            throw AHE;
        }
    }

    // Returns a list of accounts, based on a hierarchy approval record
    public static list<Account> getHierarchyByHierarchyApproval(Id HierarchyApprovalId)
    {
        // Determine what year it is for
        list<Hierarchy_Approval__c> lstHA =
        [
                SELECT
                        Id,
                        Contract__c,
                        District_Account__c,
                        District_Account__r.Current_Year_Hierarchy__c,
                        District_Account__r.One_Year_Previous_Hierarchy__c,
                        District_Account__r.Two_Years_Previous_Hierarchy__c
                FROM
                        Hierarchy_Approval__c
                WHERE
                        Id =: HierarchyApprovalId
        ];

        if (lstHA.size() == 1)
        {
            // If this hierarchy is for the current year, return the current account and children
            if (lstHA[0].District_Account__r.Current_Year_Hierarchy__c == HierarchyApprovalId) {
                map<id, list<Account>> mapAccountAndChildren = getAccountIdToChildrenMap(new set<Id>{lstHA[0].District_Account__c}, true, false);

                return mapAccountAndChildren.get(lstHA[0].District_Account__c);
            }

            // Otherwise, try get the info from the contract administration participant table
            // Variables to manage the tree search
            set<Contract_Administration_Participant__c> setChildren = new set<Contract_Administration_Participant__c>();
            set<id> setCurrentParents = new set<id>{};
            Integer intLevel = 0;

            // Start with the district, and go down
            setCurrentParents.add(lstHA[0].District_Account__c);

            // Loop though and find all the children
            while (setCurrentParents.size() > 0 && intLevel < 25) {
                list<Contract_Administration_Participant__c> lstChildren =
                [
                        SELECT
                                Account_ID__c,
                                Parent_Account__r.Id
                        FROM
                                Contract_Administration_Participant__c
                        WHERE
                        Contract_Administration_ID__r.Contract_ID__c =: lstHA[0].Contract__c
                        And Parent_Account__r.Id in: setCurrentParents
                ];

                system.debug('Level ' + intLevel + ' Accounts = ' + lstChildren.size());

                // Clear out the parents
                setCurrentParents.clear();

                // Loop through the children
                for (Contract_Administration_Participant__c thisCAP : lstChildren) {
                    // Add each account as a child, and new parent
                    setChildren.add(thisCAP);
                    setCurrentParents.add(thisCAP.Account_ID__c);
                }

                // Increment the level
                intLevel++;
            }

            // Get the accounts, but swap out the parents based on the old hierarchy
            map<Id, Id> mapAccountParents = new map<Id, Id>();
            set<Id> setAccounts = new set<Id>();

            // Add the district, to get that in the hierarchy too
            setAccounts.add(lstHA[0].District_Account__c);

            for (Contract_Administration_Participant__c thisCAP : setChildren) {
                mapAccountParents.put(thisCAP.Account_ID__c, thisCAP.Parent_Account__r.Id);
                setAccounts.add(thisCAP.Account_ID__c);
            }

            list<Account> rstReturn =
            [
                    SELECT
                            Id,
                            Name,
                            Active__c,
                            BillingCity,
                            BillingPostalCode,
                            BillingState,
                            BillingStreet,
                            eMetric_Org_Type__c,
                            Industry,
                            MDM_ID__c,
                            ParentId,
                            Type
                    FROM
                            Account
                    WHERE
                            Id In: setAccounts
            ];

            for (Account thisA : rstReturn) {
                thisA.ParentId = mapAccountParents.get(thisA.Id);
            }

            return rstReturn;
        }

        return null;
    }

    /**
     * @param accessRecord = The access record that would be copied to the children
     * @param accountRecord = The target account
     *
     * @return boolean that is whether or not to copy down to the children
     *
     * Current Logic = If the target account is a district or sub-district, return true, otherwise false
     * Sub-district is determined as the parent being a district, and the org itself has no eMetricsOrgType
     * Note that the access record is included because previous (and potentially future) logic considered
     *   whether or not the access record was for a trusted agent.
     */
    public static boolean getPropagateACRToChildren(Access__c accessRecord, Account accountRecord) {
        return accountRecord.eMetric_Org_Type__c == 'D' || (accountRecord.Parent.eMetric_Org_Type__c == 'D' && String.isEmpty(accountRecord.eMetric_Org_Type__c));
    }

    // If the SuccessCommunityRole is TrustedAgent, and the Account has an eMetricsOrgType of 'D', or has a parent of eMetricsOrgType of 'D' create matching ACRs for the child records
    // If the SuccessCommunityRole is Standard, and the Account has an eMetricsOrgType of null and has a parent of eMetricsOrgType of 'D', then it is considered a sub-district, so create matching ACRs for the child records
    // Should be called from the without sharing wrapper
    public static void grantContactsACRToAccount(Id AccountId, set<Id> ContactIds, String SuccessCommunityRole, String eMetricsRole, String EdFiRole, String TAARole, Id AuditChangeByContact, String AuditChangeType, List<SObject> AuditChangeTypeRecords, String AuditChangeTypeId, String AuditReason) {
        try {
            // Get the target account
            list<Account> lstAccounts = [
                    SELECT
                            Id,
                            Name,
                            Active__c,
                            eMetric_Org_Type__c,
                            Parent.eMetric_Org_Type__c
                    FROM
                            Account
                    WHERE
                            Id = :AccountId
            ];

            // Abort if no account found
            if (lstAccounts.size() != 1) {
                throw new CC_SC_GEN_Exception('The requested account was not found, please try again.');
            }

            // Check for children accounts
            Access__c thisAccess = new Access__c();

            thisAccess.eMetrics_Role__c = eMetricsRole;

            boolean blnIncludeChildren = ACT_GEN_HierarchyFunctionsWithoutSharing.getPropagateACRToChildren(thisAccess, lstAccounts[0]);

            if (blnIncludeChildren) {
                map<id, list<Account>> mapChildren = getAccountIdToChildrenMap(new set<id>{AccountId}, false, true);

                list<Account> lstChildren = mapChildren.get(AccountId);

                if (lstChildren != null && lstChildren.size() > 0) {
                    lstAccounts.addAll(lstChildren);
                }
            }

            // Create a list to hold the new ACRs
            list<ACRMVP> lstACRMVP = new list<ACRMVP>();

            // Create a map of AuditChangeTypeRecords to their key
            map<Id, SObject> mapACTR = new map<Id, SObject>();

            if (AuditChangeTypeRecords != null && AuditChangeTypeRecords.size() > 0) {
                // Handle the change, based on the type
                switch on AuditChangeType {
                    when 'Access' {
                        for (Access__c thisA : (List<Access__c>)AuditChangeTypeRecords) {
                            mapACTR.put(thisA.Community_Contact__c, thisA);
                        }
                    }
                }
            }

            // Loop through and create the new ACRs
            for (Account thisAccount : lstAccounts) {
                for (Id ContactId : ContactIds) {
                    ACRMVP newACRMVP = new ACRMVP();

                    newACRMVP.AccountId = thisAccount.Id;
                    newACRMVP.ContactId = ContactId;
                    newACRMVP.Contract = '99_2018_2019';
                    newACRMVP.EdfiRole = EdFiRole;
                    newACRMVP.eMetricsRole = eMetricsRole;
                    newACRMVP.SuccessCommunityRole = SuccessCommunityRole;
                    newACRMVP.TAARole = TAARole;

                    // Base active/statue off of the account active field
                    if (thisAccount.Active__c) {
                        newACRMVP.Active = true;
                        newACRMVP.Status = 'Active';
                    }
                    else {
                        newACRMVP.Active = false;
                        newACRMVP.Status = 'Inactive';
                    }

                    // Only do upgrades
                    newACRMVP.UpgradeRolesOnly = true;

                    // Pass the audit values
                    newACRMVP.AuditChangeType = AuditChangeType;
                    newACRMVP.AuditContactId = AuditChangeByContact;
                    newACRMVP.AuditReason = AuditReason;

                    if (AuditChangeTypeId != null) {
                        newACRMVP.AuditChangeTypeId = AuditChangeTypeId;
                    }

                    if (AuditChangeTypeRecords != null && AuditChangeTypeRecords.size() > 0) {
                        // Handle the change, based on the type
                        switch on AuditChangeType {
                            when 'Access' {
                                Access__c thisA = (Access__c)mapACTR.get(ContactId);

                                if (thisA != null) {
                                    newACRMVP.AuditChangeTypeId = thisA.Id;
                                }
                            }
                        }
                    }

                    lstACRMVP.add(newACRMVP);
                }
            }

            setACRAccess(lstACRMVP);
        }
        catch (Exception ex) {
            system.debug('Exception occurred in grantACRToContact >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'grantACRToContact', ex.getMessage(), '', '', '');
            throw ex;
        }
    }

    public static void grantContactsACRToAccountWithPANext(Id AccountId, set<Id> ContactIds, String SuccessCommunityRole, String eMetricsRole, String EdFiRole, String TAARole, Id AuditChangeByContact, String AuditChangeType, List<SObject> AuditChangeTypeRecords, String AuditChangeTypeId, String AuditReason,String OLRAccessLevel) {
        try {
            // Get the target account
            list<Account> lstAccounts = [
                    SELECT
                            Id,
                            Name,
                            Active__c,
                            eMetric_Org_Type__c,
                            Parent.eMetric_Org_Type__c
                    FROM
                            Account
                    WHERE
                            Id = :AccountId
            ];

            // Abort if no account found
            if (lstAccounts.size() != 1) {
                throw new CC_SC_GEN_Exception('The requested account was not found, please try again.');
            }

            // Check for children accounts
            Access__c thisAccess = new Access__c();

            thisAccess.eMetrics_Role__c = eMetricsRole;

            boolean blnIncludeChildren = ACT_GEN_HierarchyFunctionsWithoutSharing.getPropagateACRToChildren(thisAccess, lstAccounts[0]);

            if (blnIncludeChildren) {
                map<id, list<Account>> mapChildren = getAccountIdToChildrenMap(new set<id>{AccountId}, false, true);

                list<Account> lstChildren = mapChildren.get(AccountId);

                if (lstChildren != null && lstChildren.size() > 0) {
                    lstAccounts.addAll(lstChildren);
                }
            }

            // Create a list to hold the new ACRs
            list<ACRMVP> lstACRMVP = new list<ACRMVP>();

            // Create a map of AuditChangeTypeRecords to their key
            map<Id, SObject> mapACTR = new map<Id, SObject>();

            if (AuditChangeTypeRecords != null && AuditChangeTypeRecords.size() > 0) {
                // Handle the change, based on the type
                switch on AuditChangeType {
                    when 'Access' {
                        for (Access__c thisA : (List<Access__c>)AuditChangeTypeRecords) {
                            mapACTR.put(thisA.Community_Contact__c, thisA);
                        }
                    }
                }
            }

            // Loop through and create the new ACRs
            for (Account thisAccount : lstAccounts) {
                for (Id ContactId : ContactIds) {
                    ACRMVP newACRMVP = new ACRMVP();

                    newACRMVP.AccountId = thisAccount.Id;
                    newACRMVP.ContactId = ContactId;
                    newACRMVP.Contract = '99_2018_2019';
                    newACRMVP.EdfiRole = EdFiRole;
                    newACRMVP.eMetricsRole = eMetricsRole;
                    newACRMVP.SuccessCommunityRole = SuccessCommunityRole;
                    newACRMVP.TAARole = TAARole;

                    if(OLRAccessLevel != '' && OLRAccessLevel == 'View Contract Deliverables'){
                        newACRMVP.PANextRole = OLRAccessLevel;
                    }

                    // Base active/statue off of the account active field
                    if (thisAccount.Active__c) {
                        newACRMVP.Active = true;
                        newACRMVP.Status = 'Active';
                    }
                    else {
                        newACRMVP.Active = false;
                        newACRMVP.Status = 'Inactive';
                    }

                    // Only do upgrades
                    newACRMVP.UpgradeRolesOnly = true;

                    // Pass the audit values
                    newACRMVP.AuditChangeType = AuditChangeType;
                    newACRMVP.AuditContactId = AuditChangeByContact;
                    newACRMVP.AuditReason = AuditReason;

                    if (AuditChangeTypeId != null) {
                        newACRMVP.AuditChangeTypeId = AuditChangeTypeId;
                    }

                    if (AuditChangeTypeRecords != null && AuditChangeTypeRecords.size() > 0) {
                        // Handle the change, based on the type
                        switch on AuditChangeType {
                            when 'Access' {
                                Access__c thisA = (Access__c)mapACTR.get(ContactId);

                                if (thisA != null) {
                                    newACRMVP.AuditChangeTypeId = thisA.Id;
                                }
                            }
                        }
                    }

                    lstACRMVP.add(newACRMVP);
                }
            }

            setACRAccess(lstACRMVP);
        }
        catch (Exception ex) {
            system.debug('Exception occurred in grantContactsACRToAccountWithPANext >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'grantACRToContact', ex.getMessage(), '', '', '');

            throw ex;
        }
    }
    // Processes an access code based on the account, code and user
    // Returns an ACRMVP that uses the Status Field that is "Success" if it is processed, "Duplicate" if they already have the access, or "Invalid" if an error occurs
    // The ACRMVP will also have relevant data to call grantContactsACRToAccount after this function
    public static ACRMVP ProcessAccessCode(Id accountId, String accessCode, Id userId) {
        // Create placeholder variables
        ACRMVP objReturn = new ACRMVP();
        string strSuccessCommunityRole;

        try {
            // Get the access code
            list<Access_Code__c> accessCodes =
            [
                    SELECT
                            Id,
                            Access_Code__c,
                            Uses_Remaining__c,
                            Type__c
                    FROM
                            Access_Code__c
                    WHERE
                    District_Account__c =: AccountId
                    AND Access_Code__c =: AccessCode
            ];

            if (accessCodes.size() != 1 || accessCodes[0].Uses_Remaining__c < 1) {
                objReturn.Status = 'Invalid';
                return objReturn;
            }

            // Get the current user
            User userRecord = [SELECT ContactId, Contact.Email FROM User WHERE Id = :userId];

            // Create Access Record
            Id devRecordTypeId = Schema.SObjectType.Access__c.getRecordTypeInfosByName().get('Active').getRecordTypeId();

            Access__c thisAccess = ACT_AccessUtility.createAccess(accessCodes[0].Id, userRecord.ContactId, AccountId, 'Approved', 'Access code', null);

            thisAccess.recordTypeId = devRecordTypeId;

            // Check if this user already has this access
            string strACRQuery = 'SELECT Id FROM AccountContactRelation WHERE IsActive = true And Status__c = \'Active\' And AccountId = \'' + AccountId + '\' And ContactId = \'' + userRecord.ContactId + '\' ';

            switch on accessCodes[0].Type__c {
                when 'Ed-Fi Admin' {
                    strACRQuery += 'And Ed_Fi_Role__c = \'EDFI_TENANT_ADMIN\' ';
                    thisAccess.Ed_Fi_Role__c = 'EDFI_TENANT_ADMIN';
                }

                when 'Ed-Fi User' {
                    strACRQuery += 'And Ed_Fi_Role__c != null ';
                    thisAccess.Ed_Fi_Role__c = 'EDFI_TENANT_USER';
                }

                when 'State Online Reporting' {
                    strACRQuery += 'And Success_Community_Role__c != null';
                    // Create on-line reporting to the state
                    strSuccessCommunityRole = 'State User';
                    thisAccess.eMetrics_Role__c = 'Normal-Full';
                }

                when 'Trusted Agent' {
                    strACRQuery += 'And Success_Community_Role__c = \'Trusted Agent\'';
                    strSuccessCommunityRole = 'Trusted Agent';
                    thisAccess.eMetrics_Role__c = 'Admin-Full';
                    thisAccess.TAA_Role__c = 'ACCTAC';
                }
                when 'State Trusted Agent' {
                    strACRQuery += 'And Success_Community_Role__c = \'State Trusted Agent\'';
                    strSuccessCommunityRole = 'State Trusted Agent';
                    thisAccess.eMetrics_Role__c = 'Admin-Full';
                }
            }

            list<AccountContactRelation> lstDupCheck = new list<AccountContactRelation>();

            if (userRecord.contactid != null) {
                lstDupCheck = Database.query(strACRQuery);
            }

            if (lstDupCheck != null && lstDupCheck.size() > 0) {
                objReturn.Status = 'Duplicate';
                return objReturn;
            }

            // Decrement the uses remaining
            accessCodes[0].Uses_Remaining__c = accessCodes[0].Uses_Remaining__c - 1;
            update accessCodes[0];

            // Insert the access return
            insert thisAccess;

            // Create the access code use record
            Access_Code_Use__c accessCodeUse = ACT_AccessUtility.createAccessCodeUse(userRecord.contactid, accessCodes[0].id);

            insert accessCodeUse;

            // Create Hierarchy Approval records for trusted agents, if there aren't any already
            if (String.isNotEmpty(accessCodes[0].Type__c) && accessCodes[0].Type__c == 'Trusted Agent') {
                boolean updateAccount = false;

                Account thisAccount =
                [
                        SELECT
                                Current_Year_Hierarchy__c,
                                eMetric_Org_Type__c,
                                One_Year_Previous_Hierarchy__c,
                                Two_Years_Previous_Hierarchy__c
                        FROM
                                Account
                        WHERE
                                id =: accountId
                ];

                if (thisAccount.eMetric_Org_Type__c != 'B') {
                    Date oneYearDate = date.today().addDays(-365);
                    Date SecondYearDate = date.today().addDays(-730);
                    Date TodayDate = date.today();

                    string firstPrevYearContractId;
                    string secondPrevYearContractId;

                    // Get any existing contract participant records for this account
                    list<Contract_Administration_Participant__c> FirstPreviousYearContractList =
                    [
                            SELECT
                                    Id,
                                    Account_ID__c,
                                    Contract_Administration_ID__c,
                                    Contract_Administration_ID__r.Contract_Code__c,
                                    Contract_Administration_ID__r.Contract_ID__c,
                                    Contract_Administration_ID__r.Contract_ID__r.EndDate,
                                    Contract_Administration_ID__r.Contract_ID__r.Program__c,
                                    Contract_Administration_ID__r.Contract_ID__r.StartDate,
                                    Contract_Administration_ID__r.Program__c,
                                    Org_Type__c,
                                    Parent_Account__c
                            FROM
                                    Contract_Administration_Participant__c
                            WHERE
                            Contract_Administration_ID__r.Contract_ID__r.Program__c = 'National'
                            AND eMetric_Org_Type__c  != 'B'
                            AND Account_ID__c =: accountId
                            AND
                            (
                                    (Contract_Administration_ID__r.Contract_ID__r.startDate <= last_n_days:365 AND Contract_Administration_ID__r.Contract_ID__r.endDate >= last_n_days:365)
                                    OR
                                    (Contract_Administration_ID__r.Contract_ID__r.startDate <= last_n_days:730 AND Contract_Administration_ID__r.Contract_ID__r.endDate >= last_n_days:730)
                            )
                    ];

                    // Loop through, looking for valid contracts for the previous years
                    for (Contract_Administration_Participant__c contractRecord :FirstPreviousYearContractList) {
                        if (contractRecord.Contract_Administration_ID__r.Contract_ID__r.startDate <= oneYearDate &&  oneYearDate <= contractRecord.Contract_Administration_ID__r.Contract_ID__r.EndDate) {
                            firstPrevYearContractId = contractRecord.Contract_Administration_ID__r.Contract_ID__c ;
                        }

                        if (contractRecord.Contract_Administration_ID__r.Contract_ID__r.startDate <= SecondYearDate &&  SecondYearDate <= contractRecord.Contract_Administration_ID__r.Contract_ID__r.EndDate) {
                            secondPrevYearContractId = contractRecord.Contract_Administration_ID__r.Contract_ID__c ;
                        }
                    }

                    system.debug('firstPrevYearContractId-------'+firstPrevYearContractId);
                    system.debug('secondPrevYearContractId-------'+secondPrevYearContractId);

                    // Look for existing HA records for this account
                    list<Hierarchy_Approval__c> hierarchyApprovalsList =
                    [
                            SELECT
                                    Id,
                                    District_Account__c,
                                    status__c,
                                    Contract__c
                            FROM
                                    Hierarchy_Approval__c
                            WHERE
                                    District_Account__c =: accountId
                    ];

                    // Map the HA records to the contracts
                    map<string,Hierarchy_Approval__c> hierarchyApprovalsMap = new map<string,Hierarchy_Approval__c>();

                    if (hierarchyApprovalsList.size() > 0)
                    {
                        for (Hierarchy_Approval__c approvalRecord: hierarchyApprovalsList)
                        {
                            hierarchyApprovalsMap.put(approvalRecord.Contract__c,approvalRecord);
                        }
                    }

                    system.debug('hierarchyApprovalsMap-----'+hierarchyApprovalsMap);

                    // If there are no HA records for this account, create one for the current year
                    if (hierarchyApprovalsList.size() == 0) {
                        Hierarchy_Approval__c Hierarchyapproval = new Hierarchy_Approval__c();

                        Hierarchyapproval.District_Account__c = accountId;
                        Hierarchyapproval.status__c = 'Approval Required';

                        // Get the contract for the current year
                        list<contract> contractList =
                        [
                                SELECT
                                        Id
                                FROM
                                        Contract
                                WHERE
                                startdate <=:todayDate
                                AND enddate >=:todaydate
                                AND Program__c = 'National'
                        ];

                        // If an appropriate one is there, attach it to the HA record
                        if(contractList.size() > 0) {
                            Hierarchyapproval.Contract__c = contractList[0].id;
                        }

                        insert Hierarchyapproval;

                        thisAccount.Current_Year_Hierarchy__c = Hierarchyapproval.id;
                        updateAccount = true;
                    }

                    // Create an HA for the previous year, if applicable
                    if (firstPrevYearContractId !=null  && !hierarchyApprovalsMap.containsKey(firstPrevYearContractId)) {
                        Hierarchy_Approval__c FirstYearHierarchyapproval = new Hierarchy_Approval__c();

                        FirstYearHierarchyapproval.District_Account__c = accountId;
                        FirstYearHierarchyapproval.status__c = 'Approval Required';
                        FirstYearHierarchyapproval.Contract__c = firstPrevYearContractId;

                        insert FirstYearHierarchyapproval;

                        thisAccount.One_Year_Previous_Hierarchy__c = FirstYearHierarchyapproval.id;
                        updateAccount = true;
                    }

                    // Create an HA for two years ago, if applicable
                    if (secondPrevYearContractId !=null && ! hierarchyApprovalsMap.containsKey(secondPrevYearContractId))
                    {
                        Hierarchy_Approval__c SecondYearHierarchyapproval = new Hierarchy_Approval__c();

                        SecondYearHierarchyapproval.District_Account__c = accountId;
                        SecondYearHierarchyapproval.status__c = 'Approval Required';
                        SecondYearHierarchyapproval.Contract__c = secondPrevYearContractId;

                        insert SecondYearHierarchyapproval;

                        thisAccount.Two_Years_Previous_Hierarchy__c = SecondYearHierarchyapproval.id;
                        updateAccount = true;
                    }

                    system.debug('updateAccount---------'+updateAccount);

                    if(updateAccount) {
                        update thisAccount;
                    }
                }
            }

            // Call AccountContactRelation shared functionality, if applicable, or just return the info needed to call it later
            objReturn.AuditChangeTypeId = thisAccess.Id;
            objReturn.EdFiRole = thisAccess.Ed_Fi_Role__c;
            objReturn.eMetricsRole = thisAccess.eMetrics_Role__c;
            objReturn.Status = 'Success';
            objReturn.SuccessCommunityRole = strSuccessCommunityRole;
            objReturn.TAARole = thisAccess.TAA_Role__c;
        }
        catch (Exception ex) {
            system.debug('Exception occurred in ProcessAccessCode >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'ProcessAccessCode', ex.getMessage(), '', '', '');

            objReturn.Status = 'Invalid';
        }

        return objReturn;
    }

    // Sets ACR records for various roles, and active/inactive state
    // Active = true will be active.  Active = false will be inactive.  Active = null will be ignored.
    // String values that are populated will be written.  Nulls will be ignored.  'MakeNull' will make them null.
    // ACRs that don't exist for the AccountId/ContactId combination will be created
    // Permission sets will be handled via a trigger on ACRs
    public static void setACRAccess(list<ACRMVP> AccessList) {
        try {
            // Initialize the sets
            set<id> setAccounts = new set<id>();
            set<id> setContacts = new set<id>();

            // Populate the sets
            for (ACRMVP thisMVP : AccessList) {
                setAccounts.add(thisMVP.AccountId);
                setContacts.add(thisMVP.ContactId);
            }

            // Map a map of ACRMVP items based on account and then contact to use for auditing later
            map<id, map<id, ACRMVP>> mapACRMVP = new map<id, map<id, ACRMVP>>();

            for (ACRMVP thisACRMVP : AccessList) {
                map<id, ACRMVP> mapTemp = mapACRMVP.get(thisACRMVP.AccountId);

                if (mapTemp == null) {
                    mapTemp = new map<id, ACRMVP>();
                }

                mapTemp.put(thisACRMVP.ContactId, thisACRMVP);

                mapACRMVP.put(thisACRMVP.AccountId, mapTemp);
            }

            // Get existing ACRs, note that this SOQL may return unnecessary values, can eventually be turned into a bunch
            // OR/AND statements, or moved to a batch operation
            list<AccountContactRelation> lstACR = [
                    SELECT
                            Active__c,
                            AccountId,
                            ContactId,
                            Contract__c,
                            Ed_Fi_Role__c,
                            eMetrics_Role__c,
                            IsActive,
                            Status__c,
                            Success_Community_Role__c,
                            TAA_Role__c,
                            PANext_Role__c
                    FROM
                            AccountContactRelation
                    WHERE
                    AccountId in :setAccounts
                    And ContactId in :setContacts
            ];

            // Make a clone/map of the ACR list for later audit support
            List<AccountContactRelation> lstOldACRs = lstACR.deepClone(true, false, false);
            map<Id, AccountContactRelation> mapOldACRs = new map<Id, AccountContactRelation>(lstOldACRs);

            // Map the ACRs, accounts to a map of contacts to ACRs, to make it easier to find them
            map<id, map<id, AccountContactRelation>> mapAccountsToContactMap = new map<id, map<id, AccountContactRelation>>();

            for (AccountContactRelation thisACR : lstACR) {
                map<id, AccountContactRelation> mapTemp = mapAccountsToContactMap.get(thisACR.AccountId);

                if (mapTemp == null) {
                    mapTemp = new map<id, AccountContactRelation> ();
                }

                mapTemp.put(thisACR.ContactId, thisACR);

                mapAccountsToContactMap.put(thisACR.AccountId, mapTemp);
            }

            // Get the org types for the accounts and map them
            list<Account> lstAccounts =
            [
                    SELECT
                            Id,
                            eMetric_Org_Type__c
                    FROM
                            Account
                    WHERE
                            id in: setAccounts
            ];

            map<Id, String> mapEOT = new map<Id, String>();

            for (Account thisA : lstAccounts) {
                mapEOT.put(thisA.Id, thisA.eMetric_Org_Type__c);
            }

            // Loop through and set the values, adding missing ACRs as necessary
            // Flag roles that would grant permission sets along the way
            for (ACRMVP thisMVP : AccessList) {
                AccountContactRelation thisACR;

                map<id, AccountContactRelation> mapTemp = mapAccountsToContactMap.get(thisMVP.AccountId);

                if (mapTemp != null) {
                    thisACR = mapTemp.get(thisMVP.ContactId);

                    // If the old ACR was found for this contact, and it was inactive, turn off upgrading
                    if (thisACR != null && !thisACR.IsActive) {
                        thisMVP.UpgradeRolesOnly = false;
                    }
                }

                if (thisACR == null) {
                    thisACR = new AccountContactRelation();

                    thisACR.AccountId = thisMVP.AccountId;
                    thisACR.ContactId = thisMVP.ContactId;

                    lstACR.add(thisACR);
                }

                // If the old ACR was inactive, turn off UpgradeRolesOnly
                if (thisACR.IsActive != null && !thisACR.IsActive) {
                    thisMVP.UpgradeRolesOnly = false;
                }

                if (thisMVP.Active != null) {
                    thisACR.IsActive = thisMVP.Active;
                }

                thisACR.Contract__c = setString(thisACR.Contract__c, thisMVP.Contract);
                thisACR.Ed_Fi_Role__c = setString(thisACR.Ed_Fi_Role__c, thisMVP.EdFiRole, thisMVP.UpgradeRolesOnly, 'EdFi');
                thisACR.eMetrics_Role__c = setString(thisACR.eMetrics_Role__c, thisMVP.eMetricsRole, thisMVP.UpgradeRolesOnly, 'eMetrics');
                thisACR.Status__c = setString(thisACR.Status__c, thisMVP.Status);
                thisACR.TAA_Role__c = setString(thisACR.TAA_Role__c, getTAARole(thisMVP.TAARole), thisMVP.UpgradeRolesOnly, 'TAA');
                thisACR.PANext_Role__c = setPANextRole(thisACR.PANext_Role__c, thisMVP.PANextRole);

                // If the account is a state (eMetrics Org Type = S), always use State User, otherwise set it with setString
                if (mapEOT.get(thisMVP.AccountId) != null && mapEOT.get(thisMVP.AccountId) == 'S') {
                    if(thisMVP.SuccessCommunityRole=='State Trusted Agent'){
                        thisACR.Success_Community_Role__c = 'State Trusted Agent';
                    }
                    else{
                        thisACR.Success_Community_Role__c = 'State User';
                    }
                }
                else {
                    thisACR.Success_Community_Role__c = setString(thisACR.Success_Community_Role__c, thisMVP.SuccessCommunityRole, thisMVP.UpgradeRolesOnly, 'SuccessCommunity');
                }

                // Add the ACR back to the mapAccountsToContactMap, in case multiple ACRs for the same account/contact come in
                if (mapTemp == null) {
                    mapTemp = new map<id, AccountContactRelation>();
                }

                mapTemp.put(thisACR.ContactId, thisACR);
                mapAccountsToContactMap.put(thisACR.AccountId, mapTemp);
            }

            // Upsert the values
            upsert lstACR;

            // Delete any existing self registration accounts
            ACT_AccessUtility.DeleteSelfRegistrationAccounts(setContacts);

            // Now look for audit records to create
            // Create holders for the audit records
            list<Audit_Change__c> lstNewAC = new list<Audit_Change__c>();
            list<Audit_Change_Detail__c> lstNewACD = new list<Audit_Change_Detail__c>();
            map<Id, list<Audit_Change_Detail__c>> mapACR2ACD = new map<Id, list<Audit_Change_Detail__c>>();

            // Loop through the now created ACRs
            for (AccountContactRelation thisACR : lstACR) {
                // Find the associated ACRMVP
                map<Id, ACRMVP> mapTemp = mapACRMVP.get(thisACR.AccountId);
                ACRMVP thisACRMVP = mapTemp.get(thisACR.ContactId);

                // Find the original ACR (if it exists)
                AccountContactRelation oldACR = mapOldACRs.get(thisACR.Id);

                if (oldACR == null) {
                    oldACR = new AccountContactRelation();
                }

                // Look for changes
                FindChange(mapACR2ACD, thisACR, oldACR, 'IsActive', 'Active');
                FindChange(mapACR2ACD, thisACR, oldACR, 'Ed_Fi_Role__c', 'Ed-Fi Role');
                FindChange(mapACR2ACD, thisACR, oldACR, 'eMetrics_Role__c', 'eMetrics Role');
                FindChange(mapACR2ACD, thisACR, oldACR, 'Success_Community_Role__c', 'Success Community Role');
                FindChange(mapACR2ACD, thisACR, oldACR, 'TAA_Role__c', 'TAA Role');
                FindChange(mapACR2ACD, thisACR, oldACR, 'PANext_Role__c', 'PANext Role');

                // If there was a change create the audit change record for this ACR
                if (mapACR2ACD.get(thisACR.Id) != null) {
                    Audit_Change__c newAC = new Audit_Change__c();

                    newAC.Account__c = thisACR.AccountId;
                    newAC.AccountContact_Relation__c = thisACR.Id;
                    newAC.Change_Date__c = Date.today();
                    newAC.Change_Type__c = thisACRMVP.AuditChangeType;
                    newAC.Change_Type_Id__c = thisACRMVP.AuditChangeTypeId;
                    newAC.Changed_By_User__c = thisACRMVP.AuditContactId;
                    newAC.Contact__c = thisACR.ContactId;
                    newAC.Reason__c = thisACRMVP.AuditReason;

                    lstNewAC.add(newAC);
                }
            }

            // If there were audit changes, insert those
            if (lstNewAC.size() > 0){
                insert lstNewAC;

                // Now go through the audit change detail map, and create those records
                for (Audit_Change__c thisAC : lstNewAC) {
                    // Get the detail records for this audit change, based on the associated ACR Id
                    list<Audit_Change_Detail__c> lstTemp = mapACR2ACD.get(thisAC.AccountContact_Relation__c);

                    for (Audit_Change_Detail__c thisACD : lstTemp) {
                        thisACD.Audit_Change__c = thisAC.Id;

                        lstNewACD.add(thisACD);
                    }
                }

                // Insert the audit change detail records
                insert lstNewACD;
            }
        }
        catch (Exception ex) {
            system.debug('Exception occurred in setACRAccess >>>>> ' + ex.getMessage() + ' Stack Dump: ' + ex.getStackTraceString());
            CC_SC_ERR_EventLogger.LogSingleError(ex, null, 'Error', '', 'setACRAccess', ex.getMessage(), '', '', '');
            throw ex;
        }
    }

    ////////////////////////////
    // Lookup Maps
    ////////////////////////////
    public static string getEdFiRole(string accessLevel, boolean APIName) {
        return accessLevel == 'true' ? APIName == true ? 'EDFI_TENANT_ADMIN' : 'EdFi Tenant Admin' : null;
    }


    public static string geteMetricsRole(string accessLevel) {
        switch on accessLevel {
            when 'State Trusted Agent' {
                return 'Admin-Full';
            }
            when 'Trusted Agent' {
                return 'Admin-Full';
            }

            when 'Detail Viewer' {
                return 'Normal-Full';
            }

            when 'Summary Viewer' {
                return 'Normal-Limited';
            }
        }

        return null;
    }

    public static string getRequestedRole(string eMetricsOrSuccessCommunityRole) {
        switch on eMetricsOrSuccessCommunityRole {
            when 'State Trusted Agent' {
                return 'State Trusted Agent';
            }
            when 'Admin-Full', 'Trusted Agent' {
                return 'Trusted Agent';
            }

            when 'Normal-Limited', 'Summary Viewer' {
                return 'Online Reporting: Summary Viewer';
            }

            when 'Normal-Full', 'Detail Viewer' {
                return 'Online Reporting: Detail Viewer';
            }
        }

        return '';
    }

    public static string getSuccessCommunityRole(Account targetAccount, string accessLevel) {
        if (targetAccount.eMetric_Org_Type__c == 'S') {
            if(accessLevel == 'State Trusted Agent'){
                return 'State Trusted Agent';
            }
            else{
                return 'State User';
            }
        }

        switch on accessLevel {
            when 'Trusted Agent' {
                return 'Trusted Agent';
            }

            when 'Detail Viewer', 'Summary Viewer' {
                return 'Standard';
            }
        }

        return null;
    }

    public static string getTAARole(string accessLevel) {
        return (accessLevel == 'true' || accessLevel == 'ACCTAC' || accessLevel == 'TAA Coordinator') ? 'ACCTAC' : null;
    }

    public static string getTAAFriendlyName(string accessLevel) {
        if (accessLevel == 'ACCTAC') {
            return 'TAA Coordinator';
        }

        return '';
    }

    ////////////////////////////
    // Private functions
    ////////////////////////////
    private static List<ACRMVP> assignParentACRsToChildren(map<id, list<AccountContactRelation>> mapACRs, Id AccountId, Id ParentId, Id UserContactId, String AuditReason, Boolean UpgradeRoles) {
        List<ACRMVP> lstReturn = new List<ACRMVP>();

        if (mapACRs != null && mapACRs.get(ParentId) != null) {
            // Get the parent ACRs
            list<AccountContactRelation> lstParentACR = mapACRs.get(ParentId);

            // Make the new ACRs, which will have the same features as the parents (including active/inactive)
            for (AccountContactRelation thisACR : lstParentACR) {
                ACRMVP thisACRMVP = new ACRMVP();

                thisACRMVP.Active = thisACR.IsActive;
                thisACRMVP.AccountId = AccountId;
                thisACRMVP.AuditChangeType = 'Trigger';
                thisACRMVP.AuditChangeTypeId = null;
                thisACRMVP.AuditContactId = UserContactId;
                thisACRMVP.AuditReason = AuditReason;
                thisACRMVP.ContactId = thisACR.ContactId;
                thisACRMVP.EdFiRole = thisACR.Ed_Fi_Role__c;
                thisACRMVP.eMetricsRole = thisACR.eMetrics_Role__c;
                thisACRMVP.Status = thisACR.Status__c;
                thisACRMVP.SuccessCommunityRole = thisACR.Success_Community_Role__c;
                thisACRMVP.TAARole = thisACR.TAA_Role__c;
                thisACRMVP.UpgradeRolesOnly = UpgradeRoles;

                lstReturn.add(thisACRMVP);
            }
        }

        return lstReturn;
    }

    private static string setString(string OldValue, string NewValue) {
        return setString(OldValue, NewValue, false, '');
    }

    // UpgradeOnly will not overwrite higher roles with lower roles
    private static string setString(string OldValue, string NewValue, boolean UpgradeOnly, string RoleType) {
        // First check for upgrades
        if (UpgradeOnly == true) {
            switch on RoleType {
                when 'EdFi' {
                    if (OldValue == 'EDFI_TENANT_ADMIN') {
                        return 'EDFI_TENANT_ADMIN';
                    }

                    if (OldValue == 'EDFI_TENANT_USER' && NewValue != 'EDFI_TENANT_ADMIN') {
                        return 'EDFI_TENANT_USER';
                    }
                }

                when 'eMetrics' {
                    map<string, integer> mapValues = new map<string, integer>();

                    mapValues.put('Admin-Full', 5);
                    mapValues.put('Admin-Limited', 4);
                    mapValues.put('Normal-Full', 3);
                    mapValues.put('Normal-Limited', 2);
                    mapValues.put('Summary', 1);

                    if (NewValue == null || NewValue == 'MakeNull' || mapValues.get(OldValue) > mapValues.get(NewValue)) {
                        return OldValue;
                    }
                }

                when 'SuccessCommunity' {
                    if (OldValue == 'Trusted Agent') {
                        return 'Trusted Agent';
                    }

                    if (OldValue == 'Standard' && NewValue == 'MakeNull') {
                        return 'Standard';
                    }
                }

                when 'TAA' {
                    if (RoleType == 'TAA' && OldValue == 'ACCTAC') {
                        return 'ACCTAC';
                    }
                }
            }
        }

        // Next check if it should be made null
        if (NewValue == 'MakeNull') {
            return null;
        }

        // If the new value is null, return the old value, otherwise return the new value
        if (NewValue == null) {
            return OldValue;
        }
        else {
            return NewValue;
        }
    }

    ////////////////////////////
    // Private Functions
    ////////////////////////////
    private static void findChange(map<Id, list<Audit_Change_Detail__c>> ChangeDetailMap, AccountContactRelation NewACR, AccountContactRelation OldACR, String FieldAPIName, String FieldFriendlyName) {
        String NewValue = string.valueOf(NewACR.get(FieldAPIName));
        String OldValue = string.valueOf(OldACR.get(FieldAPIName));

        // Check if they are not the same, and at least one of them has a value
        if (OldValue != NewValue && (!String.isEmpty(OldValue) || !String.isEmpty(NewValue))) {
            Audit_Change_Detail__c newACD = new Audit_Change_Detail__c();

            newACD.Field_Name__c = FieldFriendlyName;
            newACD.New_Value__c = NewValue;
            newACD.Old_Value__c = OldValue;

            list<Audit_Change_Detail__c> lstTemp = ChangeDetailMap.get(NewACR.Id);

            if (lstTemp == null) {
                lstTemp = new list<Audit_Change_Detail__c>();
            }

            lstTemp.add(newACD);

            ChangeDetailMap.put(NewACR.id, lstTemp);
        }
    }

    public static string setPANextRole(string oldValue,string newValue) {
        system.debug('in setPANextRole');
        //setting PANext
        if(newValue == 'removeTestCoordinator') {
            List<string> PANextList = oldValue.split(';');
            List<string> extPANextValues = new List<string>();
            string PANextReturn;
            if(!PANextList.isEmpty()) {
                for (string panext : PANextList) {
                    if (panext != 'Test Coordinator') {
                        extPANextValues.add(panext);
                    }
                }
            }
            if (!extPANextValues.isEmpty()) {
                for (string temp : extPANextValues) {
                    if (PANextReturn == null) {
                        PANextReturn = temp;
                    } else {
                        PANextReturn += ';' + temp;
                    }
                }
            }
            Return PANextReturn;
        }
        // If the new value is null, return the old value, otherwise return the new value
        if (newValue == null) {
            return oldValue;
        }
        else if(oldValue == null) {
            return newValue;
        }
        else if(oldValue!=null && newValue!=null){
            List<string> extOldValues = oldValue.split(';');
            if(extOldValues.contains(newValue)){
                return oldValue;
            }
            else{
                return oldValue+';'+newValue;
            }

        }
        else {
            return newValue;
        }

    }

    ////////////////////////////
    // Subclasses
    ////////////////////////////
    public class ACRMVP {
        public Id AccountId {get; set;} // Account the ACR is for
        public Boolean Active {get; set;} // Should the ACRs be active?
        public String AuditChangeType {get; set;}  // MDM, Access
        public String AuditChangeTypeId {get; set;}  //  ID of the existing MDM or Access record
        public Id AuditContactId {get; set;} // Contact that is creating/modifying the ACR
        public String AuditReason {get; set;} // Reason for the changes (Invitation, etc.)
        public Id ContactId {get; set;} // Contact the ACR is for
        public String Contract {get; set;} // Not typically used, but here if needed
        public String EdFiRole {get; set;} // What role the contacts have with EdFi
        public String eMetricsRole {get; set;} // What role the contact have with eMetrics
        public String PANextRole {get;set;} // What role the contact have with PANextRole
        public String Status {get; set;} // The status of the ACR (Usually Active/Inactive, not always used)
        public String SuccessCommunityRole {get; set;} // What role the contact have in the community
        public String TAARole {get; set;} // What role the contact have with Test Accommodations
        public Boolean UpgradeRolesOnly {get; set;}  // If this is set, it will not override a higher role with a lower one
    }
}
