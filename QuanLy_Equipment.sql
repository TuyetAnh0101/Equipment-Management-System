-- =========================
-- 1. MASTER TABLES
-- =========================
CREATE TABLE SHOP_INFO (
    shop_id CHAR(5) PRIMARY KEY,
    shop_name VARCHAR2(100) NOT NULL,
    shop_address VARCHAR2(255) NOT NULL,
    city VARCHAR2(50) NOT NULL,
    district VARCHAR2(50) NOT NULL,
    created_at DATE NOT NULL,
    latitude  NUMBER(9,6),
    longitude NUMBER(9,6)
);

CREATE TABLE CUSTOMERS (
    customer_id CHAR(5) PRIMARY KEY,
    username VARCHAR2(50) NOT NULL UNIQUE,
    password_hash VARCHAR2(255) NOT NULL,
    full_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) NOT NULL UNIQUE,
    phone VARCHAR2(15) NOT NULL,
    address VARCHAR2(255) NOT NULL,
    status VARCHAR2(20) NOT NULL CHECK (status IN ('ACTIVE','INACTIVE')),
    created_at DATE NOT NULL,
    latitude  NUMBER(9,6),
    longitude NUMBER(9,6)
);


CREATE TABLE EMPLOYEES (
    employee_id CHAR(5) PRIMARY KEY,
    username VARCHAR2(50) NOT NULL UNIQUE,
    password_hash VARCHAR2(255) NOT NULL,
    full_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) NOT NULL UNIQUE,
    phone VARCHAR2(15) NOT NULL,
    role VARCHAR2(50) NOT NULL,
    status VARCHAR2(20) NOT NULL CHECK (status IN ('ACTIVE','INACTIVE')),
    created_at DATE NOT NULL
);

CREATE TABLE CATEGORIES (
    category_id CHAR(5) PRIMARY KEY,
    category_name VARCHAR2(100) NOT NULL,
    description VARCHAR2(255) NOT NULL,
    created_at DATE NOT NULL
);

-- =========================
-- BẢNG EQUIPMENTS HOÀN CHỈNH 
-- =========================

CREATE TABLE EQUIPMENTS (
    equipment_id CHAR(5) PRIMARY KEY,
    equipment_name VARCHAR2(100) NOT NULL,
    
    -- Phân loại MAIN hay ACCESSORY
    equipment_type VARCHAR2(50) NOT NULL 
        CHECK (equipment_type IN ('MAIN','ACCESSORY')),
    
    -- Trạng thái thiết bị
    status VARCHAR2(20) NOT NULL 
        CHECK (status IN ('AVAILABLE','MAINTENANCE','DISABLED')),
    
    -- Thông tin mô tả kỹ thuật / markdown / bảng
    description VARCHAR2(1000),
    
    -- Giá trị thiết bị, tính bằng DB
    equipment_value NUMBER(10,2) NOT NULL,
    purchase_price NUMBER(10,2) NOT NULL,
    rental_price_per_day NUMBER(10,2) NOT NULL,
    depreciation_rate NUMBER(5,2) NOT NULL,
    total_usage_days NUMBER(5) NOT NULL,
    purchase_date DATE NOT NULL,
    
    -- Thông tin kiểm tra tương thích
    brand VARCHAR2(50),
    model VARCHAR2(50),
    mount_type VARCHAR2(50),
    category_id CHAR(5),
    
    -- Thiết bị giá trị cao
    is_high_value NUMBER(1) DEFAULT 0,
    
    -- Deposit mặc định
    deposit_rate NUMBER(5,2) DEFAULT 0.2,
    
    -- Ngày tạo
    created_at DATE NOT NULL,
    
     FOREIGN KEY (category_id) REFERENCES CATEGORIES(category_id)
);
-- =========================
-- 2. RENTAL CORE
-- =========================
CREATE TABLE RENTALS (
    rental_id CHAR(5) PRIMARY KEY,
    rental_code VARCHAR2(20) NOT NULL UNIQUE,

    rental_type VARCHAR2(50) NOT NULL,

    status VARCHAR2(20) NOT NULL 
    CHECK (status IN (
        'CREATED',
        'CONFIRMED',
        'BORROWING',
        'RETURNED',
        'OVERDUE',
        'CANCELLED'
    )),
    payment_status VARCHAR2(20)
    CHECK (payment_status IN ('UNPAID','PARTIAL','PAID')),

    notes VARCHAR2(255),

    -- tiền
    total_amount NUMBER(10,2) NOT NULL,
    deposit_required NUMBER(10,2) NOT NULL,

    -- thời gian
    rental_date DATE NOT NULL,   -- ngày tạo đơn
    start_date DATE,             -- ngày bắt đầu thuê
    due_date DATE NOT NULL,
    return_date DATE,

    created_at DATE NOT NULL,
    updated_at DATE NOT NULL,

    -- FK
    customer_id CHAR(5) NOT NULL,
    employee_id CHAR(5) NOT NULL,
    shop_id CHAR(5) NOT NULL,

    -- snapshot (PHÁP LÝ)
    customer_name VARCHAR2(100),
    customer_phone VARCHAR2(15),
    customer_address VARCHAR2(255),

    -- xác nhận (PHÁP LÝ)
    customer_confirmed NUMBER(1) DEFAULT 0,
    confirmed_at DATE,

    -- điều khoản
    contract_terms VARCHAR2(1000),

    FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id),
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEES(employee_id),
    FOREIGN KEY (shop_id) REFERENCES SHOP_INFO(shop_id)
);

