## Business Analytics — Eight Questions and Answers

These results were obtained by running `08_Business_Analytics_Queries.sql` in SQL Server Management Studio on 19 November 2026. Questions 1–7 use the Gold warehouse; Q8 uses Silver order data for delivery dates. Monetary values are in Brazilian reais (BRL). Item value is the sum of recorded item prices, excluding freight; it is not net revenue or profit. Order counts in the sales analysis refer to orders with recorded items, not necessarily delivered orders.

### Q01. What are the total sales value, order volume and average order value?

| Metric | Result |
|---|---:|
| Orders with items | 98,666 |
| Order items | 112,650 |
| Total item value (BRL) | 13,591,643.70 |
| Total freight (BRL) | 2,251,909.54 |
| Average order value excluding freight (BRL) | 137.75 |

**Insight:** The marketplace recorded more than BRL 13.59 million in item value. The average order value provides a baseline for evaluating basket-size and cross-selling initiatives.

### Q02. How does sales performance change month by month?

Monthly item value generally increased during 2017, rising from BRL 120,312.87 in January to a dataset peak of BRL 1,010,271.37 in November. November 2017 also recorded 7,451 orders with items, the highest monthly order count in the results. Sales remained comparatively strong during the first half of 2018.

| Purchase month | Orders with items | Item value (BRL) |
|---|---:|---:|
| January 2017 | 789 | 120,312.87 |
| October 2017 | 4,568 | 664,219.43 |
| November 2017 | 7,451 | 1,010,271.37 |
| December 2017 | 5,624 | 743,914.17 |
| January 2018 | 7,220 | 950,030.36 |
| March 2018 | 7,188 | 983,213.44 |
| April 2018 | 6,934 | 996,647.75 |
| May 2018 | 6,853 | 996,517.68 |
| August 2018 | 6,452 | 854,686.33 |

**Insight:** The November peak suggests a period worth investigating for promotional and seasonal demand planning. The query does not establish the cause of that peak. The selected months above summarize the trend; the SQL returns the full observed monthly series. Sparse months at the dataset boundaries should not be interpreted as normal full-month performance.

### Q03. Which ten product categories generate the highest sales value?

| Rank | Product category (source label) | Order items | Item value (BRL) |
|---:|---|---:|---:|
| 1 | beleza_saude | 9,670 | 1,258,681.34 |
| 2 | relogios_presentes | 5,991 | 1,205,005.68 |
| 3 | cama_mesa_banho | 11,115 | 1,036,988.68 |
| 4 | esporte_lazer | 8,641 | 988,048.97 |
| 5 | informatica_acess... | 7,827 | 911,954.32 |
| 6 | moveis_decoracao | 8,334 | 729,762.49 |
| 7 | cool_stuff | 3,796 | 635,290.85 |
| 8 | utilidades_domest... | 6,964 | 632,248.66 |
| 9 | automotivo | 4,235 | 592,720.11 |
| 10 | ferramentas_jardim | 4,347 | 485,256.46 |

*Two source labels are shortened as displayed in the SSMS screenshot.*

**Insight:** Health and beauty generated the highest item value, followed by watches and gifts. Bed, table and bath products recorded the largest number of items among these ten categories. The difference between item-value and volume rankings highlights the need to monitor both metrics when planning inventory and promotions.

### Q04. Which ten sellers generate the highest sales value?

| Rank | Seller ID | State | Orders with seller | Item value (BRL) |
|---:|---|---|---:|---:|
| 1 | `4869f7a5dfa277a7dca6462dcf3b52b2` | SP | 1,132 | 229,472.63 |
| 2 | `53243585a1d6dc2643021fd1853d8905` | BA | 358 | 222,776.05 |
| 3 | `4a3ca9315b744ce9f8e9374361493884` | SP | 1,806 | 200,472.92 |
| 4 | `fa1c13f2614d7b5c4749cbc52fecda94` | SP | 585 | 194,042.03 |
| 5 | `7c67e1448b00f6e969d365cea6b010ab` | SP | 982 | 187,923.89 |
| 6 | `7e93a43ef30c4f03f38b393420bc753a` | SP | 336 | 176,431.87 |
| 7 | `da8622b14eb17ae2831f4ac5b9dab84a` | SP | 1,314 | 160,236.57 |
| 8 | `7a67c85e85bb2ce8582c35f2203ad736` | SP | 1,160 | 141,745.53 |
| 9 | `1025f0e2d44d7041d6cf58b6550e0bfa` | SP | 915 | 138,968.55 |
| 10 | `955fee9216a65b617aa5c0531780ce60` | SP | 1,287 | 135,171.70 |

