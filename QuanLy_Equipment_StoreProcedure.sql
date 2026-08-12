--------------------
--- STORE PROCEDURE
--------------------

--- SP Ngăn người dùng thuê thiết bị KHÔNG tương thích
CREATE OR REPLACE PROCEDURE SP_CHECK_COMPATIBILITY (
    p_main_equipment_id   IN CHAR,
    p_extra_equipment_id  IN CHAR
)
IS
    v_main_mount        VARCHAR2(50);
    v_main_category     VARCHAR2(50);

    v_extra_mount       VARCHAR2(50);
    v_extra_category    VARCHAR2(50);

    v_main_exists       NUMBER;
    v_extra_exists      NUMBER;
BEGIN
    ------------------------------------------------------------
    -- 1. Check tồn tại
    ------------------------------------------------------------
    SELECT COUNT(*) INTO v_main_exists
    FROM EQUIPMENTS
    WHERE equipment_id = p_main_equipment_id;

    IF v_main_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20042, 'Main equipment not found');
    END IF;

    SELECT COUNT(*) INTO v_extra_exists
    FROM EQUIPMENTS
    WHERE equipment_id = p_extra_equipment_id;

    IF v_extra_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20043, 'Extra equipment not found');
    END IF;

    ------------------------------------------------------------
    -- 2. Lấy thông tin
    ------------------------------------------------------------
    SELECT mount_type, category_id
    INTO v_main_mount, v_main_category
    FROM EQUIPMENTS
    WHERE equipment_id = p_main_equipment_id;

    SELECT mount_type, category_id
    INTO v_extra_mount, v_extra_category
    FROM EQUIPMENTS
    WHERE equipment_id = p_extra_equipment_id;

    ------------------------------------------------------------
    -- 3. Rule 1: MAIN phải là CAMERA
    ------------------------------------------------------------
    IF v_main_category <> 'CAT01' THEN
        RAISE_APPLICATION_ERROR(-20044, 'Main equipment must be a CAMERA');
    END IF;

    ------------------------------------------------------------
    -- 4. Rule 2: LENS → check mount (QUAN TRỌNG NHẤT)
    ------------------------------------------------------------
    IF v_extra_category = 'CAT02' THEN
        IF v_main_mount IS NULL OR v_extra_mount IS NULL THEN
            RAISE_APPLICATION_ERROR(-20045, 'Missing mount information');
        END IF;

        IF v_main_mount <> v_extra_mount THEN
            RAISE_APPLICATION_ERROR(-20046, 'Lens is not compatible with camera');
        END IF;
    END IF;

    ------------------------------------------------------------
    -- 5. Rule 3: FLASH / LIGHT → check trigger (optional)
    ------------------------------------------------------------
    IF v_extra_category = 'CAT03' THEN
        -- giả sử dùng mount làm trigger type luôn
        IF v_main_mount IS NOT NULL 
           AND v_extra_mount IS NOT NULL
           AND v_main_mount <> v_extra_mount THEN

            RAISE_APPLICATION_ERROR(-20047, 'Flash trigger not compatible');
        END IF;
    END IF;

    ------------------------------------------------------------
    -- 6. Rule 4: MICRO / AUDIO → có thể yêu cầu port (future)
    ------------------------------------------------------------
    IF v_extra_category = 'CAT04' THEN
        -- cho phép tất cả (hoặc sau này check port)
        NULL;
    END IF;

    ------------------------------------------------------------
    -- 7. Rule 5: TRIPOD / ACCESSORY CHUNG → always OK
    ------------------------------------------------------------
    IF v_extra_category IN ('CAT05', 'CAT06') THEN
        NULL;
    END IF;

    ------------------------------------------------------------
    -- 8. Default: cho phép nếu không có rule
    ------------------------------------------------------------

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20048, 'Data inconsistency detected');
END;
/
--- TEST
BEGIN
    SP_CHECK_COMPATIBILITY('EQ001', 'EQ021');
END;
/

