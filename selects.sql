-- =========================================================================
--  ОСНОВНЫЕ ЗАПРОСЫ ДАННЫХ
--
--  Разделы:
--    1. Справочник ставок налога
--    2. Доходы: текущие, по периодам, по типам лиц
--    3. Накопленный налог: по периодам, за год, к уплате
--    4. Журнал изменений доходов
--    5. Журнал изменений налогов
--    6. Аналитические и сводные запросы
--    7. Проверочные и диагностические запросы
-- =========================================================================


-- =========================================================================
-- 1. СПРАВОЧНИК СТАВОК НАЛОГА
-- =========================================================================

-- 1.1. Все ставки налога по типам лиц
SELECT person_type,
       valid_from,
       valid_to,
       rate
FROM table_tax_rates
ORDER BY person_type, valid_from;

-- 1.2. Действующие ставки на текущую дату
SELECT person_type,
       valid_from,
       valid_to,
       rate
FROM table_tax_rates
WHERE CURRENT_DATE >= valid_from
  AND (valid_to IS NULL OR CURRENT_DATE < valid_to)
ORDER BY person_type;


-- =========================================================================
-- 2. ДОХОДЫ
-- =========================================================================

-- 2.1. Все доходы, отсортированные по дате
SELECT id,
       date,
       person_type,
       income,
       is_deleted
FROM table_income
ORDER BY date, id;

-- 2.2. Только активные доходы (не помеченные как удалённые)
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
ORDER BY date, id;

-- 2.3. Доходы за конкретный месяц
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
  AND date >= DATE '2024-01-01'
  AND date < DATE '2024-02-01'
ORDER BY date, id;

-- 2.4. Доходы за конкретный год
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
  AND EXTRACT(YEAR FROM date)::INT = 2024
ORDER BY date, id;

-- 2.5. Доходы физического лица
SELECT id,
       date,
       income
FROM table_income
WHERE person_type = 'ФЛ'
  AND is_deleted = FALSE
ORDER BY date, id;

-- 2.6. Доходы юридического лица
SELECT id,
       date,
       income
FROM table_income
WHERE person_type = 'ЮЛ'
  AND is_deleted = FALSE
ORDER BY date, id;

-- 2.7. Удалённые доходы (помеченные как удалённые)
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = TRUE
ORDER BY date, id;

-- 2.8. Доходы за произвольный диапазон дат
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
  AND date BETWEEN DATE '2024-01-01' AND DATE '2024-03-31'
ORDER BY date, id;

-- 2.9. Доходы с суммой выше заданного порога
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
  AND income > 5000
ORDER BY income DESC, date;


-- =========================================================================
-- 3. НАКОПЛЕННЫЙ НАЛОГ
-- =========================================================================

-- 3.1. Все накопленные налоги по периодам
SELECT year,
       month,
       tax,
       is_paid,
       paid_at
FROM table_taxes
ORDER BY year, month;

-- 3.2. Налоги за конкретный год
SELECT month,
       tax,
       is_paid,
       paid_at
FROM table_taxes
WHERE year = 2024
ORDER BY month;

-- 3.3. Налог за конкретный период
SELECT year,
       month,
       tax,
       is_paid,
       paid_at
FROM table_taxes
WHERE year = 2024
  AND month = 1;

-- 3.4. Неуплаченные налоги (к уплате)
SELECT year,
       month,
       tax
FROM table_taxes
WHERE is_paid = FALSE
  AND tax <> 0
ORDER BY year, month;

-- 3.5. Уплаченные налоги
SELECT year,
       month,
       tax,
       paid_at
FROM table_taxes
WHERE is_paid = TRUE
ORDER BY year, month;

-- 3.6. Итоговая сумма налога за год
SELECT year,
       SUM(tax) AS total_tax
FROM table_taxes
WHERE year = 2024
GROUP BY year;

-- 3.7. Итоговая сумма неуплаченного налога
SELECT SUM(tax) AS unpaid_tax
FROM table_taxes
WHERE is_paid = FALSE
  AND tax <> 0;

-- 3.8. Периоды с переплатой (отрицательное значение налога)
SELECT year,
       month,
       tax
