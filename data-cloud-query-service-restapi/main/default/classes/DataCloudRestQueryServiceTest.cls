/**
 * @description
 * Test class for DataCloudRestQueryService.
 * Uses DataCloudCalloutMock to simulate Data Cloud REST API responses.
 */
@isTest
private class DataCloudRestQueryServiceTest {

    private static final String TEST_NAMED_CRED = 'Test_Data_Cloud_NC';
    private static final String TEST_QUERY_ID = 'a1b2c3d4-e5f6-7890-g1h2-i3j4k5l6m7n8';

    /**
     * @description Mock implementation for HttpCalloutMock to intercept
     * REST API calls and provide controlled responses.
     */
    public class DataCloudCalloutMock implements HttpCalloutMock {

        private HttpResponse mockResponse;
        private HttpRequest actualRequest;

        public void setMockResponse(HttpResponse res) {
            mockResponse = res;
        }

        public HttpRequest getActualRequest() {
            return actualRequest;
        }

        public HttpResponse respond(HttpRequest req) {
            // Capture the request for later inspection
            actualRequest = req;

            if (mockResponse == null) {
                // Fallback in case a response wasn't set
                HttpResponse res = new HttpResponse();
                res.setStatusCode(500);
                res.setStatus('Mock Not Set');
                res.setBody('Test setup error: HttpCalloutMock response was not set.');
                return res;
            }
            return mockResponse;
        }
    }