--- 
CREATE OR REPLACE PROCEDURE SP_UPDATE_INVENTORY_ON_RENT (
    p_equipment_id IN INVENTORY.equipment_id%TYPE,
    p_quantity     IN NUMBER
)
IS
    v_available_qty INVENTORY.available_quantity%TYPE;
BEGIN
    -- Validate input
    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Quantity must be greater than 0');
    END IF;

    -- Lấy số lượng tồn kho, lock row
    SELECT NVL(available_quantity,0)
    INTO v_available_qty
    FROM INVENTORY
    WHERE equipment_id = p_equipment_id
    FOR UPDATE;

    -- Check đủ hàng
    IF v_available_qty < p_quantity THEN
        RAISE_APPLICATION_ERROR(-20011, 'Not enough inventory available');
    END IF;

    -- Update kho
    UPDATE INVENTORY
    SET available_quantity = available_quantity - p_quantity,
        rented_quantity    = NVL(rented_quantity,0) + p_quantity,
        last_updated       = SYSDATE
    WHERE equipment_id = p_equipment_id;

END;
/


---
CREATE OR REPLACE PROCEDURE SP_UPDATE_INVENTORY_ON_RETURN (
    p_rental_item_id   IN RENTAL_ITEMS.rental_item_id%TYPE,
    p_condition_status IN VARCHAR2
)
IS
    v_equipment_id INVENTORY.equipment_id%TYPE;
    v_quantity     RENTAL_ITEMS.quantity%TYPE;
    v_dummy        NUMBER;
BEGIN
    -- Validate status
    IF p_condition_status NOT IN ('GOOD','DAMAGED','LOST') THEN
        RAISE_APPLICATION_ERROR(-20020, 'Invalid condition status');
    END IF;

    -- Lấy thông tin thiết bị và số lượng
    SELECT equipment_id, quantity
    INTO v_equipment_id, v_quantity
    FROM RENTAL_ITEMS
    WHERE rental_item_id = p_rental_item_id;

    -- Lock row inventory
    SELECT 1
    INTO v_dummy
    FROM INVENTORY
    WHERE equipment_id = v_equipment_id
    FOR UPDATE;

    -- Update kho dựa trên trạng thái trả
    IF p_condition_status = 'GOOD' THEN
        UPDATE INVENTORY
        SET available_quantity = NVL(available_quantity,0) + v_quantity,
            rented_quantity    = GREATEST(NVL(rented_quantity,0) - v_quantity,0),
            last_updated       = SYSDATE
        WHERE equipment_id = v_equipment_id;

    ELSIF p_condition_status = 'DAMAGED' THEN
        UPDATE INVENTORY
        SET damaged_quantity    = NVL(damaged_quantity,0) + v_quantity,
            rented_quantity     = GREATEST(NVL(rented_quantity,0) - v_quantity,0),
            last_updated        = SYSDATE
        WHERE equipment_id = v_equipment_id;

    ELSIF p_condition_status = 'LOST' THEN
        UPDATE INVENTORY
        SET lost_quantity       = NVL(lost_quantity,0) + v_quantity,
            rented_quantity     = GREATEST(NVL(rented_quantity,0) - v_quantity,0),
            last_updated        = SYSDATE
        WHERE equipment_id = v_equipment_id;
    END IF;

END;
/



--- 
CREATE OR REPLACE PROCEDURE SP_CREATE_RENTAL (
    p_customer_id       IN CHAR,
    p_employee_id       IN CHAR,
    p_shop_id           IN CHAR,
    p_equipment_id      IN CHAR,
    p_quantity          IN NUMBER,
    p_days              IN NUMBER,
    p_rental_date       IN DATE,
    p_due_date          IN DATE,
    p_customer_confirm  IN NUMBER DEFAULT 0  -- 0 = chưa đồng ý, 1 = đã đồng ý
)
IS
    v_rental_id        RENTALS.rental_id%TYPE;
    v_price            NUMBER(10,2);
    v_subtotal         NUMBER(10,2);
    v_deposit          NUMBER(10,2);
    v_high_value       NUMBER(1);

    -- snapshot thông tin khách
    v_customer_name    CUSTOMERS.full_name%TYPE;
    v_customer_phone   CUSTOMERS.phone%TYPE;
    v_customer_address CUSTOMERS.address%TYPE;

