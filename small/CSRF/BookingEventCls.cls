/**
* @author Liza Romanenko
* @date 15/06/2012  
* @description : class contains Triggers logic for BookingEvent object
*/
public class BookingEventCls {
    /*------------------------------------
        BookingEvent Trigger Handlers
        Description:
    -------------------------------*/
    /**
        FollowBookingStatusOwner - following status and owner. Also apply DateTime convertion here for StartDateTime and EndDateTime
            SetupValues Trigger
        before insert, before update
    */
    public class BookingStorage {
        public string Status {get; set;}
        public Date StartDate {get; set;}
        public Date EndDate {get; set;}
        public string updateCause {get; set;} //Revenue, Status, Date
    }

	public List<SelectOption> propertyOptions{get;set{this.propertyOptions=value;}}
	public Map<Id, String> propertyNameLookup{get;set{this.propertyNameLookup=value;}}
	public Id selectedPropertyId{get;set{this.selectedPropertyId = value;}}
	String RecordTypeId {get;set;}
	public static Boolean securityEnabled = SharingManager.getBookingSecuritySettings();
	public static Boolean AccSecurityEnabled = SharingManager.getAccountSecuritySettings();
	public String PropertyInitiated;
    
    public static final string protectedCustomSettingName = 'Default';
    public static string eventMessages{get; set;}
    
    public static boolean RollupRevenue = true;
    
    public static boolean RollupBooking = false;
    
    public static boolean updateFromBooking= false;
    
    public static boolean processingClone= false;

    public static Map<Id, BookingStorage> bookingsToUpdate = new Map<Id, BookingStorage>();
    
    public static ApexPages.StandardController messagePage {get; set;}
    
    public static BookingEventDataStore queriedInfo = new BookingEventDataStore();
    
    public static boolean enableAverageCheckDefaulting = false;
    
    public BookingEventCls(ApexPages.StandardController controller)
    {
        messagePage = controller; 
        eventMessages = '';
        
		this.propertyNameLookup = new Map<Id, String>();
        this.propertyOptions = new List<SelectOption>();
		
		if(ApexPages.currentPage().getParameters().containsKey('RecordType')) {
        	RecordTypeId = ApexPages.currentPage().getParameters().get('RecordType');
        }
		
		if(ApexPages.currentPage().getParameters().containsKey('selectedProperty'))
        	PropertyInitiated = ApexPages.currentPage().getParameters().get('selectedProperty');

		initializePropertyList();
    }
    public BookingEventCls(){
        eventMessages = '';
		
    }

	// ====== PROPERTY SELECTION ======

	private Map<String, String> label_fieldId;
	public PageReference next () {
		BookingEvent__c booking = new BookingEvent__c();
		label_fieldId = fillLabelToIdMap();
		String LocationFieldId = label_fieldId.get(BookingEvent__c.Location__c.getDescribe().getLabel());
		String PropertyFieldId = label_fieldId.get(BookingEvent__c.Property__c.getDescribe().getLabel());
		for (String i: label_fieldId.keySet()) {
			System.debug('====> ' + i);
			System.debug('====> ' + label_fieldId.get(i));
		}
		System.debug('====  >> ' + LocationFieldId);
		System.debug('====  >> ' + PropertyFieldId);
		String recordTypeQueryParam = '';            
            
        if(RecordTypeId != null && RecordTypeId != ''){
        	recordTypeQueryParam += '&' + 'RecordType=' +  EncodingUtil.urlEncode(RecordTypeId,'UTF-8');
        }

		PageReference evtPage = new PageReference('/' + Schema.getGlobalDescribe().get('BookingEvent__c').getDescribe().getKeyPrefix() +'/e?nooverride=1'
			+ '&' + LocationFieldId + '=' + EncodingUtil.urlEncode(propertyNameLookup.get(selectedPropertyId),'UTF-8')
			+ '&' + PropertyFieldId + '=' + EncodingUtil.urlEncode(propertyNameLookup.get(selectedPropertyId),'UTF-8')
			+ recordTypeQueryParam
        );

		evtPage.setRedirect(true);
        return evtPage;
	}

