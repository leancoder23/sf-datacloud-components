/**
 * @description Tests the DataCloudQueryServiceProvider to ensure it returns the
 * correct service implementation (CDP or REST) based on metadata settings
 * and handles configuration errors gracefully.
 */
@IsTest
@TestVisible
private class DataCloudQueryServiceProviderTest {

    private class  DataCloudQueryServiceMock implements DataCloudQueryServiceProvider.IDataCloudQueryProvider{

        public String serviceName;
        public String namedCredential;

        public void initializeWith(Map<String,Object> params){
           return;
        }

        public DataCloudQueryServiceProvider.QueryResult executeQuerySql(String query, List<DataCloudQueryServiceProvider.SqlParameterItem> params, String dataspace, String workload) {
           return null;
        }

        public DataCloudQueryServiceProvider.QueryResult getQueryStatus(String queryId, String dataspace, String workload) {
            return null;
        }

        public DataCloudQueryServiceProvider.QueryResult getQueryResult(String queryId, Integer rowStart, Integer rowCount, String dataspace, String workload) {
           return null;
        }
    }

    private class ServiceProviderInitializationAdapterMock extends DataCloudQueryServiceProvider.ServiceProviderInitializationAdapter {

        public Boolean cdpQueryServiceExists=false;
        public Boolean restQueryServiceExists=false;

        public override Boolean isCdpQueryServiceExists(){
            return cdpQueryServiceExists;
        }

        public override Boolean isRestQueryServiceExists(){
            return restQueryServiceExists;
        }

        public override DataCloudQueryServiceProvider.IDataCloudQueryProvider createCdpServiceInstance(){
            DataCloudQueryServiceMock serviceMock =  new DataCloudQueryServiceMock();
            serviceMock.serviceName='DataCloudCdpQueryService';
            return serviceMock;
        }

        public override  DataCloudQueryServiceProvider.IDataCloudQueryProvider createRestServiceInstance(String namedCredential){
            DataCloudQueryServiceMock serviceMock =  new DataCloudQueryServiceMock();
            serviceMock.namedCredential=namedCredential;
            serviceMock.serviceName='DataCloudRestQueryService';
            return serviceMock;
        }
    }

    /**
     * @description Helper method to create a new, in-memory custom metadata setting for tests.
     */
    public static DataCloudQuerySetting__mdt createMdtSetting(
            Boolean useRest,
            String namedCred,
            String dataspace,
            String workload
    ) {
        return new DataCloudQuerySetting__mdt(
                DeveloperName = 'QueryDefault',
                UseDataCloudRestApi__c = useRest,
                NamedCredential__c = namedCred,
                Dataspace__c = dataspace,
                WorkloadName__c = workload
        );
    }

    @IsTest
    static void initialize_SqlParameterItem_forTestCoverage(){
        //No assert is needed, as there is no logic to test.
        // This test block is only for test coverage
        DataCloudQueryServiceProvider.SqlParameterItem param = new DataCloudQueryServiceProvider.SqlParameterItem();
        param.name='test';
        param.value='test';
        param.type='varchar';
    }

    @IsTest
    static void execute_ServiceProviderInitializationAdapter_methods(){
        // test ServiceProviderInitializationAdapter methods -
        // key focus for this test is code coverage,
        // main logic is tested within tests below

        Exception expectedException;
        DataCloudQueryServiceProvider.ServiceProviderInitializationAdapter initializationAdapter = new DataCloudQueryServiceProvider.ServiceProviderInitializationAdapter();

        try{
            initializationAdapter.createCdpServiceInstance();
        }catch(Exception e){
            expectedException=e;
        }

        if(initializationAdapter.isCdpQueryServiceExists()){
            Assert.areEqual(null,expectedException,'No exception expected when Cdp query service exists');
        }else{
            Assert.areNotEqual(null,expectedException,'An exception expected when Cdp query service does not exists');
        }

        //Test for rest service
        expectedException = null;
        try{
            initializationAdapter.createRestServiceInstance('TestNC');
        }catch(Exception e){
            expectedException=e;
        }

        if(initializationAdapter.isRestQueryServiceExists()){
            Assert.areEqual(null,expectedException,'No exception expected when Rest query service exists');
        }else{
            Assert.areNotEqual(null,expectedException,'An exception expected when Rest query service does not exists');
        }

    }