CREATE TABLE RENTAL_ITEMS (
    rental_item_id CHAR(5) PRIMARY KEY,
    rental_id CHAR(5) NOT NULL,
    equipment_id CHAR(5) NOT NULL,
    quantity NUMBER(5) NOT NULL,
    days NUMBER(5) NOT NULL,
    price_per_day NUMBER(10,2) NOT NULL,
    subtotal NUMBER(10,2) NOT NULL,
    item_status VARCHAR2(20) NOT NULL 
        CHECK (item_status IN ('BORROWING','RETURNED','DAMAGED','LOST')),
    FOREIGN KEY (rental_id) REFERENCES RENTALS(rental_id),
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENTS(equipment_id)
);

CREATE TABLE RENTAL_ITEM_MEDIA (
    media_id CHAR(5) PRIMARY KEY,
    rental_item_id CHAR(5) NOT NULL,
    media_type VARCHAR2(10) CHECK (media_type IN ('IMAGE','VIDEO')),
    media_path VARCHAR2(255) NOT NULL,
    capture_stage VARCHAR2(20) NOT NULL 
        CHECK (capture_stage IN ('BEFORE_DELIVERY','AFTER_RETURN')), -- trạng thái trước khi giao hoặc sau khi trả
    created_at DATE NOT NULL,
    FOREIGN KEY (rental_item_id) REFERENCES RENTAL_ITEMS(rental_item_id)
);

CREATE TABLE RETURNS (
    return_id CHAR(5) PRIMARY KEY,

    return_date DATE NOT NULL,

    condition_status VARCHAR2(50) NOT NULL
        CHECK (condition_status IN (
            'GOOD',
            'DAMAGED',
            'BROKEN',
            'LOST'
        )),

    damage_percent NUMBER(5,2) 
        CHECK (damage_percent BETWEEN 0 AND 100),  -- OK


    damage_fee NUMBER(10,2) DEFAULT 0,
    late_fee NUMBER(10,2) DEFAULT 0,

    notes VARCHAR2(255),

    inspection_status VARCHAR2(20) DEFAULT 'PENDING'
        CHECK (inspection_status IN (
            'PENDING',
            'CHECKED',
            'CONFIRMED'
        )),
    checked_by CHAR(5),
    checked_at DATE,

    rental_item_id CHAR(5) NOT NULL,

    FOREIGN KEY (rental_item_id) REFERENCES RENTAL_ITEMS(rental_item_id),
    FOREIGN KEY (checked_by) REFERENCES EMPLOYEES(employee_id)
);
-- =========================
-- 3. PAYMENT / INVOICE
-- =========================

CREATE TABLE TAXES (
    tax_id CHAR(5) PRIMARY KEY,
    tax_name VARCHAR2(100) NOT NULL,
    description VARCHAR2(255) NOT NULL,
    tax_rate NUMBER(5,2) NOT NULL,
    is_active NUMBER(1) CHECK (is_active IN (0,1)) NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE NOT NULL,
    created_at DATE NOT NULL,
    updated_at DATE NOT NULL
);

