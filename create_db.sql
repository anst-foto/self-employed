-- =========================================================================
--  БАЗА ДАННЫХ УЧЁТА ДОХОДОВ И НАЛОГОВ
--  Структура скрипта:
--    1. Типы
--    2. Таблицы
--    3. Индексы
--    4. Начальные данные
--    5. Функции
--    6. Процедуры
--    7. Триггерные функции
--    8. Триггеры
-- =========================================================================


-- =========================================================================
-- 1. ТИПЫ
-- =========================================================================

CREATE TYPE type_person AS ENUM ('ФЛ', 'ЮЛ');

COMMENT ON TYPE type_person IS 'Тип лица: ФЛ — физическое лицо, ЮЛ — юридическое лицо';


-- =========================================================================
-- 2. ТАБЛИЦЫ
-- =========================================================================

-- -------------------------------------------------------------------------
-- 2.1. Ставки налога
-- -------------------------------------------------------------------------
CREATE TABLE table_tax_rates
(
    person_type type_person   NOT NULL,
    valid_from  DATE          NOT NULL,
    valid_to    DATE,
    rate        NUMERIC(5, 4) NOT NULL,

    CONSTRAINT constraint_primary_key_table_tax_rates
        PRIMARY KEY (person_type, valid_from),

    CONSTRAINT constraint_check_table_tax_rates_rate_range
        CHECK ( rate > 0 AND rate < 1 ),

    CONSTRAINT constraint_check_table_tax_rates_valid_period
        CHECK ( valid_to IS NULL OR valid_to > valid_from )
);

COMMENT ON TABLE table_tax_rates IS 'Исторические ставки налога по типам лиц';
COMMENT ON COLUMN table_tax_rates.person_type IS 'Тип лица: ФЛ или ЮЛ';
COMMENT ON COLUMN table_tax_rates.valid_from IS 'Дата начала действия ставки (включительно)';
COMMENT ON COLUMN table_tax_rates.valid_to IS 'Дата окончания действия ставки (не включительно); NULL — бессрочно';
COMMENT ON COLUMN table_tax_rates.rate IS 'Ставка налога в долях единицы (0.04 — 4%)';

-- -------------------------------------------------------------------------
-- 2.2. Доходы
-- -------------------------------------------------------------------------
CREATE TABLE table_income
(
    id          INT GENERATED ALWAYS AS IDENTITY,
    date        DATE           NOT NULL DEFAULT current_date,
    person_type type_person    NOT NULL,
    income      NUMERIC(11, 2) NOT NULL,
    is_deleted  BOOLEAN        NOT NULL DEFAULT FALSE,

    CONSTRAINT constraint_primary_key_table_income
        PRIMARY KEY (id),

    CONSTRAINT constraint_check_table_income_income_non_negative
        CHECK ( income >= 0 )
);

COMMENT ON TABLE table_income IS 'Доходы физических и юридических лиц';
COMMENT ON COLUMN table_income.date IS 'Дата дохода; не может быть в будущем (проверяется триггером)';
COMMENT ON COLUMN table_income.person_type IS 'Тип лица: ФЛ или ЮЛ';
COMMENT ON COLUMN table_income.income IS 'Сумма дохода в рублях';
COMMENT ON COLUMN table_income.is_deleted IS 'Мягкое удаление: TRUE — доход исключён из расчёта налога';

-- -------------------------------------------------------------------------
-- 2.3. Накопленный налог по периодам
-- -------------------------------------------------------------------------
CREATE TABLE table_taxes
(
    year    INT            NOT NULL,
    month   INT            NOT NULL,
    tax     NUMERIC(11, 2) NOT NULL,
    is_paid BOOLEAN        NOT NULL DEFAULT FALSE,
    paid_at TIMESTAMPTZ,

    CONSTRAINT constraint_primary_key_table_taxes
        PRIMARY KEY (year, month),

    CONSTRAINT constraint_check_table_taxes_year_range
        CHECK ( year BETWEEN 2000 AND 2100 ),

    CONSTRAINT constraint_check_table_taxes_month_range
        CHECK ( month BETWEEN 1 AND 12 ),

    CONSTRAINT constraint_check_table_taxes_paid_at
        CHECK ( NOT is_paid OR paid_at IS NOT NULL )
);

