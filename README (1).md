# Online Retail II: monthly revenue in PostgreSQL

A PostgreSQL project that takes a messy two-year sales export from raw rows to a reconciled revenue figure.

**Result:** store revenue of **£18,885,984.99** from 1 Dec 2009 to 9 Dec 2011, net of VAT, reconciled to every row of the cleaned table.

## Question and data

This project uses Online Retail II (UCI): 1,067,371 transaction lines from one UK-based, online-only retailer that mainly sells gift items, covering 1 Dec 2009 to 9 Dec 2011.

The goal is monthly revenue that can be trusted. A plain `SUM(price * quantity)` over the raw data would be wrong for two reasons:

- The two source files overlap on 1–9 Dec 2010, so those days would be counted twice.
- Not every line is a sale. Some are service lines, such as postage and bank charges.

## Data issues

Counts are from the raw table, before cleaning.

| # | Issue | Size | Effect on revenue |
|---|---|---|---|
| F1 | Missing `customer_id` | 243,007 rows | None: revenue doesn't need the customer |
| F2 | Missing `description` | 4,382 rows | None: revenue uses price and quantity |
| F3 | Stock codes with several descriptions | 1,232 codes | None on the total; group products by `stock_code`, not `description` |
| F4 | Cancellations (invoice starts with `C`) | 19,494 rows, 8,292 invoices | Yes: ignoring them overstates revenue |
| F5 | Warehouse adjustments (no customer, price 0) | 6,131 rows | None: price 0 adds nothing |
| F6 | Full-row duplicates | 34,335 extra copies (3.22%) | Partly: 22,523 come from the file overlap and inflate revenue; the other 11,812 were already repeated in the source and may be real purchases |

## Revenue rules

| Line type | In store revenue? | Why |
|---|---|---|
| Product sales | Yes | Money received for goods |
| Product cancellations | Yes, as a minus | Money returned to customers |
| Discounts (`D`) | Yes, as a minus | Customers paid less |
| Manual corrections (`M`) | Yes | Includes product cancellations; mixed code, so it can't be tied to products |
| Gift vouchers | Yes, as a separate group | Customers pay for them |
| Postage, carriage, fees, samples and other service lines | No | Not payment for goods |
| Bad-debt write-offs (`A` invoices, code `B`) | No | Accounting entry, not a sale or a return |
| Sheet 1 copy of 1–9 Dec 2010 | No | Exact copy of rows in sheet 2 |
| Duplicates already in the source | Yes | May be real repeat purchases |

Product revenue counts only product sales and cancellations.

## Results

Revenue is seasonal. It rises from September to a November peak, about 2.2–2.3 times the January–August average, then falls in December and again in January and February. It recovers in March and mostly stays around £600–700K until August. April 2011 is the main exception, at about £482K.

| Month | Product revenue (GBP) | Store revenue (GBP) |
|---|---:|---:|
| 2009-12 | 781,378.55 | 778,636.91 |
| 2010-01 | 606,358.96 | 603,466.51 |
| 2010-02 | 527,144.16 | 524,249.08 |
| 2010-03 | 754,636.29 | 753,929.54 |
| 2010-04 | 638,860.81 | 637,088.95 |
| 2010-05 | 608,333.50 | 608,112.48 |
| 2010-06 | 672,828.29 | 672,625.07 |
| 2010-07 | 617,753.45 | 609,843.88 |
| 2010-08 | 663,641.22 | 666,730.51 |
| 2010-09 | 844,081.69 | 843,533.24 |
| 2010-10 | 1,072,389.35 | 1,071,345.66 |
| 2010-11 | 1,400,411.93 | 1,397,797.33 |
| 2010-12 | 760,257.78 | 759,586.48 |
| 2011-01 | 580,388.64 | 575,308.48 |
| 2011-02 | 500,493.88 | 497,341.29 |
| 2011-03 | 680,457.29 | 676,844.87 |
| 2011-04 | 482,878.00 | 482,422.84 |
| 2011-05 | 732,205.53 | 721,616.08 |
| 2011-06 | 724,991.03 | 685,313.02 |
| 2011-07 | 677,880.65 | 673,608.29 |
| 2011-08 | 702,564.24 | 698,849.20 |
| 2011-09 | 1,013,424.10 | 1,012,466.14 |
| 2011-10 | 1,062,674.37 | 1,061,573.39 |
| 2011-11 | 1,432,731.70 | 1,432,320.11 |
| 2011-12 (to Dec 9, partial) | 441,363.22 | 441,375.64 |

## Reconciliation

Every row in `retail_clean` falls into exactly one group, and the groups add up to the table total.

| Group | Rows | Sum (GBP) |
|---|---:|---:|
| Product sales | 1,020,883 | 19,699,784.97 |
| Product cancellations | 17,973 | -719,656.34 |
| Manual corrections (`M`) | 1,398 | -82,950.62 |
| Discounts (`D`) | 173 | -12,879.63 |
| Gift vouchers | 100 | 1,686.61 |
| Excluded service lines | 4,321 | 23,777.13 |
| **Total** | **1,044,848** | **18,909,762.12** |

Store revenue is the total minus excluded service lines: **£18,885,984.99**.

Checks:

- Raw row count matches UCI: 525,461 + 541,910 = 1,067,371.
- Rows after removing the overlap: 1,067,371 − 22,523 = 1,044,848.
- Group totals match `SELECT COUNT(*), SUM(price * quantity) FROM retail_clean`.
- Monthly store revenue adds up to the same £18,885,984.99.

## Limitations

- Profit can't be calculated because the data has no costs.
- The 11,812 repeated source rows are kept. The data alone can't show whether they are real purchases or double entries.
- `M` mixes different kinds of manual corrections, so revenue by product would need it as a separate line.

## Files

Run the files in this order:

| File | Purpose |
|---|---|
| `01_load.sql` | Creates `retail_raw` and loads the two CSV files as text |
| `02_explore.sql` | Profiles the raw data and documents findings F1–F6 |
| `02b_reload.sql` | Reloads the data with a source-file marker and proves the overlap is an exact copy |
| `03_clean.sql` | Checks each column, records the revenue decisions and builds `retail_clean` |
| `04_revenue.sql` | Reconciles all rows and calculates monthly revenue |

## Data source

[Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii), UCI Machine Learning Repository, licensed under CC BY 4.0. The raw data isn't included here. To reproduce the project, download it, save each sheet as a CSV file and update the paths in the `\copy` commands.