CREATE TABLE INVOICES (
    invoice_id CHAR(5) PRIMARY KEY,

    invoice_number VARCHAR2(20) NOT NULL UNIQUE,

    status VARCHAR2(20) NOT NULL
        CHECK (status IN (
            'PENDING',     -- chưa thanh toán
            'PAID',        -- đã thanh toán
            'PARTIAL',     -- thanh toán 1 phần
            'CANCELLED'
        )),

    notes VARCHAR2(255),

    rental_amount NUMBER(10,2) NOT NULL,

    late_fee NUMBER(10,2) DEFAULT 0,
    damage_fee NUMBER(10,2) DEFAULT 0,
    shipping_fee NUMBER(10,2) DEFAULT 0,

    subtotal_amount NUMBER(10,2) NOT NULL,

    tax_amount NUMBER(10,2) NOT NULL,

    total_amount NUMBER(10,2) NOT NULL,

    deposit_used NUMBER(10,2) DEFAULT 0,

    final_amount NUMBER(10,2) NOT NULL,

    invoice_date DATE NOT NULL,
    payment_due_date DATE NOT NULL,
    created_at DATE NOT NULL,
    invoice_type VARCHAR2(20)
    CHECK (invoice_type IN ('FINAL','ADJUSTMENT')),

    tax_id CHAR(5) NOT NULL,
    rental_id CHAR(5) NOT NULL,

    FOREIGN KEY (tax_id) REFERENCES TAXES(tax_id),
    FOREIGN KEY (rental_id) REFERENCES RENTALS(rental_id)
);

CREATE TABLE PAYMENTS (
    payment_id CHAR(5) PRIMARY KEY,

    payment_method VARCHAR2(50) NOT NULL 
        CHECK (payment_method IN ('CASH','CARD','BANK_TRANSFER','E_WALLET')),

    payment_type VARCHAR2(50) NOT NULL 
        CHECK (payment_type IN (
            'DEPOSIT',     -- đặt cọc
            'RENTAL',      -- thanh toán tiền thuê
            'REFUND',      -- hoàn tiền cọc
            'EXTRA'        -- trả thêm (do thiếu cọc)
        )),

    payment_status VARCHAR2(20) NOT NULL 
        CHECK (payment_status IN (
            'PENDING',
            'COMPLETED',
            'FAILED'
        )),

    transaction_code VARCHAR2(100) UNIQUE,

    amount NUMBER(10,2) NOT NULL,

    payment_date DATE NOT NULL,
    created_at DATE NOT NULL,
    notes VARCHAR2(255),

    invoice_id CHAR(5) ,
    rental_id CHAR (5) ,
    CHECK (
    (payment_type = 'DEPOSIT' AND rental_id IS NOT NULL AND invoice_id IS NULL)
     OR (payment_type = 'RENTAL' AND invoice_id IS NOT NULL)
     OR (payment_type = 'REFUND' AND rental_id IS NOT NULL)
     OR (payment_type = 'EXTRA' AND invoice_id IS NOT NULL)
    ),
    FOREIGN KEY (invoice_id) REFERENCES INVOICES(invoice_id),
    FOREIGN KEY (rental_id) REFERENCES RENTALS(rental_id)
);

CREATE TABLE DEPOSITS (
    deposit_id CHAR(5) PRIMARY KEY,

    deposit_amount NUMBER(10,2) NOT NULL,
    refund_amount NUMBER(10,2),
    extra_charge_amount NUMBER(10,2),

    status VARCHAR2(20) NOT NULL 
        CHECK (status IN (
            'HELD',
            'REFUNDED',
            'PARTIAL_REFUND',
            'USED',
            'EXTRA_CHARGED'
        )),

    deposit_date DATE NOT NULL,
    refund_date DATE,

    created_at DATE DEFAULT SYSDATE,

    rental_id CHAR(5) NOT NULL UNIQUE,
    payment_id CHAR(5) NOT NULL,



    FOREIGN KEY (rental_id) REFERENCES RENTALS(rental_id),
    FOREIGN KEY (payment_id) REFERENCES PAYMENTS(payment_id),

    CHECK (deposit_amount >= 0),
    CHECK (refund_amount IS NULL OR refund_amount >= 0),
    CHECK (refund_amount IS NULL OR refund_amount <= deposit_amount),
    CHECK (extra_charge_amount IS NULL OR extra_charge_amount >= 0)
);
-- =========================
-- 4. OTHER TABLES
-- =========================

