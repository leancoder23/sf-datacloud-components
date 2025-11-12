/**
 * @description Tests the DataCloudCdpQueryService.
 * This class uses a stub adapter (DataCloudQueryAdapter_stub) to mock
 * responses from the ConnectApi and ensures the service correctly
 * translates them into the standardized QueryResult object.
 */
@IsTest
private class DataCloudCdpQueryServiceTest {

    // --- Static variables to hold mock responses for the StubProvider ---
    @TestVisible
    private static ConnectApi.QuerySqlOutput mockQuerySqlOutput;
    @TestVisible
    private static ConnectApi.QuerySqlStatus mockQuerySqlStatus;
    @TestVisible
    private static ConnectApi.QuerySqlPageOutput mockQuerySqlPageOutput;

    // --- Mock Data Constants ---
    private static final String MOCK_QUERY_ID = '000-TEST-QUERY-ID-123';
    private static final String MOCK_DATASPACE = 'TestDataspace';
    private static final String MOCK_WORKLOAD = 'TestWorkload';

    /**
     * @description Stub implementation of DataCloudQueryAdapter to mock ConnectApi calls.
     */
    private class CdpQueryAdapterStub extends DataCloudCdpQueryService.CdpQueryAdapter {
        public override ConnectApi.QuerySqlOutput querySql(
                ConnectApi.QuerySqlInput input,
                String workloadName,
                String dataspace
        ) {
            return mockQuerySqlOutput;
        }
        public override ConnectApi.QuerySqlStatus querySqlStatus(
                String queryId,
                String workloadName,
                String dataspace
        ) {
            return mockQuerySqlStatus;
        }
        public override ConnectApi.QuerySqlPageOutput querySqlRows(
                String queryId,
                Long offset,
                Long rowLimit,
                String workloadName,
                String dataspace
        ) {
            return mockQuerySqlPageOutput;
        }
    }

    /**
     * @description Helper to create a service instance with an injected stub.
     */
    private static DataCloudCdpQueryService createServiceWithStub() {
        DataCloudCdpQueryService service = new DataCloudCdpQueryService();
        service.queryAdapter = new CdpQueryAdapterStub();
        return service;
    }

    /**
     * @description Helper to build mock query metadata
     */
    private static List<ConnectApi.QuerySqlMetadataItem> getMockMetadata() {
        ConnectApi.QuerySqlMetadataItem col1 = new ConnectApi.QuerySqlMetadataItem();
        col1.name = 'Id';
        col1.type = ConnectApi.TypeEnum.Varchar;

        ConnectApi.QuerySqlMetadataItem col2 = new ConnectApi.QuerySqlMetadataItem();
        col2.name = 'FirstName';
        col2.type = ConnectApi.TypeEnum.Varchar;

        return new List<ConnectApi.QuerySqlMetadataItem>{ col1, col2 };
    }

    /**
     * @description Helper to build mock query data rows
     */
    private static List<ConnectApi.QuerySqlRow> getMockDataRows() {
        ConnectApi.QuerySqlRow row1 = new ConnectApi.QuerySqlRow();
        row1.row = new List<Object>{ 'id-001', 'Alice' };

        ConnectApi.QuerySqlRow row2 = new ConnectApi.QuerySqlRow();
        row2.row = new List<Object>{ 'id-002', 'Bob' };

        return new List<ConnectApi.QuerySqlRow>{ row1, row2 };
    }

    // --- Test Methods ---