	//Cancel any updates
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + Schema.getGlobalDescribe().get('BookingEvent__c').getDescribe().getKeyPrefix() + '/o');
        returnPage.setRedirect(true);
        return returnPage ;
    }

	//Initialize the list of Properties (propertyOptions)
    public void initializePropertyList(){
  
        List<propertyuser__c> propUserList = new List<propertyuser__c>(); 
        List<Location__c> locationList = new List<Location__c>(); 
        //Applying fix for Defect #47454
        Map<String,Id> propNameIdtoId = new Map<String,Id>();
        List<String> propNameIdList;

        propUserList =[select id, property__c,Property__r.Name FROM propertyuser__c WHERE Property__r.isActive__c = true AND user__c =:(UserInfo.getUserId()) // fix for defect 53505
        		AND (AccessLevel__c = 'Read/Write' or  AccessLevel__c = 'Read Only')];
        if(propUserList.size() == 0) {
  			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,Label.AccountNotAccesible));
  			return;
        }
  	      
	    if(!securityEnabled || !AccSecurityEnabled)
	   		locationList = LocationClass.getLocations().values();
	   		 															
  		//check to see if PropertyUser__c is in use. else use Location 
  		if(securityEnabled && AccSecurityEnabled){
	        for (propertyuser__c pUser: propUserList){
	            propertyNameLookup.put(pUser.property__c, pUser.property__r.Name);
	            //Map key is combination of property name and ID, later used for sorting.
	            propNameIdtoId.put(pUser.property__r.Name+pUser.property__c,pUser.property__c);
	        } 
  		}
  		else{
  			for(Location__c loc : locationList){
  				// Applying change for propery sorting.
  				propNameIdtoId.put(loc.Name,loc.Id);
  				propertyNameLookup.put(loc.Id,loc.Name);
  			}
  		}
        
        //Need to apply sort on property name insted of Id i.e. propertyNameLookup.keyset()
        propNameIdList = new List<String>(propNameIdtoId.keyset());        
        propNameIdList.sort();
        for(string s : propNameIdList){
            SelectOption so = new SelectOption(propNameIdtoId.get(s),propertyNameLookup.get(propNameIdtoId.get(s)));
            propertyOptions.add(so);
			this.selectedPropertyId = propNameIdtoId.get(s);        
		}
        if(PropertyInitiated != Null && propertyNameLookup.containsKey(PropertyInitiated))
        {
        	this.selectedPropertyId = PropertyInitiated;
        }
        else
        {
        	NiPublic__c niPublic = NiPublic__c.getInstance();
        	if (niPublic.DefaultLocationId__c != null && propertyNameLookup.containsKey(niPublic.DefaultLocationId__c))
        		this.selectedPropertyId = niPublic.DefaultLocationId__c;
        }
    }

	// fillLabelToIdMap used for populate the Account and Property on the booking
    public Map<String, String> fillLabelToIdMap() {
        // Obtain the ids
        PageReference p= new PageReference('/' + Schema.getGlobalDescribe().get('BookingEvent__c').getDescribe().getKeyPrefix() +'/e?nooverride=1');
        String html = '';
        if (!Test.isRunningTest())
          html = p.getContent().toString();
        else
        	html = '<label for="test.istest">(<span class="requiredMark"></span>)test.istest</label>';
        Map<String, String> labelToId = new Map<String, String>();
        Matcher m = Pattern.compile('<label for="(.*?)">(<span class="\\w+"?>\\*</span>)*(.*?)</label>').matcher(html);
        while (m.find()) {
            String label = m.group(3);
            String id = m.group(1);
            labelToId.put(label, id);
        }
        return labelToId;
    }

	// ====== END OF PROPERTY SELECTION ======
    
    public class BookingEventDataStore
    {
        
        public map<Id,list<BookingPackageEvent__c>> eventIdToPackageEvents {get; set;}
        public boolean queryPackageEvent {get;set;}

        public Map<Id, Location__c> Locations {get; set;}
        public Map<Id, FunctionRoom__c> FunctionRooms {get; set;}
        public Map<Id, FunctionRoomTax__c> FunctionRoomTaxes {get; set;}
  //      public Map<Id, ComboRoomComponent__c> ComboRoomComponents {get; set;}
        public Map<Id, BookingEvent__c> ContextEvents {get; set;}
        public Map<Id, Booking__c> Bookings {get; set;}
        public Map<Id, BookingPackageEvent__c> PackageEvents {get; set;}
        public Map<Id, EventClassification__c> EventClassifications {get; set;}
        public Map<Id, TaxGroup__c> TaxGroups{get; set;}

        public BookingEventDataStore(){
            this.ContextEvents = new Map<Id, BookingEvent__c>(); 
            this.Bookings = new Map<Id, Booking__c>(); 
            this.Locations = new Map<Id, Location__c>(); 
            this.FunctionRooms = new Map<Id, FunctionRoom__c>();
            this.FunctionRoomTaxes = new Map<Id, FunctionRoomTax__c>();
        //    this.ComboRoomComponents = new Map<Id, ComboRoomComponent__c>(); 
            this.PackageEvents = new Map<Id, BookingPackageEvent__c>();
            this.EventClassifications = new Map<Id, EventClassification__c>();
            this.TaxGroups = new Map<Id, TaxGroup__c>();
        }

        public void buildOutEventSpecificData(List<BookingEvent__c> events){
        
            if(events.isEmpty())
                return;

            
           if(!Trigger.isInsert){
                Map<Id, BookingEvent__c> tempEvents = new Map<Id, BookingEvent__c>(events);
                //if(!this.ContextEvents.isEmpty() && this.ContextEvents.keySet().containsAll(tempEvents.keySet()))
                //    return;
            } 
           
                
            Set<Id> eventIds = new Set<Id>();
            
            Set<Id> bookingIds = new Set<Id>();
            Set<Id> locationIds = new Set<Id>(); 
            Set<Id> eventClassificationIds = new Set<Id>(); 

            for(BookingEvent__c be : events){
                if(be.Id != null)
                    this.ContextEvents.put(be.Id, be);

                bookingIds.add(be.Booking__c);
                
                locationIds.add(be.Location__c);
                
                if(be.EventClassification__c != null)
                    eventClassificationIds.add(be.EventClassification__c);



            }
            eventIds.addAll(this.ContextEvents.keySet());
            this.Bookings = new Map<Id, Booking__c>([SELECT         
                                                        Id, BookingStatus__c, OwnerId, ArrivalDate__c, DepartureDate__c,

                                                        (SELECT Id, BookingEvent__c, AgreedPackageAttendance__c,
                                                            ForecastPackageAttendance__c, GuaranteedPackageAttendance__c,
                                                            BookedRevenue1__c, BookedRevenue2__c, BookedRevenue3__c, BookedRevenue4__c, BookedRevenue5__c, 
                                                            BookedRevenue6__c, BookedRevenue7__c, BookedRevenue8__c, BookedRevenue9__c, BookedRevenue10__c, 
                                                            BookedRevenue11__c, BookedRevenue12__c, BookedRevenue13__c, BookedRevenue14__c, BookedRevenue15__c,
                                                            
                                                            ActualRevenue1__c, ActualRevenue2__c, ActualRevenue3__c, ActualRevenue4__c, ActualRevenue5__c, 
                                                            ActualRevenue6__c, ActualRevenue7__c, ActualRevenue8__c, ActualRevenue9__c, ActualRevenue10__c, 
                                                            ActualRevenue11__c, ActualRevenue12__c, ActualRevenue13__c, ActualRevenue14__c, ActualRevenue15__c,

                                                            BookingPackage__r.BookingRoomBlock__c, 
                                                            BookingPackage__r.BookingRoomBlock__r.Id, 
                                                            BookingPackage__r.BookingRoomBlock__r.Name, 
                                                            BookingPackage__r.BookingRoomBlock__r.Location__c, 
                                                            BookingPackage__r.BookingRoomBlock__r.RoomBlockStatus__c
                                                        FROM BookingPackageEvents__r 
                                                        WHERE BookingEvent__c IN: eventIds)

                                                    FROM Booking__c
                                                    WHERE Id IN: bookingIds]);

            /**
            Reinstantiating this.PackageEvents here in-case booking.BookingPackageEvents__r is empty. 
            If it IS empty when we do the putAll inside the loop, the old contents 
            of booking.BookingPackageEvents__r remain intact and that causes problems.
            */
            this.PackageEvents  = new Map<Id, BookingPackageEvent__c>();
            for(Booking__c booking : this.Bookings.values()){
                this.PackageEvents.putAll(booking.BookingPackageEvents__r);
            }
            buildOutLocationSpecificData(locationIds, eventClassificationIds);


        }

       public void buildOutLocationSpecificData(Set<Id> properties, Set<Id> eventClassifications){
            
            if(properties.isEmpty())
                return;

            if(this.Locations.isEmpty() || !this.Locations.keySet().containsAll(properties)){

                this.FunctionRooms = new Map<Id, FunctionRoom__c>( 
                    [SELECT 
                        CurrencyIsoCode, Name, Id, 
                        Location__c, Location__r.UnassignedFunctionRoom__c,
                        Location__r.ConflictCheckProspects__c,
                        DefaultSetupDuration__c, DefaultTeardownDuration__c, 
                        DefaultRentalRate__c, DefaultMinCapacity__c, DefaultMaxCapacity__c,
                        FunctionRoomSetupName__c, CombinationType__c, IsInclusive__c,
                        IsCombinationRoom__c, IsActive__c, AllowMultiGroupBlocking__c                     
                     FROM FunctionRoom__C 
                     WHERE location__C in : properties]                          
                     );

                //This cannot be a subquery of Location because we may have Corporate Event Classifications  
                this.EventClassifications = new map<Id, EventClassification__c>  (
                    [SELECT  
                        DefaultTaxGroup__c,Location__r.DefaultTaxGroup__c,
                        DefaultStartTime24Hour__c, 
                        DefaultStartTime12Hour__c, 
                        DefaultSetup__c, 
                        DefaultSetup__r.Name,
                        DefaultEndTime24Hour__c, 
                        DefaultEndTime12Hour__c, 
                        DefaultAverageCheckFactor9__c, DefaultAverageCheckFactor8__c, 
                        DefaultAverageCheckFactor7__c, DefaultAverageCheckFactor6__c, 
                        DefaultAverageCheckFactor5__c, DefaultAverageCheckFactor4__c, 
                        DefaultAverageCheckFactor3__c, DefaultAverageCheckFactor2__c, 
                        DefaultAverageCheckFactor1__c, DefaultAverageCheckFactor15__c, 
                        DefaultAverageCheckFactor14__c, DefaultAverageCheckFactor13__c, 
                        DefaultAverageCheckFactor12__c, DefaultAverageCheckFactor11__c, 
                        DefaultAverageCheckFactor10__c, DefaultAverageCheck9__c, 
                        DefaultAverageCheck8__c, DefaultAverageCheck7__c, 
                        DefaultAverageCheck6__c, DefaultAverageCheck5__c, 
                        DefaultAverageCheck4__c, DefaultAverageCheck3__c, 
                        DefaultAverageCheck2__c, DefaultAverageCheck1__c, 
                        DefaultAverageCheck15__c, DefaultAverageCheck14__c, 
                        DefaultAverageCheck13__c, DefaultAverageCheck12__c, 
                        DefaultAverageCheck11__c, DefaultAverageCheck10__c,
                        Id, Name, DefaultIsPosted__c
                    FROM EventClassification__c
                    WHERE ID IN : eventClassifications]
                );
                
                this.Locations = new Map<Id, Location__c>(
                    [SELECT Id, DefaultTaxGroup__c, IsRemoveCancelledEventsFromBEOs__c, UpdateBookingEventAverageChecks__c,
                        (SELECT 
                            Id, Name, AppliesTo__c, IsCompound__c, FlatRate__c, Rate__c, 
                            Location__c, SortOrder__c 
                        FROM FunctionRoomTaxes__r),
                    /*
                        (SELECT 
                            ComboFunctionRoom__c, ComboFunctionRoom__r.Location__c, 
                            ComboFunctionRoom__r.Name, ComponentFunctionRoom__c, 
                            ComponentFunctionRoom__r.Name, Id, Name  
                        FROM Combo_Room_Components__r),
                    */
                        (SELECT
                            InclusiveRates__c, Id, Name
                        FROM TaxGroups__r)
                                                                    
                    FROM Location__c
                    WHERE Id IN: properties]
                );
                
                for(Location__c prop : this.Locations.values()){
                    this.FunctionRoomTaxes.putAll(new Map<Id, FunctionRoomTax__c>(prop.FunctionRoomTaxes__r));
                   // this.ComboRoomComponents.putAll(new Map<Id, ComboRoomComponent__c>(prop.Combo_Room_Components__r));
                    this.TaxGroups.putAll(new Map<Id, TaxGroup__c>(prop.TaxGroups__r));
                }
            }
        } 
    }

    public class CreateBookingEventDataStore implements Triggers.Handler {
        public void handle() {
            
            if(Test.isRunningTest())
                queriedInfo = new BookingEventDataStore();
            queriedInfo.buildOutEventSpecificData((List<BookingEvent__c>)(Trigger.isDelete ? Trigger.Old : Trigger.New));

            
            queriedInfo.eventIdToPackageEvents = new map<Id,list<BookingPackageEvent__c>>();
            
            for(BookingPackageEvent__c bpe : queriedInfo.PackageEvents.Values() )
            {
                if(queriedInfo.eventIdToPackageEvents.get(bpe.BookingEvent__c) == null)
                {
                    queriedInfo.eventIdToPackageEvents.put(bpe.BookingEvent__c,new list<BookingPackageEvent__c>());
                }
                queriedInfo.eventIdToPackageEvents.get(bpe.BookingEvent__c).add(bpe);
            }
            
        }
    }
    
    public class FollowBookingStatusOwner  implements Triggers.Handler {// combined with FunctionPriority trigger
        public void handle() {
            
             Triggers.TriggerParameters.put('isEventModification', 'true'); //MDC 215658 - JUL 2017
            
            if (!Triggers.getBoolParam('FollowBookingStatusOwner', true)) { 
                return;
            }
            
            List<BookingEvent__c> bookingEvents = (List<BookingEvent__c>)Trigger.New;
            Map<Id, BookingEvent__c> oldBookingEvents;
            if(Trigger.isUpdate)
                oldBookingEvents = (Map<Id, BookingEvent__c>)Trigger.oldMap;
           // List<Id> bookingIds = new List<Id>();
            Set<Id> bookingIds = new set<Id>();
            Set<Id> setupIds = new Set<Id>();
            

            for(BookingEvent__c be : bookingEvents) {
                if(!bookingIds.contains(be.Booking__c) &&  be.Booking__c != null )
                    bookingIds.add(be.Booking__c);
            }
                
            map<Id, Booking__c> bookingsMap = queriedInfo.Bookings;
            
            String bookingStatus;
            for(BookingEvent__c be : bookingEvents) {                
                if (be.Booking__c != null) {
                    bookingStatus = bookingsMap.get(be.Booking__c).BookingStatus__c;
                    if(bookingStatus != be.EventStatus__c){
                        //if the booking is Terminal Status, then all bookingEvents will also be. Cannot have a terminal booking with live Events. 
                        if(bookingStatus == 'TurnedDown' || bookingStatus == 'Lost'){
                                be.EventStatus__c = bookingStatus;
                        }
                        //if isStatusLocked is unchecked, then follow the Booking
                        if( bookingStatus == 'Cancelled'){
                            be.EventStatus__c = 'Booking Cancelled';
                        }
                        else if (!be.IsStatusLocked__c && (bookingStatus == 'Prospect' || bookingStatus == 'Tentative' || bookingStatus == 'Definite' || bookingStatus == 'TurnedDown'
                                        || bookingStatus == 'Lost' || bookingStatus == 'Cancelled')) { 
                                if(bookingStatus == 'Cancelled')
                                    be.EventStatus__c = 'Booking Cancelled';
                                else{
                                    be.EventStatus__c = bookingStatus;
                                }
                        }
                    }
                    if(Trigger.isInsert || (Trigger.isUpdate && be.EventStatus__c != oldBookingEvents.get(be.Id).EventStatus__c)){
                        be.StatusModifiedDate__c = Date.today();
                        //add Booking To Context Store
                        BookingCls.addToBookingContext(be.Booking__c, 'Event');
                    }
                } 
                else {  
                    BookingEvent__c oldBookingEvent;
                    if(Trigger.isUpdate){
                        oldBookingEvent = oldBookingEvents.get(be.Id);
                    }else{
                        oldBookingEvent = new BookingEvent__c();
                    }
                    if(be.EventStatus__c == 'Definite' && oldBookingEvent.EventStatus__c != be.EventStatus__c){
                        be.addError(Label.BookingEventStatus);
                    }
                }
            }   
        }
    }
    
    public static boolean executeSetupTeardownTimes = true;
    public class SetupTeardownTimes implements Triggers.Handler {// combined with FunctionPriority trigger
        public void handle() {
        
            if (!executeSetupTeardownTimes) return;
        
            Set<Id> functionRoomIds = new Set<Id>();
            Set<Id> propertyIds = new Set<Id>();   //cut down on data volume a lot
            
            Set<String> functionRoomSetupNames = new Set<String>();
            Set<Id> bookingEventForUpdateIds = new Set<Id>();
            
            
           for(BookingEvent__c be:(List<BookingEvent__c>)Trigger.New){  
                //JC 7/16- Changed FunctionRoomSetup to check the picklist instead of the lookup            
                if(Trigger.isInsert || (be.FunctionRoom__c != ((BookingEvent__c)Trigger.oldMap.get(be.Id)).FunctionRoom__c 
                        || be.FunctionRoomSetupName__c != ((BookingEvent__c)Trigger.oldMap.get(be.Id)).FunctionRoomSetupName__c))
                {
                    if(be.FunctionRoom__c != null)
                        functionRoomIds.add(be.FunctionRoom__c);
                    
                    if(be.location__c != null) propertyIds.add(be.location__c);
                        
                    if(be.FunctionRoomSetupName__c != null)
                        functionRoomSetupNames.add(be.FunctionRoomSetupName__c);
                        
                    bookingEventForUpdateIds.add(be.Id);
                }
            }
            
            system.debug(loggingLevel.info,  ' functionRoomSetupNames=  ' + functionRoomSetupNames);
            
            map<id, Map<String, FunctionRoomSetup__c>> roomSetups = new  map<id, Map<String, FunctionRoomSetup__c>>();  //each room maps to a collection of setups           
            if(!functionRoomSetupNames.isEmpty()){
              system.debug(loggingLevel.info,  ' inside IF above query with propertyIds = ' +  propertyIds);

            /**
            We're taking the FunctionRoomsSetup collection out of the BookingEventsDataStore object 
            and putting the SOQL query here because the collection in the datastore used excessive
            heap space and was alive for as long as the the trigger was in-memory. This technique 
            uses the lower-cost in-line for loop query, and all memory used by the method is released 
            when the method exits.  In taking this approach, we had to increase the SOQL count because the 
            FunctionRoomsSetup collection is required in two places in the trigger. But increasing the SOQL 
            count by one is preferrable to the alternative which was runtime heap errors.
            */
               
                for(FunctionRoomSetup__c frs : [SELECT  
                         SetupDuration__c, TeardownDuration__c, Name, Id,
                         FunctionRoomSetupName__c, MinCapacity__c,
                         MaxCapacity__c, FunctionRoom__c, FunctionRoom__r.Location__c,
                         FunctionRoom__r.Name
                     FROM FunctionRoomSetup__c 
                     WHERE FunctionRoom__c in : functionRoomIds ]){ 

                    if(!functionRoomSetupNames.contains(frs.FunctionRoomSetupName__c))
                        continue;

                    
                    system.debug(loggingLevel.info,  ' found frs =  ' + frs );            
                    if (roomSetups.containsKey(frs.FunctionRoom__c)) {
                        roomSetups.get(frs.FunctionRoom__c).put(frs.FunctionRoomSetupName__c, frs); 
                    }
                    else
                    {
                        Map<String, FunctionRoomSetup__c> setups = new Map<String, FunctionRoomSetup__c> {frs.FunctionRoomSetupName__c => frs } ;   
                        system.debug(loggingLevel.info,  ' mapping setups =  ' +  setups );                       
                        roomSetups.put(frs.FunctionRoom__c, setups);
                        system.debug(loggingLevel.info,  ' roomSetups in loop =  ' +  roomSetups );     
                    }
                    
                }
            }
            
            system.debug(loggingLevel.info,  ' roomSetups =  ' +  roomSetups );            
            
            Map<Id, FunctionRoom__c> functionRooms;
            if(!functionRoomIds.isEmpty())
                functionRooms = queriedInfo.FunctionRooms;
                
            //Get tax information from the tax group and deserialize. If a tax info is found for FunctionRoom, the tax is applicable
            map<Id, string> taxGroupIdToJSON = new map<Id, string>();
            for(TaxGroup__c tg : queriedInfo.TaxGroups.values()){
                taxGroupIdToJSON.put(tg.Id, tg.InclusiveRates__c);
            }
            QueryTaxGroupSchedule tgs = new QueryTaxGroupSchedule(taxGroupIdToJSON);
            
            Security.checkAreFieldsAccessible('RevenueClassification__c', new List<String>{'Id', 'IsFunctionRoomRevenue__c', 'DefaultGratuity__c', 'DefaultAdminCharge__c', 'GratuityIsIncludedInInclusivePrice__c', 'AdminIsIncludedInInclusivePrice__c', 'ApplyChargesToDiscPrice__c'});
            // There is only one record where IsFunctionRoomrevenue__c == true
            List<RevenueClassification__c> funcRoomrentalRevClassifications = ([Select Id, DefaultGratuity__c, DefaultAdminCharge__c, GratuityIsIncludedInInclusivePrice__c, AdminIsIncludedInInclusivePrice__c, ApplyChargesToDiscPrice__c from RevenueClassification__c where IsFunctionRoomRevenue__c =: true LIMIT 1]);
            
            system.debug(logginglevel.info, 'propertyIds= ' + propertyIds);
            CustomRevenueClass.init(propertyIds, !bookingEventForUpdateIds.IsEmpty());
             
            for(BookingEvent__c be:(list<BookingEvent__c>)Trigger.New){
                if(bookingEventForUpdateIds.contains(be.Id)){

                    system.debug(logginglevel.info, 'bookingEvent= ' + be);
                    system.debug(logginglevel.info, 'funcRoomrentalRevClassifications= ' + funcRoomrentalRevClassifications);

                    decimal base = 1;
                    decimal admin = 0;
                    decimal grat = 0;
                    if (!funcRoomrentalRevClassifications.isEmpty())  // Use property default grat & admincharge
                    {
                        decimal propertyCustomAdminCharge = CustomRevenueClass.getAdminCharge(be.Location__c, funcRoomrentalRevClassifications[0].Id);
                        decimal propertyCustomGratuity = CustomRevenueClass.getGratuity(be.Location__c, funcRoomrentalRevClassifications[0].Id);
                        
                        boolean adminIsIncluded = be.FunctionRoomRentalAdminCharge__c != null ? be.AdminIsIncludedInInclusivePrice__c : (propertyCustomAdminCharge != null ? (funcRoomrentalRevClassifications[0]).AdminIsIncludedInInclusivePrice__c : false);
                        boolean gratIsIncluded = be.FunctionRoomRentalGratuity__c != null ? be.GratuityIsIncludedInInclusivePrice__c : (propertyCustomGratuity != null ? (funcRoomrentalRevClassifications[0]).GratuityIsIncludedInInclusivePrice__c : false);
                        
                        // For calculations
                        admin = adminIsIncluded ? (be.FunctionRoomRentalAdminCharge__c != null ? be.FunctionRoomRentalAdminCharge__c : propertyCustomAdminCharge != null ? propertyCustomAdminCharge : 0)/100 : 0;
                        grat = gratIsIncluded ? (be.FunctionRoomRentalGratuity__c != null ? be.FunctionRoomRentalGratuity__c : propertyCustomGratuity != null ? propertyCustomGratuity : 0)/100 : 0;                        
                      
                        // For updating bookingEvent's admin & grat values regardless of adminIsIncluded/gratIsIncluded flag
                        decimal adminValForNewEvent = (be.FunctionRoomRentalAdminCharge__c != null ? be.FunctionRoomRentalAdminCharge__c : propertyCustomAdminCharge != null ? propertyCustomAdminCharge : 0)/100;
                        decimal gratValForNewEvent =  (be.FunctionRoomRentalGratuity__c != null ? be.FunctionRoomRentalGratuity__c : propertyCustomGratuity != null ? propertyCustomGratuity : 0)/100;                        
                        
                        
                        system.debug(logginglevel.info, 'adminValForNewEvent= ' + adminValForNewEvent);
                        system.debug(logginglevel.info, 'gratValForNewEvent= ' + gratValForNewEvent);
                        
                        system.debug(logginglevel.info, 'admin= ' + admin);
                        system.debug(logginglevel.info, 'grat= ' + grat);

                        if (be.FunctionRoomRentalAdminCharge__c == null) {
                            be.FunctionRoomRentalAdminCharge__c = adminValForNewEvent * 100;
                            be.AdminIsIncludedInInclusivePrice__c = adminIsIncluded;
                        }
                        if (be.FunctionRoomRentalGratuity__c == null) {
                            be.FunctionRoomRentalGratuity__c = gratValForNewEvent * 100;
                            be.GratuityIsIncludedInInclusivePrice__c = gratIsIncluded;
                        }                        
                        
                    }
                    else
                    {
                        admin = be.AdminIsIncludedInInclusivePrice__c ? (be.FunctionRoomRentalAdminCharge__c != null ? be.FunctionRoomRentalAdminCharge__c : 0)/100 : 0;
                        grat = be.GratuityIsIncludedInInclusivePrice__c ? (be.FunctionRoomRentalGratuity__c != null ? be.FunctionRoomRentalGratuity__c : 0)/100 : 0;
                    }
                    
                    if(be.TaxGroup__c != null){
                        if(be.FunctionRoom__c != null && functionRooms.get(be.FunctionRoom__c).IsInclusive__c){
                            base = tgs.GetInclusiveBaseRate(be.TaxGroup__c, 'FunctionRoom');
                            admin *= tgs.GetInclusiveAdminRate(be.TaxGroup__c, 'FunctionRoom');
                            grat *= tgs.GetInclusiveGratuityRate(be.TaxGroup__c, 'FunctionRoom');
                        }
                    }
                    
                    if(be.FunctionRoom__c != null){
                        //J.C 7/8: added Setup/Teardown check to see if its zero so that the values default correctly when creating an event from the 
                        //function diary. 
                         
                        if(!Trigger.isInsert || (Trigger.isInsert && (be.SetupDuration__c == null || be.SetupDuration__c == 0)))
                            be.SetupDuration__c = functionRooms.get(be.FunctionRoom__c).DefaultSetupDuration__c;
                        if(!Trigger.isInsert || (Trigger.isInsert && (be.TeardownDuration__c == null || be.TeardownDuration__c == 0)))
                            be.TeardownDuration__c = functionRooms.get(be.FunctionRoom__c).DefaultTeardownDuration__c;
                        //only default the rental from functionroom if the rental is currently null or back out admin/grat/taxes if the rate is the same as the default rate.
                        if(be.FunctionRoomRental__c == null){
                            //If the function room is set as inclusive, back out Admin/Grat/Taxes
                            if(functionRooms.get(be.FunctionRoom__c).DefaultRentalRate__c != null){
                                if(functionRooms.get(be.FunctionRoom__c).IsInclusive__c)
                                    be.FunctionRoomRental__c = Ni.getConvertedValue(functionRooms.get(be.FunctionRoom__c).CurrencyIsoCode, be.CurrencyIsoCode, functionRooms.get(be.FunctionRoom__c).DefaultRentalRate__c) / (base + admin + grat);
                                else
                                    be.FunctionRoomRental__c = Ni.getConvertedValue(functionRooms.get(be.FunctionRoom__c).CurrencyIsoCode, be.CurrencyIsoCode, functionRooms.get(be.FunctionRoom__c).DefaultRentalRate__c); 
                            
                            system.debug(logginglevel.info, 'be.FunctionRoomRental__c= ' + be.FunctionRoomRental__c);
                            }
                        }
                    }
                    
                   //get the setups for the specific functionroom
                   if (roomSetups.containsKey(be.FunctionRoom__c)) {
                       Map<String, FunctionRoomSetup__c> setupForRoom = roomSetups.get(be.FunctionRoom__c);
                       FunctionRoomSetup__c frs = setupForRoom.get(be.FunctionRoomSetupName__c);
                        if(frs != null && frs.FunctionRoom__c == be.FunctionRoom__c){
                            if (frs.SetupDuration__c != null)
                                be.SetupDuration__c = frs.SetupDuration__c;
                            if (frs.TeardownDuration__c != null)
                                be.TeardownDuration__c = frs.TeardownDuration__c;
                        }
                    }
                }
                
                if(be.StartDateTime__c != null){
                    be.BlockStartDateTime__c = be.StartDateTime__c;
                    if(be.SetupDuration__c != null){
                        be.BlockStartDateTime__c = be.BlockStartDateTime__c.addMinutes(-Integer.valueOf(be.SetupDuration__c));
                    }
                    if(be.PreEventHoldDuration__c != null){
                        be.BlockStartDateTime__c = be.BlockStartDateTime__c.addMinutes(-Integer.valueOf(be.PreEventHoldDuration__c));
                    }
                }
                if(be.EndDateTime__c != null){
                    be.BlockEndDateTime__c = be.EndDateTime__c;
                    if(be.TeardownDuration__c != null)
                        be.BlockEndDateTime__c = be.BlockEndDateTime__c.addMinutes(Integer.valueOf(be.TeardownDuration__c));
                    if(be.PostEventHoldDuration__c != null)
                        be.BlockEndDateTime__c = be.BlockEndDateTime__c.addMinutes(Integer.valueOf(be.PostEventHoldDuration__c));
                }
            }
        }
    }
    
    /*
        BookingEventDates - Sets the date of the Booking Arrival and Departure if the BookingEvent is outside those dates. 
 
    */
    
    public static boolean firstPass_shiftDates = true;
    public class BookingEventDates implements Triggers.Handler { 
        public void handle(){
            if(firstPass_shiftDates){
                firstPass_shiftDates = false; 
                
                Set<Id> bookingIds = new Set<Id>();
                List<Date> maxDates = new List<Date>();
                
                for (BookingEvent__c be : (List<BookingEvent__c>)(Trigger.isDelete ? Trigger.Old : Trigger.New)) {                    
                    bookingIds.add(be.Booking__c);
                }   
                
                if(bookingIds != null && bookingIds.size() != 0){
                    maxBookingEvents(bookingIds);
                }           
            }
        }
    } 
    
    /* 
        This method will calculate the max Booking Event start and end dates based on a booking Ids
        and set the Booking Arrival and Departure dates equal to the largest event. 
        
    */
    
    public static void maxBookingEvents(Set<Id> bookingIds){
        
        Boolean updateBooking = false;
        //query for booking related to event. 
        Map<Id,Booking__c> eventsBooking = queriedInfo.Bookings;
                                        
        for (BookingEvent__c be : (List<BookingEvent__c>)(Trigger.isDelete ? Trigger.Old : Trigger.New)) {                    
            
            if(be.StartDate__c < eventsBooking.get(be.Booking__c).ArrivalDate__c){
                // Fix for defect 55034
                if(be.StartDate__c.daysBetween(eventsBooking.get(be.Booking__c).DepartureDate__c) > 365){
                    be.addError(Label.BookingLengthOverYear);
                    break;
                }

                BookingCls.addToBookingContext(be.Booking__c, be.StartDate__c, null, 'Event');

                
            } 
                
            if(be.EndDate__c > eventsBooking.get(be.Booking__c).DepartureDate__c){
                // Fix for defect 55034
                if(eventsBooking.get(be.Booking__c).ArrivalDate__c.daysBetween(be.EndDate__c) > 365){
                    be.addError(Label.BookingLengthOverYear);
                    break;
                }
                BookingCls.addToBookingContext(be.Booking__c, null, be.EndDate__c, 'Event');

            }
            
            
        }
    }
    
   
    /*
        DefaultEventItems - Trigger creates EventItems from associate EventClassificationItems
                            B-01811 
                            after insert, after update
    */
    public static boolean firstPass_DefaultEventItems = true;
    public class DefaultEventItems implements Triggers.Handler 
    { 
        public void handle() 
        {
                if (firstPass_DefaultEventItems) //check for recursion
                {
                    firstPass_DefaultEventItems = false;
                    
                    map<Id,BookingEvent__c> newBookingEvents = (map<Id,BookingEvent__c>)trigger.newMap;
                    map<Id,BookingEvent__c> oldBookingEvents = (map<Id,BookingEvent__c>)trigger.oldMap;
                    
                    map<Id,list<BookingEvent__c>> eventClassificationId_BookingEvents = new map<Id,list<BookingEvent__c>>();
                    map<Id,list<EventClassificationItem__c>> eventClassificationId_EventClassificationItems = new map<Id,list<EventClassificationItem__c>>();
                    
                    map<Id, string> taxGroupIdToJSON = new map<Id, string>();
                    for(TaxGroup__c tg : queriedInfo.TaxGroups.values()){
                        taxGroupIdToJSON.put(tg.Id, tg.InclusiveRates__c);
                    }
                    QueryTaxGroupSchedule tgs = new QueryTaxGroupSchedule(taxGroupIdToJSON);
                    map<Id, Id> bookingEventToTaxGroup = new map<Id, Id>();
                   
                    system.debug(logginglevel.info,'In DefaultEventItems');
                    Set<Id> propertyIds = new Set<Id>();
                    
                    for (BookingEvent__c be : (list<BookingEvent__c>)(trigger.New))
                    {
                        bookingEventToTaxGroup.put(be.Id, be.TaxGroup__c);
                        
                        //Default EventItems from EventClassificationItems if a BookingEvent is inserted 
                        //or an EventClassification is associated to a BookingEvent with no EventClassification and no EventItems.           
                        if(be.EventClassification__c != null && (trigger.isInsert || ( be.TotalEventItems__c == 0 && oldBookingEvents.get(be.Id).EventClassification__c == null)))
                        {
                            if(eventClassificationId_BookingEvents.get(be.EventClassification__c) == null)
                            {
                                eventClassificationId_BookingEvents.put(be.EventClassification__c,new list<BookingEvent__c>());
                            }
                            eventClassificationId_BookingEvents.get(be.EventClassification__c).add(be);
                        }
                        
                        propertyIds.add(be.location__c);
                        system.debug(logginglevel.info,'Looping thru bookingEvents and retrieving list of propertyIds');  
                    }
                    
                    //If we have any EventClassifications which are associated to BookingEvents that need default EventItems, get the EventClassificationItems.
                    if(!eventClassificationId_BookingEvents.isEmpty())
                    {
                        for(EventClassificationItem__c eci : [
                            SELECT EventClassification__c, Item__c, Item__r.Name, Item__r.Location__c
                                ,Item__r.QuantityCalculation__c, Item__r.ItemType__c ,Item__r.AllowDecimalQuantities__c
                                ,Item__r.Description__c ,Item__r.EstimatedConsumptionPercentage__c 
                                ,Item__r.DoNotPrintOnBeo__c ,Item__r.DoNotPrintOnCheck__c, Item__r.IsInclusive__c
                                ,Item__r.HidePriceOnBeo__c ,Item__r.HideQuantityOnBeo__c ,Item__r.RevenueClassification__c
                                ,Item__r.RichDescription__c ,Item__r.Service_Factor__c ,Item__r.UnitPrice__c
                                ,Item__r.SoldByUnit__c, Item__r.RevenueClassification__r.DefaultGratuity__c
                                ,Item__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c, Item__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c
                                ,Item__r.RevenueClassification__r.DefaultAdminCharge__c
                                ,Item__r.RevenueClassification__r.ApplyChargesToDiscPrice__c
                                ,Item__r.Gratuity__c, Item__r.AdminCharge__c, Item__r.AdminIsIncludedInInclusivePrice__c 
                                ,Item__r.GratuityIsIncludedInInclusivePrice__c
                                ,Item__r.CurrencyIsoCode, Item__r.ServingUnit__c
                                ,Item__r.AlternateNameDE__c
                                ,Item__r.AlternateNameENUS__c
                                ,Item__r.AlternateNameES__c
                                ,Item__r.AlternateNameFR__c
                                ,Item__r.AlternateNameIT__c
                                ,Item__r.AlternateNameNLNL__c
                                ,Item__r.AlternateNamePL__c
                                ,Item__r.AlternateNamePTBR__c
                                ,Item__r.AlternateNamePTPT__c
                                ,Item__r.AlternateNameZHCN__c
                                ,Item__r.AlternateNameZHTW__c
                                ,Item__r.AlternateRichDescriptionDE__c
                                ,Item__r.AlternateRichDescriptionENUS__c
                                ,Item__r.AlternateRichDescriptionES__c
                                ,Item__r.AlternateRichDescriptionFR__c
                                ,Item__r.AlternateRichDescriptionIT__c
                                ,Item__r.AlternateRichDescriptionNLNL__c
                                ,Item__r.AlternateRichDescriptionPL__c
                                ,Item__r.AlternateRichDescriptionPTBR__c
                                ,Item__r.AlternateRichDescriptionPTPT__c
                                ,Item__r.AlternateRichDescriptionZHCN__c
                                ,Item__r.AlternateRichDescriptionZHTW__c
                                ,Item__r.AlternateServingUnitDE__c
                                ,Item__r.AlternateServingUnitENUS__c
                                ,Item__r.AlternateServingUnitES__c
                                ,Item__r.AlternateServingUnitFR__c
                                ,Item__r.AlternateServingUnitIT__c
                                ,Item__r.AlternateServingUnitNLNL__c
                                ,Item__r.AlternateServingUnitPL__c
                                ,Item__r.AlternateServingUnitPTBR__c
                                ,Item__r.AlternateServingUnitPTPT__c
                                ,Item__r.AlternateServingUnitZHCN__c
                                ,Item__r.AlternateServingUnitZHTW__c
                                ,Item__r.AlternateSoldByUnitDE__c
                                ,Item__r.AlternateSoldByUnitENUS__c
                                ,Item__r.AlternateSoldByUnitES__c
                                ,Item__r.AlternateSoldByUnitFR__c
                                ,Item__r.AlternateSoldByUnitIT__c
                                ,Item__r.AlternateSoldByUnitNLNL__c
                                ,Item__r.AlternateSoldByUnitPL__c
                                ,Item__r.AlternateSoldByUnitPTBR__c
                                ,Item__r.AlternateSoldByUnitPTPT__c
                                ,Item__r.AlternateSoldByUnitZHCN__c
                                ,Item__r.AlternateSoldByUnitZHTW__c
                            FROM EventClassificationItem__c 
                            WHERE EventClassification__c IN : eventClassificationId_BookingEvents.KeySet() AND Item__r.ItemType__c != NULL
                        ])
                        {
                            if(eventClassificationId_EventClassificationItems.get(eci.EventClassification__c) == null)
                            {
                                eventClassificationId_EventClassificationItems.put(eci.EventClassification__c,new list<EventClassificationItem__c>());
                            }
                            eventClassificationId_EventClassificationItems.get(eci.EventClassification__c).add(eci);
                        }
                    }
                    
                    //Create Applicable Booking Taxes on the Function Room (Delphi.Net Parady)
                    if (trigger.isInsert)
                     {
     
                        map<Id,list<FunctionRoomTax__c>> propertyIdToFunctionRoomTaxes = new map<Id,list<FunctionRoomTax__c>>();
                            
                        list<BookingTax__c> bookingTaxesFR = new list<BookingTax__c>();
                            
                        for(FunctionRoomTax__c tax : queriedInfo.FunctionRoomTaxes.values())
                        {
                            if(propertyIdToFunctionRoomTaxes.get(tax.Location__c) == null)
                                propertyIdToFunctionRoomTaxes.put(tax.Location__c,new list<FunctionRoomTax__c>());
                                propertyIdToFunctionRoomTaxes.get(tax.Location__c).add(tax);
                            }
                        for (BookingEvent__c be : (list<BookingEvent__c>)(trigger.New))
                        {
                            if (propertyIdToFunctionRoomTaxes.get(be.Location__c) != null)
                            {
                                for(FunctionRoomTax__c tax : propertyIdToFunctionRoomTaxes.get(be.Location__c) )
                                {
                                    BookingTax__c BT = new BookingTax__c();
                                    BT.Name = tax.Name+'__'+be.Name;
                                    BT.Booking__c = be.Booking__c;
                                    BT.AppliesTo__c = tax.AppliesTo__c;
                                    BT.BookingEvent__c = be.Id;
                                    BT.FlatRate__c = tax.FlatRate__c;
                                    BT.Rate__c = tax.Rate__c;
                                    BT.Location__c = be.Location__c;
                                    BT.SortOrder__c = tax.SortOrder__c;
                                    BT.IsCompound__c = tax.IsCompound__c;
                                    bookingTaxesFR.add(BT);
                                }
                            }
                        }
                        if(bookingTaxesFR.size()>0)
                            insert bookingTaxesFR;
                    }
                    
                    //If we have EventClassificationItems to default.
                    if(!eventClassificationId_EventClassificationItems.isEmpty())
                    {
                        //Create a list of Event Items associated to the event classifications to Insert
                        List<EventItem__c> newEventItems = new List<EventItem__c>();
                        
                        //Create a map of event item its to event items for menus (event items with children)
                        map<Id,EventItem__c> parentEventItemIdToParentEventItem = new map<Id,EventItem__c>();
        
                        //Create a map of record type Ids
                        map<String, Id> EventItemRecordTypeId = new map<String, Id>();
                        try{
                            EventItemRecordTypeId.put('Item', Schema.SObjectType.EventItem__c.getRecordTypeInfosByName().get('Item').getRecordTypeId());
                            EventItemRecordTypeId.put('Simple Menu', Schema.SObjectType.EventItem__c.getRecordTypeInfosByName().get('Simple Menu').getRecordTypeId());
                            EventItemRecordTypeId.put('Detailed Menu', Schema.SObjectType.EventItem__c.getRecordTypeInfosByName().get('Detailed Menu').getRecordTypeId());
                            EventItemRecordTypeId.put('Text', Schema.SObjectType.EventItem__c.getRecordTypeInfosByName().get('Text').getRecordTypeId());
                        }catch(Exception e){}
                        
                        //Create maps of setup item and item breakdown ids to the list of taxable event items and event item revenue breakdowns they are to create
                        map<Id,list<EventItem__c>> itemIdToNewTaxedEventItems = new map<Id,list<EventItem__c>>();
                        map<Id,list<EventItemRevenueBreakdown__c>> itemRevenueBreakdownIdToNewTaxedEventItemRevenueBreakdown = new map<Id,list<EventItemRevenueBreakdown__c>>();
                        
    
                        system.debug(logginglevel.info, 'propertyIds= ' + propertyIds);
                        CustomRevenueClass.init(propertyIds, Trigger.IsInsert);
                        
                        //Loop through all EventClassificationIds which are associated to BookingEvents that need default EventItems.
                        for(Id  eventClassificationId : eventClassificationId_BookingEvents.KeySet())
                        {
                            //Get the EventClassificationItems associated to the EventClassification.
                            list<EventClassificationItem__c> eventClassificationItems = eventClassificationId_EventClassificationItems.get(eventClassificationId);
                            if(eventClassificationItems != null && eventClassificationItems.Size() > 0)
                            {
                                //Loop through all the BookingEvents associated with the EventClassification.
                                for(BookingEvent__c be : eventClassificationId_BookingEvents.get(eventClassificationId))
                                {                               
                                    //Loop through all the EventClassificationItems associated with the EventClassification.CheckUniqueName
                                    for(EventClassificationItem__c eci : eventClassificationItems)
                                    {
                                        // Use booking event's propertyId if the item is corporate (location__c = null)                           
                                        Id location = (eci.item__r.Location__c != null) ? eci.item__r.Location__c : be.location__c;
                                        
                                        decimal propertyCustomAdminCharge = CustomRevenueClass.getAdminCharge(location, eci.item__r.revenueClassification__c);
                                        decimal propertyCustomGratuity = CustomRevenueClass.getGratuity(location, eci.item__r.revenueClassification__c);
                                        boolean propertyCustomApplyChargesToDiscPrice = CustomRevenueClass.getApplyChargesToDiscPrice(location, eci.item__r.revenueClassification__c); 
            
                                        system.debug(logginglevel.info, 'propertyCustomAdminCharge= ' + propertyCustomAdminCharge);
                                        system.debug(logginglevel.info, 'propertyCustomGratuity= ' + propertyCustomGratuity);
                                        system.debug(logginglevel.info, 'propertyCustomApplyChargesToDiscPrice= ' + propertyCustomApplyChargesToDiscPrice);                                    
                                       
                                        // Modified 4 following lines to use propertydefaultgrat & admincharge
                                        boolean adminIsIncluded = eci.Item__r.ItemType__c == 'Item' ? (eci.Item__r.AdminCharge__c != null ? eci.Item__r.AdminIsIncludedInInclusivePrice__c : (propertyCustomAdminCharge != null ? eci.Item__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c : false)) : false;
                                        boolean gratIsIncluded = eci.Item__r.ItemType__c == 'Item' ? (eci.Item__r.Gratuity__c != null ? eci.Item__r.GratuityIsIncludedInInclusivePrice__c : (propertyCustomGratuity != null ? eci.Item__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c : false)) : false;
    
                                        decimal admin = eci.Item__r.ItemType__c == 'Item' ? ( eci.Item__r.AdminCharge__c != null ? eci.Item__r.AdminCharge__c : (propertyCustomAdminCharge != null ? propertyCustomAdminCharge : 0)) : 0;
                                        decimal grat = eci.Item__r.ItemType__c == 'Item' ? ( eci.Item__r.Gratuity__c != null ? eci.Item__r.Gratuity__c : (propertyCustomGratuity != null ? propertyCustomGratuity : 0)) : 0;
                                        boolean applyChargesToDiscPrice = eci.Item__r.ItemType__c == 'Item' ? propertyCustomApplyChargesToDiscPrice : false;
                                        decimal inclRate = 1;
                                        
                                        system.debug(logginglevel.info, 'eci.Item__r.ItemType__c= ' + eci.Item__r.ItemType__c);
                                        
                                        if(be.TaxGroup__c != null){
                                            if(eci.Item__r.IsInclusive__c){ 
                                                inclRate = tgs.GetInclusiveBaseRate(be.TaxGroup__c, eci.Item__r.RevenueClassification__c) + ((adminIsIncluded ? (admin / 100) : 0) * tgs.GetInclusiveAdminRate(be.TaxGroup__c, eci.Item__r.RevenueClassification__c)) + ((gratIsIncluded ? (grat / 100) : 0) * tgs.GetInclusiveGratuityRate(be.TaxGroup__c, eci.Item__r.RevenueClassification__c));
                                            }
                                        }
                                        
                                        //Add the setup item to the map of setup item ids to new event items if the setup id is not there already
                                        //ie: if there was not already and an item using this Id
                                        if (!itemIdToNewTaxedEventItems.containsKey(eci.Item__c))
                                            itemIdToNewTaxedEventItems.put(eci.Item__c,new list<EventItem__c>());
                                        //Create Event Item
                                        //the following fields check to make sure the item field isn't null before assigned to EventItem
                                        EventItem__c newEventItem = new EventItem__c(
                                            Name = eci.Item__r.Name
                                            ,RecordTypeId = EventItemRecordTypeId.get(eci.Item__r.ItemType__c)
                                            ,Event__c = be.Id
                                            ,ItemReference__c = eci.Item__c
                                            ,Location__c = be.Location__c
                                            ,AllowDecimalQuantities__c = (eci.Item__r.AllowDecimalQuantities__c != null ? eci.Item__r.AllowDecimalQuantities__c : null)
                                            ,Booking__c = be.Booking__c
                                            ,Description__c = (eci.Item__r.Description__c != null ? eci.Item__r.Description__c : null)
                                            ,DoNotPrintOnBeo__c =  (eci.Item__r.DoNotPrintOnBeo__c != null ? eci.Item__r.DoNotPrintOnBeo__c : null)
                                            ,DoNotPrintOnCheck__c =  (eci.Item__r.DoNotPrintOnCheck__c != null ? eci.Item__r.DoNotPrintOnCheck__c : null)
                                            ,EstimatedConsumptionPercentage__c =  (eci.Item__r.EstimatedConsumptionPercentage__c != null ? eci.Item__r.EstimatedConsumptionPercentage__c : null)
                                            ,HidePriceOnBeo__c =  (eci.Item__r.HidePriceOnBeo__c != null ? eci.Item__r.HidePriceOnBeo__c : null)
                                            ,HideQuantityOnBeo__c =  (eci.Item__r.HideQuantityOnBeo__c != null ? eci.Item__r.HideQuantityOnBeo__c : null)
                                            ,QuantityCalculation__c =  (eci.Item__r.QuantityCalculation__c != null ? eci.Item__r.QuantityCalculation__c : null)
                                            ,RevenueClassification__c =  (eci.Item__r.RevenueClassification__c != null ? eci.Item__r.RevenueClassification__c : null)
                                            ,RichDescription__c =  (eci.Item__r.RichDescription__c != null ? eci.Item__r.RichDescription__c : null)
                                            ,ServFactor__c =  (eci.Item__r.Service_Factor__c != null ? eci.Item__r.Service_Factor__c : null)
                                            ,UnitPrice__c =  (eci.Item__r.UnitPrice__c != null ? (eci.Item__r.IsInclusive__c ? NI.getConvertedValue(eci.Item__r.CurrencyIsoCode, be.CurrencyIsoCode, eci.Item__r.UnitPrice__c) / (inclRate) : NI.getConvertedValue(eci.Item__r.CurrencyIsoCode, be.CurrencyIsoCode, eci.Item__r.UnitPrice__c)) : null)
                                            ,ServiceStartDate__c = (be.StartDate__c != null ? be.StartDate__c : null)
                                            ,ServiceStartTime12Hour__c = (be.StartTime12Hour__c != null ? be.StartTime12Hour__c : null)
                                            ,ServiceStartTime24Hour__c = (be.StartTime24Hour__c != null ? be.StartTime24Hour__c : null)
                                            ,ServiceEndDate__c = (be.EndDate__c != null ? be.EndDate__c : null)
                                            ,ServiceEndTime12Hour__c = (be.EndTime12Hour__c != null ? be.EndTime12Hour__c : null)
                                            ,ServiceEndTime24Hour__c = (be.EndTime24Hour__c != null ? be.EndTime24Hour__c : null)
                                            ,SoldByUnit__c = (eci.Item__r.SoldByUnit__c != null ? eci.Item__r.SoldByUnit__c : null)
                                            ,Gratuity__c = grat
                                            ,AdminCharge__c = admin
                                            ,GratuityIsIncludedInInclusivePrice__c = gratIsIncluded
                                            ,AdminIsIncludedInInclusivePrice__c = adminIsIncluded
                                            ,ApplyChargesToDiscPrice__c = applyChargesToDiscPrice
                                            ,ServingUnit__c = eci.Item__r.ServingUnit__c
                                            ,AlternateNameDE__c = eci.Item__r.AlternateNameDE__c
                                            ,AlternateRichDescriptionDE__c = eci.Item__r.AlternateRichDescriptionDE__c
                                            ,AlternateServingUnitDE__c = eci.Item__r.AlternateServingUnitDE__c
                                            ,AlternateSoldByUnitDE__c = eci.Item__r.AlternateSoldByUnitDE__c
                                            ,AlternateNameENUS__c = eci.Item__r.AlternateNameENUS__c
                                            ,AlternateRichDescriptionENUS__c = eci.Item__r.AlternateRichDescriptionENUS__c
                                            ,AlternateServingUnitENUS__c = eci.Item__r.AlternateServingUnitENUS__c
                                            ,AlternateSoldByUnitENUS__c = eci.Item__r.AlternateSoldByUnitENUS__c
                                            ,AlternateNameES__c = eci.Item__r.AlternateNameES__c
                                            ,AlternateRichDescriptionES__c = eci.Item__r.AlternateRichDescriptionES__c
                                            ,AlternateServingUnitES__c = eci.Item__r.AlternateServingUnitES__c
                                            ,AlternateSoldByUnitES__c = eci.Item__r.AlternateSoldByUnitES__c
                                            ,AlternateNameFR__c = eci.Item__r.AlternateNameFR__c
                                            ,AlternateRichDescriptionFR__c = eci.Item__r.AlternateRichDescriptionFR__c
                                            ,AlternateServingUnitFR__c = eci.Item__r.AlternateServingUnitFR__c
                                            ,AlternateSoldByUnitFR__c = eci.Item__r.AlternateSoldByUnitFR__c
                                            ,AlternateNameIT__c = eci.Item__r.AlternateNameIT__c
                                            ,AlternateRichDescriptionIT__c = eci.Item__r.AlternateRichDescriptionIT__c
                                            ,AlternateServingUnitIT__c = eci.Item__r.AlternateServingUnitIT__c
                                            ,AlternateSoldByUnitIT__c = eci.Item__r.AlternateSoldByUnitIT__c
                                            ,AlternateNameNLNL__c = eci.Item__r.AlternateNameNLNL__c
                                            ,AlternateRichDescriptionNLNL__c = eci.Item__r.AlternateRichDescriptionNLNL__c
                                            ,AlternateServingUnitNLNL__c = eci.Item__r.AlternateServingUnitNLNL__c
                                            ,AlternateSoldByUnitNLNL__c = eci.Item__r.AlternateSoldByUnitNLNL__c
                                            ,AlternateNamePL__c = eci.Item__r.AlternateNamePL__c
                                            ,AlternateRichDescriptionPL__c = eci.Item__r.AlternateRichDescriptionPL__c
                                            ,AlternateServingUnitPL__c = eci.Item__r.AlternateServingUnitPL__c
                                            ,AlternateSoldByUnitPL__c = eci.Item__r.AlternateSoldByUnitPL__c
                                            ,AlternateNamePTBR__c = eci.Item__r.AlternateNamePTBR__c
                                            ,AlternateRichDescriptionPTBR__c = eci.Item__r.AlternateRichDescriptionPTBR__c
                                            ,AlternateServingUnitPTBR__c = eci.Item__r.AlternateServingUnitPTBR__c
                                            ,AlternateSoldByUnitPTBR__c = eci.Item__r.AlternateSoldByUnitPTBR__c
                                            ,AlternateNamePTPT__c = eci.Item__r.AlternateNamePTPT__c
                                            ,AlternateRichDescriptionPTPT__c = eci.Item__r.AlternateRichDescriptionPTPT__c
                                            ,AlternateServingUnitPTPT__c = eci.Item__r.AlternateServingUnitPTPT__c
                                            ,AlternateSoldByUnitPTPT__c = eci.Item__r.AlternateSoldByUnitPTPT__c
                                            ,AlternateNameZHCN__c = eci.Item__r.AlternateNameZHCN__c
                                            ,AlternateRichDescriptionZHCN__c = eci.Item__r.AlternateRichDescriptionZHCN__c
                                            ,AlternateServingUnitZHCN__c = eci.Item__r.AlternateServingUnitZHCN__c
                                            ,AlternateSoldByUnitZHCN__c = eci.Item__r.AlternateSoldByUnitZHCN__c
                                            ,AlternateNameZHTW__c = eci.Item__r.AlternateNameZHTW__c
                                            ,AlternateRichDescriptionZHTW__c = eci.Item__r.AlternateRichDescriptionZHTW__c
                                            ,AlternateServingUnitZHTW__c = eci.Item__r.AlternateServingUnitZHTW__c
                                            ,AlternateSoldByUnitZHTW__c = eci.Item__r.AlternateSoldByUnitZHTW__c
                                        );
                                        //Add event item to the list of event items to insert 
                                        newEventItems.add(newEventItem);
                                        //Add the event item to the map of setup item to taxable event item it creates
                                        itemIdToNewTaxedEventItems.get(newEventItem.ItemReference__c).add(newEventItem);
                                    }
                                }
                            }
                        }
                        /*  Insert the event items
                            Note this must be inserted here because child event items need parent event item ids
                            We set this EventItem.RollupEvents to false here to stop that trigger from updating Events more times
                            than absolutely necessary. with This boolean set to false events will not be updated, but they will have
                            to be updated when inserting childEvents
                        */
                        EventItemCls.RollupEvents = false; 
                        if(!newEventItems.isEmpty())
                            insert newEventItems;
                        
                        //Next, Insert Revenue Breakdwowns, and menu items assoicated to Items on the Event Classification
                        
                        //Create maps of setup item (menus) ids to list of children setup items
                        map<Id,Id> itemRevenueBreakdownIdToItemId = new map<Id,Id>();
                        map<Id,list<ItemRevenueBreakdown__c>> itemIdToItemRevenueBreakdowns = new map<Id,list<ItemRevenueBreakdown__c>>();
                        map<Id,list<MenuItem__c>> itemIdToMenuItems = new map<Id,list<MenuItem__c>>();
                        map<Id,map<Id,ChoiceGroup__c>> itemIdToChoiceGroupMenuItemIdsToChoiceGroup = new map<Id,map<Id,ChoiceGroup__c>>();
                        map<Id,list<ChoiceGroupItem__c>> choiceGroupIdToChoiceGroupItems = new map<Id,list<ChoiceGroupItem__c>>();
                        map<Id,map<Id,boolean>> parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu = new map<Id,map<Id,boolean>>();
    
                        //Loop through all event Items and create maps of Parent Item to lists of breakdown items, menu items, and choice groups
                        for (EventItem__c oneItem : newEventItems)
                        {
                            itemIdToItemRevenueBreakdowns.put(oneItem.ItemReference__c,new list<ItemRevenueBreakdown__c>());
                            itemIdToMenuItems.put(oneItem.ItemReference__c,new list<MenuItem__c>());
                            itemIdToChoiceGroupMenuItemIdsToChoiceGroup.put(oneItem.ItemReference__c,new map<Id,ChoiceGroup__c>());
                            parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.put(oneItem.ItemReference__c,new map<Id,boolean>());
                            parentEventItemIdToParentEventItem.put(oneItem.Id,oneItem);
                        }
                        
                        //Create list of child event items (on event menus) to be inserted
                        List<EventItemRevenueBreakdown__c> newEventItemRevenueBreakdowns = new List<EventItemRevenueBreakdown__c>();
                        List<EventItem__c> newChildEventItems = new List<EventItem__c>();
                        
                        //Create list of booking taxes to be inserted
                        List<BookingTax__c> newBookingTaxes = new List<BookingTax__c>();
        
                        //Querty for all Revenue Breakdowns associated to parent items
                        for (ItemRevenueBreakdown__c oneRevenueBreakdown : [Select Id,Item__c, Name, Location__c, RevenueClassification__c, UnitPrice__c, RevenueClassification__r.DefaultGratuity__c, RevenueClassification__r.DefaultAdminCharge__c, RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c, RevenueClassification__r.AdminIsIncludedInInclusivePrice__c, RevenueClassification__r.ApplyChargesToDiscPrice__c,
                                                                            IsInclusive__c, Gratuity__c, AdminCharge__c, GratuityIsIncludedInInclusivePrice__c, AdminIsIncludedInInclusivePrice__c, CurrencyIsoCode FROM ItemRevenueBreakdown__c WHERE Item__c IN : itemIdToItemRevenueBreakdowns.KeySet() ])
                        {
                            itemIdToItemRevenueBreakdowns.get(oneRevenueBreakdown.Item__c).add(oneRevenueBreakdown);
                            itemRevenueBreakdownIdToNewTaxedEventItemRevenueBreakdown.put(oneRevenueBreakdown.Id,new list<EventItemRevenueBreakdown__c>());
                        }
        
                        //Query for all menu items (items and choice groups) associated to parent items
                        for(MenuItem__c oneMenuItem : 
                            [Select ParentMenu__c, Id, Name, ChildItem__r.UnitPrice__c
                                ,ChildItem__r.Location__c
                                ,ChildItem__r.ItemType__c
                                ,ChildItem__r.Id
                                ,ChildItem__r.IsActive__c 
                                ,ChildItem__r.IsInclusive__c
                                ,ChildItem__r.AllowDecimalQuantities__c
                                ,ChildItem__r.Description__c
                                ,ChildItem__r.DoNotPrintOnBeo__c
                                ,ChildItem__r.DoNotPrintOnCheck__c
                                ,ChildItem__r.EstimatedConsumptionPercentage__c
                                ,ChildItem__r.HidePriceOnBeo__c
                                ,ChildItem__r.HideQuantityOnBeo__c
                                ,ChildItem__r.QuantityCalculation__c
                                ,ChildItem__r.RevenueClassification__c
                                ,ChildItem__r.RichDescription__c
                                ,ChildItem__r.Service_Factor__c
                                ,ChoiceGroup__r.Id
                                ,ChoiceGroup__r.IsActive__c
                                ,PriceWithMenu__c
                                ,ChildItem__r.SoldByUnit__c
                                ,ChildItem__r.RevenueClassification__r.DefaultGratuity__c
                                ,ChildItem__r.RevenueClassification__r.DefaultAdminCharge__c
                                ,ChildItem__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c
                                ,ChildItem__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c
                                ,ChildItem__r.RevenueClassification__r.ApplyChargesToDiscPrice__c
                                ,ChildItem__r.Gratuity__c
                                ,ChildItem__r.AdminCharge__c
                                ,ChildItem__r.GratuityIsIncludedInInclusivePrice__c
                                ,ChildItem__r.AdminIsIncludedInInclusivePrice__c
                                ,UnitPrice__c
                                ,EstimatedConsumptionPercentage__c
                                ,CurrencyIsoCode
                                ,ChildItem__r.ServingUnit__c
                                ,ChildItem__r.AlternateNameDE__c
                                ,ChildItem__r.AlternateNameENUS__c
                                ,ChildItem__r.AlternateNameES__c
                                ,ChildItem__r.AlternateNameFR__c
                                ,ChildItem__r.AlternateNameIT__c
                                ,ChildItem__r.AlternateNameNLNL__c
                                ,ChildItem__r.AlternateNamePL__c
                                ,ChildItem__r.AlternateNamePTBR__c
                                ,ChildItem__r.AlternateNamePTPT__c
                                ,ChildItem__r.AlternateNameZHCN__c
                                ,ChildItem__r.AlternateNameZHTW__c
                                ,ChildItem__r.AlternateRichDescriptionDE__c
                                ,ChildItem__r.AlternateRichDescriptionENUS__c
                                ,ChildItem__r.AlternateRichDescriptionES__c
                                ,ChildItem__r.AlternateRichDescriptionFR__c
                                ,ChildItem__r.AlternateRichDescriptionIT__c
                                ,ChildItem__r.AlternateRichDescriptionNLNL__c
                                ,ChildItem__r.AlternateRichDescriptionPL__c
                                ,ChildItem__r.AlternateRichDescriptionPTBR__c
                                ,ChildItem__r.AlternateRichDescriptionPTPT__c
                                ,ChildItem__r.AlternateRichDescriptionZHCN__c
                                ,ChildItem__r.AlternateRichDescriptionZHTW__c
                                ,ChildItem__r.AlternateServingUnitDE__c
                                ,ChildItem__r.AlternateServingUnitENUS__c
                                ,ChildItem__r.AlternateServingUnitES__c
                                ,ChildItem__r.AlternateServingUnitFR__c
                                ,ChildItem__r.AlternateServingUnitIT__c
                                ,ChildItem__r.AlternateServingUnitNLNL__c
                                ,ChildItem__r.AlternateServingUnitPL__c
                                ,ChildItem__r.AlternateServingUnitPTBR__c
                                ,ChildItem__r.AlternateServingUnitPTPT__c
                                ,ChildItem__r.AlternateServingUnitZHCN__c
                                ,ChildItem__r.AlternateServingUnitZHTW__c
                                ,ChildItem__r.AlternateSoldByUnitDE__c
                                ,ChildItem__r.AlternateSoldByUnitENUS__c
                                ,ChildItem__r.AlternateSoldByUnitES__c
                                ,ChildItem__r.AlternateSoldByUnitFR__c
                                ,ChildItem__r.AlternateSoldByUnitIT__c
                                ,ChildItem__r.AlternateSoldByUnitNLNL__c
                                ,ChildItem__r.AlternateSoldByUnitPL__c
                                ,ChildItem__r.AlternateSoldByUnitPTBR__c
                                ,ChildItem__r.AlternateSoldByUnitPTPT__c
                                ,ChildItem__r.AlternateSoldByUnitZHCN__c
                                ,ChildItem__r.AlternateSoldByUnitZHTW__c
                            FROM MenuItem__c WHERE ParentMenu__c IN : itemIdToMenuItems.KeySet()])
                        {
                            if(oneMenuItem.ChildItem__r != NULL && oneMenuItem.ChildItem__r.IsActive__c == true)
                                itemIdToMenuItems.get(oneMenuItem.ParentMenu__c).add(oneMenuItem);
                            else if (oneMenuItem.ChoiceGroup__r != NULL && oneMenuItem.ChoiceGroup__r.IsActive__c == true)
                            {
                                itemIdToChoiceGroupMenuItemIdsToChoiceGroup.get(oneMenuItem.ParentMenu__c).put(oneMenuItem.Id,oneMenuItem.ChoiceGroup__r);
                                choiceGroupIdToChoiceGroupItems.put(oneMenuItem.ChoiceGroup__r.Id,new list<ChoiceGroupItem__c>());
                                parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneMenuItem.ParentMenu__c).put(oneMenuItem.Id,oneMenuItem.PriceWithMenu__c);
                            }
                        }
        
                        //Query for all choice group items associated to the choice groups we just gathered
                        for (ChoiceGroupItem__c oneChoiceGroupItem : 
                            [SELECT Id, ChoiceGroup__r.Id
                                ,Item__r.Name
                                ,Item__r.Location__c
                                ,Item__r.ItemType__c
                                ,Item__r.Id
                                ,Item__r.IsInclusive__c
                                ,Item__r.AllowDecimalQuantities__c
                                ,Item__r.Description__c
                                ,Item__r.DoNotPrintOnBeo__c
                                ,Item__r.DoNotPrintOnCheck__c
                                ,Item__r.EstimatedConsumptionPercentage__c
                                ,Item__r.HidePriceOnBeo__c
                                ,Item__r.HideQuantityOnBeo__c
                                ,Item__r.QuantityCalculation__c
                                ,Item__r.RevenueClassification__c
                                ,Item__r.RichDescription__c
                                ,Item__r.Service_Factor__c
                                ,UnitPrice__c
                                ,Item__r.UnitPrice__c
                                ,Item__r.SoldByUnit__c
                                ,Item__r.RevenueClassification__r.DefaultGratuity__c
                                ,Item__r.RevenueClassification__r.DefaultAdminCharge__c
                                ,Item__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c
                                ,Item__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c
                                ,Item__r.RevenueClassification__r.ApplyChargesToDiscPrice__c
                                ,Item__r.Gratuity__c
                                ,Item__r.AdminCharge__c
                                ,Item__r.GratuityIsIncludedInInclusivePrice__c
                                ,Item__r.AdminIsIncludedInInclusivePrice__c
                                ,CurrencyIsoCode 
                                ,Item__r.ServingUnit__c
                                ,Item__r.AlternateNameDE__c
                                ,Item__r.AlternateNameENUS__c
                                ,Item__r.AlternateNameES__c
                                ,Item__r.AlternateNameFR__c
                                ,Item__r.AlternateNameIT__c
                                ,Item__r.AlternateNameNLNL__c
                                ,Item__r.AlternateNamePL__c
                                ,Item__r.AlternateNamePTBR__c
                                ,Item__r.AlternateNamePTPT__c
                                ,Item__r.AlternateNameZHCN__c
                                ,Item__r.AlternateNameZHTW__c
                                ,Item__r.AlternateRichDescriptionDE__c
                                ,Item__r.AlternateRichDescriptionENUS__c
                                ,Item__r.AlternateRichDescriptionES__c
                                ,Item__r.AlternateRichDescriptionFR__c
                                ,Item__r.AlternateRichDescriptionIT__c
                                ,Item__r.AlternateRichDescriptionNLNL__c
                                ,Item__r.AlternateRichDescriptionPL__c
                                ,Item__r.AlternateRichDescriptionPTBR__c
                                ,Item__r.AlternateRichDescriptionPTPT__c
                                ,Item__r.AlternateRichDescriptionZHCN__c
                                ,Item__r.AlternateRichDescriptionZHTW__c
                                ,Item__r.AlternateServingUnitDE__c
                                ,Item__r.AlternateServingUnitENUS__c
                                ,Item__r.AlternateServingUnitES__c
                                ,Item__r.AlternateServingUnitFR__c
                                ,Item__r.AlternateServingUnitIT__c
                                ,Item__r.AlternateServingUnitNLNL__c
                                ,Item__r.AlternateServingUnitPL__c
                                ,Item__r.AlternateServingUnitPTBR__c
                                ,Item__r.AlternateServingUnitPTPT__c
                                ,Item__r.AlternateServingUnitZHCN__c
                                ,Item__r.AlternateServingUnitZHTW__c
                                ,Item__r.AlternateSoldByUnitDE__c
                                ,Item__r.AlternateSoldByUnitENUS__c
                                ,Item__r.AlternateSoldByUnitES__c
                                ,Item__r.AlternateSoldByUnitFR__c
                                ,Item__r.AlternateSoldByUnitIT__c
                                ,Item__r.AlternateSoldByUnitNLNL__c
                                ,Item__r.AlternateSoldByUnitPL__c
                                ,Item__r.AlternateSoldByUnitPTBR__c
                                ,Item__r.AlternateSoldByUnitPTPT__c
                                ,Item__r.AlternateSoldByUnitZHCN__c
                                ,Item__r.AlternateSoldByUnitZHTW__c
                            FROM ChoiceGroupItem__c WHERE ChoiceGroup__c IN : choiceGroupIdToChoiceGroupItems.KeySet() AND IsDefault__c = true])
                        {
                            choiceGroupIdToChoiceGroupItems.get(oneChoiceGroupItem.ChoiceGroup__r.Id).add(oneChoiceGroupItem);
                        }
                        
                        //Once again loop through all inserted items in order to create the necessary children
                        for (EventItem__c oneEventItem : newEventItems)
                        {
                            system.debug(logginglevel.info, 'On line 1145');
                            //Create the children revenue breakdowns
                            for (ItemRevenueBreakdown__c oneItemRevenueBreakdown : itemIdToItemRevenueBreakdowns.get(oneEventItem.ItemReference__c))
                            {
                                system.debug(logginglevel.info, 'On line 1128, oneItemRevenueBreakdown= ' + oneItemRevenueBreakdown);
                                
                                // oneEventItem.location__c should never be blank since it originates from be.Location__c when filling in newEventItems above        
                                Id location = (oneItemRevenueBreakdown.Location__c != null) ? oneItemRevenueBreakdown.Location__c : oneEventItem.location__c;
                               
                                decimal propertyCustomAdminCharge = CustomRevenueClass.getAdminCharge(location, oneItemRevenueBreakdown.revenueClassification__c);
                                decimal propertyCustomGratuity = CustomRevenueClass.getGratuity(location, oneItemRevenueBreakdown.revenueClassification__c);
                                boolean propertyCustomApplyChargesToDiscPrice = CustomRevenueClass.getApplyChargesToDiscPrice(location, oneItemRevenueBreakdown.revenueClassification__c); 
                                       
                                system.debug(logginglevel.info, 'processing revenueBreakdownItems -- propertyCustomAdminCharge= ' + propertyCustomAdminCharge);
                                system.debug(logginglevel.info, 'processing revenueBreakdownItems -- propertyCustomGratuity= ' + propertyCustomGratuity);
                                system.debug(logginglevel.info, 'processing revenueBreakdownItems -- propertyCustomApplyChargesToDiscPrice= ' + propertyCustomApplyChargesToDiscPrice);
                                
                                boolean adminIsIncluded = (oneItemRevenueBreakdown.AdminCharge__c != null ? oneItemRevenueBreakdown.AdminIsIncludedInInclusivePrice__c : (propertyCustomAdminCharge != null ? oneItemRevenueBreakdown.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c : false));
                                boolean gratIsIncluded = (oneItemRevenueBreakdown.Gratuity__c != null ? oneItemRevenueBreakdown.GratuityIsIncludedInInclusivePrice__c : (propertyCustomGratuity != null ? oneItemRevenueBreakdown.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c : false));
                                decimal admin = oneItemRevenueBreakdown.AdminCharge__c != null ? oneItemRevenueBreakdown.AdminCharge__c : (propertyCustomAdminCharge != null ? propertyCustomAdminCharge : 0);
                                decimal grat = oneItemRevenueBreakdown.Gratuity__c != null ? oneItemRevenueBreakdown.Gratuity__c : (propertyCustomGratuity != null ? propertyCustomGratuity : 0);
                                boolean applyChargesToDiscPrice = propertyCustomApplyChargesToDiscPrice;
                                decimal inclRate = 1;
                                
                                system.debug(logginglevel.info, 'admin= ' + admin);
                                system.debug(logginglevel.info, 'adminIsIncluded= ' + adminIsIncluded);
                                system.debug(logginglevel.info, 'applyChargesToDiscPrice= ' + applyChargesToDiscPrice);
                                
                                if(bookingEventToTaxGroup.get(oneEventItem.Event__c) != null){
                                    if(oneItemRevenueBreakdown.IsInclusive__c){
                                        inclRate = tgs.GetInclusiveBaseRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneItemRevenueBreakdown.RevenueClassification__c) + ((adminIsIncluded ? (admin / 100) : 0) * tgs.GetInclusiveAdminRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneItemRevenueBreakdown.RevenueClassification__c)) + ((gratIsIncluded ? (grat / 100) : 0) * tgs.GetInclusiveGratuityRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneItemRevenueBreakdown.RevenueClassification__c));
                                    }
                                }
                                
                                EventItemRevenueBreakdown__c oneEventItemRevenueBreakdown = new EventItemRevenueBreakdown__c();
                                oneEventItemRevenueBreakdown.EventItem__c = oneEventItem.Id;
                                oneEventItemRevenueBreakdown.Name = oneItemRevenueBreakdown.Name;
                                oneEventItemRevenueBreakdown.RevenueClassification__c = oneItemRevenueBreakdown.RevenueClassification__c;
                                oneEventItemRevenueBreakdown.UnitPrice__c = (oneItemRevenueBreakdown.UnitPrice__c != null ? (oneItemRevenueBreakdown.IsInclusive__c ? NI.getConvertedValue(oneItemRevenueBreakdown.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneItemRevenueBreakdown.UnitPrice__c) / (inclRate) : NI.getConvertedValue(oneItemRevenueBreakdown.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneItemRevenueBreakdown.UnitPrice__c)) : null);
                                oneEventItemRevenueBreakdown.Location__c = oneEventItem.Location__c;
                                oneEventItemRevenueBreakdown.Gratuity__c = grat;
                                oneEventItemRevenueBreakdown.AdminCharge__c = admin;
                                oneEventItemRevenueBreakdown.GratuityIsIncludedInInclusivePrice__c = gratIsIncluded;
                                oneEventItemRevenueBreakdown.AdminIsIncludedInInclusivePrice__c = adminIsIncluded;
                                oneEventItemRevenueBreakdown.ApplyChargesToDiscPrice__c = applyChargesToDiscPrice;
                                
                                newEventItemRevenueBreakdowns.add(oneEventItemRevenueBreakdown);
                                itemRevenueBreakdownIdToNewTaxedEventItemRevenueBreakdown.get(oneItemRevenueBreakdown.Id).add(oneEventItemRevenueBreakdown);
                            }
                            
                            //Create the children menu items (from non choice groups)
                            for (MenuItem__c oneMenuItem : itemIdToMenuItems.get(oneEventItem.ItemReference__c))
                            {
                                // oneEventItem.location__c should never be blank since it originates from be.Location__c when filling in newEventItems above        
                                Id location = (oneMenuItem.ChildItem__r.Location__c != null) ? oneMenuItem.ChildItem__r.Location__c : oneEventItem.location__c;
     
                                decimal propertyCustomAdminCharge = CustomRevenueClass.getAdminCharge(location, oneMenuItem.ChildItem__r.revenueClassification__c);
                                decimal propertyCustomGratuity = CustomRevenueClass.getGratuity(location, oneMenuItem.ChildItem__r.revenueClassification__c);
                                boolean propertyCustomApplyChargesToDiscPrice = CustomRevenueClass.getApplyChargesToDiscPrice(location, oneMenuItem.ChildItem__r.revenueClassification__c); 
                                       
                                system.debug(logginglevel.info, 'processing menuItems -- propertyCustomAdminCharge= ' + propertyCustomAdminCharge);
                                system.debug(logginglevel.info, 'processing menuItems -- propertyCustomGratuity= ' + propertyCustomGratuity);
                                system.debug(logginglevel.info, 'processing menuItems -- propertyCustomApplyChargesToDiscPrice' +  propertyCustomApplyChargesToDiscPrice);                            
                                
                                boolean adminIsIncluded = oneMenuItem.PriceWithMenu__c == false ? (oneMenuItem.ChildItem__r.AdminCharge__c != null ? oneMenuItem.ChildItem__r.AdminIsIncludedInInclusivePrice__c : (propertyCustomAdminCharge != null ? oneMenuItem.ChildItem__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c : false)) : false;
                                boolean gratIsIncluded = oneMenuItem.PriceWithMenu__c == false ? (oneMenuItem.ChildItem__r.Gratuity__c != null ? oneMenuItem.ChildItem__r.GratuityIsIncludedInInclusivePrice__c : (propertyCustomGratuity  != null ? oneMenuItem.ChildItem__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c : false)) : false;
                                decimal admin = oneMenuItem.PriceWithMenu__c == false ? (oneMenuItem.ChildItem__r.AdminCharge__c != null ? oneMenuItem.ChildItem__r.AdminCharge__c : (propertyCustomAdminCharge != null ? propertyCustomAdminCharge : 0)) : 0;
                                decimal grat = oneMenuItem.PriceWithMenu__c == false ? (oneMenuItem.ChildItem__r.Gratuity__c != null ? oneMenuItem.ChildItem__r.Gratuity__c : (propertyCustomGratuity != null ? propertyCustomGratuity : 0)) : 0;
                                boolean applyChargesToDiscPrice = oneMenuItem.PriceWithMenu__c == false ? propertyCustomApplyChargesToDiscPrice : false;
                                decimal inclRate = 1;
                                
                                if(bookingEventToTaxGroup.get(oneEventItem.Event__c) != null){
                                    if(oneMenuItem.ChildItem__r.IsInclusive__c){
                                        inclRate = tgs.GetInclusiveBaseRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneMenuItem.ChildItem__r.RevenueClassification__c) + ((adminIsIncluded ? (admin / 100) : 0) * tgs.GetInclusiveAdminRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneMenuItem.ChildItem__r.RevenueClassification__c)) + ((gratIsIncluded ? (grat / 100) : 0) * tgs.GetInclusiveGratuityRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneMenuItem.ChildItem__r.RevenueClassification__c));
                                    }
                                }
                                
                                //Add the setup item to the map of setup item ids to new event items if the setup id is not there already
                                //ie: if there was not already and item or menu item using this Id
                                if (!itemIdToNewTaxedEventItems.containsKey(oneMenuItem.ChildItem__r.Id))
                                    itemIdToNewTaxedEventItems.put(oneMenuItem.ChildItem__r.Id,new list<EventItem__c>());
                                EventItem__c oneChildEventItem = new EventItem__c();
                                oneChildEventItem.Event__c = oneEventItem.Event__c;
                                oneChildEventItem.Name = oneMenuItem.Name;
                                oneChildEventItem.RecordTypeId = EventItemRecordTypeId.get(oneMenuItem.ChildItem__r.ItemType__c);
                                oneChildEventItem.ItemReference__c = oneMenuItem.ChildItem__r.Id;
                                oneChildEventItem.Location__c = oneEventItem.Location__c;
                                oneChildEventItem.AllowDecimalQuantities__c = oneMenuItem.ChildItem__r.AllowDecimalQuantities__c;
                                oneChildEventItem.Booking__c = oneEventItem.Booking__c;
                                oneChildEventItem.Description__c = oneMenuItem.ChildItem__r.Description__c;
                                oneChildEventItem.DoNotPrintOnBeo__c = oneMenuItem.ChildItem__r.DoNotPrintOnBeo__c;
                                oneChildEventItem.DoNotPrintOnCheck__c = oneMenuItem.ChildItem__r.DoNotPrintOnCheck__c;
                                oneChildEventItem.EstimatedConsumptionPercentage__c = oneMenuItem.EstimatedConsumptionPercentage__c;
                                oneChildEventItem.HidePriceOnBeo__c = oneMenuItem.ChildItem__r.HidePriceOnBeo__c;
                                oneChildEventItem.HideQuantityOnBeo__c = oneMenuItem.ChildItem__r.HideQuantityOnBeo__c;
                                oneChildEventItem.QuantityCalculation__c = oneMenuItem.ChildItem__r.QuantityCalculation__c;
                                oneChildEventItem.RevenueClassification__c = oneMenuItem.ChildItem__r.RevenueClassification__c;
                                oneChildEventItem.RichDescription__c = oneMenuItem.ChildItem__r.RichDescription__c;
                                oneChildEventItem.ServFactor__c = oneMenuItem.ChildItem__r.Service_Factor__c;
                                oneChildEventItem.UnitPrice__c = (oneMenuItem.UnitPrice__c != null ? (oneMenuItem.ChildItem__r.IsInclusive__c ? NI.getConvertedValue(oneMenuItem.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneMenuItem.UnitPrice__c) / (inclRate) : NI.getConvertedValue(oneMenuItem.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneMenuItem.UnitPrice__c)) : null);
                                oneChildEventItem.Menu__c = oneEventItem.Id;
                                oneChildEventItem.MenuItem__c = oneMenuItem.Id;
                                oneChildEventItem.PriceWithMenu__c = oneMenuItem.PriceWithMenu__c;
                                oneChildEventItem.ServiceStartDate__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartDate__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartDate__c : null);
                                oneChildEventItem.ServiceStartTime12Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime12Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime12Hour__c : null);
                                oneChildEventItem.ServiceStartTime24Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime24Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime24Hour__c : null);
                                oneChildEventItem.ServiceEndDate__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndDate__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndDate__c : null);
                                oneChildEventItem.ServiceEndTime12Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime12Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime12Hour__c : null);
                                oneChildEventItem.ServiceEndTime24Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime24Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime24Hour__c : null);
                                oneChildEventItem.SoldByUnit__c = (oneMenuItem.ChildItem__r.SoldByUnit__c != null ? oneMenuItem.ChildItem__r.SoldByUnit__c : null);
                                oneChildEventItem.Gratuity__c = grat;
                                oneChildEventItem.AdminCharge__c = admin;
                                oneChildEventItem.GratuityIsIncludedInInclusivePrice__c = gratIsIncluded;
                                oneChildEventItem.AdminIsIncludedInInclusivePrice__c = adminIsIncluded;
                                oneChildEventItem.ApplyChargesToDiscPrice__c = applyChargesToDiscPrice;                            
                                oneChildEventItem.ServingUnit__c = oneMenuItem.ChildItem__r.ServingUnit__c;
                                oneChildEventItem.AlternateNameDE__c = oneMenuItem.ChildItem__r.AlternateNameDE__c;
                                oneChildEventItem.AlternateRichDescriptionDE__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionDE__c;
                                oneChildEventItem.AlternateServingUnitDE__c = oneMenuItem.ChildItem__r.AlternateServingUnitDE__c;
                                oneChildEventItem.AlternateSoldByUnitDE__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitDE__c;
                                oneChildEventItem.AlternateNameENUS__c = oneMenuItem.ChildItem__r.AlternateNameENUS__c;
                                oneChildEventItem.AlternateRichDescriptionENUS__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionENUS__c;
                                oneChildEventItem.AlternateServingUnitENUS__c = oneMenuItem.ChildItem__r.AlternateServingUnitENUS__c;
                                oneChildEventItem.AlternateSoldByUnitENUS__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitENUS__c;
                                oneChildEventItem.AlternateNameES__c = oneMenuItem.ChildItem__r.AlternateNameES__c;
                                oneChildEventItem.AlternateRichDescriptionES__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionES__c;
                                oneChildEventItem.AlternateServingUnitES__c = oneMenuItem.ChildItem__r.AlternateServingUnitES__c;
                                oneChildEventItem.AlternateSoldByUnitES__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitES__c;
                                oneChildEventItem.AlternateNameFR__c = oneMenuItem.ChildItem__r.AlternateNameFR__c;
                                oneChildEventItem.AlternateRichDescriptionFR__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionFR__c;
                                oneChildEventItem.AlternateServingUnitFR__c = oneMenuItem.ChildItem__r.AlternateServingUnitFR__c;
                                oneChildEventItem.AlternateSoldByUnitFR__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitFR__c;
                                oneChildEventItem.AlternateNameIT__c = oneMenuItem.ChildItem__r.AlternateNameIT__c;
                                oneChildEventItem.AlternateRichDescriptionIT__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionIT__c;
                                oneChildEventItem.AlternateServingUnitIT__c = oneMenuItem.ChildItem__r.AlternateServingUnitIT__c;
                                oneChildEventItem.AlternateSoldByUnitIT__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitIT__c;
                                oneChildEventItem.AlternateNameNLNL__c = oneMenuItem.ChildItem__r.AlternateNameNLNL__c;
                                oneChildEventItem.AlternateRichDescriptionNLNL__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionNLNL__c;
                                oneChildEventItem.AlternateServingUnitNLNL__c = oneMenuItem.ChildItem__r.AlternateServingUnitNLNL__c;
                                oneChildEventItem.AlternateSoldByUnitNLNL__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitNLNL__c;
                                oneChildEventItem.AlternateNamePL__c = oneMenuItem.ChildItem__r.AlternateNamePL__c;
                                oneChildEventItem.AlternateRichDescriptionPL__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionPL__c;
                                oneChildEventItem.AlternateServingUnitPL__c = oneMenuItem.ChildItem__r.AlternateServingUnitPL__c;
                                oneChildEventItem.AlternateSoldByUnitPL__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitPL__c;
                                oneChildEventItem.AlternateNamePTBR__c = oneMenuItem.ChildItem__r.AlternateNamePTBR__c;
                                oneChildEventItem.AlternateRichDescriptionPTBR__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionPTBR__c;
                                oneChildEventItem.AlternateServingUnitPTBR__c = oneMenuItem.ChildItem__r.AlternateServingUnitPTBR__c;
                                oneChildEventItem.AlternateSoldByUnitPTBR__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitPTBR__c;
                                oneChildEventItem.AlternateNamePTPT__c = oneMenuItem.ChildItem__r.AlternateNamePTPT__c;
                                oneChildEventItem.AlternateRichDescriptionPTPT__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionPTPT__c;
                                oneChildEventItem.AlternateServingUnitPTPT__c = oneMenuItem.ChildItem__r.AlternateServingUnitPTPT__c;
                                oneChildEventItem.AlternateSoldByUnitPTPT__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitPTPT__c;
                                oneChildEventItem.AlternateNameZHCN__c = oneMenuItem.ChildItem__r.AlternateNameZHCN__c;
                                oneChildEventItem.AlternateRichDescriptionZHCN__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionZHCN__c;
                                oneChildEventItem.AlternateServingUnitZHCN__c = oneMenuItem.ChildItem__r.AlternateServingUnitZHCN__c;
                                oneChildEventItem.AlternateSoldByUnitZHCN__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitZHCN__c;
                                oneChildEventItem.AlternateNameZHTW__c = oneMenuItem.ChildItem__r.AlternateNameZHTW__c;
                                oneChildEventItem.AlternateRichDescriptionZHTW__c = oneMenuItem.ChildItem__r.AlternateRichDescriptionZHTW__c;
                                oneChildEventItem.AlternateServingUnitZHTW__c = oneMenuItem.ChildItem__r.AlternateServingUnitZHTW__c;
                                oneChildEventItem.AlternateSoldByUnitZHTW__c = oneMenuItem.ChildItem__r.AlternateSoldByUnitZHTW__c;
    
                                newChildEventItems.add(oneChildEventItem);
                                //If the Menu item is not priced with menu, add taxes
                                if (oneChildEventItem.PriceWithMenu__c == false)
                                    itemIdToNewTaxedEventItems.get(oneMenuItem.ChildItem__r.Id).add(oneChildEventItem);
                            }
                            
                            //Create the children items from choice groups
                            for(Id oneMenuItemId : itemIdToChoiceGroupMenuItemIdsToChoiceGroup.get(oneEventItem.ItemReference__c).KeySet() )
                            {
                                ChoiceGroup__c oneChoiceGroup = itemIdToChoiceGroupMenuItemIdsToChoiceGroup.get(oneEventItem.ItemReference__c).get(oneMenuItemId);
                                for(ChoiceGroupItem__c oneChoiceGroupItem : choiceGroupIdToChoiceGroupItems.get(oneChoiceGroup.Id))
                                {
                                    // oneEventItem.location__c should never be blank since it originates from be.Location__c when filling in newEventItems above        
                                    Id location = (oneChoiceGroupItem.Item__r.Location__c != null) ? oneChoiceGroupItem.Item__r.Location__c : oneEventItem.location__c;
                                         
                                    decimal propertyCustomAdminCharge = CustomRevenueClass.getAdminCharge(location, oneChoiceGroupItem.Item__r.revenueClassification__c);
                                    decimal propertyCustomGratuity = CustomRevenueClass.getGratuity(location, oneChoiceGroupItem.Item__r.revenueClassification__c);
                                    boolean propertyCustomApplyChargesToDiscPrice = CustomRevenueClass.getApplyChargesToDiscPrice(location, oneChoiceGroupItem.Item__r.revenueClassification__c); 
                   
                                    system.debug(logginglevel.info, 'choiceGroupItems--propertyCustomAdminCharge= ' + propertyCustomAdminCharge);
                                    system.debug(logginglevel.info, 'choiceGroupItems--propertyCustomGratuity= ' + propertyCustomGratuity);
                                    
                                    boolean adminIsIncluded = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId) == false ? (oneChoiceGroupItem.Item__r.AdminCharge__c != null ? oneChoiceGroupItem.Item__r.AdminIsIncludedInInclusivePrice__c : (propertyCustomAdminCharge  != null ? oneChoiceGroupItem.Item__r.RevenueClassification__r.AdminIsIncludedInInclusivePrice__c : false)) : false;
                                    boolean gratIsIncluded = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId) == false ? (oneChoiceGroupItem.Item__r.Gratuity__c != null ? oneChoiceGroupItem.Item__r.GratuityIsIncludedInInclusivePrice__c : (propertyCustomGratuity != null ? oneChoiceGroupItem.Item__r.RevenueClassification__r.GratuityIsIncludedInInclusivePrice__c : false)) : false;
                                    decimal admin = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId) == false ? (oneChoiceGroupItem.Item__r.AdminCharge__c != null ? oneChoiceGroupItem.Item__r.AdminCharge__c : (propertyCustomAdminCharge != null ? propertyCustomAdminCharge  : 0)) : 0;
                                    decimal grat = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId) == false ? (oneChoiceGroupItem.Item__r.Gratuity__c != null ? oneChoiceGroupItem.Item__r.Gratuity__c : (propertyCustomGratuity != null ? propertyCustomGratuity : 0)) : 0;
                                    boolean applyChargesToDiscPrice = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId) == false ? propertyCustomApplyChargesToDiscPrice : false;
                                    decimal inclRate = 1;
                                                                    
                                    if(bookingEventToTaxGroup.get(oneEventItem.Event__c) != null){
                                        if(oneChoiceGroupItem.Item__r.IsInclusive__c){
                                            inclRate = tgs.GetInclusiveBaseRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneChoiceGroupItem.Item__r.RevenueClassification__c) + ((adminIsIncluded ? (admin / 100) : 0) * tgs.GetInclusiveAdminRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneChoiceGroupItem.Item__r.RevenueClassification__c)) + ((gratIsIncluded ? (grat / 100) : 0) * tgs.GetInclusiveGratuityRate(bookingEventToTaxGroup.get(oneEventItem.Event__c), oneChoiceGroupItem.Item__r.RevenueClassification__c));
                                        }
                                    }
                                    
                                    //Add the setup item to the map of setup item ids to new event items if the setup id is not there already
                                    //ie: if there was not already and item or menu item using this Id
                                    if (!itemIdToNewTaxedEventItems.containsKey(oneChoiceGroupItem.Item__r.Id))
                                        itemIdToNewTaxedEventItems.put(oneChoiceGroupItem.Item__r.Id,new list<EventItem__c>());
                                    EventItem__c oneChildEventItem = new EventItem__c();
                                    oneChildEventItem.Event__c = oneEventItem.Event__c;
                                    oneChildEventItem.Name = oneChoiceGroupItem.Item__r.Name;
                                    oneChildEventItem.RecordTypeId = EventItemRecordTypeId.get(oneChoiceGroupItem.Item__r.ItemType__c);
                                    oneChildEventItem.ItemReference__c = oneChoiceGroupItem.Item__r.Id;
                                    oneChildEventItem.Location__c = oneEventItem.Location__c;
                                    oneChildEventItem.AllowDecimalQuantities__c = oneChoiceGroupItem.Item__r.AllowDecimalQuantities__c;
                                    oneChildEventItem.Booking__c = oneEventItem.Booking__c;
                                    oneChildEventItem.Description__c = oneChoiceGroupItem.Item__r.Description__c;
                                    oneChildEventItem.DoNotPrintOnBeo__c = oneChoiceGroupItem.Item__r.DoNotPrintOnBeo__c;
                                    oneChildEventItem.DoNotPrintOnCheck__c = oneChoiceGroupItem.Item__r.DoNotPrintOnCheck__c;
                                    oneChildEventItem.EstimatedConsumptionPercentage__c = oneChoiceGroupItem.Item__r.EstimatedConsumptionPercentage__c;
                                    oneChildEventItem.HidePriceOnBeo__c = oneChoiceGroupItem.Item__r.HidePriceOnBeo__c;
                                    oneChildEventItem.HideQuantityOnBeo__c = oneChoiceGroupItem.Item__r.HideQuantityOnBeo__c;
                                    oneChildEventItem.QuantityCalculation__c = oneChoiceGroupItem.Item__r.QuantityCalculation__c;
                                    oneChildEventItem.RevenueClassification__c = oneChoiceGroupItem.Item__r.RevenueClassification__c;
                                    oneChildEventItem.RichDescription__c = oneChoiceGroupItem.Item__r.RichDescription__c;
                                    oneChildEventItem.ServFactor__c = oneChoiceGroupItem.Item__r.Service_Factor__c;
                                    oneChildEventItem.UnitPrice__c = (oneChoiceGroupItem.UnitPrice__c != null ? (oneChoiceGroupItem.Item__r.IsInclusive__c ? NI.getConvertedValue(oneChoiceGroupItem.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneChoiceGroupItem.UnitPrice__c) / (inclRate) : NI.getConvertedValue(oneChoiceGroupItem.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).CurrencyIsoCode, oneChoiceGroupItem.UnitPrice__c)) : null);
                                    oneChildEventItem.Menu__c = oneEventItem.Id;
                                    oneChildEventItem.ChoiceGroupItem__c = oneChoiceGroupItem.Id;
                                    oneChildEventItem.PriceWithMenu__c = parentMenuIdToChoiceGroupMenuItemIdToPriceWithMenu.get(oneEventItem.ItemReference__c).get(oneMenuItemId);
                                    oneChildEventItem.ServiceStartDate__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartDate__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartDate__c : null);
                                    oneChildEventItem.ServiceStartTime12Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime12Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime12Hour__c : null);
                                    oneChildEventItem.ServiceStartTime24Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime24Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).StartTime24Hour__c : null);
                                    oneChildEventItem.ServiceEndDate__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndDate__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndDate__c : null);
                                    oneChildEventItem.ServiceEndTime12Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime12Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime12Hour__c : null);
                                    oneChildEventItem.ServiceEndTime24Hour__c = (((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime24Hour__c != null ? ((BookingEvent__c)trigger.newMap.get(oneEventItem.Event__c)).EndTime24Hour__c : null);
                                    oneChildEventItem.SoldByUnit__c = (oneChoiceGroupItem.Item__r.SoldByUnit__c != null ? oneChoiceGroupItem.Item__r.SoldByUnit__c : null);
                                    oneChildEventItem.Gratuity__c = grat;
                                    oneChildEventItem.AdminCharge__c = admin;
                                    oneChildEventItem.GratuityIsIncludedInInclusivePrice__c = gratIsIncluded;
                                    oneChildEventItem.AdminIsIncludedInInclusivePrice__c = adminIsIncluded;
                                    oneChildEventItem.ApplyChargesToDiscPrice__c = applyChargesToDiscPrice;                                
                                    oneChildEventItem.ServingUnit__c = oneChoiceGroupItem.Item__r.ServingUnit__c;
                                    oneChildEventItem.AlternateNameDE__c = oneChoiceGroupItem.Item__r.AlternateNameDE__c;
                                    oneChildEventItem.AlternateRichDescriptionDE__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionDE__c;
                                    oneChildEventItem.AlternateServingUnitDE__c = oneChoiceGroupItem.Item__r.AlternateServingUnitDE__c;
                                    oneChildEventItem.AlternateSoldByUnitDE__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitDE__c;
                                    oneChildEventItem.AlternateNameENUS__c = oneChoiceGroupItem.Item__r.AlternateNameENUS__c;
                                    oneChildEventItem.AlternateRichDescriptionENUS__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionENUS__c;
                                    oneChildEventItem.AlternateServingUnitENUS__c = oneChoiceGroupItem.Item__r.AlternateServingUnitENUS__c;
                                    oneChildEventItem.AlternateSoldByUnitENUS__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitENUS__c;
                                    oneChildEventItem.AlternateNameES__c = oneChoiceGroupItem.Item__r.AlternateNameES__c;
                                    oneChildEventItem.AlternateRichDescriptionES__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionES__c;
                                    oneChildEventItem.AlternateServingUnitES__c = oneChoiceGroupItem.Item__r.AlternateServingUnitES__c;
                                    oneChildEventItem.AlternateSoldByUnitES__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitES__c;
                                    oneChildEventItem.AlternateNameFR__c = oneChoiceGroupItem.Item__r.AlternateNameFR__c;
                                    oneChildEventItem.AlternateRichDescriptionFR__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionFR__c;
                                    oneChildEventItem.AlternateServingUnitFR__c = oneChoiceGroupItem.Item__r.AlternateServingUnitFR__c;
                                    oneChildEventItem.AlternateSoldByUnitFR__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitFR__c;
                                    oneChildEventItem.AlternateNameIT__c = oneChoiceGroupItem.Item__r.AlternateNameIT__c;
                                    oneChildEventItem.AlternateRichDescriptionIT__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionIT__c;
                                    oneChildEventItem.AlternateServingUnitIT__c = oneChoiceGroupItem.Item__r.AlternateServingUnitIT__c;
                                    oneChildEventItem.AlternateSoldByUnitIT__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitIT__c;
                                    oneChildEventItem.AlternateNameNLNL__c = oneChoiceGroupItem.Item__r.AlternateNameNLNL__c;
                                    oneChildEventItem.AlternateRichDescriptionNLNL__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionNLNL__c;
                                    oneChildEventItem.AlternateServingUnitNLNL__c = oneChoiceGroupItem.Item__r.AlternateServingUnitNLNL__c;
                                    oneChildEventItem.AlternateSoldByUnitNLNL__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitNLNL__c;
                                    oneChildEventItem.AlternateNamePL__c = oneChoiceGroupItem.Item__r.AlternateNamePL__c;
                                    oneChildEventItem.AlternateRichDescriptionPL__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionPL__c;
                                    oneChildEventItem.AlternateServingUnitPL__c = oneChoiceGroupItem.Item__r.AlternateServingUnitPL__c;
                                    oneChildEventItem.AlternateSoldByUnitPL__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitPL__c;
                                    oneChildEventItem.AlternateNamePTBR__c = oneChoiceGroupItem.Item__r.AlternateNamePTBR__c;
                                    oneChildEventItem.AlternateRichDescriptionPTBR__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionPTBR__c;
                                    oneChildEventItem.AlternateServingUnitPTBR__c = oneChoiceGroupItem.Item__r.AlternateServingUnitPTBR__c;
                                    oneChildEventItem.AlternateSoldByUnitPTBR__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitPTBR__c;
                                    oneChildEventItem.AlternateNamePTPT__c = oneChoiceGroupItem.Item__r.AlternateNamePTPT__c;
                                    oneChildEventItem.AlternateRichDescriptionPTPT__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionPTPT__c;
                                    oneChildEventItem.AlternateServingUnitPTPT__c = oneChoiceGroupItem.Item__r.AlternateServingUnitPTPT__c;
                                    oneChildEventItem.AlternateSoldByUnitPTPT__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitPTPT__c;
                                    oneChildEventItem.AlternateNameZHCN__c = oneChoiceGroupItem.Item__r.AlternateNameZHCN__c;
                                    oneChildEventItem.AlternateRichDescriptionZHCN__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionZHCN__c;
                                    oneChildEventItem.AlternateServingUnitZHCN__c = oneChoiceGroupItem.Item__r.AlternateServingUnitZHCN__c;
                                    oneChildEventItem.AlternateSoldByUnitZHCN__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitZHCN__c;
                                    oneChildEventItem.AlternateNameZHTW__c = oneChoiceGroupItem.Item__r.AlternateNameZHTW__c;
                                    oneChildEventItem.AlternateRichDescriptionZHTW__c = oneChoiceGroupItem.Item__r.AlternateRichDescriptionZHTW__c;
                                    oneChildEventItem.AlternateServingUnitZHTW__c = oneChoiceGroupItem.Item__r.AlternateServingUnitZHTW__c;
                                    oneChildEventItem.AlternateSoldByUnitZHTW__c = oneChoiceGroupItem.Item__r.AlternateSoldByUnitZHTW__c;
                                    newChildEventItems.add(oneChildEventItem);
                                    //If the Menu item is not priced with menu, add taxes
                                    if (oneChildEventItem.PriceWithMenu__c == false)
                                        itemIdToNewTaxedEventItems.get(oneChoiceGroupItem.Item__r.Id).add(oneChildEventItem);
                                }
                            }
                        //ended here
                        }//End loop through event items to create children event items and event item revenue breakdowns
        
                        //Insert children breakdowns (to menus)
                        if(!newEventItemRevenueBreakdowns.isEmpty())
                            insert(newEventItemRevenueBreakdowns);
                            
                        /*
                            Insert Children items (to menus)
                            Here we must trigger an update to the events that were effected by inserting these eventItems
                            but the items added had no children. we will fire off another update of the original parent 
                            EventItems but set the firstPass to false, so that we we don't have to recalculate the revenue
                            again. (saves queries)
                        */
                        if(!newChildEventItems.isEmpty())
                        {
                            EventItemCls.RollupEvents = true;
                            Security.createWithFLSCheck(newChildEventItems);
                        }
                        else
                        {
                            EventItemCls.RollupEvents = true; 
                            update newEventItems;
                        }
        
                        //Get all item taxes associated to the event items
                        for (ItemTax__c itemTax : [Select Id, Name, AppliesTo__c, IsCompound__c, FlatRate__c, Item__c, ItemRevenueBreakdown__c, Rate__c, SortOrder__c, CurrencyIsoCode FROM ItemTax__c WHERE Item__c IN : itemIdToNewTaxedEventItems.KeySet() OR ItemRevenueBreakdown__c IN : itemRevenueBreakdownIdToNewTaxedEventItemRevenueBreakdown.KeySet()  ])
                        {
                            if (itemTax.ItemRevenueBreakdown__c != NULL)
                            {
                                for (EventItemRevenueBreakdown__c eventItemRevenueBreakdown : itemRevenueBreakdownIdToNewTaxedEventItemRevenueBreakdown.get(itemTax.ItemRevenueBreakdown__c))
                                {
                                    BookingTax__c newBookingTax = new BookingTax__c(
                                        Name = itemTax.Name
                                        ,AppliesTo__c = (itemTax.AppliesTo__c != null ? itemTax.AppliesTo__c : null)
                                        ,IsCompound__c = (itemTax.IsCompound__c != null ? itemTax.IsCompound__c : null)
                                        ,FlatRate__c = (parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Event__c != null ? (itemTax.FlatRate__c != null ? NI.getConvertedValue(itemTax.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Event__c)).CurrencyIsoCode, itemTax.FlatRate__c) : null) : itemTax.FlatRate__c) 
                                        ,Rate__c = (itemTax.Rate__c != null ? itemTax.Rate__c : null)
                                        ,SortOrder__c = (itemTax.AppliesTo__c != null ? itemTax.SortOrder__c : null)
                                        ,Booking__c = (parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Booking__c != null ? parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Booking__c : null)
                                        ,BookingEvent__c = (parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Event__c != null ? parentEventItemIdToParentEventItem.get(eventItemRevenueBreakdown.EventItem__c).Event__c : null)
                                        ,Location__c = (eventItemRevenueBreakdown.Location__c != null ? eventItemRevenueBreakdown.Location__c : null)
                                        ,EventItem__c = (eventItemRevenueBreakdown.EventItem__c != null ? eventItemRevenueBreakdown.EventItem__c : null)
                                        ,EventItemRevenueBreakdown__c = eventItemRevenueBreakdown.Id
                                    );
                                    newBookingTaxes.add(newBookingTax);
                                }
                            }
                            else if (itemTax.Item__c != NULL)
                            {
                                for (EventItem__c eventItem : itemIdToNewTaxedEventItems.get(itemTax.Item__c))
                                {
                                    BookingTax__c newBookingTax = new BookingTax__c(
                                        Name = itemTax.Name
                                        ,AppliesTo__c = (itemTax.AppliesTo__c != null ? itemTax.AppliesTo__c : null)
                                        ,IsCompound__c = (itemTax.IsCompound__c != null ? itemTax.IsCompound__c : null)
                                        ,FlatRate__c = (eventItem.Event__c != null ? (itemTax.FlatRate__c != null ? NI.getConvertedValue(itemTax.CurrencyIsoCode, ((BookingEvent__c)trigger.newMap.get(eventItem.Event__c)).CurrencyIsoCode, itemTax.FlatRate__c) : null) : itemTax.FlatRate__c) 
                                        ,Rate__c = (itemTax.Rate__c != null ? itemTax.Rate__c : null)
                                        ,SortOrder__c = (itemTax.AppliesTo__c != null ? itemTax.SortOrder__c : null)
                                        ,Booking__c = (eventItem.Booking__c != null ? eventItem.Booking__c : null)
                                        ,BookingEvent__c = (eventItem.Event__c != null ? eventItem.Event__c : null)
                                        ,Location__c = (eventItem.Location__c != null ? eventItem.Location__c : null)
                                        ,EventItem__c = eventItem.Id
                                    );
                                    newBookingTaxes.add(newBookingTax);
                                }
                            }
                        }
                        //Insert all booking taxes
                        insert(newBookingTaxes);
                    }//End if there are event classification items to add
                }//End if first pass
            }      
    }
    
    /**
        BookingEventDelete - deletes all child EventItems.
        before delete 
    */
    public class BookingEventDelete implements Triggers.Handler {  
        public void handle() {
            //Delete the Orphaned Booking taxes.  
            if(Trigger.isBefore){       
                BookingTax__c[] BookingTaxes = [SELECT Id FROM BookingTax__c WHERE BookingEvent__c IN : trigger.oldMap.keySet()];
                Security.DeleteListWithCheck(BookingTaxes);
                BookingPackageEvent__c[] BookingPackageEvents = [Select Id from BookingPackageEvent__c WHERE BookingEvent__c IN : trigger.oldMap.keySet()];
                Security.DeleteListWithCheck(BookingPackageEvents);
            }
            if(Trigger.isAfter){
                Set<Id> bookings = new Set<Id>();
                for(BookingEvent__c be : (List<BookingEvent__c>)(Trigger.old)){
                    bookings.add(be.Booking__c);
                }
                
                List<Booking__c> bks = [Select Id from Booking__c where Id IN: bookings];
                update bks;
            }
        }
    }
    
    /*
        Josh Clairmont 6/19/13
        This trigger class will implement default values for event classification
        if values other than the defaults are specified, the users input should 
        not be overwritten. 
    */
    public class EventClassificationDefaulting implements Triggers.Handler{
        public void handle() {
            
            if (!Triggers.getBoolParam('EventClassificationDefaulting', true)) { 
                return;
            }
            
            if(enableAverageCheckDefaulting){            
                boolean changeForecastOnClassificationLocationFlag = false;   
                boolean changeForecastOnClassificationUpdate = false;        
                boolean eventInPast = false;  //if null, continue 
                boolean eventComplete = true;
                boolean didClassificationChange = false;
                Map<Id, boolean> eventIdToChangeFlag = new Map<Id, boolean>();
                
                //
                Map<Id, EventClassification__c> mapEventClassifications = new Map<Id, EventClassification__c>();
                List<Id> eventClassificationIds = new List<Id>();
                for (BookingEvent__c be : (list<BookingEvent__c>)(trigger.New)){
                
                    Time ev1EndTime = null;
                    DateTime ev1EndDateTime = null;
                    if (be.EndTime24Hour__c != null) {
                        ev1EndTime = Time.newInstance(Integer.valueOf(be.EndTime24Hour__c.left(2)), Integer.valueOf(be.EndTime24Hour__c.right(2)), 0, 0);
                               
                    }
                    if ( be.EndDate__c != null) {
                      if (ev1EndTime  != null ) {
                          ev1EndDateTime = DateTime.newInstanceGmt(be.EndDate__c, ev1EndTime); 
                      }
                      else {//if time is null, just cast the date
                          ev1EndDateTime  = (dateTime)be.EndDate__c;
                      }
                    }    
            
                    location__c eventLocation;
                    if (be.Location__c != null ) {
                        eventLocation = queriedInfo.Locations.get(be.Location__c);
                     }
                     
                    changeForecastOnClassificationLocationFlag =  eventLocation == null? false: eventLocation.UpdateBookingEventAverageChecks__c;
                    eventComplete = be.IsDone__c == null? false :  be.IsDone__c ;
                    eventInPast = ev1EndDateTime == null? false:  ev1EndDateTime < datetime.now();
                    
                   if (Trigger.IsUpdate) {
                      system.debug(loggingLevel.info, '  ((BookingEvent__c)trigger.oldMap.get(be.Id)).EventClassification__c = ' +  ((BookingEvent__c)trigger.oldMap.get(be.Id)).EventClassification__c   +  '  be.EventClassification__c  + '  + be.EventClassification__c );
                      didClassificationChange =  ((BookingEvent__c)trigger.oldMap.get(be.Id)).EventClassification__c  != be.EventClassification__c ;                
                   }
                   else {
                      didClassificationChange = (be.EventClassification__c!= null);
                   }
                   
                   
                    system.debug(loggingLevel.info, ' changeForecastOnClassificationLocationFlag   = ' + changeForecastOnClassificationLocationFlag   + ' eventComplete  = ' + eventComplete  + 'eventInPast= ' + eventInPast ) ;
                    changeForecastOnClassificationUpdate =  didClassificationChange &&  changeForecastOnClassificationLocationFlag  && !eventComplete && !eventInPast;
                
                    if(be.EventClassification__c != null && Trigger.isInsert){
                        eventClassificationIds.add(be.EventClassification__c);
                    }
                    if(trigger.isUpdate){
                        if((((BookingEvent__c)trigger.oldMap.get(be.Id)).EventClassification__c == null && be.EventClassification__c != null)
                                || changeForecastOnClassificationUpdate  ) //for flagged properties
                            eventClassificationIds.add(be.EventClassification__c);
                            eventIdToChangeFlag.put(be.id, changeForecastOnClassificationUpdate);
                    }
                    
                    if(Trigger.isInsert && be.BookedDate__c == null)
                    {
                        if(be.BookedDate__c == null)
                        {
                            be.BookedDate__c = Date.Today();
                        }
                        if(be.EndDate__c == null)
                        {
                            be.EndDate__c = be.StartDate__c;
                        }
                    }
                    
                    //Default TaxGroup (if no Tax Group is specified)
                    if(be.TaxGroup__c == null)
                    {
                        //When inserting an Event
                        if(Trigger.IsInsert)
                        {
                            //Set to the associated Event Classification's default tax group if there is one
                            if(be.EventClassification__c != null && queriedInfo.EventClassifications.get(be.EventClassification__c) != null && queriedInfo.EventClassifications.get(be.EventClassification__c).DefaultTaxGroup__c != null )
                            {
                                be.TaxGroup__c = queriedInfo.EventClassifications.get(be.EventClassification__c).DefaultTaxGroup__c;
                            }
                            //Otherwise set to the associated Location's default tax group
                            else if(be.Location__c != null && queriedInfo.Locations.get(be.Location__c) != null && queriedInfo.Locations.get(be.Location__c).DefaultTaxGroup__c != null )
                            {
                                be.TaxGroup__c = queriedInfo.Locations.get(be.Location__c).DefaultTaxGroup__c;
                            }
                        }
                        //When updating an Event
                        else if(Trigger.IsUpdate)
                        {
                            //If updating an Event from no Event Classification to having an Event Classification
                            //Set to the associated Event Classification's default tax group if there is one
                            if(((BookingEvent__c)trigger.oldMap.get(be.Id)).EventClassification__c == null && be.EventClassification__c != null && queriedInfo.EventClassifications.get(be.EventClassification__c) != null && queriedInfo.EventClassifications.get(be.EventClassification__c).DefaultTaxGroup__c != null )
                            {
                                be.TaxGroup__c = queriedInfo.EventClassifications.get(be.EventClassification__c).DefaultTaxGroup__c;
                            }
                        }
                    }
                    
                    be.LocIdBkgIdEventClassIdStartDateString__c = String.ValueOf(be.Location__c) + String.ValueOf(be.Booking__c) + String.ValueOf(be.EventClassification__c) + String.ValueOf(be.StartDate__c);
                }
                
                //put all of the event classifications in a map make sure to select all possible fields to be
                //applied to the BookingEvent.
                if(eventClassificationIds.size() > 0){
                    for(EventClassification__c item : queriedInfo.EventClassifications.values()){
                        mapEventClassifications.put(item.Id, item);
                    }
                }
                for(BookingEvent__c be : (list<BookingEvent__c>)(trigger.New)) {
                    if(be.EventClassification__c != null && mapEventClassifications.containsKey(be.EventClassification__c))
                    {
                        EventClassification__c ec = mapEventClassifications.get(be.EventClassification__c);
                        
                        if(Trigger.IsInsert && be.Name == null)
                        {
                            be.Name = ec.Name;
                        }
                        
                       location__c loc;
                       if (be.Location__c != null )  loc= queriedInfo.Locations.get(be.Location__c);
               
                       boolean locationFlag =  loc== null? false: loc.UpdateBookingEventAverageChecks__c;             
                       boolean changeFlag = false;
                       
                       if(Trigger.IsUpdate) changeFlag = eventIdToChangeFlag.get(be.id);           
                       if(Trigger.IsInsert && locationFlag && be.EventClassification__c != null  ) changeFlag = true;
                        
                       if (locationFlag) {
                        if(changeFlag )
                            be.ForecastAverageCheck1__c = ec.DefaultAverageCheck1__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor1__c = ec.DefaultAverageCheckFactor1__c;
                        if(changeFlag )
                            be.ForecastAverageCheck2__c = ec.DefaultAverageCheck2__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor2__c = ec.DefaultAverageCheckFactor2__c;
                        if(changeFlag )
                            be.ForecastAverageCheck3__c = ec.DefaultAverageCheck3__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor3__c = ec.DefaultAverageCheckFactor3__c;
                        if(changeFlag )
                            be.ForecastAverageCheck4__c = ec.DefaultAverageCheck4__c;
                        if( changeFlag )
                            be.ForecastAverageCheckFactor4__c = ec.DefaultAverageCheckFactor4__c;
                        if( changeFlag )
                            be.ForecastAverageCheck5__c = ec.DefaultAverageCheck5__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor5__c = ec.DefaultAverageCheckFactor5__c;
                        if(changeFlag )
                            be.ForecastAverageCheck6__c = ec.DefaultAverageCheck6__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor6__c = ec.DefaultAverageCheckFactor6__c;
                        if(changeFlag )
                            be.ForecastAverageCheck7__c = ec.DefaultAverageCheck7__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor7__c = ec.DefaultAverageCheckFactor7__c;
                        if(changeFlag )
                            be.ForecastAverageCheck8__c = ec.DefaultAverageCheck8__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor8__c = ec.DefaultAverageCheckFactor8__c;
                        if(changeFlag )
                            be.ForecastAverageCheck9__c = ec.DefaultAverageCheck9__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor9__c = ec.DefaultAverageCheckFactor9__c;
                        if(changeFlag )
                            be.ForecastAverageCheck10__c = ec.DefaultAverageCheck10__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor10__c = ec.DefaultAverageCheckFactor10__c;
                        if(changeFlag )
                            be.ForecastAverageCheck11__c = ec.DefaultAverageCheck11__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor11__c = ec.DefaultAverageCheckFactor11__c;
                        if(changeFlag )
                            be.ForecastAverageCheck12__c = ec.DefaultAverageCheck12__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor12__c = ec.DefaultAverageCheckFactor12__c;
                        if(changeFlag )
                            be.ForecastAverageCheck13__c = ec.DefaultAverageCheck13__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor13__c = ec.DefaultAverageCheckFactor13__c;
                        if(changeFlag )
                            be.ForecastAverageCheck14__c = ec.DefaultAverageCheck14__c;
                        if(changeFlag )
                            be.ForecastAverageCheckFactor14__c = ec.DefaultAverageCheckFactor14__c;
                        if(changeFlag )
                            be.ForecastAverageCheck15__c = ec.DefaultAverageCheck15__c;
                        if( changeFlag )
                            be.ForecastAverageCheckFactor15__c = ec.DefaultAverageCheckFactor15__c;
                       } 
                       else {                     
                        if(be.ForecastAverageCheck1__c == null  )
                            be.ForecastAverageCheck1__c = ec.DefaultAverageCheck1__c;
                        if(be.ForecastAverageCheckFactor1__c == null  )
                            be.ForecastAverageCheckFactor1__c = ec.DefaultAverageCheckFactor1__c;
                        if(be.ForecastAverageCheck2__c == null )
                            be.ForecastAverageCheck2__c = ec.DefaultAverageCheck2__c;
                        if(be.ForecastAverageCheckFactor2__c == null )
                            be.ForecastAverageCheckFactor2__c = ec.DefaultAverageCheckFactor2__c;
                        if(be.ForecastAverageCheck3__c == null )
                            be.ForecastAverageCheck3__c = ec.DefaultAverageCheck3__c;
                        if(be.ForecastAverageCheckFactor3__c == null )
                            be.ForecastAverageCheckFactor3__c = ec.DefaultAverageCheckFactor3__c;
                        if(be.ForecastAverageCheck4__c == null )
                            be.ForecastAverageCheck4__c = ec.DefaultAverageCheck4__c;
                        if(be.ForecastAverageCheckFactor4__c == null )
                            be.ForecastAverageCheckFactor4__c = ec.DefaultAverageCheckFactor4__c;
                        if(be.ForecastAverageCheck5__c == null  )
                            be.ForecastAverageCheck5__c = ec.DefaultAverageCheck5__c;
                        if(be.ForecastAverageCheckFactor5__c == null )
                            be.ForecastAverageCheckFactor5__c = ec.DefaultAverageCheckFactor5__c;
                        if(be.ForecastAverageCheck6__c == null  )
                            be.ForecastAverageCheck6__c = ec.DefaultAverageCheck6__c;
                        if(be.ForecastAverageCheckFactor6__c == null )
                            be.ForecastAverageCheckFactor6__c = ec.DefaultAverageCheckFactor6__c;
                        if(be.ForecastAverageCheck7__c == null )
                            be.ForecastAverageCheck7__c = ec.DefaultAverageCheck7__c;
                        if(be.ForecastAverageCheckFactor7__c == null )
                            be.ForecastAverageCheckFactor7__c = ec.DefaultAverageCheckFactor7__c;
                        if(be.ForecastAverageCheck8__c == null )
                            be.ForecastAverageCheck8__c = ec.DefaultAverageCheck8__c;
                        if(be.ForecastAverageCheckFactor8__c == null )
                            be.ForecastAverageCheckFactor8__c = ec.DefaultAverageCheckFactor8__c;
                        if(be.ForecastAverageCheck9__c == null )
                            be.ForecastAverageCheck9__c = ec.DefaultAverageCheck9__c;
                        if(be.ForecastAverageCheckFactor9__c == null  )
                            be.ForecastAverageCheckFactor9__c = ec.DefaultAverageCheckFactor9__c;
                        if(be.ForecastAverageCheck10__c == null )
                            be.ForecastAverageCheck10__c = ec.DefaultAverageCheck10__c;
                        if(be.ForecastAverageCheckFactor10__c == null )
                            be.ForecastAverageCheckFactor10__c = ec.DefaultAverageCheckFactor10__c;
                        if(be.ForecastAverageCheck11__c == null )
                            be.ForecastAverageCheck11__c = ec.DefaultAverageCheck11__c;
                        if(be.ForecastAverageCheckFactor11__c == null )
                            be.ForecastAverageCheckFactor11__c = ec.DefaultAverageCheckFactor11__c;
                        if(be.ForecastAverageCheck12__c == null  )
                            be.ForecastAverageCheck12__c = ec.DefaultAverageCheck12__c;
                        if(be.ForecastAverageCheckFactor12__c == null  )
                            be.ForecastAverageCheckFactor12__c = ec.DefaultAverageCheckFactor12__c;
                        if(be.ForecastAverageCheck13__c == null )
                            be.ForecastAverageCheck13__c = ec.DefaultAverageCheck13__c;
                        if(be.ForecastAverageCheckFactor13__c == null )
                            be.ForecastAverageCheckFactor13__c = ec.DefaultAverageCheckFactor13__c;
                        if(be.ForecastAverageCheck14__c == null  )
                            be.ForecastAverageCheck14__c = ec.DefaultAverageCheck14__c;
                        if(be.ForecastAverageCheckFactor14__c == null  )
                            be.ForecastAverageCheckFactor14__c = ec.DefaultAverageCheckFactor14__c;
                        if(be.ForecastAverageCheck15__c == null  )
                            be.ForecastAverageCheck15__c = ec.DefaultAverageCheck15__c;
                        if(be.ForecastAverageCheckFactor15__c == null )
                            be.ForecastAverageCheckFactor15__c = ec.DefaultAverageCheckFactor15__c;
                       }
                        
                        if(be.FunctionRoomSetupName__c == null || be.FunctionRoomSetupName__c == '')
                            be.FunctionRoomSetupName__c = ec.DefaultSetup__r.Name;
                        if(be.EndTime12Hour__c == null )
                            be.EndTime12Hour__c = ec.DefaultEndTime12Hour__c;   
                        if(be.EndTime24Hour__c == null )
                            be.EndTime24Hour__c = ec.DefaultEndTime24Hour__c;   
                        if(be.StartTime12Hour__c == null )
                            be.StartTime12Hour__c = ec.DefaultStartTime12Hour__c;   
                        if(be.StartTime24Hour__c == null )
                            be.StartTime24Hour__c = ec.DefaultStartTime24Hour__c;   
                        if(be.IsPosted__c != true)
                            be.IsPosted__c = ec.DefaultIsPosted__c;
                    }
                    
                    if(
                        (be.ForecastAverageCheck1__c != null && be.ForecastAverageCheckFactor1__c == null)
                        || (be.ForecastAverageCheck2__c != null && be.ForecastAverageCheckFactor2__c == null)
                        || (be.ForecastAverageCheck3__c != null && be.ForecastAverageCheckFactor3__c == null)
                        || (be.ForecastAverageCheck4__c != null && be.ForecastAverageCheckFactor4__c == null)
                        || (be.ForecastAverageCheck5__c != null && be.ForecastAverageCheckFactor5__c == null)
                        || (be.ForecastAverageCheck6__c != null && be.ForecastAverageCheckFactor6__c == null)
                        || (be.ForecastAverageCheck7__c != null && be.ForecastAverageCheckFactor7__c == null)
                        || (be.ForecastAverageCheck8__c != null && be.ForecastAverageCheckFactor8__c == null)
                        || (be.ForecastAverageCheck9__c != null && be.ForecastAverageCheckFactor9__c == null)
                        || (be.ForecastAverageCheck10__c != null && be.ForecastAverageCheckFactor10__c == null)
                        || (be.ForecastAverageCheck11__c != null && be.ForecastAverageCheckFactor11__c == null)
                        || (be.ForecastAverageCheck12__c != null && be.ForecastAverageCheckFactor12__c == null)
                        || (be.ForecastAverageCheck13__c != null && be.ForecastAverageCheckFactor13__c == null)
                        || (be.ForecastAverageCheck14__c != null && be.ForecastAverageCheckFactor14__c == null)
                        || (be.ForecastAverageCheck15__c != null && be.ForecastAverageCheckFactor15__c == null)
                    )
                        trigger.new[0].addError(Label.BookingEventForecastFactorIssue);
                }
            }
        }        
    }
    
    //Sets 24 hour times from 12 hour times, or vice/versa.
    //Validates presence of both times or neither.
    //Extends event date to next day if event goes past midnight.
    public class SetEventTimes implements Triggers.Handler {
  
        public void handle() {

            if (!Triggers.getBoolParam('SetEventTimes', true)) { 
                return;
            }

            for (BookingEvent__c newEvent : (List<BookingEvent__c>)(trigger.New))
            {

                //If a start/end time is specified and no end/start time is specified throw error. 
                if ((newEvent.StartTime12Hour__c == null && newEvent.EndTime12Hour__c != null) || (newEvent.StartTime12Hour__c != null && newEvent.EndTime12Hour__c == null) ||
                    (newEvent.StartTime24Hour__c == null && newEvent.EndTime24Hour__c != null) || (newEvent.StartTime24Hour__c != null && newEvent.EndTime24Hour__c == null)) {
                    system.debug('Bad Data entered: must specify both start and end times'); 
                    newEvent.addError(Label.SpecifyStart_EndTime);
                    continue;
                }

                if (Trigger.isInsert)
                {
                    if (!((newEvent.StartTime12Hour__c == null && newEvent.EndTime12Hour__c == null) && 
                        (newEvent.StartTime24Hour__c == null && newEvent.EndTime24Hour__c == null))) {

                        //If 12 hour is not specified and 24 hour is -- update 12hr times
                        if ((newEvent.StartTime12Hour__c == null && newEvent.EndTime12Hour__c == null) && (newEvent.StartTime24Hour__c != null && newEvent.EndTime24Hour__c != null))
                        {
                            newEvent.StartTime12Hour__c = Ni.convert24To12Hour(newEvent.StartTime24Hour__c) ;
                            newEvent.EndTime12Hour__c = Ni.convert24To12Hour(newEvent.EndTime24Hour__c);
                        }
                        
                        //If 12 hour is specified -- update 24hr times
                        else if (newEvent.StartTime12Hour__c != null && newEvent.EndTime12Hour__c != null){
                            newEvent.StartTime24Hour__c = Ni.convert12To24Hour(newEvent.StartTime12Hour__c);
                            newEvent.EndTime24Hour__c = Ni.convert12To24Hour(newEvent.EndTime12Hour__c);
                        }

                    }

                }

                if(Trigger.isUpdate)
                {
                    BookingEvent__c oldEvent = (BookingEvent__c)Trigger.oldMap.get(newEvent.Id);

                    //Check to see if all picklist values are now null and the dateTime fields are filled in. 
                    if(((newEvent.StartTime12Hour__c == null && newEvent.EndTime12Hour__c == null) && (oldEvent.StartTime12Hour__c != null && oldEvent.EndTime12Hour__c != null)) ||
                    ((newEvent.StartTime24Hour__c == null && newEvent.EndTime24Hour__c == null) && (oldEvent.StartTime24Hour__c != null && oldEvent.EndTime24Hour__c != null)))
                    {
                        //times were removed, set all values to blank and break from trigger.
                        newEvent.StartTime12Hour__c = '';
                        newEvent.StartTime24Hour__c = '';
                        newEvent.EndTime12Hour__c = '';
                        newEvent.EndTime24Hour__c = '';
                        continue;

                    }

                    //if they have updated the 24 hour startTime and not the 12
                    if((oldEvent.StartTime24Hour__c != newEvent.StartTime24Hour__c) && (oldEvent.StartTime12Hour__c == newEvent.StartTime12Hour__c)) {
                        newEvent.StartTime12Hour__c = Ni.convert24To12Hour(newEvent.StartTime24Hour__c);
                    }
                    //if they have updated the 12 hour startTime
                    else if(oldEvent.StartTime12Hour__c != newEvent.StartTime12Hour__c ) {
                        newEvent.StartTime24Hour__c = Ni.convert12To24Hour(newEvent.StartTime12Hour__c);
                    }
                    //if they have updated the 24 hour end time and not 12 hr
                    if((oldEvent.EndTime24Hour__c != newEvent.EndTime24Hour__c) && (oldEvent.EndTime12Hour__c == newEvent.EndTime12Hour__c)) {
                        newEvent.EndTime12Hour__c = Ni.convert24To12Hour(newEvent.EndTime24Hour__c);
                    }
                    
                    //if they have updated the 12 hour end time
                    else if(oldEvent.EndTime12Hour__c != newEvent.EndTime12Hour__c) {
                        newEvent.EndTime24Hour__c = Ni.convert12To24Hour(newEvent.EndTime12Hour__c);        
                    }

                }
           
                //Extend event end date if end time goes past midnight
                if (newEvent.StartTime24Hour__c != null && newEvent.StartTime24Hour__c !='' && newEvent.EndTime24Hour__c != null && newEvent.EndTime24Hour__c !='') {
                    Double startTime = double.valueOf(newEvent.StartTime24Hour__c.substringBefore(':'))*100 + double.valueOf(newEvent.StartTime24Hour__c.substringAfter(':'));
                    Double endTime = double.valueOf(newEvent.EndTime24Hour__c.substringBefore(':'))*100 + double.valueOf(newEvent.EndTime24Hour__c.substringAfter(':'));
                    if (startTime > endTime && newEvent.StartDate__c == newEvent.EndDate__c)
                        newEvent.EndDate__c = newEvent.EndDate__c.addDays(1);
                }

            }   
        }
    }


    public static void setPrivateInventorySetting(Boolean val) {
         
        try {
            NiProtected__c niProtectedSettings = NiProtected__c.getValues(BookingEventcls.protectedCustomSettingName );
            niProtectedSettings.LDVFRInventory__c = val;
            
            Security.UpdateWithFLSCheck(niProtectedSettings);
        }
        catch (exception e) {}
              
    
    }
    
    public static void setPrivateInventoryPopulatedSetting(Boolean val) {
         
        try {
            NiProtected__c niProtectedSettings = NiProtected__c.getValues(BookingEventcls.protectedCustomSettingName );
            niProtectedSettings.LDVFRInventoryWasPopulated__c = val;
            
            Security.UpdateWithFLSCheck(niProtectedSettings);
        }
        catch (exception e) {}
              
    
    }
    
    
    public static boolean getPrivateInventorySetting() {
        boolean returnInventorySetting = false;
        try {
            NiProtected__c niProtectedSettings = NiProtected__c.getValues(BookingEventcls.protectedCustomSettingName );
            returnInventorySetting  = niProtectedSettings.LDVFRInventory__c;
        }
        catch (exception e) {}
        return returnInventorySetting;
    }
    
    
    public static boolean getPrivateInventoryPopulatedSetting() {
        boolean returnInventoryPopulatedSetting = false;
        try {
            NiProtected__c niProtectedSettings = NiProtected__c.getValues(BookingEventcls.protectedCustomSettingName );
            returnInventoryPopulatedSetting = niProtectedSettings.LDVFRInventoryWasPopulated__c;
        }
        catch (exception e) {}
        return returnInventoryPopulatedSetting;    
    }

    
    /*    
    public method for generating inventory records
    bookingEvents:         the source events for which the inventory records will be generated
    maxRecords:            the maximum number of records to generate.  this variable exists so the system can quit before a DML error (10,000 records) occurs.  
                                The batch process will always pick up any skipped records in its next batch, so quitting in that context is safe.
                                In the regular UI, it might be better to throw a hard error, instead of quietly skipping records.
    updateIds:             ids of existing records.  This variable is provided so the generated records can be treated as updates.                                
    */
    public static list<EventFunctionroomDate__c> buildFunctionroomInventoryRecords(List<bookingEvent__C> bookingEvents, integer maxRecords, List<EventFunctionroomdate__C> updateIds) {
       list<EventFunctionroomDate__c> returnEFRs = new list<EventFunctionroomDate__c>();       

            boolean idsIsNull = (updateIds == null);

            for(bookingEvent__C e : bookingEvents) {      
                if (e.startDate__C == null || e.enddate__C == null  || e.FunctionRoom__c == null) continue;   
                integer duration =  e.startdate__C.daysBetween(e.enddate__C) +1;     
                if (returnEFRs.size() + duration >= maxRecords) break;
                for (integer i = 0; i < duration; i++) { 
                    date efrDate = e.startdate__C.addDays(i);        
                    EventFunctionroomDate__c newEfr = idsIsNull ? new EventFunctionroomDate__c() : new EventFunctionroomDate__c(id=updateIds[i].id);
                    newEfr.name = e.startdate__C+ '~' + e.id + '~' + e.functionroom__C + '~' + efrDate ;
                    newEfr.event__C = e.id;
                    newEfr.eventdate__C = efrDate;
                    newEfr.functionroom__C = e.functionroom__C;                     
                    string stringDate = efrDate.year() +  string.valueof(efrDate.month()).leftPad(2).replace(' ', '0') + string.valueOf(efrDate.day()).leftPad(2).replace(' ', '0');                    
                    newEfr.eventDateIndexed__C =stringDate;
                    newEfr.dateFunctionroomId__C = stringDate + e.functionroom__C;
                    returnEFRs.add(newEfr);
                }                         
             }        
        
        return returnEFRs;    
     } 
     
    
    // When an event is cancelled and 'isRemoveCancelledEventsFromBEOs__c' property setting == true, detach the BookingDocument from the booking event.
    public class BookingEventRemoveBeo implements Triggers.Handler {
        public void handle() {
 
            List<BookingEvent__c> events = (List<BookingEvent__c>)Trigger.New;
            if (!events.IsEmpty()) {

 
                for (BookingEvent__c event : events) {
                    BookingEvent__c oldEvent = (BookingEvent__c)Trigger.oldMap.get(event.Id);
            
                    // If eventStatus was changed to 'Event Cancelled' then saved, remove all beo and BC fields on the event record
                    if ((event.eventStatus__c == 'Event Cancelled' && oldEvent.eventStatus__c != 'Event Cancelled') && 
                        queriedInfo.Locations.containsKey(event.Location__c) && queriedInfo.Locations.get(event.Location__c).IsRemoveCancelledEventsFromBEOs__c == true){
                        if (event.beo__c != null)
                            event.beo__c = null;
                        if (event.BanquetCheck__c != null)
                            event.banquetCheck__c = null;
                    }
                }
            }               
        }
    }
 
    
    public class FunctionroomInventory implements Triggers.Handler {
        set<string> relevantFields = new set<string>{'startDate__c', 'endDate__c', 'functionroom__c', 'StartTime12Hour__c', 'EndTime12Hour__c', 
                                                       'StartTime24Hour__c', 'EndTime24Hour__c', 'CustomEventStatusName__c', 'EventStatus__c',
                                                       'SetupDuration__c', 'TeardownDuration__c' };
        
        public void handle() {
            system.debug(loggingLevel.info, ' Entered FunctionroomInventory ');
            if(!trigger.isDelete) {
                if (!triggers.testTriggerChange(trigger.isInsert, trigger.old, trigger.new, this.relevantFields)) return;
            }
            
            if (trigger.isInsert) {
                writeFunctionroomInventory(trigger.new, trigger.isUpdate);   
            }
            if (trigger.isUpdate) {
                replaceFunctionroomInventory(trigger.oldMap, trigger.newMap, trigger.isUpdate);   
            }
            if (trigger.isDelete) {
                deleteFunctionroomInventory(trigger.old);
            }                        
        }  
       
              
        public void replaceFunctionroomInventory(map<id, sobject> oldMap, map<id, sobject> newMap, boolean triggerIsUpdate) {            
           list<EventFunctionroomDate__c> allUpdates = new list<EventFunctionroomDate__c>();
           list<BookingEvent__c> deleteAndInserts = new list<BookingEvent__c>();
           system.debug(loggingLevel.info, ' Entered replaceFunctionroomInventory');
           
           /*
           list<BookingEvent__c> InventoryPerEvent = [SELECT Id, name,
                                                       (SELECT id, name , event__C, functionroom__C, eventdate__c, eventdateindexed__C, dateFunctionroomId__C
                                                            FROM EventFunctionroomDates__r )
                                                    FROM bookingEvent__c 
                                                    WHERE id in : newMap.keySet() 
                                                   ]; 
           */
           for (bookingEvent__C e : [SELECT Id, name,
                                        (SELECT id, name , event__C, functionroom__C, eventdate__c, eventdateindexed__C, dateFunctionroomId__C
                                             FROM EventFunctionroomDates__r )
                                     FROM bookingEvent__c 
                                     WHERE id in : newMap.keySet() 
                                    ]) 
           {
               bookingEvent__C newBookingEvent = (bookingEvent__C)newMap.get(e.id);
               if (newBookingEvent.startDate__C == null || newBookingEvent.enddate__C == null || newBookingEvent.functionroom__C == null) continue;   
               integer newDuration = newBookingEvent.startDate__C.daysBetween(newBookingEvent.endDate__C) + 1;     
               list<EventFunctionroomDate__C> oldInventory = new list<EventFunctionroomDate__C>();
               //the loop below is due to the warning about child records in this link:  https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_loops_for_SOQL.htm
               for (EventFunctionroomDate__C efr : e.EventFunctionroomDates__r) oldInventory.add(efr);
                
               if (newDuration == oldInventory.size()) {
                   system.debug(loggingLevel.info, ' replaceFunctionroomInventory newDuration  matches; '+ newDuration );
                   list<EventFunctionroomDate__C> toUpdate = buildFunctionroomInventoryRecords(new list<bookingEvent__C>{newBookingEvent}, 10000, oldInventory);                    
                   allUpdates.addall(toUpdate);
               }
               else {
                   system.debug(loggingLevel.info, ' replaceFunctionroomInventory newDuration  mismatch; '+ newDuration );
                   deleteAndInserts.add(newBookingEvent);
               }
           
                 }

                boolean hasError = false;
                if (!allUpdates.isempty() ) {
                    try {
                        NI.updateWithRetry(allUpdates, 5);
                    }
                    catch (exception e) {
                        hasError = true;
                        throw new Ni.NiException(Label.BookingEventFunctionRoomDayCannotSave);
                    }
                }
                if (deleteAndInserts.size() >0) writeFunctionroomInventory(deleteAndInserts, triggerIsUpdate);
            }
           
        public void writeFunctionroomInventory(list<BookingEvent__c> events, boolean triggerIsUpdate) {
            if (events == null || events.size() ==0) return;        
        
            list<EventFunctionroomDate__c> efr = new list<EventFunctionroomDate__c>();   
                            
            efr = BookingEventcls.buildFunctionroomInventoryRecords(events, 11000, null);                                   
            if (triggerIsUpdate) deleteFunctionroomInventory(events); //skip this for inserts
            
            boolean hasError = false;
            if (!efr.isempty() ) {
                try {
                    NI.insertWithRetry(efr, 5);
                }
                catch (exception e) {
                    hasError = true;
                    throw new Ni.NiException(Label.BookingEventFunctionRoomDayCannotSave);
                }
            }

        }
           
        public void deleteFunctionroomInventory(list<BookingEvent__c> events) {
            if (events == null || events.size() ==0) return;        
           
            boolean hasError = false;
            try {
                NI.deleteWithRetry(new list<EventFunctionroomDate__c> ([select id from EventFunctionroomDate__c  where Event__C in : events]), 5);
            }
            catch (exception e) {
                hasError = true;
                throw new Ni.NiException(Label.BookingEventFunctionRoomDayCannotSave);
            }

        }  
    }


    private static list<bookingEvent__C> getEventsFromFunctionroomInventory( Set<Id> roomsToCheck, Date sDate, Date eDate, Set<String> validStatus)   {
        List<BookingEvent__c> existingEvents = new List<BookingEvent__c>();
        set<string> dateSet = new set<string>();
        set<string> dateFRs = new set<string>();
    
        integer duration = sdate.daysBetween(eDate) +1;     
        for (integer i = 0 ; i < duration; i++ ) { 
            date efrDate = sdate.addDays(i);        
            string stringDate = efrDate.year() + string.valueof(efrDate.month()).leftPad(2).replace(' ', '0') + string.valueOf(efrDate.day()).leftPad(2).replace(' ', '0');
            dateSet.add(stringDate);
            for (id frid : roomsToCheck) {
                string datefrid = stringDate + frid;
                dateFRs.add(dateFrid);            
            }
        }
    
     existingEvents = [Select StartTime24Hour__c, 
                                                    StartTime12Hour__c,
                                                    StartDate__c, 
                                                    SetupDuration__c, 
                                                    TeardownDuration__c,
                                                    Name, 
                                                    Location__c, 
                                                    Location__r.ConflictCheckProspects__c,
                                                    Location__r.CreateOptionsOnConflict__c,
                                                    IsOwnerLocked__c, 
                                                    IsMoveable__c, 
                                                    IsDeleted, 
                                                    Id, 
                                                    FunctionRoom__c,
                                                    FunctionRoom__r.Name,
                                                    FunctionRoomOption__c,
                                                    FunctionRoom__r.IsCombinationRoom__c,
                                                    FunctionRoom__r.AllowMultiGroupBlocking__c, 
                                                    EventStatus__c, 
                                                    EventMessage__c,
                                                    EndTime24Hour__c, 
                                                    EndTime12Hour__c,
                                                    EndDate__c, 
                                                    CustomEventStatusName__c,
                                                    Booking__c,
                                                    Booking__r.Name 
                                                    FROM BookingEvent__c 
                                                    WHERE id in (select event__C 
                                                        FROM EventFunctionRoomdate__C 
                                                        WHERE 
                                                        //FunctionRoom__c IN :roomsToCheck 
                                                        event__r.EventStatus__c IN :validStatus 
                                                        //AND eventDateIndexed__C in :dateSet
                                                        AND dateFunctionroomId__C IN : dateFRs
                                                        )
                                                   ];
        return existingEvents;
    
    }


    /*
        Josh Clairmont 6/17/13
        Below are the two classes that provide conflict checking and updating of messages on events
        
        
    */
    
        public class BookingEventConflictCheck implements Triggers.Handler {
        public void handle() {
            system.debug('##!#!#!#!#!#!# Entered Conflict Check ');
            
            
            system.debug('Events in trigger.new' + (List<BookingEvent__c>)(trigger.New));
            List<BookingEvent__c> newEvents = (List<BookingEvent__c>)(trigger.New);
            Set<Id> eventProperties = new Set<Id>();
            Date sDate;
            Date eDate; 
            Set<String> validStatus = new Set<String>{'Definite', 'Tentative'};
            Set<Id> roomsToCheck = new Set<Id>();
            
            //get the max and minimum start and end dates on the bookings
            //add all properties to set
            
            for(BookingEvent__c be : newEvents)
            {     
                roomsToCheck.add(be.FunctionRoom__c);
                            
                if(sDate == null || sDate > be.StartDate__c)
                    sDate = be.StartDate__c;
                if(eDate == null || eDate < be.EndDate__c)
                    eDate = be.EndDate__c;
                eventProperties.add(be.Location__c);
            }

            //adding this boolean here will force the trigger to only conflict check against the events that were updated in the original execution context. 
            //The class RollupUpdateOnBooking calls another update on all events on the booking. we shouldn't have to do checks on those. Events as they
            //are only having revenue rollups updated.
            system.debug('performing map building for conflict checking');                                                  
            List<FunctionRoom__c> functionRooms = queriedInfo.FunctionRooms.values();
                                                    
            //List<ComboRoomComponent__c> comboRooms = queriedInfo.ComboRoomComponents.values();
            List<ComboRoomComponent__c> comboRooms =
                        [SELECT 
                            ComboFunctionRoom__c, ComboFunctionRoom__r.Location__c, 
                            ComboFunctionRoom__r.Name, ComponentFunctionRoom__c, 
                            ComponentFunctionRoom__r.Name, Id, Name  
                        FROM ComboRoomComponent__c
                        WHERE ComboFunctionRoom__r.Location__c IN : eventProperties];
            system.debug(loggingLevel.warn, 'combo count = ' +comboRooms.size() );          
            
            
            //get a map of functionroomsetups to do capacity calculations
           
            //create a map of FunctionRoomSetup__c with the name as the key,
            //you will need to search based on the name of the setupvalue and functionroom.
            map<string, map<Id, FunctionRoomSetup__c>> functionRoomSetupMap = new map<string, map<Id, FunctionRoomSetup__c>>(); 
            // map contains the ID of a location and a corresponding list of all function rooms contained at the property
            map<Id, Set<FunctionRoom__c>> locationRoomMap = new Map<Id, Set<FunctionRoom__c>>();
            //map contains the ID of a function room and a list of all the corresponding bookingEvents booked in that room 
            map<Id, Set<BookingEvent__c>> functionRoomMap = new Map<ID, Set<BookingEvent__c>>();
            //Map contains the unassigned function room for each property
            map<Id, FunctionRoom__c> unassignedLocationMap = new Map<Id, FunctionRoom__c>();
            //map of FunctionRoom ID's and the corresponding functionRoom object
            map<Id, FunctionRoom__c> frIDMatch = new Map<Id, FunctionRoom__c>();
            //the following map is constructed as: <FunctinoRoomId, List of rooms that can't be sold if key is sold>
            map<Id, Set<Id>> comboRoomAssociationMap = new Map<Id, Set<Id>>(); 
            
            
            /**
            We're taking the FunctionRoomsSetup collection out of the BookingEventsDataStore object 
            and putting the SOQL query here because the collection in the datastore used excessive
            heap space and was alive for as long as the the trigger was in-memory. This new technique 
            uses the lower-cost in-line for loop query, and all memory used by the method is released 
            when the method exits.  In taking this approach, we increase the SOQL count because the 
            FunctionRoomsSetup collection is required in two places in the trigger. But increasing the SOQL 
            count by one is preferrable to the alternative which was runtime heap errors.
            */

            // This loop will create a nested map configured like the following: 
            // <SetupValueName, map<FunctionRoomId, FunctionRoomSetupId
            // 
            for(FunctionRoomSetup__c frs : [SELECT 
                         SetupDuration__c, TeardownDuration__c, Name, Id,
                         FunctionRoomSetupName__c, MinCapacity__c,
                         MaxCapacity__c, FunctionRoom__c, FunctionRoom__r.Location__c,
                         FunctionRoom__r.Name
                     FROM FunctionRoomSetup__c
                     where FunctionRoom__C in : roomsToCheck]
                     ){
                if(functionRoomSetupMap.get(frs.FunctionRoomSetupName__c) != null){
                    functionRoomSetupMap.get(frs.FunctionRoomSetupName__c).put(frs.FunctionRoom__c, frs);
                }   
                else{ //parent setup value doesn't exist in map
                    map<Id, FunctionRoomSetup__c> svMap = new map<Id, FunctionRoomSetup__c>();
                    svMap.put(frs.FunctionRoom__c, frs);
                    functionRoomSetupMap.put(frs.FunctionRoomSetupName__c, svMap);
                }
            }
            
            
            //loop assigns function rooms to the location room map and the unassigned map
            for(FunctionRoom__c fr : functionRooms)
            {
                if(fr.Id == fr.Location__r.UnassignedFunctionRoom__c)
                    unassignedLocationMap.put(fr.Location__c, fr);
                if(locationRoomMap.containsKey(fr.Location__c))
                {
                    locationRoomMap.get(fr.Location__c).add(fr);
                }
                else{
                    Set<FunctionRoom__c> frlist = new Set<FunctionRoom__c>();
                    frlist.add(fr);
                    locationRoomMap.put(fr.Location__c, frlist);
                }
                if(fr.Location__r.ConflictCheckProspects__c)
                    validStatus.add('Prospect');
                frIDMatch.put(fr.ID, fr);
            }
            //This builds out a list of all combo/component rooms in the property and generates a map
            //that contains the functionRoom and a list of rooms that will need to be checked if the 
            //current event is in that room. 
            for(ComboRoomComponent__c crc : comboRooms)
            {
                if(!comboRoomAssociationMap.containsKey(crc.ComboFunctionRoom__c))
                {
                    Set<Id> componentList = new Set<Id>(); 
                    componentList.add(crc.ComponentFunctionRoom__c);
                    componentList.add(crc.ComboFunctionRoom__c);
                    comboRoomAssociationMap.put(crc.ComboFunctionRoom__c, componentList);
                }
                else{
                    comboRoomAssociationMap.get(crc.ComboFunctionRoom__c).add(crc.ComponentFunctionRoom__c);
                }
                
                //add the component to the list of rooms
                if(!comboRoomAssociationMap.containsKey(crc.ComponentFunctionRoom__c))
                {
                    Set<Id> comboList = new Set<Id>(); 
                    comboList.add(crc.ComboFunctionRoom__c);
                    comboList.add(crc.ComponentFunctionRoom__c);
                    comboRoomAssociationMap.put(crc.ComponentFunctionRoom__c, comboList);
                }
                else{
                    comboRoomAssociationMap.get(crc.ComponentFunctionRoom__c).add(crc.ComboFunctionRoom__c);
                    //If the componenet room already exists in the map this will make sure other comborooms that share the 
                    //component will be checked for conflicts. 
                    for(Id i : comboRoomAssociationMap.get(crc.ComponentFunctionRoom__c)){
                        comboRoomAssociationMap.get(i).add(crc.ComboFunctionRoom__c);
                        comboRoomAssociationMap.get(crc.ComboFunctionRoom__c).add(i);
                    }
        
                }
        
            }
            Set<Id> tempSet = new Set<Id>();
            for(Id fr: roomsToCheck){
                if(fr != null && comboRoomAssociationMap.containsKey(fr)){
                    for(Id i : comboRoomAssociationMap.get(fr)){
                        tempSet.add(i);
                    }
                }
            }
            roomsToCheck.addAll(tempSet);
        
            system.debug('Conflict check query bind variables'); 
            system.debug('Conflict check query - eventProperties: '+eventProperties); 
            system.debug('Conflict check query - roomsToCheck: '+roomsToCheck);
            system.debug('Conflict check query - validStatus: '+validStatus); 
            system.debug('Conflict check query - sDate: '+sDate); 
            system.debug('Conflict check query - eDate: '+eDate);
            system.debug('Conflict check query executing query');   
                       
                        //query for all events on the property where 
            boolean bFromEventFunctionroomDateTable = false;            
            bFromEventFunctionroomDateTable  = BookingEventcls.getPrivateInventorySetting();
                       
            
            List<BookingEvent__c> existingEvents = new List<BookingEvent__c> ();
            if ( bFromEventFunctionroomDateTable ) {  //false &&
                system.debug(loggingLevel.info, 'getting inventory from inventory table');
                existingEvents = bookingEventcls.getEventsFromFunctionroomInventory(roomsToCheck, sDate, eDate, validStatus);
            }
            else {                        
                system.debug(loggingLevel.info, 'getting inventory from Event table');
                existingEvents = [Select StartTime24Hour__c, 
                                                    StartTime12Hour__c,
                                                    StartDate__c, 
                                                    SetupDuration__c, 
                                                    TeardownDuration__c,
                                                    Name, 
                                                    Location__c, 
                                                    Location__r.ConflictCheckProspects__c,
                                                    Location__r.CreateOptionsOnConflict__c,
                                                    IsOwnerLocked__c, 
                                                    IsMoveable__c, 
                                                    IsDeleted, 
                                                    Id, 
                                                    FunctionRoom__c,
                                                    FunctionRoom__r.Name,
                                                    FunctionRoomOption__c,
                                                    FunctionRoom__r.IsCombinationRoom__c,
                                                    FunctionRoom__r.AllowMultiGroupBlocking__c, 
                                                    EventStatus__c, 
                                                    EventMessage__c,
                                                    EndTime24Hour__c, 
                                                    EndTime12Hour__c,
                                                    EndDate__c, 
                                                    CustomEventStatusName__c,
                                                    Booking__c,
                                                    Booking__r.Name From BookingEvent__c 
                                                    WHERE Location__c IN :eventProperties 
                                                    AND FunctionRoom__c IN :roomsToCheck AND EventStatus__c IN :validStatus 
                                                    AND
                                                    ((EndDate__c >=: sDate) AND (StartDate__c <=: eDate ))];                                                  
            }
            
            //create a map of functionRooms and the corresponding list of bookingEvents associated with them.
            //if the functionRoom is a comboRoom add the parent room to the map of ID's and associate the ..
            //booking event with that room as well;
            for(BookingEvent__c ev :  existingEvents)
                         
                        
            {
                
                system.debug('existingEvents: ' + ev);
                if(!ev.FunctionRoom__r.AllowMultiGroupBlocking__c&&(ev.EventStatus__c == 'Definite' || ev.EventStatus__c == 'Tentative' || (ev.Location__r.ConflictCheckProspects__c == true && ev.EventStatus__c == 'Prospect')))
                {
                    if(!functionRoomMap.containsKey(ev.FunctionRoom__r.Id))
                    {
                        Set<BookingEvent__c> bel = new Set<BookingEvent__c>();
                        bel.add(ev);
                        functionRoomMap.put(ev.FunctionRoom__c, bel);   
                        
                    }
                    else{
                        functionRoomMap.get(ev.FunctionRoom__c).add(ev);
                    }
                }
                
            }

            //This loop will preform the actual conflict checking on the incoming/updating bookingevents
            Map<Id, BookingEvent__c> eventsToUpdate = new Map<Id, BookingEvent__c>(); 
            for(BookingEvent__c event : newEvents)
            {
                //set the message to what 
                String oldMessage = event.EventMessage__c;
                String turnTimeMessage = '';
                String conflictMessage = '';
                string capacityMessage = '';
                system.debug('conflict check event loop: ' + event.Name); 

                //This boolean will determine if conflict checking needs to occur on an event
                //if the trigger is an update and any startDate/Time, endDate/Time, FunctionRoom, EventStatus, Booking, Property have changed
                //then conflictChecking needs to be performed
                boolean runConflictCheck = true;
                if(Trigger.isUpdate){
                    BookingEvent__c oldEvent = (BookingEvent__c)Trigger.oldMap.get(event.ID);
                    if(event.StartDate__c == oldEvent.StartDate__c && event.StartTime12Hour__c == oldEvent.StartTime12Hour__c &&event.StartTime24Hour__c == oldEvent.StartTime24Hour__c 
                    && event.EndDate__c == oldEvent.EndDate__c && event.EndTime12Hour__c == oldEvent.EndTime12Hour__c && event.EndTime24Hour__c == oldEvent.EndTime24Hour__c 
                    && event.Booking__c == oldEvent.Booking__c && event.EventStatus__c == oldEvent.EventStatus__c && event.Property__c == oldEvent.Property__c 
                    && event.FunctionRoom__c == oldEvent.FunctionRoom__c && event.FunctionRoomSetupName__c == oldEvent.FunctionRoomSetupName__c
                    && event.SetupDuration__c == oldEvent.SetupDuration__c && event.TeardownDuration__c == oldEvent.TeardownDuration__c){
                        system.debug('Not Running Conflict Checking!!!');
                        runConflictCheck = false; 
                    }
                    //if conflictChecking is going to happen then reset the EventMessage to blank and rebuild the message
                    else{
                        system.debug('Running Conflict Checking!!!');
                        event.EventMessage__c = '';
                    }
                    
                }
                
                string messageOptionEvent = '';
                //bookingEvent room is part of a combination room. not only do you need to check the current 
                //function room for conflicts but you must check all component function rooms for conflicts 
                //as well
                if(event.FunctionRoom__c != null && comboRoomAssociationMap.containsKey(event.FunctionRoom__c))
                {
                    for(Id i : comboRoomAssociationMap.get(event.FunctionRoom__c))
                    {
                        if(functionRoomMap.containsKey(i))
                        {
                            for(BookingEvent__c cEvent: functionRoomMap.get(i))
                            {
                                system.debug('Event Room: ' + event.FunctionRoom__c + '\n\nChecking for conflicts in: ' + cEvent.FunctionRoom__r.Name);
                                //if the parentBooking is the same for the conflictingevents then proceed because those events can overlap
                                if(cEvent.Booking__c != event.Booking__c && (event.EventStatus__c == 'Definite' || event.EventStatus__c == 'Tentative' || (event.EventStatus__c =='Prospect' && cEvent.Location__r.ConflictCheckProspects__c == true)))
                                {
                                    //check to see if the event is in conflict
                                    if(checkForTimeConflicts(event.StartTime24Hour__c, cEvent.StartTime24Hour__c, event.EndTime24Hour__c, cEvent.EndTime24Hour__c,
                                                            event.StartDate__c, cEvent.StartDate__c, event.EndDate__c, cEvent.EndDate__c ) && runConflictCheck)
                                    {
                                        //set the functionRoomOption to the functionRoom
                                        if(cEvent.Location__r.CreateOptionsOnConflict__c && event.FunctionRoom__c != unassignedLocationMap.get(event.Location__c).Id)
                                        {
                                            System.Debug('Set Function Room Option: ' + frIDMatch.get(event.FunctionRoom__c).Name);
                                            event.FunctionRoomOption__c = event.FunctionRoom__c;
                                            messageOptionEvent = Label.BookingEventCreateOptionMessage.replace('{0}', frIDMatch.get(event.FunctionRoom__c).Name);
                                        }
                                        //set functionRoom to be the unassigned function room for the property. 
                                        event.FunctionRoom__c = unassignedLocationMap.get(event.Location__c).Id;
                                        // you must fill in the data on conflictig event
                                        string message = Label.BookingEventConflictWarningMessage; 
                                        message = message.replace('{0}', cEvent.Booking__r.Name); //{0} = Booking Name
                                        message = message.replace('{1}', cEvent.Name); //{1} = Event Name
                                        message = message.replace('{2}', cEvent.startDate__c.format()); //{2} = start date
                                        message = message.replace('{3}', cEvent.StartTime12Hour__c); //{3} = 12 hour start time
                                        message = message.replace('{4}', cEvent.StartTime24Hour__c); //{4} = 24 hour start time
                                        conflictMessage = message + (messageOptionEvent != '' ? ' ' : '') + messageOptionEvent;
                                        break;  
                                    }
                                    //if there is no conflict check the setup and teardown overlap. 
                                    else{
                                        //add setup and teardown times to the start and ends of both events and check for soft conflict here
                                        //if a conflict occurs a notification will be appended to the eventMessage field to notify the user. 
                                        if(checkForTimeConflictsWithTurnTimes(event.StartTime24Hour__c, Integer.valueOf(event.SetupDuration__c),
                                        cEvent.StartTime24Hour__c, Integer.valueOf(cEvent.SetupDuration__c),
                                        event.EndTime24Hour__c, Integer.valueOf(event.TeardownDuration__c), 
                                        cEvent.EndTime24Hour__c, Integer.valueOf(cEvent.TeardownDuration__c),
                                        event.StartDate__c, cEvent.StartDate__c, event.EndDate__c, cEvent.EndDate__c )){
                                            System.debug('Found conflict with setup teardown times with events: ' + event.Name + ' and ' + cEvent.Name);
                                            if(turnTimeMessage == ''){
                                                turnTimeMessage = (Label.SetupTeardownConflictMessage + cEvent.Booking__r.Name +' ('+cEvent.Name+')');
                                            }
                                            else{
                                                turnTimeMessage += (', ' + cEvent.Booking__r.Name + ' ('+cEvent.Name+')');
                                            }
                                        }   
                                    }
                                }
                            }
                        }
                    }
                }
                
                //if event room is not part of a combination room you only need to check the current functionroom
                else 
                {
                    if(event.FunctionRoom__c !=  null && functionRoomMap.containsKey(event.FunctionRoom__c))
                    {                   
                        for(BookingEvent__c cEvent: functionRoomMap.get(event.FunctionRoom__c))
                        {
                            //if the parentBooking is the same for the conflictingevents then proceed because those events can overlap
                            if(cEvent.Booking__c != event.Booking__c && (event.EventStatus__c == 'Definite' || event.EventStatus__c == 'Tentative' || (event.EventStatus__c == 'Prospect' && cEvent.Location__r.ConflictCheckProspects__c == true)))
                            {
                                if(checkForTimeConflicts(event.StartTime24Hour__c, cEvent.StartTime24Hour__c, event.EndTime24Hour__c, cEvent.EndTime24Hour__c,
                                                        event.StartDate__c, cEvent.StartDate__c, event.EndDate__c, cEvent.EndDate__c ) && runConflictCheck)
                                {
                                    //set the functionRoomOption to the functionRoom
                                    if(cEvent.Location__r.CreateOptionsOnConflict__c && event.FunctionRoom__c != unassignedLocationMap.get(event.Location__c).Id)
                                    {
                                        event.FunctionRoomOption__c = event.FunctionRoom__c;
                                        messageOptionEvent = Label.BookingEventCreateOptionMessage.replace('{0}', frIDMatch.get(event.FunctionRoom__c).Name);
                                    }
                                    //set functionRoom to be the unassigned function room for the property. 
                                    event.FunctionRoom__c = unassignedLocationMap.get(event.Location__c).Id;
                                    //set IsMoveable to true
                                    event.IsMoveable__c = true;
                                    // you must fill in the data on conflictig event
                                    string message = Label.BookingEventConflictWarningMessage; 
                                    message = message.replace('{0}', cEvent.Booking__r.Name); //{0} = Booking Name
                                    message = message.replace('{1}', cEvent.Name); //{1} = Event Name
                                    message = message.replace('{2}', cEvent.startDate__c.format()); //{2} = start date
                                    message = message.replace('{3}', cEvent.StartTime12Hour__c); //{3} = 12 hour start time
                                    message = message.replace('{4}', cEvent.StartTime24Hour__c); //{4} = 24 hour start time
                                    conflictMessage = message + (messageOptionEvent != '' ? ' ' : '') + messageOptionEvent;
                                    break;
                                    //trigger.new[0].addError(eventMessages);
                                    
                                }
                                //if there is no conflict check the setup and teardown overlap. 
                                else{
                                    //add setup and teardown times to the start and ends of both events and check for soft conflict here
                                    //if a conflict occurs a notification will be appended to the eventMessage field to notify the user. 
                                    if(checkForTimeConflictsWithTurnTimes(event.StartTime24Hour__c, Integer.valueOf(event.SetupDuration__c),
                                        cEvent.StartTime24Hour__c, Integer.valueOf(cEvent.SetupDuration__c),
                                        event.EndTime24Hour__c, Integer.valueOf(event.TeardownDuration__c), 
                                        cEvent.EndTime24Hour__c, Integer.valueOf(cEvent.TeardownDuration__c),
                                        event.StartDate__c, cEvent.StartDate__c, event.EndDate__c, cEvent.EndDate__c )){
                                            System.debug('Found conflict with setup teardown times with events: ' + event.Name + ' and ' + cEvent.Name);
                                            if(turnTimeMessage == ''){
                                                turnTimeMessage = (Label.SetupTeardownConflictMessage + cEvent.Booking__r.Name +' ('+cEvent.Name+')');
                                            }
                                            else{
                                                turnTimeMessage += (', ' + cEvent.Booking__r.Name + ' ('+cEvent.Name+')');
                                            }
                                        }
                                    }   
                                }
                            }
                        }
                    }
                    //the following code gets the max/min capacity for the setup/room, then checks to see if the current status is valid 
                    //if its not it sends back a message dictating what the issue is. 
                    boolean roomDefined = false;  
                    boolean setupDefined = false;
                    double max = 0;
                    double min = 0;
                    if(event.FunctionRoom__c != null && frIDMatch.get(event.FunctionRoom__c) != null){
                        max = (frIDMatch.get(event.FunctionRoom__c).DefaultMaxCapacity__c != null ? frIDMatch.get(event.FunctionRoom__c).DefaultMaxCapacity__c : 0 );
                        min = (frIDMatch.get(event.FunctionRoom__c).DefaultMinCapacity__c != null ? frIDMatch.get(event.FunctionRoom__c).DefaultMinCapacity__c : 0 );
                        roomDefined = true;
                    }
        
                    if((!FunctionRoomSetupMap.isEmpty()) && frIDMatch.get(event.FunctionRoom__c) != null && event.FunctionRoomSetupName__c != null && event.FunctionRoomSetupName__c != '' && FunctionRoomSetupMap.get(event.FunctionRoomSetupName__c) != null){
                        system.debug('setting setupName!!!');
                        FunctionRoomSetup__c frs = FunctionRoomSetupMap.get(event.FunctionRoomSetupName__c).get(event.FunctionRoom__c);
                        if(frs != null){
                            max = frs.MaxCapacity__c != null ? frs.MaxCapacity__c : 0 ;
                            min = frs.MinCapacity__c != null ? frs.MinCapacity__c : 0 ;
                        } 
                        setupDefined = true; 
                    }
                    
                    capacityMessage = checkCapacity(event, max, min, roomDefined, setupDefined);
                    system.debug('Original Message: ' + event.EventMessage__c);
                    system.debug('conflictMessage : ' + conflictMessage);
                    system.debug('turnTimeMessage: ' + turnTimeMessage);
                    system.debug('capacityMessage: ' + capacityMessage);
                    system.debug('RunConflictCheck: ' + runConflictCheck);
                    
                    //logic to set the message on the event
                    if(runConflictCheck){
                        if(conflictMessage != ''){
                            event.EventMessage__c = conflictMessage;
                        }
                        else{
                            //if no hard conflict occured check turntime/capacity messages and set if required;
                            if(turnTimeMessage != ''){
                                if(capacityMessage != ''){
                                    event.EventMessage__c = turnTimeMessage + '\r\n' + capacityMessage;
                                }
                                else{
                                    event.EventMessage__c = turnTimeMessage;
                                }
                            }//else if only a capacity message exists set that. 
                            else if(capacityMessage != ''){
                                event.EventMessage__c = capacityMessage;
                            } 
                        }
                    }
                    else{
                        if(event.EventMessage__c != null && (!event.EventMessage__c.contains(Label.BookingEventConflictWarningMessage.substring(0,10))) && turnTimeMessage =='' && capacityMessage == ''){
                            event.EventMessage__c = '';
                        }
                        //if runConflictCheck was false check the setup/teardown and capacity messages
                        //if they exist
                        else{
                            if(turnTimeMessage != ''){
                                if(capacityMessage != ''){
                                    event.EventMessage__c = turnTimeMessage + '\r\n' + capacityMessage;
                                }
                                else{
                                    event.EventMessage__c = turnTimeMessage;
                                }
                            }//else if only a capacity message exists set that. 
                            else if(capacityMessage != ''){
                                event.EventMessage__c = capacityMessage;
                            }
                        }               
                    }
                    system.debug('Final message for event ' + event.Name + ' : ' + event.EventMessage__c);
                }
            }
        }
    
   
   // returns a string describing the capacity issue (over/under) or an empty '' string in the case of no conflict occuring.  
   public static string checkCapacity(BookingEvent__c event, double max, double min, boolean roomDefined, boolean setupDefined) {
       if (updateFromBooking) return '';
        string capacityMessage = '';
        if(event.AgreedAttendance__c != null && event.AgreedAttendance__c != 0){
            if(event.AgreedAttendance__c > max && max != 0){
                if(setupDefined){
                        capacityMessage =  Label.FunctionRoomSetupMaxCapacity.replace('{0}', max.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage =  Label.FunctionRoomMaxCapacity.replace('{0}', max.intValue().format());
                    }
                }
                if(event.AgreedAttendance__c < min){
                    if(setupDefined){
                        capacityMessage =  Label.FunctionRoomSetupMinCapacity.replace('{0}', min.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage =  Label.FunctionRoomMinCapacity.replace('{0}', min.intValue().format());
                    }
                }
            }
            if(event.ForecastAttendance__c != null && event.ForecastAttendance__c != 0){
                capacityMessage = '';
                if(event.ForecastAttendance__c > max && max != 0){
                    if(setupDefined){
                        capacityMessage =  Label.FunctionRoomSetupMaxCapacity.replace('{0}', max.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage =  Label.FunctionRoomMaxCapacity.replace('{0}', max.intValue().format());
                    }
                }
                if(event.ForecastAttendance__c < min){
                    if(setupDefined){
                        capacityMessage =  Label.FunctionRoomSetupMinCapacity.replace('{0}', min.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage =  Label.FunctionRoomMinCapacity.replace('{0}', min.intValue().format());
                    }
                }
            }
            if(event.GuaranteedAttendance__c != null && event.GuaranteedAttendance__c != 0 ){
                capacityMessage = '';
                if(event.GuaranteedAttendance__c > max && max != 0){
                    if(setupDefined){
                        capacityMessage =  Label.FunctionRoomSetupMaxCapacity.replace('{0}', max.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage =  Label.FunctionRoomMaxCapacity.replace('{0}', max.intValue().format());
                    }
                }
                if(event.GuaranteedAttendance__c < min){
                    if(setupDefined){
                        capacityMessage = Label.FunctionRoomSetupMinCapacity.replace('{0}', min.intValue().format());
                    }
                    else if(roomDefined && ! setupDefined){
                        capacityMessage = Label.FunctionRoomMinCapacity.replace('{0}', min.intValue().format());
                    }
                }
            }
            
            return capacityMessage;
   }
    
    
    
   //this function should always pass in the 24 hour time.  
   public static boolean checkForTimeConflicts(string aStartTime, string bStartTime, string aEndTime, string bEndTime, Date aStartDate, Date bStartDate, Date aEndDate, Date bEndDate)
   {
        
        
        //check to make sure all time values are not null, if the times are null then you don't need to conflict check. 
        if(aStartTime == null || bStartTime == null || aEndTime == null || bEndTime == null || aStartDate == null || bStartDate == null || aEndDate == null || bEndDate == null )
            return false; 
        //conversion will give 4 digit number HHMM
        Time ev1StartTime = Time.newInstance(Integer.valueOf(aStartTime.left(2)), Integer.valueOf(aStartTime.right(2)), 0, 0);
        Time ev1EndTime = Time.newInstance(Integer.valueOf(aEndTime.left(2)), Integer.valueOf(aEndTime.right(2)), 0, 0);
        Time ev2StartTime = Time.newInstance(Integer.valueOf(bStartTime.left(2)), Integer.valueOf(bStartTime.right(2)), 0, 0);
        Time ev2EndTime = Time.newInstance(Integer.valueOf(bEndTime.left(2)), Integer.valueOf(bEndTime.right(2)), 0, 0 );
        DateTime ev1StartDateTime = DateTime.newInstanceGmt(aStartDate, ev1StartTime);
        DateTime ev1EndDateTime = DateTime.newInstanceGmt(aEndDate, ev1EndTime);
        DateTime ev2StartDateTime = DateTime.newInstanceGmt(bStartDate, ev2StartTime);
        DateTime ev2EndDateTime = DateTime.newInstanceGmt(bEndDate, ev2EndTime);
        system.debug('checkForTimeConflicts times: '+ ev1StartDateTime +'\n'+ ev1EndDateTime+'\n'+ ev2StartDateTime+'\n'+ ev2EndDateTime);
        return conflictCheck(ev1StartDateTime, ev1EndDateTime, ev2StartDateTime, ev2EndDateTime);
        
   } 
   //this function should always pass in the 24 hour time.  
   //this function formats the dates and times into datetimes then calls conflictCheck which contains the actual 
   //logic for conflict checking. 
   public static boolean checkForTimeConflictsWithTurnTimes(string aStartTime, integer aSetupdur, string bStartTime, integer bSetupdur, string aEndTime, integer aTeardur, string bEndTime, integer bTeardur, Date aStartDate, Date bStartDate, Date aEndDate, Date bEndDate)
   {
        system.debug('turntimes: ' + aSetupdur +'\n'+aTeardur +'\n'+bSetupdur +'\n'+bTeardur);
        //check to make sure all time values are not null, if the times are null then you don't need to conflict check. 
        if(aStartTime == null || bStartTime == null || aEndTime == null || bEndTime == null || aStartDate == null || bStartDate == null || aEndDate == null || bEndDate == null )
            return false; 
        //conversion will give 4 digit number HHMM
        Time ev1StartTime = Time.newInstance(Integer.valueOf(aStartTime.left(2)), Integer.valueOf(aStartTime.right(2)), 0, 0);
        Time ev1EndTime = Time.newInstance(Integer.valueOf(aEndTime.left(2)), Integer.valueOf(aEndTime.right(2)), 0, 0);
        Time ev2StartTime = Time.newInstance(Integer.valueOf(bStartTime.left(2)), Integer.valueOf(bStartTime.right(2)), 0, 0);
        Time ev2EndTime = Time.newInstance(Integer.valueOf(bEndTime.left(2)), Integer.valueOf(bEndTime.right(2)), 0, 0 );
        DateTime ev1StartDateTime = DateTime.newInstanceGmt(aStartDate, ev1StartTime);
        DateTime ev1EndDateTime = DateTime.newInstanceGmt(aEndDate, ev1EndTime);
        DateTime ev2StartDateTime = DateTime.newInstanceGmt(bStartDate, ev2StartTime);
        DateTime ev2EndDateTime = DateTime.newInstanceGmt(bEndDate, ev2EndTime);
        
        //if the setup or teardown is null mark it 0 otherwise use the times provided
        ev1StartDateTime = ev1StartDateTime.addMinutes((aSetupdur != null ? (-1*aSetupdur) : 0));
        ev1EndDateTime = ev1EndDateTime.addMinutes(aTeardur != null ? (aTeardur) : 0);
        ev2StartDateTime = ev2StartDateTime.addMinutes((bSetupdur != null ? (-1*bSetupdur) : 0));
        ev2EndDateTime = ev2EndDateTime.addMinutes(bTeardur != null ? (bTeardur) : 0);
        system.debug('checkForTimeConflictsWithTurnTimes times: '+ ev1StartDateTime +'\n'+ ev1EndDateTime+'\n'+ ev2StartDateTime+'\n'+ ev2EndDateTime);
        return conflictCheck(ev1StartDateTime, ev1EndDateTime, ev2StartDateTime, ev2EndDateTime);   
   } 
   
   //This function contains the actual logic for conflict checking it was pulled out into a seperate function for efficiency
   //it is called by both checkForTimeConflictsWithTurnTimes and checkForTimeConflicts  
   public static boolean conflictCheck(Datetime ev1StartDateTime, Datetime ev1EndDateTime, Datetime ev2StartDateTime, Datetime ev2EndDateTime){
        if( ev2StartDateTime > ev1EndDateTime ){
          system.debug('NO Conflict. Event 2 Begins AFTER Event 1 Ends');
          return false;
        }
        else if( ev2EndDateTime < ev1StartDateTime){
          system.debug('NO Conflict. Event 2 Begins BEFORE Event 1 Starts');
          return false;
        }
        else if( ev2StartDateTime == ev1StartDateTime ){
          system.debug('CONFLICT. Event 2 Starts at the same time Event 1 Starts');
          return true;
        }
        else if( ev2StartDateTime == ev1EndDateTime ){
            //JD - Removing this as being flagged for conflict, per comment on Changeset 18396
          //system.debug('CONFLICT. Event 2 Starts at the same time Event 1 Ends');
          //return true;
          system.debug('NO CONFLICT. Event 2 Starts at the same time Event 1 Ends');
          return false;
        }
        else if( ev2EndDateTime == ev1StartDateTime ){
            //JD - Removing this as being flagged for conflict, per comment on Changeset 18396
          //system.debug('CONFLICT. Event 2 Ends at the same time Event 1 Starts');
          //return true;
          system.debug('NO CONFLICT. Event 2 Ends at the same time Event 1 Starts');
          return false;
        }
        else if( ev2EndDateTime == ev1EndDateTime ){
          system.debug('CONFLICT. Event 2 Ends at the same time Event 1 Ends');
          return true;
        }
        else if( ev2StartDateTime > ev1StartDateTime && ev2StartDateTime < ev1EndDateTime ){
          system.debug('CONFLICT. Event 2 overlaps Event 1 (StartTime Check)');
          return true;
        }
        else if( ev2EndDateTime > ev1StartDateTime && ev2EndDateTime < ev1EndDateTime ){
          system.debug('CONFLICT. Event 2 overlaps Event 1 (EndTime Check)');
          return true;
        }
        else if( ev2StartDateTime > ev1StartDateTime && ev2EndDateTime < ev1EndDateTime ){
          system.debug('CONFLICT. Event 2 falls within Event 1 Start and End times');
          return true;
        }
        else if( ev1StartDateTime > ev2StartDateTime && ev1EndDateTime < ev2EndDateTime){
          system.debug('CONFLICT. Event 2 encompasses Event 1 Start and End times');
          return true;
        }
        else{
            //no conflict found
            return false;
        }
   }
   
    //Before Insert Update
    public class BookingEventAttendanceRollup implements Triggers.Handler
    {
        public void handle()
        {
            if (!Triggers.getBoolParam('BookingEventAttendanceRollup', true)) { 
                return;
            }
            
            map<Id,BookingEvent__c> oldEvents = (map<Id,BookingEvent__c>)Trigger.oldMap;
            for(BookingEvent__c be: (List<BookingEvent__c>)(Trigger.New))
            {
                BookingEvent__c oldBe;
                if(!Trigger.IsInsert && oldEvents.get(be.Id) != null)
                {
                    oldBe = oldEvents.get(be.Id);
                }
                else
                {
                    oldBe = new BookingEvent__c();
                }
                decimal bookedPackageCovers = 0;
                decimal actualPackageCovers = 0;
                if(queriedInfo.eventIdToPackageEvents.get(be.Id) != null)
                {
                    decimal totalAgreedAttendance = 0;
                    decimal totalForecastAttendance = 0;
                    decimal totalGuaranteedAttendance = 0;
                    for(BookingPackageEvent__c bpe : queriedInfo.eventIdToPackageEvents.get(be.Id))
                    {
                        if(bpe.AgreedPackageAttendance__c != null)
                        {
                            totalAgreedAttendance += bpe.AgreedPackageAttendance__c;    
                        }
                        
                        if(bpe.ForecastPackageAttendance__c != null)
                        {
                            totalForecastAttendance += bpe.ForecastPackageAttendance__c;
                            bookedPackageCovers += bpe.ForecastPackageAttendance__c;
                        }
                        else if(bpe.AgreedPackageAttendance__c != null)
                        {
                            bookedPackageCovers += bpe.AgreedPackageAttendance__c;
                        }
                        
                        if(bpe.GuaranteedPackageAttendance__c != null)
                        {
                            totalGuaranteedAttendance += bpe.GuaranteedPackageAttendance__c;    
                            actualPackageCovers += bpe.GuaranteedPackageAttendance__c;  
                        }
                        else if(bpe.ForecastPackageAttendance__c != null)
                        {
                            actualPackageCovers += bpe.ForecastPackageAttendance__c;
                        }
                        else if(bpe.AgreedPackageAttendance__c != null)
                        {
                            actualPackageCovers += bpe.AgreedPackageAttendance__c;  
                        }
                        
                        
                    }
                    be.AgreedPackageAttendance__c = totalAgreedAttendance;
                    be.AgreedAttendance__c = (be.AgreedEventAttendance__c != null ? be.AgreedEventAttendance__c : 0) + be.AgreedPackageAttendance__c;
                    be.ForecastPackageAttendance__c = totalForecastAttendance;
                    be.ForecastAttendance__c = (be.ForecastEventAttendance__c != null ? be.ForecastEventAttendance__c : 0) + be.ForecastPackageAttendance__c;
                    be.GuaranteedPackageAttendance__c = totalGuaranteedAttendance;
                    be.GuaranteedAttendance__c = (be.GuaranteedEventAttendance__c != null ? be.GuaranteedEventAttendance__c : 0) + be.GuaranteedPackageAttendance__c;
                }
                else
                {
                    be.AgreedPackageAttendance__c = null;
                    if(oldBe.AgreedAttendance__c != be.AgreedAttendance__c)
                    {
                        be.AgreedEventAttendance__c = be.AgreedAttendance__c;
                    }
                    be.AgreedAttendance__c = be.AgreedEventAttendance__c;
                    be.ForecastPackageAttendance__c = null;
                    if(oldBe.ForecastAttendance__c != be.ForecastAttendance__c)
                    {
                        be.ForecastEventAttendance__c = be.ForecastAttendance__c;
                    }
                    be.ForecastAttendance__c = be.ForecastEventAttendance__c;
                    be.GuaranteedPackageAttendance__c = null;
                    if(oldBe.GuaranteedAttendance__c != be.GuaranteedAttendance__c)
                    {
                        be.GuaranteedEventAttendance__c = be.GuaranteedAttendance__c;
                    }
                    be.GuaranteedAttendance__c = be.GuaranteedEventAttendance__c;
                }
                
                be.BookedPackageCovers__c = bookedPackageCovers;
                be.ActualPackageCovers__c = actualPackageCovers;
                
                if (be.ForecastEventAttendance__c != null)
                {
                    be.BookedEventCovers__c = be.ForecastEventAttendance__c;
                }
                else if (be.AgreedEventAttendance__c != null)
                {
                    be.BookedEventCovers__c = be.AgreedEventAttendance__c;
                }
                else
                {
                    be.BookedEventCovers__c = 0;
                }
                
                if (be.GuaranteedEventAttendance__c != null)
                {
                    be.ActualEventCovers__c = be.GuaranteedEventAttendance__c;
                }
                else
                {
                    be.ActualEventCovers__c = be.BookedEventCovers__c;
                }
                
                if( be.ActualAttendance__c != null && (((be.ActualAttendance__c != null ? be.ActualAttendance__c : 0) - (be.ActualPackageCovers__c != null ? be.ActualPackageCovers__c : 0)) >= (be.ActualEventCovers__c != null ? be.ActualEventCovers__c : 0) ))
                {
                    be.ActualEventCovers__c = ((be.ActualAttendance__c != null ? be.ActualAttendance__c : 0) - (be.ActualPackageCovers__c != null ? be.ActualPackageCovers__c : 0));
                }
                
                be.BookedCovers__c = be.BookedEventCovers__c + be.BookedPackageCovers__c;
                
                be.ActualCovers__c = be.ActualEventCovers__c + be.ActualPackageCovers__c;
            }
        }
    }
    
    //After Update
    public class UpdateBookingPackageEvent implements Triggers.Handler{
    
        public void handle(){
            
            list<Id> bookingEventIds = new list<Id>();
        
            for(BookingEvent__c be: (List<BookingEvent__c>)(Trigger.New)){
                BookingEvent__c oldBe = (BookingEvent__c)Trigger.oldMap.get(be.Id); 
                if(oldBe.Name != be.Name || oldBe.StartDate__c != be.StartDate__c || oldBe.EventClassification__c != be.EventClassification__c)
                    bookingEventIds.add(be.Id);
            }
            
            update([SELECT Id from BookingPackageEvent__c Where BookingEvent__c IN : bookingEventIds]);
            
                
        }
    }
    
    public class BookingEventRevenueRollup implements Triggers.Handler{
    
        public void handle(){
            
            Set<Id> bookings = new Set<Id>();

            if (updateFromBooking || processingClone) return;
            
            system.debug(logginglevel.info, 'In BookingEventCls, BookingEventRevenueRollup, RollupRevenue flag = ' + rolluprevenue);
           
            
            if(RollupRevenue)
            {
                if(Trigger.IsInsert)
                {
                    CalculateRevenue((list<BookingEvent__c>)(Trigger.New));
                }
                else
                {
                    CalculateRevenue((map<Id,BookingEvent__c>)Trigger.newMap);
                }
                RollupBooking = true;
            }
            
            for(BookingEvent__c event : (List<BookingEvent__c>)(Trigger.New)){
                if(event.CalculateRevenue__c)
                {//if calculateRevenue is false then don't roll up any revenue
                    
                    BookingEvent__c oldEvent = (BookingEvent__c)(Trigger.isUpdate ? Trigger.OldMap.get(event.Id) : NULL);
                    
                    if(Trigger.isUpdate && event.isDone__c != oldEvent.isDone__c){
                        bookings.add(event.Booking__c);
                        RollupBooking = true;
                    }
                    else if(RollupRevenue)
                    {
                        bookings.add(event.Booking__c);
                    }
                }
                
                event.NumberForecastRevenue1__c = event.ForecastRevenue1__c != null ? event.ForecastRevenue1__c : 0;
                event.NumberForecastRevenue2__c = event.ForecastRevenue2__c != null ? event.ForecastRevenue2__c : 0;
                event.NumberForecastRevenue3__c = event.ForecastRevenue3__c != null ? event.ForecastRevenue3__c : 0;
                event.NumberForecastRevenue4__c = event.ForecastRevenue4__c != null ? event.ForecastRevenue4__c : 0;
                event.NumberForecastRevenue5__c = event.ForecastRevenue5__c != null ? event.ForecastRevenue5__c : 0;
                event.NumberForecastRevenue6__c = event.ForecastRevenue6__c != null ? event.ForecastRevenue6__c : 0;
                event.NumberForecastRevenue7__c = event.ForecastRevenue7__c != null ? event.ForecastRevenue7__c : 0;
                event.NumberForecastRevenue8__c = event.ForecastRevenue8__c != null ? event.ForecastRevenue8__c : 0;
                event.NumberForecastRevenue9__c = event.ForecastRevenue9__c != null ? event.ForecastRevenue9__c : 0;
                event.NumberForecastRevenue10__c = event.ForecastRevenue10__c != null ? event.ForecastRevenue10__c : 0;
                event.NumberForecastRevenue11__c = event.ForecastRevenue11__c != null ? event.ForecastRevenue11__c : 0;
                event.NumberForecastRevenue12__c = event.ForecastRevenue12__c != null ? event.ForecastRevenue12__c : 0;
                event.NumberForecastRevenue13__c = event.ForecastRevenue13__c != null ? event.ForecastRevenue13__c : 0;
                event.NumberForecastRevenue14__c = event.ForecastRevenue14__c != null ? event.ForecastRevenue14__c : 0;
                event.NumberForecastRevenue15__c = event.ForecastRevenue15__c != null ? event.ForecastRevenue15__c : 0;
                
                event.NumberBookedRevenue1__c = event.BookedRevenue1__c != null ? event.BookedRevenue1__c : 0;
                event.NumberBookedRevenue2__c = event.BookedRevenue2__c != null ? event.BookedRevenue2__c : 0;
                event.NumberBookedRevenue3__c = event.BookedRevenue3__c != null ? event.BookedRevenue3__c : 0;
                event.NumberBookedRevenue4__c = event.BookedRevenue4__c != null ? event.BookedRevenue4__c : 0;
                event.NumberBookedRevenue5__c = event.BookedRevenue5__c != null ? event.BookedRevenue5__c : 0;
                event.NumberBookedRevenue6__c = event.BookedRevenue6__c != null ? event.BookedRevenue6__c : 0;
                event.NumberBookedRevenue7__c = event.BookedRevenue7__c != null ? event.BookedRevenue7__c : 0;
                event.NumberBookedRevenue8__c = event.BookedRevenue8__c != null ? event.BookedRevenue8__c : 0;
                event.NumberBookedRevenue9__c = event.BookedRevenue9__c != null ? event.BookedRevenue9__c : 0;
                event.NumberBookedRevenue10__c = event.BookedRevenue10__c != null ? event.BookedRevenue10__c : 0;
                event.NumberBookedRevenue11__c = event.BookedRevenue11__c != null ? event.BookedRevenue11__c : 0;
                event.NumberBookedRevenue12__c = event.BookedRevenue12__c != null ? event.BookedRevenue12__c : 0;
                event.NumberBookedRevenue13__c = event.BookedRevenue13__c != null ? event.BookedRevenue13__c : 0;
                event.NumberBookedRevenue14__c = event.BookedRevenue14__c != null ? event.BookedRevenue14__c : 0;
                event.NumberBookedRevenue15__c = event.BookedRevenue15__c != null ? event.BookedRevenue15__c : 0;
                
                event.NumberActualRevenue1__c = event.ActualRevenue1__c != null ? event.ActualRevenue1__c : 0;
                event.NumberActualRevenue2__c = event.ActualRevenue2__c != null ? event.ActualRevenue2__c : 0;
                event.NumberActualRevenue3__c = event.ActualRevenue3__c != null ? event.ActualRevenue3__c : 0;
                event.NumberActualRevenue4__c = event.ActualRevenue4__c != null ? event.ActualRevenue4__c : 0;
                event.NumberActualRevenue5__c = event.ActualRevenue5__c != null ? event.ActualRevenue5__c : 0;
                event.NumberActualRevenue6__c = event.ActualRevenue6__c != null ? event.ActualRevenue6__c : 0;
                event.NumberActualRevenue7__c = event.ActualRevenue7__c != null ? event.ActualRevenue7__c : 0;
                event.NumberActualRevenue8__c = event.ActualRevenue8__c != null ? event.ActualRevenue8__c : 0;
                event.NumberActualRevenue9__c = event.ActualRevenue9__c != null ? event.ActualRevenue9__c : 0;
                event.NumberActualRevenue10__c = event.ActualRevenue10__c != null ? event.ActualRevenue10__c : 0;
                event.NumberActualRevenue11__c = event.ActualRevenue11__c != null ? event.ActualRevenue11__c : 0;
                event.NumberActualRevenue12__c = event.ActualRevenue12__c != null ? event.ActualRevenue12__c : 0;
                event.NumberActualRevenue13__c = event.ActualRevenue13__c != null ? event.ActualRevenue13__c : 0;
                event.NumberActualRevenue14__c = event.ActualRevenue14__c != null ? event.ActualRevenue14__c : 0;
                event.NumberActualRevenue15__c = event.ActualRevenue15__c != null ? event.ActualRevenue15__c : 0;
                
                if(event.IsDone__c == true)
                {
                    event.NumberCurrentBlendedRevenue1__c = event.ActualRevenue1__c != null ? event.ActualRevenue1__c : 0;
                    event.NumberCurrentBlendedRevenue2__c = event.ActualRevenue2__c != null ? event.ActualRevenue2__c : 0;
                    event.NumberCurrentBlendedRevenue3__c = event.ActualRevenue3__c != null ? event.ActualRevenue3__c : 0;
                    event.NumberCurrentBlendedRevenue4__c = event.ActualRevenue4__c != null ? event.ActualRevenue4__c : 0;
                    event.NumberCurrentBlendedRevenue5__c = event.ActualRevenue5__c != null ? event.ActualRevenue5__c : 0;
                    event.NumberCurrentBlendedRevenue6__c = event.ActualRevenue6__c != null ? event.ActualRevenue6__c : 0;
                    event.NumberCurrentBlendedRevenue7__c = event.ActualRevenue7__c != null ? event.ActualRevenue7__c : 0;
                    event.NumberCurrentBlendedRevenue8__c = event.ActualRevenue8__c != null ? event.ActualRevenue8__c : 0;
                    event.NumberCurrentBlendedRevenue9__c = event.ActualRevenue9__c != null ? event.ActualRevenue9__c : 0;
                    event.NumberCurrentBlendedRevenue10__c = event.ActualRevenue10__c != null ? event.ActualRevenue10__c : 0;
                    event.NumberCurrentBlendedRevenue11__c = event.ActualRevenue11__c != null ? event.ActualRevenue11__c : 0;
                    event.NumberCurrentBlendedRevenue12__c = event.ActualRevenue12__c != null ? event.ActualRevenue12__c : 0;
                    event.NumberCurrentBlendedRevenue13__c = event.ActualRevenue13__c != null ? event.ActualRevenue13__c : 0;
                    event.NumberCurrentBlendedRevenue14__c = event.ActualRevenue14__c != null ? event.ActualRevenue14__c : 0;
                    event.NumberCurrentBlendedRevenue15__c = event.ActualRevenue15__c != null ? event.ActualRevenue15__c : 0;
                }
                else
                {
                    event.NumberCurrentBlendedRevenue1__c = event.ForecastRevenue1__c != null ? event.ForecastRevenue1__c : 0;
                    event.NumberCurrentBlendedRevenue2__c = event.ForecastRevenue2__c != null ? event.ForecastRevenue2__c : 0;
                    event.NumberCurrentBlendedRevenue3__c = event.ForecastRevenue3__c != null ? event.ForecastRevenue3__c : 0;
                    event.NumberCurrentBlendedRevenue4__c = event.ForecastRevenue4__c != null ? event.ForecastRevenue4__c : 0;
                    event.NumberCurrentBlendedRevenue5__c = event.ForecastRevenue5__c != null ? event.ForecastRevenue5__c : 0;
                    event.NumberCurrentBlendedRevenue6__c = event.ForecastRevenue6__c != null ? event.ForecastRevenue6__c : 0;
                    event.NumberCurrentBlendedRevenue7__c = event.ForecastRevenue7__c != null ? event.ForecastRevenue7__c : 0;
                    event.NumberCurrentBlendedRevenue8__c = event.ForecastRevenue8__c != null ? event.ForecastRevenue8__c : 0;
                    event.NumberCurrentBlendedRevenue9__c = event.ForecastRevenue9__c != null ? event.ForecastRevenue9__c : 0;
                    event.NumberCurrentBlendedRevenue10__c = event.ForecastRevenue10__c != null ? event.ForecastRevenue10__c : 0;
                    event.NumberCurrentBlendedRevenue11__c = event.ForecastRevenue11__c != null ? event.ForecastRevenue11__c : 0;
                    event.NumberCurrentBlendedRevenue12__c = event.ForecastRevenue12__c != null ? event.ForecastRevenue12__c : 0;
                    event.NumberCurrentBlendedRevenue13__c = event.ForecastRevenue13__c != null ? event.ForecastRevenue13__c : 0;
                    event.NumberCurrentBlendedRevenue14__c = event.ForecastRevenue14__c != null ? event.ForecastRevenue14__c : 0;
                    event.NumberCurrentBlendedRevenue15__c = event.ForecastRevenue15__c != null ? event.ForecastRevenue15__c : 0;
                }
                
            }
           
            system.debug('end of RevenueRollup: RollupBooking->' + RollupBooking + ' Bookings: ' + bookings);
            if(RollupBooking && !bookings.isEmpty()){
                for(Id i : bookings){
                    BookingCls.addToBookingContext(i, 'Event');
                }
            }
        }
        
        private void InitializeForecastRevenue(list<BookingEvent__c> events)
        {
            for(BookingEvent__c event : events)
            {
                if(event.CalculateRevenue__c)
                {
                    if(event.ForecastAverageCheckFactor1__c != 'Not Calculated')
                    {
                        event.ForecastRevenue1__c = 0;
                        if (event.ForecastAverageCheckFactor1__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck1__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue1__c = event.ForecastAverageCheck1__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue1__c = event.ForecastAverageCheck1__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor1__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck1__c != null)
                            {
                                event.ForecastRevenue1__c = event.ForecastAverageCheck1__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor2__c != 'Not Calculated')
                    {
                        event.ForecastRevenue2__c = 0;
                        if (event.ForecastAverageCheckFactor2__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck2__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue2__c = event.ForecastAverageCheck2__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue2__c = event.ForecastAverageCheck2__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor2__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck2__c != null)
                            {
                                event.ForecastRevenue2__c = event.ForecastAverageCheck2__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor3__c != 'Not Calculated')
                    {
                        event.ForecastRevenue3__c = 0;
                        if (event.ForecastAverageCheckFactor3__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck3__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue3__c = event.ForecastAverageCheck3__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue3__c = event.ForecastAverageCheck3__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor3__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck3__c != null)
                            {
                                event.ForecastRevenue3__c = event.ForecastAverageCheck3__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor4__c != 'Not Calculated')
                    {
                        event.ForecastRevenue4__c = 0;
                        if (event.ForecastAverageCheckFactor4__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck4__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue4__c = event.ForecastAverageCheck4__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue4__c = event.ForecastAverageCheck4__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor4__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck4__c != null)
                            {
                                event.ForecastRevenue4__c = event.ForecastAverageCheck4__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor5__c != 'Not Calculated')
                    {
                        event.ForecastRevenue5__c = 0;
                        if (event.ForecastAverageCheckFactor5__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck5__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue5__c = event.ForecastAverageCheck5__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue5__c = event.ForecastAverageCheck5__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor5__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck5__c != null)
                            {
                                event.ForecastRevenue5__c = event.ForecastAverageCheck5__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor6__c != 'Not Calculated')
                    {
                        event.ForecastRevenue6__c = 0;
                        if (event.ForecastAverageCheckFactor6__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck6__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue6__c = event.ForecastAverageCheck6__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue6__c = event.ForecastAverageCheck6__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor6__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck6__c != null)
                            {
                                event.ForecastRevenue6__c = event.ForecastAverageCheck6__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor7__c != 'Not Calculated')
                    {
                        event.ForecastRevenue7__c = 0;
                        if (event.ForecastAverageCheckFactor7__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck7__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue7__c = event.ForecastAverageCheck7__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue7__c = event.ForecastAverageCheck7__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor7__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck7__c != null)
                            {
                                event.ForecastRevenue7__c = event.ForecastAverageCheck7__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor8__c != 'Not Calculated')
                    {
                        event.ForecastRevenue8__c = 0;
                        if (event.ForecastAverageCheckFactor8__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck8__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue8__c = event.ForecastAverageCheck8__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue8__c = event.ForecastAverageCheck8__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor8__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck8__c != null)
                            {
                                event.ForecastRevenue8__c = event.ForecastAverageCheck8__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor9__c != 'Not Calculated')
                    {
                        event.ForecastRevenue9__c = 0;
                        if (event.ForecastAverageCheckFactor9__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck9__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue9__c = event.ForecastAverageCheck9__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue9__c = event.ForecastAverageCheck9__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor9__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck9__c != null)
                            {
                                event.ForecastRevenue9__c = event.ForecastAverageCheck9__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor10__c != 'Not Calculated')
                    {
                        event.ForecastRevenue10__c = 0;
                        if (event.ForecastAverageCheckFactor10__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck10__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue10__c = event.ForecastAverageCheck10__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue10__c = event.ForecastAverageCheck10__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor10__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck10__c != null)
                            {
                                event.ForecastRevenue10__c = event.ForecastAverageCheck10__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor11__c != 'Not Calculated')
                    {
                        event.ForecastRevenue11__c = 0;
                        if (event.ForecastAverageCheckFactor11__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck11__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue11__c = event.ForecastAverageCheck11__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue11__c = event.ForecastAverageCheck11__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor11__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck11__c != null)
                            {
                                event.ForecastRevenue11__c = event.ForecastAverageCheck11__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor12__c != 'Not Calculated')
                    {
                        event.ForecastRevenue12__c = 0;
                        if (event.ForecastAverageCheckFactor12__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck12__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue12__c = event.ForecastAverageCheck12__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue12__c = event.ForecastAverageCheck12__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor12__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck12__c != null)
                            {
                                event.ForecastRevenue12__c = event.ForecastAverageCheck12__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor13__c != 'Not Calculated')
                    {
                        event.ForecastRevenue13__c = 0;
                        if (event.ForecastAverageCheckFactor13__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck13__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue13__c = event.ForecastAverageCheck13__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue13__c = event.ForecastAverageCheck13__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor13__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck13__c != null)
                            {
                                event.ForecastRevenue13__c = event.ForecastAverageCheck13__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor14__c != 'Not Calculated')
                    {
                        event.ForecastRevenue14__c = 0;
                        if (event.ForecastAverageCheckFactor14__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck14__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue14__c = event.ForecastAverageCheck14__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue14__c = event.ForecastAverageCheck14__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor14__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck14__c != null)
                            {
                                event.ForecastRevenue14__c = event.ForecastAverageCheck14__c;
                            }
                        }
                    }
                    if(event.ForecastAverageCheckFactor15__c != 'Not Calculated')
                    {
                        event.ForecastRevenue15__c = 0;
                        if (event.ForecastAverageCheckFactor15__c == 'Per Person')
                        {
                            if (event.ForecastAverageCheck15__c != null)
                            {
                                if (event.ForecastEventAttendance__c != null)
                                {
                                    event.ForecastRevenue15__c = event.ForecastAverageCheck15__c*event.ForecastEventAttendance__c;
                                }
                                else if (event.AgreedEventAttendance__c != null)
                                {
                                    event.ForecastRevenue15__c = event.ForecastAverageCheck15__c*event.AgreedEventAttendance__c;
                                }
                            }
                        }
                        else if (event.ForecastAverageCheckFactor15__c == 'Per Event')
                        {
                            if (event.ForecastAverageCheck15__c != null)
                            {
                                event.ForecastRevenue15__c = event.ForecastAverageCheck15__c;
                            }
                        }
                    }
                }
            }       
        }

        private void InitializeBookedActualRevenue(list<BookingEvent__c> events)
        {
            for(BookingEvent__c event : events)
            {
                event.TotalEventItems__c = 0;
                
                if(event.CalculateRevenue__c)
                {
                    event.BookedRevenue1__c = 0;
                    event.BookedRevenue2__c = 0;
                    event.BookedRevenue3__c = 0;
                    event.BookedRevenue4__c = 0;
                    event.BookedRevenue5__c = 0;
                    event.BookedRevenue6__c = 0;
                    event.BookedRevenue7__c = 0;
                    event.BookedRevenue8__c = 0;
                    event.BookedRevenue9__c = 0;
                    event.BookedRevenue10__c = 0;
                    event.BookedRevenue11__c = 0;
                    event.BookedRevenue12__c = 0;
                    event.BookedRevenue13__c = 0;
                    event.BookedRevenue14__c = 0;
                    event.BookedRevenue15__c = 0;
                    
                    event.ActualRevenue1__c = 0;
                    event.ActualRevenue2__c = 0;
                    event.ActualRevenue3__c = 0;
                    event.ActualRevenue4__c = 0;
                    event.ActualRevenue5__c = 0;
                    event.ActualRevenue6__c = 0;
                    event.ActualRevenue7__c = 0;
                    event.ActualRevenue8__c = 0;
                    event.ActualRevenue9__c = 0;
                    event.ActualRevenue10__c = 0;
                    event.ActualRevenue11__c = 0;
                    event.ActualRevenue12__c = 0;
                    event.ActualRevenue13__c = 0;
                    event.ActualRevenue14__c = 0;
                    event.ActualRevenue15__c = 0;
                    
                    //Add Function Room Rental
                    if(event.FunctionRoomRental__c != null)
                    {
                        if(event.FunctionRoomRentalCalculation__c == 'Per Event')
                        {
                            event.BookedRevenue7__c += event.FunctionRoomRental__c;
                            event.ActualRevenue7__c += event.FunctionRoomRental__c;
                            
                            // Added for fr admin charge = (frrental * percentage) / 100
                            if (event.FunctionRoomRentalAdminCharge__c != null) {
                                event.BookedRevenue5__c += (event.FunctionRoomRental__c * event.FunctionRoomRentalAdminCharge__c) / 100;
                                event.ActualRevenue5__c += (event.FunctionRoomRental__c * event.FunctionRoomRentalAdminCharge__c) / 100;
                            }
                        }
                        else
                        {//Value is per person
                            if (event.ActualEventCovers__c != null)
                            {
                                event.ActualRevenue7__c += event.FunctionRoomRental__c * event.ActualEventCovers__c;
                                
                                // Added for fr admin charge = ((frrental * num people) * percentage) / 100
                                if (event.FunctionRoomRentalAdminCharge__c != null) {
                                    event.ActualRevenue5__c += ((event.FunctionRoomRental__c * event.ActualEventCovers__c) * event.FunctionRoomRentalAdminCharge__c) / 100;
                                }
                            }

                            if(event.ForecastEventAttendance__c != null)
                            {
                                event.BookedRevenue7__c += event.FunctionRoomRental__c * event.ForecastEventAttendance__c;
                                
                                // Added for fr admin charge = ((frrental * num people) * percentage) / 100
                                if (event.FunctionRoomRentalAdminCharge__c != null) {
                                    event.BookedRevenue5__c += ((event.FunctionRoomRental__c * event.ForecastEventAttendance__c) * event.FunctionRoomRentalAdminCharge__c) / 100;
                                }

                            }
                            else if(event.AgreedEventAttendance__c != null)
                            {
                                event.BookedRevenue7__c += event.FunctionRoomRental__c * event.AgreedEventAttendance__c;
                                
                                // Added for fr admin charge = ((frrental * num people) * percentage) / 100
                                if (event.FunctionRoomRentalAdminCharge__c != null) {
                                    event.BookedRevenue5__c += ((event.FunctionRoomRental__c * event.AgreedEventAttendance__c) * event.FunctionRoomRentalAdminCharge__c) / 100;
                                }
                                
                            }
                        }
                    }                    
                    
                }
            }
        }
        
        public void AddPackageEventRevenue(Map<Id,BookingEvent__c> events)
        {
            for(AggregateResult eventRoll :
                 [ SELECT BookingEvent__c BookingEvent,
                    COUNT(NumberBookedRevenue1__c) NonNullRecords,
                    COUNT(Id) AllRecords,
                     SUM(NumberBookedRevenue1__c) BookedRevenue1, SUM(NumberBookedRevenue2__c) BookedRevenue2, SUM(NumberBookedRevenue3__c) BookedRevenue3,
                     SUM(NumberBookedRevenue4__c) BookedRevenue4, SUM(NumberBookedRevenue5__c) BookedRevenue5, SUM(NumberBookedRevenue6__c) BookedRevenue6,
                     SUM(NumberBookedRevenue7__c) BookedRevenue7, SUM(NumberBookedRevenue8__c) BookedRevenue8, SUM(NumberBookedRevenue9__c) BookedRevenue9,
                     SUM(NumberBookedRevenue10__c) BookedRevenue10, SUM(NumberBookedRevenue11__c) BookedRevenue11, SUM(NumberBookedRevenue12__c) BookedRevenue12,
                     SUM(NumberBookedRevenue13__c) BookedRevenue13, SUM(NumberBookedRevenue14__c) BookedRevenue14, SUM(NumberBookedRevenue15__c) BookedRevenue15,
                     SUM(NumberActualRevenue1__c) ActualRevenue1, SUM(NumberActualRevenue2__c) ActualRevenue2, SUM(NumberActualRevenue3__c) ActualRevenue3,
                     SUM(NumberActualRevenue4__c) ActualRevenue4, SUM(NumberActualRevenue5__c) ActualRevenue5, SUM(NumberActualRevenue6__c) ActualRevenue6,
                     SUM(NumberActualRevenue7__c) ActualRevenue7, SUM(NumberActualRevenue8__c) ActualRevenue8, SUM(NumberActualRevenue9__c) ActualRevenue9,
                     SUM(NumberActualRevenue10__c) ActualRevenue10, SUM(NumberActualRevenue11__c) ActualRevenue11, SUM(NumberActualRevenue12__c) ActualRevenue12,
                     SUM(NumberActualRevenue13__c) ActualRevenue13, SUM(NumberActualRevenue14__c) ActualRevenue14, SUM(NumberActualRevenue15__c) ActualRevenue15
                 FROM BookingPackageEvent__c 
                 WHERE BookingEvent__c IN : events.KeySet()
                 GROUP By BookingEvent__c]) 
            {
                if(events.get((Id)eventRoll.get('BookingEvent')).CalculateRevenue__c == true)
                {
                    if(eventRoll.get('NonNullRecords') != eventRoll.get('AllRecords') )
                        throw new Ni.NiException(Label.RevenueRollupError.replace('{0}','nihrm__BookingPackageEvent__c'));
                        
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor1__c != 'Not Calculated')
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue1__c += (Decimal)(eventRoll.get('BookedRevenue1'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor2__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue2__c += (Decimal)(eventRoll.get('BookedRevenue2'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor3__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue3__c += (Decimal)(eventRoll.get('BookedRevenue3'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor4__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue4__c += (Decimal)(eventRoll.get('BookedRevenue4'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor5__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue5__c += (Decimal)(eventRoll.get('BookedRevenue5'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor6__c != 'Not Calculated')   
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue6__c += (Decimal)(eventRoll.get('BookedRevenue6'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor7__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue7__c += (Decimal)(eventRoll.get('BookedRevenue7'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor8__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue8__c += (Decimal)(eventRoll.get('BookedRevenue8'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor9__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue9__c += (Decimal)(eventRoll.get('BookedRevenue9'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor10__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue10__c += (Decimal)(eventRoll.get('BookedRevenue10'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor11__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue11__c += (Decimal)(eventRoll.get('BookedRevenue11'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor12__c != 'Not Calculated')    
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue12__c += (Decimal)(eventRoll.get('BookedRevenue12'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor13__c != 'Not Calculated')   
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue13__c += (Decimal)(eventRoll.get('BookedRevenue13'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor14__c != 'Not Calculated')   
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue14__c += (Decimal)(eventRoll.get('BookedRevenue14'));
                    if(events.get((Id)eventRoll.get('BookingEvent')).ForecastAverageCheckFactor15__c != 'Not Calculated')   
                        events.get((Id)eventRoll.get('BookingEvent')).ForecastRevenue15__c += (Decimal)(eventRoll.get('BookedRevenue15'));
                    
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue1__c += (Decimal)(eventRoll.get('BookedRevenue1'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue2__c += (Decimal)(eventRoll.get('BookedRevenue2'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue3__c += (Decimal)(eventRoll.get('BookedRevenue3'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue4__c += (Decimal)(eventRoll.get('BookedRevenue4'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue5__c += (Decimal)(eventRoll.get('BookedRevenue5'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue6__c += (Decimal)(eventRoll.get('BookedRevenue6'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue7__c += (Decimal)(eventRoll.get('BookedRevenue7'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue8__c += (Decimal)(eventRoll.get('BookedRevenue8'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue9__c += (Decimal)(eventRoll.get('BookedRevenue9'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue10__c += (Decimal)(eventRoll.get('BookedRevenue10'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue11__c += (Decimal)(eventRoll.get('BookedRevenue11'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue12__c += (Decimal)(eventRoll.get('BookedRevenue12'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue13__c += (Decimal)(eventRoll.get('BookedRevenue13'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue14__c += (Decimal)(eventRoll.get('BookedRevenue14'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue15__c += (Decimal)(eventRoll.get('BookedRevenue15'));
                        
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue1__c += (Decimal)(eventRoll.get('ActualRevenue1'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue2__c += (Decimal)(eventRoll.get('ActualRevenue2'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue3__c += (Decimal)(eventRoll.get('ActualRevenue3'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue4__c += (Decimal)(eventRoll.get('ActualRevenue4'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue5__c += (Decimal)(eventRoll.get('ActualRevenue5'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue6__c += (Decimal)(eventRoll.get('ActualRevenue6'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue7__c += (Decimal)(eventRoll.get('ActualRevenue7'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue8__c += (Decimal)(eventRoll.get('ActualRevenue8'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue9__c += (Decimal)(eventRoll.get('ActualRevenue9'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue10__c += (Decimal)(eventRoll.get('ActualRevenue10'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue11__c += (Decimal)(eventRoll.get('ActualRevenue11'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue12__c += (Decimal)(eventRoll.get('ActualRevenue12'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue13__c += (Decimal)(eventRoll.get('ActualRevenue13'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue14__c += (Decimal)(eventRoll.get('ActualRevenue14'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue15__c += (Decimal)(eventRoll.get('ActualRevenue15'));
                }
            }
        }
        
        public void AddEventItemRevenue(Map<Id,BookingEvent__c> events)
        {
            for(AggregateResult eventRoll :
                 [ SELECT Event__c BookingEvent,
                    COUNT(NumberBookedRevenue1__c) NonNullRecords,
                    COUNT(Id) AllRecords,
                     SUM(NumberBookedRevenue1__c) BookedRevenue1, SUM(NumberBookedRevenue2__c) BookedRevenue2, SUM(NumberBookedRevenue3__c) BookedRevenue3,
                     SUM(NumberBookedRevenue4__c) BookedRevenue4, SUM(NumberBookedRevenue5__c) BookedRevenue5, SUM(NumberBookedRevenue6__c) BookedRevenue6,
                     SUM(NumberBookedRevenue7__c) BookedRevenue7, SUM(NumberBookedRevenue8__c) BookedRevenue8, SUM(NumberBookedRevenue9__c) BookedRevenue9,
                     SUM(NumberBookedRevenue10__c) BookedRevenue10, SUM(NumberBookedRevenue11__c) BookedRevenue11, SUM(NumberBookedRevenue12__c) BookedRevenue12,
                     SUM(NumberBookedRevenue13__c) BookedRevenue13, SUM(NumberBookedRevenue14__c) BookedRevenue14, SUM(NumberBookedRevenue15__c) BookedRevenue15,
                     SUM(NumberActualRevenue1__c) ActualRevenue1, SUM(NumberActualRevenue2__c) ActualRevenue2, SUM(NumberActualRevenue3__c) ActualRevenue3,
                     SUM(NumberActualRevenue4__c) ActualRevenue4, SUM(NumberActualRevenue5__c) ActualRevenue5, SUM(NumberActualRevenue6__c) ActualRevenue6,
                     SUM(NumberActualRevenue7__c) ActualRevenue7, SUM(NumberActualRevenue8__c) ActualRevenue8, SUM(NumberActualRevenue9__c) ActualRevenue9,
                     SUM(NumberActualRevenue10__c) ActualRevenue10, SUM(NumberActualRevenue11__c) ActualRevenue11, SUM(NumberActualRevenue12__c) ActualRevenue12,
                     SUM(NumberActualRevenue13__c) ActualRevenue13, SUM(NumberActualRevenue14__c) ActualRevenue14, SUM(NumberActualRevenue15__c) ActualRevenue15,
                     COUNT(Id) TotalEventItems
                 FROM EventItem__c 
                 WHERE Event__c IN : events.KeySet()
                 GROUP By Event__c])    
            {
                events.get((Id)eventRoll.get('BookingEvent')).TotalEventItems__c = (Decimal)(eventRoll.get('TotalEventItems'));
                
                if(events.get((Id)eventRoll.get('BookingEvent')).CalculateRevenue__c == true)
                {
                    if(eventRoll.get('NonNullRecords') != eventRoll.get('AllRecords') )
                        throw new Ni.NiException(Label.RevenueRollupError.replace('{0}','nihrm__EventItem__c'));
                        
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue1__c += (Decimal)(eventRoll.get('BookedRevenue1'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue2__c += (Decimal)(eventRoll.get('BookedRevenue2'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue3__c += (Decimal)(eventRoll.get('BookedRevenue3'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue4__c += (Decimal)(eventRoll.get('BookedRevenue4'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue5__c += (Decimal)(eventRoll.get('BookedRevenue5'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue6__c += (Decimal)(eventRoll.get('BookedRevenue6'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue7__c += (Decimal)(eventRoll.get('BookedRevenue7'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue8__c += (Decimal)(eventRoll.get('BookedRevenue8'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue9__c += (Decimal)(eventRoll.get('BookedRevenue9'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue10__c += (Decimal)(eventRoll.get('BookedRevenue10'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue11__c += (Decimal)(eventRoll.get('BookedRevenue11'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue12__c += (Decimal)(eventRoll.get('BookedRevenue12'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue13__c += (Decimal)(eventRoll.get('BookedRevenue13'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue14__c += (Decimal)(eventRoll.get('BookedRevenue14'));
                    events.get((Id)eventRoll.get('BookingEvent')).BookedRevenue15__c += (Decimal)(eventRoll.get('BookedRevenue15'));
                        
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue1__c += (Decimal)(eventRoll.get('ActualRevenue1'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue2__c += (Decimal)(eventRoll.get('ActualRevenue2'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue3__c += (Decimal)(eventRoll.get('ActualRevenue3'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue4__c += (Decimal)(eventRoll.get('ActualRevenue4'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue5__c += (Decimal)(eventRoll.get('ActualRevenue5'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue6__c += (Decimal)(eventRoll.get('ActualRevenue6'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue7__c += (Decimal)(eventRoll.get('ActualRevenue7'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue8__c += (Decimal)(eventRoll.get('ActualRevenue8'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue9__c += (Decimal)(eventRoll.get('ActualRevenue9'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue10__c += (Decimal)(eventRoll.get('ActualRevenue10'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue11__c += (Decimal)(eventRoll.get('ActualRevenue11'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue12__c += (Decimal)(eventRoll.get('ActualRevenue12'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue13__c += (Decimal)(eventRoll.get('ActualRevenue13'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue14__c += (Decimal)(eventRoll.get('ActualRevenue14'));
                    events.get((Id)eventRoll.get('BookingEvent')).ActualRevenue15__c += (Decimal)(eventRoll.get('ActualRevenue15'));
                }
            }
        }
        
        private void CalculateRevenue(map<Id,BookingEvent__c> events)
        {
            InitializeForecastRevenue(events.Values());
            InitializeBookedActualRevenue(events.Values());
            AddPackageEventRevenue(events);
            AddEventItemRevenue(events);
        }
        
        private void CalculateRevenue(list<BookingEvent__c> events)
        {
            InitializeForecastRevenue(events);
            InitializeBookedActualRevenue(events);
        }
   }
   
    
    /*  this class will implement a verification to determine that the person updating the event actually has permissions to do so
        US:44586
        Users with Read-Write access referred to in this user story include the Booking Owner, Additional Sales Manager, 
        Catering Manager, Service Manager, and any other user who is a member of the Read-Write Public Group for the Booking Property,
        also validate that users are not able to create events for a property that they do not have visiblity into 
        (this is because the Property picklist does not filter out properties that the user does not have access to).
        
        if the user updating the event doesn't have permission to do so throw insufficient permissions error
    */ 
    public class BookingEventAccessCheck implements Triggers.Handler {
        public void handle() {
            List<Id> bookings = new List<Id>(); 
                           
            for(BookingEvent__c be : (List<BookingEvent__c>)Trigger.New){
                bookings.add(be.Booking__c);
            }

            Map<String, Boolean> bookingAccessMap = new Map<String, Boolean>();
            for(UserRecordAccess ura : [Select RecordId, HasEditAccess From UserRecordAccess WHERE UserId =:UserInfo.getUserId() AND RecordId IN : bookings ]){
                   bookingAccessMap.put(ura.RecordId, ura.HasEditAccess);
            }
            for(BookingEvent__c be : (List<BookingEvent__c>)Trigger.New){
                 if (bookingAccessMap.get(be.Booking__c) == false)
                   be.addError(Label.InsufficientPrivileges);
            }
        }
    }

    public static boolean executeEventOutsideArrivalOrDeparture = true;
    public class EventOutsideArrivalOrDeparture implements Triggers.Handler {
        public void handle() {
        if (!executeEventOutsideArrivalOrDeparture ) return;
        
            List<Id> bookingsList = new List<Id>(); 
             
            for(BookingEvent__c be : (List<BookingEvent__c>)Trigger.New){
                bookingsList.add(be.Booking__c);
            } 
            
            map<id, booking__c> bookings = queriedInfo.Bookings;
             
            for(BookingEvent__c event : (List<BookingEvent__c>)Trigger.New){
               if (bookings.containsKey(event.booking__C )) {
                   booking__C parentBooking = bookings.get(event.booking__C);
                   if (event.StartDate__c != null && parentBooking.DepartureDate__C != null ) {
                       if  (parentBooking.DepartureDate__c.adddays(7) < event.StartDate__c ) {
                           event.addError(Label.BookingEventOutsideDays);
                           system.debug(loggingLevel.info, 'EventOutsideArrivalOrDeparture problem with parentBooking.DepartureDate__c.adddays(7) = ' + parentBooking.DepartureDate__c.adddays(7));
                       }
                   }     
                   if (event.StartDate__c != null && parentBooking.ArrivalDate__c != null ) {
                       if  (event.EndDate__c < parentBooking.ArrivalDate__c.adddays(-7)) {
                           event.addError(Label.BookingEventOutsideDays);
                           system.debug(loggingLevel.info, 'EventOutsideArrivalOrDeparture problem with parentBooking.ArrivalDate__c.adddays(-7)  = ' + parentBooking.ArrivalDate__c.adddays(-7));
                       }                                              
                   }                    
               }
               
            } 
  
        }
    }

    
    public class UpdateEventItems implements Triggers.Handler {
        public void handle() {
            if (updateFromBooking) return;
        
            //Unique list of EventIds whose items may need to be updated/recalculated
            Set<Id> eventIds = new Set<Id>(); 
            //Get a map of the old booking event values
            map<Id,BookingEvent__c> oldBookingEventValues = (map<Id,BookingEvent__c>)(Trigger.OldMap);
            //For the condition when Event start date/time is changed, store the offset number (in minutes) of the date/time difference to move event items the same amount.
            Map<Id, Long> dateTimeOffsetStartMap = new Map<Id, Long>();
            // For the condition when Event end date/time is changed, store the changed end date/time in order to move event items no later than the event date/time 
            Map<Id, DateTime> dateTimeEventEndNewDateMap = new Map<Id, DateTime>();
            // For the condition when Event end date/time is changed, store the old end date/time in order to determine, based on comparing its value to the item's serve end time. whether the item's serve end time has been customized 
            Map<Id, DateTime> dateTimeEventEndOldDateMap = new Map<Id, DateTime>();            
           
            //Holds list of items that need to be updated
            List<EventItem__c>itemsToUpdate = new List<EventItem__c>();
            
            boolean eventApplyChargesOverrideChanged = false;            
            for (BookingEvent__c event : (list<BookingEvent__c>)Trigger.New)
            {
                //JD: Check for trigger operation.  Trigger.old is not valid in an insert operation and will therefore throw a nullpointerexception
                /* Fix for Defect #66347   */ 
                //Determine if the actual covers value has changed to recalculate any "Per Person" items
                if (Trigger.isInsert || event.ForecastEventAttendance__c != oldBookingEventValues.get(event.Id).ForecastEventAttendance__c || event.AgreedEventAttendance__c != oldBookingEventValues.get(event.Id).AgreedEventAttendance__c || event.ActualAttendance__c != oldBookingEventValues.get(event.Id).ActualAttendance__c || event.GuaranteedEventAttendance__c != oldBookingEventValues.get(event.Id).GuaranteedEventAttendance__c)
                {
                    eventIds.add(event.Id);
                }
                
                //Find offset in case event dates have moved and apply that offset to the Event Items' service times (UPDATE only, not INSERT).
                if (Trigger.isUpdate && event.StartDate__c != null && oldBookingEventValues.get(event.Id).StartDate__c != null) {
                    DateTime dtEventStartNew = getDateTimeFromDateAndTimeStr24Hour(event.StartDate__c, event.StartTime24Hour__c);
                    DateTime dtEventStartOld = getDateTimeFromDateAndTimeStr24Hour(oldBookingEventValues.get(event.Id).StartDate__c, oldBookingEventValues.get(event.Id).StartTime24Hour__c);
                    if (dtEventStartOld.getTime() != dtEventStartNew.getTime()) {
                        //Store offset by Event Id 
                        dateTimeOffsetStartMap.put(event.Id, dtEventStartNew.getTime() - dtEventStartOld.getTime());
                        //system.debug(logginglevel.info, 'dateTimeOffsetStartMap = ' + dateTimeOffsetStartMap);
                        eventIds.add(event.Id);
                    }
                    
                    // Added for the case where event end has been modified
                    DateTime dtEventEndNew = getDateTimeFromDateAndTimeStr24Hour(event.EndDate__c, event.EndTime24Hour__c);
                    DateTime dtEventEndOld = getDateTimeFromDateAndTimeStr24Hour(oldBookingEventValues.get(event.Id).EndDate__c, oldBookingEventValues.get(event.Id).EndTime24Hour__c);
               
                    if (dtEventEndNew != dtEventEndOld) {
                        //Store new Event end date by Event Id 
                        system.debug(logginglevel.info, 'event new time != event old time');
                        dateTimeEventEndNewDateMap.put(event.Id, dtEventEndNew);
                        dateTimeEventEndOldDateMap.put(event.id, dtEventEndOld);
                        eventIds.add(event.Id);
                    }
                    system.debug(logginglevel.info, 'New event.EndTime24Hour__c = ' + event.EndTime24Hour__c);
                }
                
                // In order to call the eventItemCls trigger method EventItemCls.rollupRevenueToEvents(), we need to insert all the eventItems for the event(s) 
                // where the event ApplyChargesToDiscPriceOverride__c has been modified. 
                if (Trigger.isUpdate && event.ApplyChargesToDiscPriceOverride__c != oldBookingEventValues.get(event.Id).ApplyChargesToDiscPriceOverride__c)
                {
                    eventIds.add(event.Id);
                    eventApplyChargesOverrideChanged = true;
                }
            }
            
            //If no events eligible, do no more
            if (eventIds.size() == 0) return;
             
            Set<EventItem__c>eventItemSet = new Set<EventItem__c>();            
            //Loop through all items for the specified Events and either 1) apply the offset if the start date/time changed, or 2) if the item is Per Person, force recalc 
            for (EventItem__c eventItem : [SELECT Id, Event__c, ActualQuantity__c, BookedQuantity__c, QuantityCalculation__c, ServiceStartDate__c, ServiceEndDate__c, 
                                                ServiceStartTime24Hour__c, ServiceEndTime24Hour__c, ServiceStartTime12Hour__c, ServiceEndTime12Hour__c  
                                                FROM EventItem__c 
                                                WHERE Event__c = :eventIds
                                                LIMIT 50000] ) {
                                                    

                //adjust event item's service start/end times based on event start date/time changes                         
                if (dateTimeOffsetStartMap.containsKey(eventItem.Event__c)) 
                {  
                    if(eventItem.ServiceStartDate__c != null && eventItem.ServiceEndDate__c != null)
                    {  
                        Long offSet = dateTimeOffsetStartMap.get(eventItem.Event__c);  //get offset calculated before
                  
                        //Build datetime and add offset (in minutes)
                        DateTime dtEventItemServiceStartNew = getDateTimeFromDateAndTimeStr24Hour(eventItem.ServiceStartDate__c, eventItem.ServiceStartTime24Hour__c).addMinutes(Integer.valueOf((offSet / 60) / 1000));
                        DateTime dtEventItemServiceEndNew = getDateTimeFromDateAndTimeStr24Hour(eventItem.ServiceEndDate__c, eventItem.ServiceEndTime24Hour__c).addMinutes(Integer.valueOf((offSet / 60) / 1000));
  
                        // Set the service start date/time to new offset start datetime
                        eventItem.ServiceStartDate__c = dtEventItemServiceStartNew.dateGmt();
                        eventItem.ServiceStartTime12Hour__c = dtEventItemServiceStartNew.formatGmt('h:mm a');
                        eventItem.ServiceStartTime24Hour__c = NI.convert12To24Hour(eventItem.ServiceStartTime12Hour__c);   
 
                        //if the event end date/time has been modified to be earlier than then eventItem's end date/time, and the serve end time has not been customized, set the eventItem's datetime = event's new end time
                        DateTime dtEventEndNew = dateTimeEventEndNewDateMap.get(eventItem.Event__c);
                        DateTime dtEventEndOld = dateTimeEventEndOldDateMap.get(eventItem.Event__c);
                        DateTime dtEventItemServiceEndOld = getDateTimeFromDateAndTimeStr24Hour(eventitem.ServiceEndDate__c, eventItem.ServiceEndTime24Hour__c);
                        system.debug(logginglevel.info, 'dtEventEndOld= ' + dtEventEndOld);
                        system.debug(logginglevel.info, 'dtEventItemServiceEndOld = ' + dtEventItemServiceEndOld );
                        if (dtEventEndOld >= dtEventItemServiceEndOld) {  // service end datetime is not customized, so compare against new event end date
                            // use the event's end datetime
                            eventItem.ServiceEndDate__c = dtEventEndNew.dateGmt();
                            eventItem.ServiceEndTime12Hour__c = dtEventEndNew.formatGmt('h:mm a'); 
                            eventItem.ServiceEndTime24Hour__c = NI.convert12To24Hour(eventItem.ServiceEndTime12Hour__c);
                            system.debug(logginglevel.info, 'setting eventitem.serviceEndDate__c = event new endaDateTime: ' + eventItem.ServiceEndDate__c);
                        }
 
                        system.debug(logginglevel.info, 'dtEventItemServiceEndNew= ' + dtEventItemServiceEndNew);
                        system.debug(logginglevel.info, 'eventItem.ServiceEndTime12Hour__c= ' + eventItem.ServiceEndTime12Hour__c);
 
                        itemsToUpdate.add(eventItem);
                    }
                }

                // If it's in here, it's because the event end date/time has been changed
                else if (dateTimeEventEndNewDateMap.containsKey(eventItem.Event__c)) 
                {
                    DateTime dtEventEndNew = dateTimeEventEndNewDateMap.get(eventItem.Event__c);
                    DateTime dtEventEndOld = dateTimeEventEndOldDateMap.get(eventItem.Event__c);
                    system.debug(logginglevel.info, 'dtEventNewEnd = ' + dtEventEndNew);
 
                    DateTime dtEventItemServiceEnd = getDateTimeFromDateAndTimeStr24Hour(eventitem.ServiceEndDate__c, eventItem.ServiceEndTime24Hour__c);
                    system.debug(logginglevel.info, 'dtEventItemServiceEnd = ' + dtEventItemServiceEnd );

                    //if the event end date/time has been modified to be earlier than then eventItem's end date/time, set the eventItem's datetime = event's new end time
                    if (dtEventEndOld >= dtEventItemServiceEnd) {  // service end datetime is not customized, so compare against new event end date
                        if (dtEventEndNew < dtEventItemServiceEnd ) {
                            eventItem.ServiceEndDate__c = dtEventEndNew.dateGmt();
                            eventItem.ServiceEndTime12Hour__c = dtEventEndNew.formatGmt('h:mm a'); 
                            eventItem.ServiceEndTime24Hour__c = NI.convert12To24Hour(eventItem.ServiceEndTime12Hour__c);
                            system.debug(logginglevel.info, 'setting eventItem.ServiceEndTime24Hour__c = event new EndTime24Hour__c: ' + eventItem.ServiceEndTime24Hour__c);
                   
                            system.debug(logginglevel.info, 'setting eventitem.serviceEndDate__c = event new endaDateTime: ' + eventItem.ServiceEndDate__c);
                        }
                    }
                    itemsToUpdate.add(eventItem);
                }
         
                //recalulate "Per Person" items with updated event cover count. 
                else if (eventItem.QuantityCalculation__c == 'Per Person') 
                {  
                    itemsToUpdate.add(eventItem);
                }
      
                if (eventApplyChargesOverrideChanged) {
                    itemsToUpdate.add(eventItem);
                }
            }
            
            // Remove possible duplicate eventItems from list, then perform the update
            List<eventItem__c> uniqueEventItemList = new List<eventItem__c>();
            if (itemsToUpdate.size() > 0)
            {
                eventItemSet.AddAll(itemsToUpdate);
                uniqueEventItemList.AddAll(eventItemSet);
                Security.UpdateWithFLSCheck(uniqueEventItemList);
            }
         }
        
        //Concatenates a Date (DATE) value and 24 hour time (STRING) and generates a real DateTime
        private DateTime getDateTimeFromDateAndTimeStr24Hour(Date realDate, String timeStr24Hour) {
            if (timeStr24Hour != null) 
                return datetime.newInstanceGmt(realDate, Time.newInstance(Integer.valueof(timeStr24Hour.split(':')[0]), Integer.valueof(timeStr24Hour.split(':')[1]), 0, 0));
            else 
                return datetime.newInstanceGmt(realDate, Time.newInstance(0, 0, 0, 0));
        }
    } 
    
    public static boolean skipApplyDateChangeToDocument = false;
    public class applyDateChangeToDocument implements Triggers.Handler {
        public void handle() {
        
            system.debug(logginglevel.info, 'In applyChangeToDocument');
        
            if (skipApplyDateChangeToDocument) return;
            
            //in the case of a delete, get data from Trigger.Old
            List<BookingEvent__c> triggerBookingEvents = (Trigger.isUpdate || Trigger.isInsert)? (List<BookingEvent__c>)Trigger.New: (List<BookingEvent__c>)Trigger.Old ;
             
            Map<Id, BookingEvent__c> oldBookingEvents;
            if(Trigger.isUpdate) oldBookingEvents = (Map<Id, BookingEvent__c>)Trigger.oldMap;
            
            Set<Id> beoIds = new set<Id>();
            
            for(BookingEvent__c event : triggerBookingEvents) {
                boolean relevantChange = false;
                 
                if (!Trigger.isUpdate && event.beo__C != null) relevantChange= true;
                if (Trigger.isUpdate) {
                    relevantChange= (event.StartDate__c !=  oldBookingEvents.get(event.id).StartDate__c
                                || event.beo__C !=  oldBookingEvents.get(event.id).beo__c);       
                    system.debug (loggingLevel.info, '    relevantChange = ' + relevantChange + ' for event = ' +  event.id);                                          
                }
                if (relevantChange) {
                    if (event.beo__C != null) {
                        beoIds.add(event.beo__C);
                    }
                    if (event.banquetCheck__c != null) {
                        beoIds.add(event.banquetCheck__c);
                    }
                    if (Trigger.isUpdate && oldBookingEvents.get(event.id).beo__c != null && oldBookingEvents.get(event.id).beo__c != event.beo__C) {
                        beoIds.add( oldBookingEvents.get(event.id).beo__c );
                        beoIds.add( oldBookingEvents.get(event.id).banquetCheck__c );
                    }                        
                }  
            }
            
            system.debug (loggingLevel.info, ' BEO set = ' +  beoids);         
            if (beoids.size() == 0 ) return;
            
            list<bookingDocument__c> updateBEOs = new list<bookingDocument__c>();
            AggregateResult[] minDateByBEO =
                [SELECT BEO__r.id,  min(startdate__c) minEventDate
                 FROM Bookingevent__c
                 WHERE BEO__C in : beoIds
                 GROUP BY BEO__r.id ];
            
           system.debug (loggingLevel.info, ' minDateByBEO  = ' +  minDateByBEO );   
           for(AggregateResult minDate: minDateByBEO) {
             Id thisBEOid = string.valueOf(minDate.get('Id'));
             bookingDocument__c thisBEO = new bookingDocument__c(Id=thisBEOid);   
             thisBEO.BookingDocumentEventDate__c = date.valueOf(string.valueOf(minDate.get('minEventDate')));
             updateBEOs.add(thisBEO ); 
          
           }
           
           // Update the min event date on the banquetcheck bookingDocument record that is paired with the BEO
           List<bookingevent__c> bookingEventList = [select beo__r.id, banquetCheck__c, startDate__c from bookingEvent__c WHERE BEO__C in : beoIds order by BEO__r.id, startdate__c];
           
           /* foreach bookingEvent record returned (sorted by startDate):
                get it's beo__r.id
                if not in the list of updateBEOs, continue: 
                    get it's first record's date (this will be the earliest date)
                    get it's banquetCheck__c number and convert it to an ID
                    create a new bookingDocument record and update it with the banquetCheck__c
                    update it's BookingDocumentEvent__c with the first record's date (minimum)
                    add this new bookingDocument record to the list of updateBEOs
          */      
           Set<String> updateBeosSet = new Set<String>();
           for (bookingEvent__c be : bookingEventList) {
               if (!updateBeosSet.contains(be.beo__r.id) && be.BanquetCheck__c != null) {
                   bookingDocument__c BCDocument = new bookingDocument__c(Id=be.banquetCheck__c);
                   BCDocument.BookingDocumentEventDate__c = be.startDate__c;
                   updateBeosSet.Add(be.beo__r.id);
                   updateBeos.Add(BCDocument );
               }
           }
           
           system.debug (loggingLevel.info, ' updateBEOs  = ' +  updateBEOs );       
           Security.UpdateWithFLSCheck(updateBEOs);
   
        }
    }

  public class GenerateObjectNotificationsForIntegration implements Triggers.Handler{

    public void handle(){
        
        List<BookingEvent__c> records = (List<BookingEvent__c>)(Trigger.isDelete ? Trigger.old : Trigger.new);
        
        List<ObjectNotification__c> notifications = new List<ObjectNotification__c>();
        Map<Id, Set<BookingRoomBlock__c>> loc_blockIds = new Map<Id, Set<BookingRoomBlock__c>>();
        
        Map<Id, ObjectSubscription__c> blockSubscriptions = new Map<Id, ObjectSubscription__c>(); 
        
        Set<Id> eventIds = new Set<Id>();
       
        
        for(BookingEvent__c bevent : records){
            
            if(Trigger.isUpdate){
            
                BookingEvent__c oldbevent = (BookingEvent__c)Trigger.oldMap.get(bevent.Id);
                if(doesRecordNeedToGenerateNotification(bevent, oldbevent))                    
                    eventIds.add(bevent.Id);
            
            }
        }

        for(BookingPackageEvent__c bpe : queriedInfo.PackageEvents.values()){
            if(bpe.BookingPackage__c != null && bpe.BookingPackage__r.BookingRoomBlock__c != null){
                
                LocationIntegrationSettings__c locSettings = LocationIntegrationSettingsCls.getLocationSettings(bpe.BookingPackage__r.BookingRoomBlock__r.Location__c);
                
                if(locSettings != null && locSettings.SendRateDetail__c == 'Inclusive Package'){
                
                    if(!loc_blockIds.containsKey(bpe.BookingPackage__r.BookingRoomBlock__r.Location__c))
                        loc_blockIds.put(bpe.BookingPackage__r.BookingRoomBlock__r.Location__c, new Set<BookingRoomBlock__c>());
                    loc_blockIds.get(bpe.BookingPackage__r.BookingRoomBlock__r.Location__c).add(bpe.BookingPackage__r.BookingRoomBlock__r);

                }

            }
        }

        if(!loc_blockIds.isEmpty()){

            for(ObjectSubscription__c sub : [SELECT Id, Name, IsEnabled__c, Integration__c, Integration__r.Name, 
                                                ObjectType__c, CaptureOldValues__c, CaptureNewValues__c, 
                                                CaptureLocation__c, CaptureFields__c 
                                            FROM ObjectSubscription__c 
                                            WHERE ObjectType__c =: PrefixMgr.getObjName('BookingRoomBlock__c')]){
                
                blockSubscriptions.put(sub.Integration__c, sub);
            }

            for(Id locId : loc_blockIds.keySet()){

                for(BookingRoomBlock__c block : loc_blockIds.get(locId)){
                
                    LocationIntegrationSettings__c locSettings = LocationIntegrationSettingsCls.getLocationSettings(block.Location__c); 
                    
                    ObjectNotification__c notification = ObjectNotificationCls.generateNotification(block, blockSubscriptions.get(locSettings.Integration__c));
                    notifications.add(notification);  
                        
                }
            }

            ObjectNotificationCls.addToObjectNotificationContext(notifications);
        }

    }

    private boolean doesRecordNeedToGenerateNotification(BookingEvent__c bevent, BookingEvent__c oldbevent){
        return (oldbevent.TaxGroup__c != bevent.TaxGroup__c);
    }

}

    public class enableDefaulting implements Triggers.Handler {
        public void handle(){
            enableAverageCheckDefaulting = true;      
        }
    }


  /////////////////////////////////////////////////////////////////////////////
  //  
  //
  //-----Start of the Deferred Handler for BookingEvent------------------------
  //
  //
  /////////////////////////////////////////////////////////////////////////////


  public class BookingEventDeferredHandler extends Context.Handler{

        public BookingEventDeferredHandler(){
            super('BookingEvent');
        }

        public override void clean(){
            BookingEventContextMap = null;
        }
        
        public override void handle(){
            
            if(BookingEventContextMap == null || BookingEventContextMap.isEmpty())
                return; 

            system.debug('entered BookingEventDeferredHandler' + BookingEventContextMap);
            
            Set<String> eventIds = BookingEventContextMap.keySet();
            
            RollupRevenue = true;
             //RollupRevenue = true; 
            BookingEventContextMap = null;

            update [SELECT Id from BookingEvent__c WHERE Id IN: eventIds];
  
        }
        
    }
    
    
    //builds out a context store for GuestroomTypeDays to do one bulk update at the end of a 
    //trigger context
    public class BookingEventContextTemplate {
        
        public String EventId {get; set;}
        
        public BookingEventContextTemplate(String evntId){
            
            this.EventId = evntId; 
            
            if(String.isEmpty(this.EventId))
                throw new Ni.NiException('An Event Id is required to create a Booking Event Context record');

        }
    }
    
    
    public static Map<String, BookingEventContextTemplate> BookingEventContextMap {get; set;}
    
    public static void addToBookingEventContext(String evntId){
        
        if(BookingEventContextMap == null){
            BookingEventContextMap = new Map<String, BookingEventContextTemplate>();
            Context.registerDeferredOperations(new BookingEventDeferredHandler());
        }
        
        BookingEventContextTemplate newRecord = new BookingEventContextTemplate(evntId);
        
        if(!BookingEventContextMap.containsKey(newRecord.EventId))
            BookingEventContextMap.put(newRecord.EventId, newRecord);
        
    }

    public static void addToBookingEventContext(Set<Id> evntIds){
        
        if(BookingEventContextMap == null){
            BookingEventContextMap = new Map<String, BookingEventContextTemplate>();
            Context.registerDeferredOperations(new BookingEventDeferredHandler());
        }

        for(Id i : evntIds){
        
            BookingEventContextTemplate newRecord = new BookingEventContextTemplate(i);
            
            if(!BookingEventContextMap.containsKey(newRecord.EventId))
                BookingEventContextMap.put(newRecord.EventId, newRecord);

        }
        
    }
}