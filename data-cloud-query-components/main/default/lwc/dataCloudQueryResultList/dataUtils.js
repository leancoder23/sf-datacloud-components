/**
 * Pure, stateless utility functions for the dataCloudQueryResultList component.
 * No LWC dependency — independently testable.
 */

// =======================================================================
//  PAGINATION
// =======================================================================

function computeTotalPages(totalRecords, pageSize) {
  if (!totalRecords || !pageSize) return 0;
  return Math.ceil(totalRecords / pageSize);
}

function getPageBounds(pageNumber, pageSize, totalRecords) {
  const start = (pageNumber - 1) * pageSize;
  const end = Math.min(start + pageSize, totalRecords);
  return { start, end, startRecord: end?start + 1:end, endRecord: end };
}

function getPageSlice(data, pageNumber, pageSize) {
  if (!data || !data.length) return [];
  const startIndex = (pageNumber - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  return data.slice(startIndex, endIndex);
}

// =======================================================================
//  SEARCH / FILTER
// =======================================================================

/**
 * Filters data rows by matching a search key against filterable column values.
 * @param {Array} data - The dataset to filter.
 * @param {string} searchKey - Already-lowercased search term.
 * @param {Array} filterableColumns - Column configs with filterable === true.
 * @returns {Array} Filtered subset of data.
 */
function filterByColumns(data, searchKey, filterableColumns) {
  if (!searchKey || !filterableColumns.length) return data;

  return data.filter((row) =>
    filterableColumns.some((col) => {
      const field = col.sortFilterField || col.fieldName;
      const value = row[field];
      return (value ? String(value).toLowerCase() : "").includes(searchKey);
    })
  );
}

// =======================================================================
//  SORT
// =======================================================================

/**
 * Returns a new sorted copy of the data array.
 * Supports type-aware sorting (number, date, text) and custom sort fields.
 * @param {Array} data - Source dataset (not mutated).
 * @param {string} fieldName - The datatable column fieldName to sort by.
 * @param {string} direction - 'asc' or 'desc'.
 * @param {Object} columnConfig - Column config object; may contain sortFilterField and type.
 * @returns {Array} A new sorted array.
 */
function sortData(data, fieldName, direction, columnConfig = {}) {
  const sorted = [...data];
  const sortField = columnConfig.sortFilterField || fieldName;
  const sortType = columnConfig.type || "auto";
  const isReverse = direction === "asc" ? 1 : -1;

  sorted.sort((a, b) => {
    let x = a[sortField] ?? "";
    let y = b[sortField] ?? "";

    if (sortType === "number") {
      x = parseFloat(x) || 0;
      y = parseFloat(y) || 0;
    } else if (sortType === "date") {
      x = new Date(x).getTime() || 0;
      y = new Date(y).getTime() || 0;
    } else {
      x = String(x).toLowerCase();
      y = String(y).toLowerCase();
    }

    return isReverse * ((x > y) - (y > x));
  });

  return sorted;
}

// =======================================================================
//  DATA TRANSFORMATION
// =======================================================================

/**
 * Adds _key and _row metadata to each record for lightning-datatable.
 * @param {Array} records - Raw records from server.
 * @param {number} startIndex - Starting index for key generation.
 * @returns {Array} Records with _key and _row appended.
 */
function addKeyToData(records, startIndex = 0) {
  return records.map((record, index) => ({
    ...record,
    _key: `row-${startIndex + index}`,
    _row: record,
  }));
}

// =======================================================================
//  GENERAL UTILITIES
// =======================================================================

/**
 * Returns a debounced version of the given function.
 * Calling wrapper.cancel() clears a pending timer.
 * @param {Function} fn - The function to debounce.
 * @param {number} delay - Milliseconds to wait (default 300).
 * @returns {Function} Debounced wrapper with a .cancel() method.
 */
function debounce(fn, delay = 300) {
  let timeoutId;

  function wrapper(...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn.apply(this, args), delay);
  }

  wrapper.cancel = () => clearTimeout(timeoutId);

  return wrapper;
}

export {
  computeTotalPages, getPageBounds, getPageSlice,
  filterByColumns, sortData, addKeyToData, debounce,
};
