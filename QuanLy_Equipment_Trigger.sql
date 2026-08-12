--------------------
--- TRIGGER
--------------------
CREATE OR REPLACE TRIGGER TRG_CHECK_COMPATIBILITY
BEFORE INSERT ON RENTAL_ITEMS
FOR EACH ROW
DECLARE
    v_equipment_type EQUIPMENTS.equipment_type%TYPE;
    v_main_equipment_id RENTAL_ITEMS.equipment_id%TYPE;
BEGIN
    -- 1️ Lấy loại thiết bị
    SELECT equipment_type
    INTO v_equipment_type
    FROM EQUIPMENTS
    WHERE equipment_id = :NEW.equipment_id;

    -- 2️ Nếu là phụ kiện → gọi SP kiểm tra
    IF v_equipment_type = 'ACCESSORY' THEN
        BEGIN
            SELECT equipment_id
            INTO v_main_equipment_id
            FROM RENTAL_ITEMS
            WHERE rental_id = :NEW.rental_id
              AND equipment_id <> :NEW.equipment_id
              AND ROWNUM = 1;

            IF v_main_equipment_id IS NOT NULL THEN
                SP_CHECK_COMPATIBILITY(v_main_equipment_id, :NEW.equipment_id);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- chưa có máy chính, cho phép insert
        END;
    END IF;

    -- 3️ Validation quantity, days, price_per_day
    IF :NEW.quantity IS NULL OR :NEW.quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20040, 'Quantity must be greater than 0');
    END IF;

    IF :NEW.days IS NULL OR :NEW.price_per_day IS NULL THEN
        RAISE_APPLICATION_ERROR(-20041, 'Days and price_per_day cannot be NULL');
    END IF;

    -- 4️ Validation item_status
    IF NOT (:NEW.item_status IN ('BORROWING','RETURNED','DAMAGED','LOST')) THEN
        RAISE_APPLICATION_ERROR(-20042, 'Invalid item_status');
    END IF;

    -- 5️ Tính subtotal
    :NEW.subtotal := :NEW.quantity * :NEW.days * :NEW.price_per_day;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20043, 'Trigger TRG_CHECK_COMPATIBILITY error: ' || SQLERRM);
END;
/

--- TRG_SYSTEM_LOG_CUSTOMERS
CREATE OR REPLACE TRIGGER TRG_SYSTEM_LOG_CUSTOMERS
AFTER INSERT OR UPDATE OR DELETE ON CUSTOMERS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(20);
    v_record_id VARCHAR2(50);
    v_desc VARCHAR2(255);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_record_id := :NEW.customer_id;
        v_desc := 'Inserted customer ' || :NEW.username;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_record_id := :NEW.customer_id;
        v_desc := 'Updated customer ' || :NEW.username;
    ELSIF DELETING THEN
        -- Kiểm tra FK trước DELETE
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM RENTALS WHERE customer_id = :OLD.customer_id;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20060,'Cannot delete customer; linked rentals exist.');
            END IF;
        END;
        v_action := 'DELETE';
        v_record_id := :OLD.customer_id;
        v_desc := 'Deleted customer ' || :OLD.username;
    END IF;

    INSERT INTO SYSTEM_LOG(log_id, action, table_name, record_id, action_time, description)
    VALUES ('LG' || LPAD(SEQ_SYSTEM_LOG.NEXTVAL,3,'0'), v_action, 'CUSTOMERS', v_record_id, SYSDATE, v_desc);
END;
/

--- TEST
INSERT INTO CUSTOMERS(customer_id, username, password_hash, full_name, email, phone, address, status, created_at)
VALUES ('CU003','alice','hash','Alice','alice@test.com','0123456789','HN','ACTIVE', SYSDATE);

SELECT * FROM SYSTEM_LOG ORDER BY action_time DESC;