    @IsTest
    static void givenCdpSetting_whenGetInstance_thenReturnsDefaultNull(){
        // Given
        DataCloudQuerySetting__mdt settings = createMdtSetting(false, null, 'TestDS', 'TestWL');
        DataCloudQueryServiceProvider.defaultSettings = settings;

        ServiceProviderInitializationAdapterMock initializationAdapterMock = new ServiceProviderInitializationAdapterMock();
        DataCloudQueryServiceProvider.initializationAdapter=initializationAdapterMock;

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.IDataCloudQueryProvider provider = DataCloudQueryServiceProvider.getInstance();

        Test.stopTest();

        // Then
        Assert.areEqual(null,provider,'Expected null');

    }
    @IsTest
    static void givenCdpSetting_whenGetInstance_thenReturnsCdpServiceInstance() {
        // Given
        DataCloudQuerySetting__mdt settings = createMdtSetting(false, null, 'TestDS', 'TestWL');
        DataCloudQueryServiceProvider.defaultSettings = settings;

        ServiceProviderInitializationAdapterMock initializationAdapterMock = new ServiceProviderInitializationAdapterMock();
        DataCloudQueryServiceProvider.initializationAdapter=initializationAdapterMock;
        //Mock expected data
        initializationAdapterMock.cdpQueryServiceExists=true;

        DataCloudQueryServiceMock queryService;
        // When
        Test.startTest();
         DataCloudQueryServiceProvider.IDataCloudQueryProvider provider = DataCloudQueryServiceProvider.getInstance();
        queryService =((DataCloudQueryServiceMock)provider);
        Test.stopTest();

        // Then
        Assert.areEqual(queryService.serviceName,'DataCloudCdpQueryService','Expected service name is DataCloudCdpQueryService');

    }

    @IsTest
    static void givenRestSetting_whenGetInstance_thenReturnsRestServiceInstanceWithNamedCred() {
        // Given
        DataCloudQuerySetting__mdt settings = createMdtSetting(true, 'TestNC', 'TestDS', 'TestWL');
        DataCloudQueryServiceProvider.defaultSettings = settings;

        ServiceProviderInitializationAdapterMock initializationAdapterMock = new ServiceProviderInitializationAdapterMock();
        DataCloudQueryServiceProvider.initializationAdapter=initializationAdapterMock;
        //Mock expected data
        initializationAdapterMock.cdpQueryServiceExists=true;
        initializationAdapterMock.restQueryServiceExists=true;

        DataCloudQueryServiceMock queryService;
        // When
        Test.startTest();
        DataCloudQueryServiceProvider.IDataCloudQueryProvider provider = DataCloudQueryServiceProvider.getInstance();
        queryService =((DataCloudQueryServiceMock)provider);
        Test.stopTest();

        // Then
        Assert.areEqual(queryService.serviceName,'DataCloudRestQueryService','Expected service name is DataCloudRestQueryService');
        Assert.areEqual(
                'TestNC',
                queryService.namedCredential,
                'Should set the named credential developer name'
        );
    }

