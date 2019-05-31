// BatchMergeCls.cls

public with sharing class MergeBatchCls {

    public static final String MERGETYPE_BANQUETCHECK = 'Banquet Check';
    public static final String MERGETYPE_BEO = 'BEO';
    
    private Boolean ForceBeoAndBanquetCheckToPdf {get; set;}
    public Boolean ShowDocOutputOption {get; set;}
    
    public string BatchMergeObjectURL {get;set;}
    public string BatchMergeObjectURLPrefix {get;set;}
    public string BatchMergeObjectId {get;set;}
    public string BatchMergeObjectName {get;set;}

    public String DocType{get;set;}  // PDF or Doc
    public boolean isGenerateButtonDisabled { get; set; } { isGenerateButtonDisabled = true; }    
    public boolean generationerror{get;set;}
    public BeoSearchCriteria criteria { get; private set; }
    public Boolean fromObject {get; set;}
    public string selectedBookingDocumentIds {get; set;}

    public List<SelectOption> Languages { get; private set; }
    public String SelectedLanguage { get; set; }
    public String SelectedSecondaryLanguage { get; set; }
    public Boolean IsLanguagesVisible {
        get {
            return Languages != null && Languages.size() > 0;
        }
    }
    
    public List<SelectOption> Locales { get; private set; }
    public String SelectedLocale { get; set; }
    public Boolean IsLocalesVisible {
        get {
            return Locales != null && Locales.size() > 0;
        }
    }

    // Used when merging from a Booking, Account, etc. object and not from the Merges Tab
    private String objectId;
    private string objectNameWithoutNamespace;
    private string objectNameWithNamespace;
    private string objectTypeCallingMerge {get;set;}
    private Boolean isBooking{get;set;}

    public Set<Id> deSelectedIds{get;set;}
    private BeoItem[] beoItems { private get; private set; }
    public String selectedMergeType {get; set;}
    public String selectedTemplateId {get; set;}
    public boolean isDistributed{get;set;}
    public boolean isBCBatchPrinted{get;set;}
    public boolean isDone{get;set;}
    private Boolean templatesFilled = false;
    private Map<Id,String> templateMap = new Map<Id,String>();
    public string UserLocale {get; set;}

    // Validation and notifications
    public String errorMessage { get; private set; }
    public boolean notificationsPending { get; set; }
    public string notificationMessage {get; set;}
    private Validator validator;
    private boolean errorsPending { get; set; }

    // Pagination
    public Boolean displayNavButtons { get; set; } { displayNavButtons = false; }
    private Integer noOfRecords{get; set;}
    private integer PageSize = 20;  // Number of records in a page
    private Integer TotalPageNumber;  // Total pages
    private String fullQuery;
    private Boolean resetSetCon {get; set;}

    // For displaying default property when merging from booking layout
    private string selectedProperty {get;set;}

    //OAUTH
    public Static Final String Endpoint = Ni.getSalesforceURL()+'/services/oauth2/token';
    public Static Final String MergeRedirectUri = Ni.getSalesforceURL()+'/apex/nihrm__BatchMerge';
    private String OAuthAccessToken;
    private String OAuthRefreshToken;

    public static String getOauthClientId(){
        if (!Ni.isRunningInSandbox()){
            return NiProtected__c.getValues('Default') != null ? NiProtected__c.getValues('Default').MergeOauthClientId__c : '';
        }
        else{
            return NiProtected__c.getValues('Default') != null ? NiProtected__c.getValues('Default').MergeOauthClientIdSandbox__c : '';
        }
    }

    public static String getOauthClientSecret(){
        if (!Ni.isRunningInSandbox()){
            return NiProtected__c.getValues('Default') != null ? NiProtected__c.getValues('Default').MergeOauthClientSecret__c : '';
        }
        else{
            return NiProtected__c.getValues('Default') != null ? NiProtected__c.getValues('Default').MergeOauthClientSecretSandbox__c : '';
        }
    }

    // Authentication
    public PageReference initDoc() {
        if (ApexPages.currentPage().getParameters().get('code') == null)
        {
            objectId = ApexPages.currentPage().getParameters().get('id');
        }
        else
        {
            objectId = ApexPages.currentPage().getParameters().get('state');
        }

        if (objectId != null) {
            fromObject = true;
            Schema.SObjectType token = ID.valueOf(objectId).getSObjectType();
            objectNameWithNamespace = token.getDescribe().getName();
            objectNameWithoutNamespace = token.getDescribe().getLocalName();
            //system.debug(loggingLevel.info, 'In merge Init with recordid = ' + objectId + ' and RecordType = '  + objectNameWithoutNamespace + ' and sectionHeaderTitle = ' + sectionHeaderTitle );
            objectTypeCallingMerge = token.getDescribe().getLocalName();
        }

        PageReference pageRef;
        string authCode = ApexPages.currentPage().getParameters().get('code');
        if (authCode == null)
        {
            String authuri;
            if (objectId != null) {
            	Id idO = Id.valueOf(objectId);
                authuri = '/services/oauth2/authorize?'+
                    'response_type=code&client_id='+getOauthClientId()+'&redirect_uri='+MergeRedirectUri+'&state='+EncodingUtil.urlEncode(String.ValueOf(idO),'UTF-8');
            }
            else {
                authuri = '/services/oauth2/authorize?'+
                    'response_type=code&client_id='+getOauthClientId()+'&redirect_uri='+MergeRedirectUri;
            }
            pageRef = new PageReference(authuri);
        }

        return pageRef;
    }

    // Set the flag in the page that determines wheter to shoe "DOC" or not in the docPdf dropdown
    public void CheckForTemplateType() {

        if (selectedMergeType == MERGETYPE_BANQUETCHECK || selectedMergeType == MERGETYPE_BEO) {

            system.debug(logginglevel.info, 'In CheckForTemplateType, ForceBeoAndBanquetCheckToPdf = ' + ForceBeoAndBanquetCheckToPdf);

            if (ForceBeoAndBanquetCheckToPdf == true)
                ShowDocOutputOption = false;
            else
                ShowDocOutputOption = true;
        }
        else
            ShowDocOutputOption = true;
            
      criteria.apply();
    }

    //=========== Constructors =========================
    public MergeBatchCls() {
        this(new DefaultValidator());

        system.debug(logginglevel.info, 'initializing Criteria in Ctor');
        criteria.init();

        // using the "state" parameter to hold the bookingId because the authCode overwrites where the id= would go (that normally holds the bookingId)
        String state = ApexPages.currentPage().getParameters().get('state');
        if (state != null)
            ApexPages.currentPage().getParameters().put('id', state);

        if (ApexPages.currentPage().getParameters().get('id') != null) {
            isBooking = false;
            if( Id.ValueOf(ApexPages.currentPage().getParameters().get('id')).getsobjectType()==Booking__c.sobjectType)
                isBooking = true;
        }
    }

    public MergeBatchCls(Validator validator) {
        system.debug(logginglevel.info, 'In mergeBatchCls with Validator');

        // Pagination
        pageNumber = 0;
        totalPageNumber = 0;
        pageSize = 20;
        deSelectedIds = new Set<Id>();
        resetSetCon = true;
        selectedBookingDocumentIds = '[]';

        errorsPending = false;
        notificationsPending = false;

        system.debug(logginglevel.info, 'making new instance of Criteria in Ctor with Validator');
        this.validator = validator;

        criteria = new BeoSearchCriteria();
        criteria.init();

        //Default Distributed Options selection to "All"
        criteria.selectedDistributedOption = Label.Merge_DistributedAll;
        criteria.selectedBCBatchPrintedOption = Label.Merge_DistributedAll;

        // If calling from Merge tab instead of calling from some object (i.e. Booking), set default selected status to 'Definite';
        if (objectId == null) {
            criteria.SelectedStatuses = new list<String>();
            criteria.selectedStatuses.add('Definite');


            // If defaultproperty is not null, set the property = defaultProperty; if null, set to first element in the Properties control
            if(criteria.defaultProperty == null)
            {   system.debug('Null Default Property ... ');
                if(getPropertyOptions() == null){
                    String errorMsg1 = Label.BM_error;
                    String[] msg1 = errorMsg1.split(';');
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg1[0]));
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg1[1]));
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg1[2]));
                 }
                 else
                 {
                     criteria.property = getPropertyOptions()[0].getValue();
                 }
            }
            else
            {
                 criteria.property = criteria.defaultProperty;
            }
        }
        else  // Merging from current booking
        {

        system.debug(logginglevel.info, 'setting criteria.property= ' + criteria.property);

            if (String.isNotBlank(selectedProperty))
               criteria.property = selectedProperty;
            //else
               //criteria.property = criteria.defaultProperty;
        }


        // Default to 2nd in list (BEO)
        selectedMergeType = getMergeTypeOptions()[1].getValue();

        // Fix for defect 79802
        if(getTemplateOptions().size() > 0){
            selectedTemplateId = getTemplateOptions()[0].getValue();
        }else{
            apexpages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, Label.NoActiveDocumnetTemplate));
        }



        DocType = 'PDF';

        // Get the ForceBeoAndBanquetCheckToPdf__c from this ORG's public settings
        NiPublic__c nip =  NiPublic__c.getOrgDefaults();
        ForceBeoAndBanquetCheckToPdf = nip.ForceBeoAndBanquetCheckToPdf__c;
        ShowDocOutputOption = true;
        CheckForTemplateType();

        Languages = new List<SelectOption>();
        Map<String, String> accessibleTranslations =
            sortMapByValueAscending(
                AlternateLanguageUtils.getAccessibleTranslationsForUser(
                    UserInfo.getUserId()));
        for (String code : accessibleTranslations.keySet()) {
            SelectOption option = new SelectOption(code, accessibleTranslations.get(code));
            Languages.add(option);
        }
        
        // Piggyback off the language codes that are based on user language permissionsets above
        Locales = new List<SelectOption>();
        String localeCode = '';
        for (String code : accessibleTranslations.keySet()) {
            system.debug(logginglevel.info, 'code before=' + code);
            localeCode = code;
            // Some of the language codes are only 2 characters whereas locale codes are 5 characters; 
            // correct for locale dropdown codes if needed:  i.e. language code 'fr' vs locale code 'fr_FR'
            if (code.length() == 2)
                localeCode = code + '_' + code.toUppercase();       
            
            SelectOption option = new SelectOption(localeCode, accessibleTranslations.get(code));
            Locales.add(option);
            system.debug(logginglevel.info, 'code after=' + localeCode);
        }

        if ((UserInfo.getLocale()).length() > 2)
            UserLocale = (UserInfo.getLocale()).substring(0,5);
        else
            UserLocale = (UserInfo.getLocale());
        system.debug(logginglevel.info, 'UserLocale= ' + UserLocale);
    }


    // Instantiate ApexPages.StandardSetController - used for pagination and querying data in batches
    public ApexPages.StandardSetController setCon {
        get {
            if(setCon == null && fullQuery != null) {
                //system.debug(logginglevel.info,'in SetCon, fullquery = ' + fullquery);
                setCon = new ApexPages.StandardSetController(Database.getQueryLocator(fullQuery));
                setCon.setPageSize(PageSize);
                noOfRecords = setCon.getResultSize();

                //system.debug(logginglevel.info,'setCon.Getrecords() size = ' + setCon.GetRecords().size());
                //system.debug(logginglevel.info,'resultSize = ' + noOfRecords);

            }
            return setCon;
        }
        set;
    }

    public List<BeoItem> getBeoItems(){
        return beoItems;
    }

    private static Map<String, String> sortMapByValueAscending(Map<String, String> toSort) {
        Map<String, String> invertedMap = new Map<String, String>();
        for (String key : toSort.keySet())
            invertedMap.put(toSort.get(key), key);
        List<String> sortedValues = new List<String>(invertedMap.keySet());
        sortedValues.sort();

        Map<String, String> result = new Map<String, String>();
        for (String value : sortedValues)
            result.put(invertedMap.get(value), value);
        return result;
    }


    // called from the page when user selects a property from the property dropdown
    public void refreshTemplatesAndDates() {
       if (criteria.property != null) {

           if(getTemplateOptions().size() > 0){
               selectedTemplateId = getTemplateOptions()[0].getValue();
           }else{
              apexpages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, Label.NoActiveDocumnetTemplate));
           }

           if (objectId == null)
               criteria.initDates();
        }
    }


    //*******************
    // Pagination methods
    //*******************
    public Boolean hasNext {
        get {
            if (setCon != null)
                return setCon.getHasNext();
            else
                return false;
        }
        set;
    }
    public Boolean hasPrevious {
        get {
            if (setCon != null)
                return setCon.getHasPrevious();
            else
                return false;
        }
        set;
    }
    public Integer pageNumber {
        get {
            if (setCon != null)
                return setCon.getPageNumber();
            else
                return 0;
        }
        set;
    }
    public void firstPage() {

        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }
        setCon.first();
        resetSetCon = false;
        getData();
        resetSetCon = true;
    }
    public void lastPage() {

        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }
        setCon.last();
        resetSetCon = false;
        getData();
        resetSetCon = true;
    }
    public void previous() {

        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }
        setCon.previous();
        resetSetCon = false;
        getData();
        resetSetCon = true;
    }
    public void next() {
        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }
        setCon.next();
        resetSetCon = false;
        getData();
        resetSetCon = true;
    }

    public Integer getTotalPageNumber(){
        if (totalPageNumber == 0 && beoItems !=null) {
            totalPageNumber = noOfRecords / PageSize;
            Integer mod = noOfRecords - (TotalPageNumber * PageSize);

            if (mod > 0)
                TotalPageNumber++;
        }
        return TotalPageNumber;
    }

    public void updateIds(BeoItem beoItem){
        if(!beoItem.checked){
            deSelectedIds.add(beoItem.beo.docId);
        }
        else if(deSelectedIds.contains(beoItem.beo.docId)){
            deSelectedIds.remove(beoItem.beo.docId);
        }
    }


    //**************************************
    // Merge Type Criteria Controls and Data
    //**************************************

    //String[] selMergeType = new String[]{};
    //String selMergeType;
    public SelectOption[] getMergeTypeOptions() {
        SelectOption[] options = new List<SelectOption>();
        //options.add(new SelectOption('Booking','Booking'));
        options.add(new SelectOption(MERGETYPE_BANQUETCHECK, MERGETYPE_BANQUETCHECK));
        options.add(new SelectOption(MERGETYPE_BEO, MERGETYPE_BEO));
        //options.add(new SelectOption('Account','Account'));
        //options.add(new SelectOption('Contact','Contact'));
        //options.add(new SelectOption('Inquiry','Inquiry'));
        //options.add(new SelectOption('Volume Contract','Volume Contract'));
        return options;
    }


    // Get all templates for selected merge type
    public SelectOption[] getTemplateOptions() {
        SelectOption[] options = new List<SelectOption>();

        templatesFilled = true;
        for(Template template : getTemplates()) {
            options.add(new SelectOption(template.id, template.name));
            //if(templateId == null) {
            //    templateId = template.id;
            //    templateName = template.Name;
            //}
        }

        return options;
    }


    //***********************************
    // Search Criteria Controls and Data
    //***********************************

    // Load the Property picklist
    public SelectOption[] getPropertyOptions() {

        SelectOption[] options = new List<SelectOption>();

        // Calling from batch merge tab
        if (objectId == null) {

            //options.add(new SelectOption('--All--', '--All--'));
            Location__c[] dbProp = [SELECT Id, Name FROM Location__c where IsActive__c =:true order by Name];
            if(dbProp.size()>0) {
                for(Location__c selprop : dbProp ) {
                    system.debug('selprop:::'+selprop);
                    options.add(new SelectOption(selprop.Id, selprop.Name));
                }
                return options;
             }
             else {
                 return null;
            }
        }
        // Added for retrieving all locations belonging to current booking's bookingEvents wwhen accessing batch merge page from booking layout
        else
        {

            // Searching for cross-property bookingEvents to grab their location: get current booking's bookingEvents associated BookingDocument (BEO or BC) in order to locate the bookingevents' properties
            List<BookingEvent__c> allEventList = [Select location__c from bookingEvent__c WHERE Booking__c = :objectId and (Beo__c != NULL or BanquetCheck__c != NULL) order by property__c];

            // get current booking's property
            List<Booking__c> bookingProperties = [Select location__c from Booking__c where id = :objectId];

            Set<String> eventLocationSet = new Set<String>();
            for (BookingEvent__c event : allEventList) {

                eventLocationSet.Add(event.location__c);

                // default selected property in property dropdown to the booking's property if bookingevents have BEOs or banquet checks
                if (bookingProperties.Size() == 1) {
                    if (event.location__c == bookingProperties[0].location__c) {
                         selectedProperty = event.location__c;  // Current booking's property
                    }
                }
                else {  // default selected property based on cross-property event
                    if(String.isBlank(selectedProperty))
                        selectedProperty = event.location__c;
                }
            }

            // Filter out inactive properties
            List<String> propIdList = new List<String>();
            propIdList.addAll(eventLocationSet);
            Location__c[] dbprop = [SELECT Id, Name FROM Location__c where IsActive__c = true AND id in :propIdList order by Name limit 1000];

            propIdList.Clear();  //reuse variable
            system.debug(logginglevel.info,'dbProp.size()= ' + dbProp.size());
            if(dbProp.size()>0) {
                for(Location__c selprop : dbProp ) {
                    system.debug('selprop:::'+selprop);
                    options.add(new SelectOption(selprop.Id, selprop.Name));

                    propIdList.add(String.valueOf(selProp.Id));
                }

                // Be sure the selectedProperty is still valid -- has not been filtered out as inactive property
                if (String.isNotBlank(selectedProperty)) {
                    Set<String> dbPropSet = new Set<String>();
                    dbPropSet.addAll(propIdList);

                    if (!dbPropSet.contains(selectedProperty))
                        selectedProperty = '';
                }
                return options;
             }
             else {
                 return null;
            }
        }
    }

    // For BEO search criteria only
    public SelectOption[] getDistributedOptions() {
        SelectOption[] options = new List<SelectOption>();

        options.add(new SelectOption('All', Label.Merge_DistributedAll));
        options.add(new SelectOption('Distributed', Label.Merge_Distributed));
        options.add(new SelectOption('Undistributed', Label.Merge_UnDistributed));        
        return options;
    }

    // For Banquet Check search criteria only   
    public SelectOption[] getBCBatchPrintedOptions() {
        SelectOption[] options = new List<SelectOption>();

        options.add(new SelectOption('All', Label.Merge_DistributedAll));
        options.add(new SelectOption('Batch Printed', Label.Merge_BatchPrinted));
        options.add(new SelectOption('Not Batch Printed', Label.Merge_NotBatchPrinted));        
        return options;
    }    

    // Load the EventClassification picklist
    public SelectOption[] getEventClassificationOptions() {
        SelectOption[] options = new List<SelectOption>();

        if (criteria.property != null) {
            for(EventClassification__c dbEventClassification: [select Id, Name from EventClassification__c where Location__c =: criteria.property OR MasterSource__c = 'Corporate'  order by name asc]) {
                options.add(new SelectOption(dbEventClassification.Id, dbEventClassification.Name));
            }
        }
        return options;
    }

    // Get Booking Statuses from Describe Schema
    public SelectOption[] getStatusOptions() {
        SelectOption[] options = new List<SelectOption>();
        for(Schema.PicklistEntry ple : Booking__c.getSObjectType().getDescribe().fields.getMap().get('BookingStatus__c').getDescribe().getPicklistValues()) {
            //System.debug('Value: ' + ple.getValue());
            if (ple.getValue() != 'Lost' && ple.getValue() != 'Cancelled' && ple.getValue() != 'TurnedDown')
                options.add(new SelectOption(ple.getValue(), ple.getLabel()));
        }
        return options;
    }

    // Load the FunctionRoom picklist
    public SelectOption[] getFunctionRoomOptions() {
        SelectOption[] options = new List<SelectOption>();

        if (criteria.property != null) {
            for(FunctionRoom__c dbFunctionRoom: [select Id, Name from FunctionRoom__c where Location__c =: criteria.property order by sortOrder__c limit 1000]) {
                options.add(new SelectOption(dbFunctionRoom.Id, dbFunctionRoom.Name));
            }
        }
        return options;
    }


    public void getData() {

        system.debug(loggingLevel.info, 'In GetData; selectedMergeType = ' + selectedMergeType);
        system.debug(loggingLevel.info,'In GetData, selectedTemplateId = ' + selectedTemplateId);

        // When this.OAuthAccessToken = null, this means we have just clicked the Generate button for the first time.
        if (this.OAuthAccessToken == null)
        {
            system.debug(logginglevel.info, 'OAuthAccessToken is null!!!');
            string authCode = ApexPages.currentPage().getParameters().get('code');

            // In case the page has been sitting idle and user has not yet clicked Generate button and the authCode has expired
            if (authCode == null)  // expired authCode while page is still open
            {
                String authuri;
                if (objectId != null) {
                	Id idO = Id.valueOf(objectId);
                    authuri = '/services/oauth2/authorize?'+
                        'response_type=code&client_id='+getOauthClientId()+'&redirect_uri='+MergeRedirectUri+'&state='+EncodingUtil.urlEncode(String.ValueOf(idO),'UTF-8');
                }
                else {
                    authuri = '/services/oauth2/authorize?'+
                        'response_type=code&client_id='+getOauthClientId()+'&redirect_uri='+MergeRedirectUri;
                }

                PageReference pageRef = new PageReference(authuri);
                authCode = pageRef.getParameters().get('code');
            }

            // Finally, get Access Tokens
            if (authCode != null)
                GetAccessTokens(authCode);
        }  // else we're clicking the generate button the second time+ and we already have the OAuth access and refesh tokens-- no need to get them again while still in the batchmerge page.

        isGenerateButtonDisabled = false;
        errorspending = false;
        notificationsPending = false;

        criteria.apply();
        if(templatesFilled) {
            // validate criteria only if using search criteria page block (i.e. opened page from merges tab and not from booking page)
            if (objectId == null) {
                if(setError(validator.validate(criteria))) {
                    errorsPending = true;
                    return;
                }
            }
        }


        beoItems = new List<BeoItem>();

        /*  create new list<Beo> which will save sorted beo.
            and iterate that list to get proper dispaly of first event date
        */
        List<Beo> beoList = new List<Beo>();

        if (resetSetCon == true)
            SetCon = null;

        beoList = getBeos(criteria);
        //beoList.sort();
        List<Beo> beoListWithChangedDateFormat = new List<Beo>();
        for(Beo beo : beoList)
        {
            String dateInString = beo.firstEventDate.format();
            Beo beoWithChangedDateFormat = new Beo(beo, dateInString);
            beoListWithChangedDateFormat.add(beoWithChangedDateFormat);
        }

        for(Beo beo : beoListWithChangedDateFormat) {
            BeoItem item = new BeoItem(beo);
            if(deSelectedIds.contains(beo.docId))
                item.checked = false;
            beoItems.add(item);
        }

        system.debug(logginglevel.info, 'beoItems.size() = ' + beoItems.Size());

        // Pagination
        if (noOfRecords > pageSize)
            displayNavButtons = true;
        else
            displayNavButtons = false;

        TotalPageNumber = 0;

        if (beoItems.Size() == 0) {
            if (objectId == null) {
                this.notificationMessage = Label.Merge_NoRecordsFound_TryAgain;
            }
            else {
                this.notificationMessage = Label.Merge_NoRecordsFound;
            }
            this.notificationsPending = true;
        }
        else {
            this.notificationMessage = Label.Merge_NumberOfRecordsReturned + ' ' + noOfRecords;
            this.notificationsPending = true;
        }
    }

    public void getDataForSearch(){
        deSelectedIds = new Set<Id>();
        if(criteria != null){
            criteria.deSelectedIds = new Set<Id>();
        }
        getData();
    }


    public void applyFilters() {
        criteria.apply();
    }

    // For request
    private class MergePayload  {
        public String sessionId {get;set;}
        public Integer timeout { get; set;} //in seconds
        public Integer maxFileSize {get; set;} //in MB
        public String userEmail {get; set;}
        public boolean isBatch {get; set;}
        public String sfServer {get;set;}
        public Id templateId {get;set;}
        public String templateName {get;set;}
        public MergeDataRequest[] MergeDataRequests{get;set;}
        public String outputFileType {get;set;}
        public string namespace {get;set;}
        public string locale {get;set;}
        public string accessToken {get;set;}
        public string refreshToken {get;set;}
        public Integer maxBatchLimit {get;set;}
        public Id batchMergeAttachmentObjectId {get;set;}
        public string language {get;set;}
        public string secondaryLanguage {get;set;}
    }

    private class MergeDataRequest{
        public String objectType {get;set;}
        public Id objectId {get;set;}
        public Id[] eventIds {get;set;}
        public Id[] roomblockIds {get;set;}

        public MergeDataRequest(string objectTypeName, Id recordId, Id[] events, Id[] roomblocks){
            objectId = recordId;
            objectType = objectTypeName;
            eventIds = events;
            roomblockIds = roomblocks;
        }
    }

    // Inserts new instance of BatchMerge object
    private BatchMerge__c createBatchMergeObject() {
        BatchMerge__c batchmerge = new Batchmerge__c();
        batchMerge.name = templateMap.get(selectedTemplateId) + '_' + dateTime.now();
        batchMerge.mergeType__c = selectedMergeType;
        batchMerge.Location__c = criteria.property;
        if (objectId != null)
            batchmerge.Booking__c = objectId;
        //batchMerge.documentPath__c = 'someURL TBD pointing to where all docs are stored after merging';
        Security.CreateObjectWithCheck(batchMerge); //insert batchMerge;
        return batchMerge;
    }

    @RemoteAction
    public static Set<Id> ResolveEventItemBeoSectionByEventIdList(String documentTemplateId, List<Id> bookingDocumentIdList, List<Id> eventIdList) {

        if (eventIdList != null && !eventIdList.isEmpty()) {
            return resolveEventItemBeoSectionBatch(documentTemplateId, eventIdList, null);

        } else if (bookingDocumentIdList != null && !bookingDocumentIdList.isEmpty()) {
            eventIdList = new List<Id>();
            for (BookingEvent__c be : [SELECT Id from BookingEvent__c WHERE Beo__c = : bookingDocumentIdList ]) {
                eventIdList.add(be.Id);
            }
            return resolveEventItemBeoSectionBatch(documentTemplateId, eventIdList, null);
        }

        return new Set<Id>();
    }

    //EVENT - Associate document sections to event items for the supplied event ids.
    private static Set<Id> resolveEventItemBeoSectionBatch(String documentTemplateId, List<Id> eventIdList, Integer batchSize) {
        if (batchSize == null || batchSize <= 0) {
            batchSize = 100;
        }

        Set<Id>eventIdSet = new Set<Id>(eventIdList);
        if (eventIdSet.size() <= batchSize) {
            resolveEventItemBeoSectionInternal(documentTemplateId, eventIdSet);
            return new Set<Id>();  //all ids processed, return empty
        } else {
            Set<Id>currentEventIdSet = new Set<Id>();
            for (Integer index = 0; index < eventIdList.size(); index++) {
                currentEventIdSet.add(eventIdList[index]);
                eventIdSet.remove(eventIdList[index]);
                if (currentEventIdSet.size() >= batchSize) {
                    resolveEventItemBeoSectionInternal(documentTemplateId, currentEventIdSet);
                    currentEventIdSet.clear();
                    break;
                }
            }
            return eventIdSet;
        }
    }

    private static void resolveEventItemBeoSectionInternal(String documentTemplateId, Set<Id> currentEventIdSet) {

        //data structure = Document SectionId => (RevenueClassificationID=>DocumentSectionRevenueClassification)
        Map<Id, Id> sectionMappings = new Map<Id, Id>();
        //get all the documentSections on the selected templates, and get all of those sections associated rev class's
        for(DocumentSection__c ds : [Select
                                        Id,
                                        Name,
                                        DocumentTemplate__c,
                                        Location__c,
                                        (Select
                                            Id,
                                            Location__c,
                                            DocumentSection__c,
                                            RevenueClassification__c
                                        from DocumentSectionRevClasses__r)
                                    from DocumentSection__c
                                    where DocumentTemplate__c =: documentTemplateId ]){

            for(DocumentSectionRevClass__c r : ds.DocumentSectionRevClasses__r){
                if(!sectionMappings.containsKey(r.RevenueClassification__c)){
                    sectionMappings.put(r.RevenueClassification__c, ds.Id);
                }
            }
        }


        //get all EventItems with events being updated, and if applicable update those
        //items beoSectionLookup
        if(!sectionMappings.isEmpty()){
            List<EventItem__c> eventItemsBeingUpdated = new List<EventItem__c>();
            for(EventItem__c ei : [Select
                                        Id,
                                        Name,
                                        RevenueClassification__c,
                                        BeoSection__c,
                                        Booking__c,
                                        Event__c
                                    from EventItem__c
                                    where Event__c IN: currentEventIdSet]){


                if(ei.RevenueClassification__c != null){
                    if(sectionMappings.containsKey(ei.RevenueClassification__c)){
                        if(ei.BeoSection__c != sectionMappings.get(ei.RevenueClassification__c)){
                            ei.BeoSection__c = sectionMappings.get(ei.RevenueClassification__c);
                            eventItemsBeingUpdated.add(ei);
                        }
                    }
                    else{
                        if(ei.BeoSection__c != null){
                            ei.BeoSection__c = null;
                            eventItemsBeingUpdated.add(ei);
                        }
                    }
                }
            }

            if(!eventItemsBeingUpdated.isEmpty()) {
                Security.checkIsObjectUpdateable('EventItem__c');
                try {
                    Triggers.disableAllTriggers = true;
                    Ni.updateWithRetry(eventItemsBeingUpdated, 3);
                } catch (Exception ex) {
                     throw ex;
                } finally {
                    Triggers.disableAllTriggers = false;
                }
            }
        }

    }

    public void getSelectedBookingDocumentIds() {

        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }

        criteria.apply();
        criteria.deSelectedIds = this.deSelectedIds;

        List<String> bdIdList = new List<String>();
        for (BookingDocument__c bd : getRawBeos(criteria, true)) {
            bdIdList.add(bd.Id);
        }

        selectedBookingDocumentIds = json.serialize(bdIdList);
    }

    public void generateDoc() {

        for(BeoItem beoItem : beoItems){
            updateIds(beoItem);
        }

        criteria.apply();
        criteria.deSelectedIds = this.deSelectedIds;
        List<BookingDocument__c> bds = sortBookingDocuments(getRawBeos(criteria, true));

        system.debug('deSelectedIds ====  '+ deSelectedIds);
        system.debug('fullQuery ==== ' + fullQuery);
        system.debug('documents '+ bds);
        system.debug('documents size '+ bds.size());

        String[] bookings = new List<String>();
        String[] documents = new List<String>();
        String events;
        String groups;

        if(setError(validator.validate(bds))) return;

        if (objectId == null) {
            if(setError(validator.validate(criteria))) return;
        }

        isGenerateButtonDisabled = true;



        for(BookingDocument__c bd : bds) {
            bookings.add(bd.Booking__c);
            documents.add(bd.Id);
        }

        if (documents.Size() > 0)
        {

            // Ensure the refresh token is not null
            generationerror = false;
            if (this.OAuthRefreshToken == null){
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.INFO, Label.NiAdminOAuthRefreshTokenNull);
                generationerror = true;
                ApexPages.addMessage(msg);
                return;
            }

            //  Need to create and save a new merge record in order to pass in its objectID for processing.
            BatchMerge__c batchMerge = createBatchMergeObject();

            // Set values used for hyperlink in page
            this.BatchMergeObjectURL = Ni.getSalesforceURL()+'/'+ batchMerge.Id;
            this.BatchMergeObjectURLPrefix = Ni.getSalesforceURL()+'/';
            this.BatchMergeObjectId = batchMerge.Id;
            this.BatchMergeObjectName = batchMerge.name;

            // Set "DistributedInternally" = true when merging BEOs (and not when merging Banquet Checks)
            if (selectedMergeType == MERGETYPE_BEO && isDistributed) {
                Database.executeBatch(new BatchUpdateIsDistributed(documents));
            }
            
            // Set "isBCBatchPrinted" = true when merging Banqeut Checks (and not when merging BEOs)
            if (selectedMergeType == MERGETYPE_BANQUETCHECK && isBCBatchPrinted) {
                Database.executeBatch(new BatchUpdateIsBCBatchPrinted(documents));
            }            

            GenerateBatchHTTPJSON(documents, batchMerge.Id);

            this.notificationMessage = Label.Merge_JobSubmitted;
            this.notificationsPending = true;

        }
    }


    public PageReference back(){
        PageReference page;

        if (objectId != null) {
            String state = ApexPages.currentPage().getParameters().get('state');
            if (state != null)
                ApexPages.currentPage().getParameters().put('id', state);

            page = new PageReference('/apex/' + PrefixMgr.getObjPrefix() + 'BatchMerge?id='+ApexPages.currentPage().getParameters().get('id'));

            system.debug (loggingLevel.info, ' In pagereference back, page = ' + page);
            page.setRedirect(true);
        }
        // came from merges tab
        else {

        }
        //page.setRedirect(true);
        return page;
    }

    public PageReference cancel(){
        PageReference page;

        if (objectId != null) {
            String state = ApexPages.currentPage().getParameters().get('state');
            if (state != null)
                ApexPages.currentPage().getParameters().put('id', state);

            page = new PageReference('/'+ApexPages.currentPage().getParameters().get('id'));
            page.setRedirect(true);
        }
        // came from merges tab
        else {

        }

        //page.setRedirect(true);
        return page;
    }

    public class Session {
        public string access_token;
        public string refresh_token;
    }

    private boolean GetAccessTokens(string authCode) {
        Httprequest req = new httprequest();
        req.setEndpoint(EndPoint);
        req.setMethod('POST');
        req.setbody('grant_type=authorization_code&code='+authCode+'&client_id='+getOauthClientId()+
                        '&client_secret='+getOauthClientSecret()+'&redirect_uri='+MergeRedirectUri);


        try
        {
            session session = new session();
            if(!test.isrunningtest())
            {
                httpresponse response = httpcallout(req);
                session = (session)Json.deserialize(response.getBody(), MergeBatchCls.session.class);
            }
            if(session != null)
            {
                this.OAuthAccessToken = session.access_token;
                this.OAuthRefreshToken = session.refresh_token;
            }
            return true;
        }
        catch(Exception e)
        {
        	if (Security.isObjectCreateable('log__c')) {
            	LogCls.write(e, 'MergeBatchCls.GetAccessTokens', null);
            	return false;
        	}
        }

        return true;
    }

    // handling of http callout
    public static HttpResponse HTTPCallout(HttpRequest req)
    {
        HttpResponse res = new HttpResponse();
        HTTP Http = new HTTP();

        if(req != null)
            res = HTTP.send(req);
        if(res.getStatusCode() == 200)
            return res;
        else
            throw new MergeCalloutException('Http Callout Failed with a status code of '+res.getstatusCode()+' and here are the details '+res.getBody());
    }
    //exception throwing class
    public class MergeCalloutException extends Exception{}

    private void GenerateBatchHTTPJSON(List<String> recordIdList, Id objectId) {
        system.debug(logginglevel.info, 'In GenerateBatchHTTPJSON');

        ApexPages.Message msg;
        generationerror = false;

        if (string.isBlank(recordIdList[0]))
        {
            msg = new ApexPages.Message(ApexPages.Severity.INFO,Label.InvalidRecordId);
            generationerror = true;
            ApexPages.addMessage(msg);
            return;
        }

        Id[] eventIdList = new Id[]{};
        Id[] roomblockIdList = new Id[]{};

        //need to add attribute for PrefixMgr.namespacePrefix
        system.debug(logginglevel.info, 'merge with namespace = ' + PrefixMgr.getNamespace());

        NiPublic__c nip =  NiPublic__c.getOrgDefaults();
        string targetURL =   nip.MergeServiceURL__c ;

        // Get the batchMergeLimit from this ORG's public settings
        Integer maxBatchMergeSize = ( nip.MaxBatchMergeSize__c == null || (nip.MaxBatchMergeSize__c).intValue() > 5 ? 5 : (nip.MaxBatchMergeSize__c).intValue() );
        system.debug(logginglevel.info, 'nip.MaxBatchMergeSize__c= ' + nip.MaxBatchMergeSize__c);

        //Strip server instance out of URL (such as na15)... getHost() does not work for this in VF
        String retURL = URL.getSalesforceBaseUrl().toExternalForm();
        retURL = retURL.substring(retURL.indexOf('.') + 1, retURL.indexOf('.',retURL.indexOf('.') + 1));
        retUrl = 'https://' + retURL + '.salesforce.com';
        retURL += '/services/Soap/u/' + ( nip.APIVersion__c == null ? '27.0' : nip.APIVersion__c) ;

        mergePayload payload = new mergePayload();
        payload.sessionId =  (UserInfo.getSessionId()); //EncBase64
        payload.isBatch = true;
        payload.timeout = 120;
        payload.maxFileSize = 5;
        payload.userEmail = (UserInfo.getUserEmail());
        payload.sfServer = retURL;
        payload.templateId = selectedTemplateId;
        payload.templateName = templateMap.get(selectedTemplateId); //selectedTemplateName;
        
        //payload.locale = (UserInfo.getLocale()).substring(0,5);  // i.e. fr_FR instead of fr_FR_EURO
        if (SelectedLocale == null)
            SelectedLocale = UserLocale;
        payload.locale = SelectedLocale;
        
        system.debug(logginglevel.info, 'selectedLocale= ' + selectedLocale);
        
        payload.namespace = PrefixMgr.getNamespace();
        payload.outputFileType = DocType.toUpperCase(); //selects DOCX or PDF
        payload.accessToken = this.OAuthAccessToken;
        payload.refreshToken = this.OAuthRefreshToken;
        payload.maxBatchLimit = maxBatchMergeSize;
        payload.batchMergeAttachmentObjectId = objectId;
        payload.language = SelectedLanguage;
        payload.secondaryLanguage = SelectedSecondaryLanguage;
        payload.MergeDataRequests = new list<MergeDataRequest>();
                    
        for (Id recordId : recordIdList)
        { 
            Schema.SObjectType token = ID.valueOf(recordId).getSObjectType();
            string packetObject = token.getDescribe().getName();
            eventIdList = null;
            roomblockIdList = null;
  
            MergeDataRequest mergeDataRequest = new MergeDataRequest(selectedMergeType, recordId, eventIdList, roomblockIdList);
            payload.MergeDataRequests.add(mergeDataRequest); 
        }   
      
        if (Test.isRunningTest()) return;  //Tests can't call callout methods
        
        SendPayloadToMergeService(targetURL, JSON.serialize(payload), objectId);
    }    
    
    @future(callout=true)
    private static void SendPayloadToMergeService(string targetURL, string payload, string objectId) { 
         
        HttpRequest req = new HttpRequest();
        req.setEndpoint(targetURL);
        req.setMethod('POST');
        req.setBody(payload);
        req.setTimeout(120000);//set timeout to 2 minutes (can be set from 1ms to 120000ms)
    
        Http http = new Http();
        req.setHeader('X-XSS-Protection', '0');
        HTTPResponse res = http.send(req);
        
        system.debug('HTTPResponse res has returned with throwing exception\n\n\n\n\n' + res.getBody());
        
        string jsonResponse = res.getBody();
        if (objectId != null && !string.isempty(jsonResponse)) {
            try { 
                MergePayloadResponse mergeResponse = (MergePayloadResponse)Json.deserialize(jsonResponse, MergePayloadResponse.class);
                
                if (!mergeResponse.Success) {
                    List<BatchMerge__c> bmList = [Select MergeStatus__c, Message__c From BatchMerge__c Where Id = :objectId]; 
                    if (bmList.size() > 0) { 
                        bmList[0].MergeStatus__c = 'Failure';
                        bmList[0].Message__c = mergeResponse.Error;
                        Security.UpdateListWithCheck(bmList); //update bmList;
                    }
                }
            } catch (Exception e) { 
                LogCls.write(e, 'MergeBatchCls.SendPayloadToMergeService', null);
            }
        }
            
    }    
 
    private Boolean setError(String[] errors) {
        if(errors != null) {
            errorMessage = errors[0];
            
            //  Display errors
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, errorMessage);
            ApexPages.addMessage(myMsg); 
 
            return true;
        }
        else { 
            errorMessage = null;
            return false;
        }
    }
    
    private abstract class Validator {
        public abstract String[] validate(BeoItem[] items);
        
        public abstract String[] validate(BeoSearchCriteria criteria);
        
        public abstract String[] validate(List<BookingDocument__c> items);
    }
    
    private class DefaultValidator extends Validator {
        public override String[] validate(BeoItem[] items) {
            system.debug(logginglevel.info, 'in Validate, validating BeoItems checked');
            for(BeoItem beoItem : items) {
                if(beoItem.checked) return null;
            }
            return new String[] { Label.Merge_SelectBookingDocument };
        }
        
        public override String[] validate(List<BookingDocument__c> items){
            
            if(items.size() > 0){
                return null;
            }
            return new String [] { Label.Merge_SelectBookingDocument };
        }
        

        public override String[] validate(BeoSearchCriteria criteria)
        {
            String[] errors = new List<String>();
            if(criteria.eventStartDate != null && criteria.eventEndDate == null) {
                errors.add(Label.Merge_SelectEventEndDate);  
            }
            if(criteria.eventEndDate != null && criteria.eventStartDate == null) {
                errors.add(Label.Merge_SelectEventStartDate);  
            }
            if( (criteria.eventStartDate != null && criteria.eventEndDate != null) && (criteria.eventStartDate > criteria.eventEndDate)) {
                errors.add(Label.Merge_EventEndDateGreaterThanStart);  
            }
            if(criteria.beoNumberFrom > criteria.beoNumberTo) {
                errors.add(Label.Merge_BeoEndLessThanBeoStart);
            }
            if (criteria.beoNumberFrom < 0 || criteria.beoNumberTo < 0) {
                errors.add(Label.Merge_BeoNumberNegative);
            }
            if (criteria.property == null) {
                errors.add(Label.Merge_SelProp);
            }
            /*system.debug(loggingLevel.info, 'templateId = ' + templateId);            
            if(templateId == null) {
                errors.add(Label.MergeSelectDocumentTemplate);      
            }*/
            
            return errors.size() == 0 ? null : errors;
        }
    }

    public Beo[] getBeos(BeoSearchCriteria criteria) {             
        return mapBeos(getRawBeos(criteria, false), criteria.eventStartDate);
    }
        
    public Template[] getTemplates() {
        return mapTemplates(getRawTemplates());
    }      
        
    private BookingDocument__c[] getRawBeos(BeoSearchCriteria criteria, boolean getFullResults) {       
    
        fullQuery = '';
        String query = '';
        if (selectedMergeType == MERGETYPE_BANQUETCHECK)
            query = 'SELECT Name, Id, Booking__c, Booking__r.Name, Booking__r.BookingStatus__c, Number__c, Beo__r.IsRevised__c, Beo__r.LastRevisedDate__c, (SELECT StartDate__c, StartTime24hour__c, EndDate__c, EndTime24Hour__c, Name, EventClassification__c FROM BanquetCheckBookingEvents__r order by OrderedDateTime__c, Name  LIMIT 1) FROM BookingDocument__c'; 
        else
            query = 'SELECT Name, Id, Booking__c, Booking__r.Name, Booking__r.BookingStatus__c, Number__c, IsRevised__c, LastRevisedDate__c, (SELECT StartDate__c, StartTime24hour__c, EndDate__c, EndTime24Hour__c, Name, EventClassification__c FROM BeoBookingEvents__r order by OrderedDateTime__c, Name LIMIT 1) FROM BookingDocument__c';     
                
        String whereClause = '';
        
        String isDoneWhereClauseBanquet = ' ';
        String isDoneWhereClauseBEO = ' ';
        if (criteria.isDone == true) {                                  //User Story 77063, Add Where clause if IsDone is checked 
            isDoneWhereClauseBanquet = 'Id NOT In (Select BanquetCheck__c from BookingEvent__c where BanquetCheck__c != NULL and IsDone__c = false ) AND Id In (Select BanquetCheck__c from BookingEvent__c where BanquetCheck__c != NULL ';
            isDoneWhereClauseBEO = 'Id NOT In (Select Beo__c from BookingEvent__c where Beo__c != NULL and IsDone__c = false ) AND Id In (Select Beo__c from BookingEvent__c where Beo__c != NULL ';
        }
        else{
            isDoneWhereClauseBanquet = 'Id In (Select BanquetCheck__c from BookingEvent__c where BanquetCheck__c != NULL';
            isDoneWhereClauseBEO = 'Id In (Select Beo__c from BookingEvent__c where Beo__c != NULL';
        }   
            
        // Searching for all bookingDocuments for specific booking because we got to this screen from the Booking's "Batch Merge" button click
        //SELECT Name, Id, devwork__Booking__c, devwork__Booking__r.Name, devwork__Booking__r.devwork__BookingStatus__c, devwork__Number__c, (SELECT Name, devwork__StartDate__c, devwork__EventClassification__c FROM devwork__BanquetCheckBookingEvents__r ORDER BY devwork__StartDate__c LIMIT 1) FROM devwork__BookingDocument__c 
        //where Id In (Select devwork__BanquetCheck__c from devwork__BookingEvent__c where devwork__BanquetCheck__c != NULL) 
        //and devwork__Booking__c = 'a09G000000cYsZT' ORDER BY devwork__BookingDocumentEventDate__c

        system.debug(logginglevel.info, 'In GetRawBeos, objectId = ' + objectId);

        if (objectId != null) {
        
            //system.debug(logginglevel.info, 'creating whereclause; criteria.property= ' + criteria.property);
        
            if (selectedMergeType == MERGETYPE_BANQUETCHECK)
                whereClause = isDoneWhereClauseBanquet + ' ) and Booking__c = ' + '\'' + String.escapeSingleQuotes(objectId) + '\'';
            else 
                whereClause = isDoneWhereClauseBEO + ' ) and Booking__c = ' + '\'' + String.escapeSingleQuotes(objectId) + '\'';
            
            
            system.debug(logginglevel.info, 'in whereclause, criteria.property= ' + criteria.property);
            
            whereClause = addToWhere(criteria.property != null, 'location__c = \'' + String.escapeSingleQuotes((criteria.property != null ? criteria.property : '')) + '\'', whereClause);                     
        }
        else {
            Integer selectedCount = 0;
            
            // EventClassifications
            String eventClassificationWhere = '';
            if (criteria.selectedEventClassifications != null && criteria.selectedEventClassifications.Size() > 0) {
                selectedCount = criteria.selectedEventClassifications.Size();
                integer i = 0;
                eventClassificationWhere = ' EventClassification__c in (';
                for(String eventClassification : criteria.selectedEventClassifications) {
                    i++;
                    eventClassificationWhere += '\'' + string.escapeSingleQuotes(eventClassification) + '\'';                      
                    if (i < selectedCount)
                        eventClassificationWhere += ',';
                }
                eventClassificationWhere += ')';
            }
            
            // FunctionRooms
            String functionRoomWhere = '';
            if (criteria.selectedFunctionRooms != null && criteria.selectedFunctionRooms.Size() > 0) {
                selectedCount = criteria.selectedFunctionRooms.Size();
                integer i = 0;
                functionRoomWhere = ' FunctionRoom__c in (';
                for(String functionRoom : criteria.selectedFunctionRooms) {
                    i++;
                    functionRoomWhere += '\'' + string.escapeSingleQuotes(functionRoom) + '\'';                    
                    if (i < selectedCount)
                        functionRoomWhere += ',';
                }
                functionRoomWhere += ')';
            }           
            
            // Booking Statuses
            if (criteria.selectedStatuses != null && criteria.selectedStatuses.Size() > 0) {
                selectedCount = criteria.selectedStatuses.Size();
                integer i = 0;
                whereClause += 'Booking__r.BookingStatus__c in (';
                for(String status : criteria.selectedStatuses)
                {
                    i++;
                    whereClause += '\'' + string.escapeSingleQuotes(status) + '\'';
                    if (i < selectedCount)
                        whereClause += ',';         
                }
                whereClause += ')';
            } 
            
            
            // Add to the event whereClause if selected criteria is based on events (start/end dates, FunctionRooms or EventClassifications)
            if( (criteria.eventStartDate != null && criteria.eventEndDate != null) 
                || criteria.selectedFunctionRooms != null && criteria.selectedFunctionRooms.Size() > 0 
                || criteria.selectedEventClassifications != null && criteria.selectedEventClassifications.Size() > 0) {
             
                String eventSelect = '';
                if (selectedMergeType == MERGETYPE_BANQUETCHECK)
                    eventSelect = isDoneWhereClauseBanquet + ' and ';
                else
                    eventSelect = isDoneWhereClauseBEO + ' and ';
                        
                String eventWhere = '';
                eventWhere = addToWhere(criteria.eventStartDate != null, 'StartDate__c >= ' + formatDate(criteria.eventStartDate), eventWhere);
                eventWhere = addToWhere(criteria.eventStartDate != null, 'StartDate__c <= ' + formatDate(criteria.eventEndDate), eventWhere);
                eventwhere = addToWhere(criteria.selectedEventClassifications != null && criteria.selectedEventClassifications.Size() > 0, eventClassificationWhere, eventWhere);
                eventWhere = addToWhere(criteria.selectedFunctionRooms != null && criteria.selectedFunctionRooms.Size() > 0, functionRoomWhere, eventWhere);
                whereClause = addToWhere(true, eventSelect + eventWhere + ')', whereClause);    
            }
            else {
                if (criteria.selectedStatuses != null && criteria.selectedStatuses.Size() > 0) 
                    whereClause += ' and ';  
    
                if (selectedMergeType == MERGETYPE_BANQUETCHECK)
                    whereClause += isDoneWhereClauseBanquet + ' ) '; 
                else
                    whereClause += isDoneWhereClauseBEO + ' ) ';
            }
            
            if (!String.isEmpty(criteria.postAs)) {
                whereClause = addToWhere(criteria.postAs != null, 'Booking__r.Name like \'%' + String.escapeSingleQuotes(criteria.postAs) + '%\'', whereClause);
            }
            whereClause = addToWhere(criteria.beoNumberFrom != null, 'BookingDocument__c.Number__c >= ' + String.escapeSingleQuotes((criteria.beoNumberFrom != null ? string.valueOf(criteria.beoNumberFrom) : '')), whereClause);
            whereClause = addToWhere(criteria.beoNumberTo != null, 'BookingDocument__c.Number__c <= ' + String.escapeSingleQuotes((criteria.beoNumberTo != null ? string.valueOf(criteria.beoNumberTo) : '')), whereClause);
            whereClause = addToWhere(criteria.account != null, 'Booking__r.Account__c = \'' + String.escapeSingleQuotes((criteria.account != null ? criteria.account : '')) + '\'', whereClause);
            //whereClause = addToWhere(criteria.property != null && criteria.property != '--All--', 'Booking__r.Property__c = \'' + criteria.property + '\'', whereClause);
            whereClause = addToWhere(criteria.property != null, 'BookingDocument__c.Location__c = \'' + String.escapeSingleQuotes((criteria.property != null ? criteria.property : '')) + '\'', whereClause);     
        }
        
        if (selectedMergeType == MERGETYPE_BEO) {
            if (criteria.selectedDistributedOption == 'Distributed')   
                whereClause = addToWhere(criteria.selectedDistributedOption != null, 'BookingDocument__c.distributedInternally__c = true', whereClause);                    
            else if (criteria.selectedDistributedOption == 'UnDistributed')
                whereClause = addToWhere(criteria.selectedDistributedOption != null, 'BookingDocument__c.distributedInternally__c = false', whereClause);                
        }
        
        if (selectedMergeType == MERGETYPE_BANQUETCHECK) {
            if (criteria.selectedBCBatchPrintedOption == 'Batch Printed')   
                whereClause = addToWhere(criteria.selectedBCBatchPrintedOption != null, 'BookingDocument__c.isBanquetCheckBatchPrinted__c = true', whereClause);                    
            else if (criteria.selectedBCBatchPrintedOption == 'Not Batch Printed')
                whereClause = addToWhere(criteria.selectedBCBatchPrintedOption != null, 'BookingDocument__c.isBanquetCheckBatchPrinted__c = false', whereClause);                
        }        
                         
        if (criteria.isUsingTemplate == true ) {
            whereClause = addToWhere(criteria.isUsingTemplate != null, 'DocumentTemplate__c = \''+ String.escapeSingleQuotes((selectedTemplateId != null ? selectedTemplateId : '')) +'\'', whereClause);                  
        }
        
        if (criteria.isRevised == true ) {
            String st = criteria.viewEvent.StartDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
            String et = criteria.viewEvent.EndDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
            if (selectedMergeType == MERGETYPE_BANQUETCHECK) {
                whereClause = addToWhere(criteria.isRevised != null, 'Beo__r.IsRevised__c = true AND (Beo__r.LastRevisedDate__c >= ' + st + ' AND Beo__r.LastRevisedDate__c <= ' + et + ')', whereClause);
            } else { 
                whereClause = addToWhere(criteria.isRevised != null, 'IsRevised__c = true AND (LastRevisedDate__c >= ' + st + ' AND LastRevisedDate__c <= ' + et + ')', whereClause);
            }                   
        }
        
        if(criteria !=null){
            whereClause = addToWhere(criteria.deSelectedIds.size() >0, 'Id NOT IN :deSelectedIds', whereClause);    
        }
              
        fullQuery = query + (whereClause == '' ? '' : ' WHERE ' + whereClause) + ' ORDER BY BookingDocumentEventDate__c';
        
        
        system.debug(logginglevel.info, 'fullQuery= ' + fullQuery);
        
        
        if(getFullResults){
            return Database.query(fullQuery);
        }
        else{
            return setCon.GetRecords(); 
        }
    }
        
        
    private Beo[] mapBeos(BookingDocument__c[] rawBeos, Date fromDate) {
        
        rawBeos = sortBookingDocuments(rawBeos);
        
        Beo[] ret = new List<Beo>();
            
        if (selectedMergeType == MERGETYPE_BANQUETCHECK) {
            // if came from "Merges" tab            
            if (objectId == null) { 
                for(BookingDocument__c rawBeo : rawBeos) {
                    if((fromDate == null || rawBeo.BanquetCheckBookingEvents__r[0].StartDate__c >= fromDate) && rawBeo.BanquetCheckBookingEvents__r.size() != 0) {
                        
                        ret.add(new Beo(rawBeo.BanquetCheckBookingEvents__r[0].StartDate__c,
                                    rawBeo.BanquetCheckBookingEvents__r[0].Name,
                                    rawBeo.Booking__r.Name, 
                                    rawBeo.Name, 
                                    rawBeo.Booking__r.BookingStatus__c,
                                    rawBeo.Number__c,                                    
                                    rawBeo.Id, 
                                    rawBeo.Booking__c, 
                                    ((rawBeo.Beo__r.IsRevised__c == true && rawBeo.Beo__r.LastRevisedDate__c != null)? rawBeo.Beo__r.LastRevisedDate__c.format() : '')));



                    }                           
                }
            }
            else {   // came from Booking layout
                for(BookingDocument__c rawBeo : rawBeos) {
                    
                        ret.add(new Beo(rawBeo.BanquetCheckBookingEvents__r[0].StartDate__c,
                                   rawBeo.BanquetCheckBookingEvents__r[0].Name,
                                   rawBeo.Booking__r.Name, 
                                   rawBeo.Name, 
                                   rawBeo.Booking__r.BookingStatus__c,
                                   rawBeo.Number__c,
                                   rawBeo.Id, 
                                   rawBeo.Booking__c,
                                   ((rawBeo.Beo__r.IsRevised__c == true && rawBeo.Beo__r.LastRevisedDate__c != null)? rawBeo.Beo__r.LastRevisedDate__c.format() : '')));
                              
                }
            }   
        }
            
        if (selectedMergeType == MERGETYPE_BEO) {
            // if came from "Merges" tab            
            if (objectId == null) { 
                for(BookingDocument__c rawBeo : rawBeos) {
                    if((fromDate == null || rawBeo.BeoBookingEvents__r[0].StartDate__c >= fromDate) && rawBeo.BeoBookingEvents__r.size() != 0) {
                        
                        ret.add(new Beo(rawBeo.BeoBookingEvents__r[0].StartDate__c,
                                    rawBeo.BeoBookingEvents__r[0].Name,
                                    rawBeo.Booking__r.Name, 
                                    rawBeo.Name, 
                                    rawBeo.Booking__r.BookingStatus__c,
                                    rawBeo.Number__c,                                    
                                    rawBeo.Id, 
                                    rawBeo.Booking__c,
                                    ((rawBeo.IsRevised__c == true && rawBeo.LastRevisedDate__c != null) ? rawBeo.LastRevisedDate__c.format() : '')));
                    }                           
                }
            }
            else {   // came from Booking layout
                for(BookingDocument__c rawBeo : rawBeos) {
                    
                        ret.add(new Beo(rawBeo.BeoBookingEvents__r[0].StartDate__c,
                                   rawBeo.BeoBookingEvents__r[0].Name,
                                   rawBeo.Booking__r.Name, 
                                   rawBeo.Name, 
                                   rawBeo.Booking__r.BookingStatus__c,
                                   rawBeo.Number__c,
                                   rawBeo.Id, 
                                   rawBeo.Booking__c,
                                   ((rawBeo.IsRevised__c == true && rawBeo.LastRevisedDate__c != null)  ? rawBeo.LastRevisedDate__c.format() : '')));
                                                   
                }
            }   
        }       
  
                   
        return ret;
    }
    
    /*
    sort the bookingDocuments by events for the startDate,StartTime, EndDate,EndTime, Name. 
    */
    private List<BookingDocument__c> sortBookingDocuments(List<BookingDocument__c> docs){
        
        List<BookingDocument__c> sortedDocs = new List<BookingDocument__c>();
        Map<DateTime, List<BookingDocument__c>> docDateTimes = new Map<DateTime, List<BookingDocument__c>>();
        
            for(BookingDocument__c doc : docs){
                    
                BookingDocument__c lastDoc = new BookingDocument__c();
                List<BookingEvent__c> events = new List<BookingEvent__c>();
                
                if (selectedMergeType == MERGETYPE_BANQUETCHECK){
                    events.addAll(doc.BanquetCheckBookingEvents__r);
                }
                else if(selectedMergeType == MERGETYPE_BEO){
                    events.addAll(doc.BeoBookingEvents__r);
                }
                if(events.size() > 0)   {
                                
                        BookingEvent__c be = events[0];
                        DateTime dtStart;
                        DateTime dtEnd;
                    
                        if (be.StartTime24Hour__c != null)
                        dtStart = datetime.newInstanceGmt(be.StartDate__c,Time.newInstance(Integer.valueof(be.StartTime24Hour__c.split(':')[0]), Integer.valueof(be.StartTime24Hour__c.split(':')[1]), 0, 0));
                        else
                            dtStart = datetime.newInstanceGmt(be.StartDate__c, Time.newInstance(0, 0, 0, 0));
                            
                        if (be.EndTime24Hour__c != null)
                            dtEnd = datetime.newInstanceGmt(be.enddate__c,Time.newInstance(Integer.valueof(be.EndTime24Hour__c.split(':')[0]), Integer.ValueOf(be.EndTime24Hour__c.split(':')[1]), 0, 0));
                        else 
                            dtEnd = datetime.newInstanceGmt(be.enddate__c,Time.newInstance(0, 0, 0, 0));
                
                        if(!docDateTimes.containsKey(dtStart)){
                            docDateTimes.put(dtStart, new List<BookingDocument__c>());
                        }
                        docDateTimes.get(dtStart).add(doc);
                    }
                
            }
            
            List<DateTime> sortedDateTimes = new List<DateTime>();
            sortedDateTimes.addAll(docDateTimes.keySet());
            sortedDateTimes.sort();
            
            for(DateTime earliestTime : sortedDateTimes){
                for(BookingDocument__c bookingDoc : docDateTimes.get(earliestTime)){
                    sortedDocs.add(bookingDoc);
                }
            }
        
        
        return sortedDocs;
    } 
     
    private DocumentTemplate__c[] getRawTemplates() {
    
    
    
        system.debug(logginglevel.info,'in getRawTemplates(), criteria.property= ' + criteria.property);
    
    
        return [SELECT Id, Name
                FROM DocumentTemplate__c 
                WHERE IsActive__c = true
                AND (Location__c =: criteria.property OR MasterSource__c = 'Corporate') 
                AND TemplateType__c IN ( :selectedMergeType )                    
                ORDER BY Name];
    }
     
    
    private Template[] mapTemplates(DocumentTemplate__c[] rawTemplates) {
        Template[] ret = new List<Template>();
                        
        for(DocumentTemplate__c rawTempl : rawTemplates) {
            ret.add(new Template(rawTempl.Id, rawTempl.Name));
            
            // Add to the template map while we're here; this map will be accessed to get the selected template's name
            TemplateMap.put (rawTempl.Id, rawTempl.Name);
        }
        
        // test
        /*for (Id id : TemplateMap.keySet())
        {
            System.debug(logginglevel.info, 'keysetId= ' + id);
            System.debug(logginglevel.info, 'returnValue is ' + TemplateMap.get(id));
        }*/
         
        return ret;
        
    } 
    //End not portable
       
        
    private string addToWhere(Boolean cond, string param, string whereClause) {
        if(!cond) return whereClause;
            return whereClause + (whereClause.length() == 0 ? '' : ' AND ') + param;
    }
        
    private string formatDate(DateTime value) {
        if(value == null) return '';
            return value.formatGmt('yyyy-MM-dd');
    }
   
    
    public class Template {
        public String id { get; private set; }
        public String name { get; private set; }
            
        public Template(String id, String name) {
            this.id = id;
            this.name = name;
        } 
    }
    
    
    public class BeoItem {
        public BeoItem(Beo beo) {
            this.beo = beo;
            
            // Default to all checked
            this.checked = true;            
        }
        
        public Beo beo { get; set; }
        
        public Boolean checked { get; set; }
    }
    
    //public class Beo implements Comparable{    //Defect #35890 --- made this class to implement Comparable interface to use sorting
    public class Beo {    //Defect #35890 --- made this class to implement Comparable interface to use sortin
        public Beo(Date firstEventDate, String firstEventName, String bookingPostAs, String beoName, String status, Decimal beoNumber, String docId, String bookId, string LastRevisedDateStr) {
            this.firstEventDate = firstEventDate == null ? null : firstEventDate; 
    system.debug(loggingLevel.info, 'this.firstEventDate = ' + this.firstEventDate);               
            this.firstEventName = firstEventName;
            this.bookingPostAs = bookingPostAs;     
            this.beoName = beoName;
            this.status = status;
            this.beoNumber = beoNumber; 
            this.docId = docId;
            this.bookId = bookId;
            this.LastRevisedDateStr = LastRevisedDateStr;
        }
        
        //Defect #35890 --- Added parameterized constructor for saving beo detail with different date format  
        public Beo(Beo beo, String formatedDate){
            this.firstEventDateInString = formatedDate;
    system.debug(loggingLevel.info, 'this.firstEventDateInString = ' + this.firstEventDateInString);             
            this.firstEventName = beo.firstEventName;
            this.bookingPostAs = beo.bookingPostAs;     
            this.beoName = beo.beoName;
            this.status = beo.status;
            this.beoNumber = beo.beoNumber;
            this.docId = beo.docId;
            this.bookId = beo.bookId;
            this.LastRevisedDateStr = beo.LastRevisedDateStr;
        }
        

        public String firstEventName { get; private set; }
        
        public Date firstEventDate { get; private set; }
        
        public String firstEventDateInString { get; private set; }   // Display event date in String format
        
        public String bookingPostAs { get; private set; }
        
        public String beoName { get; private set; }
        
        public String status { get; private set; }
        
        public Decimal beoNumber { get; private set; }
                
        public String docId { get; private set; }
        
        public String bookId { get; private set; }
        
        public String LastRevisedDateStr { get; private set; }
    }
    
    public class BeoSearchCriteria {
        //Begin not portable        
        public MergeCls.SearchAttributes viewEvent { get; set; } 
		
        public BookingDocument__c viewBeo { get; set; }
        
        public Set<Id> deSelectedIds {get;set;}
        
        
        public void apply() {
            if(viewEvent != null) {
                account = viewEvent.EventAccount;
                eventStartDate = viewEvent.StartDate;
                eventEndDate = viewEvent.EndDate;
            }

            if(viewBeo != null) {
                beoNumber = viewBeo.Number__c;
            }
            
            clearNullValues();          
        }
        

        public void init() {
            
            deSelectedIds = new Set<Id>();
            
            initSObjects();
            initDates(); 
        }
                
        private void initSObjects() {
            viewEvent = new MergeCls.SearchAttributes();
            viewBeo = new BookingDocument__c();
        }
   
        private void initDates() {
            try{
            
                viewEvent.StartDate = date.today().addDays(defaultBeoDistributionStartDays);
                viewEvent.EndDate = viewEvent.StartDate.addDays(defaultBeoDistributionDays); 
                viewEvent.StartDateTime = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
                viewEvent.EndDateTime = DateTime.now();
            }
            catch(Exception e){
                
                String errorMsg = Label.BM_error;
                String[] msg = errorMsg.split(';');
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg[0]));
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg[1]));
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,msg[2]));
            }
            
         }
                           
 
        
        private void clearNullValues() {
            if(postAs == '') postAs = null;
            if(beoNumberFrom == 0) beoNumberFrom = null;
            if(beoNumberTo == 0) beoNumberTo = null;
            if(account == '') account = null;
        }
        
        public String property { get; set; }  
        public String postAs { get; set; }
        public Date eventStartDate { get; set; }
        public Date eventEndDate { get; set; }
        public Time eventStartTime { get; set; }
        public Time eventEndTime { get; set; }        
        public Integer beoNumberFrom { get; set; }
        public Integer beoNumberTo { get; set; }
        public String account { get; set; }
        public Decimal beoNumber { get; set; }
        public String[] selectedEventClassifications { get; set; } 
        public String[] selectedFunctionRooms { get; set; }
        public String[] selectedStatuses { get; set; }
        public String selectedDistributedOption {get;set;}
        public String selectedBCBatchPrintedOption {get;set;}
        public boolean isDone { get; set; }
        public boolean isUsingTemplate{get;set;}       
        public boolean isRevised { get; set; }
         
        // Get the default property; start with user's; if null, use the ORG's; if null, return null
        private String defaultProperty {
            get {
            
                NiPublic__c niSettingsUser = NiPublic__c.getInstance(UserInfo.GetUserId());
                if (niSettingsUser.DefaultLocationId__c != null)  
                    return niSettingsUser.DefaultLocationId__c;
                else {
                    NiPublic__c niPublic =  NiPublic__c.getOrgDefaults();
                    if (niPublic.DefaultLocationId__c != null)         
                        return niPublic.DefaultLocationId__c;
                    else
                        return null;
                }
            }
        }
       
        // This is the property's default end days
        private Integer defaultBeoDistributionDays {
            get {
                
                system.debug(loggingLevel.info, 'getting defaultDistributionDays, property = ' + property);
            
                if (property == null) 
                    return 0;   
                else {
                    Location__c prop = [select DefaultBeoDistributionDays__c from location__c where location__c.Id = :property];
                    system.debug(loggingLevel.info, 'defaultBeoDistributionDays = ' + prop.defaultBeoDistributionDays__c);
            
                    return prop.defaultBeoDistributionDays__c != null ? Integer.valueOf(prop.defaultBeoDistributionDays__c) : 0;
                }
            }
        }
        
        // this is the property's default start days
        private Integer defaultBeoDistributionStartDays {
            get {
                
                system.debug(loggingLevel.info, 'getting defaultBeoDistributionStartDays, property = ' + property);
            
                if (property == null) 
                    return 0;   
                else {
                    Location__c prop = [select defaultBeoDistributionStartDays__c from location__c where location__c.Id = :property];
                    system.debug(loggingLevel.info, 'defaultBeoDistributionStartDays = ' + prop.defaultBeoDistributionStartDays__c);
            
                    return prop.defaultBeoDistributionStartDays__c != null ? Integer.valueOf(prop.defaultBeoDistributionStartDays__c) : 0;
                }
            }
        }       
        
    }   
    
    private class MergePayloadResponse {
        private boolean Success {get; set;}
        private List<String> AttachmentIds {get; set;}
        private String Error {get; set;}
    }
    
    
    private class CannotConstructException extends Exception { }  
    

}