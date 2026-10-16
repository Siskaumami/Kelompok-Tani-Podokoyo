# Reporting and history

`buildReport` is the only calculation engine. The screen endpoint and PDF endpoint both call it; `reportPdf` only formats the returned object. It does not fetch current product prices or compute another financial model.

Reports read sale headers and aggregated snapshot lines in **one SQL statement**, so concurrent voids/entries cannot produce a half-old header/half-new line view. Organization name/timezone are metadata read separately. Sale count, Grade A and finished gross, gross revenue, discount, marketplace fees, net revenue, HPP and estimated gross profit are accumulated with BigInt from stored transaction amounts. COMPLETED contributes; VOIDED remains in supporting detail but contributes zero.

Default period is today in the organization's timezone. UI offers today/current month/current year and editable from/to dates for a chosen past month/year or arbitrary interval. Boundaries are inclusive ISO business dates; filtering does not reinterpret business dates as UTC timestamps. The API allows up to 367 inclusive days and caps a result at 5,000 transactions, returning a clear request-range error rather than silently truncating financial totals.

PDF includes organization, period, business timezone, generation timestamp, generated-by name, totals, transaction IDs, channels, statuses, snapshot lines and cancellation reason. A no-data PDF says so and contains accurate zero totals. A very large report should be split into shorter periods.

Historical reports remain independent of current master descriptions/prices/HPP. A full void restates the original transaction-date period. This is intentional operational reporting; there are no immutable closed fiscal periods or automatic double-entry journal. A physical inventory adjustment is not automatically a financial loss. A discounted sale's net/HPP may yield negative gross profit and is displayed honestly.

V1 does not model cash settlement timing, receivables, partial returns, taxes, payroll or whole-business net profit. Do not label the report a full financial statement. Future accounting modules should consume business events without rewriting sale-line snapshots.

PDF additionally limits rendered transaction-detail lines to 5,000, returning PDF_TOO_LARGE and asking for a shorter period. This is an export resource limit; financial calculations remain shared with JSON.
