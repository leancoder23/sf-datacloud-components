/**
 * @description Test class for the DataCloudQueryServiceController.
 * This class uses mock implementations for the query service
 * and adapter to isolate and test the controller's logic
 * without making real callouts or SOQL queries.
 */
@isTest
private class DataCloudQueryServiceControllerTest {

    //==========================================================================
    // Mock Implementation for the Data Cloud Query Service
    // This 'stub' class implements the provider interface so we can
    // control its behavior during tests without making real callouts.
    //==========================================================================
    private class DataCloudQueryServiceMock implements DataCloudQueryServiceProvider.IDataCloudQueryProvider {

        // Controls what the mock service will return
        public DataCloudQueryServiceProvider.QueryResult queryResultToReturn;
        public Exception exceptionToThrow;

        // Captures inputs for assertion
        public String query;
        public String queryId;
        public List<DataCloudQueryServiceProvider.SqlParameterItem> params;
        public String dataspace;
        public String workload;

        public void initializeWith(Map<String,Object> params){
            return;
        }

        public DataCloudQueryServiceProvider.QueryResult executeQuerySql(String query, List<DataCloudQueryServiceProvider.SqlParameterItem> params, String dataspace, String workload) {
            if (exceptionToThrow != null) { throw exceptionToThrow; }
            this.query = query;
            this.params = params;
            this.dataspace = dataspace;
            this.workload = workload;
            return queryResultToReturn;
        }

        public DataCloudQueryServiceProvider.QueryResult getQueryStatus(String queryId, String dataspace, String workload) {
            if (exceptionToThrow != null) { throw exceptionToThrow; }
            this.queryId = queryId;
            this.dataspace = dataspace;
            this.workload = workload;
            return queryResultToReturn;
        }

        public DataCloudQueryServiceProvider.QueryResult getQueryResult(String queryId, Integer rowStart, Integer rowCount, String dataspace, String workload) {
            if (exceptionToThrow != null) { throw exceptionToThrow; }
            this.queryId = queryId;
            this.dataspace = dataspace;
            this.workload = workload;
            return queryResultToReturn;
        }
    }

    /**
     * @description Mock implementation for the DataCloudQueryAdapter.
     * This allows faking SOQL queries and metadata retrieval.
     */
    private class SoqlQueryAdapterMock extends DataCloudQueryServiceController.SoqlQueryAdapter {
        public List<SObject> mockRecords;
        public DataCloudQuerySetting__mdt mockQuerySetting;

        public override List<SObject> querySoqlWithBinds(String soql, Map<String, Object> bindMap, System.AccessLevel accessLevel) {
            return mockRecords;
        }

        public override DataCloudQuerySetting__mdt getDataCloudQueryServiceSetting(String developerName, Boolean useSoql) {
            return mockQuerySetting;
        }
    }


    static void initializeControllerAdapterWithMockAdapter(){
        DataCloudQuerySetting__mdt querySetting = new  DataCloudQuerySetting__mdt(
                DeveloperName = 'QueryDefault',
                UseDataCloudRestApi__c = true,
                NamedCredential__c = 'TestNC',
                Dataspace__c = 'default',
                WorkloadName__c = 'wk'
        );

        DataCloudQueryServiceProvider.defaultSettings=querySetting;
        DataCloudQueryServiceController.dataCloudQueryService = new DataCloudQueryServiceMock();
        DataCloudQueryServiceController.soqlQueryAdapter =new SoqlQueryAdapterMock();

    }



    //==========================================================================
    // Test Methods
    //==========================================================================

