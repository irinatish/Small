global with sharing class Purge{
        
    //Enum for target table   
    global enum Types{LogEntry, Message, ProcessorJob}
    
    //Enum for state of the job
    public enum JobState{RUNNING, SCHEDULED, CANCELLED, SCHEDULEDRUNNING}
    
    //Enum for days to retain
    public enum DaysToRetain{THIRTY, SIXTY, NINETY, ONEHUNDREDEIGHTY, THREEHUNDREDSIXTYFIVE}
    
    //Holds all job state values
    public static Map<JobState, String> stateMap = new Map<JobState, String>{JobState.RUNNING => 'RUNNING',
    																  JobState.SCHEDULED => 'SCHEDULED',
    																  JobState.CANCELLED => 'CANCELLED',
    																  JobState.SCHEDULEDRUNNING => 'SCHEDULED and RUNNING'};
    
    public static final Integer TYPELABELINDEX = 0;
    public static final Integer TYPENAMEINDEX = 1;
    
    //Holds all days to retain values
    public static Map<DaysToRetain, String> dtrMap = new Map<DaysToRetain, String>{
    	DaysToRetain.THIRTY => '30', 
    	DaysToRetain.SIXTY => '60',
    	DaysToRetain.NINETY => '90',
    	DaysToRetain.ONEHUNDREDEIGHTY => '180',
    	DaysToRetain.THREEHUNDREDSIXTYFIVE => '365'};
    
    //Holds all target table types
    //The list holds: Type Label, Type name, Type minimum days to retain
    public static Map<Types, List<String>> typeMap = new Map<Types, List<String>>{
    	Types.LogEntry 			=> new List<String>{getObjectLabel('Log__c'), 'Log__c'},
    	Types.Message 			=> new List<String>{getObjectLabel('Message__c'), 'Message__c'},
    	Types.ProcessorJob 		=> new List<String>{getObjectLabel('ProcessorJob__c'), 'ProcessorJob__c'}};
            
    //Strings to hold IDs of various jobs
  	public String jobID{get;set;}
  	
  	//Maximum number of objects deleted per batch cycle
  	private Integer objectsPerBatch = 10000;
  	
  	//The taret user
  	public User targetUser{get;set;}

  	//Time of day to run the purge
  	public Time runTime{get;set;}
  	
  	//String to hold the run time value
  	public String runTimeString{get;
  	set{
  		Integer hours = Integer.valueOf(value.substring(0,2));
  		Integer minutes = Integer.valueOf(value.substring(3,5));
  		runTime = Time.newInstance(hours, minutes, 0, 0);
  		runTimeString=value;
  	}}
  	
  	//List of all run time values
  	public List<SelectOption> runTimeList{get;set;}
  	
  	//List of all org user emails
  	public List<SelectOption> userEmailList{get;set;}
  	
  	//String to hold the notify by email value
  	public String notifyByEmail{get;set;}		
  	
  	//Type of object to purge
  	public Types targetTable{get;set;}
  	
  	//The days to retain
  	public DaysToRetain dtrObject{get;set;}
  	
  	//String to hold the value for the target table
  	public String targetTableString{get;set{  		
    	for(Types t : typeMap.keySet()){
    		if(getTypeMapIndex(t, TYPELABELINDEX).equals(value))
    			targetTable=t;    		
    	}
  		targetTableString=value;
  	}}
  	
  	//String to hold the value for days to retain
  	public String daysToRetainString{get{
  		if(daysToRetainString==null) daysToRetainString='180';
  		return daysToRetainString;
  	}set{
  		for(DaysToRetain d : dtrMap.keySet()){
  			if(dtrMap.get(d).equals(value))
  				dtrObject=d;
  		}
  		daysToRetainString=value;
  	}}
  	
  	//The current purge
  	public PurgeConfigurationStatus__c curPurge{get;set;}
  	
  	public List<PurgeInformationWrp> purgeInfoList{get{
  			List<PurgeInformationWrp> ret=new List<PurgeInformationWrp>();
  			purgeList=[SELECT 	BatchCancel__c,
  								BatchFinishTime__c,
  								CronJobID__c,
  								DateTimeCanceled__c,
  								DateTimeExecution__c,
  								DaysToKeep__c,
  								Enabled__c,
  								ExecutionTimeOfDay__c,
  								IsRunning__c,
  								State__c,
  								TargetObjectID__c,
  								TargetObjectString__c,
  								TargetUser__c,
  								UserEmail__c,
  								TargetUser__r.Name
  								FROM PurgeConfigurationStatus__c];
 
  			for(Integer i=0; i<purgeList.size(); i++)
  				ret.add(new PurgeInformationWrp(purgeList.get(i)));
  			
  			return ret;
  		}
  	set;}
  	
  	//List of all purges that have not been deleted
  	public List<PurgeConfigurationStatus__c> purgeList{get{
  	return [SELECT 			BatchCancel__c,
  							BatchFinishTime__c,
  							CronJobID__c,
  							DateTimeCanceled__c,
  							DateTimeExecution__c,
  							DaysToKeep__c,
  							Enabled__c,
  							ExecutionTimeOfDay__c,
  							IsRunning__c,
  							State__c,
  							TargetObjectID__c,
  							TargetObjectString__c,
  							TargetUser__c,
  							UserEmail__c,
  							TargetUser__r.Name
  							FROM PurgeConfigurationStatus__c];}
  		set;}
  	  	  	  	
  	//Constructor
  	public Purge(ApexPages.StandardController ctrl){  
  		targetUser = new User();	
  		curPurge = (PurgeConfigurationStatus__c)ctrl.getRecord();
  		populateRunTimes();
  		populateUserEmailList();  		
  	}
  	
  	
  	  	    
    //Purges once every 24 hours until the scheduled job is deleted
    public void purgeScheduled(){ 
        if(validateJobLimit()){
        	
            ScheduledPurge sp = new ScheduledPurge(dtrObject, targetTable, objectsPerBatch);
            
            //Syntax: Seconds Minutes Hours Day_of_month Month Day_of_week Optional_year
            String fireTime = 
                runTime.second()+
                ' '+
                runTime.minute()+
                ' '+
                runTime.hour()+
                ' * * ?';
            
            try{        	
            	jobID = System.schedule(targetTable.name()+' Purge', fireTime, sp);

  				CronTrigger ct=getCronTrigger(jobID);

  				refreshCurrentPurge();
  				
  				String curState;
    			if(curPurge.State__c==null) curState = stateMap.get(JobState.SCHEDULED);
    			else if(curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.RUNNING))) curState=stateMap.get(JobState.SCHEDULEDRUNNING);
    			else curState = stateMap.get(JobState.SCHEDULED);

      			addRecord(ct.NextFireTime, curState);
      		}
            catch(Exception e){
            	ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Only one purge can be scheduled for each target object.'));
            }
        }
        else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Scheduled job limit (100) exceeded. Cannot schedule purge.'));
    }
    
    //Purge right now.
    public void purgeNow(){  
    	refreshCurrentPurge();
  			   	
    	if(curPurge!=null && (curPurge.State__c==null || !curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.RUNNING)))){
    		if(validateJobLimit()){ 	
    			String curState;
    			if(curPurge.State__c==null) curState = stateMap.get(JobState.RUNNING);
    			else if(curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.SCHEDULED))) curState=stateMap.get(JobState.SCHEDULEDRUNNING);
    			else curState = stateMap.get(JobState.RUNNING);
    			
    			addRecord(null, curState);
         
        		BatchPurgeRecordObjects batchDelete = new BatchPurgeRecordObjects(dtrObject, targetTable);
				Id batchDeleteId = Database.executeBatch(batchDelete, objectsPerBatch);
      		}
       		else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Scheduled job limit (100) exceeded. Cannot schedule purge.'));
    	}
    	else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Purge is already running.'));
    }
    
    //Add a record to the page and make an entry in the database
  	public PageReference addRecord(DateTime nextFireTime, String state){  		
  		boolean isNewRecord;
  		if(purgeList==null || purgeList.size()==0){  			
  			curPurge=new PurgeConfigurationStatus__c();
  			isNewRecord=true;
  		}
  		else{  			
  			boolean alreadyExists = false;
  			for(Integer i=0; i<purgeList.size(); i++){
  				if(purgeList.get(i).TargetObjectString__c.equals(targetTableString)){
  					refreshCurrentPurge();
  					isNewRecord=false;
  					alreadyExists=true;
  					break;
  				}
  			}
  			
  			if(!alreadyExists){
  				curPurge=new PurgeConfigurationStatus__c();
  				isNewRecord=true;
  			}
  		}

  		
        if(nextFireTime!=null) curPurge.DateTimeExecution__c=nextFireTime;
  		
  		curPurge.TargetObjectID__c=targetTable.ordinal();
  		
  		curPurge.TargetObjectString__c=targetTableString;

		if(curPurge.CronJobID__c==null || curPurge.CronJobID__c.equalsIgnoreCase(''))
  			curPurge.CronJobID__c=jobID;
  		
  		curPurge.State__c=state;
  		
  		curPurge.UserEmail__c=UserInfo.getUserEmail();

  		curPurge.TargetUser__c=targetUser.Id;
  		 
  		curPurge.DaysToKeep__c=Integer.valueOf(daysToRetainString);
  		  		
  		curPurge.BatchCancel__c=false;
  		  		  		
  		if(isNewRecord) insert curPurge;
  		else update curPurge;
  		
  		return null;
  	}
        
    //Salesforce has a 100 job limit for the scheduler
    private boolean validateJobLimit(){
        //JobType 7 = Scheduled Apex
        //JobType 9 = Batch Job
        Integer jobCount = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.JobType = '7'];
        if(jobCount<100) return true;
        else return false;
    }

    //Unschedule a scheduled purge
    public void unschedulePurge(){
    	if(purgeList!=null&&purgeList.size()>0){
    		refreshCurrentPurge();
			
			if(curPurge.CronJobId__c!=null){
    			curPurge.DateTimeCanceled__c=DateTime.Now();
    			curPurge.DateTimeExecution__c=null;
    			if(curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.SCHEDULEDRUNNING))) curPurge.State__c=stateMap.get(JobState.RUNNING);
    			else curPurge.State__c=stateMap.get(JobState.CANCELLED);
    			jobID = curPurge.CronJobId__c;
       			try{
    				System.abortJob(jobID);
    				curPurge.CronJobId__c=null;
    				jobId=null;
    			}
    			catch(Exception e){
    				ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'There was an error aborting a scheduled job with ID: '+jobID));
    			}
    	        security.checkAreFieldsUpdateable(curPurge);
    			update curPurge;
    		}
    		else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'There are no scheduled purges to unschedule.'));
    	}
    	else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'There are no scheduled purges to unschedule.'));
    }
    
    //Abort a running purge
    public void abortPurge(){
    	if(purgeList!=null && purgeList.size()>0){
    	   
    	   refreshCurrentPurge();    	  
    	   
    	   	if(curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.RUNNING)) || 
    	   	curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.SCHEDULEDRUNNING))){
    	   				
    			curPurge.DateTimeCanceled__c=DateTime.Now();
    			curPurge.BatchCancel__c=true;
    		
    			String curState;
    				if(curPurge.State__c.equalsIgnoreCase(stateMap.get(JobState.SCHEDULEDRUNNING))) curState=stateMap.get(JobState.SCHEDULED);
    				else curState = stateMap.get(JobState.CANCELLED);
    			
    			curPurge.State__c=curState;
    			security.checkAreFieldsUpdateable(curPurge);
    			update curPurge;    
    		}
    		else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'There are no running purges to stop.'));

    	}
      	else ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'There are no running purges to stop.'));
    }
     	
  	//Set the target user
  	public void setTargetUser(){
  		try{
  			targetUser = [SELECT id, Name FROM User WHERE id=:curPurge.TargetUser__c];
  		}
  		catch(Exception e){
  			targetUser=null;
  		}
  	}
  	
  	//Populate the list of org user emails
  	public void populateUserEmailList(){
  		userEmailList = new List<SelectOption>();
  		for(User u : [SELECT email FROM User])
  			userEmailList.add(new SelectOption(u.Email, u.Email));
  			
  		//This logic removes duplicates
  		Set<SelectOption> myset = new Set<SelectOption>();
  		List<SelectOption> result = new List<SelectOption>();
  		myset.addAll(userEmailList);
  		result.addAll(mySet);
  		userEmailList=result;
  	}
  	
  	//Populate the list of runtimes
  	public void populateRunTimes(){  		
  		runTimeList = new List<SelectOption>();
  		Schema.DescribeFieldResult runTimesDescription = PurgeConfigurationStatus__c.ExecutionTimeOfDay__c.getDescribe();
  		
  		for(Schema.Picklistentry ple : runTimesDescription.getPicklistValues())
  			runTimeList.add(new SelectOption(ple.getValue(), ple.getValue()));  		
  	}
    
    //Get the list of target object selectoptions
    public List<SelectOption> getTargetObjectItems(){
    	List<SelectOption> items = new List<SelectOption>();
    	for(Types t : typeMap.keySet())
    		items.add(new SelectOption(getTypeMapIndex(t, TYPELABELINDEX), getTypeMapIndex(t, TYPELABELINDEX)));
    		    	
    	return items;
    }
    
    //Get the list of days to retain selectoptions
     public List<SelectOption> getDaysToRetainItems(){
    	List<SelectOption> items = new List<SelectOption>();
    	for(DaysToRetain d : dtrMap.keySet())
    		items.add(new SelectOption(dtrMap.get(d), dtrMap.get(d)));    	
    	
    	return items;
    }
    
    //Get the name of the object
    public static String getTypeMapIndex(Types t, Integer index){
  		return typeMap.get(t).get(index);
  	}
  	
  	public void refreshCurrentPurge(){
  		for(Integer i=0; i<purgeList.size(); i++){
			if(purgeList.get(i).TargetObjectString__c.equals(targetTableString)) curPurge = purgeList.get(i);			
    	}
  	}
   
  	//Get the label of the object from Salesforce
  	public static String getObjectLabel(String objectName){
		String ns = prefixMgr.getObjPrefix();
		String fullObjectName = ns + objectName;
		Schema.DescribeSObjectResult objectDescribe = DescribeCache.getObjectDescribe(fullObjectName);
		return objectDescribe.getLabel();	
  	}
  	
  	//Wrapper to hold all purge information displayed on Purge.page
    public class PurgeInformationWrp {
	 	public String targetObject{get;set;}
	 	public String executionTime{get;set;}
	 	public Decimal daysToKeep{get;set;}
	 	public String cronJobID{get;set;}
	 	public String state{get;set;}
	 	public String canceledTime{get;set;}
	 	public String userEmail{get;set;}
	 	public String targetUser{get;set;}
		
		public PurgeInformationWrp(PurgeConfigurationStatus__c purge){
			if(purge.TargetObjectString__c!=null) targetObject=purge.TargetObjectString__c;
			if(purge.DateTimeExecution__c!=null) executionTime=purge.DateTimeExecution__c.format();
			if(purge.DaysToKeep__c!=null) daysToKeep=purge.DaysToKeep__c;
			if(purge.CronJobID__c!=null) cronJobID=purge.CronJobID__c;
			if(purge.State__c!=null) state=purge.State__c;
			if(purge.DateTimeCanceled__c!=null) canceledTime=purge.DateTimeCanceled__c.format();
			if(purge.UserEmail__c!=null) userEmail=purge.UserEmail__c;
			if(purge.TargetUser__r!=null) targetUser=purge.TargetUser__r.Name;
		}		 
	}
    
    //Get the crontrigger for the given jobID
    public CronTrigger getCronTrigger(String jobID){
    	return	[SELECT   CronExpression,
                          CronJobDetailId,
                          EndTime,
                          NextFireTime,
                          OwnerId,
                          PreviousFireTime,
                          StartTime,
                          State,
                          TimesTriggered,
                          TimeZoneSidKey,
                          CronJobDetail.Id,
                          CronJobDetail.Name,
                          CronJobDetail.JobType
                          FROM CronTrigger WHERE Id = :jobID];                       
    }
}