FROM table_taxes
WHERE tax < 0
ORDER BY year, month;


-- =========================================================================
-- 4. ЖУРНАЛ ИЗМЕНЕНИЙ ДОХОДОВ
-- =========================================================================

-- 4.1. Все изменения доходов, начиная с последних
SELECT id,
       income_id,
       operation,
       changed_at,
       old_row,
       new_row
FROM table_income_history
ORDER BY changed_at DESC, id DESC;

-- 4.2. История изменений конкретной записи о доходе
SELECT id,
       operation,
       changed_at,
       old_row,
       new_row
FROM table_income_history
WHERE income_id = 1
ORDER BY changed_at, id;

-- 4.3. Только вставки доходов
SELECT id,
       income_id,
       changed_at,
       new_row
FROM table_income_history
WHERE operation = 'I'
ORDER BY changed_at, id;

-- 4.4. Только обновления доходов
SELECT id,
       income_id,
       changed_at,
       old_row,
       new_row
FROM table_income_history
WHERE operation = 'U'
ORDER BY changed_at, id;

-- 4.5. Изменения за конкретный день
SELECT id,
       income_id,
       operation,
       changed_at,
       old_row,
       new_row
FROM table_income_history
WHERE changed_at >= DATE '2024-01-01'
  AND changed_at < DATE '2024-01-02'
ORDER BY changed_at, id;

-- 4.6. Только изменения суммы дохода
SELECT id,
       income_id,
       changed_at,
       (old_row ->> 'income')::NUMERIC AS old_income,
       (new_row ->> 'income')::NUMERIC AS new_income
FROM table_income_history
WHERE operation = 'U'
  AND (old_row ->> 'income') IS DISTINCT FROM (new_row ->> 'income')
ORDER BY changed_at, id;

-- 4.7. Только изменения признака удаления
SELECT id,
       income_id,
       changed_at,
       (old_row ->> 'is_deleted')::BOOLEAN AS old_is_deleted,
       (new_row ->> 'is_deleted')::BOOLEAN AS new_is_deleted
FROM table_income_history
WHERE operation = 'U'
  AND (old_row ->> 'is_deleted') IS DISTINCT FROM (new_row ->> 'is_deleted')
ORDER BY changed_at, id;

-- 4.8. Только изменения типа лица
SELECT id,
       income_id,
       changed_at,
       old_row ->> 'person_type' AS old_person_type,
       new_row ->> 'person_type' AS new_person_type
FROM table_income_history
WHERE operation = 'U'
  AND (old_row ->> 'person_type') IS DISTINCT FROM (new_row ->> 'person_type')
ORDER BY changed_at, id;

-- 4.9. Количество изменений по каждой записи о доходе
SELECT income_id,
       COUNT(*) AS change_count
FROM table_income_history
GROUP BY income_id
ORDER BY change_count DESC, income_id;


-- =========================================================================
-- 5. ЖУРНАЛ ИЗМЕНЕНИЙ НАЛОГОВ
-- =========================================================================

-- 5.1. Все изменения налогов, начиная с последних
SELECT id,
       year,
       month,
       delta,
       income_id,
       changed_at
FROM table_taxes_history
ORDER BY changed_at DESC, id DESC;

-- 5.2. История изменений налога за конкретный период
SELECT id,
       delta,
       income_id,
       changed_at
FROM table_taxes_history
WHERE year = 2024
  AND month = 1
ORDER BY changed_at, id;

-- 5.3. Изменения налога, вызванные конкретным доходом
SELECT id,
       year,
       month,
       delta,
       changed_at
FROM table_taxes_history
WHERE income_id = 2
ORDER BY changed_at, id;

-- 5.4. Начисления (положительные дельты)
SELECT id,
       year,
       month,
       delta,
       income_id,
       changed_at
FROM table_taxes_history
WHERE delta > 0
ORDER BY changed_at, id;

-- 5.5. Снятия (отрицательные дельты)
SELECT id,
       year,
       month,
       delta,
       income_id,
       changed_at
FROM table_taxes_history
WHERE delta < 0
ORDER BY changed_at, id;

