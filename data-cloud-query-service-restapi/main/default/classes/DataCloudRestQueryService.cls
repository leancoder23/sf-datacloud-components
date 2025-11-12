/**
 * @author Deepak Singh (Salesforce)
 * @date 23.10.25.
 * @description
 * Implements the DataCloudQueryServiceProvider interface to execute Data Cloud queries
 * via the Salesforce Data Cloud (SSOT) Connect REST API (/ssot/query-sql).
 */
public with sharing class DataCloudRestQueryService implements DataCloudQueryServiceProvider.IDataCloudQueryProvider {


    @TestVisible
    private  String  namedCredential;
    private  static final String API_ENDPOINT = '/ssot/query-sql'; // Requires API version


    public void initializeWith(Map<String,Object> params){
        String namedCredential = (String)params?.get('namedCredential');
        if(String.isBlank(namedCredential)){
            throw new DataCloudQueryServiceException('Named credential is required to use Data cloud query rest service');
        }
        this.namedCredential = namedCredential;
    }


    /**
    * @description Executes a query immediately and returns initial set of results.
    * @param query Data cloud sql query
    * @param queryParams Data cloud sql query parameters
    * @param dataspace dataspace name where this query should execute
    * @param workloadName workload name used for future debugging purpose by salesforce support team
    *
    * @return A QueryResult with Data cloud query id, and initial result - to be used by getQueryStatus and getQueryResult
    */
    public DataCloudQueryServiceProvider.QueryResult executeQuerySql(String query, List<DataCloudQueryServiceProvider.SqlParameterItem> queryParams, String dataspace, String workloadName) {

        // 1. Build the JSON body with SQL and parameters
        SsotQueryRequest requestPayload = new SsotQueryRequest(query, queryParams);
        String requestBody = JSON.serialize(requestPayload);


        // 2. Build the path, adding URL parameters if they exist


        Map<String,String> baseParams = getSsotQueryUrlBaseParams(dataspace,workloadName);
        String path = buildUrlWithParameters(API_ENDPOINT,baseParams);


        //String path = buildPathWithBaseParameters(null, dataspace, workloadName);

        // 3. Make the callout
        // <-- FIXED: Changed variable type from SsotQueryResponse to Map<String, Object>
        Map<String, Object> apiResponse = makeApiCallout('POST', path, requestBody);


        // 4. Parse and return the standardized result
        return parseRestQueryResponse(apiResponse);
    }

    /**
     * @description Checks the status of a previously submitted query.
     * This uses the /ssot/query-sql/:queryId endpoint.
     * @param queryId The ID of the query.
     * @param dataspace The name of the dataspace.
     * @param workloadName The name of the workload.
     * @return A QueryResult object with completion status flag and total rowCount.
     */
    public DataCloudQueryServiceProvider.QueryResult getQueryStatus(String queryId, String dataspace, String workloadName) {

        // 1. Build the path with queryId and optional URL parameters
        //String path = buildPathWithBaseParameters(queryId, dataspace, workloadName);

        Map<String,String> baseParams = getSsotQueryUrlBaseParams(dataspace,workloadName);

        String path = buildUrlWithParameters(API_ENDPOINT+'/'+queryId,baseParams);

        // 2. Make the callout (no body for GET)
        // <-- FIXED: Changed variable type from SsotQueryResponse to Map<String, Object>
        Map<String, Object> apiResponse = makeApiCallout('GET', path, null);

        // 3. Parse and return the standardized result
        return parseRestQueryResponse(apiResponse);
    }

    /**
     * Gets the results for a completed query, with pagination.
     * This uses the /ssot/query-sql/:queryId/rows endpoint.
     */
    /**
  * @description Gets the results for a completed query, with pagination.
  * This uses the /ssot/query-sql/:queryId/rows endpoint.
  * @param queryId The ID of the query.
  * @param rowStart The starting row offset.
  * @param rowCount The number of rows to fetch.
  * @param dataspace The name of the dataspace.
  * @param workloadName The name of the workload.
  * @return A QueryResult object containing the data rows.
  */
    public DataCloudQueryServiceProvider.QueryResult getQueryResult(String queryId, Integer rowStart, Integer rowCount, String dataspace, String workloadName) {

        // 1. Build the path with queryId,  /rows suffix  and pagination parameters

        Map<String,String> params = getSsotQueryUrlBaseParams(dataspace,workloadName);
        params.put('offset',String.valueOf(rowStart));
        params.put('rowLimit',String.valueOf(rowCount));

        String path = buildUrlWithParameters(API_ENDPOINT+'/'+queryId+'/rows',params);


        // 2. Make the callout (no body for GET)
        Map<String, Object> apiResponse = makeApiCallout('GET', path, null);
        system.debug(apiResponse);

        //Since this endpoint does not returns the query id as a part of response
        //passing this manually to be included in QueryResult
        apiResponse.put('queryId',queryId);
        // 3. Parse and return the standardized result
        return parseRestQueryResponse(apiResponse);
    }

    // --- Private Helper Methods ---

    /**
     * return a string map to be used as query parameter
     * @param dataspace dataspace name
     * @param workloadName  workload name
     *
     * @return query parameter map
     */
    private Map<String,String> getSsotQueryUrlBaseParams(String dataspace, String workloadName){
        return new Map<String,String>{
                'dataspace'=>String.isBlank(dataspace)?DataCloudQueryServiceProvider.DEFAULT_DATASPACE_NAME:dataspace,
                'workloadName'=>String.isBlank(workloadName)?DataCloudQueryServiceProvider.DEFAULT_WORKLOAD_NAME:workloadName
        };
    }

    /**
     * Helper method to make http rest api callout, checks for initial http status and throw exception if not successful.
     * @param httpMethod http verb for the rest api
     * @param path rest api endpoint
     * @param requestBody payload
     *
     * @return response data map
     */
    private Map<String, Object> makeApiCallout(String httpMethod, String path, String requestBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' +this.namedCredential + path);
        req.setMethod(httpMethod);

        req.setHeader('Accept', 'application/json');

        if (httpMethod.equalsIgnoreCase('POST') && requestBody != null) {
            req.setHeader('Content-Type', 'application/json; charset=UTF-8');
            req.setBody(requestBody);
        }

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

                return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            } else {
                handleHttpError(res);
                return null; // Unreachable
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DataCloudQueryServiceController Callout Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new DataCloudQueryServiceException(e.getMessage(), e);
        }
    }


    /**
     * Translates the SSOT API's JSON response object map into the standard QueryResult object.
     * @param apiResponse API response object map
     * @return instance of QueryResult
     */
    private DataCloudQueryServiceProvider.QueryResult parseRestQueryResponse(Map<String, Object> apiResponse) {

        // Handle nulls, especially for /rows endpoint which may not return a status block
        if (apiResponse == null) {
            return new DataCloudQueryServiceProvider.QueryResult();
        }

        DataCloudQueryServiceProvider.QueryResult result = new DataCloudQueryServiceProvider.QueryResult();

        // The /rows endpoint might not return the 'status' block,
        // but the other endpoints will.
        if (apiResponse.containsKey('status') && apiResponse.get('status') != null) {
            Map<String, Object> status = (Map<String, Object>) apiResponse.get('status');

            result.queryId = (String) status.get('queryId');

            // rowCount
            result.rowCount = (Long)status.get('rowCount');



            // Map completion status
            String statusStr = (String) status.get('completionStatus');
            system.debug('DS VV1: ' + statusStr);
            if (statusStr != null) {
                if (statusStr.equalsIgnoreCase('ResultsProduced') ||
                        statusStr.equalsIgnoreCase('Succeeded') ||
                        statusStr.equalsIgnoreCase('Failed')) {
                    result.isCompleted = true;
                }else{
                    result.isCompleted = false;
                }

                // If the query failed, throw an exception
                if (statusStr.equalsIgnoreCase('Failed')) {
                    throw new DataCloudQueryServiceException('Data Cloud Query Failed: ' + (String)status.get('queryId'));
                }
            }
        }

        // The /status endpoint might not return data, but /rows and /query will.
        result.records = new List<Map<String, Object>>();

        // Use map.containsKey and casting for 'data' and 'metadata'
        if (apiResponse.containsKey('data') && apiResponse.get('data') != null &&
                apiResponse.containsKey('metadata') && apiResponse.get('metadata') != null) {

            // Get the untyped lists
            List<Object> dataRows = (List<Object>) apiResponse.get('data');     // This is a List<Object> of List<Object>s
            List<Object> metadataList = (List<Object>) apiResponse.get('metadata'); // This is a List<Object> of Map<String, Object>s

            // Pre-parse metadata to get column names in order
            List<String> columnNames = new List<String>();
            for (Object metaObj : metadataList) {
                Map<String, Object> metaMap = (Map<String, Object>) metaObj;
                columnNames.add((String) metaMap.get('name'));
            }

            Integer colCount = columnNames.size();

            // Process the data rows
            for(Object rowObj : dataRows) {
                Map<String, Object> record = new Map<String, Object>();
                List<Object> rowValues = (List<Object>) rowObj; // Each row is a List<Object> containing the cell values

                for(Integer col = 0; col < colCount; col++){
                    // Add safety checks for mismatched data/metadata
                    if (col < rowValues.size()) {
                        record.put(columnNames.get(col), rowValues.get(col));
                    }
                }
                result.records.add(record);
            }
        }

        // Fallback for /rows endpoint which might not have queryId in status
        // <-- FIXED: Use map.containsKey and casting
        if (String.isBlank(result.queryId) && apiResponse.containsKey('queryId') && apiResponse.get('queryId') != null) {
            result.queryId = (String) apiResponse.get('queryId');
        }

        return result;
    }

    /**
     * Builds url with query string
     * @param path url
     * @param params url parameter map
     * @return url with query string
     */
    private String buildUrlWithParameters(String path, Map<String, String> params) {
        if (params == null || params.isEmpty()) {
            return path;
        }

        String querySymbol = path.contains('?') ? '&' : '?';
        List<String> paramList = new List<String>();

        system.debug('DS path: ' + path);
        system.debug('DS params: ' + params);

        for (String key : params.keySet()) {
            paramList.add(EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }

        return path + querySymbol + String.join(paramList, '&');
    }

    /**
     * Handles http response error and throws exceptions
     * @param res http response
     */
    private void handleHttpError(HttpResponse res) {
        String errorMessage = 'API Error: ' + res.getStatusCode() + ' ' + res.getStatus();
        if (String.isNotBlank(res.getBody())) {
            try {
                // This deserialize is fine, as ApiError is a simple structure
                List<ApiError> errors = (List<ApiError>) JSON.deserialize(res.getBody(), List<ApiError>.class);
                if (!errors.isEmpty() && String.isNotBlank(errors[0].message)) {
                    errorMessage += '. ' + errors[0].message;
                } else {
                    errorMessage += '. ' + res.getBody();
                }
            } catch (Exception e) {
                errorMessage += '. ' + res.getBody();
            }
        }
        throw new DataCloudQueryServiceException(errorMessage);
    }

    // --- Inner DTO Classes for JSON (De)serialization ---

    /**
     * DTO for the POST /ssot/query-sql request body.
     */
    private class SsotQueryRequest {
        public String sql;
        public Long rowLimit;
        public List<DataCloudQueryServiceProvider.SqlParameterItem> sqlParameters;

        public SsotQueryRequest(String sql, List<DataCloudQueryServiceProvider.SqlParameterItem> params) {
            this.sql = sql;
            this.sqlParameters = params;
            this.rowLimit = DataCloudQueryServiceProvider.INITIAL_ROW_LIMIT;
        }
    }

    /**
     * DTO for parsing error responses (Standard Salesforce format)
     */
    private class ApiError {
        public String errorCode;
        public String message;
    }

    /**
     * Custom exception class for service-level errors.
     */
    public class DataCloudQueryServiceException extends Exception {}
}