CREATE TABLE SHIPMENTS (
    shipment_id CHAR(5) PRIMARY KEY,

    shipping_address VARCHAR2(255),

    shipping_method VARCHAR2(50) NOT NULL
        CHECK (shipping_method IN (
            'DELIVERY',   -- giao tận nơi
            'PICKUP'      -- khách tự đến lấy
        )),

    shipment_type VARCHAR2(20) NOT NULL
        CHECK (shipment_type IN (
            'OUTBOUND',   -- giao đi
            'RETURN'      -- nhận về
        )),

    shipping_status VARCHAR2(20) NOT NULL
        CHECK (shipping_status IN (
            'PENDING',
            'SHIPPED',
            'DELIVERED',
            'RETURNED',
            'FAILED'
        )),

    shipping_fee NUMBER(10,2) DEFAULT 0,

    shipped_date DATE,
    delivered_date DATE,

    created_at DATE NOT NULL,

    rental_id CHAR(5) NOT NULL,

    FOREIGN KEY (rental_id) REFERENCES RENTALS(rental_id)
);
CREATE TABLE INVENTORY (
    inventory_id CHAR(5) PRIMARY KEY,

    total_quantity NUMBER(5) NOT NULL,

    available_quantity NUMBER(5) NOT NULL,
    rented_quantity NUMBER(5) DEFAULT 0,
    maintenance_quantity NUMBER(5) DEFAULT 0,
    damaged_quantity NUMBER(5) DEFAULT 0,
    lost_quantity NUMBER(5) DEFAULT 0,

    last_updated DATE DEFAULT SYSDATE,

    equipment_id CHAR(5) NOT NULL UNIQUE,

    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENTS(equipment_id),

    CHECK (available_quantity >= 0),
    CHECK (rented_quantity >= 0),
    CHECK (maintenance_quantity >= 0),
    CHECK (damaged_quantity >= 0),
    CHECK (lost_quantity >= 0),

    CHECK (
        total_quantity =
        available_quantity +
        rented_quantity +
        maintenance_quantity +
        damaged_quantity +
        lost_quantity
    )
);

CREATE TABLE EQUIPMENT_IMAGES (
    image_id CHAR(5) PRIMARY KEY,
    image_url VARCHAR2(255) NOT NULL,
    is_primary NUMBER(1) CHECK (is_primary IN (0,1)) NOT NULL,
    created_at DATE NOT NULL,
    equipment_id CHAR(5) NOT NULL,
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENTS(equipment_id)
);

-- =========================
-- 5. ASSOCIATIVE TABLE
-- =========================

CREATE TABLE EQUIPMENT_ACCESSORIES (
    equipment_id CHAR(5) NOT NULL,      -- Thiết bị chính (MAIN)
    accessory_id CHAR(5) NOT NULL,      -- Phụ kiện bắt buộc (ACCESSORY)
    quantity NUMBER(5) NOT NULL,        -- Số lượng phụ kiện đi kèm theo mỗi thiết bị chính
    created_at DATE NOT NULL,
    PRIMARY KEY (equipment_id, accessory_id),
    CONSTRAINT fk_main_equipment FOREIGN KEY (equipment_id) REFERENCES EQUIPMENTS(equipment_id),
    CONSTRAINT fk_accessory_equipment FOREIGN KEY (accessory_id) REFERENCES EQUIPMENTS(equipment_id)
);
-- =========================
-- 6. SYSTEM LOG (TABLE 16)
-- =========================

CREATE TABLE SYSTEM_LOG (
    log_id CHAR(5) PRIMARY KEY,
    action VARCHAR2(50) NOT NULL,
    table_name VARCHAR2(50) NOT NULL,
    record_id VARCHAR2(50),
    action_time DATE NOT NULL,
    description VARCHAR2(255),
    ip_address VARCHAR2(50)
);