-- 5.6. Изменения за конкретный день
SELECT id,
       year,
       month,
       delta,
       income_id,
       changed_at
FROM table_taxes_history
WHERE changed_at >= DATE '2024-01-01'
  AND changed_at < DATE '2024-01-02'
ORDER BY changed_at, id;

-- 5.7. Итоговая сумма изменений по периодам (должна совпадать с table_taxes.tax)
SELECT year,
       month,
       SUM(delta) AS total_delta
FROM table_taxes_history
GROUP BY year, month
ORDER BY year, month;

-- 5.8. Количество операций по каждому периоду
SELECT year,
       month,
       COUNT(*) AS change_count
FROM table_taxes_history
GROUP BY year, month
ORDER BY year, month;


-- =========================================================================
-- 6. АНАЛИТИЧЕСКИЕ И СВОДНЫЕ ЗАПРОСЫ
-- =========================================================================

-- 6.1. Помесячная сводка: доходы, налог, ставка
SELECT EXTRACT(YEAR FROM date)::INT                           AS year,
       EXTRACT(MONTH FROM date)::INT                          AS month,
       SUM(income)                                            AS total_income,
       SUM(income * function_get_tax_rate(person_type, date)) AS total_tax,
       COUNT(*)                                               AS income_count
FROM table_income
WHERE is_deleted = FALSE
GROUP BY 1, 2
ORDER BY 1, 2;

-- 6.2. Сводка по типу лица за год
SELECT person_type,
       COUNT(*)                                               AS income_count,
       SUM(income)                                            AS total_income,
       SUM(income * function_get_tax_rate(person_type, date)) AS total_tax
FROM table_income
WHERE is_deleted = FALSE
  AND EXTRACT(YEAR FROM date)::INT = 2024
GROUP BY person_type
ORDER BY person_type;

-- 6.3. Сводка по типу лица и месяцам
SELECT EXTRACT(YEAR FROM date)::INT                           AS year,
       EXTRACT(MONTH FROM date)::INT                          AS month,
       person_type,
       COUNT(*)                                               AS income_count,
       SUM(income)                                            AS total_income,
       SUM(income * function_get_tax_rate(person_type, date)) AS total_tax
FROM table_income
WHERE is_deleted = FALSE
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- 6.4. Сводка по годам
SELECT EXTRACT(YEAR FROM date)::INT                           AS year,
       COUNT(*)                                               AS income_count,
       SUM(income)                                            AS total_income,
       SUM(income * function_get_tax_rate(person_type, date)) AS total_tax
FROM table_income
WHERE is_deleted = FALSE
GROUP BY 1
ORDER BY 1;

-- 6.5. Сравнение фактического налога с пересчётом по доходам
SELECT actual.year,
       actual.month,
       actual.tax                         AS actual_tax,
       expected.expected_tax,
       actual.tax - expected.expected_tax AS difference
FROM table_taxes AS actual
         FULL OUTER JOIN (SELECT EXTRACT(YEAR FROM date)::INT                           AS year,
                                 EXTRACT(MONTH FROM date)::INT                          AS month,
                                 SUM(income * function_get_tax_rate(person_type, date)) AS expected_tax
                          FROM table_income
                          WHERE is_deleted = FALSE
                          GROUP BY 1, 2) AS expected
                         ON actual.year = expected.year
                             AND actual.month = expected.month
ORDER BY COALESCE(actual.year, expected.year),
         COALESCE(actual.month, expected.month);
-- Разница должна быть равна нулю для всех периодов.

-- 6.6. Доходы с расчётной суммой налога по каждой записи
SELECT id,
       date,
       person_type,
       income,
       function_get_tax_rate(person_type, date)                             AS rate,
       function_calculate_tax_amount(income, person_type, date, is_deleted) AS tax_amount
FROM table_income
ORDER BY date, id;

-- 6.7. Топ доходов за год
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE is_deleted = FALSE
  AND EXTRACT(YEAR FROM date)::INT = 2024
ORDER BY income DESC
LIMIT 10;

