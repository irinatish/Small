//Runs after the package is installed or upgraded.
//JD: 5/25/2016 - Changed this class to Without Sharing due to upgrade issues.  Per Salesforce, this will be acceptable during the security review And therefore should Not be changed.
Global without sharing Class PostInstaller Implements InstallHandler  {

	global static void SetOauthClientIdAndSecret()
	{
		try
		{
			NiProtected__c niProtectedSettings;
			if(NiProtected__c.getValues('Default') != null)
			{
				niProtectedSettings = NiProtected__c.getValues('Default');
			}
			else
			{
				niProtectedSettings = new NiProtected__c();
				niProtectedSettings.Name = 'Default';
			}
			niProtectedSettings.MergeOauthClientId__c = '3MVG9A2kN3Bn17hvcGWxQFwr6mgzfk8PvkJJIaYqe7T5p39MibGlJv_xjS6Bybp8DXcjedP_WOJnddz2iDDrA';
			niProtectedSettings.MergeOauthClientIdSandbox__c = '3MVG9A2kN3Bn17hvcGWxQFwr6mmUY1QdGX_PUlEMs.eeUoTRKP7FZCadp6Jq2j8CGaeh.1OZ6O2UuDP_lS0Lu';
			niProtectedSettings.MergeOauthClientSecret__c = '1044516597432564539';
			niProtectedSettings.MergeOauthClientSecretSandbox__c = '5194318642354523936';
			niProtectedSettings.NcOauthClientId__c = '3MVG9A2kN3Bn17hvcGWxQFwr6mvPrdKglmALFF4UCzUOwKX8V98BAhO1x9Fl5ePrhBnyIFnhmLz1BDN0JtoCI';
			niProtectedSettings.NcOauthClientIdSandbox__c = '3MVG9A2kN3Bn17hvcGWxQFwr6msAJ8QiPFm29iUbjTlEbbqXXPs7sfN4qu9ADPwCN7hvXrBzTfJCvPfJmKkan';
			niProtectedSettings.NcOauthClientSecret__c = '3097463750449468964';
			niProtectedSettings.NcOauthClientSecretSandbox__c = '6738300370590341964';
			niProtectedSettings.NwsOauthClientId__c = '3MVG9A2kN3Bn17hvcGWxQFwr6mnNcu_..WvTOPtVE1EI.EpXLDYshkuxqSjsQM9o41vO4zNlqxaUfiw2eqjCl';
			niProtectedSettings.NwsOauthClientSecret__c = '7004409725351287512';
			niProtectedSettings.ReportsConsumerSecretDEV__c = '1719759051651076381';
			niProtectedSettings.ReportsConsumerSecretQA__c = '2857989655060125574';
			niProtectedSettings.ReportsConsumerSecretSTAG__c = '5691867674330532257';
			niProtectedSettings.ReportsConsumerSecret__c = '1309465656795445948';
			niProtectedSettings.NcClientClientId__c = 'A24722A6-58A7-4669-9E9F-241F2C484EFD';
			niProtectedSettings.NcClientClientSecret__c = '87FB8DF0-693C-4950-91FB-E215699CBA26';	
			niProtectedSettings.HospitalityDiagrammingId__c = 'E279BB3E-9C56-4AD5-A2A5-7DB401EB521B';	
			niProtectedSettings.HospitalityDiagrammingUrl__c ='https://iplan.newmarketinc.com/bookings#/integration?SystemId={0}&BookingEventId={1}';
			upsert niProtectedSettings;
		}
		catch (System.Exception e)
		{
			LogCls.write(e, 'SetOauthClientIdAndSecret', null);

		}
	}

	global void onInstall(InstallContext context) {
			
		
		SetOauthClientIdAndSecret();

		//Check if this is an upgrade
		if(context.previousVersion() != null)
		{
			//If Upgrading from R8 or earlier we need to copy Total Attendance to Event Attendance and Total Quantity to Event Quantity
			if(context.previousVersion().compareTo(new Version(1,65)) < 0)
			{
			    Version8UpgradeScripts();
			}
			
			//If Upgrading from R12 or earlier we need to populate the Function Room Affects field on the Function Room (related Function Room Ids for combo/child rooms)
			if(context.previousVersion().compareTo(new Version(1,86)) < 0)
			{
			    Version12UpgradeScripts();
			}
			
			//If Upgrading from R13 or earlier we need to populate the numeric fields used for aggregating currency data
			if(context.previousVersion().compareTo(new Version(1,88)) < 0)
			{
			     Version13UpgradeScriptsGroup1();
			     Version13UpgradeScriptsGroup2();
			}
			
			//If Upgrading from R14 or earlier we need to populate the PMSIdIndexed field
			if(context.previousVersion().compareTo(new Version(1,93)) < 0)
			{
				Version14UpgradeScripts();
			}	
		}
		
	}

	@TestVisible
	private static void Version8UpgradeScripts() {
		BatchUpdateBookingEventAttendance batchpr1 = new BatchUpdateBookingEventAttendance ();
		Id batchprocess1Id = Database.executeBatch(batchpr1);
		    
		BatchUpdateEventItemQuantity batchpr2 = new BatchUpdateEventItemQuantity ();
		Id batchprocess2Id = Database.executeBatch(batchpr2);
	}

	@TestVisible
	private static void Version12UpgradeScripts() {
		BatchUpdateFunctionRoomAffects batchpr1 = new BatchUpdateFunctionRoomAffects ();
		Id batchprocess1Id = Database.executeBatch(batchpr1, 100);
	}

	@TestVisible
	private static void Version13UpgradeScriptsGroup1() {
		BatchUpdateEventItemNumberFields batchpr1 = new BatchUpdateEventItemNumberFields ();
	    Id batchprocess1Id = Database.executeBatch(batchpr1, 1000);
	    
	    BatchUpdateBkgPackageEventNumberFields batchpr2 = new BatchUpdateBkgPackageEventNumberFields ();
	    Id batchprocess2Id = Database.executeBatch(batchpr2, 1000);
	    
	    BatchUpdateBookingEventNumberFields batchpr3 = new BatchUpdateBookingEventNumberFields ();
	    Id batchprocess3Id = Database.executeBatch(batchpr3, 1000);
	    
	    BatchUpdateBkgOtherIncomeNumberFields batchpr4 = new BatchUpdateBkgOtherIncomeNumberFields ();
	    Id batchprocess4Id = Database.executeBatch(batchpr4, 1000);
	    
	    BatchUpdateBookingRoomBlockNumberFields batchpr5 = new BatchUpdateBookingRoomBlockNumberFields ();
	    Id batchprocess5Id = Database.executeBatch(batchpr5, 1000);
	}

	@TestVisible
	private static void Version13UpgradeScriptsGroup2() {
		BatchUpdateGuestroomTypeDayNumberFields batchpr1 = new BatchUpdateGuestroomTypeDayNumberFields ();
	    Id batchprocess1Id = Database.executeBatch(batchpr1, 1000);

   		BatchUpdateEventItemBreakdownUnitPrice batchpr2 = new BatchUpdateEventItemBreakdownUnitPrice ();
	    Id batchprocess2Id = Database.executeBatch(batchpr2, 1000);
	}
	
	@TestVisible
	private static void Version14UpgradeScripts() {
		BatchUpdatePmsIdIndexed batchpr1 = new BatchUpdatePmsIdIndexed();
		Id batchprocess1Id = Database.executeBatch(batchpr1, 5000);
		
		BatchConvertRoomBlockRevenue batchpr2 = new BatchConvertRoomBlockRevenue();
		Id batchprocess2Id = Database.executeBatch(batchpr2, 1000);
		
		BatchUpdateEventPackageItemExternalId batchpr3 = new BatchUpdateEventPackageItemExternalId();
		Id batchprocess3Id = Database.executeBatch(batchpr3, 1000);
	}

}