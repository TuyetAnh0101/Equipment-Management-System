---------------
--- FUNCTION
---------------

--- Function tính giá trị còn lại của thiết bị theo thời gian sử dụng
CREATE OR REPLACE FUNCTION FN_CALC_EQUIPMENT_VALUE (
    p_purchase_price     NUMBER,
    p_depreciation_rate  NUMBER,
    p_purchase_date      DATE
)
RETURN NUMBER
IS
    v_years_used   NUMBER;
    v_value        NUMBER;
BEGIN
    -- Tính số năm sử dụng
    v_years_used := MONTHS_BETWEEN(SYSDATE, p_purchase_date) / 12;

    -- Tính giá trị còn lại
    v_value := p_purchase_price 
               - (p_purchase_price * p_depreciation_rate * v_years_used);

    -- Không cho âm
    IF v_value < 0 THEN
        v_value := 0;
    END IF;

    RETURN ROUND(v_value, 2);
END;
/

---------
-- Test
---------
SELECT FN_CALC_EQUIPMENT_VALUE(
    50000000,   -- purchase_price (50 triệu)
    0.10,       -- depreciation_rate (10%/năm)
    DATE '2022-01-01'
) AS equipment_value
FROM dual;


--- Function Tính tiền cọc cho 1 thiết bị cụ thể
CREATE OR REPLACE FUNCTION FN_CALC_DEPOSIT (
    p_equipment_id EQUIPMENTS.equipment_id%TYPE
)
RETURN NUMBER
IS
    v_purchase_price     NUMBER;
    v_depreciation_rate  NUMBER;
    v_purchase_date      DATE;
    v_deposit_rate       NUMBER;

    v_equipment_value    NUMBER;
    v_deposit            NUMBER;
