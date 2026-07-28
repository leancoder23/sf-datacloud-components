/**
 * Created by dsingh on 07.10.25.
*/

public with sharing class DataCloudQueryServiceController {


    /**
     * @description Wraps database query related methods to facilitate the testability with mock instance of this class without needing to create actual sobject records
     */
    public virtual class SoqlQueryAdapter{
        public virtual List<SObject> querySoqlWithBinds(String soql, Map<String,Object>bindMap, System.AccessLevel accessLevel) {
            return Database.queryWithBinds(soql,bindMap,accessLevel);
        }

        public virtual DataCloudQuerySetting__mdt getDataCloudQueryServiceSetting(String developerName,Boolean useSoql){
            if(useSoql==true){
                List<DataCloudQuerySetting__mdt> querySettingList = [SELECT Query__c,
                        RecordBasedFilterConfig__c,
                        RecordFilterObject__c,
                        WorkloadName__c,
                        Dataspace__c
                FROM DataCloudQuerySetting__mdt
                WHERE DeveloperName=:developerName];

                return querySettingList.size()>0?querySettingList.get(0):null;

            }else{
                return DataCloudQuerySetting__mdt.getInstance(developerName);
            }
        }
    }



    @TestVisible
    private static DataCloudQueryServiceProvider.IDataCloudQueryProvider dataCloudQueryService = DataCloudQueryServiceProvider.getInstance();

    @TestVisible
    private static SoqlQueryAdapter soqlQueryAdapter = new SoqlQueryAdapter();


    public class RecordFieldParam {
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String type {get;set;}
        @AuraEnabled public String fieldName {get;set;}

        public DataCloudQueryServiceProvider.SqlParameterItem getSqlParameterItem(Object fieldValue){
            DataCloudQueryServiceProvider.SqlParameterItem item = new DataCloudQueryServiceProvider.SqlParameterItem();
            item.name=this.name;
            item.value=String.valueOf(fieldValue);
            item.type=this.type;
            return item;
        }

    }

    @TestVisible
    private static List<DataCloudQueryServiceProvider.SqlParameterItem> getQueryParamsBasedOnRecordId(String recordId,List<RecordFieldParam> recordFieldParams){

        if(String.isBlank(recordId)
                || recordFieldParams==null
                || recordFieldParams.size()==0){
                    return null;
                }

        List<String> recordFieldNames = new List<String>();
        for(RecordFieldParam fieldParam : recordFieldParams){
            if(fieldParam.fieldName!='recordId'){
                recordFieldNames.add(fieldParam.fieldName);
            }
        }

        SObject record;
        if(recordFieldNames.size()>0){
            record = getRecordData(recordId,recordFieldNames);

        }

        //build QuerySqlParameterItem
        List<DataCloudQueryServiceProvider.SqlParameterItem> params = new  List<DataCloudQueryServiceProvider.SqlParameterItem>();
        for(RecordFieldParam fieldParam : recordFieldParams){
            if(fieldParam.fieldName=='recordId'){
                params.add(fieldParam.getSqlParameterItem(recordId));
            }else{
                params.add(fieldParam.getSqlParameterItem(record.get(fieldParam.fieldName)));
            }
        }

        return params;
    }

    @AuraEnabled
    public static DataCloudQueryServiceProvider.QueryResult submitDataCloudQuery(String querySettingId,Id recordId){

        DataCloudQuerySetting__mdt querySetting = soqlQueryAdapter.getDataCloudQueryServiceSetting(querySettingId,true);

        if(querySetting==null) {
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Query Setting ' + querySettingId + ' is not found, please contact administrator');
        }

        if( String.isBlank(querySetting.Query__c)) {
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Query is not configured for Query Setting ' + querySettingId + ', please contact administrator');

        }

        if(String.isNotBlank(querySetting.RecordBasedFilterConfig__c) &&  String.isBlank(recordId)) {
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('[RECORD_CONTEXT_ERROR] Query requires current record id which is empty, please execute this query from a record page or provide the record id as a page parameter');

        }

        String query = querySetting.Query__c;

        String recordBasedFilterConfig = querySetting.RecordBasedFilterConfig__c;
        String recordFilterObject = querySetting.RecordFilterObject__c;

        List<RecordFieldParam>recordFieldParams = new List<RecordFieldParam>();

        if(String.isNotBlank(recordFilterObject) && recordFilterObject!=recordId.getSobjectType().toString()){
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Incorrect recordId,  Query requires to be executed in context of valid '+ recordFilterObject+' record');
        }
        if (String.isNotBlank(recordBasedFilterConfig)){
            //parse record based param
            List<String> paramStrList = recordBasedFilterConfig.split(',');
            List<String> paramParts;

            System.debug(recordBasedFilterConfig);
            for(String paramStr : paramStrList ){
                RecordFieldParam fieldParam = new RecordFieldParam();
                paramParts = paramStr.split(':');
                fieldParam.name=paramParts[0];
                fieldParam.fieldName=paramParts[1];
                fieldParam.type=paramParts[2];
                recordFieldParams.add(fieldParam);
            }
        }


        List<DataCloudQueryServiceProvider.SqlParameterItem> queryParams = getQueryParamsBasedOnRecordId(recordId,recordFieldParams);
        return dataCloudQueryService.executeQuerySql(query,queryParams,querySetting.Dataspace__c,querySetting.WorkloadName__c);

    }


    @AuraEnabled
    public static DataCloudQueryServiceProvider.QueryResult getDataCloudQueryStatus(String querySettingId,String queryId){

        DataCloudQuerySetting__mdt querySetting = soqlQueryAdapter.getDataCloudQueryServiceSetting(querySettingId,false);

        if(querySetting==null) {
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Query Setting ' + querySettingId + ' is not found, please contact administrator');
        }

        return dataCloudQueryService.getQueryStatus(queryId,querySetting.Dataspace__c,querySetting.WorkloadName__c);
    }

    @AuraEnabled
    public static DataCloudQueryServiceProvider.QueryResult getDataCloudQueryData(String querySettingId,String queryId,Integer rowStart,Integer rowCount){

       DataCloudQuerySetting__mdt querySetting = soqlQueryAdapter.getDataCloudQueryServiceSetting(querySettingId,false);

        if(querySetting==null) {
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Query Setting ' + querySettingId + ' is not found, please contact administrator');
        }

       return dataCloudQueryService.getQueryResult(queryId,rowStart,rowCount,querySetting.Dataspace__c,querySetting.WorkloadName__c);
    }

    @AuraEnabled(Cacheable=true)
    public static SObject getRecordData(Id recordId, List<String>fields){
        String sObjectTypeName = recordId.getSobjectType().toString();
        //Check user object  field permission here if now accessible then throw error
        SObjectType objectType = Schema.getGlobalDescribe().get(sObjectTypeName);
        //When we have object reference from Data cloud in that case object type could be missing, but then field accessibility check is not required
        if(objectType!=null){
            Map<String,SObjectField>sObjectFieldMap = objectType.getDescribe().fields.getMap();
            List<String> errors = new List<String>();
            for(String field : fields){
                if(!sObjectFieldMap.get(field).getDescribe().isAccessible()){
                    errors.add(field + ' is not accessible');
                }
            }
            if(errors.size()>0){
                throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException(String.join(errors,'\n'));
            }
        }

        String soql = String.format('SELECT {0} FROM {1} WHERE Id=:recordId', new List<String>{
                String.join(fields,','),
                sObjectTypeName
        });

        List<SObject> records = soqlQueryAdapter.querySoqlWithBinds(soql, new Map<String,Object>{
              'recordId'=>recordId
        },AccessLevel.SYSTEM_MODE );

        if(records.size()==0){
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException(String.format('No {0} record found for id {1}',
                    new List<String>{sObjectTypeName,recordId}));
        }

        return records.get(0);

    }

    public static final String NAV_LOCAL_RECORD   = 'LOCAL_RECORD';
    public static final String NAV_DATA360_RECORD = 'DATA360_RECORD';
    public static final String NAV_CUSTOM_PAGE    = 'CUSTOM_PAGE';

    /**
     * Resolves the navigation strategy for a given record identifier.
     *
     * Tier 1 – LOCAL_RECORD:   recordId is a valid Salesforce Id and the current user can access it.
     * Tier 2 – DATA360_RECORD: data360ObjectName is provided, the object exists in the schema
     *                          (org is connected to home/companion org), and a matching record
     *                          is found via ssot__Id__c.
     * Tier 3 – CUSTOM_PAGE:    Fallback when neither of the above succeeds.
     *
     * @param recordId          The record identifier — may be a Salesforce Id or a Data Cloud id
     * @param data360ObjectName (Optional) The Data360 object API name to attempt a ssot__Id__c lookup
     *
     * @return RecordNavigationInfo indicating which navigation path the LWC should follow
     */
    @AuraEnabled(Cacheable=true)
    public static RecordNavigationInfo resolveRecordNavigation(String recordId, String data360ObjectName) {

        RecordNavigationInfo navInfo = new RecordNavigationInfo();

        // ── Tier 1: Local Record — is recordId a valid SF Id accessible by this user? ──
        try {
            Id sfId = Id.valueOf(recordId);
            String sObjName = sfId.getSObjectType().getDescribe().getName();

            List<SObject> records = soqlQueryAdapter.querySoqlWithBinds(
                    String.format('SELECT Id FROM {0} WHERE Id=:recordId', new List<String>{ sObjName }),
                    new Map<String, Object>{ 'recordId' => recordId },
                    AccessLevel.USER_MODE
            );

            if (!records.isEmpty()) {
                navInfo.navigationType  = NAV_LOCAL_RECORD;
                navInfo.resolvedRecordId = recordId;
                navInfo.objectApiName   = sObjName;
                return navInfo;
            }
        } catch (System.StringException e) {
            // Not a valid Salesforce Id — expected for Data Cloud / DMO ids, continue to Tier 2
        }

        // ── Tier 2: Data360 Record — org connected and record found via ssot__Id__c? ──
        if (String.isNotBlank(data360ObjectName)
                && Schema.getGlobalDescribe().containsKey(data360ObjectName)) {

            List<SObject> records = soqlQueryAdapter.querySoqlWithBinds(
                    String.format('SELECT Id FROM {0} WHERE ssot__Id__c=:recordId', new List<String>{ data360ObjectName }),
                    new Map<String, Object>{ 'recordId' => recordId },
                    AccessLevel.SYSTEM_MODE
            );

            if (!records.isEmpty()) {
                navInfo.navigationType   = NAV_DATA360_RECORD;
                navInfo.resolvedRecordId = (String) records.get(0).get('Id');
                navInfo.objectApiName    = data360ObjectName;
                return navInfo;
            }
        }

        // ── Tier 3: Fallback — no local or Data360 match ──
        navInfo.navigationType = NAV_CUSTOM_PAGE;
        return navInfo;
    }

    public class RecordNavigationInfo {
        @AuraEnabled public String navigationType;
        @AuraEnabled public String resolvedRecordId;
        @AuraEnabled public String objectApiName;
    }
}