    // Testing CdpQueryAdapter - the focus is just to improve the code coverage
    @IsTest
    static void executeCdPQueryMethod_withInvalidQuery_expectException() {

        DataCloudCdpQueryService.CdpQueryAdapter adapter  = new DataCloudCdpQueryService.CdpQueryAdapter();

        Exception expectedException;
        try{
            adapter.querySql(new ConnectApi.QuerySqlInput(),null,null);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areNotEqual(null,expectedException,'Exception expected');

        try{
            expectedException=null;
            adapter.querySqlStatus('fake-query-id',null,null);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areNotEqual(null,expectedException,'Exception expected');

        try{
            expectedException=null;
            adapter.querySqlRows('fake-query-id',0,5,null,null);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areNotEqual(null,expectedException,'Exception expected');


    }


    // Testing main logics

    @IsTest
    static void givenCompletedQuery_whenExecuteQuerySql_thenReturnsResultWithRecords() {
        // Given
        mockQuerySqlOutput = new ConnectApi.QuerySqlOutput();
        mockQuerySqlOutput.status = new ConnectApi.QuerySqlStatus();
        mockQuerySqlOutput.status.completionStatus = ConnectApi.QuerySqlStatusEnum.Finished;
        mockQuerySqlOutput.status.queryId = MOCK_QUERY_ID;
        mockQuerySqlOutput.status.rowCount = 2;
        mockQuerySqlOutput.metadata = getMockMetadata();
        mockQuerySqlOutput.dataRows = getMockDataRows();

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.QueryResult result = service.executeQuerySql(
                'SELECT Id, FirstName FROM ssot__Contact_dlm',
                null,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(MOCK_QUERY_ID, result.queryId, 'Query ID mismatch');
        Assert.isTrue(result.isCompleted, 'Query should be completed');
        Assert.areEqual(2, result.rowCount, 'Row count mismatch');
        Assert.isNotNull(result.records, 'Records list should not be null');
        Assert.areEqual(2, result.records.size(), 'Records list size mismatch');
        Assert.areEqual('Alice', result.records[0].get('FirstName'), 'Record data mismatch');
        Assert.areEqual('id-002', result.records[1].get('Id'), 'Record data mismatch');
    }

    @IsTest
    static void givenRunningQuery_whenExecuteQuerySql_thenReturnsIncompleteResult() {
        // Given
        mockQuerySqlOutput = new ConnectApi.QuerySqlOutput();
        mockQuerySqlOutput.status = new ConnectApi.QuerySqlStatus();
        mockQuerySqlOutput.status.completionStatus = ConnectApi.QuerySqlStatusEnum.Running;
        mockQuerySqlOutput.status.queryId = MOCK_QUERY_ID;

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.QueryResult result = service.executeQuerySql(
                'SELECT Id FROM ssot__Contact_dlm',
                null,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual(MOCK_QUERY_ID, result.queryId);
        Assert.isFalse(result.isCompleted, 'Query should be in progress');
        Assert.isNull(result.rowCount, 'Row count should be null for incomplete query');
        Assert.isNull(result.records, 'Records should be null for incomplete query');
    }

    @IsTest
    static void givenQueryWithParams_whenExecuteQuerySql_thenReturnsCompletedResult() {
        // Given
        mockQuerySqlOutput = new ConnectApi.QuerySqlOutput();
        mockQuerySqlOutput.status = new ConnectApi.QuerySqlStatus();
        mockQuerySqlOutput.status.completionStatus = ConnectApi.QuerySqlStatusEnum.Finished;
        mockQuerySqlOutput.status.queryId = MOCK_QUERY_ID;
        mockQuerySqlOutput.status.rowCount = 1;
        mockQuerySqlOutput.metadata = getMockMetadata();
        mockQuerySqlOutput.dataRows = getMockDataRows(); // Mock data is fine

        DataCloudCdpQueryService service = createServiceWithStub();

        // Setup parameters to pass
        List<DataCloudQueryServiceProvider.SqlParameterItem> queryParams = new List<DataCloudQueryServiceProvider.SqlParameterItem>();
        DataCloudQueryServiceProvider.SqlParameterItem param = new DataCloudQueryServiceProvider.SqlParameterItem();
        param.name = 'email';
        param.value = 'test@example.com';
        param.type = 'Varchar'; // Must match a ConnectApi.TypeEnum value
        queryParams.add(param);

        // When
        Test.startTest();
        // This test implicitly validates the convertToConnectApiParams method
        DataCloudQueryServiceProvider.QueryResult result = service.executeQuerySql(
                'SELECT Id FROM ssot__Contact_dlm WHERE Email =:email',
                queryParams,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        // We just need to assert that the call succeeded and returned the mock data.
        // This confirms the parameter conversion didn't cause a crash.
        Assert.isNotNull(result);
        Assert.areEqual(MOCK_QUERY_ID, result.queryId);
        Assert.isTrue(result.isCompleted);
    }

    @IsTest
    static void givenNullAndBlankInputs_whenExecuteQuerySql_thenSucceedsWithoutError() {
        // Given
        mockQuerySqlOutput = new ConnectApi.QuerySqlOutput();
        mockQuerySqlOutput.status = new ConnectApi.QuerySqlStatus();
        mockQuerySqlOutput.status.completionStatus = ConnectApi.QuerySqlStatusEnum.Finished;
        mockQuerySqlOutput.status.queryId = MOCK_QUERY_ID;
        mockQuerySqlOutput.metadata = getMockMetadata();
        mockQuerySqlOutput.dataRows = getMockDataRows();

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        // Pass nulls and blank strings for dataspace and workload
        DataCloudQueryServiceProvider.QueryResult result1 = service.executeQuerySql(
                'SELECT Id FROM ssot__Contact_dlm',
                null,
                null,
                null
        );
        DataCloudQueryServiceProvider.QueryResult result2 = service.executeQuerySql(
                'SELECT Id FROM ssot__Contact_dlm',
                null,
                '',
                ''
        );
        Test.stopTest();

        // Then
        // The main assertion is that no NullPointerException occurred
        Assert.isNotNull(result1);
        Assert.areEqual(MOCK_QUERY_ID, result1.queryId);
        Assert.isNotNull(result2);
        Assert.areEqual(MOCK_QUERY_ID, result2.queryId);
    }

    @IsTest
    static void givenCompletedStatus_whenGetQueryStatus_thenReturnsCompletedResult() {
        // Given
        mockQuerySqlStatus = new ConnectApi.QuerySqlStatus();
        mockQuerySqlStatus.completionStatus = ConnectApi.QuerySqlStatusEnum.Finished;
        mockQuerySqlStatus.queryId = MOCK_QUERY_ID;
        mockQuerySqlStatus.rowCount = 5;

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.QueryResult result = service.getQueryStatus(
                MOCK_QUERY_ID,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual(MOCK_QUERY_ID, result.queryId);
        Assert.isTrue(result.isCompleted);
        Assert.areEqual(5, result.rowCount);
        Assert.isNull(result.records, 'Records should be null for status check');
    }

    @IsTest
    static void givenRunningStatus_whenGetQueryStatus_thenReturnsIncompleteResult() {
        // Given
        mockQuerySqlStatus = new ConnectApi.QuerySqlStatus();
        mockQuerySqlStatus.completionStatus = ConnectApi.QuerySqlStatusEnum.Running;
        mockQuerySqlStatus.queryId = MOCK_QUERY_ID;

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.QueryResult result = service.getQueryStatus(
                MOCK_QUERY_ID,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual(MOCK_QUERY_ID, result.queryId);
        Assert.isFalse(result.isCompleted);
        Assert.isNull(result.rowCount);
    }

    @IsTest
    static void givenQueryId_whenGetQueryResult_thenReturnsResultWithRecords() {
        // Given
        mockQuerySqlPageOutput = new ConnectApi.QuerySqlPageOutput();
        mockQuerySqlPageOutput.metadata = getMockMetadata();
        mockQuerySqlPageOutput.dataRows = getMockDataRows();

        DataCloudCdpQueryService service = createServiceWithStub();

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.QueryResult result = service.getQueryResult(
                MOCK_QUERY_ID,
                0,
                2,
                MOCK_DATASPACE,
                MOCK_WORKLOAD
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual(MOCK_QUERY_ID, result.queryId, 'Query ID mismatch');
        Assert.isNotNull(result.records, 'Records list should not be null');
        Assert.areEqual(2, result.records.size(), 'Records list size mismatch');
        Assert.areEqual('Alice', result.records[0].get('FirstName'), 'Record data mismatch');
        Assert.areEqual('id-002', result.records[1].get('Id'), 'Record data mismatch');
    }
}