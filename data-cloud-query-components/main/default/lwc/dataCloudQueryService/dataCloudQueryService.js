import submitDataCloudQuery from "@salesforce/apex/DataCloudQueryServiceController.submitDataCloudQuery";
import getDataCloudQueryStatus from "@salesforce/apex/DataCloudQueryServiceController.getDataCloudQueryStatus";
import getDataCloudQueryData from "@salesforce/apex/DataCloudQueryServiceController.getDataCloudQueryData";
import resolveRecordNavigationApex from "@salesforce/apex/DataCloudQueryServiceController.resolveRecordNavigation";

const DEFAULT_PAGE_SIZE = 20;
const MAX_WAIT_FOR_FINISH_STATUS = 90000; //in millisecond
const WAIT_LOOP_DELAY = 500; // in millisecond
const MAX_LOOP_COUNT = MAX_WAIT_FOR_FINISH_STATUS / WAIT_LOOP_DELAY;
async function executeDataCloudQuery(querySettingId, recordId, pageSize) {
  try {
    // Step 1: Submit the query and get the job ID
    let queryResult = await submitDataCloudQuery({
      querySettingId: querySettingId,
      recordId: recordId,
    });

    const queryId = queryResult.queryId;

    if (!queryResult.isCompleted) {
      let loopCounter = 0;
      do {
        loopCounter++;

        await delay(WAIT_LOOP_DELAY);
        queryResult = await getDataCloudQueryStatus({
          querySettingId: querySettingId,
          queryId: queryId,
        });

        if (loopCounter >= MAX_LOOP_COUNT) {
          throw new Error(
            "Fetching query status is timeout, please click on refresh",
          );
        }
      } while (!queryResult.isCompleted);
    }
    const totalRowCount = queryResult.rowCount;
    //Query processing is completed - Get the result now
    queryResult = await getDataCloudQueryResultData(
      querySettingId,
      queryId,
      0,
      pageSize ?? DEFAULT_PAGE_SIZE,
    );

    const records = queryResult.records;

    return { queryId, totalRowCount, records };
  } catch (error) {
    console.error("Error executing Data Cloud query:", error);
    throw error;
  }
}

async function getDataCloudQueryResultData(
  querySettingId,
  queryId,
  rowOffset,
  rowCount,
) {
  try {
    let queryResult = await getDataCloudQueryData({
      querySettingId: querySettingId,
      queryId: queryId,
      rowStart: rowOffset,
      rowCount: rowCount,
    });

    return queryResult;
  } catch (error) {
    console.error("Error fetching data cloud query result Data:", error);
    throw error;
  }
}

async function resolveRecordNavigation(recordId, data360ObjectName) {
  return await resolveRecordNavigationApex({ recordId, data360ObjectName });
}

function formatString(formatString, ...values) {
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
    return typeof value !== "undefined" ? value : match;
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Resolve the recordId from query parameter if component is not placed on record page in this case salesforce will not inject the recordId
 * @param apiRecordId - recordId injected by salesforce
 * @param pageReference - current page reference object
 * @returns {*|null}
 */
function resolveRecordId(apiRecordId, pageReference) {
  if (apiRecordId) return apiRecordId;
  return pageReference?.state?.c__recordId || null;
}

class PageRefTracker {
  _resolve;
  _lastLoadedRecordId;
  ready;

  constructor() {
    this.ready = new Promise(resolve => { this._resolve = resolve; });
  }

  update(pageRef, apiRecordId, onRecordChange) {
    if (pageRef) {
      this._resolve(pageRef);
      const currentId = resolveRecordId(apiRecordId, pageRef);
      if (this._lastLoadedRecordId && currentId !== this._lastLoadedRecordId) {
        onRecordChange();
      }
    }
  }

  resolve(apiRecordId, pageRef) {
    const id = resolveRecordId(apiRecordId, pageRef);
    this._lastLoadedRecordId = id;
    return id;
  }
}

export {
  executeDataCloudQuery,
  getDataCloudQueryResultData,
  resolveRecordNavigation,
  formatString,
  delay,
  resolveRecordId,
  PageRefTracker
};
