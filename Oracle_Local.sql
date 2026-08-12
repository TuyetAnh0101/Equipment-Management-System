/*========================================================
1. TẠO USER (SCHEMA CHÍNH)                            
========================================================*/
CREATE USER QuanLy_Equipment IDENTIFIED BY 123;

GRANT CREATE SESSION TO QuanLy_Equipment;
GRANT CREATE TABLE TO QuanLy_Equipment;
GRANT CREATE VIEW TO QuanLy_Equipment;
GRANT CREATE SEQUENCE TO QuanLy_Equipment;
GRANT CREATE TRIGGER TO QuanLy_Equipment;
GRANT CREATE PROCEDURE TO QuanLy_Equipment;

ALTER USER QuanLy_Equipment QUOTA UNLIMITED ON USERS;


/*========================================================
 2. PROFILE (QUẢN LÝ BẢO MẬT)                          
========================================================*/
ALTER SYSTEM SET resource_limit = TRUE;

CREATE PROFILE EQUIPMENT_PROFILE LIMIT
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LIFE_TIME 60
    PASSWORD_REUSE_TIME 30
    PASSWORD_REUSE_MAX 5
    PASSWORD_LOCK_TIME 1/24
    PASSWORD_GRACE_TIME 5
    SESSIONS_PER_USER 3
    IDLE_TIME 30;

ALTER USER QuanLy_Equipment PROFILE EQUIPMENT_PROFILE;


/*========================================================
3. TẠO ROLE THEO NGHIỆP VỤ                           
========================================================*/
CREATE ROLE ROLE_ADMIN;
CREATE ROLE ROLE_MANAGER;
CREATE ROLE ROLE_STAFF;


/*========================================================
4. CẤP QUYỀN HỆ THỐNG (SYSTEM PRIVILEGES)            
========================================================*/

-- ADMIN (toàn quyền hệ thống)
GRANT CREATE ANY TABLE TO ROLE_ADMIN;
GRANT DROP ANY TABLE TO ROLE_ADMIN;
GRANT CREATE ANY VIEW TO ROLE_ADMIN;
GRANT CREATE ANY PROCEDURE TO ROLE_ADMIN;

-- MANAGER (xem + quản lý dữ liệu kinh doanh)
GRANT CREATE VIEW TO ROLE_MANAGER;

-- STAFF (thao tác nghiệp vụ)
GRANT CREATE SESSION TO ROLE_STAFF;


/*========================================================
5. CẤP QUYỀN TRÊN BẢNG (OBJECT PRIVILEGES)      
========================================================*/

-- ===== ADMIN =====
GRANT SELECT, INSERT, UPDATE, DELETE 
ON QuanLy_Equipment.EQUIPMENTS TO ROLE_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE 
ON QuanLy_Equipment.RENTALS TO ROLE_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE 
ON QuanLy_Equipment.INVOICES TO ROLE_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE 
ON QuanLy_Equipment.SYSTEM_LOG TO ROLE_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE 
ON QuanLy_Equipment.TAXES TO ROLE_ADMIN;


-- ===== MANAGER =====
GRANT SELECT 
ON QuanLy_Equipment.INVOICES TO ROLE_MANAGER;

GRANT SELECT 
ON QuanLy_Equipment.RENTALS TO ROLE_MANAGER;

GRANT SELECT, UPDATE 
ON QuanLy_Equipment.EQUIPMENTS TO ROLE_MANAGER;


-- ===== STAFF =====
GRANT SELECT, INSERT, UPDATE 
ON QuanLy_Equipment.RENTALS TO ROLE_STAFF;

GRANT SELECT, INSERT, UPDATE 
ON QuanLy_Equipment.RETURNS TO ROLE_STAFF;

GRANT SELECT, INSERT 
ON QuanLy_Equipment.DEPOSITS TO ROLE_STAFF;

GRANT SELECT, UPDATE 
ON QuanLy_Equipment.INVENTORY TO ROLE_STAFF;


/*========================================================
= 6. TẠO USER THỰC TẾ (ỨNG DỤNG / NHÂN SỰ)             =
========================================================*/

-- Nhân viên
CREATE USER staff_user IDENTIFIED BY 123;
GRANT CREATE SESSION TO staff_user;
GRANT ROLE_STAFF TO staff_user;

-- Quản lý
CREATE USER manager_user IDENTIFIED BY 123;
GRANT CREATE SESSION TO manager_user;
GRANT ROLE_MANAGER TO manager_user;

-- Admin hệ thống
CREATE USER admin_user IDENTIFIED BY 123;
GRANT CREATE SESSION TO admin_user;
GRANT ROLE_ADMIN TO admin_user;


/*========================================================
 7. KIỂM TRA                                          
========================================================*/

-- Kiểm tra user
SELECT username, account_status FROM dba_users;

-- Kiểm tra role
SELECT * FROM dba_roles;

-- Kiểm tra quyền hệ thống
SELECT * FROM user_sys_privs;

-- Kiểm tra quyền bảng
SELECT * FROM user_tab_privs_recd;

-- Role đang hoạt động
SELECT * FROM SESSION_ROLES;