BEGIN
    ------------------------------------------------------
    -- 0. Kiểm tra khách đã đồng ý điều khoản chưa
    ------------------------------------------------------
    IF p_customer_confirm = 0 THEN
        RAISE_APPLICATION_ERROR(-20060,'Customer must accept terms before rental');
    END IF;

    ------------------------------------------------------
    -- 1. Lấy thông tin khách hàng để snapshot
    ------------------------------------------------------
    SELECT full_name, phone, address
    INTO v_customer_name, v_customer_phone, v_customer_address
    FROM CUSTOMERS
    WHERE customer_id = p_customer_id;

    ------------------------------------------------------
    -- 2. Lấy giá và thông tin thiết bị
    ------------------------------------------------------
    SELECT rental_price_per_day, is_high_value
    INTO v_price, v_high_value
    FROM EQUIPMENTS
    WHERE equipment_id = p_equipment_id;

    -- Tính subtotal và deposit
    v_subtotal := p_quantity * p_days * v_price;
    v_deposit  := FN_CALC_DEPOSIT(p_equipment_id) * p_quantity;

    -- Nếu thiết bị high-value, có thể yêu cầu manager approval
    IF v_high_value = 1 THEN
        -- Placeholder: logic approval có thể thêm ở đây
        NULL;
    END IF;

    ------------------------------------------------------
    -- 3. Insert vào RENTALS
    ------------------------------------------------------
    INSERT INTO RENTALS (
        rental_code, rental_type, status,
        total_amount, deposit_required,
        rental_date, due_date,
        created_at, updated_at,
        customer_id, employee_id, shop_id,
        customer_confirmed, confirmed_at,
        customer_name, customer_phone, customer_address,
        contract_terms
    )
    VALUES (
        NULL, -- trigger tự sinh rental_code
        'NORMAL',
        'CREATED',
        v_subtotal,
        v_deposit,
        p_rental_date,
        p_due_date,
        SYSDATE,
        SYSDATE,
        p_customer_id,
        p_employee_id,
        p_shop_id,
        1,
        SYSDATE,
        v_customer_name,
        v_customer_phone,
        v_customer_address,
        'Standard rental agreement'
    )
    RETURNING rental_id INTO v_rental_id;

    ------------------------------------------------------
    -- 4. Insert main equipment vào RENTAL_ITEMS
    ------------------------------------------------------
    INSERT INTO RENTAL_ITEMS (
        rental_id, equipment_id, quantity, days,
        price_per_day, subtotal, item_status
    )
    VALUES (
        v_rental_id,
        p_equipment_id,
        p_quantity,
        p_days,
        v_price,
        v_subtotal,
        'BORROWING'
    );

    -- Trừ kho main item
    SP_UPDATE_INVENTORY_ON_RENT(p_equipment_id, p_quantity);

    ------------------------------------------------------
    -- 5. Xử lý phụ kiện mặc định
    ------------------------------------------------------
    FOR acc IN (
        SELECT accessory_id, quantity
        FROM EQUIPMENT_ACCESSORIES
        WHERE equipment_id = p_equipment_id
    )
    LOOP
        -- Kiểm tra tương thích
        SP_CHECK_COMPATIBILITY(p_equipment_id, acc.accessory_id);

        -- Insert phụ kiện
        INSERT INTO RENTAL_ITEMS (
            rental_id, equipment_id, quantity, days,
            price_per_day, subtotal, item_status
        )
        VALUES (
            v_rental_id,
            acc.accessory_id,
            acc.quantity * p_quantity,
            p_days,
            0,
            0,
            'BORROWING'
        );

        -- Trừ kho phụ kiện
        SP_UPDATE_INVENTORY_ON_RENT(acc.accessory_id, acc.quantity * p_quantity);
    END LOOP;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20050, 'Customer or equipment not found');

    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

