# API Optimization Summary

This document summarizes the optimizations implemented to reduce redundant API calls when adding new transactions.

## Issues Identified

From the API logs, the following performance issues were identified:
1. Multiple redundant API calls to `/api/account-groups` (3 calls)
2. Multiple redundant API calls to `/api/transactions` with the same date range (3 calls)
3. High compilation times on initial requests (over 1100ms)

## Optimizations Implemented

### 1. Caching Mechanism
- Created `CacheService` class to store API responses for 5 minutes by default
- Added caching support to `ApiClient.get()` method
- Updated all service classes to support caching:
  - `AccountGroupService.fetchAccountGroups()`
  - `TransactionService.fetchTransactions()`
  - `TransactionService.fetchTransactionsForAccount()`
  - `TransactionService.fetchTransactionsForAccountWithDateRange()`
  - `CategoryService.fetchCategories()`

### 2. Request Deduplication
- Added in-flight request tracking to prevent duplicate identical requests
- If the same request is already in progress, the existing promise is returned
- This prevents multiple components from making the same API call simultaneously

### 3. Debounced Refresh Notifications
- Updated `RefreshNotifier` with debouncing (300ms delay)
- Multiple rapid refresh calls are now consolidated into a single notification
- Added `notifyImmediately()` method for cases where immediate refresh is needed

### 4. Selective Cache Invalidation
- Cache is automatically invalidated after successful POST/PUT/DELETE operations
- Added methods to clear specific endpoint caches or all caches
- Transaction creation/deletion now clears only transaction-related caches

### 5. Smart Cache Usage
- Initial data loads use cache (`useCache: true`)
- Explicit refresh operations bypass cache (`useCache: false`)
- This ensures fresh data when user explicitly requests it while still benefiting from caching

## Expected Performance Improvements

1. **Reduced API Calls**: Eliminated redundant calls by serving cached responses
2. **Faster Initial Load**: Cached responses eliminate compilation time on subsequent loads
3. **Reduced Network Traffic**: Less data transferred due to caching
4. **Better User Experience**: Faster UI updates with less loading time

## Files Modified

1. `lib/services/cache_service.dart` - New file for caching functionality
2. `lib/services/api_client.dart` - Added caching and request deduplication
3. `lib/utils/refresh_notifier.dart` - Added debouncing to refresh notifications
4. `lib/services/account_group_service.dart` - Added cache support
5. `lib/services/transaction_service.dart` - Added cache support
6. `lib/services/category_service.dart` - Added cache support
7. `lib/pages/transaction_detail_page.dart` - Updated to use cache and selective invalidation
8. `lib/widgets/accounts_view.dart` - Updated to use cache
9. `lib/widgets/transactions_table.dart` - Updated to use cache
10. `lib/pages/account_form_page.dart` - Updated to use cache

## Usage Guidelines

- For data that changes frequently (transactions), cache is used but invalidated after modifications
- For relatively static data (categories, account groups), cache is used for longer periods
- User-initiated refresh operations always bypass cache to ensure fresh data
- Cache automatically expires after 5 minutes to prevent stale data