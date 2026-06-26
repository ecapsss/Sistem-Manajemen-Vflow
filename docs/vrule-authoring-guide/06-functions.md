# 06 - Functions

VDICL has a builtin function registry. Function names are written as
ordinary calls in expressions:

```yaml
when: COALESCE(monthlyIncome, 0) >= 5000000
when: STARTS_WITH(accountNumber, "ID")
expr: ROUND(monthlyIncome * 0.35, 0)
```

The registry also contains internal helper names used by translators
and compatibility tests. Public authored rule packs should use the
functions in this document, not names beginning with `__`.

## General

| Function | Meaning |
|---|---|
| `COALESCE(value, ...)` | First non-null value. |
| `IFNULL(value, fallback)` | Fallback when value is null. |
| `UUID()` | Runtime UUID value. |

## String

| Function | Meaning |
|---|---|
| `UPPER(text)` | Uppercase text. |
| `LOWER(text)` | Lowercase text. |
| `LENGTH(text)`, `LEN(text)` | Character count. |
| `TRIM(text)` | Trim leading/trailing whitespace. |
| `SUBSTR(text, start, len)` | Substring. |
| `CONCAT(value, ...)` | Concatenate values. |
| `CONTAINS(text, needle)` | Text contains needle. |
| `STARTS_WITH(text, prefix)` | Text starts with prefix. |
| `ENDS_WITH(text, suffix)` | Text ends with suffix. |
| `MATCHES_REGEX(text, pattern)` | Regex match. |
| `REPLACE(text, from, to)` | Replace text. |
| `REPLACE_FLAGS(text, pattern, replacement, flags)` | Regex replace with flags. |
| `SPLIT(text, separator)` | Split text. |
| `STRING(value)` | Convert value to string. |
| `STRING_JOIN(list, separator)` | Join list items. |
| `SUBSTRING_BEFORE(text, marker)` | Text before marker. |
| `SUBSTRING_AFTER(text, marker)` | Text after marker. |
| `TO_BASE64(value)` | Base64 encode. |
| `FROM_BASE64(value)` | Base64 decode. |
| `TO_HEX(value)` | Hex encode. |
| `NUMBER_FROM_STRING(text)` | Parse numeric text. |

## Numeric

| Function | Meaning |
|---|---|
| `ABS(number)` | Absolute value. |
| `ROUND(number, scale)` | Round number. |
| `ROUND_UP(number, scale)` | Round away from zero. |
| `ROUND_DOWN(number, scale)` | Round toward zero. |
| `ROUND_HALF_UP(number, scale)` | Round half up. |
| `ROUND_HALF_DOWN(number, scale)` | Round half down. |
| `DECIMAL(number, scale)` | Decimal rounding. |
| `FLOOR(number)` | Floor. |
| `FLOOR_SCALED(number, scale)` | Scaled floor. |
| `CEIL(number)` | Ceiling. |
| `CEILING_SCALED(number, scale)` | Scaled ceiling. |
| `MIN(value, ...)` | Minimum. |
| `MAX(value, ...)` | Maximum. |
| `SUM(list)` | Sum numeric list. |
| `COUNT(list)` | Count items. |
| `SQRT(number)` | Square root. |
| `LOG(number)` | Natural logarithm. |
| `EXP(number)` | Exponential. |
| `ODD(number)` | True when integer is odd. |
| `EVEN(number)` | True when integer is even. |
| `MODULO(dividend, divisor)` | Modulo. |
| `POW(base, exponent)` | Power. |
| `PMT(...)`, `PMT2(...)` | Payment calculation helpers. |

## List

