import submitDataCloudQuery from '@salesforce/apex/DataCloudQueryServiceController.submitDataCloudQuery';
import getDataCloudQueryStatus from '@salesforce/apex/DataCloudQueryServiceController.getDataCloudQueryStatus';
import getDataCloudQueryData from '@salesforce/apex/DataCloudQueryServiceController.getDataCloudQueryData';
import getRecordData from '@salesforce/apex/DataCloudQueryServiceController.getRecordData';
import getDataCloudRecordLocalSalesforceId from '@salesforce/apex/DataCloudQueryServiceController.getDataCloudRecordLocalId';


const DEFAULT_PAGE_SIZE=20;

 async function executeDataCloudQuery(querySettingId,recordId,pageSize){

        try{

            // Step 1: Submit the query and get the job ID
            let queryResult = await submitDataCloudQuery({
                querySettingId:querySettingId,
                recordId:recordId
                });
            console.log('query Submit Result:', queryResult);

            const queryId = queryResult.queryId;
            console.log(queryId)

            if(!queryResult.isCompleted){
              // Step 2: Poll for job status until it's completed
                let status;
                do {
                    await delay(500); // Wait for 500 milli seconds before polling again
                    queryResult = await getDataCloudQueryStatus({
                        querySettingId:querySettingId,
                        queryId:queryId});
                    console.log('Current Status:', queryResult);
                } while (!queryResult.isCompleted);
            }

            const totalRowCount = queryResult.rowCount;
            console.log(totalRowCount)

            //Query processing is completed - Get the result now

            queryResult = await getDataCloudQueryResultData(querySettingId,queryId,0,pageSize??DEFAULT_PAGE_SIZE);

             const records = queryResult.records;

            return {queryId,totalRowCount,records};

        } catch (error) {
            console.error('Error executing Data Cloud query:', error);
            throw error;
        }
    }


     async function getDataCloudQueryResultData(querySettingId,queryId,rowOffset,rowCount){
        try{
            let queryResult = await getDataCloudQueryData({
                            querySettingId:querySettingId,
                            queryId:queryId,
                            rowStart:rowOffset,
                            rowCount: rowCount
                            });
             console.log('Query Page Result:', queryResult);
            return queryResult;
        }catch(error){
             console.error('Error fetching data cloud query result Data:', error);
             throw error;
        }
    }

     async function getDataCloudRecordLocalId(recordId,objectName){
        console.log('getting local id', recordId,objectName);
        return await getDataCloudRecordLocalSalesforceId({recordId,objectName});
    }

      function formatString(formatString, ...values){
          // The regular expression /\{(\d+)\}/g looks for:
            // \{  - a literal opening curly brace
            // (\d+) - one or more digits (captured as a group)
            // \}  - a literal closing curly brace
            // g   - the "global" flag, to replace all matches, not just the first one
            return formatString.replace(/\{(\d+)\}/g, (match, index) => {
              // 'match' is the full string found (e.g., "{0}")
              // 'index' is the captured group (e.g., "0")

              // Get the value from the 'values' array at that index
              const value = values[index];

              // If a value exists for that index (even 0, false, or null), return it.
              // Otherwise (if the value is undefined), return the original placeholder.
              return typeof value !== 'undefined' ? value : match;
            });
      }

    function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

export { executeDataCloudQuery,
    getDataCloudQueryResultData,
    getDataCloudRecordLocalId,
    formatString,
    delay
    }