-- =========================
-- DỮ LIỆU MẪU
-- =========================
-- SHOP_INFO
INSERT INTO SHOP_INFO (shop_id, shop_name, shop_address, city, district, created_at, latitude,longitude )
VALUES ('S0001', 'Main Shop', '806 Quốc lộ 22 ấp Mỹ Hòa 3 Xã Tân Xuân, Hóc Môn, HCM', 'HCM', 'Hoc Mon', SYSDATE,10.817,106.652);


-- CUSTOMER
INSERT ALL
    INTO CUSTOMERS VALUES (
        'C0001','user01','hash01','Nguyen Van A','user01@gmail.com',
        '0900000001','Quan 1','ACTIVE',SYSDATE,10.776889,106.700806
    )
    INTO CUSTOMERS VALUES (
        'C0002','user02','hash02','Tran Thi B','user02@gmail.com',
        '0900000002','Quan 2','ACTIVE',SYSDATE,10.787272,106.749810
    )
    INTO CUSTOMERS VALUES (
        'C0003','user03','hash03','Le Van C','user03@gmail.com',
        '0900000003','Quan 3','INACTIVE',SYSDATE,10.782909,106.695227
    )
    INTO CUSTOMERS VALUES (
        'C0004','user04','hash04','Pham Thi D','user04@gmail.com',
        '0900000004','Quan 4','ACTIVE',SYSDATE,10.757451,106.701721
    )
    INTO CUSTOMERS VALUES (
        'C0005','user05','hash05','Hoang Van E','user05@gmail.com',
        '0900000005','Quan 5','ACTIVE',SYSDATE,10.754027,106.663374
    )
    INTO CUSTOMERS VALUES (
        'C0006','user06','hash06','Vo Thi F','user06@gmail.com',
        '0900000006','Quan 6','INACTIVE',SYSDATE,10.748092,106.635236
    )
    INTO CUSTOMERS VALUES (
        'C0007','user07','hash07','Dang Van G','user07@gmail.com',
        '0900000007','Quan 7','ACTIVE',SYSDATE,10.728073,106.721334
    )
    INTO CUSTOMERS VALUES (
        'C0008','user08','hash08','Bui Thi H','user08@gmail.com',
        '0900000008','Quan 8','ACTIVE',SYSDATE,10.724000,106.628000
    )
    INTO CUSTOMERS VALUES (
        'C0009','user09','hash09','Do Van I','user09@gmail.com',
        '0900000009','Binh Thanh','ACTIVE',SYSDATE,10.810583,106.709142
    )
    INTO CUSTOMERS VALUES (
        'C0010','user10','hash10','Nguyen Thi K','user10@gmail.com',
        '0900000010','Thu Duc','INACTIVE',SYSDATE,10.849000,106.771000
    )
SELECT * FROM dual;

-- EMPLOYEE
INSERT ALL
    INTO EMPLOYEES VALUES (
        'E0001','emp01','hash01','Nguyen Van Admin','admin01@gmail.com',
        '0910000001','ADMIN','ACTIVE',SYSDATE
    )
    INTO EMPLOYEES VALUES (
        'E0002','emp02','hash02','Tran Thi Staff','staff01@gmail.com',
        '0910000002','STAFF','ACTIVE',SYSDATE
    )
    INTO EMPLOYEES VALUES (
        'E0003','emp03','hash03','Le Van Manager','manager01@gmail.com',
        '0910000003','MANAGER','ACTIVE',SYSDATE
    )
    INTO EMPLOYEES VALUES (
        'E0004','emp04','hash04','Pham Thi Support','support01@gmail.com',
        '0910000004','SUPPORT','INACTIVE',SYSDATE
    )
    INTO EMPLOYEES VALUES (
        'E0005','emp05','hash05','Hoang Van Sale','sale01@gmail.com',
        '0910000005','SALES','ACTIVE',SYSDATE
    )
SELECT * FROM dual;