--- TRG_SYSTEM_LOG_EQUIPMENTS
CREATE OR REPLACE TRIGGER TRG_SYSTEM_LOG_EQUIPMENTS
AFTER INSERT OR UPDATE OR DELETE ON EQUIPMENTS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(20);
    v_record_id VARCHAR2(50);
    v_desc VARCHAR2(255);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_record_id := :NEW.equipment_id;
        v_desc := 'Inserted equipment ' || :NEW.equipment_name;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_record_id := :NEW.equipment_id;
        v_desc := 'Updated equipment ' || :NEW.equipment_name;
    ELSIF DELETING THEN
        -- Kiểm tra FK trước DELETE
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM RENTAL_ITEMS WHERE equipment_id = :OLD.equipment_id;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20061,'Cannot delete equipment; linked rental items exist.');
            END IF;
        END;
        v_action := 'DELETE';
        v_record_id := :OLD.equipment_id;
        v_desc := 'Deleted equipment ' || :OLD.equipment_name;
    END IF;

    INSERT INTO SYSTEM_LOG(log_id, action, table_name, record_id, action_time, description)
    VALUES ('LG' || LPAD(SEQ_SYSTEM_LOG.NEXTVAL,3,'0'), v_action, 'EQUIPMENTS', v_record_id, SYSDATE, v_desc);
END;
/


--- TRG_SYSTEM_LOG_RENTALS
CREATE OR REPLACE TRIGGER TRG_SYSTEM_LOG_RENTALS
AFTER INSERT OR UPDATE OR DELETE ON RENTALS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(20);
    v_record_id VARCHAR2(50);
    v_desc VARCHAR2(255);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_record_id := :NEW.rental_id;
        v_desc := 'Inserted rental ' || :NEW.rental_code;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_record_id := :NEW.rental_id;
        v_desc := 'Updated rental ' || :NEW.rental_code;
    ELSIF DELETING THEN
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM RENTAL_ITEMS WHERE rental_id = :OLD.rental_id;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20062,'Cannot delete rental; linked rental items exist.');
            END IF;
            SELECT COUNT(*) INTO v_count FROM INVOICES WHERE rental_id = :OLD.rental_id;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20063,'Cannot delete rental; linked invoices exist.');
            END IF;
        END;
        v_action := 'DELETE';
        v_record_id := :OLD.rental_id;
        v_desc := 'Deleted rental ' || :OLD.rental_code;
    END IF;

    INSERT INTO SYSTEM_LOG(log_id, action, table_name, record_id, action_time, description)
    VALUES ('LG' || LPAD(SEQ_SYSTEM_LOG.NEXTVAL,3,'0'), v_action, 'RENTALS', v_record_id, SYSDATE, v_desc);
END;
/


---TRG_SYSTEM_LOG_RENTAL_ITEMS
CREATE OR REPLACE TRIGGER TRG_SYSTEM_LOG_RENTAL_ITEMS
AFTER INSERT OR UPDATE OR DELETE ON RENTAL_ITEMS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(20);
    v_record_id VARCHAR2(50);
    v_desc VARCHAR2(255);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_record_id := :NEW.rental_item_id;
        v_desc := 'Inserted rental item ' || :NEW.equipment_id;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_record_id := :NEW.rental_item_id;
        v_desc := 'Updated rental item ' || :NEW.equipment_id;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_record_id := :OLD.rental_item_id;
        v_desc := 'Deleted rental item ' || :OLD.equipment_id;
    END IF;

    INSERT INTO SYSTEM_LOG(log_id, action, table_name, record_id, action_time, description)
    VALUES ('LG' || LPAD(SEQ_SYSTEM_LOG.NEXTVAL,3,'0'), v_action, 'RENTAL_ITEMS', v_record_id, SYSDATE, v_desc);
END;
/


---  TRG_SYSTEM_LOG_INVOICES
CREATE OR REPLACE TRIGGER TRG_SYSTEM_LOG_INVOICES
AFTER INSERT OR UPDATE OR DELETE ON INVOICES
FOR EACH ROW
DECLARE
    v_action VARCHAR2(20);
    v_record_id VARCHAR2(50);
    v_desc VARCHAR2(255);
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_record_id := :NEW.invoice_id;
        v_desc := 'Inserted invoice ' || :NEW.invoice_number;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_record_id := :NEW.invoice_id;
        v_desc := 'Updated invoice ' || :NEW.invoice_number;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_record_id := :OLD.invoice_id;
        v_desc := 'Deleted invoice ' || :OLD.invoice_number;
    END IF;

    INSERT INTO SYSTEM_LOG(log_id, action, table_name, record_id, action_time, description)
    VALUES ('LG' || LPAD(SEQ_SYSTEM_LOG.NEXTVAL,3,'0'), v_action, 'INVOICES', v_record_id, SYSDATE, v_desc);
END;
/

--- TEST
-- Test INSERT
INSERT INTO CUSTOMERS(customer_id, username, password_hash, full_name, email, phone, address, status, created_at)
VALUES ('C001','alice','hash','Alice','alice@test.com','0123456789','HN','ACTIVE', SYSDATE);