COMMENT ON TABLE table_taxes IS 'Накопленный налог по годам и месяцам';
COMMENT ON COLUMN table_taxes.year IS 'Год периода';
COMMENT ON COLUMN table_taxes.month IS 'Месяц периода (1–12)';
COMMENT ON COLUMN table_taxes.tax IS 'Суммарный налог; отрицательное значение — переплата';
COMMENT ON COLUMN table_taxes.is_paid IS 'Признак уплаты налога за период';
COMMENT ON COLUMN table_taxes.paid_at IS 'Момент уплаты налога; заполнен, если is_paid = TRUE';

-- -------------------------------------------------------------------------
-- 2.4. История доходов
-- -------------------------------------------------------------------------
CREATE TABLE table_income_history
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY,
    income_id  INT         NOT NULL,
    operation  CHAR(1)     NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    old_row    JSONB,
    new_row    JSONB,

    CONSTRAINT constraint_primary_key_table_income_history
        PRIMARY KEY (id),

    CONSTRAINT constraint_foreign_key_table_income_history_income_id
        FOREIGN KEY (income_id) REFERENCES table_income (id),

    CONSTRAINT constraint_check_table_income_history_operation
        CHECK ( operation IN ('I', 'U') )
);

COMMENT ON TABLE table_income_history IS 'Журнал изменений записей о доходах';
COMMENT ON COLUMN table_income_history.income_id IS 'Ссылка на изменённую запись в table_income';
COMMENT ON COLUMN table_income_history.operation IS 'Тип операции: I — insert, U — update';
COMMENT ON COLUMN table_income_history.changed_at IS 'Момент изменения';
COMMENT ON COLUMN table_income_history.old_row IS 'Состояние строки до изменения (NULL для INSERT)';
COMMENT ON COLUMN table_income_history.new_row IS 'Состояние строки после изменения';

-- -------------------------------------------------------------------------
-- 2.5. История налогов
-- -------------------------------------------------------------------------
CREATE TABLE table_taxes_history
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY,
    year       INT            NOT NULL,
    month      INT            NOT NULL,
    delta      NUMERIC(11, 2) NOT NULL,
    income_id  INT,
    changed_at TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT constraint_primary_key_table_taxes_history
        PRIMARY KEY (id),

    CONSTRAINT constraint_foreign_key_table_taxes_history_income_id
        FOREIGN KEY (income_id) REFERENCES table_income (id)
);

COMMENT ON TABLE table_taxes_history IS 'Журнал изменений налога по периодам';
COMMENT ON COLUMN table_taxes_history.year IS 'Год периода';
COMMENT ON COLUMN table_taxes_history.month IS 'Месяц периода';
COMMENT ON COLUMN table_taxes_history.delta IS 'Изменение налога за период (может быть отрицательным)';
COMMENT ON COLUMN table_taxes_history.income_id IS 'Доход, вызвавший изменение (может быть NULL)';
COMMENT ON COLUMN table_taxes_history.changed_at IS 'Момент изменения';


-- =========================================================================
-- 3. ИНДЕКСЫ
-- =========================================================================

-- table_income
CREATE INDEX idx_table_income_date
    ON table_income (date);

CREATE INDEX idx_table_income_active_date
    ON table_income (date)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_table_income_person_type
    ON table_income (person_type);

-- table_income_history
CREATE INDEX idx_table_income_history_income_id
    ON table_income_history (income_id);

CREATE INDEX idx_table_income_history_changed_at
    ON table_income_history (changed_at);

-- table_taxes_history
CREATE INDEX idx_table_taxes_history_ym
    ON table_taxes_history (year, month);

CREATE INDEX idx_table_taxes_history_income_id
    ON table_taxes_history (income_id);