-- 6.8. Средний доход по типу лица
SELECT person_type,
       COUNT(*)    AS income_count,
       AVG(income) AS average_income,
       MIN(income) AS minimum_income,
       MAX(income) AS maximum_income
FROM table_income
WHERE is_deleted = FALSE
GROUP BY person_type
ORDER BY person_type;


-- =========================================================================
-- 7. ПРОВЕРОЧНЫЕ И ДИАГНОСТИЧЕСКИЕ ЗАПРОСЫ
-- =========================================================================

-- 7.1. Периоды, где налог в table_taxes не совпадает с журналом изменений
SELECT COALESCE(current_state.year, history.year)   AS year,
       COALESCE(current_state.month, history.month) AS month,
       current_state.tax                            AS tax_in_table,
       history.total_delta                          AS tax_from_history
FROM table_taxes AS current_state
         FULL OUTER JOIN (SELECT year,
                                 month,
                                 SUM(delta) AS total_delta
                          FROM table_taxes_history
                          GROUP BY year, month) AS history
                         ON current_state.year = history.year
                             AND current_state.month = history.month
WHERE current_state.tax IS DISTINCT FROM history.total_delta
ORDER BY 1, 2;
-- Ожидается пустой результат.

-- 7.2. Сумма налога по периодам без записи в журнале изменений
SELECT tax.year,
       tax.month,
       tax.tax
FROM table_taxes AS tax
         LEFT JOIN table_taxes_history AS history
                   ON tax.year = history.year
                       AND tax.month = history.month
WHERE history.id IS NULL
  AND tax.tax <> 0
ORDER BY tax.year, tax.month;
-- Ожидается пустой результат.

-- 7.3. Активные доходы, у которых нет ни одного изменения в журнале
SELECT income.id,
       income.date,
       income.person_type,
       income.income
FROM table_income AS income
         LEFT JOIN table_income_history AS history
                   ON income.id = history.income_id
WHERE history.id IS NULL
ORDER BY income.id;
-- Ожидается пустой результат: каждая запись должна иметь хотя бы одну
-- строку журнала (запись о вставке).

-- 7.4. Доходы, у которых ставка налога не найдена на дату дохода
SELECT income.id,
       income.date,
       income.person_type,
       income.income
FROM table_income AS income
WHERE function_get_tax_rate(income.person_type, income.date) IS NULL
ORDER BY income.id;
-- Ожидается пустой результат.

-- 7.5. Удалённые доходы, у которых в table_taxes остался налог
SELECT income.id,
       income.date,
       income.person_type,
       income.income
FROM table_income AS income
WHERE income.is_deleted = TRUE
ORDER BY income.id;
-- Дополнительно можно сверить налог за период по п. 6.5.

-- 7.6. Доходы с датой в будущем
SELECT id,
       date,
       person_type,
       income
FROM table_income
WHERE date > CURRENT_DATE
ORDER BY date;
-- Ожидается пустой результат: триггер не даёт вставить такую дату.

-- 7.7. Периоды, где налог отрицательный (переплата)
SELECT year,
       month,
       tax
FROM table_taxes
WHERE tax < 0
ORDER BY year, month;

-- 7.8. Несоответствие признака уплаты и даты уплаты
SELECT year,
       month,
       is_paid,
       paid_at
FROM table_taxes
WHERE (is_paid = TRUE AND paid_at IS NULL)
   OR (is_paid = FALSE AND paid_at IS NOT NULL)
ORDER BY year, month;
-- Ожидается пустой результат: ограничение не даёт создать такое состояние.

-- 7.9. Общая статистика по базе
SELECT (SELECT COUNT(*) FROM table_income)                          AS income_count,
       (SELECT COUNT(*) FROM table_income WHERE is_deleted = FALSE) AS active_income_count,
       (SELECT COUNT(*) FROM table_income WHERE is_deleted = TRUE)  AS deleted_income_count,
       (SELECT COUNT(*) FROM table_taxes)                           AS taxes_period_count,
       (SELECT COUNT(*) FROM table_income_history)                  AS income_history_count,
       (SELECT COUNT(*) FROM table_taxes_history)                   AS taxes_history_count;