    @IsTest
    static void givenNullSetting_whenGetInstance_thenThrowsException() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = null;
        Exception thrownException = null;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceProvider.getInstance();
        } catch (Exception e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException, 'Expected an exception to be thrown');
        Assert.isTrue(
                thrownException instanceof DataCloudQueryServiceProvider.DataCloudQueryServiceException,
                'Expected DataCloudQueryServiceException'
        );
        Assert.isTrue(
                thrownException.getMessage().contains('QueryDefault setting expected'),
                'Wrong exception message'
        );
    }

    @IsTest
    static void givenSettingWithMissingDataspace_whenGetInstance_thenThrowsException() {
        // Given
        DataCloudQuerySetting__mdt settings = createMdtSetting(false, null, '', 'TestWL'); // Blank dataspace
        DataCloudQueryServiceProvider.defaultSettings = settings;
        Exception thrownException = null;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceProvider.getInstance();
        } catch (Exception e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException, 'Expected an exception to be thrown');
        Assert.isTrue(
                thrownException instanceof DataCloudQueryServiceProvider.DataCloudQueryServiceException,
                'Expected DataCloudQueryServiceException'
        );
        Assert.isTrue(
                thrownException.getMessage().contains('Dataspace and workload name cannot be empty'),
                'Wrong exception message'
        );
    }

    @IsTest
    static void givenRestSettingWithMissingNamedCred_whenGetInstance_thenThrowsException() {
        // Given
        DataCloudQuerySetting__mdt settings = createMdtSetting(true, '', 'TestDS', 'TestWL'); // Blank named cred
        DataCloudQueryServiceProvider.defaultSettings = settings;

        ServiceProviderInitializationAdapterMock initializationAdapterMock = new ServiceProviderInitializationAdapterMock();
        DataCloudQueryServiceProvider.initializationAdapter=initializationAdapterMock;
        //Mock expected data
        initializationAdapterMock.cdpQueryServiceExists=true;
        initializationAdapterMock.restQueryServiceExists=true;

        DataCloudQueryServiceMock queryService;


        Exception thrownException = null;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceProvider.getInstance();
        } catch (Exception e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, thrownException, 'Expected an exception to be thrown');
        Assert.isTrue(
                thrownException instanceof DataCloudQueryServiceProvider.DataCloudQueryServiceException,
                'Expected DataCloudQueryServiceException'
        );
        Assert.isTrue(
                thrownException.getMessage().contains('Named credential default setting is required'),
                'Wrong exception message'
        );
    }

    private static DataCloudQuerySetting__mdt createQuerySetting(Boolean useRest, String namedCred) {
        return new DataCloudQuerySetting__mdt(
                DeveloperName = 'TestQuery',
                UseDataCloudRestApi__c = useRest,
                NamedCredential__c = namedCred
        );
    }

    private static ServiceProviderInitializationAdapterMock initializeAdapterMock(Boolean cdpExists, Boolean restExists) {
        ServiceProviderInitializationAdapterMock initializationAdapterMock = new ServiceProviderInitializationAdapterMock();
        initializationAdapterMock.cdpQueryServiceExists = cdpExists;
        initializationAdapterMock.restQueryServiceExists = restExists;
        DataCloudQueryServiceProvider.initializationAdapter = initializationAdapterMock;
        return initializationAdapterMock;
    }

    @IsTest
    static void givenCdpDefaultAndRestSetting_whenGetInstance_thenReturnsRestServiceWithDefaultNamedCred() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(false, 'DefaultNC', 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(true, null));
        Test.stopTest();

        // Then
        Assert.areEqual('DataCloudRestQueryService', queryService.serviceName, 'Expected rest service enabled on query setting');
        Assert.areEqual('DefaultNC', queryService.namedCredential, 'Expected default named credential');
    }

    @IsTest
    static void givenCdpDefaultAndRestSettingWithNamedCred_whenGetInstance_thenUsesSettingNamedCred() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(false, 'DefaultNC', 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(true, 'QueryNC'));
        Test.stopTest();

        // Then
        Assert.areEqual('DataCloudRestQueryService', queryService.serviceName, 'Expected rest service enabled on query setting');
        Assert.areEqual('QueryNC', queryService.namedCredential, 'Expected query setting named credential');
    }

    @IsTest
    static void givenRestDefaultAndUncheckedSettingWithNamedCred_whenGetInstance_thenUsesSettingNamedCred() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(true, 'DefaultNC', 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(false, 'QueryNC'));
        Test.stopTest();

        // Then
        Assert.areEqual('DataCloudRestQueryService', queryService.serviceName, 'Expected rest service from default setting');
        Assert.areEqual('QueryNC', queryService.namedCredential, 'Expected query setting named credential');
    }

    @IsTest
    static void givenRestDefaultAndUncheckedSetting_whenGetInstance_thenUsesDefaultNamedCred() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(true, 'DefaultNC', 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(false, ''));
        Test.stopTest();

        // Then
        Assert.areEqual('DataCloudRestQueryService', queryService.serviceName, 'Expected rest service from default setting');
        Assert.areEqual('DefaultNC', queryService.namedCredential, 'Expected default named credential');
    }

    @IsTest
    static void givenCdpDefaultAndUncheckedSettingWithNamedCred_whenGetInstance_thenReturnsCdpService() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(false, null, 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(false, 'QueryNC'));
        Test.stopTest();

        // Then
        Assert.areEqual('DataCloudCdpQueryService', queryService.serviceName, 'Expected cdp service, named credential ignored');
    }

    @IsTest
    static void givenRestDefaultWithoutNamedCredAndSettingNamedCred_whenGetInstance_thenUsesSettingNamedCred() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(true, null, 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);

        // When
        Test.startTest();
        DataCloudQueryServiceMock queryService = (DataCloudQueryServiceMock)DataCloudQueryServiceProvider.getInstance(createQuerySetting(false, 'QueryNC'));
        Test.stopTest();

        // Then
        Assert.areEqual('QueryNC', queryService.namedCredential, 'Expected query setting named credential');
    }

    @IsTest
    static void givenRestSettingAndNoNamedCredAnywhere_whenGetInstance_thenThrowsException() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(false, null, 'TestDS', 'TestWL');
        initializeAdapterMock(true, true);
        Exception thrownException;

        // When
        Test.startTest();
        try {
            DataCloudQueryServiceProvider.getInstance(createQuerySetting(true, null));
        } catch (Exception e) {
            thrownException = e;
        }
        Test.stopTest();

        // Then
        Assert.isTrue(
                thrownException instanceof DataCloudQueryServiceProvider.DataCloudQueryServiceException,
                'Expected DataCloudQueryServiceException'
        );
        Assert.isTrue(
                thrownException.getMessage().contains('Named credential default setting is required'),
                'Wrong exception message'
        );
    }

    @IsTest
    static void givenRestSetting_whenRestServiceMissing_thenReturnsNull() {
        // Given
        DataCloudQueryServiceProvider.defaultSettings = createMdtSetting(false, null, 'TestDS', 'TestWL');
        initializeAdapterMock(true, false);

        // When
        Test.startTest();
        DataCloudQueryServiceProvider.IDataCloudQueryProvider provider = DataCloudQueryServiceProvider.getInstance(createQuerySetting(true, 'QueryNC'));
        Test.stopTest();

        // Then
        Assert.areEqual(null, provider, 'Expected no service when rest service is not installed');
    }
}