
-- ============ EQUIPMENTS ============
-- Tìm kiếm theo loại + trạng thái (composite, giữ nguyên)
CREATE INDEX IDX_EQUIPMENTS_TYPE_STATUS 
ON EQUIPMENTS(equipment_type, status);

-- Tìm kiếm theo category đơn giản
CREATE INDEX IDX_EQUIPMENTS_CATEGORY 
ON EQUIPMENTS(category_id);

-- Tìm kiếm theo brand + model + mount_type (composite)
CREATE INDEX IDX_EQUIPMENTS_BRAND_MODEL
ON EQUIPMENTS(brand, model, mount_type);

-- ============ CUSTOMERS ============
-- Trạng thái Active/Inactive
CREATE INDEX IDX_CUSTOMERS_STATUS 
ON CUSTOMERS(status);

-- Vị trí địa lý (nếu cần tính khoảng cách, xem xét spatial index)
CREATE INDEX IDX_CUSTOMERS_LOCATION
ON CUSTOMERS(latitude, longitude);

-- ============ RENTALS ============
-- Composite index: status + rental_date, dùng cho filter + báo cáo
CREATE INDEX IDX_RENTALS_STATUS_DATE
ON RENTALS(status, rental_date);

-- Join nhanh theo customer_id + employee_id
CREATE INDEX IDX_RENTALS_CUSTOMER_EMPLOYEE
ON RENTALS(customer_id, employee_id);

-- Nếu chỉ báo cáo theo rental_date riêng lẻ (không cần filter status)
-- CREATE INDEX IDX_RENTALS_DATE ON RENTALS(rental_date);

-- ============ RENTAL_ITEMS ============
-- Composite index: equipment_id + item_status
-- Hỗ trợ check tồn kho và filter thiết bị đang mượn/hỏng
CREATE INDEX IDX_RENTAL_ITEMS_EQUIPMENT_STATUS
ON RENTAL_ITEMS(equipment_id, item_status);

-- Join nhanh theo rental_id
CREATE INDEX IDX_RENTAL_ITEMS_RENTAL
ON RENTAL_ITEMS(rental_id);

-- ============ INVOICES ============
-- Join nhanh theo rental_id
CREATE INDEX IDX_INVOICES_RENTAL
ON INVOICES(rental_id);

-- Composite index: status + invoice_date
-- Hỗ trợ tìm hóa đơn chưa thanh toán và báo cáo theo ngày
CREATE INDEX IDX_INVOICES_STATUS_DATE
ON INVOICES(status, invoice_date);

-- ============ PAYMENTS ============
-- Join nhanh theo invoice_id
CREATE INDEX IDX_PAYMENTS_INVOICE
ON PAYMENTS(invoice_id);

-- Nếu cần báo cáo theo payment_date (filter + sort)
CREATE INDEX IDX_PAYMENTS_DATE
ON PAYMENTS(payment_date);

-- ============ SYSTEM_LOG ============
-- Tra cứu nhanh theo thời gian hành động
CREATE INDEX IDX_SYSTEM_LOG_TIME
ON SYSTEM_LOG(action_time);

-- Tra cứu log của bảng cụ thể
CREATE INDEX IDX_SYSTEM_LOG_TABLE
ON SYSTEM_LOG(table_name);