    //Testing SoqlQueryAdapter - the focus is just to improve the code coverage
    @IsTest
    static void givenAccountSOQL_expectNoException(){
        DataCloudQueryServiceController.SoqlQueryAdapter adapter  = new DataCloudQueryServiceController.SoqlQueryAdapter();
        Exception expectedException;
        try{
            List<SObject> record =  adapter.querySoqlWithBinds('SELECT Id FROM Account LIMIT 5',new Map<String,Object>(),AccessLevel.SYSTEM_MODE);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areEqual(null,expectedException,'No exception expected!');


    }

    @IsTest
    static void givenValidName_GetValidCustomMetadataSetting(){
        DataCloudQueryServiceController.SoqlQueryAdapter adapter  = new DataCloudQueryServiceController.SoqlQueryAdapter();
        Exception expectedException;
        DataCloudQuerySetting__mdt setting;
        //by executing soql
        try{
            setting= adapter.getDataCloudQueryServiceSetting('QueryDefault',true);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areEqual(null,expectedException,'No exception expected!');
        Assert.areNotEqual(null,setting,'Expected setting record ');

        //using getInstance
        try{
            setting= adapter.getDataCloudQueryServiceSetting('QueryDefault',false);
        }catch(Exception e){
            expectedException = e;
        }
        Assert.areEqual(null,expectedException,'No exception expected!');
        Assert.areNotEqual(null,setting,'Expected setting record ');


    }

    //Testing main controller logics
    @IsTest
    static void givenRecordFieldParam_whenGetSqlParameterItem_thenReturnsCorrectItem() {
        // Given
        DataCloudQueryServiceController.RecordFieldParam param = new DataCloudQueryServiceController.RecordFieldParam();
        param.name = 'acctId';
        param.type = 'STRING';
        param.fieldName = 'Id';
        String testValue = '001xx00000ABCDE';

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.SqlParameterItem item = param.getSqlParameterItem(testValue);
        Test.stopTest();

        // Then
        Assert.areEqual('acctId', item.name, 'Name should match');
        Assert.areEqual('STRING', item.type, 'Type should match');
        Assert.areEqual(testValue, item.value, 'Value should match');
    }

    @IsTest
    static void givenValidId_whenGetRecordData_thenReturnsSObject() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        Id fakeAccountId = '001000000000000AAA';
        Account acct = new Account(
                Id = fakeAccountId,
                Name = 'Test Account',
                Phone = '0011'
        );
        queryAdapterMock.mockRecords = new List<SObject>{ acct };

        // When
        Test.startTest();
        SObject record = DataCloudQueryServiceController.getRecordData(
                fakeAccountId,
                new List<String>{ 'Name', 'Phone' }
        );
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, record, 'Record should not be null');
        Assert.areEqual(acct.Name, record.get('Name'), 'Name should match');
        Assert.areEqual(acct.Phone, record.get('Phone'), 'Phone should match');
    }

