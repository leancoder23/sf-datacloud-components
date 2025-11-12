/**
 * Created by dsingh on 23.10.25.
 */

public with sharing class DataCloudCdpQueryService implements DataCloudQueryServiceProvider.IDataCloudQueryProvider {

    /**
     * @description provides a wrapper methods for Cdp query class. This implementation facilitates the testability of the class
     */
    public virtual class CdpQueryAdapter{

        public  virtual ConnectApi.QuerySqlOutput querySql(ConnectApi.QuerySqlInput input, String workloadName, String dataspace){
            return ConnectApi.CdpQuery.querySql(input,workloadName,dataspace);
        }
        public virtual ConnectApi.QuerySqlStatus querySqlStatus( String queryId, String workloadName, String dataspace){
            return ConnectApi.CdpQuery.querySqlStatus(queryId,workloadName,dataspace);
        }
        public virtual ConnectApi.QuerySqlPageOutput querySqlRows( String queryId, Long offset, Long rowLimit, String workloadName, String dataspace){
            return ConnectApi.CdpQuery.querySqlRows(queryId, offset, rowLimit, workloadName, dataspace
            );
        }
    }

    @TestVisible
    private CdpQueryAdapter queryAdapter = new CdpQueryAdapter();


    // --- Interface Method Implementations ---
    //No parameter is required for the  initialization
    public void initializeWith(Map<String,Object> params){
       return;
    }

    public DataCloudQueryServiceProvider.QueryResult executeQuerySql(String query, List<DataCloudQueryServiceProvider.SqlParameterItem> queryParams, String dataspace, String workloadName) {

        ConnectApi.QuerySqlInput querySqlInput = new ConnectApi.QuerySqlInput();
        querySqlInput.sql = query;
        querySqlInput.sqlParameters = convertToConnectApiParams(queryParams);
        querySqlInput.rowLimit=DataCloudQueryServiceProvider.INITIAL_ROW_LIMIT;

        ConnectApi.QuerySqlOutput queryOutput = queryAdapter.querySql(
                querySqlInput,
                String.isBlank(workloadName)?DataCloudQueryServiceProvider.DEFAULT_WORKLOAD_NAME:workloadName,
                String.isBlank(dataspace)?DataCloudQueryServiceProvider.DEFAULT_DATASPACE_NAME:dataspace
        );

        DataCloudQueryServiceProvider.QueryResult result = new DataCloudQueryServiceProvider.QueryResult();
        result.queryId = queryOutput.status.queryId;
        result.isCompleted = queryOutput.status.completionStatus == ConnectApi.QuerySqlStatusEnum.Finished;
        if(result.isCompleted){
            result.rowCount=queryOutput.status.rowCount;
            result.records=parseQueryDataRows(queryOutput.metadata, queryOutput.dataRows);
        }

        return result;
    }
    public DataCloudQueryServiceProvider.QueryResult getQueryStatus(String queryId, String dataspace,String workloadName) {
        ConnectApi.QuerySqlStatus queryStatus = queryAdapter.querySqlStatus(
                queryId,
                String.isBlank(workloadName)?DataCloudQueryServiceProvider.DEFAULT_WORKLOAD_NAME:workloadName,
                String.isBlank(dataspace)?DataCloudQueryServiceProvider.DEFAULT_DATASPACE_NAME:dataspace
        );

        DataCloudQueryServiceProvider.QueryResult result = new DataCloudQueryServiceProvider.QueryResult();
        result.queryId=queryStatus.queryId;
        result.isCompleted = queryStatus.completionStatus == ConnectApi.QuerySqlStatusEnum.Finished;
        if(result.isCompleted){
            result.rowCount=queryStatus.rowCount;
        }

        return result;
    }
    public DataCloudQueryServiceProvider.QueryResult getQueryResult(String queryId, Integer rowStart, Integer rowCount, String dataspace,String workloadName) {
        ConnectApi.QuerySqlPageOutput queryOutput = queryAdapter.querySqlRows(
                queryId,
                rowStart,
                rowCount,
                String.isBlank(workloadName)?DataCloudQueryServiceProvider.DEFAULT_WORKLOAD_NAME:workloadName,
                String.isBlank(dataspace)?DataCloudQueryServiceProvider.DEFAULT_DATASPACE_NAME:dataspace
        );

        DataCloudQueryServiceProvider.QueryResult result = new DataCloudQueryServiceProvider.QueryResult();
        result.queryId=queryId;
        //result.rowCount=queryOutput.returnedRows;
        result.records=parseQueryDataRows(queryOutput.metadata,queryOutput.dataRows);


        return result;
    }

    // --- Helper Methods ---

    /**
     * @description Converts the provider's generic SqlParameterItem list
     * into the specific list required by the ConnectApi.
     * @param params query parameters
     *
     * @return returns connect api query parameter object list
     */
    private List<ConnectApi.QuerySqlParameterItem> convertToConnectApiParams(List<DataCloudQueryServiceProvider.SqlParameterItem> params) {
        if (params == null || params.isEmpty()) {
            return null;
        }

        List<ConnectApi.QuerySqlParameterItem> connectApiParams = new List<ConnectApi.QuerySqlParameterItem>();
        for (DataCloudQueryServiceProvider.SqlParameterItem item : params) {
            ConnectApi.QuerySqlParameterItem connectItem = new ConnectApi.QuerySqlParameterItem();
            connectItem.name = item.name;
            connectItem.value = item.value;
            connectItem.type = ConnectApi.TypeEnum.valueOf(item.type);
            connectApiParams.add(connectItem);
        }
        return connectApiParams;
    }

    /**
     * @description parse connect api query result to list of key value pairs for each column values
     * @param metadata connect api query metadata used to identify the field name
     * @param dataRows connect api query result data row
     *
     * @return list of key value pairs
     */
    private List<Map<String, Object>> parseQueryDataRows(List<ConnectApi.QuerySqlMetadataItem> metadata, List<ConnectApi.QuerySqlRow> dataRows) {
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        Integer queryOutputColumns = metadata.size();
        for (ConnectApi.QuerySqlRow dataRow : dataRows) {
            Map<String, Object> record = new Map<String, Object>();
            for (Integer col = 0; col < queryOutputColumns; col++) {
                record.put(metadata[col].name, dataRow.row[col]);
            }
            records.add(record);
        }
        return records;
    }

}