-- =========================================================================
-- 4. НАЧАЛЬНЫЕ ДАННЫЕ
-- =========================================================================

INSERT INTO table_tax_rates (person_type, valid_from, rate)
VALUES ('ФЛ', '2020-01-01', 0.04),
       ('ЮЛ', '2020-01-01', 0.06);


-- =========================================================================
-- 5. ФУНКЦИИ
-- =========================================================================

-- -------------------------------------------------------------------------
-- 5.1. Получить ставку налога для типа лица на дату
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION function_get_tax_rate(
    p_person_type type_person,
    p_date DATE
)
    RETURNS NUMERIC
    STABLE
AS
$$
SELECT rate
FROM table_tax_rates
WHERE person_type = p_person_type
  AND p_date >= valid_from
  AND (valid_to IS NULL OR p_date < valid_to)
ORDER BY valid_from DESC
LIMIT 1;
$$
    LANGUAGE sql;

COMMENT ON FUNCTION function_get_tax_rate(type_person, DATE)
    IS 'Возвращает действующую ставку налога для типа лица на указанную дату';

-- -------------------------------------------------------------------------
-- 5.2. Рассчитать сумму налога по доходу
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION function_calculate_tax_amount(
    p_income NUMERIC,
    p_person_type type_person,
    p_date DATE,
    p_is_deleted BOOLEAN
)
    RETURNS NUMERIC
    STABLE
AS
$$
SELECT CASE
           WHEN p_is_deleted THEN 0
           ELSE p_income * function_get_tax_rate(p_person_type, p_date)
           END;
$$
    LANGUAGE sql;

COMMENT ON FUNCTION function_calculate_tax_amount(NUMERIC, type_person, DATE, BOOLEAN)
    IS 'Возвращает сумму налога по доходу; 0, если запись помечена как удалённая';


-- =========================================================================
-- 6. ПРОЦЕДУРЫ
-- =========================================================================

-- -------------------------------------------------------------------------
-- 6.1. Применить дельту налога к периоду и записать в историю
-- -------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE procedure_apply_tax_delta(
    p_year INT,
    p_month INT,
    p_delta NUMERIC,
    p_income_id INT DEFAULT NULL
)
AS
$$
BEGIN
    IF p_delta = 0 THEN
        RETURN;
    END IF;

    INSERT INTO table_taxes (year, month, tax)
    VALUES (p_year, p_month, p_delta)
    ON CONFLICT (year, month) DO UPDATE
        SET tax = table_taxes.tax + EXCLUDED.tax;

    INSERT INTO table_taxes_history (year, month, delta, income_id)
    VALUES (p_year, p_month, p_delta, p_income_id);
END;
$$
    LANGUAGE plpgsql;

COMMENT ON PROCEDURE procedure_apply_tax_delta(INT, INT, NUMERIC, INT)
    IS 'Применяет дельту к налогу за период и фиксирует изменение в table_taxes_history';


-- =========================================================================
-- 7. ТРИГГЕРНЫЕ ФУНКЦИИ
-- =========================================================================

-- -------------------------------------------------------------------------
-- 7.1. Запрет даты дохода в будущем
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_function_table_income_check_future_date()
    RETURNS TRIGGER
AS
$$
BEGIN
    IF NEW.date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Дата дохода не может быть в будущем: %', NEW.date;
    END IF;
    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_function_table_income_check_future_date()
    IS 'BEFORE INSERT/UPDATE: запрещает дату дохода в будущем';

-- -------------------------------------------------------------------------
-- 7.2. Логирование изменений дохода в историю
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_function_table_income_log_history()
    RETURNS TRIGGER
AS
$$
BEGIN
    INSERT INTO table_income_history (income_id, operation, old_row, new_row)
    VALUES (COALESCE(NEW.id, OLD.id),
            LEFT(TG_OP, 1),
            CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END,
            to_jsonb(NEW));
    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_function_table_income_log_history()
    IS 'AFTER INSERT/UPDATE: пишет снимок строки в table_income_history';