-- CATERORIES
-- Dữ liệu mẫu cho bảng CATEGORIES
INSERT ALL
    INTO CATEGORIES VALUES (
        'CAT01','Camera','Các loại máy ảnh chuyên nghiệp',SYSDATE
    )
    INTO CATEGORIES VALUES (
        'CAT02','Lens','Ống kính cho máy ảnh',SYSDATE
    )
    INTO CATEGORIES VALUES (
        'CAT03','Lighting','Thiết bị ánh sáng (đèn, flash)',SYSDATE
    )
    INTO CATEGORIES VALUES (
        'CAT04','Tripod','Chân máy ảnh',SYSDATE
    )
    INTO CATEGORIES VALUES (
        'CAT05','Audio','Thiết bị âm thanh (micro, recorder)',SYSDATE
    )
    INTO CATEGORIES VALUES (
        'CAT06','Accessories','Phụ kiện khác (pin, thẻ nhớ...)',SYSDATE
    )
SELECT * FROM dual;
-- =========================
--EQUIPMENTS
-- =========================
INSERT ALL

-- ================= CAT01: CAMERA =================
INTO EQUIPMENTS VALUES ('EQ001','Canon EOS R6','MAIN','AVAILABLE',
'### Specs
- Sensor: Full-frame
- Mount: RF
- Resolution: 20MP',
50000000,60000000,500000,0.10,200,TO_DATE('2022-01-01','YYYY-MM-DD'),
'Canon','R6','RF','CAT01',1,0.3,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ002','Sony A7 III','MAIN','AVAILABLE',
'### Specs
- Sensor: Full-frame
- Mount: E
- Resolution: 24MP',
45000000,55000000,450000,0.10,250,TO_DATE('2021-06-15','YYYY-MM-DD'),
'Sony','A7III','E','CAT01',1,0.3,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ003','Nikon Z6 II','MAIN','AVAILABLE',
'### Specs
- Sensor: Full-frame
- Mount: Z
- Resolution: 24MP',
40000000,50000000,400000,0.10,180,TO_DATE('2022-03-10','YYYY-MM-DD'),
'Nikon','Z6II','Z','CAT01',1,0.3,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ004','Fujifilm X-T4','MAIN','AVAILABLE',
'### Specs
- Sensor: APS-C
- Mount: X
- Resolution: 26MP',
30000000,38000000,300000,0.12,220,TO_DATE('2021-11-20','YYYY-MM-DD'),
'Fujifilm','X-T4','X','CAT01',0,0.25,SYSDATE)

-- ================= CAT02: LENS (VẪN LÀ MAIN) =================
INTO EQUIPMENTS VALUES ('EQ005','Canon RF 24-70mm f2.8','MAIN','AVAILABLE',
'### Specs
- Focal: 24-70mm
- Aperture: f/2.8
- Mount: RF',
20000000,25000000,200000,0.10,150,TO_DATE('2022-02-01','YYYY-MM-DD'),
'Canon','24-70','RF','CAT02',0,0.2,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ006','Sony FE 85mm f1.8','MAIN','AVAILABLE',
'### Specs
- Focal: 85mm
- Aperture: f/1.8
- Mount: E',
18000000,22000000,180000,0.10,170,TO_DATE('2021-09-01','YYYY-MM-DD'),
'Sony','85mm','E','CAT02',0,0.2,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ007','Nikon Z 50mm f1.8','MAIN','AVAILABLE',
'### Specs
- Focal: 50mm
- Aperture: f/1.8
- Mount: Z',
15000000,20000000,150000,0.10,120,TO_DATE('2022-05-01','YYYY-MM-DD'),
'Nikon','50mm','Z','CAT02',0,0.2,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ008','Sigma 35mm f1.4 Art','MAIN','AVAILABLE',
'### Specs
- Focal: 35mm
- Aperture: f/1.4
- Mount: EF',
17000000,21000000,170000,0.10,130,TO_DATE('2021-08-10','YYYY-MM-DD'),
'Sigma','35mm','EF','CAT02',0,0.2,SYSDATE)

