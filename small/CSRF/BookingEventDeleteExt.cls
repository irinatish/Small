public with sharing class BookingEventDeleteExt {

	// User Story 243143: Override the Delete button on Booking Event
	// Override Delete Operation on BookingEvent__c object

	private ApexPages.StandardController sc;
	public string retBackUrl {get; private set;}
	private string retBackUrlFail;

	public BookingEventDeleteExt(ApexPages.StandardController stdController) {
		this.sc = stdController;
		this.retBackUrl = ApexPages.currentPage().getParameters().get('retURL');
		this.retBackUrlFail = ApexPages.currentPage().getParameters().get('failRetURL');
	}

	public PageReference deleteEvent() {

		system.debug(LoggingLevel.ERROR, this.sc.getRecord());

		try {
			new CustomActions().deleteEvent(this.sc.getId());
			return new PageReference(this.retBackUrl);
		}
		catch(Exception ex) {
			ApexPages.addmessage(new ApexPages.message(ApexPages.severity.Error, ex.getMessage()));
			this.retBackUrl = !string.isBlank(this.retBackUrlFail) ? this.retBackUrlFail : this.retBackUrl;
			return null;
		}
	}

	// Here is without sharing, because User should be able to delete record even he doesn't have access to delete record
	// Return Booking Id after successfull delete
	public without sharing class CustomActions {

		public void deleteEvent(Id bookingEventId) {
			if (bookingEventId == null) {
				throw new NI.NIException(Label.IncorrectBookingId);
			}
			deleteEvents(new set<Id>{bookingEventId});
			return;
		}

		public void deleteEvents(set<Id> setBbookingEventId) {

			if (!(setBbookingEventId != null && !setBbookingEventId.isEmpty())) {
				throw new NI.NIException(Label.IncorrectBookingId);
			}

			Security.checkIsObjectDeletable('BookingEvent__c');

			boolean isAllowDeleteEventSetting = false;

			NiPublic__c niSettings = NiPublic__c.getOrgDefaults();
            if (niSettings != null) {
                isAllowDeleteEventSetting = niSettings.AllowDeleteEventsOnBookings__c;
            }

			list<BookingEvent__c> listBE = [
				SELECT Id
					, Booking__c
					, Booking__r.AdditionalSalesManager__c
					, Booking__r.CateringManager__c
					, Booking__r.OtherManager__c
					, Booking__r.ServiceManager__c
					, Booking__r.OtherSource1__c
					, Booking__r.OtherSource2__c
					, Booking__r.OtherSource3__c
					, Booking__r.OtherSource4__c
					, Booking__r.ServiceAssistant__c
					, Location__c
					, OwnerId
					, Booking__r.OwnerId
				FROM BookingEvent__c
				WHERE Id IN :setBbookingEventId
			];

			if (listBE.isEmpty()) {
				throw new NI.NIException(Label.BookingRecapReportNoRecord);
			}

			list<BookingEvent__c> listBeDelete = new list<BookingEvent__c>();

			for (BookingEvent__c be : listBE) {

				checkIfUserCanDeleteEvent(be, isAllowDeleteEventSetting);

				listBeDelete.add(be);
			}

			if (!listBeDelete.isEmpty()) {
				Security.checkIsObjectDeletable('BookingEvent__c');
				delete listBeDelete;
			}
			return;
		}

		// Method check If User can delete event using custom logic
		// Throw exception if user cannot delete event
		// Fixed issue Bug 257807: Modify All permission doesn't allow to delete Booking Events		
		@TestVisible private void checkIfUserCanDeleteEvent(BookingEvent__c bookingEvent, boolean isAllowDeleteEventSetting) {

			BookingEvent__c be = bookingEvent;

			// Check Permission by following Rules:

			// The Booking Event can be deleted by:
			// Booking Event owner (native SF logic)

			boolean isUserHasNativeAccess = checkIfUserCanDeleteEvent(be);

			if (isUserHasNativeAccess == true) {
				return;
			}

			if (isAllowDeleteEventSetting == false) {
				throw new NI.NIException(Label.BookingEventDeleteFeatureNotActivated);
			}
		}

		// Method check If User can delete event using custom logic
		// Throw exception if user cannot delete event
		// Will return true if User has native access to Record for Delete
		@TestVisible private boolean checkIfUserCanDeleteEvent(BookingEvent__c bookingEvent) {

			boolean isUserHasNativeAccess = false;

			BookingEvent__c be = bookingEvent;

			// Check Permission by following Rules:

			// 1. User who is the Booking Event Owner
			// 2. User who has native permission for Delete this record

			// User who has native Edit Permission on Booking Event record and (3 or 4 or 5) and (setting NiPublic__c.AllowDeleteEventsOnBookings__c is enabled)
				// 3. User who is the Booking Owner
				// 4. User who has Read/Write (Property Admin) access to a property where Event takes place
				// 5. User who is related to the Booking via one of the following lookups: 

			
			Id userId = UserInfo.getUserId();

			// 1. Booking Event owner (native SF logic)
			if (be.OwnerId == userId) {
				return true;
			}

			// Check if User able to edit or delete current record (Additional security check)

			UserRecordAccess userAccessToEventRecord = [SELECT HasEditAccess, HasDeleteAccess, RecordId FROM UserRecordAccess WHERE UserId = :userId AND RecordId = :be.Id];
			
			// 2. 
			if (userAccessToEventRecord.HasDeleteAccess == true) {
				return true;
			}

			// Check if user has native edit access to Booking Event
			if (userAccessToEventRecord.HasEditAccess == false) {
				throw new NI.NIException(Label.BookingEventDeleteAccessDenied);
			}

			// 3. User who is the Booking Owner
			if (be.Booking__r.OwnerId == userId) {
				return false;
			}

			// 4. User who has Read/Write (Property Admin) access to a property where Event takes place
			if (be.Location__c != null) {
				UserRecordAccess userAccessToLocationRecord = [SELECT HasEditAccess, RecordId FROM UserRecordAccess WHERE UserId = :userId AND RecordId = :be.Location__c];
				if (userAccessToLocationRecord.HasEditAccess == true) {
					return false;
				}
			}

			// 5. User who is related to the Booking via one of the following lookups: 
			
			// AdditionalSalesManager__c
			// CateringManager__c
			// OtherManager__c
			// ServiceManager__c
			// OtherSource1__c
			// OtherSource2__c
			// OtherSource3__c
			// OtherSource4__c
			// ServiceAssistant__c

			if (be.Booking__r.AdditionalSalesManager__c == userId || be.Booking__r.CateringManager__c == userId
				|| be.Booking__r.OtherManager__c == userId || be.Booking__r.ServiceManager__c == userId
				|| be.Booking__r.OtherSource1__c == userId || be.Booking__r.OtherSource2__c == userId
				|| be.Booking__r.OtherSource3__c == userId || be.Booking__r.OtherSource4__c == userId
				|| be.Booking__r.ServiceAssistant__c == userId) {

				return false;
			}

			throw new NI.NIException(Label.BookingEventDeleteAccessDenied);
		}
	}
}