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
            throw new DataCloudQueryServiceProvider.DataCloudQueryServiceException('Query requires current record id which is empty, please execute this query from record page only');

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

    /**
     * Get the local salesforce record Id for the data cloud record by executing SOQL query,
     * this Id will be used by the list component to navigate to the salesforce record page for the data cloud object
     * @param recordId - Data cloud object (DMO) record id
     * @param objectName - Data cloud object name
     *
     * @return - Salesforce local record id "Id" - this "Id" is temporary
     */
    @AuraEnabled(Cacheable=true)
    public static String getDataCloudRecordLocalId(String recordId, String objectName){
        List<SObject> records = soqlQueryAdapter.querySoqlWithBinds(String.format('SELECT Id FROM {0} WHERE ssot__Id__c=:recordId',
                new List<String>{
                        objectName
                })
        ,new Map<String,Object>{
                        'recordId'=>recordId
                },AccessLevel.SYSTEM_MODE);

        return records.size()>0?(String)(records.get(0).get('Id')):null;
    }
}