-- ================= CAT03: LIGHTING =================
INTO EQUIPMENTS VALUES ('EQ009','Godox SL60W','MAIN','AVAILABLE',
'### Specs
- Power: 60W
- Color Temp: 5600K',
5000000,7000000,50000,0.15,200,TO_DATE('2021-07-01','YYYY-MM-DD'),
'Godox','SL60W',NULL,'CAT03',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ010','Godox V1 Flash','MAIN','AVAILABLE',
'### Specs
- TTL Flash
- Rechargeable battery',
4000000,6000000,40000,0.15,180,TO_DATE('2022-01-10','YYYY-MM-DD'),
'Godox','V1',NULL,'CAT03',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ011','Aputure 120D','MAIN','AVAILABLE',
'### Specs
- 120W LED
- High CRI',
8000000,10000000,80000,0.15,140,TO_DATE('2021-12-01','YYYY-MM-DD'),
'Aputure','120D',NULL,'CAT03',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ012','Nanlite Forza 60','MAIN','AVAILABLE',
'### Specs
- Compact LED 60W',
6000000,8000000,60000,0.15,160,TO_DATE('2022-04-01','YYYY-MM-DD'),
'Nanlite','Forza60',NULL,'CAT03',0,0.1,SYSDATE)

-- ================= CAT04: TRIPOD =================
INTO EQUIPMENTS VALUES ('EQ013','Manfrotto Tripod','MAIN','AVAILABLE',
'### Specs
- Height: 160cm
- Material: Aluminum',
3000000,5000000,30000,0.15,200,TO_DATE('2021-06-01','YYYY-MM-DD'),
'Manfrotto','MK190',NULL,'CAT04',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ014','Benro Tripod','MAIN','AVAILABLE',
'### Specs
- Lightweight',
2500000,4000000,25000,0.15,180,TO_DATE('2021-09-01','YYYY-MM-DD'),
'Benro','T600EX',NULL,'CAT04',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ015','Sirui Compact Tripod','MAIN','AVAILABLE',
'### Specs
- Travel tripod',
2000000,3500000,20000,0.15,150,TO_DATE('2022-01-01','YYYY-MM-DD'),
'Sirui','T005',NULL,'CAT04',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ016','Zhiyun Crane 2 Gimbal','MAIN','AVAILABLE',
'### Specs
- Stabilizer for camera',
7000000,9000000,70000,0.15,130,TO_DATE('2022-02-01','YYYY-MM-DD'),
'Zhiyun','Crane2',NULL,'CAT04',0,0.1,SYSDATE)

-- ================= CAT05: AUDIO =================
INTO EQUIPMENTS VALUES ('EQ017','Rode VideoMic','MAIN','AVAILABLE',
'### Specs
- Shotgun mic',
2000000,3000000,20000,0.15,120,TO_DATE('2021-05-01','YYYY-MM-DD'),
'Rode','VideoMic',NULL,'CAT05',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ018','Zoom H1n Recorder','MAIN','AVAILABLE',
'### Specs
- Portable recorder',
2500000,3500000,25000,0.15,110,TO_DATE('2021-08-01','YYYY-MM-DD'),
'Zoom','H1n',NULL,'CAT05',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ019','DJI Mic Wireless','MAIN','AVAILABLE',
'### Specs
- Wireless mic system',
5000000,7000000,50000,0.15,100,TO_DATE('2022-03-01','YYYY-MM-DD'),
'DJI','Mic',NULL,'CAT05',0,0.1,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ020','Boya BY-M1','MAIN','AVAILABLE',
'### Specs
- Lavalier mic',
500000,800000,10000,0.15,90,TO_DATE('2021-04-01','YYYY-MM-DD'),
'Boya','BY-M1',NULL,'CAT05',0,0.1,SYSDATE)

-- ================= CAT06: BUNDLE ACCESSORY =================
INTO EQUIPMENTS VALUES ('EQ021','Canon Battery LP-E6','ACCESSORY','AVAILABLE',
'### Default accessory
- Battery for Canon',
1000000,1500000,0,0.20,300,TO_DATE('2022-01-01','YYYY-MM-DD'),
'Canon','LP-E6',NULL,'CAT06',0,0,SYSDATE)

INTO EQUIPMENTS VALUES ('EQ022','Camera Strap','ACCESSORY','AVAILABLE',
'### Default accessory
- Strap included',
200000,300000,0,0.20,300,TO_DATE('2022-01-01','YYYY-MM-DD'),
'Generic','Strap',NULL,'CAT06',0,0,SYSDATE)

SELECT * FROM dual;
-- TAXES
INSERT ALL