-- -------------------------------------------------------------------------
-- 7.3. Пересчёт налога при изменении дохода
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_function_table_income_calculate_tax()
    RETURNS TRIGGER
AS
$$
DECLARE
    v_old_tax   NUMERIC;
    v_new_tax   NUMERIC;
    v_old_year  INT;
    v_old_month INT;
    v_new_year  INT;
    v_new_month INT;
BEGIN
    -- Значения для новой версии строки
    v_new_year := EXTRACT(YEAR FROM NEW.date)::INT;
    v_new_month := EXTRACT(MONTH FROM NEW.date)::INT;
    v_new_tax := function_calculate_tax_amount(
            NEW.income, NEW.person_type, NEW.date, NEW.is_deleted
                 );

    -- ============ INSERT ============
    IF TG_OP = 'INSERT' THEN
        CALL procedure_apply_tax_delta(v_new_year, v_new_month, v_new_tax, NEW.id);
        RETURN NEW;
    END IF;

    -- ============ UPDATE ============
    v_old_year := EXTRACT(YEAR FROM OLD.date)::INT;
    v_old_month := EXTRACT(MONTH FROM OLD.date)::INT;
    v_old_tax := function_calculate_tax_amount(
            OLD.income, OLD.person_type, OLD.date, OLD.is_deleted
                 );

    IF (v_old_year, v_old_month) IS DISTINCT FROM (v_new_year, v_new_month) THEN
        -- Доход переехал в другой период: снимаем старый, начисляем новый
        CALL procedure_apply_tax_delta(v_old_year, v_old_month, -v_old_tax, OLD.id);
        CALL procedure_apply_tax_delta(v_new_year, v_new_month, v_new_tax, NEW.id);
    ELSE
        -- Период тот же: применяем разницу
        CALL procedure_apply_tax_delta(v_new_year, v_new_month, v_new_tax - v_old_tax, NEW.id);
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_function_table_income_calculate_tax()
    IS 'AFTER INSERT/UPDATE: пересчитывает налог за период по изменению дохода';

-- -------------------------------------------------------------------------
-- 7.4. Запрет удаления доходов
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_function_table_income_prevent_delete()
    RETURNS TRIGGER
AS
$$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Удалять данные о доходах ЗАПРЕЩЕНО';
    END IF;
    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_function_table_income_prevent_delete()
    IS 'BEFORE DELETE: запрещает жёсткое удаление доходов';


-- =========================================================================
-- 8. ТРИГГЕРЫ
-- =========================================================================

-- -------------------------------------------------------------------------
-- 8.1. table_income — защита от будущей даты
-- -------------------------------------------------------------------------
CREATE TRIGGER trigger_table_income_check_future_date
    BEFORE INSERT OR UPDATE OF date
    ON table_income
    FOR EACH ROW
EXECUTE FUNCTION trigger_function_table_income_check_future_date();

-- -------------------------------------------------------------------------
-- 8.2. table_income — логирование в историю
-- -------------------------------------------------------------------------
CREATE TRIGGER trigger_table_income_log_history
    AFTER INSERT OR UPDATE
    ON table_income
    FOR EACH ROW
EXECUTE FUNCTION trigger_function_table_income_log_history();

-- -------------------------------------------------------------------------
-- 8.3. table_income — пересчёт налога
-- -------------------------------------------------------------------------
CREATE TRIGGER trigger_table_income_calculate_tax
    AFTER INSERT OR UPDATE
    ON table_income
    FOR EACH ROW
EXECUTE FUNCTION trigger_function_table_income_calculate_tax();

-- -------------------------------------------------------------------------
-- 8.4. table_income — запрет удаления
-- -------------------------------------------------------------------------
CREATE TRIGGER trigger_table_income_prevent_delete
    BEFORE DELETE
    ON table_income
    FOR EACH ROW
EXECUTE FUNCTION trigger_function_table_income_prevent_delete();