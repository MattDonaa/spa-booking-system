# Day Spa & Wellness Booking System

Version: 1.0
Status: MVP Specification

---

# Project Vision

Build a production-ready online booking platform for day spas and wellness clinics.

The platform must allow clients to discover services, book appointments, complete required intake forms, pay deposits online, receive automated reminders, and manage bookings without staff intervention.

The system must reduce administration while improving the client experience.

---

# Primary Goals

- Eliminate double bookings.
- Automate appointment scheduling.
- Automate payment collection.
- Automate client intake.
- Protect sensitive medical information.
- Minimize manual administration.
- Deliver a fast, mobile-first experience.
- Comply with POPIA.

---

# User Types

## Client

Can:

- Register/Login
- Browse services
- View therapist availability
- Book appointments
- Pay deposits
- Complete intake forms
- View booking history
- Reschedule appointments
- Cancel appointments
- Receive reminders

---

## Practitioner

Can:

- View calendar
- View assigned bookings
- Access assigned intake forms
- Manage availability
- Block dates
- Mark appointments completed
- View client history

---

## Administrator

Can:

- Manage practitioners
- Manage services
- Manage rooms
- Configure business settings
- View analytics
- View payments
- View audit logs
- Manage notifications

---

# Booking Lifecycle

Available

↓

Pending Hold

↓

Pending Payment

↓

Pending Intake

↓

Confirmed

↓

Checked In

↓

In Progress

↓

Completed

Alternative outcomes:

Expired

Cancelled

Refunded

No Show

---

# Core Features

- Online Booking
- Therapist Scheduling
- Availability Management
- Payment Collection
- Intake Forms
- Notification Engine
- Admin Dashboard
- Client Portal
- Reporting
- Audit Logging

---

# Payment Requirements

Support:

- PayFast
- Ozow

Requirements:

- Secure webhook verification
- Idempotent payment processing
- Deposit payments
- Payment history
- Refund support

---

# Intake Forms

Support:

- Medical questionnaires
- Consent forms
- Electronic signatures
- Versioned templates
- Practitioner-only access

---

# Notifications

Support:

- WhatsApp
- Email

Automations:

- Booking confirmation
- Payment reminder
- Appointment reminder
- Review request
- Rebooking reminder

---

# Compliance

The platform must comply with POPIA.

Medical information must never be publicly accessible.

Every database table containing sensitive information must enforce Row Level Security.

---

# Technical Stack

Frontend

- Next.js App Router
- React
- TypeScript
- Tailwind CSS
- Shadcn UI

Backend

- Supabase
- PostgreSQL
- Edge Functions
- Supabase Auth

Payments

- PayFast
- Ozow

---

# MVP Success Criteria

The MVP is complete when a client can:

1. Book an appointment.
2. Securely reserve a time slot.
3. Pay a deposit.
4. Complete an intake form.
5. Receive confirmations.
6. Attend the appointment.
7. Have the appointment completed.
8. Generate audit records for every important event.

No manual intervention should be required during the normal booking process.