---
CREATE OR REPLACE PROCEDURE SP_CREATE_DEPOSIT_PAYMENT (
    p_rental_id      IN CHAR,
    p_payment_method IN VARCHAR2
)
IS
    v_count            NUMBER;
    v_exist            NUMBER;
    v_deposit_amount   NUMBER(10,2);
    v_payment_id       CHAR(5);
BEGIN
    --------------------------------------------------
    -- 1. CHECK RENTAL EXIST
    --------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM RENTALS
    WHERE rental_id = p_rental_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Rental not found');
    END IF;

    --------------------------------------------------
    -- 2. CHECK RENTAL ITEMS EXIST (QUAN TRỌNG)
    --------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM RENTAL_ITEMS
    WHERE rental_id = p_rental_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'No rental items found');
    END IF;

    --------------------------------------------------
    -- 3. CHECK ALREADY HAS DEPOSIT
    --------------------------------------------------
    SELECT COUNT(*) INTO v_exist
    FROM DEPOSITS
    WHERE rental_id = p_rental_id;

    IF v_exist > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Deposit already exists');
    END IF;

    --------------------------------------------------
    -- 4. CALCULATE DEPOSIT (CHỈ TÍNH MAIN EQUIPMENT)
    --------------------------------------------------
    SELECT NVL(SUM(FN_CALC_DEPOSIT(E.EQUIPMENT_ID) * R.QUANTITY),0)
    INTO v_deposit_amount
    FROM RENTAL_ITEMS R
    JOIN EQUIPMENTS E ON R.EQUIPMENT_ID = E.EQUIPMENT_ID
    WHERE R.RENTAL_ID = p_rental_id
      AND E.DEPOSIT_RATE > 0; -- Chỉ tính main

    IF v_deposit_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid deposit amount');
    END IF;

    --------------------------------------------------
    -- 5. INSERT PAYMENT (TRIGGER sẽ sinh PAYMENT_ID)
    --    và lấy PAYMENT_ID vừa sinh
    --------------------------------------------------
    INSERT INTO PAYMENTS (
        payment_method,
        payment_type,
        payment_status,
        transaction_code,
        amount,
        payment_date,
        created_at,
        rental_id
    )
    VALUES (
        p_payment_method,
        'DEPOSIT',
        'COMPLETED',
        NULL,               -- trigger sẽ sinh transaction_code
        v_deposit_amount,
        SYSDATE,
        SYSDATE,
        p_rental_id
    )
    RETURNING payment_id INTO v_payment_id;

    --------------------------------------------------
    -- 6. INSERT DEPOSIT (TRIGGER sẽ sinh DEPOSIT_ID)
    --------------------------------------------------
    INSERT INTO DEPOSITS (
        deposit_amount,
        status,
        deposit_date,
        created_at,
        rental_id,
        payment_id
    )
    VALUES (
        v_deposit_amount,
        'HELD',
        SYSDATE,
        SYSDATE,
        p_rental_id,
        v_payment_id
    );

    --------------------------------------------------
    -- 7. UPDATE RENTALS
    --------------------------------------------------
    UPDATE RENTALS
    SET deposit_required = v_deposit_amount,
        updated_at = SYSDATE
    WHERE rental_id = p_rental_id;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

---
CREATE OR REPLACE PROCEDURE SP_CONFIRM_PICKUP (
    p_rental_id IN CHAR
)
IS
    v_dummy NUMBER;