**Insight:** Nine of the ten highest-value sellers are located in São Paulo (SP). This concentration suggests opportunities to strengthen seller partnerships in that state while investigating seller development in other regions. These are item-value rankings, not seller profitability rankings.

### Q05. Which customer states generate the most orders?

| Rank | State | Distinct customers | Orders with items | Item value (BRL) |
|---:|---|---:|---:|---:|
| 1 | SP | 39,981 | 41,375 | 5,202,955.05 |
| 2 | RJ | 12,303 | 12,762 | 1,824,092.67 |
| 3 | MG | 11,178 | 11,544 | 1,585,308.03 |
| 4 | RS | 5,249 | 5,432 | 750,304.02 |
| 5 | PR | 4,840 | 4,998 | 683,083.76 |
| 6 | SC | 3,513 | 3,612 | 520,553.34 |
| 7 | BA | 3,257 | 3,358 | 511,349.99 |
| 8 | DF | 2,062 | 2,125 | 302,603.94 |
| 9 | ES | 1,956 | 2,025 | 275,037.31 |
| 10 | GO | 1,942 | 2,007 | 294,591.95 |

**Insight:** São Paulo leads demand, followed by Rio de Janeiro (RJ) and Minas Gerais (MG). These markets are useful starting points for regional marketing and fulfillment capacity planning.

### Q06. Which payment methods are most frequently used?

| Payment method | Payment records | Share of payment records | Orders using method | Payment value (BRL) |
|---|---:|---:|---:|---:|
| credit_card | 76,795 | 73.92% | 76,505 | 12,542,084.19 |
| boleto | 19,784 | 19.04% | 19,784 | 2,869,361.27 |
| voucher | 5,775 | 5.56% | 3,866 | 379,436.87 |
| debit_card | 1,529 | 1.47% | 1,528 | 217,989.79 |
| not_defined | 3 | 0.00% | 3 | 0.00 |

**Insight:** Credit card is the dominant payment method, with boleto (a Brazilian payment slip) a significant second choice. Maintaining reliable processing for both methods is important. Percentages refer to payment records, not unique orders; one order can use multiple methods. Percentages are rounded.

### Q07. What percentage of purchasing customers place repeat orders?

| Metric | Result |
|---|---:|
| Purchasing customers | 95,420 |
| Single-order customers | 92,507 |
| Repeat customers | 2,913 |
| Repeat customer rate | 3.05% |

**Insight:** Repeat purchasing is limited within the observed dataset. Loyalty campaigns, post-purchase engagement and customer retention analysis are potential opportunities. This rate measures repeat ordering within the observed period, not lifetime retention.

### Q08. What percentage of delivered orders arrive on time, and what is the average delivery time?

| Metric | Result |
|---|---:|
| Orders with delivered status | 96,478 |
| Eligible orders included | 96,470 |
| Excluded orders | 8 |
| On-time orders | 89,936 |
| Late orders | 6,534 |
| On-time delivery rate | 93.23% |
| Average delivery time (days) | 12.56 |

**Insight:** Most eligible delivered orders arrived on time, but 6,534 were late. Further analysis by seller, destination and shipment characteristics could help identify logistics improvement opportunities. The calculation excludes eight delivered-status orders that did not meet the query's eligibility criteria.

### Business recommendations

Prioritize high-demand regions and product categories, prepare operational capacity for peak demand, maintain reliable credit card and boleto payment processing, investigate repeat-purchase opportunities, and analyze the causes of late deliveries. These are recommendations based on descriptive historical results, not proven causal relationships.