    @isTest
    static void givenInvalidId_whenGetRecordData_thenThrowsException() {
        // Given

        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        queryAdapterMock.mockRecords = new List<SObject>(); // Mock - No record found

        Id fakeAccountId = '001000000000000AAA';
        List<String> fields = new List<String>{ 'Name' };
        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.getRecordData(fakeAccountId, fields);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'An exception should have been thrown');
        Assert.isTrue(
                expectedException instanceof DataCloudQueryServiceProvider.DataCloudQueryServiceException,
                'Exception type should be DataCloudQueryServiceException'
        );
        Assert.isTrue(
                expectedException.getMessage().contains('No Account record found'),
                'Exception message should indicate record not found'
        );
    }

    @isTest
    static void givenAccessibleSalesforceId_whenResolveRecordNavigation_thenReturnsLocalRecord() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        Id fakeAccountId = '001000000000000AAA';
        queryAdapterMock.mockRecords = new List<SObject>{ new Account(Id = fakeAccountId) };

        // When — valid SF Id that the user can access (Tier 1 hit)
        Test.startTest();
        DataCloudQueryServiceController.RecordNavigationInfo navInfo =
                DataCloudQueryServiceController.resolveRecordNavigation(String.valueOf(fakeAccountId), null);
        Test.stopTest();

        // Then
        Assert.areEqual(DataCloudQueryServiceController.NAV_LOCAL_RECORD, navInfo.navigationType,
                'Should resolve to LOCAL_RECORD when user can access the record');
        Assert.areEqual(fakeAccountId, navInfo.resolvedRecordId,
                'resolvedRecordId should match the provided Salesforce Id');
        Assert.areEqual('Account', navInfo.objectApiName,
                'objectApiName should be the SObject type of the Id');

        // Cover RecordNavigationInfo property access
        DataCloudQueryServiceController.RecordNavigationInfo info = new DataCloudQueryServiceController.RecordNavigationInfo();
        info.navigationType = 'LOCAL_RECORD';
        info.resolvedRecordId = fakeAccountId;
        info.objectApiName = 'Account';
        Assert.areEqual('LOCAL_RECORD', info.navigationType);
        Assert.areEqual(fakeAccountId, info.resolvedRecordId);
        Assert.areEqual('Account', info.objectApiName);
    }

    @isTest
    static void givenDmoIdWithData360ObjectInSchema_whenResolveRecordNavigation_thenReturnsData360Record() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        Id fakeAccountId = '001000000000000AAA';
        queryAdapterMock.mockRecords = new List<SObject>{ new Account(Id = fakeAccountId) };

        // When — non-SF Id triggers StringException → falls through to Tier 2;
        //        Account exists in schema (connected org) and mock returns a match
        Test.startTest();
        DataCloudQueryServiceController.RecordNavigationInfo navInfo =
                DataCloudQueryServiceController.resolveRecordNavigation('dmo-ssot-id-001', 'Account');
        Test.stopTest();

        // Then
        Assert.areEqual(DataCloudQueryServiceController.NAV_DATA360_RECORD, navInfo.navigationType,
                'Should resolve to DATA360_RECORD when object exists in schema and ssot__Id__c match is found');
        Assert.areEqual(fakeAccountId, navInfo.resolvedRecordId,
                'resolvedRecordId should be the Id returned by ssot__Id__c lookup');
        Assert.areEqual('Account', navInfo.objectApiName,
                'objectApiName should be the Data360 object name');
    }

    @isTest
    static void givenDmoIdWithObjectNotInSchema_whenResolveRecordNavigation_thenReturnsCustomPage() {
        // Given
        initializeControllerAdapterWithMockAdapter();

        // When — non-SF Id triggers StringException → falls through to Tier 2;
        //        object not in schema (org not connected) → Tier 2 skipped → Tier 3 fallback
        Test.startTest();
        DataCloudQueryServiceController.RecordNavigationInfo navInfo =
                DataCloudQueryServiceController.resolveRecordNavigation('dmo-ssot-id-001', 'NonExistentObject__dlm');
        Test.stopTest();

        // Then
        Assert.areEqual(DataCloudQueryServiceController.NAV_CUSTOM_PAGE, navInfo.navigationType,
                'Should fall back to CUSTOM_PAGE when Data360 object is not in schema (org not connected)');
        Assert.areEqual(null, navInfo.resolvedRecordId,
                'resolvedRecordId should be null for CUSTOM_PAGE');
        Assert.areEqual(null, navInfo.objectApiName,
                'objectApiName should be null for CUSTOM_PAGE');
    }

    @isTest
    static void givenRecordIdAndFieldParams_whenGetQueryParams_thenReturnsCorrectSqlParameters() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        Id fakeAccountId = '001000000000000AAA';
        Account acct = new Account(Id = fakeAccountId, Name = 'Test-Account');
        queryAdapterMock.mockRecords = new List<SObject>{ acct };

        DataCloudQueryServiceController.RecordFieldParam recordIdParam = new DataCloudQueryServiceController.RecordFieldParam();
        recordIdParam.name = 'recordId';
        recordIdParam.type = 'varchar';
        recordIdParam.fieldName = 'Id'; // Note: 'recordId' in original, changed to 'Id' to match acct.Id

        DataCloudQueryServiceController.RecordFieldParam recordIfaParam = new DataCloudQueryServiceController.RecordFieldParam();
        recordIfaParam.name = 'accountIfa';
        recordIfaParam.type = 'varchar';
        recordIfaParam.fieldName = 'Name';

        List<DataCloudQueryServiceController.RecordFieldParam> fieldParams = new List<DataCloudQueryServiceController.RecordFieldParam>{
                recordIdParam,
                recordIfaParam
        };

        // When
        Test.startTest();
        // Test null case
        List<DataCloudQueryServiceProvider.SqlParameterItem> nullParams = DataCloudQueryServiceController.getQueryParamsBasedOnRecordId(
                null,
                fieldParams
        );

        // Test valid case
        List<DataCloudQueryServiceProvider.SqlParameterItem> sqlParams = DataCloudQueryServiceController.getQueryParamsBasedOnRecordId(
                fakeAccountId,
                fieldParams
        );
        Test.stopTest();

        // Then
        Assert.areEqual(null, nullParams, 'Should return null when recordId is null');
        Assert.areNotEqual(null, sqlParams, 'Should not return null when recordId is valid');
        Assert.areEqual(2, sqlParams.size(), 'Should return two parameters');

        Assert.areEqual(recordIdParam.name, sqlParams[0].name, 'Param 1 name mismatch');
        Assert.areEqual(acct.Id, sqlParams[0].value, 'Param 1 value should be Account Id');

        Assert.areEqual(recordIfaParam.name, sqlParams[1].name, 'Param 2 name mismatch');
        Assert.areEqual(acct.Name, sqlParams[1].value, 'Param 2 value should be Account Name');
    }

    @isTest
    static void givenMissingSetting_whenSubmitDataCloudQuery_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        queryAdapterMock.mockQuerySetting = null; // Mock - No setting found
        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.submitDataCloudQuery('FAKE_SETTING_NAME', null);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'An exception should have been thrown');
        Assert.isTrue(
                expectedException.getMessage().contains('is not found'),
                'Exception message should indicate setting not found'
        );
    }

    @isTest
    static void givenMissingSetting_whenGetDataCloudQueryStatus_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        queryAdapterMock.mockQuerySetting = null; // Mock - No setting found
        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.getDataCloudQueryStatus('FAKE_SETTING_NAME', 'q-123');
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'An exception should have been thrown');
        Assert.isTrue(
                expectedException.getMessage().contains('is not found'),
                'Exception message should indicate setting not found'
        );
    }

    @isTest
    static void givenMissingSetting_whenGetDataCloudQueryData_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        queryAdapterMock.mockQuerySetting = null; // Mock - No setting found
        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.getDataCloudQueryData('FAKE_SETTING_NAME', 'q-123', 0, 100);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'An exception should have been thrown');
        Assert.isTrue(
                expectedException.getMessage().contains('is not found'),
                'Exception message should indicate setting not found'
        );
    }

    @isTest
    static void givenSettingWithMissingQuery_whenSubmitQuery_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;


        // Mock setting exists, but the Query__c field is null
        queryAdapterMock.mockQuerySetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query'
                // Query__c is intentionally null
        );

        Id fakeAccountId = '001000000000000AAA';
        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.submitDataCloudQuery('Test_Account_Query', fakeAccountId);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'Should throw an exception');
        Assert.isTrue(
                expectedException.getMessage().contains('Query is not configured for Query Setting'),
                'Incorrect error thrown'
        );
    }

    @isTest
    static void givenSettingRequiringRecordId_whenSubmitQueryWithNullId_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;


        // Mock setting requires a record-based parameter
        queryAdapterMock.mockQuerySetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query',
                Query__c = 'SELECT * FROM ssot__opportunity_dlm where account_ifa=:accountIfa',
                RecordFilterObject__c = 'Account',
                RecordBasedFilterConfig__c = 'accountIfa:Name:varchar'
        );

        Exception expectedException;

        // When: Call submit with a null recordId
        Test.startTest();
        try {
            DataCloudQueryServiceController.submitDataCloudQuery('Test_Account_Query', null);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'Should throw an exception');
        Assert.isTrue(
                expectedException.getMessage().contains('Query requires current record id which is empty'),
                'Incorrect error thrown'
        );
    }

    @isTest
    static void givenSettingWithWrongFilterObject_whenSubmitQuery_thenThrowsException() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;

        Id fakeAccountId = '001000000000000AAA'; // This is an Account Id

        // Mock setting is configured for 'Opportunity', but we pass an 'Account' Id
        queryAdapterMock.mockQuerySetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query',
                Query__c = 'SELECT * FROM ssot__opportunity_dlm where account_ifa=:accountIfa',
                RecordFilterObject__c = 'Opportunity', // Mismatch with fakeAccountId
                RecordBasedFilterConfig__c = 'accountIfa:Name:varchar'
        );

        Exception expectedException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceController.submitDataCloudQuery('Test_Account_Query', fakeAccountId);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, expectedException, 'Should throw an exception');
        Assert.isTrue(
                expectedException.getMessage().contains('Incorrect recordId,  Query requires to be executed in context of valid'),
                'Incorrect error thrown'
        );
    }

    @isTest
    static void givenValidSettingAndRecord_whenSubmitQuery_thenReturnsQueryId() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;
        DataCloudQueryServiceMock queryServiceMock = (DataCloudQueryServiceMock)DataCloudQueryServiceController.dataCloudQueryService;


        DataCloudQueryServiceProvider.QueryResult queryResultMock = new DataCloudQueryServiceProvider.QueryResult();
        queryResultMock.queryId = 'fake-query-id';
        queryResultMock.isCompleted = false;
        queryServiceMock.queryResultToReturn = queryResultMock;

        DataCloudQuerySetting__mdt mockSetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query',
                Query__c = 'SELECT * FROM ssot__opportunity_dlm where accountIfa=:accountIfa',
                RecordFilterObject__c = 'Account',
                RecordBasedFilterConfig__c = 'accountIfa:Name:varchar'
        );
        queryAdapterMock.mockQuerySetting = mockSetting;

        Id fakeAccountId = '001000000000000AAA';
        Account acct = new Account(Id = fakeAccountId, Name = 'Test-Account');
        queryAdapterMock.mockRecords = new List<SObject>{ acct };

        DataCloudQueryServiceProvider.QueryResult result;
        Exception expectedException;

        // When
        Test.startTest();
        try {
            result = DataCloudQueryServiceController.submitDataCloudQuery('Test_Account_Query', acct.Id);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areEqual(null, expectedException, 'Should not throw exception');
        Assert.areEqual(queryResultMock.queryId, result.queryId, 'Must return query id');
        Assert.isFalse(result.isCompleted, 'result complete flag must be false');
        Assert.areEqual(null, result.records, 'No records should be returned on submit');
        Assert.areEqual(mockSetting.Query__c, queryServiceMock.query, 'Query does not match');
        Assert.areEqual(1, queryServiceMock.params.size(), 'Should have one parameter');
        Assert.areEqual('accountIfa', queryServiceMock.params.get(0).name, 'Query parameter name mismatch');
        Assert.areEqual(acct.Name, queryServiceMock.params.get(0).value, 'Query parameter value mismatch');
    }

    @isTest
    static void givenValidQueryId_whenGetStatus_thenReturnsCompletedStatus() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;
        DataCloudQueryServiceMock queryServiceMock = (DataCloudQueryServiceMock)DataCloudQueryServiceController.dataCloudQueryService;


        String queryId = 'fake-query-id';

        DataCloudQueryServiceProvider.QueryResult queryResultMock = new DataCloudQueryServiceProvider.QueryResult();
        queryResultMock.queryId = queryId;
        queryResultMock.isCompleted = true;
        queryResultMock.rowCount = 2;
        queryServiceMock.queryResultToReturn = queryResultMock;

        queryAdapterMock.mockQuerySetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query'
        );

        DataCloudQueryServiceProvider.QueryResult result;
        Exception expectedException;

        // When
        Test.startTest();
        try {
            result = DataCloudQueryServiceController.getDataCloudQueryStatus('Test_Account_Query', queryId);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areEqual(null, expectedException, 'Should not throw exception');
        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(queryResultMock.queryId, result.queryId, 'Result queryId should be from the mock');
        Assert.isTrue(result.isCompleted, 'Status isCompleted should be true');
        Assert.areEqual(queryResultMock.rowCount, result.rowCount, 'Row count should match');
    }

    @isTest
    static void givenValidQueryId_whenGetData_thenReturnsDataRecords() {
        // Given
        initializeControllerAdapterWithMockAdapter();
        //Initialize Controller Adapter must be called before
        SoqlQueryAdapterMock queryAdapterMock = (SoqlQueryAdapterMock)DataCloudQueryServiceController.soqlQueryAdapter;
        DataCloudQueryServiceMock queryServiceMock = (DataCloudQueryServiceMock)DataCloudQueryServiceController.dataCloudQueryService;


        String queryId = 'fake-query-id';

        DataCloudQueryServiceProvider.QueryResult queryResultMock = new DataCloudQueryServiceProvider.QueryResult();
        queryResultMock.queryId = queryId;
        queryResultMock.records = new List<Map<String, Object>>{
                new Map<String, Object>{ 'id' => 'test-Id', 'name' => 'test-Name' }
        };
        queryResultMock.rowCount = 1;
        queryServiceMock.queryResultToReturn = queryResultMock;


        queryAdapterMock.mockQuerySetting = new DataCloudQuerySetting__mdt(
                DeveloperName = 'Test_Account_Query'
        );

        DataCloudQueryServiceProvider.QueryResult result;
        Exception expectedException;

        // When
        Test.startTest();
        try {
            result = DataCloudQueryServiceController.getDataCloudQueryData('Test_Account_Query', queryId, 0, 200);
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        // Then
        Assert.areEqual(null, expectedException, 'Should not throw exception');
        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(queryResultMock.queryId, result.queryId, 'Result queryId should be from the mock');
        Assert.areEqual(queryResultMock.records.size(), result.records.size(), 'Record count should match');
    }
}