    /**
     * @description Helper to create a standard mock HttpResponse.
     */
    private static HttpResponse createMockResponse(Integer statusCode, String body) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setStatus('OK'); // Status text is often ignored, but good to set
        if (body != null) {
            res.setBody(body);
        }
        return res;
    }

    private static DataCloudRestQueryService initializeRestServiceWithNamedCredential(String namedCredential){
        DataCloudRestQueryService service = new DataCloudRestQueryService();
        service.initializeWith(new Map<String,Object>{
                'namedCredential'=>namedCredential
        });
        return service;
    }

    @isTest
    static void givenNullNamedCredential_whenConstruct_thenThrowsException() {
        // Given
        Exception thrownException = null;

        // When
        Test.startTest();
        try {
            new DataCloudRestQueryService().initializeWith(null);
        } catch (DataCloudRestQueryService.DataCloudQueryServiceException e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException);
        Assert.isTrue(
                thrownException.getMessage().contains('Named credential is required'),
                thrownException.getMessage()
        );
    }

    @isTest
    static void givenBlankNamedCredential_whenConstruct_thenThrowsException() {
        // Given
        Exception thrownException = null;

        // When
        Test.startTest();
        try {
            initializeRestServiceWithNamedCredential(' '); // Blank string
        } catch (DataCloudRestQueryService.DataCloudQueryServiceException e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException);
        Assert.isTrue(
                thrownException.getMessage().contains('Named credential is required'),
                thrownException.getMessage()
        );
    }

    @isTest
    static void givenSuccessfulSubmit_whenExecuteQuerySql_thenReturnsIncompleteResultAndValidCallout() {
        // Given
        String jsonBody = JSON.serialize(new Map<String, Object>{
                'status' => new Map<String, Object>{
                        'queryId' => TEST_QUERY_ID,
                        'completionStatus' => 'Running',
                        'rowCount' => 0
                },
                'data' => new List<Object>(),
                'metadata' => new List<Object>()
        });

        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(createMockResponse(200, jsonBody));

        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );
        String sql = 'SELECT ssot__id__c FROM UnifiedIndividual__dlm';
        String dataspace = 'my_dataspace';
        String workload = 'my_workload';

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        DataCloudQueryServiceProvider.QueryResult result = service.executeQuerySql(sql, null, dataspace, workload);
        Test.stopTest();

        // Then (Result)
        Assert.areEqual(TEST_QUERY_ID, result.queryId, 'Query ID should be parsed from status');
        Assert.isFalse(result.isCompleted, 'Status should be incomplete');
        Assert.areEqual(0, result.rowCount, 'Row count should be 0');
        Assert.areEqual(0, result.records.size(), 'Records list should be empty');

        // Then (Callout Details)
        HttpRequest capturedReq = calloutMock.getActualRequest();
        String endpoint = capturedReq.getEndpoint();
        Assert.areEqual('POST', capturedReq.getMethod());
        Assert.isTrue(endpoint.contains(TEST_NAMED_CRED), 'Endpoint must use Named Credential');
        Assert.isTrue(endpoint.contains('/ssot/query-sql'), 'Endpoint path is incorrect');
        Assert.isTrue(endpoint.contains('dataspace=' + dataspace), 'Dataspace param is missing');
        Assert.isTrue(endpoint.contains('workloadName=' + workload), 'Workload param is missing');

        // Then (Request Body)
        Map<String, Object> requestBodyMap = (Map<String, Object>) JSON.deserializeUntyped(capturedReq.getBody());
        Assert.areEqual(sql, requestBodyMap.get('sql'));
        Assert.areEqual(
                DataCloudQueryServiceProvider.INITIAL_ROW_LIMIT,
                (Long) requestBodyMap.get('rowLimit')
        );
    }

    @isTest
    static void givenSuccessfulStatusCheck_whenGetQueryStatus_thenReturnsCompletedResult() {
        // Given
        String jsonBody = JSON.serialize(new Map<String, Object>{
                'status' => new Map<String, Object>{
                        'queryId' => TEST_QUERY_ID,
                        'completionStatus' => 'Succeeded',
                        'rowCount' => 125
                }
        });
        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(createMockResponse(200, jsonBody));

        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        DataCloudQueryServiceProvider.QueryResult result = service.getQueryStatus(TEST_QUERY_ID, 'ds', 'wl');
        Test.stopTest();

        // Then (Result)
        Assert.areEqual(TEST_QUERY_ID, result.queryId, 'Query ID should be parsed');
        Assert.isTrue(result.isCompleted, 'Status should be completed');
        Assert.areEqual(125, result.rowCount, 'Row count should be 125');

        // Then (Callout Details)
        HttpRequest capturedReq = calloutMock.getActualRequest();
        String endpoint = capturedReq.getEndpoint();
        Assert.areEqual('GET', capturedReq.getMethod());
        Assert.isTrue(
                endpoint.contains('/ssot/query-sql/' + TEST_QUERY_ID),
                'Endpoint path must include queryId'
        );
        Assert.isTrue(String.isBlank(capturedReq.getBody()), 'GET request should not have a body');
    }

    @isTest
    static void givenSuccessfulDataFetch_whenGetQueryResult_thenReturnsResultWithRecords() {
        // Given
        String jsonBody = JSON.serialize(new Map<String, Object>{
                'data' => new List<Object>{
                        new List<Object>{ '001', 'Acme' },
                        new List<Object>{ '002', 'Globex' }
                },
                'metadata' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'Id' },
                        new Map<String, Object>{ 'name' => 'Name' }
                }
        });

        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(createMockResponse(200, jsonBody));

        Integer rowStart = 0;
        Integer rowCount = 100;
        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        DataCloudQueryServiceProvider.QueryResult result = service.getQueryResult(
                TEST_QUERY_ID,
                rowStart,
                rowCount,
                'ds',
                'wl'
        );
        Test.stopTest();

        // Then (Result)
        Assert.areEqual(TEST_QUERY_ID, result.queryId, 'Query ID should be the one passed in');
        Assert.areEqual(2, result.records.size(), 'Should parse 2 records');
        Assert.areEqual('Acme', result.records[0].get('Name'));
        Assert.areEqual('002', result.records[1].get('Id'));
        Assert.isNull(result.rowCount, 'Row count is not returned by this endpoint');

        // Then (Callout Details)
        HttpRequest capturedReq = calloutMock.getActualRequest();
        String endpoint = capturedReq.getEndpoint();
        Assert.areEqual('GET', capturedReq.getMethod());
        Assert.isTrue(
                endpoint.contains('/ssot/query-sql/' + TEST_QUERY_ID + '/rows'),
                'Endpoint path must include queryId and /rows'
        );
        Assert.isTrue(endpoint.contains('offset=' + rowStart), 'Offset param is missing');
        Assert.isTrue(endpoint.contains('rowLimit=' + rowCount), 'RowLimit param is missing');
    }

    @isTest
    static void givenLogicalFailedStatus_whenGetQueryStatus_thenThrowsException() {
        // Given
        String jsonBody = JSON.serialize(new Map<String, Object>{
                'status' => new Map<String, Object>{
                        'queryId' => TEST_QUERY_ID,
                        'completionStatus' => 'Failed',
                        'rowCount' => 0
                }
        });
        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(createMockResponse(200, jsonBody)); // HTTP 200, but logical failure

        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );
        Exception thrownException = null;

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        try {
            service.getQueryStatus(TEST_QUERY_ID, 'ds', 'wl');
        } catch (DataCloudRestQueryService.DataCloudQueryServiceException e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException);
        Assert.isTrue(
                thrownException.getMessage().contains('Data Cloud Query Failed'),
                thrownException.getMessage()
        );
    }

    @isTest
    static void givenHttpErrorWithJsonBody_whenApiCallout_thenThrowsExceptionWithJsonMessage() {
        // Given
        String jsonErrorBody = '[{"errorCode": "INVALID_QUERY", "message": "Your SQL is bad"}]';
        HttpResponse mockErr = createMockResponse(400, jsonErrorBody);
        mockErr.setStatus('Bad Request');
        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(mockErr);

        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );
        Exception thrownException = null;

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        try {
            service.executeQuerySql('bad-sql', null, 'ds', 'wl');
        } catch (DataCloudRestQueryService.DataCloudQueryServiceException e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException);
        String msg = thrownException.getMessage();
        Assert.isTrue(msg.contains('API Error: 400'), msg);
        Assert.isTrue(msg.contains('Your SQL is bad'), msg); // Check that the JSON message was parsed
    }

    @isTest
    static void givenHttpErrorWithTextBody_whenApiCallout_thenThrowsExceptionWithTextMessage() {
        // Given
        String textErrorBody = 'Internal Server Error';
        HttpResponse mockErr = createMockResponse(500, textErrorBody);
        mockErr.setStatus('Server Error');

        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(mockErr);

        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = initializeRestServiceWithNamedCredential(
                TEST_NAMED_CRED
        );
        Exception thrownException = null;

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        try {
            service.getQueryStatus(TEST_QUERY_ID, 'ds', 'wl');
        } catch (DataCloudRestQueryService.DataCloudQueryServiceException e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException);
        String msg = thrownException.getMessage();
        Assert.isTrue(msg.contains('API Error: 500'), msg);
        Assert.isTrue(msg.contains(textErrorBody), msg); // Check that the text body was appended
    }

    @isTest
    static void givenBlankInputs_whenExecuteQuerySql_thenUsesDefaultDataspaceAndWorkload() {
        // Given
        String jsonBody = JSON.serialize(new Map<String, Object>{
                'status' => new Map<String, Object>{ 'queryId' => TEST_QUERY_ID, 'completionStatus' => 'Running' }
        });
        DataCloudCalloutMock calloutMock = new DataCloudCalloutMock();
        calloutMock.setMockResponse(createMockResponse(200, jsonBody));

        // This test relies on the helper method from another test class,
        // which is fragile but preserves the original test's logic.
        DataCloudQuerySetting__mdt settings = DataCloudQueryServiceProviderTest.createMdtSetting(
                true,
                TEST_NAMED_CRED,
                'TestDS',
                'TestWL'
        );

        DataCloudQueryServiceProvider.defaultSettings = settings;
        DataCloudQueryServiceProvider.IDataCloudQueryProvider service = DataCloudQueryServiceProvider.getInstance();

        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        // Pass null dataspace and blank workload
        service.executeQuerySql(
                'SELECT Id from ssot__account__dlm',
                new List<DataCloudQueryServiceProvider.SqlParameterItem>(),
                '',
                ''
        );
        Test.stopTest();

        // Then
        HttpRequest capturedReq = calloutMock.getActualRequest();
        String endpoint = capturedReq.getEndpoint();

        // Check that the default values were URL-encoded and added
        String expectedDataspace = 'dataspace=' +
                EncodingUtil.urlEncode(DataCloudQueryServiceProvider.DEFAULT_DATASPACE_NAME, 'UTF-8');
        String expectedWorkload = 'workloadName=' +
                EncodingUtil.urlEncode(DataCloudQueryServiceProvider.DEFAULT_WORKLOAD_NAME, 'UTF-8');

        Assert.isTrue(endpoint.contains(expectedDataspace), 'Default dataspace was not used');
        Assert.isTrue(endpoint.contains(expectedWorkload), 'Default workload was not used');
    }
}