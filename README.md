<div align="center">

# Equipment Management System

### Oracle Database Project

A database-driven equipment management system for managing inventory, rentals, returns, late fees, payments, and invoices, with most business logic implemented at the database layer using PL/SQL.

<p>
  <img src="https://img.shields.io/badge/Oracle-F80000?style=for-the-badge&logo=oracle&logoColor=white" />
  <img src="https://img.shields.io/badge/PL%2FSQL-4479A1?style=for-the-badge" />
  <img src="https://img.shields.io/badge/SQL-336791?style=for-the-badge" />
</p>

</div>

---

## Table of Contents

* [Overview](#overview)
* [System Operations](#system-operations)
* [Database Design](#database-design)
* [Technologies](#technologies)
* [Project Scope](#project-scope)
* [Author](#author)

---

## Overview

The Equipment Management System manages the complete lifecycle of an equipment rental, from inventory management and rental creation to equipment returns, late fee calculation, payments, and tax-based invoice generation.

The main purpose of this project is to practice **relational database design and PL/SQL programming** for a business system with multiple constraints and interconnected operations.

Key business rules are implemented primarily at the database layer using **triggers, functions, procedures, and constraints**, reducing dependency on application-level processing.

---

## System Operations

<table>
<tr>
<td width="50%" valign="top">

### Equipment and Inventory Management

Track equipment by category, inventory quantity, and current status such as available, rented, or under maintenance.

### Rental Management

Create rental orders, assign equipment to rental items, and record deposits. Equipment status is automatically updated when a rental is confirmed.

### Return Processing

Record the actual return date, calculate late fees when the rental exceeds the due date, and evaluate equipment condition to determine the appropriate deposit refund.

</td>

<td width="50%" valign="top">

### Payments and Invoices

Calculate rental charges, additional fees, and taxes before generating an invoice for each rental.

### Logging and Control

Record important system operations such as rental creation, equipment status changes, and payment activities for auditing and data consistency checks.

</td>
</tr>
</table>

---

## Database Design

The main business rules are implemented at the database layer.

| Database Component | Responsibility                                                                                                          |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Trigger            | Automatically update equipment status when rental or return operations occur                                            |
| Function           | Calculate late fees based on overdue days and equipment rental price                                                    |
| Procedure          | Process invoice generation by calculating rental charges, additional fees, applying taxes, and creating invoice records |
| Constraint         | Prevent the same equipment from being assigned to multiple active rentals                                               |

### Entity Relationship Diagram

<details>
<summary><strong>View Database ERD</strong></summary>

<br>

<p align="center">
  <img src="./docs/erdplus.png" alt="Equipment Management System ERD" width="100%" />
</p>

</details>

---

## Technologies

| Component            | Technology                                     |
| -------------------- | ---------------------------------------------- |
| Database             | Oracle Database                                |
| Programming Language | SQL, PL/SQL                                    |
| Business Logic       | Stored Procedures, Functions, Triggers         |
| Database Design      | Relational Schema, Entity Relationship Diagram |
| Normalization        | Third Normal Form (3NF)                        |

---

## Project Scope

This project focuses primarily on **database backend development rather than the user interface**.

The main focus is designing a relational database that correctly represents the business requirements and implementing PL/SQL logic for operations such as:

* Equipment status management
* Rental processing
* Deposit calculation
* Late fee calculation
* Return processing
* Payment processing
* Invoice generation
* Tax calculation
* System logging

The goal is to ensure that important business rules are enforced directly at the database level rather than depending entirely on the application layer.

---

## Author

<div align="center">

<a href="https://github.com/TuyetAnh0101">
  <img src="https://img.shields.io/badge/GitHub-TuyetAnh0101-181717?style=for-the-badge&logo=github&logoColor=white" />
</a>

</div>