BEGIN
    -- 1. Kiểm tra rental tồn tại và trạng thái hợp lệ
    BEGIN
        SELECT 1 INTO v_dummy
        FROM RENTALS
        WHERE rental_id = p_rental_id
          AND status IN ('CREATED','CONFIRMED');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Rental không tồn tại hoặc không hợp lệ để confirm pickup.');
    END;

    -- 2. Cập nhật RENTALS trạng thái BORROWING và timestamp
    UPDATE RENTALS
    SET status = 'BORROWING',
        customer_confirmed = 1,
        confirmed_at = SYSDATE,
        start_date = SYSDATE,
        updated_at = SYSDATE
    WHERE rental_id = p_rental_id;

    -- 3. Cập nhật tất cả RENTAL_ITEMS sang BORROWING
    UPDATE RENTAL_ITEMS
    SET item_status = 'BORROWING'
    WHERE rental_id = p_rental_id;

    -- 4. Tạo placeholder media BEFORE_DELIVERY
    FOR rec IN (SELECT rental_item_id FROM RENTAL_ITEMS WHERE rental_id = p_rental_id)
    LOOP
        INSERT INTO RENTAL_ITEM_MEDIA(
            media_id,
            rental_item_id,
            media_type,
            media_path,
            capture_stage,
            created_at
        ) VALUES (
            gen_code('MD','seq_rental_item_media',5),
            rec.rental_item_id,
            'IMAGE',
            'placeholder_before_delivery.jpg',
            'BEFORE_DELIVERY',
            SYSDATE
        );
    END LOOP;

    -- **Không cần log ở đây, trigger tự động xử lý**
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END SP_CONFIRM_PICKUP;
/



--- 
CREATE OR REPLACE PROCEDURE SP_CREATE_INVOICE (
    p_rental_id IN CHAR
)
IS
    v_count           NUMBER;
    v_invoice_id      CHAR(5);
    v_invoice_number  VARCHAR2(20);
    v_rental_amount   NUMBER(10,2) := 0;
    v_late_fee        NUMBER(10,2) := 0;
    v_damage_fee      NUMBER(10,2) := 0;
    v_shipping_fee    NUMBER(10,2) := 0;
    v_deposit_used    NUMBER(10,2) := 0;
    v_subtotal        NUMBER(10,2) := 0;
    v_final_amount    NUMBER(10,2) := 0;
    v_tax_id          CHAR(5);
    v_tax_rate        NUMBER(5,2) := 0;
    v_tax_amount      NUMBER(10,2) := 0;
    v_customer_id     CHAR(5);
    v_rental_status   RENTALS.status%TYPE;