INTO TAXES VALUES (
'T0001',
'VAT 10%',
'Thuế giá trị gia tăng 10%',
10,
1,
DATE '2024-01-01',
DATE '2099-12-31',
SYSDATE,
SYSDATE
)

INTO TAXES VALUES (
'T0002',
'VAT 8%',
'Thuế giảm theo chính sách',
8,
1,
DATE '2023-01-01',
DATE '2023-12-31',
SYSDATE,
SYSDATE
)

INTO TAXES VALUES (
'T0003',
'VAT 5%',
'Thuế ưu đãi thiết bị',
5,
0,
DATE '2022-01-01',
DATE '2022-12-31',
SYSDATE,
SYSDATE
)

SELECT * FROM dual;

-- INVENTORY
INSERT ALL

-- ================= CAMERA + LENS (ĐI CHUNG) =================

-- Canon R6 + Canon RF 24-70
INTO INVENTORY VALUES ('IV001',2,1,1,0,0,0,SYSDATE,'EQ001') -- Camera
INTO INVENTORY VALUES ('IV002',2,1,1,0,0,0,SYSDATE,'EQ005') -- Lens

-- Sony A7III + Sony FE 85mm
INTO INVENTORY VALUES ('IV003',2,2,0,0,0,0,SYSDATE,'EQ002')
INTO INVENTORY VALUES ('IV004',2,2,0,0,0,0,SYSDATE,'EQ006')

-- Nikon Z6II + Nikon Z 50mm
INTO INVENTORY VALUES ('IV005',1,1,0,0,0,0,SYSDATE,'EQ003')
INTO INVENTORY VALUES ('IV006',1,1,0,0,0,0,SYSDATE,'EQ007')

-- Fujifilm XT4 + Sigma 35mm
INTO INVENTORY VALUES ('IV007',1,1,0,0,0,0,SYSDATE,'EQ004')
INTO INVENTORY VALUES ('IV008',1,1,0,0,0,0,SYSDATE,'EQ008')

-- ================= LIGHTING =================

INTO INVENTORY VALUES ('IV009',2,2,0,0,0,0,SYSDATE,'EQ009')
INTO INVENTORY VALUES ('IV010',2,1,1,0,0,0,SYSDATE,'EQ010')
INTO INVENTORY VALUES ('IV011',1,1,0,0,0,0,SYSDATE,'EQ011')
INTO INVENTORY VALUES ('IV012',1,1,0,0,0,0,SYSDATE,'EQ012')

-- ================= TRIPOD =================

INTO INVENTORY VALUES ('IV013',2,1,1,0,0,0,SYSDATE,'EQ013')
INTO INVENTORY VALUES ('IV014',1,1,0,0,0,0,SYSDATE,'EQ014')
INTO INVENTORY VALUES ('IV015',1,1,0,0,0,0,SYSDATE,'EQ015')
INTO INVENTORY VALUES ('IV016',1,1,0,0,0,0,SYSDATE,'EQ016')

-- ================= AUDIO =================

INTO INVENTORY VALUES ('IV017',2,1,1,0,0,0,SYSDATE,'EQ017')
INTO INVENTORY VALUES ('IV018',1,1,0,0,0,0,SYSDATE,'EQ018')
INTO INVENTORY VALUES ('IV019',1,1,0,0,0,0,SYSDATE,'EQ019')
INTO INVENTORY VALUES ('IV020',2,2,0,0,0,0,SYSDATE,'EQ020')

-- ================= ACCESSORY (DÙNG CHUNG) =================

INTO INVENTORY VALUES ('IV021',3,3,0,0,0,0,SYSDATE,'EQ021') -- Battery
INTO INVENTORY VALUES ('IV022',3,3,0,0,0,0,SYSDATE,'EQ022') -- Strap

SELECT 1 FROM DUAL;


--- Flow
1. Create Rental (PENDING)
2. Pay Deposit
3. Confirm Pickup → ACTIVE
4. Return Equipment
5. Calculate:
   - Late Fee
   - Damage Fee
   - Lost Fee
6. Generate Invoice
7. Customer Payment
8. Deposit Settlement:
   - Refund / Deduct / Extra charge
9. Complete Rental


