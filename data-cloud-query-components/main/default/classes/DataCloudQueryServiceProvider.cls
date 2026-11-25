/**
 * Created by dsingh on 23.10.25.
 */

public   class DataCloudQueryServiceProvider {

    public static final String DEFAULT_SETTING_NAME = 'QueryDefault';
    public static final Long INITIAL_ROW_LIMIT=1;
    public static  String DEFAULT_DATASPACE_NAME;
    public static  String DEFAULT_WORKLOAD_NAME;

    @TestVisible static DataCloudQuerySetting__mdt defaultSettings = DataCloudQuerySetting__mdt.getInstance(DEFAULT_SETTING_NAME);
    @TestVisible static ServiceProviderInitializationAdapter initializationAdapter = new ServiceProviderInitializationAdapter();

    public class SqlParameterItem{
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String type {get;set;}
        @AuraEnabled public String value {get;set;}
    }

    public class QueryResult{
        @AuraEnabled  public String queryId ;
        @AuraEnabled  public Boolean isCompleted;
        @AuraEnabled  public Long rowCount;
        @AuraEnabled  public List<Map<String,Object>> records;

    }


    public class DataCloudQueryServiceException extends Exception{}

   private static void setDefaultDataspaceAndWorkloadName(String dataspace,String workloadName){
       if(String.isBlank(DEFAULT_DATASPACE_NAME)){
           DEFAULT_DATASPACE_NAME=dataspace;
       }
       if(String.isBlank(DEFAULT_WORKLOAD_NAME)){
           DEFAULT_WORKLOAD_NAME=workloadName;
       }

   }

    /**
     * @description Returns the query service configured on the QueryDefault setting.
     */
    public static DataCloudQueryServiceProvider.IDataCloudQueryProvider getInstance(){
        return getInstance((DataCloudQuerySetting__mdt)null);
    }

    /**
     * @description Returns the query service for the given query setting.
     * REST api is used when it is enabled on the query setting, otherwise QueryDefault setting decides.
     * In REST mode the query setting named credential overrides the QueryDefault one when it is populated.
     * @param querySetting query setting being executed, null to use QueryDefault setting only
     */
    public static DataCloudQueryServiceProvider.IDataCloudQueryProvider getInstance(DataCloudQuerySetting__mdt querySetting){

        validateDefaultSettings();

        setDefaultDataspaceAndWorkloadName(defaultSettings.Dataspace__c,defaultSettings.WorkloadName__c);
        //Return the data cloud query service instance based on given configuration
        if(!isRestApiEnabled(querySetting) && initializationAdapter.isCdpQueryServiceExists()){
            return initializationAdapter.createCdpServiceInstance();
        }else if (initializationAdapter.isRestQueryServiceExists()){
            return initializationAdapter.createRestServiceInstance(resolveNamedCredential(querySetting));
        }else{
            return null;
        }

    }

    private static void validateDefaultSettings(){
        if(defaultSettings==null){
            throw new DataCloudQueryServiceException('QueryDefault setting expected and it does not exists');
        }
        if(String.isBlank(defaultSettings.Dataspace__c) || String.isBlank(defaultSettings.WorkloadName__c)){
            throw new DataCloudQueryServiceException('Dataspace and workload name cannot be empty for QueryDefault setting');
        }
    }

    @TestVisible
    private static Boolean isRestApiEnabled(DataCloudQuerySetting__mdt querySetting){
        return querySetting?.UseDataCloudRestApi__c==true
                || defaultSettings.UseDataCloudRestApi__c==true;
    }

    @TestVisible
    private static String resolveNamedCredential(DataCloudQuerySetting__mdt querySetting){
        String namedCredential = String.isNotBlank(querySetting?.NamedCredential__c)
                ? querySetting.NamedCredential__c
                : defaultSettings.NamedCredential__c;
        if(String.isBlank(namedCredential)){
            throw new DataCloudQueryServiceException('Named credential default setting is required to use Data cloud rest api');
        }
        return namedCredential;
    }

    @TestVisible
    private virtual class ServiceProviderInitializationAdapter{

        public virtual Boolean isCdpQueryServiceExists(){
            return Type.forName('DataCloudCdpQueryService')!=null;
        }

        public virtual Boolean isRestQueryServiceExists(){
            return Type.forName('DataCloudRestQueryService')!=null;
        }

        public virtual IDataCloudQueryProvider createCdpServiceInstance(){
              DataCloudQueryServiceProvider.IDataCloudQueryProvider provider =  (DataCloudQueryServiceProvider.IDataCloudQueryProvider)Type.forName('DataCloudCdpQueryService').newInstance();
            provider.initializeWith(null);
            return provider;
        }

        public virtual IDataCloudQueryProvider createRestServiceInstance(String namedCredential){
            DataCloudQueryServiceProvider.IDataCloudQueryProvider provider =  (DataCloudQueryServiceProvider.IDataCloudQueryProvider)Type.forName('DataCloudRestQueryService').newInstance();
            provider.initializeWith(new Map<String,Object>{
                    'namedCredential'=>namedCredential
            });
            return provider;
        }
    }

    /**
     * @description Interface for Data Cloud query providers.
     * Defines a contract for different query execution strategies (e.g., ConnectApi, REST).
     */
    public interface IDataCloudQueryProvider{

        /**
         * @description Allows a class to pass the parameter required for the initialization when class is instantiated dynamically
         * This allow decupling of the static type of dependencies and provide option to inject dynamic behaviour
         * @param params key value pair
         */
        void initializeWith(Map<String,Object> params);

        /**
         * @description Executes a query immediately and returns results.
         * @param query Data cloud sql query
         * @param queryParams Data cloud sql query parameters
         * @param dataspace dataspace name where this query should execute
         * @param workloadName workload name used for future debugging purpose by salesforce support team
         *
         * @return A QueryResult Data cloud query id - to be used by getQueryStatus and getQueryResult
         */
     QueryResult executeQuerySql(String query, List<SqlParameterItem> queryParams,String dataspace,String workloadName);

    /**
     * @description Checks the status of a previously submitted query.
     * @param queryId The ID of the query.
     * @param dataspace The name of the dataspace.
     * @param workloadName The name of the workload.
     * @return A QueryResult object with completion status flag and total rowCount.
     */

     QueryResult getQueryStatus(String queryId, String dataspace,String workloadName);

        /**
     * @description Gets the results for a completed query, with pagination.
     * @param queryId The ID of the query.
     * @param rowStart The starting row offset.
     * @param rowCount The number of rows to fetch.
     * @param dataspace The name of the dataspace.
     * @param workloadName The name of the workload.
     * @return A QueryResult object containing the data rows.
     */
       QueryResult getQueryResult(String queryId, Integer rowStart, Integer rowCount, String dataspace, String workloadName);

    }


}