BEGIN
    -- 1. Lấy rental info và customer_id
    SELECT customer_id, status
    INTO v_customer_id, v_rental_status
    FROM RENTALS
    WHERE rental_id = p_rental_id;

    IF v_customer_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001,'Rental not found');
    END IF;

    -- 2. Chỉ tạo invoice nếu rental đang ACTIVE
    IF v_rental_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20002,'Invoice can only be created for ACTIVE rentals');
    END IF;

    -- 3. Tính rental_amount
    SELECT NVL(SUM(subtotal),0)
    INTO v_rental_amount
    FROM RENTAL_ITEMS
    WHERE rental_id = p_rental_id;

    -- 4. Tính late_fee
    v_late_fee := FN_CALC_LATE_FEE(p_rental_id);

    -- 5. Tính damage_fee
    FOR r IN (
        SELECT r.return_id
        FROM RETURNS r
        JOIN RENTAL_ITEMS ri ON r.rental_item_id = ri.rental_item_id
        WHERE ri.rental_id = p_rental_id
    )
    LOOP
        v_damage_fee := v_damage_fee + FN_CALC_DAMAGE_FEE(r.return_id);
    END LOOP;

    -- 6. Tính shipping_fee (OUTBOUND)
    v_shipping_fee := FN_CALC_SHIPPING_FEE(p_rental_id);

    -- 7. Lấy tổng deposit_used
    SELECT NVL(SUM(deposit_amount),0)
    INTO v_deposit_used
    FROM DEPOSITS
    WHERE rental_id = p_rental_id;

    -- 8. Tính subtotal
    v_subtotal := v_rental_amount + v_late_fee + v_damage_fee + v_shipping_fee;

    -- 9. Lấy TAX mặc định (active)
    SELECT tax_id, tax_rate
    INTO v_tax_id, v_tax_rate
    FROM TAXES
    WHERE is_active = 1
      AND SYSDATE BETWEEN effective_from AND effective_to
      AND ROWNUM = 1;

    -- 10. Tính tax_amount
    v_tax_amount := ROUND(v_subtotal * v_tax_rate / 100, 2);

    -- 11. Tính final_amount (không âm)
    v_final_amount := v_subtotal + v_tax_amount - v_deposit_used;
    IF v_final_amount < 0 THEN
        v_final_amount := 0;
    END IF;

    -- 12. Insert vào INVOICES (id & number do trigger sinh tự động)
    INSERT INTO INVOICES (
        status,
        rental_amount,
        late_fee,
        damage_fee,
        shipping_fee,
        subtotal_amount,
        tax_id,
        tax_amount,
        total_amount,
        deposit_used,
        final_amount,
        invoice_date,
        payment_due_date,
        created_at,
        invoice_type,
        rental_id
    )
    VALUES (
        'PENDING',
        v_rental_amount,
        v_late_fee,
        v_damage_fee,
        v_shipping_fee,
        v_subtotal,
        v_tax_id,
        v_tax_amount,
        v_subtotal + v_tax_amount,
        v_deposit_used,
        v_final_amount,
        SYSDATE,
        SYSDATE + 7,
        SYSDATE,
        'FINAL',
        p_rental_id
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_CREATE_INVOICE;
/

---
CREATE OR REPLACE PROCEDURE SP_PAY_INVOICE (
    p_invoice_id IN CHAR,
    p_payment_method IN VARCHAR2
)
IS
    v_final_amount NUMBER(10,2);
    v_rental_id CHAR(5);
BEGIN
    -- 1️ Lấy thông tin invoice và rental_id
    SELECT final_amount, rental_id
    INTO v_final_amount, v_rental_id
    FROM INVOICES
    WHERE invoice_id = p_invoice_id
      AND status = 'PENDING';

    IF v_final_amount IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010,'Invoice không tồn tại hoặc đã thanh toán');
    END IF;

    -- 2️ Cập nhật trạng thái invoice
    UPDATE INVOICES
    SET status = 'PAID'
    WHERE invoice_id = p_invoice_id;

    -- 3️ Tạo bản ghi thanh toán trong PAYMENTS
    INSERT INTO PAYMENTS(
        payment_id,
        payment_method,
        payment_type,
        payment_status,
        amount,
        payment_date,
        created_at,
        invoice_id,
        rental_id
    ) VALUES (
        gen_code('PM','seq_payments',5),
        p_payment_method,
        'RENTAL',         -- thanh toán cuối cùng
        'COMPLETED',
        v_final_amount,
        SYSDATE,
        SYSDATE,
        p_invoice_id,
        v_rental_id
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_PAY_INVOICE;
/

---
CREATE OR REPLACE PROCEDURE SP_PROCESS_REFUND (
    p_rental_id IN RENTALS.rental_id%TYPE
)
IS
    -- Cursor lấy deposit cần xử lý
    CURSOR c_deposits IS
        SELECT deposit_id, deposit_amount, status
        FROM DEPOSITS
        WHERE rental_id = p_rental_id
          AND status IN ('HELD','USED')
        FOR UPDATE;

    v_deposit_rec c_deposits%ROWTYPE;
    v_refund_amount NUMBER := 0;

    -- Phí
    v_late_fee   NUMBER := 0;
    v_damage_fee NUMBER := 0;

    -- Payment
    v_payment_id PAYMENTS.payment_id%TYPE;

BEGIN
    -- 1. Tính phí trễ hạn
    v_late_fee := FN_CALC_LATE_FEE(p_rental_id);

    -- 2. Tính tổng phí hư hỏng (sum tất cả return)
    v_damage_fee := 0;
    FOR r IN (
        SELECT r.return_id
        FROM RETURNS r
        JOIN RENTAL_ITEMS ri ON r.rental_item_id = ri.rental_item_id
        WHERE ri.rental_id = p_rental_id
    )
    LOOP
        v_damage_fee := v_damage_fee + FN_CALC_DAMAGE_FEE(r.return_id);
    END LOOP;

    -- 3. Xử lý tất cả deposit
    OPEN c_deposits;
    LOOP
        FETCH c_deposits INTO v_deposit_rec;
        EXIT WHEN c_deposits%NOTFOUND;

        -- Tính số tiền hoàn
        v_refund_amount := v_deposit_rec.deposit_amount - v_late_fee - v_damage_fee;
        IF v_refund_amount < 0 THEN
            v_refund_amount := 0;
        END IF;

        -- Tạo payment REFUND
        v_payment_id := 'P' || TO_CHAR(SEQ_PAYMENTS.NEXTVAL,'FM0000');

        INSERT INTO PAYMENTS (
            payment_id,
            payment_method,
            payment_type,
            payment_status,
            amount,
            payment_date,
            created_at,
            rental_id
        ) VALUES (
            v_payment_id,
            'CASH',
            'REFUND',
            'COMPLETED',
            v_refund_amount,
            SYSDATE,
            SYSDATE,
            p_rental_id
        );

        -- Cập nhật deposit
        UPDATE DEPOSITS
        SET refund_amount = v_refund_amount,
            refund_date   = SYSDATE,
            status = CASE
                        WHEN v_refund_amount = v_deposit_rec.deposit_amount THEN 'REFUNDED'
                        ELSE 'PARTIAL_REFUND'
                     END
        WHERE deposit_id = v_deposit_rec.deposit_id;

    END LOOP;
    CLOSE c_deposits;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Refund processed successfully for rental: ' || p_rental_id
                         || ', refund amount: ' || v_refund_amount);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No deposit found to refund for rental: ' || p_rental_id);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END SP_PROCESS_REFUND;