INSERT INTO EQUIPMENTS(equipment_id, equipment_name, equipment_type, status, equipment_value, purchase_price, rental_price_per_day, depreciation_rate, total_usage_days, purchase_date, created_at)
VALUES ('E001','Canon R6','MAIN','AVAILABLE',50000,50000,200,5,0,SYSDATE,SYSDATE);

INSERT INTO RENTALS(rental_id, rental_code, rental_type, status, notes, total_amount, deposit_required, rental_date, due_date, created_at, updated_at, customer_id, employee_id)
VALUES ('R001','RC001','REGULAR','CREATED','Test',1000,200,SYSDATE,SYSDATE,SYSDATE,SYSDATE,'C001','EMP001');

INSERT INTO RENTAL_ITEMS(rental_item_id, rental_id, equipment_id, quantity, days, price_per_day, subtotal, item_status)
VALUES ('RI001','R001','E001',1,3,200,600,'BORROWING');

INSERT INTO INVOICES(invoice_id, invoice_number, status, rental_amount, subtotal_amount, tax_amount, total_amount, final_amount, invoice_date, payment_due_date, created_at, tax_id, rental_id)
VALUES ('I001','INV001','PENDING',600,600,60,660,660,SYSDATE,SYSDATE,SYSDATE,'T001','R001');

-- Test UPDATE
UPDATE CUSTOMERS SET full_name='Alice Smith' WHERE customer_id='C001';

-- Test DELETE
DELETE FROM RENTAL_ITEMS WHERE rental_item_id='RI001';
DELETE FROM INVOICES WHERE invoice_id='I001';
-- DELETE FROM RENTALS WHERE rental_id='R001'; -- Sẽ báo lỗi nếu còn RENTAL_ITEMS/INVOICES
-- DELETE FROM CUSTOMERS WHERE customer_id='C001'; -- Sẽ báo lỗi nếu còn RENTALS

-- Kiểm tra log
SELECT * FROM SYSTEM_LOG ORDER BY action_time DESC;


---TRG_UPDATE_EQUIPMENT_STATUS
CREATE OR REPLACE TRIGGER TRG_UPDATE_EQUIPMENT_STATUS
AFTER UPDATE OF item_status ON RENTAL_ITEMS
FOR EACH ROW
DECLARE
    v_new_status EQUIPMENTS.status%TYPE;
    v_borrowing_count NUMBER;
    v_problem_count NUMBER;
BEGIN
    -- 1. Kiểm tra tổng số item BORROWING của thiết bị này
    SELECT COUNT(*) INTO v_borrowing_count
    FROM RENTAL_ITEMS
    WHERE equipment_id = :NEW.equipment_id
      AND item_status = 'BORROWING';

    -- 2. Kiểm tra tổng số item DAMAGED/LOST nếu không còn BORROWING
    IF v_borrowing_count = 0 THEN
        SELECT COUNT(*) INTO v_problem_count
        FROM RENTAL_ITEMS
        WHERE equipment_id = :NEW.equipment_id
          AND item_status IN ('DAMAGED','LOST');
    ELSE
        v_problem_count := 0;
    END IF;

    -- 3. Xác định trạng thái mới
    IF v_borrowing_count > 0 THEN
        v_new_status := 'MAINTENANCE';
    ELSIF v_problem_count > 0 THEN
        v_new_status := 'DISABLED';
    ELSE
        v_new_status := 'AVAILABLE';
    END IF;

    -- 4. Cập nhật trạng thái thiết bị
    UPDATE EQUIPMENTS
    SET status = v_new_status
    WHERE equipment_id = :NEW.equipment_id;

    -- 5. Ghi log vào SYSTEM_LOG, log_id sẽ được trigger trg_system_log tự động sinh
    INSERT INTO SYSTEM_LOG(
        action, table_name, record_id, action_time, description, ip_address
    ) VALUES (
        'UPDATE',
        'EQUIPMENTS',
        :NEW.equipment_id,
        SYSDATE,
        'Updated equipment status to ' || v_new_status || 
        ' due to rental item ' || :NEW.rental_item_id || 
        ' changed from ' || :OLD.item_status || ' to ' || :NEW.item_status,
        SYS_CONTEXT('USERENV','IP_ADDRESS') -- lấy IP client nếu có
    );