| Function | Meaning |
|---|---|
| `PRODUCT(list)` | Product of numbers. |
| `MEAN(list)` | Mean. |
| `MEDIAN(list)` | Median. |
| `STDDEV(list)` | Sample standard deviation. |
| `MODE(list)` | Most frequent values. |
| `ALL(list)` | Boolean all. |
| `ANY(list)` | Boolean any. |
| `SUBLIST(list, start, len)` | Slice list. |
| `INSERT_BEFORE(list, position, item)` | Insert item. |
| `REMOVE(list, position)` | Remove item. |
| `REVERSE(list)` | Reverse list. |
| `INDEX_OF(list, item)` | Positions of item. |
| `LIST_CONTAINS(list, item)` | Membership test. |
| `APPEND(list, item)` | Append item. |
| `DISTINCT(list)` | Remove duplicates. |
| `FLATTEN(list)` | Flatten nested lists. |
| `SORT(list)` | Sort ascending. |
| `SORT_DESC(list)` | Sort descending. |
| `UNION(list, list)` | Union. |
| `LIST_REPLACE(list, position, item)` | Replace item. |
| `ARR_LEN(list)` | List length. |

## Date, Time, Duration, And Range

| Function | Meaning |
|---|---|
| `DATE(...)` | Build or parse date. |
| `TIME(...)` | Build or parse time. |
| `DATETIME(...)`, `DATE_AND_TIME(...)` | Build or parse datetime. |
| `DURATION(text)` | Parse duration. |
| `YEARS_AND_MONTHS_DURATION(from, to)` | Year-month duration. |
| `DAYS_BETWEEN(from, to)` | Day difference. |
| `YEARS_BETWEEN(from, to)` | Year difference. |
| `MONTHS_BETWEEN(from, to)` | Month difference. |
| `DATE_ADD(date, duration)` | Add date duration. |
| `DATE_FROM_PARTS(year, month, day)` | Build date from parts. |
| `DAY_OF_WEEK(date)` | Day of week. |
| `DAY_OF_YEAR(date)` | Day of year. |
| `WEEK_OF_YEAR(date)` | Week of year. |
| `LAST_DAY_OF_MONTH(date)` | Last day of month. |
| `MONTH_OF_YEAR(date)` | Month number. |
| `MONTH_OF_YEAR_NAME(date)` | Month name. |
| `DAY_OF_WEEK_NAME(date)` | Day name. |
| `IS_WEEKEND(date)` | Weekend check. |
| `RANGE(start, end)` | Range value. |
| `BEFORE`, `AFTER`, `MEETS`, `MET_BY`, `OVERLAPS`, `OVERLAPPED_BY`, `STARTS`, `STARTED_BY`, `DURING`, `INCLUDES`, `FINISHES`, `FINISHED_BY`, `COINCIDES`, `OVERLAPS_BEFORE`, `OVERLAPS_AFTER` | Range relation predicates. |

## JSON And Context

| Function | Meaning |
|---|---|
| `JSON_GET(json, path)` | Read JSON path. |
| `JSON_GET_STR(json, path)` | Read JSON string. |
| `JSON_GET_I64(json, path)` | Read JSON integer. |
| `JSON_GET_F64(json, path)` | Read JSON float. |
| `JSON_GET_BOOL(json, path)` | Read JSON boolean. |
| `TO_JSON(value)` | Convert to JSON. |
| `CONTEXT(key, value, ...)` | Build context. |
| `CONTEXT_PUT(context, key, value)` | Put context field. |
| `CONTEXT_MERGE(context, context)` | Merge contexts. |
| `PUT(context, key, value)` | Put field. |
| `PUT_ALL(context, context)` | Put all fields. |
| `GET_VALUE(context, key)` | Read context value. |
| `GET_ENTRIES(context)` | Context entries. |

## Type Predicates

| Function | Meaning |
|---|---|
| `IS_NUMBER(value)` | Number check. |
| `IS_STRING(value)` | String check. |
| `IS_BOOL(value)` | Boolean check. |
| `IS_LIST(value)` | List check. |
| `IS_OBJECT(value)` | Object/context check. |
| `IS_RANGE(value)` | Range check. |
| `IS_INSTANCE_OF(value, type)` | Instance check. |
| `ISBLANK(value)` | Blank check. |
| `ISEMPTY(value)` | Empty check. |
| `IS_NULL_FN(value)` | Null check. |
