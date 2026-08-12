
-- ========================================
-- SEQUENCES
-- ========================================

-- ID
CREATE SEQUENCE seq_rentals START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_rental_items START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_returns START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_invoices START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_payments START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_deposits START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_system_log START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- CODE
CREATE SEQUENCE seq_rental_code START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_invoice_number START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_transaction_code START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ========================================
-- FUNCTION GEN CODE (DÙNG CHUNG)
-- ========================================
CREATE OR REPLACE FUNCTION gen_code(prefix VARCHAR2, seq_name VARCHAR2, pad_len NUMBER)
RETURN VARCHAR2
IS
    v_val NUMBER;
    v_sql VARCHAR2(200);
BEGIN
    v_sql := 'SELECT ' || seq_name || '.NEXTVAL FROM dual';
    EXECUTE IMMEDIATE v_sql INTO v_val;

    RETURN prefix || LPAD(v_val, pad_len, '0');
END;
/

-- ========================================
-- TRIGGERS
-- ========================================

-- RENTALS
CREATE OR REPLACE TRIGGER trg_rentals
BEFORE INSERT ON RENTALS
FOR EACH ROW
BEGIN
    IF :NEW.rental_id IS NULL THEN
        :NEW.rental_id := gen_code('RE','seq_rentals',3);
    END IF;

    IF :NEW.rental_code IS NULL THEN
        :NEW.rental_code := gen_code('RC','seq_rental_code',5);
    END IF;
END;
/

-- RENTAL ITEMS
CREATE OR REPLACE TRIGGER trg_rental_items
BEFORE INSERT ON RENTAL_ITEMS
FOR EACH ROW
BEGIN
    IF :NEW.rental_item_id IS NULL THEN
        :NEW.rental_item_id := gen_code('RI','seq_rental_items',3);
    END IF;
END;
/

-- RETURNS
CREATE OR REPLACE TRIGGER trg_returns
BEFORE INSERT ON RETURNS
FOR EACH ROW
BEGIN
    IF :NEW.return_id IS NULL THEN
        :NEW.return_id := gen_code('RT','seq_returns',3);
    END IF;
END;
/

-- INVOICES
CREATE OR REPLACE TRIGGER trg_invoices
BEFORE INSERT ON INVOICES
FOR EACH ROW
BEGIN
    IF :NEW.invoice_id IS NULL THEN
        :NEW.invoice_id := gen_code('IN','seq_invoices',3);
    END IF;

    IF :NEW.invoice_number IS NULL THEN
        :NEW.invoice_number := gen_code('INV','seq_invoice_number',5);
    END IF;
END;
/

-- PAYMENTS
CREATE OR REPLACE TRIGGER trg_payments
BEFORE INSERT ON PAYMENTS
FOR EACH ROW
BEGIN
    IF :NEW.payment_id IS NULL THEN
        :NEW.payment_id := gen_code('PY','seq_payments',3);
    END IF;

    IF :NEW.transaction_code IS NULL THEN
        :NEW.transaction_code := gen_code('TX','seq_transaction_code',5);
    END IF;
END;
/

-- DEPOSITS
CREATE OR REPLACE TRIGGER trg_deposits
BEFORE INSERT ON DEPOSITS
FOR EACH ROW
BEGIN
    IF :NEW.deposit_id IS NULL THEN
        :NEW.deposit_id := gen_code('DP','seq_deposits',3);
    END IF;
END;
/

-- SYSTEM_LOG
CREATE OR REPLACE TRIGGER trg_system_log
BEFORE INSERT ON SYSTEM_LOG
FOR EACH ROW
BEGIN
    -- Nếu log_id chưa có thì sinh tự động
    IF :NEW.log_id IS NULL THEN
        :NEW.log_id := gen_code('LG','seq_system_log',3);
    END IF;
END;
/