END;
/
-- TEST
-- Giả sử đã có Rental Item
INSERT INTO RENTAL_ITEMS(rental_item_id, rental_id, equipment_id, quantity, days, price_per_day, subtotal, item_status)
VALUES ('RI002','R001','E001',1,3,200,600,'BORROWING');

-- Kiểm tra trạng thái thiết bị trước update
SELECT equipment_id, status FROM EQUIPMENTS WHERE equipment_id='E001';

-- Thay đổi item_status → kiểm tra EQUIPMENTS.status có update không
UPDATE RENTAL_ITEMS SET item_status='RETURNED' WHERE rental_item_id='RI002';
SELECT equipment_id, status FROM EQUIPMENTS WHERE equipment_id='E001';

UPDATE RENTAL_ITEMS SET item_status='DAMAGED' WHERE rental_item_id='RI002';
SELECT equipment_id, status FROM EQUIPMENTS WHERE equipment_id='E001';

UPDATE RENTAL_ITEMS SET item_status='LOST' WHERE rental_item_id='RI002';
SELECT equipment_id, status FROM EQUIPMENTS WHERE equipment_id='E001';

---- TRG_CHECK_EQUIPMENT_AVAILABLE
CREATE OR REPLACE TRIGGER TRG_CHECK_EQUIPMENT_AVAILABLE
BEFORE INSERT ON RENTAL_ITEMS
FOR EACH ROW
DECLARE
    v_status EQUIPMENTS.status%TYPE;
BEGIN
    SELECT status INTO v_status
    FROM EQUIPMENTS
    WHERE equipment_id = :NEW.equipment_id;

    IF v_status != 'AVAILABLE' THEN
        RAISE_APPLICATION_ERROR(-20050, 
            'Cannot rent equipment ' || :NEW.equipment_id || '. Status: ' || v_status);
    END IF;
END;
/

-- Test 1: Thiết bị còn AVAILABLE
INSERT INTO EQUIPMENTS(equipment_id, equipment_name, equipment_type, status, equipment_value, purchase_price, rental_price_per_day, depreciation_rate, total_usage_days, purchase_date, created_at)
VALUES ('E100', 'Canon 5D', 'MAIN', 'AVAILABLE', 50000, 50000, 200, 1, 0, SYSDATE, SYSDATE);

INSERT INTO RENTALS(rental_id, rental_code, rental_type, status, total_amount, deposit_required, rental_date, due_date, created_at, updated_at, customer_id, employee_id)
VALUES ('R100','RC100','STANDARD','CREATED',0,0,SYSDATE,SYSDATE+3,SYSDATE,SYSDATE,'C001','EMP001');

-- Thành công
INSERT INTO RENTAL_ITEMS(rental_item_id, rental_id, equipment_id, quantity, days, price_per_day, subtotal, item_status)
VALUES ('RI100','R100','E100',1,3,200,600,'BORROWING');

-- Test 2: Thiết bị không còn AVAILABLE
UPDATE EQUIPMENTS SET status='MAINTENANCE' WHERE equipment_id='E100';

-- Lệnh dưới đây phải lỗi
INSERT INTO RENTAL_ITEMS(rental_item_id, rental_id, equipment_id, quantity, days, price_per_day, subtotal, item_status)
VALUES ('RI101','R100','E100',1,3,200,600,'BORROWING');


---- TRG_UPDATE_RENTAL_TOTAL
CREATE OR REPLACE TRIGGER TRG_UPDATE_RENTAL_TOTAL
AFTER INSERT OR UPDATE OR DELETE ON RENTAL_ITEMS
FOR EACH ROW
DECLARE
    v_total NUMBER(10,2);
BEGIN
    -- Lấy tổng subtotal của tất cả item trong rental
    SELECT NVL(SUM(subtotal),0)
    INTO v_total
    FROM RENTAL_ITEMS
    WHERE rental_id = NVL(:NEW.rental_id, :OLD.rental_id);

    -- Cập nhật tổng của rental
    UPDATE RENTALS
    SET total_amount = v_total
    WHERE rental_id = NVL(:NEW.rental_id, :OLD.rental_id);
END;
/
-- Giả sử E101 đã dùng 1200 ngày
UPDATE EQUIPMENTS SET total_usage_days=1200 WHERE equipment_id='E101';

INSERT INTO RENTAL_ITEMS(rental_item_id, rental_id, equipment_id, quantity, days, price_per_day, subtotal, item_status)
VALUES ('RI103','R100','E101',1,2,200,400,'BORROWING');
-- Output trên SQL*Plus sẽ hiển thị cảnh báo

