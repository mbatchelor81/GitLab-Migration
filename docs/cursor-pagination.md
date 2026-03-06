# Cursor-Based Pagination

This feature adds cursor-based pagination alongside existing offset pagination.

## New Classes
- `CursorPageParameter` - holds cursor, limit, direction (NEXT/PREV)
- `CursorPager<T>` - wraps results with hasNext/hasPrevious flags
- `Node` interface - data objects implement `getPageCursor()`

## Usage
Pass `cursor` and `direction` query parameters instead of `offset`/`limit`.

## GraphQL
The GraphQL API uses cursor pagination by default via Relay-style connections.