/

------------------------------------------------------------
-- SP_COMPLETE_RENTAL
CREATE OR REPLACE PROCEDURE SP_COMPLETE_RENTAL (
    p_rental_id IN CHAR
)
IS
    v_status RENTALS.status%TYPE;
BEGIN
    -- 1. Kiểm tra rental tồn tại và trạng thái hợp lệ để hoàn
    BEGIN
        SELECT status
        INTO v_status
        FROM RENTALS
        WHERE rental_id = p_rental_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Rental không tồn tại');
    END;

    IF v_status NOT IN ('BORROWING','OVERDUE') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Rental không hợp lệ để hoàn');
    END IF;

    -- 2. Cập nhật trạng thái rental hoàn và ngày trả
    UPDATE RENTALS
    SET status = 'RETURNED',
        return_date = SYSDATE,
        updated_at = SYSDATE
    WHERE rental_id = p_rental_id;

    -- 3. Trả kho tất cả thiết bị
    FOR rec IN (
        SELECT rental_item_id, equipment_id, quantity
        FROM RENTAL_ITEMS
        WHERE rental_id = p_rental_id
    )
    LOOP
        -- gọi procedure trả kho
        SP_UPDATE_INVENTORY_ON_RETURN(rec.rental_item_id, 'GOOD');

        -- cập nhật trạng thái item
        UPDATE RENTAL_ITEMS
        SET item_status = 'RETURNED'
        WHERE rental_item_id = rec.rental_item_id;
    END LOOP;

    -- 4. Nếu chưa có hóa đơn cuối cùng, tạo invoice
    DECLARE
        v_invoice_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_invoice_count
        FROM INVOICES
        WHERE rental_id = p_rental_id
          AND invoice_type = 'FINAL';

        IF v_invoice_count = 0 THEN
            SP_CREATE_INVOICE(p_rental_id);
        END IF;
    END;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_COMPLETE_RENTAL;
/