BEGIN
    --------------------------------------------------
    -- 1. LẤY THÔNG TIN EQUIPMENT
    --------------------------------------------------
    SELECT 
        purchase_price,
        depreciation_rate,
        purchase_date,
        NVL(deposit_rate, 0)
    INTO 
        v_purchase_price,
        v_depreciation_rate,
        v_purchase_date,
        v_deposit_rate
    FROM EQUIPMENTS
    WHERE equipment_id = p_equipment_id;

    --------------------------------------------------
    -- 2. NẾU deposit_rate = 0 → RETURN 0 (ACCESSORY)
    --------------------------------------------------
    IF v_deposit_rate = 0 THEN
        RETURN 0;
    END IF;

    --------------------------------------------------
    -- 3. TÍNH GIÁ TRỊ THIẾT BỊ
    --------------------------------------------------
    v_equipment_value := FN_CALC_EQUIPMENT_VALUE(
        v_purchase_price,
        v_depreciation_rate,
        v_purchase_date
    );

    --------------------------------------------------
    -- 4. TÍNH DEPOSIT
    --------------------------------------------------
    v_deposit := v_equipment_value * v_deposit_rate;

    RETURN ROUND(v_deposit, 2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/

----------
--- TEST
----------
SELECT FN_CALC_EQUIPMENT_VALUE(
    e.purchase_price,
    e.depreciation_rate,
    e.purchase_date
) AS equipment_value
FROM EQUIPMENTS e;


--- Function nghiệp vụ tính phí trả trễ
CREATE OR REPLACE FUNCTION FN_CALC_LATE_FEE (
    p_rental_id IN RENTALS.rental_id%TYPE
)
RETURN NUMBER
IS
    v_due_date      DATE;
    v_return_date   DATE;
    v_days_late     NUMBER := 0;
    v_total_price   NUMBER := 0;
    v_late_fee      NUMBER := 0;
BEGIN
    -- 1. Lấy due_date
    SELECT due_date
    INTO v_due_date
    FROM RENTALS
    WHERE rental_id = p_rental_id;

    -- 2. Lấy return_date (JOIN đúng chuẩn)
    SELECT MAX(r.return_date)
    INTO v_return_date
    FROM RETURNS r
    JOIN RENTAL_ITEMS ri 
        ON r.rental_item_id = ri.rental_item_id
    WHERE ri.rental_id = p_rental_id;

    -- 3. Nếu chưa trả
    IF v_return_date IS NULL THEN
        RETURN 0;
    END IF;

    -- 4. Tính ngày trễ
    v_days_late := v_return_date - v_due_date;

    IF v_days_late <= 0 THEN
        RETURN 0;
    END IF;

    -- 5. Tổng giá thuê/ngày
    SELECT SUM(price_per_day * quantity)
    INTO v_total_price
    FROM RENTAL_ITEMS
    WHERE rental_id = p_rental_id;

    -- 6. Late fee
    v_late_fee := v_days_late * v_total_price * 1.5;

    RETURN v_late_fee;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/

----------
-- TEST
----------
SELECT 
    r.rental_id,
    r.due_date,
    MAX(rt.return_date) AS actual_return,
    FN_CALC_LATE_FEE(r.rental_id) AS late_fee
FROM RENTALS r
LEFT JOIN RENTAL_ITEMS ri ON r.rental_id = ri.rental_id
LEFT JOIN RETURNS rt ON ri.rental_item_id = rt.rental_item_id
GROUP BY r.rental_id, r.due_date;



--- Function nghiệp vụ tính tiền bồi thường thiết bị
CREATE OR REPLACE FUNCTION FN_CALC_DAMAGE_FEE (
    p_return_id IN CHAR
) RETURN NUMBER
IS
    -- Biến lấy dữ liệu từ RETURNS, RENTAL_ITEMS, EQUIPMENTS
    v_damage_percent     RETURNS.damage_percent%TYPE := 0;
    v_quantity           RENTAL_ITEMS.quantity%TYPE := 1;
    v_condition_status   RETURNS.condition_status%TYPE;
    
    v_purchase_price     EQUIPMENTS.purchase_price%TYPE;
    v_depreciation_rate  EQUIPMENTS.depreciation_rate%TYPE;
    v_purchase_date      EQUIPMENTS.purchase_date%TYPE;
    
    v_equipment_value    NUMBER := 0;
    v_damage_fee         NUMBER(10,2) := 0;
BEGIN
    --------------------------------------------------
    -- 1. LẤY DỮ LIỆU
    --------------------------------------------------
    SELECT 
        NVL(r.damage_percent, 0),
        NVL(ri.quantity, 1),
        r.condition_status,
        e.purchase_price,
        e.depreciation_rate,
        e.purchase_date
    INTO 
        v_damage_percent,
        v_quantity,
        v_condition_status,
        v_purchase_price,
        v_depreciation_rate,
        v_purchase_date
    FROM RETURNS r
    JOIN RENTAL_ITEMS ri ON r.rental_item_id = ri.rental_item_id
    JOIN EQUIPMENTS e ON ri.equipment_id = e.equipment_id
    WHERE r.return_id = p_return_id;

    --------------------------------------------------
    -- 2. TÍNH GIÁ TRỊ THIẾT BỊ
    --------------------------------------------------
    v_equipment_value := FN_CALC_EQUIPMENT_VALUE(
        v_purchase_price,
        v_depreciation_rate,
        v_purchase_date
    );

    --------------------------------------------------
    -- 3. KHÔNG HƯ HỎNG → 0
    --------------------------------------------------
    IF v_condition_status = 'GOOD' THEN
        RETURN 0;
    END IF;

    --------------------------------------------------
    -- 4. MẤT → 100%
    --------------------------------------------------
    IF v_condition_status = 'LOST' THEN
        RETURN ROUND(v_equipment_value * v_quantity, 2);
    END IF;

    --------------------------------------------------
    -- 5. DAMAGE PERCENT = 0 → 0
    --------------------------------------------------
    IF v_damage_percent = 0 THEN
        RETURN 0;
    END IF;

    --------------------------------------------------
    -- 6. TÍNH DAMAGE FEE (CÓ QUANTITY)
    --------------------------------------------------
    v_damage_fee := v_equipment_value 
                    * v_quantity 
                    * (v_damage_percent / 100);

    RETURN ROUND(v_damage_fee, 2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END FN_CALC_DAMAGE_FEE;
/
--------
--TEST
--------
SELECT 
    return_id,
    FN_CALC_DAMAGE_FEE(return_id) AS damage_fee
FROM RETURNS;


--- Function tính số tiền cuối cùng khách phải trả sau khi đã tính phí + thuế + trừ tiền cọc
CREATE OR REPLACE FUNCTION FN_CALC_INVOICE_TOTAL (
    p_rental_amount   IN NUMBER,
    p_late_fee        IN NUMBER,
    p_damage_fee      IN NUMBER,
    p_shipping_fee    IN NUMBER,
    p_tax_id          IN CHAR,
    p_deposit_used    IN NUMBER
) RETURN NUMBER
IS
    v_tax_rate      NUMBER(5,2) := 0;
    v_subtotal      NUMBER(10,2);
    v_tax_amount    NUMBER(10,2);
    v_total         NUMBER(10,2);
    v_final_amount  NUMBER(10,2);
BEGIN
    -- Lấy thuế
    SELECT NVL(tax_rate, 0)
    INTO v_tax_rate
    FROM TAXES
    WHERE tax_id = p_tax_id;

    -- Subtotal
    v_subtotal := NVL(p_rental_amount,0)
                + NVL(p_late_fee,0)
                + NVL(p_damage_fee,0)
                + NVL(p_shipping_fee,0);

    -- Tax
    v_tax_amount := v_subtotal * v_tax_rate / 100;

    -- Total
    v_total := v_subtotal + v_tax_amount;

    -- Final (không âm)
    v_final_amount := v_total - NVL(p_deposit_used,0);

    IF v_final_amount < 0 THEN
        v_final_amount := 0;
    END IF;

    RETURN ROUND(v_final_amount, 2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/

----------
--- TEST
----------
SELECT 
    i.invoice_id,
    FN_CALC_INVOICE_TOTAL(
        i.rental_amount,
        i.late_fee,
        i.damage_fee,
        i.shipping_fee,
        i.tax_id,
        i.deposit_used
    ) AS CALCULATED_FINAL,
    i.final_amount
FROM INVOICES i;

--- Function tính phí vận chuyển dựa trên khoảng cách giữa shop và khách hàng
CREATE OR REPLACE FUNCTION FN_CALC_SHIPPING_FEE (
    p_rental_id IN RENTALS.rental_id%TYPE
) RETURN NUMBER
IS
    v_shop_lat NUMBER(9,6);
    v_shop_lon NUMBER(9,6);
    v_cust_lat NUMBER(9,6);
    v_cust_lon NUMBER(9,6);
    v_distance_km NUMBER(10,2);
    v_fee NUMBER(10,2) := 0;

    v_shipping_method RENTALS.status%TYPE;
    v_shipment_type SHIPMENTS.shipment_type%TYPE;

    pi_val CONSTANT NUMBER := 3.141592653589793;
    earth_radius_km CONSTANT NUMBER := 6371;
BEGIN
    -- 1. Lấy thông tin shop + khách + phương thức vận chuyển
    SELECT s.latitude, s.longitude, c.latitude, c.longitude, r.rental_type
    INTO v_shop_lat, v_shop_lon, v_cust_lat, v_cust_lon, v_shipping_method
    FROM RENTALS r
    JOIN SHOP_INFO s ON r.shop_id = s.shop_id
    JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    WHERE r.rental_id = p_rental_id;

    -- PICKUP → miễn phí
    IF UPPER(v_shipping_method) = 'PICKUP' THEN
        RETURN 0;
    END IF;

    -- Validate tọa độ
    IF v_shop_lat IS NULL OR v_shop_lon IS NULL THEN
        RAISE_APPLICATION_ERROR(-20022,'Shop coordinates missing');
    END IF;
    IF v_cust_lat IS NULL OR v_cust_lon IS NULL THEN
        RAISE_APPLICATION_ERROR(-20020,'Customer coordinates missing');
    END IF;

    -- RETURN shipment → miễn phí
    IF UPPER(v_shipping_method) = 'RETURN' THEN
        RETURN 0;
    END IF;

    -- Haversine formula
    v_distance_km := earth_radius_km * ACOS(
        COS(v_shop_lat * pi_val / 180) * COS(v_cust_lat * pi_val / 180) *
        COS((v_cust_lon - v_shop_lon) * pi_val / 180) +
        SIN(v_shop_lat * pi_val / 180) * SIN(v_cust_lat * pi_val / 180)
    );

    -- Tính phí vận chuyển
    IF v_distance_km < 5 THEN
        v_fee := 20000;
    ELSIF v_distance_km < 10 THEN
        v_fee := 50000;
    ELSIF v_distance_km <= 20 THEN
        v_fee := 70000;
    ELSE
        RAISE_APPLICATION_ERROR(-20021,'Shipping not supported');
    END IF;

    RETURN v_fee;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20023,'Rental or customer/shop data not found');
END FN_CALC_SHIPPING_FEE;
/
----------
--- TEST
----------
SELECT 
    r.rental_id,
    SUM(s.shipping_fee) AS total_shipping_fee
FROM SHIPMENTS s
JOIN RENTALS r ON s.rental_id = r.rental_id
GROUP BY r.rental_id;