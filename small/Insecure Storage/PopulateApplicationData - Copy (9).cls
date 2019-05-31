public with sharing class PopulateApplicationData {
list<string> classesToDeploy = new list<string> {'VisualForceReportList' , 'NcIntegration', 'MbIntegration'};
public String customSettingSuccessMessage {get; set{this.customSettingSuccessMessage = value; }}

Public PopulateApplicationData()
    {

    }

    public void populateData()    
    {
    //should refactor to use private interface deployable{void deploy();}
        string className;

        PostInstaller.SetOauthClientIdAndSecret();

        className = 'MergeDescribeService';
        try {
            MergeDescribeService.deployMetadata();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  ' + className + '.deployMetadata', null);
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);
        }

        className = 'VisualForceReportList';
        try {
            VisualForceReportList.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy', null);
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);
        }

        className = 'NcIntegration';
        try {
            NcIntegration.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy' , null);     
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);    
        }

        className = 'OperaIntegration';
        try {
            OperaIntegration.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy' , null);     
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);    
        }

        className = 'NwsIntegration';
        try {
            NwsIntegration.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy' , null);     
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);    
        }

        className = 'PmsIntegration';
        try {
            PmsIntegration.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy' , null);     
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);    
        }

        className = 'MbIntegration';
        try {
            MbIntegration.deploy();
        }
        catch (System.Exception e) {
            LogCls.write(e, 'PopulateApplicationData:  '  + className + '.deploy' , null);
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, className  + ':  ' +  Label.Error.replace('{0}', e.getMessage()) );
            ApexPages.addMessage(msg);           
        }          
        this.customSettingSuccessMessage =Label.PopulateApplicationDataPageSuccessMessage;           
    }

}