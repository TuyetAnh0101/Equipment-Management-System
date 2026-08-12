----  VW_INVENTORY_STATUS
CREATE OR REPLACE VIEW VW_INVENTORY_STATUS AS
SELECT 
    i.equipment_id,
    e.equipment_name,
    e.equipment_type,
    e.status AS equipment_status,
    i.total_quantity,
    NVL(SUM(CASE WHEN ri.item_status = 'BORROWING' THEN ri.quantity ELSE 0 END),0) AS borrowed_quantity,
    i.total_quantity - NVL(SUM(CASE WHEN ri.item_status = 'BORROWING' THEN ri.quantity ELSE 0 END),0) AS available_quantity
FROM INVENTORY i
JOIN EQUIPMENTS e ON i.equipment_id = e.equipment_id
LEFT JOIN RENTAL_ITEMS ri ON i.equipment_id = ri.equipment_id AND ri.item_status = 'BORROWING'
GROUP BY i.equipment_id, e.equipment_name, e.equipment_type, e.status, i.total_quantity
ORDER BY e.equipment_name;

---- VW_AVAILABLE_EQUIPMENT (sửa WHERE)
CREATE OR REPLACE VIEW VW_AVAILABLE_EQUIPMENT AS
SELECT 
    e.equipment_id,
    e.equipment_name,
    e.equipment_type,
    e.status AS equipment_status,
    e.rental_price_per_day,
    NVL(i.total_quantity, 0) - NVL(SUM(CASE 
        WHEN ri.item_status = 'BORROWING' THEN ri.quantity ELSE 0 END),0) AS available_quantity
FROM EQUIPMENTS e
LEFT JOIN INVENTORY i ON e.equipment_id = i.equipment_id
LEFT JOIN RENTAL_ITEMS ri 
    ON e.equipment_id = ri.equipment_id
    AND ri.item_status = 'BORROWING'
WHERE e.status = 'AVAILABLE'
GROUP BY e.equipment_id, e.equipment_name, e.equipment_type, e.status, e.rental_price_per_day, i.total_quantity
ORDER BY e.equipment_name;


---- VW_RENTAL_DETAILS (LEFT JOIN để show rental chưa có item)
CREATE OR REPLACE VIEW VW_RENTAL_DETAILS AS
SELECT 
    r.rental_id,
    r.rental_code,
    r.rental_type,
    r.status AS rental_status,
    r.total_amount,
    r.deposit_required,
    r.rental_date,
    r.due_date,
    r.return_date,
    c.customer_id,
    c.full_name AS customer_name,
    e.employee_id,
    e.full_name AS employee_name,
    ri.rental_item_id,
    eq.equipment_id,
    eq.equipment_name,
    ri.quantity,
    ri.days,
    ri.price_per_day,
    ri.subtotal,
    ri.item_status
FROM RENTALS r
JOIN CUSTOMERS c ON r.customer_id = c.customer_id
JOIN EMPLOYEES e ON r.employee_id = e.employee_id
LEFT JOIN RENTAL_ITEMS ri ON r.rental_id = ri.rental_id
LEFT JOIN EQUIPMENTS eq ON ri.equipment_id = eq.equipment_id
ORDER BY r.rental_date DESC, r.rental_code;


---- VW_INVOICE_FULL (tránh double counting bằng subquery)
CREATE OR REPLACE VIEW VW_INVOICE_FULL AS
WITH total_payments AS (
    SELECT invoice_id, NVL(SUM(amount),0) AS total_paid
    FROM PAYMENTS
    GROUP BY invoice_id
),
total_deposits AS (
    SELECT rental_id, NVL(SUM(deposit_amount),0) AS total_deposit
    FROM DEPOSITS
    GROUP BY rental_id
)
SELECT 
    iv.invoice_id,
    iv.invoice_number,
    iv.status AS invoice_status,
    iv.rental_id,
    r.rental_code,
    iv.subtotal_amount,
    iv.tax_amount,
    iv.total_amount,
    iv.deposit_used,
    iv.final_amount,
    iv.invoice_date,
    iv.payment_due_date,
    NVL(tp.total_paid,0) AS total_paid,
    NVL(td.total_deposit,0) AS total_deposit
FROM INVOICES iv
JOIN RENTALS r ON iv.rental_id = r.rental_id
LEFT JOIN total_payments tp ON iv.invoice_id = tp.invoice_id
LEFT JOIN total_deposits td ON iv.rental_id = td.rental_id
ORDER BY iv.invoice_date DESC;


---- VW_RETURN_ANALYSIS (xử lý NULL return_date)
CREATE OR REPLACE VIEW VW_RETURN_ANALYSIS AS
SELECT 
    ret.return_id,
    ret.return_date,
    ri.rental_item_id,
    ri.rental_id,
    eq.equipment_id,
    eq.equipment_name,
    ri.quantity,
    ri.days,
    ri.item_status,
    r.due_date,
    CASE 
        WHEN ret.return_date IS NULL THEN NULL
        WHEN ret.return_date > r.due_date THEN ret.return_date - r.due_date
        ELSE 0
    END AS late_days
FROM RETURNS ret
JOIN RENTAL_ITEMS ri ON ret.rental_item_id = ri.rental_item_id
JOIN RENTALS r ON ri.rental_id = r.rental_id
JOIN EQUIPMENTS eq ON ri.equipment_id = eq.equipment_id
ORDER BY ret.return_date DESC;
